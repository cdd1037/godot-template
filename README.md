# Godot 4.7.2 .NET 精简桌面导出模板

面向本项目的 2D / C# 游戏，使用 Compatibility 原生 OpenGL，仅构建 Release 模板，不包含 .NET 运行时。

## 下载

[统一 Release：4.7.2-slim.2](https://github.com/cdd1037/godot-template/releases/tag/4.7.2-slim.2)

- Windows x64：MSVC，主模板 50.63 MiB；同时保留同目录 console 包装器。
- Linux x64：48.54 MiB。
- macOS Apple Silicon：ZIP 15.64 MiB，内含 ARM64 可执行文件 45.28 MiB，不支持 Intel。

在匹配的 Godot 4.7.2 .NET 编辑器中选择对应自定义 Release 模板；关闭导出调试。具体能力边界及验证限制请先阅读构建说明和研究记录。

## 文档

- [配置影响与精简研究](docs/research/template-configuration-study.md)：实测体积、功能代价、API 兼容边界，以及采用、恢复、暂缓的方案。
- [机器可读测量与 SHA256](docs/research/measurements.json)。
- [三平台构建说明](artifacts/desktop-release-plan/README.md)。
- [当前功能配置](artifacts/desktop-release-plan/custom.py) 与 [工具链记录](artifacts/desktop-release-plan/toolchains.json)。
- [三平台 Actions](.github/workflows/desktop-releases.yml)。

研究文档用于保存证据与决策，不是对所有 2D 项目的通用裁剪推荐。体积数字不等于性能测试结果。
