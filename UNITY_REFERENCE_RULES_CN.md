# Unity 文档反推规则

版本：2026-06-09

目标：当 Godot XR Foundation 在接口、生命周期、provider 划分、能力命名、fallback 行为、交互系统上出现不确定时，优先参考 Unity 的公开文档，逆向其架构思想，而不是照搬某个平台 SDK 的临时做法。

## 参考优先级

## 最新基线巡检

规则：每个周期开始或遇到架构选择时，先查 Unity 官方可见文档中的最高版本。已发行版本优先用于稳定实现；pre-release、preview、experimental 或 unreleased 官方文档也必须进入规划，但需要在 spec/report 里标注稳定性。旧 Unity API 只能作为迁移兼容层，不能压过最新设计。

当前巡检日期：2026-06-09。

| Unity 包 / 文档 | 当前可见最高基线 | 状态 | 本项目对齐要求 |
| --- | --- | --- | --- |
| AR Foundation | stable `com.unity.xr.arfoundation@6.5.0`; pre-release tracking `com.unity.xr.arfoundation@6.6.0-pre.2` | Unity package docs / registry visible; Unity 6000.6 alpha release notes visible | 以 Unity 6.x manager/subsystem 形状为主；`XROrigin` 是主入口；`ARSessionOrigin` 只做 deprecated compatibility shim |
| XR Core Utilities | `com.unity.xr.core-utils@2.6.0` | Unity 6000.6 alpha release notes visible | `XROrigin` / Origin Base / Camera Floor Offset / Camera / Trackables Parent 是坐标系和 trackable world transform 的核心参考 |
| XR Interaction Toolkit | `com.unity.xr.interaction.toolkit@3.5.1` | Unity package manual/changelog visible; newer than the 6000.6 alpha release-note package line | XRI 3.x 的 Interaction Manager、Interactors、Interactables、Input Readers、Near-Far/Ray/Gaze/Screen-space AR 交互是交互层方向 |
| Unity OpenXR Plugin | `com.unity.xr.openxr@1.17.1` | Unity package registry visible; 1.17 package manual remains the current docs line | 采用 feature/extension/provider 能力模型；OpenXR 设备必须证明 AR 路径，不能把 opaque VR runtime 当成 AR 成果 |
| Google ARCore XR Plugin | stable `com.unity.xr.arcore@6.5.0`; pre-release tracking `com.unity.xr.arcore@6.6.0-pre.2` | Unity package docs / registry visible | Android ARCore 是与 ARKit/OpenXR 同级 provider；availability、install、session、camera、planes、raycast、anchors 逐步补齐 |
| Apple ARKit XR Plugin | stable `com.unity.xr.arkit@6.5.0`; pre-release tracking `com.unity.xr.arkit@6.6.0-pre.2` | Unity package docs / registry visible | iOS/iPad ARKit 是与 ARCore/OpenXR 同级 provider；camera/background、planes、raycast、anchors、occlusion/meshing 能力按 provider bridge 接入 |
| Android XR OpenXR Plugin | `com.unity.xr.androidxr-openxr@1.3.1` | Unity 6000.6 alpha release notes visible | 作为 OpenXR AR 设备扩展方向记录；不改变 C00 第一优先级 OpenXR/ARKit/ARCore |

Unity 6.5/6.6 package manuals are the current public package reference for AR Foundation / ARCore / XRI / Android XR / XR Core Utilities, and OpenXR 1.17 is the current OpenXR docs line while the registry has advanced to `com.unity.xr.openxr@1.17.1`. Unity 6.4 package API pages remain the detailed fallback only when a specific newer API page is not visible yet. 若未来 Unity 官方文档出现更高版本，例如 AR Foundation 6.7/7.x、XRI 3.6+、OpenXR 1.18+、ARCore/ARKit 6.7+，先更新本表、cycle spec 和 migration 文档，再实现接口。

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

- Unity 6000.6 alpha release notes: https://unity.com/releases/editor/alpha
- Unity 6000.4 beta release notes: https://unity.com/releases/editor/beta/6000.4.0b4
- Unity AR Foundation 6.5 package overview: https://docs.unity3d.com/Packages/com.unity.xr.arfoundation%406.5/manual/index.html
- Unity AR Foundation pre-release registry line: https://packages.unity.com/com.unity.xr.arfoundation
- Unity AR Foundation 6.5 changelog: https://docs.unity3d.com/Packages/com.unity.xr.arfoundation%406.5/changelog/CHANGELOG.html
- Unity AR Foundation 6.4 `ARSession`: https://docs.unity.cn/Packages/com.unity.xr.arfoundation%406.4/api/UnityEngine.XR.ARFoundation.ARSession.html
- Unity AR Foundation 6.4 `ARSessionOrigin`: https://docs.unity.cn/Packages/com.unity.xr.arfoundation%406.4/api/UnityEngine.XR.ARFoundation.ARSessionOrigin.html
- Unity XR Core Utilities `XROrigin`: https://docs.unity.cn/Packages/com.unity.xr.core-utils%402.5/manual/xr-origin-reference.html
- Unity AR Foundation Subsystems: https://docs.unity.cn/Packages/com.unity.xr.arfoundation%405.0/manual/architecture/subsystems.html
- Unity AR Session component: https://docs.unity3d.com/ja/Packages/com.unity.xr.arfoundation%405.1/manual/features/session.html
- Unity XR architecture: https://docs.unity3d.com/cn/2022.1/Manual/XRPluginArchitecture.html
- Unity OpenXR Plugin 1.17 package overview: https://docs.unity3d.com/Packages/com.unity.xr.openxr%401.17/manual/index.html
- Unity OpenXR package registry line: https://packages.unity.com/com.unity.xr.openxr
- Unity OpenXR Plugin 1.17 changelog: https://docs.unity3d.com/Packages/com.unity.xr.openxr%401.17/changelog/CHANGELOG.html
- Unity AR development overview: https://docs.unity.cn/6000.0/Documentation/Manual/AROverview.html
- Unity ARCore XR Plugin 6.5: https://docs.unity3d.com/Packages/com.unity.xr.arcore%406.5/manual/index.html
- Unity ARCore XR Plugin 6.6 pre-release docs: https://docs.unity3d.com/Packages/com.unity.xr.arcore%406.6/manual/index.html
- Unity ARKit XR Plugin package registry line: https://packages.unity.com/com.unity.xr.arkit
- Unity ARKit XR Plugin 6.6 docs: https://docs.unity3d.com/Packages/com.unity.xr.arkit%406.6/manual/index.html
- Unity XRI 3.5.1 overview: https://docs.unity3d.com/Packages/com.unity.xr.interaction.toolkit%403.5/manual/index.html
- Unity XRI 3.5.1 changelog: https://docs.unity3d.com/Packages/com.unity.xr.interaction.toolkit%403.5/changelog/CHANGELOG.html
- Unity XRI 3.1 overview: https://docs.unity.cn/Packages/com.unity.xr.interaction.toolkit%403.1/manual/index.html
- Unity XR Ray Interactor 3.1: https://docs.unity.cn/Packages/com.unity.xr.interaction.toolkit%403.1/manual/xr-ray-interactor.html
- Unity XRI Input Readers: https://docs.unity.cn/Packages/com.unity.xr.interaction.toolkit%403.1/manual/input-readers.html
