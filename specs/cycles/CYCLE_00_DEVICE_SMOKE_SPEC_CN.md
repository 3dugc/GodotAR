# C00 Device Smoke Test Spec

状态：Frozen

周期：C00

版本：v0.0.1-c00-device-smoke

建议周期：3-5 天

Unity 对齐基线：以 Unity 官方可见的最新 AR Foundation / XR Core Utilities / XR Interaction Toolkit / OpenXR 文档和 alpha/beta release notes 为目标；截至 2026-06-10，Unity package registry `dist-tags.latest` 前向基线为 `com.unity.xr.arfoundation@6.6.0-pre.2`、`com.unity.xr.arcore@6.6.0-pre.2`、`com.unity.xr.arkit@6.6.0-pre.2`、`com.unity.xr.interaction.toolkit@3.5.1`、`com.unity.xr.openxr@1.17.1`。稳定 fallback 观察线为 `com.unity.xr.arfoundation@6.5.0`、`com.unity.xr.core-utils@2.6.0`、`com.unity.xr.arcore@6.5.0`、`com.unity.xr.arkit@6.5.0`；Unity 6000.6 alpha release notes 仍作为未来 API shape 信号。如果预发布、preview 或 unreleased 官方文档暴露更新设计，优先作为接口规划参考，但 C00 完成仍以 Rokid/iPad/Android 真机 evidence 为准。Unity 6.5/6.6 package manuals 是当前公开 package 参考；Unity 6.4 package API pages 只在新版对应 API 页面尚不可见时作为细节 fallback。如果后续出现更高的 released / pre-release / preview / unreleased 官方文档，后续周期必须前移基线，并把旧 API 作为兼容层而不是主设计。

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
- `GXF_SMOKE` 日志必须包含 `camera` metadata：ARCameraManager 是否存在、camera permission/background/passthrough 状态、light estimation 请求/当前值、frameReceived 计数、intrinsics availability，以及 `native_intrinsics_available` / `native_frame_available`。
- `GXF_SMOKE` 日志必须包含 `trackables` metadata：plane/anchor 数量、前几个 trackable id，以及通过 `ARRaycastManager` 从屏幕中心发起的 raycast 结果。
- 明确插件优先边界：C00 不修改 Godot 主干，只通过 addon/provider/native plugin/OpenXR runtime 接入。
- Rokid 构建一个 APK，尝试 OpenXR 初始化。
- Rokid/OpenXR 设备机必须安装 Godot OpenXR Vendors plugin 到 `addons/godotopenxrvendors`，Android export preset 必须启用 Gradle build、OpenXR XR Mode、arm64 和目标 vendor。
- 新增 `tools/c00/install_openxr_vendors.sh`，用于从官方 release zip、本地 zip、tag 或 URL 安装 OpenXR Vendors plugin 到 `addons/godotopenxrvendors`。
- Rokid/OpenXR provider 启动时必须主动尝试 `start_passthrough` 或 vendor passthrough lifecycle，并把 `openxr_passthrough_started` / `openxr_passthrough_start_report` 写入 capability report。
- Rokid/OpenXR provider 在没有真实 OpenXR plane tracker 时应提供 virtual floor plane/raycast fallback，并通过 `openxr_virtual_plane_fallback` / `openxr_plane_source` 明确标记来源，确保 C00 只证明上层 ARFoundation manager/raycast 链路，不把 fallback 当成真实空间理解。
- iPad 导出 Xcode project，尝试 ARKit provider availability。
- 新增 iPad signing helper：真机安装前必须能用 `tools/c00/configure_ios_signing.js` 把 C00/C04 iPad preset 的 starter Team ID 替换成本机 Apple Developer Team ID；helper 不写证书、密码或 provisioning profile。
- `tools/c00/run_device_cycle.sh ipad` / `ipad-place` 必须在导出前支持 `CONFIGURE_IPAD_SIGNING=auto|1|0`：默认 `auto` 会在 `IPAD_TEAM_ID` / `TEAM_ID` / `DEVELOPMENT_TEAM` / `APPLE_TEAM_ID` 存在时自动调用 `configure_ios_signing.js`，`CONFIGURE_IPAD_SIGNING=1` 缺 Team ID 必须失败并给出恢复步骤。
- 新增 `ios/plugins/godot_arkit` 插件骨架，让 iPad gate 有明确 native singleton 落点。
- 新增 `tools/c00/prepare_godot_source.sh`，用于在设备机准备与 Godot iOS export template 匹配的官方 Godot source headers，作为 `GodotARKit.xcframework` 构建前置步骤。
- `tools/c00/run_device_cycle.sh ipad` 应自动识别 `.godot/cache/c00/godot-source`；设置 `GODOT_TAG=<godot-tag>` 时，应能在构建 ARKit 插件前自动准备 source headers。
- `GodotARKit` 必须通过 ARKit `ARSessionDelegate` 上报真实 tracking state/reason，而不是用 `is_running()` 代替 normal tracking。
- `GodotARKit` 应提供 C00 级 native camera frame evidence：`try_get_intrinsics` 应来自 `ARFrame.camera.intrinsics` / `imageResolution`，`get_camera_frame` 应包含 timestamp、tracking state/reason、intrinsics 和 light estimate availability，供上层 `ARCameraManager.TryGetIntrinsics` / `frameReceived` 使用。
- `GodotARKit` 应提供 C00 级 native `hit_test` 和 `get_planes`，把 ARKit `ARRaycastQuery` / `ARPlaneAnchor` 转成上层 `ARRaycastManager` / `ARPlaneManager` 可消费的字典证据，并保留 native transform/pose 供 `XRHit.get_pose()` 和 placement 迁移代码使用。
- 新增 `android/plugins/godot_arcore` 和 `addons/godot_arcore`，提供 C00 级 Godot Android plugin v2 / AAR export hook / `GodotARCore` singleton 落点。
- Android 构建一个 APK，确认 ARCore plugin availability、install request 和 session lifecycle 可用性。
- iOS/iPhone 可作为扩展验证，不替代 iPad gate。
- 归档截图、录屏、日志。
- Android/Rokid 采集脚本自动尝试生成截图和 15 秒录屏；iOS 采集脚本在有 `idevicescreenshot` 时自动截图。
- Android/Rokid 采集脚本必须归档设备画像：设备型号、系统版本、display、target package、XR/OpenXR/ARCore/Rokid 相关包和关键 feature。
- Android/Rokid 采集脚本必须分析 device profile，报告 ADB、目标包安装、XR/OpenXR runtime 包、camera/Vulkan/XR feature 和 Rokid 硬件匹配状态。
- iPad 采集脚本必须先安装 `.app` 再归档 `devicectl --json-output` 设备画像：device details、display、lock state、目标 bundle 安装状态和原始 JSON。
- iPad 采集脚本必须分析 device profile，报告选中设备、目标 bundle 安装状态、display 和 lock state；锁屏或目标 bundle 未安装不能作为 iPad/ARKit gate 通过。
- 新增 `tools/c00` 预检、导出、日志采集和 gate 验证脚本。
- 新增 `tools/c00/bootstrap_device_machine.sh`，在设备机生成 C00 readiness report，并可选生成 export preset starter。
- 新增 `tools/c00/import_device_dependency_bundle.sh`，用于在 Godot downloads / GitHub / Android SDK repository 下载不稳定时，从离线依赖包导入 Godot export templates、Android SDK、JDK、Godot binary 和 Godot source headers，并生成 `.godot/cache/c00/device-env.sh` 供 Rokid/iPad/Android ARCore gate 复用。
- `tools/c00/preflight.sh`、`tools/c00/bootstrap_device_machine.sh` 和 `tools/c00/run_device_cycle.sh` 独立运行时也应自动读取 `.godot/cache/c00/device-env.sh`；可用 `C00_DEVICE_ENV_FILE` 指定路径，或用 `C00_AUTO_SOURCE_DEVICE_ENV=0` 关闭。
- `tools/c00/install_godot_export_templates.sh` 应支持 `--download`、`--latest` 和 `--latest-stable`，把官方 Godot export templates 安装到标准模板目录，并验证 `ios.zip` 与 `android_source.zip`。C00 默认跟随最新官方 Godot 线；截至 2026-06-10 为 `4.7-rc1` / `4.7.rc1`，最新稳定 fallback 为 `4.6.3-stable` / `4.6.3.stable`。Godot editor、export templates 和 Godot source headers 必须同版本。
- 新增 `tools/c00/install_openjdk17.sh`，用于下载或导入 OpenJDK 17 到项目本地 `.godot/cache/c00/jdk/Contents/Home`，供 Godot Android export、debug keystore 和 `sdkmanager` 复用。
- `tools/c00/install_android_sdk_packages.sh` 应支持 `--download-cmdline-tools` / `--cmdline-tools-zip`，在设备机没有 `sdkmanager` 时安装 Android command line tools，再安装 `platform-tools`、`platforms;android-34` 和 `build-tools;34.0.0`。
- 设备机在线依赖安装命令应至少覆盖：`tools/c00/install_godot_editor.sh --download`、`tools/c00/install_godot_export_templates.sh --download`、`tools/c00/install_openjdk17.sh --download` 和 `tools/c00/install_android_sdk_packages.sh --download-cmdline-tools --yes`。
- 新增 Godot project/scene 静态完整性检查，确认 C00 主场景、rig、脚本资源、autoload、OpenXR 设置和关键 NodePath 在没有 Godot binary 时也能先检查。
- 新增 launch platform evidence gate，确认运行时会同时解析 Godot 普通 command-line args 和 user args，并要求 Rokid/iPad/Android ARCore 设备日志能证明本次启动选择了目标 XR platform。
- Android/Rokid 采集脚本必须在安装前检查 APK `assets/_cl_` 中的 Godot export `command_line/extra_args`，确认 Rokid 包含 `--xr-platform=rokid`、Android ARCore 包含 `--xr-platform=arcore`；采集前必须 force-stop app，避免复用旧进程。
- 新增 C00 一键静态 gate，汇总 Node/Bash 语法、Godot project/scene、ARFoundation、XRI、OpenXR/Rokid、Android ARCore 和 iOS plugin 静态检查，并生成 Markdown/JSON 报告。
- 新增 EditorSim/模拟器 gate，用于无设备时验证 ARFoundation-style 上层 API、raycast、anchor、plane 和 smoke log。
- 新增 ARFoundation API surface 静态 gate，确保 `ARSession.state/notTrackingReason/requestedTrackingMode/matchFrameRate`、screen/ray raycast、Unity `TrackableType` mask、trackables、changed events、`ARAnchorManager.AttachAnchor/GetAnchor/GetDescriptor` 和 async anchor 探测入口稳定。
- ARFoundation API surface 静态 gate 必须覆盖 Unity 6.x `XROrigin` 作为主入口，以及 deprecated `ARSessionOrigin` 兼容入口：`Camera`、`Origin`、`TrackablesParent`、`CameraFloorOffsetObject`、`CameraYOffset`、`TrackablesParentTransformChanged`、`MoveCameraToWorldLocation`、`RotateAroundCameraUsingOriginUp`、`RotateAroundCameraPosition`、`MatchOriginUp*`、`MakeContentAppearAt`、`TransformPose` 和 `InverseTransformPose`。
- 新增 XRI-style interaction smoke surface：`XRInteractionManager` 统一注册/调度 `XRRayInteractor` 与 `XRGrabInteractable`，C00 demo 输出 XRI hover/select 状态，并保留 `TryGetCurrent3DRaycastHit` / `TryGetCurrentRaycast` 的 out-parameter style 迁移入口。
- 模拟器 gate 可以在每个周期作为可运行成果：EditorSim 验证统一上层 API；iOS Simulator 验证 iOS 导出、`.xcframework` simulator slice 和 app 启动链路；Android Emulator 验证 Android 导出和日志链路。
- 新增 `tools/c00/collect_ios_simulator_smoke.sh`、`tools/c00/run_device_cycle.sh ios-simulator` 和 `tools/c00/run_device_cycle.sh ios-simulator-place`，作为 iPad 真机前的 iOS 导出/启动辅助 gate；`ios-simulator-place` 必须路由到 `C04 iPad ARKit Place` 并验证 `GXF_ARKIT_PLACE` 的 EditorSim placement 证据。
- iOS Simulator 构建脚本在 `IOS_SIMULATOR_ARCHS=auto` 时必须从 Godot simulator template 检测 slice，并优先选择当前主机可安装的 simulator 架构；Apple Silicon 默认应产出 `arm64` app，同时保留 `IOS_SIMULATOR_ARCHS` 手动覆盖。
- 新增 `tools/c00/write_export_presets_template.js`，用于在设备机生成 C00 export preset starter，再由 Godot editor 复核保存。
- 新增 `tools/c00/build_ios_xcode_project.sh`，用于把 Godot iOS 导出的 Xcode project zip 构建成稳定路径的 `.app`，再交给 iPad gate 安装/启动。
- 新增 `tools/c00/check_ios_export_project.js`，用于在 `xcodebuild` 前确认 Godot iOS 导出的 Xcode project 已包含 `GodotARKit.xcframework`、ARKit/Metal framework 和相机 plist。
- 新增 `tools/c00/verify_phase_evidence.js`，用于聚合验证 Rokid/OpenXR、iPad/ARKit 和 Android/ARCore 三条必过 gate，并生成 C00 总报告。
- 新增 `tools/c00/audit_phase1_completion.js`，用于按第一阶段真实完成条件审计静态 gate、Unity 迁移 API surface、ARKit plugin binary、Rokid/iPad/Android preflight、C02/C04 placement preflight 和真机证据；只要缺 iPad/ARKit 或 Rokid/OpenXR 真实运行证据就必须输出 `NOT_READY`。
- 新增 `tools/c00/run_phase1_device_lab.sh`，作为设备机第一阶段一键执行入口，按顺序编排离线依赖导入、readiness report、静态 gate、`run_device_cycle.sh all` 和 completion audit，并默认纳入 `rokid-place` / `ipad-place`，支持 `--dry-run` 演练。
- `tools/c00/run_phase1_device_lab.sh --online-deps` 应能在设备机上按 spec 顺序续传/安装 Godot export templates、OpenJDK 17、Android SDK packages，配置 Android debug keystore / build template，并写回 `.godot/cache/c00/device-env.sh`，让在线和离线设备机都能用同一个入口推进到 preflight。慢网络下应支持 `ONLINE_DEPS=templates,jdk,android-sdk,android-export` 分段执行，以及 `--online-deps-only` 只推进依赖缓存。
- `tools/c00/run_phase1_device_lab.sh --wait-devices` 应在 device cycle 前调用 readiness wait，等待 Rokid/iPad/Android 真机达到 ready；`--gate all` 默认 `SPLIT_ALL_DEVICE_CYCLE=1`，必须按 iPad、Rokid、Android ARCore 分组独立等待/恢复/运行，避免单台设备缺席挡住其它已 ready 设备产出证据；若超时且 `AUTO_RECOVER_DEVICES=1`，应先执行 Rokid/Android ADB recovery 和/或 iPad DDI recovery，再二次等待 readiness；仍超时才保留 readiness / recovery evidence、跳过对应安装/启动 cycle，并继续 completion audit，避免把离线设备误报成应用运行失败。
- 新增 `tools/c00/import_device_evidence.sh`，用于导入 Xcode/Console.app/Android Studio/手动录屏导出的设备证据并运行同一套 gate。
- 新增 `tools/c00/create_device_handoff_package.sh`，用于每个周期生成设备机 handoff 包：当前 APK/iPad Xcode export、runbook、spec、Unity 迁移说明、latest readiness evidence、manifest 和下一步执行命令。handoff 包只能作为阶段可运行成果，不能替代 Rokid/OpenXR、iPad/ARKit、Android/ARCore 真机证据。
- `tools/c00/run_device_cycle.sh all` 必须继续跑完 iPad/iPad placement/Rokid/Rokid placement/Android ARCore gate 并自动执行 C00 聚合验证，避免单台失败遮住另一台设备状态。
- `tools/c00/run_device_cycle.sh` 应支持 `DRY_RUN=1`，用于设备机首次接入前打印 source 准备、构建、导出、采集和聚合验证编排，不调用真实设备或构建命令。
- 真机采集脚本必须在 smoke validation 失败时继续执行媒体证据验证、device profile 追加和 profile analysis 追加，然后用最终非零状态退出，确保失败平台也有完整诊断报告。
- readiness 和 device profile analysis 报告必须包含 `next_actions` / `Next Actions`，用于把 ADB 无设备、Android/Rokid 未授权、iPad `offline` / `unavailable`、iPad `ddiServicesAvailable=false`、目标 app 未安装、OpenXR/ARCore runtime 包缺失等状态转成现场恢复步骤。
- iPad readiness / device profile 必须包含 host Xcode 版本、build、`iphoneos` / `iphonesimulator` SDK 版本和只读 `DDI services` probe；当 `ddiServicesAvailable=false` 时，Next Actions 必须带上 iPadOS 与 host Xcode/SDK 组合，并给出 `xcrun devicectl device info ddiServices --device <device> --auto-mount-ddis` 恢复命令，避免现场只得到泛化的“更新设备支持包”提示。
- 新增 iPad DDI recovery 工具：必须能在设备机保存 auto-mount 前后 readiness、`devicectl device info ddiServices --auto-mount-ddis` JSON/log、summary 和后续动作；只有恢复后 iPad readiness 通过时，`--run-gate` 才能继续执行 iPad gate。
- Rokid/Android readiness / device profile 必须包含 ADB 版本、Android SDK/JAVA_HOME 环境、PATH 中是否有 `adb`，并在 macOS 上尝试记录 USB 中疑似 Android/XR 的设备；当 USB 可见但 ADB 无 transport 时，Next Actions 必须指向 USB debugging、RSA 授权和 USB 模式。
- 新增 Rokid/Android ADB recovery 工具：必须能在设备机保存 `adb kill-server` / `adb start-server` 前后 readiness、`adb devices -l` stdout/stderr、summary 和后续动作；只有恢复后 readiness 通过时，`--run-gate` 才能继续执行 `rokid` / `rokid-place` / `android-arcore` gate。
- iPad/ARKit gate 前应能运行 ARKit native plugin Objective-C++ 语法 smoke check；真实通过仍以 `GodotARKit.xcframework` 构建和 iPad 真机证据为准。
- iPad/ARKit gate 前应能运行 Godot source 准备链路检查；设备机没有现成 Godot source tree 时，使用 `tools/c00/prepare_godot_source.sh --tag <godot-tag>` 生成 `GODOT_SOURCE_DIR`。
- iPad/ARKit runner 应能在没有显式 `GODOT_SOURCE_DIR` 时复用默认 `.godot/cache/c00/godot-source`，并在 `GODOT_TAG` 存在时自动准备该目录。
- iPad/ARKit gate 前应校验 `GodotARKit.gdip`/`.gdip.template` 符合 Godot iOS plugin 官方格式，且 init/deinit 符号、ARKit/Metal capability、framework 和 plist 配置一致。
- iPad/ARKit gate 前应校验 Godot 导出的 Xcode project 已引用 `GodotARKit.xcframework`、`ARKit.framework`、`Metal.framework`、`NSCameraUsageDescription` 和 `UIRequiredDeviceCapabilities`。
- Rokid/OpenXR gate 前应校验导出配置 surface：`gradle_build/use_gradle_build=true`、`xr_features/xr_mode=1`、`architectures/arm64-v8a=true`、`--xr-platform=rokid`，并在设备机 preflight/readiness 中检查 `addons/godotopenxrvendors`。
- Android ARCore gate 前应校验 `GodotARCore` Android plugin surface：Godot addon export hook、Android plugin v2 manifest、AAR build script、ARCore Maven dependency、singleton API、以及 Android export preset `plugins/GodotARCore=true`。

## 本周期不做

- 不实现跨平台完整真实平面检测；C00 只要求 iPad/ARKit bridge 暴露最小 native raycast/plane evidence，Rokid/OpenXR 与 Android ARCore 的完整 trackable 行为进入后续周期。Android ARCore C00 bridge 只承诺 availability / install / session lifecycle 和 capability evidence。
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
- `ARCameraManager.frameReceived(args)`
- `ARCameraManager.permissionGranted`
- `ARCameraManager.requestedLightEstimation`
- `ARCameraManager.currentLightEstimation`
- `ARCameraManager.TryGetIntrinsics(result_dictionary)`
- `ARCameraManager.TryAcquireLatestCpuImage(result_dictionary)`
- native singleton `GodotARKit.try_get_intrinsics()` / `get_camera_frame()` / `get_light_estimation()` -> `ARCameraManager` frame metadata
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
- `XROrigin.Camera`
- `XROrigin.Origin`
- `XROrigin.TrackablesParent`
- `XROrigin.GetCamera()`
- `XROrigin.GetOrigin()`
- `XROrigin.GetTrackablesParent()`
- `XROrigin.MoveCameraToWorldLocation(...)`
- `XROrigin.RotateAroundCameraUsingOriginUp(...)`
- `XROrigin.RotateAroundCameraPosition(...)`
- `XROrigin.MatchOriginUp(...)`
- `XROrigin.MatchOriginUpCameraForward(...)`
- `XROrigin.MatchOriginUpOriginForward(...)`
- `XROrigin.MakeContentAppearAt(...)`
- `XROrigin.TransformPose(...)`
- `XROrigin.InverseTransformPose(...)`
- `ARSessionOrigin.MakeContentAppearAt(...)`
- `XRFoundation.check_availability(...)`
- `XRFoundation.install(...)`
- `XRFoundation.reset_session(...)`
- `XRFoundation.get_capabilities()`
- `XRFoundation.get_provider_name()`
- `XRFoundation.get_tracking_state_name()`
- `NativeXRProvider` preserves native anchor dictionary ids and persistent ids from ARKit/ARCore singleton bridges.
- `tools/c00/bootstrap_device_machine.sh`
- `tools/c00/import_device_dependency_bundle.sh`
- `tools/c00/validate_smoke_log.js`
- `tools/c00/validate_evidence_bundle.js`
- `tools/c00/verify_phase_evidence.js`
- `tools/c00/audit_phase1_completion.js`
- `tools/c00/run_phase1_device_lab.sh`
- `tools/c00/check_export_presets.js`
- `tools/c00/install_godot_export_templates.sh`
- `tools/c00/install_openjdk17.sh`
- `tools/c00/install_android_sdk_packages.sh`
- `tools/c00/analyze_android_device_profile.js`
- `tools/c00/analyze_ios_device_profile.js`
- `tools/c00/check_device_collector_diagnostics_surface.js`
- `tools/c00/check_godot_project_static.js`
- `tools/c00/check_ios_device_profile_surface.js`
- `tools/c00/run_static_gates.js`
- `tools/c00/check_arfoundation_api_surface.js`
- `tools/c00/check_xri_api_surface.js`
- `tools/c00/check_openxr_provider_surface.js`
- `tools/c00/check_ios_plugin_artifacts.js`
- `tools/c00/check_ios_export_project.js`
- `tools/c00/write_export_presets_template.js`
- `tools/c00/install_openxr_vendors.sh`
- `tools/c00/prepare_godot_source.sh`
- `tools/c00/check_ios_godot_source_surface.js`
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
GXF_SMOKE|{"cycle":"C00","event":"session_started","platform_hint":"rokid","runtime":{"godot":...,"cmdline_xr_args":["--xr-platform=rokid"],"resolved_platform_hint":"rokid",...},"backend":"OpenXR","session_state":"Running","ar_session_state":"SessionTracking","not_tracking_reason":"None","capabilities":{"openxr_ar_evidence":["environment_blend:alpha_blend"]},"trackables":{"planes_count":1,"anchors_count":1,"center_screen_raycast":{"hit":true}},"xri":{"interaction_manager":true,"ray_interactor":true},...}
```

Rokid gate 必须看到 `backend:"OpenXR"`。

Rokid gate 必须看到启动平台证据：`platform_hint`、`runtime.resolved_platform_hint`、project setting 或 `runtime.cmdline_xr_args` 中至少一个值指向 `rokid` / `openxr` / `androidxr`。

Rokid gate 应记录 `capabilities.openxr_ar_tier` 和 `capabilities.openxr_fallback`；`D` 代表 VR-only，不能作为 AR 产品路径通过。

Rokid gate 必须记录 `capabilities.openxr_ar_evidence`，用于说明 AR 产品路径来自 `alpha_blend` / `additive` blend mode，还是来自 OpenXR Vendors/Rokid passthrough singleton 的能力方法。

Rokid gate 应记录 `capabilities.openxr_passthrough_started` 和 `capabilities.openxr_passthrough_start_report`，用于确认 provider 在 OpenXR session 启动后是否实际调用了 passthrough lifecycle。

Rokid gate 应记录 `capabilities.openxr_virtual_plane_fallback` 和 `capabilities.openxr_plane_source`；当真实 plane tracker 不可用时，`trackables.center_screen_raycast.hit=true` 可以来自 `virtual_floor_fallback`，该结果只作为 C00 上层 ARFoundation 链路 smoke，不等同于真实环境平面检测。

iPad gate 必须看到 `backend:"ARKit"`。

iPad gate 必须看到启动平台证据：`platform_hint`、`runtime.resolved_platform_hint`、project setting 或 `runtime.cmdline_xr_args` 中至少一个值指向 `ipad` / `iphone` / `ios` / `arkit`。

iPad gate 还必须看到 `capabilities.native_plugin:true`，以及 `capabilities.runtime:"ARKit"` 或 `capabilities.arkit_supported:true`。

iPad gate 应记录 `capabilities.arkit_tracking_state` 和 `capabilities.arkit_tracking_reason`；`normal` 算稳定跟踪，`limited` 或 `not_available` 必须在报告中保留原因。

所有真机 gate 都必须看到 `trackables` metadata；iPad/ARKit 设备上该字段用于确认 `GodotARKit.hit_test` / `get_planes` 是否已经被上层 manager 消费，Rokid/OpenXR 上用于确认统一 manager/raycast fallback 是否仍可运行。

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
| ARKit native raycast/planes | iPad | 查看静态检查与运行日志 | `GodotARKit` 绑定 `hit_test` / `get_planes`，native session 使用 `ARRaycastQuery` / `ARPlaneAnchor`，并输出 native transform pose |
| iOS Simulator 启动 | iOS Simulator | 构建 simulator `.app` 并运行 `ios-simulator` gate | 输出 `backend:"EditorSim"`，只作为开发期证据 |
| iOS Simulator C04 placement | iOS Simulator | 构建 C04 simulator `.app` 并运行 `ios-simulator-place` gate | 输出 `GXF_ARKIT_PLACE`、`event:"placed"`、`center_screen_raycast.hit=true` 和 EditorSim plane/anchor evidence；只作为开发期证据 |
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
- [ ] Android/Rokid APK 的 `assets/_cl_` 包含目标 `--xr-platform`，且采集脚本在启动前 force-stop app。
- [ ] 日志包含 `trackables` metadata，能看出 plane/anchor 数量和中心屏幕 raycast 结果。
- [ ] Rokid/OpenXR 日志能区分真实 plane tracker 与 `virtual_floor_fallback`，不会把 fallback plane 当作真实环境理解。
- [ ] 设备接入路径属于 Godot addon / Android plugin / iOS plugin / GDExtension / OpenXR vendor plugin；如不是，必须提交最小侵入说明。
- [ ] 每个平台至少一张截图或一段录屏。
- [ ] Rokid/Android 设备报告包含自动采集的 device profile，用于确认设备型号、系统版本、target package、XR 相关包和关键 feature。
- [ ] Rokid/Android 设备报告包含 device profile analysis，用于提前暴露 ADB、目标包安装、OpenXR/Rokid runtime 包、camera/Vulkan/XR feature 和设备型号风险。
- [ ] iPad 设备报告包含自动采集的 devicectl device profile，用于确认设备详情、display、lock state 和目标 bundle 状态。
- [ ] iPad 设备报告包含 device profile analysis，用于确认选中设备、目标 bundle 安装状态和锁屏风险。
- [ ] Rokid/Android 设备报告通过 `validate_evidence_bundle.js`，截图和录屏都存在。
- [ ] iPad 设备报告通过 `validate_evidence_bundle.js`，至少存在截图或录屏。
- [ ] Godot project/scene 静态完整性通过 `node tools/c00/check_godot_project_static.js`。
- [ ] C00 一键静态 gate 通过 `node tools/c00/run_static_gates.js --gate all`。
- [ ] iPad/ARKit Godot source 准备链路通过 `node tools/c00/check_ios_godot_source_surface.js`；如果设备机缺 source tree，先运行 `tools/c00/prepare_godot_source.sh --tag <godot-tag>`。
- [ ] iPad/ARKit runner 能在没有显式 `GODOT_SOURCE_DIR` 时复用默认 `.godot/cache/c00/godot-source`，并在 `GODOT_TAG` 存在时自动准备该目录。
- [ ] C00 runner dry-run 通过 `DRY_RUN=1 tools/c00/run_device_cycle.sh <gate>` 输出将执行命令，且不调用真实 Godot/Xcode/ADB/devicectl。
- [ ] iPad/ARKit plugin 配置通过 `tools/c00/check_ios_plugin_artifacts.js --require-binary`。
- [ ] iPad/ARKit runtime bridge 静态证据包含 `start_session` / `stop_session` / `get_tracking_status` / `hit_test` / `get_planes` 绑定、`ARWorldTrackingConfiguration` 启动、`ARSessionDelegate` tracking state/reason 上报，以及 `ARRaycastQuery` / `ARPlaneAnchor` native transform evidence。
- [ ] ARFoundation 迁移 API surface 通过 `node tools/c00/check_arfoundation_api_surface.js`。
- [ ] C00 smoke scene 挂载 addon-only `XROrigin` shim，`GXF_SMOKE.origin` 包含 `Camera`、`Origin`、`TrackablesParent` 和 camera/origin-space metadata。
- [ ] XRI 迁移 API surface 通过 `node tools/c00/check_xri_api_surface.js`。
- [ ] Rokid/OpenXR export surface 通过 `node tools/c00/check_rokid_openxr_export_surface.js`。
- [ ] OpenXR/Rokid provider surface 通过 `node tools/c00/check_openxr_provider_surface.js`。
- [ ] Android ARCore plugin surface 通过 `node tools/c00/check_android_arcore_plugin_surface.js`。
- [ ] Android ARCore gate surface 通过 `node tools/c00/check_arcore_gate_surface.js`。
- [ ] `tools/c00/verify_phase_evidence.js` 聚合验证通过，Rokid/OpenXR、iPad/ARKit 和 Android/ARCore 三个 gate 都是 `PASS`，并且三个 gate 都包含 device profile Markdown 与 JSON。
- [ ] 失败平台有明确错误和下一步。
