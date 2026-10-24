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
