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
		file: "addons/godot_xr_foundation/scripts/providers/native_xr_provider.gd",
		requirements: [
			["native runtime capability", /capabilities\["runtime"\]\s*=\s*String\(display_name\)/],
			["ARCore supported capability", /capabilities\["arcore_supported"\]\s*=\s*plugin_available/],
		],
	},
	{
		file: "tools/c00/validate_smoke_log.js",
		requirements: [
			["Android ARCore explicit evidence gate", /Android ARCore gate requires explicit ARCore evidence/],
			["ARCore supported capability lookup", /getCapability\(evidence,\s*"arcore_supported"\)/],
			["ARCore runtime string requirement", /capabilities\.runtime=\\"ARCore\\"/],
		],
	},
	{
		file: "tools/c00/verify_phase_evidence.js",
		requirements: [
			["Android ARCore default aggregate gate", /const\s+REQUIRED_GATES\s*=\s*\["rokid",\s*"ipad",\s*"android-arcore"\]/],
			["Android ARCore explicit aggregate evidence gate", /Android ARCore gate requires explicit ARCore evidence/],
			["ARCore aggregate supported capability lookup", /getCapability\(evidence,\s*"arcore_supported"\)/],
		],
	},
	{
		file: "tools/c00/run_device_cycle.sh",
		requirements: [
			["Android ARCore included in all mode by default", /INCLUDE_ANDROID_ARCORE="\$\{INCLUDE_ANDROID_ARCORE:-1\}"/],
			["Aggregate verifier receives Android ARCore gate", /printf\s+"%s\\n"\s+--gate\s+android-arcore/],
			["Aggregate gate override", /PHASE_GATES="\$\{PHASE_GATES:-auto\}"/],
		],
	},
	{
		file: "tools/c00/check_export_presets.js",
		requirements: [
			["Android ARCore preset requirement", /"android-arcore":\s*\{\s*name:\s*"C00 Android ARCore"/],
			["Android ARCore startup arg", /--xr-platform=arcore/],
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
		"  node tools/c00/check_arcore_gate_surface.js",
		"",
		"Checks the Android ARCore C00 evidence gate without requiring Godot or a connected Android device.",
	].join("\n"));
}


function readText(filePath) {
	try {
		return fs.readFileSync(filePath, "utf8");
	} catch (error) {
		return "";
	}
}
