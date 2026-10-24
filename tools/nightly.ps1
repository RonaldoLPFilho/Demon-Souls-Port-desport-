# SPDX-License-Identifier: GPL-2.0-only
<#
.SYNOPSIS
    Bateria de testes noturna do desport: smoke, janela, vblank 120 e soak, com um relatório único.

.DESCRIPTION
    Roda em sequência, cada etapa isolada (se uma falhar ou der erro, registra e segue para a próxima):
      1. smoke      tools/run.ps1 -Label nightly-smoke -TimeoutSec 120 -Stats -Quiet, com KYTY_REDZONE_FAULT_AUDIT=1.
                    Passa se: nenhum DES_CRASH, o marco flip_600 foi atingido e não houve RED_ZONE_AUDIT.
      2. window     run.ps1 em segundo plano (-TimeoutSec 600) + tools/window-test.ps1 -RunDir <pasta>; depois encerra o
                    kyty_emulator (taskkill /T /F) e espera o job. Passa se o veredito do window-test.json for ok.
      3. vblank120  cópia do JSON de lançamento com --vblank-frequency 120 (build/nightly-launch-v120.json, fora do git) e
                    soak curto (tools/soak.ps1 -Minutes 10 -Label nightly-v120). Passa se: completed, sem DES_CRASH e
                    houver janelas DES_FPS > 90 na segunda metade da execução (prova de que o filme não ficou preso
                    limitando a 60). Informa o fps mediano do gameplay.
      4. soak       tools/soak.ps1 -Minutes <SoakMinutes> -Label nightly-soak com KYTY_FAULT_CLASSIFY=1,
                    KYTY_REDZONE_FAULT_AUDIT=1 e DES_MEM=1. Passa se: completed, sem DES_CRASH, sem freeze-*.json e a
                    inclinação de process_private (DES_MEM) < 5 MB/min depois dos 10 primeiros minutos.
    O relatório fica em captures/nightly/<data-hora>/report.md (fora do git): 3 linhas de resumo no topo e uma tabela
    etapa / resultado / pasta / números-chave (fps mediano, quadros lentos, memória, faults por segundo, DES_CRASH,
    RED_ZONE_AUDIT, eventos DES_WINDOW e DES_VBLANK), lida do log, do stdout e da triagem de cada execução. O log
    de cada etapa vai para a mesma pasta (<etapa>.txt).

    Variáveis de ambiente: cada etapa roda em um processo filho (powershell -File) com as variáveis definidas neste
    processo antes da chamada, e um processo filho (inclusive o Start-Job do soak.ps1) herda o ambiente que o pai tem
    NO MOMENTO em que o cria: por isso as variáveis são definidas aqui antes de iniciar a etapa e restauradas depois.
    O soak.ps1 também ganhou o parâmetro -Env @{...} (aplicado antes do Start-Job) para uso direto.

    Mexe no teclado e no foco das janelas (autopilot, window-test): rodar só sem ninguém usando o PC.
    Exit: 0 se todas as etapas executadas passaram, 1 se alguma falhou ou deu erro.

.EXAMPLE
    tools/nightly.ps1 -DryRun
    tools/nightly.ps1 -SoakMinutes 120
    tools/nightly.ps1 -Skip window,vblank120
#>
[CmdletBinding()]
param(
    # Configuração de lançamento (relativa à raiz do repositório).
    [string]$Launch = 'game/config/fg-launch.json',
    [int]$SoakMinutes = 60,
    # Etapas a pular: smoke, window, vblank120, soak.
    [string[]]$Skip = @(),
    # Só imprime o plano.
    [switch]$DryRun
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$Stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$OutDir = Join-Path $Root "captures/nightly/$Stamp"
$Tools = Join-Path $Root 'tools'
$Steps = 'smoke', 'window', 'vblank120', 'soak'
foreach ($s in $Skip) { if ($Steps -notcontains $s) { throw "etapa desconhecida em -Skip: $s (use: $($Steps -join ', '))" } }
$LaunchRel = $Launch
$LaunchAbs = if ([System.IO.Path]::IsPathRooted($Launch)) { $Launch } else { Join-Path $Root $Launch }
$LaunchV120Rel = 'build/nightly-launch-v120.json'

# ---------------------------------------------------------------- plano

function Get-Plan {
    @(
        [pscustomobject]@{ Step = 'smoke'; What = "run.ps1 -Launch $LaunchRel -Label nightly-smoke -TimeoutSec 120 -Stats -Quiet"; Env = 'KYTY_REDZONE_FAULT_AUDIT=1' }
        [pscustomobject]@{ Step = 'window'; What = 'run.ps1 -Label nightly-window -TimeoutSec 600 -Stats -Quiet em segundo plano + window-test.ps1 -RunDir <pasta>; taskkill no fim'; Env = '' }
        [pscustomobject]@{ Step = 'vblank120'; What = "soak.ps1 -Minutes 10 -Launch $LaunchV120Rel (cópia de $LaunchRel com --vblank-frequency 120) -Label nightly-v120"; Env = '' }
        [pscustomobject]@{ Step = 'soak'; What = "soak.ps1 -Minutes $SoakMinutes -Launch $LaunchRel -Label nightly-soak"; Env = 'KYTY_FAULT_CLASSIFY=1 KYTY_REDZONE_FAULT_AUDIT=1 DES_MEM=1' }
    )
}

if ($DryRun) {
    Write-Host "Bateria noturna (plano). Relatório: $OutDir\report.md"
    foreach ($p in Get-Plan) {
        $skipped = if ($Skip -contains $p.Step) { ' [PULADA]' } else { '' }
        Write-Host ("- {0}{1}: {2}{3}" -f $p.Step, $skipped, $p.What, $(if ($p.Env) { "  (env: $($p.Env))" } else { '' }))
    }
    Write-Host "Critérios: smoke (sem DES_CRASH, flip_600, sem RED_ZONE_AUDIT); window (window-test ok); vblank120 (completed, sem DES_CRASH, DES_FPS > 90); soak (completed, sem DES_CRASH, sem freeze-*.json, process_private < 5 MB/min após 10 min)."
    return
}

New-Item -ItemType Directory -Path $OutDir -Force | Out-Null

# ---------------------------------------------------------------- resumo de uma execução (Python, a triagem já existente)

$summaryPy = Join-Path $OutDir 'summarize.py'
Set-Content -LiteralPath $summaryPy -Encoding UTF8 -Value @'
import json, re, statistics, sys
from pathlib import Path
root, run_dir = Path(sys.argv[1]), Path(sys.argv[2])
sys.path.insert(0, str(root / 'tools'))
import log_triage

report, _ = log_triage.triage(run_dir)
out = {}
run = report.get('run') or {}
out['run_result'] = run.get('result')
out['exit_code'] = run.get('exit_code')
out['duration_sec'] = run.get('duration_sec')
out['milestones'] = [m['name'] for m in report['milestones']]
fps = [f for _, f in report['fps']]
if fps:
    half = fps[len(fps) // 2:]
    out['fps'] = dict(windows=len(fps), median_all=statistics.median(fps), median_second_half=statistics.median(half),
                      min=min(fps), max=max(fps), over90_second_half=sum(1 for f in half if f > 90))
else:
    out['fps'] = None
out['hitches'] = report.get('hitches')
out['crashes'] = report.get('crashes') or []
out['dumps'] = report.get('dumps') or []
out['error'] = report.get('error')
out['host_exception'] = bool(report.get('host_exception'))
cats = report.get('mem_categories') or {}
out['mem'] = cats.get('process_private')
# Inclinação de process_private depois dos 10 primeiros minutos.
late = [s for s in report.get('mem_samples') or [] if s[1] == 'process_private' and s[0] >= 600000]
slope = None
if late:
    saved = log_triage.MEM_SLOPE_SKIP_SEC
    log_triage.MEM_SLOPE_SKIP_SEC = 0
    slope = log_triage.mem_by_category(late).get('process_private', {}).get('slope_mb_per_min')
    log_triage.MEM_SLOPE_SKIP_SEC = saved
out['mem_slope_after_10min'] = slope
out['faults'] = report.get('faults')
text = ''
for name in ('log.txt', 'stdout.txt'):
    p = run_dir / name
    if p.exists():
        text += p.read_text(encoding='utf-8', errors='replace') + '\n'
out['red_zone_audit'] = len(re.findall(r'^RED_ZONE_AUDIT ', text, re.M))
out['des_window'] = sorted(set(re.findall(r'^DES_WINDOW (\S+)', text, re.M)))
out['des_window_lines'] = len(re.findall(r'^DES_WINDOW ', text, re.M))
out['des_vblank'] = re.findall(r'^DES_VBLANK (movie_pacing \S+)', text, re.M)[:6]
out['freeze_files'] = sorted(p.name for p in run_dir.glob('freeze-*.json'))
print(json.dumps(out, default=str))
'@

function Get-RunSummary([string]$RunDir) {
    if (-not $RunDir -or -not (Test-Path -LiteralPath $RunDir)) { return $null }
    try {
        $json = & python -I $summaryPy $Root $RunDir 2>&1
        if ($LASTEXITCODE -ne 0) { return [pscustomobject]@{ summary_error = ($json | Out-String).Trim() } }
        return ($json | Out-String | ConvertFrom-Json)
    } catch { return [pscustomobject]@{ summary_error = $_.Exception.Message } }
}

# ---------------------------------------------------------------- utilidades

function Find-RunDir([string]$Label, [datetime]$Since) {
    Get-ChildItem (Join-Path $Root 'captures/runs') -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like "*-$Label*" -and $_.CreationTime -ge $Since.AddSeconds(-5) } |
        Sort-Object CreationTime | Select-Object -Last 1
}

# Roda um script do repositório em um processo filho, com as variáveis de ambiente dadas (restauradas depois).
function Invoke-Child([string]$Script, [string[]]$Arguments, [hashtable]$EnvVars, [string]$LogName) {
    $saved = @{}
    foreach ($k in $EnvVars.Keys) { $saved[$k] = [Environment]::GetEnvironmentVariable($k); [Environment]::SetEnvironmentVariable($k, [string]$EnvVars[$k]) }
    try {
        $log = Join-Path $OutDir "$LogName.txt"
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Tools $Script) @Arguments *> $log
        return $LASTEXITCODE
    } finally {
        foreach ($k in $EnvVars.Keys) { [Environment]::SetEnvironmentVariable($k, $saved[$k]) }
    }
}

function Stop-Emulator {
    Get-Process kyty_emulator -ErrorAction SilentlyContinue | ForEach-Object { & taskkill.exe /PID $_.Id /T /F 2>&1 | Out-Null }
}

# Antes de cada etapa: nenhum emulador deve estar rodando (se houver, registra e encerra: a bateria é sem ninguém).
function Assert-NoEmulator([System.Collections.Generic.List[string]]$Notes) {
    if (Get-Process kyty_emulator -ErrorAction SilentlyContinue) {
        $Notes.Add('havia um kyty_emulator rodando antes da etapa: encerrado')
        Stop-Emulator
        Start-Sleep -Seconds 5
    }
}

# ---------------------------------------------------------------- etapas

$results = New-Object System.Collections.Generic.List[object]

function Add-Result([string]$Step, [string]$Status, $RunDir, $Summary, [System.Collections.Generic.List[string]]$Notes, [string[]]$Failures) {
    $results.Add([pscustomobject]@{ Step = $Step; Status = $Status; RunDir = $RunDir; Summary = $Summary; Notes = @($Notes); Failures = @($Failures) })
}

function Test-CommonCrash($S, [System.Collections.Generic.List[string]]$Failures) {
    if ($null -eq $S -or $S.PSObject.Properties['summary_error']) { $Failures.Add('sem resumo da execução (log ausente?)'); return }
    if (@($S.crashes).Count -gt 0) { $Failures.Add("DES_CRASH: $(@($S.crashes).Count)") }
}

function Invoke-Smoke {
    $notes = New-Object System.Collections.Generic.List[string]; $fail = New-Object System.Collections.Generic.List[string]
    Assert-NoEmulator $notes
    $t0 = Get-Date
    $code = Invoke-Child 'run.ps1' @('-Launch', $LaunchRel, '-Label', 'nightly-smoke', '-TimeoutSec', '120', '-Stats', '-Quiet') @{ KYTY_REDZONE_FAULT_AUDIT = '1' } 'smoke'
    $notes.Add("run.ps1 saiu com código $code")
    $dir = Find-RunDir 'nightly-smoke' $t0
    $s = if ($dir) { Get-RunSummary $dir.FullName } else { $null }
    if (-not $dir) { $fail.Add('pasta da execução não encontrada') }
    Test-CommonCrash $s $fail
    if ($s -and -not $s.PSObject.Properties['summary_error']) {
        if (@($s.milestones) -notcontains 'flip_600') { $fail.Add('flip_600 não atingido') }
        if ($s.red_zone_audit -gt 0) { $fail.Add("RED_ZONE_AUDIT: $($s.red_zone_audit)") }
    }
    Add-Result 'smoke' $(if ($fail.Count) { 'FALHA' } else { 'PASSOU' }) ($(if ($dir) { $dir.FullName })) $s $notes $fail
}

function Invoke-Window {
    $notes = New-Object System.Collections.Generic.List[string]; $fail = New-Object System.Collections.Generic.List[string]
    Assert-NoEmulator $notes
    $t0 = Get-Date
    $job = Start-Job -ScriptBlock {
        param($root, $launch)
        & (Join-Path $root 'tools/run.ps1') -Launch $launch -Label 'nightly-window' -TimeoutSec 600 -Stats -Quiet *> $null
    } -ArgumentList $Root, $LaunchRel
    $dir = $null
    try {
        for ($i = 0; $i -lt 60 -and -not $dir; $i++) { Start-Sleep -Milliseconds 500; $dir = Find-RunDir 'nightly-window' $t0 }
        if (-not $dir) { $fail.Add('run.ps1 não criou a pasta da execução') }
        else {
            Start-Sleep -Seconds 15
            $code = Invoke-Child 'window-test.ps1' @('-RunDir', $dir.FullName) @{} 'window-test'
            $notes.Add("window-test.ps1 saiu com código $code")
            $wt = Join-Path $dir.FullName 'window-test.json'
            if (-not (Test-Path -LiteralPath $wt)) { $fail.Add('window-test.json não foi gerado') }
            else {
                $verdict = (Get-Content -LiteralPath $wt -Raw -Encoding UTF8 | ConvertFrom-Json).verdict
                $notes.Add("veredito do window-test: $verdict")
                if ($verdict -ne 'ok') { $fail.Add("window-test: $verdict") }
            }
        }
    } finally {
        Stop-Emulator
        Wait-Job $job -Timeout 300 | Out-Null
        Remove-Job $job -Force
    }
    $s = if ($dir) { Get-RunSummary $dir.FullName } else { $null }
    Test-CommonCrash $s $fail
    Add-Result 'window' $(if ($fail.Count) { 'FALHA' } else { 'PASSOU' }) ($(if ($dir) { $dir.FullName })) $s $notes $fail
}

function Invoke-Soak([string]$Step, [string]$LaunchForSoak, [int]$Minutes, [string]$Label, [hashtable]$EnvVars) {
    $notes = New-Object System.Collections.Generic.List[string]; $fail = New-Object System.Collections.Generic.List[string]
    Assert-NoEmulator $notes
    $t0 = Get-Date
    $code = Invoke-Child 'soak.ps1' @('-Minutes', "$Minutes", '-Launch', $LaunchForSoak, '-Label', $Label) $EnvVars $Step
    $notes.Add("soak.ps1 saiu com código $code")
    $dir = Find-RunDir $Label $t0
    $s = if ($dir) { Get-RunSummary $dir.FullName } else { $null }
    if (-not $dir) { $fail.Add('pasta da execução não encontrada') }
    else {
        $soakJson = Join-Path $dir.FullName 'soak.json'
        $outcome = if (Test-Path -LiteralPath $soakJson) { (Get-Content -LiteralPath $soakJson -Raw | ConvertFrom-Json).outcome } else { 'sem soak.json' }
        $notes.Add("resultado do soak: $outcome")
        if ($outcome -ne 'completed') { $fail.Add("soak: $outcome") }
    }
    Test-CommonCrash $s $fail
    if ($s -and -not $s.PSObject.Properties['summary_error']) {
        if ($Step -eq 'vblank120') {
            $over = if ($s.fps) { $s.fps.over90_second_half } else { 0 }
            if (-not $s.fps -or $over -lt 1) { $fail.Add('nenhuma janela DES_FPS > 90 na segunda metade (preso em 60?)') }
        }
        if ($Step -eq 'soak') {
            if (@($s.freeze_files).Count -gt 0) { $fail.Add("freeze-*.json: $(@($s.freeze_files) -join ', ')") }
            if ($null -eq $s.mem_slope_after_10min) { $notes.Add('inclinação de process_private: sem amostras depois dos 10 min (DES_MEM ausente ou execução curta)') }
            elseif ($s.mem_slope_after_10min -ge 5) { $fail.Add(('process_private cresce {0:N1} MB/min depois dos 10 min' -f $s.mem_slope_after_10min)) }
            if ($s.red_zone_audit -gt 0) { $notes.Add("RED_ZONE_AUDIT: $($s.red_zone_audit) (informativo no soak)") }
        }
    }
    Add-Result $Step $(if ($fail.Count) { 'FALHA' } else { 'PASSOU' }) ($(if ($dir) { $dir.FullName })) $s $notes $fail
}

function Invoke-V120 {
    # Cópia do JSON de lançamento com 120 Hz (build/ fica fora do git).
    $launch = Get-Content -LiteralPath $LaunchAbs -Raw -Encoding UTF8 | ConvertFrom-Json
    $flags = New-Object System.Collections.Generic.List[string]
    foreach ($f in @($launch.flags)) { $flags.Add([string]$f) }
    $at = $flags.IndexOf('--vblank-frequency')
    if ($at -ge 0) { $flags[$at + 1] = '120' } else { $flags.Add('--vblank-frequency'); $flags.Add('120') }
    $launch.flags = @($flags)
    $target = Join-Path $Root $LaunchV120Rel
    New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
    ($launch | ConvertTo-Json -Depth 8) | Set-Content -LiteralPath $target -Encoding UTF8
    Invoke-Soak 'vblank120' $LaunchV120Rel 10 'nightly-v120' @{}
}

# Cada etapa é isolada: uma exceção vira ERRO e a bateria segue.
$runners = [ordered]@{
    smoke     = { Invoke-Smoke }
    window    = { Invoke-Window }
    vblank120 = { Invoke-V120 }
    soak      = { Invoke-Soak 'soak' $LaunchRel $SoakMinutes 'nightly-soak' @{ KYTY_FAULT_CLASSIFY = '1'; KYTY_REDZONE_FAULT_AUDIT = '1'; DES_MEM = '1' } }
}
foreach ($step in $runners.Keys) {
    if ($Skip -contains $step) { Add-Result $step 'PULADA' $null $null (New-Object System.Collections.Generic.List[string]) @(); continue }
    Write-Host "== $step ($((Get-Date).ToString('HH:mm:ss')))"
    try { & $runners[$step] }
    catch {
        Stop-Emulator
        $n = New-Object System.Collections.Generic.List[string]
        Add-Result $step 'ERRO' $null $null $n @($_.Exception.Message)
    }
    $last = $results[$results.Count - 1]
    Write-Host ("   -> {0} {1}" -f $last.Status, ($last.Failures -join '; '))
}

# ---------------------------------------------------------------- relatório

function Format-Number($v, [string]$f = 'N1') { if ($null -eq $v) { '—' } else { ([double]$v).ToString($f, [cultureinfo]::InvariantCulture) } }

function Get-KeyNumbers($r) {
    $s = $r.Summary
    if ($null -eq $s -or $s.PSObject.Properties['summary_error']) { return '—' }
    $parts = New-Object System.Collections.Generic.List[string]
    if ($s.fps) { $parts.Add("fps mediano $(Format-Number $s.fps.median_second_half) (min $(Format-Number $s.fps.min), max $(Format-Number $s.fps.max); > 90: $($s.fps.over90_second_half))") }
    if ($s.hitches) { $parts.Add("quadros lentos $($s.hitches.count) (pior $(Format-Number $s.hitches.worst_ms '0') ms, >= 1 s: $($s.hitches.over_1000), shader: $($s.hitches.compile_count))") }
    if ($s.mem) { $parts.Add("process_private $(Format-Number $s.mem.first_mb '0') -> $(Format-Number $s.mem.last_mb '0') MB (pico $(Format-Number $s.mem.peak_mb '0'), inclinação $(Format-Number $s.mem.slope_mb_per_min) MB/min; após 10 min: $(Format-Number $s.mem_slope_after_10min))") }
    if ($s.faults) {
        $f = $s.faults; $t = $f.totals; $sec = [double]$f.seconds
        $parts.Add(("faults/s {0:N0} (escrita direta {1:N0}, flexível {2:N0}, pooled {3:N0}, leitura {4:N1})" -f ($f.faults / $sec), ($t.write_direct / $sec), ($t.write_flexible / $sec), ($t.write_pooled / $sec), ($t.read / $sec)))
    }
    $parts.Add("DES_CRASH $(@($s.crashes).Count)")
    $parts.Add("RED_ZONE_AUDIT $($s.red_zone_audit)")
    if ($s.des_window_lines -gt 0) { $parts.Add("DES_WINDOW $($s.des_window_lines) ($(@($s.des_window) -join '/'))") }
    if (@($s.des_vblank).Count -gt 0) { $parts.Add("DES_VBLANK $(@($s.des_vblank).Count): $(@($s.des_vblank)[0])") }
    if (@($s.freeze_files).Count -gt 0) { $parts.Add("freeze: $(@($s.freeze_files).Count)") }
    return ($parts -join '; ')
}

$ran = @($results | Where-Object { $_.Status -ne 'PULADA' })
$ok = @($ran | Where-Object { $_.Status -eq 'PASSOU' })
$bad = @($ran | Where-Object { $_.Status -ne 'PASSOU' })
$crashTotal = ($ran | ForEach-Object { if ($_.Summary -and -not $_.Summary.PSObject.Properties['summary_error']) { @($_.Summary.crashes).Count } else { 0 } } | Measure-Object -Sum).Sum
$sk = $results | Where-Object { $_.Step -eq 'soak' } | Select-Object -First 1
$v120 = $results | Where-Object { $_.Step -eq 'vblank120' } | Select-Object -First 1

$L = New-Object System.Collections.Generic.List[string]
$L.Add("# Bateria noturna $Stamp")
$L.Add('')
$L.Add("1. **$($ok.Count) de $($ran.Count) etapas passaram**" + $(if ($bad.Count) { "; falharam: " + (($bad | ForEach-Object { "$($_.Step) ($($_.Status))" }) -join ', ') } else { '.' }))
$L.Add("2. DES_CRASH no total: $crashTotal." + $(if ($sk -and $sk.Status -ne 'PULADA') { " Soak: $($sk.Status)" + $(if ($sk.Failures.Count) { " ($($sk.Failures -join '; '))" } else { '' }) + '.' } else { '' }))
$L.Add("3. " + $(if ($v120 -and $v120.Summary -and $v120.Summary.PSObject.Properties['fps'] -and $v120.Summary.fps) { "vblank 120: fps mediano do gameplay $(Format-Number $v120.Summary.fps.median_second_half), $($v120.Summary.fps.over90_second_half) janelas > 90 fps." } else { 'vblank 120: sem dados de fps.' }))
$L.Add('')
$L.Add('| Etapa | Resultado | Pasta | Números-chave |')
$L.Add('|---|---|---|---|')
foreach ($r in $results) {
    $folder = if ($r.RunDir) { (Split-Path -Leaf $r.RunDir) } else { '—' }
    $L.Add("| $($r.Step) | **$($r.Status)** | $folder | $(Get-KeyNumbers $r) |")
}
$L.Add('')
foreach ($r in $results) {
    $L.Add("## $($r.Step) — $($r.Status)")
    if ($r.RunDir) { $L.Add("- Pasta: ``$($r.RunDir)``") }
    foreach ($f in $r.Failures) { $L.Add("- **Falha:** $f") }
    foreach ($n in $r.Notes) { $L.Add("- $n") }
    if ($r.Summary -and $r.Summary.PSObject.Properties['summary_error']) { $L.Add("- Resumo indisponível: $($r.Summary.summary_error)") }
    $L.Add('')
}
$reportPath = Join-Path $OutDir 'report.md'
Set-Content -LiteralPath $reportPath -Value $L -Encoding UTF8
Write-Host "Relatório: $reportPath"
foreach ($line in $L[0..4]) { Write-Host $line }
if ($bad.Count) { exit 1 }
exit 0
