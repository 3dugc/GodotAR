# C00 Device Tools

这些脚本用于把第一阶段从“能打开”推进到“能证明 Rokid/OpenXR、iPad/ARKit 是否真的通过 gate”。

## 预检

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
- `android/plugins`、`ios/plugins` 是否存在。
- `ios/plugins/godot_arkit/GodotARKit.xcframework` 和 `.gdip` 是否存在。
- `export_presets.cfg` 是否包含目标 C00 preset。
- C00 smoke scene 是否是 Godot 主场景。
- `project.godot` 是否开启 OpenXR。

iPad/ARKit gate 前先构建插件：

```bash
GODOT_SOURCE_DIR=/path/to/godot ios/plugins/godot_arkit/build_xcframework.sh
```

## 一键执行 Gate

设备机上优先使用：

```bash
tools/c00/run_device_cycle.sh rokid
```

```bash
GODOT_SOURCE_DIR=/path/to/godot \
DEVICE=<ipad-uuid-or-name> \
APP_PATH=builds/ipad/GodotXRFoundation.app \
tools/c00/run_device_cycle.sh ipad
```

完整 C00 主线：

```bash
GODOT_SOURCE_DIR=/path/to/godot \
DEVICE=<ipad-uuid-or-name> \
APP_PATH=builds/ipad/GodotXRFoundation.app \
tools/c00/run_device_cycle.sh all
```

常用开关：

- `RUN_EXPORT=0`：跳过 Godot 导出，直接采集已安装应用。
- `RUN_COLLECT=0`：只做预检和导出。
- `BUILD_ARKIT_PLUGIN=0`：跳过 ARKit 插件构建。
- `INCLUDE_ANDROID_ARCORE=1`：`all` 模式额外跑 Android ARCore gate。

## Export Preset 检查

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

Rokid 默认严格要求：

- `backend:"OpenXR"`
- `session_state:"Running"`
- `capabilities.ar_product_path:true`

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

## 手动日志验证

如果你从 Xcode、Console.app、Android Studio 或其他工具导出了日志，可以直接验证：

```bash
node tools/c00/validate_smoke_log.js --gate rokid --log path/to/rokid.log --report releases/phase_0_smoke/evidence/rokid.md
node tools/c00/validate_smoke_log.js --gate ipad --log path/to/ipad.log --report releases/phase_0_smoke/evidence/ipad.md
```

支持的 gate：

- `editor`
- `rokid`
- `ipad`
- `android-arcore`

## 报告位置

采集脚本会生成：

```text
releases/phase_0_smoke/evidence/<gate>-<timestamp>.log
releases/phase_0_smoke/evidence/<gate>-<timestamp>.md
```

这些文件是设备证据。提交发布报告时，把通过的日志、截图或录屏一起归档。
