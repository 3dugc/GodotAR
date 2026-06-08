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
			["GodotARCore addon enabled", /res:\/\/addons\/godot_arcore\/plugin\.cfg/],
		],
	},
	{
		file: "addons/godot_arcore/plugin.cfg",
		requirements: [
			["plugin name", /name="GodotARCore"/],
			["export script", /script="export_plugin\.gd"/],
		],
	},
	{
		file: "addons/godot_arcore/export_plugin.gd",
		requirements: [
			["EditorExportPlugin export hook", /extends\s+EditorExportPlugin/],
			["Android platform support", /platform\s+is\s+EditorExportPlatformAndroid/],
			["AAR library hook", /_get_android_libraries/],
			["ARCore Maven dependency hook", /_get_android_dependencies/],
			["ARCore Maven dependency", /com\.google\.ar:core:1\.33\.0/],
			["Google Maven repository", /https:\/\/dl\.google\.com\/dl\/android\/maven2\//],
			["camera permission manifest injection", /android\.permission\.CAMERA/],
			["ARCore optional manifest metadata", /android:name=\\"com\.google\.ar\.core\\"[\s\S]*android:value=\\"optional\\"/],
			["ARCore preset gating", /_is_enabled_for_preset/],
			["ARCore launch platform gating", /--xr-platform=arcore/],
		],
	},
	{
		file: "android/plugins/godot_arcore/godot-arcore/src/main/AndroidManifest.xml",
		requirements: [
			["Godot Android plugin v2 metadata", /org\.godotengine\.plugin\.v2\.GodotARCore/],
			["plugin init class", /org\.godotengine\.plugin\.android\.godotarcore\.GodotARCorePlugin/],
			["camera permission", /android\.permission\.CAMERA/],
			["ARCore optional app metadata", /android:name="com\.google\.ar\.core"[\s\S]*android:value="optional"/],
		],
	},
	{
		file: "android/plugins/godot_arcore/godot-arcore/src/main/java/org/godotengine/plugin/android/godotarcore/GodotARCorePlugin.java",
		requirements: [
			["extends GodotPlugin", /extends\s+GodotPlugin/],
			["Godot singleton name", /PLUGIN_NAME\s*=\s*"GodotARCore"/],
			["Godot exposed methods annotation", /@UsedByGodot/],
			["availability method", /check_availability\s*\(/],
			["install request method", /request_arcore_install\s*\(/],
			["session start method", /start_session\s*\(/],
			["session stop method", /stop_session\s*\(/],
			["lifecycle resume intent state", /sessionRequested/],
			["Android lifecycle pause preserves intent", /onMainPause\(\)[\s\S]*pauseSession\(\)/],
			["Android lifecycle resume restores requested session", /onMainResume\(\)[\s\S]*sessionRequested[\s\S]*resumeSession\(\)/],
			["tracking status method", /get_tracking_status\s*\(/],
			["not tracking reason method", /get_not_tracking_reason\s*\(/],
			["capability method", /get_capabilities\s*\(/],
			["ARCore runtime capability", /capabilities\.put\("runtime",\s*"ARCore"\)/],
			["native plugin capability", /capabilities\.put\("native_plugin",\s*true\)/],
			["ARCore supported capability", /capabilities\.put\("arcore_supported",\s*supported\)/],
			["ARCore availability check", /ArCoreApk\.getInstance\(\)\.checkAvailability/],
			["ARCore install request", /ArCoreApk\.getInstance\(\)\.requestInstall/],
			["ARCore session creation", /new\s+Session\(currentActivity\)/],
			["plane finding config reserved for C03", /Config\.PlaneFindingMode\.HORIZONTAL_AND_VERTICAL/],
		],
	},
	{
		file: "android/plugins/godot_arcore/build.gradle",
		requirements: [
			["Android library plugin version aligned with C00 cache", /id\s+"com\.android\.library"\s+version\s+"8\.2\.0"\s+apply\s+false/],
		],
	},
	{
		file: "android/plugins/godot_arcore/gradle.properties",
		requirements: [
			["AndroidX enabled for ARCore dependencies", /android\.useAndroidX=true/],
		],
	},
	{
		file: "android/plugins/godot_arcore/godot-arcore/build.gradle",
		requirements: [
			["Android library module", /id\s+"com\.android\.library"/],
			["C00 compile SDK", /compileSdk\s+34/],
			["minimum ARCore SDK", /minSdk\s+24/],
			["Godot Android compileOnly dependency", /compileOnly\s+"org\.godotengine:godot:\$\{godotAndroidVersion\}"/],
			["ARCore dependency", /implementation\s+"com\.google\.ar:core:\$\{arcoreVersion\}"/],
		],
	},
	{
		file: "android/plugins/godot_arcore/build_plugin.sh",
		requirements: [
			["Gradle assembleDebug", /:godot-arcore:assembleDebug/],
			["Gradle assembleRelease", /:godot-arcore:assembleRelease/],
			["copies debug AAR into addon", /addons\/godot_arcore\/bin\/debug\/GodotARCore-debug\.aar/],
			["copies release AAR into addon", /addons\/godot_arcore\/bin\/release\/GodotARCore-release\.aar/],
		],
	},
	{
		file: "tools/c00/write_export_presets_template.js",
		requirements: [
			["Android ARCore plugin enabled in starter preset", /plugins\/GodotARCore=true/],
		],
	},
	{
		file: "tools/c00/check_export_presets.js",
		requirements: [
			["Android ARCore preset requires plugin", /must enable the GodotARCore Android plugin/],
		],
	},
	{
		file: "tools/c00/check_android_apk_surface.js",
		requirements: [
			["Android ARCore launch args", /--xr-platform=arcore/],
			["Android ARCore native library requirement", /lib\/arm64-v8a\/libarcore_sdk_c\.so/],
			["OpenXR loader forbidden in Android ARCore", /Android ARCore APK should not include an OpenXR vendor loader/],
		],
	},
	{
		file: "tools/c00/run_device_cycle.sh",
		requirements: [
			["Android ARCore APK static surface check after export", /check_android_apk_surface\.js" --gate android-arcore/],
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
		"  node tools/c00/check_android_arcore_plugin_surface.js",
		"",
		"Checks the C00 GodotARCore Android plugin surface without requiring Gradle, Godot, or a connected Android device.",
	].join("\n"));
}


function readText(filePath) {
	try {
		return fs.readFileSync(filePath, "utf8");
	} catch (error) {
		return "";
	}
}
