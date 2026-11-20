# Godot iOS / iPadOS Port Harness

这是一个用于验证 Godot 4.7.2 移动端导出链路的最小项目。它包含可点击按钮、原生触控事件、窗口尺寸读数、移动渲染器和 iPhone/iPad 通用设备族配置。

## 本地运行

1. 使用 Godot 4.7.2 打开项目目录。
2. 运行主场景。
3. 点击 `Tap +1` 或在触控设备上点击屏幕，确认计数器与状态文本更新。

## iOS 构建

`export_presets.cfg` 中的 `AAAAAAAAAA` 是占位 Team ID。CI 构建前需要用 Apple Developer Team ID 替换它，并由 Codemagic 的签名集成提供证书与 provisioning profile。

Codemagic 的免费个人计划提供每月 500 分钟 macOS M2 构建额度。真实设备可安装的 IPA 需要 Apple Developer Program 签名材料。

