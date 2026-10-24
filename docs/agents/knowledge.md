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

## Readback: medições de 2026-10-24 (perf-ab, vblank 120)
- Base: 68,8 fps, a maioria dos quadros leva 2 vblanks, p50 de 14,5 ms. A thread de render tem ~7 ms ociosos por quadro, então não é ela o gargalo.
- Prefetch 1 (blocos de 64 KiB): sem ganho, só ~10% de acertos.
- Prefetch 2 (por faixa, desport-rb2): os acertos sobem muito (hits 8,7 mil e vizinhos 13 mil por 5 s), mas o fps não muda (68,7). Um acerto custa ~12 µs, só que o resto das leituras espera a GPU por ~3 ms. `sync_age` mostra que o guest lê <250 µs depois do label (que a CPU escreve cedo), com a GPU ainda 1–3 ms atrás.
- Prefetch 3 (devolução antecipada mais flush no EOP): pior (67,7 fps; cpu da render 9,2 ms).
- Conclusão: o teto de ~70 fps é a latência de ida e volta CPU→GPU→CPU nas ~84 leituras por quadro (resultados de 16 bytes de dispatches pequenos), não a vazão. Próximas ideias: reduzir a latência de submit/execução desses dispatches (fila de compute dedicada, submit imediato só dos dispatches cujo resultado o guest lê, ou executar esses dispatches pequenos na CPU). Padrão: prefetch desligado.
- Sem limite (vblank 60 + `KYTY_FPS_LIMIT=0`, com a correção do .bk2 ocioso): 71,7 fps, p50 de 13 ms. Limite 60: 59,9. Wave64 e vblank 240: sem diferença. Cache do driver frio: 60 fps nos primeiros minutos; quente: 68.
- O SpeedProbe (diff de imagem) deu ~44 em todos os modos: não serve para detectar aceleração. Precisa de conferência visual.
- Boot a frio pode falhar com "could not reserve 13824 MB": falta commit (pagefile de 24 GB, ~38 GB comprometidos com o PC ocioso). O soak espera 15 GB livres.
- Latência medida (KYTY_READBACK_LATENCY=1, desport-lat): por espera, submit 7 µs, worker 40 µs e **GPU 2,7 ms**, com `lat_gpu_backlog` em torno de 23 submissões na frente na GPU. ~3.500 de 10.700 esperas passam de 4 ms. O gargalo é a fila única: os anéis de compute do guest esperam atrás do trabalho gráfico. O yield (modo 2) não ganha nada (68 fps); com prefetch 2 fica pior. Próximo passo: uma `VkQueue` de compute de verdade para as submissões de compute do guest.
- Captura ultrawide (`captures/runs/20261024-040425-uw-capture/capture-1/captures.md`, menu/vídeo, HUD=native):
  - `#255` ps `a6b124d2b1ba4b7e` desenha na camada de UI 3440x1440 (`2824c0000`) amostrando uma RGBA16F 3840x2160. Foi esse que o pillarbox casou; provável superfície do vídeo de fundo.
  - `#257` ps `37db6bd367380e9c` compõe a cena (`2bc030000`, 3440x1440) num alvo 3840x2160 A2B10G10R10. É a passada final de saída e candidata ao ponto do DLSS de upscale real.
  - Nas capturas de tela, o vídeo ocupa a faixa esquerda de 2560 px dos 3440.
- Fila de compute separada (`KYTY_ASYNC_COMPUTE=1`, desport-acq, já em desport-int): 72,3 fps contra 70,4 da base, dentro do ruído de ±1,5. Uns 25% dos candidatos vão para a fila async, mas `rb_async=0`: as leituras do guest não vêm desses dispatches (`lat_async` ~3%). A cpu da thread de render sobe para 9–11 ms, porque perde o caminho de tabela. Os bloqueios são `fb_images`, `fb_dma` e `fb_dep_open` (dep_backlog ~19). Padrão: desligado.
- Hipótese seguinte: ~35 mil submissões a cada 5 s (~100 por quadro). Cada fronteira de submit/barreira `eAllCommands` drena a GPU, então ~23 submissões na frente × ~120 µs dão ~2,7 ms. Medir com timestamps de GPU por submissão (tempo ocupado contra lacunas).
- Chaves do FrameGen (perf-ab, com LATENCY=1): base 68,8. `KYTY_FRAME_PIPELINE=0` dá 32,9 (essencial, não desligar). `KYTY_DEFERRED_SUBMIT=0` dá 60,6. `KYTY_DISPATCH_BATCH=32` dá 70,2 (ruído). `KYTY_DISPATCH_BATCH=512` trava em 60,1 com a thread de render quase sem trabalho (cpu 1,4 ms; algo errado, não usar).
- **Timestamps de GPU (`KYTY_GPU_TIMESTAMPS=1`, desport-gts) mudaram o diagnóstico:** a GPU fica **82% ocupada** (busy 4,1 s a cada 5 s). O "~20%" do gerenciador de tarefas engana. São ~106 submissões por quadro, com busy médio de 120 µs (p50 21 µs, p95 537 µs, máx 5,3 ms) e lacunas de só 26 µs em média. O jogo está limitado pela GPU (trabalho traduzido caro), não por latência de fila.
- O agrupamento (`KYTY_SUBMIT_COALESCE=1`) baixa de 106 para 36 submissões por quadro (3 ticks por chamada), mas o fps não muda (68–70) e a utilização vai a 86%: confirma o limite de GPU. Padrão: desligado.
- Próximo passo: perfil de tempo de GPU por shader (draw/dispatch) para achar os shaders traduzidos mais caros, e reduzir o trabalho (resolução de render ou dinâmica do jogo, DLSS de upscale real, otimização do recompilador nos shaders do topo).
- **Perfil por shader:** a execução `20261024-061422-perf-ab-PROF` é **inválida**. O autopilot deu HUD falso aos 5,3 s e o jogo ficou no vídeo do título a 60 fps. O "GPU parada ~75%" estava errado: GTS e PROF concordam quando rodam juntos. Em gameplay vale GTS 82–89%, limite de GPU. Sempre confira que houve gameplay: ~25 mil `DES_STAT readback` a cada 5 s e fps acima de 60 com vblank 120. As execuções R1080/R720 também são suspeitas.
- Esperas de uma submissão gráfica: só binding esparso (`MakeResident`) e timeline async. Não há cadeia escondida (desport-wait `4cca362f`, `KYTY_GPU_TIMESTAMPS=2` com a linha `DES_GPU_WAIT`).
- **Perfil válido em gameplay** (`captures/runs/20261024-063926-perf-ab-PROF/gpu-prof.md`, HUD aos 55 s, 27 mil leituras a cada 5 s, 67 fps): GPU ocupada 12,4 de 14,9 ms por quadro (GTS 89%, esperas ~0: `DES_GPU_WAIT waited_pct=1`, só o present). O limite é trabalho real de GPU. Por quadro, dispatches somam ~6,4 ms e draws ~3,1 ms. O topo é pulverizado (top 25 = 48%; o maior leva 5%). **Quase todo compute é `64e`**: wave64 emulado com 2 lanes GCN por invocação na NVIDIA, metade das threads e pouca ocultação de latência. Alavanca sistêmica: wave64 mais eficiente no recompilador (detecção de lane-local mais ampla, ou 64 invocações reais com trocas entre lanes via subgroup/LDS).
- **Resolução de render (perf-ab, válido; gameplay confirmado por ~30 mil leituras a cada 5 s):** 2560x1440 dá 64,9 fps (GPU 90%), 1920x1080 (via `KYTY_ULTRAWIDE=1920x1080` + `RENDER=1` + `HUD=native`) dá **86,2** (GPU 80%), 1280x720 dá 94,3 (o autopilot não reconhece o HUD em 720p, mas houve gameplay). O DLSS de upscale real é a maior alavanca de fps.
- **Wave64 lockstep** (`KYTY_WAVE64_MODE=1|2`, desport-w64): o teste offline (`lane_local_tests -m 1 -g 64`, sobre `out/shaders/g64` extraídos com `tools/shader_corpus.py`) aprova 12 dos 16 shaders do topo, mas no jogo dá 70,3/70,4 fps contra 71,1 da base: as barreiras compensam. Com DLSS upscale (render 960p), DUQW deu 109 contra 98,9 do DUQ (a confirmar; pode ser ruído). Padrão: desligado.
- **DLSS upscale** (`KYTY_DLSS_UPSCALE=1`, desport-dlssu): render 1704x960 dá 98,9 fps e 1280x720 dá 109,1 (base 71). Mas a composição #225 (ps `95318d27a44b0dd5`) escreve na resolução de render ("kept"), e o upscale render→saída acontece depois. Hoje é render baixo esticado, sem reconstrução do DLSS. Continuação em andamento.
- **DLSS com upscale real FUNCIONA** (`KYTY_DLSS_UPSCALE=2`, desport-dlssu `041a73f7`, em desport-int `62228e13`). A composição #225 é regravada na resolução de saída a partir da imagem do DLSS, e a passada final em gameplay (ps `1ad8b5870fe4d3ec`, não a 37db do menu) amostra essa composição ("substituted by the output-size composite"). Resultado: quality (1704x960 → 2560x1440) dá **99,5 fps**; performance (1280x720 → 1440p) dá **111,7**; nativo 1440p dá 71. Sem crash. Para ativar: `KYTY_DLSS=<modo> KYTY_DLSS_UPSCALE=2 KYTY_ULTRAWIDE=<janela> KYTY_ULTRAWIDE_RENDER=1 KYTY_ULTRAWIDE_HUD=native`. Pendente: validar a imagem, o sinal do jitter, o LOD bias negativo e o DLSS-G combinado.
