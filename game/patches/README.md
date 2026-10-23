# Patches de memória do Demon's Souls

Aplicados pelo `GamePatch` do KytyPS5 (`engine/src/loader/gamePatch.cpp`) com
`kyty_emulator --game-patch <arquivo>.json`. O formato é o JSON de mods no estilo GoldHEN/ETAHen:

```json
{
  "id": "PPSA01341",
  "version": "01.007.000",
  "process": "eboot.bin",
  "mods": [
    { "name": "descrição curta", "enabled": true,
      "memory": [ { "offset": "<endereço em hex>", "off": "<bytes originais>", "on": "<bytes novos>" } ] }
  ]
}
```

- `id`, `version` e `process` precisam bater com o jogo carregado (`TITLE_ID`, `APP_VER` e o
  nome do executável); senão o KytyPS5 recusa o arquivo.
- `off` e `on` têm o mesmo tamanho; `off` documenta os bytes originais, o que permite conferir
  que o patch está no lugar certo.
- Regras do projeto: nada de bytes do jogo além do mínimo do patch; cada patch tem entrada em
  `docs/FIXES.md` com o motivo e a evidência; patches são aplicados em memória, nunca na pasta do
  dump (PLAN.md §1.1.3).

_Nenhum patch ainda._
