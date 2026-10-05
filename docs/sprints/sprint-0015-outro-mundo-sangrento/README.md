# Sprint 0015 — Outro Mundo sangrento

| Campo | Valor |
|-------|-------|
| Status | em andamento |
| Branch | `sprint/0015-outro-mundo-sangrento` |
| Plano | [plan.md](plan.md) |
| GDD | [atmosphere.md](../../gdd/atmosphere.md#outro-mundo-sangrento-só-na-névoa), [art-direction.md](../../gdd/art-direction.md#o-outro-mundo-sangrento-sprint-0015), [Overview.md](../../gdd/Overview.md#decisões-do-autor) |
| ADR | [ADR-015](../../architecture/adr-015-outro-mundo-sangrento.md) (nova); emenda ADR-007 |

## Objetivo

Na névoa, o mundo em volta do jogador vira o Outro Mundo: muito sangue no chão (poças, rastros) e
nas paredes, e a erosão no máximo (rachaduras, sujeira, musgo, trepadeiras), mais ainda na névoa
vermelha. Tudo só na tela de quem vê: nada vai pro save nem pra rede, e some quando a névoa acaba,
na morte e no menu.

Pedido do Johan (05/10/2026): "o Outro Mundo eu imaginei com bastante sangue e com a erosão no
máximo". As manchas da sprint 0005 (40 no chão, uma a cada 1,5 s) passaram despercebidas.

## Critérios de aceite

- [ ] Pesquisa com evidência no [pz-api-notes §16](../../architecture/pz-api-notes.md#16-outro-mundo-sangrento-sprint-0015):
      mecanismo de parede local e sem save, nomes dos sprites com contagem, modelo de custo.
- [ ] Chão com sangue denso (poças e rastros) e erosão (sujeira, rachadura, musgo) num raio de 25 tiles.
- [ ] Paredes com sangue, sujeira, rachadura e trepadeira, sem objeto no mapa.
- [ ] Posição determinística por square e período, estável enquanto o jogador anda; refeita ao andar,
      com teto de marcadores e de paredes.
- [ ] Névoa vermelha mais densa que a normal; densidade por opção do jogador (0–2).
- [ ] Entra e sai com fade; some no fim da névoa, na morte e no menu.
- [ ] Nada escrito no mapa, no save ou na rede.
- [ ] Orçamento por atualização e por quadro contado e na tabela da arquitetura.
- [ ] No jogo: denso, legível, nas paredes certas e sem engasgo — roteiro abaixo.

## Checkpoints

- **04/10/2026** — Sprint aberta. Bytecode: `IsoMarkers` (desenho e profundidade),
  `RenderOpaqueObjectsInWorld` + `IsoSprite.RenderGhostTileColor`, save do `IsoObject` e do
  `IsoGridSquare`, sprites de parede pelo pack e pelas profundidades.

## Aprendizados

## Pendências que a próxima sprint herda

## Sessões

- 2026-10-05 — abd764e2-7a9a-416b-b9b3-1630ab9e761f — pesquisa, plano, implementação
