#!/usr/bin/env node

const fs = require("fs");
const path = require("path");

const PROJECT_ROOT = path.resolve(__dirname, "../..");
const MAIN_SCENE = "res://demo/boot.tscn";
const DEFAULT_BOOT_SCENE = "res://demo/00_device_smoke_test.tscn";

if (process.argv.includes("--help") || process.argv.includes("-h")) {
	usage();
	process.exit(0);
}

const failures = [];
const warnings = [];
const evidence = [];

checkProjectSettings();
checkAddon();
checkBootRouterSurface();
checkStartupHintSurface();
checkScene("demo/boot.tscn", {
	requiredNodes: [
		"Boot",
	],
	requiredExtResourcePaths: [
		"res://demo/boot.gd",
	],
	requiredNodePaths: [],
});
checkScene("demo/00_device_smoke_test.tscn", {
	requiredNodes: [
		"DeviceSmokeTest",
		"DeviceSmokeTest/ARSession",
		"DeviceSmokeTest/ARCameraManager",
		"DeviceSmokeTest/XRFoundationRig",
		"DeviceSmokeTest/XRFoundationRig/XRCamera3D/XRRayInteractor",
		"DeviceSmokeTest/ARRaycastManager",
		"DeviceSmokeTest/ARPlaneManager",
		"DeviceSmokeTest/ARAnchorManager",
		"DeviceSmokeTest/XRInteractionManager",
		"DeviceSmokeTest/World/XRGrabInteractable",
		"DeviceSmokeTest/World/XRGrabInteractable/Body/CollisionShape3D",
	],
	requiredExtResourcePaths: [
		"res://demo/00_device_smoke_test.gd",
		"res://addons/godot_xr_foundation/scenes/xr_foundation_rig.tscn",
		"res://addons/godot_xr_foundation/scripts/arfoundation/ar_session.gd",
		"res://addons/godot_xr_foundation/scripts/arfoundation/ar_camera_manager.gd",
		"res://addons/godot_xr_foundation/scripts/arfoundation/ar_raycast_manager.gd",
		"res://addons/godot_xr_foundation/scripts/arfoundation/ar_plane_manager.gd",
		"res://addons/godot_xr_foundation/scripts/arfoundation/ar_anchor_manager.gd",
		"res://addons/godot_xr_foundation/scripts/xri/xr_interaction_manager.gd",
		"res://addons/godot_xr_foundation/scripts/xri/xr_ray_interactor.gd",
		"res://addons/godot_xr_foundation/scripts/xri/xr_grab_interactable.gd",
	],
	requiredNodePaths: [
		{ node: "DeviceSmokeTest/ARPlaneManager", property: "xr_origin_path", target: "DeviceSmokeTest/XRFoundationRig" },
		{ node: "DeviceSmokeTest/ARAnchorManager", property: "anchors_parent_path", target: "DeviceSmokeTest/XRFoundationRig" },
		{ node: "DeviceSmokeTest/ARCameraManager", property: "camera_path", target: "DeviceSmokeTest/XRFoundationRig/XRCamera3D" },
		{ node: "DeviceSmokeTest/XRFoundationRig/XRCamera3D/XRRayInteractor", property: "interaction_manager_path", target: "DeviceSmokeTest/XRInteractionManager" },
		{ node: "DeviceSmokeTest/World/XRGrabInteractable", property: "interaction_manager_path", target: "DeviceSmokeTest/XRInteractionManager" },
	],
});
checkScene("addons/godot_xr_foundation/scenes/xr_foundation_rig.tscn", {
	requiredNodes: [
		"XRFoundationRig",
		"XRFoundationRig/XRCamera3D",
		"XRFoundationRig/LeftHand",
		"XRFoundationRig/RightHand",
	],
	requiredExtResourcePaths: [
		"res://addons/godot_xr_foundation/scripts/xr_device_rig.gd",
	],
	requiredNodePaths: [],
});

const summary = {
	pass: failures.length === 0,
	projectRoot: PROJECT_ROOT,
	failures,
	warnings,
	evidence,
};

console.log(JSON.stringify(summary, null, 2));
process.exit(summary.pass ? 0 : 1);


function usage() {
	console.error([
		"Usage:",
		"  node tools/c00/check_godot_project_static.js",
		"",
		"Checks C00 Godot project settings, scene resource references, and critical NodePaths without requiring a Godot binary.",
	].join("\n"));
}


function checkProjectSettings() {
	const file = "project.godot";
	const text = readProjectFile(file);
	const localEvidence = { file, exists: Boolean(text), checks: [] };
	if (!text) {
		failures.push("Missing project.godot.");
		evidence.push(localEvidence);
		return;
	}

	requireText(text, 'run/main_scene="res://demo/boot.tscn"', `${file}: main_scene must be ${MAIN_SCENE}.`, localEvidence);
	requireText(text, 'config/icon="res://assets/app_icon.svg"', `${file}: C00 app icon should be set for iOS export.`, localEvidence);
	requireText(text, 'XRFoundation="*res://addons/godot_xr_foundation/scripts/xr_foundation.gd"', `${file}: XRFoundation autoload is missing.`, localEvidence);
	requireText(text, "res://addons/godot_xr_foundation/plugin.cfg", `${file}: XR Foundation addon plugin should be enabled.`, localEvidence);
	requireText(text, "res://addons/godot_arcore/plugin.cfg", `${file}: GodotARCore export addon plugin should be enabled.`, localEvidence);
	requireText(text, "res://addons/godot_openxr_vendors_export/plugin.cfg", `${file}: OpenXR Vendors export adapter plugin should be enabled.`, localEvidence);
	requireText(text, "limits/message_queue/max_size_mb=512", `${file}: C00 should raise message_queue max_size_mb for Godot 4.7 headless export and XR smoke scenes.`, localEvidence);
	requireText(text, "textures/vram_compression/import_etc2_astc=true", `${file}: ETC2/ASTC import must be enabled for Android/iOS mobile export.`, localEvidence);
	requireText(text, "openxr/enabled=true", `${file}: OpenXR should be enabled for Rokid/OpenXR C00.`, localEvidence);
	requireText(text, "shaders/enabled=true", `${file}: XR shaders should be enabled.`, localEvidence);

	for (const resPath of [
		"res://demo/boot.tscn",
		"res://demo/00_device_smoke_test.tscn",
		"res://assets/app_icon.svg",
		"res://addons/godot_xr_foundation/scripts/xr_foundation.gd",
		"res://addons/godot_xr_foundation/plugin.cfg",
		"res://addons/godot_arcore/plugin.cfg",
		"res://addons/godot_openxr_vendors_export/plugin.cfg",
	]) {
		checkResPathExists(resPath, localEvidence);
	}
	evidence.push(localEvidence);
}


function checkAddon() {
	const file = "addons/godot_xr_foundation/plugin.cfg";
	const text = readProjectFile(file);
	const localEvidence = { file, exists: Boolean(text), checks: [] };
	if (!text) {
		failures.push(`Missing ${file}.`);
		evidence.push(localEvidence);
		return;
	}
	const hasPluginScript = text.includes('script="godot_xr_foundation.gd"') ||
		text.includes('script="res://addons/godot_xr_foundation/godot_xr_foundation.gd"');
	addCheck(localEvidence, "plugin script", hasPluginScript, `${file}: plugin script reference is missing.`);
	checkResPathExists("res://addons/godot_xr_foundation/godot_xr_foundation.gd", localEvidence);
	evidence.push(localEvidence);
}


function checkBootRouterSurface() {
	const file = "demo/boot.gd";
	const text = readProjectFile(file);
	const localEvidence = { file, exists: Boolean(text), checks: [] };
	if (!text) {
		failures.push(`Missing ${file}.`);
		evidence.push(localEvidence);
		return;
	}
	requireText(text, `const DEFAULT_SCENE := "${DEFAULT_BOOT_SCENE}"`, `${file}: boot router must default to ${DEFAULT_BOOT_SCENE}.`, localEvidence);
	requireText(text, '"rokid_place": "res://demo/04_rokid_ray_place.tscn"', `${file}: missing rokid_place scene route.`, localEvidence);
	requireText(text, '"ios_arkit_place": "res://demo/06_ios_arkit_place.tscn"', `${file}: missing ios_arkit_place scene route.`, localEvidence);
	requireText(text, '"openxr_lab": "res://demo/03_openxr_ar_capability_lab.tscn"', `${file}: missing OpenXR capability lab route.`, localEvidence);
	requireText(text, "--xr-scene=", `${file}: boot router must read --xr-scene= for device demo selection.`, localEvidence);
	requireText(text, "--xr-demo=", `${file}: boot router must keep --xr-demo= compatibility.`, localEvidence);
	requireText(text, "OS.get_cmdline_args()", `${file}: boot router should read Godot command line args.`, localEvidence);
	requireText(text, "get_cmdline_user_args", `${file}: boot router should read exported app user args.`, localEvidence);
	requireText(text, "GXF_BOOT", `${file}: boot router must print GXF_BOOT evidence.`, localEvidence);
	for (const resPath of [
		"res://demo/boot.tscn",
		"res://demo/00_device_smoke_test.tscn",
		"res://demo/03_openxr_ar_capability_lab.tscn",
		"res://demo/04_rokid_ray_place.tscn",
		"res://demo/06_ios_arkit_place.tscn",
	]) {
		checkResPathExists(resPath, localEvidence);
	}
	evidence.push(localEvidence);
}


function checkStartupHintSurface() {
	const runtimeFile = "addons/godot_xr_foundation/scripts/xr_foundation.gd";
	const demoFile = "demo/00_device_smoke_test.gd";
	const runtimeText = readProjectFile(runtimeFile);
	const demoText = readProjectFile(demoFile);
	const localEvidence = { file: "startup hint surface", exists: Boolean(runtimeText && demoText), checks: [] };
	if (!runtimeText) {
		failures.push(`Missing ${runtimeFile}.`);
	}
	if (!demoText) {
		failures.push(`Missing ${demoFile}.`);
	}
	addCheck(localEvidence, "get_xr_cmdline_args", /func\s+get_xr_cmdline_args\s*\(/.test(runtimeText), `${runtimeFile}: missing get_xr_cmdline_args().`);
	addCheck(localEvidence, "cmdline user args compatibility", /get_cmdline_user_args/.test(runtimeText), `${runtimeFile}: should include OS.get_cmdline_user_args() compatibility.`);
	addCheck(localEvidence, "all cmdline args helper", /func\s+_all_cmdline_args\s*\(/.test(runtimeText), `${runtimeFile}: missing _all_cmdline_args().`);
	addCheck(localEvidence, "resolved platform runtime metadata", /"resolved_platform_hint"\s*:\s*XRFoundation\.resolve_platform_hint/.test(demoText), `${demoFile}: smoke runtime metadata should include resolved_platform_hint.`);
	addCheck(localEvidence, "project platform runtime metadata", /"project_platform_hint"\s*:\s*String\(ProjectSettings\.get_setting\("godot_xr_foundation\/platform_hint"/.test(demoText), `${demoFile}: smoke runtime metadata should include project_platform_hint.`);
	addCheck(localEvidence, "trackables smoke metadata", /"trackables"\s*:\s*_trackables_metadata\(\)/.test(demoText), `${demoFile}: smoke payload should include trackables metadata.`);
	addCheck(localEvidence, "camera smoke metadata", /"camera"\s*:\s*_camera_metadata\(\)/.test(demoText), `${demoFile}: smoke payload should include camera metadata.`);
	addCheck(localEvidence, "trackables metadata helper", /func\s+_trackables_metadata\s*\(\)\s*->\s*Dictionary/.test(demoText), `${demoFile}: missing _trackables_metadata().`);
	addCheck(localEvidence, "camera metadata helper", /func\s+_camera_metadata\s*\(\)\s*->\s*Dictionary/.test(demoText), `${demoFile}: missing _camera_metadata().`);
	addCheck(localEvidence, "native camera intrinsics smoke metadata", /native_intrinsics_available/.test(demoText), `${demoFile}: camera metadata should include native_intrinsics_available.`);
	addCheck(localEvidence, "native camera frame smoke metadata", /native_frame_available/.test(demoText), `${demoFile}: camera metadata should include native_frame_available.`);
	addCheck(localEvidence, "center screen raycast evidence", /func\s+_center_screen_raycast\s*\(\)\s*->\s*Array\[XRHit\]/.test(demoText), `${demoFile}: missing center screen raycast evidence helper.`);
	evidence.push(localEvidence);
}


function checkScene(file, requirements) {
	const text = readProjectFile(file);
	const localEvidence = {
		file,
		exists: Boolean(text),
		extResources: 0,
		subResources: 0,
		nodes: 0,
		checks: [],
	};
	if (!text) {
		failures.push(`Missing scene: ${file}.`);
		evidence.push(localEvidence);
		return;
	}

	const scene = parseScene(text);
	localEvidence.extResources = scene.extResources.length;
	localEvidence.subResources = scene.subResources.length;
	localEvidence.nodes = scene.nodes.length;

	if (scene.loadSteps !== null) {
		const expectedLoadSteps = scene.extResources.length + scene.subResources.length + 1;
		addCheck(localEvidence, "load_steps", scene.loadSteps === expectedLoadSteps, `${file}: load_steps should be ${expectedLoadSteps}, observed ${scene.loadSteps}.`);
	}

	for (const resource of scene.extResources) {
		checkResPathExists(resource.path, localEvidence);
	}
	for (const resPath of requirements.requiredExtResourcePaths || []) {
		const hasResource = scene.extResources.some((resource) => resource.path === resPath);
		addCheck(localEvidence, `ext_resource:${resPath}`, hasResource, `${file}: missing ext_resource ${resPath}.`);
		checkResPathExists(resPath, localEvidence);
	}

	const knownNodes = expandKnownNodes(scene.nodes);
	for (const nodePath of requirements.requiredNodes || []) {
		addCheck(localEvidence, `node:${nodePath}`, knownNodes.has(nodePath), `${file}: missing node ${nodePath}.`);
	}
	for (const nodePathCheck of requirements.requiredNodePaths || []) {
		const node = scene.nodes.find((candidate) => candidate.path === nodePathCheck.node);
		if (!node) {
			addCheck(localEvidence, `nodepath:${nodePathCheck.node}.${nodePathCheck.property}`, false, `${file}: cannot check NodePath on missing node ${nodePathCheck.node}.`);
			continue;
		}
		const actualText = node.properties[nodePathCheck.property] || "";
		const actualTarget = resolveNodePath(node.path, actualText);
		addCheck(
			localEvidence,
			`nodepath:${nodePathCheck.node}.${nodePathCheck.property}`,
			actualTarget === nodePathCheck.target && knownNodes.has(actualTarget),
			`${file}: ${nodePathCheck.node}.${nodePathCheck.property} should resolve to ${nodePathCheck.target}, observed ${actualTarget || "empty"}.`,
		);
	}

	evidence.push(localEvidence);
}


function parseScene(text) {
	const headerMatch = text.match(/^\[gd_scene[^\]]*load_steps=(\d+)/m);
	const extResources = [];
	const subResources = [];
	const nodes = [];
	let currentNode = null;
	let rootName = "";

	for (const line of text.split(/\r?\n/)) {
		const extMatch = line.match(/^\[ext_resource[^\]]*path="([^"]+)"[^\]]*id="([^"]+)"/);
		if (extMatch) {
			extResources.push({ path: extMatch[1], id: extMatch[2] });
			continue;
		}
		if (/^\[sub_resource\b/.test(line)) {
			subResources.push(line);
			continue;
		}
		const nodeMatch = line.match(/^\[node\s+name="([^"]+)"(?:\s+type="([^"]+)")?(?:\s+parent="([^"]*)")?/);
		if (nodeMatch) {
			currentNode = {
				name: nodeMatch[1],
				type: nodeMatch[2] || "",
				parent: nodeMatch[3] || "",
				properties: {},
			};
			if (!rootName) {
				rootName = currentNode.name;
			}
			currentNode.path = nodeScenePath(currentNode, rootName);
			nodes.push(currentNode);
			continue;
		}
		if (currentNode) {
			const propertyMatch = line.match(/^([^=\[][^=]*?)=(.*)$/);
			if (propertyMatch) {
				currentNode.properties[propertyMatch[1].trim()] = propertyMatch[2].trim();
			}
		}
	}

	return {
		loadSteps: headerMatch ? Number(headerMatch[1]) : null,
		extResources,
		subResources,
		nodes,
	};
}


function nodeScenePath(node, rootName) {
	if (!node.parent || node.parent === ".") {
		return node.name === rootName ? rootName : `${rootName}/${node.name}`;
	}
	return `${rootName}/${node.parent}/${node.name}`;
}


function expandKnownNodes(nodes) {
	const known = new Set();
	for (const node of nodes) {
		const parts = node.path.split("/");
		for (let index = 1; index <= parts.length; index += 1) {
			known.add(parts.slice(0, index).join("/"));
		}
	}
	return known;
}


function resolveNodePath(sourceNodePath, encodedNodePath) {
	const nodePathMatch = String(encodedNodePath).match(/^NodePath\("([^"]*)"\)$/);
	if (!nodePathMatch) {
		return "";
	}
	const rawPath = nodePathMatch[1];
	if (!rawPath) {
		return "";
	}
	if (rawPath.startsWith("/")) {
		return rawPath.slice(1);
	}
	const stack = sourceNodePath.split("/");
	for (const part of rawPath.split("/")) {
		if (!part || part === ".") {
			continue;
		}
		if (part === "..") {
			stack.pop();
		} else {
			stack.push(part);
		}
	}
	return stack.join("/");
}


function requireText(text, needle, message, evidenceBucket) {
	addCheck(evidenceBucket, needle, text.includes(needle), message);
}


function checkResPathExists(resPath, evidenceBucket) {
	const absolutePath = resPathToAbsolute(resPath);
	addCheck(evidenceBucket, `exists:${resPath}`, fs.existsSync(absolutePath), `Missing resource ${resPath}.`);
}


function addCheck(evidenceBucket, label, pass, failureMessage) {
	evidenceBucket.checks.push({ label, pass });
	if (!pass) {
		failures.push(failureMessage);
	}
}


function resPathToAbsolute(resPath) {
	if (!resPath.startsWith("res://")) {
		return path.resolve(PROJECT_ROOT, resPath);
	}
	return path.join(PROJECT_ROOT, resPath.slice("res://".length));
}


function readProjectFile(file) {
	try {
		return fs.readFileSync(path.resolve(PROJECT_ROOT, file), "utf8");
	} catch (error) {
		return "";
	}
}
