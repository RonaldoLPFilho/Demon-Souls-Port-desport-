# Triagem do upstream para o desport-fg (2026-10-23)

Upstream KytyPS5 `f2455c87..upstream/main` (946 commits) contra a base do ADR-008 (`desport-fg`).
Conflito estimado por `git apply --check` em desport-fg e em f2455c87 (baixo = aplica limpo; alto =
aplica em f2455c87 e falha no desport-fg, ou seja, conflito real com o ceremony88). Relatório de agente.

## Não trazer
- `c2173801` (quebra o jogo, ADR-007) e o que vem depois nos mesmos arquivos do recompilador:
  `e9bcc77e`, `ac3711ce`, `de81300b`, `09c993df`, `b2d3ce6d`, `c571d8ed`, `6e516759`, `2d00e13b`, `aafe014d`;
  heap bindless `27dc7c28`, `38c884e8`, `f9e14084`, `719c4431`.
- `6409be28`, `e5dcfdb8`, `68d0ba5a`: introduzem/ajustam os `EXIT` "scalar resource reads ..." de
  `descriptors.cpp`, ausentes no desport-fg. Se um dia vierem, viram aviso.
- NGS2 (o jogo não importa), outros jogos/plataformas, e o já coberto pelo ceremony88 (ZArchive, UTF-8,
  HDR, `c1dccd7d`).

## A — trazer já (lotes)
1. **Threads/kernel:** `47b26e49`, `733842ca`, `18a1e0fa` (deadlock na entrega de exceções), `afbb322b`,
   `f3c82a31`, `4e14eed7`, `7b7f9a70`, `be9e1391` (LOGF fora de linha, pilhas de fibra); depois `e87fb8c8`
   (mutex FIFO) isolado.
2. **Libs:** `4865dd92` (sceNpGetAccountLanguage2, cita o Demon's Souls), `05f92b64` (travamentos do
   SaveDataDialog), `1d2f59df` e `1cc0ac7e` (Ajm), `0f3674f5`, `7675579e` (fsync do save), `de626649`,
   `a107d1e3`, `0e8ded37` (resize ≤0 ao minimizar), `3c62359e`.
3. **GPU (pequenos):** `d63fb623` (interrupções de compute assíncrono), `7e89b97d`, `59a17604`, `9229c04e`
   (limites de LOD bias/anisotropia na NVIDIA), `440245f6`.
4. **Libs faltando:** `ba0e93da` (JpegEnc/JpegDec; o jogo importa 4 funções JpegEnc ausentes).

## B — avaliar
- AMPR (60 funções usadas): cadeia até `41beda43` (perda de conclusão de APR em leituras de 768 bytes:
  risco de travar streaming), com `5bf9218b`, `c045f089`, `5a880808`, `da9b38af`, `e43aadf7`, `f4075517`,
  `deb45a8b`, `259a40ab`.
- AudioOut2: `c86c8b4d` → `b46eeb78` (contextos que travam uns aos outros); `313b60e9`, `70a475ec`, `7855c980`.
- Fibras `71f52f9d` → `ded69649`; memória `0382d0ca`, `46900d80`, `b2fdad9e`, `c30ac7c9`; idle `6f24b031`
  (comparar com o `demonsSoulsIdle` do ceremony88).
- PM4/sincronização (`79120d53`, `629ae1ac`, `099de8de`, `840b9f57`, `70668fbd`, `a358b847`, `e6fce45d`,
  `dc40478e`, `6aaa5332`) e renderer (`18a5f04d`, `3fad77fd`, `8502d8a7`, `cd4eab9d`, `e6cb880a`, `86414760`,
  `c437de97`, `01992958`): só com captura e comparação; ficam para o rebase futuro.

Cada lote: soak de 30 min + boot até o 1-1; registro em FIXES.md.

## Lote B (2026-10-23, branch `desport-up4`, worktree `build/fg-up4`, base `desport-int` f504a246)
Universo: 945 commits sem merge em `f2455c87..upstream/main` (fetch de hoje), menos os já trazidos (lotes A, 21 `-x` e portes
manuais). Conflitos em `tests/` foram resolvidos ficando com a versão do desport-int (os testes do upstream são de outra
base, SDL3/ZArchive, e não compilam aqui); conflitos em `src/` só quando triviais. Nada foi compilado.

### Trazido (6 commits, branch `desport-up4`)
| Upstream | Local | Classe | Motivo |
|---|---|---|---|
| `49b2eedd` Fix command buffer capacity calculation | `1d59d5a7` | B | `GetAvailableSizeDW` do AGC: distância de cursores com sinal, sem truncar em 32 bits. Limpo. |
| `8b095cae` perf(files): move directory-entry names | `3e0046f6` | B | Menos cópias ao listar diretório. Limpo. |
| `c30ac7c9` memory: avoid redundant Windows view protection | `1c05b1ee` | B | Evita `VirtualProtect` redundante em `ReplacePlaceholderView`. Só o `tests/` conflitou (resolvido, ficou o nosso). |
| `e87fb8c8` kernel: hand guest mutex ownership to FIFO waiters | `f5ec99fd` | B (era A, "isolado") | Mutex do guest com entrega FIFO (justiça/sem roubo de posse). Só o `tests/` conflitou. Risco: mexe no caminho quente de pthread. |
| `e6cb880a` (parte) ignore unopenable gamepads | `e7ceb36d` | B (porte manual SDL2) | `EXIT_NOT_IMPLEMENTED(pad == nullptr)` abortava o emulador com controle que não abre; agora loga e ignora. A parte do clamp de LDS não foi trazida (ver C). |
| `ba0e93da` libs: JpegDec e JpegEnc | `259355fb` | B (porte manual) | O jogo importa funções JpegEnc ausentes. Arquivos `libJpegDec.cpp`/`libJpegEnc.cpp` iguais ao upstream + registro em `libs.cpp` + `3rdparty/stb/stb_image_write.h` (do upstream) + o `#define STB_IMAGE_IMPLEMENTATION` saiu de `window.cpp` para `libJpegDec.cpp`. Testes do upstream não trazidos. |

`0f3674f5` (ftruncate/descritor) já estava equivalente em desport-int (cherry-pick vazio).

### C — avaliar depois (conflito arriscado ou precisa de captura/teste)
- **AMPR (cadeia 41beda43 já portada à mão):** `5bf9218b` aplica limpo mas só é o 1º de uma reescrita (fila única ordenada +
  `CommandEngine` com threads em `c045f089`); `c045f089`, `da9b38af`, `deb45a8b`, `e43aadf7`, `5a880808`, `f4075517` conflitam
  com o `SlowLog`/porte do desport e com a `variant` do FrameGen em `libAmpr.cpp`. Trazer só `5bf9218b` deixaria a cadeia
  pela metade, então nenhum entrou. Reavaliar como porte manual único se o streaming mostrar perda de conclusão.
- **Memória:** `b2fdad9e`, `0382d0ca`, `46900d80`, `259a40ab` (e `1ffaaa96`, `f7ae86c9`, `7e011fa5`): conflitam com `VirtualRanges` em
  árvore, `BackingWriteFence` e `MapsErase` do ceremony88/desport-mem. Só com revisão do mapa de memória e soak.
- **Fibras:** `71f52f9d`, `ded69649`: conflitam com o controle de dono de fibra por thread do FrameGen em `libKernel.cpp`
  (`g_fiber_owner_thread`, `FiberSetCurrentFiber`); ambos são correções de migração de thread, relevantes se houver crash de fibra.
- **GPU:** `4644c529` (zerar tabela BDA antes do 1º registro; o hunk de `bufferCache.cpp` entra, `commandScheduler.cpp`
  conflita com o gravador por thread `t_recorder` do FG), `cd4eab9d` (FG já tem `ClampRangeSize` em `FindBuffers`),
  `8502d8a7` (FG só pede `eSampled` para block; sem o ramo de storage), `e6cb880a` (clamp de LDS: `GetComputeProgram` do FG tem
  assinatura própria; sem evidência de LDS > limite no jogo), `3fad77fd`/`18a5f04d` (readback 64 MiB), DCC/stencil/CMASK
  (`01df42a5`, `ea092a94`, `437e69ef`, `7b5a33f8`, `968cf3c0`, `3f80151a`), PM4/sync (`79120d53`, `629ae1ac`, `099de8de`, `840b9f57`,
  `70668fbd`, `a358b847`, `e6fce45d`, `dc40478e`, `6aaa5332`): só com captura e comparação de imagem.
- **Áudio:** `c86c8b4d`, `b46eeb78`, `313b60e9`, `70a475ec`, `7855c980` (AudioOut2/mix): sem evidência de que o Demon's Souls
  use AudioOut2; mexe na cadência de áudio. Avaliar se houver estalo/travamento de áudio.
- **Idle/kernel:** `6f24b031` (sleep curto bloqueante): comparar com o `demonsSoulsIdle` do ceremony88. Libkernel extras
  (`a0858abe` AIO em lote, `e7cfe5a2`, `92c22d60` timers periódicos, `5766b241`, `048fe9f4` ftruncate): só se um import faltar.

### Não trazer
- `8dc9b9d5`, `569ec04d` (SaveData): o FrameGen reimplementou capacidade/espaço livre (`ReadSaveDataCapacity`); conflito direto.
- `b9a0bd27` (formato do log de tempo, só cosmético), `db41d048` (fcntl/close-on-exec, sem uso), `199d0a9d` (nome de thread, só Linux),
  `3c62359e` (efeito de gatilho DualSense), tudo de launcher, VR/HMD, DualSense/haptics, troféus, DLC, self-updater,
  Nix, splash, NGS2, rede P2P/HTTP de outros jogos (`cbedf570`, `12ca1599`, `56d03f16`...).
- Reescrita do recompilador de shader e do renderer (centenas de commits `shader:`/`graphics:` de bindless, tessellation,
  RDNA2 FP64, refactors de IR): ver "Não trazer" acima (`c2173801` e cadeia); o restante só entra com o rebase futuro.

Cada lote: soak de 30 min + boot até o 1-1; registro em FIXES.md. Status do lote B: 6 commits em `desport-up4` (não
compilado, não testado, não mesclado em `desport-int`).
