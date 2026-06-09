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
		file: "addons/godot_xr_foundation/scripts/providers/openxr_provider.gd",
		requirements: [
			["official passthrough singleton name", /OpenXRFbPassthroughExtension/],
			["passthrough bool method list", /const\s+PASSTHROUGH_BOOL_METHODS\s*:=/],
			["passthrough capability method", /has_passthrough_capability/],
			["is_passthrough_supported method", /is_passthrough_supported/],
			["start_passthrough lifecycle method", /start_passthrough/],
			["stop_passthrough lifecycle method", /stop_passthrough/],
			["passthrough start helper", /func\s+_start_passthrough\s*\(/],
			["passthrough stop helper", /func\s+_stop_passthrough\s*\(/],
			["passthrough method arity guard", /func\s+_method_argument_count\s*\(/],
			["Godot OK passthrough lifecycle result", /int\(value\)\s*==\s*OK/],
			["vendor feature report helper", /func\s+_vendor_feature_report\s*\(/],
			["vendor report true helper", /func\s+_vendor_report_has_true\s*\(/],
			["AR evidence helper", /func\s+_ar_evidence\s*\(/],
			["vendor feature capability output", /capabilities\["openxr_vendor_feature_report"\]\s*=\s*vendor_feature_report/],
			["passthrough started capability output", /capabilities\["openxr_passthrough_started"\]\s*=\s*passthrough_started/],
			["passthrough start report capability output", /capabilities\["openxr_passthrough_start_report"\]\s*=\s*_passthrough_start_report/],
			["AR evidence capability output", /capabilities\["openxr_ar_evidence"\]\s*=\s*ar_evidence/],
			["virtual plane fallback capability", /capabilities\["openxr_virtual_plane_fallback"\]/],
			["virtual plane source capability", /capabilities\["openxr_plane_source"\]/],
			["virtual plane raycast fallback", /func\s+_virtual_floor_raycast\s*\(/],
			["virtual floor plane fallback", /func\s+_virtual_floor_plane\s*\(/],
			["vendor passthrough feature flag", /VENDOR_PASSTHROUGH/],
			["virtual plane feature flag", /VIRTUAL_PLANE_FALLBACK/],
		],
	},
	{
		file: "addons/godot_xr_foundation/scripts/xr_foundation.gd",
		requirements: [
			["device profile facade", /func\s+get_device_profile\s*\(/],
			["tracking mode facade", /func\s+get_tracking_mode\s*\(/],
			["device profile capability", /capabilities\.get\("device_profile"/],
			["position and rotation tracking mode", /position_and_rotation/],
		],
	},
	{
		file: "tools/c00/validate_smoke_log.js",
		requirements: [
			["Rokid AR evidence gate", /Rokid gate requires capabilities\.openxr_ar_evidence/],
			["Rokid AR evidence lookup", /getCapability\(evidence,\s*"openxr_ar_evidence"\)/],
		],
	},
	{
		file: "tools/c00/verify_phase_evidence.js",
		requirements: [
			["Rokid aggregate AR evidence gate", /Rokid gate requires capabilities\.openxr_ar_evidence/],
			["Rokid aggregate AR evidence lookup", /getCapability\(evidence,\s*"openxr_ar_evidence"\)/],
		],
	},
	{
		file: "demo/03_openxr_ar_capability_lab.gd",
		requirements: [
			["OpenXR lab marker log", /GXF_OPENXR_LAB/],
			["OpenXR backend default", /XRFoundationTypes\.Backend\.OPENXR/],
			["Rokid platform hint", /platform_hint\s*:=\s*"rokid"/],
			["AR tier reporting", /openxr_ar_tier/],
			["passthrough reporting", /openxr_passthrough_started/],
			["plane source reporting", /openxr_plane_source/],
			["vendor singleton reporting", /openxr_vendor_singletons/],
			["input profile reporting", /XRInputProfileScript/],
			["device profile reporting", /get_device_profile\(\)/],
			["tracking mode reporting", /get_tracking_mode\(\)/],
			["center raycast", /_center_screen_raycast/],
		],
	},
	{
		file: "demo/03_openxr_ar_capability_lab.tscn",
		requirements: [
			["OpenXR lab scene root", /OpenXRCapabilityLab/],
			["OpenXR lab script resource", /03_openxr_ar_capability_lab\.gd/],
			["OpenXR ARSession preset", /requested_backend\s*=\s*2/],
			["Rokid scene platform hint", /platform_hint\s*=\s*"rokid"/],
			["XRI ray interactor", /XRRayInteractor/],
			["AR raycast manager", /ARRaycastManager/],
		],
	},
	{
		file: "demo/04_rokid_ray_place.gd",
		requirements: [
			["Rokid place marker log", /GXF_ROKID_PLACE/],
			["OpenXR backend default", /XRFoundationTypes\.Backend\.OPENXR/],
			["Rokid platform hint", /platform_hint\s*:=\s*"rokid"/],
			["auto first hit placement", /auto_place_on_first_hit/],
			["center raycast", /_center_screen_raycast/],
			["anchor placement", /anchor_manager\.add_anchor/],
			["device profile reporting", /get_device_profile\(\)/],
			["tracking mode reporting", /get_tracking_mode\(\)/],
			["runtime metadata", /"runtime"\s*:\s*_runtime_metadata\(\)/],
			["XR command-line metadata", /"cmdline_xr_args"\s*:\s*XRFoundation\.get_xr_cmdline_args\(\)/],
			["resolved platform runtime metadata", /"resolved_platform_hint"\s*:\s*XRFoundation\.resolve_platform_hint\(platform_hint\)/],
			["placement event", /"placed"/],
		],
	},
	{
		file: "demo/04_rokid_ray_place.tscn",
		requirements: [
			["Rokid place scene root", /RokidRayPlace/],
			["Rokid place script resource", /04_rokid_ray_place\.gd/],
			["OpenXR ARSession preset", /requested_backend\s*=\s*2/],
			["Rokid scene platform hint", /platform_hint\s*=\s*"rokid"/],
			["AR anchor manager", /ARAnchorManager/],
			["placement cursor", /PlacementCursor/],
			["placed object", /PlacedObject/],
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


function usage() {
	console.error([
		"Usage:",
		"  node tools/c00/check_openxr_provider_surface.js",
		"",
		"Checks the OpenXR/Rokid provider diagnostics and C00 AR evidence gate without requiring Godot.",
	].join("\n"));
}


function readText(filePath) {
	try {
		return fs.readFileSync(filePath, "utf8");
	} catch (error) {
		return "";
	}
}
