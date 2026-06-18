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
			["selected iOS ARKit device failure", /No selected iOS ARKit device was found/],
			["offline iOS ARKit failure", /iOS ARKit device appears \$\{availability\}/],
			["target bundle install failure", /Target bundle was not installed/],
			["lock state failure", /iOS ARKit device appears to be locked/],
			["allow missing target option", /allow-missing-target/],
			["DDI services host toolchain action", /ddiServicesAvailable=false for iOS\/iPadOS.*host Xcode=.*iphoneos SDK=/],
			["DDI services auto-mount action", /device info ddiServices --device .*--auto-mount-ddis/],
			["nested CoreDevice property helper", /function\s+deviceProperty\s*\(/],
			["nested CoreDevice deviceProperties support", /deviceProperties/],
			["nested CoreDevice hardwareProperties support", /hardwareProperties/],
			["DDI services evidence", /ddi_services:\s*summarizeDdiServices/],
			["host toolchain evidence", /host:\s*summarizeHost/],
		],
	},
	{
		file: "tools/c00/collect_ios_device_profile.js",
		requirements: [
			["xctrace fallback device list", /xctrace_devices:\s*runXcrun\(\["xctrace",\s*"list",\s*"devices"\]\)/],
			["xcodebuild version command", /xcodebuild_version:\s*runHostTool\("xcodebuild",\s*\["-version"\]\)/],
			["iphoneos sdk command", /iphoneos_sdk_version:\s*runXcrun\(\["--sdk",\s*"iphoneos",\s*"--show-sdk-version"\]\)/],
			["DDI services no-auto-mount probe", /ddi_services:\s*runDevicectl\(\["device",\s*"info",\s*"ddiServices",\s*"--device",\s*device,\s*"--no-auto-mount-ddis"\]\)/],
			["DDI services markdown", /## DDI Services/],
			["host toolchain markdown", /## Host Toolchain/],
		],
	},
	{
		file: "tools/c00/collect_ios_smoke.sh",
		requirements: [
			["profile analysis path", /PROFILE_ANALYSIS_PATH=/],
			["install status capture", /INSTALL_STATUS="\$\?"/],
			["continue after install failure", /continuing to device profile and smoke diagnostics/],
			["iOS profile analyzer invocation", /analyze_ios_device_profile\.js/],
			["append iOS profile analysis", /Device profile analysis:/],
		],
		order: [
			["install before profile collection", /Installing app bundle:/, /Collecting iOS device profile/],
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
			["readiness DDI action", /ddiServicesAvailable=false for iOS\/iPadOS.*host Xcode=.*iphoneos SDK=/],
			["readiness DDI services summary", /ddi_services:\s*profile\.ddi_services\s*\|\|\s*commandSummary/],
			["readiness DDI auto-mount action", /device info ddiServices --device .*--auto-mount-ddis/],
			["readiness nested CoreDevice property helper", /function\s+ipadDeviceProperty\s*\(/],
			["readiness nested CoreDevice deviceProperties support", /deviceProperties/],
		],
	},
	{
		file: "tools/c00/README_CN.md",
		requirements: [
			["iPad host Xcode SDK readiness docs", /host Xcode 版本、build、`iphoneos` \/ `iphonesimulator` SDK 版本/],
			["iPad DDI services readiness docs", /DDI services/],
		],
	},
	{
		file: "releases/phase_0_smoke/RUNBOOK_CN.md",
		requirements: [
			["runbook iPad Xcode SDK readiness docs", /host Xcode 版本、build、`iphoneos` \/ `iphonesimulator` SDK 版本/],
			["runbook iPad DDI services readiness docs", /DDI services/],
		],
	},
	{
		file: "specs/cycles/CYCLE_00_DEVICE_SMOKE_SPEC_CN.md",
		requirements: [
			["spec iPad Xcode SDK readiness requirement", /iPad readiness \/ device profile 必须包含 host Xcode 版本、build、`iphoneos` \/ `iphonesimulator` SDK 版本/],
			["spec iPad DDI services readiness requirement", /DDI services/],
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
