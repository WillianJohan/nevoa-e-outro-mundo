# Sprint 0015 — Outro Mundo sangrento

| Campo | Valor |
|-------|-------|
| Status | em teste |
| Branch | `sprint/0015-outro-mundo-sangrento` |
| Plano | [plan.md](plan.md) |
| GDD | [atmosphere.md](../../gdd/atmosphere.md#outro-mundo-sangrento-só-na-névoa), [art-direction.md](../../gdd/art-direction.md#o-outro-mundo-sangrento-sprint-0015), [Overview.md](../../gdd/Overview.md#decisões-do-autor) |
| ADR | [ADR-015](../../architecture/adr-015-outro-mundo-sangrento.md) (nova; 015 pra não colidir com a 0014 em paralelo); emenda ADR-007 |

## Objetivo

Na névoa, o mundo em volta do jogador vira o Outro Mundo: muito sangue no chão (poças, rastros) e
nas paredes, e a erosão no máximo (rachaduras, sujeira, musgo, trepadeiras), mais ainda na névoa
vermelha. Tudo só na tela de quem vê: nada vai pro save nem pra rede, e some quando a névoa acaba,
na morte e no menu.

Pedido do Johan (05/10/2026): "o Outro Mundo eu imaginei com bastante sangue e com a erosão no
máximo". As manchas da sprint 0005 (40 no chão, uma a cada 1,5 s) passaram despercebidas; no print
da névoa vermelha ("ainda não tá 'o outro mundo'") a grama, o asfalto, a caixa de correio e a
lixeira estavam limpos, só a cor mudava.

## Critérios de aceite

- [x] Pesquisa com evidência no [pz-api-notes §16](../../architecture/pz-api-notes.md#16-outro-mundo-sangrento-sprint-0015):
      o que é salvo (`IsoObject.save`: anexos, overlay, sangue de parede; `IsoGridSquare.save`: todo
      objeto), o desenho do `IsoMarker` (centrado, com profundidade, sem luz), o
      `RenderOpaqueObjectsInWorld` + `RenderGhostTileColor` (posição de tile, sem profundidade), lados
      e contagens dos sprites (pack `Tiles2x` + `tileDepthTextureAssignments.txt` + `splatBlood`,
      `WallCracks.init`, `WallVines.init`), modelo de custo — bytecode do B42.21.
- [x] Chão com sangue denso (poças de até 3 camadas, rastros, respingos) e erosão (sujeira,
      rachadura, musgo) num raio de 25 tiles; calibrado pro zoom do print (qualquer janela de 7×7
      tiles: ≥ 60% do chão mudado na normal, ≥ 80% na vermelha, quase sempre com sangue) —
      `dressing_rules_pools_and_heavy_floor`, `dressing_rules_visible_at_close_zoom`,
      `overlays_fill_dense_floor`.
- [x] Paredes com sangue, sujeira, rachadura e trepadeira sem objeto no mapa: desenho no quadro do
      mundo, só jogador 0, no andar dele, parede limpa, de frente e à vista — `dressing_rules_walls_by_side`,
      `overlays_walls_drawn_in_frame`, `overlays_walls_skip_cluttered` (fake do sprite explode em
      qualquer método que não o desenho, e fora do evento); sem batente de porta ou janela
      (`overlays_walls_skip_door_and_window_frames`); parede fora da vista volta ao abrir a porta ou
      virar (`overlays_walls_door_closed_then_opened`, `overlays_walls_survive_turning_around`);
      parede que sumiu sai (`overlays_stale_wall_dropped`) (review).
- [x] Determinístico por square e período, estável andando, período novo dá desenho novo, square
      sem chunk tentado de novo — `dressing_rules_deterministic_per_square_and_period`,
      `overlays_deterministic_and_stable_while_walking`, `overlays_new_period_new_layout`,
      `overlays_missing_square_retried`, `overlays_far_and_other_floor_removed`.
- [x] Teto: ≤ 600 marcadores e ≤ 120 paredes, a serviço do que está mais perto: andando 25 tiles
      com o teto cheio, o 7×7 em volta fica com ≥ 85% do que a regra pede e, parado, ≥ 60% coberto
      (≥ 80% na vermelha); teleporte, troca de andar e período conhecido depois de nil enchem em 3 s —
      `overlays_capped`, `overlays_walk_keeps_nearby_covered`, `overlays_teleport_and_floor_change`,
      `overlays_period_known_after_nil` (review).
- [x] Vermelha mais densa (×1,6); densidade do jogador 0–2 em Opções > Mods (`FogOverlayDensity`),
      `FogOverlays` do sandbox continua o liga/desliga — `dressing_rules_red_denser_and_zero_empty`,
      `overlays_red_denser`, `overlay_density_option`, `overlays_density_zero_and_toggle`; trocar a
      densidade (ou forçar a vermelha) redesenha — `overlays_density_change_redresses`;
      traduções EN/PTBR (`translations_lua_keys_defined`).
- [x] Fade de 4 s ao surgir e ao sumir; fim da névoa remove tudo; morte e menu na hora —
      `overlays_fill_dense_floor`, `overlays_fade_out_and_removed_on_fog_end`,
      `overlays_cleared_on_death_and_menu`.
- [x] Nada no mapa, no save ou na rede — `overlays_never_touch_the_map` (square explode em escrita,
      `addBloodSplat` explode, nenhum pacote, ModData intocado); bytecode §16.1.
- [x] Orçamento contado: por quadro 1 chamada por parede desenhada e zero fora da névoa; por
      atualização ≤ 8 por square varrido + 2 por entrada, parado ~150 — `overlays_budget`; tabela no
      [architecture/README.md](../../architecture/README.md#orçamento-por-sistema).
- [ ] Denso e legível no zoom do print, chão no lugar (meio tile acima, ver roteiro) — **falta o jogo:** passos 1–3.
- [ ] Paredes no lugar certo, sem flutuar nem passar por cima do que está na frente — **falta o jogo:** passo 4.
- [ ] Sem engasgo com o teto cheio — **falta o jogo:** passo 5.
- [ ] Some no fim, na morte e no menu — **falta o jogo:** passo 6.

`./run-tests.sh`: `total=532 passou=532 falhou=0` (Lua), `contraste total=4 passou=4 falhou=0` e `build total=25 passou=25 falhou=0`.

## Roteiro in-game

**Antes:** `scripts/dev-sync.sh` (copia `mod/` pra pasta de mods do jogo; não use symlink) e
**recarregue o save** (o Lua novo só entra ao carregar). Jogo em `-debug`, save descartável.
Console em `~/.var/app/com.valvesoftware.Steam/Zomboid/console.txt`.

1. **Névoa.** `NOM_Debug.fog(true, true)`. **Esperado:** no console
   `[NOM] outro mundo: 404 de 404 sprites achados` (menos que 404: anotar o número; os que faltam
   só não aparecem). Em ~4 s o chão em volta enche de sujeira, rachadura e musgo, com poças de
   sangue e rastros saindo delas; `NOM_Debug.status()` mostra `chao=` na casa das centenas e
   `paredes=` > 0 perto de prédios. Nenhuma linha com `NOM_` e `ERROR`.
2. **Vermelha, no zoom do print.** `NOM_Debug.fog(false)`, esperar sumir, `NOM_Debug.redFog(true)`,
   aproximar o zoom como no print (rua, grama, caixa de correio). **Esperado:** de relance, rua e
   grama tomadas de sangue e sujeira, bem mais que na normal. **Se** o sangue some debaixo da grama
   alta: registrar (a grama é desenhada por cima do marcador).
3. **Posição do chão.** Olhar uma poça perto de uma parede ou meio-fio. **Esperado:** o desenho fica
   ~meio tile acima do square (jeito do marcador do jogo, igual pra todos); se incomodar, registrar.
4. **Paredes.** Entrar numa casa e olhar as paredes do fundo (norte e oeste do cômodo). **Esperado:**
   sangue escorrido, sujeira, rachaduras e trepadeira grudados na parede, no lugar certo; nada nas
   paredes que o jogo corta (as da frente). Girar: as que saem da visão somem com fade. **Se** o
   desenho flutuar fora da parede, ficar por cima de móvel ou de árvore, ou piscar: registrar com print.
   **Batentes:** olhar uma porta aberta (ou sem porta) e uma janela quebrada numa parede suja.
   **Esperado:** nada desenhado sobre o batente nem tapando o buraco; a parede do lado, sim. **Se**
   tapar: anotar o sprite do batente (clique direito > debug) — falta um nome de propriedade.
5. **Custo.** Com F3/FPS do debug, densidade 2 (Opções > Mods > "Sangue e erosão na névoa") e névoa
   vermelha, andar 30 s. **Esperado:** sem queda de FPS perceptível contra a densidade 0. **Se**
   pesar: anotar FPS nas duas; os botões são `MAX_FLOOR`, `MAX_WALL` e `SCAN_BUDGET`.
6. **Saída.** `NOM_Debug.fog(false)`: tudo some com fade em ~4 s. De novo na névoa: morrer (some na
   hora) e sair pro menu e voltar (nada sobra; `NOM_Debug.status()` com `chao=0 paredes=0` fora da névoa).

## Checkpoints

- **04/10/2026** — Sprint aberta. Bytecode: `IsoMarkers` (desenho e profundidade),
  `RenderOpaqueObjectsInWorld` + `IsoSprite.RenderGhostTileColor`, save do `IsoObject` e do
  `IsoGridSquare`, sprites de parede pelo pack e pelas profundidades. Plano escrito.
- **04/10/2026** — Regras puras, cliente reescrito (chão por marcador com camadas, paredes no
  quadro), opção de densidade, status do debug. Calibrado pelo print do Johan na vermelha (chão
  ~85% coberto). Docs: ADR-015, pz-api-notes §16, GDD, orçamento. Em teste.
- **04/10/2026** — Review: o teto cheio deixava quem anda no limpo (agora serve o mais perto),
  paredes fora da vista perdidas (agora só apagam), batentes de porta e janela, parede conferida em
  rodízio, redesenho ao trocar período ou densidade. Merge da main (sprint 0014).

## Aprendizados

- **`IsoMarker` não desenha sprite de tile na posição do tile.** Ele centra o recorte da textura no
  meio do square com a base no meio (`renderTextureWithDepth`): chão sai meio tile acima, parede cai
  fora da parede. Pra parede, só o desenho de fantasma (`RenderGhostTileColor`), que por sua vez
  desliga a profundidade.
- **`getSprite(nome)` com nome que não existe cria um sprite vazio** (`IsoSpriteManager.AddSprite`):
  conferir com `getTexture` antes, senão o mapa de sprites do jogo cresce com lixo.
- **Lado da parede dá pra ler sem o jogo:** a tabela do `.pack` tem o recorte (`ox`, `w`) de cada
  textura no quadro de 128×256 (metade esquerda = W), e o `tileDepthTextureAssignments.txt` diz a
  profundidade (`preset_depthmaps_01_4` = W, `_5` = N). Os dois bateram em todos os sets.
- **Teto que recusa o novo prende o velho:** com 600 marcadores cheios a ~15 tiles, quem andava
  ficava no limpo (o que ficou pra trás ainda estava "no raio"). O teto tem que servir o mais perto:
  raio efetivo que encolhe quando enche, e o resto sai na hora.
- **Módulo que sai cedo com `isServer()` deixa `package.loaded` = `true` e o global nil:** um teste
  de dedicado envenenou outro que não recarregava o módulo. Recarregar tudo o que o arquivo testado
  exige.

## Pendências que a próxima sprint herda

- Tudo do roteiro; em especial a parede desenhada sem profundidade (pode passar por cima de árvore
  ou poste de outro square) e o custo com o teto cheio.
- Objetos (caixa de correio, lixeira, carro) não ganham sujeira: não há sprite de overlay pra eles
  e anexar no objeto vai pro save. Ideia se faltar: grime de borda no overlay de tela (sprint 0013).
- O chão meio tile deslocado (jeito do `IsoMarker`); se incomodar, desenhar o chão também pelo
  fantasma, mas aí sem profundidade (passaria por cima de paredes na frente).
- Tela dividida: as paredes só pro jogador 0 (o chão é do andar de quem estiver no `IsoMarkers`).
- Com o teto cheio, o raio efetivo fica em ~13–15 tiles; com zoom bem afastado, a borda da tela
  fica limpa. Se incomodar, subir `MAX_FLOOR` depois de medir o FPS (roteiro, passo 5).
- Mouse fora do mapa: o jogo não dispara o evento do quadro, as paredes somem nesse quadro.

## Sessões

- 2026-10-05 — abd764e2-7a9a-416b-b9b3-1630ab9e761f — pesquisa, plano, implementação, calibração pelo print
