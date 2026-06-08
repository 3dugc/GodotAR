# Godot XR Foundation

This is a Godot 4 starter project and addon that mirrors the shape of Unity XR Interaction Toolkit and AR Foundation.

The goal is not to hide Godot. The goal is to give Unity projects a familiar migration layer:

- One session facade: `XRFoundation`
- One rig: `XRDeviceRig` with `XROrigin3D`, `XRCamera3D`, and hand/controller nodes
- AR-style managers: `XRSessionManager`, `ARRaycastManager`, `ARPlaneManager`, `ARAnchorManager`
- XRI-style components: `XRRayInteractor`, `XRGrabInteractable`
- Provider backends: Editor simulation, OpenXR/Rokid, ARCore, ARKit

The project is addon/plugin-first. Platform support should live in Godot addons, Android plugins, iOS plugins, GDExtensions, or OpenXR vendor extensions. Engine patches are a last resort and must stay minimal and isolated.

## Current Scope

Implemented:

- C00 device smoke test scene: `demo/00_device_smoke_test.tscn`.
- `GXF_SMOKE|{...}` structured runtime logs for backend, provider, tracking, capabilities, FPS, and errors.
- Unity AR Foundation-style `ARSession` compatibility wrapper with `CheckAvailability`, `Install`, `Reset`, and `state` aliases.
- Provider availability reports and capability flags.
- Runtime backend selection with fallback to editor simulation.
- OpenXR startup through `XRServer.find_interface("OpenXR")`.
- AR passthrough setup through `XRInterface.environment_blend_mode` when supported.
- Editor simulated floor raycasts and plane data.
- Generic native bridge points for ARCore and ARKit plugin singletons or XR interfaces.
- GodotARCore Android plugin v2 landing point with ARCore availability/install/session lifecycle singleton.
- Android XR/OpenXR trackable plane discovery through `XRServer` tracker signals without hard-linking vendor classes.
- GodotARKit iOS plugin bridge with native tracking reason, raycast, and plane evidence.
- Demo scene where mouse clicks place anchored cubes on the simulated floor.

Planned next:

- ARCore camera background, frame update, plane/raycast, and anchor bridge.
- OpenXR Android/Rokid raycast bridge using the vendor plugin's Android XR extension classes in an optional script that is only enabled when the vendor plugin is installed.
- Input action map presets for hand tracking, controller select/grab, and gaze.

## Open The Demo

Open this folder in Godot 4:

```text
outputs/godot_xr_foundation
```

Run `demo/00_device_smoke_test.tscn` first. This is the first-cycle device gate for Rokid/OpenXR, iPad/ARKit, and Android/ARCore.

Then run `demo/main.tscn` for the placement sample.

In the editor, the project falls back to `Editor Simulation`. Click in the viewport to place cubes on the simulated floor.

For Rokid or other Android OpenXR hardware, set `XRSessionManager.platform_hint` to `rokid` or `openxr`.

For phone ARCore, set `XRSessionManager.platform_hint` to `handheld_ar` or set `requested_backend` to `ARCore`.

For iOS ARKit, set `requested_backend` to `ARKit`.

The smoke test prints structured lines:

```text
GXF_SMOKE|{"cycle":"C00","event":"heartbeat","backend":"OpenXR","provider":"OpenXR",...}
```

For C00, a real Rokid pass must show `backend=OpenXR`, a real iPad pass must show `backend=ARKit`, and a real Android phone/tablet pass must show `backend=ARCore`. `EditorSim` proves that the Godot app starts, but it does not satisfy the device gate.

## Key Files

- `addons/godot_xr_foundation/scripts/xr_foundation.gd`  
  Autoload facade and provider selection.

- `addons/godot_xr_foundation/scripts/providers/openxr_provider.gd`  
  OpenXR/Rokid startup.

- `addons/godot_xr_foundation/scripts/providers/native_xr_provider.gd`  
  Generic ARCore/ARKit native plugin bridge.

- `addons/godot_arcore/` and `android/plugins/godot_arcore/`: Android ARCore export plugin and native singleton source.

- `ios/plugins/godot_arkit/`: iOS ARKit native singleton source and build helper.

- `addons/godot_xr_foundation/scripts/arfoundation/`  
  Unity ARFoundation-style managers.

- `addons/godot_xr_foundation/scripts/xri/`  
  Unity XRI-style interaction components.

- `PRODUCT_ROADMAP_CN.md`  
  Long-term product and engineering roadmap in Chinese, with phase deliverables.

- `PHASE_WORK_BREAKDOWN_CN.md`  
  Stage-by-stage work breakdown with runnable outputs, detection gates, and publishable results.

- `DEVICE_BRINGUP_CHECKLIST_CN.md`  
  Rokid, Quest/PICO OpenXR, Android ARCore, and iOS ARKit device bring-up checklist.

- `releases/phase_0_smoke/`
  C00 device runbook and test report template.

- `tools/c00/`
  C00 preflight, export helper, device log collection, and gate validation scripts.

- `SPEC_DRIVEN_EXECUTION_CN.md`  
  Spec-driven execution plan: every cycle must be runnable, detectable, and publishable.

- `OPENXR_AR_FIRST_SPEC_CN.md`  
  OpenXR-first AR strategy for Rokid, Quest, PICO, Android XR, and other OpenXR devices.

- `specs/OPENXR_AR_PROVIDER_SPEC_CN.md`  
  Provider-level spec for OpenXR AR feature modules and device profiles.

- `PROVIDER_PRIORITY_AND_RELEASE_GATES_CN.md`  
  Defines OpenXR, ARKit, and ARCore as equal P0 providers, with Rokid/OpenXR, iPad/ARKit, and Android/ARCore as C00 release gates.

- `GODOT_PLUGIN_BOUNDARY_CN.md`
  Defines the addon/plugin-first architecture rule and engine-patch escalation rules.

- `UNITY_REFERENCE_RULES_CN.md`  
  Rules for resolving architecture ambiguity by reverse-engineering Unity AR Foundation, XR Plug-in, and OpenXR documentation.

- `XRI_REFERENCE_RULES_CN.md`  
  Unity XR Interaction Toolkit reference rules for Interaction Manager, Interactors, Interactables, input readers, and hover/select/activate semantics.

- `specs/cycles/`  
  Frozen/draft cycle specs for device smoke test, foundation MVP, OpenXR AR devices, Android ARCore, and iOS ARKit slices.

## Why Providers

Godot's stable XR abstraction is `XRServer` and `XRInterface`. ARCore, ARKit, and OpenXR expose different platform capabilities, so this addon keeps platform-specific code behind providers and exposes migration-friendly managers to gameplay code.

Godot AR/MR passthrough is configured through environment blend modes. OpenXR Android XR/Rokid-style support depends on the OpenXR runtime and, for vendor extensions, the Godot OpenXR Vendors plugin.

## References

- Godot XR setup: https://docs.godotengine.org/en/4.6/tutorials/xr/setting_up_xr.html
- Godot AR / passthrough: https://docs.godotengine.org/en/4.4/tutorials/xr/ar_passthrough.html
- Godot OpenXR Vendors plugin: https://godotvr.github.io/godot_openxr_vendors/
- Android XR for Godot: https://developer.android.com/develop/xr/godot
- Godot ARCore plugin repository: https://github.com/GodotVR/godot_arcore
- Godot iOS plugins repository: https://github.com/godot-sdk-integrations/godot-ios-plugins
