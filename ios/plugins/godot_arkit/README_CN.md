# GodotARKit iOS Plugin Skeleton

这是 C00/C04 的 ARKit native plugin 落点。它遵守插件优先原则：通过 Godot iOS plugin 暴露 `GodotARKit` singleton，不修改 Godot engine 主干。

## C00 目标

C00 只要求 iPad 能证明 ARKit provider 可用：

- `Engine.has_singleton("GodotARKit") == true`
- `GodotARKit.initialize()` 或 `GodotARKit.start_session()` 返回 `true`
- `GodotARKit.get_capabilities().native_plugin == true`
- `GXF_SMOKE` 中出现 `backend:"ARKit"` 和 `session_state:"Running"`

真实平面检测、raycast、anchor 可以在 C04 补完。

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
check_availability() -> Dictionary
get_capabilities() -> Dictionary
hit_test(origin: Vector3, direction: Vector3, max_distance: float) -> Array[Dictionary]
create_anchor(transform: Transform3D, attached_trackable: Variant) -> Dictionary
get_planes() -> Array[Dictionary]
```

## 启用步骤

1. 准备与 Godot iOS export template 匹配的 Godot source tree。
2. 构建插件：

```bash
GODOT_SOURCE_DIR=/path/to/godot ios/plugins/godot_arkit/build_xcframework.sh
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
