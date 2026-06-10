#!/usr/bin/env node

const fs = require("fs");
const os = require("os");
const path = require("path");
const { spawnSync } = require("child_process");

const PROJECT_ROOT = path.resolve(__dirname, "../..");
const args = parseArgs(process.argv.slice(2));

if (args.help || args.h) {
	usage();
	process.exit(0);
}

const gate = String(args.gate || "all").toLowerCase();
const device = String(args.device || process.env.DEVICE || "");
const packageName = String(args.package || process.env.PACKAGE || "org.godotengine.godotxrfoundation");
const reportPath = args.report ? path.resolve(String(args.report)) : "";
const jsonPath = args.json ? path.resolve(String(args.json)) : "";
const format = String(args.format || (reportPath ? "markdown" : "json")).toLowerCase();

const supportedGates = ["rokid", "ipad", "android-arcore", "all"];
if (!supportedGates.includes(gate)) {
	usage();
	process.exit(2);
}

const gates = gate === "all" ? ["rokid", "ipad", "android-arcore"] : [gate];
const results = gates.map((item) => {
	if (item === "ipad") {
		return checkIpadReady();
	}
	return checkAndroidReady(item);
});

const summary = {
	pass: results.every((result) => result.pass),
	gate,
	generated_at: new Date().toISOString(),
	projectRoot: PROJECT_ROOT,
	results,
};

if (jsonPath) {
	fs.mkdirSync(path.dirname(jsonPath), { recursive: true });
	fs.writeFileSync(jsonPath, `${JSON.stringify(summary, null, 2)}\n`, "utf8");
}

const output = format === "markdown" ? renderMarkdown(summary) : JSON.stringify(summary, null, 2);
if (reportPath) {
	fs.mkdirSync(path.dirname(reportPath), { recursive: true });
	fs.writeFileSync(reportPath, `${output}\n`, "utf8");
}
console.log(output);
process.exit(summary.pass ? 0 : 1);


function checkAndroidReady(gateName) {
	const adb = resolveAdb();
	const serial = String(args.serial || process.env.ADB_SERIAL || "");
	const failures = [];
	const warnings = [];
	const devices = adb ? run(adb, ["devices", "-l"]) : { ok: false, stdout: "", stderr: "adb not found" };
	const parsedDevices = parseAdbDevices(devices.stdout);
	const availableDevices = parsedDevices.filter((item) => item.state === "device");
	const targetDevice = serial ? parsedDevices.find((item) => item.serial === serial) : availableDevices[0] || null;
	const hostPermissionBlocked = isAndroidHostPermissionBlocked(devices);
	const host = collectAndroidHost(adb, devices);

	if (!adb) {
		failures.push("adb was not found. Set ADB_BIN or install Android platform-tools.");
	} else if (hostPermissionBlocked) {
		failures.push(`Host permission blocked adb readiness: ${devices.stderr || "adb could not start or query its local server"}`);
	} else if (!devices.ok) {
		failures.push(`adb devices -l failed: ${devices.stderr || "unknown error"}`);
	} else if (serial && (!targetDevice || targetDevice.state !== "device")) {
		failures.push(`ADB serial ${serial} is not available in state 'device'.`);
	} else if (availableDevices.length === 0) {
		failures.push("No Android/Rokid device is available in adb state 'device'.");
	}

	for (const item of parsedDevices) {
		if (item.state !== "device") {
			warnings.push(`ADB device ${item.serial} is in state '${item.state}', not 'device'.`);
		}
	}

	if (gateName === "rokid" && targetDevice && !/rokid/i.test([targetDevice.serial, ...targetDevice.details].join(" "))) {
		warnings.push("Ready device is not visibly identified as Rokid from adb devices -l; final proof must come from device profile and OpenXR smoke evidence.");
	}

	return {
		gate: gateName,
		pass: failures.length === 0,
		failures,
		warnings,
		next_actions: androidReadinessNextActions(gateName, { adb, devices, parsedDevices, availableDevices, serial, targetDevice, hostPermissionBlocked, host }),
		evidence: {
			adb,
			serial: serial || "",
			host_permission_blocked: hostPermissionBlocked,
			host,
			devices: parsedDevices,
			selected_device: targetDevice,
			raw_devices_output: devices.stdout.trim(),
		},
	};
}


function checkIpadReady() {
	const failures = [];
	const warnings = [];
	if (!device) {
		return {
			gate: "ipad",
			pass: false,
			failures: ["iPad device name or identifier is required. Pass --device <name-or-uuid> or set DEVICE."],
			warnings,
			evidence: {},
		};
	}

	const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), "godotar-ipad-ready-"));
	const profileJsonPath = path.join(tempDir, "ipad-device.json");
	const collect = run("node", [
		path.join(PROJECT_ROOT, "tools/c00/collect_ios_device_profile.js"),
		"--device", device,
		"--bundle", packageName,
		"--timeout", String(args["device-timeout"] || process.env.DEVICECTL_TIMEOUT || "5"),
		"--json", profileJsonPath,
	]);
	if (!collect.ok) {
		failures.push(`iPad device profile collection failed: ${collect.stderr || collect.stdout || "unknown error"}`);
	}

	let profile = {};
	try {
		if (fs.existsSync(profileJsonPath)) {
			profile = JSON.parse(fs.readFileSync(profileJsonPath, "utf8"));
		}
	} catch (error) {
		failures.push(`iPad readiness profile JSON could not be parsed: ${String(error.message || error)}`);
	}

	const analyze = run("node", [
		path.join(PROJECT_ROOT, "tools/c00/analyze_ios_device_profile.js"),
		"--json", profileJsonPath,
		"--allow-missing-target",
	]);
	const analysis = parseJsonOutput(analyze.stdout);
	const hostPermissionBlocked = isIpadHostPermissionBlocked(profile, collect, analyze, analysis);
	if (!analyze.ok) {
		for (const failure of arrayOfStrings(analysis.failures)) {
			failures.push(failure);
		}
		if (arrayOfStrings(analysis.failures).length === 0) {
			failures.push(`iPad device profile analysis failed: ${analyze.stderr || analyze.stdout || "unknown error"}`);
		}
	}
	for (const warning of arrayOfStrings(analysis.warnings)) {
		warnings.push(warning);
	}

	return {
		gate: "ipad",
		pass: failures.length === 0,
		failures,
		warnings,
		next_actions: ipadReadinessNextActions({ device, profile, analysis, hostPermissionBlocked }),
		evidence: {
			device,
			host_permission_blocked: hostPermissionBlocked,
			profile: summarizeIpadProfile(profile),
			analysis: analysis.evidence || {},
		},
	};
}


function androidReadinessNextActions(gateName, context) {
	const actions = [];
	const parsedDevices = context.parsedDevices || [];
	const states = new Set(parsedDevices.map((item) => item.state));
	const label = gateName === "rokid" ? "Rokid/OpenXR" : "Android/ARCore";
	const usbDevices = ((context.host && context.host.usb && context.host.usb.android_like_devices) || []);

	if (!context.adb) {
		actions.push("Install Android platform-tools or set ADB_BIN to the adb executable from the C00 Android SDK.");
		return actions;
	}
	if (context.hostPermissionBlocked) {
		actions.push("Run the readiness command from a normal macOS terminal or an approved unsandboxed Codex command so adb can bind its local server socket.");
		actions.push("If adb is wedged after a blocked run, run `adb kill-server` and retry with the project-local platform-tools adb.");
		return actions;
	}
	if (context.devices && context.devices.ok === false) {
		actions.push("Run the readiness command from a normal terminal so adb can start its local server, then retry.");
		actions.push("If adb is wedged, run `adb kill-server` and retry with the project-local platform-tools adb.");
		return actions;
	}
	if (parsedDevices.length === 0) {
		if (usbDevices.length > 0) {
			actions.push(`macOS USB sees possible Android/XR hardware (${usbDevices.map((item) => item.name || item.manufacturer || item.serial || "unknown").join(", ")}), but adb lists no transport. Unlock the device, enable USB debugging, switch the USB mode away from charge-only if needed, and accept the RSA trust prompt.`);
		} else {
			actions.push(`Connect the ${label} device over USB-C, enable Developer Options and USB debugging, then accept the RSA trust prompt on the device.`);
		}
		actions.push("Re-run `adb devices -l` and wait until the device state is exactly `device`.");
		return actions;
	}
	if (states.has("unauthorized")) {
		actions.push("Unlock the Android/Rokid device and accept the USB debugging RSA prompt; if no prompt appears, revoke USB debugging authorizations and reconnect.");
	}
	if (states.has("offline")) {
		actions.push("Reconnect the USB cable or restart adb with `adb kill-server && adb start-server` until the device leaves the `offline` state.");
	}
	if (context.serial && (!context.targetDevice || context.targetDevice.state !== "device")) {
		actions.push(`Confirm ADB_SERIAL=${context.serial} matches the serial printed by \`adb devices -l\`, or remove ADB_SERIAL to use the first ready device.`);
	}
	if (actions.length === 0 && context.availableDevices.length === 0) {
		actions.push("Wait for adb transport to settle, then retry readiness before running the device gate.");
	}
	return actions;
}


function collectAndroidHost(adb, devicesResult) {
	const adbVersion = adb ? run(adb, ["version"]) : { ok: false, stdout: "", stderr: "adb not found" };
	return {
		adb_binary: adb || "",
		adb_version: parseAdbVersion(adbVersion.stdout || adbVersion.stderr),
		adb_version_output: truncate(adbVersion.stdout || adbVersion.stderr || "", 800),
		adb_devices_stderr: truncate((devicesResult && devicesResult.stderr) || "", 800),
		android_home: process.env.ANDROID_HOME || "",
		android_sdk_root: process.env.ANDROID_SDK_ROOT || "",
		java_home: process.env.JAVA_HOME || "",
		path_has_adb: commandExists("adb"),
		usb: collectUsbSummary(),
	};
}


function collectUsbSummary() {
	if (process.platform !== "darwin") {
		return {
			available: false,
			reason: "non-darwin-host",
			android_like_devices: [],
		};
	}
	const result = spawnSync("system_profiler", ["SPUSBDataType", "-json"], { encoding: "utf8", timeout: 8000 });
	if (result.status !== 0 || !result.stdout) {
		return {
			available: false,
			status: result.status,
			error: truncate(result.stderr || result.stdout || result.error || "", 800),
			android_like_devices: [],
		};
	}
	let json = null;
	try {
		json = JSON.parse(result.stdout);
	} catch (error) {
		return {
			available: false,
			error: `system_profiler JSON parse failed: ${String(error.message || error)}`,
			android_like_devices: [],
		};
	}
	return {
		available: true,
		android_like_devices: findUsbAndroidLikeDevices(json),
	};
}


function findUsbAndroidLikeDevices(value, output = []) {
	if (!value || typeof value !== "object") {
		return output;
	}
	if (Array.isArray(value)) {
		for (const item of value) {
			findUsbAndroidLikeDevices(item, output);
		}
		return output;
	}
	const text = JSON.stringify(value);
	if (/android|adb|rokid|pico|quest|oculus|meta|lynx|vive|google/i.test(text)) {
		output.push({
			name: value._name || value.name || "",
			manufacturer: value.manufacturer || value.vendor_name || "",
			product_id: value.product_id || "",
			vendor_id: value.vendor_id || "",
			serial: value.serial_num || value.serial || "",
		});
	}
	for (const item of Object.values(value)) {
		findUsbAndroidLikeDevices(item, output);
	}
	return output.slice(0, 12);
}


function parseAdbVersion(text) {
	const match = String(text || "").match(/Android Debug Bridge version\s+([^\s]+)/i);
	return match ? match[1] : "";
}


function commandExists(command) {
	const found = spawnSync("sh", ["-lc", `command -v ${shellQuote(command)}`], { encoding: "utf8" });
	return found.status === 0 && Boolean(found.stdout.trim());
}


function ipadReadinessNextActions(context) {
	const actions = [];
	const profile = context.profile || {};
	const analysis = context.analysis || {};
	const evidence = analysis.evidence || {};
	const selectedDevice = profile.selected_device || {};
	const availability = String(evidence.device_availability || "").toLowerCase();

	if (context.hostPermissionBlocked) {
		actions.push("Run the iPad readiness command from a normal macOS terminal or an approved unsandboxed Codex command so devicectl, CoreDevice, and xctrace can access user caches and XPC services.");
		actions.push("After the host permission check passes, reconnect and unlock the iPad, trust this Mac, then rerun readiness with the same --device value.");
		return actions;
	}
	if (!profile.selected_device) {
		actions.push(`Connect the iPad, unlock it, trust this Mac, then confirm it appears in \`xcrun devicectl list devices\` using the same --device value: ${context.device}.`);
		return actions;
	}
	if (availability === "offline" || availability === "unavailable") {
		actions.push("Unlock the iPad, keep the screen awake, reconnect USB-C, and accept any Trust This Computer prompt.");
		actions.push("Open Xcode Devices and Simulators once so CoreDevice can finish pairing and developer services setup.");
	}
	if (selectedDevice.ddiServicesAvailable === false) {
		actions.push(buildDdiServicesAction(profile, selectedDevice));
	}
	if (selectedDevice.developerModeStatus && String(selectedDevice.developerModeStatus).toLowerCase() !== "enabled") {
		actions.push("Enable Developer Mode on the iPad and reboot when iPadOS asks for it.");
	}
	if (evidence.lock_state === "locked") {
		actions.push("Unlock the iPad before running the ARKit gate.");
	}
	if (evidence.target_bundle_installed === false) {
		actions.push("This is expected before the install step; once the device is available, run the iPad gate so it can install the .app.");
	}
	if (actions.length === 0 && analysis.pass !== true) {
		actions.push("Retry readiness from a normal terminal and inspect the devicectl/xctrace stderr in the evidence block.");
	}
	return actions;
}


function isAndroidHostPermissionBlocked(result) {
	const text = [
		result && result.stderr,
		result && result.stdout,
	].join("\n");
	return /Operation not permitted|could not install \*smartsocket\* listener|ADB server didn't ACK|failed to start daemon/i.test(text);
}


function isIpadHostPermissionBlocked(profile, collect, analyze, analysis) {
	const text = [
		collect && collect.stderr,
		collect && collect.stdout,
		analyze && analyze.stderr,
		analyze && analyze.stdout,
		JSON.stringify(profile || {}),
		JSON.stringify(analysis || {}),
	].join("\n");
	return isDefiniteIpadHostPermissionBlocked(text);
}


function isDefiniteIpadHostPermissionBlocked(text) {
	return /Operation not permitted|XPCError|connection was invalidated|Cannot create temporary directory for Instruments Analysis Core|com\.apple\.dt\.InstrumentsCLI|permission to save the file|permission denied/i.test(String(text || ""));
}


function resolveAdb() {
	const candidates = [
		args.adb,
		process.env.ADB_BIN,
		path.join(PROJECT_ROOT, ".godot/cache/c00/android-sdk/platform-tools/adb"),
		"adb",
	].filter(Boolean).map(String);
	for (const candidate of candidates) {
		if (candidate.includes("/") && fs.existsSync(candidate)) {
			return candidate;
		}
		if (!candidate.includes("/")) {
			const found = spawnSync("sh", ["-lc", `command -v ${shellQuote(candidate)}`], { encoding: "utf8" });
			if (found.status === 0 && found.stdout.trim()) {
				return found.stdout.trim();
			}
		}
	}
	return "";
}


function parseAdbDevices(text) {
	const devices = [];
	for (const line of String(text || "").split(/\r?\n/)) {
		const trimmed = line.trim();
		if (!trimmed || /^List of devices/i.test(trimmed)) {
			continue;
		}
		const columns = trimmed.split(/\s+/);
		if (columns.length < 2) {
			continue;
		}
		devices.push({
			serial: columns[0],
			state: columns[1],
			details: columns.slice(2),
		});
	}
	return devices;
}


function summarizeIpadProfile(profile) {
	const commands = profile.commands || {};
	return {
		selected_device: profile.selected_device || null,
		host: profile.host || summarizeIpadHost(commands),
		display_count: Array.isArray(profile.display_summary) ? profile.display_summary.length : 0,
		target_app_found: Boolean(profile.target_app),
		devicectl_list: commandSummary(commands.list_devices),
		xctrace_devices: commandSummary(commands.xctrace_devices),
	};
}


function buildDdiServicesAction(profile, selectedDevice) {
	const host = profile.host || summarizeIpadHost(profile.commands || {});
	const deviceVersion = selectedDevice.osVersionNumber || selectedDevice.osVersion || selectedDevice.productVersion || "";
	const xcodeVersion = host.xcode || "unknown";
	const iphoneosSdk = host.iphoneos_sdk_version || "unknown";
	let action = `Xcode reports ddiServicesAvailable=false for iPadOS ${deviceVersion || "unknown"}; host Xcode=${xcodeVersion}, iphoneos SDK=${iphoneosSdk}. Open Xcode Devices and Simulators, install/update matching iPadOS device support, then reconnect the iPad.`;
	const sdkHint = compareMajorMinor(deviceVersion, iphoneosSdk);
	if (sdkHint === "device-newer") {
		action += " The iPadOS version appears newer than the host iphoneos SDK, so install a newer Xcode/Xcode beta or update the host SDK line.";
	} else if (sdkHint === "sdk-newer") {
		action += " The host SDK line appears newer than the iPadOS version; if pairing still fails, update the iPad or reinstall device support for the exact iPadOS line.";
	}
	return action;
}


function summarizeIpadHost(commands) {
	return {
		xcode: parseXcodeVersion(commandText(commands.xcodebuild_version)),
		build: parseXcodeBuildVersion(commandText(commands.xcodebuild_version)),
		iphoneos_sdk_version: commandText(commands.iphoneos_sdk_version),
		iphonesimulator_sdk_version: commandText(commands.iphonesimulator_sdk_version),
		sdks: summarizeSdkList(commandText(commands.xcodebuild_sdks)),
	};
}


function commandText(result) {
	if (!result) {
		return "";
	}
	return [result.stdout, result.stderr, result.log].filter(Boolean).join("\n").trim();
}


function parseXcodeVersion(text) {
	const match = String(text || "").match(/Xcode\s+([^\s]+)/i);
	return match ? match[1] : "";
}


function parseXcodeBuildVersion(text) {
	const match = String(text || "").match(/Build version\s+([^\s]+)/i);
	return match ? match[1] : "";
}


function summarizeSdkList(text) {
	const output = [];
	for (const line of String(text || "").split(/\r?\n/)) {
		const match = line.match(/-sdk\s+([^\s]+)/);
		if (match) {
			output.push(match[1]);
		}
	}
	return output.slice(0, 20);
}


function compareMajorMinor(left, right) {
	const leftParts = majorMinor(left);
	const rightParts = majorMinor(right);
	if (!leftParts || !rightParts) {
		return "";
	}
	if (leftParts.major > rightParts.major || (leftParts.major === rightParts.major && leftParts.minor > rightParts.minor)) {
		return "device-newer";
	}
	if (leftParts.major < rightParts.major || (leftParts.major === rightParts.major && leftParts.minor < rightParts.minor)) {
		return "sdk-newer";
	}
	return "same-line";
}


function majorMinor(value) {
	const match = String(value || "").match(/(\d+)(?:\.(\d+))?/);
	if (!match) {
		return null;
	}
	return {
		major: Number(match[1]),
		minor: Number(match[2] || "0"),
	};
}


function commandSummary(result) {
	if (!result || typeof result !== "object") {
		return {};
	}
	return {
		ok: result.ok === true,
		status: result.status,
		stdout: truncate(result.stdout || result.log || "", 1200),
		stderr: truncate(result.stderr || "", 1200),
	};
}


function run(command, argv) {
	const result = spawnSync(command, argv, { encoding: "utf8" });
	return {
		ok: result.status === 0,
		status: result.status,
		stdout: result.stdout || "",
		stderr: result.stderr || "",
		error: result.error ? String(result.error) : "",
	};
}


function parseJsonOutput(text) {
	try {
		return JSON.parse(text);
	} catch (error) {
		return {};
	}
}


function renderMarkdown(summary) {
	const lines = [];
	lines.push("# C00 Device Readiness");
	lines.push("");
	lines.push(`Generated: ${summary.generated_at}`);
	lines.push("");
	lines.push(`Gate: \`${summary.gate}\``);
	lines.push("");
	lines.push(`Result: ${summary.pass ? "PASS" : "FAIL"}`);
	lines.push("");
	for (const result of summary.results) {
		lines.push(`## ${result.gate}`);
		lines.push("");
		lines.push(`Result: ${result.pass ? "PASS" : "FAIL"}`);
		lines.push("");
		lines.push("### Failures");
		lines.push("");
		pushList(lines, result.failures);
		lines.push("");
		lines.push("### Warnings");
		lines.push("");
		pushList(lines, result.warnings);
		lines.push("");
		lines.push("### Next Actions");
		lines.push("");
		pushList(lines, result.next_actions);
		lines.push("");
		lines.push("### Evidence");
		lines.push("");
		lines.push("```json");
		lines.push(JSON.stringify(result.evidence, null, 2));
		lines.push("```");
		lines.push("");
	}
	return lines.join("\n");
}


function pushList(lines, items) {
	if (!items || items.length === 0) {
		lines.push("- None");
		return;
	}
	for (const item of items) {
		lines.push(`- ${item}`);
	}
}


function arrayOfStrings(value) {
	return Array.isArray(value) ? value.map((item) => String(item)) : [];
}


function truncate(value, maxLength) {
	const text = String(value || "").trim();
	if (text.length <= maxLength) {
		return text;
	}
	return `${text.slice(0, maxLength)}\n... truncated ...`;
}


function shellQuote(value) {
	return `'${String(value).replace(/'/g, "'\\''")}'`;
}


function parseArgs(argv) {
	const parsed = {};
	for (let index = 0; index < argv.length; index += 1) {
		const item = argv[index];
		if (!item.startsWith("--")) {
			continue;
		}
		const key = item.slice(2);
		const next = argv[index + 1];
		if (!next || next.startsWith("--")) {
			parsed[key] = true;
		} else {
			parsed[key] = next;
			index += 1;
		}
	}
	return parsed;
}


function usage() {
	console.error([
		"Usage:",
		"  node tools/c00/check_device_ready.js --gate <rokid|ipad|android-arcore|all> [--device <ipad-name-or-uuid>] [--report <file>] [--json <file>]",
		"",
		"Checks whether device transports are ready before running C00 device gates.",
		"Rokid/Android require an ADB device in state 'device'.",
		"iPad requires devicectl/xctrace evidence that the target iPad is not offline or unavailable.",
	].join("\n"));
}
