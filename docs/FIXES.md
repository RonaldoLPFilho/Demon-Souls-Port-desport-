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
