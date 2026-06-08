# Android Plugins

Put Android ARCore or OpenXR vendor plugin files here when they are built or downloaded.

Expected plugin-first path:

- `.gdap` / `.gdplugin` / export hook files required by the Godot Android plugin version in use.
- `.aar` plugin binaries and Gradle dependencies.
- Optional GDExtension binaries compiled for Android ABIs.

The gameplay layer must not call Android Java/Kotlin APIs directly. Expose platform functions through a Godot singleton or XRInterface, then adapt them in `NativeXRProvider`.
