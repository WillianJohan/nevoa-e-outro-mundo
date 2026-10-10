-- shared/NOM_PanelParams.lua (sprint 0058): knobs live do painel, sem API do jogo.
require "NOM_PanelParams"

local P = NOM_PanelParams

return {
    panel_params_defaults_match_produto = function()
        P.reset()
        assert(P.get("AlmaPopMin") == 5)
        assert(P.get("AlmaPopMax") == 30)
        assert(P.get("AlmaPopMinRed") == 25)
        assert(P.get("AlmaPopMaxRed") == 50)
        assert(P.get("AlmaPopMinBlack") == 30)
        assert(P.get("AlmaPopMaxBlack") == 100)
        assert(P.get("AlmaCrawlerPct") == 50)
        assert(P.get("AlmaFogWhite") == true)
        assert(P.get("AlmaFogRed") == true)
        assert(P.get("AlmaFogBlack") == true)
        assert(P.get("EstaladorRhythm") == "rotate")
        assert(P.get("EstaladorGapMinMs") == 5000)
        assert(P.get("EstaladorGapMaxMs") == 30000)
        assert(P.get("AmbientGapMinMs") == 30000)
        assert(P.get("AmbientGapMaxMs") == 500000)
        assert(P.get("CarpideiraScreamGapMinMs") == 45000)
        assert(P.get("CarpideiraScreamGapMaxMs") == 180000)
        assert(P.get("CinzaRateMult") == 1.0)
        assert(P.get("CinzaDensityMult") == 1.0)
        assert(P.get("LookForce") == "")
        assert(P.get("GlitchMode") == "original")
        assert(P.get("GlitchIntensity") == 110)
        assert(P.get("SemRostoPct") == 12)
    end,

    panel_params_set_clamps_and_marks_live = function()
        P.reset()
        assert(P.isLive("AlmaPopMin") == false)
        assert(P.set("AlmaPopMin", -3) == 0)
        assert(P.isLive("AlmaPopMin") == true)
        assert(P.set("AlmaCrawlerPct", 150) == 100)
        assert(P.set("CinzaRateMult", 9) == 3.0)
        assert(P.set("CinzaRateMult", 1.24) == 1.2) -- step 0.1
        assert(P.set("EstaladorRhythm", "Z") == "rotate") -- inválido → default
        assert(P.set("EstaladorRhythm", "B") == "B")
        assert(P.set("LookForce", "pale") == "pale")
        assert(P.set("LookForce", "nope") == "")
    end,

    panel_params_keeps_pop_min_le_max = function()
        P.reset()
        P.set("AlmaPopMax", 10)
        assert(P.set("AlmaPopMin", 15) == 10) -- não passa do max
        P.set("AlmaPopMin", 5)
        assert(P.set("AlmaPopMax", 2) == 5) -- não fica abaixo do min
        P.set("AlmaPopMaxRed", 40)
        assert(P.set("AlmaPopMinRed", 45) == 40)
        P.set("AlmaPopMaxBlack", 80)
        assert(P.set("AlmaPopMinBlack", 90) == 80)
        P.set("AlmaPopMinBlack", 30)
        assert(P.set("AlmaPopMaxBlack", 10) == 30)
    end,

    panel_params_gap_min_le_max = function()
        P.reset()
        P.set("EstaladorGapMaxMs", 8000)
        assert(P.set("EstaladorGapMinMs", 9000) == 8000)
        P.set("EstaladorGapMinMs", 5000)
        assert(P.set("EstaladorGapMaxMs", 4000) == 5000)
        -- playtest: gritos ambiente 30–500 s; Carpideira 45–180 s
        P.set("AmbientGapMaxMs", 120000)
        assert(P.set("AmbientGapMinMs", 200000) == 120000)
        P.set("AmbientGapMinMs", 30000)
        assert(P.set("AmbientGapMaxMs", 20000) == 30000)
        P.set("CarpideiraScreamGapMaxMs", 90000)
        assert(P.set("CarpideiraScreamGapMinMs", 120000) == 90000)
        P.set("CarpideiraScreamGapMinMs", 45000)
        assert(P.set("CarpideiraScreamGapMaxMs", 30000) == 45000)
    end,

    panel_params_reset_one_or_all = function()
        P.reset()
        P.set("AlmaPopMin", 8)
        P.set("LookForce", "wrong")
        P.reset("AlmaPopMin")
        assert(P.get("AlmaPopMin") == 5 and P.isLive("AlmaPopMin") == false)
        assert(P.get("LookForce") == "wrong")
        P.reset()
        assert(P.get("LookForce") == "")
    end,

    panel_params_helpers = function()
        P.reset()
        assert(math.abs(P.almaCrawlerChance() - 0.5) < 1e-9)
        P.set("AlmaCrawlerPct", 50)
        assert(math.abs(P.almaCrawlerChance() - 0.5) < 1e-9)
        assert(math.abs(P.cinzaRate(14) - 14) < 1e-9)
        P.set("CinzaRateMult", 2)
        assert(math.abs(P.cinzaRate(14) - 28) < 1e-9)
        P.set("CinzaDensityMult", 0.5)
        assert(math.abs(P.cinzaDensity(1) - 0.5) < 1e-9)
        assert(P.lookForce() == "")
        P.set("LookForce", "patient")
        assert(P.lookForce() == "patient")
        -- Singleton compartilhado: sem reset, LookForce="patient" vaza pra
        -- test_variant_rules / test_night_stats quando pairs() muda a ordem.
        P.reset()
    end,

    panel_params_rhythms_abc = function()
        P.reset()
        local a = P.estaladorBeats("A")
        assert(a and #a >= 8, "ritmo A (burst 0048)")
        assert(a[1] == 0)
        local b = P.estaladorBeats("B")
        assert(#b == 4 and b[1] == 0 and b[2] == 500 and b[3] == 1000 and b[4] == 1800)
        local c = P.estaladorBeats("C")
        assert(#c == 6 and c[1] == 0 and c[2] == 1000 and c[3] == 2000)
        assert(c[4] == 2060 and c[5] == 4060 and c[6] == 7060)
        assert(P.estaladorBeats("rotate") == nil, "rotate = sorteio no agente 0056")
        P.set("EstaladorRhythm", "B")
        local cur = P.estaladorBeats()
        assert(cur and cur[4] == 1800)
    end,

    panel_params_snapshot_and_format = function()
        P.reset()
        P.set("AlmaFogRed", false)
        local s = P.snapshot()
        assert(s.AlmaPopMin == 5 and s.AlmaFogRed == false)
        assert(P.format("AlmaCrawlerPct", 68) == "68%")
        assert(P.format("AlmaFogWhite", true) == "on")
        assert(P.format("EstaladorRhythm", "B") == "B")
        assert(P.format("CinzaRateMult", 1.5) == "1.5×")
    end,

    panel_params_schema_covers_ui_keys = function()
        local need = {
            "AlmaPopMin", "AlmaPopMax", "AlmaPopMinRed", "AlmaPopMaxRed",
            "AlmaPopMinBlack", "AlmaPopMaxBlack", "AlmaCrawlerPct",
            "AlmaFogWhite", "AlmaFogRed", "AlmaFogBlack",
            "EstaladorRhythm", "EstaladorGapMinMs", "EstaladorGapMaxMs",
            "AmbientGapMinMs", "AmbientGapMaxMs",
            "CarpideiraScreamGapMinMs", "CarpideiraScreamGapMaxMs",
            "CinzaRateMult", "CinzaDensityMult", "LookForce",
            "GlitchMode", "GlitchIntensity", "SemRostoPct",
            "ScreamerK1Weight", "ScreamerK2Weight",
        }
        for _, k in ipairs(need) do
            assert(P.SCHEMA[k], "SCHEMA sem " .. k)
            assert(P.DEFAULTS[k] ~= nil or P.DEFAULTS[k] == false or P.DEFAULTS[k] == "",
                "DEFAULTS sem " .. k)
        end
    end,

    -- 0058b: dump plain chave=valor pra colar no chat
    panel_params_dump_text_chave_valor = function()
        P.reset()
        local t = P.dumpText()
        assert(t:find("# NOM_PanelParams", 1, true), t)
        assert(t:find("# live: (nenhum)", 1, true), t)
        assert(t:find("AlmaPopMin=5", 1, true), t)
        assert(t:find("AlmaPopMinRed=25", 1, true), t)
        assert(t:find("AlmaPopMinBlack=30", 1, true), t)
        assert(t:find("AlmaPopMaxBlack=100", 1, true), t)
        assert(t:find("AlmaFogWhite=true", 1, true), t)
        assert(t:find("EstaladorRhythm=rotate", 1, true), t)
        assert(t:find("AmbientGapMinMs=30000", 1, true), t)
        assert(t:find("AmbientGapMaxMs=500000", 1, true), t)
        assert(t:find("CarpideiraScreamGapMinMs=45000", 1, true), t)
        assert(t:find("CarpideiraScreamGapMaxMs=180000", 1, true), t)
        assert(t:find('LookForce=""', 1, true), t)
        assert(t:find("GlitchMode=original", 1, true), t)
        assert(t:find("GlitchIntensity=110", 1, true), t)
        assert(t:find("SemRostoPct=12", 1, true), t)
        assert(t:find("ScreamerK1Weight=1", 1, true), t)
        assert(t:find("ScreamerK2Weight=1", 1, true), t)
        assert(not t:find("ScreamerK3Weight", 1, true), "K3 peso morto no dump")
        P.set("AlmaPopMin", 7)
        P.set("SemRostoPct", 20)
        P.set("CinzaRateMult", 1.5)
        t = P.dumpText()
        assert(t:find("AlmaPopMin", 1, true) and t:find("CinzaRateMult", 1, true), t)
        assert(t:find("# live:", 1, true) and t:find("AlmaPopMin", 1, true), t)
        assert(t:find("AlmaPopMin=7", 1, true), t)
        assert(t:find("CinzaRateMult=1.5", 1, true), t)
        assert(t:find("SemRostoPct=20", 1, true), t)
        P.reset()
    end,

    -- LookForce → kind de variante (runtime)
    panel_params_look_kind_maps_archetypes = function()
        P.reset()
        assert(P.lookKind() == nil)
        assert(P.set("LookForce", "pale") == "pale")
        assert(P.lookKind() == "estalador")
        assert(P.set("LookForce", "misaligned") == "misaligned")
        assert(P.lookKind() == "corredor")
        assert(P.set("LookForce", "wrong") == "wrong")
        assert(P.lookKind() == "semrosto")
        assert(P.set("LookForce", "patient") == "patient")
        assert(P.lookKind() == "carpideira")
        assert(P.set("LookForce", "silhouette") == "silhouette")
        assert(P.lookKind() == "carpideira")
        assert(P.set("LookForce", "") == "")
        assert(P.lookKind() == nil)
        P.reset()
    end,
}
