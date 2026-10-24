# Branches do engine (fork RonaldoLPFilho/KytyPS5)

Base desde o ADR-008: KytyPS5-DemonsSouls-FrameGen v1.3 (ceremony88), sobre o upstream `f2455c87`.

| Branch | Papel | Worktree local |
|---|---|---|
| `desport-int` | **Integração: a branch de trabalho.** Recebe as branches de tarefa abaixo por merge. É a que o launcher e o `fg-launch.json` usam. | `build/fg-int` |
| `desport-fg` | Import do FrameGen + camada desport de medição (DES_FPS, DES_STAT, DES_SLOW). Base de todas as branches de tarefa. | `build/fg-port` |
| `desport-crash` | Captura de crash (minidump, `DES_CRASH`). | `build/fg-crash` |
| `desport-mem` | Relatório de memória por categoria (`DES_MEM`). | `build/fg-mem` |
| `desport-s001` | FIX-005: janela minimizada/coberta não congela o jogo. | `build/fg-s001` |
| `desport-vblank` | FIX-009: vídeos no ritmo certo com vblank 120 (`KYTY_MOVIE_PACING`). | `build/fg-vblank` |
| `desport-dlss` | FIX-006: DLSS SR fase A (Streamline 2.14.1, DLSS 4.5). | `build/fg-dlss` |
| `desport-uw`, `desport-uw2` | FIX-010: ultrawide nativo, pillarbox de vídeo, HUD 16:9 opcional. | `build/fg-uw`, `build/fg-uw2` |
| `desport-up1`, `desport-up2`, `desport-up3` | Lotes do upstream (FIX-007, FIX-008, FIX-012; triagem em `UPSTREAM_TRIAGE.md`). | `build/fg-up1..3` |
| `desport-rz` | FIX-011: red zone (varredura de lacunas). | `build/fg-rz` |
| `desport-faults` | Classificação de faults (`KYTY_FAULT_CLASSIFY`, `DES_FAULTS`). | `build/fg-faults` |
| `desport-fps` | Em andamento: remoção do limite de fps (`KYTY_FPS_LIMIT`). Sobe quando validada. | `build/fg-fps` |

Branches antigas (antes do ADR-008, engine upstream `9dcff95`): `desport` (submódulo `engine/` deste repo, FIX-001 a
FIX-004) e `desport-584`. Ficam como histórico; não recebem trabalho novo.

Fluxo: tarefa nova = branch `desport-<tema>` a partir de `desport-fg` (ou de `desport-int` se depender de algo já
integrado) → compilar e validar → merge em `desport-int` → registrar em `FIXES.md` → push.
