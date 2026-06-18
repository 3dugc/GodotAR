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
			["iOS ARKit alias gate", /"iphone"/],
			["iOS ARKit automatic discovery", /resolveIosArkitDevice/],
			["iOS ARKit device discovery", /discoverIosArkitDevices/],
			["devicectl device table parser", /parseDevicectlDeviceTable/],
			["auto-selected iOS ARKit warning", /Auto-selected iOS ARKit device/],
			["iPad profile analyzer", /analyze_ios_device_profile\.js/],
			["xctrace evidence summary", /xctrace_devices/],
			["Android parsed devices", /parseAdbDevices/],
			["readiness next actions", /next_actions/],
			["Android recovery guidance", /androidReadinessNextActions/],
			["iPad recovery guidance", /ipadReadinessNextActions/],
			["host permission blocked evidence", /host_permission_blocked/],
			["Android host permission helper", /isAndroidHostPermissionBlocked/],
			["Android host diagnostics", /collectAndroidHost/],
			["Android USB diagnostics", /android_like_devices/],
			["iPad host permission helper", /isIpadHostPermissionBlocked/],
			["definite iPad host permission helper", /isDefiniteIpadHostPermissionBlocked/],
			["iPad permission denied pattern", /permission denied/],
		],
	},
	{
		file: "tools/c00/analyze_android_device_profile.js",
		requirements: [
			["Android analyzer next actions", /next_actions/],
			["Android recovery helper", /androidNextActions/],
			["USB debugging guidance", /USB debugging/],
			["Android analyzer host permission evidence", /host_permission_blocked/],
			["Android analyzer host permission helper", /isHostPermissionBlocked/],
			["Android analyzer host evidence", /host:\s*summarizeHost/],
			["Android analyzer USB guidance", /macOS USB sees possible Android\/XR hardware/],
		],
	},
	{
		file: "tools/c00/analyze_ios_device_profile.js",
		requirements: [
			["iOS analyzer next actions", /next_actions/],
			["iOS recovery helper", /iosNextActions/],
			["Xcode pairing guidance", /Xcode Devices and Simulators/],
			["iOS analyzer host permission evidence", /host_permission_blocked/],
			["iOS analyzer host permission helper", /isHostPermissionBlocked/],
			["iOS definite host permission helper", /isDefiniteIpadHostPermissionBlocked/],
		],
	},
	{
		file: "tools/c00/wait_for_device_ready.sh",
		requirements: [
			["readiness checker invocation", /check_device_ready\.js/],
			["readiness JSON report path", /JSON_REPORT/],
			["readiness iPad device resolver", /resolve_ready_ipad_device_from_json/],
			["readiness auto-discovered iPad propagation", /Using auto-discovered iPad device for gate run/],
			["readiness Android serial resolver", /resolve_ready_android_serial_from_json/],
			["readiness auto-discovered ADB serial propagation", /Using auto-discovered ADB serial for gate run/],
			["timeout loop", /Device readiness timed out/],
			["remaining timeout sleep cap", /deadline - now/],
			["bounded readiness sleep", /sleep_seconds/],
			["optional gate runner", /--run-gate/],
			["run_device_cycle dispatch", /run_device_cycle\.sh/],
		],
	},
	{
		file: "tools/c00/recover_ios_ddi_services.js",
		requirements: [
			["optional device argument", /recover_ios_ddi_services\.js \[--device <ios-device-name-or-uuid>\]/],
			["recovery iPad automatic discovery", /resolveRecoveryDevice/],
			["recovery devicectl discovery", /discoverIosArkitDevices/],
			["recovery devicectl table parser", /parseDevicectlDeviceTable/],
			["recovery auto-selected iOS ARKit warning", /Auto-selected iOS ARKit device/],
			["recovery selection evidence", /device_selection/],
			["before readiness", /runReadiness\("before"\)/],
			["after readiness", /runReadiness\("after"\)/],
			["DDI auto-mount command", /device",\s*"info",\s*"ddiServices".*--auto-mount-ddis/s],
			["DDI evidence artifacts", /ipad-ddi-automount-\$\{stamp\}\.json/],
			["optional iPad gate", /run_device_cycle\.sh/],
			["unavailable recovery action", /could not locate the iOS device/],
		],
	},
	{
		file: "tools/c00/recover_android_adb_transport.js",
		requirements: [
			["before readiness", /runReadiness\("before"\)/],
			["after readiness", /runReadiness\("after"\)/],
			["rokid-place readiness mapping", /rokid-place"\s*\?\s*"rokid"/],
			["ADB kill server command", /kill-server/],
			["ADB start server command", /start-server/],
			["ADB devices evidence", /devices",\s*"-l"/],
			["optional device gate", /run_device_cycle\.sh/],
			["USB hardware guidance", /macOS USB sees possible Android\/XR hardware/],
			["RSA debugging guidance", /RSA prompt/],
		],
	},
	{
		file: "tools/c00/README_CN.md",
		requirements: [
			["device readiness docs", /wait_for_device_ready\.sh/],
			["iPad DDI recovery docs", /recover_ios_ddi_services\.js/],
			["Android ADB recovery docs", /recover_android_adb_transport\.js/],
			["run-gate docs", /--run-gate/],
			["next actions docs", /Next Actions/],
			["Android host diagnostics docs", /ADB 版本、Android SDK 环境、JAVA_HOME/],
		],
	},
	{
		file: "releases/phase_0_smoke/RUNBOOK_CN.md",
		requirements: [
			["device readiness runbook", /wait_for_device_ready\.sh/],
			["iPad DDI recovery runbook", /recover_ios_ddi_services\.js/],
			["Android ADB recovery runbook", /recover_android_adb_transport\.js/],
			["next actions runbook", /Next Actions/],
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
