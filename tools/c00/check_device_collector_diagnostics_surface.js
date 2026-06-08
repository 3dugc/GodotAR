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
		file: "tools/c00/collect_android_smoke.sh",
		requirements: [
			["collector status accumulator", /COLLECT_STATUS=0/],
			["smoke status capture", /SMOKE_STATUS="\$\?"/],
			["evidence status capture", /EVIDENCE_STATUS="\$\?"/],
			["continues after smoke failure", /continuing to evidence\/profile report assembly/],
			["continues after media failure", /appending device diagnostics before exit/],
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
