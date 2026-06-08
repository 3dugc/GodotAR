# 阶段工作清单

版本：2026-06-08

原则：

- OpenXR、ARKit、ARCore 三者同级 P0。
- Rokid 是 OpenXR 主线每周期必测设备。
- iPad 是 ARKit 主线每周期必测设备。
- Android/ARCore 是 P0 主线，C03 起每周期回归。
- 每个阶段都必须可运行、可检测、可发表。
- 架构选择优先参考 Unity AR Foundation、AR Subsystems、OpenXR Plugin、XRI 文档。

## C00：设备 Smoke Test

目标：三条主线先点亮，建立设备部署和日志闭环。

工作：

- 新建 `demo/00_device_smoke_test.tscn`。
- 实现运行状态面板：cycle、provider、device profile、session state、tracking state、capabilities、error。
- Rokid 构建 APK，尝试 OpenXR session。
- iPad 导出 Xcode project，确认 ARKit provider availability。
- Android 构建 APK，确认 ARCore provider availability。
- EditorSim 跑通基础模拟。
- 统一日志格式和截图/录屏归档规则。

可运行产物：

- Rokid APK。
- iPad Xcode project 或 IPA。
- Android APK。
- EditorSim smoke scene。

检测：

- Rokid/OpenXR 是否启动。
- iPad/ARKit 是否启动。
- Android/ARCore availability。
- EditorSim 是否显示状态面板。

发表成果：

- “Rokid、iPad、Android 三平台首次点亮”。
- 每个平台至少一张截图或一段短录屏。

## C01：Foundation MVP

目标：完成 ARFoundation 风格的最小上层接口闭环。

工作：

- 冻结 `XRFoundation.start_session()` / `stop_session()`。
- 实现 `XRSessionManager`。
- 实现 `XRDeviceRig` / `XROrigin3D` 风格 rig。
- 实现 `ARRaycastManager`。
- 实现 `ARPlaneManager`。
- 实现 `ARAnchorManager`。
- 新增 `ARCameraManager` 初版。
- EditorSim 支持模拟 plane、raycast、anchor。
- OpenXR provider 支持 session 状态和 blend mode。
- ARKit/ARCore provider 至少输出 capability/fallback。

可运行产物：

- `demo/01_place_on_plane.tscn`。
- `demo/02_backend_switcher.tscn`。
- Rokid/OpenXR capability 或 fallback。
- iPad/ARKit capability 或 fallback。

检测：

- EditorSim 点击放置物体。
- Anchor 创建/删除。
- Backend switcher 显示 provider 状态。
- Rokid 和 iPad 都能运行同周期 scene 或 fallback panel。

发表成果：

- “Godot 版 ARFoundation 最小闭环”。
- 展示同一份上层代码不关心底层 provider。

## C02：OpenXR AR Devices Slice

目标：OpenXR 作为 P0 主线跑出第一版 AR 设备能力实验室，Rokid 优先。

工作：

- 扩展 `OpenXRProvider`。
- 建立 OpenXR feature modules：
  - Core。
  - AR Blend。
  - Passthrough。
  - Input Profiles。
  - Trackables 草案。
  - Raycast 草案。
  - Anchors 草案。
- 建立 device profiles：
  - `RokidOpenXRProfile`。
  - `GenericOpenXRProfile`。
  - `MetaQuestOpenXRProfile` 草案。
  - `PicoOpenXRProfile` 草案。
  - `AndroidXROpenXRProfile` 草案。
- 输出 `OpenXRCapabilityReport`。
- 实现 virtual plane fallback。
- 准备 Rokid export preset。

可运行产物：

- `demo/03_openxr_ar_capability_lab.tscn`。
- `demo/04_rokid_ray_place.tscn`。
- Rokid APK。
- iPad fallback/capability panel。

检测：

- Rokid/OpenXR session running。
- Rokid 输出 AR Tier A/B/C/D。
- Rokid 至少一种输入可选择 UI。
- iPad/ARKit 同周期 fallback/capability panel 可运行。
- Quest/PICO 如有设备，输出 capability report。

发表成果：

- “OpenXR-first AR 设备能力实验室”。
- Rokid 实机录屏 + capability matrix。

## C03：Android ARCore Slice

目标：Android 手机/平板完成真实 ARCore 放置闭环。

工作：

- 实现 `ARCoreProvider` 真机桥接。
- Camera permission。
- Camera background。
- Plane detection。
- Screen raycast。
- Anchor create/remove。
- Pause/resume。
- Tracking limited/none 状态上报。
- 保持 Rokid 和 iPad release gates。

可运行产物：

- `demo/05_android_arcore_place.tscn`。
- Android APK。
- Rokid fallback/capability panel。
- iPad fallback/capability panel。

检测：

- Android 显示摄像头背景。
- 扫描真实平面。
- 点击平面返回 hit。
- 创建 anchor 后物体稳定。
- Rokid/OpenXR gate。
- iPad/ARKit gate。

发表成果：

- “Android ARCore 真机放置 Demo”。
- 录屏展示真实平面放置和 anchor 稳定性。

## C04：iPad / ARKit Slice

目标：iPad 完成真实 ARKit 放置闭环。

工作：

- 实现 `ARKitProvider` 真机桥接。
- iOS plugin `.gdip` + `.xcframework`。
- Camera permission。
- Camera background。
- Plane detection。
- Screen raycast。
- Anchor create/remove。
- App pause/resume。
- 保持 Rokid/OpenXR gate。
- Android/ARCore smoke regression。

可运行产物：

- `demo/06_ios_arkit_place.tscn`。
- iPad Xcode project 或 IPA。
- Rokid fallback/capability panel。
- Android smoke/capability。

检测：

- iPad 显示摄像头背景。
- iPad 检测真实平面。
- iPad 点击平面放置 anchor 物体。
- Rokid/OpenXR gate。
- EditorSim fallback。

发表成果：

- “iPad ARKit 真机放置 Demo”。
- 录屏展示 iPad 真实环境放置。

## C05：Unity Migration Slice

目标：让 Unity ARFoundation 项目能按固定模式迁移到 Godot XR Foundation。

工作：

- 完善 Unity API 映射文档。
- 提供 Unity 风格 alias 或 wrapper：
  - `ARSession`。
  - `XROrigin`。
  - `ARRaycastManager`。
  - `ARPlaneManager`。
  - `ARAnchorManager`。
- 类型映射：
  - `Pose` 到 `Transform3D`。
  - `TrackableId` 到 `StringName` 或 GUID wrapper。
  - `TrackingState` enum。
  - `TrackableType` flags。
- 建立 migration sample。
- 对照 Unity 文档写 decision records。

可运行产物：

- `demo/07_unity_style_scene.tscn`。
- Rokid/OpenXR run。
- iPad/ARKit run。
- EditorSim run。

检测：

- Unity 风格放置脚本可迁移。
- 上层代码不出现平台 SDK 类型。
- Rokid/iPad gates。

发表成果：

- “Unity ARFoundation 迁移样板”。
- 展示 Unity 代码到 Godot 代码的迁移前后对照。

## C06：XRI Interaction Slice

目标：实现 Unity XRI 风格基础交互系统。

工作：

- 实现 `XRInteractionManager`。
- 实现 `XRBaseInteractor`。
- 实现 `XRRayInteractor`。
- 实现 `XRGazeInteractor`。
- 实现 `XRBaseInteractable`。
- 实现 `XRSimpleInteractable`。
- 实现 `XRGrabInteractable`。
- 实现 `XRInputReader`。
- Hover/Select/Activate/Focus 状态。
- Interaction layer mask。
- Straight ray line visual。
- Touch/mouse/gaze fallback。

可运行产物：

- `demo/08_spatial_ui.tscn`。
- `demo/09_grab_interactable.tscn`。
- Rokid APK：ray/gaze 空间菜单。
- iPad build：touch/gaze fallback。
- EditorSim：mouse ray + grab。

检测：

- Rokid hover/select/activate 空间 UI。
- iPad touch fallback 触发 select/activate。
- EditorSim mouse ray hover/select/grab。
- Android touch fallback smoke。

发表成果：

- “XRI 风格空间交互 Demo”。
- 展示 Rokid 空间菜单和 EditorSim 抓取。

## C07：高级 AR 能力第一批

目标：按产品需要补齐更真实的 AR 表现。

工作候选：

- Light estimation。
- Depth / occlusion。
- Persistent anchors。
- Image tracking。
- Scene mesh。
- Hand tracking。
- Eye gaze。

建议优先级：

1. Light estimation。
2. Depth / occlusion。
3. Persistent anchors。
4. Image tracking。
5. Hand tracking / eye gaze。

可运行产物：

- 每个能力单独 demo。
- Rokid/OpenXR capability 或 fallback。
- iPad/ARKit 对应能力优先验证。
- Android/ARCore 对应能力回归。

检测：

- 每个能力必须有 capability flag。
- 不支持的平台必须明确 fallback。
- 不允许静默失败。

发表成果：

- 单能力技术演示和能力矩阵更新。

## 持续工作：每周期都做

- 更新 capability matrix。
- 更新 release notes。
- 更新 test report。
- 更新 known issues。
- 更新 Unity reference decisions。
- Rokid/OpenXR gate。
- iPad/ARKit gate。
- EditorSim gate。
- Android/ARCore regression。
- 打包并保留截图/录屏/日志。

