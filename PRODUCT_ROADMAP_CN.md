# Godot XR Foundation 长期落地计划

版本：2026-06-08

目标：参考 Unity AR Foundation 和 XR Interaction Toolkit 的实现方式，在 Godot 中实现一个可长期维护的 AR/XR 兼容层。底层 AR/XR 能力做成可选择插件：ARCore、ARKit、OpenXR/Rokid。上层对项目代码提供统一接口，尽量降低 Unity 项目迁移成本。

## 结论先行

第一期应该按“真机优先、接口稳定、能力渐进”的路线做。

- OpenXR、ARKit、ARCore：三者同级第一优先级。OpenXR 负责所有可用 OpenXR AR 设备；ARKit 负责 iOS/iPadOS；ARCore 负责 Android 手机/平板。
- OpenXR：Rokid、PICO、Quest、Android XR 等都先进入 `OpenXRProvider + device profile + capability flags`，尽力共用同一套 AR provider。
- Rokid：作为 OpenXR-first 的第一台重点设备。Rokid 官方资料显示其空间生态主要适配 OpenXR，也有 UXR2.0 SDK。第一期先用 OpenXR 产出可运行空间 Demo，若具体 Rokid 型号或商店要求必须使用 UXR2.0，再做 `RokidUxrProvider`。
- iPad：作为 ARKit 主线的第一台重点检测设备。每个周期都必须在 iPad 上运行本周期 demo 或 fallback/capability panel。
- Android 手机/平板：走 ARCore provider。第一期实现 camera background、plane、raycast、anchor，并从 C03 起进入每周期回归。
- iOS/iPadOS：走 ARKit provider。第一期实现 camera background、plane、raycast、anchor，并尽早建立 Xcode 真机部署闭环。
- 上层接口：先覆盖 ARSession、XROrigin、ARRaycastManager、ARPlaneManager、ARAnchorManager、ARCameraManager、基础 XRI Ray/Grab。
- 每个阶段都要产出可运行产品，而不是只产出底层库。
- 执行方式采用 Spec 驱动：每个周期必须有冻结 spec，并同时满足“可以运行、可以检测、可以发表”。详见 `SPEC_DRIVEN_EXECUTION_CN.md` 和 `specs/cycles/`。
- 产品边界：目标是 AR，不是 VR，也不以 MR 为产品目标。OpenXR 设备只有在支持 passthrough、see-through、真实空间 trackables/raycast/anchor 或明确 AR fallback 时，才算 AR 成果。
- 发布门禁：每个周期必须在 Rokid/OpenXR 和 iPad/ARKit 上运行并留检测记录。详见 `PROVIDER_PRIORITY_AND_RELEASE_GATES_CN.md`。
- 设计原则：所有架构迷茫和选择，都优先参考 Unity AR Foundation、AR Subsystems、XR Plug-in Architecture、Unity OpenXR Plugin、XR Interaction Toolkit 文档反推。详见 `UNITY_REFERENCE_RULES_CN.md` 和 `XRI_REFERENCE_RULES_CN.md`。

## 外部资料依据

### Godot / OpenXR

- Godot XR 以 `XRServer` 为核心，平台通过 `XRInterface` 注册，项目可用 `XRServer.find_interface()` 找到并初始化接口。  
  https://docs.godotengine.org/en/4.6/tutorials/xr/setting_up_xr.html

- Godot AR/MR 透传推荐通过 `XRInterface.environment_blend_mode` 配置，`ALPHA_BLEND` 和 `ADDITIVE` 用于 AR/MR 场景。  
  https://docs.godotengine.org/en/4.6/tutorials/xr/ar_passthrough.html

- Godot OpenXR Vendors plugin v5.1 已针对 Android XR 做了大量增强，Godot 4.6 开始 Android Khronos OpenXR loader 已进入 Godot 本体。  
  https://godotengine.org/article/godot-xr-update-may-2026/

- Godot OpenXR Vendors plugin 文档说明它是 Godot 4 的 GDExtension，用来提供 vendor-specific OpenXR extensions。  
  https://godotvr.github.io/godot_openxr_vendors/

### Android XR / OpenXR

- Android XR 支持 OpenXR 1.1 和一批 vendor extensions；能力包括 trackables、raycasting、anchor persistence、depth、passthrough、scene meshing、hand tracking、eye gaze 等。  
  https://developer.android.com/develop/xr/openxr

- Android XR trackables 在 Godot OpenXR Vendors plugin 中可提供 plane、raycast、anchor persistence 等能力。  
  https://godotvr.github.io/godot_openxr_vendors/manual/androidxr/trackables.html

### Android / ARCore

- GodotVR 的 ARCore 插件仓库是 Godot 4 ARCore Android Plugin，README 指向 Godot 4.2+ demo、Android build template、Gradle build、插件 singleton wrapper 等路径。  
  https://github.com/GodotVR/godot_arcore

- Godot Android export 推荐使用 OpenJDK 17、Android SDK、Android SDK Platform 35、Build Tools 35.0.1、NDK r28b 等。  
  https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_android.html

### iOS / ARKit

- Godot iOS export 需要 macOS + Xcode，并导出到 Xcode project 进行真机构建。  
  https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_ios.html

- Godot iOS plugin 由 `.gdip`、`.a` 或 `.xcframework` 组成，并可通过 `Engine.get_singleton()` 调用。插件文件必须放在 `res://ios/plugins/` 下。  
  https://docs.godotengine.org/en/4.6/tutorials/platform/ios/ios_plugin.html

### Rokid

- Rokid AR Studio 页面写明多生态支持：主要生态适配 OpenXR，并兼容 MRTK 交互框架。  
  https://studio-test.rokid.com/

- Rokid 官方博客说明 Station2 supports OpenXR and also has a dedicated UXR2.0 SDK。  
  https://global.rokid.com/blogs/station-2/is-there-a-unity-sdk-for-the-max-2ar-glasses-or-station2

- Rokid 应用商店上架指南区分 AR Store、Rokid Station Store、AR Studio Store。空间应用一般是 6DoF 应用，基于 Station Pro + Rokid Max Pro，需集成 UXR2.0 SDK 及以上。  
  https://basecloud.rokidcdn.com/Developer/Rokid%E5%BA%94%E7%94%A8%E5%95%86%E5%BA%97%E4%B8%8A%E6%9E%B6%E6%8C%87%E5%8D%97-V1.1.pdf

### Unity 参考

- Unity AR Foundation 的 manager 模型：manager 负责 subsystem 生命周期，trackable managers 管理 plane、anchor、raycast 等 trackables。  
  https://docs.unity.cn/Packages/com.unity.xr.arfoundation%405.0/manual/architecture/managers.html

- Unity AR Foundation trackables 有新增、更新、移除生命周期，平面、锚点、raycast 等都有对应 manager。  
  https://docs.unity.cn/Packages/com.unity.xr.arfoundation%404.1/manual/trackable-managers.html

- Unity XRI 的 XR Ray Interactor 通过 raycast 远距离选择 interactables，并包含 hover/select 等事件。  
  https://docs.unity.cn/Packages/com.unity.xr.interaction.toolkit%402.0/manual/xr-ray-interactor.html

- Unity XRI 的 Interaction Manager 统一管理 Interactors 和 Interactables，交互状态包含 Hover、Select、Activate、Focus。  
  https://docs.unity.cn/Packages/com.unity.xr.interaction.toolkit%403.0/manual/architecture.html

## 产品分层

```text
业务/迁移层
  - 从 Unity 迁移过来的玩法、放置、交互、UI、数据逻辑

Godot XR Foundation 上层接口
  - XRFoundation
  - ARSession / XRSessionManager
  - XROrigin / XRDeviceRig
  - ARCameraManager
  - ARRaycastManager
  - ARPlaneManager
  - ARAnchorManager
  - XRI: XRRayInteractor / XRGrabInteractable / XRInteractionManager

Provider 能力抽象
  - IARProvider
  - ICameraProvider
  - IRaycastProvider
  - IPlaneProvider
  - IAnchorProvider
  - IInputProvider
  - ILightEstimationProvider
  - IDepthProvider

底层插件
  - EditorSimProvider
  - OpenXRProvider
  - OpenXR AR feature modules
  - RokidOpenXRProvider
  - RokidUxrProvider, optional
  - ARCoreProvider
  - ARKitProvider
```

## 仓库和插件形态

建议拆成 5 个包，降低平台耦合。

| 包 | 内容 | 是否第一期 |
| --- | --- | --- |
| `godot_xr_foundation` | 纯 GDScript 上层接口、manager、simulator、demo | 是 |
| `godot_xr_foundation_openxr` | OpenXR provider，依赖 Godot XRServer 和 OpenXR Vendors | 是 |
| `godot_xr_foundation_arcore` | Android ARCore plugin/GDExtension provider | 是 |
| `godot_xr_foundation_arkit` | iOS ARKit `.xcframework` + `.gdip` provider | 是 |
| `godot_xr_foundation_rokid` | Rokid profile、输入映射、UXR2.0 bridge | 视设备要求 |

第一期可以先把它们放在一个工程中开发，但发布形态要按包拆，避免 ARKit 代码影响 Android 导出，ARCore 代码影响 iOS 导出。

## 设备矩阵

第一天必须锁定具体设备型号。默认矩阵如下：

| 类别 | 最低设备 | 目标路径 | 第一阶段必须跑通 |
| --- | --- | --- | --- |
| Rokid | Station2 + Max 2 或 Station Pro + Max Pro | OpenXR first，必要时 UXR2.0 | OpenXR 启动、渲染、头部姿态、射线输入或 fallback 输入 |
| Quest | Quest 3 / Quest Pro | OpenXR + Meta passthrough/profile | passthrough、输入、capability report |
| PICO | PICO 4/4 Ultra 或可用 OpenXR runtime 设备 | OpenXR + PICO profile | runtime、passthrough、输入能力检测 |
| Android 手机/平板 | 支持 ARCore 的 Android 设备 | ARCore | 相机背景、平面检测、点击放置 |
| iOS/iPadOS | 支持 ARKit 的 iPhone/iPad | ARKit | 相机背景、平面检测、点击放置 |
| Editor | macOS/Windows/Linux | EditorSim | 模拟 plane、raycast、anchor |

## 阶段计划

### Phase 0：真机环境和设备 bring-up，3 到 5 天

目的：第一周内就让每类设备至少运行一个最小 Godot app。

产物：

- `demo/00_device_smoke_test.tscn`
- Rokid APK：能启动、显示立方体、读取 OpenXR tracking 状态
- Android APK：能启动、显示普通 3D/ARCore plugin availability
- iOS Xcode project：能在 iPhone/iPad 上启动并显示普通 3D/ARKit plugin availability
- `DEVICE_BRINGUP_CHECKLIST_CN.md`

验收：

- 每台设备都有安装包和截图/录屏。
- 日志能明确显示 backend：`EditorSim / OpenXR / ARCore / ARKit / RokidOpenXR`。
- 没有具体 AR 能力也可以，但必须完成部署链路。

关键任务：

- 安装 Godot 4.6+、export templates、Android SDK、OpenJDK 17、Xcode。
- 配置 Android one-click deploy。
- 配置 iOS export + Xcode signing。
- Rokid 先尝试标准 OpenXR；若失败，记录 runtime、loader、系统版本、设备型号。

### Phase 1：统一接口 MVP，2 到 3 周

目的：上层接口先稳定，让业务代码不直接依赖 ARCore/ARKit/OpenXR。

产物：

- `XRFoundation` autoload
- `XRSessionManager`
- `XRDeviceRig`
- `ARCameraManager`
- `ARRaycastManager`
- `ARPlaneManager`
- `ARAnchorManager`
- `ARTrackable / ARPlane / ARAnchor / ARRaycastHit`
- `demo/01_place_on_plane.tscn`
- `demo/02_backend_switcher.tscn`

验收：

- EditorSim 可模拟 plane/raycast/anchor。
- Android ARCore 和 iOS ARKit provider 如果 native 插件未完成，也要有 mock bridge 和 availability 状态。
- OpenXR provider 能初始化并设置 AR/MR blend mode。
- 同一份上层代码可以调用 `ARRaycastManager.raycast()` 和 `ARAnchorManager.add_anchor()`。

第一期产品输出：

- “跨平台 AR 放置 Demo”：点击/凝视放置一个模型。
- “Provider Switcher Demo”：运行时显示当前 backend、tracking state、支持能力。

### Phase 2：OpenXR AR Devices 首个空间产品，2 到 4 周

目的：尽早证明 OpenXR-first AR 路线。Rokid 是第一目标设备，同时把 Quest/PICO/Android XR 纳入 capability report。

产物：

- `OpenXRProvider` feature modules
- `OpenXRDeviceProfile`
- `OpenXRCapabilityReport`
- `RokidOpenXRProfile`
- `MetaQuestOpenXRProfile` 草案
- `PicoOpenXRProfile` 草案
- Rokid export preset
- Rokid input profile 草案
- `demo/03_openxr_ar_capability_lab.tscn`
- `demo/04_rokid_ray_place.tscn`

验收：

- Rokid 上可启动 OpenXR session。
- Quest/PICO 如有设备，能输出 capability report。
- 可显示空间 UI 面板。
- 支持头控/射线/手柄/鼠标至少一种选择方式。
- 若设备支持 plane/raycast/anchor，则接入；若不支持，提供 gaze ray + virtual plane fallback。
- VR-only runtime 必须明确标记为非 AR，不计入 AR 产品完成度。

第一期产品输出：

- “Rokid 空间菜单 Demo”：可选择、可打开页面、可放置简单模型。

Rokid 决策点：

- 如果标准 OpenXR 足够：继续 `RokidOpenXRProvider`。
- 如果商店/6DoF/手势必须 UXR2.0：启动 `RokidUxrProvider`，但仍实现同一上层接口。
- 如果某型号只有 3DoF：标记为 `tracking_mode = ORIENTATION_ONLY`，上层启用 fixed-distance placement fallback。

### Phase 3：ARCore 真机闭环，2 到 4 周

目的：Android 手机/平板成为第一个完整 handheld AR 目标。

产物：

- `ARCoreProvider`
- Android plugin wrapper
- ARCore plane/raycast/anchor bridge
- camera background bridge
- `demo/05_android_arcore_place.tscn`

验收：

- Android ARCore 设备上看到摄像头背景。
- 检测水平/垂直平面。
- 屏幕点击 raycast 到真实平面。
- 创建 anchor 后物体稳定跟踪。
- 失去 tracking 时上层收到 `LIMITED / NONE`。

产品输出：

- “Android AR 物体放置 Demo”：可作为 Unity ARFoundation 放置类项目的迁移样板。

### Phase 4：ARKit 真机闭环，2 到 5 周

目的：iPhone/iPad 支持完整 handheld AR。

产物：

- `ARKitProvider`
- `ios/plugins/GodotXRFoundationARKit/`
- `.gdip` + `.xcframework`
- ARKit plane/raycast/anchor bridge
- camera background bridge
- `demo/06_ios_arkit_place.tscn`

验收：

- iOS 真机上看到摄像头背景。
- 检测水平/垂直平面。
- 屏幕点击 raycast 到真实平面。
- 创建 anchor 后物体稳定跟踪。
- 能通过 Xcode 快速调试日志。

产品输出：

- “iOS AR 物体放置 Demo”。

风险：

- Godot iOS plugin 需要和 export template/header 版本匹配。
- ARKit 原生 texture 到 Godot 渲染管线的接入可能比 Android 更耗时。
- 因此 iOS 部署链路必须 Phase 0 就做，不能等接口写完。

### Phase 5：Unity 迁移兼容层，3 到 6 周

目的：让 Unity 项目迁移更顺。

产物：

- Unity 名称风格 alias：
  - `ARSession`
  - `XROrigin`
  - `ARRaycastManager`
  - `ARPlaneManager`
  - `ARAnchorManager`
  - `XRRayInteractor`
  - `XRGrabInteractable`
- Unity 类型映射：
  - `Pose` → `Transform3D`
  - `TrackableId` → `StringName`
  - `TrackingState` → enum
  - `TrackableType` → flags
- `MIGRATION_UNITY.md` 扩展版
- `demo/07_unity_style_scene.tscn`

验收：

- 一个 Unity ARFoundation 典型放置脚本可在 30 分钟内改写到 Godot。
- 上层 API 不出现 ARCore/ARKit/OpenXR vendor class。

产品输出：

- “Unity ARFoundation 迁移样板项目”。

### Phase 6：XRI 交互和空间 UI，3 到 6 周

目的：支持 Rokid 和后续 XR 设备的空间交互。

产物：

- `XRInteractionManager`
- `XRBaseInteractor`
- `XRRayInteractor`
- `XRGazeInteractor`
- `XRDirectInteractor`
- `XRGrabInteractable`
- `XRSimpleInteractable`
- `XRSocketInteractor`
- `XRUIInteractor`
- `XRInputReader`
- `demo/08_spatial_ui.tscn`
- `demo/09_grab_interactable.tscn`

验收：

- Rokid/OpenXR 可用 ray/gaze 操作 UI。
- Android/iOS 可用 touch 模拟同一套 interaction event。
- Interactable 有 hover/select/activate/deactivate 事件。
- Interaction Manager 负责统一状态切换，交互逻辑不散落在每个对象脚本里。

产品输出：

- “空间控制台 Demo”：适合后续项目作为入口界面。

### Phase 7：高级 AR 能力，按业务优先级迭代

候选能力：

- Depth / occlusion
- Light estimation
- Image tracking
- Object tracking
- Persistent anchors
- Scene mesh
- Hand tracking
- Eye gaze
- QR/marker tracking
- Multi-user anchors
- Recording/replay for automated tests

建议优先级：

1. Light estimation：提升真实感，成本中等。
2. Depth/occlusion：产品效果明显，但平台差异大。
3. Persistent anchors：如果业务需要固定空间内容，优先级升高。
4. Hand tracking：Rokid/Android XR 产品体验重要，但不要影响第一期。

## 第一季度排期建议

| 周期 | 重点 | 产品产出 |
| --- | --- | --- |
| W1 | Phase 0，三类设备部署闭环 | 三平台 smoke test 包 |
| W2-W3 | Phase 1，统一接口 MVP | 跨平台放置 Demo |
| W4-W5 | Phase 2，Rokid/OpenXR | Rokid 空间菜单 Demo |
| W6-W7 | Phase 3，ARCore | Android AR 放置 Demo |
| W8-W10 | Phase 4，ARKit | iOS AR 放置 Demo |
| W11-W12 | Phase 5 初版 | Unity 迁移样板 |

## 每阶段必须保留的产品输出

每个阶段都要留下能演示的包和场景：

- `.apk` for Rokid/OpenXR
- `.apk` for Android ARCore
- Xcode project 或 `.ipa` for iOS
- `demo/*.tscn`
- `docs/*.md`
- 截图/录屏
- 日志样本

建议建立目录：

```text
releases/
  phase_0_smoke/
  phase_1_place_on_plane/
  phase_2_rokid_spatial_menu/
  phase_3_android_arcore_place/
  phase_4_ios_arkit_place/
```

## 能力矩阵

| 能力 | EditorSim | Rokid/OpenXR | Android ARCore | iOS ARKit |
| --- | --- | --- | --- | --- |
| Session | P0 | P0 | P0 | P0 |
| Camera pose | P0 | P0 | P1 | P1 |
| Camera background | P0 mock | P1 passthrough/blend | P2 | P3 |
| Plane detection | P0 mock | P2 if supported | P2 | P3 |
| Raycast | P0 | P1 fallback, P2 real | P2 | P3 |
| Anchor | P0 | P2 if supported | P2 | P3 |
| Persistent anchor | Later | Later | Later | Later |
| Depth/occlusion | Later | Later | Later | Later |
| Light estimation | Later | Later | Later | Later |
| Hand/gaze input | P1 mock | P2 | Later | Later |

说明：

- P0 表示 smoke test 阶段。
- P1/P2/P3 表示第几阶段进入产品 demo。
- Rokid 的 plane/raycast/anchor 取决于具体设备、runtime 和 SDK，不能假设所有型号都有。

## 技术风险和缓解

### 风险 1：Rokid OpenXR 能力和 UXR2.0 能力边界不清

缓解：

- Phase 0 同时跑标准 OpenXR smoke test 和 Rokid 官方 demo。
- 若 OpenXR 无法获得 6DoF/手势/空间能力，单独建立 `RokidUxrProvider`。
- 上层不感知差异，只看 capability flags。

### 风险 2：ARCore 插件成熟度不足

缓解：

- 先使用 GodotVR/godot_arcore 做验证。
- 若 API 不完整，走自研 Android plugin/GDExtension。
- Android provider 暴露稳定接口，不把插件类泄漏到上层。

### 风险 3：ARKit Godot 4 原生插件需要开发成本

缓解：

- Phase 0 先打通 iOS 普通导出。
- Phase 1 加 ARKit plugin skeleton。
- Phase 4 集中处理 camera texture、hit test、anchor。

### 风险 4：Godot C# 移动端限制影响 Unity C# 迁移

缓解：

- 第一阶段核心用 GDScript。
- Unity C# 迁移先转成 Godot 调用层，不急于完整 C# 移植。
- 需要 C# 时先做 Android/iOS export spike。

### 风险 5：各平台坐标系、米制单位、tracking origin 不一致

缓解：

- 所有 provider 输出统一 `Transform3D`，1 unit = 1 meter。
- 所有 trackable 都挂在 `XRDeviceRig/XROrigin3D` 下。
- 建立坐标系测试场景：前后左右、水平/垂直平面、anchor 稳定性。

## 第一阶段具体任务清单

### 任务 A：设备确认

- 记录 Rokid 型号、系统版本、是否 Station2/Station Pro、是否 Max/Max Pro。
- 记录 Android 手机/平板型号、Android 版本、ARCore 支持状态。
- 记录 iPhone/iPad 型号、iOS/iPadOS 版本、ARKit 支持状态。

### 任务 B：构建链路

- Godot 4.6+。
- Android SDK + OpenJDK 17 + export templates。
- Xcode + iOS export templates + signing。
- Rokid APK 安装方式：ADB、Rokid Store、或 Station 文件安装。

### 任务 C：最小运行包

- `00_device_smoke_test`：
  - 显示 backend 名称。
  - 显示 tracking status。
  - 显示 FPS。
  - 显示一个 1m 坐标参考。

### 任务 D：接口冻结 v0.1

- 冻结 `XRFoundation.start_session()`。
- 冻结 `ARRaycastManager.raycast()`。
- 冻结 `ARAnchorManager.add_anchor()`。
- 冻结 `ARPlaneManager.planes_changed`。
- 冻结 capability flags。

## 立即下一步

1. 确认 Rokid 具体型号和目标发布市场。
2. 在当前 Godot project 中加入 `00_device_smoke_test.tscn`。
3. 准备 Android/Rokid export presets。
4. 准备 iOS export preset 和 Xcode project。
5. 第一周内产出三台设备的运行截图/录屏。
