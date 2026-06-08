# C00 Device Tools

这些脚本用于把第一阶段从“能打开”推进到“能证明 Rokid/OpenXR、iPad/ARKit 是否真的通过 gate”。

## 预检

第一次配置设备机时，先生成 readiness report：

```bash
tools/c00/bootstrap_device_machine.sh
```

可选生成 C00 export preset starter：

```bash
tools/c00/bootstrap_device_machine.sh \
  --write-export-presets \
  --package org.example.godotar \
  --bundle org.example.godotar \
  --team-id ABCDE12345
```

该脚本只生成报告和可选 starter，不会安装 Godot、Android platform tools、证书、provisioning profile 或设备 runtime。

```bash
tools/c00/preflight.sh
```

也可以按 gate 检查：

```bash
tools/c00/preflight.sh rokid
tools/c00/preflight.sh ipad
tools/c00/preflight.sh android-arcore
```

检查：

- `node`：运行日志 validator。
- `godot`：命令行导出/导入校验。
- `adb`：Rokid/Android 日志采集。
- `xcrun`：iPad 安装和启动。
- `xcodebuild`：把 Godot iOS 导出的 Xcode project 构建成可安装 `.app`。
- `android/plugins`、`ios/plugins` 是否存在。
- `ios/plugins/godot_arkit/GodotARKit.xcframework` 和 `.gdip` 是否存在。
- `export_presets.cfg` 是否包含目标 C00 preset。
- C00 smoke scene 是否是 Godot 主场景。
- `project.godot` 是否开启 OpenXR。

iPad/ARKit gate 前先构建插件：

```bash
GODOT_SOURCE_DIR=/path/to/godot ios/plugins/godot_arkit/build_xcframework.sh
```

如果当前机器还没有 Godot source headers，可以先跑语法级 smoke check，提前发现 ARKit / Objective-C++ bridge 的明显编译问题：

```bash
tools/c00/check_arkit_plugin_static.sh
```

这个检查使用临时 Godot stub headers 和本机 iOS SDK，不会生成 `.xcframework`，也不能替代真实 `build_xcframework.sh`。

## 一键执行 Gate

设备机上优先使用：

```bash
tools/c00/run_device_cycle.sh editor
```

```bash
tools/c00/run_device_cycle.sh rokid
```

```bash
GODOT_SOURCE_DIR=/path/to/godot \
DEVICE=<ipad-uuid-or-name> \
tools/c00/run_device_cycle.sh ipad
```

完整 C00 主线：

```bash
GODOT_SOURCE_DIR=/path/to/godot \
DEVICE=<ipad-uuid-or-name> \
tools/c00/run_device_cycle.sh all
```

`all` 模式会按 iPad、Rokid 顺序执行。默认即使某个 gate 失败也会继续跑后续 gate，最后自动执行 `verify_phase_evidence.js` 生成 C00 总报告。设置 `INCLUDE_EDITOR_SIM=1` 可在设备 gate 前先跑本地模拟器 gate。

常用开关：

- `RUN_EXPORT=0`：跳过 Godot 导出，直接采集已安装应用。
- `RUN_COLLECT=0`：只做预检和导出。
- `BUILD_ARKIT_PLUGIN=0`：跳过 ARKit 插件构建。
- `BUILD_IPAD_APP=0`：跳过 iOS Xcode project 自动构建；如果已手工构建，可直接设置 `APP_PATH`。
- `IPAD_APP_PATH=builds/ipad/GodotXRFoundation.app`：iPad 自动构建后的稳定 `.app` 输出路径。
- `SCHEME=<xcode-scheme>` / `TARGET_NAME=<xcode-target>`：导出的 Xcode project 无法自动识别 scheme 时显式指定。
- `CAPTURE_MEDIA=0`：跳过截图/录屏采集。
- `VIDEO_SECONDS=15`：Android/Rokid 录屏时长。
- `MANUAL_MEDIA_PATH=/path/to/file`：iPad 自动截图不可用时，提供手动截图或录屏。
- `ALLOW_MISSING_MEDIA=1`：继续生成报告，但把缺失媒体证据降级为 warning。
- `INCLUDE_ANDROID_ARCORE=1`：`all` 模式额外跑 Android ARCore gate。
- `CONTINUE_ON_FAILURE=0`：`all` 模式遇到第一个失败 gate 就停止。
- `RUN_PHASE_VERIFY=0`：`all` 模式跳过最终 C00 聚合验证。
- `PHASE_REPORT=releases/phase_0_smoke/C00_PHASE_REPORT.md`：覆盖 C00 总报告输出路径。
- `INCLUDE_EDITOR_SIM=1`：`all` 模式先跑 EditorSim gate。

## EditorSim / 模拟器

没有设备时可以先跑本地模拟器：

```bash
tools/c00/run_device_cycle.sh editor
```

底层采集脚本：

```bash
tools/c00/collect_editor_smoke.sh 15
```

它会用 `--xr-platform=simulator` 启动 Godot，并要求日志通过 `backend:"EditorSim"` gate。模拟器 gate 只能证明上层 ARFoundation-style API、raycast、anchor、plane 和日志链路可用，不能替代 Rokid/OpenXR 或 iPad/ARKit 真机 gate。

## Export Preset 检查

如果设备机还没有 `export_presets.cfg`，可以先生成 C00 starter：

```bash
node tools/c00/write_export_presets_template.js --output export_presets.cfg
```

常用参数：

- `--package org.example.app`：Android package id。
- `--bundle org.example.app`：iOS bundle id。
- `--team-id ABCDE12345`：Apple Team ID 占位值。
- `--force`：覆盖已有文件。
- `--dry-run`：只打印模板。

生成后请在 Godot editor 的 Export 面板打开并复核 Android XR Mode、OpenXR vendor loader、iOS signing 和 plugin 状态，再保存一次。

手动检查 preset 名称和平台：

```bash
node tools/c00/check_export_presets.js --gate all --file export_presets.cfg
```

C00 runner 依赖这些 preset 名称：

- `C00 Rokid OpenXR`
- `C00 iPad ARKit`
- `C00 Android ARCore`

Rokid preset 必须设置：

```text
command_line/extra_args="--xr-platform=rokid"
```

iPad preset 必须启用 `GodotARKit` iOS plugin。`collect_ios_smoke.sh` 默认通过 devicectl 向应用传入 `--xr-platform=ipad`，可用 `IOS_XR_PLATFORM=iphone` 覆盖。

## Rokid / Android 日志采集

导出 preset 请先按：

```text
tools/c00/EXPORT_PRESETS_CN.md
```

创建。命令行导出可使用：

```bash
tools/c00/export_with_godot.sh "C00 Rokid OpenXR" builds/rokid/c00.apk
```

```bash
tools/c00/collect_android_smoke.sh rokid org.godotengine.godotxrfoundation 30
```

可选安装 APK：

```bash
APK_PATH=builds/rokid/c00.apk tools/c00/collect_android_smoke.sh rokid org.godotengine.godotxrfoundation 30
```

采集脚本会同时生成 Android/Rokid 设备画像：

```text
releases/phase_0_smoke/evidence/rokid-<timestamp>-device.md
releases/phase_0_smoke/evidence/rokid-<timestamp>-device.json
```

设备画像会记录 `getprop` 设备型号和系统版本、`wm size/density`、target package 的安装和权限状态、XR/OpenXR/ARCore/Rokid 相关包，以及 camera/Vulkan/XR/VR 相关 feature。多设备连接时可设置 `ADB_SERIAL=<serial>`。

也可以单独采集：

```bash
node tools/c00/collect_android_device_profile.js --gate rokid --package org.godotengine.godotxrfoundation --report releases/phase_0_smoke/evidence/rokid-device.md
```

Rokid 默认严格要求：

- `backend:"OpenXR"`
- `session_state:"Running"`
- `capabilities.ar_product_path:true`
- 新日志应包含 `capabilities.openxr_ar_tier`。`A/B/C` 可作为 AR 路径证据，`D` 是 VR-only，不能算 AR 通过。

如果只想记录 OpenXR 先点亮、但不标记为 AR 通过：

```bash
EXTRA_VALIDATE_ARGS=--allow-openxr-without-ar-blend tools/c00/collect_android_smoke.sh rokid org.godotengine.godotxrfoundation 30
```

## iPad 日志采集

iPad 导出 preset 请先按 `tools/c00/EXPORT_PRESETS_CN.md` 创建。

命令行导出可使用：

```bash
tools/c00/export_with_godot.sh "C00 iPad ARKit" builds/ipad/c00.zip
```

将导出的 Xcode project zip 构建成可安装 `.app`：

```bash
tools/c00/build_ios_xcode_project.sh builds/ipad/c00.zip <device-uuid-or-name>
```

构建成功后默认输出：

```text
builds/ipad/GodotXRFoundation.app
```

先列出设备：

```bash
xcrun devicectl list devices
```

再运行：

```bash
tools/c00/collect_ios_smoke.sh <device-uuid-or-name> org.godotengine.godotxrfoundation 30
```

可选安装 `.app`：

```bash
APP_PATH=builds/ipad/GodotXRFoundation.app tools/c00/collect_ios_smoke.sh <device> org.godotengine.godotxrfoundation 30
```

iPad gate 要求：

- `backend:"ARKit"`
- `session_state:"Running"`
- `capabilities.native_plugin:true`
- `capabilities.runtime:"ARKit"` 或 `capabilities.arkit_supported:true`
- `capabilities.arkit_tracking_state` / `capabilities.arkit_tracking_reason` 必须存在，用于区分正常跟踪、初始化、重定位、运动过快或特征不足。
- `runtime` metadata 能看到 Godot 版本、`--xr-platform=ipad`、rendering/OpenXR 设置和 viewport XR 状态。

## 手动日志验证

如果你从 Xcode、Console.app、Android Studio 或其他工具导出了日志，可以直接验证：

```bash
node tools/c00/validate_smoke_log.js --gate rokid --log path/to/rokid.log --report releases/phase_0_smoke/evidence/rokid.md
node tools/c00/validate_smoke_log.js --gate ipad --log path/to/ipad.log --report releases/phase_0_smoke/evidence/ipad.md
```

也可以把手动采集的日志/截图/录屏导入到标准 C00 evidence 目录，并自动生成同格式报告：

```bash
tools/c00/import_device_evidence.sh \
  --gate rokid \
  --log path/to/rokid.log \
  --screenshot path/to/rokid.png \
  --video path/to/rokid.mp4
```

```bash
tools/c00/import_device_evidence.sh \
  --gate ipad \
  --log path/to/ipad.log \
  --manual-media path/to/ipad.mov
```

支持的 gate：

- `editor`
- `rokid`
- `ipad`
- `android-arcore`

新 C00 日志会包含 `runtime` 字段。`validate_smoke_log.js` 会在报告中追加 `Runtime Metadata` 章节；旧日志缺少该字段时仍可验证 backend，但会产生 warning。

## 手动媒体证据验证

C00 默认还会验证媒体证据：

- Rokid / Android ARCore：必须同时有 `.png` 截图和 `.mp4` 录屏。
- iPad / ARKit：必须至少有一张自动截图，或通过 `MANUAL_MEDIA_PATH` 指向手动截图/录屏。

手动验证：

```bash
node tools/c00/validate_evidence_bundle.js --gate rokid --screenshot path/to/rokid.png --video path/to/rokid.mp4 --report releases/phase_0_smoke/evidence/rokid.md
node tools/c00/validate_evidence_bundle.js --gate ipad --manual-media path/to/ipad.mov --report releases/phase_0_smoke/evidence/ipad.md
```

如果某台设备暂时无法自动截图/录屏，但仍想先保留日志结果：

```bash
ALLOW_MISSING_MEDIA=1 tools/c00/run_device_cycle.sh ipad <device>
```

## C00 发表前总验收

Rokid 和 iPad 都跑完后，用聚合 gate 生成 C00 总报告：

```bash
node tools/c00/verify_phase_evidence.js
```

默认扫描：

```text
releases/phase_0_smoke/evidence/
```

并输出：

```text
releases/phase_0_smoke/C00_PHASE_REPORT.md
```

默认要求：

- 最新 `rokid-*.log` 通过 OpenXR AR gate。
- 最新 `rokid-*.png` 和 `rokid-*.mp4` 都存在。
- 最新 `ipad-*.log` 通过 ARKit gate。
- 最新 `ipad-*.png`、`ipad-*.mp4` 或显式 `--ipad-manual-media` 至少一个存在。

如果要显式指定素材：

```bash
node tools/c00/verify_phase_evidence.js \
  --rokid-log releases/phase_0_smoke/evidence/rokid-xxx.log \
  --rokid-screenshot releases/phase_0_smoke/evidence/rokid-xxx.png \
  --rokid-video releases/phase_0_smoke/evidence/rokid-xxx.mp4 \
  --ipad-log releases/phase_0_smoke/evidence/ipad-xxx.log \
  --ipad-manual-media releases/phase_0_smoke/evidence/ipad-xxx.mov
```

## 报告位置

采集脚本会生成：

```text
releases/phase_0_smoke/evidence/<gate>-<timestamp>.log
releases/phase_0_smoke/evidence/<gate>-<timestamp>.md
releases/phase_0_smoke/evidence/<gate>-<timestamp>.png
releases/phase_0_smoke/evidence/<gate>-<timestamp>.mp4
releases/phase_0_smoke/evidence/<gate>-<timestamp>-device.md
releases/phase_0_smoke/evidence/<gate>-<timestamp>-device.json
```

Android/Rokid 会自动尝试录屏、截图和 device profile。iOS 会在安装 `idevicescreenshot` 时自动截图，否则脚本会提示手动补截图或 15 秒录屏。

采集脚本会把媒体证据验证结果追加到同一个 `.md` 报告的 `Evidence Bundle` 章节；Android/Rokid 还会把 device profile 追加到同一个 gate 报告末尾。
