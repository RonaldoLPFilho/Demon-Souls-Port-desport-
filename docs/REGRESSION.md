# Suíte de regressão: cenários x ferramentas (revisão do PLAN.md §8.3)

Revisão de 2026-10-24, feita só por leitura das ferramentas (`tools/*.ps1`, `tools/log_triage.py`) e de
`tests/regression/scenarios.toml`; **nada foi executado** para escrever este documento. O PLAN.md não foi
alterado: onde ele diverge da realidade, está dito aqui.

Vale para o engine de trabalho (`desport-int`, `game/config/fg-launch.json`). Todos os comandos abaixo abrem o
jogo, então só o coordenador/Ronaldo os executa (regras dos agentes). Rodar da raiz `D:\games\desport`, em
PowerShell: `powershell -NoProfile -ExecutionPolicy Bypass -File tools\<x>.ps1 ...` ou direto `tools\<x>.ps1 ...`.

## 0. Pontos de atenção sobre a infraestrutura de hoje

1. **`run.ps1 -Scenario` sem `-Launch` usa o engine antigo** (`KYTY_EXE` do `desport.local.ini` ou
   `engine/_Build/windows/...`, base upstream `9dcff95`), não o `desport-int`. `tools/check.ps1` chama
   `run.ps1 -Scenario boot` assim, e ainda trata `boot` como falha esperada ("parada em `descriptors.cpp:969`"),
   o que a FIX-002 resolveu: esse trecho está obsoleto. Para o engine atual: sempre `-Launch game/config/fg-launch.json`.
2. `run.ps1` combina `-Scenario` e `-Launch` (flags e timeout do cenário + env/flags/exe/work_dir do JSON); o
   `timeout_sec` do cenário só vale se `-TimeoutSec` não for passado. Cenários com `enabled = false` recusam rodar.
3. O cenário `boot` pede `trace = true` (`DES_TRACE`/`calls.json`). No engine FrameGen o encaixe do `DES_TRACE` na
   relocação ficou de fora (`docs/STATUS.md`, "Engine FrameGen"), então não haverá `calls.json`. Os critérios do
   `boot` não dependem dele, mas o `trace` deveria sair do cenário para esta base.
4. Marcos que o engine emite (`DES_MILESTONE`): `process_started`, `modules_loaded`, `game_entry`, `first_data_file`,
   `first_savedata_mount`, `flip_1`, `flip_60`, `flip_600`, `flip_3600`. **Não existe marco de título, de menu, de HUD nem
   de criação de personagem**; o HUD só é detectado por estatística de pixels no `tools/autopilot.ps1`.
5. Ferramentas citadas no PLAN.md e que **não existem**: `tools/shader_corpus.py` (§9, Fase 4) e `tools/frame_diff.py`
   (§9, Fases 4/6). `tools/check.ps1` não roda nada da suíte além de `boot`.
6. O veredito de cenário (`log_triage.py --scenario`) avalia: marcos esperados, `deadline_ms`, parada do engine (`EXIT`),
   exceção do host, código de saída, `max_vulkan_errors`, `max_growth_mb_per_min` (inclinação da memória privada
   depois de 30 s de aquecimento). Não avalia fps, travadas, pico de memória nem `DES_CRASH`.
7. O resultado `run.json` de uma execução encerrada pelo `soak.ps1` por `taskkill` fica `stopped_by_soak` (o soak
   corrige o rótulo); um crash real com `DES_CRASH` aparece como `crashed_or_error` e o soak sai com código 2.

## 1. Cenários do §8.3

### 1.1 `boot` (automático)

- **Como rodar hoje:**
  `tools\run.ps1 -Scenario boot -Launch game/config/fg-launch.json`
  (equivalente a `-TimeoutSec 150`; grava `captures/runs/<data>-boot/` com `triage.md` e o veredito em `run.json`,
  `scenario_result`). Código de saída 0 passou, 2 reprovou. Sem `-Quiet`, o log do engine cresce rápido; em 150 s é aceitável.
- **Passa se (como está no TOML):** marcos `process_started`, `modules_loaded`, `game_entry`, `flip_1` presentes, todos
  antes de 120 000 ms; nenhuma parada do engine nem exceção do host; processo sem `crashed_or_error`; crescimento de memória
  privada <= 50 MB/min depois de 30 s.
- **Referência de números reais** (`20261023-220041-soak-30m-2`, `20261023-224632-v120-on`): `process_started` 0,7 s,
  `modules_loaded` 3,2 s, `flip_1` 8,6 s.
- **Risco do critério:** a inclinação de memória após 30 s mede carregamento, não vazamento (nas execuções curtas
  ficou em 224 MB/min, `v120-on`). Com `max_growth_mb_per_min = 50` o `boot` de 150 s tende a reprovar por isso, não por
  regressão. Trocar por limite só de pico ou remover o critério de memória neste cenário.
- **Falta:** (a) atualizar `check.ps1` (obsoleto, item 0.1); (b) tirar `trace`; (c) o cenário não exercita nada além do
  primeiro flip: o "critério de regressão" real do engine atual é `flip_600` + fps, ver 1.2.

### 1.2 `title` (automático)

- **Como rodar hoje:** o cenário está `enabled = false`, então `run.ps1 -Scenario title` recusa. Aproximação manual:
  `tools\run.ps1 -Launch game/config/fg-launch.json -Label title -TimeoutSec 300 --vulkan-validation --shader-validation`
  e ler `triage.md` (seção "Validação Vulkan": "Nenhuma mensagem." e marco `flip_600`). Os flags de validação vão no fim
  da linha. Não há medição prévia dessa combinação com o engine FrameGen no registro dos docs.
- **Passa se (PLAN.md):** atinge o marco de título, zero erros de validação Vulkan. **No TOML hoje:** `flip_600` e
  `max_vulkan_errors = 0`, sem marco de título (item 0.4). O `flip_600` ocorre em ~19–22 s (`v120-on`, `soak-30m-2`), mas isso
  é logo/abertura, não a tela de título. Mesmo com o flip, o cenário não prova que a tela de título interativa apareceu.
- **Falta:** emitir um marco de título/menu no engine (`DES_MILESTONE`, por exemplo no primeiro poll de entrada do
  jogo, a escolher) ou detectar o menu por pixels como o autopilot faz (estado `menu` aparece em 44 s em `soak-30m-2`).
  Também confirmar se `--vulkan-validation` é viável com o `fg-launch.json` (o JSON traz `--shader-validation false`,
  e as 56 chaves de desempenho podem mudar o resultado).

### 1.3 `shader-corpus` (automático, local)

- **Como rodar hoje:** não dá. `tools/shader_corpus.py` não existe e o cenário só tem descrição.
- **Passa se (PLAN.md):** 100% do corpus compila e passa `spirv-val`.
- **Falta:** a ferramenta inteira (PLAN.md §9, Fase 4) e um corpus. Pontos de partida existentes: `KYTY_PIPELINE_KEY_LOG`
  (`PIPEKEY` por pipeline fora do cache estático, `knowledge.md`), o cache estático
  `_PipelineCache\static\PPSA01341_01.007.000.*` (6,5 GB; `.shaders` 211 MB) e `captures/shaders/` (nome do PLAN.md; não
  confirmado que o engine FrameGen despeje shaders ali). Atenção: o shader-corpus é derivado do jogo, fica só em
  `captures/`/`out/`. Vulkan SDK 1.4.363 (spirv-val) já instalado.

### 1.4 `charcreate` (manual)

- **Como rodar hoje:** sem save, ou apagando o save em uso: iniciar com
  `tools\run.ps1 -Launch game/config/fg-launch.json -Label charcreate -TimeoutSec 900` e o Ronaldo navega do menu
  (idioma, "novo jogo") até criar personagem. Cuidado: `user/kyty-fg/_SaveData` guarda o save; para não perder, copiar antes
  (o soak usa a cópia `user/saves-backup/kyty-fg-20261023-2050`). O cenário está `enabled = false`, então não se usa `-Scenario`.
- **Passa se:** criação de personagem visualmente correta (personagem, iluminação, texto; M4.2), julgada pelo Ronaldo.
  Registrar o resultado em `docs/PLAYTHROUGH.md` (linha "Seleção de idioma até criação de personagem").
- **Falta:** captura de referência para comparar (screenshot via `tools\screenshot.ps1 -Out captures\...\charcreate.png`
  serve de baseline; `frame_diff.py` não existe); um piloto para o menu de criação (o autopilot só confirma o menu e chega
  ao HUD com save existente). Evidência anterior: Ronaldo chegou à criação em `20261023-171535-bisect2-584c2e8c` (build
  antigo, memória 8,4 GB), sem julgamento visual formal.

### 1.5 `tutorial-10min` (manual)

- **Como rodar hoje:** `tools\run.ps1 -Launch game/config/fg-launch.json -Label tutorial -TimeoutSec 900 -Stats -Quiet`,
  Ronaldo joga 10 min do tutorial (Boletaria, primeira área); se o PC ficar com o Ronaldo, é o único cenário que exige ele.
  Cobertura automática parcial hoje: `tools\soak.ps1 -Minutes 10 -Label tutorial-auto`, que restaura o save de referência
  e anda em loop (frente/trás/câmera), sem combate nem progresso no mapa.
- **Passa se:** 10 min sem crash (sem `DES_CRASH`, sem parada do engine, `run.json` não `crashed_or_error`) e sem
  artefato grave (julgamento do Ronaldo). Sugestão de critérios objetivos que o `triage.md` já reporta: mediana de fps
  >= 55, nenhum `SLOW Frame` >= 5 s fora dos 3 primeiros minutos.
- **Falta:** não está documentado que o save de referência é o tutorial/1-1 (STATUS.md só diz "HUD: no jogo"). Um save no
  início do tutorial (backup em `user/saves-backup/`) e um marco/limiar de "chegou ao HUD". O cenário está desativado
  no TOML.

### 1.6 `soak-nexus-2h` (semi-automático)

- **Como rodar hoje (o mais próximo existente):**
  `tools\soak.ps1 -Minutes 120 -Label soak-2h -Save user/saves-backup/<save-no-Nexus>`
  (usa `fg-launch.json`, `-Stats -Quiet`, vigia de congelamento com `build/sampler/sampler.exe`, miniaturas em `shots/`).
  Variáveis úteis via `-Env @{DES_MEM='1'; KYTY_FAULT_CLASSIFY='1'; KYTY_REDZONE_FAULT_AUDIT='1'}`, como o `nightly.ps1` na
  etapa soak. Também: `tools\nightly.ps1 -SoakMinutes 120` (smoke + janela + 120 Hz + soak, relatório em
  `captures/nightly/<data>/report.md`). Tempo: ~2 h 10 min, usa teclado e foco da janela: ninguém usando o PC.
- **Passa se (PLAN.md §8.3):** 2 h sem crash; memória privada sem crescimento contínuo depois do aquecimento, inclinação
  < 50 MB/10 min (= 5 MB/min, igual ao `max_growth_mb_per_min = 5` do TOML) e **pico < 12 GB**.
  Como o nightly aplica hoje: `completed`, sem `DES_CRASH`, sem `freeze-*.json`, inclinação de `process_private` (`DES_MEM`)
  < 5 MB/min depois dos 10 primeiros minutos.
- **Divergências a resolver:** (a) o pico < 12 GB do PLAN.md **já é violado** por medição: pico 13,19 GB
  (`20261023-220041-soak-30m-2`), 13,99 GB (`fg-sessao1`); plano já pede "revisar com dados": limite sugerido pelos
  dados: pico de 14 GB, ou o platô (12,96 GB do min 15 ao 30). (b) Nenhum critério mede o pico; só a inclinação.
  (c) O soak anda em loop no ponto do save, não "parado no Nexus": o save de referência não é do Nexus.
  (d) Resultado de 2 h ainda não existe; o último longo é 30 min (`soak-30m-2`: sem crash, memória plana, 52 quadros lentos,
  pior 1,9 s) e há `nightly-soak` de 60 min em `20261023-232410-nightly-soak` (sem `triage.md` quando este documento foi escrito).
- **Falta:** um save no Nexus; critério de pico e de fps/travadas no veredito; o `-Scenario soak-nexus-2h` não é
  consumido pelo `soak.ps1` (ele não lê o TOML; o tempo limite do cenário, 7500 s, equivale a `-Minutes 120`).

## 2. Cenários extras que existem nas ferramentas e não estão no §8.3

Candidatos a entrar na suíte (hoje fora do TOML):

| Cenário | Como rodar | Passa se | Origem |
|---|---|---|---|
| `smoke` | `tools\run.ps1 -Launch game/config/fg-launch.json -Label smoke -TimeoutSec 120 -Stats -Quiet` com `KYTY_REDZONE_FAULT_AUDIT=1` no ambiente | sem `DES_CRASH`, marco `flip_600` atingido, sem `RED_ZONE_AUDIT` | nightly etapa 1 |
| `window` (S-001) | `run.ps1` em segundo plano (`-TimeoutSec 600`) e `tools\window-test.ps1 -RunDir captures\runs\<pasta>` | veredito `ok` em `window-test.json`: nenhuma fase com `DES_FPS` < 30, nenhum `SLOW Frame` > 1000 ms, nenhuma fase longa sem `DES_FPS` | nightly etapa 2; FIX-005 |
| `vblank120` | soak de 10 min com cópia do JSON com `--vblank-frequency 120` (nightly cria `build/nightly-launch-v120.json`) | completed, sem `DES_CRASH`, janelas `DES_FPS` > 90 na segunda metade | nightly etapa 3; FIX-009 |
| `perf-ab` | `tools\perf-ab.ps1 -Only base,RB,RBQ,FPS,FPS60 -Minutes 6` | sem critério de passa/falha: relatório comparativo (`captures/perf-ab/<data>/report.md`) | commit `0a54f8b` |
| `capture` | com o jogo aberto pelo `run.ps1`: `tools\capture.ps1 -RunDir captures\runs\<pasta> -Frames 2` | gera `captures.md` com a passada de TAA e as draws no alvo de saída; sem critério automático | commit do `capture.ps1` |
| `ctest` / ferramentas | `tools\check.ps1 -SkipBuild -SkipGame` ou `python -I -m unittest discover -s tests/tools` | testes passam; `ctest` 60/61 (KP-001) | §8.1 |

`nightly.ps1 -DryRun` imprime o plano sem abrir o jogo (permitido a qualquer agente; `-DryRun` também em `perf-ab.ps1`,
`run.ps1` e `launcher.ps1`).

## 3. Quando rodar o quê (§8.3, últimos parágrafos)

| Mudança | PLAN.md pede | Comando de hoje (engine `desport-int`) | Lacuna |
|---|---|---|---|
| `graphics/` | `title` + `shader-corpus` | `smoke` (ou `run.ps1 -Scenario boot -Launch ...`) + `title` manual (1.2) | `shader-corpus` não existe; sugerido acrescentar `window` e um soak de 10 min (`tools\soak.ps1 -Minutes 10`) |
| `kernel/` ou `libs/` | `boot` + `title` + `ctest` | `check.ps1 -SkipBuild` (depois de corrigir o item 0.1) + `title` manual | `check.ps1` só roda `boot` e com o engine antigo |
| lote do upstream (`UPSTREAM_TRIAGE.md`) | soak 30 min + boot até o 1-1 | `tools\soak.ps1 -Minutes 30` | "até o 1-1" não tem critério (não há marco de HUD no engine) |

## 4. O que falta de ferramenta (resumo priorizado)

1. Marco de título/menu e de HUD no engine (ou uma saída do autopilot lida pelo `log_triage.py`): destrava `title`,
   `charcreate`, `tutorial-10min` e o "boot até o 1-1".
2. `check.ps1` e `boot` apontando para o engine atual: usar `-Launch`, tirar a falha esperada, tirar `trace`
   (item 0.1 e 0.3), e ajustar `max_growth_mb_per_min` do `boot`.
3. Veredito de soak: ler pico de memória, mediana de fps e travadas, `DES_CRASH` e `freeze-*.json`
   (hoje o nightly faz isso à parte; o `-Scenario` não) e permitir `soak.ps1 -Scenario soak-nexus-2h`.
4. Saves de partida em pontos conhecidos em `user/saves-backup/` (tutorial 1-1, Nexus), com nome e local registrados.
5. `tools/shader_corpus.py` e `tools/frame_diff.py` (PLAN.md §9), mais um conjunto de screenshots de referência.
6. Relatório consolidado de cenário (hoje há `triage.md` por execução, `report.md` do nightly e `report.md` do perf-ab,
   três formatos).
7. Piloto automático para o menu de criação de personagem e para trocar de modo gráfico (cinematográfico/desempenho)
   se o `PLAYTHROUGH.md` for exigir esses casos de forma repetível.
