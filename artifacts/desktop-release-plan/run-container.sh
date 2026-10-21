#!/usr/bin/env bash
set -euo pipefail
platform="${1:?linux/windows/macos}"
root="$(pwd)"
mkdir -p dist/assets dist/evidence
[[ "$(git -C engine rev-parse HEAD)" == ed1daf0bf001b61586d9930840f2f1394092c079 ]]
[[ "$(git -C official-containers rev-parse HEAD)" == 3f3cc50c3f91c2be66e37aece9d9a57284e39db7 ]]
case "$platform" in
  linux|windows)
    image="slim-official-${platform}:4.7-pinned"
    docker build --progress=plain -f official-containers/Dockerfile.base \
      -t godot-fedora:4.7-pinned official-containers 2>&1 | tee dist/evidence/container-base.log
    docker build --progress=plain --build-arg img_version=4.7-pinned \
      -f "official-containers/Dockerfile.${platform}" -t "$image" official-containers \
      2>&1 | tee dist/evidence/container-target.log
    ;;
  *) exit 2 ;;
esac
if [[ "$platform" == windows ]]; then
  # Use the pinned engine's official dependency downloader (WinRT headers release 72).
  (cd engine && python3 misc/scripts/install_winrt.py) 2>&1 | tee dist/evidence/winrt-install.log
fi
docker image inspect "$image" > dist/evidence/container-inspect.json
# Do not expose checkout's credential helper or GitHub token inside the build container.
docker run --rm --network none -v "$root/engine:/src" \
  -v "$root/artifacts/desktop-release-plan:/plan:ro" -v "$root/dist:/out" \
  -e PLATFORM="$platform" -e NUM_CORES="$(nproc)" "$image" bash /plan/build.sh
