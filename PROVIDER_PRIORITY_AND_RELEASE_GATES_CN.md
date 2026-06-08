# Provider 第一优先级与发布门禁 Spec

版本：2026-06-08

目标：明确 Godot XR Foundation 的第一优先级不是某个单一设备，而是三条底层 Provider 主线：

- OpenXR
- ARKit
- ARCore

其中 Rokid 是 OpenXR 主线的优先检测设备，iPad 是 ARKit 主线的优先检测设备。每个周期必须能在 Rokid 和 iPad 上运行并留下检测结果，作为发布门禁。ARCore 也是第一优先级 Provider，并在 Android 手机/平板上持续建设和回归。

## 优先级

| 优先级 | Provider | 优先设备 | 目标 |
| --- | --- | --- | --- |
| P0 | OpenXR Provider | Rokid | 支持所有可用 OpenXR AR 设备的基础，包括 Rokid、PICO、Quest、Android XR 等 |
| P0 | ARKit Provider | iPad | 支持 iOS/iPadOS handheld AR，优先 iPad 真机 |
| P0 | ARCore Provider | Android 手机/平板 | 支持 Android handheld AR |
| P0 | EditorSim Provider | Desktop Editor | 保证日常开发、测试、CI 和无设备 fallback |

说明：

- Rokid 不是独立顶层架构，而是 OpenXR Provider 下的 device profile。
- iPad 不是独立顶层架构，而是 ARKit Provider 下的优先验证设备。
- Android 手机/平板不是独立顶层架构，而是 ARCore Provider 下的优先验证设备。
- 后续 PICO、Quest、VIVE、Lynx、Android XR 等都应通过 OpenXR Provider 的 device profile 扩展。

## 发布门禁

每个周期发布前必须完成：

| Gate | 要求 | 不通过时 |
| --- | --- | --- |
| Rokid OpenXR Run Gate | 周期 demo 至少能在 Rokid 上启动，显示 backend、capability、错误或 fallback 状态 | 不发布正式 cycle，只能发布 blocked report |
| iPad ARKit Run Gate | 周期 demo 至少能在 iPad 上启动，显示 backend、capability、错误或 fallback 状态 | 不发布正式 cycle，只能发布 blocked report |
| EditorSim Run Gate | 周期 demo 在 EditorSim 完整运行 | 不发布 |
| Capability Report Gate | 输出 provider capability report | 不发布 |
| Unity Reference Gate | 架构选择已对照 Unity 文档并记录理由 | 不发布 |

如果某周期功能主要开发 OpenXR，也仍要在 iPad 上跑同一个 demo 或 fallback 状态面板。反过来，如果某周期功能主要开发 ARKit，也仍要在 Rokid 上跑同一个 demo 或 fallback 状态面板。

## 每周期必须运行的矩阵

| 周期 | Rokid/OpenXR | iPad/ARKit | Android/ARCore | EditorSim |
| --- | --- | --- | --- | --- |
| C00 Device Smoke | Must run | Must run | Must run if Android device available | Must run |
| C01 Foundation MVP | Must run | Must run | Should run | Must run |
| C02 OpenXR AR Devices | Must run | Must run fallback/capability | Should run fallback/capability | Must run |
| C03 Android ARCore | Must run fallback/capability | Must run fallback/capability | Must run | Must run |
| C04 iOS ARKit | Must run fallback/capability | Must run | Should run fallback/capability | Must run |
| C05 Unity Migration | Must run | Must run | Should run | Must run |
| C06 XRI Interaction | Must run | Must run touch/fallback | Should run touch/fallback | Must run |

## 统一 Demo 要求

每个 demo 必须至少包含一个平台状态面板：

```text
Cycle:
Provider:
Device Profile:
Session State:
Tracking State:
Capabilities:
AR Tier:
Fallback:
Last Error:
Unity Reference:
```

这保证即使某个平台暂时不支持本周期核心能力，也能运行、检测并说明原因。

## 失败处理

如果 Rokid 或 iPad 不能运行：

1. 本周期状态改为 `Blocked` 或 `Partial`。
2. 仍需发布 blocked report，但不标记为正式完成。
3. blocked report 必须包含：
   - 设备型号
   - 系统版本
   - 构建版本
   - 日志
   - 截图或失败录屏
   - 疑似原因
   - 下一步

## ARCore 的第一优先级含义

ARCore 与 OpenXR、ARKit 同级第一优先级，但检测节奏允许按设备条件调整：

- C00 必须确认 Android/ARCore availability。
- C01 开始同一套 manager API 必须兼容 ARCore provider。
- C03 必须完成 Android ARCore 真机放置闭环。
- C03 之后每周期应至少跑 smoke/capability regression。

## 设计决策顺序

所有迷茫或存在多个实现路径时，按以下顺序决策：

1. Unity AR Foundation 文档。
2. Unity AR Subsystems / XR Plug-in Architecture 文档。
3. Unity OpenXR Plugin 文档。
4. Godot XR/OpenXR 当前能力。
5. 平台原生 SDK 文档。
6. 最小可运行产品切片。

如果 Godot 和 Unity 概念不一致，优先保留 Unity 的上层接口形状，同时让底层实现符合 Godot 的运行机制。

