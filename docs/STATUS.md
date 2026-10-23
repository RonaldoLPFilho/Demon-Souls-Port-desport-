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
| 6 | Execuções de linha de base (a/b/c) | pronto para rodar | `run.ps1 -DryRun` monta o comando com o dump e o executável instalado. Exige o Ronaldo observando a tela. |
| 7 | Relatório de linha de base | pendente | — |

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

## Próximo passo concreto
1. Ronaldo: confirmar o ADR-001 (alvo EUR PPSA01341 01.007.000) e se o `IMPORTS.md` pode ir
   para `docs/`.
2. Ronaldo + agente: execuções de linha de base (tarefa 6), uma por vez, com o Ronaldo dizendo
   até onde a tela chegou.
3. Agente: relatório de linha de base (tarefa 7) e fechamento da Fase 0.
