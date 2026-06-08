#!/usr/bin/env node

const fs = require("fs");
const path = require("path");

const args = parseArgs(process.argv.slice(2));

if (!args.gate) {
	usage();
	process.exit(2);
}

const gate = String(args.gate).toLowerCase();
const allowMissingMedia = Boolean(args["allow-missing-media"]);
const reportPath = args.report ? path.resolve(args.report) : "";
const minBytes = Number(args["min-bytes"] || 1024);

const media = [
	mediaEntry("screenshot", args.screenshot),
	mediaEntry("video", args.video),
	mediaEntry("manual-media", args["manual-media"]),
].filter(Boolean);

const result = evaluateEvidence(gate, media, { allowMissingMedia, minBytes });
const summary = {
	gate,
	pass: result.pass,
	failures: result.failures,
	warnings: result.warnings,
	media: result.media,
	minBytes,
};

console.log(JSON.stringify(summary, null, 2));

if (reportPath) {
	fs.mkdirSync(path.dirname(reportPath), { recursive: true });
	appendMarkdownReport(reportPath, summary);
}

process.exit(result.pass ? 0 : 1);


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
		"  node tools/c00/validate_evidence_bundle.js --gate <rokid|ipad|android-arcore> [--screenshot <file>] [--video <file>] [--manual-media <file>] [--report <file>]",
		"",
		"Options:",
		"  --allow-missing-media   Downgrade missing media evidence from failure to warning.",
		"  --min-bytes <bytes>     Minimum non-empty media file size. Default: 1024.",
	].join("\n"));
}


function mediaEntry(kind, value) {
	if (!value) {
		return null;
	}
	const absolutePath = path.resolve(String(value));
	let exists = false;
	let bytes = 0;
	try {
		const stats = fs.statSync(absolutePath);
		exists = stats.isFile();
		bytes = exists ? stats.size : 0;
	} catch (error) {
		exists = false;
	}
	return {
		kind,
		path: absolutePath,
		exists,
		bytes,
	};
}


function evaluateEvidence(gate, media, options) {
	const failures = [];
	const warnings = [];
	const goodMedia = media.filter((item) => item.exists && item.bytes >= options.minBytes);

	for (const item of media) {
		if (!item.exists) {
			recordProblem(`${item.kind} evidence is missing: ${item.path}`);
		} else if (item.bytes < options.minBytes) {
			recordProblem(`${item.kind} evidence is too small (${item.bytes} bytes): ${item.path}`);
		}
	}

	if (gate === "rokid" || gate === "android-arcore") {
		requireKind("screenshot", `${gate} gate requires a screenshot artifact.`);
		requireKind("video", `${gate} gate requires a screen recording artifact.`);
	} else if (gate === "ipad") {
		if (!hasAnyGoodMedia()) {
			recordProblem("iPad gate requires at least one screenshot, screen recording, or manual media artifact.");
		}
	} else {
		recordProblem(`Unknown gate: ${gate}`);
	}

	return {
		pass: failures.length === 0,
		failures,
		warnings,
		media,
	};

	function requireKind(kind, message) {
		if (!goodMedia.some((item) => item.kind === kind)) {
			recordProblem(message);
		}
	}

	function hasAnyGoodMedia() {
		return goodMedia.length > 0;
	}

	function recordProblem(message) {
		if (options.allowMissingMedia) {
			warnings.push(message);
		} else {
			failures.push(message);
		}
	}
}


function appendMarkdownReport(reportPath, summary) {
	const lines = [];
	lines.push("");
	lines.push("## Evidence Bundle");
	lines.push("");
	lines.push(`Result: ${summary.pass ? "PASS" : "FAIL"}`);
	lines.push("");
	lines.push("### Media");
	lines.push("");
	if (summary.media.length === 0) {
		lines.push("- None");
	} else {
		for (const item of summary.media) {
			const state = item.exists ? `${item.bytes} bytes` : "missing";
			lines.push(`- ${item.kind}: \`${item.path}\` (${state})`);
		}
	}
	lines.push("");
	lines.push("### Evidence Failures");
	lines.push("");
	if (summary.failures.length === 0) {
		lines.push("- None");
	} else {
		for (const failure of summary.failures) {
			lines.push(`- ${failure}`);
		}
	}
	lines.push("");
	lines.push("### Evidence Warnings");
	lines.push("");
	if (summary.warnings.length === 0) {
		lines.push("- None");
	} else {
		for (const warning of summary.warnings) {
			lines.push(`- ${warning}`);
		}
	}
	lines.push("");
	fs.appendFileSync(reportPath, lines.join("\n"), "utf8");
}
