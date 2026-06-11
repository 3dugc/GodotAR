#!/usr/bin/env node

const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "../..");
const failures = [];

const files = {
	lab: "tools/c00/run_phase1_device_lab.sh",
	priorityLab: "tools/c00/run_phase1_priority_ar_lab.sh",
	priorityImport: "tools/c00/import_priority_ar_evidence.sh",
	exportWithGodot: "tools/c00/export_with_godot.sh",
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
		"install_godot_editor.sh",
		"install_godot_export_templates.sh",
		"install_openjdk17.sh",
		"install_android_sdk_packages.sh",
		"configure_android_export_environment.sh",
		"bootstrap_device_machine.sh",
		"run_static_gates.js",
		"run_device_cycle.sh",
		"audit_phase1_completion.js",
		"--online-deps",
		"--online-deps-list",
		"--online-deps-only",
		"RUN_ONLINE_DEPS",
		"ONLINE_DEPS",
		"online_dep_enabled",
		"editor,templates,jdk,android-sdk,android-export",
		"WAIT_FOR_DEVICES",
		"AUTO_RECOVER_DEVICES",
		"SPLIT_ALL_DEVICE_CYCLE",
		"WAIT_TIMEOUT_SECONDS",
		"WAIT_INTERVAL_SECONDS",
		"--wait-devices",
		"--recover-devices",
		"--no-recover-devices",
		"--split-all-devices",
		"--no-split-all-devices",
		"wait_for_device_ready.sh",
		"recover_android_adb_transport.js",
		"recover_ios_ddi_services.js",
		"run_device_recovery",
		"local recovery_args=(",
		"recovery_args+=(--device \"$DEVICE\")",
		"resolve_ready_ipad_device_from_json",
		"set_ready_ipad_device_from_json_if_needed",
		"device-ready-${readiness_gate}-${safe_gate}-${TIMESTAMP}.json",
		"Using auto-discovered iPad device for later gate runs",
		"gate_uses_adb_serial",
		"ADB_BIN ADB_SERIAL",
		"resolve_ready_android_serial_from_json",
		"set_ready_android_serial_from_json_if_needed",
		"Using auto-discovered ADB serial for later gate runs",
		"saved_adb_serial",
		"run_split_all_device_cycles",
		"run_cycle_group_after_readiness",
		"run_phase_verify_after_split",
		"default_device_env_file_for_gate",
		"clear_split_gate_version_env",
		"C00_SPLIT_GATE_INHERIT_VERSION_ENV",
		"device-env-latest.sh",
		"device-env-ios-stable-fallback.sh",
		"readiness_gate_for_selected_gate",
		"readiness_gate_for_gate",
		"rokid-place)",
		"ipad-place)",
		"retry wait for device readiness after recovery",
		"Skipping device cycle because device readiness did not pass.",
		"INCLUDE_PLACE_DEMOS",
		"--include-place-demos",
		"--no-place-demos",
		"--skip-place-demos",
		"write_device_env_from_current_machine",
		"Skipping invalid Godot source headers in device env",
		"Skipping Godot source headers in device env because version is",
		"godot_source_template_version",
		"DRY_RUN",
		"CONTINUE_AFTER_CYCLE",
		"source_env_if_present",
		"GODOT_EXPORT_TEMPLATES_VERSION GODOT_EXPORT_TEMPLATES_DIR GODOT_BIN",
		"NOT_READY",
		"C00_COMPLETION_AUDIT.md",
	]);

	requireContains(files.priorityLab, [
		"Phase 1 priority AR lane: iPad/ARKit + Rokid/OpenXR",
		"run_phase1_device_lab.sh",
		"INCLUDE_ANDROID_ARCORE=0",
		"--no-audit",
		"C01_PRIORITY_AR_REPORT.md",
		"--wait-devices",
		"--include-place-demos",
		"--full-audit",
		"audit_phase1_completion.js",
		"ipad-place",
		"rokid-place",
		"This is not a full Phase 1 completion audit",
	]);

	requireContains(files.priorityImport, [
		"import_device_evidence.sh",
		"verify_phase_evidence.js",
		"C01_PRIORITY_AR_REPORT.md",
		"--gate rokid",
		"--gate ipad",
		"--gate rokid-place",
		"--gate ipad-place",
		"--rokid-log",
		"--ipad-log",
		"--ipad-manual-media",
		"--allow-missing-device-profile",
		"Priority AR evidence report",
		"full Phase 1 still requires Android/ARCore",
	]);

	requireContains("tools/c00/preflight.sh", [
		"C00_DEVICE_ENV_FILE",
		"C00_AUTO_SOURCE_DEVICE_ENV",
		"source_device_env_if_present",
		"default_device_env_file_for_gate",
		"GODOT_EXPORT_TEMPLATES_VERSION GODOT_EXPORT_TEMPLATES_DIR GODOT_BIN",
	]);

	requireContains("tools/c00/bootstrap_device_machine.sh", [
		"C00_DEVICE_ENV_FILE",
		"C00_AUTO_SOURCE_DEVICE_ENV",
		"source_device_env_if_present",
		"ADB_BIN ADB_SERIAL",
	]);

	requireContains("tools/c00/run_device_cycle.sh", [
		"C00_DEVICE_ENV_FILE",
		"C00_AUTO_SOURCE_DEVICE_ENV",
		"source_device_env_if_present",
		"default_device_env_file_for_gate",
		"clear_split_gate_version_env",
		"C00_SPLIT_GATE_INHERIT_VERSION_ENV",
		"GODOT_EXPORT_TEMPLATES_VERSION GODOT_EXPORT_TEMPLATES_DIR GODOT_BIN",
		"ADB_BIN ADB_SERIAL",
		"INCLUDE_PLACE_DEMOS",
		"ios-simulator-place",
		"rokid-place",
		"ipad-place",
		"ROKID_PLACE_PRESET",
		"IPAD_PLACE_PRESET",
		"IOS_SIMULATOR_PLACE_EXPORT_PATH",
		"IOS_SIMULATOR_PLACE_APP_PATH",
		"AUTO_SELECT_READY_DEVICE",
		"auto_select_ready_device_if_needed",
		"resolve_ready_ipad_device_from_json",
		"resolve_ready_android_serial_from_json",
		"Using auto-discovered iPad device for gate run",
		"Using auto-discovered ADB serial for gate run",
		"Device readiness did not pass for",
		"build_ios_xcode_project.sh will try the project-only export fallback",
		"build_status",
		"export_with_godot_checked",
		"export_status",
	]);

	requireContains(files.exportWithGodot, [
		"rewrite_project_only_export_name",
		"hidden_short_name",
		"old_name%%.tmp-*",
		"cleanup_stale_atomic_project_only_exports",
	]);

	requireContains("tools/c00/check_ios_export_project.js", [
		"hidden temporary project path",
		"atomic temporary export path",
		"escapeRegex",
	]);

	requireContains("tools/c00/validate_smoke_log.js", [
		"GXF_ROKID_PLACE",
		"GXF_ARKIT_PLACE",
		"rokid-place",
		"ipad-place",
		"ios-simulator-place",
	]);

	requireContains("tools/c00/check_export_presets.js", [
		"C02 Rokid OpenXR Place",
		"C04 iPad ARKit Place",
		"--xr-scene=rokid_place",
		"--xr-scene=ios_arkit_place",
	]);

	requireContains("tools/c00/build_ios_xcode_project.sh", [
		"patch_simulator_project_if_needed",
		"iOS Simulator SDK does not include MetalFX.framework",
		"MetalFX.framework",
		"detect_simulator_godot_archs",
		"select_simulator_archs_for_host",
		"Godot iOS Simulator template does not include host architecture",
		"Selecting host-compatible iOS Simulator architecture",
		"IOS_SIMULATOR_ARCHS",
		"Detected Godot iOS Simulator template architectures",
	]);

	requireContains("tools/c00/collect_ios_simulator_smoke.sh", [
		"IOS_SIM_GATE",
		"IOS_SIM_XR_SCENE",
		"SIMULATOR_REQUIRED_ARCHS",
		"app_executable_path",
		"simulator_required_archs",
		"missing_simulator_arch",
		"lipo -archs",
	]);

	requireContains(files.staticGates, [
		"check_phase1_device_lab_surface.js",
		"Phase 1 device lab surface",
	]);

	requireContains(files.readme, [
		"run_phase1_device_lab.sh",
		"run_phase1_priority_ar_lab.sh",
		"import_priority_ar_evidence.sh",
		"--bundle",
		"--dry-run",
		"--wait-devices",
		"--no-recover-devices",
		"--no-split-all-devices",
		"AUTO_SELECT_READY_DEVICE=0",
		"wait_for_device_ready.sh",
	]);

	requireContains(files.runbook, [
		"run_phase1_device_lab.sh",
		"run_phase1_priority_ar_lab.sh",
		"import_priority_ar_evidence.sh",
		"completion audit",
		"--wait-devices",
		"--no-recover-devices",
		"--no-split-all-devices",
		"AUTO_SELECT_READY_DEVICE=0",
	]);

	requireContains(files.spec, [
		"run_phase1_device_lab.sh",
		"run_phase1_priority_ar_lab.sh",
		"import_priority_ar_evidence.sh",
		"设备机",
		"--wait-devices",
		"AUTO_RECOVER_DEVICES",
		"SPLIT_ALL_DEVICE_CYCLE",
		"AUTO_SELECT_READY_DEVICE=0",
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
