# Estado do projeto

**Fase atual: 3 — Boot completo do sistema** (PLAN.md §6). Fases 0, 1 e 2 concluídas em 2026-10-23
(portão da Fase 2: ADR-003 aceito).

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
  de working set em 8,7 s (carregamento, execução `instr-scan`). Ainda sem dado de crescimento.

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
1. Ronaldo: decidir o portão da Fase 2 (ADR-003 proposto): estratégia colada no upstream e
   bissecção `22ff469..9dcff95` como primeiro passo da Fase 3.
2. Ronaldo: como tratar o hook de clang-format nos arquivos do upstream (ver commit pendente do
   engine) e se o experimento de desativar a checagem pode rodar.
3. Agente: commit do engine (branch `desport`), ponteiro do submódulo no desport, push.
