# desport — instruções para o Claude Code

Projeto: port nativo do Demon's Souls de PS5 (PPSA01341, EUR, versão 01.007.000 — ADR-001) para PC, no modelo do bbport
(Bloodborne), usando o KytyPS5 como base.

**Antes de qualquer tarefa:** leia `PLAN.md` (plano mestre) e `docs/STATUS.md` (estado atual).
Trabalhe na fase indicada em `docs/STATUS.md`; não pule fases.

Regras que nunca mudam (detalhes em `PLAN.md` §1):
- Nada do jogo, nem derivado dele, entra no git (eboot, prx, assets, imagens linkadas, dumps
  de shader/comando, capturas, saves, caches). Tudo isso fica em `out/`, `captures/`, `user/`.
- Nenhum código de descriptografia. Dump criptografado → parar com erro.
- Nunca escrever na pasta do dump do jogo nem nas pastas do bbport (`D:\games\bloodborne_pc-0.4`,
  `D:\games\bbport-windows`): são somente leitura.
- Toda alteração no código do KytyPS5 (`engine/`) leva `// desport: <motivo>`.
- Toda correção é registrada em `docs/FIXES.md` com evidência antes/depois.
- Compilar o engine só com `clang-cl` no Windows.
- PRs e issues no KytyPS5 são escritos e enviados pelo Ronaldo, nunca pelo agente.

Pare e pergunte ao Ronaldo quando precisar rodar o jogo de forma interativa, quando o dump,
a versão ou o hardware não baterem com o plano, em portões de decisão, e antes de apagar
qualquer coisa fora de `out/`, `build/`, `captures/`.

Responda ao Ronaldo em português.
