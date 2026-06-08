# Godot XR Foundation C00 Test Report

Cycle: C00 Device Smoke Test

Version: v0.0.1-c00-device-smoke

Scene: `res://demo/00_device_smoke_test.tscn`

## Summary

| Gate | Required backend | Result | Evidence |
| --- | --- | --- | --- |
| Editor smoke | EditorSim | Pass | `releases/phase_0_smoke/evidence/editor-20260608-233913.md` |
| iOS Simulator development gate | EditorSim | Build pass / install blocked by Godot simulator template arch | `releases/phase_0_smoke/evidence/ios-simulator-20260609-034114.md` |
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
- Local EditorSim now runs through project-local Godot with `--headless --xr-mode off --xr-platform=simulator`, producing clean ARFoundation/XRI smoke evidence even when the macOS machine has no active OpenXR runtime.
- `validate_smoke_log.js` and `verify_phase_evidence.js` now reject Godot `SCRIPT ERROR`, parse, compile, and failed script load lines, so a scene with broken migration scripts cannot pass by printing partial `GXF_SMOKE`.
- iOS Simulator and Android Emulator are documented as auxiliary cycle outputs for export/startup/log validation only; they cannot satisfy the C00 ARKit/OpenXR publish gate.
- `tools/c00/collect_ios_simulator_smoke.sh` and `tools/c00/run_device_cycle.sh ios-simulator` now provide a runnable iOS Simulator development gate that expects `backend:"EditorSim"` and validates the iOS export/startup/log path before iPad hardware.
- `tools/c00/collect_ios_simulator_smoke.sh` now checks the simulator `.app` executable architecture before install and writes a clear `missing_simulator_arch` evidence report when the Godot simulator template does not contain a slice accepted by the current simulator runtime.
- Godot plugin-first boundary documented. No Godot engine patch is used in C00.
- `tools/c00/bootstrap_device_machine.sh` now generates a C00 readiness report for device machines and can optionally create the export preset starter.
- `tools/c00/import_device_dependency_bundle.sh` now imports an offline dependency bundle containing Godot export templates, Android SDK, JDK, Godot binary, and Godot source headers, then writes `.godot/cache/c00/device-env.sh` for Rokid/iPad/Android ARCore gates.
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
- `GodotARKit` now exports `.gdip` init/deinit functions with the C++ linkage Godot's iOS export `dummy.cpp` expects, and registers its Object class with `ClassDB` before exposing the singleton.
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
- `tools/c00/audit_phase1_completion.js` now performs the Phase 1 completion audit: static gates, Unity ARFoundation/XRI migration surface, ARKit binary artifacts, Rokid/iPad/Android preflight, and final device evidence must all pass before C00 can be reported as ready.
- `tools/c00/run_phase1_device_lab.sh` now provides the device-machine phase-1 wrapper: optional offline dependency import, readiness report, static gates, `run_device_cycle.sh all`, and completion audit in the spec order, with `--dry-run` support.
- `tools/c00/run_phase1_device_lab.sh --online-deps` now provides the matching online dependency path: resumable Godot export template install, OpenJDK 17 install, Android SDK package install, Android export environment/build-template configuration, and `.godot/cache/c00/device-env.sh` refresh before readiness/preflight.
- Slow device-machine networks can now run `--online-deps-only` with `ONLINE_DEPS=templates,jdk,android-sdk,android-export` subsets, or pass `--online-deps-list`, so large C00 dependencies can be resumed and verified in smaller publishable steps.
- Native singleton providers can now report tracking status without an `XRInterface`; `GodotARKit` exposes `is_running()` and `get_tracking_status()` for the C00 panel and logs.
- `GodotARKit.get_tracking_status()` now maps real ARKit state to Godot tracking status: normal tracking, limited/unknown tracking, or not tracking.
- `OpenXRProvider` now reports Unity OpenXR Feature-style runtime diagnostics: selected blend mode, vendor singletons, feature flags, AR tier, and fallback path.
- `OpenXRProvider` now records method-level OpenXR Vendors/Rokid passthrough evidence in `openxr_vendor_feature_report` and `openxr_ar_evidence`.
- `OpenXRProvider` now attempts passthrough lifecycle startup through `XRInterface.start_passthrough()` or vendor singleton passthrough methods and reports `openxr_passthrough_started` / `openxr_passthrough_start_report`.
- `OpenXRProvider` now supplies a clearly marked C00 `openxr_virtual_plane_fallback` / `openxr_plane_source:"virtual_floor_fallback"` raycast and plane fallback when no real OpenXR plane tracker is available, so Rokid can prove the upper ARFoundation manager/raycast chain without pretending to have true environment understanding.
- `tools/c00/validate_smoke_log.js` and `tools/c00/verify_phase_evidence.js` now require Rokid/OpenXR logs to include non-empty `capabilities.openxr_ar_evidence`.
- ARFoundation manager facades now expose Unity AR Foundation 6-style `trackablesChanged(changes)` signals with `ARTrackablesChangedEventArgs.added/updated/removed`, while preserving the original Godot-side `planes_changed(added, updated, removed)` and `anchors_changed(added, updated, removed)` signals.
- `ARPlaneManager` now exposes `requested_detection_mode`, detection-mode string mapping, `GetTrackable(...)`, `TryGetTrackable(...)`, and `TryGetPlane(...)` migration aliases.
- `ARAnchorManager` now exposes `GetTrackable(...)`, `TryGetTrackable(...)`, and `TryGetAnchor(...)` migration aliases.
- `XRHit` now exposes Unity-style `pose`, `trackableId`, `trackableType`, `GetTrackableId()`, and `GetTrackableType()` aliases alongside the existing Godot snake_case fields.
- `ARRaycastManager` now exposes additional Unity-placement migration aliases `RaycastScreenPoint(...)` and `RaycastList(...)` for screen-point list-output workflows that still require Godot's explicit `Camera3D`.
- `XRInteractionManager`, `XRRayInteractor`, and `XRGrabInteractable` now emit Unity XRI-style camelCase signals such as `hoverEntered`, `selectEntered`, `firstSelectEntered`, and `lastSelectExited` alongside their snake_case Godot signals.
- Official Godot OpenXR Vendors 4.2.0 is now vendored under `addons/godotopenxrvendors` for Godot 4.4 Android/OpenXR exports.
- `ios/plugins/godot_arkit/GodotARKit.xcframework` and `GodotARKit.gdip` are now built locally against Godot 4.4.1 source headers; the archive contains `GodotARKitPlugin.mm.o` and `GodotARKitSession.mm.o` for iOS arm64 plus simulator arm64/x86_64.
- `tools/c00/prepare_godot_source.sh` now generates the minimum Godot build headers needed by external iOS plugin builds: `version_generated.gen.h`, `disabled_classes.gen.h`, and `gdvirtual.gen.inc`.
- `export_presets.cfg` and `tools/c00/write_export_presets_template.js` now use Godot-compatible `;` comments. Godot 4.4 `ConfigFile` does not treat `#` as a comment, which made `preset.0` load as an empty section during real export.
- `tools/c00/export_with_godot.sh` now passes `--xr-mode off` by default so build machines without a desktop OpenXR runtime can still perform command-line exports.
- `tools/c00/install_godot_export_templates.sh` now installs an official Godot export templates `.tpz` into the Godot templates directory, supports `--download`, and validates that `ios.zip` and `android_source.zip` exist.
- `tools/c00/install_android_build_template.sh` now mirrors Godot 4.4's Android build-template install flow by extracting `android_source.zip` into `android/build`, writing `android/.build_version`, and checking for `build.gradle`.
- `tools/c00/install_openjdk17.sh` now downloads or imports OpenJDK 17 into `.godot/cache/c00/jdk/Contents/Home` so Godot Android export, `sdkmanager`, and debug keystore generation can use a project-local JDK.
- `tools/c00/install_android_sdk_packages.sh` now installs Android command line tools when `--download-cmdline-tools` / `--cmdline-tools-zip` is provided, then installs the Android SDK packages Godot 4.4 expects for C00 exports: `platform-tools`, `platforms;android-34`, and `build-tools;34.0.0`.
- `tools/c00/install_android_sdk_packages.sh` now isolates the `yes | sdkmanager` pipe from shell `pipefail`, so a successful `sdkmanager` run is not reported as failed just because `yes` exits on SIGPIPE after stdin closes.
- `tools/c00/configure_android_export_environment.sh` now prepares the Android SDK path, JDK path, debug keystore, Godot Android EditorSettings, and project Android build template before Rokid/OpenXR or Android/ARCore export.
- `tools/c00/export_with_godot.sh` now auto-runs Android export environment configuration before `.apk` / `.aab` export unless `GODOT_CONFIGURE_ANDROID_EXPORT=0` is set.
- `tools/c00/preflight.sh` now checks real export prerequisites, including Godot export templates, project Android build template, Android SDK `platform-tools` / `build-tools` / `apksigner`, a working JDK (`java -version` and `keytool -help`), and debug keystore configuration.
- `tools/c00/preflight.sh` and `tools/c00/export_with_godot.sh` now auto-detect project-local Godot at `.godot/cache/c00/godot-editor/Godot.app/Contents/MacOS/Godot`, reducing device-machine environment setup friction.
- `tools/c00/preflight.sh` and `tools/c00/collect_android_smoke.sh` now auto-detect `ADB_BIN`, PATH `adb`, or project-local `.godot/cache/c00/android-sdk/platform-tools/adb`; Android/Rokid device profile collection receives the resolved adb path.
- `XRFoundation.resolve_platform_hint()` now reads both Godot command-line args and user args, and smoke/aggregate gates require launch platform evidence for Rokid, iPad, and Android ARCore device gates.
- `tools/c00/collect_android_smoke.sh` now checks APK `assets/_cl_` for the required Godot Android `command_line/extra_args` (`--xr-platform=rokid` or `--xr-platform=arcore`) before install, and force-stops the package before launch so logs come from a fresh process with the intended XR platform.
- C00 now includes an XRI-style smoke surface: `XRInteractionManager`, `XRRayInteractor`, `XRGrabInteractable`, hover/select/activate events, and `GXF_SMOKE.xri` runtime evidence from the demo scene.
- `addons/godot_openxr_vendors_export` now provides a project addon export hook for Godot OpenXR Vendors Android AARs, so Rokid/OpenXR can select one vendor loader through export preset options without modifying Godot engine code.
- `addons/godot_arcore/export_plugin.gd` now gates ARCore AAR/dependency/manifest injection on the Android ARCore preset or `--xr-platform=arcore`, so Rokid/OpenXR exports do not accidentally carry ARCore runtime libraries.
- `tools/c00/check_android_apk_surface.js` now inspects exported APKs for launch arguments and packaged native libraries, with separate gates for Rokid/OpenXR and Android/ARCore.
- ARKit plugin init/deinit linkage is now verified against Godot's generated iOS plugin call path; the rebuilt `GodotARKit.xcframework` passes symbol checks and a no-sign Xcode device build.
- Android/Rokid collection now treats lack of an ADB `device` state as an explicit diagnostic failure while still writing device profile and analysis evidence.
- iPad collection now preserves diagnostics after app install failure, records `xcrun xctrace list devices`, and treats `offline` / `unavailable` iPad state as an explicit profile-analysis failure.

Hardware status:

- Godot 4.4.1 stable editor is downloaded, ad-hoc signed for this host, and runs successfully outside the Codex sandbox: `4.4.1.stable.official.49a5bc7b6`.
- Godot source headers for `4.4.1-stable` are prepared under `.godot/cache/c00/godot-source`.
- `GodotARKit.gdip` and `GodotARKit.xcframework` are built and pass `check_ios_plugin_artifacts.js --require-binary`.
- `export_presets.cfg` is now loadable by Godot itself; `preset.0`, `preset.1`, and `preset.2` resolve to Rokid/OpenXR, Android ARCore, and iPad/ARKit respectively.
- Real Rokid/OpenXR export now produces `builds/rokid/c00.apk`; APK static inspection confirms `--xr-platform=rokid`, OpenXR loader/vendor libraries, and no ARCore native libraries.
- Real Android/ARCore export now produces `builds/android_arcore/c00.apk`; APK static inspection confirms `--xr-platform=arcore`, ARCore native libraries, and no OpenXR loader.
- Real iPad/ARKit export now produces an Xcode project zip, passes `check_ios_export_project.js`, and builds a generic iOS device `.app` with code signing disabled. Real iPad install/run is still blocked by signing/device availability.
- Real iOS Simulator export now builds an unsigned simulator `.app`, but the current Godot 4.4.1 iOS Simulator template on this host produces an `x86_64` executable while the Apple Silicon iPadOS simulator requires `arm64`; this is tracked as a development-gate blocker, not a C00 publish pass.
- Temurin OpenJDK 17 was installed on 2026-06-09 under `.godot/cache/c00/jdk/Contents/Home`; `java`, `keytool`, and `.godot/cache/c00/android/debug.keystore` pass Rokid preflight.
- Android command line tools, `platforms;android-34`, and `build-tools;34.0.0` were installed on 2026-06-09 under `.godot/cache/c00/android-sdk`; `apksigner` passes Rokid preflight.
- Attempts to download `Godot_v4.4.1-stable_export_templates.tpz` on 2026-06-08 reached the official hosts but are too slow/partial in this environment. `tools/c00/install_godot_export_templates.sh --download` resumed the export templates file to 19 MB before being stopped intentionally; rerunning the installer command will continue from the partial file because it uses `curl -L --fail -C -`.
- `brew install openjdk@17` was also attempted on 2026-06-08, but Homebrew auto-update stalled while fetching Homebrew API metadata and was stopped. No system JDK was installed; the project-local JDK installer/offline bundle path remains the preferred device-machine route.
- `tools/c00/bootstrap_device_machine.sh` now includes a Download Cache section so device-machine reports show partial dependency files and the exact resume command for each installer.
- Online dependency installers now share `C00_CURL_RETRY`, `C00_CURL_RETRY_DELAY`, `C00_CURL_CONNECT_TIMEOUT`, `C00_CURL_SPEED_LIMIT`, `C00_CURL_SPEED_TIME`, and `C00_CURL_EXTRA_ARGS`, so a device machine can tune retry/low-speed behavior without editing scripts.
- Godot export template download now tries the Godot official downloads entry first, then the GitHub release URL; all online dependency installers can accept multiple candidate URLs for device-machine mirrors or proxies.
- `tools/c00/preflight.sh`, `tools/c00/bootstrap_device_machine.sh`, and `tools/c00/run_device_cycle.sh` now auto-source `.godot/cache/c00/device-env.sh` when present, with `C00_DEVICE_ENV_FILE` / `C00_AUTO_SOURCE_DEVICE_ENV` overrides for alternate device-machine setups.
- Offline device-machine setup is still supported through `tools/c00/import_device_dependency_bundle.sh --bundle <device-bundle-dir>`. Put `Godot_v4.4.1-stable_export_templates.tpz`, Android SDK `platform-tools`/`build-tools`, a real JDK, optional `Godot.app`, and optional `godot-source` into the bundle, then either source `.godot/cache/c00/device-env.sh` manually or let the C00 entry scripts auto-source it.
- No Rokid/Android device is currently attached through ADB. The detected `iPad M4` is currently reported by `devicectl` as `unavailable`.
- Do not mark this report as passed until the device evidence below is filled.

## Local Verification On 2026-06-09

| Check | Result | Notes |
| --- | --- | --- |
| `node tools/c00/run_static_gates.js --gate all` | Pass | Includes `git diff --check`, ARFoundation/XRI surface checks, export preset checks, ARKit artifact checks, and Android export surface checks |
| `tools/c00/preflight.sh rokid` | Pass | Godot, Android SDK/JDK, debug keystore, OpenXR Vendors addon, Khronos AAR, and Rokid preset are present |
| `tools/c00/export_with_godot.sh "C00 Rokid OpenXR" builds/rokid/c00.apk` | Pass | Export completes; nonfatal Godot export warnings remain recorded for later cleanup |
| `node tools/c00/check_android_apk_surface.js --gate rokid --apk builds/rokid/c00.apk` | Pass | APK contains OpenXR loader/vendor artifacts and does not contain ARCore native libs |
| `apksigner verify --print-certs builds/rokid/c00.apk` | Pass | Debug-signed with the C00 debug keystore |
| `tools/c00/preflight.sh android-arcore` | Pass | GodotARCore plugin AARs and Android export prerequisites are present |
| `tools/c00/export_with_godot.sh "C00 Android ARCore" builds/android_arcore/c00.apk` | Pass | Export completes with GodotARCore enabled only for ARCore preset |
| `node tools/c00/check_android_apk_surface.js --gate android-arcore --apk builds/android_arcore/c00.apk` | Pass | APK contains ARCore native libs and does not contain the OpenXR loader |
| `apksigner verify --print-certs builds/android_arcore/c00.apk` | Pass | Debug-signed with the C00 debug keystore |
| `tools/c00/preflight.sh ipad` | Pass with signing warning | Placeholder Team ID remains in the starter preset and must be replaced before real iPad install |
| `node tools/c00/check_ios_plugin_artifacts.js --file ios/plugins/godot_arkit/GodotARKit.gdip --require-binary` | Pass | `GodotARKit.xcframework` is present and symbol linkage matches Godot's iOS plugin call path |
| `node tools/c00/check_ios_export_project.js --input builds/ipad/c00.zip` | Pass | Exported Xcode project references GodotARKit, ARKit/Metal frameworks, camera plist, and required capabilities |
| `tools/c00/build_ios_xcode_project.sh builds/ipad/c00.zip` with `IOS_BUILD_PLATFORM=ios CODE_SIGNING_ALLOWED=NO` | Pass | Generic iOS device build produces `builds/ipad/GodotXRFoundation-nosign.app` |
| `IOS_BUILD_PLATFORM=simulator tools/c00/build_ios_xcode_project.sh builds/ios_simulator/c00.zip` with signing disabled | Pass | Simulator Xcode build succeeds after project-only export fallback, MetalFX simulator patch, and Godot template architecture detection; resulting app executable is `x86_64` |
| `APP_PATH=builds/ios_simulator/GodotXRFoundation.app tools/c00/collect_ios_simulator_smoke.sh ...` | Fail as expected / diagnostic produced | Current Apple Silicon simulator requires `arm64`, but the app executable is `x86_64`; collector writes `releases/phase_0_smoke/evidence/ios-simulator-20260609-034114.md` before install |
| `CAPTURE_MEDIA=0 DURATION=1 APK_PATH=builds/rokid/c00.apk tools/c00/collect_android_smoke.sh rokid ...` | Fail as expected / diagnostic produced | Current host has no ADB `device` state; collector writes `has_connected_device:false`, skips install/launch, appends device profile and analysis |
| `DEVICECTL_TIMEOUT=5 CAPTURE_MEDIA=0 APP_PATH=builds/ipad/GodotXRFoundation-nosign.app tools/c00/collect_ios_smoke.sh "iPad M4" ...` | Fail as expected / diagnostic produced | Current iPad is `unavailable` in devicectl and `Devices Offline` in xctrace; collector preserves install failure, device profile, and profile analysis |

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
| `node --check tools/c00/check_device_dependency_bundle_surface.js` | Pass | Offline dependency bundle surface checker parses |
| `node tools/c00/check_device_dependency_bundle_surface.js` | Pass | Importer, README, bootstrap report, and C00 spec document offline bundle setup |
| Empty offline dependency bundle smoke | Fail as expected | Importer writes a readable report and env file while reporting missing templates, Android SDK, and JDK |
| `node --check tools/c00/audit_phase1_completion.js` | Pass | Phase 1 completion audit parser passes |
| `node --check tools/c00/check_phase1_completion_audit_surface.js` | Pass | Completion audit surface checker parses |
| `node tools/c00/check_phase1_completion_audit_surface.js` | Pass | Audit script, static gate integration, README, runbook, and TEST_REPORT references are present |
| `node tools/c00/audit_phase1_completion.js --skip-preflight --skip-evidence --report /private/tmp/c00-audit.md --json /private/tmp/c00-audit.json` | Pass / PARTIAL | Code/API/plugin/provider audit passes when intentionally skipping device-machine and device-evidence gates; it does not mark phase 1 complete |
| `node tools/c00/audit_phase1_completion.js --report /private/tmp/c00-audit-full.md --json /private/tmp/c00-audit-full.json` | Fail as expected | Full audit outputs `NOT_READY` until Rokid/OpenXR, iPad/ARKit, and Android/ARCore preflight/evidence are present |
| `bash -n tools/c00/run_phase1_device_lab.sh` | Pass | Device-lab wrapper shell syntax passes |
| `node tools/c00/check_phase1_device_lab_surface.js` | Pass | Device-lab wrapper, static gate integration, README, runbook, and C00 spec references are present |
| `tools/c00/run_phase1_device_lab.sh --dry-run --no-import --device ipad-placeholder` | Pass | Dry-run prints readiness, static gates, iPad/Rokid/Android device-cycle steps, phase evidence verify, and completion audit without invoking Godot/Xcode/ADB/devicectl |
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
| Unity ARRaycastHit alias surface | Pass | `XRHit.pose`, `trackableId`, `trackableType`, `GetTrackableId()`, and `GetTrackableType()` are guarded by `check_arfoundation_api_surface.js` |
| Unity XRI camelCase signal surface | Pass | `hoverEntered`, `selectEntered`, `firstSelectEntered`, and `lastSelectExited` are guarded by `check_xri_api_surface.js` |
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
| Local EditorSim collector | Pass | `run_device_cycle.sh editor` produced `releases/phase_0_smoke/evidence/editor-20260608-233913.md` with `scriptErrors: []`, one simulated plane, center raycast hit, and XRI manager/ray/grab evidence |
| Smoke script-error guard | Pass | `validate_smoke_log.js` rejects the earlier broken EditorSim log when Godot reports `SCRIPT ERROR` / parse / compile failures |
| Synthetic iOS Simulator gate | Pass | `validate_smoke_log.js --gate ios-simulator` accepts `backend:"EditorSim"` as development evidence |
| Synthetic iOS Simulator vs iPad boundary | Fail as expected | The same `EditorSim` log fails `--gate ipad` with `Expected backend ARKit` |
| Synthetic Rokid OpenXR-only strict gate | Fail as expected | `ar_product_path:false` is not accepted as AR product pass |
| `ios/plugins/godot_arkit/build_xcframework.sh --help` | Pass | Documents required Godot source header path and outputs |
| `tools/c00/collect_ios_simulator_smoke.sh --help` | Pass | Documents the iOS Simulator development gate |
| `tools/c00/run_device_cycle.sh --help` | Pass | Documents EditorSim, iOS Simulator, iPad, Rokid, and Android ARCore gate execution |
| `tools/c00/run_device_cycle.sh all` control flow | Pass | With export/collect disabled, records failing preflights and exits nonzero instead of silently passing |
| `APP_PATH=/private/tmp/missing.app tools/c00/preflight.sh ios-simulator` | Fail as expected | Collection-only simulator gate skips Godot/export preset checks but requires an existing `.app` |
| `node --check tools/c00/check_export_presets.js` | Pass | Preset checker parses |
| ARKit plugin symbol/static check | Pass | `.gdip` init symbols use the C++ linkage Godot's generated iOS plugin caller expects, and `GodotARKitPlugin` registers with `ClassDB` |
| ARKit tracking state/static check | Pass | `GodotARKitSession` implements `ARSessionDelegate` and exposes ARKit tracking state/reason |
| ARKit native raycast/plane static check | Pass | `GodotARKit` binds `hit_test` / `get_planes`, calls native `ARRaycastQuery`, caches `ARPlaneAnchor` evidence, and preserves native transform matrices |
| GodotARKit `.gdip` template check | Pass | Plugin config matches Godot iOS plugin format and real `GodotARKit.xcframework` artifacts are built on this host |
| ARKit plugin Objective-C++ syntax smoke | Pass | `tools/c00/check_arkit_plugin_static.sh` validates plugin sources against the local iOS SDK with Godot stubs |
| `tools/c00/preflight.sh ipad` | Superseded on 2026-06-09 | The current host now has the iOS export template and ARKit binary artifacts; see the 2026-06-09 verification table |
| `tools/c00/preflight.sh rokid` | Superseded on 2026-06-09 | The current host now has Android export templates/build template and OpenXR Vendors artifacts; see the 2026-06-09 verification table |

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
