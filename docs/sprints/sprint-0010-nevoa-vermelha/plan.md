# Névoa Vermelha — Plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Uma parte dos eventos de névoa (`RedFogChance`%, padrão 10) vem vermelha: sirene própria (mais grave, distorcida e longa), névoa e luz tingidas de vermelho, e **todo** zumbi (menos o Eco) vira variante, dividido por igual entre os tipos.

**Architecture:** O vermelho é propriedade do evento de névoa da sprint 0009. Sorteio puro e determinístico por período (`NOM_VariantRules.redFog(period, cfg)`, mesmo `mix` e um sal próprio), decidido pelo servidor na hora da sirene (o período da névoa que vem é `night + 1`), guardado em `data.fog.red` (ModData) e espalhado pela flag `NOM_World.red` → comando `fog {on, period, red}` → `NOM_FogState.red`. O sorteio da variante ganha um 4º argumento `red`: com ele, a faixa vira 100% e o tipo sai de um segundo hash (sal próprio) dividido por `#KINDS`. O `NOM_ClimateLook` ganha uma rampa do vermelho: o look da névoa puxa pro `LOOKS.redFog` (luz vermelha escura) e a cor da névoa (`COLOR_NEW_FOG`, id 1) vai pro vermelho.

**Tech Stack:** Lua 5.1 (Kahlua no jogo, luajit nos testes), Python + numpy + ffmpeg pro som.

**Spec:** brief da sprint 0010 (decisões do Johan de 05/10/2026), [README da sprint](README.md).

## Global Constraints

- Kahlua: sem `//`, `goto`, operador de bit, `next()`; `unpack`, não `table.unpack`; nada de `%d` com float.
- Lógica autoritativa no servidor (`if isClient() then return end`); lógica pura em `shared/` sem API do jogo; testes contra fakes que imitam o jogo.
- Clima: servidor, `OnClimateTick`, valor absoluto, `setModdedInterpolate(1)`, nunca acumular.
- Toda chamada de API com evidência (Lua vanilla arquivo:linha ou bytecode `Classe.metodo` + offset).
- Texto do jogador por tradução PT-BR e EN, sem `%` sozinho; sandbox no namespace `NevoaEOutroMundo`.
- Nada copiado de outro mod nem do jogo; som gerado por `scripts/gen_sounds.py` e listado no `CREDITS.md`.
- O look da névoa vermelha fica **mais escuro que a vanilla em todo caminho** (as três cores de névoa e as duas noites vanilla, `NOM_Rules.VANILLA_FOGS`/`VANILLA_NIGHTS`).

## Pesquisa (bytecode B42.21) que decide o desenho

- **Cor da névoa = `COLOR_NEW_FOG` (id 1).** `ImprovedFog.update` 132–174 copia
  `ClimateManager.getColorNewFog().getExterior()` r/g/b pro `colorR/G/B`, que o
  `renderFogSegment` passa ao `FogShader.setColorInfo(r, g, b, 1)` (459–469). Não existe
  campo estático `COLOR_NEW_FOG` no `ClimateManager` (só `COLOR_GLOBAL_LIGHT` e
  `COLOR_MAX`); o id 1 vem do `setup()` 312–321 (`iconst_1`; o `<init>` chama o `setup` no 525) e do
  `client/ISUI/AdminPanel/ISAdmPanelClimate.lua:249`.
- **O interno dela nunca volta sozinho.** O `setup()` (chamado pelo `<init>` no 525) põe 0.9/0.9/0.95/1 (324–361) e nada
  mais no `ClimateManager` escreve o interno (só o getter, 727). O
  `ClimateColor.calculate` (25–60) faz `internal.interp(modded, t, internal)` **no próprio
  interno**: com interpolate 1 o interno vira o modded, e desligar a camada deixaria a
  névoa vermelha pra sempre (até recarregar). Ao sair do vermelho o mod escreve o
  vanilla por um minuto e só então desliga a camada.
- **Tempestade pinta a névoa por override.** `WeatherPeriod.updateCurrentStage` 909–957:
  estágio com névoa faz `colorNewFog.setOverride(fogTintStorm|fogTintTropical, t)` todo
  minuto (o override passa por cima do modded no `calculate` 61–97). Na névoa vermelha
  o mod faz `setEnableOverride(false)` nela, como já faz no float da névoa (ADR-009).
- **Sincroniza no MP:** `ClimateManager.writePacketContents` 124–143 manda o
  `finalValue` de todas as `climateColors`.
- **Vinheta não tinge:** `SearchMode$PlayerSearchMode` só expõe blur, desat, radius,
  gradientWidth e darkness (`SearchModeFloat`), sem cor. A vinheta fica como está.

## Review Focus

1. Recarregar no meio da névoa vermelha — continua vermelha (luz, névoa e 100% variantes), mesmo período.
2. Fim da névoa vermelha — a cor da névoa volta ao vanilla (0.9/0.9/0.95), não fica vermelha no próximo evento normal.
3. Tipo desligado no sandbox durante a vermelha — a fatia dele vira zumbi comum (não redistribui), Eco nunca é variante.
4. Cliente que entra durante a sirene vermelha ou no meio da névoa vermelha — ouve a sirene vermelha / recebe `red`.
5. `RedFogEnabled` desligado ou `RedFogChance` 0 — nenhum evento vermelho; 100 — todos.

---

### Task 1: Sorteio puro do vermelho e da divisão das variantes

**Files:**
- Modify: `mod/42/media/lua/shared/NOM_VariantRules.lua`, `mod/42/media/lua/shared/NOM_Config.lua`, `mod/42/media/sandbox-options.txt`, `mod/42/media/lua/shared/Translate/{PTBR,EN}/Sandbox.json`
- Test: `tests/test_variant_rules.lua`, `tests/test_config.lua`

**Interfaces:**
- Produces: `NOM_VariantRules.redFog(period, cfg) -> boolean`; `NOM_VariantRules.variant(id, period, cfg, red)`; `NOM_VariantRules.semRosto(id, period, cfg, red)`; `cfg.redFogOn`, `cfg.redFogChance` em `NOM_VariantRules.config(get)`.

- [ ] **Step 1: testes que falham**

```lua
-- tests/test_variant_rules.lua
variant_rules_red_fog_deterministic_per_period = function()
    local c = cfg({ redFogOn = true, redFogChance = 10 })
    local n = 0
    for p = 1, 2000 do
        assert(R.redFog(p, c) == R.redFog(p, c))
        if R.redFog(p, c) then n = n + 1 end
    end
    assert(n > 140 and n < 260, "vermelhas em 2000: " .. n)
    assert(not R.redFog(5, cfg({ redFogOn = false, redFogChance = 100 })))
    assert(R.redFog(5, cfg({ redFogOn = true, redFogChance = 100 })))
    assert(not R.redFog(nil, c))
end,
variant_rules_red_fog_splits_evenly = function()
    local count = { estalador = 0, corredor = 0, semrosto = 0 }
    local ids = realIDs()
    for _, id in ipairs(ids) do
        local k = R.variant(id, 7, cfg(), true)
        assert(k, "comum na névoa vermelha: " .. id)
        count[k] = count[k] + 1
    end
    for k, v in pairs(count) do assert(math.abs(v / #ids - 1 / 3) < 0.02, k .. " " .. v) end
end,
variant_rules_red_fog_disabled_kind_stays_normal = function() ... end, -- estaladorOn=false: a fatia dele vira nil, as outras não mudam
variant_rules_red_fog_keeps_forced_and_id0 = function() ... end,
variant_rules_red_flag_does_not_move_normal_roll = function() ... end, -- red=nil/false igual a antes
```

- [ ] **Step 2:** `./run-tests.sh` → FAIL (`redFog` nil).
- [ ] **Step 3: implementação** — `hash(id, n, salt)` = `mix(mix(mix(A) + B) + salt)` (sal 0 = o roll de antes), `roll` usa `hash`; `redFog` = `floor(hash(0, period, RED_SALT)/Q*100) < redFogChance`; com `red`, `kind = KINDS[floor(hash(id, period, SPLIT_SALT)/Q*#KINDS) + 1]`, devolvido só se `cfg[ON[kind]]`. `RedFogEnabled`/`RedFogChance` no `NOM_Config.DEFAULTS`, no `sandbox-options.txt` e nas traduções.
- [ ] **Step 4:** `./run-tests.sh` → PASS.
- [ ] **Step 5:** commit `feat: sorteio da névoa vermelha e divisão por igual das variantes`.

### Task 2: O evento decide o vermelho, salva e espalha

**Files:**
- Modify: `shared/NOM_FogEventRules.lua` (`start(state, now, cfg, rand, red)`, `stop` limpa `red`), `server/NOM_FogEvent.lua`, `shared/NOM_World.lua` (`setFog(on, red)`, flag `red`, borda `"red"`), `server/NOM_Fog.lua` (manda `red`), `shared/NOM_FogState.lua` (`set(on, period, red)`), `client/NOM_FogClient.lua`, `shared/NOM_Siren.lua` (`play(red)`, som `NOM_SirenRed`)
- Test: `tests/test_fog_event.lua`, `tests/test_fog_event_rules.lua`, `tests/test_fog_client.lua`, `tests/test_world.lua`

**Interfaces:**
- Consumes: `NOM_VariantRules.redFog`, `NOM_VariantRules.config`.
- Produces: `NOM_World.red`; `NOM_FogState.red`; comando `fog {on, period, red}` e `siren {red}`; `NOM_FogEvent.setRed(on) -> boolean`; `NOM_FogEvent.status().sirenRed`.

- [ ] **Step 1: testes que falham** — `fog_event_red_decided_at_siren` (RedFogChance 100: toca `NOM_SirenRed`, não `NOM_Siren`; 30 s depois `NOM_World.red`, `NOM_FogState.red`, `data.fog.red`), `fog_event_red_reload_mid_fog_stays_red` (setup de novo com o mesmo `globalMD` e chance 0: continua vermelha), `fog_event_red_mp_broadcast` (`siren.args.red`, `fog.args.red`, quem entra recebe), `fog_event_red_ends_clean` (fim: `red` falso, próximo evento com chance 0 normal), `fog_client_plays_red_siren_once`, `world_red_flag_edges`, `fog_event_rules_start_stores_red`.
- [ ] **Step 2:** FAIL.
- [ ] **Step 3:** implementação (sirene: `pendingRed = forcedRed` ou `redFog(night + 1)`; `begin` passa pro `R.start`; `OnClimateTick` faz `setFog(s.inNight, s.red)`).
- [ ] **Step 4:** PASS.
- [ ] **Step 5:** commit `feat: o evento de névoa decide e espalha a névoa vermelha`.

### Task 3: Quem sorteia a variante passa o vermelho

**Files:**
- Modify: `shared/NOM_NightStats.lua`, `shared/NOM_SemRosto.lua` (`isSemRosto(z, period, cfg, red)`), `server/NOM_Fog.lua` (`seen`), `server/NOM_Variants.lua`
- Test: `tests/test_night_and_fog.lua` (ou `test_night_stats.lua`), `tests/test_semrosto.lua`, `tests/test_variants.lua`

- [ ] **Step 1:** testes: na névoa vermelha todo zumbi local tem perfil de variante (Estalador/Corredor) ou é Sem-rosto, o Eco nunca; o servidor reconhece o Corredor com `NOM_World.red`.
- [ ] **Step 2–4:** FAIL → passar `NOM_FogState.red` / `NOM_World.red` → PASS.
- [ ] **Step 5:** commit `feat: na névoa vermelha todo zumbi é variante (menos o Eco)`.

### Task 4: Look vermelho no clima

**Files:**
- Modify: `shared/NOM_Rules.lua` (`LOOKS.redFog`, `mix(nightRamp, fogRamp, intensity, redRamp)`, `VANILLA_FOG_COLOR`, `RED_FOG_COLOR`), `server/NOM_ClimateLook.lua` (rampa `redRamp`, cor da névoa id 1)
- Test: `tests/test_rules.lua`, `tests/test_climate_look.lua` (fake ganha a cor id 1 que **não** volta no `updateValues` e o override de tempestade)

- [ ] **Step 1:** testes: `rules_red_fog_darker_than_vanilla_on_every_path` (contra as 3 névoas e as 2 noites, DI 1 e 2, todo canal mais escuro e o vermelho cai menos que verde/azul), `look_red_fog_tints_without_compounding` (K 1/10/150), `look_red_fog_color_restored_after`, `look_red_fog_color_wins_storm_override`, `look_red_fog_off_touches_no_fog_color`.
- [ ] **Step 2–4:** FAIL → implementação → PASS.
- [ ] **Step 5:** commit `feat: luz e névoa vermelhas no clima`.

### Task 5: Debug e status

**Files:** `shared/NOM_DebugRules.lua` (op `redFog`), `client/NOM_Debug.lua` (`NOM_Debug.redFog(on)`, `vermelha` no status), `server/NOM_DebugServer.lua` (`ops.redFog` → `NOM_FogEvent.setRed`, `vermelha` no status). Testes em `tests/test_debug_rules.lua`, `tests/test_debug.lua`, `tests/test_fog_event.lua` (`fog_event_set_red_*`).

- [ ] TDD como acima; commit `feat: NOM_Debug.redFog força a névoa vermelha`.

### Task 6: Sirene vermelha procedural

**Files:** `scripts/gen_sounds.py` (`siren_red`: rotor 0,7× mais grave, mais saturação e wobble, ~28 s), `mod/42/media/sound/NOM_SirenRed.ogg`, `mod/42/media/scripts/NOM_sounds.txt`, `CREDITS.md`. Teste: `tests/test_credits.lua` (já cobre: arquivo sem crédito falha).

- [ ] Gerar, declarar, creditar; commit `feat: sirene procedural da névoa vermelha`.

### Task 7: Docs

README da sprint (critérios com evidência, roteiro in-game, checkpoints, aprendizados, pendências), roadmap, GDD (atmosphere, monsters, sandbox, Overview com a decisão de 05/10), ADR-010 indexada, pz-api-notes §12, teste-in-game, README do mod, descrições do Workshop. Commit `docs: sprint 0010 em teste`.
