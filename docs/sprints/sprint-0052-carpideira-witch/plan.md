# Carpideira Witch — Plano de implementação

> **For agentic workers:** TDD task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Piloto §3.2 — Carpideira com manto penitente, andar chorando e vinheta de
proximidade no soluço, sem Zombie Buddy.

**Architecture:** Regras puras em `NOM_CarpideiraRules` (intervalo/destino da
caminhada, volume do soluço) e `NOM_ScreenFxRules` (força da vinheta). Quem simula
(`NOM_Carpideira.hold` no dono) solta `useless` só durante `pathToLocationF` curto e
reaplica ao parar; `setTarget(nil)` enquanto anda. Visual: segundo `ItemVisual` de
corpo (`NOM_CarpideiraManto`) no `NOM_VariantLook`, ADR-012 (sem mexer no outfit ID).
Efeito: `s.sob` no overlay, como o chiado do Sem-rosto.

**Tech Stack:** Lua 5.1 / luajit, textura procedural (`gen_textures.py`).

## Global Constraints

- Kahlua: sem `//`, `goto`, bitops, `next()`; `unpack`; `NOM_Math.mod`; `%%` em tradução.
- Evidência de API em pz-api-notes / uso já no mod (useless, pathToLocationF, ItemVisual, setVolume).
- Nada copiado do jogo nem de mods; malha/camada vanilla **por nome**.
- PR draft; **sem merge** na staging nesta entrega.

---

### Task 1: Regras puras (walk + sob)

**Files:** `NOM_CarpideiraRules.lua`, `tests/test_carpideira_rules.lua`,
`NOM_ScreenFxRules.lua`, `tests/test_screen_fx_rules.lua`

- [ ] `R.walkGapMs`, `R.pickWalk`, `R.sobVolume` / `R.sobStrength`
- [ ] Camada de vinheta usa `s.sob`
- [ ] Testes vermelhos → verdes

### Task 2: Andar chorando (dono)

**Files:** `NOM_Carpideira.lua`, `tests/test_carpideira.lua`, `tests/fog_world.lua`
(`pathToLocationF`), ADR-011 emenda, `monsters.md`

- [ ] `hold`: agenda caminhada; halt + useless ao chegar/timeout
- [ ] Soluço com `setVolume` pela distância
- [ ] Testes: anda sem target; não aproxima; grito ainda solta

### Task 3: Look penitente

**Files:** `NOM_clothing.txt`, clothingItems XML×2, `fileGuidTable`, `gen_textures.py`,
`NOM_VariantLook.lua`, Translate, CREDITS, art-direction, testes look/contrast

- [ ] Item corpo `NOM_CarpideiraManto` (camada corpo como Eco cinza + textura escura rasgada)
- [ ] `LOOKS.carpideira.body` / `bodyFx`; put/strip/dead com os dois ItemVisual
- [ ] Contraste e assets verdes

### Task 4: Vinheta no cliente + debug

**Files:** `NOM_ScreenFx.lua`, `NOM_Console.lua`, `NOM_DebugPanel.lua`, índice sprints

- [ ] Amostrar soluço mais perto; preencher `state.sob`
- [ ] `NOM.carpWalk()` + botão
- [ ] `./run-tests.sh` verde; commit; PR draft
