# desport — port nativo do Demon's Souls (PS5) para PC

> Plano mestre para execução com Claude Code. Escrito em 2026-10-23.
> Leia este arquivo inteiro antes da primeira tarefa e releia a seção da fase atual no
> início de cada sessão. O estado vivo do projeto fica em `docs/STATUS.md`, não aqui.

---

## 0. Resumo em uma página

**O que é:** um "Wine + DXVK para um jogo só", no mesmo modelo do bbport (port do
Bloodborne que já roda nesta máquina em `D:\games\bbport-windows`). O executável original
do Demon's Souls de PS5 roda direto na CPU do PC, um runtime implementa só as funções do
sistema do PS5 que o jogo chama, e os gráficos (GPU RDNA 2 do PS5) são traduzidos para Vulkan.

**Jogo alvo:** Demon's Souls (Bluepoint, 2020), **PPSA01341 – EUR, versão 01.007.000**
(ADR-001; o plano original fixava PPSA01342 – USA). A versão foi fixada na Fase 0 lendo
`sce_sys/param.json` e não muda depois disso.

**Base técnica:** [KytyPS5](https://github.com/KytyPS5/KytyPS5) (C++, GPL-2.0-only), commit
de referência `9dcff95` (2026-10-23). Ele tem o papel que o shadPS4 teve no bbport.

**Referência de arquitetura:** bbport 0.4 em `D:\games\bloodborne_pc-0.4`
(upstream: `github.com/deadinside28/bloodborne_pc`). Leitura obrigatória, mapeada na §4.

**Diferença crucial para o bbport:** o bbport conseguiu enxugar um emulador porque o
shadPS4 *já rodava* o Bloodborne. O KytyPS5 ainda *não roda* o Demon's Souls até o fim.
Por isso o plano tem duas trilhas em sequência:

- **Trilha A (Fases 0–5): fazer funcionar.** Fork do KytyPS5 com uma camada própria do
  Demon's Souls, até o jogo ser jogável do início ao fim.
- **Trilha B (Fases 6–7): virar port.** Com o jogo funcionando e com o rastro exato do que
  ele usa, extrair o formato bbport: imagem pré-linkada offline, loader enxuto, runtime
  mínimo e biblioteca gráfica dedicada.

Fazer a Trilha B antes da A seria otimizar algo que ainda não funciona. Não inverta.

**Requisito do produto final (ADR-004):** assim como o bbport-windows, o desport terá
**DLSS** (Super Resolution/DLAA, na versão mais recente, incluindo **DLSS 5**) e **geração de
quadros DLSS** com Reflex; FSR como alternativa fora da NVIDIA. Implementação na Fase 7; as
entradas que o DLSS exige são identificadas já na Fase 4.

**Estimativa honesta:** a Fase 0–1 leva dias; a Fase 3 leva semanas; a Fase 4 (gráficos) é
a mais longa e incerta, com meses; o total até jogável é medido em meses de trabalho
consistente. Cada fase tem critério de saída mensurável para não haver dúvida de onde se está.

---

## 1. Regras invioláveis

Estas regras valem para toda sessão, toda fase, todo commit.

### 1.1 Legal e arquivos do jogo
1. **Nenhum arquivo do jogo entra no repositório.** Isso inclui `eboot.bin`, `.prx`,
   `sce_sys/`, assets, e também **qualquer coisa derivada**: imagens linkadas (`out/*.bin`),
   dumps de shaders do jogo, dumps de command buffers, capturas RenderDoc, texturas, saves,
   caches de shader. Tudo isso vai para `out/`, `user/` ou `captures/`, que ficam no
   `.gitignore` desde o primeiro commit.
2. **Nenhum código de descriptografia.** O projeto só aceita um dump já em texto claro, tirado
   pelo próprio usuário do próprio console. Se uma ferramenta encontrar segmento
   criptografado ou comprimido, ela **para com erro claro** (como o `prepare.py` do bbport faz:
   `encrypted/compressed SELF segment is unsupported`). Não implemente contorno.
3. **Nunca escreva dentro da pasta do dump do jogo.** Ela é somente leitura para o projeto.
   Mods e patches são aplicados em overlay, nunca alterando os originais.
4. **Licença:** o projeto inteiro é **GPL-2.0-only**, porque deriva do KytyPS5 (GPL-2.0-only)
   e reaproveita ideias e possivelmente código do bbport (GPL). Preserve todos os avisos de
   copyright e o `LICENSES/` do KytyPS5. Todo arquivo novo leva cabeçalho SPDX
   `GPL-2.0-only`.
5. Não use nem distribua firmware, bibliotecas do sistema do PS5 ou chaves. Só as bibliotecas
   que **vêm dentro do dump do jogo** (`sce_module/`) podem ser carregadas.

### 1.2 Disciplina de engenharia
6. **Toda alteração em código vindo do KytyPS5 é marcada** com um comentário
   `// desport: <motivo curto>`. Isso é o que torna possível rebasear sobre o upstream e
   saber o que é nosso (o bbport usa `bbport:` e tem 344 marcações assim).
7. **Nenhuma correção sem evidência.** Cada correção registra em `docs/FIXES.md`: sintoma,
   trecho do log ou captura, causa, mudança, e como foi verificada.
8. **Nenhuma regressão silenciosa.** Antes de cada commit em `engine/`, rode a suíte de
   regressão da §8.3. Se não dá para rodar (precisa do jogo aberto com controle), diga
   isso no commit e peça ao Ronaldo para validar.
9. **Uma fase só termina quando o critério de saída está cumprido e registrado** em
   `docs/STATUS.md` com data e evidência (log, screenshot, número).
10. Mudanças de arquitetura viram um ADR curto em `docs/DECISIONS.md`.

### 1.3 Quando parar e perguntar ao Ronaldo
- Qualquer coisa que precise **rodar o jogo de forma interativa** (controle, navegar menus,
  jogar uma área): prepare o comando e o que observar, e peça para ele executar.
- Antes de abrir PR ou issue no KytyPS5 (ver §11: a comunicação lá tem que ser dele).
- Antes de qualquer decisão do portão da Fase 2 (§6.3).
- Quando a pasta do dump, a versão do jogo ou o hardware forem diferentes do esperado.
- Antes de apagar qualquer coisa fora de `out/`, `build/` e `captures/`.

---

## 2. Ambiente

### 2.1 Máquina de desenvolvimento
| Item | Valor | Consequência |
|---|---|---|
| CPU | AMD Ryzen 7 9800X3D (Zen 5) | Executa nativamente as instruções do Zen 2 do PS5 (AVX2, BMI1/2, MOVBE, LZCNT, SSE4a, RDPID, CLWB). O `guestInstructionPatcher` do KytyPS5 deve reportar `trapped = 0`; se não reportar, investigue antes de seguir. |
| GPU | NVIDIA RTX 5080 | Vulkan 1.3 ok. **Atenção:** o modo novo de memória do bbport é só AMD porque o driver NVIDIA não mapeia a memória do jogo como ele precisa. Não dependa de nada desse modo. Teste sempre com driver atualizado. |
| RAM | 32 GB DDR5 | Suficiente. |
| SO | Windows 11 (principal) + Arch Linux/Hyprland (dual boot) | Windows é o alvo primário de build e teste. Linux é secundário: útil para comparar comportamento e porque o bbport é Linux-first. |

### 2.2 Toolchain (Windows) — igual ao exigido pelo KytyPS5
- Git, CMake ≥ 3.22.1, Ninja
- Visual Studio 2022 ou Build Tools 2022 com **Desktop development with C++** e
  **C++ Clang tools for Windows**. **Compilar só com `clang-cl`**; `cl.exe` é rejeitado.
- Qt 6 para MSVC 2022 64-bit (Concurrent, Network, Widgets)
- glslang (`glslangValidator`) no PATH
- Python 3 no PATH
- Vulkan SDK (para `spirv-val`, `spirv-dis` e camadas de validação)
- RenderDoc
- `pre-commit` (hook de clang-format do KytyPS5)

### 2.3 Caminhos
| Nome | Caminho | Observação |
|---|---|---|
| Projeto | `D:\games\desport` | Repositório git deste projeto |
| Dump do jogo | **`DES_GAME_DIR` — a definir na Fase 0** | Pasta com `eboot.bin`, `sce_sys/`, `sce_module/` ou um `.zar`. Somente leitura. |
| bbport (fonte) | `D:\games\bloodborne_pc-0.4` | Referência de arquitetura. Somente leitura. |
| bbport (build Windows) | `D:\games\bbport-windows` | Exemplo de empacotamento Windows. Somente leitura. |

`DES_GAME_DIR` vive em `desport.local.ini` (no `.gitignore`), nunca em código.

---

## 3. Estrutura do repositório

```
desport/
├── CLAUDE.md                 # regras curtas para o agente (aponta para este plano)
├── PLAN.md                   # este arquivo
├── LICENSE                   # GPL-2.0
├── .gitignore                # out/ build/ user/ captures/ *.local.ini dumps
├── desport.local.ini.example
├── engine/                   # fork do KytyPS5 (submódulo apontando para o fork do Ronaldo, branch desport)
├── game/                     # camada específica do Demon's Souls (Trilha A)
│   ├── config/               # flags e defaults do jogo
│   ├── hooks/                # overrides de funções HLE específicos do jogo
│   └── patches/              # patches de memória do jogo (formato do GamePatch do KytyPS5)
├── tools/                    # ferramentas Python/PowerShell (§9)
│   ├── inspect_self.py
│   ├── nid_db.py
│   ├── run.ps1
│   ├── log_triage.py
│   ├── shader_corpus.py
│   ├── frame_diff.py
│   └── soak.ps1
├── port/                     # Trilha B (Fases 6–7): loader, runtime, libdesgpu
├── tests/
│   ├── tools/                # testes das ferramentas Python (pytest, com fixtures sintéticas)
│   └── regression/           # definição da suíte de regressão (§8.3)
├── docs/
│   ├── STATUS.md             # onde estamos: fase, marcos atingidos, próximos passos
│   ├── FIXES.md              # registro de cada correção com evidência
│   ├── DECISIONS.md          # ADRs
│   ├── IMPORTS.md            # matriz de cobertura das funções importadas (gerada)
│   ├── GPU_NOTES.md          # descobertas sobre o pipeline gráfico do jogo
│   └── PLAYTHROUGH.md        # checklist de áreas jogadas e problemas por área
├── out/                      # gerado, ignorado pelo git
├── captures/                 # RenderDoc, dumps de comando, screenshots; ignorado
└── user/                     # saves, caches; ignorado
```

---

## 4. Como o bbport funciona (leitura obrigatória antes da Fase 1)

Leia estes arquivos em `D:\games\bloodborne_pc-0.4` e registre um resumo de 1 parágrafo de
cada em `docs/DECISIONS.md` (ADR-000 "O que aprendemos com o bbport"):

| Arquivo do bbport | O que faz | Equivalente no desport |
|---|---|---|
| `README.md` | Visão geral, tabela "How it differs from shadPS4" | Este plano |
| `docs/EMULATION_REMOVAL_PLAN.ru.md` | Plano de remover a emulação passo a passo (em russo) | Fase 6 |
| `docs/ROADMAP.md`, `docs/history/*` | Histórico real de problemas e soluções (em russo) | Ensina o tipo de bug que vai aparecer |
| `docs/parallel_gpu.md` | Gargalo do thread de GPU e o pipeline de 2 estágios | Fase 7 |
| `scripts/prepare.py` | Lê o SELF **já em texto claro** do PS4 e monta o ELF; recusa segmento criptografado | `tools/inspect_self.py` (Fase 1) e `port/tools/prepare.py` (Fase 6) |
| `scripts/link_modules.py` | Junta eboot + `libc.prx` + `libSceFios2.prx` numa imagem; uma tabela de imports compartilhada; casa exports por (NID, biblioteca, módulo) | `port/tools/link_modules.py` (Fase 6) |
| `scripts/link_libc.py` | Versão anterior, só com libc | Leitura histórica |
| `scripts/patches.py` | Compila patches XML da comunidade no início | `game/patches` + Fase 7 |
| `src/probe.c` | Loader em C: checa CPU, mapeia a imagem, aplica relocações, resolve imports, pula para o jogo | `port/loader/` (Fase 6) |
| `src/runtime.h`, `src/runtime_*.c` | Runtime mínimo: um `*_resolve(nid)` por área (kernel, memory, thread, mutex, rwlock, sema, file, audio, ajm, pad, rtc, savedata, services, content) | `port/runtime/` (Fase 6) |
| `gpu/shadps4/` | Núcleo gráfico do shadPS4 incorporado, com marcações `bbport:` | `port/gpu/` a partir de `engine/src/graphics` |
| `gpu/shim/` | Ponte entre o runtime em C e o núcleo gráfico em C++ (`bbgpu.h`) | `port/gpu/shim/` (`desgpu.h`) |
| `tools/re/` | Scripts de engenharia reversa: grafo de chamadas, tabela de funções Gnm, varredura de PM4 | `tools/` (Fases 1 e 4) |
| `tools/frame.sh`, `shot.sh`, `soak*.sh`, `ab.sh` | Automação: captura de frame, screenshot, teste longo, comparação A/B | `tools/run.ps1`, `soak.ps1`, `frame_diff.py` |

**Diferenças PS4 → PS5 que impedem copiar o bbport direto:**
- Formato do executável: o `prepare.py` do bbport valida o magic de SELF **do PS4**. O do PS5
  é outro. Use o loader do KytyPS5 (`engine/src/loader/elf.cpp`, `elf.h`) como referência de
  formato. **Não invente offsets**: tudo vem de lá, com checagem de limites como no bbport.
- Bibliotecas do sistema: NIDs e funções do PS5 são outras. A fonte de nomes e
  implementações é `engine/src/libs/*.cpp` e `engine/src/kernel/*`.
- GPU: PS4 é GCN/Liverpool com Gnm; PS5 é RDNA 2/Prospero com **AGC**
  (`engine/src/libs/agc.cpp`, `libAgcDriver.cpp`). Os shaders são ISA RDNA 2: referência
  oficial é o *AMD RDNA 2 Shader ISA Reference Guide*, documento 70648.
- Código x86: o PS5 é Zen 2, então pode haver instruções que o PS4 não tinha. O KytyPS5 já
  trata isso em `engine/src/loader/guestInstructionPatcher.*`.

---

## 5. Mapa do KytyPS5 (o que existe e onde)

Commit de referência `9dcff95`, ~167 mil linhas de C++ fora do launcher.

| Pasta | Conteúdo | Relevância |
|---|---|---|
| `src/loader/` | `elf.*` (SELF/ELF), `runtimeLinker.cpp` (linkagem e resolução de NIDs), `loadExec.cpp`, `gamePatch.*` (patches por jogo), `guestInstructionPatcher.*` (instruções e red zone) | Fases 1, 3, 6 |
| `src/kernel/` | memória, pthread, semáforos, event flags/queues, sistema de arquivos, `syncOnAddress` | Fase 3 |
| `src/libs/` | HLE das bibliotecas: `libKernel`, `libC`, `agc`/`libAgcDriver`, `libVideoOut`, `libAudio*`, `ajm/`, `ngs2`, `libPad`, `libSaveData`, `libPlayGo`, `libAppContent`, `libSystemService`, `libUserService`, `libAmpr`, `libUlt`, `avPlayer`, `libVideoDec2`... | Fases 3 e 5 |
| `src/graphics/guest_gpu/` | formatos da GPU do PS5, tiling, `pm4.*`, `command_processor/` (despacho e handlers de pacotes) | Fase 4 |
| `src/graphics/shader/recompiler/` | decodificação RDNA 2 → IR → SPIR-V (`frontend/`, `ir/`, `backend/`) | Fase 4 |
| `src/graphics/host_gpu/` | backend Vulkan: memória, rastreamento de páginas, `renderer/` (render targets, pipelines, compute, sincronização) | Fase 4 |
| `src/graphics/presentation/` | `videoOut`, janela, overlays, RenderDoc | Fase 4 |
| `tests/` | testes de regressão focados (memória, shaders, rastreamento de recursos, sistema de arquivos...) | Toda fase |
| `src/main.cpp` | flags de linha de comando | Ver abaixo |

**Flags de depuração úteis** (de `src/main.cpp`; confirme com `kyty_emulator --help` no commit
em uso): `--game`, `--game-patch`, `--rd` (RenderDoc), `--vulkan-validation`,
`--gpu-assisted-validation`, `--shader-validation`, `--command-buffer-dump`,
`--graphics-debug-dump`, `--spirv-debug-printf`, `--profile`, `--perf-overlay`,
`--readback-linear-images`, `--readback-tiled-images`, `--sync-raw-image-buffers`,
`--playgo-hack`, `--skip-notice-screen`, `--redzone`, `--amd-cpu`, `--no-splash`,
`--screen-width`, `--screen-height`.

---

## 6. Trilha A — fazer funcionar

### Fase 0 — Preparação e linha de base (alvo: 2–4 dias)

**Objetivo:** ambiente montado, KytyPS5 compilando, e uma medição objetiva de até onde o
Demon's Souls chega hoje.

Tarefas:
1. **Repositório.** `git init` em `D:\games\desport`; criar a estrutura da §3, `LICENSE`
   (GPL-2.0), `.gitignore` (§1.1), `desport.local.ini.example` com `DES_GAME_DIR=`,
   `docs/STATUS.md`, `docs/FIXES.md`, `docs/DECISIONS.md` vazios com cabeçalho.
2. **Localizar o dump.** Pedir ao Ronaldo o caminho e gravar em `desport.local.ini`.
   Validar sem modificar nada: existe `eboot.bin` (ou `.zar` com `eboot.bin` na raiz),
   `sce_sys/param.json`, `sce_module/`. Ler de `param.json`: title ID, versão do conteúdo,
   versão do app, região. Confirmar que é `PPSA01341` (ADR-001). Registrar em `docs/STATUS.md`:
   título, versão, tamanho total, lista dos arquivos em `sce_module/` com SHA-256.
   **A versão encontrada passa a ser a versão alvo fixa do projeto** (ADR-001).
3. **Fork do KytyPS5.** O Ronaldo cria o fork no GitHub dele (peça). Adicionar como
   submódulo em `engine/`, criar branch `desport` a partir de `9dcff95`. Registrar em
   ADR-002 o commit base e a política de rebase (§10.3).
4. **Build.** Seguir o README do KytyPS5 para Windows:
   ```
   git submodule update --init --recursive
   cmake -S . -B _Build/windows -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER=clang-cl -DCMAKE_CXX_COMPILER=clang-cl -DCMAKE_PREFIX_PATH="C:/Qt/6.x.x/msvc2022_64"
   cmake --build _Build/windows --target launcher
   cmake --install _Build/windows --prefix _Build/windows/install
   cmake --build _Build/windows --target kyty_tests
   ctest --test-dir _Build/windows --output-on-failure
   ```
   Fazer também um build `RelWithDebInfo` em `_Build/windows-dbg` (é o que vai ser usado para
   depurar). Instalar o hook do `pre-commit`. Registrar versões de todas as ferramentas.
5. **`tools/run.ps1` v1.** Executa `kyty_emulator.exe --game $DES_GAME_DIR` com flags
   configuráveis, tempo limite (padrão 180 s), grava o log completo em
   `captures/runs/<data-hora>/log.txt`, salva o comando exato e o hash do commit do engine
   em `run.json`, e encerra o processo no tempo limite.
6. **Execução de linha de base.** Três execuções, cada uma com as flags anotadas:
   (a) padrão; (b) `--vulkan-validation --shader-validation`; (c) `--command-buffer-dump`.
   O Ronaldo observa a tela e diz até onde chegou (tela preta, logo, intro, menu, criação
   de personagem, jogo).
7. **Relatório de linha de base** em `docs/STATUS.md`: o último ponto atingido, as últimas
   200 linhas relevantes do log, erros de validação agrupados por tipo, funções não
   implementadas citadas no log, se há crash e onde.

**Critério de saída:** KytyPS5 compila e passa no `ctest`; o jogo foi executado nas 3
configurações; `docs/STATUS.md` diz com evidência até onde ele chega.

---

### Fase 1 — Inventário estático (alvo: 1–2 semanas)

**Objetivo:** saber, antes de corrigir qualquer coisa, exatamente o que o jogo pede do
sistema. É a versão PS5 do `out/analysis.json` do bbport.

Tarefas:
1. **`tools/inspect_self.py`** (Python 3, sem dependências externas, como o `prepare.py`):
   - Lê `eboot.bin` e cada `.prx` de `sce_module/`.
   - Valida o formato pelo mesmo critério do `engine/src/loader/elf.cpp`; toda leitura passa
     por uma função `span()` com checagem de limites (copiar o padrão do bbport).
   - **Recusa** segmento criptografado/comprimido com erro claro (§1.1.2).
   - Extrai: cabeçalhos ELF, program headers, segmento dinâmico, tabelas de símbolos
     importados/exportados, nomes de bibliotecas e módulos, TLS, `procparam`, ponto de entrada.
   - Saída: `out/inventory.json` (estrutura documentada no topo do script).
2. **`tools/nid_db.py`**: monta a base de nomes de NIDs a partir do próprio código do
   KytyPS5 (as tabelas de registro em `engine/src/libs/*.cpp` e `engine/src/kernel/*`).
   Para cada NID importado pelo jogo, classifica:
   - `implemented` — tem implementação real no KytyPS5;
   - `stub` — existe mas só retorna OK/zero ou loga "not implemented" (detectar por padrão
     no corpo da função; listar os padrões usados);
   - `missing` — não existe;
   - `provided_by_game_module` — exportado por um `.prx` que vem no dump (como o
     `libc.prx` no bbport) e portanto roda nativo.
3. **`docs/IMPORTS.md` gerado**: uma tabela por biblioteca com NID, nome, status, quem chama
   (endereço das chamadas no eboot), contagem de sítios de chamada. No topo, resumo:
   total de imports, % por status, as 20 bibliotecas com mais `missing` + `stub`.
4. **Varredura de instruções**: usar a lógica do `guestInstructionPatcher` do KytyPS5 (ou
   Zydis via um pequeno executável de ferramenta) para listar instruções que exigem
   tratamento e funções que usam red zone. Na máquina do Ronaldo o esperado é zero
   instruções interceptadas; registrar o resultado.
5. **Grafo de bibliotecas gráficas**: listar todas as funções AGC e VideoOut importadas.
   Elas definem o escopo da Fase 4. Salvar em `docs/GPU_NOTES.md` §"Superfície AGC".
6. **Testes** em `tests/tools/` com arquivos ELF sintéticos montados pelo próprio teste
   (nunca arquivos do jogo).

**Critério de saída:** `docs/IMPORTS.md` gerado e revisado; existe um número para "quantas
funções faltam"; a superfície AGC está listada.

---

### Fase 2 — Fork, camada do jogo e harness (alvo: 1–2 semanas)

**Objetivo:** infraestrutura para iterar rápido e sem regressão.

Tarefas:
1. **Camada `game/`** ligada ao engine por um único ponto de extensão:
   - `game/config/des.toml`: flags padrão para este jogo (ex.: se `--playgo-hack` ou
     `--skip-notice-screen` forem necessários).
   - Mecanismo de override de HLE por jogo: um registro que, na resolução de NIDs do
     `runtimeLinker.cpp`, consulta primeiro `game/hooks/`. Mudança mínima no engine, marcada
     `// desport:`. Equivale à regra do bbport "o runtime pode sobrescrever qualquer função,
     contratos do host primeiro".
   - Patches de memória em `game/patches/` usando o `GamePatch` que já existe no KytyPS5.
2. **Rastreamento de chamadas**: um modo (`DES_TRACE=1`) que registra cada NID chamado com
   contagem e o primeiro instante de uso, gravado em `captures/runs/<id>/calls.json`.
   É isso que vai alimentar a Fase 6 (o runtime mínimo é exatamente o que aparece aqui
   ao longo de uma partida completa).
3. **Marcos automáticos no log** (`DES_MILESTONE <nome> t=<ms>`): processo iniciado,
   módulos carregados, `main` do jogo alcançado, primeiro `VideoOut` flip, N-ésimo flip,
   primeiro arquivo de dado do jogo aberto, primeiro save acessado. Implementar nos pontos
   correspondentes do engine com marcação `desport:`.
4. **`tools/log_triage.py`**: lê um log e produz um relatório curto: último marco, crash
   (endereço, módulo, função mais próxima pelo inventário da Fase 1), NIDs `missing`/`stub`
   efetivamente chamados, erros de validação Vulkan agrupados, avisos repetidos com contagem.
5. **`tools/run.ps1` v2**: aceita `-Scenario` (§8.3), roda `log_triage.py` no final e imprime
   o resumo.
6. **CI local mínimo**: `tools/check.ps1` que roda pytest das ferramentas, build do engine,
   `ctest` do engine e o cenário de regressão automático.

**Portão de decisão (pare e pergunte ao Ronaldo):** com o inventário e a linha de base,
apresentar em `docs/DECISIONS.md` (ADR-003) a estimativa de esforço da Fase 3 e da Fase 4 e
confirmar que a estratégia "fork primeiro, port depois" continua a certa. Se o KytyPS5
upstream estiver avançando rápido no Demon's Souls, considerar contribuir upstream e só
fazer a Trilha B depois.

**Critério de saída:** uma execução produz automaticamente log, marcos, `calls.json` e
relatório de triagem; `tools/check.ps1` passa.

---

### Fase 3 — Boot completo do sistema (alvo: semanas)

**Objetivo:** o jogo sai da inicialização e chega à tela de título com o runtime correto,
independente de a imagem estar perfeita.

**Loop de trabalho (repetir até o critério de saída):**
1. `run.ps1` → `log_triage.py`.
2. Classificar o problema: função faltando, comportamento errado de kernel (memória, threads,
   sincronização), sistema de arquivos/caminho, PlayGo/AppContent, serviço do sistema,
   timeout/deadlock.
3. Reproduzir com o menor caso possível. Se for comportamento de função, escrever um teste em
   `engine/tests/` antes de corrigir quando for viável.
4. Corrigir minimamente: preferir override em `game/hooks/` quando for específico do jogo;
   corrigir no engine quando for bug geral (e anotar como candidato a PR upstream).
5. Registrar em `docs/FIXES.md`, rodar regressão, commit.

Áreas que quase certamente vão exigir trabalho (ordem provável):
- **Memória:** mapeamentos diretos/flexíveis, alinhamentos, proteção de páginas, pools que a
  GPU também enxerga. Compare comportamento com `runtime_memory.c` do bbport (o modelo do
  PS4 é parecido em conceito).
- **Threads e sincronização:** prioridades, afinidade, `syncOnAddress`, event flags/queues.
  Deadlocks aparecem como "parou de logar". Adicione dump de estado de threads ao timeout.
- **Arquivos:** montagem de `/app0`, maiúsculas/minúsculas, `.zar` vs pasta, leitura
  assíncrona, PlayGo (chunks) — teste `--playgo-hack` só como diagnóstico.
- **Serviços:** usuário, sistema, trophies, rede desconectada (o jogo tem modo online; o
  objetivo aqui é ele aceitar estar offline), SaveData.
- **AGC/VideoOut no nível de API:** inicialização, registro de buffers de vídeo, flip.

Marcos e critério de saída (cada um registrado com evidência):
- M3.1 `main` do jogo alcançado sem crash.
- M3.2 primeiro flip de VideoOut.
- M3.3 vídeos de abertura tocam (ou são pulados corretamente) com áudio.
- M3.4 **tela de título interativa** (aceita entrada do controle).

---

### Fase 4 — Gráficos até o jogo (alvo: meses; a fase mais longa)

**Objetivo:** imagem correta do menu ao jogo.

Ferramentas a construir primeiro:
1. **`tools/shader_corpus.py` + modo `DES_SHADER_DUMP=1`**: grava cada shader do jogo
   (binário RDNA 2 + metadados de entrada) e o SPIR-V gerado em `captures/shaders/`, com
   hash. Ferramenta offline que recompila o corpus inteiro com o recompilador do engine e
   roda `spirv-val`. Saída: lista de shaders que falham ao compilar, que falham na validação,
   ou que usam instruções sem tradução. Esse corpus é o teste de regressão mais valioso do
   projeto (só roda localmente: os shaders são derivados do jogo, §1.1.1).
2. **Capturas de referência:** como não há console para comparar pixel a pixel, use como
   referência: (a) screenshots/vídeos do próprio Ronaldo jogando no PS5 nos mesmos pontos;
   (b) consistência entre frames; (c) erros de validação zerados.
3. **`tools/frame_diff.py`**: compara screenshots de duas execuções do mesmo cenário (antes e
   depois de uma mudança) e marca regressões visuais acima de um limiar.

Ordem de ataque:
1. Zerar erros de `--vulkan-validation` e `--shader-validation` na tela de título.
2. Corpus de shaders sem falhas de compilação/validação para tudo o que aparece até a
   criação de personagem.
3. Pacotes de comando: todo pacote não tratado logado com contagem
   (`engine/src/graphics/guest_gpu/command_processor/`). Tratar por frequência.
4. Formatos e tiling de texturas e render targets (`gpu_format.*`, `tile.*`): conferir cada
   formato usado contra a documentação da ISA e o comportamento observado.
5. Sincronização GPU/CPU: fences, rótulos de fim de pipe, esperas do jogo pela GPU. Bugs aqui
   aparecem como travamento intermitente ou corrupção. O histórico do bbport (ver correção do
   crash após 13–17 min por rótulos EOP fora de ordem no `ROADMAP.md`) mostra o tipo de
   problema.
6. Compute: o jogo certamente usa compute para efeitos e pós-processamento.
7. Cada efeito com problema vira uma entrada em `docs/GPU_NOTES.md` com captura RenderDoc
   (`--rd`), o draw/dispatch responsável e a hipótese.
8. **Entradas temporais para DLSS/geração de quadros (ADR-004).** Com uma captura RenderDoc
   do 1-1, localizar e registrar em `docs/GPU_NOTES.md` §"Entradas temporais": o render target
   de cor da cena antes da interface (formato, resolução, HDR ou não), a profundidade (formato,
   invertida ou não), os vetores de movimento do próprio jogo (se existem, formato, escala,
   sinal, se cobrem objetos animados), o jitter subpixel e onde ele é aplicado, as matrizes de
   câmera (atual e anterior), o passe de TAA/reconstrução do jogo (que o DLSS substituirá) e os
   passes de interface (para separar o HUD na geração de quadros). Onde algo faltar, anotar
   como será calculado, seguindo `docs/motion_vectors.md` do bbport.

Marcos e critério de saída:
- M4.1 tela de título correta.
- M4.2 criação de personagem correta (personagem, iluminação, texto).
- M4.3 tutorial (Boletaria, primeira área) jogável com imagem correta.
- M4.4 Nexus correto.
- M4.5 30 minutos contínuos no 1-1 sem crash e sem artefato grave.
- M4.6 entradas temporais catalogadas (tarefa 8), com captura de referência e a decisão do
  que é aproveitado do jogo e do que precisa ser calculado.

---

### Fase 5 — Jogável do início ao fim (alvo: meses)

**Objetivo:** o jogo inteiro funciona, com áudio, controle e saves.

Tarefas:
1. **Áudio:** música, efeitos e vozes corretos; sem estalos; sincronia com cutscenes.
   Bibliotecas prováveis: `ajm`, `ngs2`, `audio`, `audio3d` (confirmar pelo inventário).
2. **Entrada:** controle via SDL3 (DualSense e Xbox), teclado. Mapear vibração e gatilhos
   adaptativos se o engine suportar; senão degradar com elegância.
3. **Saves:** criar, carregar, sobrescrever, múltiplos personagens; saves sobrevivem a
   reinício. Pasta `user/savedata/`.
4. **Cutscenes/vídeo:** `avPlayer`/`libVideoDec2`.
5. **`tools/soak.ps1`:** sessões longas automáticas (ficar parado no Nexus, andar em loop
   simples com entrada sintética se possível), registrando memória, FPS e crashes.
6. **`docs/PLAYTHROUGH.md`:** checklist por área com status (não testado / ok / problema):
   Nexus; Palácio de Boletaria 1-1, 1-2, 1-3, 1-4; Stonefang 2-1, 2-2, 2-3; Torre de Latria
   3-1, 3-2, 3-3; Santuário das Tempestades 4-1, 4-2, 4-3; Vale da Corrupção 5-1, 5-2, 5-3;
   finais. Cada problema tem link para uma entrada em `FIXES.md` ou issue aberta.
7. Modos gráficos do jogo: o Demon's Souls de PS5 tem modo cinematográfico (4K/30) e modo
   desempenho (60 fps). Testar os dois; o modo 60 fps é o alvo padrão.

**Critério de saída:** jogo zerado de ponta a ponta pelo Ronaldo sem bloqueio; `soak.ps1`
roda 2 horas sem crash; todas as áreas `ok` ou com problema conhecido não bloqueante.

---

## 7. Trilha B — virar port (no estilo bbport)

Só começa com a Fase 5 concluída. A essa altura existe `calls.json` de partidas completas:
a lista exata e final de funções do sistema que o jogo usa.

### Fase 6 — Remoção da emulação

**Objetivo:** reproduzir a arquitetura do bbport: imagem pré-linkada offline, loader
pequeno, runtime só com o necessário, gráficos como biblioteca dedicada.

Tarefas:
1. **ADR-010:** escrever, em português, o equivalente ao `EMULATION_REMOVAL_PLAN.ru.md` do
   bbport adaptado ao PS5, com a lista de passos e como cada um é verificado.
2. **`port/tools/prepare.py` e `link_modules.py`:** adaptar os do bbport ao formato do PS5,
   reaproveitando o parser da Fase 1. Juntar eboot e os módulos do `sce_module/` que o jogo
   carrega numa imagem com tabela de imports única; exports casados por
   (NID, biblioteca, módulo). Saídas em `out/`.
3. **`port/loader/`:** loader em C no padrão do `probe.c`: checagem de CPU, mapeamento da
   imagem, relocações, TLS, `procparam`, resolução de imports contra o runtime, entrada.
4. **`port/runtime/`:** um arquivo por área no padrão `runtime_<área>.c` com
   `runtime_<área>_resolve(nid)`, implementando **somente** os NIDs de `calls.json`. Portar a
   lógica a partir do que foi corrigido no engine durante a Trilha A. Qualquer NID chamado e
   não implementado aborta com mensagem clara (nunca retorna sucesso falso).
5. **`port/gpu/` (`libdesgpu`):** incorporar `engine/src/graphics` como o bbport incorporou
   o núcleo do shadPS4, com ponte C (`desgpu.h`) para o runtime.
6. **Paridade:** para cada cenário de regressão, comparar fork (Trilha A) e port (Trilha B):
   marcos atingidos, screenshots via `frame_diff.py`, uso de memória, FPS. A Trilha B só
   substitui a A quando houver paridade em todos os cenários.

**Critério de saída:** `desport.exe` roda o jogo inteiro com paridade com o fork.

### Fase 7 — Desempenho e extras

1. Perfil de CPU e GPU (`--profile`, Tracy se disponível). Medir antes de otimizar.
2. Pipeline de GPU em mais de um thread, se o thread de comandos for o gargalo, seguindo
   `docs/parallel_gpu.md` do bbport.
3. **DLSS e geração de quadros (requisito, ADR-004).** Integração nativa no renderer, no
   modelo do `bbport_dlss.dll` do bbport-windows (não por injeção ReShade):
   - DLSS Super Resolution e DLAA na versão mais recente disponível, **incluindo DLSS 5**;
     presets selecionáveis; a resolução interna da cena muda e a interface continua na
     resolução de saída.
   - **Geração de quadros DLSS** com multiplicador (geração de múltiplos quadros na RTX 5080),
     opção de ajustar à taxa do monitor, e **Reflex** ligado sempre que a geração estiver ativa.
     A apresentação (`videoOut`) precisa intercalar os quadros gerados e controlar o ritmo.
   - FSR 3.1/4 como alternativa fora da NVIDIA (mesmas entradas).
   - Entradas vindas da Fase 4 (M4.6). Configuração no ini do desport com as mesmas chaves do
     bbport-windows (`upscaler`, `preset`, `frame_gen`, `frame_gen_multiplier`,
     `frame_gen_fit_display`).
   - Antes de começar, verificar e registrar em ADR: APIs suportadas pelo DLSS 5 (Vulkan ×
     D3D12), suporte da geração de quadros em Vulkan via Streamline/NGX, e a licença de
     redistribuição das DLLs da NVIDIA (componentes separados, nunca no git).
   - Critério: DLSS SR, DLAA e geração de quadros funcionando no 1-1 e no Nexus, sem artefatos
     graves de HUD ou de objetos em movimento, com FPS e latência medidos com e sem cada opção.
4. **Remoção do limite de FPS (pedido do Ronaldo, 2026-10-23):** sem teto fixo (ilimitado ou até
   a taxa do monitor, configurável no ini), via patch, verificando lógica de jogo amarrada a frame
   (física, animação, timers, input) e a compatibilidade com a geração de quadros e o Reflex.
5. **Suporte a 3440x1440 / 21:9 (pedido do Ronaldo, 2026-10-23):** resolução de saída e de render
   ultrawide, com campo de visão correto (sem esticar nem cortar), HUD e menus ancorados ou
   centralizados em 16:9, cutscenes com pillarbox se quebrarem fora de 16:9. Exige achar a
   projeção e o layout da interface no jogo (Fase 4 já separa cena e interface, M4.6).
6. Launcher e empacotamento Windows (referência: `D:\games\bbport-windows`), com checagem
   de versão do jogo, CPU e GPU na abertura, como o bbport faz.

---

## 8. Verificação

### 8.1 Por commit
- Build sem warnings novos no código `desport:`.
- clang-format via pre-commit.
- pytest das ferramentas.

### 8.2 Por correção
- Entrada em `docs/FIXES.md` com evidência antes/depois.

### 8.3 Suíte de regressão (cenários)
Definidos em `tests/regression/scenarios.toml`. Cada cenário: flags, tempo limite, marcos
esperados, e se é automático ou exige o Ronaldo.

| Cenário | Tipo | Passa se |
|---|---|---|
| `boot` | automático | atinge M3.2 (primeiro flip) em < 120 s, sem crash |
| `title` | automático | atinge marco de título, zero erros de validação Vulkan |
| `shader-corpus` | automático, local | 100% do corpus compila e passa `spirv-val` |
| `charcreate` | manual | criação de personagem visualmente correta |
| `tutorial-10min` | manual | 10 min no tutorial sem crash |
| `soak-nexus-2h` | semi-automático | 2 h no Nexus sem crash; memória do processo (privada) sem crescimento contínuo: após o aquecimento, inclinação < 50 MB/10 min e pico < 12 GB (limites iniciais, revisar com dados) |

Engine com mudança em `graphics/`: rodar `title` + `shader-corpus` no mínimo.
Engine com mudança em `kernel/` ou `libs/`: rodar `boot` + `title` + `ctest`.

---

## 9. Ferramentas (especificação)

| Ferramenta | Entrada | Saída | Fase |
|---|---|---|---|
| `tools/run.ps1` | cenário/flags | `captures/runs/<id>/` com log, `run.json`, resumo | 0, 2 |
| `tools/inspect_self.py` | dump do jogo | `out/inventory.json` | 1 |
| `tools/nid_db.py` | `engine/src`, inventário | `out/nid_status.json`, `docs/IMPORTS.md` | 1 |
| `tools/log_triage.py` | log de execução | relatório curto (stdout + `triage.md`) | 2 |
| `tools/shader_corpus.py` | `captures/shaders/` | relatório de compilação/validação | 4 |
| `tools/frame_diff.py` | 2 pastas de screenshots | diferenças acima do limiar | 4, 6 |
| `tools/soak.ps1` | duração, cenário | métricas de memória/FPS/crash | 5 |
| `tools/check.ps1` | — | roda tudo o que é automático | 2+ |

Regras para as ferramentas: Python 3 sem dependências externas sempre que possível;
toda leitura de binário com checagem de limites; mensagens de erro dizem o que fazer; nada
escreve fora de `out/`, `captures/` ou `docs/` (gerados).

---

## 10. Convenções

### 10.1 Git
- Branch `main` do desport; branch `desport` no fork do KytyPS5.
- Commits pequenos e com escopo: `engine: ...`, `game: ...`, `tools: ...`, `docs: ...`,
  `port: ...`. Corpo do commit cita a entrada de `FIXES.md` quando houver.
- Nunca `git add -A` sem conferir o `.gitignore` contra dados do jogo.

### 10.2 Código
- No engine: seguir o estilo do KytyPS5 (clang-format do repositório).
- Toda mudança no engine marcada `// desport: <motivo>`.
- Código novo do port (Trilha B): C para loader/runtime como no bbport; C++ só na parte gráfica.

### 10.3 Atualização do upstream
- A cada 2–4 semanas, ou quando o upstream corrigir algo do Demon's Souls: rebasear a
  branch `desport` sobre o `main` do KytyPS5, rodar a suíte de regressão inteira, registrar
  o novo commit base em `docs/DECISIONS.md`. As marcações `desport:` tornam os conflitos
  localizáveis.

---

## 11. Contribuições para o KytyPS5

Correções gerais (não específicas do Demon's Souls) são boas candidatas a PR upstream, o que
reduz o trabalho de rebase. Regras do próprio KytyPS5 que precisam ser seguidas:
- PR focado em **um problema concreto de um jogo específico**, com nome do jogo, problema
  exato e evidência. PRs genéricos, refatorações e mudanças grandes misturadas são fechados
  automaticamente.
- **IA pode ajudar, mas o Ronaldo tem que entender, revisar e testar tudo**, e a comunicação
  (descrição do PR, comentários) tem que ser dele, não de um agente. Declarar o escopo do uso
  de IA e o teste feito.
- Portanto: o agente prepara o patch isolado, a evidência e um rascunho de anotações em
  `docs/upstream/<nome>.md`; **o Ronaldo escreve e envia o PR**.
- Relatórios de compatibilidade usam o template "Game Emulation Status Report" com o log
  completo.

---

## 12. Riscos conhecidos

| Risco | Impacto | Mitigação |
|---|---|---|
| Recompilador de shaders/GPU do KytyPS5 imaturo para este jogo | Fase 4 muito longa | Corpus de shaders + validação desde cedo; atacar por frequência; acompanhar upstream |
| Driver NVIDIA com comportamento diferente de AMD em mapeamento de memória | Bugs só nesta máquina | Rodar sempre com `--vulkan-validation`; registrar em `GPU_NOTES.md` todo comportamento que dependa do fabricante; não depender do modo AMD do bbport |
| Upstream muda arquitetura e quebra o fork | Rebase caro | Mudanças pequenas e marcadas; overrides em `game/` em vez de editar o engine |
| Sem console para referência visual | Bugs gráficos sutis passam | Screenshots/vídeos do Ronaldo no PS5 nos mesmos pontos |
| Bugs de sincronização intermitentes | Crashes após muitos minutos | `soak.ps1` desde a Fase 4; logs de fences/rótulos |
| Questões legais | Projeto derrubado | §1.1 sem exceções; nada do jogo no repositório |
| **Vazamento de memória** (ponto de atenção do Ronaldo: um port comunitário do Demon's Souls chegou a ~30 GB de RAM) | Jogo trava ou derruba o PC em sessões longas; esta máquina tem 32 GB | Toda execução do `run.ps1` grava pico e curva de memória (`memory.csv`) desde a Fase 0; a Fase 2 adiciona ao `log_triage.py` o crescimento por minuto; o `soak.ps1` reprova crescimento contínuo; caches do engine (texturas, buffers, pipelines, memória do jogo mapeada) precisam de limite e liberação, como o bbport fez com texturas/buffers ociosos (README do bbport); cada caso vira entrada em `FIXES.md` com a curva antes/depois |
| DLSS 5 / geração de quadros podem não ter caminho Vulkan direto (o add-on de terceiros do bbport-windows usa D3D12 e travou nesta máquina) | Requisito do ADR-004 mais caro | Verificar o SDK antes da Fase 7; se preciso, ponte Vulkan↔D3D12 própria com imagens compartilhadas, medida e testada; DLSS SR/geração de quadros nas versões com Vulkan como piso |
| Interface misturada à cena no quadro do jogo | Artefatos no HUD com geração de quadros | Separar os passes de interface na Fase 4 (M4.6), como o bbport faz com o UI em resolução de saída |

---

## 13. Primeira sessão do Claude Code (roteiro)

1. Ler `CLAUDE.md` e este `PLAN.md` inteiro.
2. Ler os arquivos do bbport listados na §4 (pelo menos `README.md`, `scripts/prepare.py`,
   `scripts/link_modules.py`, `src/runtime.h`, início de `src/probe.c`) e escrever o ADR-000.
3. Executar as tarefas 1 a 5 da Fase 0.
4. Parar e pedir ao Ronaldo: (a) o caminho do dump, (b) a criação do fork no GitHub,
   (c) que ele observe a tela nas execuções de linha de base.
5. Ao fim da sessão: atualizar `docs/STATUS.md` com o que foi feito, o que falta na fase e o
   próximo passo concreto.
