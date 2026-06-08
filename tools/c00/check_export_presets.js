#!/usr/bin/env node

const fs = require("fs");
const path = require("path");

const args = parseArgs(process.argv.slice(2));
const gate = String(args.gate || "all").toLowerCase();
const file = path.resolve(args.file || "export_presets.cfg");

const expected = {
	rokid: { name: "C00 Rokid OpenXR", platform: "Android", path: "builds/rokid/c00.apk" },
	"android-arcore": { name: "C00 Android ARCore", platform: "Android", path: "builds/android_arcore/c00.apk" },
	ipad: { name: "C00 iPad ARKit", platform: "iOS", path: "builds/ipad/c00.zip" },
};

if (args.help || args.h) {
	usage();
	process.exit(0);
}

if (!["all", "rokid", "ipad", "android-arcore", "editor"].includes(gate)) {
	usage();
	process.exit(2);
}

if (!fs.existsSync(file)) {
	console.error(`Missing export presets file: ${file}`);
	process.exit(1);
}

const text = fs.readFileSync(file, "utf8");
const presets = parsePresets(text);
const gates = gate === "all" ? ["rokid", "ipad", "android-arcore"] : gate === "editor" ? [] : [gate];
const failures = [];
const warnings = [];
const evidence = [];

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

	const exportPath = preset.values.export_path || preset.values.custom_template_debug || "";
	if (exportPath && exportPath !== requirement.path) {
		warnings.push(`Preset "${requirement.name}" export_path is "${exportPath}", expected C00 default "${requirement.path}".`);
	}
	if (!exportPath) {
		warnings.push(`Preset "${requirement.name}" has no export_path set. The runner passes an explicit output path, but editor one-click deploy may need it.`);
	}

	if (item === "rokid") {
		const presetText = preset.raw.toLowerCase();
		if (!presetText.includes("openxr") && !presetText.includes("xr_mode")) {
			warnings.push(`Preset "${requirement.name}" does not visibly mention OpenXR/xr_mode. Confirm XR Mode is OpenXR in Godot's export UI.`);
		}
		const extraArgs = getPresetOption(preset, "command_line/extra_args");
		if (!extraArgs.includes("--xr-platform=rokid")) {
			failures.push(`Preset "${requirement.name}" must set command_line/extra_args to include --xr-platform=rokid so Android startup selects OpenXR before ARCore.`);
		}
	}

	if (item === "android-arcore") {
		const extraArgs = getPresetOption(preset, "command_line/extra_args");
		if (extraArgs && !extraArgs.includes("--xr-platform=arcore")) {
			warnings.push(`Preset "${requirement.name}" command_line/extra_args is "${extraArgs}". Expected --xr-platform=arcore for explicit ARCore startup.`);
		}
	}

	if (item === "ipad" && !preset.raw.includes("GodotARKit")) {
		failures.push(`Preset "${requirement.name}" must enable the GodotARKit iOS plugin so the ARKit singleton is exported.`);
	}

	evidence.push({
		gate: item,
		section: preset.section,
		name: preset.values.name,
		platform: preset.values.platform,
		export_path: exportPath,
		extra_args: getPresetOption(preset, "command_line/extra_args"),
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
		"  node tools/c00/check_export_presets.js --gate <all|rokid|ipad|android-arcore|editor> --file export_presets.cfg",
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
