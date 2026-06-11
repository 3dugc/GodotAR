# C00 Phase 1 Completion Audit

Generated: 2026-06-11T13:19:13.380Z

Result: NOT_READY

Project: `/Users/dirui/Documents/Codex/2026-06-08/godot-ar-ar-core-ios-ar/work/GodotAR`

Evidence: `/Users/dirui/Documents/Codex/2026-06-08/godot-ar-ar-core-ios-ar/work/GodotAR/releases/phase_0_smoke/evidence`

## Verdict

Phase 1 is not ready. Do not publish C00 as complete until every required item below passes.

## Required Checks

| Status | Group | Check | Next action |
| --- | --- | --- | --- |
| PASS | static | C00 static gates | All code/static/API/export-surface gates pass. |
| PASS | unity-migration | ARFoundation migration API surface | Unity-style ARSession, raycast, trackables, and changed-event facades are present. |
| PASS | unity-migration | XRI interaction API surface | Unity XRI-style manager/ray/interactable smoke surface is present. |
| PASS | ios | GodotARKit plugin binary artifacts | GodotARKit.gdip and GodotARKit.xcframework are built and usable by Godot iOS export. |
| PASS | rokid-openxr | Rokid/OpenXR provider evidence surface | OpenXR AR evidence, passthrough report, and virtual-plane fallback diagnostics are guarded. |
| PASS | android-arcore | Android ARCore plugin and gate surface | ARCore gate requires explicit native ARCore runtime/capability evidence. |
| PASS | device-machine | rokid preflight | rokid export/device prerequisites are present on this machine. |
| PASS | device-machine | ipad preflight | ipad export/device prerequisites are present on this machine. |
| PASS | device-machine | android-arcore preflight | android-arcore export/device prerequisites are present on this machine. |
| PASS | device-machine | rokid-place preflight | rokid-place export/device prerequisites are present on this machine. |
| PASS | device-machine | ipad-place preflight | ipad-place export/device prerequisites are present on this machine. |
| FAIL | device-evidence | Rokid/iPad/Android phase evidence plus placement demos | Collect or import real device evidence, then rerun this audit. |

## Blocking Items

- Rokid/iPad/Android phase evidence plus placement demos: Collect or import real device evidence, then rerun this audit.

## Command Output Preview

### C00 static gates

Command: `node tools/c00/run_static_gates.js --gate all --format json`

```text
{
  "pass": true,
  "gate": "all",
  "projectRoot": "/Users/dirui/Documents/Codex/2026-06-08/godot-ar-ar-core-ios-ar/work/GodotAR",
  "failures": [],
  "warnings": [],
  "results": [
    {
      "name": "node --check tools/c00/analyze_android_device_profile.js",
      "status": "PASS",
      "command": "node --check tools/c00/analyze_android_device_profile.js",
      "output": ""
    },
    {
      "name": "node --check tools/c00/analyze_ios_device_profile.js",
      "status": "PASS",
      "command": "node --check tools/c00/analyze_ios_device_profile.js",
      "output": ""
    },
    {
      "name": "node --check tools/c00/audit_phase1_completion.js",
      "status": "PASS",
      "command": "node --check tools/c00/audit_phase1_completion.js",
      "output": ""
    },
    {
      "name": "node --check tools/c00/check_android_apk_surface.js",
      "status": "PASS",
... (545 more lines)
```

### ARFoundation migration API surface

Command: `node tools/c00/check_arfoundation_api_surface.js`

```text
{
  "pass": true,
  "projectRoot": "/Users/dirui/Documents/Codex/2026-06-08/godot-ar-ar-core-ios-ar/work/GodotAR",
  "failures": [],
  "evidence": [
    {
      "file": "addons/godot_xr_foundation/scripts/xr_foundation_types.gd",
      "exists": true,
      "passed": 12,
      "total": 12
    },
    {
      "file": "addons/godot_xr_foundation/scripts/xr_foundation.gd",
      "exists": true,
      "passed": 5,
      "total": 5
    },
    {
      "file": "addons/godot_xr_foundation/scripts/providers/xr_provider.gd",
      "exists": true,
      "passed": 2,
      "total": 2
    },
    {
      "file": "addons/godot_xr_foundation/scripts/arfoundation/xr_session_manager.gd",
      "exists": true,
      "passed": 6,
      "total": 6
... (93 more lines)
```

### XRI interaction API surface

Command: `node tools/c00/check_xri_api_surface.js`

```text
{
  "pass": true,
  "projectRoot": "/Users/dirui/Documents/Codex/2026-06-08/godot-ar-ar-core-ios-ar/work/GodotAR",
  "failures": [],
  "evidence": [
    {
      "file": "addons/godot_xr_foundation/scripts/xri/xr_input_profile.gd",
      "exists": true,
      "passed": 9,
      "total": 9
    },
    {
      "file": "addons/godot_xr_foundation/scripts/xri/xr_interaction_manager.gd",
      "exists": true,
      "passed": 14,
      "total": 14
    },
    {
      "file": "addons/godot_xr_foundation/scripts/xri/xr_ray_interactor.gd",
      "exists": true,
      "passed": 17,
      "total": 17
    },
    {
      "file": "addons/godot_xr_foundation/scripts/xri/xr_grab_interactable.gd",
      "exists": true,
      "passed": 12,
      "total": 12
... (15 more lines)
```

### GodotARKit plugin binary artifacts

Command: `node tools/c00/check_ios_plugin_artifacts.js --require-binary`

```text
{
  "pass": true,
  "file": "/Users/dirui/Documents/Codex/2026-06-08/godot-ar-ar-core-ios-ar/work/GodotAR/ios/plugins/godot_arkit/GodotARKit.gdip",
  "pluginDir": "/Users/dirui/Documents/Codex/2026-06-08/godot-ar-ar-core-ios-ar/work/GodotAR/ios/plugins/godot_arkit",
  "requireBinary": true,
  "failures": [],
  "warnings": [],
  "config": {
    "name": "GodotARKit",
    "binary": "GodotARKit.xcframework",
    "initialization": "init_godot_arkit",
    "deinitialization": "deinit_godot_arkit"
  },
  "dependencies": {
    "linked": [],
    "embedded": [],
    "system": [
      "Foundation.framework",
      "UIKit.framework",
      "ARKit.framework",
      "CoreMotion.framework",
      "Metal.framework"
    ],
    "capabilities": [
      "arkit",
      "metal"
    ],
    "files": [],
... (18 more lines)
```

### Rokid/OpenXR provider evidence surface

Command: `node tools/c00/check_openxr_provider_surface.js`

```text
{
  "pass": true,
  "projectRoot": "/Users/dirui/Documents/Codex/2026-06-08/godot-ar-ar-core-ios-ar/work/GodotAR",
  "failures": [],
  "evidence": [
    {
      "file": "addons/godot_xr_foundation/scripts/providers/openxr_provider.gd",
      "exists": true,
      "passed": 23,
      "total": 23
    },
    {
      "file": "addons/godot_xr_foundation/scripts/xr_foundation.gd",
      "exists": true,
      "passed": 4,
      "total": 4
    },
    {
      "file": "tools/c00/validate_smoke_log.js",
      "exists": true,
      "passed": 2,
      "total": 2
    },
    {
      "file": "tools/c00/verify_phase_evidence.js",
      "exists": true,
      "passed": 2,
      "total": 2
... (27 more lines)
```

### Android ARCore plugin and gate surface

Command: `node tools/c00/check_arcore_gate_surface.js`

```text
{
  "pass": true,
  "projectRoot": "/Users/dirui/Documents/Codex/2026-06-08/godot-ar-ar-core-ios-ar/work/GodotAR",
  "failures": [],
  "evidence": [
    {
      "file": "addons/godot_xr_foundation/scripts/providers/native_xr_provider.gd",
      "exists": true,
      "passed": 2,
      "total": 2
    },
    {
      "file": "tools/c00/validate_smoke_log.js",
      "exists": true,
      "passed": 3,
      "total": 3
    },
    {
      "file": "tools/c00/verify_phase_evidence.js",
      "exists": true,
      "passed": 3,
      "total": 3
    },
    {
      "file": "tools/c00/run_device_cycle.sh",
      "exists": true,
      "passed": 3,
      "total": 3
... (9 more lines)
```

### rokid preflight

Command: `bash tools/c00/preflight.sh rokid`

```text
C00 device smoke preflight
Project: /Users/dirui/Documents/Codex/2026-06-08/godot-ar-ar-core-ios-ar/work/GodotAR

Gate: rokid

OK   node             /usr/local/bin/node
OK   GODOT_BIN        /Users/dirui/Documents/Codex/2026-06-08/godot-ar-ar-core-ios-ar/work/GodotAR/.godot/cache/c00/godot-editor-4.7.rc1/Godot.app/Contents/MacOS/Godot
OK   Godot version    4.7.rc1
OK   ADB_BIN          /Users/dirui/Documents/Codex/2026-06-08/godot-ar-ar-core-ios-ar/work/GodotAR/.godot/cache/c00/android-sdk/platform-tools/adb

Plugin landing zones
OK   /Users/dirui/Documents/Codex/2026-06-08/godot-ar-ar-core-ios-ar/work/GodotAR/android/plugins
OK   /Users/dirui/Documents/Codex/2026-06-08/godot-ar-ar-core-ios-ar/work/GodotAR/addons/godotopenxrvendors
OK   /Users/dirui/Documents/Codex/2026-06-08/godot-ar-ar-core-ios-ar/work/GodotAR/addons/godotopenxrvendors/.bin/android/debug/godotopenxr-khronos-debug.aar
OK   /Users/dirui/Documents/Codex/2026-06-08/godot-ar-ar-core-ios-ar/work/GodotAR/addons/godotopenxrvendors/.bin/android/release/godotopenxr-khronos-release.aar
OK   /Users/dirui/Documents/Codex/2026-06-08/godot-ar-ar-core-ios-ar/work/GodotAR/addons/godot_openxr_vendors_export/plugin.cfg

Export presets
{
  "file": "/Users/dirui/Documents/Codex/2026-06-08/godot-ar-ar-core-ios-ar/work/GodotAR/export_presets.cfg",
  "gate": "rokid",
  "pass": true,
  "failures": [],
  "warnings": [],
  "presets": [
    {
      "gate": "rokid",
      "section": "preset.0",
... (48 more lines)
```

### ipad preflight

Command: `bash tools/c00/preflight.sh ipad`

```text
C00 device smoke preflight
Project: /Users/dirui/Documents/Codex/2026-06-08/godot-ar-ar-core-ios-ar/work/GodotAR

Gate: ipad

OK   node             /usr/local/bin/node
OK   GODOT_BIN        /Users/dirui/Documents/Codex/2026-06-08/godot-ar-ar-core-ios-ar/work/GodotAR/.godot/cache/c00/godot-editor/Godot.app/Contents/MacOS/Godot
OK   Godot version    4.6.3.stable
OK   xcrun            /usr/bin/xcrun
OK   xcodebuild       /usr/bin/xcodebuild

Plugin landing zones
OK   /Users/dirui/Documents/Codex/2026-06-08/godot-ar-ar-core-ios-ar/work/GodotAR/ios/plugins

Native plugin artifacts
OK   Godot source headers /Users/dirui/Documents/Codex/2026-06-08/godot-ar-ar-core-ios-ar/work/GodotAR/.godot/cache/c00/godot-source (4.6.3.stable)
{
  "pass": true,
  "file": "/Users/dirui/Documents/Codex/2026-06-08/godot-ar-ar-core-ios-ar/work/GodotAR/ios/plugins/godot_arkit/GodotARKit.gdip",
  "pluginDir": "/Users/dirui/Documents/Codex/2026-06-08/godot-ar-ar-core-ios-ar/work/GodotAR/ios/plugins/godot_arkit",
  "requireBinary": false,
  "failures": [],
  "warnings": [],
  "config": {
    "name": "GodotARKit",
    "binary": "GodotARKit.xcframework",
    "initialization": "init_godot_arkit",
    "deinitialization": "deinit_godot_arkit"
... (80 more lines)
```

### android-arcore preflight

Command: `bash tools/c00/preflight.sh android-arcore`

```text
C00 device smoke preflight
Project: /Users/dirui/Documents/Codex/2026-06-08/godot-ar-ar-core-ios-ar/work/GodotAR

Gate: android-arcore

OK   node             /usr/local/bin/node
OK   GODOT_BIN        /Users/dirui/Documents/Codex/2026-06-08/godot-ar-ar-core-ios-ar/work/GodotAR/.godot/cache/c00/godot-editor-4.7.rc1/Godot.app/Contents/MacOS/Godot
OK   Godot version    4.7.rc1
OK   ADB_BIN          /Users/dirui/Documents/Codex/2026-06-08/godot-ar-ar-core-ios-ar/work/GodotAR/.godot/cache/c00/android-sdk/platform-tools/adb

Plugin landing zones
OK   /Users/dirui/Documents/Codex/2026-06-08/godot-ar-ar-core-ios-ar/work/GodotAR/android/plugins

Export presets
{
  "file": "/Users/dirui/Documents/Codex/2026-06-08/godot-ar-ar-core-ios-ar/work/GodotAR/export_presets.cfg",
  "gate": "android-arcore",
  "pass": true,
  "failures": [],
  "warnings": [],
  "presets": [
    {
      "gate": "android-arcore",
      "section": "preset.1",
      "name": "C00 Android ARCore",
      "platform": "Android",
      "export_path": "builds/android_arcore/c00.apk",
      "exclude_filter": "android/build/*,builds/*,exports/*,releases/*,tools/*",
... (38 more lines)
```

### rokid-place preflight

Command: `bash tools/c00/preflight.sh rokid-place`

```text
C00 device smoke preflight
Project: /Users/dirui/Documents/Codex/2026-06-08/godot-ar-ar-core-ios-ar/work/GodotAR

Gate: rokid-place

OK   node             /usr/local/bin/node
OK   GODOT_BIN        /Users/dirui/Documents/Codex/2026-06-08/godot-ar-ar-core-ios-ar/work/GodotAR/.godot/cache/c00/godot-editor-4.7.rc1/Godot.app/Contents/MacOS/Godot
OK   Godot version    4.7.rc1
OK   ADB_BIN          /Users/dirui/Documents/Codex/2026-06-08/godot-ar-ar-core-ios-ar/work/GodotAR/.godot/cache/c00/android-sdk/platform-tools/adb

Plugin landing zones
OK   /Users/dirui/Documents/Codex/2026-06-08/godot-ar-ar-core-ios-ar/work/GodotAR/android/plugins
OK   /Users/dirui/Documents/Codex/2026-06-08/godot-ar-ar-core-ios-ar/work/GodotAR/addons/godotopenxrvendors
OK   /Users/dirui/Documents/Codex/2026-06-08/godot-ar-ar-core-ios-ar/work/GodotAR/addons/godotopenxrvendors/.bin/android/debug/godotopenxr-khronos-debug.aar
OK   /Users/dirui/Documents/Codex/2026-06-08/godot-ar-ar-core-ios-ar/work/GodotAR/addons/godotopenxrvendors/.bin/android/release/godotopenxr-khronos-release.aar
OK   /Users/dirui/Documents/Codex/2026-06-08/godot-ar-ar-core-ios-ar/work/GodotAR/addons/godot_openxr_vendors_export/plugin.cfg

Export presets
{
  "file": "/Users/dirui/Documents/Codex/2026-06-08/godot-ar-ar-core-ios-ar/work/GodotAR/export_presets.cfg",
  "gate": "rokid-place",
  "pass": true,
  "failures": [],
  "warnings": [],
  "presets": [
    {
      "gate": "rokid-place",
      "section": "preset.3",
... (48 more lines)
```

### ipad-place preflight

Command: `bash tools/c00/preflight.sh ipad-place`

```text
C00 device smoke preflight
Project: /Users/dirui/Documents/Codex/2026-06-08/godot-ar-ar-core-ios-ar/work/GodotAR

Gate: ipad-place

OK   node             /usr/local/bin/node
OK   GODOT_BIN        /Users/dirui/Documents/Codex/2026-06-08/godot-ar-ar-core-ios-ar/work/GodotAR/.godot/cache/c00/godot-editor/Godot.app/Contents/MacOS/Godot
OK   Godot version    4.6.3.stable
OK   xcrun            /usr/bin/xcrun
OK   xcodebuild       /usr/bin/xcodebuild

Plugin landing zones
OK   /Users/dirui/Documents/Codex/2026-06-08/godot-ar-ar-core-ios-ar/work/GodotAR/ios/plugins

Native plugin artifacts
OK   Godot source headers /Users/dirui/Documents/Codex/2026-06-08/godot-ar-ar-core-ios-ar/work/GodotAR/.godot/cache/c00/godot-source (4.6.3.stable)
{
  "pass": true,
  "file": "/Users/dirui/Documents/Codex/2026-06-08/godot-ar-ar-core-ios-ar/work/GodotAR/ios/plugins/godot_arkit/GodotARKit.gdip",
  "pluginDir": "/Users/dirui/Documents/Codex/2026-06-08/godot-ar-ar-core-ios-ar/work/GodotAR/ios/plugins/godot_arkit",
  "requireBinary": false,
  "failures": [],
  "warnings": [],
  "config": {
    "name": "GodotARKit",
    "binary": "GodotARKit.xcframework",
    "initialization": "init_godot_arkit",
    "deinitialization": "deinit_godot_arkit"
... (80 more lines)
```

### Rokid/iPad/Android phase evidence plus placement demos

Command: `node tools/c00/verify_phase_evidence.js --dir /Users/dirui/Documents/Codex/2026-06-08/godot-ar-ar-core-ios-ar/work/GodotAR/releases/phase_0_smoke/evidence --report /var/folders/59/j9_t4rns6dj87lz0wwm8068h0000gn/T/godotar-c00-phase-evidence-1781183976217.md --gate rokid --gate ipad --gate android-arcore --gate rokid-place --gate ipad-place`

```text
{
  "pass": false,
  "gates": [
    "rokid",
    "ipad",
    "android-arcore",
    "rokid-place",
    "ipad-place"
  ],
  "evidenceDir": "/Users/dirui/Documents/Codex/2026-06-08/godot-ar-ar-core-ios-ar/work/GodotAR/releases/phase_0_smoke/evidence",
  "report": "/var/folders/59/j9_t4rns6dj87lz0wwm8068h0000gn/T/godotar-c00-phase-evidence-1781183976217.md",
  "failures": [
    "rokid: No GXF_SMOKE, GXF_ROKID_PLACE, or GXF_ARKIT_PLACE events found.",
    "rokid: rokid gate requires a screenshot artifact.",
    "rokid: rokid gate requires a screen recording artifact.",
    "rokid: Device profile analysis: no connected Android device was available in adb state 'device'.",
    "rokid: Device profile analysis: target package was not installed: org.godotengine.godotxrfoundation.",
    "ipad: No GXF_SMOKE, GXF_ROKID_PLACE, or GXF_ARKIT_PLACE events found.",
    "ipad: iPad gate requires at least one screenshot, screen recording, or manual media artifact.",
    "ipad: Device profile analysis: iPad appears unavailable; connect, unlock, and trust the device before running the ARKit gate.",
    "ipad: Device profile analysis: target bundle was not installed: org.godotengine.godotxrfoundation.",
    "android-arcore: Missing smoke log. Expected android-arcore-*.log or --android-arcore-log.",
    "android-arcore: android-arcore gate requires a screenshot artifact.",
    "android-arcore: android-arcore gate requires a screen recording artifact.",
    "android-arcore: android-arcore gate requires a device profile Markdown artifact.",
    "android-arcore: android-arcore gate requires a device profile JSON artifact.",
    "rokid-place: Missing smoke log. Expected rokid-place-*.log or --rokid-place-log.",
    "rokid-place: rokid-place gate requires a screenshot artifact.",
... (322 more lines)
```
