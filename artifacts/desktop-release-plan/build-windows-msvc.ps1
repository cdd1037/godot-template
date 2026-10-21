$ErrorActionPreference = 'Stop'
$root = $env:GITHUB_WORKSPACE
if (-not $root) { throw 'Run in the prepared GitHub Actions workspace.' }
$plan = Join-Path $root 'artifacts/desktop-release-plan'
$reports = Join-Path $root 'dist/evidence'
New-Item -ItemType Directory -Force $reports | Out-Null
$assets = Join-Path $root 'dist/assets'
New-Item -ItemType Directory -Force $assets | Out-Null
$vswhere = "${env:ProgramFiles(x86)}/Microsoft Visual Studio/Installer/vswhere.exe"
$vs = & $vswhere -latest -version '[17.0,18.0)' -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (-not $vs) { throw 'Visual Studio 2022 C++ x64 build tools not found; no fallback to MinGW.' }
$devcmd = Join-Path $vs 'Common7/Tools/VsDevCmd.bat'
$setupCmd = Join-Path $env:RUNNER_TEMP 'godot-msvc-environment.cmd'
@('@echo off', "call `"$devcmd`" -no_logo -arch=x64 -host_arch=x64", 'if errorlevel 1 exit /b %errorlevel%', 'set') | Set-Content -Encoding ascii $setupCmd
$lines = & cmd.exe /d /c $setupCmd
if ($LASTEXITCODE -ne 0) { throw 'VsDevCmd failed' }
foreach ($line in $lines) {
    if ($line -match '^([^=]+)=(.*)$') { [Environment]::SetEnvironmentVariable($matches[1], $matches[2], 'Process') }
}
Set-Location (Join-Path $root 'engine')
$commit = git rev-parse HEAD
if ($LASTEXITCODE -ne 0 -or $commit -ne 'ed1daf0bf001b61586d9930840f2f1394092c079') { throw 'Source revision mismatch' }
Copy-Item (Join-Path $plan 'custom.py') custom.py
@("Source: $commit", "VS: $vs", "VCToolsVersion: $env:VCToolsVersion", "WindowsSDKVersion: $env:WindowsSDKVersion", "Runner image: $env:ImageOS $env:ImageVersion", 'Debug symbols: no; native MSVC /DEBUG:NONE, no GNU strip') | Set-Content "$reports/toolchain.txt"
Get-Command cl.exe,link.exe | Format-List Name,Source | Out-String | Add-Content "$reports/toolchain.txt"
python --version 2>&1 | Add-Content "$reports/toolchain.txt"
python -m SCons --version 2>&1 | Add-Content "$reports/toolchain.txt"
Copy-Item custom.py "$reports/custom.py"
Copy-Item (Join-Path $plan 'toolchains.json') "$reports/toolchains.json"
# Match the verified no-g MSVC baseline. /MAP preserves linker evidence without
# introducing release PE debug-directory overhead. No external strip utility.
$symbols = 'no'
$jobs = [Math]::Min(4, [Environment]::ProcessorCount)
$sconsArgs = @("-j$jobs", 'platform=windows', 'arch=x86_64', 'target=template_release', 'production=yes', 'optimize=speed', 'lto=full', 'use_mingw=no', 'use_llvm=no', 'msvc_version=14.3', 'use_static_cpp=yes', 'incremental_link=no', 'winrt=yes', 'windows_subsystem=gui', 'opengl3=yes', 'linkflags=/MAP /OPT:REF /OPT:ICF', 'd3d12=no', 'vulkan=no', 'angle=no', 'metal=no', 'accesskit=no', 'graphite=yes', 'module_mono_enabled=yes', 'tests=no', "debug_symbols=$symbols", 'verbose=yes')
('python -m SCons ' + ($sconsArgs -join ' ')) | Add-Content "$reports/toolchain.txt"
$start = Get-Date
python -m SCons @sconsArgs 2>&1 | Tee-Object "$reports/build.log"
$result = $LASTEXITCODE
"Elapsed seconds: $((Get-Date).Subtract($start).TotalSeconds)" | Add-Content "$reports/toolchain.txt"
# Preserve native maps/PDBs as evidence, including after a failed build.
# /MAP without a filename creates separate main/console output maps.
$symbolDir = Join-Path $reports 'symbols'
New-Item -ItemType Directory -Force $symbolDir | Out-Null
Get-ChildItem -Path . -File -Recurse | Where-Object { $_.Extension -in '.map', '.pdb' } | ForEach-Object {
    $relative = [IO.Path]::GetRelativePath((Get-Location).Path, $_.FullName)
    $destination = Join-Path $symbolDir $relative
    New-Item -ItemType Directory -Force (Split-Path $destination) | Out-Null
    Copy-Item $_.FullName $destination
}
if ($result -ne 0) { throw "SCons failed with exit code $result" }
$binary = Join-Path (Get-Location).Path 'bin/godot.windows.template_release.x86_64.mono.exe'
$wrapper = [IO.Path]::ChangeExtension($binary, '.console.exe')
foreach ($file in @($binary, $wrapper)) {
    if (-not (Test-Path $file) -or (Get-Item $file).Length -eq 0) { throw "Missing output: $file" }
    $mapName = [IO.Path]::GetFileNameWithoutExtension($file) + '.map'
    if (-not (Get-ChildItem $symbolDir -Recurse -File -Filter $mapName)) { throw "Missing linker map: $mapName" }
    # Static inspection only; never launch the built template/wrapper.
    & dumpbin.exe /headers /dependents $file | Set-Content (Join-Path $reports ((Split-Path $file -Leaf) + '.headers.txt'))
    if ($LASTEXITCODE -ne 0) { throw "dumpbin failed for $file" }
}
'No PDB requested: debug_symbols=no (/DEBUG:NONE). MAP files are the native symbol evidence; any incidental PDBs are retained separately, never published.' | Set-Content "$reports/symbol-policy.txt"
python (Join-Path $plan 'package.py') windows --source (Get-Location).Path --binary $binary --output $assets
if ($LASTEXITCODE -ne 0) { throw 'Packaging failed' }
# package.py emits ONLY the same EXE pair plus windows.sha256. No .NET runtime,
# SDK, managed assembly, map or PDB is included in release assets.
