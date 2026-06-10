#!/usr/bin/env node

const fs = require("fs");
const path = require("path");
const { spawnSync } = require("child_process");

const PROJECT_ROOT = path.resolve(__dirname, "../..");
const args = parseArgs(process.argv.slice(2));

if (args.help || args.h) {
	usage();
	process.exit(0);
}

const gate = String(args.gate || "rokid").toLowerCase();
const readinessGate = gate === "rokid-place" ? "rokid" : gate;
const packageName = String(args.package || process.env.PACKAGE || "org.godotengine.godotxrfoundation");
const adbSerial = String(args.serial || process.env.ADB_SERIAL || "");
const runGate = flagEnabled(args["run-gate"]);
const stamp = timestamp();
const evidenceDir = path.resolve(args.dir || path.join(PROJECT_ROOT, "releases/phase_0_smoke/evidence"));
const reportPath = path.resolve(args.report || path.join(evidenceDir, `android-adb-recovery-${gate}-${stamp}.md`));
const jsonPath = path.resolve(args.json || path.join(evidenceDir, `android-adb-recovery-${gate}-${stamp}.json`));
const adb = resolveAdb();

if (!["rokid", "rokid-place", "android-arcore"].includes(gate)) {
	usage();
	process.exit(2);
}

fs.mkdirSync(evidenceDir, { recursive: true });

const before = runReadiness("before");
const recovery = runAdbRecovery();
const after = runReadiness("after");
const deviceGate = runGate && after.status === 0 ? runDeviceGate() : null;

const summary = {
	pass: after.status === 0 && (!runGate || (deviceGate && deviceGate.status === 0)),
	gate,
	readiness_gate: readinessGate,
	package: packageName,
	adb,
	adb_serial: adbSerial,
	generated_at: new Date().toISOString(),
	evidence_dir: evidenceDir,
	before,
	recovery,
	after,
	device_gate: deviceGate,
	next_actions: recoveryNextActions({ before, recovery, after, deviceGate }),
};

fs.mkdirSync(path.dirname(jsonPath), { recursive: true });
fs.writeFileSync(jsonPath, `${JSON.stringify(summary, null, 2)}\n`, "utf8");
fs.mkdirSync(path.dirname(reportPath), { recursive: true });
fs.writeFileSync(reportPath, renderMarkdown(summary), "utf8");

console.log(JSON.stringify({
	pass: summary.pass,
	gate,
	report: reportPath,
	json: jsonPath,
	before: before.report,
	after: after.report,
	adb,
	device_gate: deviceGate ? deviceGate.status : null,
	next_actions: summary.next_actions,
}, null, 2));
process.exit(summary.pass ? 0 : 1);


function runReadiness(label) {
	const report = path.join(evidenceDir, `device-ready-${readinessGate}-adb-${label}-${stamp}.md`);
	const json = path.join(evidenceDir, `device-ready-${readinessGate}-adb-${label}-${stamp}.json`);
	const command = [
		"node",
		path.join(PROJECT_ROOT, "tools/c00/check_device_ready.js"),
		"--gate", readinessGate,
		"--package", packageName,
		"--report", report,
		"--json", json,
		"--format", "markdown",
	];
	if (adbSerial) {
		command.push("--serial", adbSerial);
	}
	const result = spawnSync(command[0], command.slice(1), { cwd: PROJECT_ROOT, encoding: "utf8" });
	return commandResult(command, result, {
		report,
		json,
		json_summary: summarizeReadiness(json),
	});
}


function runAdbRecovery() {
	if (!adb) {
		return {
			adb: "",
			commands: [],
			ok: false,
			status: 127,
			error: "adb not found",
		};
	}
	const commands = [
		runAdbCommand(["version"]),
		runAdbCommand(["kill-server"]),
		runAdbCommand(["start-server"]),
		runAdbCommand(["devices", "-l"]),
	];
	const failing = commands.find((item) => !item.ok && !/kill-server/.test(item.command));
	return {
		adb,
		ok: !failing,
		status: failing ? (failing.status ?? 1) : 0,
		commands,
	};
}


function runAdbCommand(adbArgs) {
	const command = [adb, ...withSerial(adbArgs)];
	const result = spawnSync(command[0], command.slice(1), { cwd: PROJECT_ROOT, encoding: "utf8" });
	return commandResult(command, result, {});
}


function runDeviceGate() {
	const command = [
		path.join(PROJECT_ROOT, "tools/c00/run_device_cycle.sh"),
		gate,
	];
	const env = {
		...process.env,
		PACKAGE: packageName,
	};
	if (adbSerial) {
		env.ADB_SERIAL = adbSerial;
	}
	const result = spawnSync(command[0], command.slice(1), {
		cwd: PROJECT_ROOT,
		encoding: "utf8",
		env,
	});
	return commandResult(command, result, {});
}


function recoveryNextActions(context) {
	const actions = [];
	if (context.after && context.after.status === 0) {
		if (context.deviceGate && context.deviceGate.status !== 0) {
			actions.push(`ADB readiness passed after recovery, but ${gate} gate failed. Inspect the gate stdout/stderr in the recovery JSON, then rerun \`tools/c00/run_device_cycle.sh ${gate}\`.`);
		} else if (!context.deviceGate) {
			actions.push(`ADB readiness passed after recovery. Run \`tools/c00/run_device_cycle.sh ${gate}\` or rerun this command with \`--run-gate\`.`);
		}
		return actions;
	}
	const afterSummary = context.after && context.after.json_summary;
	const devices = (((afterSummary || {}).results || [])[0] || {}).evidence || {};
	const usbDevices = (((devices.host || {}).usb || {}).android_like_devices || []);
	const recoveryText = JSON.stringify(context.recovery || {});
	if (/Operation not permitted|could not install \*smartsocket\* listener|ADB server didn't ACK|failed to start daemon/i.test(recoveryText)) {
		actions.push("Run this recovery command from a normal macOS terminal or approved unsandboxed Codex command so adb can bind its local server socket.");
		actions.push("If adb is wedged, rerun the recovery command once after closing other Android tooling.");
		return actions;
	}
	if (usbDevices.length > 0) {
		actions.push(`macOS USB sees possible Android/XR hardware (${usbDevices.map((item) => item.name || item.manufacturer || item.serial || "unknown").join(", ")}), but adb still has no ready transport. Unlock the device, enable USB debugging, change USB mode away from charge-only, and accept the RSA prompt.`);
	} else {
		actions.push(`Connect the ${gate === "android-arcore" ? "Android/ARCore" : "Rokid/OpenXR"} device over USB-C, enable Developer Options and USB debugging, and accept the RSA trust prompt.`);
	}
	actions.push("Rerun this recovery command, then wait until `adb devices -l` shows state `device` before launching the gate.");
	return actions;
}


function commandResult(command, result, extra) {
	return {
		command: command.map(shellArg).join(" "),
		status: result.status,
		ok: result.status === 0,
		stdout: truncate(result.stdout || "", 5000),
		stderr: truncate(result.stderr || "", 5000),
		error: result.error ? String(result.error.message || result.error) : "",
		...extra,
	};
}


function summarizeReadiness(filePath) {
	try {
		if (!fs.existsSync(filePath)) {
			return null;
		}
		const parsed = JSON.parse(fs.readFileSync(filePath, "utf8"));
		return {
			pass: parsed.pass === true,
			gate: parsed.gate || "",
			results: Array.isArray(parsed.results) ? parsed.results.map((item) => ({
				gate: item.gate,
				pass: item.pass,
				failures: item.failures || [],
				warnings: item.warnings || [],
				evidence: item.evidence || {},
			})) : [],
		};
	} catch (error) {
		return {
			parse_error: String(error.message || error),
		};
	}
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


function withSerial(adbArgs) {
	if (!adbSerial || ["version", "devices", "kill-server", "start-server"].includes(adbArgs[0])) {
		return adbArgs;
	}
	return ["-s", adbSerial, ...adbArgs];
}


function renderMarkdown(summary) {
	const lines = [];
	lines.push(`# C00 Android ADB Recovery: ${summary.gate}`);
	lines.push("");
	lines.push(`Generated: ${summary.generated_at}`);
	lines.push("");
	lines.push(`Result: ${summary.pass ? "PASS" : "FAIL"}`);
	lines.push("");
	lines.push("## Artifacts");
	lines.push("");
	lines.push(`- Before readiness: \`${summary.before.report}\``);
	lines.push(`- Before readiness JSON: \`${summary.before.json}\``);
	lines.push(`- After readiness: \`${summary.after.report}\``);
	lines.push(`- After readiness JSON: \`${summary.after.json}\``);
	lines.push("");
	lines.push("## Commands");
	lines.push("");
	pushCommand(lines, "Before readiness", summary.before);
	lines.push("### ADB recovery");
	lines.push("");
	for (const command of summary.recovery.commands || []) {
		lines.push(`- ${command.ok ? "PASS" : "FAIL"}: \`${command.command}\``);
		if (command.stdout) {
			lines.push("");
			lines.push("```text");
			lines.push(command.stdout);
			lines.push("```");
			lines.push("");
		}
		if (command.stderr) {
			lines.push("");
			lines.push("```text");
			lines.push(command.stderr);
			lines.push("```");
			lines.push("");
		}
	}
	lines.push("");
	pushCommand(lines, "After readiness", summary.after);
	if (summary.device_gate) {
		pushCommand(lines, "Device gate", summary.device_gate);
	}
	lines.push("## Next Actions");
	lines.push("");
	for (const action of summary.next_actions) {
		lines.push(`- ${action}`);
	}
	lines.push("");
	return lines.join("\n");
}


function pushCommand(lines, title, result) {
	lines.push(`### ${title}`);
	lines.push("");
	lines.push(`- Status: ${result.ok ? "PASS" : "FAIL"}${result.status === null ? "" : ` (${result.status})`}`);
	lines.push(`- Command: \`${result.command}\``);
	if (result.stderr) {
		lines.push("");
		lines.push("```text");
		lines.push(result.stderr);
		lines.push("```");
	}
	lines.push("");
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
		"  node tools/c00/recover_android_adb_transport.js --gate <rokid|rokid-place|android-arcore> [--serial <adb-serial>] [--package <id>] [--adb <path>] [--dir <evidence-dir>] [--report <file>] [--json <file>] [--run-gate]",
		"",
		"Runs Android/Rokid readiness, restarts the project-local adb server, runs readiness again,",
		"and preserves all evidence paths. With --run-gate, the device gate runs only after readiness passes.",
	].join("\n"));
}


function flagEnabled(value) {
	return value === true || value === "" || value === "1" || value === "true" || value === "yes";
}


function timestamp() {
	const date = new Date();
	const pad = (value) => String(value).padStart(2, "0");
	return [
		date.getFullYear(),
		pad(date.getMonth() + 1),
		pad(date.getDate()),
		"-",
		pad(date.getHours()),
		pad(date.getMinutes()),
		pad(date.getSeconds()),
	].join("");
}


function truncate(value, maxLength) {
	const text = String(value || "").trim();
	if (text.length <= maxLength) {
		return text;
	}
	return `${text.slice(0, maxLength)}\n... truncated ...`;
}


function shellArg(value) {
	const text = String(value);
	if (/^[A-Za-z0-9_./:@%+=,-]+$/.test(text)) {
		return text;
	}
	return `'${text.replace(/'/g, "'\\''")}'`;
}


function shellQuote(value) {
	return `'${String(value).replace(/'/g, "'\\''")}'`;
}
