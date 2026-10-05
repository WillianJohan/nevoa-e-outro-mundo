# ADR-012 — Visual das variantes: pele e peça na cópia local, sem mexer no outfit

| Campo | Valor |
|-------|-------|
| Status | `accepted` |
| Data | 2026-10-05 |
| Emenda | [ADR-006](adr-006-variantes-deterministicas.md) ("a variante não tem roupa própria" deixa de valer: tem visual, que não é outfit) e [ADR-005](adr-005-quem-simula-aplica.md) (o visual vai em toda máquina que renderiza) |

## Contexto

O Johan decidiu (05/10/2026) que cada monstro tem visual próprio, de textura procedural
original em modelo vanilla ([art-direction.md](../gdd/art-direction.md)). A restrição é a
[ADR-006](adr-006-variantes-deterministicas.md): a variante sai do `persistentOutfitID`, e
vestir outro **outfit** troca esse ID e, com ele, a variante. O que o B42 dá
([pz-api-notes §14](pz-api-notes.md#14-visual-das-variantes-sprint-0012)):

- O que se vê do zumbi é a `HumanVisual` (pele, cabelo) e a lista `getItemVisuals()`
  (`ArrayList<ItemVisual>`). Mexer nas duas e chamar `resetModelNextFrame()` é o que o
  tutorial vanilla faz num zumbi (`client/Tutorial/Steps.lua:832-838`). Nenhuma das duas
  toca o `persistentOutfitID`.
- `setSkinTextureName(nome)` troca a pele inteira (`media/textures/Body/<nome>.png`); zumbi
  normal tem o campo nulo.
- `ZombiePacket` leva só `outfitId` e `skinTextureIndex`: cada máquina monta o visual do
  zumbi pelo ID. O zumbi vivo vai pro popman só com o ID (nunca salvo com visual).
- O jogo veste tarde (na criação do modelo, `dressInPersistentOutfitID` limpa pele e lista) e
  limpa a `HumanVisual` no reaproveitamento.
- Na morte, `DoZombieInventory` faz item vestido e de inventário de cada `ItemVisual` antes
  do `OnZombieDead`; o corpo copia pele, itens e inventário depois, e o corpo é salvo.

## Decisão

1. **Visual = pele + uma peça**, por variante (Sem-rosto: só a peça), em itens do mod
   (`media/scripts/NOM_clothing.txt`, `module Base`) cujos XML apontam modelos vanilla pelo
   nome e texturas de `scripts/gen_textures.py`. GUIDs na `media/fileGuidTable.xml` do mod.
   Sem `ChanceToFall` (não caem da cabeça). As quatro peças das variantes ficam em
   `base:zeddmg` (multi-item e sem exclusão, `shared/NPCs/BodyLocations.lua:859`, o lugar
   das feridas de zumbi): num lugar comum, o `WornItems.setItem` do `DoZombieInventory`
   expulsaria o chapéu, a máscara ou os óculos do próprio zumbi na morte (review da 0012).
2. **Quem renderiza pinta a própria cópia:** `client/NOM_VariantLook.lua` (não carrega no
   servidor dedicado) instala o gancho `NOM_NightStats.look`. A passada do `NightStats`, que
   já calcula a variante de cada zumbi local (dono ou remoto) em lotes, chama o gancho com
   o tipo ou nil. Uma tabela Lua guarda o que este processo pôs: sem troca, zero chamada.
3. **Pôr só em quem já foi vestido** (`isPersistentOutfitInit()`); senão espera a próxima
   passada. **Nunca em jogador reanimado** (`isReanimatedPlayer()`): o `ReanimatedPlayers`
   salva o zumbi com `HumanVisual.save`, que grava o `skinTextureName`. A marca na tabela vem
   antes de tocar no zumbi, e o `NightStats` chama o gancho em `pcall`: uma surpresa da API
   no jogo não vaza a pele (o fim da névoa tira) nem para a passada dos stats. A marca guarda
   o `persistentOutfitID`: se o jogo vestir de novo com outro ID (lista e pele somem), pinta
   de novo.
4. **Tirar:** na borda do fim da névoa (todos de uma vez), quando o tipo muda (debug,
   período novo), no `OnZombieCreate` (objeto reaproveitado) e no `OnZombieDead` (também o
   item vestido e o do inventário que o `DoZombieInventory` acabou de criar, por
   `WornItems.remove` e `ItemContainer.Remove`, que são locais). Tirar = `remove` do objeto
   que este processo pôs + pele nil. A tabela guarda objetos de zumbi, que o jogo recicla
   num pool: o tamanho dela é limitado pelo pool, e todo objeto sai no fim da névoa.
5. **Eco:** só dados. Ele nasce com o outfit `NOM_Eco` do mod, que passa a vestir
   `NOM_EcoCinza` (camada no corpo todo, sem modelo, como a `Gown_Hospital`) e
   `NOM_EcoVeu`. Mudar os itens de um outfit não muda o índice dele na lista nem o ID. Na
   morte do Eco, além do inventário (sprint 0002), o `NOM_Eco` limpa o `WornItems`
   (`WornItems.clear`, local): se a remoção do corpo falhar, ele não fica vestido com eles.

## Alternativas recusadas

| Alternativa | Por que não |
|---|---|
| Outfit próprio por variante | Troca o `persistentOutfitID` e, com ele, a variante (ADR-006). |
| `HumanVisual.addClothingItem` | Remove da lista o que ocupa o mesmo lugar: a roupa do zumbi sumiria e não voltaria. |
| Tirar re-vestindo (`dressInPersistentOutfitID`) | Também limpa o sangue e os buracos da luta; o `remove` do objeto é exato. |
| Pintar só no servidor e mandar pros clientes | O visual nem viaja; o servidor dedicado não renderiza. |
| `removeWornItem` na morte | `IsoGameCharacter.setWornItem` manda `SyncClothing` no cliente de MP. |
| Camada no corpo (sem modelo) também pras variantes | Mesmo efeito da pele, mas é mais um item na lista e mais chamadas; a pele é um campo só. |

## Consequências

- O visual aparece na passada seguinte à névoa (ou ao debug): com N zumbis, até N/20 ticks.
  Zumbi longe da tela ganha quando o jogo o veste.
- Custo ([orçamento](README.md#orçamento-por-sistema)): pôr ≤ 9 chamadas por zumbi, tirar
  ≤ 5, uma vez por borda; o zumbi comum não paga nada. Cada troca refaz a textura do modelo
  daquele zumbi (`resetModelNextFrame`): na névoa vermelha, todos de uma vez, e no fim dela
  todos no mesmo tick — pode engasgar. Medir no jogo; se pesar, espalhar o tirar pelos
  lotes da passada em vez da borda.
- As peles do mod são RGB; as de zumbi vanilla são RGBA (o alfa da pele vanilla pode ter
  uso no compositor). Conferir no jogo; se a pele sair com buraco ou preta, gerar com alfa
  opaco.
- A peça em `base:zeddmg` não tem máscara de corpo nem `setHideModel` próprios; que um
  modelo com malha renderize nesse lugar é UNKNOWN (os 77 itens vanilla dele são camadas
  sem modelo). Roteiro da sprint.
- O zumbi que já usa algo no mesmo lugar fica com as duas peças (podem atravessar).
- Depende de UNKNOWNs que só o jogo responde (roteiro da sprint): textura de mod pelo caminho
  em `Body/` e `NOM/`, `ItemVisual.new()` no Lua, `remove(Object)` escolhido pelo Kahlua,
  `OnZombieDead` no cliente de MP antes do corpo local.
