# Cycle Spec Template

状态：Draft / Frozen / In Progress / Done / Blocked

周期：

版本：

日期：

负责人：

## 一句话成果

本周期完成后，用户可以：

## 目标设备

| 设备 | 是否必须 | 运行方式 | 备注 |
| --- | --- | --- | --- |
| Editor | Yes | Godot editor |  |
| Rokid / OpenXR | Yes | APK | 每周期 release gate |
| iPad / ARKit | Yes | Xcode project / IPA | 每周期 release gate |
| Android ARCore |  | APK |  |

## 范围

### 本周期做

- 

### 本周期不做

- 

## 用户故事

- 作为开发者，我可以...
- 作为测试者，我可以...
- 作为观看成果的人，我可以...

## API / 接口

新增：

- 

冻结：

- 

废弃或变更：

- 

## Demo

场景：

```text
demo/<name>.tscn
```

运行路径：

- Editor：
- Rokid：
- Android：
- iOS：

## 检测计划

| 用例 | 平台 | 步骤 | 通过标准 |
| --- | --- | --- | --- |
|  |  |  |  |

## Release Gates

- [ ] Rokid/OpenXR 已运行并归档结果。
- [ ] iPad/ARKit 已运行并归档结果。
- [ ] EditorSim 已完整运行。
- [ ] Android/ARCore smoke 或 capability 已记录；C03 之后必须回归。
- [ ] Unity 文档参考已记录。

## 日志要求

必须输出：

```text
[XRFoundation] app_version=
[XRFoundation] cycle=
[XRFoundation] backend=
[XRFoundation] provider=
[XRFoundation] session_state=
[XRFoundation] tracking_state=
[XRFoundation] capabilities=
[XRFoundation] error=
```

## 发表要求

本周期必须产出：

- 安装包或可运行项目路径：
- 截图：
- 录屏：
- Release note：
- 已知限制：
- 下一周期预告：

## 验收标准

- [ ] 可以运行
- [ ] 可以检测
- [ ] 可以发表
- [ ] 文档已更新
- [ ] 风险已记录

## 风险

| 风险 | 影响 | 缓解 |
| --- | --- | --- |
|  |  |  |
