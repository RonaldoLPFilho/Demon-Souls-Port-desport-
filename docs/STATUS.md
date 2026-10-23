# Estado do projeto

**Fase atual: 0 — Preparação e linha de base** (PLAN.md §6). Iniciada em 2026-10-23.

## Fase 0 — progresso

| # | Tarefa | Estado | Evidência / observação |
|---|---|---|---|
| 1 | Repositório e estrutura | feito (2026-10-23) | `git init` (branch `main`), estrutura da §3, `LICENSE` (texto canônico GPL-2.0, igual ao do bbport, sha256 `edaef632…b233f6`), `.gitignore`, `desport.local.ini.example`, `docs/{STATUS,FIXES,DECISIONS}.md`. `engine/` ainda não existe (depende da tarefa 3). |
| — | ADR-000 (bbport) | feito (2026-10-23) | `docs/DECISIONS.md`. Lidos: README, EMULATION_REMOVAL_PLAN, ROADMAP, parallel_gpu, prepare.py, link_modules.py, patches.py, runtime.h, probe.c (início), runtime_kernel.c (início). |
| 2 | Localizar o dump | **bloqueado: falta o caminho** | Pedir ao Ronaldo o `DES_GAME_DIR`. |
| 3 | Fork do KytyPS5 | **bloqueado: falta o fork** | O upstream `KytyPS5/KytyPS5` está hoje exatamente em `9dcff95` (2026-10-23 09:51 +0200, "shader: fix crash from packed ancillary used as DPP old operand (#1769)"), conferido por clone só-leitura. |
| 4 | Build | **bloqueado: toolchain ausente** | Ver "Toolchain" abaixo. |
| 5 | `tools/run.ps1` v1 | feito (2026-10-23) | Testado sem o emulador: modo simulado, erro sem dump, erro sem exe, código de saída repassado (`cmd /c exit 7` → `crashed_or_error`, 7), tempo limite com encerramento da árvore de processos (3 s, nenhum filho órfão), pastas com nome repetido no mesmo segundo. Falta a primeira execução real. |
| 6 | Execuções de linha de base (a/b/c) | pendente | Depende de 2, 3, 4. Exige o Ronaldo observando a tela. |
| 7 | Relatório de linha de base | pendente | — |

### Descobertas da sessão
- **O KytyPS5 não grava log nenhum por padrão**: `printf_direction` padrão é `Silent`
  (`src/common/emulatorConfig.h:81`), e o logger inteiro segue essa opção
  (`src/common/logging/log.cpp:162`). O `run.ps1` passa sempre
  `--printf-direction File --printf-output-file captures/runs/<id>/log.txt`. O valor do enum
  diferencia maiúsculas (`File`, via `magic_enum`).
- O `--game` aceita pasta, ELF ou arquivo compactado com `eboot.bin` na raiz (`src/main.cpp:248`).
- Existe build sem Qt (`-DKYTY_BUILD_LAUNCHER=OFF`, alvos `kyty_emulator` e `kyty_tests`).
  Como o `run.ps1` chama o `kyty_emulator` direto, o Qt só é necessário para o launcher.
- O CI do KytyPS5 usa Qt 6.10.3 `win64_msvc2022_64` e glslang via vcpkg.

## Toolchain (verificado em 2026-10-23, `tools/setup-toolchain.ps1 -CheckOnly`)

| Item | Estado |
|---|---|
| Git | 2.55.0.windows.5 |
| Python | 3.15.0 |
| winget | disponível |
| Build Tools 2022 + Clang tools (`clang-cl`) | **falta** |
| CMake ≥ 3.22.1 | **falta** (winget: 4.4.4) |
| Ninja | **falta** (winget: 1.13.2) |
| Vulkan SDK (glslangValidator, spirv-val, spirv-dis, validação) | **falta** (winget: 1.4.363.0) |
| RenderDoc | **falta** (winget: 1.46.0) |
| pre-commit | **falta** (pip) |
| Qt 6 (só launcher) | **falta**, opcional |

Instalação: `tools/setup-toolchain.ps1` num PowerShell como administrador (`-WithQt` para o Qt).

## Próximo passo concreto
1. Ronaldo: rodar `tools/setup-toolchain.ps1` como administrador.
2. Ronaldo: informar o caminho do dump (`DES_GAME_DIR`).
3. Ronaldo: criar o fork do KytyPS5 no GitHub dele e passar a URL.
4. Agente: validar o dump (tarefa 2, ADR-001), submódulo + branch `desport` (tarefa 3,
   ADR-002), build Release e RelWithDebInfo + `ctest` (tarefa 4).
5. Execuções de linha de base com o Ronaldo observando (tarefa 6).
