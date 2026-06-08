# C00 Export Presets

本文件说明 C00 需要在 Godot 编辑器里创建的导出 preset。不要把证书、密码、provisioning profile 等敏感内容写进仓库；Godot 官方文档说明 `export_presets.cfg` 可以提交，敏感项应进入 `.godot/export_credentials.cfg`。

## Preset 1: C00 Rokid OpenXR

平台：Android

用途：Rokid/OpenXR gate。

关键设置：

- Runnable: enabled
- Use Gradle Build: enabled
- XR Mode: OpenXR
- OpenXR / vendor loader: 按 Rokid runtime 或 OpenXR Vendors 插件要求配置
- Main scene: `res://demo/00_device_smoke_test.tscn`
- Package name: 建议 `org.godotengine.godotxrfoundation`
- Export path: `builds/rokid/c00.apk`

导出命令：

```bash
tools/c00/export_with_godot.sh "C00 Rokid OpenXR" builds/rokid/c00.apk
```

设备验证：

```bash
APK_PATH=builds/rokid/c00.apk tools/c00/collect_android_smoke.sh rokid org.godotengine.godotxrfoundation 30
```

## Preset 2: C00 Android ARCore

平台：Android

用途：Android 手机/平板 ARCore availability gate。

关键设置：

- Runnable: enabled
- Use Gradle Build: enabled if the ARCore plugin needs Gradle/AAR integration
- Native ARCore plugin enabled in Android plugins
- Main scene: `res://demo/00_device_smoke_test.tscn`
- Package name: 建议 `org.godotengine.godotxrfoundation`
- Export path: `builds/android_arcore/c00.apk`

导出命令：

```bash
tools/c00/export_with_godot.sh "C00 Android ARCore" builds/android_arcore/c00.apk
```

设备验证：

```bash
APK_PATH=builds/android_arcore/c00.apk tools/c00/collect_android_smoke.sh android-arcore org.godotengine.godotxrfoundation 30
```

## Preset 3: C00 iPad ARKit

平台：iOS

用途：iPad/ARKit gate。

关键设置：

- ARKit iOS plugin enabled
- Plugin files under `res://ios/plugins`
- `ios/plugins/godot_arkit/GodotARKit.xcframework` exists
- `ios/plugins/godot_arkit/GodotARKit.gdip` exists
- Bundle Identifier: 建议 `org.godotengine.godotxrfoundation`
- Team ID / signing: 使用本机 Apple Developer 配置
- Main scene: `res://demo/00_device_smoke_test.tscn`
- Export path: `builds/ipad/c00.zip`

构建 ARKit 插件：

```bash
GODOT_SOURCE_DIR=/path/to/godot ios/plugins/godot_arkit/build_xcframework.sh
```

导出命令：

```bash
tools/c00/export_with_godot.sh "C00 iPad ARKit" builds/ipad/c00.zip
```

Godot iOS 导出通常生成 Xcode project zip。解压并用 Xcode 签名、部署，或生成 `.app` 后用：

```bash
APP_PATH=builds/ipad/GodotXRFoundation.app tools/c00/collect_ios_smoke.sh <device> org.godotengine.godotxrfoundation 30
```

## 不通过 preset 硬编码的原因

Rokid/OpenXR loader、ARCore plugin、ARKit plugin、Team ID、签名和 export template 路径都依赖本机环境和 Godot 版本。C00 当前提交的是稳定的导出命名、检查脚本和 gate 判定；真正的 `export_presets.cfg` 建议在有 Godot 编辑器和设备的机器上生成后再提交。

## 官方参考

- Godot Android XR setup: https://developer.android.com/develop/xr/godot/setup
- Godot XR Android deployment: https://docs.godotengine.org/en/4.0/tutorials/xr/deploying_to_android.html
- Godot iOS export: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_ios.html
- Godot export configuration: https://docs.godotengine.org/en/4.6/tutorials/export/exporting_projects.html
