#!/usr/bin/env node

const fs = require("fs");
const path = require("path");

const args = parseArgs(process.argv.slice(2));

if (args.help || args.h) {
	usage();
	process.exit(0);
}

const profilePath = args.json ? path.resolve(String(args.json)) : "";
const reportPath = args.report ? path.resolve(String(args.report)) : "";
const allowMissingTarget = Boolean(args["allow-missing-target"]);

if (!profilePath) {
	usage();
	process.exit(2);
}

let profile = null;
try {
	profile = JSON.parse(fs.readFileSync(profilePath, "utf8"));
} catch (error) {
	const summary = {
		gate: "ipad",
		profile: profilePath,
		pass: false,
		failures: [`iPad device profile JSON is not readable or parseable: ${String(error.message || error)}`],
		warnings: [],
		evidence: {},
	};
	writeReport(summary);
	console.log(JSON.stringify(summary, null, 2));
	process.exit(1);
}

const summary = analyzeProfile(profile);
writeReport(summary);
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
		"  node tools/c00/analyze_ios_device_profile.js --json <profile.json> [--report <file>]",
		"",
		"Options:",
		"  --allow-missing-target  Downgrade missing target bundle evidence to warning.",
	].join("\n"));
}


function analyzeProfile(profile) {
	const failures = [];
	const warnings = [];
	const selectedDevice = profile.selected_device || null;
	const targetApp = profile.target_app || null;
	const displays = Array.isArray(profile.display_summary) ? profile.display_summary : [];
	const commands = profile.commands || {};
	const lockState = detectLockState(commands.lock_state);

	if (profile.gate && String(profile.gate).toLowerCase() !== "ipad") {
		warnings.push(`Profile was collected for gate "${profile.gate}", but analyzed as "ipad".`);
	}
	if (!selectedDevice) {
		failures.push(`No selected iPad device was found in devicectl output for ${profile.device || "unknown device"}.`);
	}
	if (!targetApp) {
		recordMissingTarget(`Target bundle was not installed when profile was collected: ${profile.bundle_id || "unknown bundle"}.`);
	}
	if (displays.length === 0) {
		warnings.push("No iPad display summary was found in devicectl output.");
	}
	if (!commands.lock_state || commands.lock_state.ok !== true) {
		warnings.push("devicectl lockState command did not complete successfully; confirm the iPad is unlocked before launch.");
	}
	if (lockState === "locked") {
		failures.push("iPad appears to be locked; unlock the device before running the ARKit gate.");
	}

	for (const warning of arrayOfStrings(profile.warnings)) {
		warnings.push(`collector: ${warning}`);
	}

	return {
		gate: "ipad",
		profile: profilePath,
		pass: failures.length === 0,
		failures,
		warnings,
		evidence: {
			device: summarizeDevice(selectedDevice),
			target_bundle_installed: Boolean(targetApp),
			target_bundle: profile.bundle_id || "",
			lock_state: lockState || "unknown",
			displays,
		},
	};

	function recordMissingTarget(message) {
		if (allowMissingTarget) {
			warnings.push(message);
		} else {
			failures.push(message);
		}
	}
}


function detectLockState(commandResult) {
	if (!commandResult || typeof commandResult !== "object") {
		return "";
	}
	const text = [
		JSON.stringify(commandResult.json || {}),
		commandResult.stdout || "",
		commandResult.stderr || "",
		commandResult.log || "",
	].join("\n").toLowerCase();
	if (/"?(islocked|locked)"?\s*:\s*false/.test(text)) {
		return "unlocked";
	}
	if (/"?(islocked|locked)"?\s*:\s*true/.test(text)) {
		return "locked";
	}
	if (/\bunlocked\b|\bunlockedstate\b|\bpasscodeunlocked\b/.test(text)) {
		return "unlocked";
	}
	if (/\blocked\b|\bdevice.?locked\b|\bpasscode.?locked\b/.test(text)) {
		return "locked";
	}
	return "";
}


function summarizeDevice(device) {
	if (!device || typeof device !== "object") {
		return "unknown";
	}
	return [
		device.name,
		device.identifier,
		device.udid,
		device.serialNumber,
		device.serial_number,
		device.model,
	].filter(Boolean).join(" / ") || "unknown";
}


function arrayOfStrings(value) {
	return Array.isArray(value) ? value.map((item) => String(item)) : [];
}


function writeReport(summary) {
	if (!reportPath) {
		return;
	}
	fs.mkdirSync(path.dirname(reportPath), { recursive: true });
	fs.writeFileSync(reportPath, renderMarkdown(summary), "utf8");
}


function renderMarkdown(summary) {
	const lines = [];
	lines.push("# C00 iPad Device Profile Analysis");
	lines.push("");
	lines.push(`Result: ${summary.pass ? "PASS" : "FAIL"}`);
	lines.push("");
	lines.push(`Profile JSON: \`${summary.profile}\``);
	lines.push("");
	lines.push("## Failures");
	lines.push("");
	pushList(lines, summary.failures);
	lines.push("");
	lines.push("## Warnings");
	lines.push("");
	pushList(lines, summary.warnings);
	lines.push("");
	lines.push("## Evidence");
	lines.push("");
	lines.push("```json");
	lines.push(JSON.stringify(summary.evidence, null, 2));
	lines.push("```");
	lines.push("");
	return lines.join("\n");
}


function pushList(lines, items) {
	if (!items || items.length === 0) {
		lines.push("- None");
		return;
	}
	for (const item of items) {
		lines.push(`- ${item}`);
	}
}
