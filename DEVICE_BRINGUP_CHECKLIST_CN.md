# 设备真机 Bring-up 检查清单

版本：2026-06-08

目标：尽早在 Rokid、iPad、Android 手机/平板上运行，并尽快把 Quest、PICO、Android XR 等 OpenXR 设备纳入 capability report。每个阶段都要有实际产品包，而不是只写库。

硬性规则：

- 每个周期必须跑 Rokid/OpenXR。
- 每个周期必须跑 iPad/ARKit。
- 每个周期必须跑 EditorSim。
- Android/ARCore 是同级第一优先级，C00 确认可用性，C03 完成真机闭环，之后每周期回归。

## 通用规则

- 每次 bring-up 都记录设备型号、系统版本、Godot 版本、插件版本、构建时间。
- 每次构建都保留安装包、日志、截图或录屏。
- 每个平台都先跑 smoke test，再跑 AR feature test。
- 每个 provider 都必须上报 capability flags，不能让业务层猜平台。

建议 capability flags：

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

## 目录建议

```text
releases/
  phase_0_smoke/
    rokid/
    quest_openxr/
    pico_openxr/
    android_arcore/
    ios_arkit/
  phase_1_place_on_plane/
  phase_2_rokid_spatial_menu/
logs/
  rokid/
  android/
  ios/
captures/
  screenshots/
  videos/
```

## Phase 0 Smoke Test

### 场景内容

`demo/00_device_smoke_test.tscn`

必须显示：

- App version
- Build time
- Backend name
- Tracking state
- Device type
- FPS
- XR session initialized: yes/no
- 一个 1m 坐标参考物
- 一个可点击/可凝视按钮

### 验收

| 平台 | 最低验收 |
| --- | --- |
| Rokid | APK 能启动，能看到 3D 内容，OpenXR 或 fallback backend 状态可见 |
| Quest/PICO | 如有设备，APK 能启动并输出 OpenXR capability report |
| Android | APK 能启动，能看到 3D 内容，ARCore plugin availability 可见 |
| iPad | Xcode 能部署，App 能启动，ARKit plugin availability 可见 |
| Editor | 能模拟 raycast 到地面并放置物体 |

## OpenXR AR Device Bring-up

OpenXR 是第一优先级主线，但目标是 AR，不是 VR。设备只有满足以下至少一项才算 AR 路径：

- 支持 optical see-through。
- 支持 video passthrough。
- 支持 camera background。
- 支持真实环境 trackables/raycast/anchor。
- 至少支持明确的 AR fallback，例如 gaze ray + virtual plane，并在 UI 中标记为 fallback。

只支持 opaque VR 渲染的 runtime 只能记录为 OpenXR 可运行，不能发表为 AR 成果。

### 通用 OpenXR 检查

记录：

- 设备型号：
- Runtime：
- OpenXR 版本：
- 支持 blend modes：
- 是否支持 passthrough/see-through：
- 是否支持输入 profile：
- 是否支持 trackables：
- 是否支持 raycast：
- 是否支持 anchors：
- AR Tier：A/B/C/D

### OpenXR 设备列表

| 设备 | 目标 | 备注 |
| --- | --- | --- |
| Rokid | 第一目标 | 优先 OpenXR，必要时 UXR2.0 |
| Quest | 扩展验证 | 重点验证 passthrough、Meta OpenXR Vendors 能力 |
| PICO | 扩展验证 | 重点验证 runtime、passthrough、输入 profile |
| Android XR | Full AR 参考 | 重点验证 `XR_ANDROID_trackables/raycast/anchor` |

## Rokid Bring-up

### 设备信息

记录：

- Rokid 型号：
- 主机型号：Station2 / Station Pro / Android phone / 其他
- 系统版本：
- 连接方式：USB-C / Station / 其他
- 目标发布：AR Store / Rokid Station Store / AR Studio Store / 仅侧载

### 路径判断

优先顺序：

1. 标准 OpenXR：`OpenXRProvider`
2. OpenXR + Rokid profile：`RokidOpenXRProvider`
3. Rokid UXR2.0：`RokidUxrProvider`
4. 传统 Android APK + 头控/射线 fallback

### 构建配置

- Android export preset。
- Gradle build enabled。
- XR mode: OpenXR。
- OpenXR enabled。
- XR shaders enabled。
- OpenXR Vendors plugin installed if needed。
- Vendor 只启用一个，不在同一个 preset 里混多个 vendor。

### Smoke Test 步骤

1. 安装 APK。
2. 启动 app。
3. 记录是否进入 XR session。
4. 记录 `XRServer.find_interface("OpenXR")` 是否成功。
5. 记录 primary interface。
6. 记录 tracking state。
7. 转头测试 3DoF/6DoF。
8. 测试射线、头控、鼠标或手柄输入。
9. 截图/录屏。

### Rokid 产品 Demo 阶段

Phase 2 的 `03_rokid_spatial_menu` 至少包含：

- 空间菜单面板。
- 一个列表或按钮组。
- 射线/头控选择。
- 点击后打开一个 3D 模型或信息卡。
- 支持退出/返回。

Phase 2 调整后的通用 OpenXR demo 为：

```text
demo/03_openxr_ar_capability_lab.tscn
demo/04_rokid_ray_place.tscn
```

其中 `03_openxr_ar_capability_lab` 必须在 Rokid、Quest、PICO 等 OpenXR 设备上尽量运行，并输出 capability report。

## Android ARCore Bring-up

### 设备信息

记录：

- 设备型号：
- Android 版本：
- ARCore/Google Play Services for AR 是否安装：
- 摄像头权限是否正常：

### 构建配置

- OpenJDK 17。
- Android SDK Platform 35。
- Build Tools 35.0.1。
- NDK r28b。
- Godot Android export template。
- Android build template installed。
- ARCore plugin enabled。

### Smoke Test 步骤

1. 安装普通 Godot APK。
2. 启动 smoke test。
3. 验证 `Engine.has_singleton("ARCore")` 或 provider 指定 singleton。
4. 申请 camera 权限。
5. 输出 backend availability。
6. 截图/录屏。

### ARCore Feature Test

`demo/05_android_arcore_place.tscn`

必须测试：

- 摄像头背景。
- 平面检测。
- 屏幕点击 raycast。
- 创建 anchor。
- 物体跟踪稳定性。
- 暂停/恢复。
- 相机遮挡、权限拒绝、tracking limited 状态。

## iPad / iOS ARKit Bring-up

### 设备信息

记录：

- iPhone/iPad 型号：
- iOS/iPadOS 版本：
- Xcode 版本：
- Team ID：
- Bundle ID：

### 构建配置

- macOS + Xcode。
- Godot iOS export templates。
- iOS export preset。
- Bundle ID 和 Team ID。
- ARKit plugin 放在 `res://ios/plugins/`。
- `.gdip` 可被 Godot export preset 检测到。
- Info.plist camera usage description。

### Smoke Test 步骤

1. Godot export 到 Xcode project。
2. Xcode signing。
3. 真机部署。
4. 启动 smoke test。
5. 验证 `Engine.has_singleton("ARKit")` 或 provider 指定 singleton。
6. 输出 backend availability。
7. 截图/录屏。

### 每周期 iPad Gate

每个周期，即使核心功能不是 ARKit，也必须在 iPad 上跑：

- 同名 demo，或
- fallback/capability panel，或
- blocked report。

运行结果必须写入本周期 `TEST_REPORT.md`。

### ARKit Feature Test

`demo/06_ios_arkit_place.tscn`

必须测试：

- 摄像头背景。
- 平面检测。
- 屏幕点击 raycast。
- 创建 anchor。
- 物体跟踪稳定性。
- app pause/resume。
- camera permission denied。

## 日志格式

每个平台都输出统一日志：

```text
[XRFoundation] app_version=0.1.0
[XRFoundation] backend=OpenXR
[XRFoundation] provider=RokidOpenXRProvider
[XRFoundation] session_state=running
[XRFoundation] tracking_state=tracking
[XRFoundation] capabilities=SESSION,CAMERA_POSE,RAYCAST
[XRFoundation] device=...
[XRFoundation] error=...
```

## 阶段发布物检查

每个阶段都必须交付：

- 可运行场景。
- 安装包或 Xcode project。
- 设备截图/录屏。
- 运行日志。
- capability matrix 更新。
- 风险清单更新。

## 阻塞判断

如果某平台 2 天内无法跑通：

- 不阻塞其它平台。
- provider 标记为 `unavailable`。
- fallback 到 EditorSim 或 simple 3D mode。
- 记录阻塞原因：
  - SDK 权限
  - 导出失败
  - native plugin 未加载
  - runtime 不支持
  - 设备型号限制

## 第一周日程

| 天 | 目标 |
| --- | --- |
| D1 | 确认设备型号、安装 Godot/Android/Xcode 环境 |
| D2 | Android 普通 APK + Rokid 普通 APK 跑通 |
| D3 | iOS Xcode 普通 app 跑通 |
| D4 | Rokid OpenXR smoke test |
| D5 | Android ARCore plugin availability + iOS ARKit plugin skeleton |
| D6 | 三平台截图/录屏和日志归档 |
| D7 | 修正 Phase 1 接口冻结文档 |
