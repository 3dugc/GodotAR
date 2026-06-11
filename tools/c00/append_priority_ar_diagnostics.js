#!/usr/bin/env node

const fs = require("fs");
const path = require("path");

const PROJECT_ROOT = path.resolve(__dirname, "../..");
const DEFAULT_EVIDENCE_DIR = path.join(PROJECT_ROOT, "releases/phase_0_smoke/evidence");
const DEFAULT_REPORT = path.join(PROJECT_ROOT, "releases/phase_0_smoke/C01_PRIORITY_AR_REPORT.md");
const args = parseArgs(process.argv.slice(2));

if (args.help || args.h) {
	usage();
	process.exit(0);
}

const evidenceDir = path.resolve(args.dir || DEFAULT_EVIDENCE_DIR);
const reportPath = path.resolve(args.report || DEFAULT_REPORT);
const generatedAt = new Date().toISOString();
const artifacts = buildArtifacts();

fs.mkdirSync(path.dirname(reportPath), { recursive: true });
if (!fs.existsSync(reportPath)) {
	fs.writeFileSync(reportPath, [
		"# C01 Priority AR Report",
		"",
		"Result: NOT_READY",
		"",
		"The priority AR evidence verifier did not create a report before diagnostics were appended.",
		"",
	].join("\n"), "utf8");
}
fs.appendFileSync(reportPath, renderMarkdown(), "utf8");

console.log(JSON.stringify({
	pass: true,
	report: reportPath,
	evidenceDir,
	artifacts: artifacts.map((item) => ({
		label: item.label,
		path: item.path,
		exists: item.exists,
		result: item.result,
		bytes: item.bytes,
	})),
}, null, 2));


function buildArtifacts() {
	const entries = [
		{
			label: "Priority readiness report",
			path: resolveOptional(args["readiness-report"]),
			notes: "bootstrap_device_machine summary for this priority run",
		},
		{
			label: "Priority static gates report",
			path: resolveOptional(args["static-report"]),
			notes: "static/API/plugin gate summary for this priority run",
		},
		{
			label: "Latest iPad readiness",
			path: latestMarkdown(/^device-ready-ipad(?:-[A-Za-z0-9_.-]+)?-\d{8}-\d{6}\.md$/),
			notes: "selected iPad, offline/unavailable, lock, DDI, and app-install readiness",
		},
		{
			label: "Latest Rokid readiness",
			path: latestMarkdown(/^device-ready-rokid(?:-[A-Za-z0-9_.-]+)?-\d{8}-\d{6}\.md$/),
			notes: "ADB transport readiness for the Rokid/OpenXR lane",
		},
		{
			label: "Latest iPad DDI recovery",
			path: latestMarkdown(/^ipad-ddi-recovery-\d{8}-\d{6}\.md$/),
			notes: "devicectl DDI auto-mount attempt and next actions",
		},
		{
			label: "Latest Rokid ADB recovery",
			path: latestMarkdown(/^android-adb-recovery-rokid(?:-place)?-\d{8}-\d{6}\.md$/),
			notes: "ADB server restart, transport listing, and next actions",
		},
		{
			label: "Latest iPad smoke log",
			path: latestFile(/^ipad-\d{8}-\d{6}\.log$/),
			notes: "base iPad/ARKit runtime log when the app launches",
		},
		{
			label: "Latest iPad placement log",
			path: latestFile(/^ipad-place-\d{8}-\d{6}\.log$/),
			notes: "C04 iPad/ARKit placement log when available",
		},
		{
			label: "Latest Rokid smoke log",
			path: latestFile(/^rokid-\d{8}-\d{6}\.log$/),
			notes: "base Rokid/OpenXR runtime log when the app launches",
		},
		{
			label: "Latest Rokid placement log",
			path: latestFile(/^rokid-place-\d{8}-\d{6}\.log$/),
			notes: "C02 Rokid/OpenXR placement log when available",
		},
	];

	return entries.map((entry) => enrichArtifact(entry));
}


function resolveOptional(value) {
	return value ? path.resolve(String(value)) : "";
}


function latestMarkdown(pattern) {
	return latestFile(pattern);
}


function latestFile(pattern) {
	if (!fs.existsSync(evidenceDir)) {
		return "";
	}
	const matches = fs.readdirSync(evidenceDir)
		.filter((name) => pattern.test(name))
		.map((name) => path.join(evidenceDir, name))
		.filter((filePath) => fs.statSync(filePath).isFile())
		.sort((left, right) => fs.statSync(right).mtimeMs - fs.statSync(left).mtimeMs);
	return matches[0] || "";
}


function enrichArtifact(entry) {
	const output = {
		label: entry.label,
		path: entry.path || "",
		notes: entry.notes || "",
		exists: false,
		bytes: 0,
		modified: "",
		result: "missing",
	};
	if (!output.path || !fs.existsSync(output.path)) {
		return output;
	}
	const stat = fs.statSync(output.path);
	output.exists = true;
	output.bytes = stat.size;
	output.modified = stat.mtime.toISOString();
	output.result = inferResult(output.path);
	return output;
}


function inferResult(filePath) {
	const extension = path.extname(filePath).toLowerCase();
	if (extension !== ".md") {
		return "available";
	}
	const text = fs.readFileSync(filePath, "utf8");
	const result = text.match(/^Result:\s*(PASS|FAIL|READY|NOT_READY)\s*$/mi);
	if (result) {
		return result[1];
	}
	const status = text.match(/^Status:\s*(READY|NOT_READY|PASS|FAIL)\s*$/mi);
	if (status) {
		return status[1];
	}
	return "available";
}


function renderMarkdown() {
	const lines = [];
	lines.push("");
	lines.push("## Priority Lane Diagnostics");
	lines.push("");
	lines.push(`Generated: ${generatedAt}`);
	lines.push("");
	lines.push("This section is appended by `tools/c00/append_priority_ar_diagnostics.js`. It summarizes the readiness, recovery, and latest runtime artifacts that explain why the priority iPad/Rokid lane passed or remained NOT_READY. It does not weaken the required real-device evidence gates above.");
	lines.push("");
	lines.push("| Artifact | Result | Path | Notes |");
	lines.push("| --- | --- | --- | --- |");
	for (const item of artifacts) {
		const result = item.exists ? item.result : "missing";
		const filePath = item.path ? relativePath(item.path) : "";
		lines.push(`| ${escapeCell(item.label)} | ${escapeCell(result)} | ${filePath ? `\`${escapeCell(filePath)}\`` : ""} | ${escapeCell(item.notes)} |`);
	}
	lines.push("");
	lines.push("### Next Triage");
	lines.push("");
	lines.push("- If readiness reports are `FAIL`, fix the listed transport/device action before rerunning the priority lane.");
	lines.push("- If readiness is `PASS` but smoke or placement logs are missing, rerun the corresponding `ipad`, `ipad-place`, `rokid`, or `rokid-place` gate and inspect the collector report.");
	lines.push("- If logs exist but the evidence verifier still fails, import or capture the missing media/device-profile artifacts listed in the gate summary above.");
	lines.push("");
	return `${lines.join("\n")}\n`;
}


function relativePath(filePath) {
	const relative = path.relative(PROJECT_ROOT, filePath);
	if (!relative.startsWith("..") && !path.isAbsolute(relative)) {
		return relative;
	}
	return filePath;
}


function escapeCell(value) {
	return String(value || "").replace(/\|/g, "\\|").replace(/\r?\n/g, " ");
}


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
		"  node tools/c00/append_priority_ar_diagnostics.js [--report <file>] [--dir <evidence-dir>] [--readiness-report <file>] [--static-report <file>]",
		"",
		"Appends a diagnostic section to C01_PRIORITY_AR_REPORT.md linking the priority",
		"readiness, recovery, and latest iPad/Rokid smoke artifacts. This is reporting",
		"only; it does not change pass/fail evidence requirements.",
	].join("\n"));
}
