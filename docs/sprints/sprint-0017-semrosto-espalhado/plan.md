# Sem-rosto espalhado e sorteio estável com chapéu caído — Plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Uma horda de Sem-rostos vista junta reaparece espalhada (cada um num tile diferente, todos fora da vista), e um zumbi que perde o chapéu na névoa continua sendo a mesma variante (ou o mesmo zumbi comum).

**Architecture:** Duas correções pequenas, sem sistema novo. (1) Em `shared/NOM_SemRosto.lua`, quem escolhe o destino guarda os tiles dos sumiços recentes (`RESERVE_MS`) e pula esses tiles no anel; o cliente de MP também reserva os destinos que o servidor espalha em `semRostoMove`. O servidor confere como hoje. (2) Um helper puro `NOM_VariantRules.baseId(id)` tira o bit `0x8000` (chapéu caído) do `persistentOutfitID` com aritmética exata em double; o `variant()` usa ele por dentro (sorteio, vermelha, forçado do debug) e toda tabela chaveada pelo ID (Eco, Carpideira que gritou, visual, debug) lê o ID por ele. O ID cru continua só onde o jogo precisa dele (vestir, `hatFallen` do visual).

**Tech Stack:** Lua 5.1 (Kahlua no jogo, luajit nos testes), `./run-tests.sh`.

**Spec:** brief da sprint 0017 (rulings do Claude, 2026-10-05), [README da sprint](README.md), [ADR-006](../../architecture/adr-006-variantes-deterministicas.md), [ADR-007](../../architecture/adr-007-sem-rosto-e-atmosfera-local.md).

## Evidência (bytecode B42, `projectzomboid.jar`)

- `PersistentOutfits.setFallenHat(chr, b)` 0–36: lê o ID, sai se 0, `id | 32768` (ou `& ~32768` com `false`) e `setPersistentOutfitID(id, isPersistentOutfitInit())`: o init não muda, nada é vestido de novo.
- Quem liga o bit no zumbi: `hit/Zombie.react` 20–57 (só `GameServer.server`, flag de chapéu caído do golpe) e `ZombieHelmetFallingPacket.processClient` 238 (cliente). `IsoGameCharacter.helmetFall` 81–97 só liga pra quem **não** é zumbi: no solo o bit do zumbi não muda pelo jogo (só se veio salvo).
- Quem veste pelo ID: `IsoZombie.DoZombieInventory` 33, `ModelManager.dressInRandomOutfit` 58/128, `IsoGameCharacter.dressInPersistentOutfit` 35. Nenhum reage a troca do bit num zumbi já vestido; `hit/Zombie.react` 80 chama `removeFallenHat` (tira da lista quem tem `ChanceToFall > 0`), e o `processClient` refaz a lista com os mesmos objetos (pz-api-notes §14.4). A peça do mod fica: o visual não precisa repintar por causa do bit.
- `NetworkZombieSimulator.parseZombie` 144–152: o `outfitId` do pacote só é usado pra criar o zumbi (`createRealZombieAlways`); zumbi já existente não é re-vestido pelo pacote.

## Global Constraints

- Kahlua: sem `//`, `goto`, bit ops, `next`, `table.unpack`.
- Lógica do jogo autoritativa no servidor (ADR-002); regras puras em `lua/shared/` sem API do jogo.
- O ID tem sinal: bit 31 = feminino (negativo). A máscara usa `math.floor(id / 32768) % 2` (deslocamento aritmético exato em double para todo int de 32 bits) e subtrai 32768.
- O servidor continua conferindo o destino do Sem-rosto como hoje (`validMove`, `floorOk`, andar, cooldown); "fora da vista" segue sendo de todos os jogadores locais.
- Nada de mudança fora das duas correções. Comentários e docs em português do Brasil.

## Review Focus

- ID feminino (negativo) com o bit do chapéu: a máscara tem que dar exatamente o ID sem o bit 15, sem tocar no bit 31 (sexo) nem no resto. Teste: `variant_rules_base_id_exact` (casos com bit 31 e 15 ligados, e os limites `-2^31` e `2^31-1`).
- O destino reservado não pode bloquear o Sem-rosto pra sempre: a reserva expira em `RESERVE_MS` e a névoa nova começa limpa. Teste: `semrosto_reservation_expires`.
- Cliente de MP: dois clientes vendo a mesma horda escolheriam o mesmo tile; o `semRostoMove` que o servidor espalha reserva o tile em todo cliente. Teste: `fog_client_move_reserves_tile`.
- Debug forçado num zumbi que depois perde o chapéu continua forçado (o `forced` é chaveado pelo ID sem o bit). Teste: `variant_rules_fallen_hat_same_kind` (inclui o `forced`).
- Eco recarregado com o bit ligado (ID salvo sem o bit) ainda é reconhecido e vestido pelo ID cru. Teste: `eco_reloaded_with_fallen_hat_still_eco`.

---

### Task 1: `baseId` e o sorteio estável

**Files:**
- Modify: `mod/42/media/lua/shared/NOM_VariantRules.lua`
- Test: `tests/test_variant_rules.lua`

**Interfaces:**
- Produces: `NOM_VariantRules.HAT_FALLEN = 32768`; `NOM_VariantRules.baseId(id) -> id sem o bit 0x8000` (nil → nil); `variant(id, ...)` mascara por dentro (sorteio e `forced`).

- [ ] **Step 1:** testes que falham: `variant_rules_base_id_exact` (positivo, negativo, com e sem o bit, limites), `variant_rules_fallen_hat_same_kind` (todo `realIDs()` com e sem o bit dá o mesmo tipo em 5 períodos, normal e vermelha; `forced[id]` vale pro ID com o bit).
- [ ] **Step 2:** `luajit tests/run.lua` → FAIL (`baseId` nil; tipos diferentes).
- [ ] **Step 3:** implementar:

```lua
NOM_VariantRules.HAT_FALLEN = 32768
function NOM_VariantRules.baseId(id)
    if id == nil or math.floor(id / 32768) % 2 == 0 then return id end
    return id - 32768
end
```
  e `id = NOM_VariantRules.baseId(id)` na primeira linha do `variant`.
- [ ] **Step 4:** verde. **Step 5:** commit.

### Task 2: Tabelas chaveadas pelo ID

**Files:**
- Modify: `shared/NOM_NightStats.lua` (ID que vai pro visual), `server/NOM_Eco.lua` (marca e reconhecimento), `server/NOM_Variants.lua` (`pid` da Carpideira), `shared/NOM_Carpideira.lua` (`furious`), `client/NOM_VariantsClient.lua` (grito pelo `pid`), `client/NOM_Debug.lua` (ID forçado), `client/NOM_VariantLook.lua` (`hatFallen` usa `HAT_FALLEN`)
- Test: `tests/test_variant_look.lua`, `tests/test_eco.lua`, `tests/test_carpideira.lua`, `tests/test_variants_client.lua`, `tests/test_debug.lua`

**Interfaces:**
- Consumes: `NOM_VariantRules.baseId`, `NOM_VariantRules.HAT_FALLEN`.

- [ ] **Step 1:** testes que falham: `look_fallen_hat_keeps_variant` (cliente de MP, ID que muda de tipo com o bit: depois do bit a variante e o visual continuam, sem repintar), `eco_reloaded_with_fallen_hat_still_eco`, `carpideira_furious_with_fallen_hat` (solo: gritou, perdeu o chapéu, continua furiosa e não grita de novo), `variants_client_scream_with_fallen_hat`, `debug_variant_sends_base_id`.
- [ ] **Step 2:** FAIL.
- [ ] **Step 3:** trocar a leitura por `NOM_VariantRules.baseId(z:getPersistentOutfitID())` em cada lugar; o Eco veste com o ID cru (`dressInPersistentOutfitID(raw)`) e procura pela chave.
- [ ] **Step 4:** verde. **Step 5:** commit.

### Task 3: Sem-rosto espalhado

**Files:**
- Modify: `shared/NOM_SemRostoRules.lua` (`RESERVE_MS`), `shared/NOM_SemRosto.lua` (reserva, `NOM_SemRosto.reserve`), `client/NOM_FogClient.lua` (reserva no `semRostoMove`)
- Test: `tests/test_semrosto.lua`, `tests/test_fog.lua`, `tests/test_fog_client.lua`

**Interfaces:**
- Produces: `NOM_SemRostoRules.RESERVE_MS = 5000`; `NOM_SemRosto.reserve(x, y, z)`.

- [ ] **Step 1:** testes que falham: `fog_sp_horde_spreads` (solo, 5 Sem-rostos no mesmo tile vistos juntos: 5 teleportes em 5 tiles diferentes, todos fora da vista e `validMove`), `semrosto_reservation_expires` (o mesmo tile volta a valer depois de `RESERVE_MS`; névoa nova limpa), `fog_client_move_reserves_tile`.
- [ ] **Step 2:** FAIL (todos no mesmo tile).
- [ ] **Step 3:** `reserved["x,y,z"] = ms`; `destination` pula tile com `now - reserved[k] < RESERVE_MS` e reserva o escolhido; `reserve` exposto; limpa no fim da névoa.
- [ ] **Step 4:** verde. **Step 5:** commit.

### Task 4: Docs

- [ ] README da sprint (critérios com evidência, roteiro in-game, checkpoints, aprendizados, pendências), roadmap, emenda da ADR-006 e da ADR-007, `monsters.md` se mudar o comportamento descrito, pz-api-notes §14.4 (quem liga o bit). Commit.
