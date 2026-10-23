# SPDX-License-Identifier: GPL-2.0-only
<#
.SYNOPSIS
    Instala o toolchain Windows exigido pelo KytyPS5 (PLAN.md §2.2) e confere o resultado.

.DESCRIPTION
    Usa winget para: Build Tools 2022 (C++ + Clang tools for Windows), CMake, Ninja,
    Vulkan SDK (traz glslangValidator, spirv-val, spirv-dis e as camadas de validação) e
    RenderDoc. Usa pip --user para pre-commit e, com -WithQt, aqtinstall para o Qt 6.10.3
    (a mesma versão do CI do KytyPS5) em C:\Qt.

    Rode num PowerShell como administrador. Depois, abra um terminal novo (PATH atualizado)
    e rode tools/setup-toolchain.ps1 -CheckOnly para conferir.

.EXAMPLE
    tools/setup-toolchain.ps1            # instala tudo menos o Qt
    tools/setup-toolchain.ps1 -WithQt    # inclui o Qt (só necessário para o launcher)
    tools/setup-toolchain.ps1 -CheckOnly # só confere o que está instalado
#>
[CmdletBinding()]
param(
    [switch]$WithQt,
    [switch]$CheckOnly,
    [string]$QtVersion = '6.10.3'
)

$ErrorActionPreference = 'Stop'

function Find-VsDevShell {
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (-not (Test-Path $vswhere)) { return $null }
    $path = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Llvm.Clang -property installationPath
    if (-not $path) { return $null }
    return $path
}

function Show-Check {
    # No PowerShell 5.1 o stderr de um comando nativo vira erro fatal sob 'Stop'.
    $ErrorActionPreference = 'Continue'
    Write-Host '--- toolchain ---'
    $vs = Find-VsDevShell
    $clang = if ($vs) { Get-ChildItem "$vs\VC\Tools\Llvm\x64\bin\clang-cl.exe" -ErrorAction SilentlyContinue } else { $null }
    $rows = @(
        @('Build Tools 2022 + Clang', $(if ($clang) { $clang.FullName } else { $null })),
        @('cmake', (Get-Command cmake -ErrorAction SilentlyContinue).Source),
        @('ninja', (Get-Command ninja -ErrorAction SilentlyContinue).Source),
        @('python', (Get-Command python -ErrorAction SilentlyContinue).Source),
        @('glslangValidator', (Get-Command glslangValidator -ErrorAction SilentlyContinue).Source),
        @('spirv-val', (Get-Command spirv-val -ErrorAction SilentlyContinue).Source),
        @('VULKAN_SDK', $env:VULKAN_SDK),
        @('renderdoc', $(if (Test-Path "$env:ProgramFiles\RenderDoc\renderdoccmd.exe") { "$env:ProgramFiles\RenderDoc" } else { $null })),
        @('pre-commit', $(& python -m pre_commit --version 2>$null)),
        @("Qt $QtVersion (opcional)", $(if (Test-Path "C:\Qt\$QtVersion\msvc2022_64") { "C:\Qt\$QtVersion\msvc2022_64" } else { $null }))
    )
    $missing = 0
    foreach ($r in $rows) {
        if ($r[1]) { Write-Host ("  ok    {0,-26} {1}" -f $r[0], $r[1]) }
        else {
            Write-Host ("  falta {0,-26}" -f $r[0]) -ForegroundColor Yellow
            if ($r[0] -notlike '*opcional*') { $missing++ }
        }
    }
    if ($vs) { Write-Host "  (clang-cl fica no PATH dentro do 'Developer PowerShell for VS 2022' ou via Launch-VsDevShell.ps1)" }
    return $missing
}

if ($CheckOnly) { exit (Show-Check) }

$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host 'Rode este script num PowerShell como administrador.' -ForegroundColor Red
    exit 1
}

$common = @('--exact', '--accept-source-agreements', '--accept-package-agreements', '--disable-interactivity')

Write-Host '== Build Tools 2022 (C++ e Clang tools for Windows) =='
winget install --id Microsoft.VisualStudio.2022.BuildTools @common --override `
    '--wait --passive --norestart --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended --add Microsoft.VisualStudio.Component.VC.Llvm.Clang --add Microsoft.VisualStudio.Component.VC.Llvm.ClangToolset'

foreach ($id in 'Kitware.CMake', 'Ninja-build.Ninja', 'KhronosGroup.VulkanSDK', 'BaldurKarlsson.RenderDoc') {
    Write-Host "== $id =="
    winget install --id $id @common
}

Write-Host '== pre-commit =='
python -m pip install --user --upgrade pre-commit

if ($WithQt) {
    Write-Host "== Qt $QtVersion (msvc2022_64) via aqtinstall =="
    python -m pip install --user --upgrade aqtinstall
    python -m aqt install-qt windows desktop $QtVersion win64_msvc2022_64 --outputdir C:\Qt
}

Write-Host ''
Write-Host 'Concluído. Abra um terminal novo e rode: tools/setup-toolchain.ps1 -CheckOnly'
