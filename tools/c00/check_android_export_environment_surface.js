#!/usr/bin/env node

const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "../..");
const failures = [];

const files = {
	configureShell: "tools/c00/configure_android_export_environment.sh",
	configureGd: "tools/c00/configure_android_editor_settings.gd",
	editorSettingsWriter: "tools/c00/write_godot_android_editor_settings.js",
	exportCredentialsWriter: "tools/c00/write_godot_export_credentials.js",
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
		"godot_android_compile_sdk_from_template_version",
		"godot_android_build_tools_from_template_version",
		"godot_android_ndk_from_template_version",
		"KEYTOOL",
		"-genkeypair",
		"write_godot_android_editor_settings.js",
		"write_godot_export_credentials.js",
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

	requireContains(files.exportCredentialsWriter, [
		".godot",
		"export_credentials.cfg",
		"keystore/debug",
		"keystore/debug_user",
		"keystore/debug_password",
		"parseAndroidPresetSections",
	]);

	requireContains(files.templateInstaller, [
		"android_source.zip",
		"android/build",
		".build_version",
		".gdignore",
		"build.gradle",
		"apply_c00_maven_mirrors",
		"maven.aliyun.com/repository/google",
		"clean_c00_android_launcher_icon_resources",
		"apply_c00_launcher_icon_gradle_cleanup",
		"c00CleanDuplicateLauncherWebp",
		"merge\") && task.name.endsWith(\"Resources",
		"icon_foreground.webp",
	]);

	requireContains(files.sdkInstaller, [
		"godot_version_defaults.sh",
		"commandlinetools-mac-13114758_latest.zip",
		"--download-cmdline-tools",
		"--cmdline-tools-zip",
		"Resuming incomplete Android command line tools download",
		".godot/cache/c00/jdk/Contents/Home",
		"platform-tools",
		"platforms;android-$compile_sdk",
		"build-tools;$build_tools",
		"ndk;$ndk_version",
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
		"resolve_android_compile_sdk",
		"resolve_gradle_distribution",
		"C00_REQUIRE_ANDROID_GRADLE_CACHE",
		"Android Gradle plugin",
		"Kotlin Android plugin",
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
		"C00_GODOT_VERBOSE",
		"C00_ATOMIC_EXPORT",
		"EXPORT_TMP",
		"C00_GODOT_EXPORT_TIMEOUT_SECONDS",
		"Godot export timed out after",
		"The export watchdog timed out",
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
