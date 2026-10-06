# Sprint 0033: ritmo novo (plano de implementação)

> **Para agentes:** use superpowers:subagent-driven-development (recomendado) ou superpowers:executing-plans, tarefa por tarefa. Os passos usam checkbox (`- [ ]`).

**Objetivo:** a névoa passa a ser sorteada por dia (65% subindo até 85%). Pode haver uma segunda no mesmo dia, depois de uma folga. Há garantia no terceiro dia. Cada tipo tem duração própria. A sirene toca 45 s e congela todos os zumbis virados pra mesma direção. Depois de cada névoa, 2 h de calmaria.

**Arquitetura:**
- Regra pura nova em `shared/NOM_FogEventRules.lua`: agenda por dia, determinística pelo número do dia e pela semente do mundo.
- O servidor (`server/NOM_FogEvent.lua`) decide e avisa.
- Quem simula o zumbi aplica (ADR-005): os stats da calmaria em `NOM_NightStats` e o congelamento em `shared/NOM_SirenFreeze.lua`. No solo é o próprio processo; no MP, o cliente dono.

**Tecnologia:** Lua (Kahlua no jogo, luajit nos testes), sandbox do PZ B42, `./run-tests.sh`.

**Spec:** [docs/superpowers/specs/2026-10-06-modelo-novo-design.md](../../superpowers/specs/2026-10-06-modelo-novo-design.md), seções 1 a 4.

## Restrições globais

- **Kahlua (subset de Lua 5.1):**
  - sem `next()`, `//`, `goto` ou operadores de bit;
  - `unpack`, nunca `table.unpack`;
  - módulo com `NOM_Math.mod` (o `%` trunca);
  - `%%` nas traduções.
  - Os lints em `tests/test_kahlua_compat.lua` pegam isso.
- **Arquitetura:**
  - arquivo em `lua/server/` começa com `if isClient() then return end`;
  - lógica pura em `lua/shared/`, sem API do jogo.
- **Evidência:** toda chamada de API nova tem evidência (arquivo e linha do vanilla, ou bytecode) registrada em `docs/architecture/pz-api-notes.md`.
- **Fakes de teste:** modelam o jogo de verdade (`tests/fog_world.lua`).
- **Textos:** todo texto pro jogador por chave PTBR + EN em `mod/42/media/lua/shared/Translate/`.
- **Idioma:** comentários e docs em português BR com acento.
- **Números da spec, que valem exatamente:**
  - chance do dia 65%, subindo em linha reta até 85% no dia 60 (com `FogEscalation`);
  - segunda névoa 15%, só depois de 6 h de jogo sem névoa e começando antes da meia-noite;
  - garantia: 2 dias seguidos sem névoa e o terceiro tem com certeza;
  - vermelha 20%, a partir do dia 7, sem a subida até o dobro da sprint 0019;
  - duração branca 3–5 h, vermelha 4–6 h;
  - sirene 45 s reais;
  - calmaria 2 h de jogo, com um degrau a menos de velocidade, visão e audição no zumbi comum.
- **Determinismo:** o sorteio do dia usa o número do dia (`floor(horas de mundo / 24)`) e `data.fog.seed`, pelo `NOM_VariantRules.hash`. Salvar e carregar não muda nada.
- **Saves antigos:** a sirene já agendada (`data.fog.next`) continua valendo e conta como a névoa do dia.
- **Commits:** pequenos, mensagem em português. Testes verdes com `./run-tests.sh` antes de cada commit.

---

### Tarefa 1: agenda por dia (regras puras)

**Arquivos:**
- Modificar: `mod/42/media/lua/shared/NOM_FogEventRules.lua` (reescreve a agenda; mantém `born`, `days`, `durationHours`, `countdown`, `NEUTRAL_DAYS`, `MAX_STEP_MS`, `DENSITY`)
- Teste: `tests/test_fog_event_rules.lua` (reescrito)

**Interfaces:**
- Consome: `NOM_VariantRules.hash(id, n, salt)` e `NOM_VariantRules.Q` (já existem).
- Produz (as próximas tarefas usam estes nomes):
  - `R.SIREN_MS = 45000`
  - `R.config(get)` → `{ dailyChance, maxDailyChance, escalationDays, escalation, secondChance, minGapHours, maxDaysWithout, minHours, maxHours, redMinHours, redMaxHours, redGraceDays, calmHours }`
  - `R.dayOf(hours)` → inteiro
  - `R.frac(seed, n, salt)` → número em [0, 1)
  - `R.dayChance(cfg, d)` → % do dia
  - `R.firstStart(seed, D, now)` → hora de mundo da primeira névoa do dia D
  - `R.planDay(state, D, now, cfg)`
  - `R.update(state, now, cfg, rand)` → `"siren"`, `"end"` ou `nil`
  - `R.start(state, now, cfg, rand, red)` → boolean
  - `R.stop(state, now, cfg)`
  - `R.cancel(state)`
  - `R.calm(state, now)` → boolean
  - `R.redChance(chance, cfg, d)` → %
  - `R.sirenDir(seed, period)` → graus em [0, 360)
  - Campos novos em `state` (`data.fog`): `day`, `hadFog`, `daysWithout`, `wantSecond`, `lastEnd`, `calmUntil`.

- [ ] **Passo 1: escrever os testes que falham.** Substituir todo o conteúdo de `tests/test_fog_event_rules.lua` por:

```lua
-- Regras puras do evento de névoa (shared/NOM_FogEventRules.lua), agenda por dia
-- da sprint 0033 (spec do modelo novo §2).
require "NOM_FogEventRules"
local R = NOM_FogEventRules

local function seq(...)
    local v, i = { ... }, 0
    return function()
        i = i + 1
        return v[(i - 1) % #v + 1]
    end
end

local SEED = 4242
-- Agenda que sempre tem névoa e nunca segunda, sem curva: os testes do mecanismo
-- ligam o que medem.
local function cfg(over)
    local c = { dailyChance = 100, maxDailyChance = 100, escalationDays = 60, escalation = false,
        secondChance = 0, minGapHours = 6, maxDaysWithout = 2, minHours = 3, maxHours = 5,
        redMinHours = 4, redMaxHours = 6, redGraceDays = 7, calmHours = 2 }
    for k, v in pairs(over or {}) do c[k] = v end
    return c
end

return {
    fog_event_rules_siren_is_45_seconds = function()
        assert(R.SIREN_MS == 45000)
    end,
    -- 65% subindo em linha reta até 85% no dia 60, fixo depois; sem curva, o sandbox
    fog_event_rules_day_chance_curve = function()
        local c = cfg({ dailyChance = 65, maxDailyChance = 85, escalation = true })
        assert(R.dayChance(c, 0) == 65 and R.dayChance(c, 30) == 75 and R.dayChance(c, 60) == 85)
        assert(R.dayChance(c, 365) == 85, "passou do teto")
        c.escalation = false
        assert(R.dayChance(c, 0) == 65 and R.dayChance(c, 90) == 65, "sem curva")
        c.escalation, c.escalationDays = true, 0
        assert(R.dayChance(c, 0) == 85, "curva de 0 dias é o teto")
    end,
    fog_event_rules_frac_deterministic = function()
        local a = R.frac(SEED, 10, 1)
        assert(a >= 0 and a < 1 and a == R.frac(SEED, 10, 1))
        assert(a ~= R.frac(SEED, 11, 1) and a ~= R.frac(SEED, 10, 2), "dia e sal mudam o sorteio")
    end,
    -- a primeira do dia cai no dia; se a hora já passou (save carregado no meio do
    -- dia), vai pra parte que sobra do dia, na mesma proporção
    fog_event_rules_first_start_in_day = function()
        for D = 0, 50 do
            local t = R.firstStart(SEED, D, D * 24)
            assert(t >= D * 24 and t < D * 24 + 24, "fora do dia " .. D)
            local late = R.firstStart(SEED, D, D * 24 + 20)
            assert(late >= D * 24 + 20 and late < D * 24 + 24, "antes de agora no dia " .. D)
        end
    end,
    -- dia com 100%: uma sirene no dia, planejada uma vez só
    fog_event_rules_plans_once_per_day = function()
        local s = { seed = SEED, bornAt = 0 }
        assert(R.update(s, 240.01, cfg(), seq(0)) == nil or s.next <= 240.01)
        assert(s.day == 10 and s.next == R.firstStart(SEED, 10, 240.01))
        local first = s.next
        R.update(s, 240.5, cfg(), seq(0))
        assert(s.next == first, "replanejou no mesmo dia")
    end,
    -- passou da hora: pede sirene até o evento começar
    fog_event_rules_sirens_until_start = function()
        local s = { seed = SEED, bornAt = 0 }
        R.update(s, 240, cfg(), seq(0))
        local t = s.next
        assert(R.update(s, t, cfg(), seq(0)) == "siren")
        assert(R.update(s, t + 0.1, cfg(), seq(0)) == "siren", "pedido sumiu antes do evento")
    end,
    -- garantia: 2 dias seguidos sem névoa, o 3º tem com certeza
    fog_event_rules_guarantee_third_day = function()
        local c = cfg({ dailyChance = 0, maxDailyChance = 0 })
        local s = { seed = SEED, bornAt = 0 }
        R.update(s, 240, c, seq(0))
        assert(s.next == nil and s.daysWithout == 0, "dia 10")
        R.update(s, 264, c, seq(0))
        assert(s.next == nil and s.daysWithout == 1, "dia 11")
        R.update(s, 288, c, seq(0))
        assert(s.next ~= nil and s.daysWithout == 2, "dia 12 sem a garantia")
    end,
    -- dias pulados (servidor parado, sono) contam como dias sem névoa
    fog_event_rules_skipped_days_count = function()
        local c = cfg({ dailyChance = 0, maxDailyChance = 0 })
        local s = { seed = SEED, bornAt = 0 }
        R.update(s, 240, c, seq(0))
        R.update(s, 240 + 3 * 24, c, seq(0))
        assert(s.daysWithout == 3 and s.next ~= nil)
    end,
    -- dia que teve névoa zera a contagem
    fog_event_rules_fog_resets_count = function()
        local s = { seed = SEED, bornAt = 0, daysWithout = 1 }
        R.update(s, 240, cfg(), seq(0))
        R.start(s, s.next, cfg(), seq(0), false)
        assert(s.hadFog == true)
        R.update(s, 264, cfg({ dailyChance = 0, maxDailyChance = 0 }), seq(0))
        assert(s.daysWithout == 0)
    end,
    -- save antigo: a sirene já agendada vale pelo dia, sem sorteio novo
    fog_event_rules_pending_counts_for_day = function()
        local s = { seed = SEED, bornAt = 0, next = 300 }
        R.update(s, 240, cfg(), seq(0))
        assert(s.next == 300 and s.day == 10)
    end,
    -- duração pelo tipo: branca 3–5, vermelha 4–6
    fog_event_rules_duration_by_kind = function()
        local s = { seed = SEED }
        assert(R.start(s, 10, cfg(), seq(0), false) and s.endAt == 13 and s.red == false)
        R.stop(s, 13, cfg())
        assert(R.start(s, 20, cfg(), seq(0.5), true) and s.endAt == 25 and s.red == true)
        assert(not R.start(s, 21, cfg(), seq(0), false), "evento dentro de evento")
    end,
    -- fim: calmaria de calmHours e folga mínima pra próxima
    fog_event_rules_stop_sets_calm = function()
        local s = { seed = SEED }
        R.start(s, 241, cfg(), seq(0), false)
        assert(not R.calm(s, 242), "calmaria durante a névoa")
        R.stop(s, 245, cfg())
        assert(s.lastEnd == 245 and s.calmUntil == 247 and s.red == nil and not s.inNight)
        assert(R.calm(s, 246) and not R.calm(s, 247))
        R.stop(s, 250, cfg({ calmHours = 0 }))
        assert(not R.calm(s, 250), "calmaria 0 desliga")
    end,
    -- segunda névoa: depois de minGap, começando antes da meia-noite
    fog_event_rules_second_after_gap = function()
        local c = cfg({ secondChance = 100 })
        local s = { seed = SEED, bornAt = 0 }
        R.update(s, 240, c, seq(0))
        assert(s.wantSecond == true)
        R.start(s, 241, c, seq(0), false)
        R.stop(s, 250, c)
        assert(s.next >= 256 and s.next < 264, "segunda fora da janela: " .. tostring(s.next))
        assert(s.wantSecond == false)
        -- sem espaço no dia: não tem segunda
        s = { seed = SEED, bornAt = 0 }
        R.update(s, 240, c, seq(0))
        R.start(s, 241, c, seq(0), false)
        R.stop(s, 259, c)
        assert(s.next == nil, "segunda sem caber no dia")
    end,
    -- névoa que cruza a meia-noite: a do dia seguinte respeita a folga
    fog_event_rules_gap_after_midnight_fog = function()
        local s = { seed = SEED, bornAt = 0 }
        R.update(s, 240, cfg(), seq(0))
        R.start(s, 262, cfg(), seq(0), false) -- até 265
        assert(R.update(s, 264.5, cfg(), seq(0)) == nil)
        assert(R.update(s, 265, cfg(), seq(0)) == "end")
        assert(s.day == 11 and s.next ~= nil and s.next >= 271, "sem folga depois da névoa da véspera")
    end,
    -- cancelar a sirene (debug) tira a pendente
    fog_event_rules_cancel_clears_next = function()
        local s = { seed = SEED, bornAt = 0 }
        R.update(s, 240, cfg(), seq(0))
        R.cancel(s)
        assert(s.next == nil)
    end,
    -- vermelha: 0 antes da carência, a chance do sandbox depois (sem a subida da 0019)
    fog_event_rules_red_grace_only = function()
        local c = cfg({ escalation = true })
        assert(R.redChance(20, c, 6.99) == 0 and R.redChance(20, c, 7) == 20 and R.redChance(20, c, 90) == 20)
    end,
    fog_event_rules_siren_dir = function()
        local d = R.sirenDir(SEED, 3)
        assert(d >= 0 and d < 360 and d == R.sirenDir(SEED, 3) and d ~= R.sirenDir(SEED, 4))
    end,
    fog_event_rules_closes_stale_0008_save = function()
        local s = { night = 4, inNight = true, seed = SEED, bornAt = 0 }
        R.update(s, 100, cfg(), seq(0))
        assert(s.inNight == false and s.night == 4)
    end,
    fog_event_rules_countdown_pauses_and_caps = function()
        assert(R.countdown(45000, 16, false) == 44984)
        assert(R.countdown(45000, 16, true) == 45000, "pausado contou")
        assert(R.countdown(45000, 10000, false) == 45000 - R.MAX_STEP_MS, "travada comeu a sirene")
        assert(R.countdown(45000, -5, false) == 45000, "relógio voltou")
    end,
    fog_event_rules_config_reads_sandbox = function()
        local t = { FogDailyChance = 65, FogMaxDailyChance = 85, FogEscalationDays = 60, FogEscalation = true,
            FogSecondChance = 15, FogMinGapHours = 6, FogMaxDaysWithout = 2, FogMinHours = 3, FogMaxHours = 5,
            RedFogMinHours = 4, RedFogMaxHours = 6, RedFogGraceDays = 7, FogCalmHours = 2 }
        local c = R.config(function(k) return t[k] end)
        assert(c.dailyChance == 65 and c.maxDailyChance == 85 and c.escalationDays == 60 and c.escalation == true)
        assert(c.secondChance == 15 and c.minGapHours == 6 and c.maxDaysWithout == 2)
        assert(c.minHours == 3 and c.maxHours == 5 and c.redMinHours == 4 and c.redMaxHours == 6)
        assert(c.redGraceDays == 7 and c.calmHours == 2)
    end,
    fog_event_rules_days_since_born = function()
        assert(R.days({ bornAt = 100 }, 148) == 2)
        assert(R.days({}, 500) == 0, "sem bornAt")
        assert(R.days({ bornAt = 100 }, 90) == 0, "relógio antes do nascimento")
    end,
    fog_event_rules_duration_within_bounds = function()
        assert(R.durationHours(2, 6, 0) == 2 and R.durationHours(2, 6, 0.5) == 4)
        assert(R.durationHours(6, 2, 0) == 2, "min > max não troca")
    end,
}
```

Antes de substituir, copie para o arquivo novo os testes atuais de `R.born` que ainda existirem no arquivo antigo (procure `R.born`) e continuem valendo.

- [ ] **Passo 2: rodar e ver falhar.**
  - Rodar: `luajit tests/run.lua 2>&1 | grep -E "fog_event_rules|FAIL|passaram"`
  - Esperado: FAIL em `fog_event_rules_siren_is_45_seconds`, `day_chance_curve` e nos demais que usam funções novas.

- [ ] **Passo 3: implementar.** Em `NOM_FogEventRules.lua`:
  - remover `R.everyDays`, `R.gapHours` e a função local `gap`;
  - trocar `R.SIREN_MS` para 45000;
  - adicionar `require "NOM_VariantRules"` no topo;
  - reescrever `R.config`, `R.redChance`, `R.update`, `R.start` e `R.stop`;
  - acrescentar o resto abaixo.
  - Atualizar o comentário de cabeçalho com os campos novos do `state`.

```lua
local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

-- Sais do sorteio do dia: cada um é um sorteio independente do mesmo dia.
R.DAY_SALT = 15485863
R.HOUR_SALT = 32452843
R.SECOND_SALT = 49979687
R.SECOND_HOUR_SALT = 67867967
R.DIR_SALT = 86028121

function R.config(get)
    return { dailyChance = get("FogDailyChance"), maxDailyChance = get("FogMaxDailyChance"),
        escalationDays = get("FogEscalationDays"), escalation = get("FogEscalation"),
        secondChance = get("FogSecondChance"), minGapHours = get("FogMinGapHours"),
        maxDaysWithout = get("FogMaxDaysWithout"), minHours = get("FogMinHours"), maxHours = get("FogMaxHours"),
        redMinHours = get("RedFogMinHours"), redMaxHours = get("RedFogMaxHours"),
        redGraceDays = get("RedFogGraceDays"), calmHours = get("FogCalmHours") }
end

function R.dayOf(hours) return math.floor(hours / 24) end

-- Sorteio em [0, 1) do dia (ou período) n com a semente do mundo; sal separa sorteios.
function R.frac(seed, n, salt)
    return NOM_VariantRules.hash(seed or 0, n, salt) / NOM_VariantRules.Q
end

-- Chance (%) do dia d de save: com a curva, sobe em linha reta da chance do sandbox
-- até o teto no dia escalationDays e fica lá.
function R.dayChance(cfg, d)
    local base = cfg.dailyChance or 0
    if not cfg.escalation then return base end
    local days = cfg.escalationDays or 0
    local t = days > 0 and clamp(d / days, 0, 1) or 1
    return base + ((cfg.maxDailyChance or base) - base) * t
end

-- Hora de mundo da primeira névoa do dia D. Se já passou (save carregado no meio
-- do dia), vai pra parte do dia que sobra, na mesma proporção.
function R.firstStart(seed, D, now)
    local dayStart = D * 24
    local h = R.frac(seed, D, R.HOUR_SALT) * 24
    local start = dayStart + h
    if start < now then start = now + h / 24 * (dayStart + 24 - now) end
    return start
end

-- Nenhuma névoa começa antes de minGapHours depois do fim da anterior (a folga).
local function afterGap(state, t, cfg)
    if state.lastEnd == nil then return t end
    return math.max(t, state.lastEnd + (cfg.minGapHours or 0))
end

-- Planeja o dia D uma vez: conta os dias sem névoa, sorteia se tem névoa (a garantia
-- força) e se vai querer segunda. Sirene pendente (save antigo, ou empurrada da
-- véspera pela folga) vale pelo dia: sem sorteio novo.
function R.planDay(state, D, now, cfg)
    if state.day ~= nil then
        local missed = math.max(0, D - state.day - 1)
        if state.hadFog then
            state.daysWithout = missed
        else
            state.daysWithout = (state.daysWithout or 0) + 1 + missed
        end
    else
        state.daysWithout = state.daysWithout or 0
    end
    state.day, state.hadFog, state.wantSecond = D, false, false
    if state.next ~= nil then return end
    local forced = state.daysWithout >= (cfg.maxDaysWithout or 2)
    if not forced and R.frac(state.seed, D, R.DAY_SALT) * 100 >= R.dayChance(cfg, R.days(state, now)) then return end
    state.next = afterGap(state, R.firstStart(state.seed, D, now), cfg)
    state.wantSecond = R.frac(state.seed, D, R.SECOND_SALT) * 100 < (cfg.secondChance or 0)
end

-- Uma vez por minuto de jogo. "siren" enquanto for hora e o evento não começou,
-- "end" na borda do fim, nil no resto. Estado aberto sem endAt é save da 0008: fecha.
function R.update(state, now, cfg, rand)
    if state.inNight and state.endAt == nil then state.inNight = false end
    if state.inNight then
        if now < state.endAt then return nil end
        R.stop(state, now, cfg)
        if R.dayOf(now) ~= state.day then R.planDay(state, R.dayOf(now), now, cfg) end
        return "end"
    end
    local D = R.dayOf(now)
    if state.day ~= D then R.planDay(state, D, now, cfg) end
    if state.next ~= nil and now >= state.next then return "siren" end
    return nil
end

-- Abre o evento com a duração do tipo. red: o que a sirene decidiu.
function R.start(state, now, cfg, rand, red)
    if state.inNight then return false end
    state.night = (state.night or 0) + 1
    state.inNight, state.red, state.hadFog = true, red == true, true
    local lo, hi = cfg.minHours, cfg.maxHours
    if state.red then lo, hi = cfg.redMinHours, cfg.redMaxHours end
    state.endAt = now + R.durationHours(lo, hi, rand())
    state.next, state.calmUntil = nil, nil
    return true
end

-- Fecha o evento: calmaria, folga e, se o dia quis e couber, a segunda névoa
-- (começa antes da meia-noite, depois de minGapHours).
function R.stop(state, now, cfg)
    state.inNight, state.endAt, state.red = false, nil, nil
    state.lastEnd = now
    state.calmUntil = now + (cfg.calmHours or 0)
    if state.next ~= nil then state.next = afterGap(state, state.next, cfg) end
    if state.next == nil and state.wantSecond and state.day == R.dayOf(now) then
        local from, to = now + (cfg.minGapHours or 0), (state.day + 1) * 24
        if from < to then state.next = from + R.frac(state.seed, state.day, R.SECOND_HOUR_SALT) * (to - from) end
    end
    state.wantSecond = false
end

-- Sirene cancelada (debug): a pendente sai, o dia não ganha outra.
function R.cancel(state)
    state.next = nil
end

function R.calm(state, now)
    return not state.inNight and state.calmUntil ~= nil and now < state.calmUntil
end

-- Vermelha: 0 na carência, a chance do sandbox depois. A curva é só da chance do dia.
function R.redChance(chance, cfg, d)
    if d < (cfg.redGraceDays or 0) then return 0 end
    return chance
end

-- De onde a sirene "vem" no período: graus em [0, 360), igual em toda máquina.
function R.sirenDir(seed, period)
    return R.frac(seed, period, R.DIR_SALT) * 360
end
```

- [ ] **Passo 4: rodar e ver passar.**
  - Rodar: `luajit tests/run.lua 2>&1 | grep -E "fog_event_rules|FAIL|passaram"`
  - Esperado: todos os `fog_event_rules_*` passam. `test_fog_event.lua` e `test_config.lua` ainda podem falhar; eles são das tarefas 2 e 3.

- [ ] **Passo 5: commit.**

```bash
git add mod/42/media/lua/shared/NOM_FogEventRules.lua tests/test_fog_event_rules.lua
git commit -m "Regras: névoa sorteada por dia, segunda com folga, garantia no 3º dia, calmaria"
```

---

### Tarefa 2: sandbox, padrões e traduções

**Arquivos:**
- Modificar: `mod/42/media/lua/shared/NOM_Config.lua`
- Modificar: `mod/42/media/sandbox-options.txt`
- Modificar: `mod/42/media/lua/shared/Translate/EN/Sandbox.json` e `PTBR/Sandbox.json`
- Teste: `tests/test_config.lua` (e `tests/test_translations.lua`, que já confere chave por opção)

**Interfaces:**
- Produz: as chaves que `R.config` lê, com estes padrões e faixas.

| Opção | Tipo | Faixa | Padrão |
|---|---|---|---|
| `FogDailyChance` | integer | 0–100 | 65 |
| `FogEscalation` | boolean | — | true (já existe; muda o texto) |
| `FogMaxDailyChance` | integer | 0–100 | 85 |
| `FogEscalationDays` | integer | 1–365 | 60 |
| `FogSecondChance` | integer | 0–100 | 15 |
| `FogMinGapHours` | double | 0–24 | 6 |
| `FogMaxDaysWithout` | integer | 0–30 | 2 |
| `FogMinHours` | double | 0.5–48 | 3 (já existe; agora é da branca) |
| `FogMaxHours` | double | 0.5–48 | **5** (era 6; agora é da branca) |
| `RedFogMinHours` | double | 0.5–48 | 4 |
| `RedFogMaxHours` | double | 0.5–48 | 6 |
| `RedFogChance` | integer | 0–100 | **20** (era 10) |
| `FogCalmHours` | double | 0–24 | 2 |

`FogEventEveryDays` sai do `sandbox-options.txt`, do `NOM_Config.DEFAULTS` e das duas traduções.

- [ ] **Passo 1: testes que falham.** Em `tests/test_config.lua`, trocar as asserções de `FogEventEveryDays` por `FogDailyChance`. O sandbox no teste de override vira `{ FogDailyChance = 40 }`, que deve ler 40. Nos padrões, conferir todos os valores da tabela, inclusive `FogMaxHours == 5` e `RedFogChance == 20`, e conferir que `NOM_Config.DEFAULTS.FogEventEveryDays == nil`.
- [ ] **Passo 2:** rodar `luajit tests/run.lua 2>&1 | grep -E "config|FAIL"`. Esperado: FAIL.
- [ ] **Passo 3: implementar.**
  - **`NOM_Config.DEFAULTS`:** a tabela acima.
  - **`sandbox-options.txt`:** cada opção nova no mesmo formato das existentes (`page = NevoaEOutroMundo, translation = NevoaEOutroMundo.<Nome>`), na ordem da tabela, no lugar de `FogEventEveryDays`. As de vermelha ficam depois de `RedFogGraceDays`.
  - **Traduções:** chave `Sandbox_NevoaEOutroMundo.<Nome>` e `_tooltip` em EN e PTBR. Texto PTBR:
    - `FogDailyChance`: "Névoa: chance por dia (%%)" / tooltip "Todo dia, à meia-noite, sorteia se o dia terá névoa. Ela chega numa hora qualquer, anunciada por uma sirene 45 segundos antes. Fora do evento não existe névoa."
    - `FogEscalation`: tooltip novo "Ligada: a chance do dia sobe em linha reta até a chance máxima, no dia da curva. A névoa vermelha não segue a curva."
    - `FogMaxDailyChance`: "Névoa: chance máxima por dia (%%)" / "Chance do dia no fim da curva de tensão."
    - `FogEscalationDays`: "Névoa: dias da curva" / "Dia de save em que a chance do dia chega à máxima."
    - `FogSecondChance`: "Névoa: chance de segunda no dia (%%)" / "Num dia com névoa, chance de vir outra depois da folga mínima. Ela começa antes da meia-noite."
    - `FogMinGapHours`: "Névoa: folga mínima (horas)" / "Horas de jogo sem névoa antes da próxima poder começar."
    - `FogMaxDaysWithout`: "Névoa: dias seguidos sem névoa" / "Depois de tantos dias seguidos sem névoa, o próximo tem com certeza. 0 = névoa todo dia."
    - `FogMinHours` / `FogMaxHours`: "Névoa branca: duração mínima (horas)" / "Névoa branca: duração máxima (horas)".
    - `RedFogMinHours` / `RedFogMaxHours`: "Névoa vermelha: duração mínima (horas)" / "Névoa vermelha: duração máxima (horas)".
    - `FogCalmHours`: "Calmaria depois da névoa (horas)" / "Quando a névoa acaba, os zumbis comuns ficam mais lentos e com os sentidos mais fracos por tantas horas de jogo. 0 desliga."
    - EN: tradução fiel de cada um.
    - Qualquer texto que fale em "30 segundos" da sirene passa a dizer 45.
- [ ] **Passo 4:** rodar `./run-tests.sh`. Esperado: config e traduções verdes. `test_fog_event.lua` pode falhar; é da tarefa 3.
- [ ] **Passo 5: commit.** `git commit -m "Sandbox: chance por dia, segunda névoa, folga, garantia, duração por tipo e calmaria"`

---

### Tarefa 3: servidor usa a agenda nova (sirene de 45 s com direção, calmaria no mundo)

**Arquivos:**
- Modificar: `mod/42/media/lua/server/NOM_FogEvent.lua`
- Modificar: `mod/42/media/lua/shared/NOM_World.lua` (flag `calm`)
- Modificar: `mod/42/media/lua/server/NOM_Fog.lua` (o `fogState` reenvia a sirene com `dir`)
- Teste: `tests/test_fog_event.lua` (agenda nova), `tests/test_world.lua`

**Interfaces:**
- Consome: tudo da tarefa 1.
- Produz:
  - `NOM_World.calm` (boolean) e `NOM_World.setCalm(on)`, que dispara `onChange("calm", on)` só na borda;
  - o comando `"siren"` passa a levar `{ red = bool, dir = graus }`;
  - `NOM_FogEvent.status()` passa a devolver também `sirenDir`;
  - comando novo `"sirenStop"` (sem args), mandado a todos quando a sirene é cancelada no dedicado.

- [ ] **Passo 1: testes que falham.**
  - **`tests/test_world.lua`:** `setCalm(true)` avisa `("calm", true)` uma vez; repetir não avisa; `setCalm(false)` avisa `("calm", false)`.
  - **`tests/test_fog_event.lua`:** trocar o `BASE` por:

```lua
local BASE = { FogDailyChance = 100, FogMaxDailyChance = 100, FogSecondChance = 0, FogEscalation = false,
    FogMinGapHours = 6, FogMaxDaysWithout = 2, FogMinHours = 2, FogMaxHours = 6,
    RedFogMinHours = 2, RedFogMaxHours = 6, RedFogGraceDays = 0, FogCalmHours = 2 }
```

  - Em todo teste que espera uma hora fixa de sirene (ex.: `next == 136`), a hora esperada vira `NOM_FogEventRules.firstStart(fogMD(G).seed, NOM_FogEventRules.dayOf(h0), h0)`, com `h0` a hora da primeira leitura.
  - Onde o teste mede "30 s", passa a medir 45 s (`G.seconds(44.9)` não abre, `G.seconds(0.2)` abre).
  - **Testes novos:**
    - `fog_event_siren_sends_dir`: no dedicado, o comando `siren` leva `dir == NOM_FogEventRules.sirenDir(seed, period + 1)` e `red`.
    - `fog_event_calm_after_end`: depois do fim da névoa, `NOM_World.calm == true` até `FogCalmHours` depois e `false` em seguida.
    - `fog_event_cancel_sends_siren_stop`: no dedicado, `NOM_FogEvent.stop()` durante a contagem manda `sirenStop` e não toca de novo no minuto seguinte (`R.cancel`).
  - Os testes da curva da 0019 (`FogEventEveryDays`, vermelha dobrando) saem. No lugar, `fog_event_red_grace`: com `RedFogChance = 100`, nenhuma vermelha antes do dia 7 de save e vermelha depois.
- [ ] **Passo 2:** rodar `luajit tests/run.lua 2>&1 | grep -E "fog_event|world|FAIL"`. Esperado: FAIL.
- [ ] **Passo 3: implementar.**
  - **`NOM_World.lua`:**
    - `NOM_World = { night = false, fog = false, red = false, calm = false }`;
    - `function NOM_World.setCalm(on) local was = NOM_World.calm; NOM_World.calm = on == true; notify("calm", was) end`;
    - comentário do `onChange` cita a flag `"calm"`.
  - **`NOM_FogEvent.lua`:**
    - **Cabeçalho:** comentário com a agenda por dia e os 45 s.
    - **`OnClimateTick`:**
      - `R.update(s, now(), cfg(), rand)`, como hoje;
      - depois de `setFog`, `NOM_World.setCalm(R.calm(s, now()))`;
      - o log de `proxima=` continua quando `s.next` muda.
    - **`NOM_FogEvent.siren`:**
      - calcular `local dir = R.sirenDir(s.seed, (s.night or 0) + 1)`, guardar em `s.sirenDir` e mandar `{ red = s.red, dir = dir }`;
      - no solo, além de `NOM_Siren.play(s.red)`, chamar `NOM_SirenFreeze.start(dir, countdown)` se `NOM_SirenFreeze` existir. A tarefa 5 cria o módulo; aqui use `if NOM_SirenFreeze then ... end`.
    - **`NOM_FogEvent.stop`:**
      - sirene cancelada sem evento aberto: `R.cancel(state())`; no dedicado, `sendServerCommand(MODULE, "sirenStop", {})`; no solo, `NOM_SirenFreeze.stop()` se existir;
      - com evento aberto: `R.stop(state(), now(), cfg())`, sem `rand`.
    - **`begin()`:** no solo, `NOM_SirenFreeze.stop()` se existir, antes de `setFog(true)`.
    - **`status()`:** inclui `sirenDir = countdown and s.sirenDir or nil`.
    - **`decideRed`:** continua usando `R.redChance(...)`, que agora só aplica a carência.
  - **`NOM_Fog.lua`:** no `fogState`, a sirene atrasada vai com `{ red = ev.sirenRed, dir = ev.sirenDir }`.
- [ ] **Passo 4:** rodar `./run-tests.sh`. Esperado: tudo verde, menos os testes que as tarefas 4 e 5 criam.
- [ ] **Passo 5: commit.** `git commit -m "Evento de névoa: agenda por dia, sirene de 45 s com direção, calmaria no mundo"`

---

### Tarefa 4: calmaria nos stats do zumbi comum

**Arquivos:**
- Modificar: `mod/42/media/lua/shared/NOM_NightRules.lua`, `mod/42/media/lua/shared/NOM_NightStats.lua`
- Modificar: `mod/42/media/lua/server/NOM_Night.lua`, `mod/42/media/lua/client/NOM_NightClient.lua`
- Teste: `tests/test_night_rules.lua`, `tests/test_night_stats.lua`, `tests/test_night.lua`, `tests/test_night_client.lua`

**Interfaces:**
- Consome: `NOM_World.calm` e `onChange("calm")` da tarefa 3.
- Produz:
  - `NOM_NightRules.dull(tier, steps)`;
  - `NOM_NightRules.wanted(night, kind, dayTier, cfg, calm)`, com o 5º parâmetro novo;
  - `NOM_NightStats.calm` e `NOM_NightStats.setCalm(on)`;
  - comando `"calm"` `{ on = bool }`.

- [ ] **Passo 1: testes que falham.** Em `tests/test_night_rules.lua`:

```lua
    night_rules_calm_dulls_common = function()
        local R = NOM_NightRules
        local cfg = { fasterOn = true, sensesOn = true, speedMult = 1.5, senseMult = 1.5, sight = 2, hearing = 2 }
        local w = R.wanted(false, nil, 2, cfg, true)
        assert(w.speed == 3 and w.sight == 3 and w.hearing == 3 and w.key == "c3,3,3")
        w = R.wanted(true, nil, 2, cfg, true)
        assert(w.speed == 3 and w.key == "c3,3,3", "calmaria vence a noite no comum")
        assert(R.wanted(false, nil, 3, cfg, true).speed == 3, "já arrastado fica arrastado")
        assert(R.wanted(true, "eco", 2, cfg, true).key == "eco", "Eco não sente a calmaria")
        assert(R.wanted(false, nil, 2, cfg, false).key == "day", "sem calmaria, dia normal")
    end,
```

  - **`test_night_stats.lua`:** com `NOM_NightStats.setCalm(true)` de dia, um zumbi comum recebe `ZombieLore.Speed = 3` na troca e `md.NOM_night == "c3,3,3"`. Com `setCalm(false)`, volta pra `"day"`.
  - **`test_night.lua`:** no dedicado, `NOM_World.setCalm(true)` manda `calm {on=true}`. No solo, chama `NOM_NightStats.setCalm(true)`. O `nightState` responde também com `calm`.
  - **`test_night_client.lua`:** o comando `calm` chama `setCalm`.
- [ ] **Passo 2:** rodar `luajit tests/run.lua 2>&1 | grep -E "night|FAIL"`. Esperado: FAIL.
- [ ] **Passo 3: implementar.**
  - **`NOM_NightRules`:**
    - `function NOM_NightRules.dull(tier, steps) return math.min(3, tier + steps) end`;
    - em `wanted`, logo no começo:

```lua
    if calm and kind == nil then
        local w = { speed = R.dull(dayTier, 1), sight = R.dull(R.baseSense(cfg.sight or 2), 1),
            hearing = R.dull(R.baseSense(cfg.hearing or 2), 1) }
        w.key = "c" .. w.speed .. "," .. w.sight .. "," .. w.hearing
        return w
    end
```

  - **`NOM_NightStats`:**
    - campo `calm = false`;
    - `function NOM_NightStats.setCalm(on) wake(); NOM_NightStats.calm = on == true end`;
    - em `process`, o atalho do dia intocado também exige `not NOM_NightStats.calm`;
    - `wanted(..., c, NOM_NightStats.calm)`;
    - no fim de `tick`, não dormir enquanto `NOM_NightStats.calm`.
  - **`NOM_Night.lua`:**
    - no `onChange`, tratar `flag == "calm"`: dedicado `sendServerCommand(MODULE, "calm", { on = on })`; solo `NOM_NightStats.setCalm(on)`;
    - no `nightState`, mandar também `sendServerCommand(player, MODULE, "calm", { on = NOM_World.calm })`.
  - **`NOM_NightClient.lua`:** tratar `command == "calm"` → `NOM_NightStats.setCalm(args.on == true)`.
- [ ] **Passo 4:** rodar `./run-tests.sh`. Esperado: verde.
- [ ] **Passo 5: commit.** `git commit -m "Calmaria: zumbi comum um degrau mais lento e menos atento depois da névoa"`

---

### Tarefa 5: todos parados durante a sirene

**Arquivos:**
- Criar: `mod/42/media/lua/shared/NOM_SirenFreeze.lua`
- Modificar: `mod/42/media/lua/server/NOM_FogEvent.lua` (instala no solo; as chamadas já existem desde a tarefa 3)
- Modificar: `mod/42/media/lua/client/NOM_FogClient.lua` (instala no cliente; comandos `siren`, `fog`, `sirenStop`)
- Modificar: `mod/42/media/lua/shared/NOM_VariantAI.lua` (`unstick` não solta zumbi congelado pela sirene)
- Modificar: `tests/fog_world.lua` (fake `faceLocationF`, `getX`/`getY` se faltar, `OnZombieDead`/`OnZombieCreate`)
- Criar: `tests/test_siren_freeze.lua` e registrar em `tests/run.lua`
- Modificar: `docs/architecture/pz-api-notes.md` (§21, sirene)

**Interfaces:**
- Consome: comando `siren {red, dir}`, `sirenStop`, `fog {on}`; `NOM_Carpideira.still`.
- Produz:
  - `NOM_SirenFreeze.start(dirDeg, durationMs)`, `.stop()`, `.tick()`, `.install()`;
  - campos `.frozen` (tabela `[zumbi] = true`) e `.active`.

- [ ] **Passo 1: o fake.** Em `tests/fog_world.lua`, no zumbi falso:
  - `function z:faceLocationF(x, y) self.faced = { x = x, y = y }; return true end`;
  - `getX`/`getY` devolvendo `self.x`/`self.y`, se ainda não existirem.

  No cabeçalho, documentar a evidência: `IsoGameCharacter.faceLocationF(FF)Z`, uso vanilla em `client/BuildingObjects/TimedActions/ISBuildAction.lua:248`.

- [ ] **Passo 2: testes que falham.** Criar `tests/test_siren_freeze.lua`:

```lua
-- shared/NOM_SirenFreeze.lua contra o mundo falso: sirene congela, fim solta.
local W = dofile("tests/fog_world.lua")

local function setup()
    local G = W.new({})
    G.reload({ "NOM_SirenFreeze", "NOM_Carpideira" })
    require "NOM_Carpideira"
    require "NOM_SirenFreeze"
    return G
end

return {
    siren_freeze_holds_local_zombies_facing_dir = function()
        local G = setup()
        local a = G.zombie({ x = 10, y = 10 })
        local b = G.zombie({ x = 20, y = 20, remote = true })
        NOM_SirenFreeze.start(0, 45000)
        for _ = 1, 3 do NOM_SirenFreeze.tick() end
        assert(a.useless == true and a.target == nil and NOM_SirenFreeze.frozen[a])
        assert(math.abs(a.faced.x - (10 + NOM_SirenFreeze.FAR)) < 1e-6 and math.abs(a.faced.y - 10) < 1e-6, "direção 0° = +x")
        assert(not b.useless and not NOM_SirenFreeze.frozen[b], "cópia remota é do dono")
    end,
    siren_freeze_stop_releases = function()
        local G = setup()
        local a = G.zombie({ x = 1, y = 1 })
        NOM_SirenFreeze.start(90, 45000)
        NOM_SirenFreeze.tick()
        NOM_SirenFreeze.stop()
        assert(a.useless == false and next(NOM_SirenFreeze.frozen) == nil and not NOM_SirenFreeze.active)
    end,
    siren_freeze_keeps_still_carpideira = function()
        local G = setup()
        local a = G.zombie({ x = 1, y = 1 })
        NOM_SirenFreeze.start(0, 45000)
        NOM_SirenFreeze.tick()
        NOM_Carpideira.still[a] = true
        NOM_SirenFreeze.stop()
        assert(a.useless == true, "soltou a Carpideira parada")
    end,
    siren_freeze_safety_timeout = function()
        local G = setup()
        local a = G.zombie({ x = 1, y = 1 })
        NOM_SirenFreeze.start(0, 45000)
        NOM_SirenFreeze.tick()
        G.now = G.now + 45000 + NOM_SirenFreeze.SAFETY_MS + 1
        NOM_SirenFreeze.tick()
        assert(a.useless == false and not NOM_SirenFreeze.active, "ficou congelado sem fim")
    end,
    siren_freeze_idle_without_siren = function()
        local G = setup()
        local a = G.zombie({ x = 1, y = 1 })
        NOM_SirenFreeze.tick()
        assert(not a.useless)
    end,
}
```

  `next()` aqui é só no luajit dos testes (`tests/`), não no mod. Se `G.zombie` tiver outro nome ou outros parâmetros em `tests/fog_world.lua`, use o construtor de zumbi falso que já existe lá, com os mesmos campos (`x`, `y`, `remote`).

  Somar em `tests/test_fog_event.lua`:
  - `fog_event_solo_siren_freezes`: no solo, a sirene congela os zumbis (`useless`) e a névoa, ao começar, solta.

  Somar em `tests/test_fog_client.lua`:
  - comando `siren {dir=90}` ativa o congelamento;
  - `fog {on=true}` solta;
  - `sirenStop` solta.

  Somar em `tests/test_variant_ai.lua`:
  - `unstick` não solta zumbi em `NOM_SirenFreeze.frozen`.
- [ ] **Passo 3:** rodar `luajit tests/run.lua 2>&1 | grep -E "siren_freeze|fog_client|variant_ai|FAIL"`. Esperado: FAIL.
- [ ] **Passo 4: implementar** `mod/42/media/lua/shared/NOM_SirenFreeze.lua`:

```lua
-- Sirene (spec do modelo novo §3): enquanto ela toca, todo zumbi para em pé, virado
-- pra direção de onde ela "vem", e ignora o jogador. Quando a névoa começa, todos
-- voltam juntos. Roda onde o zumbi é simulado (ADR-005): no solo, chamado pelo
-- server/NOM_FogEvent.lua; no MP, pelo client/NOM_FogClient.lua (comandos "siren",
-- "fog" e "sirenStop").
-- Parada: setUseless(true) + setTarget(nil) no dono (pz-api-notes §3.2 e §13).
-- Virar: IsoGameCharacter.faceLocationF(FF)Z (uso vanilla
-- client/BuildingObjects/TimedActions/ISBuildAction.lua:248).
require "NOM_Math"
require "NOM_Carpideira"

NOM_SirenFreeze = { BATCH = 20, FAR = 100, SAFETY_MS = 15000, frozen = {}, active = false }
local F = NOM_SirenFreeze
local cursor, dx, dy, untilMs = 0, 1, 0, nil

-- dirDeg: graus de onde a sirene vem (NOM_FogEventRules.sirenDir). durationMs: o que
-- falta da sirene; passou disso mais SAFETY_MS sem fim (comando perdido), solta sozinho.
function F.start(dirDeg, durationMs)
    local a = math.rad(dirDeg or 0)
    dx, dy = math.cos(a), math.sin(a)
    F.active = true
    untilMs = getTimestampMs() + (durationMs or 0) + F.SAFETY_MS
end

-- Solta quem este processo congelou. Carpideira parada pela regra dela fica parada.
function F.stop()
    for z in pairs(F.frozen) do
        if not z:isDead() and not NOM_Carpideira.still[z] then z:setUseless(false) end
    end
    F.frozen = {}
    F.active = false
    untilMs = nil
end

local function hold(z)
    if z:isDead() or z:isRemoteZombie() then return end
    if not F.frozen[z] then
        z:setUseless(true)
        z:setTarget(nil)
        F.frozen[z] = true
    end
    z:faceLocationF(z:getX() + dx * F.FAR, z:getY() + dy * F.FAR)
end

-- Até BATCH zumbis por tick, em volta na lista (quem chega no meio da sirene entra).
function F.tick()
    if not F.active then return end
    if untilMs and getTimestampMs() > untilMs then
        F.stop()
        return
    end
    local list = getCell():getZombieList()
    local size = list:size()
    if size == 0 then return end
    local n = math.min(F.BATCH, size)
    for k = 0, n - 1 do hold(list:get(NOM_Math.mod(cursor + k, size))) end
    cursor = NOM_Math.mod(cursor + n, size)
end

local function forget(z) F.frozen[z] = nil end

function F.install()
    Events.OnTick.Add(F.tick)
    Events.OnZombieDead.Add(forget)
    Events.OnZombieCreate.Add(forget)
end

return NOM_SirenFreeze
```

  Confira o nome exato da função de módulo em `shared/NOM_Math.lua` antes de usar. Se for outro, use o nome real.

  **Integração:**
  - **`NOM_FogEvent.lua`:** `require "NOM_SirenFreeze"` e, no topo do arquivo, `if not isServer() then NOM_SirenFreeze.install() end`. Os `if NOM_SirenFreeze then` da tarefa 3 podem virar chamadas diretas.
  - **`NOM_FogClient.lua`:**
    - `require "NOM_SirenFreeze"` e `NOM_SirenFreeze.install()`;
    - no `siren`, `NOM_SirenFreeze.start(type(args) == "table" and args.dir or 0, 45000)`;
    - no `fog` com `args.on == true`, `NOM_SirenFreeze.stop()`;
    - `command == "sirenStop"` → `NOM_SirenFreeze.stop()`.
  - **`NOM_VariantAI.lua`:** `require "NOM_SirenFreeze"`; em `unstick`, acrescentar `or NOM_SirenFreeze.frozen[z]` à condição de saída da primeira linha.
  - **`tests/run.lua`:** acrescentar `"tests/test_siren_freeze.lua"` depois de `"tests/test_fog_event.lua"`.
  - **`pz-api-notes.md`:** nova seção `## 21. Sirene que congela (sprint 0033)`, com a tabela:
    - `z:setUseless(true)` / `z:setTarget(nil)`: CONFIRMED, remete à §3.2 e à §13;
    - `z:faceLocationF(x, y)`: EXISTS, `IsoGameCharacter` (bytecode `javap`), uso vanilla `client/BuildingObjects/TimedActions/ISBuildAction.lua:248`;
    - nota "o useless viaja na rede no pacote do dono (§3.2)".
- [ ] **Passo 5:** rodar `./run-tests.sh`. Esperado: verde.
- [ ] **Passo 6: commit.** `git commit -m "Sirene: todo zumbi para virado pra de onde ela vem, e volta quando a névoa começa"`

---

### Tarefa 6: documentação da sprint e do modelo

**Arquivos:**
- Criar: `docs/sprints/sprint-0033-ritmo-novo/README.md` (formato de `docs/sprints/README.md`, status `em teste`, critérios com como confirmar e roteiro in-game)
- Modificar: `docs/sprints/README.md` (linha da 0033 com o objetivo novo; a "próxima (0033)" antiga, do rosto censurado, sai porque foi pro facelift; linha "próxima (0034)" com os sons)
- Modificar: `docs/gdd/world-states.md`, `docs/gdd/sandbox.md` (opções novas, `FogEventEveryDays` fora, presets revistos pra não citar opção que não existe), `docs/gdd/Overview.md` (decisão de 2026-10-06 com link pra spec; o loop diz "quase todo dia")
- Modificar: `docs/architecture/adr-009-nevoa-evento-do-mod.md` (emenda de 2026-10-06: agenda por dia, 45 s, congelamento, calmaria)
- Modificar: `docs/HANDOFF.md` (estado: 0033 em teste; próxima 0034; a spec do modelo novo como mapa)
- Modificar: `AGENTS.md`, fluxo de sprint item 3: "Code review só no final de cada entrega (decisão do Johan, 2026-10-06)."

- [ ] **Passo 1:** escrever o README da sprint.
  - **Roteiro in-game com `-debug`:**
    1. **Sirene e congelamento:** `NOM.fog()` (ou o comando do painel) toca a sirene. Conferir 45 s, todos os zumbis à vista parados e virados pro mesmo lado, e que bater num deles não o acorda.
    2. **Volta:** quando a névoa começa, todos voltam juntos.
    3. **Calmaria:** quando a névoa acaba (`NOM.fogOff()` ou o comando equivalente que existir em `NOM.help()`), os zumbis andam visivelmente mais devagar por ~2 h de jogo.
    4. **Agenda:** no console, as linhas `[NOM] nevoa proxima=` mostram uma sirene por dia, na maioria dos dias.
    5. **Duração:** a vermelha dura mais que a branca.
  - Conferir os nomes reais dos comandos em `NOM.help()` (`mod/42/media/lua/client/NOM_Console.lua`) antes de escrever.
- [ ] **Passo 2:** atualizar os docs da lista acima, em português BR com acento.
- [ ] **Passo 3:** rodar `./run-tests.sh`. Esperado: verde. `test_translations` e os lints de comentário não reclamam.
- [ ] **Passo 4: commit.** `git commit -m "Sprint 0033: roteiro, GDD, ADR-009 e handoff do ritmo novo"`

---

### Tarefa 7: comandos de debug pedidos pelo Johan

Pedido do Johan em 2026-10-06, pra facilitar os testes. São atalhos em cima do que já existe; os comandos antigos continuam valendo. Só no cliente com `-debug`, como o resto do `NOM` (sprint 0020). As mensagens de debug são `print` em português, sem tradução, como as de hoje.

**Arquivos:**
- Modificar: `mod/42/media/lua/client/NOM_Console.lua`, `mod/42/media/lua/client/NOM_Debug.lua`, `mod/42/media/lua/server/NOM_DebugServer.lua`
- Modificar (se precisar de regra pura): `mod/42/media/lua/shared/NOM_DebugRules.lua`
- Teste: `tests/test_debug.lua`, `tests/test_debug_rules.lua` (e o fake, se precisar)

**Interfaces:**
- Consome: `NOM_Debug.fog`, `NOM_Debug.redFog`, `NOM_Debug.variant`, `NOM_VariantRules.KINDS`, `NOM_SemRosto.move` (o mesmo caminho de mover zumbi do Sem-rosto: o dono move).
- Produz:
  - `NOM.setFog(skip)`, `NOM.setRedFog(skip)`, `NOM.setBlackFog(skip)`, `NOM.setEndFog()`;
  - `NOM.getZombie()`, `NOM.turnZombie(i)`, `NOM.godMode(on)`, `NOM.wind(on)`;
  - a op `pull` no `NOM_DebugServer`;
  - o comando de servidor `debugMove`.

**Comportamento:**
- **`NOM.setFog(skip)`:**
  - névoa **branca**: desfaz qualquer vermelha forçada (`NOM_Debug.redFog(false)`) e chama `NOM_Debug.fog(true, skip)`;
  - sem argumento toca a sirene (45 s, com o congelamento); `NOM.setFog(true)` abre a névoa na hora.
  - Com névoa já aberta, termina e abre de novo branca.
- **`NOM.setRedFog(skip)`:** `NOM_Debug.redFog(true)` e, com `skip`, `NOM_Debug.fog(true, true)`. A sirene vermelha toca se não pular.
- **`NOM.setBlackFog(skip)`:** a névoa preta chega na sprint 0038. Até lá, imprime `[NOM] debug névoa preta ainda não existe (sprint 0038)` e não faz nada. Fica na lista do help com essa nota.
- **`NOM.setEndFog()`:** `NOM_Debug.fog(false)`. Termina a névoa aberta ou cancela a sirene (manda `sirenStop` no MP, tarefa 3).
- **`NOM.getZombie()`:**
  - acha o zumbi vivo mais perto no mesmo andar (a função `nearest` que já existe em `NOM_Debug.lua`, exposta como `NOM_Debug.nearest`);
  - manda `send({ op = "pull", id = z:getOnlineID(), x = floor(px), y = floor(py), z = floor(pz) })`.
  - **No servidor, a op `pull`:**
    - no solo, procura o zumbi por `getOnlineID` (sem ID de rede, compara com o mais perto do jogador que pediu) e chama `NOM_SemRosto.move(z, x, y, zz)`;
    - no dedicado, manda `debugMove` `{ id, x, y, z }` a todos, e o cliente dono (`not z:isRemoteZombie()`) chama `NOM_SemRosto.move`.
  - Imprime `[NOM] debug zumbi puxado x=.. y=..` ou `nenhum zumbi perto`.
- **`NOM.turnZombie(i)`:**
  - `i == 0` (ou sem argumento) desfaz: `NOM_Debug.variant(nil)`;
  - `1..#NOM_VariantRules.KINDS` vira `NOM_Debug.variant(NOM_VariantRules.KINDS[i])` (1 estalador, 2 corredor, 3 semrosto, 4 carpideira);
  - fora da faixa imprime o uso com a lista numerada.
  - Sem névoa aberta (`not NOM_FogState.on`), avisa `[NOM] debug variante só aparece com névoa (NOM.setFog(true))`, mas manda mesmo assim (o forçado vale quando a névoa abrir).
- **`NOM.godMode(on)`:**
  - liga ou desliga junto `setGodMod`, `setInvisible` e `setZombiesDontAttack` no jogador local, depois `sendPlayerExtraInfo(p)`;
  - sem argumento inverte, pelo `isGodMod`;
  - evidência: `client/ISUI/AdminPanel/ISAdminPowerUI.lua` linhas 44, 36 e 178;
  - imprime `[NOM] debug godMode=true`.
- **`NOM.wind(on)`:**
  - liga ou desliga o foco de vento da tarefa 8 por `NOMRender_setParam(11, on and 1 or 0)`;
  - sem argumento inverte o último valor mandado (guardado no Lua);
  - sem o mod Volumétrica (`NOMRender_setParam == nil`), imprime `[NOM] debug vento precisa do mod Volumétrica (mod3)`.
- **`NOM.HELP`:**
  - as linhas novas entram no topo, na ordem: setFog, setRedFog, setBlackFog, setEndFog, getZombie, turnZombie, godMode, wind;
  - a linha de `NOM.fog` passa a dizer 45 s;
  - `NOM.help()` continua listando tudo.

- [ ] **Passo 1: testes que falham** (em `tests/test_debug.lua`, com o padrão dos testes de `NOM.*` que já existem lá):
  - `setFog()` manda `redFog false` e `fog true`; `setFog(true)` manda `skip`;
  - `setRedFog(true)` manda `redFog true` e `fog true` com `skip`;
  - `setBlackFog()` não manda nada e imprime o aviso;
  - `setEndFog()` manda `fog false`;
  - `turnZombie(2)` manda `variant` com `kind == "corredor"`; `turnZombie(0)` manda `kind == nil`; `turnZombie(9)` não manda nada;
  - `godMode(true)` liga os três no jogador falso e chama `sendPlayerExtraInfo`; `godMode()` inverte;
  - `getZombie()` manda `pull` com o ID do zumbi mais perto e a posição do jogador;
  - no servidor (solo), `pull` move o zumbi pra posição;
  - no dedicado, `pull` manda `debugMove`;
  - `wind(true)` chama `NOMRender_setParam(11, 1)`; sem a função, imprime o aviso;
  - todo nome novo está em `NOM.HELP`.
- [ ] **Passo 2:** rodar `luajit tests/run.lua 2>&1 | grep -E "debug|FAIL"`. Esperado: FAIL.
- [ ] **Passo 3:** implementar como descrito.
- [ ] **Passo 4:** rodar `./run-tests.sh`. Esperado: verde.
- [ ] **Passo 5: commit.** `git commit -m "Debug: setFog/setRedFog/setBlackFog/setEndFog, getZombie, turnZombie, godMode e wind"`

---

### Tarefa 8: foco de vento na névoa fluida (mod3)

Primeiro teste de vento interagindo com a névoa (pedido do Johan). Com o parâmetro 11 ligado, o Java escolhe um ponto aleatório perto do jogador e sopra dali, de forma constante, numa direção aleatória. Desligar some com o foco. Ligar de novo sorteia outro.

**Arquivos:**
- Modificar: `mod3/java/nom/render/RenderContext.java` (`PARAM_WIND_SOURCE = 11`, padrão 0)
- Modificar: `mod3/java/nom/render/Flow.java` (sorteio do foco na thread principal, entra no `Input` e é aplicado na thread `NOM-fluido` antes do passo, como os `movers`)
- Teste: `tests/java/FlowWindSourceTest.java` (novo, registrado em `tests/test_mod3_flow.sh`), `tests/test_mod3_depth.py` (o contrato do parâmetro 11, como o do 10)
- Docs: tabela de parâmetros no `docs/HANDOFF.md` (linha do 11)

**Interfaces:**
- Consome: `FlowGrid.impulse(float wx, float wy, float vx, float vy, float radius)` (já existe, `FlowGrid.java:331`).
- Produz:
  - `RenderContext.PARAM_WIND_SOURCE = 11`;
  - em `Flow`: `static float sourceX, sourceY, sourceVX, sourceVY` e `static boolean sourceOn`;
  - `Flow.pickSource(float px, float py, java.util.Random r)`, `public static`, testável;
  - constantes `SOURCE_MIN_DIST = 15f`, `SOURCE_MAX_DIST = 30f`, `SOURCE_SPEED = 2.5f` (tiles/s), `SOURCE_RADIUS = 4f`.

**Comportamento:**
- **Ligar (borda de 0 para 1, lida na thread principal, onde o `Input` é montado):** sorteia ângulo e distância em [15, 30] tiles do jogador (posição de mundo) e uma direção de sopro aleatória. Loga `[NOM-Render] vento: foco em (x,y) soprando (vx,vy)`.
- **A cada passo da simulação, enquanto ligado:** `grid.impulse(sourceX, sourceY, sourceVX, sourceVY, SOURCE_RADIUS)`, convertendo pra coordenada da grade como os `movers` já fazem.
- **Desligar:** para de aplicar. O fluido segue sozinho.
- **Regra de ouro:** tudo dentro do `try/catch Throwable` que já protege o `Flow`.

- [ ] **Passo 1: teste Java que falha.** `FlowWindSourceTest`:
  - `pickSource` com `Random(1)` dá distância em [15, 30] e velocidade de módulo `SOURCE_SPEED`;
  - numa grade aberta 64×64 com densidade uniforme, 60 passos de `impulse` num ponto deixam a velocidade média na direção do sopro positiva, num raio de 6 tiles do foco, e maior que longe dele.
  - Seguir o formato de `tests/java/FlowHeightTest.java` e registrar em `tests/test_mod3_flow.sh`.
- [ ] **Passo 2:** rodar `bash tests/test_mod3_flow.sh`. Esperado: FAIL.
- [ ] **Passo 3:** implementar.
  - `test_mod3_depth.py`: asserção de que `PARAM_WIND_SOURCE = 11` existe e começa em 0.
- [ ] **Passo 4:** rodar `./run-tests.sh` e depois `scripts/build-mod3.sh`. Esperado: verde, e o jar compilado e assinado.
- [ ] **Passo 5: commit.** `git commit -m "mod3: foco de vento aleatório na névoa fluida (NOMRender_setParam 11)"`

---

## Depois das tarefas

1. **Code review final** da branch inteira, um só, no fim da entrega (decisão do Johan).
2. **Correções** do review num único despacho.
3. **Fechamento:** `./run-tests.sh` verde, merge na `main` com aprovação do Johan, push e `scripts/dev-sync.sh`. O Johan testa no jogo e reinicia depois do sync.
