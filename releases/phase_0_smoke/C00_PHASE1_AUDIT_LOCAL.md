# C00 Phase 1 Completion Audit

Generated: 2026-06-08T15:44:45.454Z

Result: PARTIAL

Project: `/Users/dirui/Documents/Codex/2026-06-08/godot-ar-ar-core-ios-ar/work/GodotAR`

Evidence: `/Users/dirui/Documents/Codex/2026-06-08/godot-ar-ar-core-ios-ar/work/GodotAR/releases/phase_0_smoke/evidence`

## Verdict

Selected checks passed, but phase 1 is not complete because one or more completion gates were skipped.

## Required Checks

| Status | Group | Check | Next action |
| --- | --- | --- | --- |
| PASS | static | C00 static gates | All code/static/API/export-surface gates pass. |
| PASS | unity-migration | ARFoundation migration API surface | Unity-style ARSession, raycast, trackables, and changed-event facades are present. |
| PASS | unity-migration | XRI interaction API surface | Unity XRI-style manager/ray/interactable smoke surface is present. |
| PASS | ios | GodotARKit plugin binary artifacts | GodotARKit.gdip and GodotARKit.xcframework are built and usable by Godot iOS export. |
| PASS | rokid-openxr | Rokid/OpenXR provider evidence surface | OpenXR AR evidence, passthrough report, and virtual-plane fallback diagnostics are guarded. |
| PASS | android-arcore | Android ARCore plugin and gate surface | ARCore gate requires explicit native ARCore runtime/capability evidence. |

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
      "name": "node --check tools/c00/check_android_arcore_plugin_surface.js",
      "status": "PASS",
... (407 more lines)
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
      "passed": 9,
      "total": 9
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
... (57 more lines)
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
      "file": "addons/godot_xr_foundation/scripts/xri/xr_interaction_manager.gd",
      "exists": true,
      "passed": 14,
      "total": 14
    },
    {
      "file": "addons/godot_xr_foundation/scripts/xri/xr_ray_interactor.gd",
      "exists": true,
      "passed": 13,
      "total": 13
    },
    {
      "file": "addons/godot_xr_foundation/scripts/xri/xr_grab_interactable.gd",
      "exists": true,
      "passed": 12,
      "total": 12
    },
    {
      "file": "demo/00_device_smoke_test.tscn",
      "exists": true,
      "passed": 3,
      "total": 3
... (9 more lines)
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
    }
  ]
}
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

