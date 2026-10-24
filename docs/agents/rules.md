# Regras para subagentes

## Papéis
- **Coordenador** (sessão principal): compila, roda o jogo, junta branches, commita no repo principal, faz push,
  fala com o Ronaldo.
- **Subagente:** lê, analisa, escreve código e ferramentas. Opus para tarefas complexas/exploratórias, Sonnet
  para operacionais. Responde em português.

## Nunca
- Compilar o engine ou rodar o jogo (nem scripts que o abram: `run.ps1` sem `-DryRun`, `soak.ps1`,
  `nightly.ps1`, `perf-ab.ps1`, `launcher.ps1` sem `-DryRun`).
- Mexer em processos (`kyty_emulator`, piloto automático) ou no worktree `build/fg-int` enquanto houver teste.
- Alterar `game/config/fg-launch.json` durante testes (está em uso); para variações, gere cópia em `build/`.
- Escrever no dump do jogo (`C:\games\DemonsSouls-PPSA01341`) ou nas pastas do bbport
  (`D:\games\bloodborne_pc-0.4`, `D:\games\bbport-windows`): só leitura.
- Colocar no git qualquer coisa do jogo ou derivada dele (logs com conteúdo, capturas, shaders, saves).
- Código de descriptografia.
- Push, PR ou issue (PRs/issues no KytyPS5 são do Ronaldo).
- Commitar no repo principal (`D:\games\desport`): deixe as mudanças locais; o coordenador revisa e commita.
- Inventar evidência, versão ou licença: o que não foi verificado vira "pendente".

## Sempre
- Engine: trabalhar num worktree próprio, branch `desport-<tema>` (ver `docs/ENGINE_BRANCHES.md`):
  `git -C D:\games\desport\build\fg-int worktree add D:\games\desport\build\fg-<tema> -b desport-<tema> desport-int`.
- Toda alteração no engine leva `// desport: <motivo>`, no estilo do código ao redor.
- Commit no engine com `SKIP=clang-format git commit ...` (o hook reformata arquivos inteiros por formatação
  antiga; aprovado pelo Ronaldo). Nunca `--no-verify`.
- Recurso novo no engine atrás de variável de ambiente, padrão = comportamento atual, com uma linha de log
  `DES_<TEMA> ...` no boot dizendo o que foi aplicado.
- Patch no código do jogo: localizar por assinatura de bytes, nunca endereço fixo.
- Ferramentas PowerShell: validar com `[System.Management.Automation.Language.Parser]::ParseFile`.
  Python: `python -I`; testes com `python -I -m unittest discover -s tests/tools` (não há pytest).
- Relatório final curto: o que mudou (hash/arquivos), como testar, riscos, pendências e "Para a memória".
