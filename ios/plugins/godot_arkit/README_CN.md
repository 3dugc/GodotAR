# GodotARKit iOS Plugin Skeleton

这是 C00/C04 的 ARKit native plugin 落点。它遵守插件优先原则：通过 Godot iOS plugin 暴露 `GodotARKit` singleton，不修改 Godot engine 主干。

## C00 目标

C00 只要求 iPad 能证明 ARKit provider 可用：

- `Engine.has_singleton("GodotARKit") == true`
- `GodotARKit.initialize()` 或 `GodotARKit.start_session()` 返回 `true`
- `GodotARKit.get_capabilities().native_plugin == true`
- `GodotARKit.get_tracking_status()` 返回 Godot `XRInterface` tracking status，并能区分 `normal`、`limited`、`not_available`
- `GodotARKit.get_capabilities()` 暴露 `arkit_tracking_state` 和 `arkit_tracking_reason`
- `GodotARKit.try_get_intrinsics()` 暴露 ARKit `ARFrame.camera.intrinsics` / `imageResolution`，供 `ARCameraManager.TryGetIntrinsics(...)` 优先使用真实设备相机模型
- `GodotARKit.get_camera_frame()` 暴露 C00 级 frame metadata：timestamp、tracking state/reason、intrinsics、light estimation
- `GodotARKit.get_light_estimation()` 暴露 ARKit `ARFrame.lightEstimate` 的 ambient intensity / color temperature
- `GodotARKit.hit_test()` 使用 ARKit `ARRaycastQuery` 返回 C00 级 native raycast hit 字典
- `GodotARKit.get_planes()` 使用 ARKit `ARPlaneAnchor` 返回 C00 级 plane 字典
- `hit_test()` / `get_planes()` 返回 native ARKit transform pose，供 `XRHit.get_pose()` 和 Unity-style placement workflow 使用
- `GXF_SMOKE` 中出现 `backend:"ARKit"` 和 `session_state:"Running"`

完整 plane classification、mesh、persistent anchor 和跨平台 trackable 行为进入 C04；C00 先保证 iPad gate 有最小 native ARKit raycast/plane evidence。

`.gdip` 中的 `initialization` / `deinitialization` 函数使用 C++ linkage 导出，匹配 Godot iOS exporter 生成的 `dummy.cpp` 中的 `extern void init_godot_arkit();` / `extern void deinit_godot_arkit();`。`GodotARKitPlugin` 会在初始化时通过 `ClassDB::register_class` 注册，确保 GDScript 可以调用 singleton 方法。

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
try_get_intrinsics() -> Dictionary
get_camera_frame() -> Dictionary
get_light_estimation() -> Dictionary
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

`try_get_intrinsics()` 返回字段会尽量贴近 Unity `XRCameraIntrinsics`：

```gdscript
{
	"success": true,
	"focal_length": [fx, fy],
	"principal_point": [cx, cy],
	"resolution": [width, height],
	"matrix": [m00, m01, ...],
	"source": "arkit_camera_intrinsics"
}
```

`get_camera_frame()` 返回字段：

```gdscript
{
	"available": true,
	"runtime": "ARKit",
	"timestamp_msec": 12345.0,
	"tracking_state": "normal",
	"tracking_reason": "none",
	"has_intrinsics": true,
	"intrinsics": {...},
	"has_light_estimate": true,
	"light_estimation": {
		"ambient_intensity": 1000.0,
		"ambient_color_temperature": 6500.0
	}
}
```

`arkit_tracking_status` 是插件内部状态：`0=not_available`、`1=limited`、`2=normal`。`GodotARKit.get_tracking_status()` 会把它映射成 Godot `XRInterface` / `ARVRInterface` 的 tracking status，便于 `NativeXRProvider` 和上层 ARFoundation-style API 使用。

`hit_test()` 返回字段：

```gdscript
{
	"trackable_id": "...",
	"distance": 1.2,
	"position": Vector3(...),
	"normal": Vector3.UP,
	"transform": Transform3D(...),
	"trackable_type": XRFoundationTypes.TrackableType.PLANE,
	"trackable_type_name": "plane",
	"raw_hit": "ARKitRaycast"
}
```

`get_planes()` 返回字段：

```gdscript
{
	"trackable_id": "...",
	"transform": Transform3D(...),
	"size": Vector2(...),
	"alignment": "horizontal|vertical",
	"label": "",
	"tracking_state": XRFoundationTypes.TrackingState.TRACKING,
	"raw_tracker": "ARKitPlaneAnchor"
}
```

## 启用步骤

1. 准备与 Godot iOS export template 匹配的 Godot source tree。设备机可以用 C00 helper 从官方 Godot 仓库准备 headers：

```bash
tools/c00/prepare_godot_source.sh --tag <godot-tag>
```

`<godot-tag>` 例如 `4.4.1-stable`，必须和本机 Godot iOS export template 的版本一致。脚本默认输出：

```bash
export GODOT_SOURCE_DIR=".godot/cache/c00/godot-source"
GODOT_SOURCE_DIR=".godot/cache/c00/godot-source" ios/plugins/godot_arkit/build_xcframework.sh
```

如果本机 `godot --version` 能输出稳定版格式，也可以省略 `--tag` 让脚本从 `GODOT_BIN` 或 PATH 中的 `godot` 推断。
`tools/c00/run_device_cycle.sh ipad` 会自动识别这个默认目录；也可以直接设置 `GODOT_TAG=<godot-tag>`，让 runner 在构建 `GodotARKit.xcframework` 前自动调用 source helper。

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
5. 导出 iOS Xcode project 后检查导出结果：

```bash
node tools/c00/check_ios_export_project.js --input builds/ipad/c00.zip
```

这个检查会确认导出的 Xcode project 已引用 `GodotARKit.xcframework`、ARKit/Metal framework、相机权限和 `arkit`/`metal` required device capabilities。`tools/c00/build_ios_xcode_project.sh` 会自动执行它。

6. 运行 C00 iPad gate：

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

如果本地已经有完整 Godot source tree，也可以跳过 `prepare_godot_source.sh`，直接设置 `GODOT_SOURCE_DIR=/path/to/godot`。C00 静态 gate 会通过 `node tools/c00/check_ios_godot_source_surface.js` 确认这个准备链路和构建说明没有被后续改动破坏。

## 参考

- Godot iOS plugins: https://docs.godotengine.org/en/4.4/tutorials/platform/ios/ios_plugin.html
- Godot source: https://github.com/godotengine/godot.git
- Unity ARSession: https://docs.unity.cn/Packages/com.unity.xr.arfoundation%406.1/api/UnityEngine.XR.ARFoundation.ARSession.html
