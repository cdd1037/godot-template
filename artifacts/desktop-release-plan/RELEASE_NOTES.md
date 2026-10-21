Release-only Godot 4.7.2 slim .NET export templates, source `ed1daf0bf001b61586d9930840f2f1394092c079`.

- Windows x86_64: `windows_release_x86_64.exe` and matching `.console.exe` wrapper; keep both in the same directory.
- Linux x86_64: `linux_release.x86_64` (official Buildroot SDK; glibc 2.28 baseline; no RELR).
- macOS Apple Silicon only: select `macos_release.arm64.mono.zip` as the custom Release template and select architecture **arm64**. Do not extract it for the template setting. No Intel/universal or Debug template.

In the matching Godot 4.7.2 .NET editor, select each asset under the export preset's **Custom Template → Release**. Export with debug disabled. These are engine templates, not standalone games or a complete editor/.NET SDK. Use matching official GodotSharp managed assemblies; exported C# games still require their normal managed publish output.

Compatibility renderer / native OpenGL only. AccessKit, GDScript, VisualShader, regex, camera, Theora, BMP/TGA/HDR/TinyEXR, 3D physics/navigation implementations, XR implementations and network modules are disabled. Full public 3D API, GDExtension and Graphite are retained. No Vulkan, D3D12, ANGLE or Metal.

Linux uses the pinned official 4.7 release-container recipe. Windows uses native Visual Studio 2022 MSVC (static C++ runtime, no bundled .NET runtime). macOS uses the user-approved native GitHub Apple Silicon runner with Xcode 26.1.1 / SDK 26.1, rather than the official private osxcross image. All use speed optimization and full LTO. macOS templates are unsigned/unnotarized; sign/notarize final games as appropriate.

`SHA256SUMS` verifies assets. Separate build logs, compiler/package provenance and symbol evidence are in this workflow run's Actions artifacts. The workflow performs no game launches, runtime smoke tests or size comparisons.
