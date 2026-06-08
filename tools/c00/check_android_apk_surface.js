#!/usr/bin/env node

const fs = require("fs");
const { spawnSync } = require("child_process");

const args = parseArgs(process.argv.slice(2));
const gate = String(args.gate || "").toLowerCase();
const apk = args.apk || args.input || "";

if (args.help || args.h || !gate || !apk) {
	usage();
	process.exit(args.help || args.h ? 0 : 2);
}

if (!["rokid", "android-arcore"].includes(gate)) {
	console.error(`Unsupported gate: ${gate}`);
	usage();
	process.exit(2);
}

if (!fs.existsSync(apk)) {
	console.error(`Missing APK: ${apk}`);
	process.exit(1);
}

const failures = [];
const warnings = [];
const listing = run("unzip", ["-l", apk]);
const commandLineAsset = runBuffer("unzip", ["-p", apk, "assets/_cl_"], { allowFailure: true });
const commandLineArgs = decodeGodotCommandLine(commandLineAsset.stdout);
const commandLineText = commandLineArgs.join("\n");

if (!listing.ok) {
	failures.push(`Could not inspect APK listing with unzip: ${listing.stderr || listing.error || "unknown error"}`);
}

if (!commandLineAsset.stdout.length) {
	failures.push("APK is missing assets/_cl_; export preset command_line/extra_args cannot be verified.");
}

if (gate === "rokid") {
	requireCommandLine("--xr-platform=rokid");
	requireListing("lib/arm64-v8a/libopenxr_loader.so", "Rokid/OpenXR APK must include the OpenXR loader from the selected vendor AAR.");
	requireListing("lib/arm64-v8a/libgodotopenxrvendors.so", "Rokid/OpenXR APK must include Godot OpenXR Vendors GDExtension native library.");
	requireListing("assets/addons/godotopenxrvendors/plugin.gdextension", "Rokid/OpenXR APK must include the OpenXR Vendors GDExtension descriptor from the AAR.");
	forbidListing("libarcore_sdk", "Rokid/OpenXR APK should not include ARCore native libraries; keep ARCore in the Android ARCore preset.");
}

if (gate === "android-arcore") {
	requireCommandLine("--xr-platform=arcore");
	requireListing("lib/arm64-v8a/libarcore_sdk_c.so", "Android ARCore APK must include the ARCore native library.");
	forbidListing("lib/arm64-v8a/libopenxr_loader.so", "Android ARCore APK should not include an OpenXR vendor loader.");
}

const summary = {
	apk,
	gate,
	pass: failures.length === 0,
	failures,
	warnings,
	command_line: commandLineArgs,
};

console.log(JSON.stringify(summary, null, 2));
process.exit(summary.pass ? 0 : 1);

function requireCommandLine(expected) {
	if (!commandLineText.includes(expected)) {
		failures.push(`APK assets/_cl_ must include ${expected}.`);
	}
}

function requireListing(needle, message) {
	if (!listing.stdout.includes(needle)) {
		failures.push(message);
	}
}

function forbidListing(needle, message) {
	if (listing.stdout.includes(needle)) {
		failures.push(message);
	}
}

function run(command, argv, options = {}) {
	const result = spawnSync(command, argv, { encoding: "utf8" });
	const ok = result.status === 0;
	if (!ok && !options.allowFailure) {
		return {
			ok,
			stdout: result.stdout || "",
			stderr: result.stderr || "",
			error: result.error ? String(result.error) : "",
		};
	}
	return {
		ok,
		stdout: result.stdout || "",
		stderr: result.stderr || "",
		error: result.error ? String(result.error) : "",
	};
}

function runBuffer(command, argv, options = {}) {
	const result = spawnSync(command, argv);
	const ok = result.status === 0;
	if (!ok && !options.allowFailure) {
		return {
			ok,
			stdout: result.stdout || Buffer.alloc(0),
			stderr: result.stderr ? result.stderr.toString("utf8") : "",
			error: result.error ? String(result.error) : "",
		};
	}
	return {
		ok,
		stdout: result.stdout || Buffer.alloc(0),
		stderr: result.stderr ? result.stderr.toString("utf8") : "",
		error: result.error ? String(result.error) : "",
	};
}

function decodeGodotCommandLine(buffer) {
	if (!buffer.length) {
		return [];
	}
	if (buffer.length < 4) {
		return [buffer.toString("utf8").trim()].filter(Boolean);
	}
	const count = buffer.readUInt32LE(0);
	const values = [];
	let offset = 4;
	for (let index = 0; index < count; index += 1) {
		if (offset + 4 > buffer.length) {
			return [buffer.toString("utf8").trim()].filter(Boolean);
		}
		const length = buffer.readUInt32LE(offset);
		offset += 4;
		if (offset + length > buffer.length) {
			return [buffer.toString("utf8").trim()].filter(Boolean);
		}
		values.push(buffer.subarray(offset, offset + length).toString("utf8"));
		offset += length;
	}
	return values;
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
		"  node tools/c00/check_android_apk_surface.js --gate <rokid|android-arcore> --apk <path.apk>",
		"",
		"Checks exported APK launch args and native XR loader/library contents.",
	].join("\n"));
}
