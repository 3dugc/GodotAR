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
- `GodotARKit` now exports `.gdip` init/deinit functions as C symbols and registers its Object class with `ClassDB` before exposing the singleton.
- `ios/plugins/godot_arkit/build_xcframework.sh` now builds the ARKit iOS plugin artifacts when `GODOT_SOURCE_DIR` points to matching Godot source headers.
- `tools/c00/run_device_cycle.sh` now orchestrates preflight, optional ARKit plugin build, Godot export, device log collection, and gate validation for iPad/ARKit and Rokid/OpenXR.
- `tools/c00/check_export_presets.js` now validates that `export_presets.cfg` contains the required C00 preset names before export, requires Rokid exports to include `--xr-platform=rokid`, and requires the iPad preset to enable `GodotARKit`.
- `tools/c00/write_export_presets_template.js` now generates a local C00 export preset starter for device machines before Godot editor review.
- `tools/c00/validate_smoke_log.js` now requires explicit ARKit evidence for the iPad gate, not only `native_plugin=true`.
- Device collectors now attempt to save media evidence: Android/Rokid records `.mp4` plus `.png`; iOS captures `.png` when `idevicescreenshot` is available and otherwise asks for manual screenshot/recording.
- `tools/c00/validate_evidence_bundle.js` now enforces publishable evidence: Rokid/Android require screenshot plus recording; iPad requires at least one screenshot or recording.
- Native singleton providers can now report tracking status without an `XRInterface`; `GodotARKit` exposes `is_running()` and `get_tracking_status()` for the C00 panel and logs.

Hardware status:

- Not executed in this Codex environment because Godot executable, Rokid hardware, and iPad hardware are not available here.
- Local preflight currently reports missing `godot`, `adb`, `GodotARKit.gdip`, and `GodotARKit.xcframework`, with `node` and `xcrun` available.
- Do not mark this report as passed until the device evidence below is filled.

## Local Verification On 2026-06-08

| Check | Result | Notes |
| --- | --- | --- |
| `git diff --check` | Pass | No whitespace errors |
| `node --check tools/c00/validate_smoke_log.js` | Pass | Validator parses |
| `node --check tools/c00/validate_evidence_bundle.js` | Pass | Evidence validator parses |
| `node --check tools/c00/write_export_presets_template.js` | Pass | Preset starter writer parses |
| `bash -n tools/c00/*.sh ios/plugins/godot_arkit/build_xcframework.sh` | Pass | Shell scripts parse |
| Synthetic iPad ARKit gate | Pass | `backend:"ARKit"`, `native_plugin:true` |
| Synthetic Rokid AR gate | Pass | `backend:"OpenXR"`, `ar_product_path:true` |
| Synthetic evidence bundle gates | Pass | Rokid requires screenshot + video; iPad accepts manual media |
| Synthetic Rokid OpenXR-only strict gate | Fail as expected | `ar_product_path:false` is not accepted as AR product pass |
| `ios/plugins/godot_arkit/build_xcframework.sh --help` | Pass | Documents required Godot source header path and outputs |
| `tools/c00/run_device_cycle.sh --help` | Pass | Documents iPad/Rokid full gate execution |
| `node --check tools/c00/check_export_presets.js` | Pass | Preset checker parses |
| ARKit plugin symbol/static check | Pass | `.gdip` init symbols are `extern "C"` and `GodotARKitPlugin` registers with `ClassDB` |
| `tools/c00/preflight.sh` | Blocked by host prerequisites | Missing `godot`, `adb`, `export_presets.cfg`, `GodotARKit.gdip`, and `GodotARKit.xcframework`; `node` and `xcrun` available |

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
- Rokid/Android publishable results require both screenshot and screen recording artifacts; iPad publishable results require at least one screenshot or recording artifact.
- Any engine patch must include a minimal-intrusion patch spec before the device gate can be marked complete.
