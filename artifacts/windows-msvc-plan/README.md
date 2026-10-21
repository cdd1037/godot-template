# MSVC native release size experiment

Prepared configuration only: no MSVC binary has been produced or measured locally.
This folder is independent of existing Linux and MinGW outputs.

## Repository layout and execution

Keep `custom.py`, `build.ps1`, and `measure.py` in `artifacts/windows-msvc-plan/`.
Install `windows-msvc-size.yml` as `.github/workflows/windows-msvc-size.yml` **last**.
Pushing those relevant paths on `main` triggers a build; manual dispatch is also available.
The workflow checks out upstream Godot commit
`ed1daf0bf001b61586d9930840f2f1394092c079` into an isolated directory, and verifies it before compilation.
No source archive, user data, old build output or private workspace path is needed in the repository.

Default run: compile and show exact bytes, MiB, SHA256 and static x64 PE/subsystem checks.
The compiled Godot main/wrapper are **never executed**, including `--version`; no tests, project export or smoke run.
The detailed build command/log is in the Actions console; the completed size table is in the job summary.
The runner's compiler tools, Python and SCons may of course execute to perform the compilation.

## Configuration held fixed

- Windows x86_64 .NET release template, production, speed, full LTO, threads, OpenGL.
- Graphite enabled; full public 3D core API retained (no class-pruning profile).
- Same explicitly disabled implementation/network/XR and extra leaf modules as prior trim6.
- GDScript, visual shaders, regex, camera, Theora, BMP/TGA/HDR/TinyEXR disabled.
- Vulkan/D3D12/ANGLE/Metal and AccessKit disabled.
- WinRT retained. MSVC uses Windows SDK WinRT headers; the MinGW-only WinRT download is unnecessary.
- Only native .NET template is compiled; managed glue is not regenerated and no .NET application runs.

## MSVC-specific decisions

Use `windows-2022`, Visual Studio 2022 (`msvc_version=14.3`), `use_mingw=no`,
`use_llvm=no`, static CRT (`/MT`) and non-incremental linking. Fail if VS C++ tools are absent,
rather than silently fall back to MinGW. SCons 4.10.1 is the pinned source's own dependency version.
The exact runner image, compiler installation/toolset and SDK are recorded because hosted images evolve.
No GNU `-Wl`, Linux RELR flags, strip command, or MinGW prefix is carried across.

Godot's MSVC `lto=auto` disables LTO, so explicitly retain `lto=full` (`/GL` + `/LTCG`).
`optimize=speed` selects `/O2`. Explicit `/OPT:REF /OPT:ICF` preserves release linker optimization.
`/MAP` uses per-output default filenames, so main and console-wrapper maps do not overwrite one another.

Default `debug_symbols=no` matches the previous size build and produces no PDB.
Optional `debug_symbols=true` on manual dispatch requests full PDBs with the same release optimization,
not a debug target. It can add EXE debug-directory metadata and is labeled as a separate variant.
PDBs/maps are not counted as executable size. Do not strip an MSVC EXE with MinGW strip.

Artifacts are opt-in: `upload_reports` retains logs/maps for seven days;
`upload_binaries` retains EXEs and any final PDBs for three days.
Without those inputs the maps/PDBs remain on the ephemeral runner only and disappear after the job;
the size summary and Actions console remain available. No giant artifact upload is required.

## Comparison limits

Prior same-feature MinGW stripped main: **66,711,040 bytes (63.620605 MiB)**;
official full .NET Release reference: **109,513,728 bytes (104.440430 MiB)**.
Console wrappers are reported separately. No invented MSVC result is supplied.
The former is the practical toolchain-size comparison; the latter additionally changes feature set.
MSVC changes compiler, linker, CRT and SDK/host versus MinGW and is **not** a reproduction of
Godot's official MinGW build environment. Neither size result establishes functionality or performance.

## Checked references

Pinned local source: `platform/windows/detect.py` (MSVC/CRT/SDK/LTO), `SConstruct`
(release optimization and debug symbols), `modules/text_server_adv/config.py` (Graphite default),
and `.github/actions/godot-deps/action.yml` (SCons 4.10.1).

Official external references checked during preparation:
- https://docs.godotengine.org/en/4.7/engine_details/development/compiling/compiling_for_windows.html
- https://github.com/actions/checkout/releases/tag/v6.0.2
- https://github.com/actions/setup-python/releases/tag/v6.1.0
- https://github.com/actions/upload-artifact/releases/tag/v4.6.2

Action versions are explicit verified release tags, not asserted to be latest; tags are not immutable commit pins.
Python 3.12 is a minor-version selector. This workflow records a reproducible *configuration*, not bit-for-bit output.
