# Decisões de arquitetura (ADRs)

Formato curto: contexto, decisão, consequências. Numeração sequencial; um ADR substituído
continua aqui, marcado como tal.

---

## ADR-000 — O que aprendemos com o bbport (2026-10-23)

**Status:** aceito. Fonte: `D:\games\bloodborne_pc-0.4` (bbport 0.4, somente leitura).

**`README.md`.** O bbport se define como "Wine + DXVK para um jogo só": o eboot do Bloodborne
1.09 roda direto na CPU x86-64, um runtime em C (~5 mil linhas com o loader) implementa só as
funções do sistema que o jogo chama, e os gráficos usam o núcleo de vídeo e o recompilador de
shaders do shadPS4, incorporados com ~200 mudanças marcadas `bbport:`. A tabela "How it differs
from shadPS4" mostra a ordem real das coisas: primeiro carregar offline (imagem pré-linkada com
`libc.prx` e `libSceFios2.prx` como código nativo), depois um runtime mínimo, e só por último
mexer no modelo de memória e no processador de comandos (o "modo novo" é experimental e **só
AMD**, porque o driver NVIDIA não mapeia a memória do jogo como precisa). O projeto aceita
uma única versão do jogo e recusa as outras com mensagem clara (`game_check.py`); a base
1.00 sem update trava num endereço conhecido. Lição para nós: fixar uma versão, checá-la no
início, e não depender de nada exclusivo de AMD.

**`docs/EMULATION_REMOVAL_PLAN.ru.md`.** Plano de 2026-10-06 de remoção da emulação. Ponto
central: como o Bloodborne tem a libGnm estática, os pacotes PM4 são escritos pelo próprio jogo
por 99 métodos de `sce::Gnm::*CommandBuffer`; interceptando-os (`BB_GNM_OBSERVE=1`) provaram
que 100% dos pacotes vêm de chamadas conhecidas, então decodificar PM4 e traduzir as chamadas
é a mesma coisa. A emulação que sobra (cópias em VRAM, constant engine executado na CPU, SRT
walker, cache de texturas por endereço) existe porque o tradutor lê descritores de recurso
(T#/V#/S#) da memória do jogo na CPU. Próximos passos deles: remover o modelo de memória 0.2,
paralelizar o estágio de gravação de draws, descritores lidos pela GPU (bindless), texturas
como objetos criados no carregamento, shaders traduzidos na instalação. Para o desport: no PS5
a camada equivalente é a AGC (`engine/src/libs/agc.cpp`, `libAgcDriver.cpp`); na Fase 4 vale
medir se a AGC também é estática no eboot ou vem como `.prx`, porque isso decide se a fronteira
da API é a chamada ou o pacote.

**`docs/ROADMAP.md` e `docs/history/*`.** Histórico real (em russo). Os tipos de bug que
apareceram: gargalo de um thread só no processador de comandos (26 → 64 FPS movendo gravação
Vulkan para outro thread, depois +19% com pipeline de 2 estágios); travadas de carregamento por
cópias de memória do jogo; cintilação de interface por fences visíveis ao jogo antes das cópias
terminarem; e o mais instrutivo: **corrupção do heap do jogo após 13–17 min** porque a
interrupção "GPU ociosa" saía antes de rótulos EOP adiados para o thread de gravação, e o jogo
liberava objetos ainda em uso — 7 de 7 execuções travavam, corrigido e validado com 2 × 30 min.
Lição: bugs de sincronização GPU/CPU só aparecem em sessões longas; o `soak` precisa existir
desde a Fase 4, e cada correção precisa de contagem antes/depois (o bbport registra assim).

**`docs/parallel_gpu.md`.** Medições do processador de comandos (~65–80 command buffers e ~1600
draws por quadro) e o perfil do thread de GPU (bind de texturas ~25%, seleção de pipeline ~19%,
bind de buffers ~14%, PM4 só ~3%). Restrições: command buffers herdam estado de registradores;
a preparação de draw lê memória do jogo que pacotes anteriores podem mudar; caches pensados
para um thread. A solução foi preparação especulativa em workers validada no thread principal
(correção nunca depende dos workers), depois pipeline de 2 estágios, sempre com um bit de
alternância em tempo de execução para A/B. Para o desport isso é Fase 7: só depois de medir.

**`scripts/prepare.py`.** Lê o SELF **do PS4 já em texto claro** (magic `4F 15 3D 1D`), valida
ELF x86-64, copia os segmentos para um ELF reconstruído e monta uma imagem de memória plana.
Toda leitura passa por `span(data, offset, size)` com checagem de limites; qualquer segmento
com flag de criptografia/compressão (`flags & 10`) aborta com `encrypted/compressed SELF
segment is unsupported`. Lê o segmento dinâmico do formato Sony (tags `0x61000xxx`: tabela de
strings, símbolos, relocações), aplica relocações relativas e marca imports para o runtime,
verifica por evidência (não por suposição) que `_init_env` da `libc.prx` é só `RET`, e grava
`out/boot.bin` (formato próprio, pequeno, sem empacotamento de struct do host) e
`out/analysis.json`. NIDs são calculados por SHA-1 com sal fixo, em base64. Padrão a copiar no
`tools/inspect_self.py`: `span()`, recusa explícita, "provar em vez de assumir", JSON de
saída; o magic e os offsets do PS5 vêm do `engine/src/loader/elf.cpp`, nunca daqui.

**`scripts/link_modules.py`.** Sucessor do `link_libc.py`: junta o eboot e os módulos do
próprio dump (`libc.prx`, `libSceFios2.prx`) numa só imagem, cada módulo alinhado a 64 KiB
após o anterior, com **uma tabela de imports compartilhada** — assim o runtime em C pode
sobrescrever qualquer função ("contratos do host primeiro") e, se não sobrescrever, a ligação
vai para o export nativo do módulo. Exports são casados por (NID, identidade da biblioteca,
identidade do módulo); imports de `libSceLibcInternal` são servidos pelos exports de mesmo NID
da `libc.prx`. Trata TLS por módulo (relocação tipo 16), troca `mov rax, fs:[0]` por GS
porque no Linux a glibc é dona do FS, rejeita exports ambíguos, e grava `out/link.json` com
imports não resolvidos. É o modelo do `port/tools/link_modules.py` da Fase 6.

**`scripts/link_libc.py`.** Versão anterior, só com a libc. Leitura histórica; é de onde vem
`encode_id` (codificação dos IDs de biblioteca/módulo).

**`scripts/patches.py`.** Compila patches XML (formato shadPS4/GoldHEN) em `out/patches.bin`
para o loader aplicar no início; endereços relativos à base 0x400000 do eboot; só escritas
literais (bytes, inteiros, floats, utf8/16), padrões com máscara são recusados. Também traduz
opções do lançador (FPS, resolução, efeitos) em listas de patches nomeados. Para o desport:
começar pelo `GamePatch` do KytyPS5 (Fase 2) e só ter compilador próprio na Fase 7.

**`src/probe.c`.** Loader em C: checa a CPU antes de tudo (AVX, BMI1, MOVBE, LZCNT, POPCNT,
SSE4.2, com mensagem dizendo qual CPU é necessária), lê `boot-linked.bin`, aloca a imagem,
aplica relocações, resolve cada import pelo runtime e, se não houver implementação, liga a um
trampolim que para com `STOP: first unsupported PS4 import: <nome>` e o endereço de quem
chamou (nunca retorna sucesso falso). Tem tratador de falha que distingue "falha no convidado
no offset X" de "falha no host em lib+offset", e um watchdog que despeja RIP e cadeia de frames
de todos os threads. Para o desport (Fase 6): o mesmo esqueleto, com checagem das instruções
do Zen 2 e com o diagnóstico de falha/travamento desde o primeiro dia.

**`src/runtime.h` e `src/runtime_*.c`.** Um `runtime_<área>_resolve(nid)` por área (kernel,
memory, thread, mutex, rwlock, sema, time, file, audio, ajm, pad, rtc, savedata, services,
content), cada um com sua tabela `RuntimeExport {nome, função}` e um `*_report()` para
estatística. Convenções importantes: errno visível ao jogo usa a numeração do FreeBSD
(`runtime_guest_errno`), erros no formato `0x8002xxxx`, ABI `sysv_abi` explícita nas funções
chamadas pelo jogo (relevante no Windows, onde a ABI padrão é outra), sistema de arquivos com
montagem de `/app0` e diretório de usuário configuráveis. É o formato do `port/runtime/`.

**`gpu/shadps4/`, `gpu/shim/`, `tools/re/`, `tools/*.sh`.** O núcleo gráfico do shadPS4 vive
vendorizado com `VENDOR.txt`; a ponte C↔C++ é `gpu/bbgpu.h` mais o `shim/` (hooks Gnm, cópias,
memória do jogo, overlay, trace de esperas). `tools/re/` tem grafo de chamadas, tabela de
funções Gnm e varredura de PM4. A automação (`frame.sh`, `shot.sh`, `soak*.sh`, `ab.sh`) se
apoia em variáveis de ambiente que alternam comportamentos em tempo de execução — esse é o
padrão para nossos `run.ps1`, `soak.ps1` e `frame_diff.py`.

**Decisão.** Seguir a ordem do bbport (fazer funcionar, medir, depois enxugar), copiar seus
padrões de engenharia (`span()` com limites, recusa explícita de dados criptografados, prova
por evidência, marcações no código vendorizado, parada clara em import não implementado,
diagnóstico de travamento, toggles A/B) e **não** copiar formatos: tudo que é específico do
PS4 (magic do SELF, NIDs, Gnm/GCN) é substituído pelo equivalente do PS5 tirado do KytyPS5.

**Consequências.** `tools/inspect_self.py` (Fase 1) nasce com o padrão do `prepare.py`; a
Fase 6 tem um modelo concreto de loader/runtime/linker; o modo de memória "só AMD" fica fora
do escopo nesta máquina (RTX 5080).

---

## ADR-001 — Versão alvo do jogo

_Pendente (Fase 0, tarefa 2): fixada pela leitura de `sce_sys/param.json` do dump._

## ADR-002 — Fork do KytyPS5, commit base e política de rebase (2026-10-23)

**Status:** aceito.

**Contexto.** O desport é um fork do KytyPS5 com uma camada própria do Demon's Souls
(PLAN.md §0, Trilha A). O código do engine precisa poder ser rebaseado sobre o upstream sem
perder o que é nosso.

**Decisão.**
- Fork: `https://github.com/RonaldoLPFilho/KytyPS5`, de propriedade do Ronaldo.
- Submódulo em `engine/` apontando para o fork, com `branch = desport` no `.gitmodules`.
- Branch `desport` criada a partir de **`9dcff95e809ec43ba66f56648164070f4b16348f`**
  (2026-10-23 09:51 +0200, "shader: fix crash from packed ancillary used as DPP old operand
  (#1769)"). Nessa data, o `main` do upstream e o do fork estavam ambos nesse commit.
- Toda mudança no engine leva `// desport: <motivo>` (PLAN.md §1.2 regra 6), e mudanças
  específicas do jogo preferem `game/` a editar o engine.
- **Rebase** (PLAN.md §10.3): a cada 2–4 semanas, ou quando o upstream corrigir algo do Demon's
  Souls, rebasear `desport` sobre `upstream/main`, rodar a suíte de regressão inteira (§8.3) e
  registrar aqui o novo commit base. Os conflitos são localizados por `grep -rn "desport:"`.
- PRs ao upstream saem de branches isoladas a partir do `main` do upstream, preparados pelo
  agente em `docs/upstream/` e escritos e enviados pelo Ronaldo (PLAN.md §11).

**Consequências.** O commit do submódulo registrado no desport identifica exatamente o engine
de cada execução (o `run.ps1` grava o hash em `run.json`). A branch `desport` precisa ser
publicada no fork para que um clone do desport consiga inicializar o submódulo.

### Histórico de commits base (ADR-002)
| Data | Commit base upstream | Motivo |
|---|---|---|
| 2026-10-23 | `9dcff95` | início do projeto |

---

## ADR-004 — Requisito: DLSS (incluindo DLSS 5) e geração de quadros (2026-10-23)

**Status:** aceito (requisito do Ronaldo). Numeração: ADR-003 fica reservado ao portão da
Fase 2 (PLAN.md §6).

**Contexto.** O bbport-windows (`D:\games\bbport-windows`, só leitura) já entrega, no
Bloodborne:
- DLSS nativo por `bin/bbport_dlss.dll` (licença MIT, IFreemz e contribuidores do bbport)
  sobre o NGX (`bin/nvngx_dlss.dll` 310.9.1.0), com escolha de upscaler e preset no
  `bbport.ini` (`upscaler=dlss`, `preset=`);
- geração de quadros (`bin/nvngx_dlssg.dll`; `frame_gen`, `frame_gen_multiplier`,
  `frame_gen_fit_display` no `bbport.ini`);
- um caminho "DLSS 5" **de terceiros**, via add-on ReShade (`renodx-dlss5.addon64` /
  `dlss5-feed.addon64`), que copia cor, profundidade, vetores de movimento e máscara do Vulkan
  para imagens D3D12 compartilhadas e avalia lá. Nesta máquina ele **travou** no primeiro quadro
  avaliado (`bin/dlss5-feed.log`: `0xC0000005` em `renodx-dlss5.addon64`, 2026-10-10).
O código-fonte do `bbport_dlss.dll` não está em `D:\games\bloodborne_pc-0.4`; só a DLL.

**Decisão.**
1. O desport terá, como requisito do produto final: **DLSS Super Resolution / DLAA** na versão
   mais recente do DLSS disponível, **incluindo DLSS 5**, e **geração de quadros DLSS**
   (com multiplicador; a RTX 5080 suporta geração de múltiplos quadros), com **Reflex** (exigido
   pela geração de quadros para manter a latência). FSR fica como alternativa para GPUs que não
   são NVIDIA.
2. A integração é **nativa no renderer** (como o `bbport_dlss.dll`), não por injeção ReShade.
   O caminho por add-on fica só como referência: depende de cópias Vulkan→D3D12 por quadro e é
   o que travou aqui.
3. **Quando:** a implementação continua na Fase 7 (não se otimiza algo que ainda não
   funciona, PLAN.md §0). Mas as **entradas** que o DLSS exige passam a ser trabalho da Fase 4:
   identificar no quadro do jogo a cor antes da interface, a profundidade, os vetores de
   movimento, o jitter, as matrizes de câmera e a separação da interface, e registrar em
   `docs/GPU_NOTES.md` §"Entradas temporais". Um protótipo de DLSS SR no fork pode começar após
   o M4.3, se as entradas estiverem identificadas.
4. Pontos a verificar antes de implementar (não assumir):
   - em quais APIs o DLSS 5 roda (o add-on de terceiros usa D3D12; o renderer do KytyPS5 é
     Vulkan) e como ele é distribuído (SDK NGX/Streamline, versão das DLLs);
   - suporte da geração de quadros DLSS em Vulkan pelo Streamline/NGX, e a extensão de baixa
     latência (`VK_NV_low_latency2`) para o Reflex;
   - licença de redistribuição das DLLs da NVIDIA (o bbport-windows inclui
     `licenses/NVIDIA-DLSS-LICENSE.txt`) e compatibilidade com o projeto GPL-2.0-only:
     as DLLs ficam como componentes separados, carregados em tempo de execução, nunca no git.

**Consequências.** A Fase 4 ganha uma tarefa e um marco (entradas temporais catalogadas). A
geração de quadros exige que a apresentação do KytyPS5 (`src/graphics/presentation/`) aceite
quadros intercalados e controle o ritmo de exibição; isso deve ser considerado ao mexer no
`videoOut` nas Fases 3–4. Vantagem esperada sobre o Bloodborne: o Demon's Souls de PS5 é de
2020 e usa reconstrução temporal, então é provável que já gere vetores de movimento e jitter
(a confirmar na Fase 4), enquanto o bbport precisou calculá-los à mão.
