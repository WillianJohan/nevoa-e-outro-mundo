# Atmosfera

| Campo | Valor |
|-------|-------|
| Status | `accepted` |
| Sprints | 0001 (clima), 0005 (som de névoa, overlays, vinheta) |

Som, overlays e vinheta rodam no **cliente**: é o que se ouve e o que cada
jogador vê sozinho. Nada disso vai pra rede nem pro save
([ADR-007](../architecture/adr-007-sem-rosto-e-atmosfera-local.md)). O clima é a exceção: roda no **servidor** e chega aos clientes pela
sincronização de clima do próprio jogo.

## Clima

Camada modded do `ClimateManager` via Lua
([ADR-004](../architecture/adr-004-clima-antes-de-shader.md)), escrita no
servidor a cada minuto de jogo (`OnClimateTick`). No solo o servidor roda no
mesmo processo; em MP o cliente não escreve no clima, só recebe.

- Noite: luz global menor, leve dessaturação, tint azulado.
- Névoa: dessaturação forte, tint sépia/cinza, névoa mais densa que a vanilla.
- Transição de ~20 minutos de jogo (um passo por minuto). No MP chega aos
  clientes a cada 10 minutos de jogo com fade de ~5 s, mesma cadência do
  anoitecer vanilla.
- Intensidade configurável no sandbox.
- A névoa do mod também encurta a visão dos zumbis (o jogo calcula a distância
  de visão pelo valor final da névoa). É intencional: ninguém enxerga na névoa,
  nem eles.
- Névoa forçada pelo admin (painel de clima) passa por cima da nossa camada e
  não liga o estado de névoa: o gatilho é só a névoa natural.

## Som

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
