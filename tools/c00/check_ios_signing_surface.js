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
		file: "tools/c00/configure_ios_signing.js",
		requirements: [
			["Team ID argument", /--team-id/],
			["check-only mode", /check-only/],
			["dry-run mode", /dry-run/],
			["C00 iPad preset", /C00 iPad ARKit/],
			["C04 iPad placement preset", /C04 iPad ARKit Place/],
			["Team ID environment aliases", /IPAD_TEAM_ID.*APPLE_TEAM_ID/s],
			["application team id update", /application\/app_store_team_id/],
			["no signing secrets policy", /does not write certificates/i],
		],
	},
	{
		file: "tools/c00/build_ios_xcode_project.sh",
		requirements: [
			["IPAD_TEAM_ID alias", /IPAD_TEAM_ID/],
			["APPLE_TEAM_ID alias", /APPLE_TEAM_ID/],
			["xcodebuild development team override", /DEVELOPMENT_TEAM=\$TEAM_ID/],
		],
	},
	{
		file: "tools/c00/run_device_cycle.sh",
		requirements: [
			["CONFIGURE_IPAD_SIGNING env", /CONFIGURE_IPAD_SIGNING/],
			["iPad Team ID resolver", /resolve_ipad_team_id/],
			["automatic signing setup step", /configure_ipad_signing_if_requested/],
			["signing helper invocation", /configure_ios_signing\.js/],
			["forced missing Team ID failure", /CONFIGURE_IPAD_SIGNING=1 requires/],
			["auto mode non-secret skip", /skipping export preset signing setup in auto mode/],
			["iPad gate before export", /configure_ipad_signing_if_requested "\$gate"[\s\S]*run_export "\$gate"/],
		],
	},
	{
		file: "tools/c00/README_CN.md",
		requirements: [
			["configure signing docs", /configure_ios_signing\.js/],
			["IPAD_TEAM_ID docs", /IPAD_TEAM_ID/],
			["run_device_cycle signing docs", /CONFIGURE_IPAD_SIGNING/],
		],
	},
	{
		file: "tools/c00/EXPORT_PRESETS_CN.md",
		requirements: [
			["configure signing export docs", /configure_ios_signing\.js/],
			["placeholder warning", /ABCDE12345/],
			["automatic signing runner docs", /run_device_cycle\.sh ipad/],
		],
	},
	{
		file: "releases/phase_0_smoke/RUNBOOK_CN.md",
		requirements: [
			["runbook signing command", /configure_ios_signing\.js/],
			["runbook Team ID env", /IPAD_TEAM_ID/],
			["runbook automatic signing mode", /CONFIGURE_IPAD_SIGNING/],
		],
	},
	{
		file: "specs/cycles/CYCLE_00_DEVICE_SMOKE_SPEC_CN.md",
		requirements: [
			["C00 signing helper requirement", /configure_ios_signing\.js/],
			["C00 no signing secrets policy", /不写证书、密码或 provisioning profile/],
			["C00 automatic runner signing requirement", /CONFIGURE_IPAD_SIGNING/],
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
		"  node tools/c00/check_ios_signing_surface.js",
		"",
		"Checks that iPad signing setup is scriptable and documented for device-machine runs.",
	].join("\n"));
}


function readText(filePath) {
	try {
		return fs.readFileSync(filePath, "utf8");
	} catch (error) {
		return "";
	}
}
