#!/usr/bin/env node

const fs = require("fs");
const path = require("path");

const args = parseArgs(process.argv.slice(2));
const gate = String(args.gate || "all").toLowerCase();
const file = path.resolve(args.file || "export_presets.cfg");

const expected = {
	rokid: { name: "C00 Rokid OpenXR", platform: "Android", path: "builds/rokid/c00.apk" },
	"rokid-place": { name: "C02 Rokid OpenXR Place", platform: "Android", path: "builds/rokid/c02-place.apk", sceneArg: "--xr-scene=rokid_place" },
	"android-arcore": { name: "C00 Android ARCore", platform: "Android", path: "builds/android_arcore/c00.apk" },
	ipad: { name: "C00 iPad ARKit", platform: "iOS", path: "builds/ipad/c00.zip" },
	"ipad-place": { name: "C04 iPad ARKit Place", platform: "iOS", path: "builds/ipad/c04-place.zip", sceneArg: "--xr-scene=ios_arkit_place" },
};
const requiredExportScenes = [
	"res://demo/boot.tscn",
	"res://demo/00_device_smoke_test.tscn",
	"res://demo/01_place_on_plane.tscn",
	"res://demo/02_backend_switcher.tscn",
	"res://demo/03_openxr_ar_capability_lab.tscn",
	"res://demo/04_rokid_ray_place.tscn",
	"res://demo/06_ios_arkit_place.tscn",
];
const openXrVendorOptions = [
	"xr_features/openxr_vendor_khronos",
	"xr_features/openxr_vendor_meta",
	"xr_features/openxr_vendor_pico",
	"xr_features/openxr_vendor_androidxr",
	"xr_features/openxr_vendor_magicleap",
	"xr_features/openxr_vendor_lynx",
];

if (args.help || args.h) {
	usage();
	process.exit(0);
}

if (!["all", "rokid", "rokid-place", "ipad", "ipad-place", "ios-simulator", "ios-simulator-place", "android-arcore", "editor"].includes(gate)) {
	usage();
	process.exit(2);
}

if (!fs.existsSync(file)) {
	console.error(`Missing export presets file: ${file}`);
	process.exit(1);
}

const text = fs.readFileSync(file, "utf8");
const presets = parsePresets(text);
const gates = gate === "all"
	? ["rokid", "rokid-place", "ipad", "ipad-place", "android-arcore"]
	: gate === "editor"
		? []
		: [gate === "ios-simulator" ? "ipad" : (gate === "ios-simulator-place" ? "ipad-place" : gate)];
const failures = [];
const warnings = [];
const evidence = [];
const hashCommentLines = text
	.split(/\r?\n/)
	.map((line, index) => ({ line, number: index + 1 }))
	.filter((item) => item.line.trim().startsWith("#"));

if (hashCommentLines.length > 0) {
	const lines = hashCommentLines.map((item) => item.number).join(", ");
	failures.push(`export_presets.cfg uses # comments on line(s) ${lines}; Godot ConfigFile requires ; comments.`);
}

for (const item of gates) {
	const requirement = expected[item];
	const preset = presets.find((candidate) => candidate.values.name === requirement.name);
	if (!preset) {
		failures.push(`Missing preset "${requirement.name}" for ${item}.`);
		continue;
	}

	if (preset.values.platform !== requirement.platform) {
		failures.push(`Preset "${requirement.name}" platform should be ${requirement.platform}, observed ${preset.values.platform || "empty"}.`);
	}
	if (preset.values.export_filter !== "scenes") {
		failures.push(`Preset "${requirement.name}" export_filter must be "scenes" so generated folders and tooling are not packed into the app.`);
	}
	const exportFiles = String(preset.values.export_files || "");
	for (const requiredScene of requiredExportScenes) {
		if (!exportFiles.includes(requiredScene)) {
			failures.push(`Preset "${requirement.name}" export_files must include ${requiredScene}.`);
		}
	}

	const exportPath = preset.values.export_path || preset.values.custom_template_debug || "";
	if (exportPath && exportPath !== requirement.path) {
		warnings.push(`Preset "${requirement.name}" export_path is "${exportPath}", expected C00 default "${requirement.path}".`);
	}
	if (!exportPath) {
		warnings.push(`Preset "${requirement.name}" has no export_path set. The runner passes an explicit output path, but editor one-click deploy may need it.`);
	}

	const excludeFilter = preset.values.exclude_filter || "";
	for (const requiredExclude of ["android/build/*", "builds/*", "exports/*", "releases/*", "tools/*"]) {
		if (!excludeFilter.includes(requiredExclude)) {
			failures.push(`Preset "${requirement.name}" exclude_filter must include ${requiredExclude} to keep generated tooling/build outputs out of exported apps.`);
		}
	}

	if (item === "rokid" || item === "rokid-place") {
		const extraArgs = getPresetOption(preset, "command_line/extra_args");
		if (!extraArgs.includes("--xr-platform=rokid")) {
			failures.push(`Preset "${requirement.name}" must set command_line/extra_args to include --xr-platform=rokid so Android startup selects OpenXR before ARCore.`);
		}
		if (requirement.sceneArg && !extraArgs.includes(requirement.sceneArg)) {
			failures.push(`Preset "${requirement.name}" must set command_line/extra_args to include ${requirement.sceneArg} so boot routes to the cycle demo.`);
		}
		if (!isTruthyOption(preset, "gradle_build/use_gradle_build")) {
			failures.push(`Preset "${requirement.name}" must enable gradle_build/use_gradle_build so Android OpenXR vendor loaders can be packaged.`);
		}
		if (getPresetOption(preset, "xr_features/xr_mode") !== "1") {
			failures.push(`Preset "${requirement.name}" must set xr_features/xr_mode=1 for OpenXR.`);
		}
		if (!isTruthyOption(preset, "architectures/arm64-v8a")) {
			failures.push(`Preset "${requirement.name}" must enable architectures/arm64-v8a for Rokid/OpenXR devices.`);
		}
		const selectedVendors = openXrVendorOptions.filter((option) => isTruthyOption(preset, option));
		if (selectedVendors.length !== 1) {
			failures.push(`Preset "${requirement.name}" must enable exactly one OpenXR vendor loader option. Selected: ${selectedVendors.join(", ") || "none"}.`);
		}
		if (!selectedVendors.includes("xr_features/openxr_vendor_khronos")) {
			failures.push(`Preset "${requirement.name}" must enable xr_features/openxr_vendor_khronos=true for the C00 Rokid/OpenXR gate.`);
		}
	}

	if (item === "android-arcore") {
		const extraArgs = getPresetOption(preset, "command_line/extra_args");
		if (!extraArgs.includes("--xr-platform=arcore")) {
			failures.push(`Preset "${requirement.name}" must set command_line/extra_args to include --xr-platform=arcore so Android startup selects ARCore explicitly.`);
		}
		if (!isTruthyOption(preset, "gradle_build/use_gradle_build")) {
			failures.push(`Preset "${requirement.name}" must enable gradle_build/use_gradle_build so GodotARCore AAR can be packaged.`);
		}
		if (!preset.raw.includes("GodotARCore")) {
			failures.push(`Preset "${requirement.name}" must enable the GodotARCore Android plugin so the ARCore singleton is exported.`);
		}
	}

	if (item === "ipad" || item === "ipad-place") {
		const extraArgs = getPresetOption(preset, "command_line/extra_args");
		if (!extraArgs.includes("--xr-platform=ipad")) {
			failures.push(`Preset "${requirement.name}" must set command_line/extra_args to include --xr-platform=ipad so startup selects ARKit explicitly.`);
		}
		if (requirement.sceneArg && !extraArgs.includes(requirement.sceneArg)) {
			failures.push(`Preset "${requirement.name}" must set command_line/extra_args to include ${requirement.sceneArg} so boot routes to the cycle demo.`);
		}
		if (!preset.raw.includes("GodotARKit")) {
			failures.push(`Preset "${requirement.name}" must enable the GodotARKit iOS plugin so the ARKit singleton is exported.`);
		}
		const targetedDeviceFamily = getPresetOption(preset, "application/targeted_device_family").trim();
		if (targetedDeviceFamily !== "2") {
			failures.push(`Preset "${requirement.name}" must set application/targeted_device_family=2 so the ARKit build supports both iPhone and iPad.`);
		}
		const teamId = getPresetOption(preset, "application/app_store_team_id").trim();
		if (!teamId) {
			failures.push(`Preset "${requirement.name}" must set application/app_store_team_id. Use a real Apple Developer Team ID on device machines; ABCDE12345 is only a starter placeholder.`);
		}
		if (teamId === "ABCDE12345") {
			warnings.push(`Preset "${requirement.name}" still uses placeholder application/app_store_team_id=ABCDE12345; replace it with a real Apple Developer Team ID before installing to an iOS device.`);
		}
		const iconPath = getPresetOption(preset, "icons/icon_1024x1024").trim();
		if (!iconPath) {
			failures.push(`Preset "${requirement.name}" must set icons/icon_1024x1024 so Godot can generate the required iOS icon sizes.`);
		} else if (iconPath.startsWith("res://")) {
			const iconFile = path.join(path.dirname(file), iconPath.slice("res://".length));
			if (!fs.existsSync(iconFile)) {
				failures.push(`Preset "${requirement.name}" icons/icon_1024x1024 points to missing file: ${iconPath}.`);
			}
		}
		if (!isTruthyOption(preset, "application/export_project_only")) {
			failures.push(`Preset "${requirement.name}" must set application/export_project_only=true so Godot exports a reproducible Xcode project before device signing.`);
		}
	}

	evidence.push({
		gate: item,
		section: preset.section,
		name: preset.values.name,
		platform: preset.values.platform,
		export_path: exportPath,
		exclude_filter: excludeFilter,
		export_files: exportFiles,
		extra_args: getPresetOption(preset, "command_line/extra_args"),
		openxr_vendors: (item === "rokid" || item === "rokid-place") ? Object.fromEntries(openXrVendorOptions.map((option) => [option, isTruthyOption(preset, option)])) : undefined,
		app_store_team_id: (item === "ipad" || item === "ipad-place") ? getPresetOption(preset, "application/app_store_team_id") : undefined,
		targeted_device_family: (item === "ipad" || item === "ipad-place") ? getPresetOption(preset, "application/targeted_device_family") : undefined,
		icon_1024x1024: (item === "ipad" || item === "ipad-place") ? getPresetOption(preset, "icons/icon_1024x1024") : undefined,
	});
}

const summary = {
	file,
	gate,
	pass: failures.length === 0,
	failures,
	warnings,
	presets: evidence,
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
		"  node tools/c00/check_export_presets.js --gate <all|rokid|rokid-place|ipad|ipad-place|ios-simulator|android-arcore|editor> --file export_presets.cfg",
	].join("\n"));
}

function parsePresets(text) {
	const sections = [];
	let current = null;
	for (const line of text.split(/\r?\n/)) {
		const sectionMatch = line.match(/^\[(preset\.\d+)\]$/);
		if (sectionMatch) {
			current = {
				section: sectionMatch[1],
				values: {},
				rawLines: [line],
			};
			sections.push(current);
			continue;
		}
		if (!current) {
			continue;
		}
		current.rawLines.push(line);
		const keyValue = line.match(/^([^=]+)=(.*)$/);
		if (keyValue) {
			current.values[keyValue[1].trim()] = decodeValue(keyValue[2].trim());
		}
	}
	return sections.map((section) => ({
		section: section.section,
		values: section.values,
		raw: section.rawLines.join("\n"),
	}));
}

function decodeValue(value) {
	if (value.startsWith('"') && value.endsWith('"')) {
		return value.slice(1, -1).replace(/\\"/g, '"');
	}
	return value;
}

function getPresetOption(preset, optionName) {
	const exact = preset.values[optionName];
	if (typeof exact === "string") {
		return exact;
	}
	const prefixed = preset.values[`options/${optionName}`];
	if (typeof prefixed === "string") {
		return prefixed;
	}
	for (const [key, value] of Object.entries(preset.values)) {
		if (key.endsWith(`/${optionName}`) && typeof value === "string") {
			return value;
		}
	}
	return "";
}

function isTruthyOption(preset, optionName) {
	const value = getPresetOption(preset, optionName).toLowerCase();
	return value === "true" || value === "1" || value === "yes" || value === "on";
}
