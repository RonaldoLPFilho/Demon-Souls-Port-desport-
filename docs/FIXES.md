# Registro de correções

Cada correção (PLAN.md §1.2 regra 7) entra aqui antes do commit, no formato:

```
## FIX-NNN — título curto (AAAA-MM-DD)
- Fase / área:
- Sintoma:
- Evidência antes (trecho de log, captura em captures/…, número):
- Causa:
- Mudança (arquivos, marcação `// desport:`):
- Verificação (como, e evidência depois):
- Candidato a upstream: sim/não
```

## FIX-001 — `vdecsw_tests` não compila no Windows (2026-10-23)
- Fase / área: 0 / testes do engine (`engine/tests/VdecswTests.cpp`).
- Sintoma: `cmake --build _Build/windows --target kyty_tests` falha; é o único erro do build
  inteiro (`-k 0`, 1205 passos).
- Evidência antes (`build/build-release-k0.log`):
  `tests\VdecswTests.cpp(62,38): error: no member named 'aligned_alloc' in namespace 'std';
  did you mean '_aligned_malloc'?`
- Causa: a STL da Microsoft não implementa `std::aligned_alloc` (C11/C++17), porque o `free`
  do CRT não libera memória alinhada. O CI do upstream no Windows compila só um subconjunto
  dos testes (`.github/workflows/build.yml:115`), sem o `vdecsw_tests`, e por isso o erro não
  aparece lá.
- Mudança: no `_WIN32`, `_aligned_malloc(size, 256)` e `_aligned_free` no destrutor;
  as outras plataformas ficam iguais. Duas marcações `// desport:`.
- Verificação: build completo sem erros; `ctest` → `vdecsw ... Passed` (antes nem compilava).
  Total: 60 de 61 testes passam; a falha restante (`kernel_file_system`) não tem relação com
  esta mudança (ver STATUS.md, "Problemas conhecidos").
- Candidato a upstream: sim (correção pequena de portabilidade; só se o Ronaldo quiser abrir).

## FIX-002 — Jogo para em 3–7 s: revert de `c2173801` do upstream (2026-10-23)
- Fase / área: 3 / recompilador de shaders (`ResourceMaterialization.cpp`, `SrtWalker.cpp`).
- Sintoma: `EXIT` em `descriptors.cpp:969`, "scalar resource reads overlap a shader buffer write",
  no ~111º pipeline de compute (CS `0x02632cb15eb8128d`).
- Evidência antes: `captures/runs/20261023-181455-bisect2-c2173801` (parada a 7,2 s, 111 pipelines
  de compute); o mesmo em `9dcff95` (`9f88043e`, `890393fb`, `22ef16a0`, `0caf4a6a`).
- Causa: regressão do upstream. Bissecção em 9 passos (`build/bisect-final.log`): primeiro commit
  ruim `c2173801` ("shader: skip resources in proven empty unsigned loops"); o pai `56d03f16` é bom.
  O commit põe `ULessThan32` no plano de recursos e faz `x < 0u` valer falso com `x` desconhecido,
  o que muda a análise de alcançabilidade usada pela checagem.
- Mudança: revert do commit inteiro (código e teste), com três marcações `// desport:` (ADR-007).
- Verificação: `9dcff95` + revert passa do ponto do bloqueio (135 pipelines de compute em 180 s, sem a
  checagem; `captures/runs/*-bisect2-9dcff95e`). Build do engine e `ctest`: ver STATUS.md.
- Candidato a upstream: sim, como issue (`docs/upstream/c2173801-demons-souls.md`); a correção certa
  é do autor da análise, o revert é só nosso.

## FIX-003 — O jogo gravava o próprio log dentro da pasta do dump (2026-10-23)
- Fase / área: 3 / sistema de arquivos (`engine/src/emulator.cpp`).
- Sintoma: um `logs/demonssoul_ps5_*.log` novo na pasta do dump a cada execução (21 em
  `D:\demon\Demon\logs` em 2026-10-23), contra a regra de dump somente leitura (CLAUDE.md).
- Evidência antes: `log.txt` de `captures/runs/20261023-175642-desport584-boot`:
  `path = /hostapp/logs/demonssoul_ps5_...log` → `Create: D:/demon/Demon\logs/...`. O KytyPS5 monta
  `/hostapp` na pasta do jogo (`emulator.cpp`).
- Causa: o executável é um build com log de desenvolvimento em `/hostapp/logs`.
- Mudança: `/hostapp/logs` montado em `_HostAppLogs` da pasta de trabalho antes de `/hostapp`
  (`MountPoints::ResolvePath` fica com o primeiro que casa); uma marcação `// desport:`. O `run.ps1`
  move esses logs para `captures/runs/<execução>/game_logs/` e a triagem extrai os tempos de
  inicialização do motor do jogo (`ResourcePool::GatherResourceFileInfo`, `Starting main loop`).
- Verificação: ver STATUS.md (execução depois da correção sem arquivo novo em `<dump>\logs`).
- Candidato a upstream: talvez (qualquer jogo com log em `/hostapp` escreve na pasta do jogo).

## FIX-004 — Fault-around nas leituras de memória escrita pela GPU (2026-10-23)
- Fase / área: 4 (desempenho) / cache de buffers (`engine/src/graphics/host_gpu/renderer/cache/bufferCache.cpp`).
- Sintoma: a 4,5 fps, ~86 ms por quadro em leituras síncronas: a cada fault da CPU numa página de
  4 KiB modificada pela GPU, o emulador drena a fila inteira da GPU e baixa só aquela página.
- Evidência antes: `captures/runs/20261023-195130-sessao-cache` (`-Stats`): por quadro, 217 leituras
  da CPU (68 ms), 108 escritas da CPU em páginas da GPU (18 ms), 323 esperas pela GPU, 386 envios
  de fila. O fault do host informa 1 byte (`RenderContext::HandleFault`).
- Causa: `BufferCache::ReadMemory` baixava e desprotegia só a página do fault; ler um buffer escrito
  pela GPU custava uma drenagem por página.
- Mudança: baixa de uma vez todas as páginas modificadas pela GPU numa janela alinhada de 1 MiB em
  volta do acesso (limitada ao buffer); `DES_FAULT_AROUND=0` volta ao comportamento do upstream.
  Uma marcação `// desport:` (engine `17950146`).
- Verificação: menu (60 fps, sem parada) 13,6 → 7,8 leituras por quadro. Jogo
  (`captures/runs/20261023-200042-sessao-faultaround`): esperas 323 → 135, envios 386 → 197, escritas 108 → 5,
  leituras 217 → 139 (68 → 58 ms), bytes baixados 0,9 → 12 MB por quadro; **fps 4,50 → 4,64**.
  O quadro continua dominado pela avaliação de recursos (~110 ms). Imagem sem anomalia relatada.
- Candidato a upstream: sim (PR pequeno, com a chave e os números); a janela pode ser ajustada.

## FIX-005 — Jogo congela com a janela minimizada, coberta ou sem foco (S-001) (2026-10-23)
- Fase / área: 5 (estabilidade) / apresentação (`engine/src/graphics/presentation/window/*`).
- Sintoma: congelamento de 30,25 s (soak `20261023-213716-soak-10m-1`, 1 perda de foco) e de ~200 s
  (`20261023-215258-soak-30m-1`, 117 falhas de foco), com a thread de renderização ociosa; volta a 60 fps
  quando a janela reaparece.
- Causa: o flip só é aposentado depois de um present bem-sucedido, na thread de vblank
  (`videoOut.cpp` PresentThread → `FlipQueue::Flip` → `Presenter::Present`); com a janela minimizada ou
  coberta o driver bloqueia acquire/present, o vblank para, a fila de flips enche e o jogo espera. O engine
  não tratava janela minimizada (só logava os eventos).
- Mudança (branch `desport-s001`, `8c950579`, em `desport-int`): estado `minimized`/`surface_dirty` da
  janela; com a janela minimizada o flip é aposentado sem acquire/present; recriação do swapchain ao
  restaurar e nunca com extensão 0x0; acquire com tempo limite de 100 ms (`KYTY_ACQUIRE_TIMEOUT_MS`) que
  descarta o quadro em vez de bloquear; logs `DES_WINDOW`. Marcado `// desport: S-001`.
- Verificação: `tools/window-test.ps1` em `captures/runs/20261023-224236-int-window`: 60 fps nas fases
  minimizada (20 s), 20 ciclos minimizar/restaurar e coberta; pior quadro 464 ms ao restaurar. Veredito ok.
- Candidato a upstream: sim.

## FIX-006 — DLSS SR: `vkCreateDevice` falha com `ErrorInitializationFailed` e o processo cai em `vulkan-1.dll` (2026-10-23)
- Fase / área: 4 (gráficos) / DLSS Super Resolution fase A (`engine/src/local/frame-gen.cpp`,
  `engine/src/kernel/memoryAddressSpace.inc`); branch `desport-dlss` (`8e6980b5`) e dois commits em `desport-int`.
- Sintoma: com `KYTY_DLSS=quality` e sem `KYTY_FRAMEGEN`, o jogo cai em 2–4 s, antes de qualquer marco, com
  `0xc0000005`; com camadas de overlay (RTSS, OBS) a queda vem do tratamento de erro delas.
- Evidência antes: `captures/runs/20261023-225137-dlss-q1` (6,2 s), `...-225345-dlss-verbose` (3,6 s),
  `...-225553-dlss-nolayers` e `...-225707-dlss-fix1` (3,9 s): todas `crashed_or_error`, código -1073741819, minidump
  na pasta; as de `q1`, `verbose` e `fix1` têm `DES_CRASH ... module=vulkan-1.dll+0x4d4c1`. O log da `-dlss-verbose`
  mostra o Streamline acrescentando `VK_NVX_binary_import` e `VK_NVX_image_view_handle` ao `vkCreateDevice`.
  Controle: `...-225206-fg-only` (só geração de quadros, sem DLSS SR) roda 41 s sem queda.
- Causa: (1) `FrameGen::Requested()` (que liga o present-id) só considerava `KYTY_FRAMEGEN`; os plugins comuns do
  Streamline habilitam `VK_NV_low_latency2` também para o DLSS SR, que exige present-id (`9eb1fa99`, sozinho
  não bastou: `fix1` ainda cai — a atribuição `fix1` = esse commit é inferida da ordem das execuções, o `run.json`
  só guarda o hash do exe). (2) Causa principal (`f5f44f50`): as extensões NVX fazem a inicialização CUDA/NGX
  reservar espaço de endereços do host abaixo de 1 TiB ao criar o dispositivo; o espaço de endereços do guest
  ocupava os 40 bits inteiros, exceto com `KYTY_FRAMEGEN`/`KYTY_FRAMEGEN_RUNTIME_TOGGLE` (`KYTY_RESERVE_CEILING`,
  padrão `0xE000000000`, mais o `LocalDriverHole` até o `vkCreateDevice`). Só com `KYTY_DLSS` o driver não achava
  espaço e devolvia `ErrorInitializationFailed`.
- Mudança (marcadas `// desport:`): `8e6980b5` (DLSS SR no lugar do dispatch de TAA, fase A); `9eb1fa99`
  (`Requested()` inclui `g_sr_mode != 0`); `f5f44f50` (`KYTY_DLSS` diferente de off/0 aplica o mesmo teto
  `0xE000000000` e o buraco do driver, com log).
- Verificação: `captures/runs/20261023-230538-dlss-fix2`: `DLSS: guest address space stops at 0xe000000000`,
  `DLSS: Super Resolution ready, mode quality`, slots (cor 0, saída 6, profundidade 1, vetores 3), preset 4.5 (M),
  sem `DES_CRASH`; 6 janelas de fps, mediana 60,0, em 46 s (fim por timeout, sem queda). Limites: execução curta, só
  1 quadro upscalado registrado, nenhum quadro de gameplay comparado. Pendente: qualidade de imagem, fps e latência
  com/sem DLSS (`tools/capture.ps1` e soak com `KYTY_DLSS`). A saída do TAA do jogo é 2560x1440 (= render): não há
  upscale real até achar a passada pós-TAA (STATUS.md).
- Candidato a upstream: não (DLSS SR é da camada desport/ceremony88); o teto de endereços vale como aviso para o
  ceremony88.

## FIX-007 — SaveDataDialog reabre para sempre (porte do upstream `05f92b64`) (2026-10-23)
- Fase / área: 5 / bibliotecas (`engine/src/libs/dialog.cpp`); branch `desport-up1` (`11cf8f9c`, em `desport-int`).
- Sintoma: título cuja etapa de gravação só aceita `FINISHED` depois de ver um poll `RUNNING` chama
  `SaveDataDialogOpen()` em laço (travamento de gravação, relatado no upstream). O jogo importa `sceSaveDataDialog*`
  (STATUS.md).
- Evidência antes: pendente — nenhuma execução registrada reproduz o laço no Demon's Souls (os saves das sessões
  de `captures/runs/` foram gravados sem travar, ex. `20261023-220041-soak-30m-2`); medir contando chamadas
  `sceSaveDataDialogOpen` (`DES_TRACE`/`calls.json`) numa gravação de save.
- Causa: `SaveDataDialogOpen()` ia de INITIALIZED direto a FINISHED, pulando RUNNING.
- Mudança: `Open()` começa em RUNNING; `UpdateStatus()` reporta RUNNING uma vez e depois FINISHED (`GetStatus()`
  fica só de leitura). O shim CP932 de libCes e as partes SDL3/CMake do commit original não vieram.
- Verificação: depois pendente (mesma medição). Sem regressão: fumaça de `desport-int` a 60 fps
  (`captures/runs/20261023-224002-int-smoke`) e bateria `captures/nightly/20261023-230747` (smoke, janela, 120 Hz).
- Candidato a upstream: não (já é do upstream).

## FIX-008 — Conclusão de APR perdida em lotes de leitura de 768 bytes (porte do upstream `41beda43`) (2026-10-23)
- Fase / área: 5 / AMPR (`engine/src/libs/libAmpr.cpp`); branch `desport-up2` (`660fadac`).
- Sintoma: risco de travar o streaming de assets: os últimos registros de um lote de 768 bytes não cabem, o append
  devolve EBUSY e a escrita de conclusão se perde (`docs/UPSTREAM_TRIAGE.md`, lote B; o jogo usa 60 funções AMPR).
- Evidência antes: pendente — nenhum travamento de streaming atribuído a isso foi registrado no desport; medir
  contando retornos EBUSY das funções de escrita do AMPR (`DES_TRACE`) num soak.
- Causa: comandos de write-address ocupavam `0x20` fixos; a biblioteca do PS5 os codifica em 8, 12 ou 16 bytes
  conforme o valor, e os jogos dimensionam os lotes por esses tamanhos.
- Mudança: porte manual limitado ao bug (tamanho por valor ao anexar e ao medir; `4fgtGfXDrFc` passa a ser medido
  como write-address). Fora: checagem de alinhamento, comandos de contador dos commits intermediários e o teste do
  upstream (depende deles). Conflito com o `AppendWriteAddressRecord` do ceremony88 resolvido à mão.
- Verificação: depois pendente (medição acima). Sem regressão observada na fumaça/janela de `desport-int` (FIX-007).
- Candidato a upstream: não.

## FIX-009 — Vídeos (Bink) a 2x a velocidade com `--vblank-frequency 120` (2026-10-23)
- Fase / área: 4 (desempenho) / apresentação (`engine/src/graphics/presentation/videoOut.cpp`,
  `engine/src/kernel/fileSystem.cpp`, `engine/src/loader/desport.cpp`); branch `desport-vblank` (`4de91172`).
- Sintoma: com vblank virtual de 120 Hz o jogo roda a 120 fps, mas os vídeos avançam um quadro por flip e tocam
  em dobro da velocidade.
- Evidência antes: o jogo só chama `sceVideoOutSetFlipRate` com 0 (131 chamadas em todos os logs gravados, dado do
  commit), então não há gancho por taxa. `captures/runs/20261023-224819-v120-off` (vblank 120, pacing desligado — o
  ambiente não ficou em `run.json`, só o contraste): mediana 120,0 fps desde o menu, ou seja, o vídeo corre a
  120 flips/s. Pendente: cronometrar o logo contra a duração do `.bk2`.
- Causa: vídeos avançam um quadro por flip e a taxa de flips segue o vblank.
- Mudança: um `.bk2` aberto nos descritores do jogo marca a reprodução; enquanto aberto, `IsFlipDueLocked` deixa pelo
  menos `vblank/60-1` vblanks entre flips (só vblank >= 100 Hz). Eventos de vblank e relógio do jogo mantêm a taxa.
  `KYTY_MOVIE_PACING=0` desliga; linhas `DES_VBLANK movie_pacing on/off` marcam as transições.
- Verificação: `captures/runs/20261023-224632-v120-on` (vblank 120, pacing ligado): `movie_pacing on` em 16,0 s
  (`ps_studios_logo.bk2`, `flip_floor=1`), `off` em 24,5 s, `on` de novo em 26,6 s (`attract_movie.bk2`); fps por
  janela mediana 60,0 (mín 30,0; máx 86,8), contra 120,0 sem a correção; 101 s, sem parada. Pendente: confirmar que o
  `attract_movie` fecha no gameplay e que o fps volta a 120 (STATUS.md).
- Candidato a upstream: não (depende de vblank acima de 60 Hz, característica do fork).

## FIX-010 — Ultrawide nativo: aspecto errado, HUD e vídeos esticados (2026-10-23)
- Fase / área: 4 (gráficos) / carregador (`engine/src/loader/desportUltrawide.cpp`, `videoOut.cpp`,
  `renderDraw.cpp`); branches `desport-uw` (`62818aa2`) e `desport-uw2` (`04489d20`, `3e609ac3`).
- Sintoma: em janela 21:9 (3440x1440) o jogo renderiza em 16:9 e estica para a janela: campo de visão errado, HUD,
  menus e vídeos esticados (`docs/DLSS_PLAN.md`, "Ultrawide").
- Evidência antes: pendente — não há captura 16:9 esticada guardada; capturar a mesma cena em 3440x1440 sem
  `KYTY_ULTRAWIDE` (`tools/capture.ps1` / `tools/screenshot.ps1`).
- Causa: o aspecto do 3D é a constante 16/9 gravada pelo jogo (`c7 43 04 39 8e e3 3f`, um único sítio no eboot
  01.007.000); as tabelas de modo de vídeo e o tamanho de tela da UI são 3840x2160 fixos.
- Mudança: `KYTY_ULTRAWIDE=<LxA>|<W:H>|<proporção>` grava a constante por assinatura (`62818aa2`, sem arquivo de
  patch); `KYTY_ULTRAWIDE_RENDER=1` troca os tamanhos de render/saída das tabelas de modo e `KYTY_ULTRAWIDE_HUD` o
  tamanho de tela da UI (`04489d20`); `KYTY_ULTRAWIDE_MOVIES=pillarbox` e `KYTY_ULTRAWIDE_HUD_LAYOUT=16x9`
  (`3e609ac3`). Cada patch loga `DES_ULTRAWIDE <o quê> applied|skipped <motivo>`; sítio ausente ou não único
  não aplica nada.
- Verificação: `captures/runs/20261023-230230-uw-native` (binário `build/fg-uw2`, 3440x1440): `aspect=2.3889 applied`;
  render 3440x1440, saída 3440x1440, dinâmico 2408x1008, UI 3440x1440 (era 3840x2160); `shot-hud.png` na pasta
  (HUD ancorado nas bordas, relato do STATUS.md). Pendente: pillarbox de vídeos e `HUD_LAYOUT=16x9` (`3e609ac3`,
  "not built or run" no commit) sem execução registrada; menus, título e cutscenes em ultrawide; fps a 3440x1440.
- Candidato a upstream: não (patch por assinatura em eboot específico).

## FIX-011 — Red zone SysV pisada pelo despacho de exceção do Windows: varredura de lacunas (2026-10-23)
- Fase / área: 5 (estabilidade) / patcher de instruções do guest (`engine/src/loader/redZonePatcher.cpp`,
  `runtimeLinker.cpp`); branch `desport-rz` (`126ca119`).
- Sintoma: latente. O Windows grava CONTEXT e registro de exceção abaixo de `rsp` antes de qualquer handler, por
  cima da red zone SysV; faults de páginas rastreadas (centenas por quadro) podem corromper dados vivos da red zone.
  Nenhuma queda foi atribuída a isso.
- Evidência antes: `captures/runs/20261023-160642-instr-scan` (Fase 1, `--redzone`, engine anterior): eboot com
  262 funções usando red zone, 8126 acessos, 7970 corrigidos, **156 não relocáveis**; `libc.prx` 42/86/86. Não é
  comparável direto com o engine atual (outra base). Código em funções sem `.eh_frame` nunca era analisado.
- Causa: a única defesa é o patcher no carregamento (baixa `rsp` em 128 em volta de acessos à memória com red zone
  viva), mas ele só percorre código alcançado a partir dos inícios de função do `.eh_frame`.
- Mudança: `KYTY_REDZONE_SWEEP_GAPS` (padrão ligado; 0 volta ao anterior) decodifica linearmente o código não
  alcançado quando parece código compilado e usa red zone (`gap_swept=<funções>` no log).
  `KYTY_REDZONE_FAULT_AUDIT=1` (padrão desligado) imprime `RED_ZONE_AUDIT` uma vez por endereço quando um fault
  tratado atinge instrução desprotegida com red zone viva.
- Verificação: `captures/runs/20261023-230538-dlss-fix2` (engine atual): eboot `functions=130886 red_zone=263
  memory=10498 patched=10500 ... unrelocatable=0 ... gap_swept=0`; `libc.prx` `patched=86 unrelocatable=0
  gap_swept=0`; `libSceNpCppWebApi.prx` nenhuma. Fumaça de 120 s sem alertas
  (`...-224002-int-smoke`, `...-230748-nightly-smoke`). Pendente: (a) `gap_swept=0` indica que a varredura não achou
  nada neste eboot, então o ganho da mudança é nulo até prova em contrário; (b) rodar com
  `KYTY_REDZONE_FAULT_AUDIT=1` numa sessão de gameplay e contar `RED_ZONE_AUDIT` (nenhuma execução registrada o
  usou).
- Candidato a upstream: talvez (o `--redzone` é do upstream; a varredura é genérica).

## FIX-012 — Lote A do upstream: 21 commits de kernel, GPU e libs (`desport-up1`) (2026-10-23)
- Fase / área: 5 (estabilidade) / kernel, libs, GPU, janela (`docs/UPSTREAM_TRIAGE.md`, lote A); branch `desport-up1`,
  mesclada em `desport-int` (`4688596e`, um conflito em `window.cpp` resolvido).
- Sintoma: as correções endereçam deadlocks, esperas e limites conhecidos no upstream: entrega de exceção
  (registro global de condição), wakeups por pthread, umtx com prazo, semáforo, evento de usuário persistente, ESRCH de
  thread já juntada, LOGF fora de linha (pilhas de fibra pequenas), `sceNpGetAccountLanguage2` (cita o Demon's Souls),
  Ajm (lote inválido, reset de decodificadores gapless), fsync do save, `/dev/random` como dispositivo de
  caractere, caminhos do guest fora do namespace do host, resize nonpositivo ao minimizar, interrupções de compute
  assíncrono, estado de alocação do shader frontal, limites de LOD bias/anisotropia, cópias de imagem sobrepostas.
- Evidência antes: pendente — nenhum desses defeitos foi observado individualmente no desport (os soaks de 10 e 30 min
  anteriores, `20261023-213716-soak-10m-1` e `20261023-220041-soak-30m-2`, não travaram por eles). Medir: soak de
  30 min em `desport-int` e boot até o 1-1, como pede `docs/UPSTREAM_TRIAGE.md` ("cada lote").
- Causa: regressões e lacunas do upstream, corrigidas lá (hashes em `git -C build/fg-int log main..desport-up1`).
- Mudança: cherry-picks sem alteração (autoria do upstream preservada), em `desport-up1`.
- Verificação: depois pendente (soak de 30 min com o lote). Sem regressão: fumaça `20261023-230748-nightly-smoke`
  (60 fps de mediana) e janela `20261023-230950-nightly-window` (ok), já sobre `desport-int`.
- Candidato a upstream: não (já é do upstream).
