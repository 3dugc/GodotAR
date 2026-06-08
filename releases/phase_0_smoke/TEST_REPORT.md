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
- `NativeXRProvider` now maps native singleton tracking reasons such as ARKit `arkit_tracking_reason` into the unified Unity-style `not_tracking_reason` facade.
- Provider capability reports created.
- Unity-style `ARSession` wrapper created.
- Unity-compatible `ARSession.state()` now returns `ARSessionState` semantics, while `ARSession.foundation_state()` keeps access to the internal lifecycle state.
- Unity-style `ARSession.notTrackingReason`, `requestedTrackingMode`, and `matchFrameRateRequested` compatibility surface added.
- Unity-style migration helpers added for placement workflows: `ARRaycastManager.TryRaycast`, `ARRaycastManager.RaycastToList`, `ARRaycastManager.TryScreenRaycast`, `XRHit.get_pose()`, `ARAnchorManager.TryAddAnchorAsync`, and `ARAnchorManager.TryRemoveAnchor`.
- `ARPlaneManager.planes_changed` and `ARAnchorManager.anchors_changed` list-style events added for Unity manager migration.
- `NativeXRProvider` now preserves native anchor dictionary ids and persistent ids from ARKit/ARCore singleton bridges instead of replacing them with generated ids.
- `tools/c00/check_arfoundation_api_surface.js` now guards the migration API surface without requiring a Godot binary.
- EditorSim/simulator gate added for local ARFoundation-style API validation through `--xr-platform=simulator`; it does not replace Rokid/iPad/Android ARCore device gates.
- iOS Simulator and Android Emulator are documented as auxiliary cycle outputs for export/startup/log validation only; they cannot satisfy the C00 ARKit/OpenXR publish gate.
- `tools/c00/collect_ios_simulator_smoke.sh` and `tools/c00/run_device_cycle.sh ios-simulator` now provide a runnable iOS Simulator development gate that expects `backend:"EditorSim"` and validates the iOS export/startup/log path before iPad hardware.
- Godot plugin-first boundary documented. No Godot engine patch is used in C00.
- `tools/c00/bootstrap_device_machine.sh` now generates a C00 readiness report for device machines and can optionally create the export preset starter.
- C00 preflight, export helper, Android/Rokid log collector, iPad log collector, and gate validator created under `tools/c00`.
- `tools/c00/check_godot_project_static.js` now validates C00 project settings, scene resource references, load steps, required smoke nodes, and critical NodePaths without requiring a Godot binary.
- `tools/c00/run_static_gates.js` now runs the C00 static gate set in one command and can write a Markdown report for CI/device-machine readiness.
- `tools/c00/check_rokid_openxr_export_surface.js` now guards Rokid/OpenXR export prerequisites: Gradle build, OpenXR XR mode, arm64, `--xr-platform=rokid`, and device-machine OpenXR Vendors plugin checks.
- `tools/c00/install_openxr_vendors.sh` now provides a device-machine installer for the official `godotopenxrvendorsaddon.zip`, including latest release download, tag/URL/local zip modes, and safe extraction of the inner `godotopenxrvendors` directory.
- `tools/c00/prepare_godot_source.sh` now prepares the matching official Godot source headers for ARKit plugin builds and prints the `GODOT_SOURCE_DIR=... ios/plugins/godot_arkit/build_xcframework.sh` command for device machines.
- `tools/c00/check_ios_godot_source_surface.js` now guards the iPad Godot source preparation surface, including official source URL, tag inference, required headers, and ARKit build guidance.
- `tools/c00/run_device_cycle.sh ipad` now reuses `.godot/cache/c00/godot-source` automatically and can prepare it before ARKit plugin builds when `GODOT_TAG`, `GODOT_BRANCH`, or `GODOT_COMMIT` is supplied.
- `tools/c00/run_device_cycle.sh` now supports `DRY_RUN=1` to print source/build/export/collect/verify orchestration without invoking Godot, Xcode, ADB, or devicectl.
- `android/plugins/godot_arcore` and `addons/godot_arcore` now provide a first-party C00 GodotARCore Android plugin v2 landing point with ARCore availability, install request, session lifecycle, Gradle build script, and Godot export hook.
- `tools/c00/check_android_arcore_plugin_surface.js` now guards the GodotARCore Android plugin surface without requiring Gradle, Godot, or a connected Android device.
- `tools/c00/check_arcore_gate_surface.js` now guards the Android ARCore evidence surface without requiring Godot or a connected Android device.
- `tools/c00/import_device_evidence.sh` now imports manually captured device logs/media into the standard C00 evidence directory and runs the same smoke/media validators.
- `NativeXRProvider` now detects native provider singletons through `Engine.has_singleton(...)` and merges their availability/capability reports.
- `NativeXRProvider` now reports backend runtime identity and `arcore_supported` / `arkit_supported` capability flags for native singleton providers.
- `ios/plugins/godot_arkit` now contains a first-party ARKit iOS plugin skeleton that registers `GodotARKit` as a Godot `Engine` singleton.
- `GodotARKit` now exports `.gdip` init/deinit functions as C symbols and registers its Object class with `ClassDB` before exposing the singleton.
- `GodotARKit` now listens to ARKit `ARSessionDelegate` tracking updates and reports `arkit_tracking_status`, `arkit_tracking_state`, and `arkit_tracking_reason` through `get_capabilities()`.
- The ARKit singleton tracking reason is now consumed by `XRFoundation.get_not_tracking_reason()` / `ARSession.notTrackingReason()` instead of being only a raw capability diagnostic.
- `ios/plugins/godot_arkit/build_xcframework.sh` now builds the ARKit iOS plugin artifacts when `GODOT_SOURCE_DIR` points to matching Godot source headers.
- `tools/c00/check_arkit_plugin_static.sh` now performs an iOS SDK Objective-C++ syntax smoke check for the ARKit plugin before the full Godot-header xcframework build.
- `tools/c00/check_ios_plugin_artifacts.js` now validates the `GodotARKit.gdip`/template against Godot iOS plugin requirements, including config fields, xcframework reference, init/deinit symbols, capabilities, frameworks, and plist entries.
- `tools/c00/check_ios_plugin_artifacts.js` now also validates the ARKit runtime bridge surface: native `start_session`/`stop_session`/tracking methods are bound, `GodotARKitSession` runs `ARWorldTrackingConfiguration`, implements `ARSessionDelegate`, and reports ARKit tracking state/reason.
- `GodotARKit` now exposes C00-level native ARKit `hit_test` / `get_planes` bridge evidence backed by `ARRaycastQuery` and `ARPlaneAnchor`.
- `GodotARKit` now preserves ARKit native transform matrices in raycast and plane dictionaries so Unity-style `XRHit.get_pose()` / placement workflows receive native pose evidence instead of position-only identity transforms.
- `XRHit.from_dictionary()` now accepts readable native trackable type names such as `plane` in addition to integer enum values, making future native plugin bridges less brittle.
- `ARPlaneManager` now polls provider planes while the session is running, so runtime ARKit plane anchors can reach the Unity-style manager layer after session start.
- `GXF_SMOKE` now includes `trackables` metadata with plane/anchor counts and a center-screen `ARRaycastManager` raycast result; smoke and aggregate gates reject logs missing this metadata.
- `tools/c00/check_ios_export_project.js` now validates the exported iOS Xcode project before `xcodebuild`, checking for `GodotARKit`, `GodotARKit.xcframework`, ARKit/Metal frameworks, camera usage, and required device capabilities.
- `tools/c00/run_device_cycle.sh` now orchestrates preflight, optional ARKit plugin build, Godot export, device log collection, and gate validation for iPad/ARKit, Rokid/OpenXR, and Android/ARCore.
- `tools/c00/build_ios_xcode_project.sh` now builds the Godot iOS export zip into `builds/ipad/GodotXRFoundation.app`, and the iPad runner can use it automatically when `APP_PATH` is not set.
- `tools/c00/run_device_cycle.sh all` now continues across iPad/Rokid/Android ARCore gate failures and runs the aggregate C00 phase verifier at the end.
- `tools/c00/check_export_presets.js` now validates that `export_presets.cfg` contains the required C00 preset names before export, requires Rokid exports to include `--xr-platform=rokid`, requires the Android ARCore preset to enable `GodotARCore`, and requires the iPad preset to enable `GodotARKit`.
- `tools/c00/write_export_presets_template.js` now generates a local C00 export preset starter for device machines before Godot editor review.
- `tools/c00/validate_smoke_log.js` now requires explicit ARKit evidence for the iPad gate and explicit ARCore evidence for the Android gate, not only `native_plugin=true`.
- `tools/c00/validate_smoke_log.js` and `tools/c00/verify_phase_evidence.js` now require Unity-style `ar_session_state` / `not_tracking_reason` and iPad ARKit `arkit_tracking_state` / `arkit_tracking_reason`.
- Device collectors now attempt to save media evidence: Android/Rokid records `.mp4` plus `.png`; iOS captures `.png` when `idevicescreenshot` is available and otherwise asks for manual screenshot/recording.
- Android/Rokid collection now writes a device profile report and JSON with model, OS, display, target package, XR-related packages, and notable camera/Vulkan/XR features.
- `tools/c00/analyze_android_device_profile.js` now analyzes Rokid/OpenXR and Android ARCore profile JSON for ADB availability, target package install state, XR/OpenXR runtime packages, camera/Vulkan/XR features, and Rokid hardware match risk.
- `tools/c00/collect_android_smoke.sh` now appends the Android device profile analysis report to the same C00 gate report.
- iPad collection now writes a devicectl-backed device profile report and JSON with device details, display, lock state, target bundle status, and raw JSON command evidence.
- iPad collection now installs the `.app` before collecting the devicectl profile when `APP_PATH` is set, then writes an iPad device profile analysis report that checks selected device, target bundle install state, display evidence, and lock-state risk.
- iPad/Rokid/Android collectors now continue assembling media evidence, device profile, and profile analysis sections after smoke validation failure, then exit non-zero so failed device runs still produce useful diagnostic reports.
- C00 aggregate verification now requires device profile Markdown and JSON evidence for Rokid/OpenXR, iPad/ARKit, and Android/ARCore; manual evidence import can carry those files into the standard evidence layout.
- `tools/c00/validate_evidence_bundle.js` now enforces publishable evidence: Rokid/Android require screenshot plus recording; iPad requires at least one screenshot or recording.
- `tools/c00/verify_phase_evidence.js` now enforces the full C00 publish gate by requiring Rokid/OpenXR, iPad/ARKit, and Android/ARCore evidence in one aggregate report by default.
- Native singleton providers can now report tracking status without an `XRInterface`; `GodotARKit` exposes `is_running()` and `get_tracking_status()` for the C00 panel and logs.
- `GodotARKit.get_tracking_status()` now maps real ARKit state to Godot tracking status: normal tracking, limited/unknown tracking, or not tracking.
- `OpenXRProvider` now reports Unity OpenXR Feature-style runtime diagnostics: selected blend mode, vendor singletons, feature flags, AR tier, and fallback path.
- `OpenXRProvider` now records method-level OpenXR Vendors/Rokid passthrough evidence in `openxr_vendor_feature_report` and `openxr_ar_evidence`.
- `OpenXRProvider` now attempts passthrough lifecycle startup through `XRInterface.start_passthrough()` or vendor singleton passthrough methods and reports `openxr_passthrough_started` / `openxr_passthrough_start_report`.
- `OpenXRProvider` now supplies a clearly marked C00 `openxr_virtual_plane_fallback` / `openxr_plane_source:"virtual_floor_fallback"` raycast and plane fallback when no real OpenXR plane tracker is available, so Rokid can prove the upper ARFoundation manager/raycast chain without pretending to have true environment understanding.
- `tools/c00/validate_smoke_log.js` and `tools/c00/verify_phase_evidence.js` now require Rokid/OpenXR logs to include non-empty `capabilities.openxr_ar_evidence`.
- Official Godot OpenXR Vendors 4.2.0 is now vendored under `addons/godotopenxrvendors` for Godot 4.4 Android/OpenXR exports.
- `ios/plugins/godot_arkit/GodotARKit.xcframework` and `GodotARKit.gdip` are now built locally against Godot 4.4.1 source headers; the archive contains `GodotARKitPlugin.mm.o` and `GodotARKitSession.mm.o` for iOS arm64 plus simulator arm64/x86_64.
- `tools/c00/prepare_godot_source.sh` now generates the minimum Godot build headers needed by external iOS plugin builds: `version_generated.gen.h`, `disabled_classes.gen.h`, and `gdvirtual.gen.inc`.
- `export_presets.cfg` and `tools/c00/write_export_presets_template.js` now use Godot-compatible `;` comments. Godot 4.4 `ConfigFile` does not treat `#` as a comment, which made `preset.0` load as an empty section during real export.
- `tools/c00/export_with_godot.sh` now passes `--xr-mode off` by default so build machines without a desktop OpenXR runtime can still perform command-line exports.
- `tools/c00/install_godot_export_templates.sh` now installs an official Godot export templates `.tpz` into the Godot templates directory and validates that `ios.zip` and `android_source.zip` exist.
- `tools/c00/preflight.sh` now checks real export prerequisites, including Godot export templates, Android SDK `platform-tools` / `build-tools` / `apksigner`, Java, and `keytool`.
- `XRFoundation.resolve_platform_hint()` now reads both Godot command-line args and user args, and smoke/aggregate gates require launch platform evidence for Rokid, iPad, and Android ARCore device gates.
- `tools/c00/collect_android_smoke.sh` now checks APK `assets/_cl_` for the required Godot Android `command_line/extra_args` (`--xr-platform=rokid` or `--xr-platform=arcore`) before install, and force-stops the package before launch so logs come from a fresh process with the intended XR platform.
- C00 now includes an XRI-style smoke surface: `XRInteractionManager`, `XRRayInteractor`, `XRGrabInteractable`, hover/select/activate events, and `GXF_SMOKE.xri` runtime evidence from the demo scene.

Hardware status:

- Godot 4.4.1 stable editor is downloaded, ad-hoc signed for this host, and runs successfully outside the Codex sandbox: `4.4.1.stable.official.49a5bc7b6`.
- Godot source headers for `4.4.1-stable` are prepared under `.godot/cache/c00/godot-source`.
- `GodotARKit.gdip` and `GodotARKit.xcframework` are built and pass `check_ios_plugin_artifacts.js --require-binary`.
- `export_presets.cfg` is now loadable by Godot itself; `preset.0`, `preset.1`, and `preset.2` resolve to Rokid/OpenXR, Android ARCore, and iPad/ARKit respectively.
- Real iPad export reached Godot's export-configuration gate and is currently blocked by missing official export template `~/Library/Application Support/Godot/export_templates/4.4.1.stable/ios.zip`.
- Real Rokid export reached Godot's export-configuration gate and is currently blocked by missing official `android_source.zip`, missing project Android build template, and missing Android SDK build-tools / Java SDK / debug keystore configuration.
- Attempts to download `Godot_v4.4.1-stable_export_templates.tpz` from GitHub, SourceForge, and `downloads.godotengine.org` failed in this environment at TLS/EOF before a secure connection was established. Install the `.tpz` manually or retry on a device machine with working access, then run `tools/c00/install_godot_export_templates.sh --tpz <file>`.
- No Rokid/Android device is currently attached through ADB. The detected `iPad M4` is currently reported by `devicectl` as `unavailable`.
- Do not mark this report as passed until the device evidence below is filled.

## Local Verification On 2026-06-08

| Check | Result | Notes |
| --- | --- | --- |
| `git diff --check` | Pass | No whitespace errors |
| `node --check tools/c00/validate_smoke_log.js` | Pass | Validator parses |
| `node --check tools/c00/collect_android_device_profile.js` | Pass | Android/Rokid profile collector parses |
| `node --check tools/c00/analyze_android_device_profile.js` | Pass | Android/Rokid profile analyzer parses |
| `node --check tools/c00/collect_ios_device_profile.js` | Pass | iPad profile collector parses |
| `node --check tools/c00/analyze_ios_device_profile.js` | Pass | iPad profile analyzer parses |
| `node --check tools/c00/check_ios_device_profile_surface.js` | Pass | iPad device profile surface checker parses |
| `node --check tools/c00/validate_evidence_bundle.js` | Pass | Evidence validator parses |
| `node --check tools/c00/verify_phase_evidence.js` | Pass | C00 aggregate verifier parses |
| `node --check tools/c00/run_static_gates.js` | Pass | Static gate runner parses |
| `node tools/c00/run_static_gates.js --gate all --report /private/tmp/godotar-static-gates.md` | Pass | Static gate report passes with C00 export presets present |
| `node --check tools/c00/check_launch_platform_surface.js` | Pass | Launch platform surface checker parses |
| `node tools/c00/check_launch_platform_surface.js` | Pass | Runtime/platform hint parser, smoke metadata, and device gate launch evidence checks are present |
| `node --check tools/c00/check_device_collector_diagnostics_surface.js` | Pass | Device collector diagnostics checker parses |
| `node tools/c00/check_device_collector_diagnostics_surface.js` | Pass | iPad/Rokid/Android collectors preserve media/profile diagnostics after smoke validation failure |
| `node --check tools/c00/check_ios_plugin_artifacts.js` | Pass | iOS plugin artifact checker parses |
| `node tools/c00/check_ios_plugin_artifacts.js` | Pass with warning | Runtime bridge surface is present; warns that real `GodotARKit.xcframework` is not built on this host |
| `tools/c00/check_arkit_plugin_static.sh` | Pass | ARKit plugin compiles against the local iPhone Simulator SDK with Godot stubs |
| `SDK_NAME=iphoneos tools/c00/check_arkit_plugin_static.sh` | Pass | ARKit plugin compiles against the local iPhoneOS SDK with Godot stubs |
| `node --check tools/c00/check_ios_export_project.js` | Pass | iOS export project checker parses |
| Synthetic iOS export project check | Pass | Checker accepts a synthetic Xcode export containing `GodotARKit`, `GodotARKit.xcframework`, ARKit/Metal frameworks, camera usage, and required device capabilities |
| Synthetic bad iOS export project check | Fail as expected | Checker rejects a synthetic Xcode export missing GodotARKit/plugin binary/framework references and `arkit` required capability |
| `node --check tools/c00/check_godot_project_static.js` | Pass | Godot project/static scene checker parses |
| `node tools/c00/check_godot_project_static.js` | Pass | C00 project settings, scene resources, load steps, required nodes, and NodePaths are intact |
| `node --check tools/c00/check_arfoundation_api_surface.js` | Pass | ARFoundation migration API checker parses |
| `node tools/c00/check_arfoundation_api_surface.js` | Pass | Unity-style ARSession/raycast/trackables surface is present |
| `node --check tools/c00/check_xri_api_surface.js` | Pass | XRI migration API checker parses |
| `node tools/c00/check_xri_api_surface.js` | Pass | XRI manager/ray/interactable smoke surface is present |
| `node --check tools/c00/check_openxr_provider_surface.js` | Pass | OpenXR provider surface checker parses |
| `node tools/c00/check_openxr_provider_surface.js` | Pass | OpenXR/Rokid AR evidence and virtual plane fallback surfaces are present |
| `node --check tools/c00/check_rokid_openxr_export_surface.js` | Pass | Rokid/OpenXR export surface checker parses |
| `node tools/c00/check_rokid_openxr_export_surface.js` | Pass | Rokid/OpenXR export preset and OpenXR Vendors preflight surface is present |
| Synthetic OpenXR Vendors local zip install | Pass | `install_openxr_vendors.sh --zip` installs the inner `asset/addons/godotopenxrvendors` directory into a temp project |
| `node --check tools/c00/check_ios_godot_source_surface.js` | Pass | iPad Godot source preparation checker parses |
| `node tools/c00/check_ios_godot_source_surface.js` | Pass | Godot source helper, ARKit build script validation, bootstrap guidance, and C00 docs are present |
| Synthetic Godot source preparation | Pass | `prepare_godot_source.sh --dir <fake-godot-source> --no-env` accepts a temp tree with required Godot headers and `platform/ios` |
| Synthetic iPad runner source discovery | Pass | `run_device_cycle.sh ipad` resolves `.godot/cache/c00/godot-source` and exports `GODOT_SOURCE_DIR` before ARKit plugin builds |
| Synthetic C00 runner dry-run | Pass | `DRY_RUN=1 tools/c00/run_device_cycle.sh ipad` prints ARKit source/build/export/collect actions without invoking real device commands |
| `node --check tools/c00/check_android_arcore_plugin_surface.js` | Pass | GodotARCore Android plugin surface checker parses |
| `node tools/c00/check_android_arcore_plugin_surface.js` | Pass | GodotARCore Android plugin v2/export singleton surface is present |
| `node --check tools/c00/check_arcore_gate_surface.js` | Pass | Android ARCore gate surface checker parses |
| `node tools/c00/check_arcore_gate_surface.js` | Pass | Android ARCore runtime/capability evidence gate is present |
| `node --check tools/c00/write_export_presets_template.js` | Pass | Preset starter writer parses |
| `bash -n tools/c00/*.sh ios/plugins/godot_arkit/build_xcframework.sh` | Pass | Shell scripts parse |
| `tools/c00/build_ios_xcode_project.sh --help` | Pass | Documents exported Xcode project build path into `builds/ipad/GodotXRFoundation.app` |
| `tools/c00/bootstrap_device_machine.sh` | Blocked by host prerequisites | Generates readiness report, confirms `xcodebuild`, and records missing `godot`, `adb`, export presets, and ARKit build artifacts on this host |
| `REPORT=/private/tmp/godotar-device-readiness.md tools/c00/bootstrap_device_machine.sh` | Blocked by host prerequisites | Readiness report includes `C00 static gates` PASS and still records missing Godot/ADB/export/ARKit binary prerequisites |
| Synthetic Android device profile smoke | Pass | `collect_android_device_profile.js` writes Markdown/JSON with a fake adb command to verify report generation |
| Synthetic Rokid device profile analysis | Pass | Analyzer accepts a Rokid/OpenXR profile with target app, runtime packages, camera, Vulkan, and XR feature evidence |
| Synthetic bad Rokid profile analysis | Fail as expected | Analyzer rejects missing ADB and missing target package while warning about missing OpenXR/camera/Vulkan/XR evidence |
| Synthetic bad ARCore profile analysis | Fail as expected | Analyzer rejects Android ARCore profile JSON with no ARCore package |
| Synthetic Android ARCore smoke gate | Pass | `validate_smoke_log.js --gate android-arcore` accepts `backend:"ARCore"` only when native plugin and explicit ARCore runtime/capability evidence are present |
| Synthetic bad Android ARCore smoke gate | Fail as expected | `validate_smoke_log.js --gate android-arcore` rejects logs that only expose `native_plugin:true` without `runtime:"ARCore"` or `arcore_supported:true` |
| Synthetic launch platform smoke gates | Pass | Rokid, iPad, and Android ARCore logs pass when `platform_hint`, `runtime.resolved_platform_hint`, or `runtime.cmdline_xr_args` proves the target launch path |
| Synthetic bad launch platform smoke gate | Fail as expected | Rokid log with backend/capabilities but no platform launch evidence is rejected |
| Synthetic trackables smoke gates | Pass | Rokid, iPad, and Android ARCore logs pass when `trackables` contains plane/anchor/raycast metadata |
| Synthetic bad trackables smoke gate | Fail as expected | Rokid log with backend/capabilities but no `trackables` object is rejected |
| Synthetic Android ARCore aggregate gate | Pass | `verify_phase_evidence.js --gate android-arcore` accepts ARCore smoke, screenshot, recording, device profile Markdown, and ARCore package JSON evidence |
| Synthetic launch platform aggregate gate | Pass | `verify_phase_evidence.js --gate rokid` accepts launch evidence and rejects the same log when that evidence is removed |
| Synthetic trackables aggregate gate | Pass | `verify_phase_evidence.js --gate rokid` accepts trackables evidence and rejects the same log when that evidence is removed |
| Synthetic Rokid phase profile analysis | Pass | `verify_phase_evidence.js --gate rokid` accepts good Rokid profile analysis when media size is relaxed for synthetic files |
| Synthetic bad Rokid phase profile analysis | Fail as expected | `verify_phase_evidence.js --gate rokid` rejects profile JSON where ADB and target package evidence are missing |
| Synthetic iPad device profile smoke | Pass | `collect_ios_device_profile.js` writes Markdown/JSON with a fake devicectl command to verify report generation |
| Synthetic iPad device profile analysis | Pass | `analyze_ios_device_profile.js` accepts a selected iPad, installed target bundle, display evidence, and unlocked state |
| Synthetic bad iPad device profile analysis | Fail as expected | Analyzer rejects missing selected device, missing target bundle, and locked device evidence |
| Synthetic iPad aggregate profile analysis | Pass | `verify_phase_evidence.js --gate ipad` accepts good iPad profile analysis and rejects locked/missing-target profile JSON |
| Synthetic collector failure diagnostics | Pass | Mocked iPad and Rokid collectors exit non-zero after smoke/media validation failure while still appending device profile and profile analysis to the gate report |
| Synthetic manual evidence import | Pass | `tools/c00/import_device_evidence.sh` imports synthetic Rokid/iPad/Android ARCore logs and media into a temp evidence directory and runs validators |
| Synthetic C00 device profile aggregate gate | Pass | `verify_phase_evidence.js` rejects missing profile evidence and accepts Rokid/iPad/Android ARCore logs, media, and profile Markdown/JSON when all required gates are supplied |
| Synthetic iPad ARKit gate | Pass | `backend:"ARKit"`, `native_plugin:true` |
| Synthetic iPad ARKit tracking gate | Pass | Validator rejects missing `arkit_tracking_state` / `arkit_tracking_reason` and accepts complete ARKit tracking evidence |
| Synthetic Rokid AR gate | Pass | `backend:"OpenXR"`, `ar_product_path:true` |
| Synthetic Rokid OpenXR tier gate | Pass | Validator rejects `openxr_ar_tier:"D"` and warns when tier data is missing |
| Synthetic Rokid OpenXR AR evidence gate | Pass | Validator rejects missing `openxr_ar_evidence` and accepts explicit blend/vendor evidence |
| Synthetic runtime metadata report | Pass | Report includes Godot version and `--xr-platform=rokid` metadata |
| Synthetic Unity-style ARSession log fields | Pass | `validate_smoke_log.js` rejects missing `ar_session_state` / `not_tracking_reason` and accepts complete evidence |
| Synthetic Unity-style ARSession aggregate fields | Pass | `verify_phase_evidence.js --gate rokid` rejects missing Unity-style fields and accepts complete evidence when media/profile are downgraded to warnings |
| Synthetic evidence bundle gates | Pass | Rokid requires screenshot + video; iPad accepts manual media |
| Synthetic C00 phase evidence gate | Pass | Aggregate report passes with Rokid + iPad + Android ARCore evidence and fails on empty evidence |
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
| ARKit native raycast/plane static check | Pass | `GodotARKit` binds `hit_test` / `get_planes`, calls native `ARRaycastQuery`, caches `ARPlaneAnchor` evidence, and preserves native transform matrices |
| GodotARKit `.gdip` template check | Pass with warning | Plugin config matches Godot iOS plugin format; warns that real `GodotARKit.xcframework` is not built on this host |
| ARKit plugin Objective-C++ syntax smoke | Pass | `tools/c00/check_arkit_plugin_static.sh` validates plugin sources against the local iOS SDK with Godot stubs |
| `ADB_BIN=.godot/cache/c00/android-sdk/platform-tools/adb tools/c00/preflight.sh rokid` | Blocked by host prerequisites | Project-local ADB, OpenXR Vendors, and C00 export presets are recognized; still missing `GODOT_BIN` and attached Rokid/OpenXR hardware |
| `tools/c00/preflight.sh ipad` | Blocked by host prerequisites | C00 iPad export preset and ARKit source smoke pass; still missing `GODOT_BIN`, Godot source headers, `GodotARKit.gdip`, and `GodotARKit.xcframework` |

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
- Android ARCore passes only when `backend:"ARCore"`, `session_state:"Running"`, `capabilities.native_plugin:true`, and explicit `capabilities.runtime:"ARCore"` or `capabilities.arcore_supported:true` are present in `GXF_SMOKE`.
- Android ARCore reports must include Unity-style `ar_session_state` and `not_tracking_reason`, plus device profile JSON evidence of an ARCore package such as `com.google.ar.core`.
- C00 device reports should include runtime metadata so startup arguments, Godot version, rendering method, and XR project settings are visible in the gate report.
- Android/Rokid reports should be collected from APKs whose `assets/_cl_` contains the required `--xr-platform` value, and the app should be force-stopped before launch to avoid stale process evidence.
- iPad reports should include device profile analysis proving the target bundle is installed on the selected device and the device is not locked before ARKit launch.
- Failed device runs should still include media evidence and device profile diagnostics in the gate report.
- `EditorSim` is useful evidence that the app starts, but never satisfies a device AR gate.
- EditorSim/simulator gate validates migrated service code and smoke logging only; C00 publish still requires Rokid/OpenXR, iPad/ARKit, and Android/ARCore evidence.
- OpenXR with only `opaque` blend mode is an OpenXR rendering pass, not an AR product pass.
- Rokid/Android publishable results require both screenshot and screen recording artifacts; iPad publishable results require at least one screenshot or recording artifact.
- C00 publishable results require `tools/c00/verify_phase_evidence.js` to pass for Rokid/OpenXR, iPad/ARKit, and Android/ARCore.
- Any engine patch must include a minimal-intrusion patch spec before the device gate can be marked complete.
