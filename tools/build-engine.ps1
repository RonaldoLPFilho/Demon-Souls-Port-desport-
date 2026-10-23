# SPDX-License-Identifier: GPL-2.0-only
<#
.SYNOPSIS
    Compila o KytyPS5 (engine/) com clang-cl, como no README dele (PLAN.md §6 Fase 0, tarefa 4).

.DESCRIPTION
    Entra no ambiente do Build Tools 2022 (x64), configura com Ninja + clang-cl e compila.
      Release        -> engine/_Build/windows
      RelWithDebInfo -> engine/_Build/windows-dbg  (o build usado para depurar)

    Sem -QtDir: -DKYTY_BUILD_LAUNCHER=OFF, alvos kyty_emulator e kyty_tests
    (o tools/run.ps1 chama o kyty_emulator direto). Com -QtDir: também o launcher e o install.
    Com -Test: roda o ctest no fim.

.EXAMPLE
    tools/build-engine.ps1 -Config Release -Test
    tools/build-engine.ps1 -Config RelWithDebInfo
    tools/build-engine.ps1 -Config Release -QtDir C:/Qt/6.10.3/msvc2022_64
#>
[CmdletBinding()]
param(
    [ValidateSet('Release', 'RelWithDebInfo')]
    [string]$Config = 'Release',
    [string]$QtDir = '',
    [switch]$Test,
    # Só configura (não compila).
    [switch]$ConfigureOnly
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$Engine = Join-Path $Root 'engine'
if (-not (Test-Path (Join-Path $Engine 'CMakeLists.txt'))) {
    Write-Host 'engine/ vazio. Rode: git submodule update --init --recursive' -ForegroundColor Red
    exit 1
}

if (-not (Get-Command clang-cl -ErrorAction SilentlyContinue)) {
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    $vs = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Llvm.Clang -property installationPath
    if (-not $vs) { Write-Host 'Build Tools 2022 com Clang não encontrado (tools/setup-toolchain.ps1).' -ForegroundColor Red; exit 1 }
    # O VsDevCmd chama o vswhere pelo PATH.
    $env:Path += ";${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer"
    & (Join-Path $vs 'Common7\Tools\Launch-VsDevShell.ps1') -Arch amd64 -HostArch amd64 -SkipAutomaticLocation | Out-Null
}
# O Vulkan SDK e o winget podem ter sido instalados depois que este terminal abriu.
foreach ($scope in 'Machine', 'User') {
    foreach ($p in ([Environment]::GetEnvironmentVariable('Path', $scope) -split ';')) {
        if ($p -and ($env:Path -split ';') -notcontains $p) { $env:Path += ";$p" }
    }
}
if (-not $env:VULKAN_SDK) { $env:VULKAN_SDK = [Environment]::GetEnvironmentVariable('VULKAN_SDK', 'Machine') }

$dir = if ($Config -eq 'Release') { '_Build/windows' } else { '_Build/windows-dbg' }
$build = Join-Path $Engine $dir

$cfg = @('-S', $Engine, '-B', $build, '-G', 'Ninja', "-DCMAKE_BUILD_TYPE=$Config",
    '-DCMAKE_C_COMPILER=clang-cl', '-DCMAKE_CXX_COMPILER=clang-cl', '-DBUILD_TESTING=ON')
if ($QtDir) { $cfg += "-DCMAKE_PREFIX_PATH=$QtDir" } else { $cfg += '-DKYTY_BUILD_LAUNCHER=OFF' }

function Run([string]$Exe, [string[]]$ArgList) {
    Write-Host "> $Exe $($ArgList -join ' ')"
    & $Exe @ArgList
    if ($LASTEXITCODE -ne 0) { Write-Host "falhou ($LASTEXITCODE)" -ForegroundColor Red; exit $LASTEXITCODE }
}

$timer = [Diagnostics.Stopwatch]::StartNew()
Run cmake $cfg
if ($ConfigureOnly) { exit 0 }
if ($QtDir) {
    Run cmake @('--build', $build, '--target', 'launcher', 'kyty_tests')
    Run cmake @('--install', $build, '--prefix', (Join-Path $build 'install'))
} else {
    Run cmake @('--build', $build, '--target', 'kyty_emulator', 'kyty_tests')
}
if ($Test) { Run ctest @('--test-dir', $build, '--output-on-failure') }
Write-Host ("Concluído em {0:N0} s: {1}" -f $timer.Elapsed.TotalSeconds, $build)
