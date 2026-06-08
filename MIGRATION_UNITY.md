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
XRRayInteractor
XRGrabInteractable
```

Godot's `XROrigin3D` is the tracking-space root. Keep imported Unity content under a world/content root, and keep the rig separate.

## Common API Replacements

| Unity | Godot XR Foundation |
| --- | --- |
| `ARSession.enabled = true` | `XRFoundation.start_session(...)` |
| `ARSession.Reset()` | `XRDeviceRig.recenter()` or `XRServer.center_on_hmd(...)` |
| `ARRaycastManager.Raycast(...)` | `ARRaycastManager.raycast(...)` or `screen_raycast(...)` |
| `ARAnchorManager.AddAnchor(...)` | `ARAnchorManager.add_anchor(...)` |
| `ARPlaneManager.trackables` | `ARPlaneManager.get_all_planes()` |
| `XROrigin.Camera` | `XRDeviceRig.get_camera()` |
| `XRRayInteractor` | `XRRayInteractor` |
| `XRGrabInteractable` | `XRGrabInteractable` |

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
	var ok := XRFoundation.start_session(XRFoundationTypes.Backend.AUTO, {
		"platform_hint": "rokid",
		"prefer_ar": true,
		"passthrough": true,
	})
	if not ok:
		push_warning(XRFoundation.last_error)
```

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

