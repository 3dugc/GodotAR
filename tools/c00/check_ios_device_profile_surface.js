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
		file: "tools/c00/analyze_ios_device_profile.js",
		requirements: [
			["selected iPad device failure", /No selected iPad device was found/],
			["target bundle install failure", /Target bundle was not installed/],
			["lock state failure", /iPad appears to be locked/],
			["allow missing target option", /allow-missing-target/],
		],
	},
	{
		file: "tools/c00/collect_ios_smoke.sh",
		requirements: [
			["profile analysis path", /PROFILE_ANALYSIS_PATH=/],
			["iPad profile analyzer invocation", /analyze_ios_device_profile\.js/],
			["append iPad profile analysis", /Device profile analysis:/],
		],
		order: [
			["install before profile collection", /Installing app bundle:/, /Collecting iPad device profile/],
		],
	},
	{
		file: "tools/c00/verify_phase_evidence.js",
		requirements: [
			["aggregate iPad profile analysis", /\["rokid",\s*"android-arcore",\s*"ipad"\]\.includes\(gate\)/],
			["aggregate iPad analyzer helper", /function\s+analyzeIosDeviceProfileJson\s*\(/],
			["aggregate target bundle failure", /target bundle was not installed/],
			["aggregate lock state failure", /iPad appears to be locked/],
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
		evidence.push({
			file: item.file,
			exists: false,
			passed: 0,
			total: item.requirements.length + (item.order ? item.order.length : 0),
		});
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
	for (const [label, beforePattern, afterPattern] of item.order || []) {
		const before = text.search(beforePattern);
		const after = text.search(afterPattern);
		if (before !== -1 && after !== -1 && before < after) {
			passed += 1;
		} else {
			failures.push(`${item.file}: invalid order for ${label}`);
		}
	}
	evidence.push({
		file: item.file,
		exists: true,
		passed,
		total: item.requirements.length + (item.order ? item.order.length : 0),
	});
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
		"  node tools/c00/check_ios_device_profile_surface.js",
		"",
		"Checks that the iPad C00 device profile is collected after install and analyzed for device, target bundle, display, and lock-state evidence.",
	].join("\n"));
}


function readText(filePath) {
	try {
		return fs.readFileSync(filePath, "utf8");
	} catch (error) {
		return "";
	}
}
