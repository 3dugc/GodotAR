#!/usr/bin/env node

const fs = require("fs");
const path = require("path");

const PROJECT_ROOT = path.resolve(__dirname, "../..");
const args = parseArgs(process.argv.slice(2));

if (args.help || args.h) {
	usage();
	process.exit(0);
}

const checks = [
	{
		file: "addons/godot_xr_foundation/scripts/xr_foundation_types.gd",
		requirements: [
			["ARSessionState enum", /enum\s+ARSessionState\s*\{/],
			["NotTrackingReason enum", /enum\s+NotTrackingReason\s*\{/],
			["ARSessionState mapper", /func\s+ar_session_state_from_foundation_state\s*\(/],
			["NotTrackingReason mapper", /func\s+not_tracking_reason_from_status\s*\(/],
			["native reason string mapper", /func\s+not_tracking_reason_from_string\s*\(/],
		],
	},
	{
		file: "addons/godot_xr_foundation/scripts/xr_foundation.gd",
		requirements: [
			["Unity ARSession state facade", /func\s+get_ar_session_state\s*\(/],
			["Unity ARSession state name facade", /func\s+get_ar_session_state_name\s*\(/],
			["Unity notTrackingReason facade", /func\s+get_not_tracking_reason\s*\(/],
			["Unity notTrackingReason name facade", /func\s+get_not_tracking_reason_name\s*\(/],
			["provider notTrackingReason facade", /provider\.get_not_tracking_reason\(\)/],
		],
	},
	{
		file: "addons/godot_xr_foundation/scripts/providers/xr_provider.gd",
		requirements: [
			["provider notTrackingReason method", /func\s+get_not_tracking_reason\s*\(/],
			["provider notTrackingReason default mapper", /XRFoundationTypes\.not_tracking_reason_from_status\(get_tracking_status\(\)\)/],
		],
	},
	{
		file: "addons/godot_xr_foundation/scripts/arfoundation/xr_session_manager.gd",
		requirements: [
			["match_frame_rate export", /@export\s+var\s+match_frame_rate\s*:=/],
			["match_frame_rate_requested export", /@export\s+var\s+match_frame_rate_requested\s*:=/],
			["match_frame_rate option", /"match_frame_rate"\s*:\s*match_frame_rate/],
			["match_frame_rate_requested option", /"match_frame_rate_requested"\s*:\s*match_frame_rate_requested\s+or\s+match_frame_rate/],
			["instance ARSessionState getter", /func\s+get_ar_session_state\s*\(/],
			["instance notTrackingReason getter", /func\s+get_not_tracking_reason\s*\(/],
		],
	},
	{
		file: "addons/godot_xr_foundation/scripts/arfoundation/ar_session.gd",
		requirements: [
			["requested_tracking_mode export", /@export\s+var\s+requested_tracking_mode\s*:=/],
			["Unity state static", /static\s+func\s+state\s*\(\)\s*->\s*int/],
			["foundation_state compatibility", /static\s+func\s+foundation_state\s*\(\)\s*->\s*int/],
			["Unity notTrackingReason static", /static\s+func\s+notTrackingReason\s*\(\)\s*->\s*int/],
			["GetARSessionState alias", /static\s+func\s+GetARSessionState\s*\(\)\s*->\s*int/],
			["GetState alias", /static\s+func\s+GetState\s*\(\)\s*->\s*int/],
			["GetNotTrackingReason alias", /static\s+func\s+GetNotTrackingReason\s*\(\)\s*->\s*int/],
			["requestedTrackingMode getter", /func\s+get_requested_tracking_mode\s*\(/],
			["matchFrameRate setter", /func\s+set_match_frame_rate\s*\(/],
		],
	},
	{
		file: "addons/godot_xr_foundation/scripts/arfoundation/ar_raycast_manager.gd",
		requirements: [
			["raycast from screen helper", /func\s+raycast_from_screen\s*\(/],
			["RaycastFromScreen alias", /func\s+RaycastFromScreen\s*\(/],
			["RaycastScreen alias", /func\s+RaycastScreen\s*\(/],
			["TryScreenRaycast list API", /func\s+TryScreenRaycast\s*\(/],
		],
	},
	{
		file: "addons/godot_xr_foundation/scripts/arfoundation/ar_plane_manager.gd",
		requirements: [
			["planes_changed signal", /signal\s+planes_changed\s*\(/],
			["plane trackables getter", /func\s+get_trackables\s*\(\)\s*->\s*Array\[ARPlane\]/],
			["plane GetTrackables alias", /func\s+GetTrackables\s*\(\)\s*->\s*Array\[ARPlane\]/],
			["planes_changed emission", /planes_changed\.emit\s*\(/],
		],
	},
	{
		file: "addons/godot_xr_foundation/scripts/arfoundation/ar_anchor_manager.gd",
		requirements: [
			["anchors_changed signal", /signal\s+anchors_changed\s*\(/],
			["anchor trackables getter", /func\s+get_trackables\s*\(\)\s*->\s*Array\[ARAnchor\]/],
			["anchor GetTrackables alias", /func\s+GetTrackables\s*\(\)\s*->\s*Array\[ARAnchor\]/],
			["anchors_changed emission", /anchors_changed\.emit\s*\(/],
		],
	},
	{
		file: "addons/godot_xr_foundation/scripts/ar_anchor.gd",
		requirements: [
			["anchor dictionary conversion", /static\s+func\s+from_dictionary\s*\(/],
			["anchor persistent id mapping", /persistent_id\s*=\s*StringName\(data\.get\("persistent_id"/],
			["anchor dictionary export", /func\s+to_dictionary\s*\(\)\s*->\s*Dictionary/],
		],
	},
	{
		file: "addons/godot_xr_foundation/scripts/providers/native_xr_provider.gd",
		requirements: [
			["native anchor conversion call", /return\s+_convert_anchor\(raw,\s*transform\)/],
			["native anchor conversion helper", /func\s+_convert_anchor\s*\(/],
			["native anchor dictionary preservation", /ARAnchor\.from_dictionary\(data\)/],
			["native notTrackingReason method", /func\s+get_not_tracking_reason\s*\(/],
			["ARKit tracking reason passthrough", /arkit_tracking_reason/],
			["native reason string mapper", /not_tracking_reason_from_string\(String\(value\)\)/],
		],
	},
	{
		file: "MIGRATION_UNITY.md",
		requirements: [
			["ARSession.state migration row", /ARSession\.state/],
			["notTrackingReason migration row", /notTrackingReason/],
			["ARRaycastManager.Raycast screen migration", /RaycastFromScreen|TryScreenRaycast/],
			["trackables changed events", /planes_changed|anchors_changed/],
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
	for (const [label, pattern] of item.requirements) {
		if (pattern.test(text)) {
			passed += 1;
		} else {
			failures.push(`${item.file}: missing ${label}`);
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


function parseArgs(argv) {
	const parsed = {};
	for (let index = 0; index < argv.length; index += 1) {
		const item = argv[index];
		if (!item.startsWith("--")) {
			continue;
		}
		const key = item.slice(2);
		const next = argv[index + 1];
		if (!next || next.startsWith("--")) {
			parsed[key] = true;
		} else {
			parsed[key] = next;
			index += 1;
		}
	}
	return parsed;
}


function usage() {
	console.error([
		"Usage:",
		"  node tools/c00/check_arfoundation_api_surface.js",
		"",
		"Checks the Unity ARFoundation-style GDScript facade without requiring a Godot binary.",
	].join("\n"));
}


function readText(filePath) {
	try {
		return fs.readFileSync(filePath, "utf8");
	} catch (error) {
		return "";
	}
}
