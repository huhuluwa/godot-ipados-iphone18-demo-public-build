# Godot iOS / iPadOS Port Harness

这是一个用于验证 Godot 4.7.2 移动端导出链路的最小项目。它包含可点击按钮、原生触控事件、窗口尺寸读数、移动渲染器和 iPhone/iPad 通用设备族配置。

## 本地运行

1. 使用 Godot 4.7.2 打开项目目录。
2. 运行主场景。
3. 点击 `Tap +1` 或在触控设备上点击屏幕，确认计数器与状态文本更新。

## iOS 构建

`export_presets.cfg` 中的 `AAAAAAAAAA` 只用于满足 Godot iOS 导出器的格式要求。它不是签名凭据，也不会连接 Apple Developer 账户。

Codemagic 流水线只构建未签名 Xcode 工程、未签名 `.xcarchive` 和未签名 `.ipa` 容器。未签名 `.ipa` 不能直接安装到 iPad 或 iPhone。

