# Brasa no corpo inteiro — Plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Na mutação e na volta da variante, o zumbi inteiro queima: uma casca de brasa (malha Hazmat vanilla, textura de carvão e brasa do mod, shader `NOM_Dissolve`) cobre o corpo e se desfaz revelando o monstro; na volta, ela queima por cima do monstro, a troca acontece embaixo dela e ela se desfaz revelando o zumbi comum. Brasas sobem do zumbi no começo de cada transição.

**Architecture:** O corpo continua no `basicEffect` (sem Java). A técnica é a da casca do Eco (sprint 0018), mas no zumbi **vivo**: um `ItemVisual` `Base.NOM_Brasa` entra na lista `getItemVisuals()` (local, sem rede, sem save, como as peças desde a 0012) e o `client/NOM_Dissolve.lua` dirige o `Alpha`. Como todo item com shader no zumbi lê o **mesmo** `Alpha`, a casca só anda junto com peças **sem** shader: quando a casca é usada, a peça da variante é a original (sem `Fx`), e o desfazer da casca é o modo `"out"` (limiar 1 → 0). Volta: `"in"` (a casca se forma), troca (`strip`) no fim e `"out"` de novo. Um módulo novo, `client/NOM_EmberShell.lua`, cuida só da casca (vestir, desfazer, tirar, teto, morte e reaproveitamento); o `NOM_VariantLook` decide quando usar.

**Tech Stack:** Lua 5.1 (Kahlua no jogo, luajit nos testes), Python 3 + numpy + Pillow (textura), `./run-tests.sh`.

**Spec:** brief da sprint 0022 (pedido do Johan, 2026-10-05: "o personagem inteiro em brasa"), [README da sprint](README.md), [ADR-016](../../architecture/adr-016-dissolve-e-bloom.md), [sprint 0018](../sprint-0018-dissolve-bloom/README.md).

## Evidência (bytecode B42.21, `projectzomboid.jar`)

- Quem lê o campo `IsoZombie.itemVisuals`: só `<init>`, `getItemVisuals`, `dressIn*`, `useDescriptor`, `helmetFallFromVisuals` e `DoZombieInventory` (varredura de todos os métodos de `IsoZombie`). `IsoZombie.save` não está na lista (e só o `ReanimatedPlayers` o chama, pz-api-notes fato 3): a casca não vai pro save. `ZombiePacket.set` leva só `outfitId` e `skinTextureIndex` (§14.3): não vai pela rede.
- `DoZombieInventory` (54–73) cria item e loot de **todo** `ItemVisual` cujo tipo existe: a casca na lista na hora da morte no solo vira item vestido e loot. Por isso a morte tira a casca da lista, do `WornItems` e do inventário (testado com o jogo falso que imita isso).
- `WornItems.setItem` 5–19: lugar comum expulsa quem já está nele. A casca vai em `base:zeddmg` (multi-item, `shared/NPCs/BodyLocations.lua:859`), como a casca do Eco e as peças: não expulsa nada no `DoZombieInventory`.
- Leitores da lista em jogo (`IsoGameCharacter`): `getBodyPartClothingDefense` 40–80 e `playWeaponHitArmourSound` 34–91 pulam item cujo script não tem `BloodLocation` (`getBloodClothingType` nulo → `goto`); `IsoZombie.cantBite` olha os lugares de máscara/capacete (não `zeddmg`); `helmetFallFromVisuals` só com `ChanceToFall > 0`. O item da casca não tem `BloodLocation`, defesa nem `ChanceToFall`: nenhum efeito de jogo.
- Máscaras: a casca do Eco tem as máscaras do `HazmatSuit.xml` (esconde o corpo: o buraco mostra o fundo). A de brasa **não** tem máscara: o buraco tem de mostrar o monstro embaixo. **UNKNOWN** (roteiro): pele ou roupa atravessando a malha.

## Global Constraints

- Kahlua: sem `//`, `goto`, bit ops, `next`, `table.unpack`; `%` só por `NOM_Math.mod`; nada de `/*` dentro de comentário de script (`tests/test_script_comments.lua`).
- Tudo local (ADR-012, ADR-016): nada pela rede nem pro save; arquivo de cliente começa com `if isServer() then return end`.
- Nunca em jogador reanimado (o `put` já sai cedo pra ele; a casca só nasce do `put`/`leave`).
- Nenhum arquivo do jogo ou de outro mod copiado; modelo Hazmat citado pelo nome; textura gerada por `scripts/gen_textures.py` (semente fixa) e citada no `CREDITS.md`.
- Texto visível por chave, PTBR e EN (`UI.json`, `ItemName.json`).
- Opção "Dissolve" desligada = sprint 0017; sub-opção "Brasa no corpo inteiro" desligada = sprint 0018 exata (os testes antigos rodam assim).
- Comentários e docs em português do Brasil.

## Review Focus

- Morte no **meio da volta, depois da troca** (o zumbi já é comum e só a casca queima): o `NOM_VariantLook` não tem mais registro dele, então quem limpa a casca do loot é o `NOM_EmberShell`. Teste: `ember_dead_after_swap_no_loot` (Task 2).
- A mesma variante pedida de novo no meio da volta: a casca que estava se formando se desfaz de novo, do limiar em que estava, e o monstro fica. Teste: `ember_leave_cancelled_by_same_look` (Task 2).
- Névoa vermelha com horda: no máximo `SHELL_CAP` cascas, o resto pelo dissolve da peça da 0018 até o teto de 12, depois instantâneo; os `strip` do fim continuam em lotes. Teste: `ember_red_fog_cap` (Task 2).
- Lista guardada da 0016 com a casca dentro: a variante que volta enquanto a casca ainda queima não pode guardar a casca como "roupa escondida" e devolvê-la no fim. Teste: `ember_shell_not_kept_as_hidden_clothes` (Task 2).
- Opção desligada no meio da transição: a casca que já está queimando termina e sai; nenhuma nova. Teste: `ember_option_off_mid_effect` (Task 2).

---

### Task 1: Item, textura, opção e traduções

**Files:**
- Create: `mod/42/media/clothing/clothingItems/NOM_Brasa.xml` (malha `Bob_Hazmat.X`/`Kate_Hazmat.X`, sem máscara, `textureChoices` `NOM\NOM_Brasa`, `<m_Shader>NOM_Dissolve</m_Shader>`, GUID novo)
- Modify: `mod/42/media/fileGuidTable.xml`, `mod/42/media/scripts/NOM_clothing.txt` (`item NOM_Brasa`, `base:zeddmg`, `CanHaveHoles = false`, ícone `Hazmatsuit`)
- Modify: `scripts/gen_textures.py` (`ember_shell`, 256, RGBA opaca: carvão quase preto com rachaduras largas laranja-brasa), gera `mod/42/media/textures/NOM/NOM_Brasa.png`
- Modify: `client/NOM_ScreenFxOptions.lua` (`addTickBox("BodyEmbers", "UI_NOM_BodyEmbers", true, …)`, `O.bodyEmbers()` = `O.dissolve()` e a caixa)
- Modify: `Translate/EN|PTBR/UI.json`, `ItemName.json`; `CREDITS.md`
- Test: `tests/test_look_assets.lua` (`look_assets_ember_shell`, 13 itens, determinismo), `tests/test_screen_fx_options.lua` (`body_embers_option`), `tests/test_credits.lua`/`test_translations.lua` (já genéricos)

**Interfaces:** Produz `Base.NOM_Brasa` e `NOM_ScreenFxOptions.bodyEmbers() → boolean`.

- [ ] Teste `look_assets_ember_shell` (malha Hazmat, shader, textura, **sem** `m_Masks`, `base:zeddmg`, sem `BloodLocation`) e `body_embers_option` (tickbox ligada, segue a caixa, falsa com o dissolve desligado). Rodar: falha.
- [ ] Item, XML, GUID, textura, opção, traduções, créditos. Rodar `./run-tests.sh`: passa.
- [ ] Commit.

### Task 2: `client/NOM_EmberShell.lua` e o `NOM_VariantLook`

**Files:**
- Create: `mod/42/media/lua/client/NOM_EmberShell.lua`
- Modify: `mod/42/media/lua/shared/NOM_DissolveRules.lua` (`SHELL_CAP = 6`)
- Modify: `mod/42/media/lua/client/NOM_VariantLook.lua` (`put`, `leave`, `sync`, `strip`)
- Modify: `mod/42/media/lua/client/NOM_Debug.lua` (`cascas=N` no status)
- Test: `tests/test_variant_look.lua` (jogo falso já imita lista, `DoZombieInventory`, `WornItems` multi-item, reaproveitamento e alfa; ganha `opts.body` e um `NOM_Embers` falso com teto), `tests/test_debug.lua`

**Interfaces:**
- `NOM_EmberShell.ITEM = "Base.NOM_Brasa"`
- `NOM_EmberShell.can(z) → boolean`: opção ligada e (já tem casca, ou cascas < `SHELL_CAP` e o dissolve tem vaga).
- `NOM_EmberShell.reveal(z) → boolean`: veste (se não tem), `NOM_Embers` não; `NOM_Dissolve.run(z, "out", remove)`; sem vaga tira na hora.
- `NOM_EmberShell.cover(z, done) → boolean`: veste e `run(z, "in", done)`.
- `NOM_EmberShell.remove(z)`, `has(z)`, `count()`, `burst(z)` (brasas no pé do zumbi, `NOM_Embers.burst`, com teto próprio dele).
- Eventos próprios: `OnZombieDead` (tira da lista, do `WornItems` e do inventário; para o efeito), `OnZombieCreate` (tira), `OnMainMenuEnter` (zera).

Fluxo no `NOM_VariantLook`:
- `put`: `NOM_EmberShell.remove(z)` antes do `hide` (a casca nunca entra na lista guardada); com dissolve e `can(z)`: peça **original**, `reveal` depois do `hide`, `burst`. Senão o caminho da 0018.
- `leave`: peça original e `can(z)`: `cover(z, done)` com `done = strip + reveal`, `burst`; peça `Fx`: o caminho da 0018; senão `strip`.
- `sync` com a mesma variante no meio da volta: com casca, `reveal` (desfaz de novo do limiar atual); sem casca, o da 0018.
- `strip`: também `NOM_EmberShell.remove(z)` (morte, troca de tipo).

- [ ] Testes (todos com `opts.body = true`): `ember_mutation_shell_burns_off` (casca e peça original no começo, `"out"`, alfa ≥ faixa, casca sai no fim, monstro fica), `ember_revert_cover_swap_reveal` (casca entra com a peça ainda lá, troca só no fim do `"in"`, casca ainda na lista depois da troca, sai no fim do `"out"`, roupa igual à de antes), `ember_leave_cancelled_by_same_look`, `ember_dead_mid_mutation_loot_exact`, `ember_dead_after_swap_no_loot`, `ember_dead_fire_and_mp_client`, `ember_reuse_mid_effect_clean`, `ember_red_fog_cap`, `ember_shell_not_kept_as_hidden_clothes`, `ember_option_off_mid_effect`, `ember_off_is_sprint_0018`, `ember_bursts_at_each_transition` (uma no começo da mutação, uma no começo da volta, nenhuma no meio), `ember_skips_reanimated_player`, `ember_budget`; `debug_status_counts_shells`. Rodar: falham.
- [ ] Implementar. Rodar `./run-tests.sh`: passa (os testes antigos sem `opts.body` ficam no caminho da 0018).
- [ ] Commit.

### Task 3: Docs

**Files:** `docs/sprints/sprint-0022-brasa-corpo-inteiro/README.md`, `docs/sprints/README.md`, `docs/architecture/adr-016-dissolve-e-bloom.md` (emenda), `docs/architecture/pz-api-notes.md` (§17.5), `docs/architecture/README.md` (orçamento), `docs/gdd/art-direction.md`.

- [ ] Critérios com evidência, roteiro in-game, checkpoints, aprendizados, pendências; roadmap `em teste`; emenda da ADR-016; nota de API; orçamento; arte.
- [ ] Commit.
