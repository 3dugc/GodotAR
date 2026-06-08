# C06 XRI Interaction Slice Spec

状态：Draft

周期：C06

版本：v0.6.0-c06-xri-interaction

建议周期：1-2 周

## 一句话成果

Godot XR Foundation 提供 Unity XRI 风格的基础交互系统：Interaction Manager、Ray/Gaze Interactor、Grab/Simple Interactable，并能在 Rokid/OpenXR、iPad/ARKit、EditorSim 上运行同一个空间交互 Demo。

## 目标设备

| 设备 | 是否必须 | 运行方式 | 备注 |
| --- | --- | --- | --- |
| Rokid / OpenXR | Yes | APK | ray 或 gaze 选择空间 UI |
| iPad / ARKit | Yes | Xcode project / IPA | touch 或 gaze fallback |
| Editor | Yes | Godot editor | mouse ray + grab |
| Android ARCore | Should | APK | touch fallback |

## 本周期做

- `XRInteractionManager`。
- `XRBaseInteractor`。
- `XRRayInteractor` v1。
- `XRGazeInteractor` v1。
- `XRBaseInteractable`。
- `XRSimpleInteractable`。
- `XRGrabInteractable` v1。
- `XRInputReader` v1。
- `demo/08_spatial_ui.tscn`。
- `demo/09_grab_interactable.tscn`。

## 本周期不做

- 不做完整 locomotion。
- 不做复杂 hand tracking gestures。
- 不做 socket 装配系统。
- 不做 bezier/projectile ray。
- 不做 haptics 完整实现。

## 用户故事

- 作为 Unity 项目迁移者，我可以把 XRI 的 Hover/Select/Activate 思路迁移到 Godot。
- 作为 Rokid 用户，我可以用 gaze/ray 操作空间菜单。
- 作为 iPad 用户，我可以用 touch fallback 操作同一套 interactable。
- 作为开发者，我可以在 EditorSim 里用鼠标测试交互。

## API / 接口

新增：

- `XRInteractionManager`
- `XRBaseInteractor`
- `XRRayInteractor`
- `XRGazeInteractor`
- `XRBaseInteractable`
- `XRSimpleInteractable`
- `XRGrabInteractable`
- `XRInputReader`

冻结：

- hover/select/activate/focus 事件命名。
- interactor valid target 查询流程。
- interaction layer mask 基础语义。

## Demo

```text
demo/08_spatial_ui.tscn
demo/09_grab_interactable.tscn
```

## 检测计划

| 用例 | 平台 | 步骤 | 通过标准 |
| --- | --- | --- | --- |
| Rokid ray/gaze UI | Rokid | 指向空间按钮并选择 | hover/select/activate 事件触发 |
| iPad touch fallback | iPad | 点击空间按钮 | select/activate 事件触发 |
| Editor mouse ray | Editor | 鼠标指向按钮 | hover/select 事件触发 |
| Grab basic | Editor | 选择并移动 cube | select_entered/select_exited 正确 |
| Release gates | Rokid/iPad/Android ARCore | 运行同周期 demo | capability panel 和 XRI 状态可见 |

## 发表要求

- 标题：Godot XR Foundation C06：XRI 风格空间交互 Demo。
- 展示：Rokid 上 ray/gaze 操作空间菜单，EditorSim 中 grab interactable，iPad touch fallback。
- 产物：Rokid APK、iPad Xcode/IPA、Editor demo、测试报告。

## 验收标准

- [ ] Rokid/OpenXR gate 已通过。
- [ ] iPad/ARKit gate 已通过。
- [ ] EditorSim 完整运行。
- [ ] Hover/Select/Activate 事件和 XRI 语义一致。
- [ ] XRI 设计引用已记录。
