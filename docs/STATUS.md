# Estado do projeto

**Fase atual: 4 — Gráficos e desempenho**, agora sobre o engine do ADR-008 (KytyPS5-DemonsSouls-FrameGen
v1.3 + camada desport, branch `desport-fg` do fork). Fases 0–2 concluídas; Fase 3 cumprida na prática
(menu, criação de personagem, gameplay).

**Meta do Ronaldo (2026-10-23):** o port do Demon's Souls tão estável quanto o bbport do Bloodborne.

## Próximo foco (2026-10-24, pedido do Ronaldo): qualidade de imagem

O monitor do Ronaldo é **3440x1440 (21:9)**, a 143 Hz. Todos os testes devem usar essa resolução. Relato da primeira sessão
com DLSS: imagem bem pior que no PS5 Pro, chão borrado, jogo muito escuro em DLAA, HUD cortado à esquerda e com moldura
duplicada, vídeos e cutscenes deslocados.
1. Ultrawide: vídeos e cutscenes centralizados em 16:9 com barras laterais; HUD sem corte (nas bordas ou 16:9 centralizado).
2. Texturas: anisotropia, LOD bias e streaming de mips (agente em `desport-tex`).
3. Escuridão no DLAA/DLSS: cor HDR e exposição automática do SR.
4. DLSS quality feio: render baixo demais (1704x960 de 2560 para 21:9), sem LOD bias negativo. Presets com render mínimo de ~1440p
   de altura para qualidade.
5. Comparação lado a lado com o PS5 Pro (prints do Ronaldo) para achar efeitos faltando na emulação.
A Trilha B (port nativo, Fase 6) continua como caminho para estabilidade; a qualidade gráfica fica no renderer, que o port reaproveita.

## Manhã de 2026-10-24 — desempenho

- **Diagnóstico:** em gameplay a GPU fica ~89% ocupada (`KYTY_GPU_TIMESTAMPS`, `KYTY_GPU_PROFILE`; o "20%" do gerenciador
  de tarefas engana), então o limite é trabalho de GPU e a resolução pesa (1440p: 65 fps; 1080p: 86).
- **DLSS com upscale real** (FIX-016, `KYTY_DLSS_UPSCALE=2`, já no launcher): quality dá **99,5 fps** e performance **111,7**,
  contra 71 em 1440p nativo. Soak de 30 min com DLSS quality, upscale, geração de quadros e `KYTY_FPS_LIMIT=display`
  (`captures/runs/*soak30-full`): 0 crash, 69,5 fps renderizados (teto 144/2), ~139 na tela, 300/300 quadros marcados.
- Testado sem ganho (desligado por padrão, documentado em `docs/agents/knowledge.md`): readback antecipado (modos 1–3),
  yield de compute, fila de compute separada, agrupamento de submits, wave64 em lockstep, chaves do FrameGen.
- Pendente com você: imagem do DLSS em movimento (jitter, nitidez das texturas, HUD um pouco maior em 16:9), velocidade do jogo
  acima de 60 fps, vídeos no ultrawide.

## Noite de 2026-10-24 (trabalho autônomo) — resumo

- `desport-int` (`279661f1`, publicada no fork) integra: ultrawide (HUD 16:9 opcional), `KYTY_FPS_LIMIT`, `DES_FRAME`,
  lote B do upstream, readback antecipado (modos 1–3), DLSS fase B (SR+FG+Reflex) e contadores de latência (`KYTY_READBACK_LATENCY`).
- Validado sem você: bateria noturna (soak 60 min, 0 crash); soak de 30 min com `KYTY_FPS_LIMIT=display`
  (`captures/runs/*soak30-fpslimit`): média de 67,6 fps, nenhuma janela abaixo de 55, 0 crash, 15 quadros lentos. DLSS quality
  com FG 1 (`*dlss-fg-combined`): `combined=1`, 2 quadros apresentados por renderizado, 300/300 marcados, sem crash.
- Correções: FIX-013 (handle de .bk2 ocioso prendia o fps), FIX-014 (build), FIX-015 (HUD 16:9 e pillarbox no ultrawide).
- Desempenho (`docs/agents/knowledge.md`): teto de ~70 fps por latência de ida e volta à GPU. O guest espera ~2,7 ms por leitura
  atrás de ~23 submissões gráficas na fila única. Readback antecipado e yield não ganharam. Em andamento: fila Vulkan de
  compute separada (`desport-acq`).
- Pendente com você: velocidade do jogo acima de 60 fps (visual), qualidade de imagem do DLSS+FG com HUD em movimento, vídeos
  no ultrawide (ainda à esquerda; pillarbox desligado por padrão) e a localização do save de referência.

## Estado em 2026-10-23 23:15 (para retomar após compactação)
**Engine de trabalho:** branch `desport-int` (worktree `build/fg-int`), = `desport-fg` + merges de
`desport-crash` (minidump + DES_CRASH), `desport-mem` (DES_MEM), `desport-s001` (FIX-005 janela
minimizada), `desport-vblank` (vídeos a 60 flips/s com vblank 120), `desport-dlss` (DLSS SR fase A),
`desport-up1` (20 correções do upstream), `desport-up2` (AMPR 41beda43), `desport-uw` (KYTY_ULTRAWIDE),
`desport-rz` (red zone: varredura de lacunas + KYTY_REDZONE_FAULT_AUDIT), `desport-faults`
(KYTY_FAULT_CLASSIFY → DES_FAULTS), `desport-uw2` (ultrawide nativo) e os commits "DLSS SR also requests
present-id" e `f5f44f50` (KYTY_DLSS reserva espaço de endereços para o NGX). `game/config/fg-launch.json`
aponta para `build/fg-int/_Build/windows/kyty_emulator.exe`. Push: só `desport-fg` está publicado no fork;
`desport-int` e os branches de funcionalidade são locais.
**Validado no desport-int:** fumaça (60 fps, red zone sem alertas), S-001 (window-test ok: 60 fps
minimizada/ciclos/coberta), 120 Hz (logo a 60 flips/s; attract_movie abre no menu e mantém 60 — conferir se
fecha no gameplay), captura de crash (minidump + pilha via cdbX64 do WinDbg instalado), DLSS SR (pronto,
modo quality, preset 4.5 M; slots auto cor 0/saída 6/prof 1/vetores 3), ultrawide nativo 3440x1440 (render
na largura real, HUD ancorado nas bordas; `captures/runs/20261023-230230-uw-native/shot-hud.png`).
**Descobertas:** overlays de terceiros (RivaTuner/Afterburner, OBS, Steam, Epic) se injetam como camadas
Vulkan e quebram com o Streamline → launcher desliga por env (DISABLE_RTSS_LAYER etc.). Saída do TAA do jogo
= 2560x1440 (= render): o upscale para 4K é uma passada separada depois do TAA; para DLSS de upscale real é
preciso achá-la e substituir o par TAA+upscale.
**Em andamento:** bateria `tools/nightly.ps1 -SoakMinutes 60` (relatório em `captures/nightly/<data>/report.md`);
agente Opus (dedicado ao ultrawide, pedido do Ronaldo): pillarbox de vídeos (KYTY_ULTRAWIDE_MOVIES) e
KYTY_ULTRAWIDE_HUD_LAYOUT=16x9 no worktree `build/fg-uw2`; agente Sonnet: `tools/capture.ps1` +
`tools/capture_report.py` (FrameCapture via KYTY_LIVE_FILE, marca o TAA e as passadas que leem a saída dele).
**Próximos passos:** (1) ler o relatório da bateria; (2) capturar um quadro para achar a passada de upscale
pós-TAA (DLSS de upscale real) e validar vídeos/menus no ultrawide; (3) juntar pillarbox/HUD_LAYOUT;
(4) KYTY_FAULT_CLASSIFY numa sessão para decidir sobre MEM_WRITE_WATCH; (5) DLSS fase B (SR + geração de
quadros com tokens compartilhados); (6) lotes B do upstream conforme `docs/UPSTREAM_TRIAGE.md`.
**Agentes:** até 2; Sonnet para operacional, Opus para complexo/exploratório; agentes não compilam nem rodam
o jogo, trabalham em worktrees próprios e eu compilo/testo/junto.

## Engine FrameGen (ADR-008) — 2026-10-23
- Import: upstream `f2455c87` + árvore da v1.3 do ceremony88 (`87183c6d`), compilado com o
  `build-windows.cmd` deles (clang-cl, -O3 -march=native, ThinLTO, PGO). Execução: `tools/run.ps1
  -Launch game/config/fg-launch.json` (56 chaves de desempenho do lançador deles; pasta `user/kyty-fg`).
- **Sessão do Ronaldo** (`captures/runs/20261023-202438-fg-sessao1`, 10 min, saída limpa, sem
  pré-compilação): travadas em cada etapa nova (compilação de shaders) e **60 fps** depois de carregar,
  contra ~5 fps no upstream atual. Memória: 5,8 GB no menu, degraus nos carregamentos até 13,8 GB.
- O build deles gravava logs na pasta do dump (`/hostapp/logs`): corrigido ao portar o FIX-003.
- Em andamento: pré-compilação estática de shaders (`precompile-windows.ps1`, horas, retomável) e a
  camada desport portada (marcos, DES_FPS, DES_STAT, hooks do jogo, FIX-003). Ficaram de fora nesta base:
  o encaixe do `DES_TRACE` na relocação (reescrita por eles) e o `DES_COUNTERS` (não há
  `Common::DebugCounters`; eles têm `live-counters.h`).

## Soak de 30 min — `captures/runs/20261023-220041-soak-30m-2`
- HUD em 70 s; 30 min de movimento; **sem crash, sem congelamento** (vigia não disparou; janela nunca
  perdeu o foco). fps por minuto 58,8–60 do 3º ao 31º minuto. 52 quadros lentos (16 s), pior 1,9 s.
- **Memória plana: 12,96 GB do minuto 15 ao 30** (12,18 GB aos 5 min, 12,55 aos 10). O "alerta" de
  41 MB/min da triagem vem do carregamento dentro da janela de cálculo.
- S-001 (congelamento de 30 s / 200 s): reproduz só com a janela minimizada/coberta/sem foco; causa no
  present (flip aposentado só depois de present bem-sucedido). Correção em `desport-s001`.

## Primeiro soak automático — `captures/runs/20261023-213716-soak-10m-1`
- `tools/soak.ps1 -Minutes 10`: save de referência, piloto automático até o HUD em 109 s, 10 min de
  movimento (frente/trás/câmera), log do engine em Silent. **Sem crash.**
- Pré-compilação estática concluída (56 min; `PPSA01341_01.007.000.binaries` 6,26 GB + `.shaders`
  211 MB em `build/fg/_PipelineCache/static`, ligado por junction em `user/kyty-fg`).
- fps: mediana 60; médias por minuto 53–60. Travadas: 56 quadros lentos (44 s) contra 276 (178 s) na
  sessão sem pré-compilação; as de compilação caíram de 135 s para 11,4 s.
- **Memória estável**: 12,3–12,8 GB por 8 min de jogo depois de carregar (sem tendência de alta).
- **Problema aberto S-001:** um congelamento de **30,25 s** aos ~6 min (`DES_FPS` 2,6), com a thread
  de renderização ociosa (`cpu=22 ms`). Suspeita: espera com tempo limite de 30 s (candidato: conexão
  de rede bloqueante; `sceHttp` tem `connect_timeout` de 30 s e os sockets são reais). Próximo soak
  mede `net_connect`/`net_resolve` (`DES_SLOW`) e amostra as pilhas durante qualquer congelamento.

## Fase 0 — progresso

| # | Tarefa | Estado | Evidência / observação |
|---|---|---|---|
| 1 | Repositório e estrutura | feito (2026-10-23) | `git init` (branch `main`), estrutura da §3, `LICENSE` (texto canônico GPL-2.0, igual ao do bbport, sha256 `edaef632…b233f6`), `.gitignore`, `desport.local.ini.example`, `docs/{STATUS,FIXES,DECISIONS}.md`. |
| — | ADR-000 (bbport) | feito (2026-10-23) | `docs/DECISIONS.md`. |
| 2 | Localizar o dump | feito (2026-10-23) | `D:\demon\Demon`: PPSA01341 EUR 01.007.000, texto claro. ADR-001 aceito (EUR em vez de USA). |
| 3 | Fork do KytyPS5 | feito (2026-10-23) | Submódulo `engine/` → `https://github.com/RonaldoLPFilho/KytyPS5`, branch `desport` a partir de `9dcff95` (ADR-002). Branch publicada no fork em 2026-10-23 (`origin/desport` = `54acdbb`). |
| 4 | Build | feito com ressalvas (2026-10-23) | Release e RelWithDebInfo compilam. `ctest`: 60/61 no Release, 59/61 no RelWithDebInfo (FIX-001; KP-001, KP-002). O critério "passa no `ctest`" não está cumprido por completo. |
| 5 | `tools/run.ps1` v1 | feito (2026-10-23) | Testado sem o jogo e usado nas 3 execuções de linha de base. Desde 2026-10-23 grava também a curva de memória (`memory.csv`, PA-001). |
| 6 | Execuções de linha de base (a/b/c) | feito (2026-10-23) | As 3 param no mesmo `EXIT` do renderer (`descriptors.cpp:969`); zero mensagens de validação. Ver "Linha de base". |
| 7 | Relatório de linha de base | feito (2026-10-23) | Ver "Relatório de linha de base". |

## Dump (tarefa 2) — verificado em 2026-10-23, somente leitura

- 1ª entrega (`D:\demon`): só o `.pkg` (`\x7FFIH`, 53.514.949.630 bytes), recusado; nada além
  dos primeiros 64 bytes foi lido.
- 2ª entrega: **`D:\demon\Demon`**, extraído pelo Ronaldo. Estrutura ok (`eboot.bin`,
  `sce_sys/param.json`, `sce_module/` com `libc.prx` e `libSceNpCppWebApi.prx`, dados do jogo em
  pastas como `levels/`, `textures/`, `sound/`).
- `param.json`: `PPSA01341`, `EP9000-PPSA01341_00-DEMONSSOULS00000` (EUR), contentVersion
  `01.007.000`, masterVersion `01.00`. `gameversion.txt`: `+BuildVersion=2025-10-15.877562`.
- `tools/inspect_self.py`: os 3 executáveis são SELF `4F153D1D` (variante aceita pelo KytyPS5),
  **nenhum segmento criptografado ou comprimido**. SHA-256 no ADR-001.
- Tamanho total: **83 GB**, 223.273 arquivos.
- `desport.local.ini` criado com `DES_GAME_DIR=D:\demon\Demon` (ignorado pelo git).
- **Divergência com o plano:** região EUR (PPSA01341), o plano fixava USA (PPSA01342). ADR-001
  está como proposta até o Ronaldo confirmar.

## Build (tarefa 4)

`tools/build-engine.ps1` (Ninja + clang-cl, `-DKYTY_BUILD_LAUNCHER=OFF`, alvos
`kyty_emulator` + `kyty_tests`, `-DBUILD_TESTING=ON`). Sem Qt: o `run.ps1` chama o
`kyty_emulator` direto; o launcher fica para quando for necessário (`-QtDir`).

| Build | Pasta | Resultado |
|---|---|---|
| Release | `engine/_Build/windows` | ok. `kyty_emulator.exe` (26.578.944 bytes) responde a `--help`: `Release, clang-lld_link, ver = 0.3.0, git = 9dcff95e-dirty`. |
| RelWithDebInfo | `engine/_Build/windows-dbg` | ok (433 s), com `kyty_emulator.pdb`; responde a `--help`. A string de versão diz "Release" também neste build (cosmético). |

`ctest` Release: **60 de 61 passam**. `ctest` RelWithDebInfo: **59 de 61**. Logs em `build/`
(ignorado pelo git).
- `vdecsw` não compilava no Windows → corrigido (FIX-001).
- `kernel_file_system` falha com `0xc0000028` nos dois builds (KP-001).
- `audio_out2_port` falha às vezes, só no RelWithDebInfo (KP-002).

## Linha de base (tarefa 6) — 2026-10-23

### (a) padrão — `captures/runs/20261023-155444-a-padrao`
- Comando: `kyty_emulator.exe --game D:\demon\Demon --printf-direction File ...` (engine
  `9dcff95` + FIX-001, Release).
- **Resultado:** o emulador abortou sozinho após **144,1 s** (código 321), antes do tempo limite.
- **O que o Ronaldo viu:** janela com a arte do jogo (`frame` subindo a 60 fps, ~3600 quadros:
  a tela de splash do KytyPS5 durante o carregamento), depois **tela preta** com `fps: 0`
  (contador parado em 5489), depois a janela fechou.
- **Último ponto atingido:** inicialização do sistema e do jogo; o jogo compilou 111 shaders de
  compute e 1 de vértice, **nenhum de pixel**, ou seja, não desenhou nenhum quadro próprio.
  Não há marcos ainda (Fase 2); "logo/intro/menu" não foram atingidos.
- **Causa da parada** (`log.txt:33942`):
  `scalar resource reads overlap a shader buffer write`
  em `engine/src/graphics/host_gpu/renderer/pipeline/descriptors.cpp:969`. É uma checagem
  conservadora do KytyPS5: num dispatch de compute, um shader lê por leitura escalar (valores
  usados na especialização do pipeline) uma região de memória que um shader ligado no mesmo
  conjunto escreve; sem poder provar que não há conflito, o engine aborta. Último shader
  compilado: CS `0x02632cb15eb8128d`. É o primeiro bloqueio a atacar (Fase 3/4).
- **Funções não implementadas:** 298 imports ligados a stub na relocação = 141 `missing`
  (eboot + módulos) + 157 imports da `libSceNpCppWebApi`, que só é carregada quando o jogo pede
  (bate com `out/nid_status.json`). **Nenhuma chamada a import não resolvido** no log.
- Crash: não; parada controlada por `EXIT` do engine.
- Observações: o emulador cria `_PipelineCache/`, `_DownloadData/` e `_TempData/` na pasta de
  trabalho (a pasta da execução), então cada execução começa com o cache de pipelines vazio.
  O log registra movimentos de mouse sobre a janela (ruído).

### (b) validação — `captures/runs/20261023-155954-b-validacao`
- Flags: `--vulkan-validation --shader-validation`, tempo limite 300 s.
- **Resultado:** mesma parada, mesma mensagem e linha (`descriptors.cpp:969`), após **12,1 s**.
- **O que o Ronaldo viu:** splash bem rápido, tela preta, janela fechou.
- **Validação:** camada `VK_LAYER_KHRONOS_validation` ativada (flag ligada e
  `VK_EXT_debug_utils` disponível, `vulkanWindow.cpp:741-752`). **Zero mensagens `[Vulkan][…]`**
  (nem erro nem aviso) até a parada; no KytyPS5 um erro de validação aborta na hora
  (`vulkanWindow.cpp`, `EXIT_COLOR`), então não houve erro de validação antes do bloqueio.
- **Diferença de tempo para a (a) (144 s → 12 s):** na (a) o jogo só começou a compilar shaders
  entre 53 e 91 s (pelos tempos do log de mouse); na (b), em poucos segundos. Hipótese: na (a)
  os dados do jogo foram lidos a frio e o disco `D:` estava ocupado por uma varredura do dump
  inteiro (cálculo de tamanho) em segundo plano. A (c) serve de terceira medida.

### (c) dump de command buffers — `captures/runs/20261023-160213-c-cbdump`
- Flags: `--command-buffer-dump` (dumps em `command_buffers/` da própria execução), limite 300 s.
- **Resultado:** mesma parada (`descriptors.cpp:969`) após **7,2 s**. O Ronaldo viu o mesmo
  padrão: splash rápido, tela preta, fechou. Disco livre e cache quente reforçam a hipótese de
  que os 144 s da (a) foram I/O.
- 54 command buffers (23 `a`, 19 `cc`, 12 `d`). Pacotes até a parada: 382 dispatches de
  compute (308 `DISPATCH_DIRECT`, 74 `DISPATCH_INDIRECT`), 15 `DRAW_INDEX_AUTO`, **1 `R_FLIP`**
  (o jogo chegou a apresentar um quadro), 1 `R_WAIT_FLIP_DONE`, muita sincronização
  (`WAIT_REG_MEM` 519, `ACQUIRE_MEM` 502, `RELEASE_MEM` 263, `WRITE_DATA` 374).
  **Nenhum pacote desconhecido.**

### Relatório de linha de base (tarefa 7)
- **Último ponto atingido (as 3 execuções, determinístico):** o sistema inicializa, o jogo roda
  sua inicialização, cria 25 threads, abre o áudio, carrega dados, envia trabalho de GPU
  (centenas de dispatches de compute, 15 draws sem shader de pixel, 1 flip) e o KytyPS5 para no
  `EXIT` de `descriptors.cpp:969` ao montar um dispatch de compute. Na tela: splash → preto →
  fecha. Nenhum quadro do jogo visível; logo, intro e menu não atingidos.
- **Últimas 200 linhas relevantes do log:**
  `captures/runs/20261023-155444-a-padrao/log_relevante_200.txt` (fora do git; sem as linhas
  indentadas de parâmetros, mouse e patches de TLS). As últimas, antes do erro, são compilações
  de shaders de compute bem-sucedidas.
- **Erros de validação:** zero, de qualquer severidade (execução b).
- **Avisos (iguais nas 3 execuções):** 6× `ignoring indirect uc reg GE_STEREO_CNTL`, 1×
  `RenderTarget: temporary: ignoring PSN color round mode`, 1× `DepthTarget: ignoring enabled
  depth/stencil state without a bound attachment`.
- **Funções não implementadas:** 298 imports ligados a stub na relocação (141 `missing` + 157
  da `libSceNpCppWebApi`, carregada sob demanda); **nenhuma foi chamada** antes da parada.
- **Crash:** não. Parada controlada (código 321) por uma checagem conservadora do renderer.
- **Primeiro alvo da Fase 3/4:** entender o dispatch que dispara a checagem (shader CS
  `0x02632cb15eb8128d` foi o último compilado) e se a leitura escalar e a escrita realmente
  colidem ou se a checagem é conservadora demais para este jogo.

## Fase 1 — progresso

| # | Tarefa | Estado | Evidência / observação |
|---|---|---|---|
| 1 | `tools/inspect_self.py` | feito (2026-10-23) | `out/inventory.json`: 3 executáveis, 1395 imports (1296 NIDs), 47.817 exports. Parser em `tools/ps5elf.py`. Validação: 1157 stubs PLT = 1157 `JUMP_SLOT`. |
| 2 | `tools/nid_db.py` | feito (2026-10-23) | 1788 registros HLE (1736 NIDs), 139 stubs prováveis, 1440 nomes verificados por hash. Regras de stub documentadas no relatório. |
| 3 | `IMPORTS.md` | feito (2026-10-23) | [`docs/IMPORTS.md`](IMPORTS.md), gerado e revisado (ADR-005). Ver números abaixo. |
| 4 | Varredura de instruções | feito (2026-10-23) | Ver abaixo. |
| 5 | Superfície AGC | feito (2026-10-23) | Resumo em `docs/GPU_NOTES.md`; tabela por função em [`docs/GPU_SURFACE.md`](GPU_SURFACE.md). |
| 6 | Testes | feito (2026-10-23) | 27 testes com ELF/SELF e engine sintéticos: `python -m unittest discover -s tests/tools`. |

### Cobertura dos imports (tarefa 3)
- eboot: 1181 imports de 47 bibliotecas. `implemented` 665 (56,3%), `provided_by_game_module`
  356 (30,1%: 199 da `libc.prx`, carregada sempre; 157 da `libSceNpCppWebApi.prx`, carregada
  quando o jogo pede), `missing` 129 (10,9%), `stub` 31 (2,6%).
- **Funções que faltam: 160** (129 + 31). Por biblioteca: `libSceAgc` 78, `libSceAgcDriver` 24,
  `libSceNpWebApi2` 10, `libSceNpSessionSignaling` 7, `libSceAjm` 5, `libSceJpegEnc` 4; o resto
  com 1–3. Os 31 stubs usados pelo eboot são, em geral, inofensivos offline
  (ex.: `sceNetCtlInit`, `sceShareInitialize`, `sceSaveDataDialogProgressBarSetValue`).
- Nenhum dos 129 NIDs ausentes aparece em qualquer lugar do código do engine; cada um tem no
  máximo 4 sítios de chamada. Nenhum foi chamado nas execuções da linha de base.
- 165 imports resolvem só pelo NID (nome de biblioteca do jogo ≠ da HLE, ex.: `libSceAgc` ×
  `Graphics5`); 23 NIDs existem em mais de uma biblioteca da HLE.
- Bate com o log da execução (a): 298 imports ligados a stub = 141 `missing` + 157 da
  `libSceNpCppWebApi`.

### Varredura de instruções (tarefa 4) — `captures/runs/20261023-160642-instr-scan`
- Feita com o próprio `guestInstructionPatcher` do KytyPS5 (`--amd-cpu --redzone`, diagnóstico).
- **Instruções que esta CPU não teria (EXTRQ, INSERTQ, RDPID, CLWB): zero** em todos os módulos.
  O Zen 5 executa tudo o que o jogo usa; no modo padrão nada é alterado.
- `VRSQRTPS` (aproximação de 1/√x, resultado varia por fabricante/geração): 1632 no eboot. Com
  `--amd-cpu` o KytyPS5 troca todas por um cálculo determinístico: 1525 em linha e **107 por trap**
  (não relocáveis; mais lentas). O plano esperava `trapped = 0`; a diferença é que esse contador
  é de um patch opcional de fidelidade numérica, não de falta de suporte da CPU. Se o jogo
  precisa dele (diferenças visuais/física Zen 2 × Zen 5) fica em aberto para a Fase 4.
- Red zone (relevante só no Windows com `--redzone`): eboot com 130.886 funções, 262 usam red
  zone, 8126 acessos de memória nelas, 7970 corrigidos, 156 não relocáveis; `libc.prx` 42/86/86;
  `libSceNpCppWebApi.prx` nenhuma.
- Memória nessa execução: pico de 3,85 GB privados em 8,7 s (carregamento).

### Critério de saída da Fase 1
- `docs/IMPORTS.md` gerado e revisado: **sim** (ADR-005).
- Existe um número para "quantas funções faltam": **sim, 160** (eboot).
- Superfície AGC listada: **sim** (`docs/GPU_NOTES.md`, `docs/GPU_SURFACE.md`).
- **Fase 1 fechada em 2026-10-23.**

## Fase 3 — progresso

### Bissecção do bloqueio (ADR-003) — concluída
- 9 passos em `build/bisect` (builds do upstream com `NOMINMAX`, cache de pipelines frio a cada passo,
  dump no SSD; ruim = checagem `scalar resource reads ...` dispara; bom = passa do 115º pipeline de
  compute). Log: `build/bisect-final.log`, resumo por passo em `build/bisect-summary.log`.
- **Primeiro commit ruim: `c2173801`** ("shader: skip resources in proven empty unsigned loops",
  17/10/2026); o pai `56d03f16` é bom. Prova: `9dcff95` com só esse commit revertido passa.
- Correção no fork: revert marcado `// desport:` (FIX-002, ADR-007); base continua `9dcff95`.
  Relato pronto para o Ronaldo: `docs/upstream/c2173801-demons-souls.md`.

### Primeira execução do build desport — `captures/runs/20261023-182308-desport-revert`
- Engine `9dcff95` + FIX-001 + camada desport (Fase 2) + FIX-002 + FIX-003; dump no SSD
  (`C:\games\DemonsSouls-PPSA01341`, cópia íntegra de 223.290 arquivos); cache de pipelines aquecido.
- `ctest`: 60/61 (só KP-001).
- 240 s sem parada: `flip_1` 3,9 s, `flip_60` 8,5 s, `flip_600` 17,6 s, `first_savedata_mount` 25,1 s,
  `flip_3600` 67,9 s. Nenhum import ausente chamado, nenhuma mensagem de validação.
- Nenhum arquivo novo na pasta do dump (FIX-003): o log do jogo foi para `game_logs/`.
- Log do jogo: `Starting main loop` 2,4 s; `ResourcePool::GatherResourceFileInfo()` **23,5 s** no SSD,
  contra 3,8–5,4 s nas execuções antigas no HD. A investigar na Fase 4 (desempenho de E/S).
- Memória: 5,2 GB privados, 108 MB/min nos primeiros 4 min (inclui carregamento; PA-001).

### Contadores por quadro — `captures/runs/20261023-193727-sessao-contadores` (`-Stats`)
| | Menu (60 fps) | Jogo parado (5 fps) |
|---|---:|---:|
| draws + dispatches | 212 | 8.824 |
| `srt_materialize` (avaliação da tabela de recursos por draw) | 247, 4,7 ms | **13.755, 88 ms** (6,4 µs cada) |
| `readback` (leitura síncrona de buffer escrito pela GPU) | 17, 4,7 ms | **290, 80 ms** |
| esperas pela GPU | 18 (3,9 ms) | 302 (49 ms) |
| envios de fila | 65 | 365 |
| faults de memória rastreada | 1.401 | 3.080 |
| upload de buffers / texturas | 5,5 MB / 58 MB | 11 MB / 18 MB |
- As duas frentes somam ~170 de ~200 ms por quadro. Leituras concentradas em poucas regiões de
  64 KiB (a pior: `0x20ed70000`, 8.843 leituras, 4,75 s na sessão).

### Diagnóstico do fps baixo — `captures/runs/20261023-192359-sessao-amostragem`
- Amostragem com `tools/sampler` (build RelWithDebInfo, personagem parado, 4,8 fps no `DES_FPS`;
  GPU em ~20% e CPU fria, relato do Ronaldo). Relatórios: `samples-base.md`, `samples-boost.json`.
- **13 workers `BPE JobWorkerThread CPU0..12`** (um por núcleo de jogo do PS5, máscara de 1 núcleo,
  prioridade 700 → normal no Windows) giram ociosos a ~95% cada: laço `pause` + `rdtsc`
  (`eboot+0x83b6fd..0x83b85f`). O engine guarda a afinidade mas não aplica. **Não é o gargalo.**
- **Gargalo: a thread de comandos de GPU do engine (uma só, em série), ocupada 100% do tempo:**
  ~72% CPU + ~23% esperando a GPU. Inclusivo: ~30% avaliando tabelas de recursos dos shaders a cada
  draw (`ShaderRecompiler::IR::SrtWalker`), ~20% em leituras síncronas de buffers escritos pela GPU
  (`BufferCache::ReadMemory` → `DownloadBufferMemory` → `CommandScheduler::Wait`), ~19% em
  `CommitBindings`/`ExecutePreparedDraw`. Nenhuma recompilação nova no trecho.
- **Teste A/B ao vivo:** prioridade máxima (+2) na thread de GPU → 4,8 → 4,9 fps. Prioridade descartada.
- Ordem de ataque (Fase 4, item 0): (1) cache no `SrtWalker`; (2) entender e reduzir as leituras
  síncronas; (3) pré-compilação de shaders; (4) Fase 7: comandos de GPU em mais de uma thread.

### Sessão de medição do Ronaldo — `captures/runs/20261023-183343-sessao-medicao`
- Build desport (`01d7965`), SSD, cache de pipelines aquecido; 15 min, saída limpa (código 0).
- Relato: abertura, menu, "iniciar" e cutscene inicial rápidos e responsivos. Depois de
  "continuar jogo": fog de carregamento lenta, cutscene lenta, minutos de tela preta, e então o
  personagem controlável a **3–5 fps**, em baixa resolução. Rodando, mas injogável.
- **Compilação refeita mesmo com o cache aquecido:** 194 VS, 319 PS, 728 CS (1.260 shaders, quase
  o mesmo da sessão com cache vazio). O `_PipelineCache/<título>.bin` guarda só o binário do driver;
  a tradução PS5 → SPIR-V é refeita a cada execução. Explica a fog, a cutscene e a tela preta.
- **Com a compilação já parada (personagem parado), a CPU continua saturada:** 13 threads do
  emulador a ~96% cada (16 lógicos ocupados). Hipótese: espera ativa de threads do jogo (GPU
  emulada ou locks) roubando CPU do thread que desenha. A confirmar com amostragem (Fase 4, item 0).
- Memória: 4,9 GB no menu; degraus nos carregamentos até ~10,3 GB; **estável nos últimos 5 min
  parado** (10.260 → 10.305 MB). Privada comprometida ~10 GB, working set residente ~1,9 GB no fim
  (Gerenciador de Tarefas); sistema em 26,7/31 GB.

### Sessão livre do Ronaldo — `captures/runs/20261023-172446-sessao-livre-584c2e8`
- Build upstream `584c2e8` (sem a camada desport, então sem marcos nem `calls.json`), dump no HD.
- 15,5 min, terminou limpa (o Ronaldo fechou). O jogo abriu e respondeu, mas a **0–3 fps**: mesmo
  sintoma da issue upstream #890. Causa principal provável: compilação contínua de shaders
  (187 VS, 343 PS, 703 CS) com o cache de pipelines vazio a cada execução (o KytyPS5 grava o cache
  na pasta de trabalho, que era a pasta da execução). Corrigido: o `run.ps1` agora roda em
  `user/kyty/` (persistente); o cache da sessão (76 MB) foi copiado para lá.
- **Saves funcionam:** `SAVEDATA0OptionsProfile0` e `SAVEDATA0PlayerProfile0` gravados; copiados
  para `user/kyty/_SaveData`.
- 14 imports ausentes chamados de fato, todos da `libSceNpCppWebApi` (API web da PSN), chamados
  antes de o módulo carregar; retornam 0 no stub. Provavelmente inofensivo offline.
- Memória: ver PA-001.

## Fase 2 — progresso

| # | Tarefa | Estado | Evidência / observação |
|---|---|---|---|
| 1 | Camada `game/` | feito (2026-10-23) | `game/hooks/gameHooks.cpp` (override de HLE por NID, consultado antes da HLE; nenhum override ainda), `game/config/des.toml` (flags padrão, vazio), `game/patches/README.md` (formato do `GamePatch`). ADR-006. |
| 2 | Rastreamento `DES_TRACE=1` | feito (2026-10-23) | `calls.json` por execução. Cenário `boot`: 347 dos 1366 imports chamados, 17,4 milhões de chamadas em 4,9 s; os mais chamados são `memcpy`, `strlen`, `strcmp`, `memset` (libc.prx nativa). Custo: 7,5 s até a parada, igual a sem rastreamento. |
| 3 | Marcos `DES_MILESTONE` | feito (2026-10-23) | `process_started` 0,8 s, `modules_loaded` 1,0 s, `game_entry` 1,0 s, `first_data_file` 1,3 s (`/app0/playgo-chunkdefs.xml`), **`flip_1` 2,8 s (CPU)**. |
| 4 | `tools/log_triage.py` | feito (2026-10-23) | Marcos, parada/exceção (módulo+offset), imports ausentes chamados, validação Vulkan agrupada, avisos repetidos, memória (crescimento por minuto, PA-001), `calls.json`, veredito de cenário. |
| 5 | `tools/run.ps1` v2 | feito (2026-10-23) | `-Scenario`, `-Trace`, flags de `game/config/des.toml`, triagem automática, veredito em `run.json`. |
| 6 | `tools/check.ps1` | feito (2026-10-23) | Testes das ferramentas, build, `ctest` (KP-001 à parte), cenário `boot` (falha esperada pelo bloqueio da linha de base). |

- Cenários em `tests/regression/scenarios.toml`: `boot` (ativo), `title`, `shader-corpus`,
  `charcreate`, `tutorial-10min`, `soak-nexus-2h` (desativados até haver infraestrutura) e as três
  reproduções da linha de base.
- 33 testes das ferramentas passam. `ctest`: 60/61 (KP-001), igual a antes das mudanças.
- **Observação:** o primeiro flip (M3.2) é atingido em 2,8 s; o cenário `boot` só falha pela
  parada do renderer logo depois (`descriptors.cpp:969`).

## Pontos de atenção

### PA-001 — Vazamento de memória (registrado em 2026-10-23, pedido do Ronaldo)
- Contexto: um port comunitário do Demon's Souls teve vazamento de RAM chegando a ~30 GB.
  Esta máquina tem 32 GB; um vazamento desses derruba o jogo ou o PC.
- Medição: desde 2026-10-23 o `tools/run.ps1` amostra a memória do processo a cada segundo
  (`memory.csv`: memória privada e working set) e grava os picos em `run.json`. Toda execução
  tem a curva, então um crescimento aparece cedo, não só no soak.
- Próximos passos: `log_triage.py` (Fase 2) reporta crescimento por minuto; cenário
  `soak-nexus-2h` com limite de inclinação e pico (PLAN.md §8.3); caches do engine com limite e
  liberação (texturas, buffers, pipelines, memória do jogo mapeada). Ver risco em PLAN.md §12.
- Referência atual: execuções duraram 7–144 s; primeiro pico medido: 3,85 GB privados / 4,49 GB
  de working set em 8,7 s (carregamento, execução `instr-scan`).
- **Primeiro sinal (2026-10-23, build upstream `584c2e8`, execução `20261023-171535-bisect2-584c2e8c`):**
  com o Ronaldo navegando do menu de idioma até a criação de personagem, a memória privada chegou a
  **8,4 GB em 180 s**, crescendo **~1,4 GB/min** após o aquecimento (alerta do `log_triage.py`).
  Ainda indistinguível de carregamento legítimo (167 pipelines de compute e 55 shaders de pixel
  compilados no período).
- **Sessão livre de 15,5 min (mesmo build):** 2,2 GB na inicialização; **estável em ~5,1 GB por
  4 min no menu** (sem crescimento em repouso); saltos para 13,4 GB em carregamentos; depois
  **subida lenta de 13,5 para 15,5 GB em ~6 min (~300 MB/min)**, ainda com shaders sendo
  compilados. Pico 15,6 GB privados. Próximo passo: repetir com o cache de pipelines aquecido e
  dump no SSD, parado num ponto fixo; se a subida continuar sem compilação, é vazamento.
- O `memory.csv` agora é gravado a cada amostra (antes só no fim).

## Problemas conhecidos

### KP-001 — `kernel_file_system_tests` aborta com `0xc0000028` no Windows
- Determinístico (5 de 5), sem saída nenhuma; falha também com `--mutex-only`, ou seja, já no
  primeiro caso (`TestMutexHandoff`: threads com pilha própria, sinais pendentes e
  `PthreadCancel`/`PthreadTestcancel`) ou na inicialização.
- O teste não faz parte do CI do upstream no Windows (`.github/workflows/build.yml:124`).
- Hipótese (não confirmada): `0xc0000028` é `STATUS_BAD_STACK`. Ao entrar em código do jogo, o
  engine zera `StackBase`/`StackLimit` do TEB (`gs:0x08`/`gs:0x10`,
  `engine/src/kernel/pthread.cpp:892-897`); qualquer despacho de exceção SEH ou desempilhamento
  nesse estado aborta com esse código.
- Relevância: o mesmo caminho roda com o jogo. Se o Demon's Souls usar cancelamento de thread
  ou gerar exceções SEH em threads do jogo, isso aparece na Fase 3. Para confirmar é preciso
  um depurador (WinDbg/cdb, não instalado) e o build RelWithDebInfo.

### KP-002 — `audio_out2_port_tests` intermitente no RelWithDebInfo
- RelWithDebInfo: `0xc0000005` (violação de acesso) em 7 de 10 execuções. Release: 10 de 10
  passam. Esse teste está no CI do upstream no Windows, que roda em Release.
- Hipótese: condição de corrida no `AudioOut2` (portas/threads de áudio) que o timing do build
  com depuração expõe. Relevante para a Fase 5 (áudio); investigar com depurador quando
  chegarmos lá, ou antes se aparecer com o jogo.

## Toolchain (verificado em 2026-10-23)

| Item | Versão |
|---|---|
| Git | 2.55.0.windows.5 |
| Python | 3.15.0 |
| Build Tools 2022 | 17.14.42 |
| clang-cl | 19.1.5 |
| CMake | 4.4.4 |
| Ninja | 1.13.2 |
| Vulkan SDK | 1.4.363.0 (glslang 16.6.0, SPIRV-Tools v2026.4) |
| RenderDoc | 1.46 |
| pre-commit | 4.7.0 (hook instalado em `engine/`) |
| Qt | não instalado (opcional, só launcher) |
| Hardware | AMD Ryzen 7 9800X3D; NVIDIA GeForce RTX 5080, driver 32.0.16.1714 |

## Descobertas
- **O KytyPS5 não grava log nenhum por padrão** (`printf_direction = Silent`,
  `src/common/emulatorConfig.h:81`); o `run.ps1` passa `--printf-direction File`.
- `--game` aceita pasta, ELF ou `.zar` (`src/main.cpp:248`, `src/common/archive.cpp:95`).
- `--game-patch` recebe um arquivo de cheats ETAHen em JSON.

## Critério de saída da Fase 0
- KytyPS5 compila: **sim** (Release e RelWithDebInfo).
- Passa no `ctest`: **parcial** — 60/61 no Release (KP-001, teste que o upstream não roda no
  Windows) e 59/61 no RelWithDebInfo (KP-002, intermitente).
- Jogo executado nas 3 configurações: **sim**.
- `STATUS.md` diz com evidência até onde ele chega: **sim**.
- **Fase 0 fechada em 2026-10-23 pelo Ronaldo**, com KP-001 e KP-002 registrados como problemas
  conhecidos (não bloqueiam a linha de base).

## Próximo passo concreto
1. Ronaldo: abrir a issue do `docs/upstream/c2173801-demons-souls.md` no KytyPS5 (se quiser).
2. Ronaldo: decidir o hook de clang-format do engine (pular nos arquivos do upstream, recomendado,
   ou aceitar a reformatação) para commitar a branch `desport`; depois, push.
3. Ronaldo: autorizar apagar os 28 logs que o jogo gravou em `<dump>\logs` (HD e SSD) antes do FIX-003.
4. Sessão de jogo com o build desport (cache aquecido, SSD), parada num ponto fixo, para medir fps e
   a curva de memória (PA-001). Depois, Fase 4 com foco em desempenho, medindo antes de otimizar.
