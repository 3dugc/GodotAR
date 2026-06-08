# C04 iOS ARKit Slice Spec

状态：Draft

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
