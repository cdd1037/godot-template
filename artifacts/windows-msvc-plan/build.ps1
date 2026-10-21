$ErrorActionPreference = 'Stop'
$root = $env:GITHUB_WORKSPACE
if (-not $root) { throw 'Run in the prepared GitHub Actions workspace.' }
$plan = Join-Path $root 'experiment/artifacts/windows-msvc-plan'
$reports = Join-Path $root 'reports'
New-Item -ItemType Directory -Force $reports | Out-Null
$vswhere = "${env:ProgramFiles(x86)}/Microsoft Visual Studio/Installer/vswhere.exe"
$vs = & $vswhere -latest -version '[17.0,18.0)' -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (-not $vs) { throw 'Visual Studio 2022 C++ x64 build tools not found; no fallback to MinGW.' }
$devcmd = Join-Path $vs 'Common7/Tools/VsDevCmd.bat'
$lines = & cmd.exe /d /s /c "`"`"$devcmd`" -no_logo -arch=x64 -host_arch=x64 && set`""
if ($LASTEXITCODE -ne 0) { throw 'VsDevCmd failed' }
foreach ($line in $lines) {
    if ($line -match '^([^=]+)=(.*)$') { [Environment]::SetEnvironmentVariable($matches[1], $matches[2], 'Process') }
}
Set-Location (Join-Path $root 'godot')
$commit = git rev-parse HEAD
if ($LASTEXITCODE -ne 0 -or $commit -ne 'ed1daf0bf001b61586d9930840f2f1394092c079') { throw 'Source revision mismatch' }
Copy-Item (Join-Path $plan 'custom.py') custom.py
@("Source: $commit", "VS: $vs", "VCToolsVersion: $env:VCToolsVersion", "WindowsSDKVersion: $env:WindowsSDKVersion", "Runner image: $env:ImageOS $env:ImageVersion", "PDB requested: $env:GENERATE_PDB") | Set-Content "$reports/toolchain.txt"
Get-Command cl.exe,link.exe | Format-List Name,Source | Out-String | Add-Content "$reports/toolchain.txt"
python --version 2>&1 | Add-Content "$reports/toolchain.txt"
python -m SCons --version 2>&1 | Add-Content "$reports/toolchain.txt"
Copy-Item custom.py "$reports/custom.py"
$symbols = if ($env:GENERATE_PDB -eq 'true') { 'yes' } else { 'no' }
$jobs = [Math]::Min(4, [Environment]::ProcessorCount)
$sconsArgs = @("-j$jobs", 'platform=windows', 'arch=x86_64', 'target=template_release', 'production=yes', 'optimize=speed', 'lto=full', 'use_mingw=no', 'use_llvm=no', 'msvc_version=14.3', 'd3d12=no', 'vulkan=no', 'angle=no', 'metal=no', 'accesskit=no', 'graphite=yes', 'module_mono_enabled=yes', 'tests=no', "debug_symbols=$symbols", 'verbose=yes')
('python -m SCons ' + ($sconsArgs -join ' ')) | Add-Content "$reports/toolchain.txt"
$start = Get-Date
python -m SCons @sconsArgs 2>&1 | Tee-Object "$reports/build.log"
$result = $LASTEXITCODE
"Elapsed seconds: $((Get-Date).Subtract($start).TotalSeconds)" | Add-Content "$reports/toolchain.txt"
# Preserve maps even when compilation/linking fails; never invoke any built EXE.
Get-ChildItem -Path . -Filter '*.map' -Recurse | ForEach-Object { Copy-Item $_.FullName (Join-Path $reports $_.Name) }
if ($result -ne 0) { throw "SCons failed with exit code $result" }
python (Join-Path $plan 'measure.py') bin $reports $symbols
if ($LASTEXITCODE -ne 0) { throw 'Static measurement failed' }
if ($env:GITHUB_STEP_SUMMARY) { Get-Content "$reports/SIZE.md" | Add-Content $env:GITHUB_STEP_SUMMARY }
