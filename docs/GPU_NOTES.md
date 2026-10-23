# Notas sobre o pipeline gráfico do Demon's Souls

Descobertas sobre como o jogo usa a GPU do PS5 e onde o KytyPS5 precisa de trabalho. Cada
problema gráfico investigado ganha uma seção com captura, draw/dispatch responsável e hipótese
(PLAN.md §6 Fase 4).

## Superfície AGC (Fase 1, tarefa 5) — 2026-10-23

Gerada por `tools/nid_db.py` a partir do inventário do eboot (PPSA01341 01.007.000) e do engine
em `9dcff95` + FIX-001. A tabela por função (NID, nome verificado, status, função do engine,
sítios de chamada) fica em `out/gpu_surface.md`, fora do git.

| Biblioteca importada | implemented | stub | missing | total | sítios de chamada |
|---|---:|---:|---:|---:|---:|
| `libSceAgc` | 133 | 1 | 77 | 211 | 220 |
| `libSceAgcDriver` | 20 | 1 | 23 | 44 | 47 |
| `libSceVideoOut` | 14 | 0 | 0 | 14 | 29 |
| `libSceAmpr` | 59 | 1 | 0 | 60 | 88 |

Observações:
- **Cada função AGC é chamada em pouquíssimos lugares** (no máximo 3; 89 das 100 ausentes têm um
  único sítio, 2 têm nenhum). O jogo passa a AGC por uma camada fina própria. É o mesmo cenário
  que o bbport encontrou com a libGnm estática: os pacotes PM4 refletem chamadas de API
  conhecidas. Medir isso direito é trabalho da Fase 4 (e base para a Fase 6/7).
- **Nomes de biblioteca diferem entre o jogo e o KytyPS5:** o eboot importa `libSceAgc` /
  `libSceAgcDriver`; a HLE registra `Graphics5` / `Graphics5Driver`. Nenhuma função AGC casa pela
  chave exata; todas as 153 implementadas resolvem pelo NID ("PS5 NID fallback" no log). Funciona,
  mas 23 NIDs do jogo existem em mais de uma biblioteca da HLE, e a escolha por NID pega a
  primeira registrada.
- VideoOut está completo para o que o jogo importa (flip, vblank, atributos de buffer, gama).
- Mais usadas entre as implementadas (sítios): `sceAgcCbReleaseMem`, `sceAgcDcbEventWrite`,
  `sceAgcDcbSetBaseIndirectArgs`, `sceAgcDcbSetPredication` (3 cada). `IT_SET_PREDICATION` não é
  implementado no bbport; aqui vale conferir o comportamento do KytyPS5 quando aparecer.
- Nomes: 140 das 255 funções AGC/AgcDriver importadas têm nome verificado pelo hash. As 100
  ausentes, em geral, não têm (o engine não as conhece, então não há função C++ de onde derivar o
  nome). Um arquivo de nomes (`nid_db.py --names`) ajudaria.

## Primeiro bloqueio gráfico (linha de base da Fase 0) — 2026-10-23

- As 3 execuções param em `engine/src/graphics/host_gpu/renderer/pipeline/descriptors.cpp:969`:
  `scalar resource reads overlap a shader buffer write`, ao montar um dispatch de compute.
- Até ali (execução c, 54 command buffers): 382 dispatches, 15 `DRAW_INDEX_AUTO` sem shader de
  pixel, 1 `R_FLIP`, nenhum pacote desconhecido; 111 shaders de compute e 1 de vértice
  compilados, todos com sucesso. Último CS compilado: `0x02632cb15eb8128d`.
- Validação Vulkan: zero mensagens até a parada.
- Hipótese a verificar na Fase 3/4: a checagem é conservadora (o shader lê por leitura escalar,
  para especializar o pipeline, uma região que outro buffer do mesmo dispatch escreve). Pode
  haver colisão real (leitura de dado produzido no mesmo dispatch) ou apenas sobreposição de
  intervalos sem conflito de fato.

## Entradas temporais (DLSS / geração de quadros, ADR-004)

_A preencher na Fase 4 (tarefa 8, marco M4.6)._
