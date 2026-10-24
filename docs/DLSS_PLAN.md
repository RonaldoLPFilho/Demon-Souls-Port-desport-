# Plano: DLSS no engine FrameGen (ADR-004, ADR-008)

Estado em 2026-10-23. Só metadados (nomes de passadas, slots, hashes de shader já públicos no código
do ceremony88); nenhum dado do jogo.

## O que já existe (KytyPS5-DemonsSouls-FrameGen v1.3, `src/local/frame-gen.{h,cpp}`)
- **Geração de quadros DLSS (DLSS-G) + Reflex** via NVIDIA Streamline: `sl.interposer.dll` vira o
  loader Vulkan do processo; `KYTY_FRAMEGEN=<1..3>` quadros gerados; F2 liga/desliga; painel de fps
  (`KYTY_FPS_HUD`). Precisa de RTX 40+ e do agendamento de GPU acelerado por hardware.
- **Entradas temporais do próprio jogo** (marco M4.6 praticamente pronto):
  - passada de TAA: compute shader `0xa44e580f4f0cfb2b` (01.007.000) / `0x934a6e1197b99148` (01.005.000),
    em `renderCompute.cpp`: slot de imagem 1 = profundidade, slot 3 = vetores de movimento;
  - câmera (world→clip atual e anterior) e jitter do TAA: constantes dos vertex shaders do G-buffer
    (tabela de 22 shaders + aprendizado em jogo salvo em `_PipelineCache\framegen-camera-layouts.txt`).
- **Resolução de render** (`KYTY_RENDER_HEIGHT`): baixa a resolução interna do jogo e deixa o TAA do
  próprio jogo reconstruir (TAAU); saída sempre 4K.
- Desde 2026-10-23 o build desport-fg compila com o Streamline SDK **v2.14.1** (`_Build/deps/streamline`,
  fora do git): `KYTY_FRAMEGEN_STREAMLINE=1`. Antes a geração de quadros ficava fora sem aviso.
- O SDK traz `nvngx_dlss.dll` / `nvngx_dlssg.dll` **310.9.1** (a mesma versão do bbport-windows, cujo
  `_DLSS5_Backup` guarda essas originais: o DLSS 5 do bbport é troca de DLL/preset sobre o 310.x).

## O que falta
1. **DLSS Super Resolution / DLAA no lugar do TAA do jogo.**
   - Ponto de inserção: a própria dispatch de TAA. Com `KYTY_RENDER_HEIGHT` baixo, o TAA do jogo já é
     um upscaler (entrada na resolução interna, saída na de tela): o DLSS SR recebe as mesmas entradas e
     escreve na imagem de saída do TAA; a dispatch original é pulada.
   - Entradas: cor antes do TAA, profundidade (slot 1), vetores (slot 3), jitter (câmera), exposição
     (verificar se o jogo tem; senão auto-exposição do DLSS), reset em cortes de câmera.
   - Falta confirmar com captura de quadro (`FrameCapture` deles) os slots de **cor de entrada**,
     **histórico** e **saída** da dispatch de TAA, e o formato (HDR ou não) da cor.
   - Presets: DLAA (render = tela), Quality/Balanced/Performance/Ultra Performance; modelo/preset do
     DLSS 4/5 escolhível (substituição da DLL como no bbport, ou override do preset do driver).
2. **Geração de múltiplos quadros** na RTX 50 (multiplicador até 3 já existe no código; validar 4x).
3. **Interface fora do upscale**: o HUD é composto depois do TAA; confirmar que o DLSS SR não o pega
   (o FrameGen deles já zera vetores no painel de fps).
4. **Configuração** no ini/launcher com as chaves do bbport-windows (`upscaler`, `preset`,
   `frame_gen`, `frame_gen_multiplier`, `frame_gen_fit_display`), quando houver launcher (Fase 7).

## Critério (PLAN.md Fase 7, item 3)
DLSS SR, DLAA e geração de quadros funcionando no 1-1 e no Nexus, sem artefatos graves de HUD ou de
objetos em movimento, com fps e latência medidos com e sem cada opção.
