# SPDX-License-Identifier: GPL-2.0-only
<#
.SYNOPSIS
    Teste longo automático (PLAN.md Fase 5): o jogo sozinho por N minutos, com crash, memória e fps.

.DESCRIPTION
    1. Restaura o save de referência (-Save, uma cópia de _SaveData em user/saves-backup/) na pasta de
       trabalho da configuração de lançamento, para todo soak partir do mesmo ponto.
    2. Executa tools/run.ps1 -Launch <config> -Stats em segundo plano (tempo limite = minutos + folga).
    3. tools/autopilot.ps1 leva o jogo ao HUD e o mantém se mexendo; miniaturas a cada minuto em
       captures/runs/<execução>/shots/ (fora do git).
    4. Encerra o emulador no fim e grava soak.json (resultado do piloto) na pasta da execução; a
       triagem (triage.md) já traz memória, fps e paradas.

    Mexe no teclado e no foco das janelas: rodar só com o Ronaldo ciente (ele está fora ou pediu).

.EXAMPLE
    tools/soak.ps1 -Minutes 30
    tools/soak.ps1 -Minutes 120 -Label soak-2h
#>
[CmdletBinding()]
param(
    [int]$Minutes = 30,
    [string]$Label = '',
    [string]$Launch = 'game/config/fg-launch.json',
    [string]$Save = 'user/saves-backup/kyty-fg-20261023-2050',
    [int]$StartupSeconds = 300
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
if (-not $Label) { $Label = "soak-${Minutes}m" }

$launchInfo = Get-Content -LiteralPath (Join-Path $Root $Launch) -Raw | ConvertFrom-Json
$workDir = Join-Path $Root $launchInfo.work_dir
$saveSrc = Join-Path $Root $Save
if (-not (Test-Path -LiteralPath $saveSrc)) { throw "save de referência não encontrado: $saveSrc" }
if (Get-Process kyty_emulator -ErrorAction SilentlyContinue) { throw 'já há um kyty_emulator rodando' }

# 1. Save de referência.
$saveDst = Join-Path $workDir '_SaveData'
if (Test-Path -LiteralPath $saveDst) { Remove-Item -LiteralPath $saveDst -Recurse -Force }
Copy-Item -LiteralPath $saveSrc -Destination $saveDst -Recurse

# 2. Execução instrumentada.
$timeout = $Minutes * 60 + $StartupSeconds + 120
$started = Get-Date
$runJob = Start-Job -ScriptBlock {
    param($root, $launch, $label, $timeout)
    & (Join-Path $root 'tools/run.ps1') -Launch $launch -Label $label -TimeoutSec $timeout -Stats -Quiet *> $null
} -ArgumentList $Root, $Launch, $Label, $timeout

# A pasta da execução aparece logo que o run.ps1 começa.
$runDir = $null
for ($i = 0; $i -lt 120 -and -not $runDir; $i++) {
    Start-Sleep -Milliseconds 500
    $runDir = Get-ChildItem (Join-Path $Root 'captures/runs') -Directory |
        Where-Object { $_.Name -like "*-$Label*" -and $_.CreationTime -ge $started.AddSeconds(-5) } |
        Sort-Object CreationTime | Select-Object -Last 1
}
if (-not $runDir) { Stop-Job $runJob; throw 'run.ps1 não criou a pasta da execução' }
Write-Host "Execução: $($runDir.FullName)"

# 3. Piloto automático.
$pilotLog = Join-Path $runDir.FullName 'autopilot.txt'
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'autopilot.ps1') `
    -StartupSeconds $StartupSeconds -PlaySeconds ($Minutes * 60) -ShotDir (Join-Path $runDir.FullName 'shots') |
    Tee-Object -FilePath $pilotLog
$pilotCode = $LASTEXITCODE

# 4. Fim: encerra o emulador se ainda estiver aberto e espera a triagem do run.ps1.
$crashed = $pilotCode -eq 2
Get-Process kyty_emulator -ErrorAction SilentlyContinue | ForEach-Object { & taskkill.exe /PID $_.Id /T /F 2>&1 | Out-Null }
Wait-Job $runJob -Timeout 300 | Out-Null
Remove-Job $runJob -Force

$result = [ordered]@{
    label           = $Label
    minutes         = $Minutes
    save            = $Save
    autopilot_code  = $pilotCode
    outcome         = switch ($pilotCode) { 0 { 'completed' } 1 { 'no_hud' } 2 { 'emulator_exited' } default { 'error' } }
    duration_min    = [math]::Round(((Get-Date) - $started).TotalMinutes, 1)
}
$result | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $runDir.FullName 'soak.json') -Encoding UTF8
Write-Host "Soak: $($result.outcome) em $($result.duration_min) min (piloto: código $pilotCode)"
if ($crashed) { exit 2 } elseif ($pilotCode -ne 0) { exit 1 }
