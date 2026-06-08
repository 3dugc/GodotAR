# Spec 驱动执行规划

版本：2026-06-08

目标：把 Godot XR Foundation 的长期计划拆成连续可交付周期。每个周期都必须满足三件事：

- 可以运行：有 demo scene，有设备包或编辑器运行路径。
- 可以检测：有自动/手动检测项，有日志和结果记录。
- 可以发表：有 release note、截图/录屏、可对外讲清楚的成果。

## 核心原则

### 1. 每个周期都是产品切片

不要把周期定义成“完成某个底层模块”。周期必须以可体验成果命名，例如：

- 设备 Smoke Test
- 跨平台平面放置
- Rokid 空间菜单
- Android ARCore 放置
- iOS ARKit 放置
- Unity 迁移样板

底层代码只是交付这个产品切片的实现手段。

### 2. Spec 先于实现

每个周期开始前，必须冻结一个 `Cycle Spec`。冻结后本周期只做 spec 里的内容。临时发现的新想法进入 backlog，不打断当前可交付目标。

### 3. 检测和发表也是需求

检测不是开发结束后的补充，发表也不是额外工作。它们写进 spec，并作为验收条件。

### 4. Provider 能力用 capability flags 暴露

上层不判断平台，不直接调用 ARCore、ARKit、OpenXR、Rokid SDK。所有差异由 provider 上报：

```text
SESSION
CAMERA_POSE
CAMERA_BACKGROUND
PLANE_DETECTION
RAYCAST
ANCHOR
PERSISTENT_ANCHOR
DEPTH
OCCLUSION
LIGHT_ESTIMATION
HAND_TRACKING
GAZE
CONTROLLER
PASSTHROUGH
```

### 5. OpenXR-first，但目标是 AR

OpenXR 是第一优先级底层路线。Rokid、PICO、Quest、Android XR 等设备都优先通过 OpenXR provider 和 device profile 接入。

但本项目不是 VR 运行时兼容项目。若某个 OpenXR runtime 只能提供 opaque VR 渲染，不能 passthrough、see-through、camera background 或 AR fallback，则该周期可以记录“OpenXR 可运行”，但不能发表为 AR 成果。

### 6. 三 Provider 同级第一优先级

OpenXR、ARKit、ARCore 是同级第一优先级。OpenXR 不替代 ARKit/ARCore；ARKit/ARCore 也不阻碍 OpenXR 设备扩展。

每个周期发布前必须至少完成：

- Rokid/OpenXR 运行记录。
- iPad/ARKit 运行记录。
- EditorSim 完整运行记录。
- Android/ARCore smoke 或 capability 记录，C03 起进入必须回归。

### 7. Unity 文档优先

所有设计分歧先查 Unity 文档，再做 Godot 适配。参考顺序：

1. AR Foundation manager/subsystem。
2. AR Session lifecycle。
3. XR Plug-in Architecture。
4. Unity OpenXR Feature。
5. ARCore XR Plugin / ARKit XR Plugin provider model。
6. XR Interaction Toolkit architecture。

## Spec 层级

```text
Product Spec
  - 产品目标、目标设备、上层 API 边界、长期能力矩阵

Platform Specs
  - Rokid/OpenXR Spec
  - Android/ARCore Spec
  - iOS/ARKit Spec
  - EditorSim Spec

Cycle Specs
  - 每 1-2 周一个
  - 每个 cycle 必须能运行、能检测、能发表
```

## 周期节奏

建议节奏：每周期 1 周，复杂真机能力可延长到 2 周，但不能超过 2 周没有可发表成果。

每个周期固定流程：

| 节点 | 内容 | 输出 |
| --- | --- | --- |
| D0 | Spec 冻结 | `specs/cycles/CYCLE_xx_*.md` |
| D1-D2 | 最小可运行切片 | demo scene / first build |
| D3-D4 | 真机检测和修正 | logs / screenshots / test report |
| D5 | 成果发表 | release note / video / package |
| D6-D7 | 缓冲或下周期准备 | backlog / risk update |

## 每周期交付物

每个周期必须有这些文件或资产：

```text
demo/<cycle_demo>.tscn
releases/<cycle_id>/
  README.md
  CHANGELOG.md
  TEST_REPORT.md
  captures/
  logs/
  packages/
specs/cycles/<cycle_spec>.md
```

如果某周期没有真机包，也必须解释原因，并提供 fallback 可运行路径，例如 EditorSim demo。

## Definition of Runnable

满足以下条件才算“可以运行”：

- Godot editor 可打开项目。
- 至少一个 demo scene 可运行。
- 如果本周期目标包含真机，则有对应设备安装包或 Xcode project。
- 运行时 UI 或日志能显示 backend、tracking state、capabilities。
- 失败时能看到明确错误，不是黑屏或静默失败。

## Definition of Detectable

满足以下条件才算“可以检测”：

- 有手动检测步骤。
- 有日志格式。
- 有 capability matrix。
- 有截图/录屏标准。
- 有通过/失败记录。
- 失败项进入 risk/backlog。

建议检测报告结构：

```text
Device
Build
Backend
Capabilities
Test Cases
Pass / Fail
Logs
Screenshots
Known Issues
Next Actions
```

## Definition of Publishable

满足以下条件才算“可以发表”：

- 有一句话成果说明。
- 有 3-5 条本周期完成项。
- 有一张截图或一段 15-60 秒录屏。
- 有安装包或可运行项目路径。
- 有已知限制说明。
- 有下一周期预告。

发表渠道可以是：

- GitHub Release
- README 更新
- 项目周报
- 技术博客
- 短视频/演示录屏
- 内部 demo day

## 第一阶段周期规划

| Cycle | 周期名 | 可运行产物 | 检测重点 | 可发表成果 |
| --- | --- | --- | --- | --- |
| C00 | Device Smoke Test | `00_device_smoke_test` + 三平台包 | 部署链路、backend 状态、日志 | 三平台首次点亮 |
| C01 | Foundation MVP | `01_place_on_plane` + `02_backend_switcher` | 统一 API、EditorSim、OpenXR 初始化 | Godot 版 ARFoundation 最小闭环 |
| C02 | OpenXR AR Devices Slice | `03_openxr_ar_capability_lab` + `04_rokid_ray_place` | OpenXR session、passthrough/blend、头控/射线、capability report | OpenXR-first AR 设备能力实验室 |
| C03 | Android ARCore Slice | `05_android_arcore_place` | camera、plane、raycast、anchor | Android 真机 AR 放置 Demo |
| C04 | iOS ARKit Slice | `06_ios_arkit_place` | camera、plane、raycast、anchor | iOS 真机 AR 放置 Demo |
| C05 | Unity Migration Slice | `07_unity_style_scene` | Unity API 映射、迁移样例 | Unity ARFoundation 迁移样板 |
| C06 | XRI Interaction Slice | `08_spatial_ui` + `09_grab_interactable` | hover/select/grab、UI interaction | XRI 风格空间交互 Demo |

## Spec Gate

每个周期开始前必须回答：

- 用户能看到什么？
- 跑在哪些设备上？
- 失败时如何 fallback？
- 本周期新增哪些 API？
- 哪些 API 本周期冻结？
- 怎么检测？
- 怎么发表？
- 哪些事情明确不做？

回答不完整，不进入实现。

## 发布命名

建议版本：

```text
v0.0.1-c00-device-smoke
v0.1.0-c01-foundation-mvp
v0.2.0-c02-rokid-openxr
v0.3.0-c03-android-arcore
v0.4.0-c04-ios-arkit
v0.5.0-c05-unity-migration
v0.6.0-c06-xri-interaction
```

## 文档清单

- `PRODUCT_ROADMAP_CN.md`：长期路线。
- `DEVICE_BRINGUP_CHECKLIST_CN.md`：真机 bring-up 检查。
- `SPEC_DRIVEN_EXECUTION_CN.md`：Spec 驱动方法。
- `specs/templates/CYCLE_SPEC_TEMPLATE_CN.md`：周期 spec 模板。
- `specs/cycles/`：每个周期的冻结 spec。
