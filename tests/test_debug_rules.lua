require "NOM_DebugRules"

local D = NOM_DebugRules

return {
    debug_rules_parse_accepts_known_ops = function()
        local a = D.parse({ op = "night", value = true })
        assert(a.op == "night" and a.value == true)
        a = D.parse({ op = "night" })
        assert(a.op == "night" and a.value == nil, "nil devolve pro clima")
        -- névoa é evento (sprint 0009): true começa (skip pula a espera da sirene), false/nil termina
        a = D.parse({ op = "fog", value = true, skip = true })
        assert(a.value == true and a.skip == true)
        a = D.parse({ op = "fog", value = true })
        assert(a.value == true and a.skip == false)
        assert(D.parse({ op = "fog" }).value == false, "nil termina")
        assert(D.parse({ op = "fog", value = false }).value == false)
        a = D.parse({ op = "variant", id = -2147000000, kind = "estalador" })
        assert(a.id == -2147000000 and a.kind == "estalador")
        assert(D.parse({ op = "variant", id = 5 }).kind == nil, "kind nil limpa")
        assert(D.parse({ op = "spawnEco" }).op == "spawnEco")
        assert(D.parse({ op = "status" }).op == "status")
    end,
    debug_rules_parse_rejects_garbage = function()
        assert(D.parse(nil) == nil)
        assert(D.parse({ op = "kill" }) == nil)
        assert(D.parse({ op = "night", value = "sim" }) == nil)
        assert(D.parse({ op = "fog", value = "muito" }) == nil)
        assert(D.parse({ op = "fog", value = 0.8 }) == nil, "intensidade não existe mais")
        assert(D.parse({ op = "fog", value = true, skip = "sim" }) == nil)
        assert(D.parse({ op = "variant", id = 0, kind = "corredor" }) == nil, "ID 0 é zumbi sem outfit")
        assert(D.parse({ op = "variant", kind = "corredor" }) == nil)
        assert(D.parse({ op = "variant", id = 5, kind = "carrasco" }) == nil)
    end,
    debug_rules_line_is_sorted = function()
        assert(D.line("[NOM] x", { b = 2, a = true, c = "z" }) == "[NOM] x a=true b=2 c=z")
        assert(D.line("[NOM] x", {}) == "[NOM] x")
    end,
    -- NaN não é igual a si mesmo: viraria uma chave que ninguém acha (variante) ou
    -- passaria pelo math.max/min sem ser preso (névoa)
    debug_rules_parse_rejects_nan = function()
        local nan = 0 / 0
        assert(D.parse({ op = "variant", id = nan, kind = "corredor" }) == nil)
    end,
}

