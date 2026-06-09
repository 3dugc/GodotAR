#!/usr/bin/env node

const fs = require("fs");
const path = require("path");

const PROJECT_ROOT = path.resolve(__dirname, "../..");
const args = parseArgs(process.argv.slice(2));

if (args.help || args.h) {
	usage();
	process.exit(0);
}

const file = path.resolve(String(args.file || "export_presets.cfg"));
const gate = String(args.gate || "all").toLowerCase();
const teamId = String(args["team-id"] || process.env.TEAM_ID || process.env.DEVELOPMENT_TEAM || process.env.IPAD_TEAM_ID || process.env.APPLE_TEAM_ID || "").trim();
const bundleId = String(args["bundle-id"] || process.env.BUNDLE_ID || process.env.PACKAGE || "").trim();
const dryRun = Boolean(args["dry-run"]);
const checkOnly = Boolean(args.check || args["check-only"]);

const gateNames = {
	ipad: ["C00 iPad ARKit"],
	"ipad-place": ["C04 iPad ARKit Place"],
	all: ["C00 iPad ARKit", "C04 iPad ARKit Place"],
};

if (!gateNames[gate]) {
	usage();
	process.exit(2);
}
if (!fs.existsSync(file)) {
	fail(`export preset file not found: ${file}`);
}
if (!checkOnly && !isValidTeamId(teamId)) {
	fail("A real Apple Team ID is required. Pass --team-id <10-char-id> or set TEAM_ID, DEVELOPMENT_TEAM, IPAD_TEAM_ID, or APPLE_TEAM_ID.");
}

const before = fs.readFileSync(file, "utf8");
const result = configure(before, {
	presetNames: gateNames[gate],
	teamId,
	bundleId,
	checkOnly,
});

if (!result.pass) {
	console.log(JSON.stringify(publicResult(result), null, 2));
	process.exit(1);
}

if (!checkOnly && !dryRun && result.changed) {
	fs.writeFileSync(file, result.text, "utf8");
}

console.log(JSON.stringify({
	pass: true,
	file,
	gate,
	checkOnly,
	dryRun,
	changed: result.changed,
	presets: result.presets,
}, null, 2));


function configure(text, options) {
	const lines = text.split(/\r?\n/);
	const newline = text.includes("\r\n") ? "\r\n" : "\n";
	const presets = findPresets(lines);
	const selected = presets.filter((preset) => options.presetNames.includes(preset.name));
	const failures = [];
	const evidence = [];
	let changed = false;

	for (const name of options.presetNames) {
		if (!selected.some((preset) => preset.name === name)) {
			failures.push(`Missing iOS export preset: ${name}`);
		}
	}

	for (const preset of selected) {
		const optionRange = findOptionRange(lines, preset.index);
		if (!optionRange) {
			failures.push(`Missing [preset.${preset.index}.options] for ${preset.name}`);
			continue;
		}
		const currentTeam = getOption(lines, optionRange, "application/app_store_team_id");
		const currentBundle = getOption(lines, optionRange, "application/bundle_identifier");
		if (options.checkOnly) {
			if (!isValidTeamId(currentTeam) || currentTeam === "ABCDE12345") {
				failures.push(`${preset.name} must use a real application/app_store_team_id before iPad install.`);
			}
		} else {
			changed = setOption(lines, optionRange, "application/app_store_team_id", quote(options.teamId)) || changed;
			if (options.bundleId) {
				changed = setOption(lines, optionRange, "application/bundle_identifier", quote(options.bundleId)) || changed;
			}
		}
		evidence.push({
			name: preset.name,
			section: `preset.${preset.index}`,
			team_id_before: currentTeam,
			team_id_after: options.checkOnly ? currentTeam : options.teamId,
			bundle_id_before: currentBundle,
			bundle_id_after: options.bundleId || currentBundle,
		});
	}

	return {
		pass: failures.length === 0,
		failures,
		changed,
		presets: evidence,
		text: finishWithNewline(lines.join(newline), newline),
	};
}


function finishWithNewline(text, newline) {
	return text.endsWith(newline) ? text : `${text}${newline}`;
}


function publicResult(result) {
	return {
		pass: result.pass,
		failures: result.failures,
		changed: result.changed,
		presets: result.presets,
	};
}


function findPresets(lines) {
	const presets = [];
	let current = null;
	for (let lineIndex = 0; lineIndex < lines.length; lineIndex += 1) {
		const section = lines[lineIndex].match(/^\[preset\.(\d+)\]$/);
		if (section) {
			current = { index: section[1], name: "", line: lineIndex };
			presets.push(current);
			continue;
		}
		if (/^\[/.test(lines[lineIndex])) {
			current = null;
			continue;
		}
		if (current) {
			const name = lines[lineIndex].match(/^name=(.*)$/);
			if (name) {
				current.name = unquote(name[1].trim());
			}
		}
	}
	return presets;
}


function findOptionRange(lines, presetIndex) {
	const header = `[preset.${presetIndex}.options]`;
	const start = lines.findIndex((line) => line.trim() === header);
	if (start < 0) {
		return null;
	}
	let end = lines.length;
	for (let index = start + 1; index < lines.length; index += 1) {
		if (/^\[/.test(lines[index])) {
			end = index;
			break;
		}
	}
	return { start, end };
}


function getOption(lines, range, key) {
	const pattern = new RegExp(`^${escapeRegExp(key)}=(.*)$`);
	for (let index = range.start + 1; index < range.end; index += 1) {
		const match = lines[index].match(pattern);
		if (match) {
			return unquote(match[1].trim());
		}
	}
	return "";
}


function setOption(lines, range, key, value) {
	const pattern = new RegExp(`^${escapeRegExp(key)}=`);
	for (let index = range.start + 1; index < range.end; index += 1) {
		if (pattern.test(lines[index])) {
			const next = `${key}=${value}`;
			if (lines[index] === next) {
				return false;
			}
			lines[index] = next;
			return true;
		}
	}
	lines.splice(range.end, 0, `${key}=${value}`);
	range.end += 1;
	return true;
}


function quote(value) {
	return `"${String(value).replace(/\\/g, "\\\\").replace(/"/g, "\\\"")}"`;
}


function unquote(value) {
	const text = String(value || "").trim();
	if (text.startsWith("\"") && text.endsWith("\"")) {
		return text.slice(1, -1).replace(/\\"/g, "\"").replace(/\\\\/g, "\\");
	}
	return text;
}


function isValidTeamId(value) {
	return /^[A-Z0-9]{10}$/i.test(String(value || "").trim());
}


function escapeRegExp(value) {
	return String(value).replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
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
		"  node tools/c00/configure_ios_signing.js --team-id <TEAM_ID> [--bundle-id <id>] [--gate ipad|ipad-place|all] [--file export_presets.cfg] [--dry-run]",
		"  node tools/c00/configure_ios_signing.js --check-only [--gate ipad|ipad-place|all] [--file export_presets.cfg]",
		"",
		"Updates only iPad ARKit export preset signing identifiers. It does not write certificates, passwords, or provisioning profiles.",
		"Team ID can also come from TEAM_ID, DEVELOPMENT_TEAM, IPAD_TEAM_ID, or APPLE_TEAM_ID.",
	].join("\n"));
}


function fail(message) {
	console.error(`ERROR: ${message}`);
	process.exit(2);
}
