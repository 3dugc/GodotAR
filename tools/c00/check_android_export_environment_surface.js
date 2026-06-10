#!/usr/bin/env node

const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "../..");
const failures = [];

const files = {
	configureShell: "tools/c00/configure_android_export_environment.sh",
	configureGd: "tools/c00/configure_android_editor_settings.gd",
	editorSettingsWriter: "tools/c00/write_godot_android_editor_settings.js",
	templateInstaller: "tools/c00/install_android_build_template.sh",
	sdkInstaller: "tools/c00/install_android_sdk_packages.sh",
	jdkInstaller: "tools/c00/install_openjdk17.sh",
	preflight: "tools/c00/preflight.sh",
	exportWrapper: "tools/c00/export_with_godot.sh",
	androidCollector: "tools/c00/collect_android_smoke.sh",
	readme: "tools/c00/README_CN.md",
};

for (const [label, file] of Object.entries(files)) {
	if (!fs.existsSync(path.join(root, file))) {
		failures.push(`Missing ${label}: ${file}`);
	}
}

if (failures.length === 0) {
	requireContains(files.configureShell, [
		"GODOT_ANDROID_SDK_PATH",
		"GODOT_JAVA_SDK_PATH",
		"GODOT_ANDROID_KEYSTORE_DEBUG_PATH",
		".godot/cache/c00/jdk/Contents/Home",
		"KEYTOOL",
		"-genkeypair",
		"write_godot_android_editor_settings.js",
		"install_android_build_template.sh",
	]);

	requireContains(files.configureGd, [
		"Godot --script cannot access EditorInterface editor settings",
		"write_godot_android_editor_settings.js",
	]);

	requireContains(files.editorSettingsWriter, [
		"editor_settings-",
		"export/android/android_sdk_path",
		"export/android/java_sdk_path",
		"export/android/debug_keystore",
		"export/android/debug_keystore_user",
		"export/android/debug_keystore_pass",
		"quoteGodotString",
	]);

	requireContains(files.templateInstaller, [
		"android_source.zip",
		"android/build",
		".build_version",
		".gdignore",
		"build.gradle",
	]);

	requireContains(files.sdkInstaller, [
		"commandlinetools-mac-13114758_latest.zip",
		"--download-cmdline-tools",
		"--cmdline-tools-zip",
		"Resuming incomplete Android command line tools download",
		".godot/cache/c00/jdk/Contents/Home",
		"platform-tools",
		"platforms;android-34",
		"build-tools;34.0.0",
		"sdkmanager",
		"--licenses",
		"run_sdkmanager_with_yes",
		"PIPESTATUS",
		"C00_CURL_MAX_TIME",
		"C00_CURL_RETRY_ALL_ERRORS",
		"C00_CURL_HTTP1",
	]);

	requireContains(files.jdkInstaller, [
		"api.adoptium.net/v3/binary/latest/17/ga/mac",
		"jdk/hotspot/normal/eclipse",
		"Resuming incomplete OpenJDK 17 download",
		".godot/cache/c00/jdk/Contents/Home",
		"GODOT_JAVA_SDK_PATH",
		"keytool",
		"C00_CURL_MAX_TIME",
		"C00_CURL_RETRY_ALL_ERRORS",
		"C00_CURL_HTTP1",
	]);

	requireContains(files.preflight, [
		"resolve_godot_binary",
		"resolve_adb_binary",
		"resolve_java_binary",
		"resolve_keytool_binary",
		".godot/cache/c00/godot-editor/Godot.app/Contents/MacOS/Godot",
		".godot/cache/c00/jdk/Contents/Home",
		"platform-tools/adb",
		"resolve_android_debug_keystore",
		"android/build/build.gradle",
		"configure_android_export_environment.sh --install-build-template",
	]);

	requireContains(files.exportWrapper, [
		"resolve_godot_binary",
		".godot/cache/c00/godot-editor/Godot.app/Contents/MacOS/Godot",
		"is_android_export",
		"GODOT_CONFIGURE_ANDROID_EXPORT",
		"configure_android_export_environment.sh",
		"--install-build-template",
		"C00_ATOMIC_EXPORT",
		"EXPORT_TMP",
		"Godot export did not create a non-empty artifact",
	]);

	requireContains(files.androidCollector, [
		"resolve_adb_binary",
		"ADB_BIN",
		".godot/cache/c00/android-sdk/platform-tools/adb",
		"--adb",
		"Using adb:",
	]);

	requireContains(files.readme, [
		"install_openjdk17.sh --download",
		"install_android_sdk_packages.sh --download-cmdline-tools --yes",
		"configure_android_export_environment.sh --install-build-template",
		"GODOT_CONFIGURE_ANDROID_EXPORT=0",
	]);
}

if (failures.length > 0) {
	console.error(JSON.stringify({ pass: false, failures }, null, 2));
	process.exit(1);
}

console.log(JSON.stringify({ pass: true, checked: Object.values(files) }, null, 2));

function requireContains(file, needles) {
	const text = fs.readFileSync(path.join(root, file), "utf8");
	for (const needle of needles) {
		if (!text.includes(needle)) {
			failures.push(`${file} must contain ${JSON.stringify(needle)}.`);
		}
	}
}
