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
- Evidência antes: `captures/runs/20261023-195707-sessao-cache` (`-Stats`): por quadro, 217 leituras
  da CPU (68 ms), 108 escritas da CPU em páginas da GPU (18 ms), 323 esperas pela GPU, 386 envios
  de fila. O fault do host informa 1 byte (`RenderContext::HandleFault`).
- Causa: `BufferCache::ReadMemory` baixava e desprotegia só a página do fault; ler um buffer escrito
  pela GPU custava uma drenagem por página.
- Mudança: baixa de uma vez todas as páginas modificadas pela GPU numa janela alinhada de 1 MiB em
  volta do acesso (limitada ao buffer); `DES_FAULT_AROUND=0` volta ao comportamento do upstream.
  Uma marcação `// desport:` (engine `17950146`).
- Verificação: menu (60 fps, sem parada) 13,6 → 7,8 leituras por quadro. Jogo
  (`captures/runs/*-sessao-faultaround`): esperas 323 → 135, envios 386 → 197, escritas 108 → 5,
  leituras 217 → 139 (68 → 58 ms), bytes baixados 0,9 → 12 MB por quadro; **fps 4,50 → 4,64**.
  O quadro continua dominado pela avaliação de recursos (~110 ms). Imagem sem anomalia relatada.
- Candidato a upstream: sim (PR pequeno, com a chave e os números); a janela pode ser ajustada.
