# Godot 插件优先边界

状态：Frozen for C00

## 原则

本项目必须优先作为 Godot 项目插件和平台插件存在，而不是 Godot engine fork。

优先级：

1. GDScript addon：`addons/godot_xr_foundation`
2. Godot Android plugin：`res://android/plugins`
3. Godot iOS plugin：`res://ios/plugins`
4. GDExtension：跨平台 native 能力
5. OpenXR Vendors / 设备厂商扩展插件
6. 最小 Godot engine patch

第 6 项只有在前 5 项都无法满足关键 AR 能力时才允许进入设计。

## 为什么这样做

- 方便跟随 Godot 4.x 升级。
- 避免把 ARCore、ARKit、Rokid、PICO、Quest 等设备差异写进 gameplay。
- 让 Unity 迁移层保持稳定，底层 provider 可以替换。
- 降低 CI、导出模板、Xcode/Gradle 维护成本。

## 当前 C00 结论

C00 不需要修改 Godot 主干。

当前实现路径：

- `XRFoundation` autoload + addon scripts
- `EditorSimProvider`
- `OpenXRProvider` 通过 `XRServer.find_interface("OpenXR")`
- `NativeXRProvider` 通过 XRInterface 或 `Engine.get_singleton()` 连接 ARCore/ARKit 插件
- `android/plugins` 和 `ios/plugins` 作为 native plugin 固定落点
- `android/plugins/godot_arcore` + `addons/godot_arcore` 提供 `GodotARCore` Android plugin v2 / AAR export hook / singleton 落点
- `ios/plugins/godot_arkit` 提供 `GodotARKit` singleton 插件骨架
- C00 smoke scene 输出统一 `GXF_SMOKE` 日志

## 平台插件边界

### OpenXR / Rokid

默认走 Godot OpenXR interface 和 OpenXR Vendors 插件。

允许：

- 读取 OpenXR runtime availability。
- 配置 environment blend mode。
- 使用 vendor plugin 暴露的 passthrough、trackables、anchors、raycast。
- 针对 Rokid 写 Godot addon/provider 适配层。

不允许：

- 在 gameplay 中直接写 Rokid SDK 调用。
- 为某个设备默认 fork Godot。

### iOS / ARKit

默认走 Godot iOS plugin。

允许：

- `.gdip` + `.xcframework`
- 通过 `Engine.get_singleton("GodotARKit")` 或 XRInterface 暴露能力。
- provider 负责把 ARKit plane/raycast/anchor 转成统一数据结构。

不允许：

- 让业务脚本依赖 Swift/Objective-C 类名。
- 为 ARKit 默认 fork Godot。

### Android / ARCore

默认走 Godot Android plugin 或 GDExtension。

允许：

- Android plugin v2 / AAR / Gradle export hook。
- 通过 singleton 或 XRInterface 暴露 ARCore lifecycle、raycast、plane、anchor。
- provider 负责转换成 `ARPlane`、`XRHit`、`ARAnchor`。

不允许：

- gameplay 直接依赖 Android Java/Kotlin 类。
- 为 ARCore 默认 fork Godot。

## Engine Patch 升级门槛

如果确实需要侵入 Godot 主干，必须先提交一份 patch spec：

- 不能通过 addon/plugin/GDExtension 实现的具体原因。
- 影响的 Godot 版本和文件列表。
- 最小 API surface。
- 与 provider 层的隔离方式。
- 回滚方案。
- Godot 升级时的 rebase 检查清单。
- 是否可以 upstream 给 Godot 或插件生态。

未完成上述说明，不进入 engine patch。

## 验收红线

每个周期的设备报告必须记录：

- 使用的扩展路径：addon、Android plugin、iOS plugin、GDExtension、OpenXR vendor plugin、engine patch。
- 如果是 engine patch，必须附 patch spec。
- 如果设备只能通过 engine patch 运行，但没有 patch spec，该周期不能标记为完成。

## 参考资料

- Godot Android plugins: https://docs.godotengine.org/en/4.4/tutorials/platform/android/android_plugin.html
- Godot iOS plugins: https://docs.godotengine.org/en/4.4/tutorials/platform/ios/ios_plugin.html
- Godot GDExtension: https://docs.godotengine.org/en/4.4/tutorials/scripting/gdextension/what_is_gdextension.html
- Godot AR/Passthrough: https://docs.godotengine.org/en/4.4/tutorials/xr/ar_passthrough.html
