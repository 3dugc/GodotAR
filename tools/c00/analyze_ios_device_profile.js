#!/usr/bin/env node

const fs = require("fs");
const path = require("path");

const args = parseArgs(process.argv.slice(2));

if (args.help || args.h) {
	usage();
	process.exit(0);
}

const profilePath = args.json ? path.resolve(String(args.json)) : "";
const reportPath = args.report ? path.resolve(String(args.report)) : "";
const allowMissingTarget = Boolean(args["allow-missing-target"]);

if (!profilePath) {
	usage();
	process.exit(2);
}

let profile = null;
try {
	profile = JSON.parse(fs.readFileSync(profilePath, "utf8"));
} catch (error) {
	const summary = {
		gate: "ipad",
		profile: profilePath,
		pass: false,
		failures: [`iOS ARKit device profile JSON is not readable or parseable: ${String(error.message || error)}`],
		warnings: [],
		evidence: {},
	};
	writeReport(summary);
	console.log(JSON.stringify(summary, null, 2));
	process.exit(1);
}

const summary = analyzeProfile(profile);
writeReport(summary);
console.log(JSON.stringify(summary, null, 2));
process.exit(summary.pass ? 0 : 1);


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
		"  node tools/c00/analyze_ios_device_profile.js --json <profile.json> [--report <file>]",
		"",
		"Options:",
		"  --allow-missing-target  Downgrade missing target bundle evidence to warning.",
	].join("\n"));
}


function analyzeProfile(profile) {
	const failures = [];
	const warnings = [];
	const selectedDevice = profile.selected_device || null;
	const targetApp = profile.target_app || null;
	const displays = Array.isArray(profile.display_summary) ? profile.display_summary : [];
	const commands = profile.commands || {};
	const lockState = detectLockState(commands.lock_state);
	const availability = detectDeviceAvailability(profile);
	const hostPermissionBlocked = isHostPermissionBlocked(profile);

	if (profile.gate && !["ipad", "ipad-place", "ios", "iphone"].includes(String(profile.gate).toLowerCase())) {
		warnings.push(`Profile was collected for gate "${profile.gate}", but analyzed as an iOS ARKit device profile.`);
	}
	if (hostPermissionBlocked) {
		failures.push("Host permission blocked iOS ARKit device profile collection; devicectl, CoreDevice, or xctrace could not access required host services from this environment.");
	}
	if (!selectedDevice && !hostPermissionBlocked) {
		failures.push(`No selected iOS ARKit device was found in devicectl output for ${profile.device || "unknown device"}.`);
	}
	if ((availability === "offline" || availability === "unavailable") && !hostPermissionBlocked) {
		failures.push(`iOS ARKit device appears ${availability}; connect, unlock, and trust the device before running the ARKit gate.`);
	}
	if (!targetApp) {
		recordMissingTarget(`Target bundle was not installed when profile was collected: ${profile.bundle_id || "unknown bundle"}.`);
	}
	if (displays.length === 0) {
		warnings.push("No iOS display summary was found in devicectl output.");
	}
	if (!commands.lock_state || commands.lock_state.ok !== true) {
		warnings.push("devicectl lockState command did not complete successfully; confirm the iPad is unlocked before launch.");
	}
	if (lockState === "locked") {
		failures.push("iOS ARKit device appears to be locked; unlock the device before running the ARKit gate.");
	}

	for (const warning of arrayOfStrings(profile.warnings)) {
		warnings.push(`collector: ${warning}`);
	}

	return {
		gate: "ipad",
		profile: profilePath,
		pass: failures.length === 0,
		failures,
		warnings,
		next_actions: iosNextActions({ profile, selectedDevice, targetApp, availability, lockState, hostPermissionBlocked }),
		evidence: {
			device: summarizeDevice(selectedDevice),
			host_permission_blocked: hostPermissionBlocked,
			device_availability: availability || "unknown",
			target_bundle_installed: Boolean(targetApp),
			target_bundle: profile.bundle_id || "",
			lock_state: lockState || "unknown",
			displays,
			ddi_services: summarizeDdiServices(profile.ddi_services || {}, commands.ddi_services),
			host: summarizeHost(profile.host || {}, profile.commands || {}),
		},
	};

	function recordMissingTarget(message) {
		if (allowMissingTarget) {
			warnings.push(message);
		} else {
			failures.push(message);
		}
	}
}


function iosNextActions(context) {
	const actions = [];
	const profile = context.profile || {};
	const selectedDevice = context.selectedDevice || {};
	const availability = String(context.availability || "").toLowerCase();

	if (context.hostPermissionBlocked) {
		actions.push("Run the iOS profile collector from a normal macOS terminal or an approved unsandboxed Codex command so devicectl, CoreDevice, and xctrace can access user caches and XPC services.");
		actions.push("After host permissions are clear, reconnect and unlock the iOS device, trust this Mac, and rerun readiness with the same --device value.");
		return actions;
	}
	if (!context.selectedDevice) {
		actions.push(`Connect and unlock the iPad/iPhone, trust this Mac, then confirm it appears in \`xcrun devicectl list devices\` as ${profile.device || "the requested device"}.`);
		return actions;
	}
	if (availability === "offline" || availability === "unavailable") {
		actions.push("Reconnect the iPad/iPhone over USB-C, unlock it, keep the screen awake, and accept any Trust This Computer prompt.");
		actions.push("Open Xcode Devices and Simulators once to let CoreDevice finish pairing and developer service setup.");
	}
	if (deviceProperty(selectedDevice, "ddiServicesAvailable") === false) {
		actions.push(buildDdiServicesAction(profile, selectedDevice));
	}
	const developerModeStatus = deviceProperty(selectedDevice, "developerModeStatus");
	if (developerModeStatus && String(developerModeStatus).toLowerCase() !== "enabled") {
		actions.push("Enable Developer Mode on the iOS device and reboot when prompted.");
	}
	if (context.lockState === "locked") {
		actions.push("Unlock the iOS device before running the ARKit gate.");
	}
	if (!context.targetApp) {
		actions.push("The target app is not installed yet; this is okay before the gate, but the iPad must become available so the runner can install the .app.");
	}
	if (actions.length === 0) {
		actions.push("If the iPad gate still fails, inspect the raw devicectl/xctrace command evidence in the profile JSON.");
	}
	return actions;
}


function buildDdiServicesAction(profile, selectedDevice) {
	const host = summarizeHost(profile.host || {}, profile.commands || {});
	const deviceVersion = deviceProperty(selectedDevice, "osVersionNumber") || deviceProperty(selectedDevice, "osVersion") || deviceProperty(selectedDevice, "productVersion") || "";
	const xcodeVersion = host.xcode || "unknown";
	const iphoneosSdk = host.iphoneos_sdk_version || "unknown";
	const sdkHint = compareMajorMinor(deviceVersion, iphoneosSdk);
	const deviceArg = shellQuote(profile.device || deviceProperty(selectedDevice, "identifier") || deviceProperty(selectedDevice, "name") || "iOS device");
	let action = `Xcode reports ddiServicesAvailable=false for iOS/iPadOS ${deviceVersion || "unknown"}; host Xcode=${xcodeVersion}, iphoneos SDK=${iphoneosSdk}. Open Xcode Devices and Simulators, install/update matching iOS device support, then reconnect the device. To force CoreDevice to mount/update DDI from terminal, run \`xcrun devicectl device info ddiServices --device ${deviceArg} --auto-mount-ddis\` after the device is unlocked and trusted.`;
	if (sdkHint === "device-newer") {
		action += " The device OS version appears newer than the host iphoneos SDK, so install a newer Xcode/Xcode beta or update the host SDK line.";
	} else if (sdkHint === "sdk-newer") {
		action += " The host SDK line appears newer than the device OS version; if pairing still fails, update the device or reinstall device support for the exact OS line.";
	}
	return action;
}


function summarizeDdiServices(summary, commandResult) {
	return {
		ok: summary.ok === true || (commandResult && commandResult.ok === true),
		status: summary.status !== undefined ? summary.status : (commandResult ? commandResult.status : null),
		service_count: Number(summary.service_count || 0),
		services: Array.isArray(summary.services) ? summary.services : [],
		message: summary.message || (commandResult ? commandText(commandResult) : ""),
	};
}


function summarizeHost(host, commands) {
	const output = {
		xcode: host.xcode || parseXcodeVersion(commandText(commands.xcodebuild_version)),
		build: host.build || parseXcodeBuildVersion(commandText(commands.xcodebuild_version)),
		iphoneos_sdk_version: host.iphoneos_sdk_version || commandText(commands.iphoneos_sdk_version),
		iphonesimulator_sdk_version: host.iphonesimulator_sdk_version || commandText(commands.iphonesimulator_sdk_version),
		sdks: Array.isArray(host.sdks) ? host.sdks : summarizeSdkList(commandText(commands.xcodebuild_sdks)),
	};
	return output;
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


function isHostPermissionBlocked(profile) {
	const text = [
		JSON.stringify(profile.commands || {}),
		JSON.stringify(profile.warnings || []),
	].join("\n");
	return isDefiniteIpadHostPermissionBlocked(text);
}


function isDefiniteIpadHostPermissionBlocked(text) {
	return /Operation not permitted|XPCError|connection was invalidated|Cannot create temporary directory for Instruments Analysis Core|com\.apple\.dt\.InstrumentsCLI|permission to save the file|permission denied/i.test(String(text || ""));
}


function detectDeviceAvailability(profile) {
	const commands = profile.commands || {};
	const selectedDevice = profile.selected_device || {};
	const targetLines = matchingDeviceLines(profile);
	const text = [
		JSON.stringify(selectedDevice),
		targetLines.join("\n"),
	].join("\n").toLowerCase();

	if (/\bunavailable\b/.test(text)) {
		return "unavailable";
	}
	if (/\boffline\b/.test(text)) {
		return "offline";
	}
	if (/\b(available|online|connected|paired)\b/.test(text)) {
		return "available";
	}
	return "";
}


function matchingDeviceLines(profile) {
	const commands = profile.commands || {};
	const tokens = [
		profile.device,
		deviceProperty(profile.selected_device, "name"),
		deviceProperty(profile.selected_device, "identifier"),
		deviceProperty(profile.selected_device, "udid"),
		deviceProperty(profile.selected_device, "serialNumber"),
		deviceProperty(profile.selected_device, "serial_number"),
	].map(normalizeToken).filter(Boolean);
	const texts = [
		commands.list_devices ? `${commands.list_devices.stdout || ""}\n${commands.list_devices.stderr || ""}\n${commands.list_devices.log || ""}` : "",
		commands.xctrace_devices ? `${commands.xctrace_devices.stdout || ""}\n${commands.xctrace_devices.stderr || ""}` : "",
	];
	if (tokens.length === 0) {
		return [];
	}
	return texts.flatMap((text) => String(text || "").split(/\r?\n/))
		.filter((line) => tokens.some((token) => normalizeToken(line).includes(token)));
}


function normalizeToken(value) {
	return String(value || "").trim().toLowerCase();
}


function detectLockState(commandResult) {
	if (!commandResult || typeof commandResult !== "object") {
		return "";
	}
	const text = [
		JSON.stringify(commandResult.json || {}),
		commandResult.stdout || "",
		commandResult.stderr || "",
		commandResult.log || "",
	].join("\n").toLowerCase();
	if (/"?(islocked|locked)"?\s*:\s*false/.test(text)) {
		return "unlocked";
	}
	if (/"?(islocked|locked)"?\s*:\s*true/.test(text)) {
		return "locked";
	}
	if (/\bunlocked\b|\bunlockedstate\b|\bpasscodeunlocked\b/.test(text)) {
		return "unlocked";
	}
	if (/\blocked\b|\bdevice.?locked\b|\bpasscode.?locked\b/.test(text)) {
		return "locked";
	}
	return "";
}


function summarizeDevice(device) {
	if (!device || typeof device !== "object") {
		return "unknown";
	}
	return [
		deviceProperty(device, "name"),
		deviceProperty(device, "identifier"),
		deviceProperty(device, "udid"),
		deviceProperty(device, "serialNumber"),
		deviceProperty(device, "serial_number"),
		deviceProperty(device, "model") || deviceProperty(device, "marketingName") || deviceProperty(device, "productType"),
	].filter(Boolean).join(" / ") || "unknown";
}


function deviceProperty(device, key) {
	if (!device || typeof device !== "object") {
		return "";
	}
	if (device[key] !== undefined && device[key] !== null && device[key] !== "") {
		return device[key];
	}
	for (const groupKey of ["deviceProperties", "hardwareProperties", "connectionProperties"]) {
		const group = device[groupKey];
		if (group && typeof group === "object" && group[key] !== undefined && group[key] !== null && group[key] !== "") {
			return group[key];
		}
	}
	return "";
}


function shellQuote(value) {
	return `'${String(value).replace(/'/g, "'\\''")}'`;
}


function arrayOfStrings(value) {
	return Array.isArray(value) ? value.map((item) => String(item)) : [];
}


function writeReport(summary) {
	if (!reportPath) {
		return;
	}
	fs.mkdirSync(path.dirname(reportPath), { recursive: true });
	fs.writeFileSync(reportPath, renderMarkdown(summary), "utf8");
}


function renderMarkdown(summary) {
	const lines = [];
	lines.push("# C00 iPad Device Profile Analysis");
	lines.push("");
	lines.push(`Result: ${summary.pass ? "PASS" : "FAIL"}`);
	lines.push("");
	lines.push(`Profile JSON: \`${summary.profile}\``);
	lines.push("");
	lines.push("## Failures");
	lines.push("");
	pushList(lines, summary.failures);
	lines.push("");
	lines.push("## Warnings");
	lines.push("");
	pushList(lines, summary.warnings);
	lines.push("");
	lines.push("## Next Actions");
	lines.push("");
	pushList(lines, summary.next_actions);
	lines.push("");
	lines.push("## Evidence");
	lines.push("");
	lines.push("```json");
	lines.push(JSON.stringify(summary.evidence, null, 2));
	lines.push("```");
	lines.push("");
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
