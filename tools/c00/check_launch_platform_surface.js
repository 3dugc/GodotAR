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
		file: "addons/godot_xr_foundation/scripts/xr_foundation.gd",
		requirements: [
			["XR command-line metadata facade", /func\s+get_xr_cmdline_args\s*\(/],
			["combined command-line helper", /func\s+_all_cmdline_args\s*\(/],
			["Godot user args compatibility", /get_cmdline_user_args/],
			["XR platform arg parser", /--xr-platform=/],
			["XR backend arg parser", /--xr-backend=/],
		],
	},
	{
		file: "demo/00_device_smoke_test.gd",
		requirements: [
			["XR command-line runtime metadata", /"cmdline_xr_args"\s*:\s*_safe_cmdline_args\(\)/],
			["resolved platform runtime metadata", /"resolved_platform_hint"\s*:\s*XRFoundation\.resolve_platform_hint/],
			["project platform runtime metadata", /"project_platform_hint"\s*:\s*String\(ProjectSettings\.get_setting\("godot_xr_foundation\/platform_hint"/],
			["trackables runtime metadata", /"trackables"\s*:\s*_trackables_metadata\(\)/],
			["XRFoundation command-line facade usage", /XRFoundation\.get_xr_cmdline_args\(\)/],
		],
	},
	{
		file: "tools/c00/validate_smoke_log.js",
		requirements: [
			["smoke launch platform evidence check", /function\s+validateLaunchPlatformEvidence\s*\(/],
			["Rokid launch platform aliases", /return\s+\["rokid",\s*"openxr",\s*"androidxr",\s*"android_xr"\]/],
			["iPad launch platform aliases", /return\s+\["ipad",\s*"iphone",\s*"ios",\s*"arkit"\]/],
			["Android ARCore launch platform aliases", /return\s+\["arcore",\s*"handheld",\s*"handheld_ar",\s*"phone",\s*"mobile_ar"\]/],
			["XR platform arg parsing", /parseXrPlatformArgs/],
			["trackables evidence requirement", /Trackables metadata is missing from GXF_SMOKE evidence/],
		],
	},
	{
		file: "tools/c00/verify_phase_evidence.js",
		requirements: [
			["aggregate launch platform evidence check", /function\s+validateLaunchPlatformEvidence\s*\(/],
			["aggregate Rokid launch platform aliases", /return\s+\["rokid",\s*"openxr",\s*"androidxr",\s*"android_xr"\]/],
			["aggregate iPad launch platform aliases", /return\s+\["ipad",\s*"iphone",\s*"ios",\s*"arkit"\]/],
			["aggregate Android ARCore launch platform aliases", /return\s+\["arcore",\s*"handheld",\s*"handheld_ar",\s*"phone",\s*"mobile_ar"\]/],
			["aggregate XR platform arg parsing", /parseXrPlatformArgs/],
			["aggregate trackables evidence requirement", /Trackables metadata is missing from GXF_SMOKE evidence/],
		],
	},
	{
		file: "tools/c00/collect_android_smoke.sh",
		requirements: [
			["APK _cl_ launch args inspection", /unzip\s+-p\s+"\$apk"\s+assets\/_cl_/],
			["Rokid APK launch arg requirement", /--xr-platform=rokid/],
			["Android ARCore APK launch arg requirement", /--xr-platform=arcore/],
			["force-stop before launch", /adb\s+shell\s+am\s+force-stop\s+"\$PACKAGE"/],
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
		"  node tools/c00/check_launch_platform_surface.js",
		"",
		"Checks that C00 device evidence proves the intended XR launch path and runtime trackables metadata.",
	].join("\n"));
}


function readText(filePath) {
	try {
		return fs.readFileSync(filePath, "utf8");
	} catch (error) {
		return "";
	}
}
