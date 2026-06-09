# C02 OpenXR AR Devices Slice Spec

状态：Draft

周期：C02

版本：v0.2.0-c02-openxr-ar-devices

建议周期：1-2 周

## 一句话成果

OpenXR AR Provider 可以在 Rokid 上运行空间菜单 Demo，并对 PICO、Quest、Android XR 等 OpenXR 设备输出 capability report；如果设备支持 passthrough/see-through，就进入 AR 路径，否则明确降级为非 AR。

## 目标设备

| 设备 | 是否必须 | 运行方式 | 备注 |
| --- | --- | --- | --- |
| Rokid | Yes | APK | 第一目标 |
| iPad / ARKit | Yes | Xcode project | 必须运行 capability/fallback panel |
| Quest | Should | APK | 验证 OpenXR passthrough/profile |
| PICO | Should | APK | 验证 OpenXR runtime/profile |
| Android XR | Optional | APK | 验证 Android XR extensions |
| Editor | Yes | EditorSim | 同场景 fallback |
| Android | Optional | APK | 非 AR 模式 fallback |

## 本周期做

- `OpenXRProvider` feature module 草案。
- `RokidOpenXRProfile`。
- `MetaQuestOpenXRProfile` 草案。
- `PicoOpenXRProfile` 草案。
- OpenXR capability report。
- Rokid export preset。
- 基础输入：gaze、ray、controller 三选一，至少打通一种。
- `demo/03_openxr_ar_capability_lab.tscn`。
- `demo/04_rokid_ray_place.tscn`。
- 如果真实 plane/raycast 不可用，则提供 virtual plane fallback。

## 已落地接口 / 场景

- `XRInputProfile`：根据 capability report 输出 `primary`、`modes`、`xr_select` / `xr_activate` 动作名，作为 Unity XRI input profile 的轻量迁移落点。
- `XRFoundation.get_device_profile()`：从 provider capability 的 `device_profile` 输出 Rokid/Quest/PICO/Android XR 等设备画像名。
- `XRFoundation.get_tracking_mode()`：输出 `position_and_rotation` / `not_tracking` / `unknown`，作为 Unity AR/XR tracking mode 迁移占位。
- `demo/03_openxr_ar_capability_lab.tscn`：OpenXR/Rokid 优先的能力实验室，输出 `GXF_OPENXR_LAB` 日志，状态面板显示 AR tier、passthrough、vendor singletons、plane source、input profile 和中心 raycast。
- `demo/04_rokid_ray_place.tscn`：Rokid ray/gaze placement demo，输出 `GXF_ROKID_PLACE` 日志，中心 raycast 命中真实 plane 或 `virtual_floor_fallback` 后可通过 `xr_select` 或首次命中自动放置 marker。
- `tools/c00/check_openxr_provider_surface.js` 已把两个 C02 demo 和 OpenXR AR evidence surface 纳入静态 gate；它不能替代 Rokid 真机运行，但能防止 demo/日志面被后续改动破坏。

## 本周期不做

- 不要求手势完整支持。
- 不要求持久化 anchor。
- 不要求上架商店。
- 不要求 UXR2.0，除非标准 OpenXR 不满足启动和输入。
- 不把 VR-only runtime 当作 AR 成果。

## API / 接口

新增：

- `XRInputProfile`
- `XRFoundation.get_tracking_mode()`
- `XRFoundation.get_device_profile()`
- `XRFoundation.get_capabilities()`
- `OpenXRCapabilityReport`（以 `capabilities.openxr_*` 字典字段形式先落地）

冻结：

- OpenXR capability reporting。
- Gaze/ray select 事件格式。

## Demo

```text
demo/03_openxr_ar_capability_lab.tscn
demo/04_rokid_ray_place.tscn
```

## 检测计划

| 用例 | 平台 | 步骤 | 通过标准 |
| --- | --- | --- | --- |
| OpenXR session | Rokid | 启动 APK | session running |
| iPad gate | iPad | 运行同周期 scene | ARKit capability/fallback 状态可见 |
| AR tier | Rokid | 查看状态面板 | 输出 A/B/C/D，不误报 AR |
| Head pose | Rokid | 转头 | UI 相对空间稳定 |
| Select input | Rokid | gaze/ray/controller 选择 | 菜单按钮响应 |
| Fallback plane | Rokid | 放置模型 | 模型放到 virtual plane |
| Capability report | Quest/PICO | 启动 APK | 输出 blend/passthrough/input 状态 |
| Demo static surface | Editor/CI | `node tools/c00/check_openxr_provider_surface.js` | `demo/03_openxr_ar_capability_lab.tscn` / `demo/04_rokid_ray_place.tscn` 和日志 marker 存在 |

## 发表要求

- 标题：Godot XR Foundation C02：OpenXR-first AR 设备能力实验室。
- 展示：Rokid 设备实拍或录屏，附 Quest/PICO capability report 如可用。
- 产物：Rokid APK、OpenXR capability report、已知能力矩阵。

## 验收标准

- [ ] Rokid 真机可运行。
- [ ] iPad 真机可运行 capability/fallback panel。
- [ ] 至少一种输入可选择 UI。
- [ ] 空间菜单可操作。
- [ ] 若 OpenXR 不足，给出 UXR2.0 provider 决策。
- [ ] VR-only runtime 明确标记为非 AR。
