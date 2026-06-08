#!/usr/bin/env node

const fs = require("fs");
const path = require("path");

const args = parseArgs(process.argv.slice(2));

if (args.help || args.h) {
	usage();
	process.exit(0);
}

const profilePath = args.json ? path.resolve(String(args.json)) : "";
const gate = String(args.gate || "").toLowerCase();
const reportPath = args.report ? path.resolve(String(args.report)) : "";
const strictRuntimePackage = Boolean(args["strict-runtime-package"]);
const allowMissingTarget = Boolean(args["allow-missing-target"]);

if (!profilePath || !gate) {
	usage();
	process.exit(2);
}
if (!["rokid", "android-arcore"].includes(gate)) {
	console.error(`Unsupported Android profile analysis gate: ${gate}`);
	process.exit(2);
}

let profile = null;
try {
	profile = JSON.parse(fs.readFileSync(profilePath, "utf8"));
} catch (error) {
	const summary = {
		gate,
		profile: profilePath,
		pass: false,
		failures: [`Device profile JSON is not readable or parseable: ${String(error.message || error)}`],
		warnings: [],
		evidence: {},
	};
	writeReport(summary);
	console.log(JSON.stringify(summary, null, 2));
	process.exit(1);
}

const summary = analyzeProfile(profile, gate);
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
		"  node tools/c00/analyze_android_device_profile.js --gate <rokid|android-arcore> --json <profile.json> [--report <file>]",
		"",
		"Options:",
		"  --strict-runtime-package  Treat missing XR/OpenXR runtime package evidence as failure for Rokid.",
		"  --allow-missing-target    Downgrade missing target package to warning.",
	].join("\n"));
}


function analyzeProfile(profile, gateName) {
	const failures = [];
	const warnings = [];
	const properties = profile.properties || {};
	const notableFeatures = arrayOfStrings(profile.notable_features);
	const xrPackages = arrayOfStrings(profile.xr_related_packages);
	const targetPackage = profile.target_package || {};
	const display = profile.display || {};
	const deviceText = [
		properties["ro.product.manufacturer"],
		properties["ro.product.brand"],
		properties["ro.product.model"],
		properties["ro.product.device"],
		properties["ro.product.name"],
		properties["ro.hardware"],
	].filter(Boolean).join(" ");

	if (profile.gate && String(profile.gate).toLowerCase() !== gateName) {
		warnings.push(`Profile was collected for gate "${profile.gate}", but analyzed as "${gateName}".`);
	}
	if (!profile.adb || profile.adb.available !== true) {
		failures.push("adb was not available during device profile collection.");
	}
	if (!targetPackage.installed) {
		recordMissingTarget(`Target package was not installed when profile was collected: ${profile.package || "unknown package"}`);
	}
	if (!properties["ro.product.model"]) {
		warnings.push("Device model is missing from ro.product.model.");
	}
	if (!display.size) {
		warnings.push("Display size is missing from wm size.");
	}
	if (!display.density) {
		warnings.push("Display density is missing from wm density.");
	}
	if (!hasMatch(notableFeatures, /camera/i)) {
		warnings.push("No camera feature was detected; camera passthrough or handheld AR may be unavailable.");
	}
	if (!hasMatch(notableFeatures, /vulkan/i)) {
		warnings.push("No Vulkan feature was detected; Godot OpenXR Android builds may fail or fall back.");
	}

	if (gateName === "rokid") {
		const hasOpenXRPackage = hasMatch(xrPackages, /openxr|rokid|pico|quest|oculus|meta|lynx|vive|wave/i);
		if (!hasOpenXRPackage) {
			recordRuntimePackage("No OpenXR/Rokid/vendor runtime package was detected in pm list packages.");
		}
		if (!/rokid/i.test(deviceText)) {
			warnings.push(`Rokid gate expected Rokid hardware; observed "${deviceText || "unknown device"}". This may still be useful for future OpenXR devices, but it is not Rokid-specific evidence.`);
		}
		if (!hasMatch(notableFeatures, /xr|vr/i)) {
			warnings.push("No XR/VR feature flag was detected; rely on runtime smoke log for final OpenXR proof.");
		}
	}

	if (gateName === "android-arcore") {
		if (!hasMatch(xrPackages, /google\.ar\.core|arcore/i)) {
			failures.push("No ARCore package was detected for the Android ARCore gate.");
		}
	}

	for (const warning of arrayOfStrings(profile.warnings)) {
		warnings.push(`collector: ${warning}`);
	}

	return {
		gate: gateName,
		profile: profilePath,
		pass: failures.length === 0,
		failures,
		warnings,
		evidence: {
			device: deviceText || "unknown",
			target_package_installed: Boolean(targetPackage.installed),
			target_package_version: targetPackage.version_name || targetPackage.version_code || "",
			xr_related_packages: xrPackages,
			notable_features: notableFeatures,
			display,
		},
	};

	function recordRuntimePackage(message) {
		if (strictRuntimePackage) {
			failures.push(message);
		} else {
			warnings.push(`${message} Final proof still comes from GXF_SMOKE backend/capability evidence.`);
		}
	}

	function recordMissingTarget(message) {
		if (allowMissingTarget) {
			warnings.push(message);
		} else {
			failures.push(message);
		}
	}
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
	lines.push(`# C00 Android Device Profile Analysis: ${summary.gate}`);
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


function arrayOfStrings(value) {
	return Array.isArray(value) ? value.map((item) => String(item)) : [];
}


function hasMatch(items, pattern) {
	return items.some((item) => pattern.test(item));
}
