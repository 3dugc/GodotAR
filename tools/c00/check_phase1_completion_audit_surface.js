#!/usr/bin/env node

const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "../..");
const failures = [];

const files = {
	audit: "tools/c00/audit_phase1_completion.js",
	staticGates: "tools/c00/run_static_gates.js",
	readme: "tools/c00/README_CN.md",
	runbook: "releases/phase_0_smoke/RUNBOOK_CN.md",
	testReport: "releases/phase_0_smoke/TEST_REPORT.md",
};

for (const [label, file] of Object.entries(files)) {
	if (!fs.existsSync(path.join(root, file))) {
		failures.push(`Missing ${label}: ${file}`);
	}
}

if (failures.length === 0) {
	requireContains(files.audit, [
		"run_static_gates.js",
		"check_arfoundation_api_surface.js",
		"check_xri_api_surface.js",
		"check_ios_plugin_artifacts.js",
		"--require-binary",
		"check_openxr_provider_surface.js",
		"check_arcore_gate_surface.js",
		"preflight.sh",
		"verify_phase_evidence.js",
		"--include-place-demos",
		"--skip-place-demos",
		"rokid-place",
		"ipad-place",
		"NOT_READY",
		"PARTIAL",
		"includePlaceDemos",
		"phaseReady",
		"C00_COMPLETION_AUDIT.md",
	]);

	requireContains(files.staticGates, [
		"check_phase1_completion_audit_surface.js",
		"Phase 1 completion audit surface",
	]);

	requireContains(files.readme, [
		"audit_phase1_completion.js",
		"C00_COMPLETION_AUDIT.md",
	]);

	requireContains(files.runbook, [
		"audit_phase1_completion.js",
		"C00_COMPLETION_AUDIT.md",
	]);

	requireContains(files.testReport, [
		"audit_phase1_completion.js",
		"Phase 1 completion audit",
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
