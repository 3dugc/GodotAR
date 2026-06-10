#!/usr/bin/env node

const fs = require("fs");
const os = require("os");
const path = require("path");

const args = parseArgs(process.argv.slice(2));

if (args.help || args.h) {
	usage();
	process.exit(0);
}

const androidSdk = requiredEnv("GODOT_ANDROID_SDK_PATH");
const javaSdk = requiredEnv("GODOT_JAVA_SDK_PATH");
const debugKeystore = requiredEnv("GODOT_ANDROID_KEYSTORE_DEBUG_PATH");
const debugUser = requiredEnv("GODOT_ANDROID_KEYSTORE_DEBUG_USER");
const debugPassword = requiredEnv("GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD");
const settingsFile = args["settings-file"]
	? path.resolve(String(args["settings-file"]))
	: resolveSettingsFile(String(args["godot-version"] || process.env.GODOT_VERSION || process.env.GODOT_EXPORT_TEMPLATES_VERSION || process.env.C00_GODOT_DEFAULT_EXPORT_TEMPLATES_VERSION || "4.7.rc1"));

const settings = {
	"export/android/android_sdk_path": androidSdk,
	"export/android/java_sdk_path": javaSdk,
	"export/android/debug_keystore": debugKeystore,
	"export/android/debug_keystore_user": debugUser,
	"export/android/debug_keystore_pass": debugPassword,
};

const current = fs.existsSync(settingsFile)
	? fs.readFileSync(settingsFile, "utf8")
	: "[gd_resource type=\"EditorSettings\" format=3]\n\n[resource]\n";
const next = updateSettings(current, settings);

if (args["dry-run"]) {
	process.stdout.write(JSON.stringify({
		settings_file: settingsFile,
		would_update: Object.keys(settings),
	}, null, 2));
	process.stdout.write("\n");
	process.exit(0);
}

fs.mkdirSync(path.dirname(settingsFile), { recursive: true });
fs.writeFileSync(settingsFile, next, "utf8");

console.log(`configured Godot editor settings: ${settingsFile}`);
for (const key of Object.keys(settings)) {
	if (key.endsWith("_pass")) {
		console.log(`configured ${key}=<hidden>`);
	} else {
		console.log(`configured ${key}=${settings[key]}`);
	}
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
		"  GODOT_ANDROID_SDK_PATH=/path/to/sdk \\",
		"  GODOT_JAVA_SDK_PATH=/path/to/jdk \\",
		"  GODOT_ANDROID_KEYSTORE_DEBUG_PATH=/path/to/debug.keystore \\",
		"  GODOT_ANDROID_KEYSTORE_DEBUG_USER=androiddebugkey \\",
		"  GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD=android \\",
		"    node tools/c00/write_godot_android_editor_settings.js [--settings-file <file>] [--godot-version 4.7.rc1]",
	].join("\n"));
}

function requiredEnv(name) {
	const value = process.env[name];
	if (!value) {
		console.error(`Missing environment value: ${name}`);
		process.exit(2);
	}
	return value;
}

function resolveSettingsFile(version) {
	const majorMinor = /^(\d+\.\d+)/.exec(version)?.[1] || "4.4";
	const major = /^(\d+)/.exec(version)?.[1] || "4";
	const base = resolveGodotConfigDir();
	const candidates = [
		path.join(base, `editor_settings-${majorMinor}.tres`),
		path.join(base, `editor_settings-${major}.tres`),
	];
	for (const candidate of candidates) {
		if (fs.existsSync(candidate)) {
			return candidate;
		}
	}
	return candidates[0];
}

function resolveGodotConfigDir() {
	if (process.platform === "darwin") {
		return path.join(os.homedir(), "Library", "Application Support", "Godot");
	}
	if (process.platform === "win32") {
		const appData = process.env.APPDATA || path.join(os.homedir(), "AppData", "Roaming");
		return path.join(appData, "Godot");
	}
	return path.join(process.env.XDG_CONFIG_HOME || path.join(os.homedir(), ".config"), "godot");
}

function updateSettings(text, values) {
	let output = text;
	if (!/^\[resource\]\s*$/m.test(output)) {
		output = `${output.replace(/\s*$/, "")}\n\n[resource]\n`;
	}

	const missing = [];
	for (const [key, value] of Object.entries(values)) {
		const line = `${key} = ${quoteGodotString(value)}`;
		const pattern = new RegExp(`^${escapeRegExp(key)}\\s*=.*$`, "m");
		if (pattern.test(output)) {
			output = output.replace(pattern, line);
		} else {
			missing.push(line);
		}
	}

	if (missing.length > 0) {
		output = output.replace(/^\[resource\]\s*$/m, `[resource]\n${missing.join("\n")}`);
	}
	return `${output.replace(/\s*$/, "")}\n`;
}

function quoteGodotString(value) {
	return `"${String(value).replace(/\\/g, "\\\\").replace(/"/g, '\\"')}"`;
}

function escapeRegExp(value) {
	return String(value).replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}
