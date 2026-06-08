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
		file: "project.godot",
		requirements: [
			["OpenXR Vendors export adapter enabled", /res:\/\/addons\/godot_openxr_vendors_export\/plugin\.cfg/],
		],
	},
	{
		file: "addons/godot_openxr_vendors_export/plugin.cfg",
		requirements: [
			["plugin name", /name="GodotOpenXRVendorsExport"/],
			["export script", /script="export_plugin\.gd"/],
		],
	},
	{
		file: "addons/godot_openxr_vendors_export/export_plugin.gd",
		requirements: [
			["EditorExportPlugin export hook", /extends\s+EditorExportPlugin/],
			["Android platform support", /platform\s+is\s+EditorExportPlatformAndroid/],
			["OpenXR Khronos vendor option", /xr_features\/openxr_vendor_khronos/],
			["single vendor warning", /Select exactly one OpenXR vendor loader per Android export preset/],
			["AAR library hook", /_get_android_libraries/],
			["Khronos AAR path", /godotopenxr-%s-%s\.aar/],
		],
	},
	{
		file: "tools/c00/write_export_presets_template.js",
		requirements: [
			["Rokid preset name", /name="C00 Rokid OpenXR"/],
			["Rokid Gradle build enabled", /gradle_build\/use_gradle_build=true/],
			["Rokid arm64 enabled", /architectures\/arm64-v8a=true/],
			["Rokid OpenXR mode", /xr_features\/xr_mode=1/],
			["Rokid Khronos vendor loader", /xr_features\/openxr_vendor_khronos=true/],
			["Rokid launch platform arg", /command_line\/extra_args="--xr-platform=rokid"/],
		],
	},
	{
		file: "tools/c00/check_export_presets.js",
		requirements: [
			["Rokid launch arg hard failure", /must set command_line\/extra_args to include --xr-platform=rokid/],
			["Rokid Gradle build hard failure", /must enable gradle_build\/use_gradle_build so Android OpenXR vendor loaders can be packaged/],
			["Rokid OpenXR mode hard failure", /must set xr_features\/xr_mode=1 for OpenXR/],
			["Rokid arm64 hard failure", /must enable architectures\/arm64-v8a for Rokid\/OpenXR devices/],
			["Rokid single OpenXR vendor hard failure", /must enable exactly one OpenXR vendor loader option/],
			["Rokid Khronos vendor hard failure", /must enable xr_features\/openxr_vendor_khronos=true/],
		],
	},
	{
		file: "tools/c00/preflight.sh",
		requirements: [
			["OpenXR Vendors plugin preflight check", /addons\/godotopenxrvendors/],
			["OpenXR Vendors plugin install guidance", /Godot OpenXR Vendors plugin/],
			["Khronos debug AAR preflight check", /godotopenxr-khronos-debug\.aar/],
			["Khronos release AAR preflight check", /godotopenxr-khronos-release\.aar/],
		],
	},
	{
		file: "tools/c00/check_android_apk_surface.js",
		requirements: [
			["Rokid launch args", /--xr-platform=rokid/],
			["OpenXR loader requirement", /lib\/arm64-v8a\/libopenxr_loader\.so/],
			["OpenXR Vendors library requirement", /lib\/arm64-v8a\/libgodotopenxrvendors\.so/],
			["ARCore forbidden in Rokid", /Rokid\/OpenXR APK should not include ARCore native libraries/],
		],
	},
	{
		file: "tools/c00/run_device_cycle.sh",
		requirements: [
			["Rokid APK static surface check after export", /check_android_apk_surface\.js" --gate rokid/],
		],
	},
	{
		file: "tools/c00/install_openxr_vendors.sh",
		requirements: [
			["GitHub latest release API", /repos\/GodotVR\/godot_openxr_vendors\/releases\/latest/],
			["release asset name", /godotopenxrvendorsaddon\.zip/],
			["canonical plugin directory", /addons\/godotopenxrvendors/],
			["locates inner addon directory", /find "\$EXTRACT_DIR" -type d -name godotopenxrvendors/],
			["force replacement switch", /--force/],
			["local zip install switch", /--zip <file>/],
		],
	},
	{
		file: "tools/c00/bootstrap_device_machine.sh",
		requirements: [
			["OpenXR Vendors readiness check", /OpenXR Vendors plugin/],
			["OpenXR Vendors canonical addon path", /addons\/godotopenxrvendors/],
			["OpenXR Vendors install command guidance", /install_openxr_vendors\.sh/],
		],
	},
	{
		file: "tools/c00/README_CN.md",
		requirements: [
			["OpenXR Vendors documented", /addons\/godotopenxrvendors/],
			["Rokid OpenXR preset requirements documented", /xr_features\/xr_mode=1/],
			["Rokid Khronos vendor documented", /xr_features\/openxr_vendor_khronos=true/],
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
		"  node tools/c00/check_rokid_openxr_export_surface.js",
		"",
		"Checks Rokid/OpenXR export prerequisites without requiring Godot, Gradle, or a connected device.",
	].join("\n"));
}


function readText(filePath) {
	try {
		return fs.readFileSync(filePath, "utf8");
	} catch (error) {
		return "";
	}
}
