#!/usr/bin/env node

const fs = require("fs");
const path = require("path");

const PROJECT_ROOT = path.resolve(__dirname, "../..");
const failures = [];
const evidence = [];

checkBootRoutes();
checkPlaceOnPlaneDemo();
checkBackendSwitcherDemo();
checkC01Collector();
checkC01Validator();

const summary = {
	pass: failures.length === 0,
	projectRoot: PROJECT_ROOT,
	failures,
	evidence,
};

console.log(JSON.stringify(summary, null, 2));
process.exit(summary.pass ? 0 : 1);


function checkBootRoutes() {
	const file = "demo/boot.gd";
	const text = readFile(file);
	const localEvidence = { file, exists: Boolean(text), checks: [] };
	if (!text) {
		failures.push(`Missing ${file}.`);
		evidence.push(localEvidence);
		return;
	}
	requireText(text, '"place_on_plane": "res://demo/01_place_on_plane.tscn"', `${file}: missing place_on_plane route.`, localEvidence);
	requireText(text, '"c01_place": "res://demo/01_place_on_plane.tscn"', `${file}: missing c01_place route.`, localEvidence);
	requireText(text, '"backend_switcher": "res://demo/02_backend_switcher.tscn"', `${file}: missing backend_switcher route.`, localEvidence);
	requireText(text, '"c01_backend": "res://demo/02_backend_switcher.tscn"', `${file}: missing c01_backend route.`, localEvidence);
	evidence.push(localEvidence);
}


function checkPlaceOnPlaneDemo() {
	const sceneFile = "demo/01_place_on_plane.tscn";
	const scriptFile = "demo/01_place_on_plane.gd";
	const scene = readFile(sceneFile);
	const script = readFile(scriptFile);
	const localEvidence = { file: "C01 place on plane", exists: Boolean(scene && script), checks: [] };
	if (!scene) {
		failures.push(`Missing ${sceneFile}.`);
	}
	if (!script) {
		failures.push(`Missing ${scriptFile}.`);
	}
	if (scene) {
		for (const text of [
			'[node name="PlaceOnPlane" type="Node3D"]',
			'[node name="ARSession" type="Node" parent="."]',
			'[node name="ARCameraManager" type="Node" parent="."]',
			'[node name="ARRaycastManager" type="Node" parent="."]',
			'[node name="ARPlaneManager" type="Node" parent="."]',
			'[node name="ARAnchorManager" type="Node" parent="."]',
			'[node name="XROrigin" type="Node" parent="."]',
			'[node name="PlacementCursor" type="MeshInstance3D" parent="World"]',
			'[node name="PlacedObject" type="MeshInstance3D" parent="World"]',
			'res://addons/godot_xr_foundation/scripts/arfoundation/ar_session.gd',
			'res://addons/godot_xr_foundation/scripts/arfoundation/ar_raycast_manager.gd',
			'res://addons/godot_xr_foundation/scripts/arfoundation/ar_plane_manager.gd',
			'res://addons/godot_xr_foundation/scripts/arfoundation/ar_anchor_manager.gd',
			'res://addons/godot_xr_foundation/scripts/arfoundation/xr_origin.gd',
			'requested_backend = 1',
			'platform_hint = "editor"',
		]) {
			requireText(scene, text, `${sceneFile}: missing ${text}.`, localEvidence);
		}
	}
	if (script) {
		for (const text of [
			'const CYCLE_ID := "C01"',
			'GXF_C01_PLACE',
			'ARRaycastManager',
			'ARPlaneManager',
			'ARAnchorManager',
			'XRFoundationTypes.TRACKABLE_TYPE_PLANES',
			'TryAddAnchorAsync',
			'AttachAnchor',
			'trackablesChanged',
			'center_screen_raycast',
		]) {
			requireText(script, text, `${scriptFile}: missing ${text}.`, localEvidence);
		}
	}
	evidence.push(localEvidence);
}


function checkBackendSwitcherDemo() {
	const sceneFile = "demo/02_backend_switcher.tscn";
	const scriptFile = "demo/02_backend_switcher.gd";
	const scene = readFile(sceneFile);
	const script = readFile(scriptFile);
	const localEvidence = { file: "C01 backend switcher", exists: Boolean(scene && script), checks: [] };
	if (!scene) {
		failures.push(`Missing ${sceneFile}.`);
	}
	if (!script) {
		failures.push(`Missing ${scriptFile}.`);
	}
	if (scene) {
		for (const text of [
			'[node name="BackendSwitcher" type="Node3D"]',
			'[node name="ARSession" type="Node" parent="."]',
			'[node name="ARCameraManager" type="Node" parent="."]',
			'[node name="ARRaycastManager" type="Node" parent="."]',
			'[node name="ARPlaneManager" type="Node" parent="."]',
			'[node name="ARAnchorManager" type="Node" parent="."]',
			'[node name="BackendCursor" type="MeshInstance3D" parent="World"]',
			'res://demo/02_backend_switcher.gd',
			'res://addons/godot_xr_foundation/scenes/xr_foundation_rig.tscn',
			'res://addons/godot_xr_foundation/scripts/arfoundation/ar_session.gd',
			'res://addons/godot_xr_foundation/scripts/arfoundation/ar_raycast_manager.gd',
		]) {
			requireText(scene, text, `${sceneFile}: missing ${text}.`, localEvidence);
		}
	}
	if (script) {
		for (const text of [
			'const CYCLE_ID := "C01"',
			'GXF_C01_BACKEND',
			'BACKEND_OPTIONS',
			'XRFoundationTypes.Backend.EDITOR_SIM',
			'XRFoundationTypes.Backend.OPENXR',
			'XRFoundationTypes.Backend.ARCORE',
			'XRFoundationTypes.Backend.ARKIT',
			'check_availability',
			'requested_backend',
			'Actual:',
			'fallback_to_editor_sim',
			'center_screen_raycast',
		]) {
			requireText(script, text, `${scriptFile}: missing ${text}.`, localEvidence);
		}
	}
	evidence.push(localEvidence);
}


function checkC01Collector() {
	const file = "tools/c00/collect_c01_editor_smoke.sh";
	const text = readFile(file);
	const localEvidence = { file, exists: Boolean(text), checks: [] };
	if (!text) {
		failures.push(`Missing ${file}.`);
		evidence.push(localEvidence);
		return;
	}
	for (const needle of [
		"res://demo/01_place_on_plane.tscn",
		"res://demo/02_backend_switcher.tscn",
		"--gate \"$gate\"",
		"c01-place",
		"c01-backend",
		"validate_smoke_log.js",
		"C01 EditorSim Smoke",
	]) {
		requireText(text, needle, `${file}: missing ${needle}.`, localEvidence);
	}
	evidence.push(localEvidence);
}


function checkC01Validator() {
	const file = "tools/c00/validate_smoke_log.js";
	const text = readFile(file);
	const localEvidence = { file, exists: Boolean(text), checks: [] };
	if (!text) {
		failures.push(`Missing ${file}.`);
		evidence.push(localEvidence);
		return;
	}
	for (const needle of [
		"GXF_C01_PLACE|",
		"GXF_C01_BACKEND|",
		"c01-place",
		"c01-backend",
		"validateC01PlaceEvidence",
		"validateC01BackendEvidence",
	]) {
		requireText(text, needle, `${file}: missing ${needle}.`, localEvidence);
	}
	evidence.push(localEvidence);
}


function readFile(relativePath) {
	const absolutePath = path.join(PROJECT_ROOT, relativePath);
	if (!fs.existsSync(absolutePath)) {
		return "";
	}
	return fs.readFileSync(absolutePath, "utf8");
}


function requireText(text, needle, message, localEvidence) {
	const pass = text.includes(needle);
	localEvidence.checks.push({ needle, pass });
	if (!pass) {
		failures.push(message);
	}
}
