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
		file: "addons/godot_xr_foundation/scripts/xri/xr_interaction_manager.gd",
		requirements: [
			["XRInteractionManager class", /class_name\s+XRInteractionManager/],
			["interactor registration", /func\s+register_interactor\s*\(/],
			["interactable registration", /func\s+register_interactable\s*\(/],
			["Unity-style RegisterInteractor alias", /func\s+RegisterInteractor\s*\(/],
			["Unity-style RegisterInteractable alias", /func\s+RegisterInteractable\s*\(/],
			["hover entered signal", /signal\s+hover_entered\s*\(/],
			["Unity hoverEntered signal", /signal\s+hoverEntered\s*\(/],
			["select entered signal", /signal\s+select_entered\s*\(/],
			["Unity selectEntered signal", /signal\s+selectEntered\s*\(/],
			["Unity firstSelectEntered signal", /signal\s+firstSelectEntered\s*\(/],
			["Unity lastSelectExited signal", /signal\s+lastSelectExited\s*\(/],
			["activate signal", /signal\s+activated\s*\(/],
			["central select dispatch", /func\s+select\s*\(/],
			["central release dispatch", /func\s+release\s*\(/],
		],
	},
	{
		file: "addons/godot_xr_foundation/scripts/xri/xr_ray_interactor.gd",
		requirements: [
			["XRRayInteractor class", /class_name\s+XRRayInteractor/],
			["interaction manager path", /interaction_manager_path/],
			["max raycast distance", /max_raycast_distance/],
			["keep selected target valid", /keep_selected_target_valid/],
			["valid target API", /func\s+GetValidTargets\s*\(/],
			["raycast hit API", /func\s+TryGetCurrent3DRaycastHit\s*\(/],
			["Unity hoverEntered signal", /signal\s+hoverEntered\s*\(/],
			["Unity selectEntered signal", /signal\s+selectEntered\s*\(/],
			["Unity firstSelectEntered signal", /signal\s+firstSelectEntered\s*\(/],
			["Unity lastSelectExited signal", /signal\s+lastSelectExited\s*\(/],
			["manager hover dispatch", /interaction_manager\.set_hover_target/],
			["manager select dispatch", /interaction_manager\.select/],
			["activate support", /func\s+activate\s*\(/],
		],
	},
	{
		file: "addons/godot_xr_foundation/scripts/xri/xr_grab_interactable.gd",
		requirements: [
			["XRGrabInteractable class", /class_name\s+XRGrabInteractable/],
			["hover event", /signal\s+hover_entered\s*\(/],
			["Unity hoverEntered event", /signal\s+hoverEntered\s*\(/],
			["select event", /signal\s+select_entered\s*\(/],
			["Unity selectEntered event", /signal\s+selectEntered\s*\(/],
			["Unity firstSelectEntered event", /signal\s+firstSelectEntered\s*\(/],
			["Unity lastSelectExited event", /signal\s+lastSelectExited\s*\(/],
			["activate event", /signal\s+activated\s*\(/],
			["hover enter hook", /func\s+on_hover_enter\s*\(/],
			["select enter hook", /func\s+on_select_enter\s*\(/],
			["Unity-style IsHovered", /func\s+IsHovered\s*\(/],
			["Unity-style IsSelected", /func\s+IsSelected\s*\(/],
		],
	},
	{
		file: "demo/00_device_smoke_test.tscn",
		requirements: [
			["XRI manager in smoke scene", /XRInteractionManager/],
			["XRI ray interactor in smoke scene", /XRRayInteractor/],
			["XRI interactable in smoke scene", /XRGrabInteractable/],
		],
	},
	{
		file: "demo/00_device_smoke_test.gd",
		requirements: [
			["XRI smoke fields", /xri_hover_count/],
			["XRI smoke log payload", /"xri"/],
			["XRI status panel", /"XRI:/],
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
		"  node tools/c00/check_xri_api_surface.js",
		"",
		"Checks the XRI-style interaction manager/interactor/interactable surface without requiring Godot.",
	].join("\n"));
}


function readText(filePath) {
	try {
		return fs.readFileSync(filePath, "utf8");
	} catch (error) {
		return "";
	}
}
