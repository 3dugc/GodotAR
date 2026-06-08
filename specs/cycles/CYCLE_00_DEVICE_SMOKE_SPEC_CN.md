# C00 Device Smoke Test Spec

状态：Frozen

周期：C00

版本：v0.0.1-c00-device-smoke

建议周期：3-5 天

## 一句话成果

Rokid、Android 手机/平板、iOS 设备都能运行一个最小 Godot app，并显示 backend、tracking、capability 和日志。

## 目标设备

| 设备 | 是否必须 | 运行方式 | 备注 |
| --- | --- | --- | --- |
| Editor | Yes | Godot editor | 必须可运行 |
| Rokid | Yes | APK | 优先 OpenXR |
| iPad | Yes | Xcode project | 优先 ARKit |
| Android ARCore | Yes | APK | 先确认 plugin availability |
| EditorSim / iOS Simulator / Android Emulator | No | 本机模拟 | 只作为开发期 gate 和导出链路检查 |

## 本周期做

- 新增 `demo/00_device_smoke_test.tscn`。
- 新增运行时状态面板：app version、cycle、backend、provider、tracking state、capabilities、FPS。
- `GXF_SMOKE` 日志必须包含 runtime metadata：Godot 版本、XR 相关启动参数、`resolved_platform_hint`、rendering method、OpenXR/XR shader project setting、viewport XR 状态。
- `GXF_SMOKE` 日志必须包含 Unity 语义的 `ar_session_state` 和 `not_tracking_reason`，便于从 Unity ARFoundation 服务迁移时直接对照。
- 明确插件优先边界：C00 不修改 Godot 主干，只通过 addon/provider/native plugin/OpenXR runtime 接入。
- Rokid 构建一个 APK，尝试 OpenXR 初始化。
- Rokid/OpenXR provider 启动时必须主动尝试 `start_passthrough` 或 vendor passthrough lifecycle，并把 `openxr_passthrough_started` / `openxr_passthrough_start_report` 写入 capability report。
- iPad 导出 Xcode project，尝试 ARKit provider availability。
- 新增 `ios/plugins/godot_arkit` 插件骨架，让 iPad gate 有明确 native singleton 落点。
- `GodotARKit` 必须通过 ARKit `ARSessionDelegate` 上报真实 tracking state/reason，而不是用 `is_running()` 代替 normal tracking。
- `GodotARKit` 应提供 C00 级 native `hit_test` 和 `get_planes`，把 ARKit `ARRaycastQuery` / `ARPlaneAnchor` 转成上层 `ARRaycastManager` / `ARPlaneManager` 可消费的字典证据。
- Android 构建一个 APK，确认 ARCore plugin 或 fallback provider 可用性。
- iOS/iPhone 可作为扩展验证，不替代 iPad gate。
- 归档截图、录屏、日志。
- Android/Rokid 采集脚本自动尝试生成截图和 15 秒录屏；iOS 采集脚本在有 `idevicescreenshot` 时自动截图。
- Android/Rokid 采集脚本必须归档设备画像：设备型号、系统版本、display、target package、XR/OpenXR/ARCore/Rokid 相关包和关键 feature。
- Android/Rokid 采集脚本必须分析 device profile，报告 ADB、目标包安装、XR/OpenXR runtime 包、camera/Vulkan/XR feature 和 Rokid 硬件匹配状态。
- iPad 采集脚本必须归档 `devicectl --json-output` 设备画像：device details、display、lock state、目标 bundle 安装状态和原始 JSON。
- 新增 `tools/c00` 预检、导出、日志采集和 gate 验证脚本。
- 新增 `tools/c00/bootstrap_device_machine.sh`，在设备机生成 C00 readiness report，并可选生成 export preset starter。
- 新增 Godot project/scene 静态完整性检查，确认 C00 主场景、rig、脚本资源、autoload、OpenXR 设置和关键 NodePath 在没有 Godot binary 时也能先检查。
- 新增 launch platform evidence gate，确认运行时会同时解析 Godot 普通 command-line args 和 user args，并要求 Rokid/iPad/Android ARCore 设备日志能证明本次启动选择了目标 XR platform。
- 新增 C00 一键静态 gate，汇总 Node/Bash 语法、Godot project/scene、ARFoundation、XRI、OpenXR/Rokid、Android ARCore 和 iOS plugin 静态检查，并生成 Markdown/JSON 报告。
- 新增 EditorSim/模拟器 gate，用于无设备时验证 ARFoundation-style 上层 API、raycast、anchor、plane 和 smoke log。
- 新增 ARFoundation API surface 静态 gate，确保 `ARSession.state/notTrackingReason/requestedTrackingMode/matchFrameRate`、screen raycast、trackables 和 changed events 的迁移入口稳定。
- 新增 XRI-style interaction smoke surface：`XRInteractionManager` 统一注册/调度 `XRRayInteractor` 与 `XRGrabInteractable`，C00 demo 输出 XRI hover/select 状态。
- 模拟器 gate 可以在每个周期作为可运行成果：EditorSim 验证统一上层 API；iOS Simulator 验证 iOS 导出、`.xcframework` simulator slice 和 app 启动链路；Android Emulator 验证 Android 导出和日志链路。
- 新增 `tools/c00/collect_ios_simulator_smoke.sh` 和 `tools/c00/run_device_cycle.sh ios-simulator`，作为 iPad 真机前的 iOS 导出/启动辅助 gate。
- 新增 `tools/c00/write_export_presets_template.js`，用于在设备机生成 C00 export preset starter，再由 Godot editor 复核保存。
- 新增 `tools/c00/build_ios_xcode_project.sh`，用于把 Godot iOS 导出的 Xcode project zip 构建成稳定路径的 `.app`，再交给 iPad gate 安装/启动。
- 新增 `tools/c00/check_ios_export_project.js`，用于在 `xcodebuild` 前确认 Godot iOS 导出的 Xcode project 已包含 `GodotARKit.xcframework`、ARKit/Metal framework 和相机 plist。
- 新增 `tools/c00/verify_phase_evidence.js`，用于聚合验证 Rokid/OpenXR、iPad/ARKit 和 Android/ARCore 三条必过 gate，并生成 C00 总报告。
- 新增 `tools/c00/import_device_evidence.sh`，用于导入 Xcode/Console.app/Android Studio/手动录屏导出的设备证据并运行同一套 gate。
- `tools/c00/run_device_cycle.sh all` 必须继续跑完 iPad/Rokid/Android ARCore gate 并自动执行 C00 聚合验证，避免单台失败遮住另一台设备状态。
- iPad/ARKit gate 前应能运行 ARKit native plugin Objective-C++ 语法 smoke check；真实通过仍以 `GodotARKit.xcframework` 构建和 iPad 真机证据为准。
- iPad/ARKit gate 前应校验 `GodotARKit.gdip`/`.gdip.template` 符合 Godot iOS plugin 官方格式，且 init/deinit 符号、ARKit/Metal capability、framework 和 plist 配置一致。
- iPad/ARKit gate 前应校验 Godot 导出的 Xcode project 已引用 `GodotARKit.xcframework`、`ARKit.framework`、`Metal.framework`、`NSCameraUsageDescription` 和 `UIRequiredDeviceCapabilities`。

## 本周期不做

- 不实现跨平台完整真实平面检测；C00 只要求 iPad/ARKit bridge 暴露最小 native raycast/plane evidence，Rokid/OpenXR 与 Android ARCore 的完整 trackable 行为进入后续周期。
- 不实现真实 anchor。
- 不要求 camera background 成功。
- 不做最终 UI 设计。
- 不侵入 Godot engine 主干。
- 模拟器通过不替代 Rokid/OpenXR 或 iPad/ARKit 真机 gate；模拟器结果只能标记为开发期可运行成果，不能标记为 C00 发布通过。

## API / 接口

新增：

- `XRFoundation.get_backend_name()`
- provider capability flags
- unified smoke test log format

冻结：

- `XRFoundation.start_session(requested_backend, options)`
- `XRFoundation.stop_session()`

## Demo

场景：

```text
demo/00_device_smoke_test.tscn
```

最小 UI：

- 状态文本面板。
- 一个 1m 坐标参考。
- 一个按钮或 gaze target。
- 一个旋转 cube，用于确认渲染不卡死。

## 已落地接口

- `ARSession.CheckAvailability(...)`
- `ARSession.Install(...)`
- `ARSession.Reset()`
- `ARSession.state()`
- `ARSession.GetState()`
- `ARSession.GetARSessionState()`
- `ARSession.GetNotTrackingReason()`
- `ARSession.foundation_state()`
- `XRFoundation.get_ar_session_state()`
- `XRFoundation.get_not_tracking_reason()`
- native singleton `arkit_tracking_reason` / `tracking_reason` -> `XRFoundation.get_not_tracking_reason()`
- `ARRaycastManager.TryRaycast(...)`
- `ARRaycastManager.RaycastToList(...)`
- `ARRaycastManager.RaycastFromScreen(...)`
- `ARRaycastManager.TryScreenRaycast(...)`
- `XRHit.get_pose()`
- `XRInteractionManager.RegisterInteractor(...)`
- `XRInteractionManager.RegisterInteractable(...)`
- `XRInteractionManager.select(...)`
- `XRInteractionManager.release(...)`
- `XRRayInteractor.GetValidTargets(...)`
- `XRRayInteractor.TryGetCurrent3DRaycastHit(...)`
- `XRGrabInteractable.IsHovered()`
- `XRGrabInteractable.IsSelected()`
- `ARAnchorManager.TryAddAnchorAsync(...)`
- `ARAnchorManager.TryRemoveAnchor(...)`
- `ARAnchor.from_dictionary(...)`
- `ARAnchorManager.anchors_changed(added, updated, removed)`
- `ARPlaneManager.planes_changed(added, updated, removed)`
- `ARPlaneManager.GetTrackables()`
- `ARAnchorManager.GetTrackables()`
- `XRFoundation.check_availability(...)`
- `XRFoundation.install(...)`
- `XRFoundation.reset_session(...)`
- `XRFoundation.get_capabilities()`
- `XRFoundation.get_provider_name()`
- `XRFoundation.get_tracking_state_name()`
- `NativeXRProvider` preserves native anchor dictionary ids and persistent ids from ARKit/ARCore singleton bridges.
- `tools/c00/bootstrap_device_machine.sh`
- `tools/c00/validate_smoke_log.js`
- `tools/c00/validate_evidence_bundle.js`
- `tools/c00/verify_phase_evidence.js`
- `tools/c00/check_export_presets.js`
- `tools/c00/analyze_android_device_profile.js`
- `tools/c00/check_godot_project_static.js`
- `tools/c00/run_static_gates.js`
- `tools/c00/check_arfoundation_api_surface.js`
- `tools/c00/check_xri_api_surface.js`
- `tools/c00/check_openxr_provider_surface.js`
- `tools/c00/check_ios_plugin_artifacts.js`
- `tools/c00/check_ios_export_project.js`
- `tools/c00/write_export_presets_template.js`
- `tools/c00/build_ios_xcode_project.sh`
- `tools/c00/collect_android_device_profile.js`
- `tools/c00/collect_android_smoke.sh`
- `tools/c00/collect_ios_device_profile.js`
- `tools/c00/collect_ios_smoke.sh`
- `tools/c00/collect_ios_simulator_smoke.sh`
- `tools/c00/collect_editor_smoke.sh`
- `tools/c00/import_device_evidence.sh`
- `tools/c00/export_with_godot.sh`
- `tools/c00/run_device_cycle.sh`
- `tools/c00/check_arkit_plugin_static.sh`
- `ios/plugins/godot_arkit/build_xcframework.sh`

统一日志格式：

```text
GXF_SMOKE|{"cycle":"C00","event":"session_started","platform_hint":"rokid","runtime":{"godot":...,"cmdline_xr_args":["--xr-platform=rokid"],"resolved_platform_hint":"rokid",...},"backend":"OpenXR","session_state":"Running","ar_session_state":"SessionTracking","not_tracking_reason":"None","capabilities":{"openxr_ar_evidence":["environment_blend:alpha_blend"]},"xri":{"interaction_manager":true,"ray_interactor":true},...}
```

Rokid gate 必须看到 `backend:"OpenXR"`。

Rokid gate 必须看到启动平台证据：`platform_hint`、`runtime.resolved_platform_hint`、project setting 或 `runtime.cmdline_xr_args` 中至少一个值指向 `rokid` / `openxr` / `androidxr`。

Rokid gate 应记录 `capabilities.openxr_ar_tier` 和 `capabilities.openxr_fallback`；`D` 代表 VR-only，不能作为 AR 产品路径通过。

Rokid gate 必须记录 `capabilities.openxr_ar_evidence`，用于说明 AR 产品路径来自 `alpha_blend` / `additive` blend mode，还是来自 OpenXR Vendors/Rokid passthrough singleton 的能力方法。

Rokid gate 应记录 `capabilities.openxr_passthrough_started` 和 `capabilities.openxr_passthrough_start_report`，用于确认 provider 在 OpenXR session 启动后是否实际调用了 passthrough lifecycle。

iPad gate 必须看到 `backend:"ARKit"`。

iPad gate 必须看到启动平台证据：`platform_hint`、`runtime.resolved_platform_hint`、project setting 或 `runtime.cmdline_xr_args` 中至少一个值指向 `ipad` / `iphone` / `ios` / `arkit`。

iPad gate 还必须看到 `capabilities.native_plugin:true`，以及 `capabilities.runtime:"ARKit"` 或 `capabilities.arkit_supported:true`。

iPad gate 应记录 `capabilities.arkit_tracking_state` 和 `capabilities.arkit_tracking_reason`；`normal` 算稳定跟踪，`limited` 或 `not_available` 必须在报告中保留原因。

Android ARCore gate 必须看到 `backend:"ARCore"`。

Android ARCore gate 必须看到启动平台证据：`platform_hint`、`runtime.resolved_platform_hint`、project setting 或 `runtime.cmdline_xr_args` 中至少一个值指向 `arcore` / `handheld` / `phone`。

Android ARCore gate 还必须看到 `capabilities.native_plugin:true`，以及 `capabilities.runtime:"ARCore"` 或 `capabilities.arcore_supported:true`。

如果看到 `EditorSim`，只能说明应用启动，不算该设备的 AR gate 通过。

## 检测计划

| 用例 | 平台 | 步骤 | 通过标准 |
| --- | --- | --- | --- |
| Editor 启动 | Editor | 运行 scene | 显示 EditorSim backend |
| Rokid APK 启动 | Rokid | 安装并打开 APK | 能看到 3D 内容和 backend 状态 |
| OpenXR availability | Rokid | 查看日志 | 能看到 OpenXR interface 是否可用 |
| iPad Xcode 启动 | iPad | Xcode 部署 | 能看到状态面板 |
| ARKit availability | iPad | 查看日志 | 输出 ARKit available/unavailable |
| ARKit tracking state | iPad | 查看日志和状态面板 | 输出 `arkit_tracking_state` / `arkit_tracking_reason` |
| ARKit native raycast/planes | iPad | 查看静态检查与运行日志 | `GodotARKit` 绑定 `hit_test` / `get_planes`，native session 使用 `ARRaycastQuery` / `ARPlaneAnchor` |
| iOS Simulator 启动 | iOS Simulator | 构建 simulator `.app` 并运行 `ios-simulator` gate | 输出 `backend:"EditorSim"`，只作为开发期证据 |
| Android APK 启动 | Android | 安装并打开 APK | 能看到状态面板 |
| ARCore availability | Android | 查看日志 | 输出 ARCore available/unavailable |

## 发表要求

- 标题：Godot XR Foundation C00：Rokid、Android、iOS 首次点亮。
- 产物：Rokid APK、Android APK、iOS Xcode project 或运行截图。
- 素材：每个平台 1 张截图或 15 秒录屏。
- Rokid/Android 发布素材必须同时包含截图和 15 秒录屏；iPad 发布素材至少包含截图或录屏。
- 文档：`releases/phase_0_smoke/TEST_REPORT.md`。
- 总报告：`releases/phase_0_smoke/C00_PHASE_REPORT.md` 必须显示 `PASS`。

## 验收标准

- [ ] 三类设备至少有启动记录。
- [ ] Rokid/OpenXR、iPad/ARKit 和 Android/ARCore 都有启动记录。
- [ ] 日志包含 backend、provider、tracking、capabilities。
- [ ] 日志包含 Unity 语义的 AR session state 和 not tracking reason。
- [ ] 日志包含 runtime metadata，能看出 Godot 版本、XR 启动参数、rendering/OpenXR 设置和 viewport XR 状态。
- [ ] 设备接入路径属于 Godot addon / Android plugin / iOS plugin / GDExtension / OpenXR vendor plugin；如不是，必须提交最小侵入说明。
- [ ] 每个平台至少一张截图或一段录屏。
- [ ] Rokid/Android 设备报告包含自动采集的 device profile，用于确认设备型号、系统版本、target package、XR 相关包和关键 feature。
- [ ] Rokid/Android 设备报告包含 device profile analysis，用于提前暴露 ADB、目标包安装、OpenXR/Rokid runtime 包、camera/Vulkan/XR feature 和设备型号风险。
- [ ] iPad 设备报告包含自动采集的 devicectl device profile，用于确认设备详情、display、lock state 和目标 bundle 状态。
- [ ] Rokid/Android 设备报告通过 `validate_evidence_bundle.js`，截图和录屏都存在。
- [ ] iPad 设备报告通过 `validate_evidence_bundle.js`，至少存在截图或录屏。
- [ ] Godot project/scene 静态完整性通过 `node tools/c00/check_godot_project_static.js`。
- [ ] C00 一键静态 gate 通过 `node tools/c00/run_static_gates.js --gate all`。
- [ ] iPad/ARKit plugin 配置通过 `tools/c00/check_ios_plugin_artifacts.js --require-binary`。
- [ ] iPad/ARKit runtime bridge 静态证据包含 `start_session` / `stop_session` / `get_tracking_status` / `hit_test` / `get_planes` 绑定、`ARWorldTrackingConfiguration` 启动、`ARSessionDelegate` tracking state/reason 上报，以及 `ARRaycastQuery` / `ARPlaneAnchor` native evidence。
- [ ] ARFoundation 迁移 API surface 通过 `node tools/c00/check_arfoundation_api_surface.js`。
- [ ] XRI 迁移 API surface 通过 `node tools/c00/check_xri_api_surface.js`。
- [ ] OpenXR/Rokid provider surface 通过 `node tools/c00/check_openxr_provider_surface.js`。
- [ ] Android ARCore gate surface 通过 `node tools/c00/check_arcore_gate_surface.js`。
- [ ] `tools/c00/verify_phase_evidence.js` 聚合验证通过，Rokid/OpenXR、iPad/ARKit 和 Android/ARCore 三个 gate 都是 `PASS`，并且三个 gate 都包含 device profile Markdown 与 JSON。
- [ ] 失败平台有明确错误和下一步。
