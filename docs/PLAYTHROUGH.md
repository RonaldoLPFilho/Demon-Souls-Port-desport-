# Checklist de jogabilidade (Fase 5, PLAN.md §6 item 6)

Status possíveis: **não testado**, **ok**, **problema** (todo problema linka uma entrada de `docs/FIXES.md`
ou uma issue aberta). Só o Ronaldo marca `ok` de uma área: o agente e os scripts só registram evidência.
Evidência = pasta em `captures/runs/` (fora do git). Nada aqui foi inventado: o que não tem pasta citada
está como "não testado".

Build de referência das medições abaixo: engine FrameGen (ADR-008) sobre `desport-fg`/`desport-int`,
`game/config/fg-launch.json`, 2560x1440, vblank 60, dump no SSD (`docs/STATUS.md`, `docs/agents/knowledge.md`).

Como preencher: a cada sessão, uma linha por área. Desempenho = fps médio (`DES_FPS`, linha "FPS" do
`triage.md`) e travadas (linha "Travadas": quadros lentos, total e pior). Estabilidade = crash / congelamento /
memória (`triage.md`, seção Memória). Marcar a pasta da execução na coluna Evidência.

---

## 1. Itens transversais

### 1.1 Áudio

| O que testar | Status | Evidência / observação |
|---|---|---|
| Música, efeitos e vozes presentes e corretos em menu, Nexus e uma fase | não testado | Nenhum registro de escuta nos docs. O jogo abre o áudio na inicialização (`STATUS.md`, Relatório da linha de base: "abre o áudio") e o log do engine é lido só por triagem; ninguém relatou ter ouvido. |
| Estalos, picotes, dessincronia sob carga (compilação de shader, carregamento) | não testado | Travadas de 0,5–17 s existem na sessão sem pré-compilação (`20261023-202438-fg-sessao1`: 276 quadros lentos, pior 17151 ms), então é onde o áudio deve ser ouvido. |
| Sincronia de áudio com cutscenes e vídeos Bink | não testado | Vídeos `.bk2` identificados no log: `ps_studios_logo.bk2`, `attract_movie.bk2` (`20261023-224632-v120-on`). |
| Áudio com vblank 120 / sem limite de fps / geração de quadros | não testado | Cuidado: com vblank 120 o ritmo do vídeo precisou de correção (FIX-009); áudio nunca foi escutado nesse modo. |
| Áudio com janela minimizada / sem foco | não testado | FIX-005 cobre só o fps (`20261023-224236-int-window`). |
| Riscos conhecidos para investigar se houver defeito | pendente | KP-002 (`audio_out2_port_tests` intermitente no RelWithDebInfo, `STATUS.md`); `UPSTREAM_TRIAGE.md` lista commits de AudioOut2 (`c86c8b4d`, `b46eeb78`, ...) e de Ajm adiados "sem evidência de que o Demon's Souls use AudioOut2". `libSceAjm` tem 5 imports ausentes (`STATUS.md`, Fase 1). |

### 1.2 Entrada (controle SDL, teclado)

| O que testar | Status | Evidência / observação |
|---|---|---|
| Teclado: mapeamento padrão do KytyPS5 (Enter = Options, J = Cross, WASD anda, F/H giram a câmera) | ok (parcial) | O autopilot usa exatamente essas teclas e leva o jogo da tela de menu ao HUD e anda por 30 min (`20261023-220041-soak-30m-2`: HUD em 70 s, 806 movimentos). Só teclas do autopilot; todo o mapa (combate, esquiva, menus, inventário) não testado. |
| Controle Xbox via SDL | não testado | Nenhum registro de sessão com controle. |
| Controle DualSense via SDL (inclui vibração, gatilhos adaptativos, giroscópio, touchpad) | não testado | `UPSTREAM_TRIAGE.md` adiou DualSense/haptics/gatilhos como "não relevantes até a Fase 5". Controle que não abre foi tratado no porte `e7ceb36d` (loga e ignora em vez de abortar). |
| Hotplug (conectar/desconectar durante o jogo) e controle conectado com o jogo parado | não testado | |
| Aceita entrada do controle na tela de título (M3.4) | não testado | |
| Entrada com janela sem foco / minimizada | não testado | O autopilot só envia teclas à janela do emulador e conta perdas de foco (`janela fora de foco 0x` no soak de 30 min). |

### 1.3 Saves

| O que testar | Status | Evidência / observação |
|---|---|---|
| Criar save (novo personagem) e ver os arquivos em `user/` | ok (parcial) | `20261023-172446-sessao-livre-584c2e8`: `SAVEDATA0OptionsProfile0` e `SAVEDATA0PlayerProfile0` gravados (`STATUS.md`, Sessão livre). Marco `first_savedata_mount` em 25–30 s em todas as execuções (`20261023-220041-soak-30m-2`: 30,1 s). |
| Carregar ("continuar jogo") | ok (parcial) | `20261023-183343-sessao-medicao`: "continuar jogo" levou ao personagem controlável (a 3–5 fps naquele build). Soaks restauram o save de referência `user/saves-backup/kyty-fg-20261023-2050` e chegam ao HUD em 70–109 s (`20261023-213716-soak-10m-1`, `...-220041-soak-30m-2`). |
| Sobrescrever (salvar de novo por cima, em pontos diferentes) | não testado | |
| Vários personagens / vários slots | não testado | Só um save de referência foi usado. |
| Sobreviver a reinício do emulador (fechar, abrir, continuar) | ok (parcial) | O soak restaura de `user/saves-backup/` (cópia de `_SaveData`) e o jogo continua dali; reinício natural com o save gravado pela própria sessão não foi cronometrado nem comparado. |
| Tela de gravação (`sceSaveDataDialog*`) não trava | problema potencial | FIX-007 (porte do upstream `05f92b64`, SaveDataDialog reabria para sempre). Evidência antes e depois pendente: medir chamadas a `sceSaveDataDialogOpen` numa gravação (`DES_TRACE`/`calls.json`). Nenhum travamento de gravação foi observado nos soaks. |
| Integridade após fechamento forçado (taskkill) no meio de uma gravação | não testado | Upstream `7675579e` (fsync do save) veio no lote A (FIX-012), sem teste específico. |
| Pasta do dump permanece intocada | ok | FIX-003 (logs do jogo redirecionados para `_HostAppLogs`/`game_logs/`); regra do CLAUDE.md. |

### 1.4 Cutscenes e vídeo (`avPlayer` / `libVideoDec2`, Bink `.bk2`)

| O que testar | Status | Evidência / observação |
|---|---|---|
| Vídeos de abertura tocam e passam (M3.3) | ok (parcial) | `20261023-224632-v120-on`: `ps_studios_logo.bk2` aberto em ~16 s e fechado em 24,5 s; `attract_movie.bk2` abre em 26,6 s. Relato do Ronaldo na `sessao-medicao`: "abertura, menu, 'iniciar' e cutscene inicial rápidos e responsivos". Imagem e áudio dos vídeos não foram avaliados por escrito. |
| Vídeos fecham antes do gameplay e não seguram o ritmo | ok | `knowledge.md` e `nightly-v120`: o contador de `.bk2` abertos volta a 0 antes do HUD (último `off` em 37,7 s, HUD em 61,3 s). |
| Velocidade correta dos vídeos com vblank 120 | problema (corrigido, falta cronometrar) | FIX-009: sem a correção os vídeos tocam em 2x; com `KYTY_MOVIE_PACING` a mediana volta a 60 (`20261023-224632-v120-on`). Pendente cronometrar o logo contra a duração do `.bk2`. |
| Cutscene do jogo ("fog" e cutscene após "continuar jogo") | problema (build antigo) | `sessao-medicao`: cutscene lenta e minutos de tela preta (build sem pré-compilação; causa: tradução de shader refeita a cada execução). Com a pré-compilação o autopilot passa a fog/cutscene em ~16 s (`soak-30m-2`: fog em 47,8 s, HUD em 70,1 s). |
| Pular cutscene (botão) | ok (parcial) | O autopilot "pula cutscenes" por tecla (`tools/autopilot.ps1`, estado `fog`/`cutscene`); só o efeito no soak foi visto. |
| Cutscenes de história (por área) e vídeos de chefe/final | não testado | |
| Vídeos e cutscenes em ultrawide (pillarbox) | não testado | `KYTY_ULTRAWIDE_MOVIES=pillarbox` sem execução registrada (FIX-010, pendente). |

### 1.5 Modos gráficos do jogo (PLAN.md Fase 5 item 7)

| O que testar | Status | Evidência / observação |
|---|---|---|
| Modo desempenho (60 fps, alvo padrão) | ok (parcial) | O build roda a 2560x1440 com fps mediano 60,0 e médias por minuto 58,8–60 do 3º ao 31º min (`20261023-220041-soak-30m-2`). Não está registrado qual modo do menu do jogo estava selecionado: verificar no menu e anotar. |
| Modo cinematográfico (4K/30) | não testado | Não há registro de uso nem de como o engine apresenta esse modo (tabelas de modo de vídeo 3840x2160, FIX-010). |
| Troca de modo pelo menu sem reiniciar | não testado | |
| Resolução de saída/render fixa em 2560x1440 (`--screen-width 2560 --screen-height 1440`) | ok | Flags em todas as execuções do `fg-launch.json`. |

### 1.6 Opções do port

| Opção | O que testar | Status | Evidência / observação |
|---|---|---|---|
| DLSS Super Resolution (`KYTY_DLSS=quality|balanced|performance|dlaa|...`, preset 4.5 M) | Sobe sem crash; qualidade de imagem (HUD, partículas, cabelo, fog); fps e latência com/sem; em Nexus e 1-1 | ok (só inicialização) | FIX-006: `20261023-230538-dlss-fix2`, "Super Resolution ready, mode quality", mediana 60,0 em 46 s, sem queda. Limites: 1 quadro upscalado, nenhum quadro de gameplay comparado. A saída do TAA já é 2560x1440 = render, então ainda não há upscale real (passada pós-TAA não localizada). |
| DLSS + geração de quadros + Reflex (fase B, `desport-dlssb`) | SR+FG juntos estáveis por 30 min; HUD sem artefato; fps/latência | não testado em sessão | `knowledge.md` descreve a fase B (log `DES_DLSS ... combined=<0|1>`); nenhuma execução registrada. Controle: só FG sem DLSS roda 41 s (`20261023-225206-fg-only`). |
| Geração de quadros (`KYTY_FRAMEGEN=<n>`) | Artefatos de HUD e de movimento; ritmo; interação com limite de fps | não testado em sessão longa | `20261023-225206-fg-only` (41 s, sem queda). |
| Ultrawide 3440x1440 (`KYTY_ULTRAWIDE`, `_RENDER`, `_HUD`, `_MOVIES`, `_HUD_LAYOUT`) | FOV correto, HUD ancorado, menus, título, criação de personagem, cutscenes (pillarbox), fps | ok (HUD de gameplay); resto não testado | FIX-010: `20261023-230230-uw-native` (render 3440x1440, UI 3440x1440, `shot-hud.png`). Pendentes: pillarbox de vídeos, `HUD_LAYOUT=16x9`, menus/título/cutscenes, fps. |
| Limite de fps (`KYTY_FPS_LIMIT=0|display|<n>`) | Sem teto realmente sem teto; lógica do jogo (física, animação, timers, input) não acelera acima de 60 | não testado | Hipótese forte (`knowledge.md`): acima de 60 fps o jogo acelera. Experimentos `FPS`/`FPS60` do `perf-ab.ps1` com SpeedProbe foram preparados (commit `0a54f8b`); relatório não registrado nos docs. |
| Vblank 120 (`--vblank-frequency 120`) | Vídeos no ritmo; fps e travadas | ok (curto) | `20261023-224632-v120-on` (60 fps nos vídeos, FIX-009); nightly `nightly-v120` (10 min). Média de 68 fps e p1 de 58 (`knowledge.md`, Desempenho). |
| Readback antecipado (`KYTY_READBACK_PREFETCH=1`, `desport-rb`) | Sem imagem corrompida; `READBACK_QUEUE_MISMATCH` = 0 | não testado | Padrão desligado; experimentos `RB`/`RBQ` do `perf-ab.ps1`. |
| Janela minimizada / coberta / sem foco | 60 fps mantidos, sem congelar | ok | FIX-005: `20261023-224236-int-window` (60 fps nas fases; pior quadro 464 ms ao restaurar). |
| Overlays de terceiros (RTSS, OBS, Steam, Epic) com DLSS/FG | Launcher desliga as camadas por env | ok (por env) | `knowledge.md`: `DISABLE_RTSS_LAYER=1` etc.; `20261023-225553-dlss-nolayers`. |

---

## 2. Áreas do jogo

Legenda das colunas: Imagem / Áudio / Desempenho (fps médio; travadas) / Estabilidade. "n/t" = não testado.
Nenhuma área foi jogada de ponta a ponta até agora. O `HUD: no jogo` do autopilot vem de um save de
referência cuja localização exata **não está registrada**; por isso nenhuma área abaixo está marcada `ok`.

### 2.1 Pré-jogo (não é área do mapa, mas é o que já foi visto)

| Etapa | Status | Imagem | Áudio | Desempenho | Estabilidade | Link |
|---|---|---|---|---|---|---|
| Logo/abertura e menu | ok (parcial) | Visto pelo Ronaldo, sem anomalia relatada (`sessao-medicao`) | n/t | mediana 59,8 fps no menu (`20261023-193518-stats-menu`) | Sem crash | `20261023-183343-sessao-medicao` |
| Seleção de idioma até criação de personagem | ok (parcial) | Visto no build upstream `584c2e8`; sem relato de anomalia (M4.2 não fechado) | n/t | 0–3 fps no build antigo (cache frio, issue upstream #890); 60 fps com FrameGen | Sem crash | `20261023-171535-bisect2-584c2e8c` (PA-001), `20261023-172446-sessao-livre-584c2e8` |
| Tela de título interativa (M3.4) | não testado | n/t | n/t | n/t | n/t | Cenário `title` desativado (sem marco de título) |

### 2.2 Nexus

| Item | Status | Imagem | Áudio | Desempenho | Estabilidade | Link |
|---|---|---|---|---|---|---|
| Nexus (hub, NPCs, Arco-Pedra, ferreiro, mercador) | não testado | n/t | n/t | n/t | n/t | Cenário `soak-nexus-2h` desativado. O soak atual não está documentado como sendo no Nexus. |

### 2.3 Palácio de Boletaria (1)

| Fase | Status | Imagem | Áudio | Desempenho | Estabilidade | Link |
|---|---|---|---|---|---|---|
| Tutorial / 1-1 | problema (desempenho em builds antigos; sem verificação visual formal) | O README do upstream (`9dcff95`) mostra o 1-1 ("Outpost Passage") com HUD e iluminação aparentes corretos (ADR-003, evidência do upstream, não nossa). Nossas capturas guardadas: `shot-hud.png` (HUD, ultrawide) e miniaturas do autopilot em `shots/`. | n/t | 60 fps (mediana) por 30 min de movimento no ponto do save de referência; 52 quadros lentos / 16,2 s, pior 1,9 s (`20261023-220041-soak-30m-2`). Sessão sem pré-compilação: 276 quadros lentos, 178 s (`20261023-202438-fg-sessao1`). Builds antigos: 3–5 fps (`20261023-183343-sessao-medicao`). | Sem crash em 30 min; memória plana em ~12,96 GB do min 15 ao 30 (pico 13,2 GB); congelamentos S-001 só com a janela minimizada, corrigidos em FIX-005 | FIX-002, FIX-004, FIX-005 |
| 1-2 | não testado | n/t | n/t | n/t | n/t | |
| 1-3 | não testado | n/t | n/t | n/t | n/t | |
| 1-4 (chefe) | não testado | n/t | n/t | n/t | n/t | |

M4.3 (tutorial jogável com imagem correta) e M4.5 (30 min contínuos no 1-1) ainda dependem de o Ronaldo
confirmar a localização do save de referência e a imagem; o soak de 30 min cobre a parte de estabilidade.

### 2.4 Stonefang Tunnel (2)

| Fase | Status | Imagem | Áudio | Desempenho | Estabilidade | Link |
|---|---|---|---|---|---|---|
| 2-1 | não testado | n/t | n/t | n/t | n/t | |
| 2-2 | não testado | n/t | n/t | n/t | n/t | |
| 2-3 | não testado | n/t | n/t | n/t | n/t | |

### 2.5 Torre de Latria (3)

| Fase | Status | Imagem | Áudio | Desempenho | Estabilidade | Link |
|---|---|---|---|---|---|---|
| 3-1 | não testado | n/t | n/t | n/t | n/t | |
| 3-2 | não testado | n/t | n/t | n/t | n/t | |
| 3-3 | não testado | n/t | n/t | n/t | n/t | |

### 2.6 Santuário das Tempestades (4)

| Fase | Status | Imagem | Áudio | Desempenho | Estabilidade | Link |
|---|---|---|---|---|---|---|
| 4-1 | não testado | n/t | n/t | n/t | n/t | |
| 4-2 | não testado | n/t | n/t | n/t | n/t | |
| 4-3 | não testado | n/t | n/t | n/t | n/t | |

### 2.7 Vale da Corrupção (5)

| Fase | Status | Imagem | Áudio | Desempenho | Estabilidade | Link |
|---|---|---|---|---|---|---|
| 5-1 | não testado | n/t | n/t | n/t | n/t | |
| 5-2 | não testado | n/t | n/t | n/t | n/t | |
| 5-3 | não testado | n/t | n/t | n/t | n/t | |

### 2.8 Finais

| Final | Status | Imagem | Áudio | Desempenho | Estabilidade | Link |
|---|---|---|---|---|---|---|
| Créditos / vídeo final | não testado | n/t | n/t | n/t | n/t | |
| Finais alternativos (condições de mundo/ personagem) | não testado | n/t | n/t | n/t | n/t | |
| Novo Jogo+ (reinício com save existente) | não testado | n/t | n/t | n/t | n/t | |

---

## 3. Problemas abertos que afetam a jogabilidade (resumo, com fonte)

- Travadas de compilação de shader em cada etapa nova até o cache estático cobrir tudo (46 de 51 travadas;
  `knowledge.md`, Desempenho; `fg-sessao1`). Concentradas nos primeiros ~2,5 min de cada área.
- Memória cresce em degraus de carregamento até 13–14 GB e fica plana (`soak-30m-2`); o alerta da triagem
  (41 MB/min) vem da janela de cálculo incluir o carregamento. Limite de 12 GB do §8.3 está acima do medido
  (pico 13,2 GB): revisar com dados (ver `docs/REGRESSION.md`).
- Acima de 60 fps o jogo acelera (hipótese, `knowledge.md`): relevante para limite de fps e FG.
- DLSS de upscale real depende de achar a passada de upscale pós-TAA (`STATUS.md`).
- Nenhuma área além da do save de referência foi jogada: o maior risco da Fase 5 é encontrar falhas só
  em áreas novas (shaders/efeitos novos, vídeos, áudio de chefes).
