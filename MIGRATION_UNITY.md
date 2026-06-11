# Unity Migration Notes

## Unity Baseline

Target the newest public Unity XR design first, including pre-release, preview, alpha/beta release notes, or otherwise unreleased package documentation when Unity publishes it. As of 2026-06-10, Unity package registry `dist-tags.latest` points at `com.unity.xr.arfoundation@6.6.0-pre.2`, `com.unity.xr.arcore@6.6.0-pre.2`, `com.unity.xr.arkit@6.6.0-pre.2`, `com.unity.xr.interaction.toolkit@3.5.1`, and `com.unity.xr.openxr@1.17.1`; these are the forward design baseline even when the tag is pre-release. The stable fallback line for conservative device gates remains `com.unity.xr.arfoundation@6.5.0`, `com.unity.xr.arcore@6.5.0`, `com.unity.xr.arkit@6.5.0`, plus `com.unity.xr.core-utils@2.6.0` and `com.unity.xr.androidxr-openxr@1.3.1`. Use newer pre-release behavior for API shape decisions when it exposes ARFoundation/provider changes, while keeping C00 completion tied to device evidence rather than Unity package numbers. Unity 6.5/6.6 package manuals are the current public package reference; Unity 6.4 package API pages remain the detailed fallback only where newer API pages are not separately visible. Unity 6000.6 alpha release notes remain a signal for future-facing API shape, not a substitute for package docs.

Implementation rule: prefer the latest `XROrigin` / manager / subsystem shape, then keep deprecated Unity APIs as compatibility shims only when they materially reduce migration cost.

## Mental Model

Unity:

```text
ARSession
XROrigin
ARSessionOrigin (deprecated compatibility)
ARCameraManager
ARRaycastManager
ARPlaneManager
ARAnchorManager
XR Ray Interactor
XR Grab Interactable
```

Godot XR Foundation:

```text
XRFoundation autoload
XRSessionManager
XROrigin / ARSessionOrigin shim
XRDeviceRig / XROrigin3D
XRCamera3D
ARRaycastManager
ARPlaneManager
ARAnchorManager
XRInteractionManager
XRRayInteractor
XRGrabInteractable
```

Godot's `XROrigin3D` remains the low-level tracking-space root. `addons/godot_xr_foundation/scripts/arfoundation/xr_origin.gd` is the Unity-facing `XROrigin` shim that points at the Godot rig, exposes Unity-style origin/camera/trackables properties, and keeps imported Unity services away from Godot engine internals.

## Common API Replacements

| Unity | Godot XR Foundation |
| --- | --- |
| `ARSession.enabled = true` | `XRFoundation.start_session(...)` |
| `ARSession.CheckAvailability()` | `ARSession.CheckAvailability(...)` or `XRFoundation.check_availability(...)` |
| `ARSession.Install()` | `ARSession.Install(...)` or `XRFoundation.install(...)` |
| `ARSession.Reset()` | `ARSession.Reset()`, `XRFoundation.reset_session(...)`, or `XRDeviceRig.recenter()` |
| `ARSession.state` | `ARSession.state()`, `ARSession.GetState()`, or `XRFoundation.get_ar_session_state()` |
| Unity internal/session lifecycle checks | `ARSession.foundation_state()`, `ARSession.GetFoundationState()`, or `XRFoundation.state` |
| `ARSession.notTrackingReason` | `ARSession.notTrackingReason()`, `ARSession.GetNotTrackingReason()`, or `XRFoundation.get_not_tracking_reason()`; native ARKit `arkit_tracking_reason` is mapped into this facade |
| `ARSession.requestedTrackingMode` | `ARSession.requested_tracking_mode`, `get_requested_tracking_mode()`, or `set_requested_tracking_mode(...)` |
| `ARSession.currentTrackingMode` | `ARSession.get_current_tracking_mode()` |
| `ARSession.matchFrameRate` / `matchFrameRateRequested` | `XRSessionManager.match_frame_rate` / `match_frame_rate_requested`; native providers may ignore this until their frame pacing bridge is implemented |
| `ARCameraManager.frameReceived` | `ARCameraManager.frameReceived(args)` and `frame_received(args)` signals; `args` is a Godot `Dictionary` with camera/background/light-estimation/intrinsics metadata |
| `ARCameraManager.permissionGranted` | `ARCameraManager.permissionGranted` or `get_permission_granted()` |
| `ARCameraManager.requestedLightEstimation` / `currentLightEstimation` | `requestedLightEstimation`, `requested_light_estimation`, `currentLightEstimation`, and `current_light_estimation`; C00 reports support through provider capabilities |
| `ARCameraManager.TryGetIntrinsics(out XRCameraIntrinsics)` | `ARCameraManager.TryGetIntrinsics(result_dictionary)`; iPad/ARKit now prefers native `GodotARKit.try_get_intrinsics()` from the latest ARKit frame, then falls back to projection-derived Godot camera intrinsics |
| `ARCameraManager.TryAcquireLatestCpuImage(out XRCpuImage)` | `ARCameraManager.TryAcquireLatestCpuImage(result_dictionary)` currently returns `false` with `reason:"cpu_image_not_exposed_in_c00"` |
| `ARCameraFrameEventArgs` intrinsics/light metadata | `ARCameraManager.GetLatestFrame()` / `frameReceived(args)` includes native ARKit timestamp, tracking state/reason, intrinsics, and ambient light estimate when the native frame is available |
| `ARRaycastManager.Raycast(Ray, List<ARRaycastHit>, TrackableType)` | `ARRaycastManager.Raycast(ray_dictionary_or_transform, results, trackable_types)`, `RaycastRayToList(...)`, `TryRaycastRay(...)`, `ARRaycastManager.RaycastToList(origin, direction, results, max_results, trackable_types)`, or `TryRaycast(...)` |
| `ARRaycastManager.Raycast(Vector2, List<ARRaycastHit>, TrackableType)` | `ARRaycastManager.Raycast(screen_position, results, trackable_types)` when `camera_path`, `SetRaycastCamera(camera)`, or the active viewport camera is available; explicit-camera aliases remain available through `RaycastFromScreen(camera, ...)`, `RaycastScreenPoint(...)`, `RaycastList(...)`, or `TryScreenRaycast(...)` |
| `TrackableType.PlaneWithinPolygon` / `TrackableType.FeaturePoint` | `XRFoundationTypes.TRACKABLE_TYPE_PLANES`, `TRACKABLE_TYPE_POINTS`, or string masks such as `"PlaneWithinPolygon"` passed into the raycast facade |
| `ARRaycastHit.pose` | `XRHit.pose`, `XRHit.get_pose()`, `XRHit.GetPose()`, or `XRHit.to_dictionary().pose` |
| `ARRaycastHit.trackableId` / `trackableType` | `XRHit.trackableId` / `trackableType`, `GetTrackableId()`, `GetTrackableType()`, or the snake_case `trackable_id` / `trackable_type` fields |
| `ARAnchorManager.AddAnchor(...)` | `ARAnchorManager.AddAnchor(...)` or `add_anchor(...)` |
| `ARAnchorManager.AttachAnchor(ARPlane, Pose)` | `ARAnchorManager.AttachAnchor(plane, transform_or_pose_dictionary)`; check `ARAnchorManager.GetDescriptor().supportsTrackableAttachments` first when porting Unity code |
| `ARAnchorManager.TryAddAnchorAsync(Pose)` | `ARAnchorManager.TryAddAnchorAsync(transform_or_pose_dictionary)`; result includes `success`, `status`, `value`, `anchor`, and `error` |
| `ARAnchorManager.TryRemoveAnchor(anchor)` | `ARAnchorManager.TryRemoveAnchor(anchor)` |
| `ARAnchorManager.GetAnchor(trackableId)` | `ARAnchorManager.GetAnchor(id)` |
| Persistent anchor APIs | `TrySaveAnchorAsync`, `TryLoadAnchorAsync`, `TryEraseAnchorAsync`, and `TryGetSavedAnchorIdsAsync` return explicit unsupported results in C00 instead of missing methods |
| `ARPlaneManager.trackables` | `ARPlaneManager.GetTrackables()`, `GetTrackable(id)`, `TryGetPlane(id, result)`, `GetAllPlanes()`, or `get_all_planes()` |
| `ARPlaneManager.trackablesChanged` | `ARPlaneManager.trackablesChanged(changes)` where `changes` is `ARTrackablesChangedEventArgs`; legacy `planes_changed(added, updated, removed)` is also emitted |
| `ARPlaneManager.requestedDetectionMode` / `currentDetectionMode` | `requested_detection_mode`, `get_requested_detection_mode()`, `set_requested_detection_mode(...)`, `SetRequestedDetectionModeName("Horizontal")`, and `get_current_detection_mode()` |
| `ARAnchorManager.trackables` | `ARAnchorManager.GetTrackables()`, `GetTrackable(id)`, `TryGetAnchor(id, result)`, or `GetAllAnchors()` |
| `ARAnchorManager.trackablesChanged` / `anchorsChanged` | `ARAnchorManager.trackablesChanged(changes)` where `changes` is `ARTrackablesChangedEventArgs`; legacy `anchors_changed(added, updated, removed)` is also emitted |
| `XROrigin.Camera` | `XROrigin.Camera`, `XROrigin.GetCamera()`, or `XRDeviceRig.get_camera()` |
| `XROrigin.Origin` | `XROrigin.Origin`, `XROrigin.GetOrigin()`, usually pointing at `XRFoundationRig` / Godot `XROrigin3D` |
| `XROrigin.TrackablesParent` | `XROrigin.TrackablesParent` or `XROrigin.GetTrackablesParent()`; the shim creates `TrackablesParent` under the origin if needed |
| `XROrigin.CameraFloorOffsetObject` / `CameraYOffset` | `XROrigin.CameraFloorOffsetObject`, `XROrigin.GetCameraFloorOffsetObject()`, and `XROrigin.set_camera_y_offset(...)` |
| `XROrigin.MoveCameraToWorldLocation(...)` | `XROrigin.MoveCameraToWorldLocation(desired_world_location)` |
| `XROrigin.RotateAroundCameraUsingOriginUp(...)` / `RotateAroundCameraPosition(...)` | Same method names on the Godot `XROrigin` shim |
| `XROrigin.MatchOriginUp(...)` / `MatchOriginUpCameraForward(...)` / `MatchOriginUpOriginForward(...)` | Same method names on the Godot `XROrigin` shim |
| `ARSessionOrigin` | `ARSessionOrigin` shim inherits `XROrigin`; use only as a deprecated compatibility bridge for older Unity services |
| `ARSessionOrigin.camera` / `trackablesParent` | `get_camera_node()`, `GetCamera()`, `get_trackables_parent_node()`, or `GetTrackablesParent()` |
| `ARSessionOrigin.MakeContentAppearAt(...)` | `ARSessionOrigin.MakeContentAppearAt(...)` or `XROrigin.MakeContentAppearAt(...)`; the shim updates the origin transform so content appears at the requested world pose |
| `XRInteractionManager` | `XRInteractionManager` |
| `XRRayInteractor` | `XRRayInteractor` |
| `XRGrabInteractable` | `XRGrabInteractable` |
| `XRRayInteractor.TryGetCurrent3DRaycastHit(out RaycastHit)` | `XRRayInteractor.TryGetCurrent3DRaycastHit(result_array)` fills the array and returns `bool`; calling without arguments still returns a Dictionary |
| `XRRayInteractor.TryGetCurrentARRaycastHit(out ARRaycastHit)` | `XRRayInteractor.TryGetCurrentARRaycastHit(result_array, endpoint_index_array)` bridges to `ARRaycastManager` via `ar_raycast_manager_path` or scene auto-discovery |
| `XRRayInteractor.TryGetCurrentRaycast(...)` | `XRRayInteractor.TryGetCurrentRaycast(raycast_hit, raycast_hit_index, ui_raycast_hit, ui_raycast_hit_index, is_ui_hit_closest, ar_raycast_hit, ar_raycast_hit_index, is_ar_hit_closest)` fills arrays and reports `bool` |
| `XRRayInteractor.TryGetHitInfo(...)` | `XRRayInteractor.TryGetHitInfo(position_array, normal_array, position_in_line_array, is_valid_target_array)` reports the current 3D or AR hit |
| `XRRayInteractor.TryGetCurrentUIRaycastResult(out RaycastResult)` | `XRRayInteractor.TryGetCurrentUIRaycastResult(result_array, endpoint_index_array)` currently returns `false` until Godot UI hit bridging is implemented |
| `hoverEntered` / `hoverExited` | XRI-style camelCase signals are emitted alongside Godot snake_case `hover_entered` / `hover_exited` |
| `selectEntered` / `selectExited` | XRI-style camelCase signals are emitted alongside `select_entered` / `select_exited`; `firstSelectEntered` and `lastSelectExited` are also emitted for single-select migration |
| `activated` / `deactivated` | `activated` / `deactivated` signals on the interactor, interactable, and interaction manager |

## C00 ARFoundation API Surface

C00 keeps the compatibility layer intentionally thin: it copies the Unity naming shape where that helps port services, while still exposing Godot-native snake_case methods for new code.

- `ARSession.state()` follows Unity ARFoundation semantics and returns `XRFoundationTypes.ARSessionState`, not the internal `Stopped/Starting/Running/Failed` lifecycle value.
- `ARSession.foundation_state()` and `XRFoundation.state` expose the internal lifecycle value when gate scripts need to know whether the provider has started or failed.
- `ARSession.notTrackingReason()` maps the current Godot/XR tracking status to `XRFoundationTypes.NotTrackingReason`.
- `ARCameraManager` exposes Unity-style camera lifecycle fields and frame events while clearly reporting C00 limits: camera background/passthrough and light estimation come from provider capabilities, iPad/ARKit intrinsics come from the native `GodotARKit` frame when available, and CPU image acquisition is explicitly unsupported in C00.
- Manager changed events expose Unity AR Foundation 6-style `trackablesChanged(changes)` with `changes.added`, `changes.updated`, and `changes.removed`, while still emitting legacy `planes_changed(added, updated, removed)` and `anchors_changed(added, updated, removed)` for existing Godot-side scripts.
- `XROrigin` is the preferred Unity 6.x origin surface. C00 exposes `Camera`, `Origin`, `TrackablesParent`, `CameraFloorOffsetObject`, `CameraYOffset`, camera/origin-space query helpers, trackables-parent transform change events, origin movement/rotation helpers, and `MakeContentAppearAt(...)` as an addon-only shim over the existing Godot rig.
- `ARSessionOrigin` remains available only as a compatibility class that inherits the `XROrigin` shim, matching Unity 6.4's deprecated-but-present inheritance shape for older ARFoundation services.
- Screen-space raycast can now match Unity's `Raycast(screenPoint, hitResults, trackableTypes)` call shape when `ARRaycastManager.camera_path` is configured, when `SetRaycastCamera(camera)` has been called, or when a viewport/current-scene `Camera3D` can be discovered. Ray-style calls can pass a dictionary with `origin` and `direction`, a `Transform3D`, or a `Node3D`; explicit-camera aliases remain available for deterministic tests and nonstandard rigs.
- `ARAnchorManager` exposes Unity's `AttachAnchor`, `GetAnchor`, `GetDescriptor().supportsTrackableAttachments`, and async persistent-anchor method names. Persistent anchors intentionally return unsupported results in C00, so migrated services can feature-detect without crashing while native persistence is scheduled for a later cycle.
- Native ARKit/ARCore singleton bridges can return anchor dictionaries; `NativeXRProvider` preserves `trackable_id`, `persistent_id`, `transform`, and `tracking_state` through `ARAnchor.from_dictionary()`. On iPad/ARKit, `GodotARKitPlugin.create_anchor()` now routes placement poses into `ARSession.addAnchor` through `GodotARKitSession.addAnchorWithTransform(...)` when the native session is running.
- `NativeXRProvider` lazily resolves the native singleton for status, capabilities, plane, raycast, and anchor queries. This keeps Unity-style managers usable when migrated services query subsystems before an explicit `ARSession.start()` path has cached the provider singleton, and it tolerates native raycast/anchor bridge methods with 2/3/4 argument shapes.
- `match_frame_rate_requested` is surfaced as a migration option now; actual native frame pacing should be implemented in the ARKit/ARCore/OpenXR providers when those SDK bridges expose preferred frame timing.

Static API surface gate:

```bash
node tools/c00/check_arfoundation_api_surface.js
```

This check is meant to run in CI or on a device machine before the real iPad/Rokid gate. It does not prove native AR tracking; it only keeps the migration-facing facade stable.

## C00 XRI API Surface

C00 includes a thin XRI-style interaction smoke layer so Unity services that assume XRI concepts have a stable landing point before full interaction features are implemented.

- `XRInteractionManager` centrally registers interactors/interactables and dispatches hover/select/activate transitions.
- `XRRayInteractor` exposes `GetValidTargets(...)`, `TryGetCurrent3DRaycastHit()`, `TryGetCurrentARRaycastHit()`, `TryGetCurrentRaycast(...)`, `TryGetHitInfo(...)`, `TryGetCurrentUIRaycastResult(...)`, `select()`, `release()`, `activate()`, and `deactivate()`. The out-parameter style methods use caller-provided arrays so Unity services can keep a similar control flow after porting to GDScript.
- `XRRayInteractor`, `XRGrabInteractable`, and `XRInteractionManager` emit both Godot-style snake_case signals and Unity XRI-style camelCase signals such as `hoverEntered`, `selectEntered`, `firstSelectEntered`, `lastSelectExited`, `activated`, and `deactivated`.
- `XRGrabInteractable` exposes XRI-style hover/select/activate events plus `IsHovered()` and `IsSelected()`.
- `XRInputProfile` exposes a small capability-derived descriptor for gaze/ray/controller modes, so OpenXR device demos can report the intended XRI selection path before full controller profile bindings are implemented.
- The C00 smoke scene includes a camera ray and a small interactable target, and writes XRI state into the `GXF_SMOKE.xri` payload.

Static XRI surface gate:

```bash
node tools/c00/check_xri_api_surface.js
```

This check does not prove controller input or final UI interaction quality; it keeps the XRI mental model present while the native iPad/Rokid runtime gates are being brought up.

## Porting Order

1. Move scene scale to meters. Godot XR expects 1 unit to map to 1 meter.
2. Replace Unity `XROrigin` references with the addon `XROrigin` shim, and point it at `addons/godot_xr_foundation/scenes/xr_foundation_rig.tscn`.
3. Replace session startup code with `XRSessionManager`.
4. Replace AR raycasts and anchors first; they are usually the main gameplay dependency.
5. Replace plane visualization next.
6. Port interactions last; Godot physics and input action maps differ more from Unity's.

## Example Session Startup

```gdscript
func _ready() -> void:
	var report := ARSession.CheckAvailability(XRFoundationTypes.Backend.OPENXR, {
		"platform_hint": "rokid",
	})
	print(report)

	var ok := XRFoundation.start_session(XRFoundationTypes.Backend.OPENXR, {
		"platform_hint": "rokid",
		"prefer_ar": true,
		"passthrough": true,
	})
	if not ok:
		push_warning(XRFoundation.last_error)
```

For Unity service classes that currently depend on `ARSession`, keep them talking to the Godot `ARSession` wrapper first. Move lower-level calls to `XRFoundation` only when you need provider diagnostics or custom fallback behavior.

## Example Placement

```gdscript
@onready var camera: Camera3D = $XRFoundationRig/XRCamera3D
@onready var camera_manager: ARCameraManager = $ARCameraManager
@onready var raycast_manager: ARRaycastManager = $ARRaycastManager
@onready var anchor_manager: ARAnchorManager = $ARAnchorManager

func place_from_screen(screen_position: Vector2) -> void:
	var hits := raycast_manager.screen_raycast(camera, screen_position)
	if hits.is_empty():
		return

	var anchor := anchor_manager.add_anchor(hits[0].transform)
	var instance := preload("res://prefabs/placed_object.tscn").instantiate()
	anchor.node.add_child(instance)
```

Unity-style list output is also supported:

```gdscript
func _ready() -> void:
	camera_manager.SetCamera(camera)
	raycast_manager.SetRaycastCamera(camera)

func place_from_screen_unity_style(screen_position: Vector2) -> void:
	var hits: Array = []
	if not raycast_manager.Raycast(screen_position, hits, XRFoundationTypes.TRACKABLE_TYPE_PLANES):
		return

	var result := anchor_manager.TryAddAnchorAsync(hits[0].get_pose())
	if not bool(result.get("success", false)):
		return

	var anchor: ARAnchor = result.get("anchor")
	var instance := preload("res://prefabs/placed_object.tscn").instantiate()
	anchor.node.add_child(instance)
```

Unity-style camera frame metadata can be consumed without touching ARKit/ARCore/OpenXR SDK classes:

```gdscript
func _ready() -> void:
	camera_manager.frameReceived.connect(_on_camera_frame)

func _on_camera_frame(args: Dictionary) -> void:
	if bool(args.get("has_intrinsics", false)):
		var intrinsics: Dictionary = args.get("intrinsics", {})
		print(intrinsics.get("focal_length", []))
```

## C# Projects

If the Unity project is large and mostly C#, keep this addon as the platform boundary and port gameplay incrementally. Godot C# can call into GDScript nodes, but mobile/export constraints should be checked early for your target Godot version and platforms.

The practical path is:

- Keep XR/AR providers in GDScript first.
- Port high-value gameplay systems to Godot C# only after export targets are verified.
- Keep data-driven scene content in `.tscn` or imported assets so it is not tied to script language.

## What Still Needs Native Work

ARFoundation hides a lot of native SDK detail. Godot can match the shape, but concrete ARCore and ARKit features still depend on the native plugins you choose:

- Camera feed and background composition.
- Plane classification details.
- Point clouds/depth.
- Light estimation.
- Persistent cloud/local anchors.
- Image/object tracking.

The provider layer in this addon is designed so those features can be added per platform without rewriting gameplay code.

## Unity References Used For This Surface

- Unity AR Foundation 6.4 package overview: https://docs.unity.cn/Packages/com.unity.xr.arfoundation%406.4/manual/index.html
- Unity AR Foundation 6.4 `ARSession`: https://docs.unity.cn/Packages/com.unity.xr.arfoundation%406.4/api/UnityEngine.XR.ARFoundation.ARSession.html
- Unity AR Foundation 6.4 `ARSessionOrigin`: https://docs.unity.cn/Packages/com.unity.xr.arfoundation%406.4/api/UnityEngine.XR.ARFoundation.ARSessionOrigin.html
- Unity AR Foundation 5 upgrade note from `ARSessionOrigin` to `XROrigin`: https://docs.unity.cn/Packages/com.unity.xr.arfoundation%405.1/manual/version-history/upgrade-guide.html
- Unity XR Core Utilities `XROrigin`: https://docs.unity.cn/Packages/com.unity.xr.core-utils%402.5/manual/xr-origin-reference.html
- Unity AR Foundation managers architecture: https://docs.unity.cn/Packages/com.unity.xr.arfoundation%405.0/manual/architecture/managers.html
- Unity AR Foundation 6 `ARCameraManager`: https://docs.unity.cn/Packages/com.unity.xr.arfoundation%406.1/api/UnityEngine.XR.ARFoundation.ARCameraManager.html
- Apple ARKit `ARCamera`: https://developer.apple.com/documentation/arkit/arcamera
- Apple ARKit `ARFrame.lightEstimate`: https://developer.apple.com/documentation/arkit/arframe/lightestimate
- Unity AR Foundation 6 `ARPlaneManager.trackablesChanged`: https://docs.unity.cn/Packages/com.unity.xr.arfoundation%406.0/manual/features/plane-detection/arplanemanager.html
- Unity AR Foundation 6.5 `ARRaycastManager`: https://docs.unity3d.com/Packages/com.unity.xr.arfoundation%406.5/api/UnityEngine.XR.ARFoundation.ARRaycastManager.html
- Unity AR Foundation 6 `ARAnchorManager.AttachAnchor` / `TryAddAnchorAsync`: https://docs.unity.cn/Packages/com.unity.xr.arfoundation%406.1/api/UnityEngine.XR.ARFoundation.ARAnchorManager.html
- Unity XR Interaction Toolkit 3.5.1 `XRRayInteractor`: https://docs.unity3d.com/Packages/com.unity.xr.interaction.toolkit%403.5/api/UnityEngine.XR.Interaction.Toolkit.Interactors.XRRayInteractor.html
