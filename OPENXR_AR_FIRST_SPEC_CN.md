# OpenXR-First AR Spec

版本：2026-06-08

目标：把 OpenXR 作为 Godot XR Foundation 的三条第一优先级底层路线之一。只要设备提供合格的 OpenXR runtime 和 AR 相关扩展，就尽量通过同一套 OpenXR AR Provider 支持；Rokid、PICO、Quest、Android XR、VIVE、Lynx 等设备都应通过 profile/capability 分层纳入，而不是为每台设备重写上层接口。

同级第一优先级 Provider：

- OpenXR Provider：优先设备 Rokid，扩展 Quest、PICO、Android XR 等。
- ARKit Provider：优先设备 iPad，扩展 iPhone。
- ARCore Provider：优先设备 Android 手机/平板。

产品边界：我们的目标是 AR，不是 VR，也不是以 MR 为产品名的体验。文档中可能会引用 passthrough/MR 术语，因为厂商和引擎文档如此命名；但项目目标始终是“在真实世界上叠加虚拟内容”的 AR 能力。

## 为什么 OpenXR 优先

OpenXR 的价值是统一 XR session、空间坐标、渲染、输入 profile 和扩展发现机制。OpenXR 1.1 已被 Khronos 定位为跨 VR、AR、MR 设备的开放标准；Android XR 也明确基于 OpenXR 1.1 和一批 `XR_ANDROID_*` 扩展提供 trackables、raycast、anchor、depth、light estimation 等能力。

但要注意：OpenXR core 本身不能保证所有 AR 能力。AR 所需能力通常来自：

- environment blend mode：决定真实世界如何与虚拟内容合成。
- passthrough / see-through：让用户看到真实世界。
- trackables：检测平面、物体、场景几何。
- raycast：对真实环境做命中测试。
- anchors：把虚拟内容绑定到真实世界。
- depth / occlusion：让虚拟物体和真实世界互相遮挡。
- light estimation：真实环境光照估计。

因此本项目采用“OpenXR core + AR extension modules + device profiles”的结构。

## Unity 实现方式参考

Unity AR Foundation 的关键思想是 subsystem/provider：

- AR Foundation 定义上层 manager 和 subsystem 接口。
- ARCore、ARKit 等 provider plug-in 负责平台实现。
- `XRLoader` 负责创建/销毁 subsystem。
- descriptor 暴露 provider capability，上层使用前先查询能力。

对应到 Godot XR Foundation：

| Unity | Godot XR Foundation |
| --- | --- |
| `XRLoader` | `XRFoundation` backend/provider loader |
| `SubsystemWithProvider` | `XRProvider` + feature modules |
| `XRPlaneSubsystem` | `IPlaneProvider` / `ARPlaneManager` |
| `XRRaycastSubsystem` | `IRaycastProvider` / `ARRaycastManager` |
| `XRAnchorSubsystem` | `IAnchorProvider` / `ARAnchorManager` |
| subsystem descriptor | capability flags |
| OpenXR Feature | OpenXR AR feature module |
| interaction profile | input profile module |

Unity OpenXR Plugin 的另一个关键思想是 feature：

- OpenXR feature 可声明 extension strings。
- feature 可在构建时配置。
- feature 可调用 native plugin。
- 不同 build target 可以启用不同 feature。

对应到 Godot XR Foundation：

```text
OpenXRProvider
  OpenXRCoreFeature
  OpenXRArBlendFeature
  OpenXRPassthroughFeature
  OpenXRTrackablesFeature
  OpenXRRaycastFeature
  OpenXRAnchorsFeature
  OpenXRDepthFeature
  OpenXRLightEstimationFeature
  OpenXRInputProfilesFeature
  DeviceProfile: Rokid / Quest / PICO / AndroidXR / VIVE / Generic
```

## OpenXR AR Provider 架构

```text
ARFoundation-style managers
  ARSessionManager
  ARCameraManager
  ARRaycastManager
  ARPlaneManager
  ARAnchorManager
  ARPassthroughManager
  AROcclusionManager
        ↓
OpenXRProvider
        ↓
OpenXR feature modules
        ↓
OpenXR runtime + vendor extensions
        ↓
Rokid / Quest / PICO / Android XR / VIVE / other OpenXR devices
```

## Feature Modules

| Module | 目的 | OpenXR / Godot 路径 | 第一阶段 |
| --- | --- | --- | --- |
| `OpenXRCoreFeature` | session、render、spaces、tracking | Godot `XRServer` / `OpenXRInterface` | 必做 |
| `OpenXRArBlendFeature` | AR 合成模式 | `XRInterface.environment_blend_mode` | 必做 |
| `OpenXRPassthroughFeature` | 视频透传或光学 see-through | Godot AR passthrough + OpenXR Vendors | 必做 |
| `OpenXRInputProfilesFeature` | gaze、hand、controller、mouse | OpenXR interaction profiles | 必做 |
| `OpenXRTrackablesFeature` | plane/object/scene trackables | Android XR `XR_ANDROID_trackables` 或 vendor wrapper | 第二批 |
| `OpenXRRaycastFeature` | 对真实环境 raycast | Android XR `XR_ANDROID_raycast` 或 fallback | 第二批 |
| `OpenXRAnchorsFeature` | spatial/plane anchors | Android XR anchors 或 vendor wrapper | 第二批 |
| `OpenXRDepthFeature` | depth/occlusion | Android XR depth / Meta environment depth | 后续 |
| `OpenXRLightEstimationFeature` | 环境光 | Android XR light estimation 或 vendor wrapper | 后续 |

## 设备能力分层

| Tier | 名称 | 条件 | 产品策略 |
| --- | --- | --- | --- |
| A | OpenXR Full AR | passthrough/see-through + trackables + raycast + anchors | 完整 ARFoundation-style 功能 |
| B | OpenXR Passthrough AR | passthrough/see-through + tracking/input，无真实 trackables | virtual plane / gaze placement fallback |
| C | OpenXR Optical AR | additive/alpha blend + tracking/input，空间理解弱 | UI、空间标注、固定距离放置 |
| D | OpenXR VR-only | opaque blend only，看不到真实世界 | 只作为模拟或调试，不作为目标产品 |

本项目目标只认可 Tier A-C 为 AR 产品路径。Tier D 可以运行测试场景，但不计入 AR 产品完成度。

## 目标设备策略

### Rokid

- 第一选择：OpenXR runtime + `RokidOpenXRProfile`。
- 如果 OpenXR 足够支持渲染、tracking、输入、AR 合成，则不接 UXR2.0。
- 如果 Rokid 商店或空间能力要求 UXR2.0，则新增 `RokidUxrProvider`，但上层 API 不变。
- 每个周期都必须跑 Rokid/OpenXR demo 或 capability/fallback panel。

### Quest

- 第一选择：OpenXR + Godot OpenXR Vendors Meta modules。
- 必测：passthrough、boundary、controller/hand input、environment depth。
- Quest 路线用于验证“OpenXR passthrough AR”能力，但不把 Meta SDK 类型泄漏到上层。

### PICO

- 第一选择：OpenXR runtime + OpenXR Vendors 支持项。
- 必测：passthrough 是否可用、输入 profile 是否稳定、runtime 是否完整。
- 若 PICO 某型号只提供不完整 OpenXR AR 能力，则降级到 Tier B/C，并记录能力差异。

### Android XR

- 第一选择：OpenXR + OpenXR Vendors Android XR modules。
- 必测：`XR_ANDROID_trackables`、`XR_ANDROID_raycast`、anchors、depth、light estimation。
- Android XR 是 OpenXR Full AR 的主要参考实现。

## AR 而非 VR/MR 的产品定义

必须满足以下至少一项，才算 AR 设备运行成果：

- 用户能看到真实世界：optical see-through、video passthrough、或 camera background。
- 虚拟内容能和真实世界坐标建立关系：tracking、raycast、anchor、或固定空间参考。
- demo 的主任务是增强现实：放置、标注、空间菜单、真实环境交互。

以下不算 AR 产品成果：

- 纯 VR 场景。
- 只在黑色背景中显示 3D UI。
- 只有头显 tracking，没有真实世界合成或 AR fallback。

## Capability Flags

OpenXR provider 必须在运行时上报：

```text
OPENXR_SESSION
OPENXR_RENDER
OPENXR_REFERENCE_SPACES
OPENXR_ACTIONS
AR_BLEND_ALPHA
AR_BLEND_ADDITIVE
PASSTHROUGH
SEE_THROUGH
TRACKABLE_PLANES
TRACKABLE_OBJECTS
RAYCAST_ENVIRONMENT
ANCHOR_SPATIAL
ANCHOR_PLANE
ANCHOR_PERSISTENCE
DEPTH_TEXTURE
OCCLUSION
LIGHT_ESTIMATION
HAND_INTERACTION
HAND_TRACKING
EYE_GAZE
CONTROLLER_INPUT
MOUSE_INPUT
```

上层 manager 不允许通过设备名分支实现功能，只允许根据 capability flags 决定是否启用 feature 或 fallback。

## OpenXR-first 周期调整

| Cycle | 原名 | 调整后 |
| --- | --- | --- |
| C00 | Device Smoke Test | 加入 Quest/PICO/OpenXR runtime availability 检测项 |
| C01 | Foundation MVP | OpenXR core provider 和 capability flags 必须冻结 |
| C02 | Rokid OpenXR Slice | 改为 OpenXR AR Devices Slice，Rokid 为第一设备，Quest/PICO 为扩展验证 |
| C03 | Android ARCore Slice | 保留，手机 ARCore 仍是 handheld AR 主线 |
| C04 | iOS ARKit Slice | 保留，iOS ARKit 仍是 handheld AR 主线 |
| C05 | Unity Migration Slice | 按 Unity subsystem/provider 和 OpenXR Feature 模型完善 API |

## 第一优先级实现清单

1. `OpenXRProvider` 能枚举并输出：
   - supported blend modes
   - enabled extensions, 如果 Godot 暴露
   - available vendor singletons
   - interaction profiles, 如果可查询

2. `ARPassthroughManager`：
   - 优先使用 `environment_blend_mode`。
   - 支持 `ALPHA_BLEND`、`ADDITIVE`、`OPAQUE`。
   - 如果 vendor passthrough singleton 存在，则调用 vendor module。
   - 如果不支持 passthrough，则明确降级。

3. `OpenXRDeviceProfile`：
   - GenericOpenXR
   - RokidOpenXR
   - MetaQuestOpenXR
   - PicoOpenXR
   - AndroidXROpenXR

4. `OpenXRCapabilityReport`：
   - 运行时 UI 显示。
   - 日志输出。
   - JSON 导出，便于设备矩阵积累。

5. `demo/03_openxr_ar_capability_lab.tscn`：
   - 显示 blend modes。
   - 显示 passthrough 状态。
   - 显示 input profile 状态。
   - 显示 trackables/raycast/anchor 是否可用。
   - 支持 fallback virtual plane placement。

## 参考资料

- Unity AR Foundation Subsystems: https://docs.unity.cn/Packages/com.unity.xr.arfoundation%405.0/manual/architecture/subsystems.html
- Unity OpenXR Features: https://docs.unity.cn/Packages/com.unity.xr.openxr%401.7/manual/features.html
- Android XR for Unity: https://developer.android.com/develop/xr/unity
- Android XR OpenXR extensions: https://developer.android.com/develop/xr/openxr/extensions
- Godot AR / Passthrough: https://docs.godotengine.org/en/4.4/tutorials/xr/ar_passthrough.html
- Godot OpenXR Vendors Meta Passthrough: https://godotvr.github.io/godot_openxr_vendors/manual/meta/passthrough.html
- Godot OpenXR Vendors Android XR Trackables: https://godotvr.github.io/godot_openxr_vendors/manual/androidxr/trackables.html
