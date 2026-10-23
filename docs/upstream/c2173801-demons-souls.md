# Regressão: `c2173801` faz o Demon's Souls parar em "scalar resource reads overlap a shader buffer write"

Rascunho para o Ronaldo abrir como issue no KytyPS5 (PLAN.md §11). O texto abaixo da linha é o
que vai para a issue, em inglês; ajuste à vontade antes de enviar.

Evidência local (fora do git): `build/bisect-final.log`, `build/bisect-summary.log`,
`captures/runs/*-bisect2-*` (log de cada passo), `captures/runs/*-bisect2-9dcff95e` (revert).

---

**Title:** Demon's Souls (PPSA01341) stops with "scalar resource reads overlap a shader buffer
write" since c2173801

**Game:** Demon's Souls, PPSA01341, EUR, version 01.007.000 (unencrypted dump, folder).
**Hardware:** Ryzen 7 9800X3D, RTX 5080 (NVIDIA), 32 GB RAM, Windows 11.
**Build:** clang-cl 19.1.5, Release, no launcher.

**What happens.** About 7 s after start, while creating the ~111th compute pipeline (CS hash
`0x02632cb15eb8128d`), the emulator exits with:

```
--- Error ---
scalar resource reads overlap a shader buffer write
 in src/graphics/host_gpu/renderer/pipeline/descriptors.cpp:951
```

(`descriptors.cpp:969` on `9dcff95`.)

**Bisect.** `git bisect` between `22ff469` (good) and `9dcff95` (bad), building each commit and
running the game for up to 180 s with an empty pipeline cache. Criterion: bad = that check fires;
good = more than 115 compute pipelines created without it firing.

```
first bad commit: c2173801d47f65d840487e9998bddcbb601c6691
shader: skip resources in proven empty unsigned loops
```

Parent `56d03f16` is good (135 compute pipelines in 180 s, no error). `c2173801` and every bad
commit after it stop at the same place.

**Revert test.** Current `main` (`9dcff95`) with only `c2173801` reverted no longer hits the check
(135 compute pipelines in 180 s, no error). With `584c2e8` (before the change) the game reaches the
title screen, character creation and gameplay.

**Guess.** The commit lets `ULessThan32` into `ExtractResourcePlan` and makes `SrtWalker` evaluate
`x < 0u` as false even when `x` is unknown. Some branch in this shader now looks unreachable (or
reachable) in a way that makes the scalar refresh analysis prove an overlap with a buffer write
that did not exist before. Happy to provide the shader dump or test a patch.
