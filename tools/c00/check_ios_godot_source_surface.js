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
		file: "tools/c00/godot_version_defaults.sh",
		requirements: [
			["Godot source template version parser", /godot_source_template_version/],
			["Godot source tag parser", /godot_source_tag/],
			["Godot source/template match helper", /godot_source_matches_template_version/],
			["shared version.py reader", /godot_read_version_value/],
		],
	},
	{
		file: "tools/c00/prepare_godot_source.sh",
		requirements: [
			["official Godot repository", /https:\/\/github\.com\/godotengine\/godot\.git/],
			["Godot source env", /GODOT_SOURCE_DIR/],
			["Godot tag env", /GODOT_TAG/],
			["Godot binary tag inference", /infer_tag_from_godot/],
			["Godot tag/template conversion", /godot_tag_from_template_version/],
			["latest Godot tag option", /C00_GODOT_LATEST_TAG/],
			["existing source tag guard", /source_tree_tag/],
			["source mismatch replacement guidance", /Pass --force to replace it/],
			["Godot source clone", /git clone/],
			["remote tag availability guard", /ensure_requested_tag_available_or_fallback/],
			["remote tag check", /git ls-remote --exit-code --tags/],
			["stable source fallback option", /--allow-stable-fallback/],
			["stable source fallback env", /GODOT_ALLOW_STABLE_SOURCE_FALLBACK/],
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
			["loads C00 version helper", /godot_version_defaults\.sh/],
			["expected source version override", /EXPECTED_GODOT_SOURCE_VERSION/],
			["checks parsed source version", /godot_source_template_version/],
			["rejects mismatched source headers", /Godot source headers do not match selected export template version/],
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
			["default prepared source path", /\.godot\/cache\/c00\/godot-source/],
			["Godot source helper guidance", /prepare_godot_source\.sh/],
			["Godot source version parse", /godot_source_template_version/],
			["Godot source expected version", /expected_source_version/],
		],
	},
	{
		file: "tools/c00/preflight.sh",
		requirements: [
			["Godot source preflight row", /Godot source headers/],
			["default prepared source path", /\.godot\/cache\/c00\/godot-source/],
			["Godot source helper guidance", /prepare_godot_source\.sh/],
			["Godot source version parse", /godot_source_template_version/],
			["Godot source version mismatch failure", /Expected %s, got %s/],
			["prebuilt ARKit escape hatch", /C00_ALLOW_PREBUILT_ARKIT/],
			["latest source tag missing guidance", /wait for that tag or switch the whole chain to --latest-stable/],
		],
	},
	{
		file: "tools/c00/run_device_cycle.sh",
		requirements: [
			["Godot source resolver", /resolve_godot_source_for_arkit/],
			["default prepared source path", /\.godot\/cache\/c00\/godot-source/],
			["Godot source version resolver", /resolve_template_version/],
			["Godot source match helper", /is_matching_godot_source/],
			["Godot source mismatch fail", /Godot source version mismatch/],
			["automatic source preparation env", /AUTO_PREPARE_GODOT_SOURCE/],
			["dry-run source resolution", /DRY_RUN/],
			["Godot tag env", /GODOT_TAG/],
			["uses source helper", /prepare_godot_source\.sh/],
			["exports Godot source env", /export GODOT_SOURCE_DIR/],
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
