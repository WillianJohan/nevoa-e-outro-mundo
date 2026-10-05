# Sprint 0012 — Visual das variantes

| Campo | Valor |
|-------|-------|
| Status | em teste |
| Branch | `sprint/0012-visual-variantes` |
| Plano | [plan.md](plan.md) |
| GDD | [art-direction.md](../../gdd/art-direction.md) (novo), [monsters.md](../../gdd/monsters.md), [Overview.md](../../gdd/Overview.md#decisões-do-autor) |
| ADR | [ADR-012](../../architecture/adr-012-visual-das-variantes.md) (nova); emenda ADR-006 e ADR-005 |

## Objetivo

Na névoa, dá pra saber o que é cada monstro olhando: o Estalador de olhos vendados e pele
de porcelana rachada, o Corredor de boca rasgada e veias escuras, o Sem-rosto com a cabeça
de chiado de TV, a Carpideira de cabelo preto caído no rosto; o Eco é cinza e fumaça. Quando
a névoa baixa, o zumbi volta a ser o de antes.

Decisão do Johan (05/10/2026): textura procedural original em modelo 3D vanilla, sem modelo
novo; "não quero ser igual TLOU... quero me inspirar, então pode ser criativo". A direção de
arte (aprovada) e o porquê de cada visual estão no [art-direction.md](../../gdd/art-direction.md).

## Critérios de aceite

- [x] Visual aplicado quando a variante começa e tirado quando a névoa acaba, com a roupa e o
      `persistentOutfitID` do zumbi intactos — `look_applied_when_variant_starts`,
      `look_removed_when_fog_ends` (os 4 tipos: lista de `ItemVisual` volta igual, pele nil, ID
      igual), `look_semrosto_removed_at_day` (o Sem-rosto, que a passada de dia não revisita),
      `look_period_change_without_edge`; nenhum `dressIn*`/`setPersistentOutfitID` no código do
      visual (ADR-012).
- [x] Cada tipo com o seu visual, e nada pra zumbi comum nem pro Eco por esse caminho —
      `look_each_kind_distinct`, `look_common_zombie_untouched` (zero chamada de visual com 30
      comuns na névoa), `look_eco_untouched`, `look_red_fog_everyone` (vermelha: todos).
- [x] Nada preso em objeto reaproveitado nem em quem o jogo veste depois — `look_reused_object_clean`
      (inclusive o reaproveitado ainda não vestido), `look_waits_until_dressed` (bytecode
      `ModelManager.dressInRandomOutfit` 116–128, `dressInPersistentOutfitID` 1–43).
- [x] Variante morta não deixa peça, pele nem item no corpo (loot e save) — `look_dead_leaves_no_loot`
      (o fake faz o `DoZombieInventory` antes do `OnZombieDead`, como `IsoZombie.onKilled` 45–52,
      e o corpo copia pele, vestidos e inventário, como `IsoDeadBody.<init>` 661–710).
- [x] MP: cada cliente pinta a própria cópia, dona ou remota, sem mandar nada; o dedicado não
      carrega — `look_remote_copy_gets_it_and_nothing_sent` (`sendClientCommand` explode no
      fake), `look_not_on_dedicated_server`; o visual não viaja (`ZombiePacket.set`: só
      `outfitId` e `skinTextureIndex`, pz-api-notes §14.3).
- [x] `NOM_Debug.variant(...)` mostra o visual na passada seguinte e o status conta —
      `look_debug_forced_and_undone` (forçar, trocar de tipo, desfazer), `debug_status_counts_looks`
      (`visuais=N`).
- [x] Orçamento — `look_budget` (pôr ≤ 8 chamadas, tirar ≤ 5, passada sem troca 0); tabela no
      [architecture/README.md](../../architecture/README.md#orçamento-por-sistema).
- [x] Texturas originais, procedurais, no tamanho da vanilla; itens, GUIDs, nomes e créditos —
      `scripts/gen_textures.py` (semente fixa, mesmos bytes ao rodar de novo), `look_assets_*`
      (item → XML → GUID na `fileGuidTable` do mod → textura com o tamanho da vanilla, sem
      `ChanceToFall`, nome em EN e PTBR, outfit do Eco só com itens do mod),
      `look_items_exist_in_script`, `credits_clothing_listed` (modelos vanilla e GUIDs no
      `CREDITS.md`), `credits_every_asset_listed`.
- [ ] Cada visual aparece no jogo, legível de frente no zoom normal — **falta o jogo:**
      roteiro, passos 1–4.
- [ ] O Eco aparece cinza e de véu de fumaça — **falta o jogo:** passo 5.
- [ ] Some no fim da névoa, na morte (corpo e loot limpos) e não aparece em zumbi comum —
      **falta o jogo:** passos 6–7.
- [ ] MP: os dois clientes veem o mesmo visual — **falta o jogo:** passo 8.
- [ ] Sem engasgo grande no começo e no fim de uma névoa vermelha com horda — **falta o
      jogo:** passo 9.

`./run-tests.sh`: `total=451 passou=451 falhou=0` (Lua) e `build total=22 passou=22 falhou=0`.

## Roteiro in-game

Jogo em `-debug`, **save descartável** (o evento avança o contador de névoas salvo). Console
em `~/.var/app/com.valvesoftware.Steam/Zomboid/console.txt` (Flatpak). O Lua e os itens novos
só carregam ao reabrir o jogo (scripts e `fileGuidTable` são lidos no boot). Zoom normal (o
padrão), câmera de frente pro zumbi.

1. **Carregou.** Abrir o save. **Esperado:** nenhuma linha com `NOM_` e `ERROR`, nem
   `ClothingItem not found for ItemVisual`, nem `Could not find item type`, no console.
   Debug → Items, procurar "NOM_": os 6 itens aparecem com nome em português.
2. **Estalador e Corredor.** De dia, Spawn Horde com 5 zumbis a ~6 tiles,
   `NOM_Debug.fog(true, true)`, `NOM_Debug.variant("estalador")` no mais perto. **Esperado:**
   em até 1 s ele fica branco-osso com rachaduras escuras e uma faixa ferrugem tapando os
   olhos; `NOM_Debug.status()` com `visuais=1` (ou mais, se o sorteio já fez outros).
   `NOM_Debug.variant("corredor")` em outro: pele cinza com veias e uma mancha vermelho-escura
   na boca. A roupa deles continua a mesma. **Se** a pele ficar rosa/branca lisa ou a peça
   não aparecer: a textura do mod não foi achada (registrar o caminho e a linha do console).
3. **Sem-rosto.** `NOM_Debug.variant("semrosto")` num terceiro (de longe, pra ele não sumir
   antes de olhar): a cabeça inteira cinza granulada, sem rosto nem cabelo.
4. **Carpideira.** `NOM_Debug.variant("carpideira")`: corpo pálido com escorridos pretos e
   uma massa preta caindo do alto da cabeça sobre o rosto. Ela fica parada e soluça (sprint
   0011).
5. **Eco.** `NOM_Debug.night(true)`, Debug → Time pra noite, `NOM_Debug.spawnEco()`.
   **Esperado:** um vulto quase branco, cinza no corpo todo, de véu claro; nenhum pedaço de
   camisola de hospital.
6. **Fim da névoa.** `NOM_Debug.fog(false)`. **Esperado:** no mesmo instante todos voltam à
   pele e à roupa de antes; `NOM_Debug.status()` com `visuais=0`.
7. **Morte e loot.** Nova névoa, `NOM_Debug.variant("estalador")`, matar. **Esperado:** o
   corpo com a pele e a roupa normais, e nenhum item "Venda de arame enferrujado" no
   inventário do corpo. Zumbis comuns em volta nunca ganharam nada.
8. **MP** (dedicado + 2 clientes). Repetir 2 com o cliente A. **Esperado:** o cliente B,
   olhando o mesmo zumbi, vê o mesmo visual (cada cliente calcula); console do **servidor**
   sem linha do visual. Matar a variante pelo cliente B: o corpo nos dois clientes sem a
   peça. **Se** o corpo aparecer com a peça em um cliente: o `OnZombieDead` não rodou antes
   do corpo local (registrar qual cliente).
9. **Vermelha.** `NOM_Debug.redFog(true)` com ~30 zumbis à vista. **Esperado:** em ~1 s todos
   com visual; FPS (parte 3 do [teste in-game](../../teste-in-game.md#parte-3--medições-15-min)).
   `NOM_Debug.fog(false)`: anotar se há engasgo no instante em que todos voltam.

## Checkpoints

- **04/10/2026** — Sprint aberta pela decisão do Johan (05/10). Pesquisa no bytecode: pele por
  `setSkinTextureName`, peça por `ItemVisual` na lista do zumbi, nada disso no `ZombiePacket`;
  o jogo veste tarde e limpa no reaproveitamento; `DoZombieInventory` vem antes do
  `OnZombieDead`. Plano escrito.
- **04/10/2026** — Texturas procedurais (`gen_textures.py`), itens, XML, GUIDs, nomes; outfit do
  Eco com itens do mod; `NOM_VariantLook` pelo gancho do `NightStats`; status do debug.
- **04/10/2026** — Docs: art-direction, ADR-012, pz-api-notes §14, orçamento, roteiro. Em teste.

## Aprendizados

- **O jogo veste o zumbi tarde.** `isPersistentOutfitInit()` fica false até o `ModelManager`
  criar o modelo, e aí `dressInPersistentOutfitID` limpa pele e lista: pintar antes some sem
  aviso. Pintar só em quem já foi vestido.
- **Na morte, o loot já existe no `OnZombieDead`.** `DoZombieInventory` cria item vestido e de
  inventário de cada `ItemVisual` antes do evento; tirar só a peça da lista deixa o item no
  corpo (e no save).
- **`removeWornItem` não é local.** Ele passa por `setWornItem`, que manda `SyncClothing` no
  cliente de MP; `WornItems.remove` e `ItemContainer.Remove` não mandam nada.
- **`addClothingItem` apaga a roupa do zumbi** que ocupa o mesmo lugar (e não devolve).

## Pendências que a próxima sprint herda

- Tudo do roteiro acima (nada visto no jogo ainda), em especial os UNKNOWNs do
  [pz-api-notes §14](../../architecture/pz-api-notes.md#14-visual-das-variantes-sprint-0012):
  textura do mod pelo caminho, `ItemVisual.new()`, `remove(Object)` no Kahlua.
- Peça por cima de peça: zumbi que já usa chapéu, máscara ou óculos fica com as duas.
- Chiado animado do Sem-rosto: não há textura animada em roupa; fica um quadro.
- Modelos 3D próprios continuam `later` ([Overview](../../gdd/Overview.md#fora-do-mvp-later)).

## Sessões

- 2026-10-05 — abd764e2-7a9a-416b-b9b3-1630ab9e761f — plano, assets, visual, debug, docs
