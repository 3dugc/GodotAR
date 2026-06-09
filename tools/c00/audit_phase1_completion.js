#!/usr/bin/env node

const fs = require("fs");
const os = require("os");
const path = require("path");
const { spawnSync } = require("child_process");

const PROJECT_ROOT = path.resolve(__dirname, "../..");
const DEFAULT_EVIDENCE_DIR = path.join(PROJECT_ROOT, "releases/phase_0_smoke/evidence");
const DEFAULT_REPORT = path.join(PROJECT_ROOT, "releases/phase_0_smoke/C00_COMPLETION_AUDIT.md");
const DEFAULT_JSON = path.join(PROJECT_ROOT, "releases/phase_0_smoke/C00_COMPLETION_AUDIT.json");

const args = parseArgs(process.argv.slice(2));

if (args.help || args.h) {
	usage();
	process.exit(0);
}

const evidenceDir = path.resolve(args.dir || DEFAULT_EVIDENCE_DIR);
const reportPath = path.resolve(args.report || DEFAULT_REPORT);
const jsonPath = args.json ? path.resolve(String(args.json)) : DEFAULT_JSON;
const skipPreflight = flagEnabled(args["skip-preflight"]);
const skipEvidence = flagEnabled(args["skip-evidence"]);
const includePlaceDemos = !flagEnabled(args["skip-place-demos"]);
const timeoutMs = Number(args.timeout || 120000);

const audit = runAudit();
fs.mkdirSync(path.dirname(reportPath), { recursive: true });
fs.writeFileSync(reportPath, renderMarkdown(audit), "utf8");
if (jsonPath) {
	fs.mkdirSync(path.dirname(jsonPath), { recursive: true });
	fs.writeFileSync(jsonPath, JSON.stringify(audit, null, 2) + "\n", "utf8");
}

console.log(JSON.stringify({
	pass: audit.pass,
	phaseReady: audit.phaseReady,
	status: audit.status,
	report: reportPath,
	json: jsonPath,
	failures: audit.failures,
	warnings: audit.warnings,
}, null, 2));
process.exit(audit.pass ? 0 : 1);


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
		"  node tools/c00/audit_phase1_completion.js [options]",
		"",
		"Options:",
		"  --dir <evidence-dir>       Evidence directory. Default: releases/phase_0_smoke/evidence",
		"  --report <file>            Markdown audit report. Default: releases/phase_0_smoke/C00_COMPLETION_AUDIT.md",
		"  --json <file>              JSON audit report. Default: releases/phase_0_smoke/C00_COMPLETION_AUDIT.json",
		"  --skip-preflight           Skip device-machine preflight commands.",
		"  --skip-evidence            Skip final device evidence verification.",
		"  --include-place-demos      Require Rokid/iPad placement demo preflight and evidence. Default.",
		"  --skip-place-demos         Only require base Rokid/iPad/Android smoke gates.",
		"  --timeout <ms>             Per-command timeout. Default: 120000.",
		"",
		"The audit exits 0 only when C00/phase-1 is actually ready: static gates pass,",
		"Rokid/OpenXR + iPad/ARKit + Android/ARCore preflight pass, ARKit binary artifacts",
		"are present, and final device evidence verifies through verify_phase_evidence.js.",
		"By default this also requires C02/C04 Rokid/iPad placement demo evidence.",
		"With --skip-preflight or --skip-evidence, passing checks report PARTIAL and do not",
		"mean phase 1 is complete.",
	].join("\n"));
}


function flagEnabled(value) {
	return value === true || value === "" || value === "1" || value === "true" || value === "yes";
}


function runAudit() {
	const generatedAt = new Date().toISOString();
	const checks = [];

	addCommand(checks, {
		id: "static-gates",
		group: "static",
		title: "C00 static gates",
		required: true,
		command: ["node", "tools/c00/run_static_gates.js", "--gate", "all", "--format", "json"],
		success: "All code/static/API/export-surface gates pass.",
		failure: "Fix static gate failures before trying device exports.",
	});

	addCommand(checks, {
		id: "arfoundation-api",
		group: "unity-migration",
		title: "ARFoundation migration API surface",
		required: true,
		command: ["node", "tools/c00/check_arfoundation_api_surface.js"],
		success: "Unity-style ARSession, raycast, trackables, and changed-event facades are present.",
		failure: "Restore ARFoundation migration aliases before device work.",
	});

	addCommand(checks, {
		id: "xri-api",
		group: "unity-migration",
		title: "XRI interaction API surface",
		required: true,
		command: ["node", "tools/c00/check_xri_api_surface.js"],
		success: "Unity XRI-style manager/ray/interactable smoke surface is present.",
		failure: "Restore XRI migration aliases before publishing phase 1.",
	});

	addCommand(checks, {
		id: "arkit-binary",
		group: "ios",
		title: "GodotARKit plugin binary artifacts",
		required: true,
		command: ["node", "tools/c00/check_ios_plugin_artifacts.js", "--require-binary"],
		success: "GodotARKit.gdip and GodotARKit.xcframework are built and usable by Godot iOS export.",
		failure: "Build the iOS plugin with GODOT_SOURCE_DIR=/path/to/godot ios/plugins/godot_arkit/build_xcframework.sh.",
	});

	addCommand(checks, {
		id: "openxr-surface",
		group: "rokid-openxr",
		title: "Rokid/OpenXR provider evidence surface",
		required: true,
		command: ["node", "tools/c00/check_openxr_provider_surface.js"],
		success: "OpenXR AR evidence, passthrough report, and virtual-plane fallback diagnostics are guarded.",
		failure: "Restore OpenXR provider diagnostics before running Rokid.",
	});

	addCommand(checks, {
		id: "arcore-surface",
		group: "android-arcore",
		title: "Android ARCore plugin and gate surface",
		required: true,
		command: ["node", "tools/c00/check_arcore_gate_surface.js"],
		success: "ARCore gate requires explicit native ARCore runtime/capability evidence.",
		failure: "Restore Android ARCore evidence checks before publishing phase 1.",
	});

	const preflightGates = ["rokid", "ipad", "android-arcore"];
	if (includePlaceDemos) {
		preflightGates.push("rokid-place", "ipad-place");
	}
	if (!skipPreflight) {
		for (const gate of preflightGates) {
			addCommand(checks, {
				id: `preflight-${gate}`,
				group: "device-machine",
				title: `${gate} preflight`,
				required: true,
				command: ["bash", "tools/c00/preflight.sh", gate],
				success: `${gate} export/device prerequisites are present on this machine.`,
				failure: `${gate} cannot be considered runnable until preflight passes on the device machine.`,
			});
		}
	}

	if (!skipEvidence) {
		const phaseReport = path.join(os.tmpdir(), `godotar-c00-phase-evidence-${Date.now()}.md`);
		const evidenceGates = ["rokid", "ipad", "android-arcore"];
		if (includePlaceDemos) {
			evidenceGates.push("rokid-place", "ipad-place");
		}
		const gateArgs = evidenceGates.flatMap((gate) => ["--gate", gate]);
		addCommand(checks, {
			id: "phase-evidence",
			group: "device-evidence",
			title: includePlaceDemos ? "Rokid/iPad/Android phase evidence plus placement demos" : "Rokid/iPad/Android phase evidence",
			required: true,
			command: [
				"node",
				"tools/c00/verify_phase_evidence.js",
				"--dir",
				evidenceDir,
				"--report",
				phaseReport,
				...gateArgs,
			],
			success: includePlaceDemos
				? "Rokid/OpenXR, iPad/ARKit, Android/ARCore, and C02/C04 placement logs/media/device profiles all verify."
				: "Rokid/OpenXR, iPad/ARKit, and Android/ARCore logs/media/device profiles all verify.",
			failure: "Collect or import real device evidence, then rerun this audit.",
		});
	}

	const failures = checks
		.filter((check) => check.required && check.status !== "PASS")
		.map((check) => `${check.title}: ${check.nextAction}`);
	const warnings = checks
		.filter((check) => !check.required && check.status !== "PASS")
		.map((check) => `${check.title}: ${check.nextAction}`);

	const selectedChecksPass = failures.length === 0;
	const skippedRequiredCompletionGate = skipPreflight || skipEvidence;
	const phaseReady = selectedChecksPass && !skippedRequiredCompletionGate;

	return {
		pass: selectedChecksPass,
		phaseReady,
		status: phaseReady ? "READY" : (selectedChecksPass ? "PARTIAL" : "NOT_READY"),
		generatedAt,
		projectRoot: PROJECT_ROOT,
		evidenceDir,
		reportPath,
		jsonPath,
		skipPreflight,
		skipEvidence,
		includePlaceDemos,
		failures,
		warnings,
		checks,
	};
}


function addCommand(checks, definition) {
	const result = spawnSync(definition.command[0], definition.command.slice(1), {
		cwd: PROJECT_ROOT,
		encoding: "utf8",
		timeout: timeoutMs,
	});
	const output = [result.stdout || "", result.stderr || ""].join("").trim();
	const timedOut = result.error && result.error.code === "ETIMEDOUT";
	checks.push({
		id: definition.id,
		group: definition.group,
		title: definition.title,
		required: definition.required,
		command: definition.command.join(" "),
		status: result.status === 0 ? "PASS" : (definition.required ? "FAIL" : "WARN"),
		exitCode: result.status,
		timedOut,
		summary: result.status === 0 ? definition.success : definition.failure,
		nextAction: result.status === 0 ? "" : definition.failure,
		outputPreview: previewOutput(output || String(result.error || "")),
	});
}


function previewOutput(output) {
	if (!output) {
		return "";
	}
	const lines = output.split(/\r?\n/);
	const maxLines = 28;
	const selected = lines.slice(0, maxLines);
	if (lines.length > maxLines) {
		selected.push(`... (${lines.length - maxLines} more lines)`);
	}
	return selected.join("\n");
}


function renderMarkdown(audit) {
	const lines = [];
	lines.push("# C00 Phase 1 Completion Audit");
	lines.push("");
	lines.push(`Generated: ${audit.generatedAt}`);
	lines.push("");
	lines.push(`Result: ${audit.status}`);
	lines.push("");
	lines.push(`Project: \`${audit.projectRoot}\``);
	lines.push("");
	lines.push(`Evidence: \`${audit.evidenceDir}\``);
	lines.push("");
	lines.push("## Verdict");
	lines.push("");
	if (audit.pass) {
		if (audit.phaseReady) {
			lines.push("Phase 1 is ready: all required code, preflight, and device evidence gates passed.");
		} else {
			lines.push("Selected checks passed, but phase 1 is not complete because one or more completion gates were skipped.");
		}
	} else {
		lines.push("Phase 1 is not ready. Do not publish C00 as complete until every required item below passes.");
	}
	lines.push("");
	lines.push("## Required Checks");
	lines.push("");
	lines.push("| Status | Group | Check | Next action |");
	lines.push("| --- | --- | --- | --- |");
	for (const check of audit.checks) {
		lines.push(`| ${check.status} | ${escapeMd(check.group)} | ${escapeMd(check.title)} | ${escapeMd(check.nextAction || check.summary)} |`);
	}
	lines.push("");
	if (audit.failures.length > 0) {
		lines.push("## Blocking Items");
		lines.push("");
		for (const failure of audit.failures) {
			lines.push(`- ${failure}`);
		}
		lines.push("");
	}
	lines.push("## Command Output Preview");
	lines.push("");
	for (const check of audit.checks) {
		if (!check.outputPreview) {
			continue;
		}
		lines.push(`### ${check.title}`);
		lines.push("");
		lines.push(`Command: \`${check.command}\``);
		lines.push("");
		lines.push("```text");
		lines.push(check.outputPreview);
		lines.push("```");
		lines.push("");
	}
	while (lines[lines.length - 1] === "") {
		lines.pop();
	}
	return lines.join("\n") + "\n";
}


function escapeMd(value) {
	return String(value).replace(/\|/g, "\\|").replace(/\n/g, " ");
}
