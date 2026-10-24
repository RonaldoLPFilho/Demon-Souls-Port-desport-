# SPDX-License-Identifier: GPL-2.0-only
<#
.SYNOPSIS
    Executa o KytyPS5 com o Demon's Souls e guarda tudo da execução (PLAN.md §6 Fases 0 e 2).

.DESCRIPTION
    Lê DES_GAME_DIR (e opcionalmente KYTY_EXE) de desport.local.ini, executa
    kyty_emulator.exe --game <dump> com as flags pedidas e encerra o processo no tempo limite.

    Saída em captures/runs/<data-hora>[-rótulo]/:
      log.txt     log do KytyPS5 (--printf-direction File; sem isso o KytyPS5 não loga nada)
      stdout.txt  saída padrão do processo (mensagens antes do log iniciar)
      stderr.txt  erro padrão do processo
    O processo roda em user/kyty/ (persistente, fora do git): cache de pipelines, saves e dados
    temporários do KytyPS5 sobrevivem entre execuções.
      run.json    comando exato, commits do engine e do desport, tempos, resultado e picos de memória
      memory.csv  memória privada e working set do processo a cada segundo
      calls.json  chamadas por import (com -Trace ou cenário com trace = true; DES_TRACE=1)
      triage.md   relatório do tools/log_triage.py (e veredito do cenário, com -Scenario)

    Nada é escrito fora de captures/. A pasta do dump só é lida.

.EXAMPLE
    tools/run.ps1
    tools/run.ps1 -Label validation --vulkan-validation --shader-validation
    tools/run.ps1 -Label cbdump -TimeoutSec 120 --command-buffer-dump
    tools/run.ps1 -DryRun
    tools/run.ps1 -Scenario boot               # cenário de tests/regression/scenarios.toml
    tools/run.ps1 -Trace -Label trace          # conta as chamadas a cada import
#>
[CmdletBinding(PositionalBinding = $false)]
param(
    # Flags extras para o kyty_emulator, no fim da linha (ex.: --vulkan-validation --shader-validation).
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Flags = @(),
    # Tempo limite em segundos; ao estourar, o processo e seus filhos são encerrados.
    [int]$TimeoutSec = 180,
    # Sufixo opcional do nome da pasta da execução.
    [string]$Label = '',
    # Sobrescreve DES_GAME_DIR do desport.local.ini.
    [string]$GameDir = '',
    # Sobrescreve KYTY_EXE do desport.local.ini.
    [string]$KytyExe = '',
    # Cenário de tests/regression/scenarios.toml: flags, tempo limite, trace e critérios.
    [string]$Scenario = '',
    # Pasta de trabalho do processo (padrão user/kyty). Uma pasta vazia dá cache de pipelines frio.
    [string]$WorkDir = '',
    # Liga o rastreamento de chamadas (DES_TRACE=1 -> calls.json).
    [switch]$Trace,
    # Configuração de lançamento (JSON: environment, flags e, opcionais, kyty_exe e work_dir relativos à raiz).
    [string]$Launch = '',
    # Log do engine em Silent (testes longos: o log completo do engine FrameGen cresce ~80 MB/min);
    # as linhas DES_* e SLOW Frame continuam no stdout.txt, que a triagem também lê.
    [switch]$Quiet,
    # Liga os contadores de desempenho no log (DES_STATS=1 -> DES_COUNTERS, DES_STAT, DES_STAT_ADDR).
    [switch]$Stats,
    # Monta e grava o comando em run.json sem executar.
    [switch]$DryRun
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSScriptRoot

function Fail([string]$Message) {
    Write-Host "run.ps1: $Message" -ForegroundColor Red
    exit 1
}

function Read-LocalIni([string]$Path) {
    $values = @{}
    if (-not (Test-Path -LiteralPath $Path)) { return $values }
    foreach ($line in Get-Content -LiteralPath $Path -Encoding UTF8) {
        $t = $line.Trim()
        if ($t -eq '' -or $t.StartsWith('#') -or $t.StartsWith(';')) { continue }
        $eq = $t.IndexOf('=')
        if ($eq -lt 1) { continue }
        $values[$t.Substring(0, $eq).Trim()] = $t.Substring($eq + 1).Trim().Trim('"')
    }
    return $values
}

# Aspas no estilo do CommandLineToArgvW, para o comando gravado ser exatamente o executado.
function Quote-Arg([string]$Arg) {
    if ($Arg -ne '' -and $Arg -notmatch '[\s"]') { return $Arg }
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append('"')
    $slashes = 0
    foreach ($ch in $Arg.ToCharArray()) {
        if ($ch -eq '\') { $slashes++; continue }
        if ($ch -eq '"') { [void]$sb.Append('\' * ($slashes * 2 + 1)); [void]$sb.Append('"') }
        else { [void]$sb.Append('\' * $slashes); [void]$sb.Append($ch) }
        $slashes = 0
    }
    [void]$sb.Append('\' * ($slashes * 2))
    [void]$sb.Append('"')
    return $sb.ToString()
}

function Get-GitInfo([string]$Path) {
    if (-not (Test-Path -LiteralPath (Join-Path $Path '.git'))) { return $null }
    # No PowerShell 5.1 o stderr de um comando nativo vira erro fatal sob 'Stop'.
    $ErrorActionPreference = 'Continue'
    $commit = (& git -C $Path rev-parse --verify --quiet HEAD 2>$null)
    if (-not $commit) { return $null }
    $dirty = [bool](& git -C $Path status --porcelain --untracked-files=no 2>$null)
    return [ordered]@{ commit = "$commit".Trim(); dirty = $dirty }
}

$ini = Read-LocalIni (Join-Path $Root 'desport.local.ini')

if (-not $GameDir) { if ($ini.ContainsKey('DES_GAME_DIR')) { $GameDir = $ini['DES_GAME_DIR'] } }
if (-not $GameDir) {
    Fail 'DES_GAME_DIR não definido. Copie desport.local.ini.example para desport.local.ini e preencha.'
}
if (-not (Test-Path -LiteralPath $GameDir)) { Fail "pasta do dump não encontrada: $GameDir" }
$GameDir = (Resolve-Path -LiteralPath $GameDir).Path
if ((Test-Path -LiteralPath $GameDir -PathType Container) -and
    -not (Test-Path -LiteralPath (Join-Path $GameDir 'eboot.bin'))) {
    Fail "não há eboot.bin em $GameDir (esperado o dump PPSA01342)."
}

if (-not $KytyExe) { if ($ini.ContainsKey('KYTY_EXE')) { $KytyExe = $ini['KYTY_EXE'] } }
if (-not $KytyExe) {
    $candidates = @(
        'engine/_Build/windows/install/kyty_emulator.exe',
        'engine/_Build/windows/kyty_emulator.exe',
        'engine/_Build/windows-dbg/install/kyty_emulator.exe',
        'engine/_Build/windows-dbg/kyty_emulator.exe'
    )
    foreach ($c in $candidates) {
        $p = Join-Path $Root $c
        if (Test-Path -LiteralPath $p) { $KytyExe = $p; break }
    }
}
if (-not $KytyExe -and -not $DryRun) {
    Fail 'kyty_emulator.exe não encontrado. Compile o engine (PLAN.md Fase 0, tarefa 4) ou defina KYTY_EXE.'
}
if ($KytyExe) {
    if (Test-Path -LiteralPath $KytyExe) { $KytyExe = (Resolve-Path -LiteralPath $KytyExe).Path }
    elseif (-not $DryRun) { Fail "KYTY_EXE não existe: $KytyExe" }
} else {
    $KytyExe = 'kyty_emulator.exe'
}

# Flags padrão do jogo (game/config/des.toml) vêm antes das do cenário e da linha de comando.
$gameConfig = Join-Path $Root 'game/config/des.toml'
$gameFlags = @()
if (Test-Path -LiteralPath $gameConfig) {
    $json = & python -I -c "import json,sys,tomllib; print(json.dumps(tomllib.load(open(sys.argv[1],'rb')).get('flags', [])))" $gameConfig
    if ($LASTEXITCODE -ne 0) { Fail "game/config/des.toml inválido" }
    $gameFlags = @($json | ConvertFrom-Json)
}

$scenarioInfo = $null
if ($Scenario) {
    $tomlPath = Join-Path $Root 'tests/regression/scenarios.toml'
    $json = & python -I -c "import json,sys,tomllib; d=tomllib.load(open(sys.argv[1],'rb')); print(json.dumps(d.get(sys.argv[2])))" $tomlPath $Scenario
    if ($LASTEXITCODE -ne 0 -or -not $json -or $json -eq 'null') { Fail "cenário desconhecido: $Scenario ($tomlPath)" }
    $scenarioInfo = $json | ConvertFrom-Json
    if ($scenarioInfo.PSObject.Properties['enabled'] -and -not $scenarioInfo.enabled) {
        Fail "cenário '$Scenario' está desativado (enabled = false): $($scenarioInfo.description)"
    }
    if ($scenarioInfo.PSObject.Properties['type'] -and $scenarioInfo.type -ne 'auto') {
        Write-Host "Cenário '$Scenario' é $($scenarioInfo.type): exige o Ronaldo durante a execução." -ForegroundColor Yellow
    }
    if ($scenarioInfo.PSObject.Properties['flags']) { $Flags = @($scenarioInfo.flags) + @($Flags) }
    if ($scenarioInfo.PSObject.Properties['timeout_sec'] -and -not $PSBoundParameters.ContainsKey('TimeoutSec')) {
        $TimeoutSec = [int]$scenarioInfo.timeout_sec
    }
    if ($scenarioInfo.PSObject.Properties['trace'] -and $scenarioInfo.trace) { $Trace = [switch]$true }
    if (-not $Label) { $Label = $Scenario }
}
$launchEnv = @{}
if ($Launch) {
    $launchPath = if (Test-Path -LiteralPath $Launch) { (Resolve-Path -LiteralPath $Launch).Path } else { Join-Path $Root $Launch }
    if (-not (Test-Path -LiteralPath $launchPath)) { Fail "configuração de lançamento não encontrada: $Launch" }
    $launchInfo = Get-Content -LiteralPath $launchPath -Raw | ConvertFrom-Json
    foreach ($p in $launchInfo.environment.PSObject.Properties) { $launchEnv[$p.Name] = [string]$p.Value }
    if ($launchInfo.PSObject.Properties['flags']) { $Flags = @($launchInfo.flags) + @($Flags) }
    if ($launchInfo.PSObject.Properties['kyty_exe'] -and -not $PSBoundParameters.ContainsKey('KytyExe')) {
        $KytyExe = Join-Path $Root $launchInfo.kyty_exe
    }
    if ($launchInfo.PSObject.Properties['work_dir'] -and -not $WorkDir) { $WorkDir = Join-Path $Root $launchInfo.work_dir }
}
if ($Quiet) { $Flags = @($Flags) + @('--printf-direction', 'Silent') }
# No PowerShell 5.1 um array JSON vazio vira um elemento vazio; descarta-os.
$Flags = @(@($gameFlags) + @($Flags) | Where-Object { $_ -ne $null -and "$_" -ne '' })

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$name = if ($Label) { "$stamp-$($Label -replace '[^\w.-]', '_')" } else { $stamp }
$RunDir = Join-Path $Root "captures/runs/$name"
for ($i = 2; Test-Path -LiteralPath $RunDir; $i++) {
    $RunDir = Join-Path $Root "captures/runs/$name-$i"
}
$name = Split-Path -Leaf $RunDir
New-Item -ItemType Directory -Force -Path $RunDir | Out-Null

$logFile = Join-Path $RunDir 'log.txt'
$argList = New-Object System.Collections.Generic.List[string]
$argList.Add('--game'); $argList.Add($GameDir)
foreach ($f in $Flags) { $argList.Add($f) }
# Sem --printf-direction o KytyPS5 fica em Silent e não grava log nenhum.
if ($Flags -notcontains '--printf-direction') {
    $argList.Add('--printf-direction'); $argList.Add('File')
    $argList.Add('--printf-output-file'); $argList.Add($logFile)
}
# Dumps de command buffer ficam dentro da pasta da execução (captures/ é ignorado pelo git).
if ($Flags -contains '--command-buffer-dump' -and $Flags -notcontains '--command-buffer-dump-folder') {
    $argList.Add('--command-buffer-dump-folder'); $argList.Add((Join-Path $RunDir 'command_buffers'))
}
$argString = ($argList | ForEach-Object { Quote-Arg $_ }) -join ' '

$exeHash = $null
if (Test-Path -LiteralPath $KytyExe) { $exeHash = (Get-FileHash -LiteralPath $KytyExe -Algorithm SHA256).Hash.ToLower() }

$run = [ordered]@{
    run_id      = $name
    label       = $Label
    command     = "$(Quote-Arg $KytyExe) $argString"
    exe         = $KytyExe
    exe_sha256  = $exeHash
    args        = @($argList)
    flags       = @($Flags)
    game_dir    = $GameDir
    timeout_sec = $TimeoutSec
    scenario    = $Scenario
    trace       = [bool]$Trace
    stats       = [bool]$Stats
    launch      = $Launch
    launch_environment = $launchEnv
    engine_git  = Get-GitInfo (Join-Path $Root 'engine')
    desport_git = Get-GitInfo $Root
    host        = [ordered]@{ machine = $env:COMPUTERNAME; os = [Environment]::OSVersion.VersionString }
    started     = (Get-Date).ToString('o')
    ended       = $null
    duration_sec = $null
    result      = $null
    exit_code   = $null
}

function Save-Run { $run | ConvertTo-Json -Depth 5 | Out-File -LiteralPath (Join-Path $RunDir 'run.json') -Encoding utf8 }

if ($DryRun) {
    $run.result = 'dry_run'
    Save-Run
    Write-Host "Execução simulada: $RunDir"
    Write-Host $run.command
    exit 0
}

Save-Run
Write-Host "Executando ($TimeoutSec s): $($run.command)"

if ($Stats) { $env:DES_STATS = '1' }
# Minidump e linha DES_CRASH de um crash real vão para a pasta da execução (engine desport-crash).
$env:DES_CRASH_DIR = $RunDir
foreach ($k in $launchEnv.Keys) { Set-Item -Path "Env:$k" -Value $launchEnv[$k] }
if ($Trace) {
    $env:DES_TRACE = '1'
    $env:DES_TRACE_FILE = Join-Path $RunDir 'calls.json'
}
$timer = [Diagnostics.Stopwatch]::StartNew()
# Pasta de trabalho persistente: o KytyPS5 grava ali _PipelineCache, _DownloadData, _TempData e
# saves, relativos ao diretório atual. Log, dumps e calls.json vão para $RunDir por caminho absoluto.
if (-not $WorkDir) { $WorkDir = Join-Path $Root 'user/kyty' }
New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null
$run.work_dir = $WorkDir
Save-Run
$proc = Start-Process -FilePath $KytyExe -ArgumentList $argString -WorkingDirectory $WorkDir `
    -RedirectStandardOutput (Join-Path $RunDir 'stdout.txt') `
    -RedirectStandardError (Join-Path $RunDir 'stderr.txt') -PassThru
[void]$proc.Handle  # no PowerShell 5.1, sem isso ExitCode fica vazio depois do término
Remove-Item Env:DES_TRACE, Env:DES_TRACE_FILE, Env:DES_STATS, Env:DES_CRASH_DIR -ErrorAction SilentlyContinue
foreach ($k in $launchEnv.Keys) { Remove-Item -Path "Env:$k" -ErrorAction SilentlyContinue }

# Memória a cada segundo (PA-001 em docs/STATUS.md): privada e working set do processo principal.
$memFile = Join-Path $RunDir 'memory.csv'
[IO.File]::WriteAllText($memFile, "t_sec,private_mb,working_set_mb`n")
$memSamples = 0
$peakPrivate = 0.0; $peakWorkingSet = 0.0
$exited = $false
$deadline = $TimeoutSec * 1000
while (-not $exited -and $timer.ElapsedMilliseconds -lt $deadline) {
    try {
        $proc.Refresh()
        $private = [math]::Round($proc.PrivateMemorySize64 / 1MB, 1)
        $working = [math]::Round($proc.WorkingSet64 / 1MB, 1)
        $peakPrivate = [math]::Max($peakPrivate, $private)
        $peakWorkingSet = [math]::Max($peakWorkingSet, $working)
        # Uma linha por amostra, já no arquivo: uma sessão longa interrompida não perde a curva.
        [IO.File]::AppendAllText($memFile, [string]::Format([cultureinfo]::InvariantCulture, "{0},{1},{2}`n",
                [math]::Round($timer.Elapsed.TotalSeconds, 1), $private, $working))
        $memSamples++
    } catch { }
    $wait = [math]::Min(1000, [math]::Max(1, $deadline - $timer.ElapsedMilliseconds))
    $exited = $proc.WaitForExit([int]$wait)
}
$run.memory = [ordered]@{ peak_private_mb = $peakPrivate; peak_working_set_mb = $peakWorkingSet;
    samples = $memSamples; file = 'memory.csv'; scope = 'processo principal' }

if ($exited) {
    $proc.WaitForExit()
    $run.result = if ($proc.ExitCode -eq 0) { 'exited' } else { 'crashed_or_error' }
    $run.exit_code = $proc.ExitCode
} else {
    # Encerra o processo e os filhos (o KytyPS5 pode relançar a si mesmo via LoadExec).
    & taskkill.exe /PID $proc.Id /T /F 2>&1 | Out-Null
    $proc.WaitForExit(10000) | Out-Null
    $run.result = 'timeout'
}
$timer.Stop()
# Logs do próprio jogo (/hostapp/logs, montado em _HostAppLogs pelo engine desport): vão para a
# pasta da execução, para não se acumularem em user/.
$gameLogs = Join-Path $WorkDir '_HostAppLogs'
if (Test-Path $gameLogs) {
    $dest = Join-Path $RunDir 'game_logs'
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    Get-ChildItem $gameLogs -File | Move-Item -Destination $dest -Force
}
$run.ended = (Get-Date).ToString('o')
$run.duration_sec = [math]::Round($timer.Elapsed.TotalSeconds, 1)
Save-Run

Write-Host ''
Write-Host "Resultado: $($run.result)  código: $($run.exit_code)  duração: $($run.duration_sec) s"
Write-Host "Memória: pico privada $($run.memory.peak_private_mb) MB, pico working set $($run.memory.peak_working_set_mb) MB"
Write-Host "Pasta: $RunDir"
if ($Quiet -and -not (Test-Path -LiteralPath $logFile)) { New-Item -ItemType File -Path $logFile | Out-Null }
if (-not (Test-Path -LiteralPath $logFile)) {
    Write-Host 'log.txt não foi criado; veja stdout.txt e stderr.txt.' -ForegroundColor Yellow
    exit 1
}
# Triagem automática (tools/log_triage.py); com cenário, o veredito vai para run.json.
$triageArgs = @('-I', (Join-Path $Root 'tools/log_triage.py'), $RunDir)
if ($Scenario) { $triageArgs += @('--scenario', $Scenario) }
Write-Host ''
& python @triageArgs
$triageCode = $LASTEXITCODE
if ($Scenario) {
    $run.scenario_result = if ($triageCode -eq 0) { 'pass' } elseif ($triageCode -eq 2) { 'fail' } else { 'error' }
    Save-Run
    Write-Host "Cenário $Scenario`: $($run.scenario_result)"
    if ($triageCode -ne 0) { exit 2 }
}
