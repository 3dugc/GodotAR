#!/usr/bin/env node

const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "../..");
const failures = [];

const files = {
	configureShell: "tools/c00/configure_android_export_environment.sh",
	configureGd: "tools/c00/configure_android_editor_settings.gd",
	templateInstaller: "tools/c00/install_android_build_template.sh",
	sdkInstaller: "tools/c00/install_android_sdk_packages.sh",
	preflight: "tools/c00/preflight.sh",
	exportWrapper: "tools/c00/export_with_godot.sh",
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
		"keytool -genkeypair",
		"configure_android_editor_settings.gd",
		"install_android_build_template.sh",
	]);

	requireContains(files.configureGd, [
		"EditorSettings.get_singleton()",
		"export/android/android_sdk_path",
		"export/android/java_sdk_path",
		"export/android/debug_keystore",
		"export/android/debug_keystore_user",
		"export/android/debug_keystore_pass",
		"settings.save()",
	]);

	requireContains(files.templateInstaller, [
		"android_source.zip",
		"android/build",
		".build_version",
		".gdignore",
		"build.gradle",
	]);

	requireContains(files.sdkInstaller, [
		"platform-tools",
		"platforms;android-34",
		"build-tools;34.0.0",
		"sdkmanager",
		"--licenses",
	]);

	requireContains(files.preflight, [
		"resolve_android_debug_keystore",
		"android/build/build.gradle",
		"configure_android_export_environment.sh --install-build-template",
	]);

	requireContains(files.exportWrapper, [
		"is_android_export",
		"GODOT_CONFIGURE_ANDROID_EXPORT",
		"configure_android_export_environment.sh",
		"--install-build-template",
	]);

	requireContains(files.readme, [
		"install_android_sdk_packages.sh --yes",
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
