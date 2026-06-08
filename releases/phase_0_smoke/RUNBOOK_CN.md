# C00 Device Smoke Runbook

目标：让第一阶段每次都能在 Rokid/OpenXR 和 iPad/ARKit 上运行、检测、归档。

## 运行入口

Godot 主场景已经设置为：

```text
res://demo/00_device_smoke_test.tscn
```

也可以在编辑器中手动运行该场景。

## 工具链预检

```bash
tools/c00/preflight.sh
```

如果本机 Godot 不在 PATH，可以设置：

```bash
GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot tools/c00/preflight.sh
```

导出 preset 说明：

```text
tools/c00/EXPORT_PRESETS_CN.md
```

如果还没有 `export_presets.cfg`，先生成 C00 starter，然后用 Godot editor 复核并保存：

```bash
node tools/c00/write_export_presets_template.js --output export_presets.cfg
```

确认 C00 preset 名称和平台：

```bash
node tools/c00/check_export_presets.js --gate all --file export_presets.cfg
```

## 一键执行

设备机上优先用 spec runner：

```bash
tools/c00/run_device_cycle.sh editor
```

```bash
tools/c00/run_device_cycle.sh rokid
```

```bash
GODOT_SOURCE_DIR=/path/to/godot \
DEVICE=<ipad-uuid-or-name> \
APP_PATH=builds/ipad/GodotXRFoundation.app \
tools/c00/run_device_cycle.sh ipad
```

`all` 会按 iPad/ARKit、Rokid/OpenXR 顺序执行；如需同时跑 Android ARCore，增加 `INCLUDE_ANDROID_ARCORE=1`。

```bash
GODOT_SOURCE_DIR=/path/to/godot \
DEVICE=<ipad-uuid-or-name> \
APP_PATH=builds/ipad/GodotXRFoundation.app \
tools/c00/run_device_cycle.sh all
```

`all` 模式默认会继续执行后续 gate，即使前一个 gate 失败；最后会自动运行 `tools/c00/verify_phase_evidence.js` 并生成 `C00_PHASE_REPORT.md`。如果希望失败即停，设置 `CONTINUE_ON_FAILURE=0`。
如需在设备 gate 前先跑本地模拟器，设置 `INCLUDE_EDITOR_SIM=1`。

## 插件优先边界

C00 不修改 Godot 主干。

设备接入路径必须记录为：

- Godot addon
- Android plugin
- iOS plugin
- GDExtension
- OpenXR vendor plugin
- engine patch

如果出现 `engine patch`，本周期必须附带最小侵入说明，否则不能标记为通过。

## EditorSim / 模拟器

模拟器用于没有设备时验证上层接口和 Unity 迁移代码：

```bash
tools/c00/run_device_cycle.sh editor
```

或：

```bash
tools/c00/collect_editor_smoke.sh 15
```

模拟器会通过 `--xr-platform=simulator` 选择 `EditorSim` backend，提供模拟 floor plane、raycast、anchor 和 tracking。它可以作为开发 gate，但不能替代 Rokid/OpenXR 或 iPad/ARKit 真机通过标准。

## Rokid / OpenXR

通过标准：

- 设备中能看到状态面板和旋转 cube。
- 面板显示 `Session: Running`。
- 面板显示 `Backend: OpenXR`。
- 日志包含 `GXF_SMOKE`，且 JSON 中 `backend` 为 `OpenXR`。
- 日志 `runtime.cmdline_xr_args` 包含 `--xr-platform=rokid`，并能看到 Godot 版本、rendering method、OpenXR/XR shader 设置。
- `capabilities.ar_product_path` 为 `true` 时，才算 AR 产品路径通过。

建议设置：

```gdscript
XRFoundation.start_session(XRFoundationTypes.Backend.OPENXR, {
	"platform_hint": "rokid",
	"prefer_ar": true,
	"passthrough": true,
})
```

可选启动参数：

```text
--xr-platform=rokid
```

Rokid Android export preset 必须设置：

```text
command_line/extra_args="--xr-platform=rokid"
```

这样无论通过 launcher、`monkey` 还是设备桌面启动，Godot 都会优先选择 OpenXR 路径，而不是在 Android 上先尝试 ARCore。

自动采集和验证：

```bash
tools/c00/run_device_cycle.sh rokid
```

默认会同时采集日志、gate 报告、截图和 15 秒录屏；如设备不支持 `screenrecord`，请手动补录屏。
Rokid gate 默认要求截图和录屏都存在；临时调试可用 `ALLOW_MISSING_MEDIA=1` 降级为 warning，但不能作为发表通过结果。

底层脚本：

```bash
APK_PATH=builds/rokid/c00.apk tools/c00/collect_android_smoke.sh rokid org.godotengine.godotxrfoundation 30
```

失败判定：

- `Backend: EditorSim`：Godot 应用启动了，但 OpenXR gate 未通过。
- `ar_product_path=false` 且 blend 只有 `opaque`：OpenXR 渲染启动了，但还不是 AR 结果。
- OpenXR interface unavailable：检查 Godot OpenXR 设置、Android export XR mode、Rokid runtime、OpenXR Vendors 插件。

## iPad / ARKit

通过标准：

- iPad 上能看到状态面板和旋转 cube。
- 面板显示 `Session: Running`。
- 面板显示 `Backend: ARKit`。
- 日志包含 `GXF_SMOKE`，且 JSON 中 `backend` 为 `ARKit`。
- 日志包含 runtime metadata，能确认 Godot 版本、`--xr-platform=ipad` 启动参数和 viewport XR 状态。
- `capabilities.native_plugin=true`。
- `capabilities.runtime="ARKit"` 或 `capabilities.arkit_supported=true`。
- `capabilities.arkit_tracking_state` 和 `capabilities.arkit_tracking_reason` 能说明 ARKit 当前是 `normal`、`limited` 还是 `not_available`。

失败判定：

- `Backend: EditorSim`：iOS app 启动了，但 ARKit native plugin 没有被 Godot 识别。
- `singleton_registered=false` 且 `interface_registered=false`：检查 `.gdip`、`.xcframework`、Xcode linking、iOS plugin singleton 名称。
- `arkit_tracking_state=limited`：ARKit 已启动但尚未稳定跟踪，保留 `arkit_tracking_reason`，按原因检查光照、纹理、设备运动或重定位。
- `export_presets.cfg` 中看不到 `GodotARKit`：iOS preset 没有启用 ARKit plugin，不能算 iPad/ARKit gate。

自动采集和验证：

```bash
GODOT_SOURCE_DIR=/path/to/godot APP_PATH=builds/ipad/GodotXRFoundation.app tools/c00/run_device_cycle.sh ipad <device>
```

底层脚本：

```bash
APP_PATH=builds/ipad/GodotXRFoundation.app tools/c00/collect_ios_smoke.sh <device> org.godotengine.godotxrfoundation 30
```

`collect_ios_smoke.sh` 默认传入 `--xr-platform=ipad`；如需改成 iPhone 验证，可设置 `IOS_XR_PLATFORM=iphone`。
如果本机安装了 `idevicescreenshot`，脚本会自动截图；否则请手动补一张截图或 15 秒录屏。
手动素材可以通过 `MANUAL_MEDIA_PATH=/path/to/ipad.mov` 传给采集脚本；没有任何媒体素材时，iPad gate 默认失败。

## 归档材料

每台设备至少保存：

- 一张截图或 15 秒录屏。
- 过滤 `GXF_SMOKE` 后的日志。
- 设备型号、系统版本、Godot 版本、插件版本。
- 使用的扩展路径：addon / Android plugin / iOS plugin / GDExtension / OpenXR vendor plugin / engine patch。
- 是否通过 gate。

脚本生成的 gate 报告在：

```text
releases/phase_0_smoke/evidence/
```

自动产物命名：

```text
<gate>-<timestamp>.log
<gate>-<timestamp>.md
<gate>-<timestamp>.png
<gate>-<timestamp>.mp4
```

`.md` 报告会包含两个门禁结果：

- smoke log gate：验证 `GXF_SMOKE`、backend、native plugin、ARKit/OpenXR 证据。
- evidence bundle gate：验证截图和录屏是否存在并非空文件。

smoke log gate 还会展示 `Runtime Metadata`，用于确认 Godot 版本、启动参数和 XR/rendering project setting 是否符合设备 gate。

## C00 总验收

Rokid/OpenXR 和 iPad/ARKit 都跑完后，执行：

```bash
node tools/c00/verify_phase_evidence.js
```

该命令会扫描 `releases/phase_0_smoke/evidence/` 中最新的 Rokid/iPad 日志和媒体证据，并生成：

```text
releases/phase_0_smoke/C00_PHASE_REPORT.md
```

只有这个总报告显示 `PASS`，C00 才能作为可发表结果。单台设备 gate 通过但另一台缺证据时，C00 仍然不能标记完成。

## 参考原则

- Unity `ARSession` 的 `CheckAvailability` 和 `Install` 模型，用于统一生命周期判断。
- Unity `ARRaycastManager.Raycast` 的结果由调用方传入/接收列表，结果按距离优先；Godot 当前返回 `Array[XRHit]`，语义保持接近。
- Unity `XROrigin`/`ARSessionOrigin` 的核心职责是把 session space 映射到场景空间；Godot 使用 `XROrigin3D` 实现同一边界。
- Godot OpenXR AR/Passthrough 通过 environment blend mode 表达 AR/MR 背景能力；只有 opaque 不能算 AR 产品通过。
- Godot iOS 插件必须放在 `res://ios/plugins`，并通过 `.gdip` + `.xcframework` 暴露给 Godot，再用 `Engine.get_singleton()` 访问。

## 资料

- Unity ARSession: https://docs.unity.cn/Packages/com.unity.xr.arfoundation%406.1/api/UnityEngine.XR.ARFoundation.ARSession.html
- Unity ARRaycastManager: https://docs.unity.cn/Packages/com.unity.xr.arfoundation%406.0/api/UnityEngine.XR.ARFoundation.ARRaycastManager.html
- Unity XR Origin: https://docs.unity3d.com/cn/2023.2/Manual/xr-origin.html
- Godot AR/Passthrough: https://docs.godotengine.org/en/4.4/tutorials/xr/ar_passthrough.html
- Godot iOS plugins: https://docs.godotengine.org/en/4.4/tutorials/platform/ios/ios_plugin.html
