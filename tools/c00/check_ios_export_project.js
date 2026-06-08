#!/usr/bin/env node

const fs = require("fs");
const os = require("os");
const path = require("path");
const { spawnSync } = require("child_process");

const args = parseArgs(process.argv.slice(2));

if (args.help || args.h || !args.input) {
	usage();
	process.exit(args.input ? 0 : 2);
}

const input = path.resolve(String(args.input));
const requirePlugin = args["require-plugin"] !== false && args["require-plugin"] !== "0";
const expectedPlugin = String(args.plugin || "GodotARKit");
const expectedBinary = String(args.binary || `${expectedPlugin}.xcframework`);
const keepTemp = Boolean(args["keep-temp"]);

const work = resolveInput(input);
const summary = inspectExport(work.dir);
summary.input = input;
summary.extractedDir = work.dir;
summary.requirePlugin = requirePlugin;
summary.expectedPlugin = expectedPlugin;
summary.expectedBinary = expectedBinary;

if (!keepTemp && work.cleanup) {
	work.cleanup();
	summary.extractedDir = "";
}

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
		"  node tools/c00/check_ios_export_project.js --input <ios-export.zip-or-dir>",
		"",
		"Options:",
		"  --plugin <name>       Expected iOS plugin name. Default: GodotARKit.",
		"  --binary <name>       Expected plugin binary. Default: GodotARKit.xcframework.",
		"  --require-plugin 0    Downgrade missing plugin references to warnings.",
		"  --keep-temp           Keep temporary extraction directory for debugging.",
	].join("\n"));
}


function resolveInput(inputPath) {
	if (!fs.existsSync(inputPath)) {
		if (inputPath.toLowerCase().endsWith(".zip")) {
			const root = path.dirname(inputPath);
			const basename = path.basename(inputPath, ".zip");
			if (fs.existsSync(path.join(root, `${basename}.xcodeproj`))) {
				return { dir: root, cleanup: null };
			}
		}
		throwResult(`Input does not exist: ${inputPath}`);
	}
	const stats = fs.statSync(inputPath);
	if (stats.isDirectory()) {
		return { dir: inputPath, cleanup: null };
	}
	if (!stats.isFile() || !inputPath.toLowerCase().endsWith(".zip")) {
		throwResult(`Input must be a Godot iOS export .zip or unpacked directory: ${inputPath}`);
	}
	const unzip = spawnSync("command", ["-v", "unzip"], { encoding: "utf8", shell: true });
	if (unzip.status !== 0) {
		throwResult("Missing required command: unzip");
	}
	const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), "godot-ios-export-"));
	const result = spawnSync("unzip", ["-q", inputPath, "-d", tempDir], { encoding: "utf8" });
	if (result.status !== 0) {
		throwResult(`Failed to unzip ${inputPath}: ${result.stderr || result.stdout || result.error || "unknown error"}`);
	}
	return {
		dir: tempDir,
		cleanup: () => fs.rmSync(tempDir, { recursive: true, force: true }),
	};
}


function inspectExport(root) {
	const failures = [];
	const warnings = [];
	const files = walk(root);
	const projectFiles = files.filter((file) => file.endsWith(".xcodeproj/project.pbxproj"));
	const plistFiles = files.filter((file) => path.basename(file).endsWith(".plist"));
	const textFiles = files.filter((file) => isTextCandidate(file));
	const textByFile = new Map(textFiles.map((file) => [file, readText(file)]));
	const allText = Array.from(textByFile.values()).join("\n");
	const plistText = plistFiles.map((file) => readText(file)).join("\n");

	if (projectFiles.length === 0) {
		failures.push("No .xcodeproj/project.pbxproj found in the iOS export.");
	}
	if (plistFiles.length === 0) {
		failures.push("No Info.plist/plist file found in the iOS export.");
	}

	recordPluginProblem(
		allText.includes(expectedPlugin),
		`Exported Xcode project should reference the ${expectedPlugin} iOS plugin.`
	);
	recordPluginProblem(
		allText.includes(expectedBinary),
		`Exported Xcode project should reference ${expectedBinary}.`
	);
	recordPluginProblem(
		allText.includes("ARKit.framework"),
		"Exported Xcode project should link ARKit.framework."
	);
	recordPluginProblem(
		allText.includes("Metal.framework"),
		"Exported Xcode project should link Metal.framework."
	);

	if (!plistText.includes("NSCameraUsageDescription")) {
		failures.push("Exported Info.plist should include NSCameraUsageDescription.");
	}
	if (!plistText.includes("UIRequiredDeviceCapabilities")) {
		failures.push("Exported Info.plist should include UIRequiredDeviceCapabilities.");
	} else {
		for (const capability of ["arkit", "metal"]) {
			if (!new RegExp(`<string>\\s*${capability}\\s*</string>|\\b${capability}\\b`, "i").test(plistText)) {
				failures.push(`Exported Info.plist UIRequiredDeviceCapabilities should include ${capability}.`);
			}
		}
	}

	return {
		pass: failures.length === 0,
		failures,
		warnings,
		xcodeProjects: projectFiles.map((file) => path.relative(root, file)),
		plistFiles: plistFiles.map((file) => path.relative(root, file)),
		pluginReferences: {
			plugin: textHits(textByFile, expectedPlugin, root),
			binary: textHits(textByFile, expectedBinary, root),
			arkitFramework: textHits(textByFile, "ARKit.framework", root),
			metalFramework: textHits(textByFile, "Metal.framework", root),
			cameraUsage: textHits(textByFile, "NSCameraUsageDescription", root),
			deviceCapabilities: textHits(textByFile, "UIRequiredDeviceCapabilities", root),
		},
	};

	function recordPluginProblem(condition, message) {
		if (condition) {
			return;
		}
		if (requirePlugin) {
			failures.push(message);
		} else {
			warnings.push(message);
		}
	}
}


function walk(root) {
	const files = [];
	const stack = [root];
	while (stack.length > 0) {
		const current = stack.pop();
		let entries = [];
		try {
			entries = fs.readdirSync(current, { withFileTypes: true });
		} catch (error) {
			continue;
		}
		for (const entry of entries) {
			const absolute = path.join(current, entry.name);
			if (entry.isDirectory()) {
				stack.push(absolute);
			} else if (entry.isFile()) {
				files.push(absolute);
			}
		}
	}
	return files.sort();
}


function isTextCandidate(filePath) {
	const name = path.basename(filePath);
	const extension = path.extname(name).toLowerCase();
	return [
		".pbxproj",
		".plist",
		".xcconfig",
		".entitlements",
		".gdip",
		".h",
		".m",
		".mm",
		".txt",
		".xml",
	].includes(extension) || name === "project.pbxproj";
}


function readText(filePath) {
	try {
		return fs.readFileSync(filePath, "utf8");
	} catch (error) {
		return "";
	}
}


function textHits(textByFile, needle, root) {
	const hits = [];
	for (const [file, text] of textByFile.entries()) {
		if (text.includes(needle)) {
			hits.push(path.relative(root, file));
		}
	}
	return hits;
}


function throwResult(message) {
	const summary = {
		pass: false,
		failures: [message],
		warnings: [],
	};
	console.log(JSON.stringify(summary, null, 2));
	process.exit(1);
}
