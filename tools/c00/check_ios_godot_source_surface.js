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
		file: "tools/c00/prepare_godot_source.sh",
		requirements: [
			["official Godot repository", /https:\/\/github\.com\/godotengine\/godot\.git/],
			["Godot source env", /GODOT_SOURCE_DIR/],
			["Godot tag env", /GODOT_TAG/],
			["Godot binary tag inference", /infer_tag_from_godot/],
			["stable tag conversion", /\.stable\/-stable/],
			["Godot source clone", /git clone/],
			["required core version header", /core\/version\.h/],
			["required ClassDB header", /core\/object\/class_db\.h/],
			["required Engine header", /core\/config\/engine\.h/],
			["required iOS platform path", /platform\/ios/],
			["ARKit build command guidance", /ios\/plugins\/godot_arkit\/build_xcframework\.sh/],
		],
	},
	{
		file: "ios/plugins/godot_arkit/build_xcframework.sh",
		requirements: [
			["requires Godot source dir", /GODOT_SOURCE_DIR\s+Required/],
			["validates version header", /core\/version\.h/],
			["validates ClassDB header", /core\/object\/class_db\.h/],
			["validates Engine header", /core\/config\/engine\.h/],
			["validates iOS platform path", /platform\/ios/],
		],
	},
	{
		file: "tools/c00/bootstrap_device_machine.sh",
		requirements: [
			["Godot source readiness row", /Godot source headers/],
			["Godot source helper guidance", /prepare_godot_source\.sh/],
		],
	},
	{
		file: "tools/c00/README_CN.md",
		requirements: [
			["Godot source helper documented", /prepare_godot_source\.sh/],
			["ARKit xcframework build documented", /build_xcframework\.sh/],
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
		"  node tools/c00/check_ios_godot_source_surface.js",
		"",
		"Checks the iPad/ARKit Godot source preparation surface without requiring a Godot checkout.",
	].join("\n"));
}


function readText(filePath) {
	try {
		return fs.readFileSync(filePath, "utf8");
	} catch (error) {
		return "";
	}
}
