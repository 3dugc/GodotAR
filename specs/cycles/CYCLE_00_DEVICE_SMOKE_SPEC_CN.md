# C00 Device Smoke Test Spec

状态：Frozen

周期：C00

版本：v0.0.1-c00-device-smoke

建议周期：3-5 天

## 一句话成果

Rokid、Android 手机/平板、iOS 设备都能运行一个最小 Godot app，并显示 backend、tracking、capability 和日志。

## 目标设备

| 设备 | 是否必须 | 运行方式 | 备注 |
| --- | --- | --- | --- |
| Editor | Yes | Godot editor | 必须可运行 |
| Rokid | Yes | APK | 优先 OpenXR |
| iPad | Yes | Xcode project | 优先 ARKit |
| Android ARCore | Yes | APK | 先确认 plugin availability |

## 本周期做

- 新增 `demo/00_device_smoke_test.tscn`。
- 新增运行时状态面板：app version、cycle、backend、provider、tracking state、capabilities、FPS。
- 明确插件优先边界：C00 不修改 Godot 主干，只通过 addon/provider/native plugin/OpenXR runtime 接入。
- Rokid 构建一个 APK，尝试 OpenXR 初始化。
- iPad 导出 Xcode project，尝试 ARKit provider availability。
- Android 构建一个 APK，确认 ARCore plugin 或 fallback provider 可用性。
- iOS/iPhone 可作为扩展验证，不替代 iPad gate。
- 归档截图、录屏、日志。
- 新增 `tools/c00` 预检、导出、日志采集和 gate 验证脚本。

## 本周期不做

- 不实现真实平面检测。
- 不实现真实 anchor。
- 不要求 camera background 成功。
- 不做最终 UI 设计。
- 不侵入 Godot engine 主干。

## API / 接口

新增：

- `XRFoundation.get_backend_name()`
- provider capability flags
- unified smoke test log format

冻结：

- `XRFoundation.start_session(requested_backend, options)`
- `XRFoundation.stop_session()`

## Demo

场景：

```text
demo/00_device_smoke_test.tscn
```

最小 UI：

- 状态文本面板。
- 一个 1m 坐标参考。
- 一个按钮或 gaze target。
- 一个旋转 cube，用于确认渲染不卡死。

## 已落地接口

- `ARSession.CheckAvailability(...)`
- `ARSession.Install(...)`
- `ARSession.Reset()`
- `ARSession.state()`
- `XRFoundation.check_availability(...)`
- `XRFoundation.install(...)`
- `XRFoundation.reset_session(...)`
- `XRFoundation.get_capabilities()`
- `XRFoundation.get_provider_name()`
- `XRFoundation.get_tracking_state_name()`
- `tools/c00/validate_smoke_log.js`
- `tools/c00/collect_android_smoke.sh`
- `tools/c00/collect_ios_smoke.sh`
- `tools/c00/export_with_godot.sh`

统一日志格式：

```text
GXF_SMOKE|{"cycle":"C00","event":"session_started","backend":"OpenXR","session_state":"Running",...}
```

Rokid gate 必须看到 `backend:"OpenXR"`。

iPad gate 必须看到 `backend:"ARKit"`。

如果看到 `EditorSim`，只能说明应用启动，不算该设备的 AR gate 通过。

## 检测计划

| 用例 | 平台 | 步骤 | 通过标准 |
| --- | --- | --- | --- |
| Editor 启动 | Editor | 运行 scene | 显示 EditorSim backend |
| Rokid APK 启动 | Rokid | 安装并打开 APK | 能看到 3D 内容和 backend 状态 |
| OpenXR availability | Rokid | 查看日志 | 能看到 OpenXR interface 是否可用 |
| iPad Xcode 启动 | iPad | Xcode 部署 | 能看到状态面板 |
| ARKit availability | iPad | 查看日志 | 输出 ARKit available/unavailable |
| Android APK 启动 | Android | 安装并打开 APK | 能看到状态面板 |
| ARCore availability | Android | 查看日志 | 输出 ARCore available/unavailable |

## 发表要求

- 标题：Godot XR Foundation C00：Rokid、Android、iOS 首次点亮。
- 产物：Rokid APK、Android APK、iOS Xcode project 或运行截图。
- 素材：每个平台 1 张截图或 15 秒录屏。
- 文档：`releases/phase_0_smoke/TEST_REPORT.md`。

## 验收标准

- [ ] 三类设备至少有启动记录。
- [ ] Rokid/OpenXR 和 iPad/ARKit 都有启动记录。
- [ ] 日志包含 backend、provider、tracking、capabilities。
- [ ] 设备接入路径属于 Godot addon / Android plugin / iOS plugin / GDExtension / OpenXR vendor plugin；如不是，必须提交最小侵入说明。
- [ ] 每个平台至少一张截图或一段录屏。
- [ ] 失败平台有明确错误和下一步。
