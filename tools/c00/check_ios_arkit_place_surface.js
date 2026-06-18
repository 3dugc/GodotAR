#!/usr/bin/env node

const fs = require("fs");
const path = require("path");

const PROJECT_ROOT = path.resolve(__dirname, "../..");

if (process.argv.includes("--help") || process.argv.includes("-h")) {
	usage();
	process.exit(0);
}

const checks = [
	{
		file: "demo/06_ios_arkit_place.gd",
		requirements: [
			["C04 marker", /const\s+CYCLE_ID\s*:=\s*"C04"/],
			["structured log marker", /GXF_ARKIT_PLACE\|/],
			["ARKit backend default", /requested_backend:\s*int\s*=\s*XRFoundationTypes\.Backend\.ARKIT/],
			["iPad platform hint", /platform_hint\s*:=\s*"ipad"/],
			["ARCameraManager node usage", /@onready\s+var\s+camera_manager:[^\n]+=\s*\$ARCameraManager/],
			["ARPlaneManager usage", /@onready\s+var\s+plane_manager:\s*ARPlaneManager/],
			["ARRaycastManager usage", /@onready\s+var\s+raycast_manager:\s*ARRaycastManager/],
			["ARAnchorManager usage", /@onready\s+var\s+anchor_manager:\s*ARAnchorManager/],
			["screen touch placement", /InputEventScreenTouch/],
			["Unity-style screen raycast", /raycast_manager\.Raycast\(screen_position,\s*raw_hits/],
			["explicit raycast camera binding", /SetRaycastCamera\(xr_camera\)/],
			["center raycast fallback", /auto_place_on_first_hit/],
			["Unity async anchor facade", /TryAddAnchorAsync\(transform\)/],
			["Unity trackable anchor facade", /AttachAnchor\(plane,\s*transform\)/],
			["Unity anchor descriptor probe", /GetDescriptor\(\)\.get\("supportsTrackableAttachments"/],
			["camera intrinsics evidence", /TryGetIntrinsics\(intrinsics\)/],
			["camera frame evidence", /GetLatestFrame\(\)/],
			["ARKit tracking state evidence", /arkit_tracking_state/],
			["ARKit tracking reason evidence", /arkit_tracking_reason/],
			["native frame evidence", /native_frame_available/],
			["native camera pose application", /_apply_native_camera_pose/],
			["native camera transform evidence", /native_camera_transform_matrix/],
			["transparent AR viewport", /viewport\.transparent_bg\s*=\s*true/],
			["transparent AR clear color", /RenderingServer\.set_default_clear_color\(Color\(0\.0,\s*0\.0,\s*0\.0,\s*0\.0\)\)/],
			["native camera background diagnostics", /arkit_camera_background_reason/],
			["runtime metadata", /"runtime"\s*:\s*_runtime_metadata\(\)/],
			["XR command-line metadata", /"cmdline_xr_args"\s*:\s*XRFoundation\.get_xr_cmdline_args\(\)/],
			["resolved platform runtime metadata", /"resolved_platform_hint"\s*:\s*XRFoundation\.resolve_platform_hint\(platform_hint\)/],
			["plane count evidence", /"planes"\s*:\s*_plane_metadata\(\)/],
			["anchor count evidence", /"anchors"\s*:\s*_anchor_list_metadata\(\)/],
		],
	},
	{
		file: "demo/06_ios_arkit_place.tscn",
		requirements: [
			["scene header", /\[gd_scene\s+load_steps=17\s+format=3\]/],
			["demo script", /res:\/\/demo\/06_ios_arkit_place\.gd/],
			["ARSession script", /res:\/\/addons\/godot_xr_foundation\/scripts\/arfoundation\/ar_session\.gd/],
			["ARCameraManager script", /res:\/\/addons\/godot_xr_foundation\/scripts\/arfoundation\/ar_camera_manager\.gd/],
			["ARRaycastManager script", /res:\/\/addons\/godot_xr_foundation\/scripts\/arfoundation\/ar_raycast_manager\.gd/],
			["ARPlaneManager script", /res:\/\/addons\/godot_xr_foundation\/scripts\/arfoundation\/ar_plane_manager\.gd/],
			["ARAnchorManager script", /res:\/\/addons\/godot_xr_foundation\/scripts\/arfoundation\/ar_anchor_manager\.gd/],
			["ARKit backend value", /requested_backend\s*=\s*4/],
			["iPad platform hint", /platform_hint\s*=\s*"ipad"/],
			["camera path", /camera_path\s*=\s*NodePath\("\.\.\/XRFoundationRig\/XRCamera3D"\)/],
			["plane manager node", /\[node\s+name="ARPlaneManager"\s+type="Node"\s+parent="\."\]/],
			["anchor manager node", /\[node\s+name="ARAnchorManager"\s+type="Node"\s+parent="\."\]/],
			["placement cursor", /\[node\s+name="PlacementCursor"\s+type="MeshInstance3D"\s+parent="World"\]/],
			["placed object", /\[node\s+name="PlacedObject"\s+type="MeshInstance3D"\s+parent="World"\]/],
		],
	},
	{
		file: "ios/plugins/godot_arkit/src/GodotARKitSession.h",
		requirements: [
			["native add anchor declaration", /-\s*\(NSDictionary\s+\*\)addAnchorWithTransform:\(NSArray\s+\*\)transformMatrix/],
		],
	},
	{
		file: "ios/plugins/godot_arkit/src/GodotARKitSession.mm",
		requirements: [
			["native add anchor method", /addAnchorWithTransform/],
			["ARSession addAnchor call", /\[_session\s+addAnchor:anchor\]/],
			["persistent anchor id evidence", /@"persistent_id":\s*anchor\.identifier\.UUIDString/],
			["native anchor transform evidence", /@"transform":\s*matrixArrayFromTransform\(anchor\.transform\)/],
			["native camera background underlay", /ARSCNView|native_arscnview_underlay/],
			["native camera underlay retry", /ensureCameraBackgroundViewForRunningSession/],
			["native camera transform evidence", /@"camera_transform":\s*cameraTransform/],
		],
	},
	{
		file: "ios/plugins/godot_arkit/src/GodotARKitPlugin.mm",
		requirements: [
			["Godot transform matrix export", /matrix_array_from_transform/],
			["native camera transform bridge", /frame\["camera_transform"\]\s*=\s*transform_from_array/],
			["native camera background state bridge", /get_camera_background_state/],
			["native anchor bridge call", /addAnchorWithTransform:matrix_array_from_transform\(p_transform\)/],
			["native anchor conversion", /persistent_id/],
			["fallback reason", /native_anchor_not_running/],
		],
	},
	{
		file: "specs/cycles/CYCLE_04_IOS_ARKIT_SPEC_CN.md",
		requirements: [
			["demo documented", /demo\/06_ios_arkit_place\.tscn/],
			["structured marker documented", /GXF_ARKIT_PLACE/],
			["static check documented", /check_ios_arkit_place_surface\.js/],
			["native anchor bridge documented", /native ARAnchor|ARSession\.addAnchor|ARKit native anchor/],
		],
	},
];

const failures = [];
const evidence = [];

for (const item of checks) {
	const absolutePath = path.join(PROJECT_ROOT, item.file);
	const text = readText(absolutePath);
	if (!text) {
		failures.push(`Missing required file: ${item.file}`);
		evidence.push({ file: item.file, exists: false, passed: 0, total: item.requirements.length });
		continue;
	}

	let passed = 0;
	for (const [name, pattern] of item.requirements) {
		if (pattern.test(text)) {
			passed += 1;
		} else {
			failures.push(`${item.file}: missing ${name}`);
		}
	}
	evidence.push({ file: item.file, exists: true, passed, total: item.requirements.length });
}

const summary = {
	pass: failures.length === 0,
	projectRoot: PROJECT_ROOT,
	failures,
	evidence,
};

console.log(JSON.stringify(summary, null, 2));
process.exit(summary.pass ? 0 : 1);


function usage() {
	console.error([
		"Usage:",
		"  node tools/c00/check_ios_arkit_place_surface.js",
		"",
		"Checks the C04 iOS ARKit placement demo and native anchor bridge surface without a connected iPad.",
	].join("\n"));
}


function readText(filePath) {
	try {
		return fs.readFileSync(filePath, "utf8");
	} catch {
		return "";
	}
}
