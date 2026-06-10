#!/usr/bin/env node

const fs = require("fs");
const path = require("path");

const PROJECT_ROOT = path.resolve(__dirname, "../..");
const checks = [
	{
		file: "UNITY_REFERENCE_RULES_CN.md",
		requirements: [
			["current review date", /当前巡检日期：2026-06-10/],
			["Unity dist-tags.latest policy", /dist-tags\.latest/],
			["AR Foundation 6.5 baseline", /com\.unity\.xr\.arfoundation@6\.5\.0/],
			["AR Foundation 6.6 pre-release tracking", /com\.unity\.xr\.arfoundation@6\.6\.0-pre\.2/],
			["XR Core Utilities 2.6 baseline", /com\.unity\.xr\.core-utils@2\.6\.0/],
			["XRI 3.5.1 baseline", /com\.unity\.xr\.interaction\.toolkit@3\.5\.1/],
			["OpenXR 1.17.1 baseline", /com\.unity\.xr\.openxr@1\.17\.1/],
			["ARCore 6.5 baseline", /com\.unity\.xr\.arcore@6\.5\.0/],
			["ARCore 6.6 pre-release tracking", /com\.unity\.xr\.arcore@6\.6\.0-pre\.2/],
			["ARKit 6.5 baseline", /com\.unity\.xr\.arkit@6\.5\.0/],
			["ARKit 6.6 pre-release tracking", /com\.unity\.xr\.arkit@6\.6\.0-pre\.2/],
			["Android XR OpenXR baseline", /com\.unity\.xr\.androidxr-openxr@1\.3\.1/],
			["Unity 6000.6 alpha source", /unity\.com\/releases\/editor\/alpha/],
			["latest-forward policy", /若未来 Unity 官方 registry 或文档出现更高版本/],
			["deprecated API compatibility policy", /旧 Unity API 只能作为迁移兼容层/],
			["Unity 6.5 AR Foundation package URL", /docs\.unity3d\.com\/Packages\/com\.unity\.xr\.arfoundation%406\.5\/manual\/index\.html/],
			["Unity AR Foundation registry URL", /packages\.unity\.com\/com\.unity\.xr\.arfoundation/],
			["Unity XRI 3.5 package URL", /docs\.unity3d\.com\/Packages\/com\.unity\.xr\.interaction\.toolkit%403\.5\/manual\/index\.html/],
			["Unity OpenXR 1.17 package URL", /docs\.unity3d\.com\/Packages\/com\.unity\.xr\.openxr%401\.17\/manual\/index\.html/],
			["Unity OpenXR registry URL", /packages\.unity\.com\/com\.unity\.xr\.openxr/],
			["Unity ARCore 6.6 docs URL", /docs\.unity3d\.com\/Packages\/com\.unity\.xr\.arcore%406\.6\/manual\/index\.html/],
			["Unity ARKit registry URL", /packages\.unity\.com\/com\.unity\.xr\.arkit/],
			["XRI 3.1 compatibility URL", /docs\.unity\.cn\/Packages\/com\.unity\.xr\.interaction\.toolkit%403\.1\/manual\/index\.html/],
			["OpenXR 1.17 changelog URL", /docs\.unity3d\.com\/Packages\/com\.unity\.xr\.openxr%401\.17\/changelog\/CHANGELOG\.html/],
		],
	},
	{
		file: "MIGRATION_UNITY.md",
		requirements: [
			["Unity 6000.6 alpha baseline", /Unity 6000\.6 alpha release notes/],
			["Unity registry latest migration policy", /dist-tags\.latest.*forward design baseline/s],
			["AR Foundation 6.5 migration baseline", /com\.unity\.xr\.arfoundation@6\.5\.0/],
			["AR Foundation 6.6 migration tracking", /com\.unity\.xr\.arfoundation@6\.6\.0-pre\.2/],
			["XRI 3.5.1 migration baseline", /com\.unity\.xr\.interaction\.toolkit@3\.5\.1/],
			["OpenXR 1.17.1 migration baseline", /com\.unity\.xr\.openxr@1\.17\.1/],
			["Unity 6.5/6.6 package docs with 6.4 API fallback", /Unity 6\.5\/6\.6 package manuals are the current public package reference.*Unity 6\.4 package API pages remain/s],
			["pre-release baseline policy", /pre-release, preview.*unreleased package documentation/s],
			["XROrigin preferred", /prefer the latest `XROrigin`/],
			["ARSessionOrigin compatibility", /ARSessionOrigin.*compatibility/s],
		],
	},
	{
		file: "specs/cycles/CYCLE_00_DEVICE_SMOKE_SPEC_CN.md",
		requirements: [
			["C00 latest baseline policy", /pre-release \/ preview \/ unreleased 官方文档/],
			["C00 alpha release notes baseline", /6000\.6 alpha release notes/],
			["C00 registry latest policy", /dist-tags\.latest`? 前向基线/],
			["C00 AR Foundation 6.5 baseline", /com\.unity\.xr\.arfoundation@6\.5\.0/],
			["C00 AR Foundation 6.6 tracking", /com\.unity\.xr\.arfoundation@6\.6\.0-pre\.2/],
			["C00 XRI 3.5.1 baseline", /com\.unity\.xr\.interaction\.toolkit@3\.5\.1/],
			["C00 XROrigin surface", /Unity 6\.x `XROrigin` 作为主入口/],
		],
	},
	{
		file: "specs/cycles/CYCLE_01_FOUNDATION_MVP_SPEC_CN.md",
		requirements: [
			["C01 latest baseline policy", /pre-release、preview 或 unreleased 文档/],
			["C01 registry latest policy", /dist-tags\.latest.*前向设计基线/],
			["C01 AR Foundation 6.5 baseline", /com\.unity\.xr\.arfoundation@6\.5\.0/],
			["C01 AR Foundation 6.6 tracking", /com\.unity\.xr\.arfoundation@6\.6\.0-pre\.2/],
			["C01 XRI 3.5.1 baseline", /com\.unity\.xr\.interaction\.toolkit@3\.5\.1/],
			["C01 XROrigin baseline", /`XROrigin` 是主入口/],
		],
	},
];

const failures = [];
const evidence = [];

for (const item of checks) {
	const absolutePath = path.join(PROJECT_ROOT, item.file);
	const text = fs.existsSync(absolutePath) ? fs.readFileSync(absolutePath, "utf8") : "";
	if (!text) {
		failures.push(`Missing required file: ${item.file}`);
		evidence.push({ file: item.file, exists: false, passed: 0, total: item.requirements.length });
		continue;
	}
	let passed = 0;
	for (const [label, pattern] of item.requirements) {
		if (pattern.test(text)) {
			passed += 1;
		} else {
			failures.push(`${item.file}: missing ${label}`);
		}
	}
	evidence.push({ file: item.file, exists: true, passed, total: item.requirements.length });
}

const result = {
	pass: failures.length === 0,
	projectRoot: PROJECT_ROOT,
	failures,
	evidence,
};

console.log(JSON.stringify(result, null, 2));
process.exit(result.pass ? 0 : 1);
