# C04 iOS ARKit Slice Spec

状态：Draft / Implementation in progress

周期：C04

版本：v0.4.0-c04-ios-arkit

建议周期：1-2 周

## 一句话成果

iPhone/iPad 上可以运行真实 ARKit 放置 Demo，看到摄像头背景，检测平面，点击放置 anchor 物体。

## 目标设备

| 设备 | 是否必须 | 运行方式 | 备注 |
| --- | --- | --- | --- |
| iPad / ARKit | Yes | Xcode project / IPA | 第一目标 |
| Rokid / OpenXR | Yes | APK | 必须运行 capability/fallback panel |
| Android ARCore | Should | APK | smoke/capability regression |
| Editor | Yes | EditorSim | fallback |

## 本周期做

- `ARKitProvider` 真机桥接。
- iOS plugin `.gdip` + `.xcframework`。
- camera permission。
- camera background。
- plane detection。
- screen raycast。
- anchor create/remove。
- `demo/06_ios_arkit_place.tscn`。

## 已落地接口 / 场景

- `demo/06_ios_arkit_place.tscn`：iPad/ARKit 优先的放置 Demo；真机使用 `requested_backend=ARKit` / `platform_hint=ipad`，桌面使用 EditorSim fallback，输出 `GXF_ARKIT_PLACE` 结构化日志。
- `demo/06_ios_arkit_place.gd`：通过 Unity-style `ARCameraManager`、`ARRaycastManager`、`ARPlaneManager`、`ARAnchorManager` 完成 camera metadata、screen raycast、plane count、anchor count 和 touch/click/auto placement evidence。
- `GodotARKit` native ARAnchor bridge：`GodotARKitPlugin.create_anchor()` 调用 `GodotARKitSession.addAnchorWithTransform(...)`，由 ARKit plugin 内部执行 `ARSession.addAnchor`，并回传 `trackable_id` / `persistent_id` / native transform。该改动限定在 `ios/plugins/godot_arkit`，不修改 Godot 主干。
- `tools/c00/check_ios_arkit_place_surface.js`：静态保护 C04 iOS ARKit placement demo、`GXF_ARKIT_PLACE` 日志面、ARKit tracking/camera evidence 和 native anchor bridge。

当前限制：

- `GodotARKit` 已提供 native frame/intrinsics/light metadata；真实摄像头背景纹理接入 Godot 渲染管线仍未完成，C04 真机验收时必须用 `camera.native_frame_available` 与实际画面分别记录，不能把 metadata 当作 background render 通过。
- 真机 iPad 运行、签名、录屏证据仍是本周期完成门禁；EditorSim 只证明上层迁移 API 和场景不会坏。

## 本周期不做

- 不做 world map persistence。
- 不做 LiDAR mesh。
- 不做 depth/occlusion。
- 不做 image tracking。

## API / 接口

冻结：

- `ARKitProvider` 对上层返回统一 `ARPlane`、`XRHit`、`ARAnchor`。
- iOS permission error 格式。

## Demo

```text
demo/06_ios_arkit_place.tscn
```

## 检测计划

| 用例 | 平台 | 步骤 | 通过标准 |
| --- | --- | --- | --- |
| Xcode deploy | iOS | 真机运行 | app 启动 |
| Rokid gate | Rokid | 运行同周期 scene | OpenXR capability/fallback 状态可见 |
| Camera background | iOS | 授权摄像头 | 摄像头画面显示 |
| Plane detection | iOS | 扫描地面 | 状态显示 plane count > 0 |
| Raycast | iOS | 点击平面 | 返回 hit |
| Anchor | iOS | 放置 cube | 物体稳定在真实空间 |
| Pause/resume | iOS | 切后台再回来 | session 恢复 |
| Simulator placement dev gate | iOS Simulator | `tools/c00/run_device_cycle.sh ios-simulator-place` | `GXF_ARKIT_PLACE`、`event:"placed"`、`center_screen_raycast.hit=true`、EditorSim plane/anchor evidence；不替代真机 |
| C04 demo static surface | Editor/CI | `node tools/c00/check_ios_arkit_place_surface.js` | `demo/06_ios_arkit_place.tscn`、`GXF_ARKIT_PLACE`、ARKit camera/tracking/anchor evidence surface 存在 |

## 发表要求

- 标题：Godot XR Foundation C04：iOS ARKit 真机放置 Demo。
- 展示：iPhone/iPad AR 放置录屏。
- 产物：Xcode project 或 IPA、测试报告、限制说明。

## 验收标准

- [ ] 真机看到 camera background。
- [ ] iPad/ARKit gate 已通过。
- [ ] Rokid/OpenXR gate 已通过或有 blocked report。
- [ ] 可检测平面。
- [ ] 可点击放置。
- [ ] Anchor 稳定性有测试记录。
