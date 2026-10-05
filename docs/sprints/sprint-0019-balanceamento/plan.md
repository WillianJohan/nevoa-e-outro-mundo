# Balanceamento do PO e curva de tensão — Plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Os defaults do sandbox passam a ser os da análise do PO (aprovada pelo Johan em 05/10/2026), e a névoa ganha uma curva de tensão: começa mais rara e sem vermelha, encurta o intervalo e engrossa a vermelha com os dias do save.

**Architecture:** Sem sistema novo. (1) Defaults trocados nos dois lugares (`sandbox-options.txt` e `NOM_Config.DEFAULTS`). (2) Duas opções novas (`FogEscalation`, `RedFogGraceDays`) lidas pelo `NOM_FogEventRules.config`; fórmulas puras no `NOM_FogEventRules` (`days`, `everyDays`, `redChance`); o intervalo é sorteado no `R.stop` (e na primeira agenda do `R.update`) com o `everyDays` da curva e salvo no `next`, como hoje. (3) No servidor, `data.fog.bornAt` é gravado uma vez (como a `seed`), e o vermelho é decidido na sirene e salvo em `data.fog.red` (antes ficava só em memória até o evento abrir).

**Tech Stack:** Lua 5.1 (Kahlua no jogo, luajit nos testes), `./run-tests.sh`.

**Spec:** análise do PO aprovada pelo Johan (brief da sprint 0019), [README da sprint](README.md), [ADR-009](../../architecture/adr-009-nevoa-evento-do-mod.md), [ADR-010](../../architecture/adr-010-nevoa-vermelha.md), [sandbox.md](../../gdd/sandbox.md).

## Evidência

Nenhuma API nova. Usadas, já confirmadas: `ModData.getOrCreate` (estado global, sprint
0009), `getGameTime():getWorldAgeHours()` (`shared/Definitions/animal/ButcheringUtil.lua:594`),
`ZombRand` (ADR-010). Sandbox novo segue o formato de `sandbox-options.txt` (boolean e
integer, como `RedFogEnabled` e `RedFogChance`).

## Global Constraints

- Kahlua: sem `//`, `goto`, operador de bit; `unpack`; sem `%d` em float; resto de tempo pelo `NOM_Math.mod`.
- Servidor decide (ADR-002): `server/NOM_FogEvent.lua` começa com `if isClient() then return end`.
- Default igual em `sandbox-options.txt` e `NOM_Config.DEFAULTS` (`config_sandbox_defaults_match_lua`).
- Todo texto do jogador por chave, PT-BR e EN, sem `%` sozinho.
- Chances dos monstros e da noite fixas: a ADR-006 não muda.
- Arquivos da sprint 0018 (opções de cliente, VariantLook/Eco visual, mod2) não são tocados.

## Review Focus

1. Save antigo sem `bornAt`, já com dias de jogo: a curva começa no primeiro uso, não no dia 0 do mundo — `fog_event_born_at_saved_once`.
2. Sono/fast-forward de meses: o fator do intervalo não passa de 0,75 nem a chance de 2× — `fog_event_rules_escalation_clamps`.
3. `NOM_Debug.redFog(true)` antes da carência: o debug vence a carência — `fog_event_debug_red_ignores_grace`.
4. Recarregar no meio da sirene vermelha com a chance mudada: continua vermelha — `fog_event_red_saved_at_siren_survives_reload`.
5. `FogEscalation` desligado e `RedFogGraceDays` 0 = comportamento de hoje — `fog_event_rules_escalation_off_is_flat`, `fog_event_escalation_off_is_today`.

---

### Task 1: Defaults do PO

**Files:**
- Modify: `mod/42/media/sandbox-options.txt`, `mod/42/media/lua/shared/NOM_Config.lua`, `mod/42/media/lua/shared/Translate/{PTBR,EN}/Sandbox.json` (tooltip do Eco)
- Test: `tests/test_config.lua` e os testes que dependiam dos números velhos

- [ ] **Step 1:** `test_config.lua` com os números novos (FogEventEveryDays 2, FogMinHours 3, EcoMaxPerPlayer 20, EcoRadius 30, HuntIntervalMinutes 90, HuntRadius 25, CorredorChance 3, SemRostoChance 3, CarpideiraScreamRadius 50) e `config_eco_tooltip_says_bite_infects` (as duas línguas dizem que a mordida infecta).
- [ ] **Step 2:** `luajit tests/run.lua` → FAIL nos defaults.
- [ ] **Step 3:** trocar os números nos dois lugares; tooltip do Eco ganha "A mordida do Eco infecta como a de qualquer zumbi." / "An Echo's bite infects like any zombie's."
- [ ] **Step 4:** rodar tudo; teste que dependia do número velho passa a fixar o sandbox que ele mede (não o default). Verde.
- [ ] **Step 5:** commit.

### Task 2: Curva de tensão (regra pura)

**Files:**
- Modify: `mod/42/media/lua/shared/NOM_FogEventRules.lua`
- Test: `tests/test_fog_event_rules.lua`

**Interfaces:**
- Produces: `R.config(get)` → `{ everyDays, minHours, maxHours, escalation, redGraceDays }`;
  `R.days(state, now)` → dias desde `state.bornAt` (≥ 0; sem `bornAt` = 0);
  `R.everyDays(cfg, d)` → `everyDays × clamp(1,5 − d/60, 0,75, 1,5)` (sem escalada: `everyDays`);
  `R.redChance(chance, cfg, d)` → 0 antes de `redGraceDays`; depois `chance × clamp(1 + (d−30)/60, 1, 2)` (sem escalada: `chance`).
  `R.update`/`R.stop` sorteiam com `R.everyDays(cfg, R.days(state, now))`.

```lua
local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
function R.days(state, now) return math.max(0, now - (state.bornAt or now)) / 24 end
function R.everyDays(cfg, d)
    if not cfg.escalation then return cfg.everyDays end
    return cfg.everyDays * clamp(1.5 - d / 60, 0.75, 1.5)
end
function R.redChance(chance, cfg, d)
    if d < (cfg.redGraceDays or 0) then return 0 end
    if not cfg.escalation then return chance end
    return chance * clamp(1 + (d - 30) / 60, 1, 2)
end
```

- [ ] **Step 1:** testes que falham: `fog_event_rules_interval_curve` (critério 1: base 2, dia 0 → gap entre 36 e 108 h; dia 45 e 200 → entre 18 e 54 h; dia 30 → fator 1), `fog_event_rules_red_curve` (carência 7: 0 no dia 6,99; 10 do 7 ao 30; 15 no 60; 20 no 90 e no 300), `fog_event_rules_escalation_clamps`, `fog_event_rules_escalation_off_is_flat` (critério 4), `fog_event_rules_stop_uses_curve` (o `next` do `stop` sai do fator do dia do fim), `config_reads_sandbox` com as chaves novas.
- [ ] **Step 2:** FAIL. **Step 3:** implementar. **Step 4:** verde. **Step 5:** commit.

### Task 3: Servidor — bornAt, vermelha salva na sirene, opções novas

**Files:**
- Modify: `mod/42/media/lua/server/NOM_FogEvent.lua`, `mod/42/media/sandbox-options.txt`, `mod/42/media/lua/shared/NOM_Config.lua`, `Translate/{PTBR,EN}/Sandbox.json`
- Test: `tests/test_fog_event.lua`, `tests/test_config.lua`

**Interfaces:**
- Consumes: Task 2.
- Produces: `data.fog.bornAt` (hora de mundo, gravada uma vez); `data.fog.red` vale da sirene ao fim do evento; log `sirene contagem=… vermelha=… dias=… chance=…`.

- [ ] **Step 1:** testes que falham: `fog_event_born_at_saved_once`, `fog_event_grace_no_red_in_50_forced_fogs` (critério 2: `RedFogChance` 100, 50 `siren(true)` + `stop` antes do dia 7 → nenhuma vermelha), `fog_event_red_saved_at_siren_survives_reload` (critério 3), `fog_event_debug_red_ignores_grace`, `fog_event_escalation_off_is_today` (critério 4 no servidor), `fog_event_interval_follows_curve` (o `next` depois do evento do dia 45 cabe em 0,75–2,25 dias), `config_new_options_defaults` (critério 5: defaults, faixa 0–60, tradução das duas línguas sem `%` sozinho).
- [ ] **Step 2:** FAIL.
- [ ] **Step 3:** `state()` grava `bornAt = now()` se nil; `decideRed` troca `redFogChance` por `R.redChance(...)`; `siren` guarda em `s.red` (mantém o que já estava salvo: recarga na contagem); `setRed` na contagem escreve `s.red`; `begin` passa `s.red`; sai o `pendingRed`. Opções novas no sandbox, no Config e nas traduções.
- [ ] **Step 4:** verde (os testes de vermelha da 0010 passam `RedFogGraceDays = 0`). **Step 5:** commit.

### Task 4: Docs

- [ ] README da sprint (critérios com evidência, roteiro in-game, riscos de produto), roadmap, `sandbox.md` (defaults e presets), Overview (Decisões 2026-10-05), `monsters.md`/`night.md`/`atmosphere.md`/`world-states.md` onde há número, emenda da ADR-009 e ADR-010, `teste-in-game.md` (Balanceamento). Commit.
