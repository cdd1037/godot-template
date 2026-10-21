# Desktop slim .NET release pipeline

## Install in the repository

Keep this directory at `artifacts/desktop-release-plan/`. Copy `workflow.desktop-releases.yml` to `.github/workflows/desktop-releases.yml`. Disable/delete the previous Windows MSVC size-comparison workflow, or remove its push trigger, in the same commit. Do not leave both workflows active on the same push.

Pushes touching this plan on `main`, or manual dispatch, start three parallel jobs. Each job uses internal compiler parallelism (Linux all runner CPUs; Windows up to 4 jobs; macOS 3 jobs), builds **only template_release**, produces symbol-free normal templates (Windows uses MSVC /DEBUG:NONE; no GNU strip), then uploads separate evidence. The publish job runs only after all three succeed. It creates a new `4.7.2-slim.N` tag/release; existing tags/releases are not overwritten. For a rerun after publication choose a new suffix. The default suffix is the workflow run number, not an upstream version claim.

## Toolchains and provenance

- Engine SHA: `ed1daf0bf001b61586d9930840f2f1394092c079`.
- Official 4.7 container recipes: `godotengine/build-containers@3f3cc50c3f91c2be66e37aece9d9a57284e39db7`.
- Reference official release build scripts: `godotengine/godot-build-scripts@63625f75c0f869dea4a01811522e10fefcd0f322`.
- Linux: official Fedora 43 container recipe and Buildroot `godot-2023.08.x-4`, GCC 13.2 / glibc 2.28 / binutils 2.40. The complete upstream recipe is built unchanged (it includes unused SDK architectures; engine compilation is x86_64 only).
- Windows: native `windows-2022`, Visual Studio 2022/MSVC family `14.3`, pinned SCons `4.10.1`, static C++ CRT, full LTO and speed optimization. Exact runner image, toolset and Windows SDK versions are recorded; runner contents can change. No fallback to MinGW/LLVM.
- macOS: user-approved native `macos-15` Apple Silicon runner; explicitly selects `/Applications/Xcode_26.1.1.app`, verifies Xcode build `17B100`, SDK `26.1` and host arm64. No automatic upgrade to another Xcode. macOS minimum deployment target is 11.0 as specified in this engine's arm64 platform configuration.

Official prebuilt registry images were unavailable during preparation and Apple images require private SDK inputs. Therefore Linux builds the pinned public recipe; Windows uses the native MSVC toolchain; macOS uses the explicitly approved native alternative. These are **not claimed to be byte-identical official release images**. Fedora base tags and package repositories remain mutable; save image inspection, complete RPM package lists and compiler versions in Actions evidence. No fictional image digests or credentials are required. A future fully immutable pipeline can replace recipe builds with verified, accessible official-generation image digests.

References: [official container recipes](https://github.com/godotengine/build-containers/tree/3f3cc50c3f91c2be66e37aece9d9a57284e39db7), [official release scripts](https://github.com/godotengine/godot-build-scripts/tree/63625f75c0f869dea4a01811522e10fefcd0f322), [GitHub macOS 15 arm64 image inventory](https://github.com/actions/runner-images/blob/main/images/macos/macos-15-arm64-Readme.md).

## Compatibility and scope

`custom.py` preserves trim6/no-four-images settings and explicitly retains Graphite. No `disable_3d`/API pruning experiment is applied. GDExtension remains built in; no non-existent GDExtension SCons option is added. AccessKit is disabled on all targets. Speed/full-LTO is intentional, including macOS where upstream defaults may differ; it increases build/link memory and time.

The prior local `artifacts/relr-trim6` experiment is untouched. Do **not** add `-z pack-relative-relocs` to this pipeline: the official SDK is based on glibc 2.28, while glibc's DT_RELR contract would require a newer runtime (normally 2.36). This workflow keeps the official baseline instead of silently raising it. It statically audits ELF symbol requirements and rejects DT_RELR without executing the binary. The glibc baseline is not a promise that every .NET/game dependency runs on every glibc-2.28 distribution.

## Packaging and use

See `RELEASE_NOTES.md`. Windows publishes its release binary plus console wrapper; Linux publishes a stripped executable. macOS ZIP uses the engine's complete `misc/dist/macos_template.app` skeleton, plist, privacy manifest and icon, plus `Contents/MacOS/godot_macos_release.arm64`, with executable permissions preserved. It is a custom export-template ZIP, not a raw Mach-O binary or universal bundle. No debug template or editor is built; use non-debug exports and arm64 architecture on macOS.

Evidence is kept separate from release template assets: build logs, custom configuration, toolchain manifest, compiler/package versions, linker maps where supported, detached ELF symbols, Windows native linker MAP files (any incidental PDBs kept separately), macOS dSYM and unstripped engine. No engine/game execution or size comparison occurs. The packaging script checks ZIP structure and architecture is inspected using `lipo`, not by launching it.

## Local verification status

Bash syntax and Python compilation are checked; packaging is exercised on inert fixtures, never game executables. Full cross-platform compilation/publication must be verified by the actual Actions run; no local build or release success is implied by these files.

Windows keeps WinRT/TTS enabled using the MSVC SDK headers. `/MAP` uses separate output-derived names for main and console wrapper, without the MinGW SCsub patch. Windows defaults to `debug_symbols=no` (`/DEBUG:NONE`); no PDB generation is promised. It preserves any incidental PDB files separately. No GNU strip/objcopy is used on MSVC outputs. No .NET runtime is bundled. Critical renderer/AccessKit/Graphite flags are repeated on the SCons command line so platform defaults cannot override them.
