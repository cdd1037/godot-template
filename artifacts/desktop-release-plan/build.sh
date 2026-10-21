#!/usr/bin/env bash
# Runs inside the official release SDK container; never executes a game/template.
set -euo pipefail
cd /src
cp /plan/custom.py custom.py
mkdir -p /out/assets /out/evidence
cp /plan/custom.py /plan/toolchains.json /out/evidence/
rpm -qa | sort > /out/evidence/rpm-packages.txt
scons --version > /out/evidence/scons-version.txt
args=(target=template_release production=yes optimize=speed lto=full debug_symbols=yes module_mono_enabled=yes opengl3=yes vulkan=no d3d12=no angle=no metal=no accesskit=no graphite=yes)
case "${PLATFORM:?}" in
  linux)
    : "${GODOT_SDK_LINUX_X86_64:?Missing official Buildroot SDK}"
    export PATH="$GODOT_SDK_LINUX_X86_64/bin:$PATH"
    prefix="$GODOT_SDK_LINUX_X86_64/bin/x86_64-godot-linux-gnu-"
    args+=(platform=linuxbsd arch=x86_64 use_llvm=no "CC=${prefix}gcc" "CXX=${prefix}g++" "AR=${prefix}ar" "RANLIB=${prefix}ranlib")
    strip="${prefix}strip"; objcopy="${prefix}objcopy"
    binary=bin/godot.linuxbsd.template_release.x86_64.mono
    # No -z pack-relative-relocs: keep the official glibc 2.28 baseline.
    args+=("linkflags=-Wl,-Map,/out/evidence/linux.map")
    "${prefix}gcc" --version > /out/evidence/compiler.txt
    ;;
  windows)
    patch -p1 < /plan/separate-maps.patch
    cp /plan/separate-maps.patch /out/evidence/
    test -d bin/build_deps/winrt_mingw
    args+=(platform=windows arch=x86_64 use_mingw=yes use_llvm=no use_static_cpp=yes winrt=yes "linkflags=-Wl,-Map,/out/evidence/windows_main.map")
    strip=x86_64-w64-mingw32-strip; objcopy=x86_64-w64-mingw32-objcopy
    binary=bin/godot.windows.template_release.x86_64.mono.exe
    x86_64-w64-mingw32-gcc --version > /out/evidence/compiler.txt
    ;;
  *) exit 2 ;;
esac
printf '%q ' scons -j"${NUM_CORES:-2}" "${args[@]}" > /out/evidence/command.txt
printf '\n' >> /out/evidence/command.txt
scons -j"${NUM_CORES:-2}" "${args[@]}" 2>&1 | tee /out/evidence/build.log
test -s "$binary"
cp "$binary" /out/evidence/template.unstripped
"$objcopy" --only-keep-debug "$binary" /out/evidence/template.debug
"$strip" --strip-all "$binary"
if [[ "$PLATFORM" == linux ]]; then
  "${prefix}readelf" --version-info "$binary" > /out/evidence/elf-version-info.txt
  "${prefix}readelf" -d "$binary" > /out/evidence/elf-dynamic.txt
  # Audit only; does not run the built engine. Fail if glibc requirements drift.
  python3 - <<'PY'
import re
from pathlib import Path
s = Path('/out/evidence/elf-version-info.txt').read_text()
versions = [tuple(map(int, v.split('.'))) for v in re.findall(r'GLIBC_(\d+\.\d+(?:\.\d+)?)', s)]
assert versions and max(versions) <= (2, 28), f'glibc baseline exceeded: {max(versions, default=None)}'
assert 'GLIBC_ABI_DT_RELR' not in s
assert '(RELR)' not in Path('/out/evidence/elf-dynamic.txt').read_text()
PY
fi
if [[ "$PLATFORM" == windows ]]; then
  wrapper="${binary%.exe}.console.exe"
  test -s "$wrapper"
  "$objcopy" --only-keep-debug "$wrapper" /out/evidence/console-wrapper.debug
  "$strip" --strip-all "$wrapper"
fi
python3 /plan/package.py "$PLATFORM" --source /src --binary "$binary" --output /out/assets
# Separate debug evidence is uploaded to Actions, not installed as an export template.
