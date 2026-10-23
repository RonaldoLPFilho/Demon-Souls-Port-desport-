# SPDX-License-Identifier: GPL-2.0-only
# Compila tools/sampler/sampler.cpp com clang-cl -> build/sampler/sampler.exe.
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if (-not (Get-Command clang-cl -ErrorAction SilentlyContinue)) {
    $vs = & "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe" -latest -products * -property installationPath
    $env:Path += ";${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer"
    & (Join-Path $vs 'Common7\Tools\Launch-VsDevShell.ps1') -Arch amd64 -HostArch amd64 -SkipAutomaticLocation | Out-Null
}
$out = Join-Path $Root 'build/sampler'
New-Item -ItemType Directory -Force -Path $out | Out-Null
$ErrorActionPreference = 'Continue'  # avisos do clang-cl vão para o stderr; vale o código de saída
& clang-cl /nologo /std:c++20 /O2 /EHsc /W3 /D_CRT_SECURE_NO_WARNINGS (Join-Path $PSScriptRoot 'sampler.cpp') "/Fe$out\sampler.exe" "/Fo$out\" `
    /link dbghelp.lib winmm.lib
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Host "ok: $out\sampler.exe"
