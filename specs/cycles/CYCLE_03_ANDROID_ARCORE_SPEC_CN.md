# C03 Android ARCore Slice Spec

状态：Draft

周期：C03

版本：v0.3.0-c03-android-arcore

建议周期：1-2 周

## 一句话成果

Android 手机/平板上可以运行真实 ARCore 放置 Demo，看到摄像头背景，检测平面，点击放置 anchor 物体。

## 目标设备

| 设备 | 是否必须 | 运行方式 | 备注 |
| --- | --- | --- | --- |
| Android ARCore | Yes | APK | 第一目标 |
| Rokid / OpenXR | Yes | APK | 必须运行 capability/fallback panel |
| iPad / ARKit | Yes | Xcode project | 必须运行 capability/fallback panel |
| Editor | Yes | EditorSim | fallback |

## 本周期做

- `ARCoreProvider` 真机桥接。
- camera permission。
- camera background。
- plane detection。
- screen raycast。
- anchor create/remove。
- `demo/05_android_arcore_place.tscn`。

## 本周期不做

- 不做 depth/occlusion。
- 不做 light estimation。
- 不做 cloud anchor。
- 不做 image tracking。

## API / 接口

冻结：

- `ARCoreProvider` 对上层返回统一 `ARPlane`、`XRHit`、`ARAnchor`。
- Android permission error 格式。

## Demo

```text
demo/05_android_arcore_place.tscn
```

## 检测计划

| 用例 | 平台 | 步骤 | 通过标准 |
| --- | --- | --- | --- |
| Camera background | Android | 启动 app | 摄像头画面显示 |
| Rokid gate | Rokid | 运行同周期 scene | OpenXR capability/fallback 状态可见 |
| iPad gate | iPad | 运行同周期 scene | ARKit capability/fallback 状态可见 |
| Plane detection | Android | 扫描地面 | 状态显示 plane count > 0 |
| Raycast | Android | 点击平面 | 返回 hit |
| Anchor | Android | 放置 cube | 物体稳定在真实空间 |
| Pause/resume | Android | 切后台再回来 | session 恢复 |

## 发表要求

- 标题：Godot XR Foundation C03：Android ARCore 真机放置 Demo。
- 展示：真实手机/平板 AR 放置录屏。
- 产物：APK、测试报告、限制说明。

## 验收标准

- [ ] 真机看到 camera background。
- [ ] Rokid/OpenXR gate 已通过或有 blocked report。
- [ ] iPad/ARKit gate 已通过或有 blocked report。
- [ ] 可检测平面。
- [ ] 可点击放置。
- [ ] Anchor 稳定性有测试记录。
