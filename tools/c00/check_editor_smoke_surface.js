#!/usr/bin/env node

const fs = require("fs");
const path = require("path");

const PROJECT_ROOT = path.resolve(__dirname, "../..");

if (process.argv.includes("--help") || process.argv.includes("-h")) {
	usage();
	process.exit(0);
}

const file = "tools/c00/collect_editor_smoke.sh";
const text = readText(path.join(PROJECT_ROOT, file));
const requirements = [
	["project-local Godot fallback", /DEFAULT_GODOT_BIN="\$PROJECT_ROOT\/\.godot\/cache\/c00\/godot-editor\/Godot\.app\/Contents\/MacOS\/Godot"/],
	["headless default", /EDITOR_HEADLESS="\$\{EDITOR_HEADLESS:-1\}"/],
	["native XR disabled by default", /EDITOR_XR_MODE="\$\{EDITOR_XR_MODE:-off\}"/],
	["headless argument assembly", /GODOT_ARGS=\(--headless "\$\{GODOT_ARGS\[@\]\}"\)/],
	["xr-mode argument assembly", /GODOT_ARGS\+=\(--xr-mode "\$EDITOR_XR_MODE"\)/],
	["simulator platform argument", /"--xr-platform=\$\{EDITOR_XR_PLATFORM\}"/],
	["project-local Godot log path", /GODOT_LOG_PATH="\$OUT_DIR\/editor-\$\{STAMP\}\.godot\.log"/],
	["explicit Godot log-file argument", /--log-file "\$GODOT_LOG_PATH"/],
];

const failures = [];
let passed = 0;

if (!text) {
	failures.push(`Missing required file: ${file}`);
} else {
	for (const [label, pattern] of requirements) {
		if (pattern.test(text)) {
			passed += 1;
		} else {
			failures.push(`${file}: missing ${label}`);
		}
	}
}

const summary = {
	pass: failures.length === 0,
	projectRoot: PROJECT_ROOT,
	failures,
	evidence: {
		file,
		exists: Boolean(text),
		passed,
		total: requirements.length,
	},
};

console.log(JSON.stringify(summary, null, 2));
process.exit(summary.pass ? 0 : 1);


function usage() {
	console.error([
		"Usage:",
		"  node tools/c00/check_editor_smoke_surface.js",
		"",
		"Checks that the local EditorSim collector defaults to a deterministic headless simulator run.",
	].join("\n"));
}


function readText(filePath) {
	try {
		return fs.readFileSync(filePath, "utf8");
	} catch (error) {
		return "";
	}
}
