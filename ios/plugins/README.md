# iOS Plugins

Put ARKit iOS plugin files here when they are built or downloaded.

Expected plugin-first path:

- `.gdip` plugin configuration.
- `.xcframework` or static library artifacts.
- Required system frameworks and capabilities declared by the plugin.

The gameplay layer must not call Swift or Objective-C classes directly. Expose ARKit through a Godot singleton or XRInterface, then adapt it in `NativeXRProvider`.
