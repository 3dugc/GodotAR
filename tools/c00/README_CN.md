# C00 Device Tools

这些脚本用于把第一阶段从“能打开”推进到“能证明 Rokid/OpenXR、iPad/ARKit 是否真的通过 gate”。

## 预检

```bash
tools/c00/preflight.sh
```

检查：

- `node`：运行日志 validator。
- `godot`：命令行导出/导入校验。
- `adb`：Rokid/Android 日志采集。
- `xcrun`：iPad 安装和启动。
- `android/plugins`、`ios/plugins` 是否存在。
- C00 smoke scene 是否是 Godot 主场景。

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
