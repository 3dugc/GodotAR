# Unity Migration Notes

## Mental Model

Unity:

```text
ARSession
ARSessionOrigin / XROrigin
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
XRDeviceRig / XROrigin3D
XRCamera3D
ARRaycastManager
ARPlaneManager
ARAnchorManager
XRInteractionManager
XRRayInteractor
XRGrabInteractable
```

Godot's `XROrigin3D` is the tracking-space root. Keep imported Unity content under a world/content root, and keep the rig separate.

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
| `ARRaycastManager.Raycast(Ray, List<ARRaycastHit>, TrackableType)` | `ARRaycastManager.RaycastToList(origin, direction, results, max_results, trackable_types)` or `TryRaycast(...)` |
| `ARRaycastManager.Raycast(Vector2, List<ARRaycastHit>, TrackableType)` | `ARRaycastManager.RaycastFromScreen(camera, screen_position, results, trackable_types)`, `RaycastScreenPoint(...)`, `RaycastList(...)`, or `TryScreenRaycast(...)`; Godot requires an explicit `Camera3D` |
| `ARRaycastHit.pose` | `XRHit.pose`, `XRHit.get_pose()`, `XRHit.GetPose()`, or `XRHit.to_dictionary().pose` |
| `ARRaycastHit.trackableId` / `trackableType` | `XRHit.trackableId` / `trackableType`, `GetTrackableId()`, `GetTrackableType()`, or the snake_case `trackable_id` / `trackable_type` fields |
| `ARAnchorManager.AddAnchor(...)` | `ARAnchorManager.AddAnchor(...)` or `add_anchor(...)` |
| `ARAnchorManager.TryAddAnchorAsync(Pose)` | `ARAnchorManager.TryAddAnchorAsync(transform_or_pose_dictionary)` |
| `ARAnchorManager.TryRemoveAnchor(anchor)` | `ARAnchorManager.TryRemoveAnchor(anchor)` |
| `ARPlaneManager.trackables` | `ARPlaneManager.GetTrackables()`, `GetTrackable(id)`, `TryGetPlane(id, result)`, `GetAllPlanes()`, or `get_all_planes()` |
| `ARPlaneManager.trackablesChanged` | `ARPlaneManager.trackablesChanged(changes)` where `changes` is `ARTrackablesChangedEventArgs`; legacy `planes_changed(added, updated, removed)` is also emitted |
| `ARPlaneManager.requestedDetectionMode` / `currentDetectionMode` | `requested_detection_mode`, `get_requested_detection_mode()`, `set_requested_detection_mode(...)`, `SetRequestedDetectionModeName("Horizontal")`, and `get_current_detection_mode()` |
| `ARAnchorManager.trackables` | `ARAnchorManager.GetTrackables()`, `GetTrackable(id)`, `TryGetAnchor(id, result)`, or `GetAllAnchors()` |
| `ARAnchorManager.trackablesChanged` / `anchorsChanged` | `ARAnchorManager.trackablesChanged(changes)` where `changes` is `ARTrackablesChangedEventArgs`; legacy `anchors_changed(added, updated, removed)` is also emitted |
| `XROrigin.Camera` | `XRDeviceRig.get_camera()` |
| `XRInteractionManager` | `XRInteractionManager` |
| `XRRayInteractor` | `XRRayInteractor` |
| `XRGrabInteractable` | `XRGrabInteractable` |
| `hoverEntered` / `hoverExited` | XRI-style camelCase signals are emitted alongside Godot snake_case `hover_entered` / `hover_exited` |
| `selectEntered` / `selectExited` | XRI-style camelCase signals are emitted alongside `select_entered` / `select_exited`; `firstSelectEntered` and `lastSelectExited` are also emitted for single-select migration |
| `activated` / `deactivated` | `activated` / `deactivated` signals on the interactor, interactable, and interaction manager |

## C00 ARFoundation API Surface

C00 keeps the compatibility layer intentionally thin: it copies the Unity naming shape where that helps port services, while still exposing Godot-native snake_case methods for new code.

- `ARSession.state()` follows Unity ARFoundation semantics and returns `XRFoundationTypes.ARSessionState`, not the internal `Stopped/Starting/Running/Failed` lifecycle value.
- `ARSession.foundation_state()` and `XRFoundation.state` expose the internal lifecycle value when gate scripts need to know whether the provider has started or failed.
- `ARSession.notTrackingReason()` maps the current Godot/XR tracking status to `XRFoundationTypes.NotTrackingReason`.
- Manager changed events expose Unity AR Foundation 6-style `trackablesChanged(changes)` with `changes.added`, `changes.updated`, and `changes.removed`, while still emitting legacy `planes_changed(added, updated, removed)` and `anchors_changed(added, updated, removed)` for existing Godot-side scripts.
- Screen-space raycast needs a `Camera3D` argument because Godot does not have Unity's implicit active AR camera.
- Native ARKit/ARCore singleton bridges can return anchor dictionaries; `NativeXRProvider` preserves `trackable_id`, `persistent_id`, `transform`, and `tracking_state` through `ARAnchor.from_dictionary()`.
- `match_frame_rate_requested` is surfaced as a migration option now; actual native frame pacing should be implemented in the ARKit/ARCore/OpenXR providers when those SDK bridges expose preferred frame timing.

Static API surface gate:

```bash
node tools/c00/check_arfoundation_api_surface.js
```

This check is meant to run in CI or on a device machine before the real iPad/Rokid gate. It does not prove native AR tracking; it only keeps the migration-facing facade stable.

## C00 XRI API Surface

C00 includes a thin XRI-style interaction smoke layer so Unity services that assume XRI concepts have a stable landing point before full interaction features are implemented.

- `XRInteractionManager` centrally registers interactors/interactables and dispatches hover/select/activate transitions.
- `XRRayInteractor` exposes `GetValidTargets(...)`, `TryGetCurrent3DRaycastHit()`, `select()`, `release()`, `activate()`, and `deactivate()`.
- `XRRayInteractor`, `XRGrabInteractable`, and `XRInteractionManager` emit both Godot-style snake_case signals and Unity XRI-style camelCase signals such as `hoverEntered`, `selectEntered`, `firstSelectEntered`, `lastSelectExited`, `activated`, and `deactivated`.
- `XRGrabInteractable` exposes XRI-style hover/select/activate events plus `IsHovered()` and `IsSelected()`.
- The C00 smoke scene includes a camera ray and a small interactable target, and writes XRI state into the `GXF_SMOKE.xri` payload.

Static XRI surface gate:

```bash
node tools/c00/check_xri_api_surface.js
```

This check does not prove controller input or final UI interaction quality; it keeps the XRI mental model present while the native iPad/Rokid runtime gates are being brought up.

## Porting Order

1. Move scene scale to meters. Godot XR expects 1 unit to map to 1 meter.
2. Replace Unity `XROrigin` with `addons/godot_xr_foundation/scenes/xr_foundation_rig.tscn`.
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
func place_from_screen_unity_style(screen_position: Vector2) -> void:
	var hits: Array = []
	if not raycast_manager.RaycastFromScreen(camera, screen_position, hits):
		return

	var result := anchor_manager.TryAddAnchorAsync(hits[0].get_pose())
	if not bool(result.get("success", false)):
		return

	var anchor: ARAnchor = result.get("anchor")
	var instance := preload("res://prefabs/placed_object.tscn").instantiate()
	anchor.node.add_child(instance)
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

- Unity AR Foundation `ARSession`: https://docs.unity.cn/Packages/com.unity.xr.arfoundation%404.2/api/UnityEngine.XR.ARFoundation.ARSession.html
- Unity AR Foundation managers architecture: https://docs.unity.cn/Packages/com.unity.xr.arfoundation%405.0/manual/architecture/managers.html
- Unity AR Foundation 6 `ARPlaneManager.trackablesChanged`: https://docs.unity.cn/Packages/com.unity.xr.arfoundation%406.0/manual/features/plane-detection/arplanemanager.html
- Unity AR Foundation `ARRaycastManager`: https://docs.unity.cn/Packages/com.unity.xr.arfoundation%405.0/api/UnityEngine.XR.ARFoundation.ARRaycastManager.html
- Unity XR Interaction Toolkit `XRRayInteractor`: https://docs.unity.cn/Packages/com.unity.xr.interaction.toolkit%402.5/manual/xr-ray-interactor.html
