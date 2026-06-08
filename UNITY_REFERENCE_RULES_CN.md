# Unity 文档反推规则

版本：2026-06-08

目标：当 Godot XR Foundation 在接口、生命周期、provider 划分、能力命名、fallback 行为、交互系统上出现不确定时，优先参考 Unity 的公开文档，逆向其架构思想，而不是照搬某个平台 SDK 的临时做法。

## 参考优先级

### 1. AR Foundation

Unity AR Foundation 定义了面向业务层的 AR manager 和组件。它本身不实现平台能力，而是通过 provider plug-in 提供具体实现。

本项目规则：

- 上层必须像 AR Foundation 一样稳定。
- `ARSessionManager` 控制 AR 生命周期。
- `ARPlaneManager`、`ARRaycastManager`、`ARAnchorManager` 管理对应 trackables。
- 上层不直接调用 OpenXR、ARKit、ARCore SDK。

### 2. AR Subsystems / Provider

Unity 的 subsystem/provider 模型是本项目最重要的架构参考：

- subsystem 定义生命周期和脚本接口。
- provider plug-in 负责平台实现。
- descriptor/capability 用于运行时能力判断。

本项目规则：

| Unity | Godot XR Foundation |
| --- | --- |
| `SubsystemWithProvider` | Provider + Feature Module |
| `XRLoader` | `XRFoundation` provider loader |
| `XRSessionSubsystem` | Session provider |
| `XRCameraSubsystem` | Camera provider |
| `XRPlaneSubsystem` | Plane provider |
| `XRRaycastSubsystem` | Raycast provider |
| `XRAnchorSubsystem` | Anchor provider |
| subsystem descriptor | capability flags |

### 3. XR Plug-in Architecture

Unity XR 插件架构强调：provider plug-in 实现统一 subsystem 接口，应用代码通过 common interface 跨设备复用。

本项目规则：

- OpenXR、ARKit、ARCore 是同级 provider。
- Rokid、Quest、PICO 是 OpenXR provider 下的 device profile。
- iPad/iPhone 是 ARKit provider 下的 device target。
- Android 手机/平板是 ARCore provider 下的 device target。

### 4. Unity OpenXR Feature

Unity OpenXR Plugin 使用 feature 模型管理 extension、构建配置和 native hook。

本项目规则：

- OpenXR Provider 内部拆 feature module：
  - Core
  - AR Blend
  - Passthrough
  - Input Profiles
  - Trackables
  - Raycast
  - Anchors
  - Depth/Occlusion
  - Light Estimation
- 每个 module 明确 required/optional extensions。
- 每个 module 只向上暴露 capability，不暴露 vendor 类型。

### 5. AR Session 生命周期

Unity AR Session 负责 AR 生命周期；其它功能可以启停，但 session 是总开关。Unity 也要求检查设备支持状态。

本项目规则：

- `XRFoundation.start_session()` 是唯一 session 入口。
- session state 至少包含：
  - `NONE`
  - `CHECKING_AVAILABILITY`
  - `UNSUPPORTED`
  - `READY`
  - `SESSION_INITIALIZED`
  - `SESSION_TRACKING`
  - `FAILED`
- 任何 provider 都必须先做 availability/capability 检查。

### 6. ARCore / ARKit Provider Packages

Unity 明确 ARCore XR Plugin 和 ARKit XR Plugin 是 AR Foundation 的平台 provider。

本项目规则：

- ARCore 和 ARKit 不作为 OpenXR 的 fallback。
- ARCore、ARKit、OpenXR 三者同级第一优先级。
- ARCore/ARKit 的 native bridge 可以不同，但上层 manager API 必须相同。

### 7. XR Interaction Toolkit

Unity XRI 是本项目交互层的主要参考。ARFoundation 层负责真实世界 tracking/raycast/anchor，XRI 层负责用户如何 hover/select/activate/grab/UI。

本项目规则：

- 必须实现 `XRInteractionManager` 统一调度。
- 必须保留 Interactor / Interactable 的分工。
- 交互状态采用 Hover、Select、Activate、Focus。
- `XRRayInteractor` 是 Rokid/OpenXR 空间菜单的第一交互方式。
- `XRGazeInteractor` 是无手柄设备 fallback。
- `XRGrabInteractable`、`XRSimpleInteractable`、`XRUIInteractor` 按 XRI 语义实现。
- 输入参考 XRI input reader/action model，避免直接绑定具体设备按钮。

## 决策记录模板

每个争议设计都要写一条记录：

```text
Decision:
Question:
Unity Reference:
Godot Constraint:
Chosen Design:
Alternatives:
Risk:
Review Date:
```

建议保存到：

```text
specs/decisions/
```

## 当前引用资料

- Unity AR Foundation package overview: https://docs.unity3d.com/cn/2023.2/Manual/com.unity.xr.arfoundation.html
- Unity AR Foundation Subsystems: https://docs.unity.cn/Packages/com.unity.xr.arfoundation%405.0/manual/architecture/subsystems.html
- Unity AR Session component: https://docs.unity3d.com/ja/Packages/com.unity.xr.arfoundation%405.1/manual/features/session.html
- Unity XR architecture: https://docs.unity3d.com/cn/2022.1/Manual/XRPluginArchitecture.html
- Unity OpenXR Features: https://docs.unity.cn/Packages/com.unity.xr.openxr%401.7/manual/features.html
- Unity AR development overview: https://docs.unity3d.com/es/2019.4/Manual/AROverview.html
- Unity ARCore XR Plugin overview: https://docs.unity3d.com/es/2020.1/Manual/com.unity.xr.arcore.html
- Unity XRI Architecture: https://docs.unity.cn/Packages/com.unity.xr.interaction.toolkit%403.0/manual/architecture.html
- Unity XR Ray Interactor: https://docs.unity.cn/Packages/com.unity.xr.interaction.toolkit%402.0/manual/xr-ray-interactor.html
- Unity XRI Input Readers: https://docs.unity.cn/Packages/com.unity.xr.interaction.toolkit%403.1/manual/input-readers.html
