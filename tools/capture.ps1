# SPDX-License-Identifier: GPL-2.0-only
<#
.SYNOPSIS
    Captura quadros de uma execução em andamento do engine e gera o relatório (captures.md).

.DESCRIPTION
    Usa o canal ao vivo do engine (KYTY_LIVE_FILE, src/local/live-control.h): o tools/run.ps1 define a variável com o
    arquivo <pasta da execução>\live-commands.txt (parâmetro -LiveFile do run.ps1). Este script escreve nele
        id <n>
        capture <pasta> <quadros> [hashes]
    (um "id" novo a cada pedido; o engine só roda ids maiores que o último que viu), espera os frame-N.jsonl completos
    aparecerem em <pasta da execução>\capture-<k> e chama tools/capture_report.py, que escreve captures.md ali:
    cada draw/dispatch em ordem, a dispatch do TAA (cs a44e580f4f0cfb2b) e as passadas que leem a saída dela, e as draws
    no alvo do tamanho da saída (UI). -Hashes lista shaders (hex, separados por vírgula) cujas constantes entram no
    .jsonl (jitter, matrizes).

    O caminho da pasta de captura não pode ter espaços (o comando do engine separa por espaço). A captura grava o
    estado do renderizador e deixa o jogo mais lento por alguns quadros; o jogo continua rodando depois.
    Só lê/escreve dentro da pasta da execução (captures/runs/..., fora do git).

.EXAMPLE
    tools/capture.ps1 -RunDir captures/runs/20261024-101500-play
    tools/capture.ps1 -RunDir captures/runs/20261024-101500-play -Frames 3 -Hashes a44e580f4f0cfb2b
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$RunDir,
    [int]$Frames = 2,
    # Hashes de shader (hex, separados por vírgula) cujas constantes entram na captura.
    [string]$Hashes = '',
    # Tempo máximo de espera pela captura, em segundos.
    [int]$TimeoutSec = 180,
    [string]$Python = 'python',
    # Shader do TAA e tamanho de saída (para o relatório).
    [string]$TaaShader = 'a44e580f4f0cfb2b',
    [string]$OutputSize = '3840x2160'
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
if (-not [System.IO.Path]::IsPathRooted($RunDir)) { $RunDir = Join-Path $Root $RunDir }
$RunDir = (Resolve-Path -LiteralPath $RunDir).Path
if ($Frames -lt 1) { throw '-Frames deve ser >= 1' }
if ($Hashes -notmatch '^[0-9a-fA-F,]*$') { throw '-Hashes: só hexadecimal separado por vírgula' }

$liveFile = Join-Path $RunDir 'live-commands.txt'
if (-not (Get-Process kyty_emulator -ErrorAction SilentlyContinue)) { throw 'nenhum kyty_emulator em execução' }

# Pasta da captura: capture-<k>, a próxima livre.
$k = 1
while (Test-Path -LiteralPath (Join-Path $RunDir "capture-$k")) { $k++ }
$captureDir = Join-Path $RunDir "capture-$k"
if ($captureDir -match '\s') { throw "o caminho da captura tem espaços: $captureDir" }

# O engine ignora ids que já viu (e o que já estava no arquivo ao iniciar): usa um id maior que o do arquivo e que o relógio.
$last = 0
if (Test-Path -LiteralPath $liveFile) {
    $first = Get-Content -LiteralPath $liveFile -TotalCount 1 -ErrorAction SilentlyContinue
    if ($first -match '^id (\d+)') { $last = [int64]$Matches[1] }
}
$id = [Math]::Max($last + 1, [DateTimeOffset]::UtcNow.ToUnixTimeSeconds())
$command = "capture $captureDir $Frames" + $(if ($Hashes) { " $Hashes" } else { '' })
$text = "id $id`n$command`n"
Write-Host "Comando: $command (id $id) em $liveFile"

# Uma só escrita (o engine lê o arquivo inteiro a cada 100 ms); tenta de novo se ele estiver abrindo o arquivo.
for ($try = 0; $try -lt 20; $try++) {
    try { [System.IO.File]::WriteAllText($liveFile, $text, (New-Object System.Text.UTF8Encoding $false)); break }
    catch [System.IO.IOException] { Start-Sleep -Milliseconds 100; if ($try -eq 19) { throw } }
}

# Espera os frames completos: cada frame-N.jsonl termina com a linha {"t":"flip",...}.
$deadline = (Get-Date).AddSeconds($TimeoutSec)
$complete = $false
while ((Get-Date) -lt $deadline) {
    Start-Sleep -Milliseconds 500
    if (-not (Test-Path -LiteralPath $captureDir)) { continue }
    $done = 0
    for ($n = 0; $n -lt $Frames; $n++) {
        $file = Join-Path $captureDir "frame-$n.jsonl"
        if (Test-Path -LiteralPath $file) {
            $tail = Get-Content -LiteralPath $file -Tail 1 -ErrorAction SilentlyContinue
            if ($tail -match '"t":"flip"') { $done++ }
        }
    }
    if ($done -ge $Frames) { $complete = $true; break }
    if (-not (Get-Process kyty_emulator -ErrorAction SilentlyContinue)) { throw 'o emulador fechou durante a captura' }
}
if (-not $complete) { throw "a captura não terminou em $TimeoutSec s (o jogo está rodando e submetendo quadros? KYTY_LIVE_FILE definido no lançamento?)" }

& $Python -I (Join-Path $Root 'tools/capture_report.py') $captureDir --taa-cs $TaaShader --output-size $OutputSize
if ($LASTEXITCODE -ne 0) { throw "capture_report.py falhou (código $LASTEXITCODE)" }
Write-Host "Captura: $captureDir"
Write-Host "Relatório: $(Join-Path $captureDir 'captures.md')"
