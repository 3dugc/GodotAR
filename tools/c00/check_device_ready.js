#!/usr/bin/env node

const fs = require("fs");
const os = require("os");
const path = require("path");
const { spawnSync } = require("child_process");

const PROJECT_ROOT = path.resolve(__dirname, "../..");
const args = parseArgs(process.argv.slice(2));

if (args.help || args.h) {
	usage();
	process.exit(0);
}

const gate = String(args.gate || "all").toLowerCase();
const device = String(args.device || process.env.DEVICE || "");
const packageName = String(args.package || process.env.PACKAGE || "org.godotengine.godotxrfoundation");
const reportPath = args.report ? path.resolve(String(args.report)) : "";
const jsonPath = args.json ? path.resolve(String(args.json)) : "";
const format = String(args.format || (reportPath ? "markdown" : "json")).toLowerCase();

const supportedGates = ["rokid", "ipad", "android-arcore", "all"];
if (!supportedGates.includes(gate)) {
	usage();
	process.exit(2);
}

const gates = gate === "all" ? ["rokid", "ipad", "android-arcore"] : [gate];
const results = gates.map((item) => {
	if (item === "ipad") {
		return checkIpadReady();
	}
	return checkAndroidReady(item);
});

const summary = {
	pass: results.every((result) => result.pass),
	gate,
	generated_at: new Date().toISOString(),
	projectRoot: PROJECT_ROOT,
	results,
};

if (jsonPath) {
	fs.mkdirSync(path.dirname(jsonPath), { recursive: true });
	fs.writeFileSync(jsonPath, `${JSON.stringify(summary, null, 2)}\n`, "utf8");
}

const output = format === "markdown" ? renderMarkdown(summary) : JSON.stringify(summary, null, 2);
if (reportPath) {
	fs.mkdirSync(path.dirname(reportPath), { recursive: true });
	fs.writeFileSync(reportPath, `${output}\n`, "utf8");
}
console.log(output);
process.exit(summary.pass ? 0 : 1);


function checkAndroidReady(gateName) {
	const adb = resolveAdb();
	const serial = String(args.serial || process.env.ADB_SERIAL || "");
	const failures = [];
	const warnings = [];
	const devices = adb ? run(adb, ["devices", "-l"]) : { ok: false, stdout: "", stderr: "adb not found" };
	const parsedDevices = parseAdbDevices(devices.stdout);
	const availableDevices = parsedDevices.filter((item) => item.state === "device");
	const targetDevice = serial ? parsedDevices.find((item) => item.serial === serial) : availableDevices[0] || null;

	if (!adb) {
		failures.push("adb was not found. Set ADB_BIN or install Android platform-tools.");
	} else if (!devices.ok) {
		failures.push(`adb devices -l failed: ${devices.stderr || "unknown error"}`);
	} else if (serial && (!targetDevice || targetDevice.state !== "device")) {
		failures.push(`ADB serial ${serial} is not available in state 'device'.`);
	} else if (availableDevices.length === 0) {
		failures.push("No Android/Rokid device is available in adb state 'device'.");
	}

	for (const item of parsedDevices) {
		if (item.state !== "device") {
			warnings.push(`ADB device ${item.serial} is in state '${item.state}', not 'device'.`);
		}
	}

	if (gateName === "rokid" && targetDevice && !/rokid/i.test([targetDevice.serial, ...targetDevice.details].join(" "))) {
		warnings.push("Ready device is not visibly identified as Rokid from adb devices -l; final proof must come from device profile and OpenXR smoke evidence.");
	}

	return {
		gate: gateName,
		pass: failures.length === 0,
		failures,
		warnings,
		evidence: {
			adb,
			serial: serial || "",
			devices: parsedDevices,
			selected_device: targetDevice,
			raw_devices_output: devices.stdout.trim(),
		},
	};
}


function checkIpadReady() {
	const failures = [];
	const warnings = [];
	if (!device) {
		return {
			gate: "ipad",
			pass: false,
			failures: ["iPad device name or identifier is required. Pass --device <name-or-uuid> or set DEVICE."],
			warnings,
			evidence: {},
		};
	}

	const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), "godotar-ipad-ready-"));
	const profileJsonPath = path.join(tempDir, "ipad-device.json");
	const collect = run("node", [
		path.join(PROJECT_ROOT, "tools/c00/collect_ios_device_profile.js"),
		"--device", device,
		"--bundle", packageName,
		"--timeout", String(args["device-timeout"] || process.env.DEVICECTL_TIMEOUT || "5"),
		"--json", profileJsonPath,
	]);
	if (!collect.ok) {
		failures.push(`iPad device profile collection failed: ${collect.stderr || collect.stdout || "unknown error"}`);
	}

	let profile = {};
	try {
		if (fs.existsSync(profileJsonPath)) {
			profile = JSON.parse(fs.readFileSync(profileJsonPath, "utf8"));
		}
	} catch (error) {
		failures.push(`iPad readiness profile JSON could not be parsed: ${String(error.message || error)}`);
	}

	const analyze = run("node", [
		path.join(PROJECT_ROOT, "tools/c00/analyze_ios_device_profile.js"),
		"--json", profileJsonPath,
		"--allow-missing-target",
	]);
	const analysis = parseJsonOutput(analyze.stdout);
	if (!analyze.ok) {
		for (const failure of arrayOfStrings(analysis.failures)) {
			failures.push(failure);
		}
		if (arrayOfStrings(analysis.failures).length === 0) {
			failures.push(`iPad device profile analysis failed: ${analyze.stderr || analyze.stdout || "unknown error"}`);
		}
	}
	for (const warning of arrayOfStrings(analysis.warnings)) {
		warnings.push(warning);
	}

	return {
		gate: "ipad",
		pass: failures.length === 0,
		failures,
		warnings,
		evidence: {
			device,
			profile: summarizeIpadProfile(profile),
			analysis: analysis.evidence || {},
		},
	};
}


function resolveAdb() {
	const candidates = [
		args.adb,
		process.env.ADB_BIN,
		path.join(PROJECT_ROOT, ".godot/cache/c00/android-sdk/platform-tools/adb"),
		"adb",
	].filter(Boolean).map(String);
	for (const candidate of candidates) {
		if (candidate.includes("/") && fs.existsSync(candidate)) {
			return candidate;
		}
		if (!candidate.includes("/")) {
			const found = spawnSync("sh", ["-lc", `command -v ${shellQuote(candidate)}`], { encoding: "utf8" });
			if (found.status === 0 && found.stdout.trim()) {
				return found.stdout.trim();
			}
		}
	}
	return "";
}


function parseAdbDevices(text) {
	const devices = [];
	for (const line of String(text || "").split(/\r?\n/)) {
		const trimmed = line.trim();
		if (!trimmed || /^List of devices/i.test(trimmed)) {
			continue;
		}
		const columns = trimmed.split(/\s+/);
		if (columns.length < 2) {
			continue;
		}
		devices.push({
			serial: columns[0],
			state: columns[1],
			details: columns.slice(2),
		});
	}
	return devices;
}


function summarizeIpadProfile(profile) {
	const commands = profile.commands || {};
	return {
		selected_device: profile.selected_device || null,
		display_count: Array.isArray(profile.display_summary) ? profile.display_summary.length : 0,
		target_app_found: Boolean(profile.target_app),
		devicectl_list: commandSummary(commands.list_devices),
		xctrace_devices: commandSummary(commands.xctrace_devices),
	};
}


function commandSummary(result) {
	if (!result || typeof result !== "object") {
		return {};
	}
	return {
		ok: result.ok === true,
		status: result.status,
		stdout: truncate(result.stdout || result.log || "", 1200),
		stderr: truncate(result.stderr || "", 1200),
	};
}


function run(command, argv) {
	const result = spawnSync(command, argv, { encoding: "utf8" });
	return {
		ok: result.status === 0,
		status: result.status,
		stdout: result.stdout || "",
		stderr: result.stderr || "",
		error: result.error ? String(result.error) : "",
	};
}


function parseJsonOutput(text) {
	try {
		return JSON.parse(text);
	} catch (error) {
		return {};
	}
}


function renderMarkdown(summary) {
	const lines = [];
	lines.push("# C00 Device Readiness");
	lines.push("");
	lines.push(`Generated: ${summary.generated_at}`);
	lines.push("");
	lines.push(`Gate: \`${summary.gate}\``);
	lines.push("");
	lines.push(`Result: ${summary.pass ? "PASS" : "FAIL"}`);
	lines.push("");
	for (const result of summary.results) {
		lines.push(`## ${result.gate}`);
		lines.push("");
		lines.push(`Result: ${result.pass ? "PASS" : "FAIL"}`);
		lines.push("");
		lines.push("### Failures");
		lines.push("");
		pushList(lines, result.failures);
		lines.push("");
		lines.push("### Warnings");
		lines.push("");
		pushList(lines, result.warnings);
		lines.push("");
		lines.push("### Evidence");
		lines.push("");
		lines.push("```json");
		lines.push(JSON.stringify(result.evidence, null, 2));
		lines.push("```");
		lines.push("");
	}
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


function arrayOfStrings(value) {
	return Array.isArray(value) ? value.map((item) => String(item)) : [];
}


function truncate(value, maxLength) {
	const text = String(value || "").trim();
	if (text.length <= maxLength) {
		return text;
	}
	return `${text.slice(0, maxLength)}\n... truncated ...`;
}


function shellQuote(value) {
	return `'${String(value).replace(/'/g, "'\\''")}'`;
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
		"  node tools/c00/check_device_ready.js --gate <rokid|ipad|android-arcore|all> [--device <ipad-name-or-uuid>] [--report <file>] [--json <file>]",
		"",
		"Checks whether device transports are ready before running C00 device gates.",
		"Rokid/Android require an ADB device in state 'device'.",
		"iPad requires devicectl/xctrace evidence that the target iPad is not offline or unavailable.",
	].join("\n"));
}
