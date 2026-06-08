# Platform Setup

## Shared Godot Settings

Use Godot 4.3 or newer. Godot 4.6 is preferred for current Android XR/OpenXR vendor work.

The demo project already enables:

```ini
[xr]
openxr/enabled=true
shaders/enabled=true
```

For production builds, also review the OpenXR form factor and view configuration:

- Phone AR: handheld + mono when using a handheld OpenXR path.
- Rokid / glasses / headset: head mounted + stereo when the runtime presents that form factor.

## Android Phone ARCore

ARCore is handled by `NativeXRProvider`.

The provider searches for an XR interface named one of:

```gdscript
["ARCore", "GodotARCore", "ARCoreInterface"]
```

It also searches for plugin singletons named:

```gdscript
["GodotARCore", "ARCore", "ARCorePlugin"]
```

If your chosen ARCore plugin exposes different names, pass them through `XRFoundation.start_session()`:

```gdscript
XRFoundation.start_session(XRFoundationTypes.Backend.ARCORE, {
	"arcore_interface_names": ["YourARCoreInterface"],
	"arcore_singleton_names": ["YourARCoreSingleton"],
	"platform_hint": "handheld_ar",
})
```

Native plugin methods currently supported by convention:

- `initialize()`, `start()`, `start_session()`, or `resume()`
- `stop()`, `stop_session()`, or `pause()`
- `try_raycast(origin, direction, max_distance)`, `raycast(...)`, or `hit_test(...)`
- `create_anchor(transform, attached_trackable)` or `add_anchor(...)`

## iOS ARKit

ARKit is also handled by `NativeXRProvider`.

The provider searches for:

```gdscript
["ARKit", "GodotARKit", "ARKitInterface"]
```

and singletons:

```gdscript
["GodotARKit", "ARKit", "ARKitPlugin"]
```

iOS plugin singletons are normally only available in exported iOS builds, not when running in the desktop editor. Keep editor simulation enabled for desktop iteration.

## Rokid / OpenXR

Rokid should be treated as the OpenXR path unless Rokid's SDK requires a custom Godot plugin.

Use:

```gdscript
XRFoundation.start_session(XRFoundationTypes.Backend.OPENXR, {
	"platform_hint": "rokid",
	"prefer_ar": true,
	"passthrough": true,
})
```

For Android OpenXR exports:

- Install Android build templates.
- Enable Gradle build.
- Select OpenXR as XR mode in the Android export preset.
- Install and configure the Godot OpenXR Vendors plugin if vendor extensions or Android XR features are required.
- Enable only the vendor needed by that export preset.

## Android XR Trackables

The OpenXR Vendors plugin exposes Android XR plane/object/anchor tracker classes through `XRServer` trackers.

This addon avoids hard dependencies on those classes. `ARPlaneManager` listens to:

```gdscript
XRServer.tracker_added
XRServer.tracker_removed
```

and accepts trackers whose class name contains `plane`.

Raycasts against the physical environment need the Android XR raycast extension. Keep that bridge optional because referencing vendor extension classes directly will fail in projects where the plugin is not installed.

