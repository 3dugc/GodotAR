#!/usr/bin/env node

const fs = require("fs");
const path = require("path");

const args = parseArgs(process.argv.slice(2));

if (!args.log || !args.gate) {
	usage();
	process.exit(2);
}

const logPath = path.resolve(args.log);
const gate = String(args.gate).toLowerCase();
const allowOpenXRWithoutARBlend = Boolean(args["allow-openxr-without-ar-blend"]);
const reportPath = args.report ? path.resolve(args.report) : "";

const text = fs.readFileSync(logPath, "utf8");
const events = extractSmokeEvents(text);
const result = evaluateGate(events, gate, { allowOpenXRWithoutARBlend });
const scriptErrors = extractScriptErrors(text);
if (scriptErrors.length > 0) {
	result.failures.push(`${scriptErrors.length} Godot script/runtime error line(s) found in smoke log.`);
	result.scriptErrors = scriptErrors;
	result.pass = false;
}

const summary = {
	gate,
	log: logPath,
	pass: result.pass,
	failures: result.failures,
	warnings: result.warnings,
	scriptErrors,
	events: events.length,
	selectedEvidence: result.evidence,
	runtimeMetadata: result.evidence && result.evidence.runtime ? result.evidence.runtime : null,
};

console.log(JSON.stringify(summary, null, 2));

if (reportPath) {
	fs.mkdirSync(path.dirname(reportPath), { recursive: true });
	fs.writeFileSync(reportPath, renderMarkdownReport(summary), "utf8");
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
		"  node tools/c00/validate_smoke_log.js --gate <rokid|ipad|android-arcore|editor|ios-simulator|android-emulator> --log <file> [--report <file>]",
		"",
		"Options:",
		"  --allow-openxr-without-ar-blend   Downgrade Rokid ar_product_path=false from failure to warning.",
	].join("\n"));
}


function extractSmokeEvents(text) {
	const events = [];
	for (const line of text.split(/\r?\n/)) {
		const marker = "GXF_SMOKE|";
		const markerIndex = line.indexOf(marker);
		if (markerIndex === -1) {
			continue;
		}
		const jsonText = line.slice(markerIndex + marker.length).trim();
		try {
			events.push(JSON.parse(jsonText));
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


function extractScriptErrors(text) {
	const patterns = [
		/SCRIPT ERROR:/,
		/Parse Error:/,
		/Compile Error:/,
		/Compilation failed/,
		/Failed to load script/,
	];
	return text.split(/\r?\n/)
		.filter((line) => patterns.some((pattern) => pattern.test(line)))
		.slice(0, 20);
}


function evaluateGate(events, gate, options) {
	const failures = [];
	const warnings = [];

	if (events.length === 0) {
		failures.push("No GXF_SMOKE events found.");
		return { pass: false, failures, warnings, evidence: null };
	}

	const parseErrors = events.filter((event) => event.event === "parse_error");
	if (parseErrors.length > 0) {
		failures.push(`${parseErrors.length} GXF_SMOKE line(s) failed JSON parsing.`);
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

	const expectedBackend = backendForGate(gate);
	if (!expectedBackend) {
		failures.push(`Unknown gate: ${gate}`);
		return { pass: false, failures, warnings, evidence: null };
	}

	const evidence = candidates.find((event) => event.backend === expectedBackend) || null;
	if (!evidence) {
		const observed = Array.from(new Set(events.map((event) => event.backend).filter(Boolean))).join(", ") || "none";
		failures.push(`Expected backend ${expectedBackend}, observed ${observed}.`);
		return { pass: false, failures, warnings, evidence: null };
	}

	if (!evidence.provider || evidence.provider === "None") {
		failures.push("Provider is missing or None.");
	}

	if (!evidence.capabilities || typeof evidence.capabilities !== "object") {
		failures.push("Capabilities object is missing.");
	}

	if (!evidence.runtime || typeof evidence.runtime !== "object") {
		warnings.push("Runtime metadata is missing. New C00 logs should include Godot version, XR command-line args, and rendering/XR project settings.");
	}
	validateLaunchPlatformEvidence(evidence, gate, failures);
	if (!evidence.trackables || typeof evidence.trackables !== "object") {
		failures.push("Trackables metadata is missing from GXF_SMOKE evidence.");
	}

	if (!evidence.tracking || evidence.tracking === "None") {
		warnings.push("Tracking state is missing or None.");
	}
	if (!evidence.ar_session_state) {
		failures.push("Unity-style ar_session_state is missing from GXF_SMOKE evidence.");
	}
	if (!evidence.not_tracking_reason) {
		failures.push("Unity-style not_tracking_reason is missing from GXF_SMOKE evidence.");
	}

	if (gate === "rokid") {
		const arProductPath = Boolean(getCapability(evidence, "ar_product_path"));
		if (!arProductPath && options.allowOpenXRWithoutARBlend) {
			warnings.push("Rokid OpenXR is running, but ar_product_path=false. Treat as OpenXR smoke only, not AR product pass.");
		} else if (!arProductPath) {
			failures.push("Rokid gate requires capabilities.ar_product_path=true to avoid accepting an opaque VR path as AR.");
		}
		const arTier = String(getCapability(evidence, "openxr_ar_tier") || "");
		if (!arTier) {
			warnings.push("Rokid gate should include capabilities.openxr_ar_tier for AR-vs-VR diagnosis.");
		} else if (arTier === "D") {
			failures.push("Rokid gate reports OpenXR AR tier D, which is VR-only and not an AR product path.");
		}
		const arEvidence = getCapability(evidence, "openxr_ar_evidence");
		if (!Array.isArray(arEvidence) || arEvidence.length === 0) {
			failures.push("Rokid gate requires capabilities.openxr_ar_evidence so AR product proof is tied to blend mode or vendor passthrough evidence.");
		}
	}

	if (gate === "ipad" || gate === "android-arcore") {
		if (!getCapability(evidence, "native_plugin")) {
			failures.push(`${gate} gate requires capabilities.native_plugin=true.`);
		}
	}

	if (gate === "ipad") {
		const runtime = String(getCapability(evidence, "runtime") || evidence.runtime || "");
		const hasArkitEvidence = runtime === "ARKit" ||
			getCapability(evidence, "arkit_supported") === true ||
			evidence.provider === "ARKit";
		if (!hasArkitEvidence) {
			failures.push("iPad gate requires explicit ARKit evidence: capabilities.runtime=\"ARKit\" or capabilities.arkit_supported=true.");
		}
		if (!getCapability(evidence, "arkit_tracking_state")) {
			failures.push("iPad gate requires capabilities.arkit_tracking_state so ARKit tracking can be diagnosed.");
		}
		if (!getCapability(evidence, "arkit_tracking_reason")) {
			failures.push("iPad gate requires capabilities.arkit_tracking_reason so ARKit tracking limits can be diagnosed.");
		}
	}

	if (gate === "android-arcore") {
		const runtime = String(getCapability(evidence, "runtime") || evidence.runtime || "");
		const hasArcoreEvidence = runtime === "ARCore" ||
			getCapability(evidence, "arcore_supported") === true;
		if (!hasArcoreEvidence) {
			failures.push("Android ARCore gate requires explicit ARCore evidence: capabilities.runtime=\"ARCore\" or capabilities.arcore_supported=true.");
		}
	}

	return {
		pass: failures.length === 0,
		failures,
		warnings,
		evidence,
	};
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
		case "ios-simulator":
		case "android-emulator":
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


function validateLaunchPlatformEvidence(evidence, gate, failures) {
	const allowed = platformHintsForGate(gate);
	if (allowed.length === 0) {
		return;
	}

	const observed = new Set();
	for (const value of [
		evidence.platform_hint,
		evidence.runtime && evidence.runtime.resolved_platform_hint,
		evidence.runtime && evidence.runtime.project_platform_hint,
	]) {
		const text = String(value || "").trim().toLowerCase();
		if (text) {
			observed.add(text);
		}
	}
	for (const value of parseXrPlatformArgs(evidence.runtime && evidence.runtime.cmdline_xr_args)) {
		observed.add(value);
	}

	if (allowed.some((value) => observed.has(value))) {
		return;
	}

	const observedText = Array.from(observed).join(", ") || "none";
	failures.push(`${gate} gate requires launch platform evidence (${allowed.join("|")}) in platform_hint, runtime.resolved_platform_hint, project setting, or runtime.cmdline_xr_args; observed ${observedText}.`);
}


function platformHintsForGate(gate) {
	switch (gate) {
		case "rokid":
			return ["rokid", "openxr", "androidxr", "android_xr"];
		case "ipad":
			return ["ipad", "iphone", "ios", "arkit"];
		case "android-arcore":
			return ["arcore", "handheld", "handheld_ar", "phone", "mobile_ar"];
		case "ios-simulator":
		case "android-emulator":
			return ["simulator", "simulation", "sim", "editor", "editorsim", "editor_sim"];
		default:
			return [];
	}
}


function parseXrPlatformArgs(value) {
	if (!Array.isArray(value)) {
		return [];
	}
	const result = [];
	for (let index = 0; index < value.length; index += 1) {
		const text = String(value[index] || "").trim().toLowerCase();
		for (const prefix of ["--xr-platform=", "--xr-backend="]) {
			if (text.startsWith(prefix)) {
				result.push(text.slice(prefix.length).trim());
			}
		}
		if (["--xr-platform", "--xr-backend"].includes(text) && value[index + 1]) {
			result.push(String(value[index + 1]).trim().toLowerCase());
		}
	}
	return result.filter(Boolean);
}


function renderMarkdownReport(summary) {
	const lines = [];
	lines.push(`# C00 Smoke Gate Report: ${summary.gate}`);
	lines.push("");
	lines.push(`Result: ${summary.pass ? "PASS" : "FAIL"}`);
	lines.push("");
	lines.push(`Log: \`${summary.log}\``);
	lines.push("");
	lines.push(`Events: ${summary.events}`);
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
	lines.push("## Script Errors");
	lines.push("");
	if (!summary.scriptErrors || summary.scriptErrors.length === 0) {
		lines.push("- None");
	} else {
		for (const errorLine of summary.scriptErrors) {
			lines.push(`- ${errorLine}`);
		}
	}
	lines.push("");
	lines.push("## Selected Evidence");
	lines.push("");
	lines.push("```json");
	lines.push(JSON.stringify(summary.selectedEvidence || {}, null, 2));
	lines.push("```");
	lines.push("");
	lines.push("## Runtime Metadata");
	lines.push("");
	lines.push("```json");
	lines.push(JSON.stringify(summary.runtimeMetadata || {}, null, 2));
	lines.push("```");
	lines.push("");
	return lines.join("\n");
}
