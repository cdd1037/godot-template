#!/usr/bin/env bash
set -euo pipefail
root="$(pwd)"
plan="$root/artifacts/desktop-release-plan"
out="$root/dist"
mkdir -p "$out/assets" "$out/evidence"
# Explicit matching Xcode; never silently use the runner's changing default.
export DEVELOPER_DIR=/Applications/Xcode_26.1.1.app/Contents/Developer
test -d "$DEVELOPER_DIR"
[[ "$(uname -m)" == arm64 ]] || { echo 'Expected Apple Silicon runner'; exit 1; }
xcodebuild -version | tee "$out/evidence/xcode-version.txt"
grep -qx 'Xcode 26.1.1' "$out/evidence/xcode-version.txt"
grep -qx 'Build version 17B100' "$out/evidence/xcode-version.txt"
[[ "$(xcrun --sdk macosx --show-sdk-version)" == 26.1 ]]
export PATH="$(xcrun --find clang | xargs dirname):$PATH"
python3 -m venv "$root/.scons-venv"
source "$root/.scons-venv/bin/activate"
python -m pip install scons==4.10.1
cp "$plan/custom.py" "$root/engine/custom.py"
cp "$plan/custom.py" "$plan/toolchains.json" "$out/evidence/"
xcrun clang --version > "$out/evidence/compiler.txt"
printf '%s\n' "${ImageOS:-unknown} ${ImageVersion:-unknown}" > "$out/evidence/runner-image.txt"
cd "$root/engine"
[[ "$(git rev-parse HEAD)" == ed1daf0bf001b61586d9930840f2f1394092c079 ]]
args=(platform=macos arch=arm64 target=template_release production=yes optimize=speed lto=full debug_symbols=yes module_mono_enabled=yes opengl3=yes vulkan=no d3d12=no angle=no metal=no accesskit=no graphite=yes "linkflags=-Wl,-map,$out/evidence/macos.map")
printf '%q ' scons -j3 "${args[@]}" > "$out/evidence/command.txt"
scons -j3 "${args[@]}" 2>&1 | tee "$out/evidence/build.log"
binary=bin/godot.macos.template_release.arm64.mono
test -s "$binary"
# Inspect architecture, never launch the engine.
[[ "$(xcrun lipo -archs "$binary")" == arm64 ]]
xcrun dsymutil "$binary" -o "$out/evidence/template.dSYM"
cp "$binary" "$out/evidence/template.unstripped"
xcrun strip -S -x "$binary"
python3 "$plan/package.py" macos --source "$root/engine" --binary "$binary" --output "$out/assets"
