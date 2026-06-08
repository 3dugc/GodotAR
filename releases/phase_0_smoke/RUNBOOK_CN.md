# C00 Device Smoke Runbook

目标：让第一阶段每次都能在 Rokid/OpenXR 和 iPad/ARKit 上运行、检测、归档。

## 运行入口

Godot 主场景已经设置为：

```text
res://demo/00_device_smoke_test.tscn
```

也可以在编辑器中手动运行该场景。

## 插件优先边界

C00 不修改 Godot 主干。

设备接入路径必须记录为：

- Godot addon
- Android plugin
- iOS plugin
- GDExtension
- OpenXR vendor plugin
- engine patch

如果出现 `engine patch`，本周期必须附带最小侵入说明，否则不能标记为通过。

## Rokid / OpenXR

通过标准：

- 设备中能看到状态面板和旋转 cube。
- 面板显示 `Session: Running`。
- 面板显示 `Backend: OpenXR`。
- 日志包含 `GXF_SMOKE`，且 JSON 中 `backend` 为 `OpenXR`。
- `capabilities.ar_product_path` 为 `true` 时，才算 AR 产品路径通过。

建议设置：

```gdscript
XRFoundation.start_session(XRFoundationTypes.Backend.OPENXR, {
	"platform_hint": "rokid",
	"prefer_ar": true,
	"passthrough": true,
})
```

可选启动参数：

```text
--xr-platform=rokid
```

失败判定：

- `Backend: EditorSim`：Godot 应用启动了，但 OpenXR gate 未通过。
- `ar_product_path=false` 且 blend 只有 `opaque`：OpenXR 渲染启动了，但还不是 AR 结果。
- OpenXR interface unavailable：检查 Godot OpenXR 设置、Android export XR mode、Rokid runtime、OpenXR Vendors 插件。

## iPad / ARKit

通过标准：

- iPad 上能看到状态面板和旋转 cube。
- 面板显示 `Session: Running`。
- 面板显示 `Backend: ARKit`。
- 日志包含 `GXF_SMOKE`，且 JSON 中 `backend` 为 `ARKit`。
- `capabilities.native_plugin=true`。

失败判定：

- `Backend: EditorSim`：iOS app 启动了，但 ARKit native plugin 没有被 Godot 识别。
- `singleton_registered=false` 且 `interface_registered=false`：检查 `.gdip`、`.xcframework`、Xcode linking、iOS plugin singleton 名称。

## 归档材料

每台设备至少保存：

- 一张截图或 15 秒录屏。
- 过滤 `GXF_SMOKE` 后的日志。
- 设备型号、系统版本、Godot 版本、插件版本。
- 使用的扩展路径：addon / Android plugin / iOS plugin / GDExtension / OpenXR vendor plugin / engine patch。
- 是否通过 gate。

## 参考原则

- Unity `ARSession` 的 `CheckAvailability` 和 `Install` 模型，用于统一生命周期判断。
- Unity `ARRaycastManager.Raycast` 的结果由调用方传入/接收列表，结果按距离优先；Godot 当前返回 `Array[XRHit]`，语义保持接近。
- Unity `XROrigin`/`ARSessionOrigin` 的核心职责是把 session space 映射到场景空间；Godot 使用 `XROrigin3D` 实现同一边界。
- Godot OpenXR AR/Passthrough 通过 environment blend mode 表达 AR/MR 背景能力；只有 opaque 不能算 AR 产品通过。
- Godot iOS 插件必须放在 `res://ios/plugins`，并通过 `.gdip` + `.xcframework` 暴露给 Godot，再用 `Engine.get_singleton()` 访问。

## 资料

- Unity ARSession: https://docs.unity.cn/Packages/com.unity.xr.arfoundation%406.1/api/UnityEngine.XR.ARFoundation.ARSession.html
- Unity ARRaycastManager: https://docs.unity.cn/Packages/com.unity.xr.arfoundation%406.0/api/UnityEngine.XR.ARFoundation.ARRaycastManager.html
- Unity XR Origin: https://docs.unity3d.com/cn/2023.2/Manual/xr-origin.html
- Godot AR/Passthrough: https://docs.godotengine.org/en/4.4/tutorials/xr/ar_passthrough.html
- Godot iOS plugins: https://docs.godotengine.org/en/4.4/tutorials/platform/ios/ios_plugin.html
