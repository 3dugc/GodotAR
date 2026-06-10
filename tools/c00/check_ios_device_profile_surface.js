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
			["offline iPad failure", /iPad appears \$\{availability\}/],
			["target bundle install failure", /Target bundle was not installed/],
			["lock state failure", /iPad appears to be locked/],
			["allow missing target option", /allow-missing-target/],
			["DDI services host toolchain action", /ddiServicesAvailable=false for iPadOS.*host Xcode=.*iphoneos SDK=/],
			["host toolchain evidence", /host:\s*summarizeHost/],
		],
	},
	{
		file: "tools/c00/collect_ios_device_profile.js",
		requirements: [
			["xctrace fallback device list", /xctrace_devices:\s*runXcrun\(\["xctrace",\s*"list",\s*"devices"\]\)/],
			["xcodebuild version command", /xcodebuild_version:\s*runHostTool\("xcodebuild",\s*\["-version"\]\)/],
			["iphoneos sdk command", /iphoneos_sdk_version:\s*runXcrun\(\["--sdk",\s*"iphoneos",\s*"--show-sdk-version"\]\)/],
			["host toolchain markdown", /## Host Toolchain/],
		],
	},
	{
		file: "tools/c00/collect_ios_smoke.sh",
		requirements: [
			["profile analysis path", /PROFILE_ANALYSIS_PATH=/],
			["install status capture", /INSTALL_STATUS="\$\?"/],
			["continue after install failure", /continuing to device profile and smoke diagnostics/],
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
			["aggregate iPad profile analysis", /\["rokid",\s*"rokid-place",\s*"android-arcore",\s*"ipad",\s*"ipad-place"\]\.includes\(gate\)/],
			["aggregate iPad analyzer helper", /function\s+analyzeIosDeviceProfileJson\s*\(/],
			["aggregate iPad availability helper", /function\s+detectIosDeviceAvailability\s*\(/],
			["aggregate offline iPad failure", /iPad appears \$\{availability\}/],
			["aggregate target bundle failure", /target bundle was not installed/],
			["aggregate lock state failure", /iPad appears to be locked/],
		],
	},
	{
		file: "tools/c00/check_device_ready.js",
		requirements: [
			["readiness host summary", /host:\s*profile\.host\s*\|\|\s*summarizeIpadHost/],
			["readiness DDI action", /ddiServicesAvailable=false for iPadOS.*host Xcode=.*iphoneos SDK=/],
		],
	},
	{
		file: "tools/c00/README_CN.md",
		requirements: [
			["iPad host Xcode SDK readiness docs", /host Xcode 版本、build、`iphoneos` \/ `iphonesimulator` SDK 版本/],
		],
	},
	{
		file: "releases/phase_0_smoke/RUNBOOK_CN.md",
		requirements: [
			["runbook iPad Xcode SDK readiness docs", /host Xcode 版本、build、`iphoneos` \/ `iphonesimulator` SDK 版本/],
		],
	},
	{
		file: "specs/cycles/CYCLE_00_DEVICE_SMOKE_SPEC_CN.md",
		requirements: [
			["spec iPad Xcode SDK readiness requirement", /iPad readiness \/ device profile 必须包含 host Xcode 版本、build、`iphoneos` \/ `iphonesimulator` SDK 版本/],
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
