#!/usr/bin/env node

const fs = require("fs");
const path = require("path");

const PROJECT_ROOT = path.resolve(__dirname, "../..");
const DEFAULT_PLUGIN_DIR = path.join(PROJECT_ROOT, "ios/plugins/godot_arkit");

const args = parseArgs(process.argv.slice(2));

if (args.help || args.h) {
	usage();
	process.exit(0);
}

const pluginDir = path.resolve(args.dir || DEFAULT_PLUGIN_DIR);
const gdipPath = path.resolve(args.file || firstExisting([
	path.join(pluginDir, "GodotARKit.gdip"),
	path.join(pluginDir, "GodotARKit.gdip.template"),
]));
const requireBinary = Boolean(args["require-binary"]);
const sourcePath = path.resolve(args.source || path.join(pluginDir, "src/GodotARKitPlugin.mm"));

const failures = [];
const warnings = [];
const gdip = readGdip(gdipPath);

if (!gdip.exists) {
	failures.push(`Missing iOS plugin config: ${gdipPath}`);
}

const config = gdip.sections.config || {};
const dependencies = gdip.sections.dependencies || {};
const plist = gdip.sections.plist || {};

requireValue("config.name", config.name, "GodotARKit");
requireValue("config.binary", config.binary, "GodotARKit.xcframework");
requireValue("config.initialization", config.initialization, "init_godot_arkit");
requireValue("config.deinitialization", config.deinitialization, "deinit_godot_arkit");

requireArrayIncludes("dependencies.system", dependencies.system, [
	"Foundation.framework",
	"UIKit.framework",
	"ARKit.framework",
	"CoreMotion.framework",
	"Metal.framework",
]);
requireArrayIncludes("dependencies.capabilities", dependencies.capabilities, ["arkit", "metal"]);
requireArrayIncludes("dependencies.linker_flags", dependencies.linker_flags, ["-ObjC"]);

if (!hasPlistKey(plist, "NSCameraUsageDescription")) {
	failures.push("plist must include NSCameraUsageDescription.");
}
if (!hasPlistKey(plist, "UIRequiredDeviceCapabilities")) {
	failures.push("plist must include UIRequiredDeviceCapabilities with arkit/metal.");
} else {
	const rawCapabilities = Object.entries(plist)
		.find(([key]) => key.split(":")[0] === "UIRequiredDeviceCapabilities");
	const value = rawCapabilities ? String(rawCapabilities[1]) : "";
	for (const expected of ["arkit", "metal"]) {
		if (!value.includes(expected)) {
			failures.push(`UIRequiredDeviceCapabilities should include ${expected}.`);
		}
	}
}

const binaryEvidence = resolveBinary(gdipPath, config.binary || "");
if (config.binary && !binaryEvidence.exists) {
	const message = `Binary referenced by gdip is missing: ${binaryEvidence.path}`;
	if (requireBinary) {
		failures.push(message);
	} else {
		warnings.push(message);
	}
}

const source = readText(sourcePath);
if (!source) {
	failures.push(`Missing plugin source for symbol check: ${sourcePath}`);
} else {
	for (const symbol of [config.initialization, config.deinitialization].filter(Boolean)) {
		if (!new RegExp(`extern\\s+"C"\\s+void\\s+${escapeRegExp(symbol)}\\s*\\(`).test(source)) {
			failures.push(`Source must export extern "C" void ${symbol}(...).`);
		}
	}
	if (!source.includes('Engine::get_singleton()->add_singleton(Engine::Singleton("GodotARKit"')) {
		failures.push("Source must register the GodotARKit Engine singleton.");
	}
	if (!source.includes("ClassDB::register_class<GodotARKitPlugin>()")) {
		failures.push("Source must register GodotARKitPlugin with ClassDB before exposing the singleton.");
	}
}

const summary = {
	pass: failures.length === 0,
	file: gdipPath,
	pluginDir,
	requireBinary,
	failures,
	warnings,
	config,
	dependencies,
	plistKeys: Object.keys(plist),
	binary: binaryEvidence,
	source: sourcePath,
};

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
		"  node tools/c00/check_ios_plugin_artifacts.js [--file ios/plugins/godot_arkit/GodotARKit.gdip.template] [--require-binary]",
		"",
		"Options:",
		"  --dir <dir>          iOS plugin directory. Default: ios/plugins/godot_arkit",
		"  --file <file>        gdip or gdip.template to validate.",
		"  --source <file>      Objective-C++ source used for symbol checks.",
		"  --require-binary     Treat a missing referenced xcframework as failure instead of warning.",
	].join("\n"));
}


function firstExisting(paths) {
	return paths.find((item) => fs.existsSync(item)) || paths[0];
}


function readGdip(filePath) {
	const text = readText(filePath);
	const sections = {};
	let current = "";
	let pending = null;
	for (const rawLine of text.split(/\r?\n/)) {
		if (pending) {
			if (rawLine.trim() === "\"") {
				sections[pending.section][pending.key] = pending.lines.join("\n");
				pending = null;
			} else if (rawLine.endsWith("\"")) {
				pending.lines.push(rawLine.slice(0, -1));
				sections[pending.section][pending.key] = pending.lines.join("\n");
				pending = null;
			} else {
				pending.lines.push(rawLine);
			}
			continue;
		}

		const line = rawLine.trim();
		if (!line || line.startsWith(";") || line.startsWith("#")) {
			continue;
		}
		const sectionMatch = line.match(/^\[([^\]]+)\]$/);
		if (sectionMatch) {
			current = sectionMatch[1];
			sections[current] = sections[current] || {};
			continue;
		}
		const keyValue = line.match(/^([^=]+)=(.*)$/);
		if (current && keyValue) {
			const key = keyValue[1].trim();
			const value = keyValue[2].trim();
			if (value === "\"" || (value.startsWith("\"") && !value.endsWith("\""))) {
				pending = {
					section: current,
					key,
					lines: [value.slice(1)],
				};
			} else {
				sections[current][key] = decodeValue(value);
			}
		}
	}
	return {
		exists: Boolean(text),
		text,
		sections,
	};
}


function decodeValue(value) {
	if (value.startsWith("[") && value.endsWith("]")) {
		try {
			return JSON.parse(value);
		} catch (error) {
			return value;
		}
	}
	if (value.startsWith('"') && value.endsWith('"')) {
		return value.slice(1, -1).replace(/\\"/g, '"');
	}
	return value;
}


function requireValue(name, actual, expected) {
	if (actual !== expected) {
		failures.push(`${name} should be ${JSON.stringify(expected)}, observed ${JSON.stringify(actual || "")}.`);
	}
}


function requireArrayIncludes(name, actual, expectedValues) {
	if (!Array.isArray(actual)) {
		failures.push(`${name} should be an array.`);
		return;
	}
	for (const expected of expectedValues) {
		if (!actual.includes(expected)) {
			failures.push(`${name} should include ${expected}.`);
		}
	}
}


function hasPlistKey(plist, expectedKey) {
	return Object.keys(plist).some((key) => key.split(":")[0] === expectedKey);
}


function resolveBinary(gdipPath, binary) {
	if (!binary) {
		return { path: "", exists: false };
	}
	const binaryPath = binary.startsWith("res://")
		? path.join(PROJECT_ROOT, binary.slice("res://".length))
		: path.resolve(path.dirname(gdipPath), binary);
	return {
		path: binaryPath,
		exists: fs.existsSync(binaryPath),
	};
}


function readText(filePath) {
	try {
		return fs.readFileSync(filePath, "utf8");
	} catch (error) {
		return "";
	}
}


function escapeRegExp(value) {
	return String(value).replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}
