# Godot XR Foundation C00 Test Report

Cycle: C00 Device Smoke Test

Version: v0.0.1-c00-device-smoke

Scene: `res://demo/00_device_smoke_test.tscn`

## Summary

| Gate | Required backend | Result | Evidence |
| --- | --- | --- | --- |
| Editor smoke | EditorSim | Pending local Godot run | Screenshot/log |
| Rokid AR gate | OpenXR | Pending device run | Screenshot/log |
| iPad AR gate | ARKit | Pending device run | Screenshot/log |
| Android ARCore availability | ARCore | Pending device run | Screenshot/log |
| Plugin boundary | No engine patch | Pass by implementation | Addon/provider only |

Codex implementation status:

- C00 smoke scene created.
- Runtime status panel created.
- `GXF_SMOKE` structured logs created.
- Provider capability reports created.
- Unity-style `ARSession` wrapper created.
- Godot plugin-first boundary documented. No Godot engine patch is used in C00.

Hardware status:

- Not executed in this Codex environment because Godot executable, Rokid hardware, and iPad hardware are not available here.
- Do not mark this report as passed until the device evidence below is filled.

## Device Evidence

### Rokid / OpenXR

Device:

OS/runtime:

Godot version:

OpenXR Vendors plugin version:

Extension path:

Observed panel:

```text
Session:
Backend:
Provider:
Tracking:
AR path:
Blend:
```

Required log snippets:

```text
GXF_SMOKE|
```

Result:

- [ ] Pass
- [ ] Fail

Notes:

### iPad / ARKit

Device:

iPadOS:

Godot version:

ARKit plugin build:

Extension path:

Observed panel:

```text
Session:
Backend:
Provider:
Tracking:
Native plugin:
```

Required log snippets:

```text
GXF_SMOKE|
```

Result:

- [ ] Pass
- [ ] Fail

Notes:

### Android Phone / ARCore

Device:

Android version:

Godot version:

ARCore plugin build:

Extension path:

Observed panel:

```text
Session:
Backend:
Provider:
Tracking:
Native plugin:
```

Required log snippets:

```text
GXF_SMOKE|
```

Result:

- [ ] Pass
- [ ] Fail

Notes:

## C00 Pass Rules

- Rokid passes only when `backend:"OpenXR"` and `session_state:"Running"` are present in `GXF_SMOKE`.
- iPad passes only when `backend:"ARKit"` and `session_state:"Running"` are present in `GXF_SMOKE`.
- `EditorSim` is useful evidence that the app starts, but never satisfies a device AR gate.
- OpenXR with only `opaque` blend mode is an OpenXR rendering pass, not an AR product pass.
- Any engine patch must include a minimal-intrusion patch spec before the device gate can be marked complete.
