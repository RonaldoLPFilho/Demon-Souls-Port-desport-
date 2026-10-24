# SPDX-License-Identifier: GPL-2.0-only
<#
.SYNOPSIS
    Salva a área do jogo (cliente da janela do kyty_emulator) em PNG na resolução real.

.DESCRIPTION
    Para avaliar imagem (ultrawide, DLSS): a miniatura do autopilot é reduzida a 640x360. Traz a janela para
    a frente só se -Focus for passado; sem isso captura onde a janela estiver (precisa estar visível).
    A imagem é derivada do jogo: salve só em captures/ (fora do git).
#>
[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$Out, [switch]$Focus)
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing @"
using System; using System.Drawing; using System.Runtime.InteropServices;
public class DesShot {
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
  [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }
  [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref POINT p);
  public static Bitmap Client(IntPtr h) {
    RECT r; POINT o = new POINT();
    if (!GetClientRect(h, out r) || !ClientToScreen(h, ref o) || r.Right <= 0 || r.Bottom <= 0) return null;
    var full = new Bitmap(r.Right, r.Bottom);
    using (var g = Graphics.FromImage(full)) g.CopyFromScreen(o.X, o.Y, 0, 0, full.Size);
    return full;
  }
}
"@
[DesShot]::SetProcessDPIAware() | Out-Null
$p = Get-Process kyty_emulator -ErrorAction SilentlyContinue | Where-Object MainWindowHandle -ne 0 | Select-Object -First 1
if (-not $p) { Write-Host 'emulador não está rodando'; exit 1 }
if ($Focus) { [DesShot]::SetForegroundWindow($p.MainWindowHandle) | Out-Null; Start-Sleep -Milliseconds 300 }
$bmp = [DesShot]::Client($p.MainWindowHandle)
if (-not $bmp) { Write-Host 'sem área cliente'; exit 1 }
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Out) | Out-Null
$bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
Write-Host ("{0}x{1} -> {2}" -f $bmp.Width, $bmp.Height, $Out)
$bmp.Dispose()
