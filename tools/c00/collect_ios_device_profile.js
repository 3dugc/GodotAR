#!/usr/bin/env node

const fs = require("fs");
const os = require("os");
const path = require("path");
const { spawnSync } = require("child_process");

const args = parseArgs(process.argv.slice(2));

if (args.help || args.h) {
	usage();
	process.exit(0);
}

const device = String(args.device || process.env.DEVICE || "");
const bundleId = String(args.bundle || args.package || process.env.BUNDLE_ID || process.env.PACKAGE || "org.godotengine.godotxrfoundation");
const reportPath = args.report ? path.resolve(String(args.report)) : "";
const jsonPath = args.json ? path.resolve(String(args.json)) : "";
const appendReportPath = args["append-report"] ? path.resolve(String(args["append-report"])) : "";
const devicectlBin = String(args.devicectl || process.env.DEVICECTL_BIN || "xcrun");
const devicectlPrefix = path.basename(devicectlBin) === "xcrun" ? ["devicectl"] : [];
const timeout = String(args.timeout || process.env.DEVICECTL_TIMEOUT || "20");

if (!device) {
	console.error("ERROR: --device is required.");
	process.exit(2);
}

const profile = collectProfile();

if (jsonPath) {
	fs.mkdirSync(path.dirname(jsonPath), { recursive: true });
	fs.writeFileSync(jsonPath, `${JSON.stringify(profile, null, 2)}\n`, "utf8");
}

const markdown = renderMarkdown(profile);
if (reportPath) {
	fs.mkdirSync(path.dirname(reportPath), { recursive: true });
	fs.writeFileSync(reportPath, markdown, "utf8");
}
if (appendReportPath) {
	fs.mkdirSync(path.dirname(appendReportPath), { recursive: true });
	fs.appendFileSync(appendReportPath, `\n${markdown}`, "utf8");
}

console.log(JSON.stringify(profile, null, 2));
process.exit(0);


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
		"  node tools/c00/collect_ios_device_profile.js --device <uuid|name> --bundle <id> [--report <file>] [--json <file>] [--append-report <file>]",
		"",
		"Options:",
		"  --devicectl <path>  devicectl executable. Default: xcrun devicectl.",
		"  --timeout <seconds> devicectl command timeout. Default: 20.",
	].join("\n"));
}


function collectProfile() {
	const generatedAt = new Date().toISOString();
	const commands = {
		list_devices: runDevicectl(["list", "devices"]),
		details: runDevicectl(["device", "info", "details", "--device", device]),
		displays: runDevicectl(["device", "info", "displays", "--device", device]),
		apps: runDevicectl(["device", "info", "apps", "--device", device, "--bundle-id", bundleId]),
		lock_state: runDevicectl(["device", "info", "lockState", "--device", device]),
		xctrace_devices: runXcrun(["xctrace", "list", "devices"]),
	};

	const selectedDevice = selectDevice(commands.list_devices.json, device) ||
		selectDevice(commands.details.json, device) ||
		null;
	const targetApp = selectApp(commands.apps.json, bundleId);
	const displaySummary = summarizeDisplays(commands.displays.json);
	const warnings = collectWarnings(commands, selectedDevice, targetApp);

	return {
		gate: "ipad",
		device,
		bundle_id: bundleId,
		generated_at: generatedAt,
		devicectl: {
			binary: devicectlBin,
			timeout_seconds: Number(timeout),
		},
		selected_device: selectedDevice,
		display_summary: displaySummary,
		target_app: targetApp,
		warnings,
		commands,
	};
}


function runDevicectl(commandArgs) {
	const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "godotar-devicectl-"));
	const jsonOutput = path.join(tmpDir, "out.json");
	const logOutput = path.join(tmpDir, "log.txt");
	const fullArgs = [
		...devicectlPrefix,
		"--timeout", timeout,
		"--json-output", jsonOutput,
		"--log-output", logOutput,
		...commandArgs,
	];
	const result = spawnSync(devicectlBin, fullArgs, { encoding: "utf8" });
	const json = readJson(jsonOutput);
	const log = readText(logOutput);
	return {
		command: [devicectlBin, ...fullArgs].join(" "),
		ok: result.status === 0,
		status: result.status,
		stdout: result.stdout || "",
		stderr: result.stderr || "",
		log,
		json,
		json_path: jsonOutput,
		log_path: logOutput,
	};
}


function runXcrun(commandArgs) {
	const result = spawnSync("xcrun", commandArgs, { encoding: "utf8" });
	return {
		command: ["xcrun", ...commandArgs].join(" "),
		ok: result.status === 0,
		status: result.status,
		stdout: result.stdout || "",
		stderr: result.stderr || "",
		log: "",
		json: null,
		json_path: "",
		log_path: "",
	};
}


function readJson(filePath) {
	try {
		if (!fs.existsSync(filePath)) {
			return null;
		}
		return JSON.parse(fs.readFileSync(filePath, "utf8"));
	} catch (error) {
		return {
			parse_error: String(error.message || error),
			raw: readText(filePath),
		};
	}
}


function readText(filePath) {
	try {
		if (!fs.existsSync(filePath)) {
			return "";
		}
		return fs.readFileSync(filePath, "utf8");
	} catch (error) {
		return "";
	}
}


function selectDevice(json, wanted) {
	const candidates = collectObjects(json).filter((item) => {
		return hasAnyKey(item, ["name", "identifier", "udid", "serialNumber", "serial_number", "ecid", "dnsName", "dns_name"]);
	});
	const normalizedWanted = normalize(wanted);
	return candidates.find((item) => {
		return [
			item.name,
			item.identifier,
			item.udid,
			item.serialNumber,
			item.serial_number,
			item.ecid,
			item.dnsName,
			item.dns_name,
		].some((value) => normalize(value) === normalizedWanted);
	}) || candidates[0] || null;
}


function selectApp(json, bundleId) {
	const normalizedBundle = normalize(bundleId);
	const candidates = collectObjects(json).filter((item) => {
		return normalize(item.bundleIdentifier || item.bundle_id || item.identifier || item.bundleID) === normalizedBundle;
	});
	return candidates[0] || null;
}


function summarizeDisplays(json) {
	const displays = collectObjects(json).filter((item) => {
		return hasAnyKey(item, ["width", "height", "scale", "bounds", "nativeBounds", "main"]);
	});
	return displays.slice(0, 8);
}


function collectObjects(value, output = []) {
	if (!value || typeof value !== "object") {
		return output;
	}
	if (Array.isArray(value)) {
		for (const item of value) {
			collectObjects(item, output);
		}
		return output;
	}
	output.push(value);
	for (const item of Object.values(value)) {
		collectObjects(item, output);
	}
	return output;
}


function hasAnyKey(object, keys) {
	return keys.some((key) => object[key] !== undefined && object[key] !== null && object[key] !== "");
}


function collectWarnings(commands, selectedDevice, targetApp) {
	const warnings = [];
	for (const [name, result] of Object.entries(commands)) {
		if (!result.ok) {
			const message = devicectlMessage(result);
			warnings.push(`${name} failed${message ? `: ${message}` : ""}`);
		}
	}
	if (!selectedDevice) {
		warnings.push(`Could not match device in devicectl JSON output: ${device}`);
	}
	if (!targetApp) {
		warnings.push(`Target bundle was not found by devicectl device info apps: ${bundleId}`);
	}
	return warnings;
}


function devicectlMessage(result) {
	const localized = findStringByKey(result.json, "NSLocalizedDescription") ||
		findStringByKey(result.json, "description") ||
		findStringByKey(result.json, "message");
	return localized || result.stderr.trim() || result.stdout.trim();
}


function findStringByKey(value, key) {
	if (!value || typeof value !== "object") {
		return "";
	}
	if (Object.prototype.hasOwnProperty.call(value, key)) {
		const found = value[key];
		if (typeof found === "string") {
			return found;
		}
		if (found && typeof found.string === "string") {
			return found.string;
		}
	}
	for (const item of Object.values(value)) {
		const nested = findStringByKey(item, key);
		if (nested) {
			return nested;
		}
	}
	return "";
}


function normalize(value) {
	return String(value || "").trim().toLowerCase();
}


function renderMarkdown(profile) {
	const lines = [];
	lines.push("# C00 iPad Device Profile");
	lines.push("");
	lines.push(`Generated: ${profile.generated_at}`);
	lines.push("");
	lines.push(`Device: \`${profile.device}\``);
	lines.push("");
	lines.push(`Bundle: \`${profile.bundle_id}\``);
	lines.push("");
	lines.push("## devicectl");
	lines.push("");
	lines.push(`- Binary: \`${profile.devicectl.binary}\``);
	lines.push(`- Timeout: ${profile.devicectl.timeout_seconds}s`);
	lines.push("");
	lines.push("## Selected Device");
	lines.push("");
	lines.push("```json");
	lines.push(JSON.stringify(profile.selected_device || {}, null, 2));
	lines.push("```");
	lines.push("");
	lines.push("## Target App");
	lines.push("");
	lines.push("```json");
	lines.push(JSON.stringify(profile.target_app || {}, null, 2));
	lines.push("```");
	lines.push("");
	lines.push("## Displays");
	lines.push("");
	lines.push("```json");
	lines.push(JSON.stringify(profile.display_summary || [], null, 2));
	lines.push("```");
	lines.push("");
	lines.push("## Command Results");
	lines.push("");
	for (const [name, result] of Object.entries(profile.commands)) {
		lines.push(`### ${name}`);
		lines.push("");
		lines.push(`- Status: ${result.ok ? "PASS" : "FAIL"}${result.status === null ? "" : ` (${result.status})`}`);
		lines.push("");
		lines.push("```text");
		lines.push(truncate(result.stderr || result.stdout || result.log || "", 4000));
		lines.push("```");
		lines.push("");
	}
	lines.push("## Device Profile Warnings");
	lines.push("");
	if (profile.warnings.length === 0) {
		lines.push("- None");
	} else {
		for (const warning of profile.warnings) {
			lines.push(`- ${warning}`);
		}
	}
	lines.push("");
	return lines.join("\n");
}


function truncate(value, maxLength) {
	const text = String(value || "").trim();
	if (text.length <= maxLength) {
		return text;
	}
	return `${text.slice(0, maxLength)}\n... truncated ...`;
}
