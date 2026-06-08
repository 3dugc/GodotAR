# C00 Device Smoke Runbook

目标：让第一阶段每次都能在 Rokid/OpenXR、iPad/ARKit 和 Android/ARCore 上运行、检测、归档。

## 运行入口

Godot 主场景已经设置为：

```text
res://demo/00_device_smoke_test.tscn
```

也可以在编辑器中手动运行该场景。

## 工具链预检

第一次配置设备机时，先生成 readiness report：

```bash
tools/c00/bootstrap_device_machine.sh
```

如果还没有 `export_presets.cfg`，可以同时生成 starter：

```bash
tools/c00/bootstrap_device_machine.sh --write-export-presets --package org.example.godotar --bundle org.example.godotar --team-id ABCDE12345
```

生成后仍要在 Godot editor 里复核 Android OpenXR loader、iOS signing、`GodotARKit` plugin 选项，然后保存。

```bash
tools/c00/preflight.sh
```

设备机第一道静态 gate：

```bash
node tools/c00/run_static_gates.js --gate all --report releases/phase_0_smoke/evidence/static-gates.md
```

如果设备机还没有 Godot binary，也可以先跑不依赖 Godot 的项目/场景完整性检查：

```bash
node tools/c00/check_godot_project_static.js
```

如果本机 Godot 不在 PATH，可以设置：

```bash
GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot tools/c00/preflight.sh
```

导出 preset 说明：

```text
tools/c00/EXPORT_PRESETS_CN.md
```

如果还没有 `export_presets.cfg`，先生成 C00 starter，然后用 Godot editor 复核并保存：

```bash
node tools/c00/write_export_presets_template.js --output export_presets.cfg
```

确认 C00 preset 名称和平台：

```bash
node tools/c00/check_export_presets.js --gate all --file export_presets.cfg
```

## 一键执行

设备机上优先用 spec runner：

```bash
tools/c00/run_device_cycle.sh editor
```

```bash
tools/c00/run_device_cycle.sh rokid
```

```bash
tools/c00/run_device_cycle.sh android-arcore
```

```bash
GODOT_SOURCE_DIR=/path/to/godot \
DEVICE=<ipad-uuid-or-name> \
tools/c00/run_device_cycle.sh ipad
```

`all` 会按 iPad/ARKit、Rokid/OpenXR、Android/ARCore 顺序执行；如需临时跳过 Android ARCore，设置 `INCLUDE_ANDROID_ARCORE=0`。

```bash
GODOT_SOURCE_DIR=/path/to/godot \
DEVICE=<ipad-uuid-or-name> \
tools/c00/run_device_cycle.sh all
```

`all` 模式默认会继续执行后续 gate，即使前一个 gate 失败；最后会自动运行 `tools/c00/verify_phase_evidence.js` 并生成 `C00_PHASE_REPORT.md`。如果希望失败即停，设置 `CONTINUE_ON_FAILURE=0`。
如需在设备 gate 前先跑本地模拟器，设置 `INCLUDE_EDITOR_SIM=1`。
如需临时只聚合某几台设备，设置 `PHASE_GATES=rokid,ipad`；C00 发布默认要求 `rokid,ipad,android-arcore`。

## 插件优先边界

C00 不修改 Godot 主干。

设备接入路径必须记录为：

- Godot addon
- Android plugin
- iOS plugin
- GDExtension
- OpenXR vendor plugin
- engine patch

如果出现 `engine patch`，本周期必须附带最小侵入说明，否则不能标记为通过。

## EditorSim / 模拟器

模拟器用于没有设备时验证上层接口和 Unity 迁移代码：

```bash
tools/c00/run_device_cycle.sh editor
```

或：

```bash
tools/c00/collect_editor_smoke.sh 15
```

模拟器会通过 `--xr-platform=simulator` 选择 `EditorSim` backend，提供模拟 floor plane、raycast、anchor 和 tracking。它可以作为开发 gate，但不能替代 Rokid/OpenXR 或 iPad/ARKit 真机通过标准。
C00 demo 同时包含 XRI-style `XRInteractionManager`、camera `XRRayInteractor` 和 `XRGrabInteractable`；`GXF_SMOKE` 的 `xri` 字段用于记录交互层是否被加载、ray 是否命中、hover/select 计数。它证明 Unity XRI 迁移入口可运行，但不替代 ARKit/OpenXR 真机 tracking gate。

iOS Simulator 和 Android Emulator 也可以作为周期内的辅助成果：它们用于验证导出链路、app 启动、日志格式，以及 iOS `.xcframework` 是否包含 simulator slice。它们不能证明真实 ARKit/OpenXR AR tracking，因此不能让 C00 发布门禁通过。

iOS Simulator 辅助 gate：

```bash
tools/c00/run_device_cycle.sh ios-simulator
```

如果已经有 simulator `.app`：

```bash
APP_PATH=builds/ios_simulator/GodotXRFoundation.app \
tools/c00/collect_ios_simulator_smoke.sh booted org.godotengine.godotxrfoundation 30
```

该 gate 会通过 `--xr-platform=simulator` 选择 `EditorSim` backend，用来验证 iOS 导出、simulator app 启动、日志和截图链路。报告路径仍在 `releases/phase_0_smoke/evidence/ios-simulator-*.md`，但不会进入 C00 真机总验收。

如果 export preset 和启动命令都包含 `--xr-platform=...`，运行时以后出现的参数为准；这允许 simulator gate 复用 iPad preset，同时在启动时覆盖成 `--xr-platform=simulator`。

## Rokid / OpenXR

通过标准：

- 设备中能看到状态面板和旋转 cube。
- 面板显示 `Session: Running`。
- 面板显示 `Backend: OpenXR`。
- 日志包含 `GXF_SMOKE`，且 JSON 中 `backend` 为 `OpenXR`。
- 日志包含 `ar_session_state` 和 `not_tracking_reason`，用于对照 Unity ARFoundation 状态。
- 日志包含 `trackables`，能看到 `planes_count`、`anchors_count` 和 `center_screen_raycast`，用于确认统一 ARFoundation manager/raycast fallback 仍在工作。
- 日志能看到启动平台证据：`platform_hint`、`runtime.resolved_platform_hint`、project setting 或 `runtime.cmdline_xr_args` 中至少一个值指向 `rokid` / `openxr`；并能看到 Godot 版本、rendering method、OpenXR/XR shader 设置。
- `capabilities.ar_product_path` 为 `true` 时，才算 AR 产品路径通过。
- `capabilities.openxr_ar_evidence` 必须说明 AR 路径来自 environment blend mode 或 OpenXR Vendors/Rokid passthrough singleton 方法。
- `capabilities.openxr_passthrough_start_report` 应记录 `XRInterface.start_passthrough` 或 vendor singleton passthrough lifecycle 调用结果。

建议设置：

```gdscript
XRFoundation.start_session(XRFoundationTypes.Backend.OPENXR, {
	"platform_hint": "rokid",
	"prefer_ar": true,
	"passthrough": true,
})
```

可选启动参数：

```text
--xr-platform=rokid
```

Rokid Android export preset 必须设置：

```text
command_line/extra_args="--xr-platform=rokid"
```

这样无论通过 launcher、`monkey` 还是设备桌面启动，Godot 都会优先选择 OpenXR 路径，而不是在 Android 上先尝试 ARCore。
Godot Android 会从导出 APK 的 `assets/_cl_` 读取这些参数；外部传给 exported Activity 的 `command_line_params` 会被 Godot Activity 清理，不能作为 C00 gate 的可靠启动参数来源。因此采集脚本会在安装前检查 APK `assets/_cl_`，并在启动前 force-stop app，确保本次日志来自带正确启动参数的新进程。

自动采集和验证：

```bash
tools/c00/run_device_cycle.sh rokid
```

默认会同时采集日志、gate 报告、截图和 15 秒录屏；如设备不支持 `screenrecord`，请手动补录屏。
Rokid gate 默认要求截图和录屏都存在；临时调试可用 `ALLOW_MISSING_MEDIA=1` 降级为 warning，但不能作为发表通过结果。
脚本还会生成 `rokid-<timestamp>-device.md/json` 设备画像，记录型号、系统版本、display、target package、XR/OpenXR/ARCore/Rokid 相关包和关键 feature；并生成 `rokid-<timestamp>-device-analysis.md`，提前标出 ADB、目标包安装、runtime 包、camera/Vulkan/XR feature 和 Rokid 硬件匹配风险。多台 Android 设备连接时设置 `ADB_SERIAL=<serial>`。

底层脚本：

```bash
APK_PATH=builds/rokid/c00.apk tools/c00/collect_android_smoke.sh rokid org.godotengine.godotxrfoundation 30
```

失败判定：

- `Backend: EditorSim`：Godot 应用启动了，但 OpenXR gate 未通过。
- `ar_product_path=false` 且 blend 只有 `opaque`：OpenXR 渲染启动了，但还不是 AR 结果。
- `openxr_ar_tier=D`：OpenXR runtime 是 VR-only，本周期不能作为 AR 成果发布。
- `openxr_ar_evidence` 缺失：使用的构建太旧，或 provider 没有读到 blend/vendor passthrough 能力；重新导出并检查 OpenXR Vendors/Rokid 插件。
- `openxr_passthrough_start_report` 为空：provider 没有找到可调用的 passthrough lifecycle；检查 Godot OpenXR 版本、OpenXR Vendors 插件和 Rokid runtime。
- OpenXR interface unavailable：检查 Godot OpenXR 设置、Android export XR mode、Rokid runtime、OpenXR Vendors 插件。

## Android / ARCore

通过标准：

- Android 手机/平板上能看到状态面板和旋转 cube。
- 面板显示 `Session: Running`。
- 面板显示 `Backend: ARCore`。
- 日志包含 `GXF_SMOKE`，且 JSON 中 `backend` 为 `ARCore`。
- 日志包含 `ar_session_state` 和 `not_tracking_reason`，用于对照 Unity ARFoundation 状态。
- 日志包含 `trackables`，能看到 `planes_count`、`anchors_count` 和 `center_screen_raycast`。
- 日志能看到启动平台证据：`platform_hint`、`runtime.resolved_platform_hint`、project setting 或 `runtime.cmdline_xr_args` 中至少一个值指向 `arcore` / `handheld` / `phone`。
- `capabilities.native_plugin=true`。
- `capabilities.runtime="ARCore"` 或 `capabilities.arcore_supported=true`。
- device profile JSON 检测到 ARCore package，例如 `com.google.ar.core`。

自动采集和验证：

```bash
tools/c00/run_device_cycle.sh android-arcore
```

Android ARCore export preset 应设置：

```text
command_line/extra_args="--xr-platform=arcore"
```

当 `APK_PATH` 指向本次导出的 APK 时，采集脚本会检查 APK `assets/_cl_` 是否包含该参数；如果没有，脚本会在安装前失败，避免把手机/平板误跑到 OpenXR 或 EditorSim 路径。

底层脚本：

```bash
APK_PATH=builds/android_arcore/c00.apk tools/c00/collect_android_smoke.sh android-arcore org.godotengine.godotxrfoundation 30
```

失败判定：

- `Backend: EditorSim`：Android app 启动了，但 ARCore native path 没有被识别。
- `native_plugin=true` 但缺少 `capabilities.runtime="ARCore"` / `capabilities.arcore_supported=true`：日志证据太弱，不能证明是 ARCore runtime。
- device profile 里没有 `com.google.ar.core` 或 ARCore 包：设备缺 ARCore 服务或采集权限不足。
- `Backend: OpenXR`：这台 Android 设备跑到了 OpenXR 路径，不能替代手机/平板 ARCore gate。

## iPad / ARKit

通过标准：

- iPad 上能看到状态面板和旋转 cube。
- 面板显示 `Session: Running`。
- 面板显示 `Backend: ARKit`。
- 日志包含 `GXF_SMOKE`，且 JSON 中 `backend` 为 `ARKit`。
- 日志包含 `ar_session_state` 和 `not_tracking_reason`，用于对照 Unity ARFoundation 状态。
- 日志包含 `trackables`，能看到 `planes_count`、`anchors_count` 和 `center_screen_raycast`；当环境中已检测到平面时，该字段应能证明 `GodotARKit.hit_test` / `get_planes` 已被上层 manager 消费。
- `not_tracking_reason` 会优先使用 ARKit singleton 的 `arkit_tracking_reason` 映射结果，便于直接对照 Unity `ARSession.notTrackingReason`。
- 日志能看到启动平台证据：`platform_hint`、`runtime.resolved_platform_hint`、project setting 或 `runtime.cmdline_xr_args` 中至少一个值指向 `ipad` / `ios` / `arkit`；并能确认 Godot 版本和 viewport XR 状态。
- `capabilities.native_plugin=true`。
- `capabilities.runtime="ARKit"` 或 `capabilities.arkit_supported=true`。
- `capabilities.arkit_tracking_state` 和 `capabilities.arkit_tracking_reason` 能说明 ARKit 当前是 `normal`、`limited` 还是 `not_available`。
- `node tools/c00/check_ios_plugin_artifacts.js` 应确认 `hit_test` / `get_planes` 已绑定，并且 native session 使用 `ARRaycastQuery` / `ARPlaneAnchor`，用于证明 iPad bridge 已接到 C00 级 ARFoundation raycast/plane 入口。

失败判定：

- `Backend: EditorSim`：iOS app 启动了，但 ARKit native plugin 没有被 Godot 识别。
- `singleton_registered=false` 且 `interface_registered=false`：检查 `.gdip`、`.xcframework`、Xcode linking、iOS plugin singleton 名称。
- `native_plugin=true` 但 `session_state` 不能进入 `Running`：先跑 `node tools/c00/check_ios_plugin_artifacts.js`，确认 `GodotARKit` singleton 绑定了 `start_session` / `stop_session` / `get_tracking_status`，并确认 `GodotARKitSession` 真实调用 ARKit `runWithConfiguration`。
- `arkit_tracking_state=limited`：ARKit 已启动但尚未稳定跟踪，保留 `arkit_tracking_reason`；同时检查统一日志里的 `not_tracking_reason` 是否映射为光照、纹理、设备运动或重定位等原因。
- `export_presets.cfg` 中看不到 `GodotARKit`：iOS preset 没有启用 ARKit plugin，不能算 iPad/ARKit gate。

自动采集和验证：

```bash
GODOT_SOURCE_DIR=/path/to/godot DEVICE=<device> tools/c00/run_device_cycle.sh ipad
```

默认流程会先构建 `GodotARKit.xcframework`，再用 Godot 导出 `builds/ipad/c00.zip`，随后通过 `tools/c00/build_ios_xcode_project.sh` 自动发现导出的 `.xcodeproj` 和 scheme，用 `xcodebuild` 产出 `builds/ipad/GodotXRFoundation.app`。如果已经手工构建了 `.app`，可设置 `APP_PATH=builds/ipad/GodotXRFoundation.app` 跳过自动 Xcode 构建。
`build_ios_xcode_project.sh` 会在 `xcodebuild` 前自动运行 `node tools/c00/check_ios_export_project.js --input <unpacked-ios-export>`，确认 Xcode project 已引用 `GodotARKit.xcframework`、`ARKit.framework`、`Metal.framework`，并且 plist 包含相机权限和 `arkit`/`metal` required device capabilities。

底层脚本：

```bash
APP_PATH=builds/ipad/GodotXRFoundation.app tools/c00/collect_ios_smoke.sh <device> org.godotengine.godotxrfoundation 30
```

`collect_ios_smoke.sh` 默认传入 `--xr-platform=ipad`；如需改成 iPhone 验证，可设置 `IOS_XR_PLATFORM=iphone`。
当 `APP_PATH` 指向本次 `.app` 时，脚本会先安装 app，再采集 `ipad-<timestamp>-device.md/json`，确保目标 bundle 安装状态反映本次构建。随后会生成 `ipad-<timestamp>-device-analysis.md`，分析选中设备、目标 bundle 安装状态、display 和 lock state；目标 bundle 缺失或设备锁屏不能作为 iPad/ARKit gate 通过。
如果本机安装了 `idevicescreenshot`，脚本会自动截图；否则请手动补一张截图或 15 秒录屏。
手动素材可以通过 `MANUAL_MEDIA_PATH=/path/to/ipad.mov` 传给采集脚本；没有任何媒体素材时，iPad gate 默认失败。

如果日志或媒体是从 Xcode、Console.app、Android Studio 或手动录屏导出的，用统一导入脚本归档：

```bash
tools/c00/import_device_evidence.sh --gate ipad --log path/to/ipad.log --manual-media path/to/ipad.mov
```

```bash
tools/c00/import_device_evidence.sh --gate rokid --log path/to/rokid.log --screenshot path/to/rokid.png --video path/to/rokid.mp4
```

如果手工导入的素材已经包含 device profile，也一起传入：

```bash
tools/c00/import_device_evidence.sh --gate ipad --log path/to/ipad.log --manual-media path/to/ipad.mov --device-profile path/to/ipad-device.md --device-profile-json path/to/ipad-device.json
```

```bash
tools/c00/import_device_evidence.sh --gate rokid --log path/to/rokid.log --screenshot path/to/rokid.png --video path/to/rokid.mp4 --device-profile path/to/rokid-device.md --device-profile-json path/to/rokid-device.json
```

## 归档材料

每台设备至少保存：

- 一张截图或 15 秒录屏。
- 过滤 `GXF_SMOKE` 后的日志。
- 设备型号、系统版本、Godot 版本、插件版本。
- 使用的扩展路径：addon / Android plugin / iOS plugin / GDExtension / OpenXR vendor plugin / engine patch。
- 是否通过 gate。

脚本生成的 gate 报告在：

```text
releases/phase_0_smoke/evidence/
```

自动产物命名：

```text
<gate>-<timestamp>.log
<gate>-<timestamp>.md
<gate>-<timestamp>.png
<gate>-<timestamp>.mp4
<gate>-<timestamp>-device.md
<gate>-<timestamp>-device.json
```

`.md` 报告会包含两个门禁结果：

- smoke log gate：验证 `GXF_SMOKE`、backend、Unity-style session state、native plugin、ARKit/OpenXR 证据。
- evidence bundle gate：验证截图和录屏是否存在并非空文件。
- Android/Rokid device profile：记录设备属性、target package、XR 相关包和关键 feature。
- iPad device profile：记录 devicectl details、display、lock state、目标 bundle 安装状态和原始 JSON；profile analysis 会检查目标 bundle 是否安装、设备是否锁屏。

smoke log gate 还会展示 `Runtime Metadata`，用于确认 Godot 版本、启动参数和 XR/rendering project setting 是否符合设备 gate。

## C00 总验收

Rokid/OpenXR、iPad/ARKit 和 Android/ARCore 都跑完后，执行：

```bash
node tools/c00/verify_phase_evidence.js
```

该命令会扫描 `releases/phase_0_smoke/evidence/` 中最新的 Rokid/iPad/Android ARCore 日志和媒体证据，并生成：

```text
releases/phase_0_smoke/C00_PHASE_REPORT.md
```

只有这个总报告显示 `PASS`，C00 才能作为可发表结果。单台设备 gate 通过但其他必需设备缺证据时，C00 仍然不能标记完成。
总报告默认还要求 Rokid、iPad 和 Android ARCore 都有 `*-device.md` 与 `*-device.json` device profile；Rokid/Android JSON 会被分析 ADB、target package、XR/OpenXR/ARCore runtime 包、camera/Vulkan/XR feature 和设备匹配风险，iPad JSON 会被分析选中设备、目标 bundle 安装状态、display 和 lock state。临时调试可用 `--allow-missing-device-profile` 降级为 warning，但不能作为 C00 可发表结果。

## 参考原则

- Unity `ARSession` 的 `CheckAvailability` 和 `Install` 模型，用于统一生命周期判断。
- Unity `ARRaycastManager.Raycast` 的结果由调用方传入/接收列表，结果按距离优先；Godot 当前返回 `Array[XRHit]`，语义保持接近。
- Unity `XROrigin`/`ARSessionOrigin` 的核心职责是把 session space 映射到场景空间；Godot 使用 `XROrigin3D` 实现同一边界。
- Godot OpenXR AR/Passthrough 通过 environment blend mode 表达 AR/MR 背景能力；只有 opaque 不能算 AR 产品通过。
- Godot iOS 插件必须放在 `res://ios/plugins`，并通过 `.gdip` + `.xcframework` 暴露给 Godot，再用 `Engine.get_singleton()` 访问。

## 资料

- Unity ARSession: https://docs.unity.cn/Packages/com.unity.xr.arfoundation%406.1/api/UnityEngine.XR.ARFoundation.ARSession.html
- Unity ARRaycastManager: https://docs.unity.cn/Packages/com.unity.xr.arfoundation%406.0/api/UnityEngine.XR.ARFoundation.ARRaycastManager.html
- Unity XR Origin: https://docs.unity3d.com/cn/2023.2/Manual/xr-origin.html
- Godot AR/Passthrough: https://docs.godotengine.org/en/4.4/tutorials/xr/ar_passthrough.html
- Godot iOS plugins: https://docs.godotengine.org/en/4.4/tutorials/platform/ios/ios_plugin.html
