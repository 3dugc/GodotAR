# C01 Foundation MVP Spec

状态：Draft

周期：C01

版本：v0.1.0-c01-foundation-mvp

建议周期：1-2 周

Unity 对齐基线：以 Unity 官方可见的最新 AR Foundation / XR Core Utilities / XR Interaction Toolkit / OpenXR 文档和 alpha/beta release notes 为目标；当前 C01 以 Unity package registry `dist-tags.latest` 作为前向设计基线：`com.unity.xr.arfoundation@6.6.0-pre.2`、`com.unity.xr.arcore@6.6.0-pre.2`、`com.unity.xr.arkit@6.6.0-pre.2`、`com.unity.xr.interaction.toolkit@3.5.1`、`com.unity.xr.openxr@1.17.1`。稳定 fallback 线为 Unity 6.x `com.unity.xr.arfoundation@6.5.0`、`com.unity.xr.arcore@6.5.0`、`com.unity.xr.arkit@6.5.0` 和 `com.unity.xr.core-utils@2.6.0`。在 6.5/6.6 对应 API 页面尚不可见时，用 Unity 6.4 package API pages 补足细节。`XROrigin` 是主入口，`ARSessionOrigin` 只作为 deprecated 迁移 shim。若官方出现更高 released、pre-release、preview 或 unreleased 文档，后续 spec 必须前移基线。

## 一句话成果

同一份上层代码可以通过 Godot XR Foundation 完成 session、raycast、plane、anchor 的最小闭环，并在 EditorSim 和 OpenXR fallback 下运行。

## 目标设备

| 设备 | 是否必须 | 运行方式 | 备注 |
| --- | --- | --- | --- |
| Editor | Yes | Godot editor | 完整闭环 |
| Rokid / OpenXR | Yes | APK | OpenXR 启动或 fallback |
| iPad / ARKit | Yes | Xcode project | ARKit availability 或 fallback |
| Android ARCore | Should | APK | provider availability |

## 本周期做

- `ARRaycastManager.screen_raycast()` 和 `raycast()` 稳定。
- `ARPlaneManager.get_all_planes()` 稳定。
- `ARAnchorManager.add_anchor()` 稳定。
- `ARCameraManager` 初版。
- `XROrigin` 作为 Unity 6.x 风格 session-space/world-space 入口稳定，`ARSessionOrigin` 仅作为 deprecated 迁移 shim。
- `demo/01_place_on_plane.tscn`。
- `demo/02_backend_switcher.tscn`。
- EditorSim 中支持地面 plane、raycast、anchor。
- OpenXR provider 支持 session 状态和 blend mode。

## 本周期不做

- 不要求 ARCore/ARKit camera background。
- 不要求 Rokid 真实空间 plane。
- 不做复杂交互系统。

## API / 接口

新增：

- `ARCameraManager`
- `XRFoundation.get_capabilities()`
- `XRFoundation.capabilities_changed`
- `ARRaycastManager.Raycast(screen_position, results, trackable_types)`
- `ARRaycastManager.Raycast(ray_dictionary_or_transform, results, trackable_types)`
- `ARAnchorManager.AttachAnchor(plane, pose)`
- `ARAnchorManager.GetDescriptor()`
- `XROrigin.Camera`
- `XROrigin.Origin`
- `XROrigin.TrackablesParent`
- `XROrigin.MoveCameraToWorldLocation(...)`
- `XROrigin.RotateAroundCameraUsingOriginUp(...)`
- `XROrigin.MakeContentAppearAt(...)`
- `ARSessionOrigin.MakeContentAppearAt(...)`
- `XRRayInteractor.TryGetCurrent3DRaycastHit(result_array)`

冻结：

- `ARRaycastManager.raycast(origin, direction, max_results)`
- `ARRaycastManager.screen_raycast(camera, screen_position, max_results)`
- `ARAnchorManager.add_anchor(transform, attached_trackable)`
- `ARPlaneManager.get_all_planes()`
- `XROrigin.GetCamera()`
- `XROrigin.GetTrackablesParent()`

## Demo

```text
demo/01_place_on_plane.tscn
demo/02_backend_switcher.tscn
```

## 当前落地状态

- `demo/01_place_on_plane.tscn` 已落地为 EditorSim-first 的可运行放置 demo；同一份脚本只调用 `ARSession`、`ARRaycastManager`、`ARPlaneManager`、`ARAnchorManager` 和 `XROrigin` 上层接口，并输出 `GXF_C01_PLACE` 日志。
- `demo/02_backend_switcher.tscn` 已落地为 backend 选择/切换 demo；可在 EditorSim、OpenXR/Rokid、Android ARCore、iOS ARKit 之间切换 requested backend，并把 requested 与实际 provider/fallback 写入 `GXF_C01_BACKEND` 日志。
- `demo/boot.gd` 已加入 `place_on_plane` / `c01_place` / `backend_switcher` / `c01_backend` 路由，导出包可通过 `--xr-scene=<alias>` 启动对应成果。
- `tools/c00/check_c01_demo_surface.js` 和 `tools/c00/run_static_gates.js --gate all` 已覆盖 C01 demo 的场景、节点、manager、boot route、导出清单和日志标记。
- `tools/c00/collect_c01_editor_smoke.sh` 已落地 C01 EditorSim evidence 采集入口；它会运行两个 C01 场景并用 `validate_smoke_log.js --gate c01-place` / `--gate c01-backend` 生成 Markdown/JSON 报告。
- `tools/c00/run_phase1_priority_ar_lab.sh` 已落地 iPad/ARKit + Rokid/OpenXR 第一优先级真机 lane；它默认等待并恢复设备、运行 `ipad` / `ipad-place` / `rokid` / `rokid-place`，输出 `C01_PRIORITY_AR_REPORT.md`，但不替代包含 Android/ARCore 的完整 Phase 1 completion audit。
- `tools/c00/import_priority_ar_evidence.sh` 已落地优先真机 lane 的手动证据导入入口；当 Xcode/ADB 自动 collector 失败但现场有日志、截图/录屏和 device profile 时，可导入并复用同一套 `verify_phase_evidence.js` 聚合验证。

## 检测计划

| 用例 | 平台 | 步骤 | 通过标准 |
| --- | --- | --- | --- |
| Editor 放置 | Editor | 点击地面 | cube 出现在模拟平面上 |
| Anchor 生命周期 | Editor | 添加/删除 anchor | 节点和数据一致 |
| Backend switcher | Editor | 切换 backend | 状态显示正确 |
| OpenXR 启动 | Rokid | 运行 APK | session 状态可见 |
| ARKit availability | iPad | Xcode 运行 | provider/capability 状态可见 |
| C01 静态保护 | 本机 | `node tools/c00/check_c01_demo_surface.js` | C01 场景、boot route、manager 和日志 surface 均通过 |
| C01 Godot 运行 | 本机/Godot | `Godot --headless --path . --xr-mode off --quit --scene res://demo/01_place_on_plane.tscn` 与 `... --scene res://demo/02_backend_switcher.tscn` | 两个 C01 场景可一帧启动并输出 `GXF_C01_PLACE` / `GXF_C01_BACKEND` |
| C01 证据采集 | 本机/Godot | `tools/c00/collect_c01_editor_smoke.sh` | 生成 `c01-place-*.md/json`、`c01-backend-*.md/json` 和 `c01-editor-*.md`，且 validator 通过 |
| C01 优先真机 lane | 设备机 | `tools/c00/run_phase1_priority_ar_lab.sh --device "iPad M4" --wait-devices` | 生成 `C01_PRIORITY_AR_REPORT.md`，并验证 `ipad`、`ipad-place`、`rokid`、`rokid-place`；Android/ARCore 仍由完整 Phase 1 audit 补齐 |
| C01 手动证据导入 | 设备机/本机 | `tools/c00/import_priority_ar_evidence.sh --rokid-log ... --ipad-log ...` | 手动证据被复制到标准 evidence 目录，并生成同一份 `C01_PRIORITY_AR_REPORT.md`；缺失真机日志/媒体/profile 时保持 NOT_READY |

## 发表要求

- 标题：Godot XR Foundation C01：ARFoundation 风格最小闭环。
- 展示：同一个放置 Demo 使用统一 API，不关心底层 provider。
- 素材：EditorSim 录屏 + Rokid/OpenXR 状态截图。

## 验收标准

- [ ] EditorSim 完整可运行。
- [ ] Rokid/OpenXR 可运行。
- [ ] iPad/ARKit 可运行或输出明确 fallback。
- [ ] 上层放置代码不出现 ARCore/ARKit/OpenXR class。
- [ ] capability flags 可见。
- [ ] 发布说明写明限制。
