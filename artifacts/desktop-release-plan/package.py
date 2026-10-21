#!/usr/bin/env python3
"""Package already-stripped release templates. Never executes engine binaries."""
import argparse
import hashlib
import json
import shutil
import stat
import zipfile
from pathlib import Path


def zip_tree(root: Path, destination: Path):
    with zipfile.ZipFile(destination, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for path in sorted(root.rglob('*')):
            if path.is_file():
                info = zipfile.ZipInfo(path.relative_to(root).as_posix(), (2026, 1, 1, 0, 0, 0))
                info.create_system = 3
                info.external_attr = (stat.S_IFREG | (0o755 if path.stat().st_mode & 0o111 else 0o644)) << 16
                archive.writestr(info, path.read_bytes(), compress_type=zipfile.ZIP_DEFLATED)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('platform', choices=['linux', 'windows', 'macos'])
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--binary', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    stage = args.output / 'stage'
    stage.mkdir()
    if args.platform == 'macos':
        bundle = stage / 'macos_template.app'
        shutil.copytree(args.source / 'misc/dist/macos_template.app', bundle)
        dest = bundle / 'Contents/MacOS/godot_macos_release.arm64'
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(args.binary, dest)
        dest.chmod(0o755)
        asset = args.output / 'macos_release.arm64.mono.zip'
        zip_tree(stage, asset)
        with zipfile.ZipFile(asset) as archive:
            expected = 'macos_template.app/Contents/MacOS/godot_macos_release.arm64'
            assert expected in archive.namelist()
            assert not any('x86_64' in n or 'debug' in n or 'universal' in n for n in archive.namelist())
            assert (archive.getinfo(expected).external_attr >> 16) & 0o111
    else:
        name = 'windows_release_x86_64.exe' if args.platform == 'windows' else 'linux_release.x86_64'
        asset = args.output / name
        shutil.copy2(args.binary, asset)
        asset.chmod(0o755)
    assets = [asset]
    if args.platform == 'windows':
        wrapper = args.binary.with_suffix('.console.exe')
        dest = args.output / 'windows_release_x86_64.console.exe'
        shutil.copy2(wrapper, dest)
        assets.append(dest)
    shutil.rmtree(stage)
    (args.output / f'{args.platform}.sha256').write_text(''.join(f'{hashlib.sha256(a.read_bytes()).hexdigest()}  {a.name}\n' for a in assets))
    print(json.dumps({'asset': str(asset), 'sha256': hashlib.sha256(asset.read_bytes()).hexdigest()}))


if __name__ == '__main__':
    main()
