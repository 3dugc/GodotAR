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

const device = String(args.device || process.env.DEVICE || "");
const packageName = String(args.package || process.env.PACKAGE || "org.godotengine.godotxrfoundation");
const timeout = String(args.timeout || process.env.DEVICECTL_TIMEOUT || "60");
const runGate = flagEnabled(args["run-gate"]);
const stamp = timestamp();
const evidenceDir = path.resolve(args.dir || path.join(PROJECT_ROOT, "releases/phase_0_smoke/evidence"));
const reportPath = path.resolve(args.report || path.join(evidenceDir, `ipad-ddi-recovery-${stamp}.md`));
const jsonPath = path.resolve(args.json || path.join(evidenceDir, `ipad-ddi-recovery-${stamp}.json`));

if (!device) {
	usage();
	process.exit(2);
}

fs.mkdirSync(evidenceDir, { recursive: true });

const before = runReadiness("before");
const ddi = runDdiAutoMount();
const after = runReadiness("after");
const gate = runGate && after.status === 0 ? runIpadGate() : null;

const summary = {
	pass: after.status === 0 && (!runGate || (gate && gate.status === 0)),
	device,
	package: packageName,
	generated_at: new Date().toISOString(),
	evidence_dir: evidenceDir,
	before,
	ddi,
	after,
	gate,
	next_actions: recoveryNextActions({ before, ddi, after, gate }),
};

fs.mkdirSync(path.dirname(jsonPath), { recursive: true });
fs.writeFileSync(jsonPath, `${JSON.stringify(summary, null, 2)}\n`, "utf8");
fs.mkdirSync(path.dirname(reportPath), { recursive: true });
fs.writeFileSync(reportPath, renderMarkdown(summary), "utf8");

console.log(JSON.stringify({
	pass: summary.pass,
	device,
	report: reportPath,
	json: jsonPath,
	before: before.report,
	ddi_json: ddi.json_output,
	ddi_log: ddi.log_output,
	after: after.report,
	gate: gate ? gate.status : null,
	next_actions: summary.next_actions,
}, null, 2));
process.exit(summary.pass ? 0 : 1);


function runReadiness(label) {
	const report = path.join(evidenceDir, `device-ready-ipad-ddi-${label}-${stamp}.md`);
	const json = path.join(evidenceDir, `device-ready-ipad-ddi-${label}-${stamp}.json`);
	const command = [
		"node",
		path.join(PROJECT_ROOT, "tools/c00/check_device_ready.js"),
		"--gate", "ipad",
		"--device", device,
		"--package", packageName,
		"--report", report,
		"--json", json,
		"--format", "markdown",
	];
	const result = spawnSync(command[0], command.slice(1), { cwd: PROJECT_ROOT, encoding: "utf8" });
	return commandResult(command, result, { report, json });
}


function runDdiAutoMount() {
	const jsonOutput = path.join(evidenceDir, `ipad-ddi-automount-${stamp}.json`);
	const logOutput = path.join(evidenceDir, `ipad-ddi-automount-${stamp}.log`);
	const command = [
		"xcrun",
		"devicectl",
		"--timeout", timeout,
		"--json-output", jsonOutput,
		"--log-output", logOutput,
		"device", "info", "ddiServices",
		"--device", device,
		"--auto-mount-ddis",
	];
	const result = spawnSync(command[0], command.slice(1), { cwd: PROJECT_ROOT, encoding: "utf8" });
	return commandResult(command, result, {
		json_output: jsonOutput,
		log_output: logOutput,
		json_summary: summarizeJson(jsonOutput),
	});
}


function runIpadGate() {
	const command = [
		path.join(PROJECT_ROOT, "tools/c00/run_device_cycle.sh"),
		"ipad",
		device,
	];
	const result = spawnSync(command[0], command.slice(1), {
		cwd: PROJECT_ROOT,
		encoding: "utf8",
		env: {
			...process.env,
			DEVICE: device,
			PACKAGE: packageName,
		},
	});
	return commandResult(command, result, {});
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


function recoveryNextActions(context) {
	const actions = [];
	if (context.after && context.after.status === 0) {
		if (context.gate && context.gate.status !== 0) {
			actions.push("iPad readiness passed after DDI recovery, but the iPad gate failed. Inspect the gate stdout/stderr in the recovery JSON, then rerun `tools/c00/run_device_cycle.sh ipad <device>`.");
		} else if (!context.gate) {
			actions.push("iPad readiness passed after DDI recovery. Run `tools/c00/run_device_cycle.sh ipad <device>` or rerun this command with `--run-gate`.");
		}
		return actions;
	}
	const ddiText = [
		context.ddi && context.ddi.stdout,
		context.ddi && context.ddi.stderr,
		context.ddi && context.ddi.error,
	].join("\n");
	if (/unable to locate a device|unavailable|offline/i.test(ddiText)) {
		actions.push("The DDI auto-mount command could not locate the iPad. Unlock the iPad, keep the screen awake, reconnect USB-C, accept Trust This Computer, then open Xcode Devices and Simulators once.");
		actions.push("After the iPad no longer appears as unavailable/offline, rerun this recovery command.");
	} else if (/permission|Operation not permitted|XPCError|connection was invalidated/i.test(ddiText)) {
		actions.push("Run this recovery command from a normal macOS terminal or approved unsandboxed Codex command so CoreDevice can access XPC services and user caches.");
	} else {
		actions.push("Inspect the DDI auto-mount JSON/log and the after-readiness report, then reconnect/unlock/trust the iPad before retrying.");
	}
	return actions;
}


function summarizeJson(filePath) {
	try {
		if (!fs.existsSync(filePath)) {
			return null;
		}
		const parsed = JSON.parse(fs.readFileSync(filePath, "utf8"));
		return {
			info: parsed.info || null,
			error: parsed.error || null,
			result_keys: parsed.result && typeof parsed.result === "object" ? Object.keys(parsed.result).slice(0, 20) : [],
		};
	} catch (error) {
		return {
			parse_error: String(error.message || error),
		};
	}
}


function renderMarkdown(summary) {
	const lines = [];
	lines.push("# C00 iPad DDI Recovery");
	lines.push("");
	lines.push(`Generated: ${summary.generated_at}`);
	lines.push("");
	lines.push(`Device: \`${summary.device}\``);
	lines.push("");
	lines.push(`Result: ${summary.pass ? "PASS" : "FAIL"}`);
	lines.push("");
	lines.push("## Artifacts");
	lines.push("");
	lines.push(`- Before readiness: \`${summary.before.report}\``);
	lines.push(`- Before readiness JSON: \`${summary.before.json}\``);
	lines.push(`- DDI auto-mount JSON: \`${summary.ddi.json_output}\``);
	lines.push(`- DDI auto-mount log: \`${summary.ddi.log_output}\``);
	lines.push(`- After readiness: \`${summary.after.report}\``);
	lines.push(`- After readiness JSON: \`${summary.after.json}\``);
	lines.push("");
	lines.push("## Commands");
	lines.push("");
	pushCommand(lines, "Before readiness", summary.before);
	pushCommand(lines, "DDI auto-mount", summary.ddi);
	pushCommand(lines, "After readiness", summary.after);
	if (summary.gate) {
		pushCommand(lines, "iPad gate", summary.gate);
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
		"  node tools/c00/recover_ios_ddi_services.js --device <ipad-name-or-uuid> [--package <bundle-id>] [--timeout <seconds>] [--dir <evidence-dir>] [--report <file>] [--json <file>] [--run-gate]",
		"",
		"Runs iPad readiness, attempts `devicectl device info ddiServices --auto-mount-ddis`,",
		"then runs readiness again and preserves all evidence paths.",
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
