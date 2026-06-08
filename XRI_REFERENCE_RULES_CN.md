# Unity XRI 反推规则

版本：2026-06-08

目标：Godot XR Foundation 的交互层要参考 Unity XR Interaction Toolkit，也就是 XRI。上层项目迁移时，不仅 ARFoundation 风格的 session/plane/raycast/anchor 要像 Unity，交互系统也要尽量保留 XRI 的 mental model。

## 结论

Godot 交互层采用 XRI 风格：

```text
XRInteractionManager
  - 统一注册和调度 Interactors / Interactables

XRBaseInteractor
  - XRRayInteractor
  - XRDirectInteractor
  - XRGazeInteractor
  - XRSocketInteractor
  - XRUIInteractor

XRBaseInteractable
  - XRGrabInteractable
  - XRSimpleInteractable
  - XRSocketTarget
  - XRUIButtonInteractable

Input Readers
  - Action-based input
  - Device/profile input
  - Manual/simulated input
```

## XRI 核心概念

### Interaction Manager

Unity XRI 中，Interaction Manager 是 Interactors 和 Interactables 的中介。它负责注册、反注册、计算有效目标，并触发交互状态变化。

本项目规则：

- 必须实现 `XRInteractionManager`。
- Interactor 和 Interactable 默认注册到场景中第一个 manager。
- 支持多个 manager，但第一期默认一个。
- 状态切换必须由 manager 统一处理，不鼓励 Interactor 直接调用 Interactable 的业务方法。
- C00 已提供最小 smoke surface：`XRInteractionManager`、`XRRayInteractor`、`XRGrabInteractable`、hover/select/activate 事件和静态检查脚本 `tools/c00/check_xri_api_surface.js`。

### Interactor

Interactor 表示用户“用什么方式”发起交互，例如射线、直接触碰、凝视、socket。

本项目规则：

- `XRRayInteractor`：远距离选择、UI、空间菜单，Rokid/OpenXR 优先。
- `XRDirectInteractor`：近距离抓取，后续用于手柄/手势。
- `XRGazeInteractor`：Rokid/光学 AR/无手柄设备 fallback。
- `XRSocketInteractor`：吸附、装配、放置点。
- `XRUIInteractor`：Godot UI/3D UI 交互。

### Interactable

Interactable 表示场景中“可被交互”的对象。

本项目规则：

- `XRGrabInteractable`：抓取、移动、释放。
- `XRSimpleInteractable`：按钮、开关、可点击物。
- `XRSocketTarget`：可被 socket 接收。
- Interactable 不直接关心设备是 Rokid、iPad、Android、Quest 或 PICO。

## 状态模型

按 XRI 参考，交互状态必须至少包含：

| 状态 | 含义 |
| --- | --- |
| Hover | Interactor 指向/接近 Interactable |
| Select | Interactor 选择/抓取/按下 Interactable |
| Activate | 对已选中或 hover 的对象执行上下文动作 |
| Focus | 当前被交互系统聚焦的对象 |

事件命名采用 XRI 风格：

```text
hover_entering
hover_entered
hover_exiting
hover_exited
select_entering
select_entered
select_exiting
select_exited
activated
deactivated
focus_entered
focus_exited
```

Godot signal 可以用 snake_case，但语义要对应 XRI。

## Update Loop

参考 XRI，Interaction Manager 每帧负责：

1. 收集所有 Interactor 的 valid targets。
2. 对 targets 排序。
3. 清理无效 hover/select/focus。
4. 进入新的 hover/select/focus。
5. 处理 activate/deactivate。
6. 处理 interaction strength。

本项目第一期可以简化，但不能把状态逻辑散落到每个 Interactor 里。

## 输入模型

XRI 3.x 将输入抽象为 input readers，可来自 Input Action Reference、Input Action、Object Reference、Manual Value、Unused。

本项目规则：

- `XRInputReader` 作为统一输入读取接口。
- 支持 action-based input。
- 支持 device/profile input，用于 OpenXR interaction profiles。
- 支持 manual/simulated input，用于 EditorSim 和 iPad touch fallback。
- 所有 Interactor 读取 `select`、`activate`、`ui_press`、`scroll` 等语义动作，而不是读取平台按钮名。

## Ray Interactor 规则

参考 XRI 的 XR Ray Interactor：

- 支持 interaction layer mask。
- 支持 max raycast distance。
- 支持 closest-only 或 multi-hover。
- 支持 keep selected target valid。
- 支持 force grab，远距离对象可移动到手/射线 attach 点。
- 支持 line visual。
- 第一阶段至少实现 straight line。
- 后续扩展 projectile curve 和 bezier curve。

Rokid/OpenXR 第一优先：

- `XRRayInteractor` 必须能在 Rokid 上作为主要交互方式运行。
- 如果没有手柄，使用 `XRGazeInteractor` + dwell/select fallback。

## Direct / Socket / UI

第一期之后按优先级实现：

1. `XRRayInteractor`：空间菜单、远距离选择、放置。
2. `XRGazeInteractor`：Rokid/iPad fallback。
3. `XRUIInteractor`：3D UI。
4. `XRDirectInteractor`：近距离抓取。
5. `XRSocketInteractor`：装配、放置点、吸附。

## 与 ARFoundation 层的关系

XRI 不替代 ARFoundation 层，而是使用它：

- ARFoundation 提供 session、camera、raycast、plane、anchor。
- XRI 提供 hover/select/activate/grab/ui。
- AR placement 可以用 `ARRaycastManager`。
- XRI ray 可以命中 UI、Interactable，也可以调用 AR raycast 放置真实空间对象。

## 每周期检测要求

从 C00 开始保留 XRI smoke surface；从 C06 开始，每周期增加完整 XRI regression：

- Rokid/OpenXR：ray 或 gaze 可以 hover/select 空间 UI。
- iPad/ARKit：touch 或 gaze fallback 可以 select UI。
- EditorSim：mouse ray 可以 hover/select/grab。
- Android/ARCore：touch fallback 可以 select UI。

## Unity 参考资料

- XRI Architecture: https://docs.unity.cn/Packages/com.unity.xr.interaction.toolkit%403.0/manual/architecture.html
- XR Ray Interactor: https://docs.unity.cn/Packages/com.unity.xr.interaction.toolkit%402.0/manual/xr-ray-interactor.html
- XR Interaction Manager API: https://docs.unity3d.com/ja/Packages/com.unity.xr.interaction.toolkit%402.0/api/UnityEngine.XR.Interaction.Toolkit.XRInteractionManager.html
- XRI Input Readers: https://docs.unity.cn/Packages/com.unity.xr.interaction.toolkit%403.1/manual/input-readers.html
- Unity Learn Interactors / Interactables: https://learn.unity.com/course/vr-curricular-framework-resources/tutorial/using-interactors-and-interactables-with-the-xr-interaction-toolkit
