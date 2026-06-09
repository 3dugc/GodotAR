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
		file: "tools/c00/check_device_ready.js",
		requirements: [
			["ADB device state readiness", /state 'device'/],
			["iPad availability readiness", /not offline or unavailable/],
			["iPad profile analyzer", /analyze_ios_device_profile\.js/],
			["xctrace evidence summary", /xctrace_devices/],
			["Android parsed devices", /parseAdbDevices/],
		],
	},
	{
		file: "tools/c00/wait_for_device_ready.sh",
		requirements: [
			["readiness checker invocation", /check_device_ready\.js/],
			["timeout loop", /Device readiness timed out/],
			["remaining timeout sleep cap", /deadline - now/],
			["bounded readiness sleep", /sleep_seconds/],
			["optional gate runner", /--run-gate/],
			["run_device_cycle dispatch", /run_device_cycle\.sh/],
		],
	},
	{
		file: "tools/c00/README_CN.md",
		requirements: [
			["device readiness docs", /wait_for_device_ready\.sh/],
			["run-gate docs", /--run-gate/],
		],
	},
	{
		file: "releases/phase_0_smoke/RUNBOOK_CN.md",
		requirements: [
			["device readiness runbook", /wait_for_device_ready\.sh/],
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
		"  node tools/c00/check_device_ready_surface.js",
		"",
		"Checks that C00 device readiness polling is documented and guarded.",
	].join("\n"));
}


function readText(filePath) {
	try {
		return fs.readFileSync(filePath, "utf8");
	} catch (error) {
		return "";
	}
}
