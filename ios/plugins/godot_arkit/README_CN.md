# GodotARKit iOS Plugin Skeleton

这是 C00/C04 的 ARKit native plugin 落点。它遵守插件优先原则：通过 Godot iOS plugin 暴露 `GodotARKit` singleton，不修改 Godot engine 主干。

## C00 目标

C00 只要求 iPad 能证明 ARKit provider 可用：

- `Engine.has_singleton("GodotARKit") == true`
- `GodotARKit.initialize()` 或 `GodotARKit.start_session()` 返回 `true`
- `GodotARKit.get_capabilities().native_plugin == true`
- `GodotARKit.get_tracking_status()` 返回 Godot `XRInterface` tracking status，并能区分 `normal`、`limited`、`not_available`
- `GodotARKit.get_capabilities()` 暴露 `arkit_tracking_state` 和 `arkit_tracking_reason`
- `GXF_SMOKE` 中出现 `backend:"ARKit"` 和 `session_state:"Running"`

真实平面检测、raycast、anchor 可以在 C04 补完。

`.gdip` 中的 `initialization` / `deinitialization` 函数以 `extern "C"` 导出，避免 C++ name mangling 导致 Godot 找不到符号。`GodotARKitPlugin` 会在初始化时通过 `ClassDB::register_class` 注册，确保 GDScript 可以调用 singleton 方法。

## 文件说明

- `GodotARKit.gdip.template`：Godot iOS plugin 配置模板。构建出 `GodotARKit.xcframework` 后复制为 `GodotARKit.gdip`。
- `src/GodotARKitPlugin.h`
- `src/GodotARKitPlugin.mm`
- `src/GodotARKitSession.h`
- `src/GodotARKitSession.mm`
- `build_xcframework.sh`：实际构建入口，依赖 Godot source headers、Xcode command line tools，并产出 `GodotARKit.xcframework` 与 `GodotARKit.gdip`。

## Singleton API

`NativeXRProvider` 会优先适配这些方法：

```gdscript
initialize() -> bool
start_session() -> bool
stop_session() -> bool
pause() -> bool
resume() -> bool
is_running() -> bool
get_tracking_status() -> int
check_availability() -> Dictionary
get_capabilities() -> Dictionary
hit_test(origin: Vector3, direction: Vector3, max_distance: float) -> Array[Dictionary]
create_anchor(transform: Transform3D, attached_trackable: Variant) -> Dictionary
get_planes() -> Array[Dictionary]
```

`get_capabilities()` 的 ARKit tracking 字段：

```gdscript
{
	"arkit_supported": true,
	"arkit_running": true,
	"arkit_tracking_status": 2,
	"arkit_tracking_state": "normal",
	"arkit_tracking_reason": "none"
}
```

`arkit_tracking_status` 是插件内部状态：`0=not_available`、`1=limited`、`2=normal`。`GodotARKit.get_tracking_status()` 会把它映射成 Godot `XRInterface` / `ARVRInterface` 的 tracking status，便于 `NativeXRProvider` 和上层 ARFoundation-style API 使用。

## 启用步骤

1. 准备与 Godot iOS export template 匹配的 Godot source tree。
2. 构建插件：

```bash
GODOT_SOURCE_DIR=/path/to/godot ios/plugins/godot_arkit/build_xcframework.sh
```

没有 Godot source headers 时，可以先做 Objective-C++ 静态语法检查：

```bash
tools/c00/check_arkit_plugin_static.sh
```

这个检查只证明插件源码能和本机 iOS SDK、最小 Godot stub headers 对齐；iPad gate 仍然必须构建真实 `GodotARKit.xcframework`。

也可以检查 `.gdip` 是否符合 Godot iOS plugin 官方格式：

```bash
node tools/c00/check_ios_plugin_artifacts.js
```

构建出真实产物后运行严格检查：

```bash
node tools/c00/check_ios_plugin_artifacts.js --file ios/plugins/godot_arkit/GodotARKit.gdip --require-binary
```

3. 确认生成：

```text
ios/plugins/godot_arkit/GodotARKit.xcframework
ios/plugins/godot_arkit/GodotARKit.gdip
```

4. 在 Godot iOS export preset 的 Plugins 区域启用 `GodotARKit`。
5. 运行 C00 iPad gate：

```bash
APP_PATH=builds/ipad/GodotXRFoundation.app tools/c00/collect_ios_smoke.sh <device> org.godotengine.godotxrfoundation 30
```

## 构建参数

默认构建 `release_debug`，同时包含 device `arm64` 和 simulator `arm64/x86_64`：

```bash
GODOT_SOURCE_DIR=/path/to/godot \
TARGET=release_debug \
IOS_MIN_VERSION=12.0 \
SIM_ARCHS="arm64 x86_64" \
ios/plugins/godot_arkit/build_xcframework.sh
```

`GODOT_SOURCE_DIR` 必须和 iOS export template 使用的 Godot 版本一致。Godot 官方 iOS plugin 文档要求插件库依赖 Godot engine headers，且插件文件位于 `res://ios/plugins` 下才能被 Godot editor 自动检测。

## 参考

- Godot iOS plugins: https://docs.godotengine.org/en/4.4/tutorials/platform/ios/ios_plugin.html
- Unity ARSession: https://docs.unity.cn/Packages/com.unity.xr.arfoundation%406.1/api/UnityEngine.XR.ARFoundation.ARSession.html
