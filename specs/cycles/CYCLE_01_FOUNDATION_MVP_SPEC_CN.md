# C01 Foundation MVP Spec

状态：Draft

周期：C01

版本：v0.1.0-c01-foundation-mvp

建议周期：1-2 周

Unity 对齐基线：以 Unity 官方可见的最新 AR Foundation / XR Core Utilities / XR Interaction Toolkit / OpenXR 文档为目标；当前 C01 以 Unity 6.x `com.unity.xr.arfoundation@6.4.x` 的 manager/subsystem 形状和 `XROrigin` 主入口为设计基线。若官方出现更高 released、pre-release、preview 或 unreleased 文档，后续 spec 必须前移基线。

## 一句话成果

同一份上层代码可以通过 Godot XR Foundation 完成 session、raycast、plane、anchor 的最小闭环，并在 EditorSim 和 OpenXR fallback 下运行。

## 目标设备

| 设备 | 是否必须 | 运行方式 | 备注 |
| --- | --- | --- | --- |
| Editor | Yes | Godot editor | 完整闭环 |
| Rokid / OpenXR | Yes | APK | OpenXR 启动或 fallback |
| iPad / ARKit | Yes | Xcode project | ARKit availability 或 fallback |
| Android ARCore | Should | APK | provider availability |

## 本周期做

- `ARRaycastManager.screen_raycast()` 和 `raycast()` 稳定。
- `ARPlaneManager.get_all_planes()` 稳定。
- `ARAnchorManager.add_anchor()` 稳定。
- `ARCameraManager` 初版。
- `XROrigin` 作为 Unity 6.x 风格 session-space/world-space 入口稳定，`ARSessionOrigin` 仅作为 deprecated 迁移 shim。
- `demo/01_place_on_plane.tscn`。
- `demo/02_backend_switcher.tscn`。
- EditorSim 中支持地面 plane、raycast、anchor。
- OpenXR provider 支持 session 状态和 blend mode。

## 本周期不做

- 不要求 ARCore/ARKit camera background。
- 不要求 Rokid 真实空间 plane。
- 不做复杂交互系统。

## API / 接口

新增：

- `ARCameraManager`
- `XRFoundation.get_capabilities()`
- `XRFoundation.capabilities_changed`
- `ARRaycastManager.Raycast(screen_position, results, trackable_types)`
- `ARRaycastManager.Raycast(ray_dictionary_or_transform, results, trackable_types)`
- `ARAnchorManager.AttachAnchor(plane, pose)`
- `ARAnchorManager.GetDescriptor()`
- `XROrigin.Camera`
- `XROrigin.Origin`
- `XROrigin.TrackablesParent`
- `XROrigin.MoveCameraToWorldLocation(...)`
- `XROrigin.RotateAroundCameraUsingOriginUp(...)`
- `XROrigin.MakeContentAppearAt(...)`
- `ARSessionOrigin.MakeContentAppearAt(...)`
- `XRRayInteractor.TryGetCurrent3DRaycastHit(result_array)`

冻结：

- `ARRaycastManager.raycast(origin, direction, max_results)`
- `ARRaycastManager.screen_raycast(camera, screen_position, max_results)`
- `ARAnchorManager.add_anchor(transform, attached_trackable)`
- `ARPlaneManager.get_all_planes()`
- `XROrigin.GetCamera()`
- `XROrigin.GetTrackablesParent()`

## Demo

```text
demo/01_place_on_plane.tscn
demo/02_backend_switcher.tscn
```

## 检测计划

| 用例 | 平台 | 步骤 | 通过标准 |
| --- | --- | --- | --- |
| Editor 放置 | Editor | 点击地面 | cube 出现在模拟平面上 |
| Anchor 生命周期 | Editor | 添加/删除 anchor | 节点和数据一致 |
| Backend switcher | Editor | 切换 backend | 状态显示正确 |
| OpenXR 启动 | Rokid | 运行 APK | session 状态可见 |
| ARKit availability | iPad | Xcode 运行 | provider/capability 状态可见 |

## 发表要求

- 标题：Godot XR Foundation C01：ARFoundation 风格最小闭环。
- 展示：同一个放置 Demo 使用统一 API，不关心底层 provider。
- 素材：EditorSim 录屏 + Rokid/OpenXR 状态截图。

## 验收标准

- [ ] EditorSim 完整可运行。
- [ ] Rokid/OpenXR 可运行。
- [ ] iPad/ARKit 可运行或输出明确 fallback。
- [ ] 上层放置代码不出现 ARCore/ARKit/OpenXR class。
- [ ] capability flags 可见。
- [ ] 发布说明写明限制。
