# Estado do projeto

**Fase atual: 0 — Preparação e linha de base** (PLAN.md §6). Iniciada em 2026-10-23.

## Fase 0 — progresso

| # | Tarefa | Estado | Evidência / observação |
|---|---|---|---|
| 1 | Repositório e estrutura | feito (2026-10-23) | `git init` (branch `main`), estrutura da §3, `LICENSE` (texto canônico GPL-2.0, igual ao do bbport, sha256 `edaef632…b233f6`), `.gitignore`, `desport.local.ini.example`, `docs/{STATUS,FIXES,DECISIONS}.md`. |
| — | ADR-000 (bbport) | feito (2026-10-23) | `docs/DECISIONS.md`. |
| 2 | Localizar o dump | feito (2026-10-23), região a confirmar | `D:\demon\Demon`: PPSA01341 EUR 01.007.000, texto claro. ADR-001 proposto (EUR em vez de USA). |
| 3 | Fork do KytyPS5 | feito (2026-10-23) | Submódulo `engine/` → `https://github.com/RonaldoLPFilho/KytyPS5`, branch `desport` a partir de `9dcff95` (ADR-002). Branch publicada no fork em 2026-10-23 (`origin/desport` = `54acdbb`). |
| 4 | Build | feito com ressalvas (2026-10-23) | Release e RelWithDebInfo compilam. `ctest`: 60/61 no Release, 59/61 no RelWithDebInfo (FIX-001; KP-001, KP-002). O critério "passa no `ctest`" não está cumprido por completo. |
| 5 | `tools/run.ps1` v1 | feito (2026-10-23) | Testado sem o jogo (simulado, erros, código de saída, tempo limite com encerramento da árvore). Falta a primeira execução real. |
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
- Tamanho total: ainda calculando (≈50 GB).
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

## Adiantado da Fase 1 (com OK do Ronaldo em 2026-10-23, enquanto o dump era extraído)

- `tools/ps5elf.py` (parser SELF/ELF com limites, recusa de criptografia), `tools/inspect_self.py`
  (→ `out/inventory.json`) e `tools/nid_db.py` (base de NIDs do engine e cobertura dos imports →
  `out/nid_db.json`, `out/nid_status.json`, `IMPORTS.md`). 27 testes com executáveis e engine
  sintéticos: `python -m unittest discover -s tests/tools`.
- Validação contra o dump real: 1157 stubs PLT encontrados = 1157 relocações `JUMP_SLOT`;
  procparam começa com `ORBI`; tabelas dinâmicas por `DT_*` (endereço virtual), não `DT_OS_*`.
- **Primeiro número (preliminar):** o eboot importa 1181 símbolos de 47 bibliotecas.
  `implemented` 665 (56,3%), `stub` 31 (2,6%), `missing` 129 (10,9%), `provided_by_game_module`
  356 (30,1%) → **160 funções faltando**, 78 delas na `libSceAgc` e 24 na `libSceAgcDriver`.
  Nenhum dos 129 NIDs `missing` aparece no código do engine; cada um tem no máximo 4 sítios de
  chamada. O relatório está em `out/IMPORTS.md` até decidir se vai para `docs/` (contém NIDs e
  endereços derivados do eboot).

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
- Decisão pendente do Ronaldo: aceitar o fechamento da Fase 0 com KP-001/KP-002 registrados,
  ou investigá-los antes (precisa do WinDbg).

## Próximo passo concreto
1. Ronaldo: decidir o fechamento da Fase 0 (acima) e se o `IMPORTS.md` pode ir para `docs/`.
2. Agente: terminar a Fase 1 (já adiantada): revisar `IMPORTS.md`, varredura de instruções
   (tarefa 4), superfície AGC em `docs/GPU_NOTES.md` (tarefa 5).
