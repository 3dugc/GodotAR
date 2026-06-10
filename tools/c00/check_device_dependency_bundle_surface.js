#!/usr/bin/env node

const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "../..");
const failures = [];

const files = {
	importer: "tools/c00/import_device_dependency_bundle.sh",
	editorInstaller: "tools/c00/install_godot_editor.sh",
	templateInstaller: "tools/c00/install_godot_export_templates.sh",
	rangeDownloader: "tools/c00/download_http_ranges.js",
	versionDefaults: "tools/c00/godot_version_defaults.sh",
	jdkInstaller: "tools/c00/install_openjdk17.sh",
	sdkInstaller: "tools/c00/install_android_sdk_packages.sh",
	readme: "tools/c00/README_CN.md",
	bootstrap: "tools/c00/bootstrap_device_machine.sh",
	spec: "specs/cycles/CYCLE_00_DEVICE_SMOKE_SPEC_CN.md",
};

for (const [label, file] of Object.entries(files)) {
	if (!fs.existsSync(path.join(root, file))) {
		failures.push(`Missing ${label}: ${file}`);
	}
}

if (failures.length === 0) {
	requireContains(files.importer, [
		"Godot_v4.7-rc1_macos.universal.zip",
		"install_godot_editor.sh",
		"Godot editor import",
		"Godot_v4.7-rc1_export_templates.tpz",
		"Godot_v4.6.3-stable_export_templates.tpz",
		"legacy Godot_v4.4.1-stable_export_templates.tpz",
		"ios.zip",
		"android_source.zip",
		"device-env.sh",
		"ANDROID_SDK_ROOT",
		"JAVA_HOME",
		"ADB_BIN",
		"godot_source_template_version",
		"expected $VERSION",
		"install_android_build_template.sh",
		"configure_android_export_environment.sh",
		"tools/c00/preflight.sh rokid",
		"tools/c00/preflight.sh ipad",
	]);

	requireContains(files.editorInstaller, [
		"godot_version_defaults.sh",
		"--latest",
		"--latest-stable",
		"macos.universal.zip",
		"GODOT_EDITOR_URL",
		"GODOT_EDITOR_URLS",
		"godot_github_macos_editor_url_from_template_version",
		"Resuming incomplete Godot editor download",
		"Godot editor installed for",
		"godot_binary_version",
		"C00_CURL_MAX_TIME",
		"C00_CURL_RETRY_ALL_ERRORS",
		"C00_CURL_HTTP1",
	]);

	requireContains(files.templateInstaller, [
		"godot_version_defaults.sh",
		"--latest",
		"--latest-stable",
		"4.7.rc1",
		"--download",
		"GODOT_EXPORT_TEMPLATES_URL",
		"GODOT_EXPORT_TEMPLATES_URLS",
		"Godot_v%s_export_templates.tpz",
		"Resuming incomplete Godot export templates download",
		"C00_CURL_RETRY",
		"C00_CURL_MAX_TIME",
		"C00_CURL_RETRY_ALL_ERRORS",
		"C00_CURL_HTTP1",
		"C00_PARALLEL_DOWNLOAD",
		"download_http_ranges.js",
		"--speed-limit",
	]);

	requireContains(files.rangeDownloader, [
		"Range download:",
		"--range",
		"C00_PARALLEL_DOWNLOAD_PARTS",
		"content-length",
		"accept-ranges",
	]);

	requireContains(files.jdkInstaller, [
		"--download",
		"--urls",
		"api.adoptium.net/v3/binary/latest/17/ga/mac",
		"Resuming incomplete OpenJDK 17 download",
		".godot/cache/c00/jdk/Contents/Home",
		"C00_CURL_RETRY",
		"C00_CURL_MAX_TIME",
		"C00_CURL_RETRY_ALL_ERRORS",
		"C00_CURL_HTTP1",
		"--speed-limit",
	]);

	requireContains(files.sdkInstaller, [
		"--download-cmdline-tools",
		"--cmdline-tools-urls",
		"commandlinetools-mac-13114758_latest.zip",
		"Resuming incomplete Android command line tools download",
		"cmdline-tools/latest/bin/sdkmanager",
		"run_sdkmanager_with_yes",
		"PIPESTATUS",
		"C00_CURL_RETRY",
		"C00_CURL_MAX_TIME",
		"C00_CURL_RETRY_ALL_ERRORS",
		"C00_CURL_HTTP1",
		"--speed-limit",
	]);

	requireContains(files.readme, [
		"import_device_dependency_bundle.sh --bundle",
		"source .godot/cache/c00/device-env.sh",
		"install_godot_editor.sh --download",
		"install_openjdk17.sh --download",
		"install_godot_export_templates.sh --download",
		"离线依赖包",
	]);

	requireContains(files.bootstrap, [
		"import_device_dependency_bundle.sh --bundle",
		"install_godot_editor.sh --download",
		"install_openjdk17.sh --download",
		"device-env.sh",
		"## Download Cache",
		"Godot_v${C00_GODOT_LATEST_TAG}_macos.universal.zip",
		"Godot_v${C00_GODOT_LATEST_TAG}_export_templates.tpz",
		"commandlinetools-mac-13114758_latest.zip",
		"temurin17-mac-aarch64.tar.gz",
	]);

	requireContains(files.versionDefaults, [
		"C00_GODOT_LATEST_TAG",
		"4.7-rc1",
		"C00_GODOT_STABLE_TAG",
		"4.6.3-stable",
		"downloads.godotengine.org",
		"godot_normalize_template_version",
		"godot_tag_from_template_version",
		"godot_source_template_version",
		"godot_source_matches_template_version",
		"godot_official_macos_editor_url_from_template_version",
		"godot_github_macos_editor_url_from_template_version",
		"godot_official_download_url_from_template_version",
	]);

	requireContains(files.spec, [
		"import_device_dependency_bundle.sh",
		"install_godot_editor.sh --download",
		"install_openjdk17.sh --download",
		"install_godot_export_templates.sh --download",
		"离线依赖包",
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
