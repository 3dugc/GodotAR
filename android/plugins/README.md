# Android Plugins

Android platform support lives here first. Gameplay code must not call Android Java or Kotlin APIs directly; expose platform functions through a Godot singleton or XRInterface, then adapt them in `NativeXRProvider`.

Current plugin-first paths:

- `godot_arcore/`: C00 Android ARCore plugin source. It builds a `GodotARCore` Android plugin v2 AAR and exposes an ARCore availability/session singleton.
- OpenXR/Rokid vendor plugin files: place downloaded vendor AAR/export hooks here when the chosen vendor package requires local plugin files.
- Optional GDExtension binaries compiled for Android ABIs.

Build the ARCore plugin on a device/build machine:

```bash
android/plugins/godot_arcore/build_plugin.sh
```

The script copies AARs into `addons/godot_arcore/bin`, where the Godot export plugin can include them in the Android ARCore preset.
