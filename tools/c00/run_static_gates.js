#!/usr/bin/env node

const fs = require("fs");
const path = require("path");
const { spawnSync } = require("child_process");

const PROJECT_ROOT = path.resolve(__dirname, "../..");
const args = parseArgs(process.argv.slice(2));
const gate = String(args.gate || "all").toLowerCase();
const reportPath = args.report ? path.resolve(args.report) : "";
const format = String(args.format || (reportPath ? "markdown" : "json")).toLowerCase();

if (args.help || args.h) {
	usage();
	process.exit(0);
}

if (!["all", "editor", "rokid", "ipad", "ios-simulator", "android-arcore"].includes(gate)) {
	usage();
	process.exit(2);
}

const checks = [
	...nodeSyntaxChecks(),
	...shellSyntaxChecks(),
	{
		name: "Godot project/static scene references",
		command: ["node", "tools/c00/check_godot_project_static.js"],
		required: true,
	},
	{
		name: "Launch platform evidence surface",
		command: ["node", "tools/c00/check_launch_platform_surface.js"],
		required: true,
	},
	{
		name: "Device collector diagnostics surface",
		command: ["node", "tools/c00/check_device_collector_diagnostics_surface.js"],
		required: true,
	},
	{
		name: "Device readiness wait surface",
		command: ["node", "tools/c00/check_device_ready_surface.js"],
		required: true,
	},
	{
		name: "EditorSim collector surface",
		command: ["node", "tools/c00/check_editor_smoke_surface.js"],
		required: true,
	},
	{
		name: "Device dependency bundle surface",
		command: ["node", "tools/c00/check_device_dependency_bundle_surface.js"],
		required: true,
	},
	{
		name: "Device handoff package surface",
		command: ["node", "tools/c00/check_device_handoff_surface.js"],
		required: true,
	},
	{
		name: "Phase 1 completion audit surface",
		command: ["node", "tools/c00/check_phase1_completion_audit_surface.js"],
		required: true,
	},
	{
		name: "Phase 1 device lab surface",
		command: ["node", "tools/c00/check_phase1_device_lab_surface.js"],
		required: true,
	},
	{
		name: "ARFoundation migration API surface",
		command: ["node", "tools/c00/check_arfoundation_api_surface.js"],
		required: true,
	},
	{
		name: "XRI interaction API surface",
		command: ["node", "tools/c00/check_xri_api_surface.js"],
		required: true,
	},
	...(needsOpenXR(gate) ? [{
		name: "Rokid/OpenXR export surface",
		command: ["node", "tools/c00/check_rokid_openxr_export_surface.js"],
		required: true,
	}, {
		name: "OpenXR/Rokid AR evidence surface",
		command: ["node", "tools/c00/check_openxr_provider_surface.js"],
		required: true,
	}] : []),
	...(needsARCore(gate) ? [{
		name: "GodotARCore Android plugin surface",
		command: ["node", "tools/c00/check_android_arcore_plugin_surface.js"],
		required: true,
	}, {
		name: "Android ARCore gate surface",
		command: ["node", "tools/c00/check_arcore_gate_surface.js"],
		required: true,
	}] : []),
	...(needsAndroidExport(gate) ? [{
		name: "Android export environment surface",
		command: ["node", "tools/c00/check_android_export_environment_surface.js"],
		required: true,
	}] : []),
	...(needsIOS(gate) ? [
		{
			name: "iPad Godot source preparation surface",
			command: ["node", "tools/c00/check_ios_godot_source_surface.js"],
			required: true,
		},
		{
			name: "GodotARKit plugin config surface",
			command: ["node", "tools/c00/check_ios_plugin_artifacts.js"],
			required: true,
		},
		{
			name: "iOS ARKit placement demo surface",
			command: ["node", "tools/c00/check_ios_arkit_place_surface.js"],
			required: true,
		},
		{
			name: "iPad device profile analysis surface",
			command: ["node", "tools/c00/check_ios_device_profile_surface.js"],
			required: true,
		},
		{
			name: "ARKit Objective-C++ syntax smoke",
			command: ["bash", "tools/c00/check_arkit_plugin_static.sh"],
			required: true,
		},
	] : []),
	...(needsExportPresets(gate) ? [{
		name: "export_presets.cfg C00 gate config",
		command: ["node", "tools/c00/check_export_presets.js", "--gate", gate, "--file", "export_presets.cfg"],
		required: false,
		skipIfMissing: "export_presets.cfg",
	}] : []),
	{
		name: "git diff whitespace",
		command: ["git", "diff", "--check"],
		required: false,
		skipIfMissingCommand: "git",
	},
];

const results = checks.map(runCheck);
const failures = results.filter((result) => result.status === "FAIL");
const warnings = results.filter((result) => result.status === "WARN");
const summary = {
	pass: failures.length === 0,
	gate,
	projectRoot: PROJECT_ROOT,
	failures: failures.map((result) => result.name),
	warnings: warnings.map((result) => result.name),
	results,
};

const output = format === "markdown" ? renderMarkdown(summary) : JSON.stringify(summary, null, 2);
if (reportPath) {
	fs.mkdirSync(path.dirname(reportPath), { recursive: true });
	fs.writeFileSync(reportPath, output + "\n", "utf8");
}
console.log(output);
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
		"  node tools/c00/run_static_gates.js [--gate all|editor|rokid|ipad|ios-simulator|android-arcore] [--report <file>] [--format json|markdown]",
		"",
		"Runs C00 static gates that do not require a Godot export or connected devices.",
	].join("\n"));
}


function nodeSyntaxChecks() {
	return listFiles("tools/c00", (file) => file.endsWith(".js"))
		.map((file) => ({
			name: `node --check ${file}`,
			command: ["node", "--check", file],
			required: true,
		}));
}


function shellSyntaxChecks() {
	const files = [
		...listFiles("tools/c00", (file) => file.endsWith(".sh")),
		"ios/plugins/godot_arkit/build_xcframework.sh",
		"android/plugins/godot_arcore/build_plugin.sh",
	];
	return files.map((file) => ({
		name: `bash -n ${file}`,
		command: ["bash", "-n", file],
		required: true,
		skipIfMissingCommand: "bash",
	}));
}


function listFiles(relativeDir, predicate) {
	const absoluteDir = path.join(PROJECT_ROOT, relativeDir);
	if (!fs.existsSync(absoluteDir)) {
		return [];
	}
	return fs.readdirSync(absoluteDir)
		.map((name) => path.join(relativeDir, name))
		.filter((file) => fs.statSync(path.join(PROJECT_ROOT, file)).isFile())
		.filter(predicate)
		.sort();
}


function runCheck(check) {
	if (check.skipIfMissing && !fs.existsSync(path.join(PROJECT_ROOT, check.skipIfMissing))) {
		return {
			name: check.name,
			status: check.required ? "FAIL" : "WARN",
			command: check.command.join(" "),
			output: `Missing optional input: ${check.skipIfMissing}`,
		};
	}
	if (check.skipIfMissingCommand && !commandExists(check.skipIfMissingCommand)) {
		return {
			name: check.name,
			status: check.required ? "FAIL" : "WARN",
			command: check.command.join(" "),
			output: `Missing command: ${check.skipIfMissingCommand}`,
		};
	}
	const result = spawnSync(check.command[0], check.command.slice(1), {
		cwd: PROJECT_ROOT,
		encoding: "utf8",
	});
	const output = [result.stdout || "", result.stderr || ""].join("").trim();
	if (result.status === 0) {
		return {
			name: check.name,
			status: "PASS",
			command: check.command.join(" "),
			output,
		};
	}
	return {
		name: check.name,
		status: check.required ? "FAIL" : "WARN",
		command: check.command.join(" "),
		exitCode: result.status,
		output: output || String(result.error || ""),
	};
}


function commandExists(commandName) {
	const result = spawnSync("command", ["-v", commandName], {
		cwd: PROJECT_ROOT,
		encoding: "utf8",
		shell: true,
	});
	return result.status === 0;
}


function needsOpenXR(targetGate) {
	return targetGate === "all" || targetGate === "rokid";
}


function needsARCore(targetGate) {
	return targetGate === "all" || targetGate === "android-arcore";
}


function needsAndroidExport(targetGate) {
	return targetGate === "all" || targetGate === "rokid" || targetGate === "android-arcore";
}


function needsIOS(targetGate) {
	return targetGate === "all" || targetGate === "ipad" || targetGate === "ios-simulator";
}


function needsExportPresets(targetGate) {
	return !["editor"].includes(targetGate);
}


function renderMarkdown(summary) {
	const lines = [];
	lines.push(`# C00 Static Gate Report: ${summary.gate}`);
	lines.push("");
	lines.push(`Result: ${summary.pass ? "PASS" : "FAIL"}`);
	lines.push("");
	lines.push(`Project: \`${summary.projectRoot}\``);
	lines.push("");
	lines.push("| Status | Check | Command |");
	lines.push("| --- | --- | --- |");
	for (const result of summary.results) {
		lines.push(`| ${result.status} | ${escapeMarkdownTable(result.name)} | \`${escapeBackticks(result.command)}\` |`);
	}
	lines.push("");
	if (summary.failures.length > 0) {
		lines.push("## Failures");
		lines.push("");
		for (const result of summary.results.filter((item) => item.status === "FAIL")) {
			lines.push(`### ${result.name}`);
			lines.push("");
			lines.push("```text");
			lines.push(result.output || `exit ${result.exitCode}`);
			lines.push("```");
			lines.push("");
		}
	}
	if (summary.warnings.length > 0) {
		lines.push("## Warnings");
		lines.push("");
		for (const result of summary.results.filter((item) => item.status === "WARN")) {
			lines.push(`- ${result.name}: ${result.output || "warning"}`);
		}
	}
	return lines.join("\n");
}


function escapeMarkdownTable(value) {
	return String(value).replace(/\|/g, "\\|").replace(/\r?\n/g, " ");
}


function escapeBackticks(value) {
	return String(value).replace(/`/g, "\\`");
}
