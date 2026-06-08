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
- `GXF_SMOKE` 日志必须包含 runtime metadata：Godot 版本、XR 相关启动参数、rendering method、OpenXR/XR shader project setting、viewport XR 状态。
- 明确插件优先边界：C00 不修改 Godot 主干，只通过 addon/provider/native plugin/OpenXR runtime 接入。
- Rokid 构建一个 APK，尝试 OpenXR 初始化。
- iPad 导出 Xcode project，尝试 ARKit provider availability。
- 新增 `ios/plugins/godot_arkit` 插件骨架，让 iPad gate 有明确 native singleton 落点。
- `GodotARKit` 必须通过 ARKit `ARSessionDelegate` 上报真实 tracking state/reason，而不是用 `is_running()` 代替 normal tracking。
- Android 构建一个 APK，确认 ARCore plugin 或 fallback provider 可用性。
- iOS/iPhone 可作为扩展验证，不替代 iPad gate。
- 归档截图、录屏、日志。
- Android/Rokid 采集脚本自动尝试生成截图和 15 秒录屏；iOS 采集脚本在有 `idevicescreenshot` 时自动截图。
- Android/Rokid 采集脚本必须归档设备画像：设备型号、系统版本、display、target package、XR/OpenXR/ARCore/Rokid 相关包和关键 feature。
- iPad 采集脚本必须归档 `devicectl --json-output` 设备画像：device details、display、lock state、目标 bundle 安装状态和原始 JSON。
- 新增 `tools/c00` 预检、导出、日志采集和 gate 验证脚本。
- 新增 `tools/c00/bootstrap_device_machine.sh`，在设备机生成 C00 readiness report，并可选生成 export preset starter。
- 新增 EditorSim/模拟器 gate，用于无设备时验证 ARFoundation-style 上层 API、raycast、anchor、plane 和 smoke log。
- 模拟器 gate 可以在每个周期作为可运行成果：EditorSim 验证统一上层 API；iOS Simulator 验证 iOS 导出、`.xcframework` simulator slice 和 app 启动链路；Android Emulator 验证 Android 导出和日志链路。
- 新增 `tools/c00/collect_ios_simulator_smoke.sh` 和 `tools/c00/run_device_cycle.sh ios-simulator`，作为 iPad 真机前的 iOS 导出/启动辅助 gate。
- 新增 `tools/c00/write_export_presets_template.js`，用于在设备机生成 C00 export preset starter，再由 Godot editor 复核保存。
- 新增 `tools/c00/build_ios_xcode_project.sh`，用于把 Godot iOS 导出的 Xcode project zip 构建成稳定路径的 `.app`，再交给 iPad gate 安装/启动。
- 新增 `tools/c00/verify_phase_evidence.js`，用于聚合验证 Rokid/OpenXR 和 iPad/ARKit 两条必过 gate，并生成 C00 总报告。
- 新增 `tools/c00/import_device_evidence.sh`，用于导入 Xcode/Console.app/Android Studio/手动录屏导出的设备证据并运行同一套 gate。
- `tools/c00/run_device_cycle.sh all` 必须继续跑完 iPad/Rokid gate 并自动执行 C00 聚合验证，避免单台失败遮住另一台设备状态。
- iPad/ARKit gate 前应能运行 ARKit native plugin Objective-C++ 语法 smoke check；真实通过仍以 `GodotARKit.xcframework` 构建和 iPad 真机证据为准。
- iPad/ARKit gate 前应校验 `GodotARKit.gdip`/`.gdip.template` 符合 Godot iOS plugin 官方格式，且 init/deinit 符号、ARKit/Metal capability、framework 和 plist 配置一致。

## 本周期不做

- 不实现真实平面检测。
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
- `ARRaycastManager.TryRaycast(...)`
- `ARRaycastManager.RaycastToList(...)`
- `ARRaycastManager.TryScreenRaycast(...)`
- `XRHit.get_pose()`
- `ARAnchorManager.TryAddAnchorAsync(...)`
- `ARAnchorManager.TryRemoveAnchor(...)`
- `XRFoundation.check_availability(...)`
- `XRFoundation.install(...)`
- `XRFoundation.reset_session(...)`
- `XRFoundation.get_capabilities()`
- `XRFoundation.get_provider_name()`
- `XRFoundation.get_tracking_state_name()`
- `tools/c00/bootstrap_device_machine.sh`
- `tools/c00/validate_smoke_log.js`
- `tools/c00/validate_evidence_bundle.js`
- `tools/c00/verify_phase_evidence.js`
- `tools/c00/check_export_presets.js`
- `tools/c00/check_ios_plugin_artifacts.js`
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
GXF_SMOKE|{"cycle":"C00","event":"session_started","runtime":{"godot":...,"cmdline_xr_args":["--xr-platform=rokid"],...},"backend":"OpenXR","session_state":"Running",...}
```

Rokid gate 必须看到 `backend:"OpenXR"`。

Rokid gate 应记录 `capabilities.openxr_ar_tier` 和 `capabilities.openxr_fallback`；`D` 代表 VR-only，不能作为 AR 产品路径通过。

iPad gate 必须看到 `backend:"ARKit"`。

iPad gate 还必须看到 `capabilities.native_plugin:true`，以及 `capabilities.runtime:"ARKit"` 或 `capabilities.arkit_supported:true`。

iPad gate 应记录 `capabilities.arkit_tracking_state` 和 `capabilities.arkit_tracking_reason`；`normal` 算稳定跟踪，`limited` 或 `not_available` 必须在报告中保留原因。

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
- [ ] Rokid/OpenXR 和 iPad/ARKit 都有启动记录。
- [ ] 日志包含 backend、provider、tracking、capabilities。
- [ ] 日志包含 runtime metadata，能看出 Godot 版本、XR 启动参数、rendering/OpenXR 设置和 viewport XR 状态。
- [ ] 设备接入路径属于 Godot addon / Android plugin / iOS plugin / GDExtension / OpenXR vendor plugin；如不是，必须提交最小侵入说明。
- [ ] 每个平台至少一张截图或一段录屏。
- [ ] Rokid/Android 设备报告包含自动采集的 device profile，用于确认设备型号、系统版本、target package、XR 相关包和关键 feature。
- [ ] iPad 设备报告包含自动采集的 devicectl device profile，用于确认设备详情、display、lock state 和目标 bundle 状态。
- [ ] Rokid/Android 设备报告通过 `validate_evidence_bundle.js`，截图和录屏都存在。
- [ ] iPad 设备报告通过 `validate_evidence_bundle.js`，至少存在截图或录屏。
- [ ] iPad/ARKit plugin 配置通过 `tools/c00/check_ios_plugin_artifacts.js --require-binary`。
- [ ] `tools/c00/verify_phase_evidence.js` 聚合验证通过，Rokid/OpenXR 和 iPad/ARKit 双 gate 都是 `PASS`，并且两个 gate 都包含 device profile Markdown 与 JSON。
- [ ] 失败平台有明确错误和下一步。
