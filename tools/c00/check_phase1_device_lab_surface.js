#!/usr/bin/env node

const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "../..");
const failures = [];

const files = {
	lab: "tools/c00/run_phase1_device_lab.sh",
	staticGates: "tools/c00/run_static_gates.js",
	readme: "tools/c00/README_CN.md",
	runbook: "releases/phase_0_smoke/RUNBOOK_CN.md",
	spec: "specs/cycles/CYCLE_00_DEVICE_SMOKE_SPEC_CN.md",
};

for (const [label, file] of Object.entries(files)) {
	if (!fs.existsSync(path.join(root, file))) {
		failures.push(`Missing ${label}: ${file}`);
	}
}

if (failures.length === 0) {
	requireContains(files.lab, [
		"import_device_dependency_bundle.sh",
		"install_godot_export_templates.sh",
		"install_openjdk17.sh",
		"install_android_sdk_packages.sh",
		"configure_android_export_environment.sh",
		"bootstrap_device_machine.sh",
		"run_static_gates.js",
		"run_device_cycle.sh",
		"audit_phase1_completion.js",
		"--online-deps",
		"RUN_ONLINE_DEPS",
		"write_device_env_from_current_machine",
		"DRY_RUN",
		"CONTINUE_AFTER_CYCLE",
		"source_env_if_present",
		"NOT_READY",
		"C00_COMPLETION_AUDIT.md",
	]);

	requireContains("tools/c00/preflight.sh", [
		"C00_DEVICE_ENV_FILE",
		"C00_AUTO_SOURCE_DEVICE_ENV",
		"source_device_env_if_present",
	]);

	requireContains("tools/c00/bootstrap_device_machine.sh", [
		"C00_DEVICE_ENV_FILE",
		"C00_AUTO_SOURCE_DEVICE_ENV",
		"source_device_env_if_present",
	]);

	requireContains("tools/c00/run_device_cycle.sh", [
		"C00_DEVICE_ENV_FILE",
		"C00_AUTO_SOURCE_DEVICE_ENV",
		"source_device_env_if_present",
	]);

	requireContains(files.staticGates, [
		"check_phase1_device_lab_surface.js",
		"Phase 1 device lab surface",
	]);

	requireContains(files.readme, [
		"run_phase1_device_lab.sh",
		"--bundle",
		"--dry-run",
	]);

	requireContains(files.runbook, [
		"run_phase1_device_lab.sh",
		"completion audit",
	]);

	requireContains(files.spec, [
		"run_phase1_device_lab.sh",
		"设备机",
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
