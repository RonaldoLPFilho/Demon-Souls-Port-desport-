# SPDX-License-Identifier: GPL-2.0-only
<#
.SYNOPSIS
    Launcher do desport: uma janela com todas as opções do Demon's Souls no PC e o botão Jogar.

.DESCRIPTION
    Janela WinForms (português do Brasil) na frente de tools/run.ps1, no estilo do launcher do
    bbport. Opções: pasta do jogo (confere eboot.bin e sce_sys\param.json: PPSA01341, versão
    01.007.000; avisa se for outra), resolução de saída (inclui 3440x1440 ultrawide), proporção (ultrawide
    nativo, 16:9 com barras pretas ou esticar), tela cheia, idioma do console, limite de fps (taxa do monitor, 60, sem limite ou número), resolução de render,
    DLSS (modo e preset; padrão DLSS 4.5), geração de quadros (2x/3x/4x) e os botões Jogar,
    Parar, Pré-compilar shaders, Abrir pasta de logs e Restaurar padrões.

    As escolhas ficam em user/launcher-settings.json (fora do git). Ao jogar, o launcher parte de
    game/config/fg-launch.json (environment e flags da configuração testada), aplica as escolhas
    num JSON temporário de lançamento (mesmo formato) e chama, sem bloquear a janela:
        tools/run.ps1 -Launch <temp> -TimeoutSec 86400 -Label play -GameDir <pasta> [-Quiet]
    A janela mostra "rodando" e "fechou com código X". Cada execução fica em captures/runs/.

    Variáveis aplicadas: KYTY_DLSS e KYTY_DLSS_PRESET (só com DLSS ligado e preset não padrão),
    KYTY_FRAMEGEN=<quadros gerados por quadro renderizado: 2x=1, 3x=2, 4x=3>, KYTY_RENDER_HEIGHT,
    KYTY_PRESENT_ASPECT=fit (16:9 com barras), KYTY_ULTRAWIDE=<largura>x<altura> + KYTY_ULTRAWIDE_RENDER=1 + KYTY_ULTRAWIDE_HUD=native|16x9 (ultrawide nativo: render na proporção da
    resolução escolhida e HUD ancorado nas bordas; a opção avançada "HUD em 16:9 centralizado" usa 16x9; a proporção da resolução escolhida
    no setup de render, só 01.007.000, imagem esticada na janela; -LegacyPatch usa o patch --game-patch temporário,
    para engines sem a variável), --vblank-frequency 60 sempre (120 só no modo legado explícito), KYTY_FPS_LIMIT=display|60|0|<n> (com geração de
    quadros e "taxa do monitor": taxa/(1+quadros gerados)), KYTY_DRIVER_CACHE_KEY=<sha256 do exe> (cache de pipelines do driver
    persistente; só se o JSON base e o ambiente não a definem; chaves antigas em <work_dir>\_PipelineCache\local são só avisadas), --fullscreen,
    --screen-width/--screen-height e --console-language.

    "Desativar overlays de terceiros no jogo" (padrão ligada) define, só para o processo do jogo, DISABLE_RTSS_LAYER=1,
    DISABLE_VULKAN_OBS_CAPTURE=1, DISABLE_VK_LAYER_VALVE_steam_overlay_1=1 e EOS_OVERLAY_DISABLE_VULKAN_WIN64=1 (as chaves
    disable_environment das camadas Vulkan implícitas do RivaTuner/Afterburner, OBS, Steam e Epic, que quebram junto com o Streamline).

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
    # Script de pré-compilação dos shaders (padrão precompile-windows.ps1 na raiz do pacote, ou build/fg/ na árvore de desenvolvimento).
    [string]$PrecompileScript = '',
    # Ultrawide pelo patch de memória temporário (--game-patch) em vez de KYTY_ULTRAWIDE (engines sem a variável).
    [switch]$LegacyPatch
)

Set-Strictmode -Version 2.0
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
if (-not $Settings) { $Settings = Join-Path $Root 'user\launcher-settings.json' }
elseif (-not [System.IO.Path]::IsPathRooted($Settings)) { $Settings = Join-Path $Root $Settings }
if (-not $BaseLaunch) { $BaseLaunch = Join-Path $Root 'game\config\fg-launch.json' }
elseif (-not [System.IO.Path]::IsPathRooted($BaseLaunch)) { $BaseLaunch = Join-Path $Root $BaseLaunch }
if (-not $PrecompileScript) {
    # Pacote: precompile-windows.ps1 na raiz; árvore de desenvolvimento: o do fork em build\fg.
    $PrecompileScript = @((Join-Path $Root 'precompile-windows.ps1'), (Join-Path $Root 'build\fg\precompile-windows.ps1')) |
        Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if (-not $PrecompileScript) { $PrecompileScript = Join-Path $Root 'precompile-windows.ps1' }
}
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
# desport: limite de fps (KYTY_FPS_LIMIT): o vblank fica em 60 e o engine limita os flips; 'display' = taxa do monitor.
$FpsModes = @(@('display', 'Taxa do monitor (padrão)'), @('60', '60 fps (como no console)'), @('unlimited', 'Sem limite'), @('custom', 'Número...'))
$FrameGenModes = @(@(0, 'Desligada'), @(1, '2x (1 quadro gerado)'), @(2, '3x (2 quadros gerados)'), @(3, '4x (3 quadros gerados)'))
$DlssModes = @(
    @('off', 'Desligado'), @('dlaa', 'DLAA (qualidade nativa)'), @('quality', 'Qualidade'), @('balanced', 'Equilibrado'),
    @('performance', 'Desempenho'), @('ultra_performance', 'Desempenho máximo'))
$DlssPresets = @(
    @('default', 'Padrão (DLSS 4.5)'), @('J', 'J'), @('K', 'K'), @('L', 'L'), @('M', 'M'))

# Chaves disable_environment das camadas Vulkan implícitas instaladas (RivaTuner/Afterburner, OBS, Steam, Epic): definidas só no
# processo do jogo (o run.ps1 as aplica e remove), elas quebram junto com o Streamline (crash dentro do vulkan-1.dll).
$OverlayEnv = [ordered]@{
    DISABLE_RTSS_LAYER                      = '1'
    DISABLE_VULKAN_OBS_CAPTURE              = '1'
    DISABLE_VK_LAYER_VALVE_steam_overlay_1  = '1'
    EOS_OVERLAY_DISABLE_VULKAN_WIN64        = '1'
}

function Get-Defaults {
    [ordered]@{
        game = ''; resolution = '2560x1440'; fullscreen = $false; aspect = 'auto'; language = 17
        fpsMode = 'display'; fpsCustom = 90; legacyVblank120 = $false; renderHeight = 0; dlss = 'off'; dlssPreset = 'default'; frameGen = 0; fullLog = $false
        ultrawideHud16x9 = $false; disableOverlays = $true
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

# desport: detecta eboot.bin criptografado/comprimido pelo cabeçalho (SELF: magic, contagem e tipo dos segmentos; bit 0x800 =
# tem program header, 0x2 = criptografado, 0x8 = comprimido). Só lê os primeiros bytes; nada é descriptografado.
function Test-EbootHeader([string]$EbootPath) {
    $bad = { param($m) [pscustomobject]@{ nivel = 'erro'; msg = $m } }
    try {
        $fs = [System.IO.File]::Open($EbootPath, 'Open', 'Read', 'ReadWrite')
        try {
            $head = New-Object byte[] 32
            $n = $fs.Read($head, 0, 32)
            if ($n -lt 32) { return (& $bad 'eboot.bin pequeno demais: não é um executável do jogo.') }
            $magic = [BitConverter]::ToString($head, 0, 4)
            if ($magic -eq '7F-45-4C-46') { return [pscustomobject]@{ nivel = 'ok'; msg = 'eboot.bin em texto claro (ELF).' } }
            if ($magic -ne '4F-15-3D-1D' -and $magic -ne '54-14-F5-EE') {
                return (& $bad 'eboot.bin em formato desconhecido (talvez criptografado). Só dumps já em texto claro são aceitos; o launcher não descriptografa nada.')
            }
            $count = [int][BitConverter]::ToUInt16($head, 24)
            if ($count -lt 1 -or $count -gt 512) { return (& $bad 'Cabeçalho SELF do eboot.bin inválido (contagem de segmentos).') }
            $seg = New-Object byte[] ($count * 32)
            if ($fs.Read($seg, 0, $seg.Length) -lt $seg.Length) { return (& $bad 'Cabeçalho SELF do eboot.bin truncado.') }
            for ($i = 0; $i -lt $count; $i++) {
                $type = [BitConverter]::ToUInt64($seg, $i * 32)
                if (($type -band 0x800) -and ($type -band 0xA)) {
                    return (& $bad 'eboot.bin criptografado ou comprimido. O desport só aceita um dump já em texto claro, tirado do seu próprio console; não há descriptografia aqui.')
                }
            }
            return [pscustomobject]@{ nivel = 'ok'; msg = 'eboot.bin em texto claro (SELF).' }
        } finally { $fs.Dispose() }
    } catch { return [pscustomobject]@{ nivel = 'aviso'; msg = "Não consegui ler o cabeçalho do eboot.bin: $($_.Exception.Message)" } }
}

# Confere a pasta do jogo: devolve ok (pode jogar), nivel (ok/aviso/erro) e a mensagem.
function Test-GameFolder([string]$Path) {
    if (-not $Path) { return [pscustomobject]@{ ok = $false; nivel = 'erro'; msg = 'Escolha a pasta do jogo (a que tem o eboot.bin).' } }
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        return [pscustomobject]@{ ok = $false; nivel = 'erro'; msg = 'Pasta não encontrada.' }
    }
    if (-not (Test-Path -LiteralPath (Join-Path $Path 'eboot.bin'))) {
        return [pscustomobject]@{ ok = $false; nivel = 'erro'; msg = 'Não há eboot.bin nessa pasta (o dump precisa estar descriptografado).' }
    }
    # desport: só detecta (cabeçalho do SELF, mesmo critério de tools/ps5elf.py); não há descriptografia no projeto.
    $enc = Test-EbootHeader (Join-Path $Path 'eboot.bin')
    if ($enc.nivel -eq 'erro') { return [pscustomobject]@{ ok = $false; nivel = 'erro'; msg = $enc.msg } }
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

# ---------------------------------------------------------------- limite de fps e cache de driver

# Taxa de atualização (Hz) do monitor, pela placa de vídeo (0 se não der para saber). Só serve para o limite com geração de quadros.
function Get-MonitorHz {
    try {
        $hz = Get-CimInstance -ClassName Win32_VideoController -ErrorAction Stop |
            Where-Object { $_.CurrentRefreshRate -gt 0 } | ForEach-Object { [int]$_.CurrentRefreshRate } | Sort-Object -Descending | Select-Object -First 1
        if ($hz) { return [int]$hz }
    } catch {}
    return 0
}

# Valor de KYTY_FPS_LIMIT para as escolhas ('' no modo legado). Define $script:fpsNote com uma explicação curta.
function Get-FpsLimitValue($s) {
    $script:fpsNote = ''
    if ($s.legacyVblank120) { $script:fpsNote = 'Modo legado: vblank 120, sem limite de fps (o jogo pode andar mais rápido que o normal).'; return '' }
    switch ([string]$s.fpsMode) {
        '60' { return '60' }
        'unlimited' { return '0' }
        'custom' { return "$([math]::Min([math]::Max([int]$s.fpsCustom, 20), 1000))" }
        default {
            $fg = [int]$s.frameGen
            if ($fg -le 0) { return 'display' }
            # Com geração de quadros o monitor mostra renderizados x (1 + gerados): limita os renderizados.
            $hz = Get-MonitorHz
            if ($hz -le 0) { $hz = 60; $script:fpsNote = 'Taxa do monitor desconhecida: assumi 60 Hz para o limite com geração de quadros.' }
            $lim = [math]::Max([int][math]::Floor($hz / (1 + $fg)), 20)
            if (-not $script:fpsNote) { $script:fpsNote = "Limite de $lim fps renderizados (monitor $hz Hz, geração de quadros com $fg gerado(s) por quadro)." }
            return "$lim"
        }
    }
}

# Exe do engine e pasta de trabalho do JSON base.
function Get-DriverCacheInfo($base) {
    $exe = if ($base.PSObject.Properties['kyty_exe']) { Join-Path $Root ([string]$base.kyty_exe) } else { '' }
    $work = if ($base.PSObject.Properties['work_dir']) { Join-Path $Root ([string]$base.work_dir) } else { Join-Path $Root 'user\kyty' }
    [pscustomobject]@{ exe = $exe; work = $work }
}

# Chaves de cache de driver antigas (pastas em <work>\_PipelineCache\local\ que não são a chave atual): só mede, nunca apaga.
function Get-StaleDriverCache([string]$Work, [string]$CurrentKey) {
    $dir = Join-Path $Work '_PipelineCache\local'
    $result = [pscustomobject]@{ count = 0; bytes = [int64]0; total = [int64]0; dir = $dir }
    if (-not (Test-Path -LiteralPath $dir)) { return $result }
    foreach ($d in Get-ChildItem -LiteralPath $dir -Directory -ErrorAction SilentlyContinue) {
        $m = Get-ChildItem -LiteralPath $d.FullName -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum
        $size = if ($m.Sum) { [int64]$m.Sum } else { [int64]0 }
        $result.total += $size
        if ($d.Name -ne $CurrentKey) { $result.count++; $result.bytes += $size }
    }
    return $result
}

# ---------------------------------------------------------------- checagens de abertura

# desport: checagens antes de liberar o Jogar (PLAN.md Fase 7 item 6), no espírito do bbport (CPU, versão do jogo, GPU/driver).
# Nada de rede. Nível: ok (verde), aviso (amarelo), erro (vermelho, bloqueia o Jogar).
# Streamline 2.14.1: README do SDK exige driver NVIDIA 512.15 ou mais novo; o SDK não documenta mínimo próprio do DLSS 4.5.
$script:sysInfo = $null
$MinNvidiaDriver = [version]'512.15'
# Heurística do projeto (não vem de documentação): abaixo de 4 núcleos o jogo não roda decente; recomendado 6 núcleos / 12 threads.
$CpuMinCores = 4; $CpuRecCores = 6; $CpuRecThreads = 12
$RamRecGB = 16
# DLLs que o frame-gen.cpp carrega (tools/package.ps1 lista as mesmas): DLSS-SR e, com geração de quadros, as do DLSS-G.
$SlDllsBase = 'sl.interposer.dll', 'sl.common.dll', 'sl.dlss.dll', 'nvngx_dlss.dll'
$SlDllsFg = 'sl.dlss_g.dll', 'sl.reflex.dll', 'sl.pcl.dll', 'nvngx_dlssg.dll'

if (-not ('DesLauncher.Cpu' -as [type])) {
    Add-Type -Namespace DesLauncher -Name Cpu -MemberDefinition '[DllImport("kernel32.dll")] public static extern bool IsProcessorFeaturePresent(uint f);'
}

# Driver NVIDIA "32.0.15.6094" -> 560.94 (os 5 últimos dígitos das duas últimas partes); $null se não for possível.
function ConvertTo-NvidiaDriver([string]$Raw) {
    $p = $Raw -split '\.'
    if ($p.Count -lt 4) { return $null }
    $d = ($p[2] + $p[3]) -replace '\D', ''
    if ($d.Length -lt 5) { return $null }
    $d = $d.Substring($d.Length - 5)
    try { return [version]($d.Substring(0, 3) + '.' + $d.Substring(3)) } catch { return $null }
}

# Hardware (CPU, RAM, GPUs), lido uma vez por execução.
function Get-SystemInfo {
    if ($script:sysInfo) { return $script:sysInfo }
    $info = [ordered]@{ cpuName = ''; cores = 0; threads = 0; avx = $null; avx2 = $null; ramGB = 0; gpus = @() }
    try {
        $cpus = @(Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop)
        $info.cpuName = ($cpus[0].Name -replace '\s+', ' ').Trim()
        $info.cores = [int](($cpus | Measure-Object -Property NumberOfCores -Sum).Sum)
        $info.threads = [int](($cpus | Measure-Object -Property NumberOfLogicalProcessors -Sum).Sum)
    } catch {}
    try { $info.avx = [DesLauncher.Cpu]::IsProcessorFeaturePresent(39); $info.avx2 = [DesLauncher.Cpu]::IsProcessorFeaturePresent(40) } catch {}
    try { $info.ramGB = [math]::Round((Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop).TotalPhysicalMemory / 1GB, 1) } catch {}
    try {
        $info.gpus = @(Get-CimInstance -ClassName Win32_VideoController -ErrorAction Stop |
            Where-Object { $_.Name -and $_.Name -notmatch 'Basic Render|Remote|Virtual|Parsec|Meta Virtual' } | ForEach-Object {
                $vendor = switch -Regex ([string]$_.PNPDeviceID) { 'VEN_10DE' { 'NVIDIA' } 'VEN_1002' { 'AMD' } 'VEN_8086' { 'Intel' } default { 'desconhecido' } }
                [pscustomobject]@{ name = [string]$_.Name; vendor = $vendor; driverRaw = [string]$_.DriverVersion; nvDriver = $(if ($vendor -eq 'NVIDIA') { ConvertTo-NvidiaDriver ([string]$_.DriverVersion) } else { $null }) }
            })
    } catch {}
    $script:sysInfo = [pscustomobject]$info
    return $script:sysInfo
}

# Pasta das DLLs do Streamline como o engine a procura (KYTY_STREAMLINE_DIR, depois três candidatas ao lado do exe).
function Find-StreamlineDir([string]$ExePath, $base) {
    $envDir = ''
    if ($base -and $base.PSObject.Properties['environment'] -and $base.environment.PSObject.Properties['KYTY_STREAMLINE_DIR']) { $envDir = [string]$base.environment.KYTY_STREAMLINE_DIR }
    elseif ($env:KYTY_STREAMLINE_DIR) { $envDir = $env:KYTY_STREAMLINE_DIR }
    if ($envDir) { return $envDir }
    if (-not $ExePath) { return '' }
    $exeDir = Split-Path -Parent $ExePath
    $cands = @((Join-Path $exeDir 'streamline\bin\x64'), (Join-Path $exeDir '_Build\deps\streamline\sdk\bin\x64'),
        (Join-Path (Split-Path -Parent $exeDir) 'deps\streamline\sdk\bin\x64'))
    foreach ($c in $cands) { if (Test-Path -LiteralPath (Join-Path $c 'sl.interposer.dll')) { return $c } }
    return $cands[0]
}

# Roda todas as checagens para as escolhas $s. Devolve itens (area/nivel/msg), blocking (algum erro) e se DLSS / geração de
# quadros devem ser desligados (placa sem RTX, RTX 20/30 sem geração de quadros, driver abaixo do mínimo).
function Get-LaunchChecks($s) {
    $items = New-Object System.Collections.Generic.List[object]
    $add = { param($area, $nivel, $msg) $items.Add([pscustomobject]@{ area = $area; nivel = $nivel; msg = $msg }) }
    $sys = Get-SystemInfo
    $disableDlss = $false; $disableFg = $false
    $wantDlss = ($s.dlss -and $s.dlss -ne 'off'); $wantFg = ([int]$s.frameGen -gt 0)

    # 1. Jogo
    $g = Test-GameFolder ([string]$s.game)
    & $add 'Jogo' $g.nivel $g.msg

    # 2. CPU
    $cpu = if ($sys.cpuName) { "$($sys.cpuName), $($sys.cores) núcleos / $($sys.threads) threads" } else { 'CPU não identificada' }
    if ($null -eq $sys.avx2) { & $add 'CPU' 'aviso' "$cpu. Não consegui verificar AVX2 (o engine exige)." }
    elseif (-not $sys.avx2) { & $add 'CPU' 'erro' "$cpu. Sem AVX2: o engine é compilado para x86-64-v3 (AVX2, FMA, BMI2) e travaria. Precisa de Intel Haswell (4a geração) ou mais nova, ou AMD Ryzen." }
    elseif ($sys.cores -gt 0 -and $sys.cores -lt $CpuMinCores) { & $add 'CPU' 'aviso' "$cpu. AVX2 presente, mas abaixo do mínimo de $CpuMinCores núcleos: vai engasgar." }
    elseif ($sys.cores -gt 0 -and ($sys.cores -lt $CpuRecCores -or $sys.threads -lt $CpuRecThreads)) { & $add 'CPU' 'aviso' "$cpu. AVX2 presente; recomendado $CpuRecCores núcleos / $CpuRecThreads threads ou mais." }
    else { & $add 'CPU' 'ok' "$cpu. AVX2 presente." }
    if ($sys.ramGB -gt 0 -and $sys.ramGB -lt $RamRecGB) { & $add 'Memória' 'aviso' "$($sys.ramGB) GB de RAM: recomendado $RamRecGB GB ou mais." }

    # 3. GPU, driver, Vulkan
    $gpu = @($sys.gpus | Where-Object { $_.vendor -eq 'NVIDIA' } | Select-Object -First 1)
    if (-not $gpu) { $gpu = @($sys.gpus | Select-Object -First 1) }
    if (-not $gpu) {
        & $add 'GPU' 'aviso' 'Não consegui identificar a placa de vídeo (Win32_VideoController).'
        if ($wantDlss -or $wantFg) { $disableDlss = $true; $disableFg = $true }
    } else {
        $gpu = $gpu[0]
        $drv = if ($gpu.nvDriver) { "driver $($gpu.nvDriver)" } elseif ($gpu.driverRaw) { "driver $($gpu.driverRaw)" } else { 'driver desconhecido' }
        $label = "$(if ($gpu.name -like "$($gpu.vendor)*") { $gpu.name } else { $gpu.vendor + " " + $gpu.name }), $drv"
        $isRtx = ($gpu.vendor -eq 'NVIDIA' -and $gpu.name -match 'RTX')
        $series = 0
        if ($isRtx -and $gpu.name -notmatch 'Quadro|RTX\s*A\d|Tesla' -and $gpu.name -match 'RTX\s*(\d{2})\d{2}') { $series = [int]$Matches[1] }
        if (-not $isRtx) {
            if ($wantDlss -or $wantFg) {
                $disableDlss = $true; $disableFg = $true
                & $add 'GPU' 'aviso' "$label. DLSS e geração de quadros exigem placa NVIDIA RTX: opções desligadas."
            } else { & $add 'GPU' 'ok' "$label. Sem NVIDIA RTX: DLSS e geração de quadros ficam indisponíveis." }
        } elseif ($gpu.nvDriver -and $gpu.nvDriver -lt $MinNvidiaDriver) {
            if ($wantDlss -or $wantFg) {
                $disableDlss = $true; $disableFg = $true
                & $add 'GPU' 'aviso' "$label. O Streamline 2.14 exige driver NVIDIA $MinNvidiaDriver ou mais novo (README do SDK): DLSS e geração de quadros desligados. Atualize o driver."
            } else { & $add 'GPU' 'aviso' "$label. Driver abaixo de $MinNvidiaDriver (mínimo do Streamline 2.14): DLSS e geração de quadros não vão funcionar." }
        } elseif ($isRtx -and -not $gpu.nvDriver) {
            & $add 'GPU' 'aviso' "$label. Não consegui ler a versão do driver NVIDIA (mínimo para o Streamline 2.14: $MinNvidiaDriver)."
        } elseif ($series -gt 0 -and $series -lt 40 -and $wantFg) {
            $disableFg = $true
            & $add 'GPU' 'aviso' "$label. Geração de quadros pede RTX 40 ou mais nova: opção desligada (o DLSS continua)."
        } elseif ($series -gt 0 -and $series -lt 50 -and [int]$s.frameGen -ge 2) {
            & $add 'GPU' 'aviso' "$label. Geração de quadros 3x e 4x pedem RTX 50; nesta placa o engine pode recusar."
        } else { & $add 'GPU' 'ok' "$label." }
        $others = @($sys.gpus | Where-Object { $_.name -ne $gpu.name })
        if ($others.Count -gt 0) { & $add 'GPU' 'ok' ('Também presente: ' + (($others | ForEach-Object { $_.name }) -join ', ') + '. O engine escolhe a placa; em notebook, rode o launcher na GPU NVIDIA.') }
    }
    $vk = Join-Path $env:windir 'System32\vulkan-1.dll'
    if (Test-Path -LiteralPath $vk) { & $add 'Vulkan' 'ok' 'vulkan-1.dll presente (o driver precisa suportar Vulkan 1.3).' }
    else { & $add 'Vulkan' 'erro' 'vulkan-1.dll não encontrado em System32: instale ou atualize o driver da placa de vídeo.' }

    # 4. Arquivos do engine
    $base = $null
    try { $base = Get-Content -LiteralPath $BaseLaunch -Raw -Encoding UTF8 | ConvertFrom-Json } catch {}
    if (-not $base) {
        & $add 'Engine' 'erro' "Configuração de lançamento ausente ou inválida: $BaseLaunch"
    } else {
        $ci = Get-DriverCacheInfo $base
        $exe = $ci.exe
        if (-not $exe) { $exe = (Read-LocalIni (Join-Path $Root 'desport.local.ini'))['KYTY_EXE'] }
        if (-not $exe -or -not (Test-Path -LiteralPath $exe)) {
            & $add 'Engine' 'erro' "kyty_emulator.exe não encontrado$(if ($exe) { ' (' + $exe + ')' }). Compile o engine ou use o pacote completo."
        } else {
            $enginMsg = 'kyty_emulator.exe presente.'
            $nivel = 'ok'
            if (($wantDlss -and -not $disableDlss) -or ($wantFg -and -not $disableFg)) {
                $slDir = Find-StreamlineDir $exe $base
                $need = @($SlDllsBase)
                if ($wantFg -and -not $disableFg) { $need += $SlDllsFg }
                $missing = @($need | Where-Object { -not (Test-Path -LiteralPath (Join-Path $slDir $_)) })
                if ($missing.Count -gt 0) {
                    $nivel = 'aviso'
                    $enginMsg += " Faltam DLLs do Streamline em ${slDir}: $($missing -join ', '). O engine roda sem DLSS/geração de quadros."
                } else { $enginMsg += " DLLs do Streamline/DLSS presentes ($slDir)." }
            }
            & $add 'Engine' $nivel $enginMsg
        }
        # Cache estático de pipelines (junction em <work_dir>\_PipelineCache\static)
        $static = Join-Path $ci.work '_PipelineCache\static'
        $hasStatic = $false
        if (Test-Path -LiteralPath $static -PathType Container) {
            $hasStatic = [bool](Get-ChildItem -LiteralPath $static -File -ErrorAction SilentlyContinue | Select-Object -First 1)
        }
        if ($hasStatic) { & $add 'Shaders' 'ok' 'Cache estático de pipelines presente.' }
        else { & $add 'Shaders' 'aviso' 'Sem cache estático de pipelines: a primeira sessão vai compilar shaders (travadas). Use "Pré-compilar shaders".' }
    }
    $blocking = (@($items.ToArray() | Where-Object { $_.nivel -eq 'erro' }).Count -gt 0)
    return [pscustomobject]@{ items = $items.ToArray(); blocking = $blocking; disableDlss = $disableDlss; disableFg = $disableFg }
}

# Desliga em $s o que as checagens mandaram desligar.
function Set-CheckOverrides($s, $c) {
    if ($c.disableDlss -and $s.dlss -ne 'off') { $s.dlss = 'off' }
    if ($c.disableFg -and [int]$s.frameGen -gt 0) { $s.frameGen = 0 }
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
    $envVars.Remove('KYTY_ULTRAWIDE')
    $envVars.Remove('KYTY_ULTRAWIDE_RENDER'); $envVars.Remove('KYTY_ULTRAWIDE_HUD')
    if ($plan.mode -eq 'ultrawide') {
        if ($LegacyPatch -and $PatchPath) {
            $script:ultrawidePatch = New-UltrawidePatch $plan.ratio
            Set-Flag '--game-patch' $PatchPath
        } else {
            # desport: ultrawide nativo: o engine acha a constante 16/9 pelos bytes, renderiza na proporção (a largura vem da
            # altura de KYTY_RENDER_HEIGHT/DLSS) e ancora o HUD nas bordas (native) ou o deixa em 16:9 centralizado (16x9).
            $envVars['KYTY_ULTRAWIDE'] = ([string]$s.resolution).Trim().ToLower()
            $envVars['KYTY_ULTRAWIDE_RENDER'] = '1'
            $envVars['KYTY_ULTRAWIDE_HUD'] = $(if ($s.ultrawideHud16x9) { '16x9' } else { 'native' })
        }
    }
    if ($plan.mode -ne 'ultrawide' -or ($LegacyPatch -and $PatchPath)) { $envVars.Remove('KYTY_ULTRAWIDE_RENDER'); $envVars.Remove('KYTY_ULTRAWIDE_HUD') }
    # desport: overlays de terceiros fora do processo do jogo.
    foreach ($key in $OverlayEnv.Keys) { if ($s.disableOverlays) { $envVars[$key] = $OverlayEnv[$key] } else { $envVars.Remove($key) } }
    $rh = [int]$s.renderHeight
    if ($rh -gt 0 -and $rh -ne 1440) { $envVars['KYTY_RENDER_HEIGHT'] = "$rh" } else { $envVars.Remove('KYTY_RENDER_HEIGHT') }

    # Idioma e fps
    Set-Flag '--console-language' "$([int]$s.language)"
    # desport: vblank sempre 60 (o passo de tempo do jogo tem piso de 1/60 s: vblank 120 acelera o jogo); o limite de fps
    # vai em KYTY_FPS_LIMIT. O modo legado (vblank 120) só com a opção explícita.
    $limit = Get-FpsLimitValue $s
    $script:fpsLimitShown = $limit
    Set-Flag '--vblank-frequency' "$(if ($s.legacyVblank120) { 120 } else { 60 })"
    if ($limit -ne '') { $envVars['KYTY_FPS_LIMIT'] = $limit } else { $envVars.Remove('KYTY_FPS_LIMIT') }

    # DLSS (KYTY_DLSS/KYTY_DLSS_PRESET) e geração de quadros (KYTY_FRAMEGEN)
    if ($s.dlss -and $s.dlss -ne 'off') {
        $envVars['KYTY_DLSS'] = [string]$s.dlss
        if ($s.dlssPreset -and $s.dlssPreset -ne 'default') { $envVars['KYTY_DLSS_PRESET'] = [string]$s.dlssPreset } else { $envVars.Remove('KYTY_DLSS_PRESET') }
    } else { $envVars.Remove('KYTY_DLSS'); $envVars.Remove('KYTY_DLSS_PRESET') }
    if ([int]$s.frameGen -gt 0) { $envVars['KYTY_FRAMEGEN'] = "$([int]$s.frameGen)" } else { $envVars.Remove('KYTY_FRAMEGEN') }

    # desport: cache de pipelines do driver persistente: chave = sha256 do exe, salvo se o JSON base ou o ambiente já a definem.
    # (O run.ps1 faz o mesmo quando ninguém define; aqui a chave entra no JSON para aparecer no -DryRun.)
    $script:cacheKey = ''
    $script:cacheNote = ''
    $ci = Get-DriverCacheInfo $base
    if ($envVars.Contains('KYTY_DRIVER_CACHE_KEY')) { $script:cacheKey = $envVars['KYTY_DRIVER_CACHE_KEY'] }
    elseif ($env:KYTY_DRIVER_CACHE_KEY) { $script:cacheKey = $env:KYTY_DRIVER_CACHE_KEY }
    elseif ($ci.exe -and (Test-Path -LiteralPath $ci.exe)) {
        $script:cacheKey = (Get-FileHash -LiteralPath $ci.exe -Algorithm SHA256).Hash.ToLower()
        $envVars['KYTY_DRIVER_CACHE_KEY'] = $script:cacheKey
    }
    if ($script:cacheKey) {
        $stale = Get-StaleDriverCache $ci.work $script:cacheKey
        if ($stale.count -gt 0) {
            $script:cacheNote = ('Cache de driver: {0} chave(s) antiga(s) ocupam {1:N1} GB em {2} (nada é apagado; pode remover à mão).' -f $stale.count, ($stale.bytes / 1GB), $stale.dir)
        }
    }

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
    # desport: checagens de abertura (o que o launcher mostra no painel); DLSS/geração de quadros caem aqui se a placa não der.
    $checks = Get-LaunchChecks $s
    Set-CheckOverrides $s $checks
    Write-Host '# checagens de abertura:'
    foreach ($c in $checks.items) { Write-Host ('#   [{0}] {1}: {2}' -f $c.nivel, $c.area, $c.msg) }
    Write-Host "#   Jogar: $(if ($checks.blocking) { 'BLOQUEADO (há erro vermelho)' } else { 'liberado' })"
    $check = Test-GameFolder ([string]$s.game)
    Write-Host "# pasta do jogo: [$($check.nivel)] $($check.msg)"
    $patchTmp = Join-Path ([System.IO.Path]::GetTempPath()) 'desport-ultrawide-<id>.json'
    $json = (Build-Launch $s $patchTmp) | ConvertTo-Json -Depth 6
    Write-Host "# proporção: $((Get-AspectPlan $s).mode)$(if ($script:aspectNote) { ' - ' + $script:aspectNote })"
    Write-Host "# fps: KYTY_FPS_LIMIT=$(if ($script:fpsLimitShown) { $script:fpsLimitShown } else { '(não definida)' })$(if ($script:fpsNote) { ' - ' + $script:fpsNote })"
    Write-Host "# cache de driver: KYTY_DRIVER_CACHE_KEY=$(if ($script:cacheKey) { $script:cacheKey } else { '(não definida; exe não encontrado)' })$(if ($script:cacheNote) { ' - ' + $script:cacheNote })"
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
$script:fpsNote = ''
$script:cacheNote = ''
$script:ultrawidePatch = $null
$script:ui = @{}
$script:loading = $true
$script:gameOk = $false
$script:checksBlock = $false

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
    $s.fpsMode = Get-Pair $u.fps $FpsModes
    $s.fpsCustom = [int]$u.fpsNum.Value
    $s.legacyVblank120 = $u.legacy.Checked
    $s.renderHeight = Get-Pair $u.render $RenderHeights
    $s.dlss = Get-Pair $u.dlss $DlssModes
    $s.dlssPreset = Get-Pair $u.preset $DlssPresets
    $s.frameGen = Get-Pair $u.fg $FrameGenModes
    $s.fullLog = $u.log.Checked
    $s.ultrawideHud16x9 = $u.hud16.Checked
    $s.disableOverlays = $u.overlays.Checked
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
    Select-Pair $u.fps $FpsModes $s.fpsMode
    $u.fpsNum.Value = [math]::Min([math]::Max([int]$s.fpsCustom, 20), 1000)
    $u.legacy.Checked = [bool]$s.legacyVblank120
    Select-Pair $u.render $RenderHeights $s.renderHeight
    Select-Pair $u.dlss $DlssModes $s.dlss
    Select-Pair $u.preset $DlssPresets $s.dlssPreset
    Select-Pair $u.fg $FrameGenModes $s.frameGen
    $u.log.Checked = [bool]$s.fullLog
    $u.hud16.Checked = [bool]$s.ultrawideHud16x9
    $u.overlays.Checked = [bool]$s.disableOverlays
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
    Update-Checks
}

# desport: checagens de abertura no painel (verde ok, amarelo aviso, vermelho bloqueia o Jogar). Desliga DLSS / geração de
# quadros nos controles quando a placa ou o driver não dão conta.
function Update-Checks {
    $u = $script:ui
    Read-Controls
    $c = Get-LaunchChecks $script:s
    $before = "$($script:s.dlss)|$($script:s.frameGen)"
    Set-CheckOverrides $script:s $c
    if ("$($script:s.dlss)|$($script:s.frameGen)" -ne $before) {
        $prev = $script:loading
        $script:loading = $true
        Select-Pair $u.dlss $DlssModes $script:s.dlss
        Select-Pair $u.fg $FrameGenModes $script:s.frameGen
        $script:loading = $prev
        $why = ($c.items | Where-Object { $_.area -eq 'GPU' -and $_.nivel -eq 'aviso' } | Select-Object -First 1)
        Set-Status ('DLSS / geração de quadros desligados. ' + $(if ($why) { $why.msg } else { '' })) ([System.Drawing.Color]::FromArgb(190, 110, 0))
    }
    $rtb = $u.checks
    $rtb.Clear()
    foreach ($i in $c.items) {
        $rtb.SelectionColor = switch ($i.nivel) {
            'ok' { [System.Drawing.Color]::FromArgb(0, 120, 40) }
            'aviso' { [System.Drawing.Color]::FromArgb(190, 110, 0) }
            default { [System.Drawing.Color]::FromArgb(190, 30, 30) }
        }
        $tag = switch ($i.nivel) { 'ok' { 'OK   ' } 'aviso' { 'AVISO' } default { 'ERRO ' } }
        $rtb.AppendText("[$tag] $($i.area): $($i.msg)`n")
    }
    $script:checksBlock = $c.blocking
    Update-Enabled
}

function Update-Enabled {
    $u = $script:ui
    $running = ($null -ne $script:proc -and -not $script:proc.HasExited)
    $u.play.Enabled = ($script:gameOk -and -not $script:checksBlock -and -not $running)
    $u.stop.Enabled = $running
    $u.precompile.Enabled = ($script:gameOk -and -not $running)
    $u.preset.Enabled = ((Get-Pair $u.dlss $DlssModes) -ne 'off')
    $u.fpsNum.Enabled = (-not $running) -and ((Get-Pair $u.fps $FpsModes) -eq 'custom') -and -not $u.legacy.Checked
    foreach ($name in 'game', 'browse', 'res', 'full', 'aspect', 'lang', 'fps', 'render', 'dlss', 'fg', 'log', 'hud16', 'overlays', 'legacy', 'reset') { $u[$name].Enabled = -not $running }
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
        $extra = (@($script:aspectNote, $script:fpsNote, $script:cacheNote) | Where-Object { $_ }) -join "`n"
        Set-Status ('Rodando... (feche o jogo para voltar; as execuções ficam em captures\runs)' + $(if ($extra) { "`n" + $extra } else { '' })) ([System.Drawing.Color]::FromArgb(0, 90, 160))
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
$form.ClientSize = New-Object System.Drawing.Size(600, 798)
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
$g2.Text = 'Imagem'; $g2.Location = New-Object System.Drawing.Point(12, 100); $g2.Size = New-Object System.Drawing.Size(576, 180)
$u.res = New-Combo 190 22 250 ($Resolutions) 'DropDown'
$u.full = New-Object System.Windows.Forms.CheckBox
$u.full.Text = 'Tela cheia'; $u.full.Location = New-Object System.Drawing.Point(456, 22); $u.full.Size = New-Object System.Drawing.Size(110, 24)
$u.aspect = New-Combo 190 52 376 $AspectModes
$u.render = New-Combo 190 82 250 $RenderHeights
$u.lang = New-Object System.Windows.Forms.ComboBox
$u.lang.Location = New-Object System.Drawing.Point(190, 112); $u.lang.Size = New-Object System.Drawing.Size(250, 24); $u.lang.DropDownStyle = 'DropDownList'
foreach ($n in $Languages) { [void]$u.lang.Items.Add($n) }
$u.hud16 = New-Object System.Windows.Forms.CheckBox
$u.hud16.Text = 'Avançado: HUD em 16:9 centralizado (ultrawide nativo)'
$u.hud16.Location = New-Object System.Drawing.Point(12, 144); $u.hud16.Size = New-Object System.Drawing.Size(552, 24)
$g2.Controls.AddRange(@(
    $u.hud16,
    (New-Label 'Resolução de saída (janela)' 12 22 175), $u.res, $u.full,
    (New-Label 'Proporção da imagem' 12 52 175), $u.aspect,
    (New-Label 'Resolução de render do 3D' 12 82 175), $u.render,
    (New-Label 'Idioma do console' 12 112 175), $u.lang))

# Desempenho
$g3 = New-Object System.Windows.Forms.GroupBox
$g3.Text = 'Desempenho e DLSS (placa NVIDIA RTX)'; $g3.Location = New-Object System.Drawing.Point(12, 286); $g3.Size = New-Object System.Drawing.Size(576, 236)
$u.fps = New-Combo 190 22 250 $FpsModes
$u.fpsNum = New-Object System.Windows.Forms.NumericUpDown
$u.fpsNum.Location = New-Object System.Drawing.Point(450, 22); $u.fpsNum.Size = New-Object System.Drawing.Size(70, 24)
$u.fpsNum.Minimum = 20; $u.fpsNum.Maximum = 1000; $u.fpsNum.Value = 90
$u.dlss = New-Combo 190 52 250 $DlssModes
$u.preset = New-Combo 190 82 250 $DlssPresets
$u.fg = New-Combo 190 112 250 $FrameGenModes
$u.log = New-Object System.Windows.Forms.CheckBox
$u.log.Text = 'Gravar o log completo do engine (diagnóstico; cresce ~80 MB por minuto)'
$u.log.Location = New-Object System.Drawing.Point(12, 146); $u.log.Size = New-Object System.Drawing.Size(552, 24)
$u.overlays = New-Object System.Windows.Forms.CheckBox
$u.overlays.Text = 'Desativar overlays de terceiros no jogo (RivaTuner/Afterburner, OBS, Steam, Epic)'
$u.overlays.Location = New-Object System.Drawing.Point(12, 174); $u.overlays.Size = New-Object System.Drawing.Size(552, 24)
$u.legacy = New-Object System.Windows.Forms.CheckBox
$u.legacy.Text = 'Avançado, legado: vblank de 120 Hz em vez do limite (o jogo anda mais rápido)'
$u.legacy.Location = New-Object System.Drawing.Point(12, 202); $u.legacy.Size = New-Object System.Drawing.Size(552, 24)
$g3.Controls.AddRange(@(
    $u.overlays, $u.legacy, $u.fpsNum,
    (New-Label 'Limite de fps' 12 22 175), $u.fps,
    (New-Label 'DLSS (super-resolução)' 12 52 175), $u.dlss,
    (New-Label 'Preset do DLSS' 12 82 175), $u.preset,
    (New-Label 'Geração de quadros (DLSS-G)' 12 112 175), $u.fg, $u.log))

# Botões
$u.play = New-Button 'JOGAR' 12 528 270 44
$u.play.Font = New-Object System.Drawing.Font('Segoe UI', 12, [System.Drawing.FontStyle]::Bold)
$u.stop = New-Button 'Parar o jogo' 290 528 120 44
$u.precompile = New-Button 'Pré-compilar shaders' 12 580 190
$u.logs = New-Button 'Abrir pasta de logs' 210 580 190
$u.reset = New-Button 'Restaurar padrões' 408 580 180
$u.status = New-Label 'Pronto.' 12 622 576
$u.status.Size = New-Object System.Drawing.Size(576, 48)
$u.status.TextAlign = 'TopLeft'
# desport: painel das checagens de abertura
$g4 = New-Object System.Windows.Forms.GroupBox
$g4.Text = 'Checagens de abertura'; $g4.Location = New-Object System.Drawing.Point(12, 676); $g4.Size = New-Object System.Drawing.Size(576, 114)
$u.checks = New-Object System.Windows.Forms.RichTextBox
$u.checks.Location = New-Object System.Drawing.Point(8, 20); $u.checks.Size = New-Object System.Drawing.Size(560, 86)
$u.checks.ReadOnly = $true; $u.checks.BorderStyle = 'None'; $u.checks.BackColor = [System.Drawing.SystemColors]::Control
$u.checks.Font = New-Object System.Drawing.Font('Segoe UI', 8.25); $u.checks.ScrollBars = 'Vertical'; $u.checks.TabStop = $false
$g4.Controls.Add($u.checks)
$form.Controls.AddRange(@($g1, $g2, $g3, $u.play, $u.stop, $u.precompile, $u.logs, $u.reset, $u.status, $g4))

# Dicas
$tip = New-Object System.Windows.Forms.ToolTip
$tip.SetToolTip($u.render, 'Altura em que o jogo desenha o 3D (padrão 1440p). Menos pixels = mais fps; a imagem é escalada para a janela.')
$tip.SetToolTip($u.fps, 'O vblank fica em 60 Hz e o engine limita os quadros (KYTY_FPS_LIMIT). Taxa do monitor: o limite é a taxa da tela (com geração de quadros, taxa / (1 + quadros gerados)). Vídeos e menus seguem o vblank.')
$tip.SetToolTip($u.legacy, 'Modo antigo: --vblank-frequency 120 sem limite de fps. O passo de tempo do jogo tem piso de 1/60 s, então o jogo acelera. Use só para comparar.')
$tip.SetToolTip($u.dlss, 'Super-resolução da NVIDIA no lugar do TAA do jogo (RTX 20 ou mais nova).')
$tip.SetToolTip($u.preset, 'Padrão deixa o engine escolher (DLSS 4.5). J e K são os modelos antigos; L e M, os do DLSS 4.5.')
$tip.SetToolTip($u.fg, 'Geração de quadros da NVIDIA (DLSS-G): RTX 40 ou mais nova para 2x; 3x e 4x pedem RTX 50.')
$tip.SetToolTip($u.hud16, 'Só no ultrawide nativo: o HUD e os menus ficam em 16:9 no centro da tela (KYTY_ULTRAWIDE_HUD=16x9). Sem isto o HUD fica ancorado nas bordas da tela larga.')
$tip.SetToolTip($u.overlays, 'Define, só para o processo do jogo, as chaves que desligam as camadas Vulkan do RivaTuner/Afterburner, do OBS, da Steam e da Epic: elas quebram junto com o Streamline (crash dentro do vulkan-1.dll ao criar o device). Consequência: o overlay de fps do Afterburner/OBS não aparece no jogo.')
$tip.SetToolTip($u.aspect, 'Ultrawide nativo: renderiza na proporção da resolução, com campo de visão mais largo e HUD ancorado nas bordas (só versão 01.007.000); vídeos ficam esticados na horizontal. 16:9 com barras: sem distorção. Automática: ultrawide quando a resolução é mais larga que 16:9.')

# Eventos
$u.browse.Add_Click({
    $d = New-Object System.Windows.Forms.FolderBrowserDialog
    $d.Description = 'Pasta do jogo (a que tem eboot.bin e sce_sys)'
    if ($u.game.Text -and (Test-Path -LiteralPath $u.game.Text)) { $d.SelectedPath = $u.game.Text }
    if ($d.ShowDialog() -eq 'OK') { $u.game.Text = $d.SelectedPath }
})
$u.game.Add_TextChanged({ if (-not $script:loading) { Update-GameStatus } })
$u.dlss.Add_SelectedIndexChanged({ if (-not $script:loading) { Update-Enabled; Update-Checks } })
$u.fg.Add_SelectedIndexChanged({ if (-not $script:loading) { Update-Checks } })
$u.fps.Add_SelectedIndexChanged({ if (-not $script:loading) { Update-Enabled } })
$u.legacy.Add_CheckedChanged({ if (-not $script:loading) { Update-Enabled } })
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
