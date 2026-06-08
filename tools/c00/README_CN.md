# C00 Device Tools

这些脚本用于把第一阶段从“能打开”推进到“能证明 Rokid/OpenXR、iPad/ARKit、Android/ARCore 是否真的通过 gate”。

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
报告会同时列出 `.godot/cache/c00/downloads` 中的断点续传缓存，例如 Godot export templates、Android command line tools 和 OpenJDK 17；如果网络中断，保留这些 partial 文件后重跑同一 installer 即可继续。

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
- `adb` 或 `ADB_BIN=/path/to/adb`：Rokid/Android 日志采集；可使用项目本地 Android platform-tools。
- `xcrun`：iPad 安装和启动。
- `xcodebuild`：把 Godot iOS 导出的 Xcode project 构建成可安装 `.app`。
- `android/plugins`、`ios/plugins` 是否存在。
- Rokid/OpenXR gate 前 `addons/godotopenxrvendors` 是否已安装；这是 Godot OpenXR Vendors plugin 的默认安装路径，用于 Android OpenXR vendor loader 和扩展。
- `addons/godot_arcore` 和 `android/plugins/godot_arcore` 是否保留 Android plugin v2 / AAR export hook / `GodotARCore` singleton surface。
- Android ARCore gate 前 `addons/godot_arcore/bin/release/GodotARCore-release.aar` 是否已由 `android/plugins/godot_arcore/build_plugin.sh` 生成。
- `ios/plugins/godot_arkit/GodotARKit.xcframework` 和 `.gdip` 是否存在。
- `export_presets.cfg` 是否包含目标 C00 preset。
- Godot 官方 export templates 是否已安装到 `~/Library/Application Support/Godot/export_templates/4.4.1.stable`，至少需要 `ios.zip` 和 `android_source.zip`。
- Android/Rokid 导出所需 Android SDK `platform-tools`、`build-tools/apksigner`、Java SDK 和 `keytool` 是否可用。
- `project.godot`、C00 主场景、rig 场景、脚本资源和关键 NodePath 是否完整。
- ARFoundation / XRI / OpenXR provider 静态 surface 是否稳定。
- C00 smoke scene 是否是 Godot 主场景。
- `project.godot` 是否开启 OpenXR。

一键静态 gate：

```bash
node tools/c00/run_static_gates.js --gate all --report releases/phase_0_smoke/evidence/static-gates.md
```

该命令不导出、不安装、不连接设备。它汇总 Node 工具语法、shell 脚本语法、Godot project/scene 静态完整性、ARFoundation API surface、XRI API surface、Rokid/OpenXR export surface、OpenXR/Rokid provider surface、GodotARCore Android plugin surface、iPad Godot source 准备 surface、iOS plugin 配置和 ARKit Objective-C++ syntax smoke。缺少 `export_presets.cfg` 会作为 warning 记录，因为真正导出前仍需在设备机 Godot editor 里复核保存。

## 离线依赖包导入

如果设备机访问 GitHub、SourceForge 或 Android SDK repository 不稳定，可以先在任意网络可用机器准备一个离线依赖包目录，再在设备机导入。推荐目录内容：

```text
device-bundle/
  Godot_v4.4.1-stable_export_templates.tpz
  android-sdk/
    platform-tools/adb
    build-tools/<version>/apksigner
    platforms/android-34/
  jdk/
    bin/java
    bin/keytool
  Godot.app/
  godot-source/
    core/version.h
    platform/ios/
```

导入并生成设备机环境文件：

```bash
tools/c00/import_device_dependency_bundle.sh --bundle /Volumes/USB/device-bundle
source .godot/cache/c00/device-env.sh
```

该脚本会安装 Godot export templates 到 `~/Library/Application Support/Godot/export_templates/4.4.1.stable`，自动识别 Android SDK / JDK / Godot / Godot source headers，写出 `.godot/cache/c00/device-env.sh`，并生成 `releases/phase_0_smoke/evidence/dependency-bundle-*.md`。如果需要同时写入 Godot Android EditorSettings，可以加：

```bash
tools/c00/import_device_dependency_bundle.sh \
  --bundle /Volumes/USB/device-bundle \
  --configure-android-export
```

导入后立即跑三条预检：

```bash
tools/c00/preflight.sh rokid
tools/c00/preflight.sh ipad
tools/c00/preflight.sh android-arcore
```

## 第一阶段完成审计

设备机推荐用一键入口执行完整顺序：

```bash
tools/c00/run_phase1_device_lab.sh \
  --bundle /Volumes/USB/device-bundle \
  --device <ipad-uuid-or-name>
```

它会按顺序执行：

- 导入离线依赖包并 source `.godot/cache/c00/device-env.sh`。
- 生成 device readiness report。
- 跑 C00 static gates。
- 调用 `tools/c00/run_device_cycle.sh all` 执行 iPad/ARKit、Rokid/OpenXR、Android/ARCore。
- 调用 `tools/c00/audit_phase1_completion.js` 生成最终完成审计。

第一次接设备机时先 dry-run：

```bash
tools/c00/run_phase1_device_lab.sh \
  --bundle /Volumes/USB/device-bundle \
  --device <ipad-uuid-or-name> \
  --dry-run
```

当设备机依赖和真机证据都准备好后，用 completion audit 做最后确认：

```bash
node tools/c00/audit_phase1_completion.js
```

默认报告输出到：

```text
releases/phase_0_smoke/C00_COMPLETION_AUDIT.md
releases/phase_0_smoke/C00_COMPLETION_AUDIT.json
```

该审计会同时检查：

- C00 静态 gate。
- ARFoundation / XRI Unity 迁移 API surface。
- `GodotARKit.gdip` + `GodotARKit.xcframework` 是否按 iOS plugin 方式构建完成。
- Rokid/OpenXR provider AR evidence surface。
- Android ARCore gate surface。
- `tools/c00/preflight.sh rokid/ipad/android-arcore` 是否在当前设备机通过。
- `tools/c00/verify_phase_evidence.js` 是否验证到 Rokid/OpenXR、iPad/ARKit、Android/ARCore 的日志、媒体和设备画像。

只要 iPad/Rokid/Android 任一条真机证据缺失，审计会输出 `NOT_READY` 并以非零状态退出；这就是预期行为，不能用模拟器结果替代真机通过。临时只想看代码面是否完整时可以跳过设备预检或证据聚合：

```bash
node tools/c00/audit_phase1_completion.js --skip-preflight --skip-evidence --report /tmp/c00-audit.md --json /tmp/c00-audit.json
```

带 `--skip-*` 的审计只会输出 `PARTIAL`，即使命令退出 0，也只代表所选代码面检查通过，不代表第一阶段完成。

安装 Godot 官方 export templates：

```bash
tools/c00/install_godot_export_templates.sh --download --version 4.4.1.stable
```

如果已经手动下载了 `.tpz`：

```bash
tools/c00/install_godot_export_templates.sh \
  --tpz .godot/cache/c00/downloads/Godot_v4.4.1-stable_export_templates.tpz \
  --version 4.4.1.stable
```

如果 GitHub 下载失败，可以从 Godot 官方 4.4.1 archive 页面下载同名 standard export templates `.tpz` 后，把本地文件路径传给 `--tpz`。iPad 导出至少需要 `ios.zip`；Rokid/OpenXR 和 Android ARCore 的 Gradle 导出至少需要 `android_source.zip`。
`--download` 使用 `curl -L --fail -C -`，如果网络中断，重复运行同一命令会尝试继续下载未完成文件。

安装项目内 Android Gradle build template：

```bash
tools/c00/install_android_build_template.sh
```

该脚本按 Godot 4.4 的 `Project > Install Android Build Template` 逻辑，把 `android_source.zip` 解到 `android/build`，并写入 `android/.build_version` 与 `android/build/.gdignore`。Rokid/OpenXR 和 Android ARCore 都启用了 Gradle export，因此这个步骤是 APK 导出前置条件。

安装项目本地 OpenJDK 17。Godot 4.4 Android export 要求 `Java SDK Path` 指向 OpenJDK 17：

```bash
tools/c00/install_openjdk17.sh --download
export GODOT_JAVA_SDK_PATH="$PWD/.godot/cache/c00/jdk/Contents/Home"
export JAVA_HOME="$GODOT_JAVA_SDK_PATH"
```

如果已经有 OpenJDK 17 tar.gz，可以用：

```bash
tools/c00/install_openjdk17.sh --archive <OpenJDK17-macos-aarch64.tar.gz>
```

安装 Godot 4.4 默认 Android SDK 依赖：

```bash
tools/c00/install_android_sdk_packages.sh --download-cmdline-tools --yes
```

默认安装 `platform-tools`、`platforms;android-34`、`build-tools;34.0.0`。如果设备机已经有 Android command line tools，可以省略 `--download-cmdline-tools`；如果 `sdkmanager` 不在默认 SDK 目录里，传入 `--sdkmanager /path/to/sdkmanager`。如果已有 command line tools zip，可以传入 `--cmdline-tools-zip <commandlinetools-mac-*_latest.zip>`。
OpenJDK 和 Android command line tools 下载同样支持断点续传，重复运行安装命令即可。

Android/Rokid 导出还需要真实 JDK。macOS 的 `/usr/bin/java` / `/usr/bin/keytool` 可能只是系统 stub；`tools/c00/preflight.sh rokid` 会用 `java -version` 和 `keytool -help` 验证它们真的可运行。项目本地 `.godot/cache/c00/jdk/Contents/Home` 会被 `preflight`、readiness report 和 Android 配置脚本自动识别。

配置 Android SDK、debug keystore 和 Godot Android EditorSettings：

```bash
tools/c00/configure_android_export_environment.sh --install-build-template
```

该脚本会生成默认 debug keystore 到 `.godot/cache/c00/android/debug.keystore`，并通过 Godot editor binary 写入 `export/android/android_sdk_path`、`export/android/java_sdk_path`、`export/android/debug_keystore`、`export/android/debug_keystore_user` 和 `export/android/debug_keystore_pass`。`tools/c00/export_with_godot.sh` 在导出 `.apk` / `.aab` 前会自动调用它；如果需要完全手动控制，可设置 `GODOT_CONFIGURE_ANDROID_EXPORT=0`。

`tools/c00/preflight.sh`、`tools/c00/export_with_godot.sh` 和 Android/Rokid 采集脚本会自动查找：

- `GODOT_BIN`。
- PATH 中的 `godot`。
- 项目本地 `.godot/cache/c00/godot-editor/Godot.app/Contents/MacOS/Godot`。
- `/Applications/Godot.app/Contents/MacOS/Godot`。
- `ADB_BIN`、PATH 中的 `adb` 或项目本地 `.godot/cache/c00/android-sdk/platform-tools/adb`。
- `GODOT_JAVA_SDK_PATH` / `JAVA_HOME` / 项目本地 `.godot/cache/c00/jdk/Contents/Home` 下的 `java` 和 `keytool`。

命令行导出时，`tools/c00/export_with_godot.sh` 默认传入 `--xr-mode off`，避免开发机没有 OpenXR runtime 时阻塞导出流程。这个参数只影响构建机上的 Godot editor 进程，不会移除导出包里的 OpenXR/ARKit/ARCore 启动参数。

iPad/ARKit gate 前先构建插件：

```bash
tools/c00/prepare_godot_source.sh --tag <godot-tag>
```

该脚本会把官方 Godot source tree 准备到 `.godot/cache/c00/godot-source`，并输出可直接复制的 `GODOT_SOURCE_DIR=...` 构建命令。`<godot-tag>` 必须和设备机使用的 Godot iOS export template 版本一致，例如 `4.4.1-stable`；如果本机 `godot --version` 能输出 `4.4.1.stable.official` 这类格式，也可以不传 `--tag` 让脚本自动推断。它只准备 headers，不 rebuild Godot，也不修改 engine 主干。

`run_device_cycle.sh` 会自动识别 `.godot/cache/c00/godot-source`。如果该目录还不存在，也可以用 `GODOT_TAG=<godot-tag>` 让 iPad gate 在构建 ARKit 插件前自动准备 source headers：

```bash
GODOT_TAG=4.4.1-stable DEVICE=<ipad-uuid-or-name> tools/c00/run_device_cycle.sh ipad
```

静态检查 source 准备链路：

```bash
node tools/c00/check_ios_godot_source_surface.js
```

然后构建 ARKit iOS plugin：

```bash
GODOT_SOURCE_DIR=/path/to/godot ios/plugins/godot_arkit/build_xcframework.sh
```

如果当前机器还没有 Godot source headers，可以先跑语法级 smoke check，提前发现 ARKit / Objective-C++ bridge 的明显编译问题：

```bash
tools/c00/check_arkit_plugin_static.sh
```

这个检查使用临时 Godot stub headers 和本机 iOS SDK，不会生成 `.xcframework`，也不能替代真实 `build_xcframework.sh`。

同时检查 Godot iOS plugin 配置：

```bash
node tools/c00/check_ios_plugin_artifacts.js
```

设备机上构建出真实 `.gdip` 与 `.xcframework` 后，使用严格检查：

```bash
node tools/c00/check_ios_plugin_artifacts.js --file ios/plugins/godot_arkit/GodotARKit.gdip --require-binary
```

该检查会验证 Godot 官方 `.gdip` 必需字段、`GodotARKit.xcframework` 引用、`init_godot_arkit` / `deinit_godot_arkit` 符号、ARKit/Metal capability、系统 framework、plist camera 权限和 required device capabilities。
它还会检查 iPad gate 真实运行所需的 runtime bridge：`start_session` / `stop_session` / `is_running` / `get_tracking_status` / `get_capabilities` / `hit_test` / `get_planes` 是否绑定，`GodotARKitSession` 是否使用 `ARWorldTrackingConfiguration` 调用 `runWithConfiguration`，是否实现 `ARSessionDelegate` 并输出 `arkit_tracking_state` / `arkit_tracking_reason`，以及是否用 `ARRaycastQuery` / `ARPlaneAnchor` 提供 C00 级 native raycast/plane evidence。
它还会确认 iPad Xcode build helper 会在 `xcodebuild` 前运行导出工程检查，避免 `GodotARKit` 没进 Xcode project 时才到真机上失败。

检查 Godot iOS 导出的 Xcode project 是否真的包含 ARKit plugin：

```bash
node tools/c00/check_ios_export_project.js --input builds/ipad/c00.zip
```

该检查会解包或读取导出目录，确认 `.xcodeproj` 引用了 `GodotARKit`、`GodotARKit.xcframework`、`ARKit.framework`、`Metal.framework`，并确认 plist 含 `NSCameraUsageDescription` 和 `UIRequiredDeviceCapabilities` 的 `arkit`/`metal`。`tools/c00/build_ios_xcode_project.sh` 会在 `xcodebuild` 前自动执行它。

检查 Godot project 和 C00 场景静态完整性：

```bash
node tools/c00/check_godot_project_static.js
```

该检查不需要 Godot binary。它确认 `project.godot` 主场景、XRFoundation autoload、OpenXR 设置、addon plugin、C00 demo/rig 场景的 ext_resource、load_steps、关键节点和 `XRInteractionManager` / AR manager NodePath 引用都能静态解析。

检查 ARFoundation 迁移 API surface：

```bash
node tools/c00/check_arfoundation_api_surface.js
```

该检查不需要 Godot binary。它确认 Unity 风格的 `ARSession.state/notTrackingReason/requestedTrackingMode/matchFrameRate`、`ARRaycastManager` screen/list raycast、`ARPlaneManager`/`ARAnchorManager` trackables 与 changed events 仍存在，用于防止后续周期破坏 Unity 项目迁移入口。

检查 XRI 迁移 API surface：

```bash
node tools/c00/check_xri_api_surface.js
```

该检查不需要 Godot binary。它确认 XRI 风格的 `XRInteractionManager`、`XRRayInteractor`、`XRGrabInteractable`、hover/select/activate 事件和 C00 demo 交互 smoke 节点仍存在，用于防止后续周期破坏 Unity XRI 服务迁移入口。

检查启动平台证据链：

```bash
node tools/c00/check_launch_platform_surface.js
```

该检查确认运行时会同时解析 Godot 普通 command-line args 和 user args，`GXF_SMOKE.runtime` 会输出 `resolved_platform_hint`，并确认 Rokid/iPad/Android ARCore 的 smoke/aggregate gate 会拒绝缺少目标启动平台证据的日志。

检查采集失败诊断链：

```bash
node tools/c00/check_device_collector_diagnostics_surface.js
```

该检查确认 iPad/Rokid/Android collector 在 smoke validation 失败后仍会继续做媒体证据验证、追加 device profile 和 profile analysis，最后再用非零状态退出。这样第一次真机失败也会留下可诊断报告。

检查 iPad 设备画像分析链：

```bash
node tools/c00/check_ios_device_profile_surface.js
```

该检查确认 iPad collector 会先安装 `.app` 再采集 devicectl device profile，并确认 profile analysis 会检查选中设备、目标 bundle 安装状态、display 和 lock state。

检查 OpenXR/Rokid provider 诊断面：

```bash
node tools/c00/check_openxr_provider_surface.js
```

该检查确认 `OpenXRProvider` 会记录 environment blend、OpenXR Vendors passthrough singleton 方法结果和 `openxr_ar_evidence`，会在 session lifecycle 中尝试 `start_passthrough` / vendor passthrough 启动方法，会在没有真实 plane tracker 时提供明确标记的 `openxr_virtual_plane_fallback` / `openxr_plane_source`，并确认 Rokid smoke gate 不会只凭一个模糊布尔值通过。

检查 Rokid/OpenXR 导出配置面：

```bash
node tools/c00/check_rokid_openxr_export_surface.js
```

该检查确认 C00 starter preset 和 preset checker 会要求 Rokid APK 使用 Gradle build、`xr_features/xr_mode=1`、arm64、`--xr-platform=rokid`，并确认设备机 preflight/readiness 会检查 `addons/godotopenxrvendors`。它不下载或捆绑 OpenXR Vendors 插件。

检查 Android ARCore gate 诊断面：

```bash
node tools/c00/check_arcore_gate_surface.js
```

该检查确认 native provider 会输出 `capabilities.runtime:"ARCore"` / `capabilities.arcore_supported:true`，并确认 Android ARCore smoke/aggregate gate 不会只凭 `native_plugin:true` 通过。

检查 GodotARCore Android 插件落点：

```bash
node tools/c00/check_android_arcore_plugin_surface.js
```

该检查确认 `addons/godot_arcore` 导出插件、Android plugin v2 manifest、Java `GodotARCore` singleton、ARCore Maven dependency、C00 build script、以及 Android ARCore export preset 的 `plugins/GodotARCore=true` 入口都还在。它不运行 Gradle，也不替代真机 ARCore gate。

## 一键执行 Gate

设备机上优先使用：

```bash
tools/c00/run_device_cycle.sh editor
```

```bash
APP_PATH=builds/ios_simulator/GodotXRFoundation.app \
tools/c00/run_device_cycle.sh ios-simulator
```

```bash
tools/c00/run_device_cycle.sh rokid
```

```bash
GODOT_SOURCE_DIR=/path/to/godot \
DEVICE=<ipad-uuid-or-name> \
tools/c00/run_device_cycle.sh ipad
```

如果还没有 `/path/to/godot`，先运行：

```bash
tools/c00/prepare_godot_source.sh --tag <godot-tag>
```

也可以把 tag 交给 runner，让它自动准备默认 source 目录：

```bash
GODOT_TAG=<godot-tag> DEVICE=<ipad-uuid-or-name> tools/c00/run_device_cycle.sh ipad
```

完整 C00 主线：

```bash
GODOT_SOURCE_DIR=/path/to/godot \
DEVICE=<ipad-uuid-or-name> \
tools/c00/run_device_cycle.sh all
```

`all` 模式会按 iPad、Rokid、Android ARCore 顺序执行。默认即使某个 gate 失败也会继续跑后续 gate，最后自动执行 `verify_phase_evidence.js` 生成 C00 总报告。设置 `INCLUDE_EDITOR_SIM=1` 可在设备 gate 前先跑本地 EditorSim gate；设置 `INCLUDE_IOS_SIMULATOR=1` 可额外跑 iOS Simulator 辅助 gate。

常用开关：

- `DRY_RUN=1`：只解析 source、export、build、collect、phase verify 的将执行命令，不调用 Godot/Xcode/ADB/devicectl。
- `RUN_EXPORT=0`：跳过 Godot 导出，直接采集已安装应用。
- `RUN_COLLECT=0`：只做预检和导出。
- `BUILD_ARKIT_PLUGIN=0`：跳过 ARKit 插件构建。
- `GODOT_TAG=4.4.1-stable`：当 `.godot/cache/c00/godot-source` 不存在时，允许 iPad gate 自动准备匹配 Godot source headers。
- `AUTO_PREPARE_GODOT_SOURCE=0`：禁止 iPad gate 自动调用 `prepare_godot_source.sh`。
- `BUILD_IPAD_APP=0`：跳过 iOS Xcode project 自动构建；如果已手工构建，可直接设置 `APP_PATH`。
- `IPAD_APP_PATH=builds/ipad/GodotXRFoundation.app`：iPad 自动构建后的稳定 `.app` 输出路径。
- `SCHEME=<xcode-scheme>` / `TARGET_NAME=<xcode-target>`：导出的 Xcode project 无法自动识别 scheme 时显式指定。
- `CAPTURE_MEDIA=0`：跳过截图/录屏采集。
- `VIDEO_SECONDS=15`：Android/Rokid 录屏时长。
- `ANDROID_FORCE_STOP=0`：Android/Rokid 采集前不执行 `adb shell am force-stop`；默认会 force-stop，确保重新读取 APK `assets/_cl_` 启动参数。
- `MANUAL_MEDIA_PATH=/path/to/file`：iPad 自动截图不可用时，提供手动截图或录屏。
- `ALLOW_MISSING_MEDIA=1`：继续生成报告，但把缺失媒体证据降级为 warning。
- `INCLUDE_ANDROID_ARCORE=0`：`all` 模式临时跳过 Android ARCore gate。
- `CONTINUE_ON_FAILURE=0`：`all` 模式遇到第一个失败 gate 就停止。
- `RUN_PHASE_VERIFY=0`：`all` 模式跳过最终 C00 聚合验证。
- `PHASE_REPORT=releases/phase_0_smoke/C00_PHASE_REPORT.md`：覆盖 C00 总报告输出路径。
- `PHASE_GATES=rokid,ipad`：覆盖聚合验证 gate 列表，适合设备机暂时只验证某几台；C00 发布默认要求 `rokid,ipad,android-arcore`。
- `INCLUDE_EDITOR_SIM=1`：`all` 模式先跑 EditorSim gate。
- `INCLUDE_IOS_SIMULATOR=1`：`all` 模式先跑 iOS Simulator 辅助 gate。

设备机首次接入前可先 dry-run 编排：

```bash
DRY_RUN=1 GODOT_TAG=<godot-tag> DEVICE=<ipad-uuid-or-name> tools/c00/run_device_cycle.sh all
```

该命令只打印将执行的 source 准备、ARKit 插件构建、导出、Xcode 构建、设备采集和聚合验证命令，不会改动设备或调用真实构建。

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
默认采集脚本会优先使用 `.godot/cache/c00/godot-editor/Godot.app/Contents/MacOS/Godot`，并以 `--headless --xr-mode off --xr-platform=simulator` 运行。这样本机没有 OpenXR runtime 时也能稳定跑 EditorSim；需要手动 GUI 演示时可设置 `EDITOR_HEADLESS=0`。
C00 demo 还包含一个 XRI-style `XRInteractionManager`、camera `XRRayInteractor` 和 `XRGrabInteractable`，日志中的 `xri` 字段会记录 manager/ray/interactable 是否存在以及 hover/select 计数。

iOS Simulator 和 Android Emulator 可以作为补充：用于验证导出链路、app 启动、日志格式、以及 iOS `.xcframework` simulator slice 是否存在。它们不具备真实 ARKit/OpenXR AR tracking 证据，不能作为 C00 发表通过标准。

iOS Simulator 辅助 gate：

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

或一键执行：

```bash
tools/c00/run_device_cycle.sh ios-simulator
```

该 gate 会用 `--xr-platform=simulator` 启动 iOS app，并要求 `validate_smoke_log.js --gate ios-simulator` 看到 `backend:"EditorSim"`。它证明 iOS 导出、simulator app 启动和统一接口日志链路，不证明 ARKit 真机 tracking。

如果 export preset 和启动命令都包含 `--xr-platform=...`，运行时以后出现的参数为准；因此 iOS Simulator 可以覆盖 iPad preset 中的 `--xr-platform=ipad`。

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
gradle_build/use_gradle_build=true
xr_features/xr_mode=1
architectures/arm64-v8a=true
command_line/extra_args="--xr-platform=rokid"
```

Rokid/OpenXR 设备机还必须安装 Godot OpenXR Vendors plugin 到：

```text
addons/godotopenxrvendors
```

可用脚本安装最新 release：

```bash
tools/c00/install_openxr_vendors.sh
```

也可以从已下载的 `godotopenxrvendorsaddon.zip` 安装：

```bash
tools/c00/install_openxr_vendors.sh --zip /path/to/godotopenxrvendorsaddon.zip
```

安装后在 Godot editor 的 Android export preset 里启用目标 vendor，只启用本次目标设备需要的 vendor 配置，然后保存 `export_presets.cfg`。

iPad preset 必须启用 `GodotARKit` iOS plugin。`collect_ios_smoke.sh` 默认通过 devicectl 向应用传入 `--xr-platform=ipad`，可用 `IOS_XR_PLATFORM=iphone` 覆盖。

Android ARCore preset 必须启用 `GodotARCore` Android plugin：

```text
plugins/GodotARCore=true
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

采集脚本会同时生成 Android/Rokid 设备画像：

```text
releases/phase_0_smoke/evidence/rokid-<timestamp>-device.md
releases/phase_0_smoke/evidence/rokid-<timestamp>-device.json
releases/phase_0_smoke/evidence/rokid-<timestamp>-device-analysis.md
```

设备画像会记录 `getprop` 设备型号和系统版本、`wm size/density`、target package 的安装和权限状态、XR/OpenXR/ARCore/Rokid 相关包，以及 camera/Vulkan/XR/VR 相关 feature。分析报告会把 ADB、目标包安装、runtime 包、camera/Vulkan/XR feature、Rokid 硬件匹配等风险分成 failure/warning。多设备连接时可设置 `ADB_SERIAL=<serial>`。
当 `APK_PATH` 指向 APK 时，脚本会在安装前读取 APK 内的 `assets/_cl_` 并确认 Rokid 包含 `--xr-platform=rokid`。这是 Godot Android export `command_line/extra_args` 的可靠启动参数入口；通过 `adb monkey` 或 exported Activity intent extra 临时补参数不能作为 C00 gate 证据。脚本默认还会在启动前执行 `adb shell am force-stop <package>`，避免复用旧进程。

也可以单独采集：

```bash
node tools/c00/collect_android_device_profile.js --gate rokid --package org.godotengine.godotxrfoundation --report releases/phase_0_smoke/evidence/rokid-device.md
```

也可以对已有 profile JSON 单独分析：

```bash
node tools/c00/analyze_android_device_profile.js \
  --gate rokid \
  --json releases/phase_0_smoke/evidence/rokid-<timestamp>-device.json \
  --report releases/phase_0_smoke/evidence/rokid-<timestamp>-device-analysis.md
```

默认情况下，Rokid/OpenXR runtime 包名未知只会 warning；最终 AR 产品通过仍以 `GXF_SMOKE` 的 `backend:"OpenXR"`、`capabilities.ar_product_path:true` 和 `openxr_ar_tier` 为准。若设备机已经确定 runtime 包名规则，可加 `--strict-runtime-package` 把缺失 runtime 包提升为 failure。

Rokid 默认严格要求：

- `backend:"OpenXR"`
- `session_state:"Running"`
- `ar_session_state` 和 `not_tracking_reason` 必须存在，用于对照 Unity ARFoundation 状态判断。
- `capabilities.ar_product_path:true`
- `capabilities.openxr_ar_evidence` 必须存在且非空，用于说明 AR 路径证据来源。
- `capabilities.openxr_passthrough_start_report` 应记录 passthrough lifecycle 调用结果；为空时先检查 Godot OpenXR 版本和 OpenXR Vendors/Rokid 插件。
- `capabilities.openxr_virtual_plane_fallback` / `capabilities.openxr_plane_source` 应说明 raycast/plane evidence 来自真实 OpenXR tracker 还是 C00 virtual floor fallback。
- 新日志应包含 `capabilities.openxr_ar_tier`。`A/B/C` 可作为 AR 路径证据，`D` 是 VR-only，不能算 AR 通过。

如果只想记录 OpenXR 先点亮、但不标记为 AR 通过：

```bash
EXTRA_VALIDATE_ARGS=--allow-openxr-without-ar-blend tools/c00/collect_android_smoke.sh rokid org.godotengine.godotxrfoundation 30
```

## Android ARCore 日志采集

Android 手机/平板使用单独的 ARCore gate：

先构建 Android plugin AAR：

```bash
android/plugins/godot_arcore/build_plugin.sh
```

```bash
tools/c00/export_with_godot.sh "C00 Android ARCore" builds/android_arcore/c00.apk
```

```bash
APK_PATH=builds/android_arcore/c00.apk \
tools/c00/collect_android_smoke.sh android-arcore org.godotengine.godotxrfoundation 30
```

Android ARCore gate 要求：

- `backend:"ARCore"`
- `session_state:"Running"`
- `ar_session_state` 和 `not_tracking_reason` 必须存在，用于对照 Unity ARFoundation 状态判断。
- `capabilities.native_plugin:true`
- `capabilities.runtime:"ARCore"` 或 `capabilities.arcore_supported:true`
- device profile JSON 能检测到 ARCore package，例如 `com.google.ar.core`。
- Android export preset 启用了 `plugins/GodotARCore=true`，APK 才能暴露 `Engine.get_singleton("GodotARCore")`。
- 截图和录屏都存在。
- 当 `APK_PATH` 指向 APK 时，脚本会检查 `assets/_cl_` 包含 `--xr-platform=arcore`，避免 Android 手机/平板误跑到 OpenXR 路径。

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

构建脚本会先运行：

```bash
node tools/c00/check_ios_export_project.js --input <unpacked-ios-export>
```

如果导出的 Xcode project 没有引用 `GodotARKit.xcframework`、ARKit/Metal framework 或相机 plist，脚本会在 `xcodebuild` 前失败；这通常说明 iOS export preset 没有启用 `GodotARKit` plugin，或 `.gdip`/`.xcframework` 没有放在 `res://ios/plugins`。

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

采集脚本会同时生成 iPad 设备画像：

```text
releases/phase_0_smoke/evidence/ipad-<timestamp>-device.md
releases/phase_0_smoke/evidence/ipad-<timestamp>-device.json
```

设备画像会调用 `devicectl --json-output`，记录 device details、display、lock state、目标 bundle 安装状态和原始 JSON。也可以单独采集：

```bash
node tools/c00/collect_ios_device_profile.js --device <device-uuid-or-name> --bundle org.godotengine.godotxrfoundation --report releases/phase_0_smoke/evidence/ipad-device.md
```

可选安装 `.app`：

```bash
APP_PATH=builds/ipad/GodotXRFoundation.app tools/c00/collect_ios_smoke.sh <device> org.godotengine.godotxrfoundation 30
```

iPad gate 要求：

- `backend:"ARKit"`
- `session_state:"Running"`
- `ar_session_state` 和 `not_tracking_reason` 必须存在，用于对照 Unity ARFoundation 状态判断。
- `capabilities.native_plugin:true`
- `capabilities.runtime:"ARKit"` 或 `capabilities.arkit_supported:true`
- `capabilities.arkit_tracking_state` / `capabilities.arkit_tracking_reason` 必须存在，用于区分正常跟踪、初始化、重定位、运动过快或特征不足。
- `runtime` metadata 能看到 Godot 版本、`--xr-platform=ipad`、rendering/OpenXR 设置和 viewport XR 状态。
- device profile analysis 能确认已选中目标 iPad、目标 bundle 已安装，且设备没有锁屏。

## 手动日志验证

如果你从 Xcode、Console.app、Android Studio 或其他工具导出了日志，可以直接验证：

```bash
node tools/c00/validate_smoke_log.js --gate rokid --log path/to/rokid.log --report releases/phase_0_smoke/evidence/rokid.md
node tools/c00/validate_smoke_log.js --gate ipad --log path/to/ipad.log --report releases/phase_0_smoke/evidence/ipad.md
node tools/c00/validate_smoke_log.js --gate android-arcore --log path/to/android-arcore.log --report releases/phase_0_smoke/evidence/android-arcore.md
```

也可以把手动采集的日志/截图/录屏导入到标准 C00 evidence 目录，并自动生成同格式报告：

```bash
tools/c00/import_device_evidence.sh \
  --gate rokid \
  --log path/to/rokid.log \
  --screenshot path/to/rokid.png \
  --video path/to/rokid.mp4 \
  --device-profile path/to/rokid-device.md \
  --device-profile-json path/to/rokid-device.json
```

```bash
tools/c00/import_device_evidence.sh \
  --gate ipad \
  --log path/to/ipad.log \
  --manual-media path/to/ipad.mov \
  --device-profile path/to/ipad-device.md \
  --device-profile-json path/to/ipad-device.json
```

```bash
tools/c00/import_device_evidence.sh \
  --gate android-arcore \
  --log path/to/android-arcore.log \
  --screenshot path/to/android-arcore.png \
  --video path/to/android-arcore.mp4 \
  --device-profile path/to/android-arcore-device.md \
  --device-profile-json path/to/android-arcore-device.json
```

支持的 gate：

- `editor`
- `rokid`
- `ipad`
- `android-arcore`

新 C00 日志会包含 `runtime` 和 `trackables` 字段。`validate_smoke_log.js` 会在报告中追加 `Runtime Metadata` 章节；Rokid/iPad/Android ARCore 真机 gate 还要求 `platform_hint`、`runtime.resolved_platform_hint`、project setting 或 `runtime.cmdline_xr_args` 中至少一个值能证明本次启动选择了目标 XR platform。`trackables` 缺失会直接失败，因为它证明当前 app 版本已经经过 ARFoundation manager 层输出 plane/anchor/raycast evidence。

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

Rokid、iPad 和 Android ARCore 都跑完后，用聚合 gate 生成 C00 总报告：

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
- 最新 `rokid-*-device.md` 和 `rokid-*-device.json` 都存在，且 JSON 可解析；聚合 gate 会分析 ADB、target package、XR/OpenXR runtime 包、camera/Vulkan/XR feature 和 Rokid 硬件匹配风险。
- 最新 `ipad-*.log` 通过 ARKit gate。
- 最新 `ipad-*.png`、`ipad-*.mp4` 或显式 `--ipad-manual-media` 至少一个存在。
- 最新 `ipad-*-device.md` 和 `ipad-*-device.json` 都存在，且 JSON 可解析。

如果要显式指定素材：

```bash
node tools/c00/verify_phase_evidence.js \
  --rokid-log releases/phase_0_smoke/evidence/rokid-xxx.log \
  --rokid-screenshot releases/phase_0_smoke/evidence/rokid-xxx.png \
  --rokid-video releases/phase_0_smoke/evidence/rokid-xxx.mp4 \
  --rokid-device-profile releases/phase_0_smoke/evidence/rokid-xxx-device.md \
  --rokid-device-profile-json releases/phase_0_smoke/evidence/rokid-xxx-device.json \
  --ipad-log releases/phase_0_smoke/evidence/ipad-xxx.log \
  --ipad-manual-media releases/phase_0_smoke/evidence/ipad-xxx.mov \
  --ipad-device-profile releases/phase_0_smoke/evidence/ipad-xxx-device.md \
  --ipad-device-profile-json releases/phase_0_smoke/evidence/ipad-xxx-device.json
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

Android/Rokid 会自动尝试录屏、截图和 device profile。iOS 会自动采集 devicectl device profile，并在安装 `idevicescreenshot` 时自动截图，否则脚本会提示手动补截图或 15 秒录屏。

采集脚本会把媒体证据验证结果追加到同一个 `.md` 报告的 `Evidence Bundle` 章节；Android/Rokid、Android ARCore 和 iPad 都会把 device profile 追加到同一个 gate 报告末尾。iPad 还会追加 `ipad-*-device-analysis.md`，用于快速看到目标 bundle 和锁屏状态风险。
即使 `validate_smoke_log.js` 失败，collector 也会继续追加媒体证据和设备画像诊断，然后以非零状态退出；不要只看命令退出码，失败时也要打开对应 `.md` 报告。
