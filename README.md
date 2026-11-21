# Godot iOS / iPadOS Port Harness

这是一个用于验证 Godot 4.7.2 iOS/iPadOS 移动端导出链路和运行时能力的验证项目。它包含按钮点击、单指和多指触摸、拖动、捏合距离、触点可视化、窗口旋转、安全区、暂停/恢复生命周期、设备触觉、iOS 键盘输入、FPS 读数、移动渲染器和 iPhone/iPad 通用设备族配置。

## 本地运行

1. 使用 Godot 4.7.2 打开项目目录。
2. 运行主场景。
3. 点击 `Tap +1` 或在触控设备上点击屏幕，确认计数器与状态文本更新。
4. 同时放置两个手指并拖动，确认触点数量和捏合距离更新。
5. 旋转设备，确认方向和安全区读数变化。
6. 点击键盘输入框、触觉按钮，并将应用切到后台再恢复，确认对应状态更新。

## iOS 构建

`export_presets.cfg` 中的 `AAAAAAAAAA` 只用于满足 Godot iOS 导出器的格式要求。它不是签名凭据，也不会连接 Apple Developer 账户。

Codemagic 流水线只构建未签名 Xcode 工程、未签名 `.xcarchive` 和未签名 `.ipa` 容器。未签名 `.ipa` 不能直接安装到 iPad 或 iPhone。实体设备验收仍需要 Apple 签名配置。

