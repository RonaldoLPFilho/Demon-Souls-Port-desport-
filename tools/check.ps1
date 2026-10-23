# SPDX-License-Identifier: GPL-2.0-only
<#
.SYNOPSIS
    CI local do desport (PLAN.md §6 Fase 2, tarefa 6): tudo o que é automático, em ordem.

.DESCRIPTION
    1. Testes das ferramentas Python (tests/tools, unittest).
    2. Build do engine (tools/build-engine.ps1, Release).
    3. ctest do engine. Problemas conhecidos (docs/STATUS.md) rodam à parte e não reprovam:
       KP-001 kernel_file_system.
    4. Cenário automático `boot` (tests/regression/scenarios.toml), que abre o jogo por alguns
       segundos. Enquanto o bloqueio da linha de base existir, a falha dele é esperada e
       informada como tal (EXPECTED_SCENARIO_FAILURES).

    Código de saída 0 só se nada falhar além do esperado.

.EXAMPLE
    tools/check.ps1
    tools/check.ps1 -SkipBuild -SkipGame
#>
[CmdletBinding()]
param(
    [switch]$SkipBuild,
    [switch]$SkipGame,
    [ValidateSet('Release', 'RelWithDebInfo')]
    [string]$Config = 'Release'
)

$ErrorActionPreference = 'Continue'
$Root = Split-Path -Parent $PSScriptRoot

# Testes do ctest que falham por problemas conhecidos (docs/STATUS.md, "Problemas conhecidos").
$KNOWN_CTEST_FAILURES = @{ 'kernel_file_system' = 'KP-001' }
# Cenários que ainda falham por um bloqueio já registrado (docs/STATUS.md, linha de base).
$EXPECTED_SCENARIO_FAILURES = @{ 'boot' = 'parada em descriptors.cpp:969 (primeiro bloqueio, Fase 3/4)' }

$results = New-Object System.Collections.Generic.List[object]
function Add-Result([string]$Step, [string]$Status, [string]$Detail) {
    $results.Add([pscustomobject]@{ Etapa = $Step; Resultado = $Status; Detalhe = $Detail })
    $color = switch ($Status) { 'ok' { 'Green' } 'esperado' { 'Yellow' } 'pulado' { 'DarkGray' } default { 'Red' } }
    Write-Host ("[{0}] {1} {2}" -f $Status, $Step, $Detail) -ForegroundColor $color
}

# 1. Ferramentas
Write-Host '== testes das ferramentas =='
& python -I -m unittest discover -s (Join-Path $Root 'tests/tools')
if ($LASTEXITCODE -eq 0) { Add-Result 'tests/tools' 'ok' '' } else { Add-Result 'tests/tools' 'FALHOU' "código $LASTEXITCODE" }

# 2. Build
$buildDir = Join-Path $Root ($(if ($Config -eq 'Release') { 'engine/_Build/windows' } else { 'engine/_Build/windows-dbg' }))
if ($SkipBuild) {
    Add-Result 'build' 'pulado' ''
} else {
    Write-Host '== build do engine =='
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root 'tools/build-engine.ps1') -Config $Config
    if ($LASTEXITCODE -eq 0) { Add-Result 'build' 'ok' $Config } else { Add-Result 'build' 'FALHOU' "código $LASTEXITCODE" }
}

# 3. ctest
if (Test-Path (Join-Path $buildDir 'CTestTestfile.cmake')) {
    foreach ($scope in 'Machine', 'User') {
        foreach ($p in ([Environment]::GetEnvironmentVariable('Path', $scope) -split ';')) {
            if ($p -and ($env:Path -split ';') -notcontains $p) { $env:Path += ";$p" }
        }
    }
    Write-Host '== ctest =='
    $known = '^(' + (($KNOWN_CTEST_FAILURES.Keys | ForEach-Object { [regex]::Escape($_) }) -join '|') + ')$'
    & ctest --test-dir $buildDir --output-on-failure -E $known
    if ($LASTEXITCODE -eq 0) { Add-Result 'ctest' 'ok' "sem $($KNOWN_CTEST_FAILURES.Keys -join ', ')" }
    else { Add-Result 'ctest' 'FALHOU' "código $LASTEXITCODE" }
    foreach ($test in $KNOWN_CTEST_FAILURES.Keys) {
        & ctest --test-dir $buildDir -R ('^' + [regex]::Escape($test) + '$') *> $null
        if ($LASTEXITCODE -eq 0) {
            Add-Result "ctest $test" 'ok' "$($KNOWN_CTEST_FAILURES[$test]) passou: atualizar docs/STATUS.md"
        } else {
            Add-Result "ctest $test" 'esperado' $KNOWN_CTEST_FAILURES[$test]
        }
    }
} else {
    Add-Result 'ctest' 'FALHOU' "sem build em $buildDir"
}

# 4. Cenário automático
if ($SkipGame) {
    Add-Result 'cenário boot' 'pulado' ''
} else {
    Write-Host '== cenário boot =='
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root 'tools/run.ps1') -Scenario boot
    $code = $LASTEXITCODE
    if ($code -eq 0) {
        $note = if ($EXPECTED_SCENARIO_FAILURES.ContainsKey('boot')) { 'passou: remover de EXPECTED_SCENARIO_FAILURES' } else { '' }
        Add-Result 'cenário boot' 'ok' $note
    } elseif ($code -eq 2 -and $EXPECTED_SCENARIO_FAILURES.ContainsKey('boot')) {
        Add-Result 'cenário boot' 'esperado' $EXPECTED_SCENARIO_FAILURES['boot']
    } else {
        Add-Result 'cenário boot' 'FALHOU' "código $code"
    }
}

Write-Host ''
$results | Format-Table -AutoSize | Out-String | Write-Host
$failed = @($results | Where-Object { $_.Resultado -eq 'FALHOU' }).Count
if ($failed -gt 0) { Write-Host "check: $failed etapa(s) falharam" -ForegroundColor Red; exit 1 }
Write-Host 'check: ok' -ForegroundColor Green
exit 0
