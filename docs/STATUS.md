# Estado do projeto

**Fase atual: 0 — Preparação e linha de base** (PLAN.md §6). Iniciada em 2026-10-23.

## Fase 0 — progresso

| # | Tarefa | Estado | Evidência / observação |
|---|---|---|---|
| 1 | Repositório e estrutura | feito (2026-10-23) | `git init` (branch `main`), estrutura da §3, `LICENSE` (texto canônico GPL-2.0, igual ao do bbport, sha256 `edaef632…b233f6`), `.gitignore`, `desport.local.ini.example`, `docs/{STATUS,FIXES,DECISIONS}.md`. |
| — | ADR-000 (bbport) | feito (2026-10-23) | `docs/DECISIONS.md`. |
| 2 | Localizar o dump | **bloqueado: dump não utilizável** | Ver "Dump" abaixo. |
| 3 | Fork do KytyPS5 | feito (2026-10-23) | Submódulo `engine/` → `https://github.com/RonaldoLPFilho/KytyPS5`, branch `desport` a partir de `9dcff95` (ADR-002). Branch publicada no fork em 2026-10-23 (`origin/desport` = `54acdbb`). |
| 4 | Build | feito com ressalvas (2026-10-23) | Release e RelWithDebInfo compilam. `ctest`: 60/61 no Release, 59/61 no RelWithDebInfo (FIX-001; KP-001, KP-002). O critério "passa no `ctest`" não está cumprido por completo. |
| 5 | `tools/run.ps1` v1 | feito (2026-10-23) | Testado sem o jogo (simulado, erros, código de saída, tempo limite com encerramento da árvore). Falta a primeira execução real. |
| 6 | Execuções de linha de base (a/b/c) | pendente | Depende da tarefa 2. Exige o Ronaldo observando a tela. |
| 7 | Relatório de linha de base | pendente | — |

## Dump (tarefa 2) — verificado em 2026-10-23, somente leitura

`D:\demon` contém **apenas** `Demons.Souls-PPSA01341-EUR-v01.007.000.pkg` (53.514.949.630 bytes),
sem `eboot.bin`, `sce_sys/` nem `sce_module/`. Divergências com o plano:
1. **Formato:** pacote com cabeçalho `7F 46 49 48` ("\x7FFIH"). O KytyPS5 só aceita pasta, ELF ou
   `.zar` (`engine/src/common/archive.cpp:95`). Extrair um `.pkg` do PS5 normalmente exige
   descriptografia, proibida no projeto (§1.1.2). Nada além dos primeiros 64 bytes foi lido.
2. **Região:** PPSA01341 (EUR), o plano fixa PPSA01342 (USA).
3. **Versão:** v01.007.000 (com update).

Aguardando o Ronaldo: dump em texto claro (pasta com `eboot.bin`, `sce_sys/param.json`,
`sce_module/`, ou `.zar`), e decisão sobre a região (ADR-001). `desport.local.ini` não foi criado.

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

## Próximo passo concreto
1. Ronaldo: fornecer o dump em texto claro e decidir a região (EUR × USA).
2. (feito) branch `desport` publicada no fork.
3. Agente: validar o dump e escrever o ADR-001; preparar as 3 execuções de linha de base.
