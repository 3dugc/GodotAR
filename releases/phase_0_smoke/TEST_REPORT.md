# Godot XR Foundation C00 Test Report

Cycle: C00 Device Smoke Test

Version: v0.0.1-c00-device-smoke

Scene: `res://demo/00_device_smoke_test.tscn`

## Summary

| Gate | Required backend | Result | Evidence |
| --- | --- | --- | --- |
| Editor smoke | EditorSim | Pending local Godot run | Screenshot/log |
| iOS Simulator development gate | EditorSim | Pending simulator app run | Simulator log/screenshot |
| Rokid AR gate | OpenXR | Pending device run | Screenshot/log |
| iPad AR gate | ARKit | Pending device run | Screenshot/log |
| Android ARCore availability | ARCore | Pending device run | Screenshot/log |
| Plugin boundary | No engine patch | Pass by implementation | Addon/provider only |

Codex implementation status:

- C00 smoke scene created.
- Runtime status panel created.
- Runtime status panel now shows ARKit tracking state/reason when the native ARKit provider reports them.
- Runtime status panel now shows OpenXR AR tier/fallback when the OpenXR provider reports them.
- `GXF_SMOKE` structured logs created.
- `GXF_SMOKE` now includes runtime metadata: Godot version info, XR-related command-line args, rendering method, OpenXR/XR shader settings, and viewport XR state.
- `GXF_SMOKE` and the C00 status panel now include Unity-style `ar_session_state` and `not_tracking_reason` fields.
- Provider capability reports created.
- Unity-style `ARSession` wrapper created.
- Unity-compatible `ARSession.state()` now returns `ARSessionState` semantics, while `ARSession.foundation_state()` keeps access to the internal lifecycle state.
- Unity-style `ARSession.notTrackingReason`, `requestedTrackingMode`, and `matchFrameRateRequested` compatibility surface added.
- Unity-style migration helpers added for placement workflows: `ARRaycastManager.TryRaycast`, `ARRaycastManager.RaycastToList`, `ARRaycastManager.TryScreenRaycast`, `XRHit.get_pose()`, `ARAnchorManager.TryAddAnchorAsync`, and `ARAnchorManager.TryRemoveAnchor`.
- `ARPlaneManager.planes_changed` and `ARAnchorManager.anchors_changed` list-style events added for Unity manager migration.
- `NativeXRProvider` now preserves native anchor dictionary ids and persistent ids from ARKit/ARCore singleton bridges instead of replacing them with generated ids.
- `tools/c00/check_arfoundation_api_surface.js` now guards the migration API surface without requiring a Godot binary.
- EditorSim/simulator gate added for local ARFoundation-style API validation through `--xr-platform=simulator`; it does not replace Rokid/iPad device gates.
- iOS Simulator and Android Emulator are documented as auxiliary cycle outputs for export/startup/log validation only; they cannot satisfy the C00 ARKit/OpenXR publish gate.
- `tools/c00/collect_ios_simulator_smoke.sh` and `tools/c00/run_device_cycle.sh ios-simulator` now provide a runnable iOS Simulator development gate that expects `backend:"EditorSim"` and validates the iOS export/startup/log path before iPad hardware.
- Godot plugin-first boundary documented. No Godot engine patch is used in C00.
- `tools/c00/bootstrap_device_machine.sh` now generates a C00 readiness report for device machines and can optionally create the export preset starter.
- C00 preflight, export helper, Android/Rokid log collector, iPad log collector, and gate validator created under `tools/c00`.
- `tools/c00/import_device_evidence.sh` now imports manually captured device logs/media into the standard C00 evidence directory and runs the same smoke/media validators.
- `NativeXRProvider` now detects native provider singletons through `Engine.has_singleton(...)` and merges their availability/capability reports.
- `ios/plugins/godot_arkit` now contains a first-party ARKit iOS plugin skeleton that registers `GodotARKit` as a Godot `Engine` singleton.
- `GodotARKit` now exports `.gdip` init/deinit functions as C symbols and registers its Object class with `ClassDB` before exposing the singleton.
- `GodotARKit` now listens to ARKit `ARSessionDelegate` tracking updates and reports `arkit_tracking_status`, `arkit_tracking_state`, and `arkit_tracking_reason` through `get_capabilities()`.
- `ios/plugins/godot_arkit/build_xcframework.sh` now builds the ARKit iOS plugin artifacts when `GODOT_SOURCE_DIR` points to matching Godot source headers.
- `tools/c00/check_arkit_plugin_static.sh` now performs an iOS SDK Objective-C++ syntax smoke check for the ARKit plugin before the full Godot-header xcframework build.
- `tools/c00/check_ios_plugin_artifacts.js` now validates the `GodotARKit.gdip`/template against Godot iOS plugin requirements, including config fields, xcframework reference, init/deinit symbols, capabilities, frameworks, and plist entries.
- `tools/c00/run_device_cycle.sh` now orchestrates preflight, optional ARKit plugin build, Godot export, device log collection, and gate validation for iPad/ARKit and Rokid/OpenXR.
- `tools/c00/build_ios_xcode_project.sh` now builds the Godot iOS export zip into `builds/ipad/GodotXRFoundation.app`, and the iPad runner can use it automatically when `APP_PATH` is not set.
- `tools/c00/run_device_cycle.sh all` now continues across iPad/Rokid gate failures and runs the aggregate C00 phase verifier at the end.
- `tools/c00/check_export_presets.js` now validates that `export_presets.cfg` contains the required C00 preset names before export, requires Rokid exports to include `--xr-platform=rokid`, and requires the iPad preset to enable `GodotARKit`.
- `tools/c00/write_export_presets_template.js` now generates a local C00 export preset starter for device machines before Godot editor review.
- `tools/c00/validate_smoke_log.js` now requires explicit ARKit evidence for the iPad gate, not only `native_plugin=true`.
- `tools/c00/validate_smoke_log.js` and `tools/c00/verify_phase_evidence.js` now require Unity-style `ar_session_state` / `not_tracking_reason` and iPad ARKit `arkit_tracking_state` / `arkit_tracking_reason`.
- Device collectors now attempt to save media evidence: Android/Rokid records `.mp4` plus `.png`; iOS captures `.png` when `idevicescreenshot` is available and otherwise asks for manual screenshot/recording.
- Android/Rokid collection now writes a device profile report and JSON with model, OS, display, target package, XR-related packages, and notable camera/Vulkan/XR features.
- `tools/c00/analyze_android_device_profile.js` now analyzes Rokid/OpenXR and Android ARCore profile JSON for ADB availability, target package install state, XR/OpenXR runtime packages, camera/Vulkan/XR features, and Rokid hardware match risk.
- `tools/c00/collect_android_smoke.sh` now appends the Android device profile analysis report to the same C00 gate report.
- iPad collection now writes a devicectl-backed device profile report and JSON with device details, display, lock state, target bundle status, and raw JSON command evidence.
- C00 aggregate verification now requires device profile Markdown and JSON evidence for both Rokid/OpenXR and iPad/ARKit; manual evidence import can carry those files into the standard evidence layout.
- `tools/c00/validate_evidence_bundle.js` now enforces publishable evidence: Rokid/Android require screenshot plus recording; iPad requires at least one screenshot or recording.
- `tools/c00/verify_phase_evidence.js` now enforces the full C00 publish gate by requiring both Rokid/OpenXR and iPad/ARKit evidence in one aggregate report.
- Native singleton providers can now report tracking status without an `XRInterface`; `GodotARKit` exposes `is_running()` and `get_tracking_status()` for the C00 panel and logs.
- `GodotARKit.get_tracking_status()` now maps real ARKit state to Godot tracking status: normal tracking, limited/unknown tracking, or not tracking.
- `OpenXRProvider` now reports Unity OpenXR Feature-style runtime diagnostics: selected blend mode, vendor singletons, feature flags, AR tier, and fallback path.
- `OpenXRProvider` now records method-level OpenXR Vendors/Rokid passthrough evidence in `openxr_vendor_feature_report` and `openxr_ar_evidence`.
- `tools/c00/validate_smoke_log.js` and `tools/c00/verify_phase_evidence.js` now require Rokid/OpenXR logs to include non-empty `capabilities.openxr_ar_evidence`.

Hardware status:

- Not executed in this Codex environment because Godot executable, Rokid hardware, and iPad hardware are not available here.
- Local preflight currently reports missing `godot`, `adb`, `export_presets.cfg`, `GodotARKit.gdip`, and `GodotARKit.xcframework`; `node`, `xcrun`, `xcodebuild`, and the ARKit Objective-C++ syntax smoke check are available.
- Do not mark this report as passed until the device evidence below is filled.

## Local Verification On 2026-06-08

| Check | Result | Notes |
| --- | --- | --- |
| `git diff --check` | Pass | No whitespace errors |
| `node --check tools/c00/validate_smoke_log.js` | Pass | Validator parses |
| `node --check tools/c00/collect_android_device_profile.js` | Pass | Android/Rokid profile collector parses |
| `node --check tools/c00/analyze_android_device_profile.js` | Pass | Android/Rokid profile analyzer parses |
| `node --check tools/c00/collect_ios_device_profile.js` | Pass | iPad profile collector parses |
| `node --check tools/c00/validate_evidence_bundle.js` | Pass | Evidence validator parses |
| `node --check tools/c00/verify_phase_evidence.js` | Pass | C00 aggregate verifier parses |
| `node --check tools/c00/check_ios_plugin_artifacts.js` | Pass | iOS plugin artifact checker parses |
| `node --check tools/c00/check_arfoundation_api_surface.js` | Pass | ARFoundation migration API checker parses |
| `node tools/c00/check_arfoundation_api_surface.js` | Pass | Unity-style ARSession/raycast/trackables surface is present |
| `node --check tools/c00/check_openxr_provider_surface.js` | Pass | OpenXR provider surface checker parses |
| `node tools/c00/check_openxr_provider_surface.js` | Pass | OpenXR/Rokid AR evidence surface is present |
| `node --check tools/c00/write_export_presets_template.js` | Pass | Preset starter writer parses |
| `bash -n tools/c00/*.sh ios/plugins/godot_arkit/build_xcframework.sh` | Pass | Shell scripts parse |
| `tools/c00/build_ios_xcode_project.sh --help` | Pass | Documents exported Xcode project build path into `builds/ipad/GodotXRFoundation.app` |
| `tools/c00/bootstrap_device_machine.sh` | Blocked by host prerequisites | Generates readiness report, confirms `xcodebuild`, and records missing `godot`, `adb`, export presets, and ARKit build artifacts on this host |
| Synthetic Android device profile smoke | Pass | `collect_android_device_profile.js` writes Markdown/JSON with a fake adb command to verify report generation |
| Synthetic Rokid device profile analysis | Pass | Analyzer accepts a Rokid/OpenXR profile with target app, runtime packages, camera, Vulkan, and XR feature evidence |
| Synthetic bad Rokid profile analysis | Fail as expected | Analyzer rejects missing ADB and missing target package while warning about missing OpenXR/camera/Vulkan/XR evidence |
| Synthetic bad ARCore profile analysis | Fail as expected | Analyzer rejects Android ARCore profile JSON with no ARCore package |
| Synthetic Rokid phase profile analysis | Pass | `verify_phase_evidence.js --gate rokid` accepts good Rokid profile analysis when media size is relaxed for synthetic files |
| Synthetic bad Rokid phase profile analysis | Fail as expected | `verify_phase_evidence.js --gate rokid` rejects profile JSON where ADB and target package evidence are missing |
| Synthetic iPad device profile smoke | Pass | `collect_ios_device_profile.js` writes Markdown/JSON with a fake devicectl command to verify report generation |
| Synthetic manual evidence import | Pass | `tools/c00/import_device_evidence.sh` imports synthetic Rokid/iPad logs and media into a temp evidence directory and runs validators |
| Synthetic C00 device profile aggregate gate | Pass | `verify_phase_evidence.js` rejects missing profile evidence and accepts Rokid/iPad logs, media, and profile Markdown/JSON |
| Synthetic iPad ARKit gate | Pass | `backend:"ARKit"`, `native_plugin:true` |
| Synthetic iPad ARKit tracking gate | Pass | Validator rejects missing `arkit_tracking_state` / `arkit_tracking_reason` and accepts complete ARKit tracking evidence |
| Synthetic Rokid AR gate | Pass | `backend:"OpenXR"`, `ar_product_path:true` |
| Synthetic Rokid OpenXR tier gate | Pass | Validator rejects `openxr_ar_tier:"D"` and warns when tier data is missing |
| Synthetic Rokid OpenXR AR evidence gate | Pass | Validator rejects missing `openxr_ar_evidence` and accepts explicit blend/vendor evidence |
| Synthetic runtime metadata report | Pass | Report includes Godot version and `--xr-platform=rokid` metadata |
| Synthetic Unity-style ARSession log fields | Pass | `validate_smoke_log.js` rejects missing `ar_session_state` / `not_tracking_reason` and accepts complete evidence |
| Synthetic Unity-style ARSession aggregate fields | Pass | `verify_phase_evidence.js --gate rokid` rejects missing Unity-style fields and accepts complete evidence when media/profile are downgraded to warnings |
| Synthetic evidence bundle gates | Pass | Rokid requires screenshot + video; iPad accepts manual media |
| Synthetic C00 phase evidence gate | Pass | Aggregate report passes with Rokid + iPad evidence and fails on empty evidence |
| Synthetic EditorSim gate | Pass | `backend:"EditorSim"` validates without media evidence |
| Synthetic iOS Simulator gate | Pass | `validate_smoke_log.js --gate ios-simulator` accepts `backend:"EditorSim"` as development evidence |
| Synthetic iOS Simulator vs iPad boundary | Fail as expected | The same `EditorSim` log fails `--gate ipad` with `Expected backend ARKit` |
| Synthetic Rokid OpenXR-only strict gate | Fail as expected | `ar_product_path:false` is not accepted as AR product pass |
| `ios/plugins/godot_arkit/build_xcframework.sh --help` | Pass | Documents required Godot source header path and outputs |
| `tools/c00/collect_ios_simulator_smoke.sh --help` | Pass | Documents the iOS Simulator development gate |
| `tools/c00/run_device_cycle.sh --help` | Pass | Documents EditorSim, iOS Simulator, iPad, Rokid, and Android ARCore gate execution |
| `tools/c00/run_device_cycle.sh all` control flow | Pass | With export/collect disabled, records failing preflights and exits nonzero instead of silently passing |
| `APP_PATH=/private/tmp/missing.app tools/c00/preflight.sh ios-simulator` | Fail as expected | Collection-only simulator gate skips Godot/export preset checks but requires an existing `.app` |
| `node --check tools/c00/check_export_presets.js` | Pass | Preset checker parses |
| ARKit plugin symbol/static check | Pass | `.gdip` init symbols are `extern "C"` and `GodotARKitPlugin` registers with `ClassDB` |
| ARKit tracking state/static check | Pass | `GodotARKitSession` implements `ARSessionDelegate` and exposes ARKit tracking state/reason |
| GodotARKit `.gdip` template check | Pass with warning | Plugin config matches Godot iOS plugin format; warns that real `GodotARKit.xcframework` is not built on this host |
| ARKit plugin Objective-C++ syntax smoke | Pass | `tools/c00/check_arkit_plugin_static.sh` validates plugin sources against the local iOS SDK with Godot stubs |
| `tools/c00/preflight.sh all` | Blocked by host prerequisites | Missing `godot`, `adb`, `export_presets.cfg`, `GodotARKit.gdip`, and `GodotARKit.xcframework`; ARKit Objective-C++ syntax smoke passes |

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
ARKit tracking:
ARKit reason:
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
- Rokid reports must include Unity-style `ar_session_state` and `not_tracking_reason`.
- Rokid reports should preserve `capabilities.openxr_ar_tier` and `capabilities.openxr_fallback`; tier `D` is VR-only and cannot pass as AR.
- Rokid reports must include non-empty `capabilities.openxr_ar_evidence`.
- iPad passes only when `backend:"ARKit"` and `session_state:"Running"` are present in `GXF_SMOKE`.
- iPad reports must include Unity-style `ar_session_state` and `not_tracking_reason`.
- iPad reports should preserve `capabilities.arkit_tracking_state` and `capabilities.arkit_tracking_reason`; `normal` is stable tracking, while `limited` or `not_available` must include the reason in notes.
- C00 device reports should include runtime metadata so startup arguments, Godot version, rendering method, and XR project settings are visible in the gate report.
- `EditorSim` is useful evidence that the app starts, but never satisfies a device AR gate.
- EditorSim/simulator gate validates migrated service code and smoke logging only; C00 publish still requires Rokid/OpenXR and iPad/ARKit evidence.
- OpenXR with only `opaque` blend mode is an OpenXR rendering pass, not an AR product pass.
- Rokid/Android publishable results require both screenshot and screen recording artifacts; iPad publishable results require at least one screenshot or recording artifact.
- C00 publishable results require `tools/c00/verify_phase_evidence.js` to pass for both Rokid/OpenXR and iPad/ARKit.
- Any engine patch must include a minimal-intrusion patch spec before the device gate can be marked complete.
