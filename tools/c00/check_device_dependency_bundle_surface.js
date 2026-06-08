#!/usr/bin/env node

const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "../..");
const failures = [];

const files = {
	importer: "tools/c00/import_device_dependency_bundle.sh",
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
		"Godot_v4.4.1-stable_export_templates.tpz",
		"ios.zip",
		"android_source.zip",
		"device-env.sh",
		"ANDROID_SDK_ROOT",
		"JAVA_HOME",
		"ADB_BIN",
		"install_android_build_template.sh",
		"configure_android_export_environment.sh",
		"tools/c00/preflight.sh rokid",
		"tools/c00/preflight.sh ipad",
	]);

	requireContains(files.readme, [
		"import_device_dependency_bundle.sh --bundle",
		"source .godot/cache/c00/device-env.sh",
		"离线依赖包",
	]);

	requireContains(files.bootstrap, [
		"import_device_dependency_bundle.sh --bundle",
		"device-env.sh",
	]);

	requireContains(files.spec, [
		"import_device_dependency_bundle.sh",
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
