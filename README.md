# desport — Demon's Souls (PS5) no PC

Port experimental do **Demon's Souls** de PS5 (PPSA01341, EUR, versão 01.007.000) para PC, sobre o emulador
[KytyPS5](https://github.com/KytyPS5/KytyPS5) e o fork de desempenho
[KytyPS5-DemonsSouls-FrameGen](https://github.com/ceremony88/KytyPS5-DemonsSouls-FrameGen) (ceremony88), no
espírito do bbport (o port do Bloodborne).

> **Você precisa do seu próprio dump legal e descriptografado do jogo.** Este repositório não contém nada do
> jogo: nem binários, nem assets, nem shaders, nem saves. Também não contém código de descriptografia.

*English summary at the end.*

## Estado (2026-10-24)

Jogável do começo do jogo em diante, com sessões de 30–60 min sem crash nos testes automáticos (RTX 5080, Ryzen
7 9800X3D). Não foi jogado de ponta a ponta. Em resumo:

| Recurso | Estado |
|---|---|
| Boot, menus, vídeos, gameplay | funciona |
| 60 fps / sem teto de fps (`KYTY_FPS_LIMIT`) | funciona; a velocidade do jogo acima de 60 fps ainda precisa ser conferida por uma pessoa jogando |
| DLSS 4.5 (Streamline 2.14.1), DLAA e upscale real (`KYTY_DLSS_UPSCALE=2`) | funciona: 71 fps em 1440p nativo, ~100 em quality e ~112 em performance |
| Geração de quadros DLSS + Reflex, junto com o DLSS | funciona (soak de 30 min) |
| Ultrawide nativo (3440x1440): render, HUD, vídeos centralizados | funciona; o HUD tem ajustes pendentes |
| Pré-compilação de shaders | do fork do ceremony88 |
| Qualidade de imagem igual à do PS5 Pro | **ainda não**: texturas mais borradas e DLSS em modos baixos feio (ver `docs/STATUS.md`) |
| Port nativo sem emulação (Fase 6, estilo bbport) | não começou |

Detalhes, medições e pendências: [`docs/STATUS.md`](docs/STATUS.md), [`docs/FIXES.md`](docs/FIXES.md) e
[`docs/agents/knowledge.md`](docs/agents/knowledge.md) (base de conhecimento técnica, com todas as variáveis de
ambiente e medições de desempenho).

## Onde está o código

- **Engine:** fork [RonaldoLPFilho/KytyPS5](https://github.com/RonaldoLPFilho/KytyPS5), branch **`desport-int`**
  (integração). Cada recurso tem a sua branch `desport-<tema>`; o mapa está em
  [`docs/ENGINE_BRANCHES.md`](docs/ENGINE_BRANCHES.md). Toda mudança no engine é marcada com `// desport:`.
- **Este repositório:** plano ([`PLAN.md`](PLAN.md)), documentação, decisões (`docs/DECISIONS.md`), launcher e
  ferramentas de teste (`tools/`): execução instrumentada, soak com piloto automático, bateria de desempenho A/B,
  captura de quadro, triagem de logs e empacotamento.

## Compilar

Windows, Visual Studio 2022 (clang-cl), CMake e Ninja.

```
git clone -b desport-int https://github.com/RonaldoLPFilho/KytyPS5 engine-src
cd engine-src
git submodule update --init
set KYTY_CMAKE_ARGS=-DKYTY_MARCH=x86-64-v3
build-windows.cmd
```

`KYTY_MARCH=x86-64-v3` gera um exe para qualquer CPU com AVX2; sem ele o padrão é `native`, só para a CPU que
compilou. O Streamline SDK 2.14.1 (NVIDIA) entra em `_Build/deps/streamline/sdk` (ver `docs/DLSS_PLAN.md`).

## Jogar

1. Baixe o pacote da página de releases, ou monte um com `tools/package.ps1 -Zip`.
2. Abra o `launcher.cmd`, aponte para a pasta do seu dump (01.007.000) e escolha a resolução, o DLSS, a geração de
   quadros, o limite de fps e as opções de qualidade.
3. Na primeira vez, a pré-compilação de shaders do fork demora: rode `precompile.cmd`.

O launcher confere a versão do jogo, se o eboot está descriptografado, AVX2, GPU, driver e as DLLs do DLSS antes
de liberar o botão Jogar.

## Como contribuir

- Leia [`PLAN.md`](PLAN.md) (regras em §1: nada do jogo no git, nada de descriptografia) e
  [`docs/STATUS.md`](docs/STATUS.md).
- Os próximos passos mais valiosos estão em `docs/STATUS.md` ("Próximo foco"): qualidade de imagem (texturas,
  LOD, DLSS), HUD no ultrawide, velocidade acima de 60 fps, jogar a campanha toda (`docs/PLAYTHROUGH.md`) e, por fim,
  o port nativo (Fase 6).
- As ferramentas de medição (`tools/perf-ab.ps1`, `KYTY_GPU_TIMESTAMPS`, `KYTY_GPU_PROFILE`, `DES_FRAME`) estão
  descritas em `docs/agents/knowledge.md`.
- Bugs e correções que valem para o KytyPS5 em geral devem ir para o upstream.

## Créditos e licença

- [KytyPS5](https://github.com/KytyPS5/KytyPS5) e colaboradores: o emulador.
- [ceremony88/KytyPS5-DemonsSouls-FrameGen](https://github.com/ceremony88/KytyPS5-DemonsSouls-FrameGen): o fork de
  desempenho, a pré-compilação e a geração de quadros, sobre os quais este trabalho foi feito.
- O bbport (Bloodborne): a inspiração para o modelo de port.
- NVIDIA Streamline / DLSS: SDK sob os termos da NVIDIA (licenças no pacote).
- Desenvolvido por Ronaldo com o Claude Code (Anthropic).

Licença: GPL-2.0 ([`LICENSE`](LICENSE)), a mesma do KytyPS5. Demon's Souls é marca da Sony Interactive
Entertainment; este projeto não tem relação com a Sony nem com a Bluepoint Games.

---

## English summary

Experimental PC port of **Demon's Souls (PS5, PPSA01341 EUR 01.007.000)** built on KytyPS5 and ceremony88's
FrameGen fork. **Bring your own legally dumped, decrypted copy**: this repository contains no game data and no
decryption code. Playable with 30–60 min automated soaks without crashes. Added DLSS 4.5 with real upscaling
(~100 fps quality / ~112 performance vs 71 native at 1440p on an RTX 5080), DLSS frame generation + Reflex, an
uncapped frame-rate limiter, native ultrawide with centred movies, a launcher with startup checks, and
measurement tooling. Image quality is not yet on par with the PS5 Pro. Engine code: branch `desport-int` of
RonaldoLPFilho/KytyPS5; docs and tools here (Portuguese). GPL-2.0.
