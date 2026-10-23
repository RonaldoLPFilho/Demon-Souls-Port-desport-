# SPDX-License-Identifier: GPL-2.0-only
<#
.SYNOPSIS
    Leva o jogo aberto até o gameplay e o mantém se mexendo (PLAN.md Fase 5, soak).

.DESCRIPTION
    Adaptado de tools/local/windows/bench-run.ps1 do KytyPS5-DemonsSouls-FrameGen (ceremony88, GPL-2.0):
    o estado da tela (menu, prompt offline, fog, cutscene, HUD) sai de estatísticas de pixels da área
    do jogo reduzida a 640x360, e as teclas vão só para a janela do emulador (Enter = Options,
    J = Cross, WASD anda, F/H giram a câmera no mapeamento padrão do KytyPS5).

    Fases:
      1. até o HUD (no máximo -StartupSeconds): responde ao prompt, confirma o menu, pula cutscenes;
      2. por -PlaySeconds: anda para frente e para trás e gira a câmera, sem sair muito do lugar.
    Uma linha por mudança de estado vai para a saída; com -ShotDir, uma miniatura a cada -ShotEvery s.
    Código de saída: 0 terminou, 1 sem HUD, 2 o emulador fechou (crash ou saída) durante o jogo.
#>
[CmdletBinding()]
param(
    [int]$StartupSeconds = 240,
    [int]$PlaySeconds = 600,
    [string]$ShotDir = '',
    [int]$ShotEvery = 60
)

Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing @"
using System; using System.Drawing; using System.Runtime.InteropServices;
public class DesWin {
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
  [DllImport("user32.dll")] public static extern uint MapVirtualKey(uint code, uint type);
  [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, IntPtr extra);
  [DllImport("imm32.dll")] public static extern IntPtr ImmGetDefaultIMEWnd(IntPtr h);
  [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr h, uint msg, IntPtr w, IntPtr l);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
  [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }
  [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref POINT p);
  [StructLayout(LayoutKind.Sequential)] public struct KEYBDINPUT { public ushort wVk, wScan; public uint dwFlags, time; public IntPtr dwExtraInfo; }
  [StructLayout(LayoutKind.Explicit, Size=40)] public struct INPUT { [FieldOffset(0)] public uint type; [FieldOffset(8)] public KEYBDINPUT ki; }
  [DllImport("user32.dll")] public static extern uint SendInput(uint n, INPUT[] i, int size);
  public static bool Focus(IntPtr h) {
    if (IsIconic(h)) ShowWindow(h, 9);
    if (GetForegroundWindow() != h) { keybd_event(0x12, 0, 0, IntPtr.Zero); keybd_event(0x12, 0, 2, IntPtr.Zero); SetForegroundWindow(h); System.Threading.Thread.Sleep(150); }
    return GetForegroundWindow() == h;
  }
  public static void Key(ushort vk, bool up) {
    var i = new INPUT[1]; i[0].type = 1; i[0].ki.wScan = (ushort)MapVirtualKey(vk, 0);
    i[0].ki.dwFlags = 8u | (up ? 2u : 0u);
    SendInput(1, i, Marshal.SizeOf(typeof(INPUT)));
  }
  public static Bitmap Client(IntPtr h) {
    RECT r; POINT o = new POINT();
    if (!GetClientRect(h, out r) || !ClientToScreen(h, ref o) || r.Right <= 0 || r.Bottom <= 0) return null;
    using (var full = new Bitmap(r.Right, r.Bottom)) {
      using (var g = Graphics.FromImage(full)) g.CopyFromScreen(o.X, o.Y, 0, 0, full.Size);
      var small = new Bitmap(640, 360);
      using (var g2 = Graphics.FromImage(small)) { g2.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.Bilinear; g2.DrawImage(full, 0, 0, 640, 360); }
      return small;
    }
  }
}
"@
[DesWin]::SetProcessDPIAware() | Out-Null

function Window { Get-Process kyty_emulator -ErrorAction SilentlyContinue | Where-Object MainWindowHandle -ne 0 | Select-Object -First 1 }
$script:unfocused = 0

# Teclas só com a janela do emulador na frente: nunca digita em outra janela.
function Press([string]$key, [int]$ms = 150) {
    $w = Window; if (-not $w -or -not [DesWin]::Focus($w.MainWindowHandle)) { $script:unfocused++; return }
    $ime = [DesWin]::ImmGetDefaultIMEWnd($w.MainWindowHandle)
    if ($ime -ne [IntPtr]::Zero) { [DesWin]::SendMessage($ime, 0x283, [IntPtr]6, [IntPtr]::Zero) | Out-Null }
    $code = if ($key -eq 'enter') { 0x0D } else { [int][char]$key.ToUpper() }
    [DesWin]::Key([uint16]$code, $false); Start-Sleep -Milliseconds $ms; [DesWin]::Key([uint16]$code, $true)
}

# Estado da tela a partir da imagem 640x360 (limiares do bench-run.ps1).
function Get-ScreenState([System.Drawing.Bitmap]$bmp) {
    $red = 0
    for ($y = 250; $y -lt 360; $y++) { for ($x = 0; $x -lt 130; $x++) {
        $c = $bmp.GetPixel($x, $y); if ($c.R -gt 90 -and $c.R -gt 2 * $c.G -and $c.R -gt 2 * $c.B) { $red++ } } }
    $bar = 0
    for ($y = 2; $y -lt 22; $y++) { for ($x = 10; $x -lt 140; $x++) {
        $c = $bmp.GetPixel($x, $y); if ($c.R -gt 90 -and $c.R -gt 2 * $c.G -and $c.R -gt 2 * $c.B) { $bar++ } } }
    if ($red -gt 70 -and $bar -gt 100) { return 'hud' }
    $stamina = 0
    if ($red -gt 20) {
        for ($y = 2; $y -lt 30; $y++) { for ($x = 10; $x -lt 200; $x++) {
            $c = $bmp.GetPixel($x, $y); if ($c.G -gt 80 -and $c.G -gt 1.5 * $c.R -and $c.G -gt 1.3 * $c.B) { $stamina++ } } }
    }
    if ($stamina -gt 120) { return 'hud' }
    $dark = 0; $total = 0; $sr = 0; $sg = 0; $sb = 0; $center = 0; $sat = 0
    for ($y = 0; $y -lt 360; $y += 4) { for ($x = 0; $x -lt 640; $x += 4) {
        $c = $bmp.GetPixel($x, $y); $total++; $sr += $c.R; $sg += $c.G; $sb += $c.B
        $sat += [Math]::Max([Math]::Max($c.R, $c.G), $c.B) - [Math]::Min([Math]::Min($c.R, $c.G), $c.B)
        if ($c.R + $c.G + $c.B -lt 30) { $dark++ }
        if ($x -gt 200 -and $x -lt 440 -and $y -gt 110 -and $y -lt 240 -and ($c.R + $c.G + $c.B) -gt 400) { $center++ } } }
    $teal = 0
    for ($y = 178; $y -le 210; $y += 2) { for ($x = 220; $x -lt 420; $x += 2) {
        $c = $bmp.GetPixel($x, $y); if ($c.G -gt 45 -and $c.G -gt $c.R + 25 -and [Math]::Abs([int]$c.G - [int]$c.B) -le 12) { $teal++ } } }
    if ($dark / $total -gt 0.75 -and $center -gt 3 -and $teal -gt 20) { return 'prompt' }
    if ($sg -gt 1.25 * $sr -and $sg -gt 1.1 * $sb) { return 'menu' }
    if ($dark / $total -gt 0.97) { return 'dark' }
    $bands = 0; $bandTotal = 0; $middle = 0; $middleTotal = 0
    for ($x = 0; $x -lt 640; $x += 8) {
        foreach ($y in @(4, 12, 20, 28, 332, 340, 348, 356)) { $c = $bmp.GetPixel($x, $y); $bandTotal++; if ($c.R + $c.G + $c.B -lt 30) { $bands++ } }
        for ($y = 80; $y -lt 280; $y += 20) { $c = $bmp.GetPixel($x, $y); $middleTotal++; if ($c.R + $c.G + $c.B -lt 30) { $middle++ } }
    }
    if ($bands / $bandTotal -gt 0.97 -and $middle / $middleTotal -lt 0.8) { return 'cinematic' }
    $lum = ($sr + $sg + $sb) / (3.0 * $total); $sat = $sat / $total
    if ($lum -gt 60 -and $dark -eq 0 -and $sat -lt 5) { return 'fog' }
    if ($lum -lt 30 -and $sat -lt 2.5) { return 'mono' }
    return 'other'
}

function Capture {
    $w = Window
    if ($w -and [DesWin]::Focus($w.MainWindowHandle)) { return [DesWin]::Client($w.MainWindowHandle) }
    $script:unfocused++
    return $null
}

$clock = [Diagnostics.Stopwatch]::StartNew()
function Say([string]$text) { Write-Output ("{0,7:N1} s {1}" -f $clock.Elapsed.TotalSeconds, $text) }

# 1. Até o HUD.
while (-not (Window)) {
    if ($clock.Elapsed.TotalSeconds -gt 60) { Say 'janela do emulador não apareceu'; exit 1 }
    Start-Sleep -Milliseconds 500
}
$answered = $false; $fogSeen = $false; $earlySkips = 0; $lastSkip = [DateTime]::MinValue; $last = ''; $state = ''
while ($clock.Elapsed.TotalSeconds -lt $StartupSeconds) {
    if (-not (Get-Process kyty_emulator -ErrorAction SilentlyContinue)) { Say 'emulador fechou antes do HUD'; exit 2 }
    $bmp = Capture
    if (-not $bmp) { Start-Sleep -Milliseconds 500; continue }
    try { $state = Get-ScreenState $bmp } finally { $bmp.Dispose() }
    if ($state -ne $last) { Say "estado: $state"; $last = $state }
    if ($state -eq 'hud') { break }
    if ($state -eq 'prompt') { Press j; $answered = $true; Start-Sleep -Milliseconds 1500; continue }
    if ($state -eq 'menu') { Press j; Start-Sleep -Milliseconds 1500; continue }
    if ($state -eq 'fog') { $fogSeen = $true }
    $early = $answered -and $fogSeen -and $state -eq 'mono' -and $earlySkips -lt 3 -and ((Get-Date) - $lastSkip).TotalSeconds -ge 4
    if ($state -eq 'cinematic' -or (($state -eq 'other' -or $state -eq 'mono') -and -not $answered) -or $early) {
        if ($early) { $earlySkips++ }
        Press enter; Start-Sleep -Milliseconds 700; Press j 1500; Start-Sleep -Milliseconds 800
        $lastSkip = Get-Date
        continue
    }
    Start-Sleep -Milliseconds 500
}
if ($state -ne 'hud') { Say "sem HUD em $StartupSeconds s (último estado: $state; janela fora de foco ${script:unfocused}x)"; exit 1 }
Say 'HUD: no jogo'

# 2. Jogo: frente, giro, trás, giro — fica perto do ponto de partida.
$plan = @(@('w', 3000), @('h', 600), @('s', 3000), @('f', 600))
$playClock = [Diagnostics.Stopwatch]::StartNew()
$nextShot = 0; $step = 0
while ($playClock.Elapsed.TotalSeconds -lt $PlaySeconds) {
    if (-not (Get-Process kyty_emulator -ErrorAction SilentlyContinue)) { Say 'emulador fechou durante o jogo'; exit 2 }
    if ($ShotDir -and $playClock.Elapsed.TotalSeconds -ge $nextShot) {
        $bmp = Capture
        if ($bmp) {
            try {
                New-Item -ItemType Directory -Force -Path $ShotDir | Out-Null
                $s = Get-ScreenState $bmp
                $bmp.Save((Join-Path $ShotDir ("{0:0000}-{1}.png" -f [int]$playClock.Elapsed.TotalSeconds, $s)))
            } finally { $bmp.Dispose() }
        }
        $nextShot += $ShotEvery
    }
    $key, $ms = $plan[$step % $plan.Count]
    Press $key $ms
    Start-Sleep -Milliseconds 400
    $step++
}
Say "jogo por $PlaySeconds s concluído ($step movimentos, janela fora de foco ${script:unfocused}x)"
exit 0
