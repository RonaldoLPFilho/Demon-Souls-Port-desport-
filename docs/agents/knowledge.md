# Base de conhecimento

Fatos verificados. Cada item diz de onde veio; "hipótese" quando não foi testado no jogo.

## Alvo e máquina
- Jogo: Demon's Souls PS5, PPSA01341 EUR 01.007.000 (ADR-001). Dump em `C:\games\DemonsSouls-PPSA01341` (só leitura).
- PC: RTX 5080, Ryzen Zen 5 com 8 núcleos e 16 threads, monitor de 143–144 Hz (Windows informa 143).
- Meta: estabilidade no nível do bbport (Bloodborne); DLSS 4.5 (DLL 310.x, não DLSS 5); geração de quadros;
  fps sem teto; ultrawide 3440x1440 nativo; pré-compilação de shaders; launcher no estilo do bbport.

## Engine
- Base desde o ADR-008: KytyPS5-DemonsSouls-FrameGen v1.3 (ceremony88, GPL-2.0) sobre o upstream `f2455c87`.
  Fork: `github.com/RonaldoLPFilho/KytyPS5`. Integração: branch `desport-int` (worktree `build/fg-int`).
- Compilação (só o coordenador; só clang-cl):
  `$env:KYTY_CMAKE_ARGS='-DDESPORT_GAME_DIR=D:/games/desport/game'; cmd.exe /c "D:\games\desport\build\fg-int\build-windows.cmd"`.
- Pontos fortes do FrameGen: draws XPR nativos, thread de gravação Vulkan, fila de readback, JIT de SRT,
  PGO/ThinLTO, ~56 chaves de ambiente em `game/config/fg-launch.json`, cache estático de pipelines
  (`_PipelineCache\static\PPSA01341_01.007.000.*`, 6,5 GB, ligado por junction em `user/kyty-fg`).
- Streamline SDK 2.14.1 em `build/fg-port/_Build/deps/streamline/sdk`; `nvngx_dlss` 310.9.1.
- FFmpeg ligado estático ao exe (prebuilt do shadPS4, série 7.1, LGPL 2.1+).

## Variáveis de ambiente (desport)
- Medição: `DES_FPS` (sempre ligado, janela de 5 s), `DES_FRAME` (desport-perf; histograma em vblanks,
  percentis, esperas da thread de render, caches; `DES_FRAME=0` desliga), `DES_STATS=1` (`DES_STAT`,
  `DES_STAT_ADDR`), `DES_SLOW` (chamada ≥1 s), `DES_MEM`, `DES_CRASH` (`DES_CRASH_DIR`),
  `KYTY_FAULT_CLASSIFY=1` (`DES_FAULTS`), `KYTY_REDZONE_FAULT_AUDIT=1`.
- Diagnóstico do FrameGen: `KYTY_HITCH_LOG_MS` (padrão 100 no JSON; linhas `SLOW Frame`),
  `KYTY_PIPELINE_KEY_LOG` (basta existir; `PIPEKEY` por pipeline fora do cache estático),
  `KYTY_GPU_WRITE_WATCH=<hexini>-<hexfim>` (sem 0x), `KYTY_SYNC_STACK` (só leituras da thread de GPU).
- Cache do driver: `KYTY_DRIVER_CACHE_KEY` = exatamente 64 hex minúsculos (sha256 do exe); senão desligado.
  Fica em `<work_dir>\_PipelineCache\local\<chave>\PPSA01341.bin`. run.ps1 e launcher definem sozinhos.
  Com a chave, `KYTY_SHADER_WARMUP=1` também passa a agir.
- Janela e vídeo: `KYTY_ACQUIRE_TIMEOUT_MS`, `KYTY_MOVIE_PACING` (vídeos no ritmo certo com vblank 120).
- Fps: `KYTY_FPS_LIMIT` (desport-fps): ausente = atual; `0` = sem limite; `<n>` = 20–1000; `display`.
  Injeta os convars `gameMinDeltaTime=0.001;gameDeltaTimeCorrectionTolorance=0.1` (`KYTY_FPS_GAME_CONVARS`
  troca; `0` remove). Nunca usar tolerância 0 (o laço do jogo trava).
- DLSS: `KYTY_DLSS=off|dlaa|quality|balanced|performance|ultra_performance`, `KYTY_DLSS_PRESET`.
  Com DLSS: present-id ligado e teto de espaço de endereços `0xE000000000` (sem isso, `vkCreateDevice` falha).
- Ultrawide: `KYTY_ULTRAWIDE=<LxA>`, `KYTY_ULTRAWIDE_RENDER=1`, `KYTY_ULTRAWIDE_HUD=native|16x9`,
  `KYTY_ULTRAWIDE_MOVIES=pillarbox|stretch`, `KYTY_ULTRAWIDE_HUD_LAYOUT=16x9` (desport-uw2).
- Geração de quadros: `KYTY_FRAMEGEN=<n>`. Fase B (`desport-dlssb`, em `desport-next`): SR + DLSS-G + Reflex juntos, log `DES_DLSS ... combined=<0|1> streamline=<estado>`. Com SR+FG há um índice de quadro por quadro do jogo, viewport 0 para os dois, e o `slSetConstants` vem do SR. `slGetNewFrameToken` avança um anel de 6 posições se o índice muda: constantes e tags valem pelo índice, não pelo ponteiro.
- Camadas Vulkan de overlay quebram o Streamline: `DISABLE_RTSS_LAYER=1`, `DISABLE_VULKAN_OBS_CAPTURE=1`,
  `DISABLE_VK_LAYER_VALVE_steam_overlay_1=1`, `EOS_OVERLAY_DISABLE_VULKAN_WIN64=1`.
- Canal ao vivo: `KYTY_LIVE_FILE` (run.ps1 define; `tools/capture.ps1` escreve comandos de captura).

## Descobertas do jogo
- Ritmo: o jogo não limita o fps (convar `TargetFramesPerSecond` = 0), mas o passo de tempo tem piso de
  1/59,94 s (`gameMinDeltaTime=-1` = igual ao esperado). Acima de 60 fps o jogo **acelera** (hipótese forte,
  leitura estática; o ceremony88 também anota). Física com passo fixo de 60 Hz.
- TAA: compute shader `0xa44e580f4f0cfb2b`, saída 2560x1440 (= resolução de render). O upscale para 4K é
  uma passada separada, ainda não localizada (bloqueia o DLSS de upscale real).
- Vídeos: o contador de .bk2 abertos volta a 0 antes do HUD (nightly-v120: último `off` em 37,7 s, HUD em 61,3 s); nenhum vídeo segura o ritmo no gameplay. `DES_VBLANK movie_pacing` só é logado com vblank ≥100 Hz.
- Layout da UI: função do retângulo localizável pela assinatura `c5 fb 10 4f 04 c5 fa 10 57 14 8b 07 c5 fa 16 c1`.

## Desempenho (2026-10-23, análise em `captures/perf-analysis-20261023.md`)
- Vblank 120: média de 68 fps, p1 de 58. Causa provável do teto: ~80 leituras síncronas por quadro
  (`ReadMemory`, memória escrita pela GPU). A latência sobe de 0,44 para 0,91 ms quando o fps sobe, ou seja,
  a thread de render serializa. Ponto quente em 0x220a00000–0x220a70000. Solução em `desport-rb` (`KYTY_READBACK_PREFETCH=1`, padrão desligado): copia logo depois do escritor os blocos de 64 KiB que o guest lê e serve a leitura desse snapshot. Linha `DES_READBACK` a cada 5 s; validar com `KYTY_READBACK_QUEUE=3` (`READBACK_QUEUE_MISMATCH`). Causa: os rótulos EOP/WRITE_DATA são escritos pela CPU ao processar o pacote, antes de a GPU terminar, então cada leitura faz submit e espera a fila inteira.
- Travadas: 46 de 51 vêm de compilação de pipeline. O cache estático não cobre tudo e o cache do driver
  estava desligado. Concentradas nos primeiros ~2,5 min de cada área.
- GPU perto de 20%: o gargalo é CPU.

## Ferramentas (`tools/`)
- `run.ps1` (execução instrumentada, `-Launch <json>`, `-Stats`, `-Quiet`, `-DryRun`), `soak.ps1`,
  `nightly.ps1`, `autopilot.ps1`, `perf-ab.ps1` (experimentos A/B → `captures/perf-ab/`), `capture.ps1` mais
  `capture_report.py` (captura de quadro e cadeia pós-TAA), `screenshot.ps1`, `launcher.ps1`, `package.ps1`.
- `log_triage.py`: gera `triage.md` por execução; é a biblioteca de leitura das linhas DES_*.
  Não duplicar o parser.
- Saídas derivadas do jogo ficam em `captures/`, `user/` e `out/`, todas fora do git.

## Upstream (cherry-pick para o FrameGen)
- Os testes de `tests/` do upstream não casam com a base do FrameGen (SDL2, sem ZArchive). Em conflito, use `git checkout --ours` nos `tests/`.
- O FrameGen reimplementou capacidade de SaveData, `ClampRangeSize` em `FindBuffers`, `VirtualRanges` em árvore e fibras por thread. Commits do upstream nesses pontos tendem a conflitar.
- AMPR: a reescrita em threads (`5bf9218b`, `c045f089` e seguintes) é tudo ou nada. Ela conflita com o `SlowLog` e com o porte do `41beda43` em `libAmpr.cpp`.
- Lote B em `desport-up4` (6 commits; JpegDec/JpegEnc com `stb_image_write.h`; mutex FIFO `f5ec99fd`: se houver deadlock ou queda de fps, reverter esse primeiro).

## Regressão e marcos
- `run.ps1 -Scenario X` sem `-Launch game/config/fg-launch.json` usa o engine antigo; `tools/check.ps1` está assim e com falhas esperadas obsoletas.
- Marcos DES_MILESTONE: `process_started`, `modules_loaded`, `game_entry`, `first_data_file`, `first_savedata_mount`, `flip_1/60/600/3600`. Não há marco de título, menu ou HUD (o autopilot detecta o HUD por pixels).
- O save de referência `user/saves-backup/kyty-fg-20261023-2050` está provavelmente na primeira área do jogo (tutorial de Boletaria), segundo o Ronaldo ("acho"), sem confirmação por captura.
- Pico de memória medido: 13,2–14,0 GB (platô de ~13 GB). O limite de 12 GB do PLAN §8.3 precisa ser revisto.
- `KYTY_FPS_LIMIT` conta sempre flips (quadros renderizados). Só `display` com DLSS-G divide a taxa do monitor por `FrameGen::PresentedFrames()` (desport-next `7358db0d`).
- C++ gerado por Bash/heredoc já quebrou `\n` dentro de string literal (window.cpp do up4): antes de entregar, rode um varredor de strings sem fechamento.
- O CMake do engine não usa `-Werror`. Os alvos `add_kyty_full_emulator_test` são EXCLUDE_FROM_ALL; `virtual_memory_allocation_tests` não compila na desport-next (falta `GuestBackingStore::MapFixed`).
