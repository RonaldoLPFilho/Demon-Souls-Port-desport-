# SPDX-License-Identifier: GPL-2.0-only
<#
.SYNOPSIS
    Launcher do desport: uma janela com todas as opções do Demon's Souls no PC e o botão Jogar.

.DESCRIPTION
    Janela WinForms (português do Brasil) na frente de tools/run.ps1, no estilo do launcher do
    bbport. Opções: pasta do jogo (confere eboot.bin e sce_sys\param.json: PPSA01341, versão
    01.007.000; avisa se for outra), resolução de saída (inclui 3440x1440 ultrawide), proporção (ultrawide
    nativo, 16:9 com barras pretas ou esticar), tela cheia, idioma do console, fps (60 ou até 120), resolução de render,
    DLSS (modo e preset; padrão DLSS 4.5), geração de quadros (2x/3x/4x) e os botões Jogar,
    Parar, Pré-compilar shaders, Abrir pasta de logs e Restaurar padrões.

    As escolhas ficam em user/launcher-settings.json (fora do git). Ao jogar, o launcher parte de
    game/config/fg-launch.json (environment e flags da configuração testada), aplica as escolhas
    num JSON temporário de lançamento (mesmo formato) e chama, sem bloquear a janela:
        tools/run.ps1 -Launch <temp> -TimeoutSec 86400 -Label play -GameDir <pasta> [-Quiet]
    A janela mostra "rodando" e "fechou com código X". Cada execução fica em captures/runs/.

    Variáveis aplicadas: KYTY_DLSS e KYTY_DLSS_PRESET (só com DLSS ligado e preset não padrão),
    KYTY_FRAMEGEN=<quadros gerados por quadro renderizado: 2x=1, 3x=2, 4x=3>, KYTY_RENDER_HEIGHT,
    KYTY_PRESENT_ASPECT=fit (16:9 com barras), o patch de memória do ultrawide (--game-patch, só 01.007.000:
    a proporção da resolução escolhida no setup de render, imagem esticada na janela), --vblank-frequency 120 (fps até 120), --fullscreen,
    --screen-width/--screen-height e --console-language.

    -DryRun não cria janela nenhuma: imprime o JSON de lançamento montado e a linha de comando.

    Baseado no launcher do KytyPS5-DemonsSouls-FrameGen v1.3 (ceremony88, launcher.ps1 e
    run-windows.ps1) e no launcher do KytyPS5 (lista de idiomas do console), GPL-2.0. O desenho de
    funções segue o README do bbport (somente como referência de produto; nenhum código copiado).

.EXAMPLE
    tools/launcher.ps1                      # abre a janela (ou dê duplo clique em tools/launcher.cmd)
    tools/launcher.ps1 -DryRun              # só imprime o JSON e a linha de comando
    tools/launcher.ps1 -DryRun -Settings user/launcher-settings.json
#>
[CmdletBinding()]
param(
    # Não abre janela: imprime o JSON de lançamento e a linha de comando e sai.
    [switch]$DryRun,
    # Arquivo de escolhas (padrão user/launcher-settings.json).
    [string]$Settings = '',
    # Configuração base de lançamento (padrão game/config/fg-launch.json).
    [string]$BaseLaunch = '',
    # Script de pré-compilação dos shaders (padrão build/fg/precompile-windows.ps1).
    [string]$PrecompileScript = ''
)

Set-Strictmode -Version 2.0
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
if (-not $Settings) { $Settings = Join-Path $Root 'user\launcher-settings.json' }
elseif (-not [System.IO.Path]::IsPathRooted($Settings)) { $Settings = Join-Path $Root $Settings }
if (-not $BaseLaunch) { $BaseLaunch = Join-Path $Root 'game\config\fg-launch.json' }
elseif (-not [System.IO.Path]::IsPathRooted($BaseLaunch)) { $BaseLaunch = Join-Path $Root $BaseLaunch }
if (-not $PrecompileScript) { $PrecompileScript = Join-Path $Root 'build\fg\precompile-windows.ps1' }
$RunScript = Join-Path $Root 'tools\run.ps1'
$TestedTitle = 'PPSA01341'
$TestedVersion = '01.007.000'

# ---------------------------------------------------------------- opções (valor interno, texto)

# Idiomas do console, numerados como o PS5 (nomes do launcher do KytyPS5).
$Languages = 'Japanese', 'English (United States)', 'French (France)', 'Spanish (Spain)', 'German', 'Italian', 'Dutch',
    'Portuguese (Portugal)', 'Russian', 'Korean', 'Chinese (Traditional)', 'Chinese (Simplified)', 'Finnish', 'Swedish',
    'Danish', 'Norwegian', 'Polish', 'Portuguese (Brazil)', 'English (United Kingdom)', 'Turkish', 'Spanish (Latin America)',
    'Arabic', 'French (Canada)', 'Czech', 'Hungarian', 'Greek', 'Romanian', 'Thai', 'Vietnamese', 'Indonesian'

$Resolutions = @(
    @('1280x720', '1280 x 720 (HD)'),
    @('1920x1080', '1920 x 1080 (Full HD)'),
    @('2560x1440', '2560 x 1440 (QHD)'),
    @('3440x1440', '3440 x 1440 (ultrawide 21:9)'),
    @('3840x2160', '3840 x 2160 (4K)'))
$RenderHeights = @(
    @(0, 'Padrão do jogo (1440p)'), @(720, '720p'), @(900, '900p'), @(1080, '1080p'), @(2160, '2160p (4K)'))
$AspectModes = @(
    @('auto', 'Automática (ultrawide se a tela não for 16:9)'),
    @('ultrawide', 'Ultrawide nativo (campo de visão mais largo)'),
    @('fit', '16:9 com barras pretas'),
    @('stretch', 'Esticar a imagem 16:9'))
$FpsModes = @(@(60, '60 fps (como no console)'), @(120, 'Até 120 fps'))
$FrameGenModes = @(@(0, 'Desligada'), @(1, '2x (1 quadro gerado)'), @(2, '3x (2 quadros gerados)'), @(3, '4x (3 quadros gerados)'))
$DlssModes = @(
    @('off', 'Desligado'), @('dlaa', 'DLAA (qualidade nativa)'), @('quality', 'Qualidade'), @('balanced', 'Equilibrado'),
    @('performance', 'Desempenho'), @('ultra_performance', 'Desempenho máximo'))
$DlssPresets = @(
    @('default', 'Padrão (DLSS 4.5)'), @('J', 'J'), @('K', 'K'), @('L', 'L'), @('M', 'M'))

function Get-Defaults {
    [ordered]@{
        game = ''; resolution = '2560x1440'; fullscreen = $false; aspect = 'auto'; language = 17
        fps = 60; renderHeight = 0; dlss = 'off'; dlssPreset = 'default'; frameGen = 0; fullLog = $false
    }
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

function Load-Settings {
    $s = Get-Defaults
    $ini = Read-LocalIni (Join-Path $Root 'desport.local.ini')
    if ($ini.ContainsKey('DES_GAME_DIR')) { $s.game = $ini['DES_GAME_DIR'] }
    if (Test-Path -LiteralPath $Settings) {
        try {
            $saved = Get-Content -LiteralPath $Settings -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($p in $saved.PSObject.Properties) { if ($s.Contains($p.Name) -and $null -ne $p.Value) { $s[$p.Name] = $p.Value } }
        } catch { Write-Warning "launcher-settings.json inválido, usando os padrões: $($_.Exception.Message)" }
    }
    return $s
}

function Save-Settings($s) {
    $dir = Split-Path -Parent $Settings
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
    $s | ConvertTo-Json | Set-Content -LiteralPath $Settings -Encoding UTF8
}

# ---------------------------------------------------------------- jogo

# Confere a pasta do jogo: devolve ok (pode jogar), nivel (ok/aviso/erro) e a mensagem.
function Test-GameFolder([string]$Path) {
    if (-not $Path) { return [pscustomobject]@{ ok = $false; nivel = 'erro'; msg = 'Escolha a pasta do jogo (a que tem o eboot.bin).' } }
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        return [pscustomobject]@{ ok = $false; nivel = 'erro'; msg = 'Pasta não encontrada.' }
    }
    if (-not (Test-Path -LiteralPath (Join-Path $Path 'eboot.bin'))) {
        return [pscustomobject]@{ ok = $false; nivel = 'erro'; msg = 'Não há eboot.bin nessa pasta (o dump precisa estar descriptografado).' }
    }
    $paramPath = Join-Path $Path 'sce_sys\param.json'
    if (-not (Test-Path -LiteralPath $paramPath)) {
        return [pscustomobject]@{ ok = $true; nivel = 'aviso'; msg = 'Falta sce_sys\param.json: não consigo confirmar a versão do jogo.' }
    }
    try { $param = Get-Content -LiteralPath $paramPath -Raw -Encoding UTF8 | ConvertFrom-Json }
    catch { return [pscustomobject]@{ ok = $true; nivel = 'aviso'; msg = 'param.json ilegível: não consigo confirmar a versão do jogo.' } }
    $title = if ($param.PSObject.Properties['titleId']) { [string]$param.titleId } else { '' }
    $version = if ($param.PSObject.Properties['contentVersion']) { [string]$param.contentVersion } else { '' }
    if ($title -ne $TestedTitle) {
        return [pscustomobject]@{ ok = $true; nivel = 'aviso'; msg = "Título ${title}: o launcher é para ${TestedTitle} (Demon's Souls, Europa). Pode não funcionar." }
    }
    if ($version -ne $TestedVersion) {
        return [pscustomobject]@{ ok = $true; nivel = 'aviso'; msg = "Versão ${version}: só a ${TestedVersion} foi testada. Pode ter travamentos ou erros gráficos." }
    }
    return [pscustomobject]@{ ok = $true; nivel = 'ok'; msg = "Demon's Souls $title, versão $version (testada)." }
}

# desport: ultrawide (patch de memória do ceremony88, eboot.bin 01.007.000): a constante 16/9 do setup de render
# ("mov dword [rbx+4], 16/9", file offset 0x90ae7f) vira largura/altura da resolução escolhida, qualquer proporção. Os
# buffers continuam 16:9 (3840x2160 de saída, render 16:9): o campo de visão fica mais largo, desenhado de forma
# anamórfica, e a janela estica a imagem de volta. HUD, menus e vídeos ficam esticados na horizontal.
$UltrawideOffset = '90ae7f'
$UltrawideOff    = 'c74304398ee33f' # c7 43 04 + 16/9 como float32

function Get-GameVersion([string]$Path) {
    $paramPath = Join-Path $Path 'sce_sys\param.json'
    if (-not $Path -or -not (Test-Path -LiteralPath $paramPath)) { return '' }
    try {
        $param = Get-Content -LiteralPath $paramPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($param.PSObject.Properties['contentVersion']) { return [string]$param.contentVersion }
    } catch {}
    return ''
}

# Como a imagem é mostrada: modo efetivo (ultrawide / fit / stretch), proporção da resolução e uma nota.
function Get-AspectPlan($s) {
    $parts = ([string]$s.resolution).Trim().ToLower() -split 'x'
    $ratio = if ($parts.Count -eq 2 -and [double]$parts[1] -gt 0) { [double]$parts[0] / [double]$parts[1] } else { 16.0 / 9.0 }
    $is169 = [math]::Abs($ratio - 16.0 / 9.0) -lt 0.02
    $wide = $ratio -ge 1.9
    $mode = [string]$s.aspect
    $note = ''
    if ($mode -eq 'auto') { $mode = if ($is169) { 'stretch' } elseif ($wide) { 'ultrawide' } else { 'fit' } }
    if ($mode -eq 'ultrawide') {
        $version = Get-GameVersion ([string]$s.game)
        if (-not $wide) { $mode = 'fit'; $note = 'Ultrawide pede uma resolução mais larga que 16:9: usando 16:9 com barras.' }
        elseif ($version -and $version -ne $TestedVersion) { $mode = 'fit'; $note = "Ultrawide só existe para a versão ${TestedVersion} (esta é a ${version}): usando 16:9 com barras." }
    }
    return [pscustomobject]@{ mode = $mode; ratio = $ratio; note = $note }
}

# O patch de memória do ultrawide (formato GoldHEN, o que o --game-patch lê).
function New-UltrawidePatch([double]$Ratio) {
    $bytes = [BitConverter]::GetBytes([single]$Ratio)
    $on = 'c74304' + ([BitConverter]::ToString($bytes).Replace('-', '').ToLower())
    return [ordered]@{
        id = $TestedTitle; version = $TestedVersion; process = 'eboot.bin'
        mods = @([ordered]@{
            name = ('ultrawide: aspect ratio ' + $Ratio.ToString('0.0000', [cultureinfo]::InvariantCulture) + ' in the render setup (was 16:9)'); enabled = $true
            memory = @([ordered]@{ offset = $UltrawideOffset; off = $UltrawideOff; on = $on }) })
    }
}

# ---------------------------------------------------------------- JSON de lançamento

# Parte de game/config/fg-launch.json e aplica as escolhas (mesmo formato do arquivo base).
function Build-Launch($s, [string]$PatchPath = '') {
    $base = Get-Content -LiteralPath $BaseLaunch -Raw -Encoding UTF8 | ConvertFrom-Json
    $envVars = [ordered]@{}
    foreach ($p in $base.environment.PSObject.Properties) { $envVars[$p.Name] = [string]$p.Value }
    $flags = New-Object System.Collections.Generic.List[string]
    foreach ($f in @($base.flags)) { $flags.Add([string]$f) }
    function Set-Flag([string]$name, [string]$value) {
        $at = $flags.IndexOf($name)
        if ($at -ge 0) { $flags[$at + 1] = $value } else { $flags.Add($name); $flags.Add($value) }
    }

    # Imagem
    $res = ([string]$s.resolution).Trim().ToLower()
    if ($res -notmatch '^(\d{3,5})x(\d{3,5})$') { throw "resolução inválida: '$($s.resolution)' (use LARGURAxALTURA)" }
    Set-Flag '--screen-width' $Matches[1]
    Set-Flag '--screen-height' $Matches[2]
    if ($s.fullscreen -and -not $flags.Contains('--fullscreen')) { $flags.Add('--fullscreen') }
    if (-not $s.fullscreen) { while ($flags.Remove('--fullscreen')) {} }
    # desport: proporção. fit: barras pretas; ultrawide: patch de memória + imagem esticada na janela; stretch: nada.
    $plan = Get-AspectPlan $s
    $script:aspectNote = $plan.note
    $script:ultrawidePatch = $null
    if ($plan.mode -eq 'fit') { $envVars['KYTY_PRESENT_ASPECT'] = 'fit' } else { $envVars.Remove('KYTY_PRESENT_ASPECT') }
    if ($plan.mode -eq 'ultrawide' -and $PatchPath) {
        $script:ultrawidePatch = New-UltrawidePatch $plan.ratio
        Set-Flag '--game-patch' $PatchPath
    }
    $rh = [int]$s.renderHeight
    if ($rh -gt 0 -and $rh -ne 1440) { $envVars['KYTY_RENDER_HEIGHT'] = "$rh" } else { $envVars.Remove('KYTY_RENDER_HEIGHT') }

    # Idioma e fps
    Set-Flag '--console-language' "$([int]$s.language)"
    Set-Flag '--vblank-frequency' "$(if ([int]$s.fps -ge 120) { 120 } else { 60 })"

    # DLSS (KYTY_DLSS/KYTY_DLSS_PRESET) e geração de quadros (KYTY_FRAMEGEN)
    if ($s.dlss -and $s.dlss -ne 'off') {
        $envVars['KYTY_DLSS'] = [string]$s.dlss
        if ($s.dlssPreset -and $s.dlssPreset -ne 'default') { $envVars['KYTY_DLSS_PRESET'] = [string]$s.dlssPreset } else { $envVars.Remove('KYTY_DLSS_PRESET') }
    } else { $envVars.Remove('KYTY_DLSS'); $envVars.Remove('KYTY_DLSS_PRESET') }
    if ([int]$s.frameGen -gt 0) { $envVars['KYTY_FRAMEGEN'] = "$([int]$s.frameGen)" } else { $envVars.Remove('KYTY_FRAMEGEN') }

    $out = [ordered]@{ _source = 'tools/launcher.ps1 sobre game/config/fg-launch.json' }
    foreach ($name in 'kyty_exe', 'work_dir') { if ($base.PSObject.Properties[$name]) { $out[$name] = $base.$name } }
    $out['environment'] = $envVars
    $out['flags'] = @($flags)
    return $out
}

function Quote-Arg([string]$a) { if ($a -match '[\s"]') { '"' + ($a -replace '"', '\"') + '"' } else { $a } }

# Argumentos do powershell que executa tools/run.ps1.
function Get-RunArguments([string]$LaunchFile, $s) {
    $a = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Quote-Arg $RunScript),
        '-Launch', (Quote-Arg $LaunchFile), '-TimeoutSec', '86400', '-Label', 'play', '-GameDir', (Quote-Arg ([string]$s.game)))
    if (-not $s.fullLog) { $a += '-Quiet' }   # log do engine em Silent (o completo cresce ~80 MB/min)
    return ($a -join ' ')
}

# ---------------------------------------------------------------- -DryRun (sem janela)

if ($DryRun) {
    $s = Load-Settings
    $check = Test-GameFolder ([string]$s.game)
    Write-Host "# pasta do jogo: [$($check.nivel)] $($check.msg)"
    $patchTmp = Join-Path ([System.IO.Path]::GetTempPath()) 'desport-ultrawide-<id>.json'
    $json = (Build-Launch $s $patchTmp) | ConvertTo-Json -Depth 6
    Write-Host "# proporção: $((Get-AspectPlan $s).mode)$(if ($script:aspectNote) { ' - ' + $script:aspectNote })"
    Write-Host '# JSON de lançamento:'
    Write-Output $json
    if ($script:ultrawidePatch) {
        Write-Host "# patch do ultrawide ($patchTmp):"
        Write-Output ($script:ultrawidePatch | ConvertTo-Json -Depth 8)
    }
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) 'desport-launch-<id>.json'
    Write-Host '# linha de comando:'
    Write-Host ("powershell.exe " + (Get-RunArguments $tmp $s))
    return
}

# ---------------------------------------------------------------- janela

Add-Type -AssemblyName System.Windows.Forms, System.Drawing
Add-Type -Namespace DesLauncher -Name Dpi -MemberDefinition '[DllImport("user32.dll")] public static extern bool SetProcessDPIAware();'
[void][DesLauncher.Dpi]::SetProcessDPIAware()
[System.Windows.Forms.Application]::EnableVisualStyles()

$script:s = Load-Settings
$script:proc = $null
$script:tmpLaunch = $null
$script:tmpPatch = $null
$script:aspectNote = ''
$script:ultrawidePatch = $null
$script:ui = @{}
$script:loading = $true
$script:gameOk = $false

function New-Label([string]$text, [int]$x, [int]$y, [int]$w = 150) {
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $text; $l.Location = New-Object System.Drawing.Point($x, $y); $l.Size = New-Object System.Drawing.Size($w, 22)
    $l.TextAlign = 'MiddleLeft'
    return $l
}
function New-Combo([int]$x, [int]$y, [int]$w, $pairs, [string]$style = 'DropDownList') {
    $c = New-Object System.Windows.Forms.ComboBox
    $c.Location = New-Object System.Drawing.Point($x, $y); $c.Size = New-Object System.Drawing.Size($w, 24)
    $c.DropDownStyle = $style
    foreach ($p in $pairs) { [void]$c.Items.Add($p[1]) }
    return $c
}
function Select-Pair($combo, $pairs, $value) {
    for ($i = 0; $i -lt $pairs.Count; $i++) { if ("$($pairs[$i][0])" -eq "$value") { $combo.SelectedIndex = $i; return } }
    $combo.SelectedIndex = 0
}
function Get-Pair($combo, $pairs) {
    if ($combo.SelectedIndex -lt 0) { return $pairs[0][0] }
    return $pairs[$combo.SelectedIndex][0]
}
function New-Button([string]$text, [int]$x, [int]$y, [int]$w, [int]$h = 30) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $text; $b.Location = New-Object System.Drawing.Point($x, $y); $b.Size = New-Object System.Drawing.Size($w, $h)
    return $b
}

# Lê os controles para $script:s.
function Read-Controls {
    $u = $script:ui
    $s = $script:s
    $s.game = $u.game.Text.Trim()
    $text = $u.res.Text.Trim()
    $found = $null
    foreach ($r in $Resolutions) { if ($r[1] -eq $text) { $found = $r[0] } }
    $s.resolution = if ($found) { $found } else { $text }
    $s.fullscreen = $u.full.Checked
    $s.aspect = Get-Pair $u.aspect $AspectModes
    $s.language = [math]::Max($u.lang.SelectedIndex, 0)
    $s.fps = Get-Pair $u.fps $FpsModes
    $s.renderHeight = Get-Pair $u.render $RenderHeights
    $s.dlss = Get-Pair $u.dlss $DlssModes
    $s.dlssPreset = Get-Pair $u.preset $DlssPresets
    $s.frameGen = Get-Pair $u.fg $FrameGenModes
    $s.fullLog = $u.log.Checked
}

# Escreve $script:s nos controles.
function Write-Controls {
    $u = $script:ui
    $s = $script:s
    $script:loading = $true
    $u.game.Text = [string]$s.game
    $shown = $null
    foreach ($r in $Resolutions) { if ($r[0] -eq $s.resolution) { $shown = $r[1] } }
    $u.res.Text = if ($shown) { $shown } else { [string]$s.resolution }
    $u.full.Checked = [bool]$s.fullscreen
    Select-Pair $u.aspect $AspectModes $s.aspect
    $u.lang.SelectedIndex = [math]::Min([math]::Max([int]$s.language, 0), $Languages.Count - 1)
    Select-Pair $u.fps $FpsModes $s.fps
    Select-Pair $u.render $RenderHeights $s.renderHeight
    Select-Pair $u.dlss $DlssModes $s.dlss
    Select-Pair $u.preset $DlssPresets $s.dlssPreset
    Select-Pair $u.fg $FrameGenModes $s.frameGen
    $u.log.Checked = [bool]$s.fullLog
    $script:loading = $false
    Update-GameStatus
    Update-Enabled
}

function Update-GameStatus {
    $u = $script:ui
    $check = Test-GameFolder $u.game.Text.Trim()
    $u.gameStatus.Text = $check.msg
    $u.gameStatus.ForeColor = switch ($check.nivel) {
        'ok' { [System.Drawing.Color]::FromArgb(0, 120, 40) }
        'aviso' { [System.Drawing.Color]::FromArgb(190, 110, 0) }
        default { [System.Drawing.Color]::FromArgb(190, 30, 30) }
    }
    $script:gameOk = $check.ok
    Update-Enabled
}

function Update-Enabled {
    $u = $script:ui
    $running = ($null -ne $script:proc -and -not $script:proc.HasExited)
    $u.play.Enabled = ($script:gameOk -and -not $running)
    $u.stop.Enabled = $running
    $u.precompile.Enabled = ($script:gameOk -and -not $running)
    $u.preset.Enabled = ((Get-Pair $u.dlss $DlssModes) -ne 'off')
    foreach ($name in 'game', 'browse', 'res', 'full', 'aspect', 'lang', 'fps', 'render', 'dlss', 'fg', 'log', 'reset') { $u[$name].Enabled = -not $running }
}

function Set-Status([string]$text, $color = $null) {
    $script:ui.status.Text = $text
    $script:ui.status.ForeColor = if ($color) { $color } else { [System.Drawing.SystemColors]::ControlText }
}

function Start-Game {
    Read-Controls
    try {
        if (Get-Process -Name 'kyty_emulator' -ErrorAction SilentlyContinue) {
            [void][System.Windows.Forms.MessageBox]::Show('Já há um kyty_emulator rodando. Feche-o antes de jogar.', 'Demon''s Souls', 'OK', 'Warning')
            return
        }
        $id = [guid]::NewGuid().ToString('N')
        $script:tmpPatch = Join-Path ([System.IO.Path]::GetTempPath()) ("desport-ultrawide-{0}.json" -f $id) # desport: ultrawide
        $launch = Build-Launch $script:s $script:tmpPatch
        if ($script:ultrawidePatch) {
            ($script:ultrawidePatch | ConvertTo-Json -Depth 8) | Set-Content -LiteralPath $script:tmpPatch -Encoding UTF8
        }
        $script:tmpLaunch = Join-Path ([System.IO.Path]::GetTempPath()) ("desport-launch-{0}.json" -f $id)
        ($launch | ConvertTo-Json -Depth 6) | Set-Content -LiteralPath $script:tmpLaunch -Encoding UTF8
        Save-Settings $script:s
        $runArgs = Get-RunArguments $script:tmpLaunch $script:s
        $script:proc = Start-Process -FilePath 'powershell.exe' -ArgumentList $runArgs -WindowStyle Hidden -PassThru
        Set-Status ('Rodando... (feche o jogo para voltar; as execuções ficam em captures\runs)' + $(if ($script:aspectNote) { "`n" + $script:aspectNote } else { '' })) ([System.Drawing.Color]::FromArgb(0, 90, 160))
        $script:ui.timer.Start()
    } catch {
        Set-Status "Erro ao iniciar: $($_.Exception.Message)" ([System.Drawing.Color]::FromArgb(190, 30, 30))
    }
    Update-Enabled
}

function Stop-Game {
    if ($null -eq $script:proc -or $script:proc.HasExited) { return }
    # Encerra o run.ps1 e toda a árvore de processos (o emulador é filho dele).
    & taskkill.exe /PID $script:proc.Id /T /F *> $null
    Set-Status 'Encerrando o jogo...'
}

function Open-Logs {
    $runs = Join-Path $Root 'captures\runs'
    if (-not (Test-Path -LiteralPath $runs)) { New-Item -ItemType Directory -Path $runs | Out-Null }
    $last = Get-ChildItem -LiteralPath $runs -Directory -Filter '*-play' -ErrorAction SilentlyContinue |
        Sort-Object CreationTime | Select-Object -Last 1
    Start-Process explorer.exe -ArgumentList (Quote-Arg $(if ($last) { $last.FullName } else { $runs }))
}

function Start-Precompile {
    Read-Controls
    if (-not (Test-Path -LiteralPath $PrecompileScript)) {
        [void][System.Windows.Forms.MessageBox]::Show("Script de pré-compilação não encontrado:`n$PrecompileScript", 'Demon''s Souls', 'OK', 'Error')
        return
    }
    $answer = [System.Windows.Forms.MessageBox]::Show(
        "Pré-compilar os shaders leva cerca de 1 hora e usa bastante CPU. Depois disso o jogo não trava ao compilar shaders novos.`n`nO computador fica lento enquanto isso. Continuar?",
        'Pré-compilar shaders', 'YesNo', 'Question')
    if ($answer -ne 'Yes') { return }
    $argText = '-NoProfile -ExecutionPolicy Bypass -File {0} -Game {1}' -f (Quote-Arg $PrecompileScript), (Quote-Arg ([string]$script:s.game))
    Start-Process -FilePath 'powershell.exe' -ArgumentList $argText -WorkingDirectory (Split-Path -Parent $PrecompileScript)
    Set-Status 'Pré-compilação iniciada em outra janela (leva cerca de 1 hora).'
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "Demon's Souls para PC - launcher do desport"
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.ClientSize = New-Object System.Drawing.Size(600, 600)
$form.Font = New-Object System.Drawing.Font('Segoe UI', 9)
$u = $script:ui

# Jogo
$g1 = New-Object System.Windows.Forms.GroupBox
$g1.Text = 'Jogo'; $g1.Location = New-Object System.Drawing.Point(12, 8); $g1.Size = New-Object System.Drawing.Size(576, 86)
$u.game = New-Object System.Windows.Forms.TextBox
$u.game.Location = New-Object System.Drawing.Point(12, 24); $u.game.Size = New-Object System.Drawing.Size(458, 24)
$u.browse = New-Button 'Procurar...' 478 22 86 28
$u.gameStatus = New-Label '' 12 54 552
$g1.Controls.AddRange(@($u.game, $u.browse, $u.gameStatus))

# Imagem
$g2 = New-Object System.Windows.Forms.GroupBox
$g2.Text = 'Imagem'; $g2.Location = New-Object System.Drawing.Point(12, 100); $g2.Size = New-Object System.Drawing.Size(576, 150)
$u.res = New-Combo 190 22 250 ($Resolutions) 'DropDown'
$u.full = New-Object System.Windows.Forms.CheckBox
$u.full.Text = 'Tela cheia'; $u.full.Location = New-Object System.Drawing.Point(456, 22); $u.full.Size = New-Object System.Drawing.Size(110, 24)
$u.aspect = New-Combo 190 52 376 $AspectModes
$u.render = New-Combo 190 82 250 $RenderHeights
$u.lang = New-Object System.Windows.Forms.ComboBox
$u.lang.Location = New-Object System.Drawing.Point(190, 112); $u.lang.Size = New-Object System.Drawing.Size(250, 24); $u.lang.DropDownStyle = 'DropDownList'
foreach ($n in $Languages) { [void]$u.lang.Items.Add($n) }
$g2.Controls.AddRange(@(
    (New-Label 'Resolução de saída (janela)' 12 22 175), $u.res, $u.full,
    (New-Label 'Proporção da imagem' 12 52 175), $u.aspect,
    (New-Label 'Resolução de render do 3D' 12 82 175), $u.render,
    (New-Label 'Idioma do console' 12 112 175), $u.lang))

# Desempenho
$g3 = New-Object System.Windows.Forms.GroupBox
$g3.Text = 'Desempenho e DLSS (placa NVIDIA RTX)'; $g3.Location = New-Object System.Drawing.Point(12, 256); $g3.Size = New-Object System.Drawing.Size(576, 180)
$u.fps = New-Combo 190 22 250 $FpsModes
$u.dlss = New-Combo 190 52 250 $DlssModes
$u.preset = New-Combo 190 82 250 $DlssPresets
$u.fg = New-Combo 190 112 250 $FrameGenModes
$u.log = New-Object System.Windows.Forms.CheckBox
$u.log.Text = 'Gravar o log completo do engine (diagnóstico; cresce ~80 MB por minuto)'
$u.log.Location = New-Object System.Drawing.Point(12, 146); $u.log.Size = New-Object System.Drawing.Size(552, 24)
$g3.Controls.AddRange(@(
    (New-Label 'Taxa de quadros do jogo' 12 22 175), $u.fps,
    (New-Label 'DLSS (super-resolução)' 12 52 175), $u.dlss,
    (New-Label 'Preset do DLSS' 12 82 175), $u.preset,
    (New-Label 'Geração de quadros (DLSS-G)' 12 112 175), $u.fg, $u.log))

# Botões
$u.play = New-Button 'JOGAR' 12 446 270 44
$u.play.Font = New-Object System.Drawing.Font('Segoe UI', 12, [System.Drawing.FontStyle]::Bold)
$u.stop = New-Button 'Parar o jogo' 290 446 120 44
$u.precompile = New-Button 'Pré-compilar shaders' 12 498 190
$u.logs = New-Button 'Abrir pasta de logs' 210 498 190
$u.reset = New-Button 'Restaurar padrões' 408 498 180
$u.status = New-Label 'Pronto.' 12 540 576
$u.status.Size = New-Object System.Drawing.Size(576, 48)
$u.status.TextAlign = 'TopLeft'
$form.Controls.AddRange(@($g1, $g2, $g3, $u.play, $u.stop, $u.precompile, $u.logs, $u.reset, $u.status))

# Dicas
$tip = New-Object System.Windows.Forms.ToolTip
$tip.SetToolTip($u.render, 'Altura em que o jogo desenha o 3D (padrão 1440p). Menos pixels = mais fps; a imagem é escalada para a janela.')
$tip.SetToolTip($u.fps, 'Até 120 fps usa um vblank de 120 Hz; vídeos e cenas avançam um quadro por flip e podem rodar mais rápido.')
$tip.SetToolTip($u.dlss, 'Super-resolução da NVIDIA no lugar do TAA do jogo (RTX 20 ou mais nova).')
$tip.SetToolTip($u.preset, 'Padrão deixa o engine escolher (DLSS 4.5). J e K são os modelos antigos; L e M, os do DLSS 4.5.')
$tip.SetToolTip($u.fg, 'Geração de quadros da NVIDIA (DLSS-G): RTX 40 ou mais nova para 2x; 3x e 4x pedem RTX 50.')
$tip.SetToolTip($u.aspect, 'Ultrawide nativo: campo de visão mais largo na proporção da resolução (só versão 01.007.000); HUD, menus e vídeos ficam esticados na horizontal. 16:9 com barras: sem distorção. Automática: ultrawide quando a resolução é mais larga que 16:9.')

# Eventos
$u.browse.Add_Click({
    $d = New-Object System.Windows.Forms.FolderBrowserDialog
    $d.Description = 'Pasta do jogo (a que tem eboot.bin e sce_sys)'
    if ($u.game.Text -and (Test-Path -LiteralPath $u.game.Text)) { $d.SelectedPath = $u.game.Text }
    if ($d.ShowDialog() -eq 'OK') { $u.game.Text = $d.SelectedPath }
})
$u.game.Add_TextChanged({ if (-not $script:loading) { Update-GameStatus } })
$u.dlss.Add_SelectedIndexChanged({ if (-not $script:loading) { Update-Enabled } })
$u.play.Add_Click({ Start-Game })
$u.stop.Add_Click({ Stop-Game })
$u.precompile.Add_Click({ Start-Precompile })
$u.logs.Add_Click({ Open-Logs })
$u.reset.Add_Click({
    $game = $u.game.Text
    $script:s = Get-Defaults
    $script:s.game = $game   # a pasta do jogo não é uma preferência a restaurar
    Write-Controls
    Set-Status 'Padrões restaurados (a pasta do jogo foi mantida).'
})

$u.timer = New-Object System.Windows.Forms.Timer
$u.timer.Interval = 1000
$u.timer.Add_Tick({
    if ($null -ne $script:proc -and $script:proc.HasExited) {
        $u.timer.Stop()
        $code = $script:proc.ExitCode
        if ($code -eq 0) { Set-Status 'O jogo fechou com código 0.' }
        else { Set-Status "O jogo fechou com código $code. Veja o log (Abrir pasta de logs)." ([System.Drawing.Color]::FromArgb(190, 30, 30)) }
        if ($script:tmpLaunch -and (Test-Path -LiteralPath $script:tmpLaunch)) { Remove-Item -LiteralPath $script:tmpLaunch -Force -ErrorAction SilentlyContinue }
        if ($script:tmpPatch -and (Test-Path -LiteralPath $script:tmpPatch)) { Remove-Item -LiteralPath $script:tmpPatch -Force -ErrorAction SilentlyContinue } # desport: ultrawide
        $script:proc = $null
        Update-Enabled
    }
})

$form.Add_FormClosing({
    param($sender, $e)
    if ($null -ne $script:proc -and -not $script:proc.HasExited) {
        $answer = [System.Windows.Forms.MessageBox]::Show('O jogo ainda está rodando. Fechar o launcher não o encerra. Fechar mesmo assim?',
            'Demon''s Souls', 'YesNo', 'Question')
        if ($answer -ne 'Yes') { $e.Cancel = $true; return }
    }
    try { Read-Controls; Save-Settings $script:s } catch {}
})

Write-Controls
[void]$form.ShowDialog()
