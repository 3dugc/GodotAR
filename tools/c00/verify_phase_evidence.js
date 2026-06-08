#!/usr/bin/env node

const fs = require("fs");
const path = require("path");

const PROJECT_ROOT = path.resolve(__dirname, "../..");
const DEFAULT_EVIDENCE_DIR = path.join(PROJECT_ROOT, "releases/phase_0_smoke/evidence");
const DEFAULT_REPORT = path.join(PROJECT_ROOT, "releases/phase_0_smoke/C00_PHASE_REPORT.md");
const REQUIRED_GATES = ["rokid", "ipad"];

const args = parseArgs(process.argv.slice(2));

if (args.help || args.h) {
	usage();
	process.exit(0);
}

const evidenceDir = path.resolve(args.dir || DEFAULT_EVIDENCE_DIR);
const reportPath = args.report ? path.resolve(args.report) : DEFAULT_REPORT;
const allowOpenXRWithoutARBlend = Boolean(args["allow-openxr-without-ar-blend"]);
const allowMissingMedia = Boolean(args["allow-missing-media"]);
const allowMissingDeviceProfile = Boolean(args["allow-missing-device-profile"]);
const minBytes = Number(args["min-bytes"] || 1024);
const gates = gatesFromArgs(args);

const summaries = gates.map((gate) => verifyGate(gate));
const failures = summaries.flatMap((summary) => summary.failures.map((failure) => `${summary.gate}: ${failure}`));
const warnings = summaries.flatMap((summary) => summary.warnings.map((warning) => `${summary.gate}: ${warning}`));
const pass = failures.length === 0;
const output = {
	pass,
	gates,
	evidenceDir,
	report: reportPath,
	failures,
	warnings,
	summaries,
};

fs.mkdirSync(path.dirname(reportPath), { recursive: true });
fs.writeFileSync(reportPath, renderMarkdown(output), "utf8");

console.log(JSON.stringify(output, null, 2));
process.exit(pass ? 0 : 1);


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
			if (parsed[key] === undefined) {
				parsed[key] = true;
			} else if (Array.isArray(parsed[key])) {
				parsed[key].push(true);
			} else {
				parsed[key] = [parsed[key], true];
			}
		} else {
			if (parsed[key] === undefined) {
				parsed[key] = next;
			} else if (Array.isArray(parsed[key])) {
				parsed[key].push(next);
			} else {
				parsed[key] = [parsed[key], next];
			}
			index += 1;
		}
	}
	return parsed;
}


function usage() {
	console.error([
		"Usage:",
		"  node tools/c00/verify_phase_evidence.js [--dir releases/phase_0_smoke/evidence] [--report releases/phase_0_smoke/C00_PHASE_REPORT.md]",
		"",
		"Options:",
		"  --gate <gate>                 Gate to require. Repeatable. Default: rokid + ipad.",
		"  --<gate>-log <file>           Explicit smoke log path.",
		"  --<gate>-screenshot <file>    Explicit screenshot path.",
		"  --<gate>-video <file>         Explicit recording path.",
		"  --<gate>-manual-media <file>  Explicit manual iPad media path.",
		"  --<gate>-device-profile <file>       Explicit device profile Markdown path.",
		"  --<gate>-device-profile-json <file>  Explicit device profile JSON path.",
		"  --allow-missing-media         Downgrade missing media from failure to warning.",
		"  --allow-missing-device-profile  Downgrade missing device profile evidence from failure to warning.",
		"  --allow-openxr-without-ar-blend  Downgrade Rokid ar_product_path=false to warning.",
		"  --min-bytes <bytes>           Minimum non-empty media file size. Default: 1024.",
	].join("\n"));
}


function gatesFromArgs(parsed) {
	if (!parsed.gate) {
		return REQUIRED_GATES;
	}
	const values = Array.isArray(parsed.gate) ? parsed.gate : [parsed.gate];
	return values.map((value) => String(value).toLowerCase());
}


function verifyGate(gate) {
	const files = resolveGateFiles(gate);
	const failures = [];
	const warnings = [];

	if (!files.log) {
		failures.push(`Missing smoke log. Expected ${gate}-*.log or --${gate}-log.`);
	}

	const smoke = files.log ? validateSmokeLog(gate, files.log) : null;
	if (smoke) {
		failures.push(...smoke.failures);
		warnings.push(...smoke.warnings);
	}

	const media = [
		mediaEntry("screenshot", files.screenshot),
		mediaEntry("video", files.video),
		mediaEntry("manual-media", files.manualMedia),
	].filter(Boolean);
	const evidence = validateEvidence(gate, media);
	failures.push(...evidence.failures);
	warnings.push(...evidence.warnings);

	const profile = validateDeviceProfile(gate, files.deviceProfile, files.deviceProfileJson);
	failures.push(...profile.failures);
	warnings.push(...profile.warnings);

	return {
		gate,
		pass: failures.length === 0,
		failures,
		warnings,
		files,
		smoke: smoke ? smoke.summary : null,
		media: evidence.media,
		deviceProfile: profile.summary,
	};
}


function resolveGateFiles(gate) {
	return {
		log: explicitOrLatest(gate, "log", "log"),
		screenshot: explicitOrLatest(gate, "screenshot", "png"),
		video: explicitOrLatest(gate, "video", "mp4"),
		manualMedia: explicitOrLatest(gate, "manual-media"),
		deviceProfile: explicitOrLatest(gate, "device-profile", "md"),
		deviceProfileJson: explicitOrLatest(gate, "device-profile-json", "json"),
	};
}


function explicitOrLatest(gate, argName, extension = "") {
	const key = `${gate}-${argName}`;
	if (args[key]) {
		return path.resolve(String(args[key]));
	}
	if (!fs.existsSync(evidenceDir)) {
		return "";
	}

	const extensions = extension ? [extension] : ["png", "jpg", "jpeg", "mp4", "mov"];
	const candidates = fs.readdirSync(evidenceDir)
		.filter((name) => name.startsWith(`${gate}-`))
		.filter((name) => argName !== "manual-media" || name.includes("-manual-media."))
		.filter((name) => argName !== "device-profile" || name.includes("-device."))
		.filter((name) => argName !== "device-profile-json" || name.includes("-device."))
		.filter((name) => extensions.includes(path.extname(name).slice(1).toLowerCase()))
		.map((name) => path.join(evidenceDir, name))
		.filter((filePath) => fs.statSync(filePath).isFile())
		.sort((left, right) => fs.statSync(right).mtimeMs - fs.statSync(left).mtimeMs);

	return candidates[0] || "";
}


function validateDeviceProfile(gate, markdownPath, jsonPath) {
	const failures = [];
	const warnings = [];
	const summary = {
		markdown: fileEvidence("device-profile", markdownPath),
		json: fileEvidence("device-profile-json", jsonPath),
		jsonPreview: null,
	};

	if (gate === "editor") {
		return { failures, warnings, summary };
	}

	requireProfile(summary.markdown, `${gate} gate requires a device profile Markdown artifact.`);
	requireProfile(summary.json, `${gate} gate requires a device profile JSON artifact.`);
	if (summary.json.exists && summary.json.bytes >= minBytes) {
		try {
			const parsed = JSON.parse(fs.readFileSync(summary.json.path, "utf8"));
			summary.jsonPreview = summarizeDeviceProfileJson(parsed);
		} catch (error) {
			recordProblem(`Device profile JSON is not parseable: ${summary.json.path}`);
		}
	}

	return { failures, warnings, summary };

	function requireProfile(item, message) {
		if (!item.path) {
			recordProblem(message);
		} else if (!item.exists) {
			recordProblem(`${item.kind} evidence is missing: ${item.path}`);
		} else if (item.bytes < minBytes) {
			recordProblem(`${item.kind} evidence is too small (${item.bytes} bytes): ${item.path}`);
		}
	}

	function recordProblem(message) {
		if (allowMissingDeviceProfile) {
			warnings.push(message);
		} else {
			failures.push(message);
		}
	}
}


function summarizeDeviceProfileJson(parsed) {
	if (!parsed || typeof parsed !== "object") {
		return parsed;
	}
	return {
		gate: parsed.gate || null,
		device: parsed.device || null,
		package: parsed.package || parsed.bundle_id || null,
		generated_at: parsed.generated_at || null,
		warnings: Array.isArray(parsed.warnings) ? parsed.warnings : [],
		selected_device: parsed.selected_device || null,
		target_package: parsed.target_package || null,
		target_app: parsed.target_app || null,
	};
}


function validateSmokeLog(gate, logPath) {
	let text = "";
	try {
		text = fs.readFileSync(logPath, "utf8");
	} catch (error) {
		return {
			failures: [`Cannot read smoke log: ${logPath}`],
			warnings: [],
			summary: null,
		};
	}

	const events = extractSmokeEvents(text);
	const result = evaluateSmokeEvents(events, gate);
	return {
		failures: result.failures,
		warnings: result.warnings,
		summary: {
			log: logPath,
			events: events.length,
			selectedEvidence: result.evidence,
			runtimeMetadata: result.evidence && result.evidence.runtime ? result.evidence.runtime : null,
		},
	};
}


function extractSmokeEvents(text) {
	const events = [];
	for (const line of text.split(/\r?\n/)) {
		const marker = "GXF_SMOKE|";
		const markerIndex = line.indexOf(marker);
		if (markerIndex === -1) {
			continue;
		}
		try {
			events.push(JSON.parse(line.slice(markerIndex + marker.length).trim()));
		} catch (error) {
			events.push({
				event: "parse_error",
				parse_error: String(error.message || error),
				raw_line: line,
			});
		}
	}
	return events;
}


function evaluateSmokeEvents(events, gate) {
	const failures = [];
	const warnings = [];
	if (events.length === 0) {
		failures.push("No GXF_SMOKE events found.");
		return { failures, warnings, evidence: null };
	}

	const parseErrors = events.filter((event) => event.event === "parse_error");
	if (parseErrors.length > 0) {
		failures.push(`${parseErrors.length} GXF_SMOKE line(s) failed JSON parsing.`);
	}

	const expectedBackend = backendForGate(gate);
	if (!expectedBackend) {
		failures.push(`Unknown gate: ${gate}`);
		return { failures, warnings, evidence: null };
	}

	const candidates = events.filter((event) => {
		return event.event !== "parse_error" && (
			event.session_state === "Running" ||
			event.event === "session_started" ||
			event.event === "heartbeat"
		);
	});
	if (candidates.length === 0) {
		failures.push("No running/session_started/heartbeat event found.");
	}

	const evidence = candidates.find((event) => event.backend === expectedBackend) || null;
	if (!evidence) {
		const observed = Array.from(new Set(events.map((event) => event.backend).filter(Boolean))).join(", ") || "none";
		failures.push(`Expected backend ${expectedBackend}, observed ${observed}.`);
		return { failures, warnings, evidence: null };
	}

	if (!evidence.provider || evidence.provider === "None") {
		failures.push("Provider is missing or None.");
	}
	if (!evidence.capabilities || typeof evidence.capabilities !== "object") {
		failures.push("Capabilities object is missing.");
	}
	if (!evidence.runtime || typeof evidence.runtime !== "object") {
		warnings.push("Runtime metadata is missing.");
	}
	if (!evidence.tracking || evidence.tracking === "None") {
		warnings.push("Tracking state is missing or None.");
	}

	if (gate === "rokid") {
		const arProductPath = Boolean(getCapability(evidence, "ar_product_path"));
		if (!arProductPath && allowOpenXRWithoutARBlend) {
			warnings.push("Rokid OpenXR is running, but ar_product_path=false. Treat as OpenXR smoke only, not AR product pass.");
		} else if (!arProductPath) {
			failures.push("Rokid gate requires capabilities.ar_product_path=true.");
		}
		const arTier = String(getCapability(evidence, "openxr_ar_tier") || "");
		if (!arTier) {
			warnings.push("Rokid gate should include capabilities.openxr_ar_tier.");
		} else if (arTier === "D") {
			failures.push("Rokid gate reports OpenXR AR tier D.");
		}
	}

	if ((gate === "ipad" || gate === "android-arcore") && !getCapability(evidence, "native_plugin")) {
		failures.push(`${gate} gate requires capabilities.native_plugin=true.`);
	}

	if (gate === "ipad") {
		const runtime = String(getCapability(evidence, "runtime") || evidence.runtime || "");
		const hasArkitEvidence = runtime === "ARKit" ||
			getCapability(evidence, "arkit_supported") === true ||
			evidence.provider === "ARKit";
		if (!hasArkitEvidence) {
			failures.push("iPad gate requires explicit ARKit evidence.");
		}
		if (!getCapability(evidence, "arkit_tracking_state")) {
			failures.push("iPad gate requires capabilities.arkit_tracking_state.");
		}
		if (!getCapability(evidence, "arkit_tracking_reason")) {
			failures.push("iPad gate requires capabilities.arkit_tracking_reason.");
		}
	}

	return { failures, warnings, evidence };
}


function validateEvidence(gate, media) {
	const failures = [];
	const warnings = [];
	const goodMedia = media.filter((item) => item.exists && item.bytes >= minBytes);

	for (const item of media) {
		if (!item.exists) {
			recordProblem(`${item.kind} evidence is missing: ${item.path}`);
		} else if (item.bytes < minBytes) {
			recordProblem(`${item.kind} evidence is too small (${item.bytes} bytes): ${item.path}`);
		}
	}

	if (gate === "rokid" || gate === "android-arcore") {
		requireKind("screenshot", `${gate} gate requires a screenshot artifact.`);
		requireKind("video", `${gate} gate requires a screen recording artifact.`);
	} else if (gate === "ipad") {
		if (goodMedia.length === 0) {
			recordProblem("iPad gate requires at least one screenshot, screen recording, or manual media artifact.");
		}
	} else if (gate === "editor") {
		if (media.length > 0 && goodMedia.length === 0) {
			recordProblem("Editor simulator media was provided but no valid media artifact was found.");
		}
	} else {
		recordProblem(`Unknown gate: ${gate}`);
	}

	return { failures, warnings, media };

	function requireKind(kind, message) {
		if (!goodMedia.some((item) => item.kind === kind)) {
			recordProblem(message);
		}
	}

	function recordProblem(message) {
		if (allowMissingMedia) {
			warnings.push(message);
		} else {
			failures.push(message);
		}
	}
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
	return { kind, path: absolutePath, exists, bytes };
}


function fileEvidence(kind, value) {
	if (!value) {
		return { kind, path: "", exists: false, bytes: 0 };
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
	return { kind, path: absolutePath, exists, bytes };
}


function backendForGate(gate) {
	switch (gate) {
		case "rokid":
			return "OpenXR";
		case "ipad":
			return "ARKit";
		case "android-arcore":
			return "ARCore";
		case "editor":
			return "EditorSim";
		default:
			return "";
	}
}


function getCapability(event, key) {
	if (!event.capabilities || typeof event.capabilities !== "object") {
		return undefined;
	}
	return event.capabilities[key];
}


function renderMarkdown(summary) {
	const lines = [];
	lines.push("# C00 Phase Evidence Report");
	lines.push("");
	lines.push(`Result: ${summary.pass ? "PASS" : "FAIL"}`);
	lines.push("");
	lines.push(`Evidence dir: \`${summary.evidenceDir}\``);
	lines.push("");
	lines.push("## Required Gates");
	lines.push("");
	for (const gate of summary.gates) {
		lines.push(`- ${gate}`);
	}
	lines.push("");
	lines.push("## Failures");
	lines.push("");
	if (summary.failures.length === 0) {
		lines.push("- None");
	} else {
		for (const failure of summary.failures) {
			lines.push(`- ${failure}`);
		}
	}
	lines.push("");
	lines.push("## Warnings");
	lines.push("");
	if (summary.warnings.length === 0) {
		lines.push("- None");
	} else {
		for (const warning of summary.warnings) {
			lines.push(`- ${warning}`);
		}
	}
	lines.push("");
	for (const gateSummary of summary.summaries) {
		lines.push(`## Gate: ${gateSummary.gate}`);
		lines.push("");
		lines.push(`Result: ${gateSummary.pass ? "PASS" : "FAIL"}`);
		lines.push("");
		lines.push("### Files");
		lines.push("");
		for (const [key, value] of Object.entries(gateSummary.files)) {
			lines.push(`- ${key}: ${value ? `\`${value}\`` : "missing"}`);
		}
		lines.push("");
		lines.push("### Runtime Metadata");
		lines.push("");
		lines.push("```json");
		lines.push(JSON.stringify(gateSummary.smoke ? gateSummary.smoke.runtimeMetadata || {} : {}, null, 2));
		lines.push("```");
		lines.push("");
		lines.push("### Media");
		lines.push("");
		if (gateSummary.media.length === 0) {
			lines.push("- None");
		} else {
			for (const item of gateSummary.media) {
				const state = item.exists ? `${item.bytes} bytes` : "missing";
				lines.push(`- ${item.kind}: \`${item.path}\` (${state})`);
			}
		}
		lines.push("");
		lines.push("### Device Profile");
		lines.push("");
		if (gateSummary.deviceProfile) {
			for (const item of [gateSummary.deviceProfile.markdown, gateSummary.deviceProfile.json]) {
				const state = item.exists ? `${item.bytes} bytes` : "missing";
				lines.push(`- ${item.kind}: ${item.path ? `\`${item.path}\`` : "missing"} (${state})`);
			}
			lines.push("");
			lines.push("```json");
			lines.push(JSON.stringify(gateSummary.deviceProfile.jsonPreview || {}, null, 2));
			lines.push("```");
		} else {
			lines.push("- None");
		}
		lines.push("");
		lines.push("### Selected Smoke Evidence");
		lines.push("");
		lines.push("```json");
		lines.push(JSON.stringify(gateSummary.smoke ? gateSummary.smoke.selectedEvidence || {} : {}, null, 2));
		lines.push("```");
		lines.push("");
	}
	return lines.join("\n");
}
