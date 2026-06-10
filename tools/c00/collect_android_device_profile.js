#!/usr/bin/env node

const fs = require("fs");
const path = require("path");
const { spawnSync } = require("child_process");

const PROJECT_ROOT = path.resolve(__dirname, "../..");
const args = parseArgs(process.argv.slice(2));

if (args.help || args.h) {
	usage();
	process.exit(0);
}

const gate = String(args.gate || "rokid").toLowerCase();
const packageName = String(args.package || process.env.PACKAGE || "org.godotengine.godotxrfoundation");
const reportPath = args.report ? path.resolve(String(args.report)) : "";
const jsonPath = args.json ? path.resolve(String(args.json)) : "";
const appendReportPath = args["append-report"] ? path.resolve(String(args["append-report"])) : "";
const adbBin = resolveAdb(String(args.adb || process.env.ADB_BIN || ""));
const adbSerial = String(args.serial || process.env.ADB_SERIAL || "");

if (!["rokid", "android-arcore"].includes(gate)) {
	console.error(`Unsupported Android device profile gate: ${gate}`);
	process.exit(2);
}

const profile = collectProfile();

if (jsonPath) {
	fs.mkdirSync(path.dirname(jsonPath), { recursive: true });
	fs.writeFileSync(jsonPath, `${JSON.stringify(profile, null, 2)}\n`, "utf8");
}

const markdown = renderMarkdown(profile);
if (reportPath) {
	fs.mkdirSync(path.dirname(reportPath), { recursive: true });
	fs.writeFileSync(reportPath, markdown, "utf8");
}
if (appendReportPath) {
	fs.mkdirSync(path.dirname(appendReportPath), { recursive: true });
	fs.appendFileSync(appendReportPath, `\n${markdown}`, "utf8");
}

console.log(JSON.stringify(profile, null, 2));
process.exit(profile.adb.available && profile.adb.has_connected_device ? 0 : 2);


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
		"  node tools/c00/collect_android_device_profile.js --gate <rokid|android-arcore> --package <id> [--report <file>] [--json <file>] [--append-report <file>]",
		"",
		"Options:",
		"  --adb <path>       adb executable. Default: ADB_BIN, project-local C00 adb, or PATH adb.",
		"  --serial <id>      adb device serial. Default: ADB_SERIAL.",
	].join("\n"));
}


function collectProfile() {
	const generatedAt = new Date().toISOString();
	const devices = runAdb(["devices", "-l"]);
	const connectedDevices = parseAdbDevices(devices.stdout);
	const host = collectHostDiagnostics(devices);
	const properties = collectProperties();
	const display = {
		size: runAdbShell(["wm", "size"]).stdout.trim(),
		density: runAdbShell(["wm", "density"]).stdout.trim(),
	};
	const featuresText = runAdbShell(["pm", "list", "features"]).stdout;
	const packagesText = runAdbShell(["pm", "list", "packages"]).stdout;
	const targetPackageText = runAdbShell(["dumpsys", "package", packageName]).stdout;
	const xrPackages = packagesText.split(/\r?\n/)
		.map((line) => line.replace(/^package:/, "").trim())
		.filter((line) => /openxr|rokid|pico|quest|oculus|arcore|google\.ar\.core|meta/i.test(line))
		.sort();
	const notableFeatures = featuresText.split(/\r?\n/)
		.map((line) => line.replace(/^feature:/, "").trim())
		.filter((line) => /camera|vulkan|vr|xr|ar/i.test(line))
		.sort();
	const targetPackage = parseTargetPackage(targetPackageText);
	const warnings = collectWarnings({ devices, connectedDevices, properties, display, notableFeatures, xrPackages, targetPackage });

	return {
		gate,
		package: packageName,
		generated_at: generatedAt,
		adb: {
			binary: adbBin,
			serial: adbSerial || null,
			available: devices.ok,
			version: host.adb_version,
			has_connected_device: connectedDevices.some((item) => item.state === "device"),
			connected_devices: connectedDevices,
			devices: devices.stdout.trim(),
			error: devices.ok ? "" : devices.stderr.trim(),
		},
		host,
		properties,
		display,
		notable_features: notableFeatures,
		xr_related_packages: xrPackages,
		target_package: targetPackage,
		warnings,
	};
}


function collectHostDiagnostics(devicesResult) {
	const adbVersion = runAdb(["version"]);
	return {
		adb_binary: adbBin,
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


function collectProperties() {
	const keys = [
		"ro.product.manufacturer",
		"ro.product.brand",
		"ro.product.model",
		"ro.product.device",
		"ro.product.name",
		"ro.hardware",
		"ro.build.version.release",
		"ro.build.version.sdk",
		"ro.build.version.incremental",
		"ro.build.version.security_patch",
		"ro.build.fingerprint",
	];
	const values = {};
	for (const key of keys) {
		values[key] = runAdbShell(["getprop", key]).stdout.trim();
	}
	return values;
}


function parseTargetPackage(text) {
	if (!text.trim()) {
		return {
			installed: false,
			version_name: "",
			version_code: "",
			requested_permissions: [],
		};
	}

	const versionName = matchLine(text, /\bversionName=([^\s]+)/);
	const versionCode = matchLine(text, /\bversionCode=([^\s]+)/);
	const requestedPermissions = [];
	let inRequestedPermissions = false;
	for (const line of text.split(/\r?\n/)) {
		if (line.includes("requested permissions:")) {
			inRequestedPermissions = true;
			continue;
		}
		if (inRequestedPermissions && /^\S/.test(line)) {
			inRequestedPermissions = false;
		}
		if (inRequestedPermissions) {
			const value = line.trim();
			if (value) {
				requestedPermissions.push(value);
			}
		}
	}

	return {
		installed: true,
		version_name: versionName,
		version_code: versionCode,
		requested_permissions: requestedPermissions,
	};
}


function collectWarnings(profile) {
	const warnings = [];
	if (!profile.devices.ok) {
		warnings.push(`adb devices failed: ${profile.devices.stderr.trim() || profile.devices.error || "unknown error"}`);
	}
	if (!profile.connectedDevices.some((item) => item.state === "device")) {
		warnings.push("No connected Android device is in adb state 'device'. Connect and authorize the Rokid/Android device before running the gate.");
	}
	if (!profile.properties["ro.product.model"]) {
		warnings.push("Device model is missing from getprop.");
	}
	if (!profile.targetPackage.installed) {
		warnings.push(`Target package was not found by dumpsys package: ${packageName}`);
	}
	if (gate === "rokid" && profile.xrPackages.length === 0) {
		warnings.push("No XR-related packages matched openxr/rokid/pico/quest/oculus/arcore/meta filters.");
	}
	if (gate === "android-arcore" && !profile.xrPackages.some((item) => /google\.ar\.core|arcore/i.test(item))) {
		warnings.push("No ARCore package was detected in pm list packages.");
	}
	if (!profile.notableFeatures.some((item) => /camera/i.test(item))) {
		warnings.push("No camera feature was detected in pm list features.");
	}
	if (!profile.notableFeatures.some((item) => /vulkan/i.test(item))) {
		warnings.push("No Vulkan feature was detected in pm list features.");
	}
	return warnings;
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


function matchLine(text, pattern) {
	const match = text.match(pattern);
	return match ? match[1] : "";
}


function runAdb(argsList) {
	if (!adbBin) {
		return {
			ok: false,
			stdout: "",
			stderr: "adb not found",
			status: null,
			error: "adb not found",
		};
	}
	const result = spawnSync(adbBin, withSerial(argsList), { encoding: "utf8" });
	return {
		ok: result.status === 0,
		stdout: result.stdout || "",
		stderr: result.stderr || "",
		status: result.status,
		error: result.error ? String(result.error) : "",
	};
}


function runAdbShell(shellArgs) {
	return runAdb(["shell", ...shellArgs]);
}


function withSerial(argsList) {
	if (!adbSerial) {
		return argsList;
	}
	return ["-s", adbSerial, ...argsList];
}


function resolveAdb(requested) {
	const candidates = [
		requested,
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


function renderMarkdown(profile) {
	const lines = [];
	lines.push(`# C00 Android Device Profile: ${profile.gate}`);
	lines.push("");
	lines.push(`Generated: ${profile.generated_at}`);
	lines.push("");
	lines.push(`Package: \`${profile.package}\``);
	lines.push("");
	lines.push("## ADB");
	lines.push("");
	lines.push(`- Binary: \`${profile.adb.binary}\``);
	lines.push(`- Serial: ${profile.adb.serial ? `\`${profile.adb.serial}\`` : "default"}`);
	lines.push(`- Available: ${profile.adb.available ? "yes" : "no"}`);
	lines.push(`- Connected device: ${profile.adb.has_connected_device ? "yes" : "no"}`);
	lines.push(`- Version: ${profile.adb.version || "unknown"}`);
	lines.push("");
	lines.push("## Host Diagnostics");
	lines.push("");
	lines.push("```json");
	lines.push(JSON.stringify(profile.host || {}, null, 2));
	lines.push("```");
	lines.push("");
	lines.push("```text");
	lines.push(profile.adb.devices || profile.adb.error || "");
	lines.push("```");
	lines.push("");
	lines.push("### Parsed Devices");
	lines.push("");
	lines.push("```json");
	lines.push(JSON.stringify(profile.adb.connected_devices || [], null, 2));
	lines.push("```");
	lines.push("");
	lines.push("## Device");
	lines.push("");
	lines.push("| Key | Value |");
	lines.push("| --- | --- |");
	for (const [key, value] of Object.entries(profile.properties)) {
		lines.push(`| ${escapeTable(key)} | ${escapeTable(value)} |`);
	}
	lines.push(`| wm size | ${escapeTable(profile.display.size)} |`);
	lines.push(`| wm density | ${escapeTable(profile.display.density)} |`);
	lines.push("");
	lines.push("## Target Package");
	lines.push("");
	lines.push(`- Installed: ${profile.target_package.installed ? "yes" : "no"}`);
	lines.push(`- Version name: ${profile.target_package.version_name || "unknown"}`);
	lines.push(`- Version code: ${profile.target_package.version_code || "unknown"}`);
	lines.push("");
	lines.push("### Requested Permissions");
	lines.push("");
	pushList(lines, profile.target_package.requested_permissions);
	lines.push("");
	lines.push("## XR-Related Packages");
	lines.push("");
	pushList(lines, profile.xr_related_packages);
	lines.push("");
	lines.push("## Notable Features");
	lines.push("");
	pushList(lines, profile.notable_features);
	lines.push("");
	lines.push("## Device Profile Warnings");
	lines.push("");
	pushList(lines, profile.warnings);
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


function escapeTable(value) {
	return String(value || "").replace(/\r?\n/g, " ").replace(/\|/g, "\\|");
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
