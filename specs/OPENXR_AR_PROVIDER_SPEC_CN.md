# OpenXR AR Provider Spec

状态：Draft

目标：定义 `OpenXRProvider` 的 AR 能力边界和 feature module 结构，让 Rokid、PICO、Quest、Android XR 等 OpenXR 设备尽量共用一套实现。

## Provider 职责

`OpenXRProvider` 负责：

- 初始化 OpenXR session。
- 配置 AR blend mode。
- 查询和输出 capability flags。
- 启动 passthrough 或 see-through 合成。
- 在 provider `start()` 生命周期中优先调用 `XRInterface.start_passthrough()` / vendor singleton passthrough 启动方法，并在 `stop()` 中成对停止。
- 提供输入 profile。
- 将 XRServer plane trackers，以及 OpenXR vendor singleton 暴露的 `get_planes` / `raycast` / `create_anchor` 这类 bridge，转换为 Godot XR Foundation 的统一 `ARPlane` / `XRHit` / `ARAnchor` 数据结构。
- 在 AR 能力不足时提供 fallback。

`OpenXRProvider` 不负责：

- 直接暴露 vendor SDK 类型给业务层。
- 把 VR-only 能力包装成 AR 成果。
- 替代 ARCore/ARKit 的手机 handheld AR provider。

## Feature Interface

每个 OpenXR feature module 建议实现：

```gdscript
func get_feature_name() -> StringName
func get_required_extensions() -> PackedStringArray
func get_optional_extensions() -> PackedStringArray
func is_available(provider: OpenXRProvider) -> bool
func start(provider: OpenXRProvider) -> bool
func stop(provider: OpenXRProvider) -> void
func get_capabilities() -> PackedStringArray
func get_last_error() -> String
```

## Feature 列表

| Feature | Required | Capability |
| --- | --- | --- |
| `OpenXRCoreFeature` | Yes | `OPENXR_SESSION`, `OPENXR_RENDER`, `OPENXR_REFERENCE_SPACES` |
| `OpenXRArBlendFeature` | Yes | `AR_BLEND_ALPHA`, `AR_BLEND_ADDITIVE` |
| `OpenXRPassthroughFeature` | Yes for AR devices | `PASSTHROUGH`, `SEE_THROUGH` |
| `OpenXRInputProfilesFeature` | Yes | `HAND_INTERACTION`, `CONTROLLER_INPUT`, `EYE_GAZE` |
| `OpenXRTrackablesFeature` | Optional | `TRACKABLE_PLANES`, `TRACKABLE_OBJECTS` |
| `OpenXRRaycastFeature` | Optional | `RAYCAST_ENVIRONMENT` |
| `OpenXRAnchorsFeature` | Optional | `ANCHOR_SPATIAL`, `ANCHOR_PLANE`, `ANCHOR_PERSISTENCE` |
| `OpenXRDepthFeature` | Optional | `DEPTH_TEXTURE`, `OCCLUSION` |
| `OpenXRLightEstimationFeature` | Optional | `LIGHT_ESTIMATION` |

## Device Profiles

```gdscript
class_name OpenXRDeviceProfile

var profile_name: StringName
var vendor: StringName
var required_features: PackedStringArray
var preferred_blend_modes: Array[int]
var required_permissions: PackedStringArray
var notes: String
```

第一批 profile：

- `GenericOpenXR`
- `RokidOpenXR`
- `MetaQuestOpenXR`
- `PicoOpenXR`
- `AndroidXROpenXR`

## Fallback 策略

| 缺失能力 | Fallback |
| --- | --- |
| passthrough/see-through 缺失 | 标记为 VR-only，不计入 AR 成果 |
| trackables 缺失 | virtual plane，并在 capability 中标记 `openxr_virtual_plane_fallback=true` |
| environment raycast 缺失 | gaze ray + virtual plane，并在 `openxr_plane_source` 中标记 `virtual_floor_fallback` |
| anchor 缺失 | local Node3D anchor |
| hand/controller 缺失 | gaze dwell 或 mouse |
| depth/occlusion 缺失 | 关闭 occlusion，保留 placement |

## 检测输出

每次 OpenXR 启动都输出：

```text
[OpenXRProvider] runtime=
[OpenXRProvider] device_profile=
[OpenXRProvider] blend_modes=
[OpenXRProvider] selected_blend_mode=
[OpenXRProvider] vendor_singletons=
[OpenXRProvider] vendor_trackable_bridge=
[OpenXRProvider] capabilities=
[OpenXRProvider] ar_tier=A|B|C|D
[OpenXRProvider] passthrough_started=
[OpenXRProvider] passthrough_start_report=
[OpenXRProvider] fallback=
[OpenXRProvider] virtual_plane_fallback=
[OpenXRProvider] plane_source=xr_tracker|vendor_singleton_bridge|virtual_floor_fallback|none
[OpenXRProvider] errors=
```

## 验收

- 同一个 `OpenXRProvider` 可在 Generic/Rokid/Quest/PICO/AndroidXR profile 下运行。
- AR 能力只通过 capability flags 暴露。
- VR-only runtime 不被误报为 AR-ready。
- 设备差异进入 profile 和 feature module，不进入业务层。
