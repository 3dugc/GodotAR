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
- `build_xcframework.sh`：占位构建入口，依赖 Godot iOS plugin headers 和 Xcode 工程配置。

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

1. 准备与 Godot iOS export template 匹配的 Godot headers。
2. 用 Xcode 或脚本构建 `GodotARKit.xcframework`。
3. 复制模板：

```bash
cp ios/plugins/godot_arkit/GodotARKit.gdip.template ios/plugins/godot_arkit/GodotARKit.gdip
```

4. 确认 `GodotARKit.gdip` 中的 `binary` 指向实际 `GodotARKit.xcframework`。
5. 在 Godot iOS export preset 的 Plugins 区域启用 `GodotARKit`。
6. 运行 C00 iPad gate：

```bash
APP_PATH=builds/ipad/GodotXRFoundation.app tools/c00/collect_ios_smoke.sh <device> org.godotengine.godotxrfoundation 30
```

## 参考

- Godot iOS plugins: https://docs.godotengine.org/en/4.4/tutorials/platform/ios/ios_plugin.html
- Unity ARSession: https://docs.unity.cn/Packages/com.unity.xr.arfoundation%406.1/api/UnityEngine.XR.ARFoundation.ARSession.html
