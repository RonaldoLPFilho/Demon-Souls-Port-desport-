# SPDX-License-Identifier: GPL-2.0-only
<#
.SYNOPSIS
    Teste do S-001: o jogo continua emulando com a janela minimizada, coberta ou restaurada em ciclos.

.DESCRIPTION
    Recebe a pasta de uma execução em andamento de tools/run.ps1 (-RunDir, com stdout.txt e o
    emulador vivo), espera o jogo estabilizar (N linhas DES_FPS seguidas >= -MinFps) e executa as
    fases abaixo, mexendo na janela só com ShowWindow por P/Invoke (SW_MINIMIZE, SW_SHOWNOACTIVATE,
    SW_RESTORE). NUNCA usa SetForegroundWindow e NUNCA envia teclas.

      1. baseline         janela normal.
      2. minimizada       SW_MINIMIZE por -PhaseSeconds.
      3. restaurada       SW_SHOWNOACTIVATE por -PhaseSeconds (volta sem foco).
      4. ciclos           -Cycles vezes minimizar/restaurar rápido (0,5 s cada).
      5. coberta          um Form de topo, sem ativar, cobrindo a janela do jogo.
      6. restore          minimizada 10 s e SW_RESTORE (como o usuário restaura).
      7. final            janela normal de novo.

    Para cada fase lê do stdout.txt as linhas DES_FPS (a cada 5 s), "SLOW Frame" e DES_WINDOW
    escritas durante a fase e grava window-test.json em -RunDir com fps mínimo/médio, maior SLOW
    Frame e veredito por fase. Uma fase FALHA se alguma linha DES_FPS ficar abaixo de
    -FailFps (30, uma janela de 5 s), se algum SLOW Frame passar de -FailSlowMs (1000 ms), ou se
    uma fase longa não tiver nenhuma linha DES_FPS (emulação parada). Código de saída: 0 tudo ok,
    1 alguma fase falhou, 2 o jogo não estabilizou ou a janela não foi achada.

    Não faz commit nem mexe em nada do jogo; ao sair (mesmo com erro) restaura a janela e fecha o
    Form de cobertura. Rodar só com o Ronaldo ciente: minimiza a janela do jogo na tela dele.

.EXAMPLE
    tools/window-test.ps1 -RunDir captures/runs/20261024-101500-fg
    tools/window-test.ps1 -RunDir captures/runs/20261024-101500-fg -PhaseSeconds 30 -Cycles 20
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$RunDir,
    [int]$StableCount = 3,        # linhas DES_FPS seguidas >= MinFps antes de começar
    [double]$MinFps = 50,
    [int]$PhaseSeconds = 20,
    [int]$Cycles = 20,
    [double]$FailFps = 30,        # abaixo disto em uma janela de 5 s a fase falha
    [double]$FailSlowMs = 1000,   # SLOW Frame acima disto falha a fase
    [int]$StartupTimeoutSec = 600,
    [string]$ProcessName = 'kyty_emulator'
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
if (-not [System.IO.Path]::IsPathRooted($RunDir)) { $RunDir = Join-Path $Root $RunDir }
$stdout = Join-Path $RunDir 'stdout.txt'
$jsonPath = Join-Path $RunDir 'window-test.json'
if (-not (Test-Path -LiteralPath $stdout)) { Write-Error "stdout.txt não encontrado em $RunDir"; exit 2 }

Add-Type -AssemblyName System.Windows.Forms
Add-Type -ReferencedAssemblies System.Windows.Forms, System.Drawing -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Windows.Forms;

public static class DesWin {
    public delegate bool EnumProc(IntPtr hwnd, IntPtr lparam);
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc proc, IntPtr lparam);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint pid);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr hwnd);
    [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr hwnd);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hwnd, int cmd);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hwnd, out RECT rect);
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }

    // A maior janela visível de nível superior do processo (a do jogo; sem título fixo).
    public static IntPtr FindMainWindow(uint pid) {
        IntPtr best = IntPtr.Zero; long bestArea = -1;
        EnumWindows(delegate (IntPtr h, IntPtr l) {
            uint p; GetWindowThreadProcessId(h, out p);
            if (p != pid || !IsWindowVisible(h)) return true;
            RECT r; GetWindowRect(h, out r);
            long area = (long)Math.Max(r.Right - r.Left, 1) * Math.Max(r.Bottom - r.Top, 1);
            if (IsIconic(h)) area = Math.Max(area, 1);
            if (area > bestArea) { bestArea = area; best = h; }
            return true;
        }, IntPtr.Zero);
        return best;
    }
}

// Form de topo que cobre a janela do jogo sem roubar o foco (WS_EX_NOACTIVATE).
public class DesCoverForm : Form {
    protected override bool ShowWithoutActivation { get { return true; } }
    protected override CreateParams CreateParams {
        get {
            CreateParams cp = base.CreateParams;
            cp.ExStyle |= 0x08000000 | 0x00000080 | 0x00000008; // NOACTIVATE | TOOLWINDOW | TOPMOST
            return cp;
        }
    }
}
'@

$SW_MINIMIZE = 6
$SW_SHOWNOACTIVATE = 4
$SW_RESTORE = 9

function Read-Lines {
    # Lê o stdout.txt inteiro com o emulador ainda escrevendo nele (compartilha leitura e escrita).
    $fs = [System.IO.File]::Open($stdout, 'Open', 'Read', 'ReadWrite')
    try {
        $sr = New-Object System.IO.StreamReader($fs)
        $list = New-Object System.Collections.Generic.List[string]
        while ($null -ne ($line = $sr.ReadLine())) { $list.Add($line) }
        return , $list
    } finally { $fs.Dispose() }
}

function Get-Game {
    $p = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $p) { return $null }
    $h = [DesWin]::FindMainWindow([uint32]$p.Id)
    if ($h -eq [IntPtr]::Zero) { return $null }
    return [pscustomobject]@{ Pid = $p.Id; Hwnd = $h }
}

function Parse-Fps($lines) {
    foreach ($l in $lines) { if ($l -match '^DES_FPS t=\d+ fps=([0-9.]+)') { [double]::Parse($Matches[1], [cultureinfo]::InvariantCulture) } }
}

# Fase: roda $Action (bloco que mexe na janela e espera) e avalia as linhas escritas durante ela.
$phases = New-Object System.Collections.Generic.List[object]
function Invoke-Phase([string]$Name, [int]$Seconds, [scriptblock]$Action) {
    $game = Get-Game
    if (-not $game) { throw "emulador ou janela sumiu antes da fase $Name" }
    $before = (Read-Lines).Count
    Write-Host "== fase $Name ($Seconds s)"
    $t0 = Get-Date
    & $Action
    $elapsed = ((Get-Date) - $t0).TotalSeconds
    $all = Read-Lines
    $new = if ($all.Count -gt $before) { $all.GetRange($before, $all.Count - $before) } else { @() }
    $fps = @(Parse-Fps $new)
    $slow = @()
    foreach ($l in $new) { if ($l -match 'SLOW Frame ([0-9.]+) ms') { $slow += [double]::Parse($Matches[1], [cultureinfo]::InvariantCulture) } }
    $events = @($new | Where-Object { $_ -like 'DES_WINDOW*' })
    $reasons = @()
    if ($fps.Count -eq 0 -and $Seconds -ge 10) { $reasons += 'nenhuma linha DES_FPS (emulação parada?)' }
    $fpsMin = $null; $fpsAvg = $null
    if ($fps.Count -gt 0) {
        $m = $fps | Measure-Object -Minimum -Average
        $fpsMin = [math]::Round($m.Minimum, 1); $fpsAvg = [math]::Round($m.Average, 1)
        if ($m.Minimum -lt $FailFps) { $reasons += "fps mínimo $fpsMin < $FailFps" }
    }
    $slowMax = if ($slow.Count) { ($slow | Measure-Object -Maximum).Maximum } else { 0 }
    if ($slowMax -gt $FailSlowMs) { $reasons += "SLOW Frame $slowMax ms > $FailSlowMs" }
    if (-not (Get-Process -Id $game.Pid -ErrorAction SilentlyContinue)) { $reasons += 'o emulador morreu na fase' }
    $verdict = if ($reasons.Count) { 'FALHA' } else { 'ok' }
    Write-Host ("   fps min={0} med={1} slow_max={2} ms eventos={3} -> {4}" -f $fpsMin, $fpsAvg, $slowMax, $events.Count, $verdict)
    $phases.Add([ordered]@{
        phase = $Name; seconds = [math]::Round($elapsed, 1); fps_lines = $fps.Count
        fps_min = $fpsMin; fps_avg = $fpsAvg; slow_count = $slow.Count; slow_max_ms = $slowMax
        window_events = $events; verdict = $verdict; reasons = $reasons
    })
}

function Wait-Pumping([double]$Seconds, $Form) {
    # Espera; com um Form de cobertura, bombeia as mensagens dele.
    $end = (Get-Date).AddSeconds($Seconds)
    while ((Get-Date) -lt $end) {
        if ($Form) { [System.Windows.Forms.Application]::DoEvents() }
        Start-Sleep -Milliseconds 50
    }
}

$game = Get-Game
if (-not $game) { Write-Error "processo $ProcessName ou sua janela não encontrados"; exit 2 }
$hwnd = $game.Hwnd
$cover = $null
$exit = 0
try {
    # 0. Espera o jogo estabilizar: StableCount linhas DES_FPS seguidas >= MinFps, ao menos uma nova.
    $startLines = (Read-Lines).Count
    $deadline = (Get-Date).AddSeconds($StartupTimeoutSec)
    $stable = $false
    Write-Host "esperando $StableCount linhas DES_FPS seguidas >= $MinFps ..."
    while ((Get-Date) -lt $deadline) {
        $all = Read-Lines
        $fps = @(Parse-Fps $all)
        $newCount = @(Parse-Fps ($all.GetRange($startLines, [math]::Max(0, $all.Count - $startLines)))).Count
        if ($newCount -ge 1 -and $fps.Count -ge $StableCount) {
            $tail = $fps[($fps.Count - $StableCount)..($fps.Count - 1)]
            if (@($tail | Where-Object { $_ -lt $MinFps }).Count -eq 0) { $stable = $true; break }
        }
        if (-not (Get-Process -Id $game.Pid -ErrorAction SilentlyContinue)) { Write-Error 'o emulador morreu antes de estabilizar'; exit 2 }
        Start-Sleep -Seconds 2
    }
    if (-not $stable) { Write-Error 'o jogo não estabilizou (fps) no prazo'; exit 2 }

    # 1. baseline
    Invoke-Phase 'baseline' $PhaseSeconds { Wait-Pumping $PhaseSeconds $null }

    # 2. minimizada
    Invoke-Phase 'minimizada' $PhaseSeconds {
        [void][DesWin]::ShowWindow($hwnd, $SW_MINIMIZE)
        Wait-Pumping $PhaseSeconds $null
    }

    # 3. restaurada sem foco
    Invoke-Phase 'restaurada' $PhaseSeconds {
        [void][DesWin]::ShowWindow($hwnd, $SW_SHOWNOACTIVATE)
        Wait-Pumping $PhaseSeconds $null
    }

    # 4. ciclos rápidos
    Invoke-Phase 'ciclos' ([int]($Cycles * 1.0 + 10)) {
        for ($i = 0; $i -lt $Cycles; $i++) {
            [void][DesWin]::ShowWindow($hwnd, $SW_MINIMIZE)
            Wait-Pumping 0.5 $null
            [void][DesWin]::ShowWindow($hwnd, $SW_SHOWNOACTIVATE)
            Wait-Pumping 0.5 $null
        }
        Wait-Pumping 10 $null   # deixa uma janela de 5 s inteira depois dos ciclos
    }

    # 5. coberta: Form de topo sem ativar, sobre o retângulo do jogo
    Invoke-Phase 'coberta' $PhaseSeconds {
        $r = New-Object DesWin+RECT
        [void][DesWin]::GetWindowRect($hwnd, [ref]$r)
        $script:cover = New-Object DesCoverForm
        $script:cover.FormBorderStyle = 'None'
        $script:cover.StartPosition = 'Manual'
        $script:cover.ShowInTaskbar = $false
        $script:cover.BackColor = [System.Drawing.Color]::Black
        $script:cover.Bounds = New-Object System.Drawing.Rectangle($r.Left, $r.Top, ($r.Right - $r.Left), ($r.Bottom - $r.Top))
        $script:cover.Show()
        Wait-Pumping $PhaseSeconds $script:cover
        $script:cover.Close()
        $script:cover.Dispose()
        $script:cover = $null
    }

    # 6. restore (SW_RESTORE, que pode dar foco, como o usuário faria)
    Invoke-Phase 'restore' 25 {
        [void][DesWin]::ShowWindow($hwnd, $SW_MINIMIZE)
        Wait-Pumping 10 $null
        [void][DesWin]::ShowWindow($hwnd, $SW_RESTORE)
        Wait-Pumping 15 $null
    }

    # 7. final
    Invoke-Phase 'final' $PhaseSeconds { Wait-Pumping $PhaseSeconds $null }
}
catch {
    Write-Host "erro: $($_.Exception.Message)" -ForegroundColor Red
    $exit = 2
}
finally {
    if ($cover) { try { $cover.Close(); $cover.Dispose() } catch {} }
    # Deixa a janela do jogo como estava: restaurada.
    if ([DesWin]::IsIconic($hwnd)) { [void][DesWin]::ShowWindow($hwnd, $SW_SHOWNOACTIVATE) }
    $failed = @($phases | Where-Object { $_.verdict -ne 'ok' })
    $overall = if ($exit -eq 2) { 'ERRO' } elseif ($failed.Count) { 'FALHA' } else { 'ok' }
    [ordered]@{
        test = 'S-001 window-test'; run_dir = $RunDir; when = (Get-Date).ToString('s')
        params = [ordered]@{ min_fps = $MinFps; phase_seconds = $PhaseSeconds; cycles = $Cycles; fail_fps = $FailFps; fail_slow_ms = $FailSlowMs }
        verdict = $overall; phases = $phases
    } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $jsonPath -Encoding UTF8
    Write-Host "veredito: $overall  ($jsonPath)"
}
if ($exit -eq 0 -and $failed.Count) { exit 1 }
exit $exit
