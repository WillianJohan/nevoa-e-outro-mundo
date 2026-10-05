# Atmosfera

| Campo | Valor |
|-------|-------|
| Status | `accepted` |
| Sprints | 0001 (clima), 0005 (som de névoa, overlays, vinheta), 0008 (noite pela luz global), 0009 (névoa como evento, sirene) |

Som, overlays e vinheta rodam no **cliente**: é o que se ouve e o que cada
jogador vê sozinho. Nada disso vai pra rede nem pro save
([ADR-007](../architecture/adr-007-sem-rosto-e-atmosfera-local.md)). O clima é a exceção: roda no **servidor** e chega aos clientes pela
sincronização de clima do próprio jogo.

## Clima

Camada modded do `ClimateManager` via Lua
([ADR-004](../architecture/adr-004-clima-antes-de-shader.md)), escrita no
servidor a cada minuto de jogo (`OnClimateTick`). No solo o servidor roda no
mesmo processo; em MP o cliente não escreve no clima, só recebe.

- **Noite: claramente mais escura e mais fria que a vanilla.** A cor da luz global
  vai pra quase preto, puxado pro azul, com força alta: contra a noite vanilla (com
  ou sem lua) a luz do céu cai ~46% no vermelho e ~40% no azul com `DarkIntensity` 1,
  e 73–89% com 2. Lanterna, poste e luz de casa não
  mudam: de noite, luz vira o que separa ver de não ver.
- **Névoa: do mod, não do clima** ([ADR-009](../architecture/adr-009-nevoa-evento-do-mod.md)).
  O canal de névoa do clima é 0 fora do evento e denso (0.85) durante, com entrada e
  saída de ~20 minutos de jogo. Vale com o clima sombrio desligado: a névoa é o evento.
  Por cima, o look: dessaturação forte (de dia), tint sépia bem escuro, luz ambiente menor. Contra a luz de névoa vanilla (que também escurece)
  a luz do céu cai mais 29–46% com `DarkIntensity` 1, o azul mais (sépia).
- Por que esses canais ([ADR-008](../architecture/adr-008-noite-pela-luz-global.md)):
  o jogo só escurece o céu pela cor e pela força da luz global; a "intensidade" da luz
  não é lida, a dessaturação some de noite (o render multiplica pelo dia), e de
  madrugada a luz ambiente já é zero.
- **O sandbox vanilla "Escuridão à noite" continua valendo** e soma depois do clima:
  "Muito escuro" deixa o céu apagado, "Claro" põe um piso de 25%. A noite do mod
  escurece por cima de qualquer um deles (multiplica), mas não tira o piso.
- Transição de ~20 minutos de jogo (um passo por minuto). No MP chega aos
  clientes a cada 10 minutos de jogo com fade de ~5 s, mesma cadência do
  anoitecer vanilla.
- Intensidade configurável no sandbox.
- A névoa do mod também encurta a visão dos zumbis (o jogo calcula a distância
  de visão pelo valor final da névoa). É intencional: ninguém enxerga na névoa,
  nem eles.
- Névoa do painel de clima do admin passa por cima da nossa camada e não abre evento.
- Resíduo aceito: num dia em que a vanilla teria névoa natural, o jogo ainda puxa a luz
  pro cinza e dessatura um pouco (calcula isso antes da camada do mod), sem névoa
  nenhuma. É o mesmo da opção vanilla "Sem névoa".

## Som

- **Sirene** (evento de névoa): sirene de ataque aéreo, ~24 s, sobe e cai duas vezes,
  tocada pra todo jogador 30 s reais antes da névoa, alta e audível em qualquer lugar
  (toca no próprio jogador). Sem toggle: é o aviso do evento.
- Névoa (`FogAmbience`): um drone grave em loop entra em ~8 s e sai em ~8 s com
  a névoa; ruídos metálicos distantes de vez em quando (a cada 20–60 s).
- Rádio chiando por proximidade do Sem-rosto (`SemRostoEnabled`): loop de estática
  com volume pela distância do Sem-rosto mais perto; para quando a névoa baixa.
- Estalo do Estalador, grito do Corredor.
- Sons originais, gerados por `scripts/gen_sounds.py` ([CREDITS.md](../../CREDITS.md)).

## Overlays (só na névoa)

- `FogOverlays`: manchas de sangue e ferrugem surgem aos poucos (uma a cada
  1,5 s, com fade de 6 s) em tiles livres a 3–12 tiles do jogador, até 40. As que
  ficam a mais de 20 tiles somem. Quando a névoa baixa, todas somem em ~6 s.
- **Locais e só visuais**, sem sincronizar. Cada jogador vê o próprio pesadelo.
  São marcadores de tela (`IsoMarkers`), não objetos do mapa: nada fica no save.
- Visual por nome de sprite vanilla (`overlay_blood_floor_01_*`, e
  `overlay_grime_floor_01_*` tingido de ferrugem).

## Vinheta (só na névoa)

> Vinheta, sangue/ferrugem no chão, drone e rádio **só aparecem no evento de névoa**,
> nunca só de noite. Pra ver sem esperar: `NOM_Debug.fog(true, true)` no console
> (névoa na hora) ou `NOM_Debug.fog(true)` (sirene e névoa 30 s depois).

- `FogVignette`, `FogVignetteIntensity` (1.0, 0–2): as bordas da tela escurecem,
  desfocam e perdem cor, com fade. É o efeito de tela do modo de busca do jogo,
  ligado sem ligar o forrageamento.
- Se o jogador forragear na névoa, a vinheta sai da frente e o forrageamento usa a
  dele; volta quando ele para.

## Shader (spike)

| Status | `accepted` — concluído ([spike](../sprints/spike-shader/README.md)) |
|---|---|

- Override de shader do jogo (grão de filme): arquivado. Vale só pra primeira carga
  de mundo da sessão e troca o shader de todo mundo. A vinheta saiu sem shader.

O jogo trata a névoa do mod como névoa de verdade em todo lugar que lê `getFogIntensity()`: visão dos zumbis, do jogador, combate e o parâmetro de áudio de névoa. É intencional.
