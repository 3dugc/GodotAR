# GodotARCore Android Plugin

状态：C00 native singleton landing point。

这个目录放 Android ARCore 原生插件源码；`addons/godot_arcore` 放 Godot editor export hook。两者配合后，Android 导出可以包含 `GodotARCore` AAR，并在运行时通过：

```gdscript
Engine.has_singleton("GodotARCore")
Engine.get_singleton("GodotARCore")
```

交给 `NativeXRProvider` 统一适配。

## C00 范围

已实现：

- Android plugin v2 manifest entry：`org.godotengine.plugin.v2.GodotARCore`。
- `GodotARCore` singleton。
- ARCore availability / install request / session start-stop。
- `get_capabilities()` 输出 `runtime:"ARCore"`、`native_plugin:true`、`arcore_supported`、`arcore_running`。
- 生命周期中 pause/resume/close ARCore session。

未在 C00 承诺：

- 摄像头背景渲染到 Godot viewport。
- ARCore frame update、plane list、raycast、anchor 稳定放置。
- Android 权限弹窗 UI 和用户引导。

这些进入 `C03 Android ARCore Slice`。

## 构建

需要 Android SDK、Gradle、Google Maven、Godot Android Maven artifact。

```bash
android/plugins/godot_arcore/build_plugin.sh
```

可覆盖版本：

```bash
GODOT_ANDROID_VERSION=4.4.1.stable \
ARCORE_VERSION=1.33.0 \
android/plugins/godot_arcore/build_plugin.sh
```

脚本会把 AAR 拷贝到：

```text
addons/godot_arcore/bin/debug/GodotARCore-debug.aar
addons/godot_arcore/bin/release/GodotARCore-release.aar
```

然后打开 Godot editor，确认 `GodotARCore` addon 已启用，并在 Android export preset 的 Plugins 里启用 `GodotARCore`。

## C00 设备验证

Android ARCore preset 至少需要：

```text
gradle_build/use_gradle_build=true
command_line/extra_args="--xr-platform=arcore"
permissions/camera=true
plugins/GodotARCore=true
```

设备机执行：

```bash
tools/c00/run_device_cycle.sh android-arcore
```

C00 gate 会要求日志中看到：

- `backend:"ARCore"`
- `capabilities.native_plugin:true`
- `capabilities.runtime:"ARCore"` 或 `capabilities.arcore_supported:true`
- 启动平台证据指向 `arcore` / `handheld` / `phone`
- Android device profile JSON 检测到 ARCore package，例如 `com.google.ar.core`

## 参考

- Godot Android plugin v2: https://docs.godotengine.org/en/4.5/tutorials/platform/android/android_plugin.html
- ARCore Android enable guide: https://developers.google.com/ar/develop/java/enable-arcore
