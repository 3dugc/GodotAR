#!/usr/bin/env node

const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "../..");
const failures = [];

const checks = [
	{
		file: "tools/c00/create_device_handoff_package.sh",
		requirements: [
			"DEVICE_LAB_HANDOFF.md",
			"manifest.json",
			"artifacts/rokid/c00.apk",
			"artifacts/ipad/c00.xcodeproj",
			"artifacts/android-arcore/c00.apk",
			"wait_for_device_ready.sh --gate all",
			"run_phase1_device_lab.sh --device",
			"--no-recover-devices",
			"recover_android_adb_transport.js",
			"recover_ios_ddi_services.js",
			"not a phase-1 pass result",
			"zip -qry",
			"ditto -c -k",
			"include_latest_glob",
		],
	},
	{
		file: "tools/c00/README_CN.md",
		requirements: [
			"create_device_handoff_package.sh",
			"Device Lab Handoff",
		],
	},
	{
		file: "releases/phase_0_smoke/RUNBOOK_CN.md",
		requirements: [
			"create_device_handoff_package.sh",
			"handoff",
		],
	},
	{
		file: "specs/cycles/CYCLE_00_DEVICE_SMOKE_SPEC_CN.md",
		requirements: [
			"create_device_handoff_package.sh",
			"handoff",
		],
	},
];

for (const item of checks) {
	const text = readFile(item.file);
	if (!text) {
		failures.push(`Missing ${item.file}`);
		continue;
	}
	for (const needle of item.requirements) {
		if (!text.includes(needle)) {
			failures.push(`${item.file} must contain ${JSON.stringify(needle)}.`);
		}
	}
}

if (failures.length > 0) {
	console.error(JSON.stringify({ pass: false, failures }, null, 2));
	process.exit(1);
}

console.log(JSON.stringify({ pass: true, checked: checks.map((item) => item.file) }, null, 2));

function readFile(file) {
	try {
		return fs.readFileSync(path.join(root, file), "utf8");
	} catch (error) {
		return "";
	}
}
