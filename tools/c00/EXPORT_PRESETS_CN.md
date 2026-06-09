# C00 Export Presets

本文件说明 C00 需要在 Godot 编辑器里创建的导出 preset。不要把证书、密码、provisioning profile 等敏感内容写进仓库；Godot 官方文档说明 `export_presets.cfg` 可以提交，敏感项应进入 `.godot/export_credentials.cfg`。

创建后先检查：

```bash
node tools/c00/check_export_presets.js --gate all --file export_presets.cfg
```

`tools/c00/preflight.sh <gate>` 会自动执行同样的检查。

如果设备机还没有任何 preset，可以先生成 C00 starter：

```bash
node tools/c00/write_export_presets_template.js --output export_presets.cfg
```

示例：

```bash
node tools/c00/write_export_presets_template.js \
  --package org.example.godotxrfoundation \
  --bundle org.example.godotxrfoundation \
  --team-id ABCDE12345 \
  --output export_presets.cfg
```

生成后必须在 Godot editor 的 Export 面板逐项复核并保存：

- Android/Rokid：确认 XR Mode 是 OpenXR，并按 Rokid runtime 或 OpenXR Vendors 插件配置 loader。
- Android/ARCore：确认 native ARCore Android plugin 已按本机插件接入方式启用。
- iOS/iPad：确认 `GodotARKit` plugin 启用，签名和 provisioning 使用本机 Apple Developer 配置。

## Preset 1: C00 Rokid OpenXR

平台：Android

用途：Rokid/OpenXR gate。

关键设置：

- Runnable: enabled
- Use Gradle Build: enabled
- XR Mode: OpenXR
- OpenXR / vendor loader: C00 Rokid gate 当前启用 `xr_features/openxr_vendor_khronos=true`
- Godot OpenXR Vendors plugin: 安装到 `addons/godotopenxrvendors`；同一个 preset 只启用一个目标 vendor。
- Extra Args / `command_line/extra_args`: `--xr-platform=rokid`
- Main scene: `res://demo/boot.tscn`，默认路由到 `res://demo/00_device_smoke_test.tscn`
- Demo route: 需要跑 Rokid placement 时追加 `--xr-scene=rokid_place`
- Package name: 建议 `org.godotengine.godotxrfoundation`
- Export path: `builds/rokid/c00.apk`

导出命令：

如果还没有 OpenXR Vendors 插件：

```bash
tools/c00/install_openxr_vendors.sh
```

```bash
tools/c00/export_with_godot.sh "C00 Rokid OpenXR" builds/rokid/c00.apk
```

导出后检查 APK 是否真的包含 OpenXR loader：

```bash
node tools/c00/check_android_apk_surface.js --gate rokid --apk builds/rokid/c00.apk
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
- Use Gradle Build: enabled
- Native ARCore plugin enabled: `plugins/GodotARCore=true`
- Extra Args / `command_line/extra_args`: 必须包含 `--xr-platform=arcore`
- Main scene: `res://demo/boot.tscn`，默认路由到 `res://demo/00_device_smoke_test.tscn`
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

## Preset 3: C02 Rokid OpenXR Place

平台：Android

用途：Rokid/OpenXR placement demo gate。

关键设置：

- Preset name: `C02 Rokid OpenXR Place`
- Use Gradle Build: enabled
- XR Mode: OpenXR
- OpenXR / vendor loader: 当前启用 `xr_features/openxr_vendor_khronos=true`
- Extra Args / `command_line/extra_args`: `--xr-platform=rokid --xr-scene=rokid_place`
- Export path: `builds/rokid/c02-place.apk`

导出和验证：

```bash
tools/c00/export_with_godot.sh "C02 Rokid OpenXR Place" builds/rokid/c02-place.apk
node tools/c00/check_android_apk_surface.js --gate rokid-place --apk builds/rokid/c02-place.apk
tools/c00/run_device_cycle.sh rokid-place
```

## Preset 4: C00 iPad ARKit

平台：iOS

用途：iPad/ARKit gate。

关键设置：

- ARKit iOS plugin enabled
- Preset text must mention `GodotARKit`; `tools/c00/check_export_presets.js` treats a missing plugin entry as a failure
- Plugin files under `res://ios/plugins`
- `ios/plugins/godot_arkit/GodotARKit.xcframework` exists
- `ios/plugins/godot_arkit/GodotARKit.gdip` exists
- Bundle Identifier: 建议 `org.godotengine.godotxrfoundation`
- Team ID / signing: `application/app_store_team_id` 必须非空；`ABCDE12345` 只是 starter 占位，真机安装前要替换成本机 Apple Developer Team ID
- Base icon: `icons/icon_1024x1024="res://assets/app_icon.svg"`，Godot 会用它生成 iOS 所需尺寸
- `application/export_project_only=true`：Godot 阶段只稳定产出 Xcode project，真机签名/安装交给 `tools/c00/build_ios_xcode_project.sh`
- `export_filter="scenes"` 且 `export_files` 包含 `res://demo/boot.tscn`、C00 smoke、OpenXR lab、Rokid placement、iOS ARKit placement 场景：只导出每期可运行 demo 依赖，避免 `.godot/` 和历史构建产物进入包
- `exclude_filter` 至少排除 `android/build/*,builds/*,exports/*,releases/*,tools/*`，作为额外保险
- Main scene: `res://demo/boot.tscn`，默认路由到 `res://demo/00_device_smoke_test.tscn`
- Demo route: 需要跑 iPad/ARKit placement 时追加 `--xr-scene=ios_arkit_place`
- Export path: `builds/ipad/c00.zip`

设备机可用 signing helper 同时更新 C00/C04 iPad preset 的 Team ID 和 bundle id；它不会写证书、密码或 provisioning profile：

```bash
IPAD_TEAM_ID=<10-char-team-id> \
node tools/c00/configure_ios_signing.js --bundle-id org.godotengine.godotxrfoundation
```

只验证当前 preset 是否已经不是占位 Team ID：

```bash
node tools/c00/configure_ios_signing.js --check-only
```

## Preset 5: C04 iPad ARKit Place

平台：iOS

用途：iPad/ARKit placement demo gate。

关键设置：

- Preset name: `C04 iPad ARKit Place`
- ARKit iOS plugin enabled
- Extra Args / `command_line/extra_args`: `--xr-platform=ipad --xr-scene=ios_arkit_place`
- Export path: `builds/ipad/c04-place.zip`
- 默认 `.app` 输出：`builds/ipad/GodotXRFoundation-C04.app`

导出和验证：

```bash
tools/c00/export_with_godot.sh "C04 iPad ARKit Place" builds/ipad/c04-place.zip
DEVICE=<ipad-uuid-or-name> tools/c00/run_device_cycle.sh ipad-place
```

构建 ARKit 插件：

```bash
tools/c00/prepare_godot_source.sh --tag <godot-tag>
```

```bash
GODOT_SOURCE_DIR=/path/to/godot ios/plugins/godot_arkit/build_xcframework.sh
```

`prepare_godot_source.sh` 会准备与 export template 匹配的 Godot source headers，并输出下一条 `GODOT_SOURCE_DIR=... build_xcframework.sh` 命令。如果已经有本机 Godot source tree，可以直接设置 `GODOT_SOURCE_DIR`。
`run_device_cycle.sh ipad` 会自动识别 `.godot/cache/c00/godot-source`；如果该目录不存在，可以用 `GODOT_TAG=<godot-tag>` 让 runner 在 iPad gate 前自动准备。

导出命令：

```bash
tools/c00/export_with_godot.sh "C00 iPad ARKit" builds/ipad/c00.zip
```

Godot iOS 导出通常生成 Xcode project zip。设备机可继续用脚本构建 `.app`：

```bash
IPAD_TEAM_ID=<10-char-team-id> \
tools/c00/build_ios_xcode_project.sh builds/ipad/c00.zip <device-uuid-or-name>
```

默认输出：

```text
builds/ipad/GodotXRFoundation.app
```

然后安装和采集：

```bash
APP_PATH=builds/ipad/GodotXRFoundation.app tools/c00/collect_ios_smoke.sh <device> org.godotengine.godotxrfoundation 30
```

### iOS Simulator 辅助验证

iOS Simulator 复用 `C00 iPad ARKit` preset，不新增发布 preset。它只验证导出、simulator slice、app 启动和日志链路：

```bash
tools/c00/export_with_godot.sh "C00 iPad ARKit" builds/ios_simulator/c00.zip
```

```bash
IOS_BUILD_PLATFORM=simulator \
ALLOW_PROVISIONING_UPDATES=0 \
CODE_SIGN_STYLE= \
CODE_SIGNING_ALLOWED=NO \
APP_OUTPUT_PATH=builds/ios_simulator/GodotXRFoundation.app \
tools/c00/build_ios_xcode_project.sh builds/ios_simulator/c00.zip
```

```bash
APP_PATH=builds/ios_simulator/GodotXRFoundation.app \
tools/c00/collect_ios_simulator_smoke.sh booted org.godotengine.godotxrfoundation 30
```

等价一键命令：

```bash
tools/c00/run_device_cycle.sh ios-simulator
```

通过标准是 `backend:"EditorSim"`；它不能替代 iPad/ARKit 真机 gate。

C04 placement 对应的 simulator 开发门：

```bash
tools/c00/export_with_godot.sh "C04 iPad ARKit Place" builds/ios_simulator/c04-place.zip
```

```bash
IOS_BUILD_PLATFORM=simulator \
ALLOW_PROVISIONING_UPDATES=0 \
CODE_SIGN_STYLE= \
CODE_SIGNING_ALLOWED=NO \
APP_OUTPUT_PATH=builds/ios_simulator/GodotXRFoundation-C04.app \
tools/c00/build_ios_xcode_project.sh builds/ios_simulator/c04-place.zip
```

```bash
IOS_SIM_GATE=ios-simulator-place \
IOS_SIM_XR_SCENE=ios_arkit_place \
APP_PATH=builds/ios_simulator/GodotXRFoundation-C04.app \
tools/c00/collect_ios_simulator_smoke.sh booted org.godotengine.godotxrfoundation 30
```

等价一键命令：

```bash
tools/c00/run_device_cycle.sh ios-simulator-place
```

该 gate 通过 `EditorSim` 验证 C04 placement 场景、`GXF_ARKIT_PLACE`、raycast/anchor 和 iOS simulator app 启动链路；它不能替代 `tools/c00/run_device_cycle.sh ipad-place`。

## 不通过 preset 硬编码的原因

Rokid/OpenXR loader、ARCore plugin、ARKit plugin、Team ID、签名和 export template 路径都依赖本机环境和 Godot 版本。C00 当前提交的是稳定的导出命名、starter 生成脚本、检查脚本和 gate 判定；真正的 `export_presets.cfg` 建议在有 Godot 编辑器和设备的机器上生成、复核后再提交。

## 官方参考

- Godot Android XR setup: https://developer.android.com/develop/xr/godot/setup
- Godot XR Android deployment: https://docs.godotengine.org/en/4.0/tutorials/xr/deploying_to_android.html
- Godot iOS export: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_ios.html
- Godot export configuration: https://docs.godotengine.org/en/4.6/tutorials/export/exporting_projects.html
