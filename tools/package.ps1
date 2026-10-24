# SPDX-License-Identifier: GPL-2.0-only
<#
.SYNOPSIS
    Monta a pasta de distribuição do desport: descompactar, abrir o launcher, jogar.

.DESCRIPTION
    Junta, em out/dist/desport-<data>/ (out/ fica fora do git):
      - kyty_emulator.exe, kyty_shader_precompile.exe (se houver), libwinpthread-1.dll e, se achar, o runtime do
        Visual C++ (msvcp140*/vcruntime140*, como o fork faz) ao lado do exe;
      - streamline\bin\x64\ com as DLLs que o frame-gen.cpp carrega (sl.interposer, sl.common, sl.dlss, sl.dlss_g,
        sl.reflex, sl.pcl, nvngx_dlss, nvngx_dlssg, NvLowLatencyVk) e as licenças da NVIDIA;
      - o launcher: launcher.cmd na raiz (duplo clique), tools\launcher.ps1, tools\run.ps1 e tools\log_triage.py,
        game\config\fg-launch.json "portátil" (kyty_exe = o exe ao lado; pasta de trabalho = a raiz do pacote, onde o
        precompile e o jogo compartilham o _PipelineCache, que o engine procura relativo ao diretório de trabalho);
      - a pré-compilação do fork: precompile-windows.ps1, launch.json, precompile.cmd e
        tools\local\static-precompile\ (pass-states.json e hints-*.hints, que não trazem código do jogo);
      - licenças: LICENSE (GPL-2.0 do engine), LICENSES\ do fork, THIRD-PARTY-NOTICES.md (do ceremony88 com a nota do
        desport) e as licenças do Streamline/NVIDIA; e um README.txt em português (com um resumo em inglês).
    No fim confere o pacote contra uma lista de padrões proibidos (nada do jogo nem derivado dele: eboot.bin, *.prx,
    *.bk2, sce_sys, _PipelineCache, _SaveData, seeds-*.seeds, *.binaries, *.shaders, captures, dumps...) e FALHA
    se achar algum, apagando o pacote incompleto só com -Clean. Nunca escreve fora de -OutDir.

    -DryRun só lista o que seria copiado (e confere os nomes de destino contra os padrões proibidos).
    -Zip gera também out/dist/desport-<data>.zip.

.EXAMPLE
    tools/package.ps1 -DryRun
    tools/package.ps1 -EngineDir D:\games\desport\build\fg-int\_Build\windows -Zip
#>
[CmdletBinding()]
param(
    # Engine compilado (kyty_emulator.exe e companhia).
    [string]$EngineDir = 'D:\games\desport\build\fg-int\_Build\windows',
    # bin\x64 do SDK do Streamline (sl.*.dll, nvngx_*.dll e *.license.txt).
    [string]$StreamlineDir = 'D:\games\desport\build\fg-port\_Build\deps\streamline\sdk\bin\x64',
    # Árvore do fork: scripts de pré-compilação, LICENSE, LICENSES, notas de terceiros, run-windows.json.
    [string]$SourceDir = 'D:\games\desport\build\fg-int',
    # Pasta de saída (padrão out\dist).
    [string]$OutDir = '',
    # Nome do pacote (padrão desport-AAAAMMDD).
    [string]$Name = '',
    [switch]$Zip,
    # Apaga a pasta do pacote se ela já existir (sem isto, falha).
    [switch]$Clean,
    # Não procura o runtime do Visual C++ (o usuário precisaria do redistribuível instalado).
    [switch]$NoCrt,
    [switch]$DryRun
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
if (-not $OutDir) { $OutDir = Join-Path $Root 'out\dist' }
if (-not $Name) { $Name = 'desport-' + (Get-Date -Format 'yyyyMMdd') }
$PackageDir = Join-Path $OutDir $Name
$TestedTitle = 'PPSA01341'
$TestedVersion = '01.007.000'

# Nada do jogo, nem derivado dele, entra no pacote (PLAN.md §1). Padrões de nome de arquivo e de componente de caminho.
$ForbiddenFiles = @('eboot.bin', '*.prx', '*.sprx', '*.self', '*.elf', '*.bk2', '*.zar', '*.pkg', '*.dmp', 'seeds-*.seeds',
    '*.seeds', '*.binaries', '*.shaders', '*.blobs', 'param.json', 'param.sfo', '*.at9', '*.trp')
$ForbiddenDirs = @('sce_sys', 'sce_module', '_PipelineCache', '_SaveData', 'captures', 'savedata', 'user', 'logs', '_HostAppLogs',
    'movies', 'dumps')

function Test-Forbidden([string]$RelativePath) {
    $parts = $RelativePath -split '[\\/]'
    $file = $parts[-1]
    foreach ($p in $ForbiddenFiles) { if ($file -like $p) { return "arquivo proibido ($p)" } }
    foreach ($dir in $parts[0..([Math]::Max(0, $parts.Count - 2))]) {
        if ($parts.Count -gt 1) { foreach ($d in $ForbiddenDirs) { if ($dir -ieq $d) { return "pasta proibida ($d)" } } }
    }
    return $null
}

# ---------------------------------------------------------------- plano: lista de (origem, destino relativo)

$plan = New-Object System.Collections.Generic.List[object]
$warnings = New-Object System.Collections.Generic.List[string]
$errors = New-Object System.Collections.Generic.List[string]

function Add-File([string]$Source, [string]$Destination, [switch]$Optional) {
    if (Test-Path -LiteralPath $Source -PathType Leaf) {
        $plan.Add([pscustomobject]@{ Kind = 'copy'; Source = $Source; Destination = $Destination })
    } elseif ($Optional) { $warnings.Add("ausente (opcional): $Source")
    } else { $errors.Add("ausente: $Source") }
}
function Add-Generated([string]$Destination, [string]$Content) {
    $plan.Add([pscustomobject]@{ Kind = 'text'; Source = '(gerado)'; Destination = $Destination; Content = $Content })
}

# Engine
Add-File (Join-Path $EngineDir 'kyty_emulator.exe') 'kyty_emulator.exe'
Add-File (Join-Path $EngineDir 'kyty_shader_precompile.exe') 'kyty_shader_precompile.exe' -Optional
Add-File (Join-Path $EngineDir 'libwinpthread-1.dll') 'libwinpthread-1.dll'
if (Test-Path -LiteralPath $EngineDir) {
    # Outras DLLs ao lado do exe no build: o fork empacota só a libwinpthread (+ o runtime do VC++).
    foreach ($dll in Get-ChildItem -LiteralPath $EngineDir -Filter '*.dll' -File -ErrorAction SilentlyContinue) {
        if ($dll.Name -ne 'libwinpthread-1.dll') { $warnings.Add("DLL no build não copiada: $($dll.Name) (confira se o exe a usa)") }
    }
}
if (-not $NoCrt) {
    $crt = $null
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    if (Test-Path -LiteralPath $vswhere) {
        $vs = & $vswhere -latest -products * -property installationPath
        if ($vs) {
            $crt = Get-Item "$vs\VC\Redist\MSVC\*\x64\Microsoft.VC14*.CRT" -ErrorAction SilentlyContinue |
                Where-Object { $_.Parent.Parent.Name -match '^\d+\.' } |
                Sort-Object { [version]$_.Parent.Parent.Name } | Select-Object -Last 1
        }
    }
    if ($crt) {
        foreach ($f in Get-ChildItem $crt.FullName -File | Where-Object { $_.Name -like 'msvcp140*.dll' -or $_.Name -like 'vcruntime140*.dll' }) {
            Add-File $f.FullName $f.Name
        }
    } else { $warnings.Add('runtime do Visual C++ não encontrado: o usuário precisa do redistribuível x64 instalado') }
}

# Streamline (frame-gen.cpp procura <exe>\streamline\bin\x64\sl.interposer.dll)
foreach ($dll in 'sl.interposer.dll', 'sl.common.dll', 'sl.dlss.dll', 'sl.dlss_g.dll', 'sl.reflex.dll', 'sl.pcl.dll',
    'nvngx_dlss.dll', 'nvngx_dlssg.dll') {
    Add-File (Join-Path $StreamlineDir $dll) "streamline\bin\x64\$dll"
}
Add-File (Join-Path $StreamlineDir 'NvLowLatencyVk.dll') 'streamline\bin\x64\NvLowLatencyVk.dll' -Optional
if (Test-Path -LiteralPath $StreamlineDir) {
    foreach ($f in Get-ChildItem -LiteralPath $StreamlineDir -Filter '*.license.txt' -File) { Add-File $f.FullName "streamline\bin\x64\$($f.Name)" }
}
$sdkRoot = Split-Path -Parent (Split-Path -Parent $StreamlineDir)   # ...\sdk
Add-File (Join-Path $sdkRoot 'license.txt') 'streamline\license.txt' -Optional
Add-File (Join-Path $sdkRoot '3rd-party-licenses.md') 'streamline\3rd-party-licenses.md' -Optional
Add-File (Join-Path $sdkRoot 'NVIDIA Nsight Graphics SDK License (Apache 2.0).txt') 'streamline\NVIDIA Nsight Graphics SDK License (Apache 2.0).txt' -Optional

# Launcher e o que ele chama (a raiz do pacote é a "raiz do repositório" de tools\run.ps1)
Add-File (Join-Path $PSScriptRoot 'launcher.ps1') 'tools\launcher.ps1'
Add-File (Join-Path $PSScriptRoot 'run.ps1') 'tools\run.ps1'
Add-File (Join-Path $PSScriptRoot 'log_triage.py') 'tools\log_triage.py' -Optional
Add-Generated 'launcher.cmd' ((@(
    '@echo off',
    'rem Launcher do desport: escolha a pasta do jogo, as opcoes e clique em JOGAR.',
    'start "" powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0tools\launcher.ps1" %*') -join "`r`n") + "`r`n")

# game\config\fg-launch.json portátil: o exe ao lado e o diretório de trabalho na raiz do pacote
$baseLaunch = Join-Path $Root 'game\config\fg-launch.json'
if (Test-Path -LiteralPath $baseLaunch) {
    $launch = Get-Content -LiteralPath $baseLaunch -Raw -Encoding UTF8 | ConvertFrom-Json
    $launch.kyty_exe = 'kyty_emulator.exe'
    $launch.work_dir = '.'   # _PipelineCache é relativo ao diretório de trabalho: o mesmo do precompile-windows.ps1
    $launch._source = 'game/config/fg-launch.json do desport, adaptado pelo tools/package.ps1 (pacote portátil)'
    Add-Generated 'game\config\fg-launch.json' (($launch | ConvertTo-Json -Depth 8) + "`r`n")
} else { $errors.Add("ausente: $baseLaunch") }

# Pré-compilação do fork
Add-File (Join-Path $SourceDir 'precompile-windows.ps1') 'precompile-windows.ps1'
Add-File (Join-Path $SourceDir 'run-windows.json') 'launch.json'
Add-File (Join-Path $SourceDir 'tools\local\static-precompile\pass-states.json') 'tools\local\static-precompile\pass-states.json'
foreach ($h in @(Get-ChildItem (Join-Path $SourceDir 'tools\local\static-precompile') -Filter 'hints-*.hints' -File -ErrorAction SilentlyContinue)) {
    Add-File $h.FullName "tools\local\static-precompile\$($h.Name)"
}
Add-Generated 'precompile.cmd' ((@(
    '@echo off',
    'rem Pre-compila os shaders do jogo (~1 hora na primeira vez; retoma se for interrompida).',
    'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0precompile-windows.ps1" %*',
    'pause') -join "`r`n") + "`r`n")

# Licenças
Add-File (Join-Path $SourceDir 'LICENSE') 'LICENSE'
Add-File (Join-Path $Root 'LICENSE') 'LICENSE-desport.txt' -Optional
$licenses = Join-Path $SourceDir 'LICENSES'
if (Test-Path -LiteralPath $licenses) {
    foreach ($f in Get-ChildItem -LiteralPath $licenses -Recurse -File) {
        Add-File $f.FullName ('LICENSES\' + $f.FullName.Substring($licenses.Length + 1))
    }
    if (-not (Test-Path -LiteralPath (Join-Path $licenses 'third-party'))) {
        $warnings.Add('LICENSES\third-party não existe na árvore do fork (o THIRD-PARTY-NOTICES cita FFmpeg LGPL etc.): confira antes de distribuir')
    }
} else { $errors.Add("ausente: $licenses") }

$notices = Join-Path $SourceDir 'tools\local\package\THIRD-PARTY-NOTICES.md'
if (Test-Path -LiteralPath $notices) {
    $text = [System.IO.File]::ReadAllText($notices)
    $note = @'

## desport (Demon's Souls para PC)

Este pacote e do **desport**, um port do Demon's Souls (PS5, PPSA01341) para PC feito sobre o fork
KytyPS5-DemonsSouls-FrameGen de ceremony88, que e baseado no KytyPS5 (GPL 2.0). As alteracoes do desport ficam marcadas
com `// desport:` no codigo-fonte do engine e tambem sao GPL 2.0 (`LICENSE`, `LICENSE-desport.txt`). O launcher
(`tools\launcher.ps1`) usa o desenho do launcher do ceremony88 e a lista de idiomas do launcher do KytyPS5.
O NVIDIA Streamline, o DLSS (super-resolucao e geracao de quadros) e o Reflex vem com as licencas da NVIDIA em
`streamline\`. Nenhum arquivo do jogo faz parte deste pacote: o jogo e seu, de uma copia propria.
'@
    Add-Generated 'THIRD-PARTY-NOTICES.md' ($text.TrimEnd() + "`r`n" + ($note -replace "`r?`n", "`r`n"))
} else { $errors.Add("ausente: $notices") }

# README e carimbo de versão
$readme = @'
DESPORT - Demon's Souls para PC  /  Demon's Souls on PC
=========================================================

NENHUM ARQUIVO DO JOGO VEM NESTE PACOTE. Voce precisa da sua propria copia, ja descriptografada, do
Demon's Souls PS5: titulo PPSA01341, versao 01.007.000 (a versao testada; outras versoes podem travar ou
dar erros graficos). Nada do jogo e alterado: ele e lido da pasta que voce escolher.

REQUISITOS
- Windows 10 ou 11, 64 bits.
- Placa de video NVIDIA RTX recomendada (RTX 20 ou mais nova para o DLSS; RTX 40 ou mais nova para a geracao
  de quadros 2x; 3x e 4x pedem RTX 50). Driver NVIDIA atual com Vulkan.
- 32 GB de RAM recomendados (o jogo chega a 12-14 GB de memoria) e ~83 GB livres em disco para o jogo,
  mais alguns GB para os caches de shaders.
- CPU moderna com AVX2.

PRIMEIROS PASSOS
1. Descompacte esta pasta em um lugar com permissao de escrita (ex.: C:\Jogos\desport). Nao rode de dentro do .zip.
2. De um duplo clique em launcher.cmd.
3. Em "Jogo", clique em Procurar e escolha a pasta do dump (a que tem eboot.bin e sce_sys). O launcher
   confere o titulo e a versao.
4. Na primeira vez, clique em "Pre-compilar shaders" (leva cerca de 1 hora e usa bastante CPU; pode ser
   interrompida e retomada). Sem isso o jogo trava toda vez que compila um shader novo.
5. Escolha a resolucao, tela cheia, taxa de quadros, DLSS e geracao de quadros e clique em JOGAR.
   Para telas ultrawide (ex.: 3440x1440) use a proporcao "Ultrawide nativo" (campo de visao mais largo; HUD,
   menus e videos ficam esticados na horizontal) ou "16:9 com barras pretas".
   O ultrawide nativo renderiza na proporcao da tela, com o HUD ancorado nas bordas; a opcao avancada
   "HUD em 16:9 centralizado" deixa o HUD e os menus em 16:9 no centro.
6. "Desativar overlays de terceiros no jogo" (ligada por padrao) desliga, so no processo do jogo, as camadas
   Vulkan do RivaTuner/Afterburner, do OBS, da Steam e da Epic, que quebram junto com o DLSS/Streamline (o jogo
   fecha ao iniciar). Efeito: o overlay de fps do Afterburner/OBS nao aparece no jogo. Desligue a opcao so se
   precisar dele e o jogo iniciar normalmente.

ONDE FICA CADA COISA
- user\launcher-settings.json: suas escolhas do launcher.
- captures\runs\: log e informacoes de cada execucao (util para relatar problemas).
- _PipelineCache\, _SaveData\: caches de shaders e os saves do jogo, criados nesta pasta.
- tools\launcher.ps1, tools\run.ps1: os scripts por tras do launcher.

LICENCAS
GPL-2.0 (LICENSE, LICENSE-desport.txt, LICENSES\). Avisos de terceiros: THIRD-PARTY-NOTICES.md. NVIDIA Streamline,
DLSS e Reflex: licencas em streamline\.

ENGLISH (short)
No game files are included: you need your own decrypted dump of Demon's Souls (PS5), title PPSA01341, version
01.007.000. Requirements: Windows 10/11 64-bit, an NVIDIA RTX GPU recommended (DLSS, frame generation), 32 GB RAM
recommended, ~83 GB of disk. Unzip to a writable folder, double-click launcher.cmd, pick your game folder, press
"Pre-compile shaders" once (about an hour), then PLAY. Licenses: GPL-2.0 and NVIDIA's (see above).
'@
Add-Generated 'README.txt' (($readme -replace "`r?`n", "`r`n"))

$stamp = New-Object System.Text.StringBuilder
[void]$stamp.AppendLine("pacote: $Name")
[void]$stamp.AppendLine("data: $((Get-Date).ToString('s'))")
foreach ($pair in @(@('desport', $Root), @('engine', $SourceDir))) {
    $commit = ''
    try { $commit = (& git -C $pair[1] rev-parse --short HEAD 2>$null) } catch {}
    [void]$stamp.AppendLine("$($pair[0]): $commit")
}
Add-Generated 'version-stamp.txt' ($stamp.ToString())

# ---------------------------------------------------------------- confere os destinos contra os padrões proibidos

$violations = New-Object System.Collections.Generic.List[string]
foreach ($item in $plan) {
    if ($reason = Test-Forbidden $item.Destination) { $violations.Add("$($item.Destination): $reason") }
    if ($item.Kind -eq 'copy' -and ($reason = Test-Forbidden ([System.IO.Path]::GetFileName($item.Source)))) {
        $violations.Add("origem $($item.Source): $reason")
    }
}

# ---------------------------------------------------------------- relatório do plano

Write-Host "Pacote: $PackageDir"
foreach ($item in $plan) {
    $size = if ($item.Kind -eq 'copy') { '{0,12:N0}' -f (Get-Item -LiteralPath $item.Source).Length } else { '{0,12}' -f 'gerado' }
    Write-Host ("{0}  {1}" -f $size, $item.Destination)
}
foreach ($w in $warnings) { Write-Host "AVISO: $w" -ForegroundColor Yellow }
foreach ($e in $errors) { Write-Host "ERRO: $e" -ForegroundColor Red }
foreach ($v in $violations) { Write-Host "PROIBIDO: $v" -ForegroundColor Red }

if ($violations.Count -gt 0) { Write-Host 'Pacote recusado: algo do jogo (ou derivado) iria junto.' -ForegroundColor Red; exit 1 }
if ($DryRun) {
    Write-Host ("-DryRun: {0} itens, {1} avisos, {2} erros (nada foi copiado)." -f $plan.Count, $warnings.Count, $errors.Count)
    if ($errors.Count -gt 0) { exit 1 }
    return
}
if ($errors.Count -gt 0) { Write-Host 'Pacote não montado: há arquivos ausentes.' -ForegroundColor Red; exit 1 }

# ---------------------------------------------------------------- monta

if (Test-Path -LiteralPath $PackageDir) {
    if (-not $Clean) { Write-Host "A pasta $PackageDir já existe (use -Clean para refazer)." -ForegroundColor Red; exit 1 }
    # Só apaga dentro de out\dist.
    $full = (Resolve-Path -LiteralPath $PackageDir).Path
    $dist = [System.IO.Path]::GetFullPath($OutDir)
    if (-not $full.StartsWith($dist, [StringComparison]::OrdinalIgnoreCase) -or $full.Length -le $dist.Length) { throw "recusando apagar fora de ${dist}: $full" }
    Remove-Item -LiteralPath $full -Recurse -Force
}
New-Item -ItemType Directory -Path $PackageDir -Force | Out-Null
foreach ($item in $plan) {
    $target = Join-Path $PackageDir $item.Destination
    New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
    if ($item.Kind -eq 'copy') { Copy-Item -LiteralPath $item.Source -Destination $target -Force }
    else { [System.IO.File]::WriteAllText($target, $item.Content, (New-Object System.Text.UTF8Encoding $true)) }
}

# Verificação de segurança no pacote montado (todo arquivo e pasta, não só o plano).
$bad = New-Object System.Collections.Generic.List[string]
$base = (Resolve-Path -LiteralPath $PackageDir).Path
foreach ($f in Get-ChildItem -LiteralPath $PackageDir -Recurse -File) {
    $relative = $f.FullName.Substring($base.Length + 1)
    if ($reason = Test-Forbidden $relative) { $bad.Add("${relative}: $reason") }
}
if ($bad.Count -gt 0) {
    foreach ($b in $bad) { Write-Host "PROIBIDO no pacote: $b" -ForegroundColor Red }
    Write-Host "Verificação de segurança FALHOU: $PackageDir não deve ser distribuído." -ForegroundColor Red
    exit 1
}
Write-Host "Verificação de segurança: ok ($((Get-ChildItem -LiteralPath $PackageDir -Recurse -File).Count) arquivos, nada do jogo)."

if ($Zip) {
    $zipPath = "$PackageDir.zip"
    if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }
    Compress-Archive -Path $PackageDir -DestinationPath $zipPath -CompressionLevel Optimal
    Write-Host ("Zip: {0} ({1:N0} bytes)" -f $zipPath, (Get-Item -LiteralPath $zipPath).Length)
}
Write-Host "Pronto: $PackageDir"
