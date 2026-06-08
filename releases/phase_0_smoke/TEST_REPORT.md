# Godot XR Foundation C00 Test Report

Cycle: C00 Device Smoke Test

Version: v0.0.1-c00-device-smoke

Scene: `res://demo/00_device_smoke_test.tscn`

## Summary

| Gate | Required backend | Result | Evidence |
| --- | --- | --- | --- |
| Editor smoke | EditorSim | Pending local Godot run | Screenshot/log |
| Rokid AR gate | OpenXR | Pending device run | Screenshot/log |
| iPad AR gate | ARKit | Pending device run | Screenshot/log |
| Android ARCore availability | ARCore | Pending device run | Screenshot/log |
| Plugin boundary | No engine patch | Pass by implementation | Addon/provider only |

Codex implementation status:

- C00 smoke scene created.
- Runtime status panel created.
- `GXF_SMOKE` structured logs created.
- Provider capability reports created.
- Unity-style `ARSession` wrapper created.
- Godot plugin-first boundary documented. No Godot engine patch is used in C00.
- C00 preflight, export helper, Android/Rokid log collector, iPad log collector, and gate validator created under `tools/c00`.
- `NativeXRProvider` now detects native provider singletons through `Engine.has_singleton(...)` and merges their availability/capability reports.
- `ios/plugins/godot_arkit` now contains a first-party ARKit iOS plugin skeleton that registers `GodotARKit` as a Godot `Engine` singleton.

Hardware status:

- Not executed in this Codex environment because Godot executable, Rokid hardware, and iPad hardware are not available here.
- Local preflight currently reports missing `godot` and `adb`, with `node` and `xcrun` available.
- Do not mark this report as passed until the device evidence below is filled.

## Local Verification On 2026-06-08

| Check | Result | Notes |
| --- | --- | --- |
| `git diff --check` | Pass | No whitespace errors |
| `node --check tools/c00/validate_smoke_log.js` | Pass | Validator parses |
| `bash -n tools/c00/*.sh ios/plugins/godot_arkit/build_xcframework.sh` | Pass | Shell scripts parse |
| Synthetic iPad ARKit gate | Pass | `backend:"ARKit"`, `native_plugin:true` |
| Synthetic Rokid AR gate | Pass | `backend:"OpenXR"`, `ar_product_path:true` |
| Synthetic Rokid OpenXR-only strict gate | Fail as expected | `ar_product_path:false` is not accepted as AR product pass |
| `tools/c00/preflight.sh` | Blocked by host prerequisites | Missing `godot` and `adb`; `node` and `xcrun` available |

## Device Evidence

### Rokid / OpenXR

Device:

OS/runtime:

Godot version:

OpenXR Vendors plugin version:

Extension path:

Observed panel:

```text
Session:
Backend:
Provider:
Tracking:
AR path:
Blend:
```

Required log snippets:

```text
GXF_SMOKE|
```

Result:

- [ ] Pass
- [ ] Fail

Notes:

### iPad / ARKit

Device:

iPadOS:

Godot version:

ARKit plugin build:

Extension path:

Observed panel:

```text
Session:
Backend:
Provider:
Tracking:
Native plugin:
```

Required log snippets:

```text
GXF_SMOKE|
```

Result:

- [ ] Pass
- [ ] Fail

Notes:

### Android Phone / ARCore

Device:

Android version:

Godot version:

ARCore plugin build:

Extension path:

Observed panel:

```text
Session:
Backend:
Provider:
Tracking:
Native plugin:
```

Required log snippets:

```text
GXF_SMOKE|
```

Result:

- [ ] Pass
- [ ] Fail

Notes:

## C00 Pass Rules

- Rokid passes only when `backend:"OpenXR"` and `session_state:"Running"` are present in `GXF_SMOKE`.
- iPad passes only when `backend:"ARKit"` and `session_state:"Running"` are present in `GXF_SMOKE`.
- `EditorSim` is useful evidence that the app starts, but never satisfies a device AR gate.
- OpenXR with only `opaque` blend mode is an OpenXR rendering pass, not an AR product pass.
- Any engine patch must include a minimal-intrusion patch spec before the device gate can be marked complete.
