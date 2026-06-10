#!/usr/bin/env node

const fs = require("fs");
const path = require("path");

const PROJECT_ROOT = path.resolve(__dirname, "../..");

if (process.argv.includes("--help") || process.argv.includes("-h")) {
	usage();
	process.exit(0);
}

const checks = [
	{
		file: "tools/c00/collect_android_device_profile.js",
		requirements: [
			["parsed adb devices", /function parseAdbDevices/],
			["connected device evidence", /has_connected_device/],
			["no connected device warning", /No connected Android device is in adb state 'device'/],
			["host diagnostics evidence", /collectHostDiagnostics/],
			["USB Android-like evidence", /android_like_devices/],
			["project-local adb fallback", /\.godot\/cache\/c00\/android-sdk\/platform-tools\/adb/],
		],
	},
	{
		file: "tools/c00/analyze_android_device_profile.js",
		requirements: [
			["no connected device failure", /No connected Android device was available in adb state 'device'/],
			["connected devices evidence", /connected_devices/],
			["host diagnostics evidence", /host:\s*summarizeHost/],
			["USB Android-like guidance", /macOS USB sees possible Android\/XR hardware/],
		],
	},
	{
		file: "tools/c00/collect_android_smoke.sh",
		requirements: [
			["collector status accumulator", /COLLECT_STATUS=0/],
			["smoke status capture", /SMOKE_STATUS="\$\?"/],
			["evidence status capture", /EVIDENCE_STATUS="\$\?"/],
			["continues after smoke failure", /continuing to evidence\/profile report assembly/],
			["continues after media failure", /appending device diagnostics before exit/],
			["continues after no Android device", /Skipping APK install, launch, logcat, and media capture because no Android device is connected/],
			["profile appended after validators", /cat "\$PROFILE_PATH" >> "\$REPORT_PATH"/],
			["analysis appended after validators", /cat "\$PROFILE_ANALYSIS_PATH" >> "\$REPORT_PATH"/],
			["final collector exit", /exit "\$COLLECT_STATUS"/],
		],
	},
	{
		file: "tools/c00/collect_ios_smoke.sh",
		requirements: [
			["collector status accumulator", /COLLECT_STATUS=0/],
			["smoke status capture", /SMOKE_STATUS="\$\?"/],
			["evidence status capture", /EVIDENCE_STATUS="\$\?"/],
			["continues after iPad install failure", /iPad app install failed with exit \$INSTALL_STATUS; continuing to device profile and smoke diagnostics/],
			["continues after smoke failure", /continuing to evidence\/profile report assembly/],
			["continues after media failure", /appending device diagnostics before exit/],
			["profile appended after validators", /cat "\$PROFILE_PATH" >> "\$REPORT_PATH"/],
			["analysis appended after validators", /cat "\$PROFILE_ANALYSIS_PATH" >> "\$REPORT_PATH"/],
			["final collector exit", /exit "\$COLLECT_STATUS"/],
		],
	},
];

const failures = [];
const evidence = [];

for (const item of checks) {
	const absolutePath = path.join(PROJECT_ROOT, item.file);
	const text = readText(absolutePath);
	if (!text) {
		failures.push(`Missing required file: ${item.file}`);
		evidence.push({ file: item.file, exists: false, passed: 0, total: item.requirements.length });
		continue;
	}

	let passed = 0;
	for (const [label, pattern] of item.requirements) {
		if (pattern.test(text)) {
			passed += 1;
		} else {
			failures.push(`${item.file}: missing ${label}`);
		}
	}
	evidence.push({ file: item.file, exists: true, passed, total: item.requirements.length });
}

const summary = {
	pass: failures.length === 0,
	projectRoot: PROJECT_ROOT,
	failures,
	evidence,
};

console.log(JSON.stringify(summary, null, 2));
process.exit(summary.pass ? 0 : 1);


function usage() {
	console.error([
		"Usage:",
		"  node tools/c00/check_device_collector_diagnostics_surface.js",
		"",
		"Checks that C00 device collectors keep assembling media/profile diagnostics even when smoke validation fails.",
	].join("\n"));
}


function readText(filePath) {
	try {
		return fs.readFileSync(filePath, "utf8");
	} catch (error) {
		return "";
	}
}
