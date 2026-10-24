# SPDX-License-Identifier: GPL-2.0-only
<#
.SYNOPSIS
    Bateria A/B de desempenho (captures/perf-analysis-20261023.md, experimentos A-H): várias execuções
    do soak com uma variável de cada vez, e um relatório comparativo.

.DESCRIPTION
    Cada execução é um tools/soak.ps1 de -Minutes minutos (save de referência + autopilot, como no soak) com uma
    cópia do JSON de lançamento em build/perf-ab/launch-<id>.json (fora do git; o game/config/fg-launch.json não é
    tocado). As mudanças de env e de flags vão NA CÓPIA, não em soak -Env: o run.ps1 aplica o environment do JSON
    depois do ambiente do processo, e o fg-launch.json já define KYTY_HITCH_LOG_MS=100, que anularia o do experimento A.
    soak.ps1 e run.ps1 não mudam.

    Experimentos (ordem padrão; -Only escolhe e ordena):
      base  config atual (vblank 60 do fg-launch.json) com --vblank-frequency 120, como o nightly-v120. Com SpeedProbe.
      C1    cache de driver FRIO: KYTY_DRIVER_CACHE_KEY = chave nova aleatória (64 hex, gerada a cada execução
            do perf-ab; -CacheKey fixa uma) + KYTY_PIPELINE_KEY_LOG=1.
      C2    mesma chave de C1, logo depois: cache de driver QUENTE (e a gravação de warmup do C1 reaproveitada).
      A     base + DES_STATS=1, KYTY_GPU_WRITE_WATCH=220a00000-220a80000, KYTY_SYNC_STACK=1, KYTY_HITCH_LOG_MS=20.
      B     vblank 240.
      H     KYTY_COMPUTE_WAVE64=1.
      RB    base + KYTY_READBACK_PREFETCH=1.
      RBQ   RB + KYTY_READBACK_QUEUE=3 (validação: cada cópia é repetida e comparada; o relatório conta
            READBACK_QUEUE_MISMATCH).
      RB2   base + KYTY_READBACK_PREFETCH=2 (snapshot por faixa escrita; engine com desport-rb2).
      RB3   base + KYTY_READBACK_PREFETCH=3 (RB2 + write-back antecipado e submit no ponto de sincronização).
      FPS   vblank 60 + KYTY_FPS_LIMIT=0 (sem teto de vblank), com SpeedProbe.
      FPS60 vblank 60 + KYTY_FPS_LIMIT=60, com SpeedProbe.
    Todos (exceto B, FPS, FPS60) usam vblank 120. SpeedProbe (autopilot -SpeedProbe via soak.ps1) roda em base, FPS e
    FPS60 (ou em todas com -SpeedProbe): o relatório mostra as linhas SPEEDPROBE (diff) para comparar a aceleração do
    jogo acima de 60 fps.
    Cache de driver: o run.ps1 define KYTY_DRIVER_CACHE_KEY sozinho (SHA-256 do exe) quando nada o define, então TODAS
    as rodadas usam o cache do driver (quente a partir da 2ª com o mesmo exe). Só C1/C2 sobrescrevem a chave, por isso
    C1 é frio de verdade (chave nunca usada) e C2 é a mesma chave já preenchida; as demais rodadas não são frias.
    Cuidado: com chave válida o engine também liga o warmup de shaders (KYTY_SHADER_WARMUP=1 do JSON só age com
    chave): C1 grava _PipelineCache/warmup-v2/ (60 s) e C2 o reaproveita; isso persiste para as rodadas seguintes.

    Relatório: captures/perf-ab/<data-hora>/report.md (tabela fps médio/p1/p5, travadas, DES_FRAME quando o engine
    o emite) via tools/perf_ab_report.py (usa tools/log_triage.py). Um manifest.json com tudo fica ao lado.
    Se uma execução falhar, registra e segue. Mexe no teclado e no foco das janelas (autopilot): rodar sem ninguém no PC.

.EXAMPLE
    tools/perf-ab.ps1 -DryRun
    tools/perf-ab.ps1
    tools/perf-ab.ps1 -Only A,B -Minutes 8
    tools/perf-ab.ps1 -Only C1,C2 -CacheKey <64 hex minúsculos>
    tools/perf-ab.ps1 -Only base,RB,RBQ,FPS,FPS60
#>
[CmdletBinding()]
param(
    [int]$Minutes = 6,
    # Experimentos e ordem (padrão: base,C1,C2,A,B,H,RB,RBQ,RB2,RB3,FPS,FPS60).
    [string[]]$Only = @(),
    [string]$Launch = 'game/config/fg-launch.json',
    [string]$Save = 'user/saves-backup/kyty-fg-20261023-2050',
    # Chave do cache de driver de C1/C2 (64 hex minúsculos). Padrão: uma chave nova aleatória a cada execução (C1 frio).
    [string]$CacheKey = '',
    # Liga o SpeedProbe do autopilot em todas as rodadas (padrão: só base, FPS e FPS60).
    [switch]$SpeedProbe,
    # Segundos de log ignorados nas estatísticas do relatório (carregamento + caminho até o HUD).
    [int]$WarmupSec = 180,
    [switch]$DryRun
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$Stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$OutDir = Join-Path $Root "captures/perf-ab/$Stamp"
$StageDir = Join-Path $Root 'build/perf-ab'

$LaunchAbs = if ([System.IO.Path]::IsPathRooted($Launch)) { $Launch } else { Join-Path $Root $Launch }
if (-not (Test-Path -LiteralPath $LaunchAbs)) { throw "configuração de lançamento não encontrada: $Launch" }
$base = Get-Content -LiteralPath $LaunchAbs -Raw | ConvertFrom-Json

# Chave do cache de driver de C1/C2: aleatória (64 hex), salvo -CacheKey. O run.ps1 usa o SHA-256 do exe nas outras rodadas.
if ($CacheKey) {
    if ($CacheKey -notmatch '^[0-9a-f]{64}$') { throw '-CacheKey deve ter 64 hex minúsculos (IsBinaryDriverCacheKey do engine)' }
} elseif ($DryRun) {
    $CacheKey = '<64 hex aleatórios>'
} else {
    $bytes = New-Object byte[] 32
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $rng.GetBytes($bytes)
    $rng.Dispose()
    $CacheKey = (($bytes | ForEach-Object { $_.ToString('x2') }) -join '')
}

# id -> descrição, env, vblank (flags), SpeedProbe
$Experiments = [ordered]@{
    base = @{ Desc = 'configuração atual, vblank 120, SpeedProbe'; Env = [ordered]@{}; Vblank = '120'; Probe = $true }
    C1   = @{ Desc = 'cache de driver FRIO (chave nova aleatória) + PIPELINE_KEY_LOG'; Env = [ordered]@{ KYTY_DRIVER_CACHE_KEY = $CacheKey; KYTY_PIPELINE_KEY_LOG = '1' }; Vblank = '120' }
    C2   = @{ Desc = 'cache de driver QUENTE (mesma chave de C1) + PIPELINE_KEY_LOG'; Env = [ordered]@{ KYTY_DRIVER_CACHE_KEY = $CacheKey; KYTY_PIPELINE_KEY_LOG = '1' }; Vblank = '120' }
    A    = @{ Desc = 'readback: DES_STATS, GPU_WRITE_WATCH 0x220a00000-0x220a80000, SYNC_STACK, HITCH_LOG_MS=20'
              Env = [ordered]@{ DES_STATS = '1'; KYTY_GPU_WRITE_WATCH = '220a00000-220a80000'; KYTY_SYNC_STACK = '1'; KYTY_HITCH_LOG_MS = '20' }; Vblank = '120' }
    B    = @{ Desc = 'vblank 240'; Env = [ordered]@{}; Vblank = '240' }
    H    = @{ Desc = 'KYTY_COMPUTE_WAVE64=1'; Env = [ordered]@{ KYTY_COMPUTE_WAVE64 = '1' }; Vblank = '120' }
    RB   = @{ Desc = 'KYTY_READBACK_PREFETCH=1, vblank 120'; Env = [ordered]@{ KYTY_READBACK_PREFETCH = '1' }; Vblank = '120' }
    RBQ  = @{ Desc = 'RB + KYTY_READBACK_QUEUE=3 (validação de divergência), vblank 120'; Env = [ordered]@{ KYTY_READBACK_PREFETCH = '1'; KYTY_READBACK_QUEUE = '3' }; Vblank = '120' }
    RB2  = @{ Desc = 'KYTY_READBACK_PREFETCH=2 (snapshot por faixa), vblank 120'; Env = [ordered]@{ KYTY_READBACK_PREFETCH = '2' }; Vblank = '120' }
    RB3  = @{ Desc = 'KYTY_READBACK_PREFETCH=3 (faixa + write-back antecipado + submit), vblank 120'; Env = [ordered]@{ KYTY_READBACK_PREFETCH = '3' }; Vblank = '120' }
    FPS  = @{ Desc = 'vblank 60 + KYTY_FPS_LIMIT=0 (sem teto), SpeedProbe'; Env = [ordered]@{ KYTY_FPS_LIMIT = '0' }; Vblank = '60'; Probe = $true }
    FPS60 = @{ Desc = 'vblank 60 + KYTY_FPS_LIMIT=60, SpeedProbe'; Env = [ordered]@{ KYTY_FPS_LIMIT = '60' }; Vblank = '60'; Probe = $true }
}
function Use-Probe($Exp) { return ($SpeedProbe.IsPresent -or ($Exp.ContainsKey('Probe') -and $Exp.Probe)) }
$Plan = if ($Only.Count) { @($Only | ForEach-Object { $_ -split ',' } | Where-Object { $_ } | ForEach-Object { $_.Trim() }) } else { @($Experiments.Keys) }
foreach ($id in $Plan) {
    if (-not $Experiments.Contains($id)) { throw "experimento desconhecido: $id (use: $(@($Experiments.Keys) -join ', '))" }
}
if (@($Plan | Select-Object -Unique).Count -ne $Plan.Count) { throw 'experimento repetido em -Only' }

if ($DryRun) {
    Write-Host "perf-ab (plano): $($Plan.Count) execuções de $Minutes min, relatório em $OutDir\report.md"
    foreach ($id in $Plan) {
        $e = $Experiments[$id]
        $envText = (@($e.Env.Keys) | ForEach-Object { "$_=$($e.Env[$_])" }) -join ' '
        $probe = if (Use-Probe $e) { ' [SpeedProbe]' } else { '' }
        Write-Host ("- {0}: {1}  [--vblank-frequency {2}]{3} {4}" -f $id, $e.Desc, $e.Vblank, $probe, $envText)
    }
    if (($Plan -contains 'C2') -and ($Plan -notcontains 'C1')) { Write-Host 'Aviso: C2 sem C1: só é quente se o cache dessa chave já existir (-CacheKey).' -ForegroundColor Yellow }
    return
}
if (($Plan -contains 'C2') -and ($Plan -notcontains 'C1')) { Write-Host 'Aviso: C2 sem C1: só é quente se o cache dessa chave já existir (-CacheKey).' -ForegroundColor Yellow }

New-Item -ItemType Directory -Path $OutDir, $StageDir -Force | Out-Null
$workDir = if ($base.PSObject.Properties['work_dir']) { Join-Path $Root $base.work_dir } else { Join-Path $Root 'user/kyty' }
$driverCacheDir = Join-Path $workDir "_PipelineCache/local/$CacheKey"

function Stop-Emulator {
    Get-Process kyty_emulator -ErrorAction SilentlyContinue | ForEach-Object { & taskkill.exe /PID $_.Id /T /F 2>&1 | Out-Null }
}

# Cópia do JSON de lançamento com as mudanças do experimento (o original não é tocado).
function New-LaunchCopy([string]$Id, $Exp) {
    $copy = Get-Content -LiteralPath $LaunchAbs -Raw | ConvertFrom-Json
    foreach ($k in $Exp.Env.Keys) { $copy.environment | Add-Member -NotePropertyName $k -NotePropertyValue ([string]$Exp.Env[$k]) -Force }
    $flags = New-Object System.Collections.Generic.List[string]
    foreach ($f in @($copy.flags)) { $flags.Add([string]$f) }
    $at = $flags.IndexOf('--vblank-frequency')
    if ($at -ge 0) { $flags[$at + 1] = $Exp.Vblank } else { $flags.Add('--vblank-frequency'); $flags.Add($Exp.Vblank) }
    $copy.flags = @($flags)
    $rel = "build/perf-ab/launch-$Id.json"
    ($copy | ConvertTo-Json -Depth 8) | Set-Content -LiteralPath (Join-Path $Root $rel) -Encoding UTF8
    return $rel
}

$runs = New-Object System.Collections.Generic.List[object]
foreach ($id in $Plan) {
    $e = $Experiments[$id]
    Write-Host "== $id ($((Get-Date).ToString('HH:mm:ss'))): $($e.Desc)"
    $entry = [ordered]@{ id = $id; desc = $e.Desc; run_dir = $null; outcome = 'error'; env = $e.Env; flags = @('--vblank-frequency', $e.Vblank); speed_probe = (Use-Probe $e) }
    try {
        if (Get-Process kyty_emulator -ErrorAction SilentlyContinue) { Write-Host 'kyty_emulator já rodando: encerrando'; Stop-Emulator; Start-Sleep -Seconds 5 }
        # A memória do processo anterior demora a ser liberada ("could not reserve 13824 MB for guest direct memory").
        Start-Sleep -Seconds 20
        if ($e.Env.Contains('KYTY_DRIVER_CACHE_KEY')) {
            $entry.desc += $(if (Test-Path -LiteralPath $driverCacheDir) { ' [cache dessa chave já existia ao iniciar]' } else { ' [cache dessa chave não existia ao iniciar]' })
        }
        $rel = New-LaunchCopy $id $e
        $t0 = Get-Date
        $label = "perf-ab-$id"
        $log = Join-Path $OutDir "$id.txt"
        $soakArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $PSScriptRoot 'soak.ps1'),
            '-Minutes', $Minutes, '-Label', $label, '-Launch', $rel, '-Save', $Save)
        if (Use-Probe $e) { $soakArgs += '-SpeedProbe' }
        & powershell.exe @soakArgs *> $log
        $code = $LASTEXITCODE
        $dir = Get-ChildItem (Join-Path $Root 'captures/runs') -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like "*-$label*" -and $_.CreationTime -ge $t0.AddSeconds(-5) } |
            Sort-Object CreationTime | Select-Object -Last 1
        if ($dir) { $entry.run_dir = $dir.FullName }
        $entry.outcome = switch ($code) { 0 { 'completed' } 1 { 'no_hud' } 2 { 'emulator_exited' } default { "soak_exit_$code" } }
        if (-not $dir) { $entry.outcome = 'sem_pasta' }
    } catch {
        Stop-Emulator
        $entry.outcome = 'erro: ' + $_.Exception.Message
    }
    Write-Host "   -> $($entry.outcome)  $($entry.run_dir)"
    $runs.Add([pscustomobject]$entry)
}

# Relatório (Python; reaproveita tools/log_triage.py).
$manifest = [ordered]@{ date = $Stamp; minutes = $Minutes; warmup_sec = $WarmupSec; cache_key = $CacheKey; cache_note = 'C1 frio (chave nova), C2 quente (mesma chave); as outras rodadas usam o cache do driver da chave automática do run.ps1 (sha256 do exe)'; launch = $Launch; runs = $runs.ToArray() }
$manifestPath = Join-Path $OutDir 'manifest.json'
($manifest | ConvertTo-Json -Depth 8) | Set-Content -LiteralPath $manifestPath -Encoding UTF8
$reportPath = Join-Path $OutDir 'report.md'
& python -I (Join-Path $PSScriptRoot 'perf_ab_report.py') $manifestPath --out $reportPath --warmup-sec $WarmupSec
if ($LASTEXITCODE -ne 0) { Write-Host 'perf_ab_report.py falhou' -ForegroundColor Red; exit 1 }
Write-Host "Relatório: $reportPath"
if (@($runs | Where-Object { $_.outcome -ne 'completed' }).Count) { exit 1 }
exit 0
