# Monstro sem roupa comum — Plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enquanto um zumbi é variante ativa (Estalador, Corredor, Sem-rosto, Carpideira), a roupa vanilla dele some do desenho; só a pele e a peça do mod aparecem. Quando a variante acaba (fim da névoa, troca de tipo, reaproveitamento, morte), a roupa volta, e o corpo e o loot ficam exatamente com o que o zumbi vanilla teria.

**Architecture:** Tudo em `client/NOM_VariantLook.lua` (mesma responsabilidade: o visual da variante na cópia local). Esconder = tirar da `ItemVisuals` do zumbi os `ItemVisual` vanilla (não existe flag de "escondido", bytecode abaixo) e guardar a lista original na tabela Lua do processo; voltar = tirar a peça do mod e devolver a lista original na ordem. Na morte no solo, o `DoZombieInventory` já fez vestidos e inventário da lista escondida antes do `OnZombieDead`: o mod devolve a lista e refaz só a parte vestida pelo próprio `WornItems` (`setFromItemVisuals` + `addItemsToItemContainer`), sem tocar em item preso nem em `itemsToSpawnAtDeath`. O fim da névoa deixa de tirar todo mundo na borda: a passada em lotes do `NightStats` já chama o gancho com `nil` em cada zumbi.

**Tech Stack:** Lua 5.1 (Kahlua no jogo, luajit nos testes), `./run-tests.sh`.

**Spec:** brief da sprint 0016 (decisão do Johan, 05/10/2026), [README da sprint](README.md), [ADR-012](../../architecture/adr-012-visual-das-variantes.md), [art-direction.md](../../gdd/art-direction.md).

## Evidência (bytecode B42, `projectzomboid.jar`)

- `ItemVisual`: campos e métodos não têm flag de esconder/render (só tipo, tinta, textura, decal, sangue, buracos, remendos). `HumanVisual` idem para itens. Opção (c) do brief não existe.
- `IsoZombie.onKilled` 38–52: `if (!GameClient.client) DoZombieInventory()`, depois `OnZombieDead`. Nenhum evento Lua antes (`IsoGameCharacter.onKilled` é vazio; `Kill` 0–53 só chama `onKilled`). Opção (a) não existe.
- `DoZombieInventory(Z)` 0–14: sai cedo pra jogador reanimado e `wasFakeDead`; 36–73: `inventory.removeAllItems`, `wornItems.setFromItemVisuals(itemVisuals)`, `wornItems.addItemsToItemContainer(inventory)`; 76–328: itens presos e `itemsToSpawnAtDeath` (esta lista é limpa no fim, 321–325): chamar `DoZombieInventory` de novo perderia esses itens.
- `WornItems.setFromItemVisuals` 0–105: `clear()` e, pra cada `ItemVisual`, `InventoryItemFactory.CreateItem(tipo)`, `getVisual().copyFrom(iv)`, `setItem(lugar, item)`. `addItemsToItemContainer` 0–66: `AddItem` de cada vestido (condição pelos buracos). `WornItems` está no `LuaManager$Exposer`; `getWornItems():size()` e `:get(i):getItem()` CONFIRMED `client/ISUI/ISFitnessUI.lua:295-296`.
- `IsoGameCharacter.die` 15–80: `Kill` (→ `onKilled`) e, fora do cliente de MP, `becomeCorpse` → `IsoDeadBody.<init>` 661–710 copia `HumanVisual`, inventário e `WornItems` (o corpo desenha o `WornItems`).
- Cliente de MP: `DeadZombiePacket.parse` → `parseCharacterInventory` limpa e lê inventário, vestidos e presos do servidor e chama `resetModelNextFrame`; `DeadCharacterPacket.processClient` 514 → `dieNetwork` 0–10: `Kill` (`OnZombieDead`, sem `DoZombieInventory`) e **depois** `becomeCorpse`. Resolve o UNKNOWN da 0012: o `OnZombieDead` do cliente vem antes do corpo local, e o corpo do cliente usa os vestidos do servidor.
- Fogo: `IsoGameCharacter.FireCheck` 268–290 e `ReduceHealthWhenBurning` 229–251 disparam `OnZombieDead` sem `DoZombieInventory`; `BurntToDeath.execute` 47–58 cria o corpo direto (sem cliente de MP).
- `IsoZombie.getItemVisuals()` com `isUsingWornItems()` (morto, reanimado, `wasFakeDead`) reconstrói a lista a partir do `WornItems`.

## Global Constraints

- Kahlua: sem `//`, `goto`, `next`, `table.unpack`.
- Visual só em memória, só onde renderiza (não carrega no dedicado); nada pela rede nem pro save; jogador reanimado nunca pintado (ADR-012).
- O `persistentOutfitID` não muda; nenhum `dressIn*`.
- Corpo e loot da variante morta = exatamente os itens vanilla do zumbi: sem perda, sem duplicata, sem item do mod.
- Exceção à regra: tabela `NOM_VariantLook.KEEP` de padrões Lua de tipo de item que ficam à mostra. Começa só com as camadas de ferida do corpo (`ZedDmg_`, `Wound_`), que não são roupa; a "saia estranha" entra aqui quando o Johan achar qual é.
- `resetModelNextFrame` depois de esconder e de devolver; tirar no fim da névoa espalhado pelos lotes do `NightStats`.
- Comentários e docs em português do Brasil.

## Review Focus

- Zumbi re-vestido pelo jogo enquanto escondido (outro ID, reaproveitamento): a lista nova é a verdade, a guardada não pode voltar por cima (roupa duplicada). Teste: `nude_redressed_does_not_restore_old_clothes`.
- Falha da API no meio do pôr (ex.: `ItemVisual.new` explode): nada pode ficar escondido sem a marca. Teste: `nude_api_error_hides_nothing`.
- Morte por fogo (`OnZombieDead` antes de qualquer inventário) e no cliente de MP (vestidos do servidor): o mod não pode inventar nem apagar loot. Testes: `nude_burn_death_no_invented_loot`, `nude_mp_client_death_keeps_server_items`.
- Item preso e item de `itemsToSpawnAtDeath` no inventário do morto: refazer os vestidos não pode tirá-los. Teste: `nude_dead_loot_exact` (o fake põe um item preso).
- Zumbi que sai da lista no meio da passada do fim da névoa: fica pelado no máximo até a passada de hora em hora (rede de segurança do `NightStats`). Teste: `nude_fog_end_spread_in_batches` (e o `stats_day_idle_wakes_every_hour` existente).

---

### Task 1: Esconder e devolver a roupa (sync)

**Files:**
- Modify: `mod/42/media/lua/client/NOM_VariantLook.lua`
- Test: `tests/test_variant_look.lua` (fake: `ItemVisual` vanilla com `getItemType`; testes novos `nude_*`)

**Interfaces:**
- Produces: `NOM_VariantLook.KEEP` (lista de padrões); `worn[z] = { kind, id, item, iv, all }` (`all` = lista original na ordem, nil se nada foi escondido).

- [ ] **Step 1:** testes que falham: `nude_hidden_on_variant_start` (só a peça do mod e o que casa com `KEEP` na lista, pele do mod), `nude_restored_on_fog_end` (mesma lista, mesmos objetos, mesma ordem), `nude_keep_body_wounds` (`Base.ZedDmg_*` fica), `nude_redressed_does_not_restore_old_clothes`, `nude_api_error_hides_nothing`, `nude_reuse_restores_nothing_stale`.
- [ ] **Step 2:** `luajit tests/run.lua` → FAIL nos `nude_*`.
- [ ] **Step 3:** implementar em `put`: depois de pôr a peça do mod, ler a lista (`size`/`get`/`getItemType`), guardar `w.all`, `remove` de cada um que não casa com `KEEP` nem é do mod. Em `strip`: se `remove(w.iv)` devolveu false (o jogo re-vestiu), não devolve nada; senão `remove` de cada um de `w.all` e `add` de volta na ordem.
- [ ] **Step 4:** testes verdes (inclusive os da 0012).
- [ ] **Step 5:** commit.

### Task 2: Morte com loot exato

**Files:**
- Modify: `mod/42/media/lua/client/NOM_VariantLook.lua` (`dead`)
- Test: `tests/test_variant_look.lua` (fake do `WornItems` com `size/get/setFromItemVisuals/addItemsToItemContainer`, item preso; caminhos solo, fogo, cliente de MP)

- [ ] **Step 1:** testes que falham: `nude_dead_loot_exact` (corpo e inventário iguais aos de um zumbi gêmeo que nunca foi variante, por tipo e contagem; item preso fica; pele nil), `nude_burn_death_no_invented_loot`, `nude_mp_client_death_keeps_server_items`.
- [ ] **Step 2:** FAIL.
- [ ] **Step 3:** `dead(z)`: `ran = inv:FindAndReturn(w.item)` (o `DoZombieInventory` rodou: a peça do mod virou loot); `strip(z)`; se `ran`: `Remove` do inventário de cada vestido atual, `setFromItemVisuals(getItemVisuals())`, `addItemsToItemContainer(inv)`.
- [ ] **Step 4:** verde. **Step 5:** commit.

### Task 3: Fim da névoa em lotes e orçamento

**Files:**
- Modify: `mod/42/media/lua/client/NOM_VariantLook.lua` (sai o `NOM_FogState.onChange`)
- Test: `tests/test_variant_look.lua` (`look_*` que liam logo depois do `fogOff` passam a convergir; `nude_fog_end_spread_in_batches`; `nude_budget` com `tests/calls.lua`)
- Modify: `docs/architecture/README.md` (linha do orçamento)

- [ ] **Step 1:** `nude_fog_end_spread_in_batches`: 40 variantes, `fogOff`, um tick devolve ≤ `BATCH` zumbis, convergir devolve todos. `nude_budget`: pôr ≤ 10 + 3 por peça vanilla, devolver ≤ 6 + 2 por peça, passada sem troca 0, contados com `tests/calls.lua` nos objetos falsos.
- [ ] **Step 2:** FAIL (a borda tira todos no mesmo tick).
- [ ] **Step 3:** tirar o `onChange`; ajustar os testes da 0012 que assumiam a borda.
- [ ] **Step 4:** verde. **Step 5:** commit.

### Task 4: Docs

- [ ] README da sprint (critérios com evidência, roteiro in-game, checkpoints, aprendizados, pendências), roadmap, art-direction (regra nova), ADR-012 (emenda), Overview (decisão de 05/10), pz-api-notes §14.4, orçamento. Commit.
