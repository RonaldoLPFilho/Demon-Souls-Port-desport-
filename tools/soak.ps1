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
    [int]$StartupSeconds = 300,
    # Variáveis de ambiente para o run.ps1 (aplicadas aqui antes do Start-Job: o job herda o ambiente do pai).
    [hashtable]$Env = @{},
    # Repassa -SpeedProbe ao autopilot (segura W por 4 s de relógio e registra SPEEDPROBE ... diff= em autopilot.txt).
    [switch]$SpeedProbe
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
# O engine reserva ~13,5 GB de memória direta comprometida de uma vez; logo depois de outro emulador sair o Windows ainda
# não devolveu o commit e o boot cai com "could not reserve 13824 MB". Espera até 3 min por 15 GB livres.
for ($i = 0; $i -lt 36; $i++) {
    $os = Get-CimInstance Win32_OperatingSystem
    if ($os.FreeVirtualMemory * 1KB -ge 15GB) { break }
    if ($i -eq 0) { Write-Host ('Aguardando memória comprometida livre ({0:N1} GB)...' -f ($os.FreeVirtualMemory * 1KB / 1GB)) }
    Start-Sleep -Seconds 5
}

# 1. Save de referência.
$saveDst = Join-Path $workDir '_SaveData'
if (Test-Path -LiteralPath $saveDst) { Remove-Item -LiteralPath $saveDst -Recurse -Force }
Copy-Item -LiteralPath $saveSrc -Destination $saveDst -Recurse

# 2. Execução instrumentada.
foreach ($k in $Env.Keys) { [Environment]::SetEnvironmentVariable([string]$k, [string]$Env[$k]) }
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

# Vigia de congelamento: sem nenhuma linha DES_FPS nova por 10 s com o emulador vivo, amostra as
# pilhas de todas as threads por 10 s (build/sampler/sampler.exe) em freeze-<s>.json; 60 s de pausa
# entre amostras. Serve para achar onde um congelamento espera (o primeiro soak teve um de 30 s).
$sampler = Join-Path $Root 'build/sampler/sampler.exe'
$watchJob = $null
if (Test-Path -LiteralPath $sampler) {
    $watchJob = Start-Job -ScriptBlock {
        param($stdout, $sampler, $outDir)
        $lastCount = 0; $lastChange = Get-Date; $cooldownUntil = Get-Date
        while ($true) {
            Start-Sleep -Seconds 2
            if (-not (Get-Process kyty_emulator -ErrorAction SilentlyContinue)) { continue }
            $count = 0
            if (Test-Path -LiteralPath $stdout) {
                $count = @(Select-String -LiteralPath $stdout -Pattern '^DES_FPS ' -ErrorAction SilentlyContinue).Count
            }
            if ($count -ne $lastCount) { $lastCount = $count; $lastChange = Get-Date; continue }
            # Só depois do primeiro DES_FPS (antes disso é o carregamento inicial).
            if ($count -gt 0 -and ((Get-Date) - $lastChange).TotalSeconds -ge 10 -and (Get-Date) -ge $cooldownUntil) {
                $name = 'freeze-{0}.json' -f [int]((Get-Date) - (Get-Item -LiteralPath $stdout).CreationTime).TotalSeconds
                & $sampler --name kyty_emulator.exe --seconds 10 --hz 100 --out (Join-Path $outDir $name) | Out-Null
                $cooldownUntil = (Get-Date).AddSeconds(60)
            }
        }
    } -ArgumentList (Join-Path $runDir.FullName 'stdout.txt'), $sampler, $runDir.FullName
}

# 3. Piloto automático.
$pilotLog = Join-Path $runDir.FullName 'autopilot.txt'
$pilotArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $PSScriptRoot 'autopilot.ps1'),
    '-StartupSeconds', $StartupSeconds, '-PlaySeconds', ($Minutes * 60), '-ShotDir', (Join-Path $runDir.FullName 'shots'))
if ($SpeedProbe) { $pilotArgs += '-SpeedProbe' }
& powershell @pilotArgs | Tee-Object -FilePath $pilotLog
$pilotCode = $LASTEXITCODE

# 4. Fim: encerra o emulador se ainda estiver aberto e espera a triagem do run.ps1.
$crashed = $pilotCode -eq 2
if ($watchJob) { Stop-Job $watchJob; Remove-Job $watchJob -Force }
Get-Process kyty_emulator -ErrorAction SilentlyContinue | ForEach-Object { & taskkill.exe /PID $_.Id /T /F 2>&1 | Out-Null }
Wait-Job $runJob -Timeout 300 | Out-Null
Remove-Job $runJob -Force

# O encerramento pelo soak (taskkill) aparece como crashed_or_error no run.json: corrige o rótulo.
$runJson = Join-Path $runDir.FullName 'run.json'
if (-not $crashed -and (Test-Path -LiteralPath $runJson)) {
    $run = Get-Content -LiteralPath $runJson -Raw | ConvertFrom-Json
    if ($run.result -eq 'crashed_or_error') {
        $run.result = 'stopped_by_soak'
        $run | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $runJson -Encoding UTF8
        & python -I (Join-Path $Root 'tools/log_triage.py') $runDir.FullName | Out-Null
    }
}

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
