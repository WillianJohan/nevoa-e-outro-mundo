require "NOM_DeviceRules"

local R = NOM_DeviceRules

-- candidato como o client/NOM_Devices.lua monta: distância² ao jogador, ligado com
-- energia (live), TV, som já escolhido pela névoa
local function cand(o)
    return { d2 = o.d * o.d, live = o.live == true, tv = o.tv == true, sound = o.sound or "NOM_DevRadio",
        x = o.x or 0, y = o.y or 0 }
end

local function soundsBlock()
    local f = assert(io.open("mod/42/media/scripts/NOM_sounds.txt"))
    local txt = f:read("*a")
    f:close()
    return function(name) return txt:match("sound%s+" .. name .. "%s*(%b{})") end
end

return {
    -- quando fala: presságio (até a sirene), névoa aberta; nada na fuga, na calmaria ou sem névoa
    device_rules_mode = function()
        assert(R.mode({ on = false, rising = false }, 0) == nil, "sem névoa")
        assert(R.mode({ on = false, rising = true, omenAt = 0, sirenAt = 3000 }, 4000) == nil, "fuga")
        assert(R.mode({ on = false, rising = true }, 0) == nil, "fuga sem presságio")
        assert(R.mode({ on = true, rising = false }, 0) == "fog", "névoa aberta")
        assert(R.mode({ on = false, rising = false, omenAt = 1000 }, 2500) == "omen", "presságio")
        assert(R.mode({ on = false, rising = false, omenAt = 1000 }, 1000 + R.OMEN_MS + 1) == nil,
            "presságio velho, sem sirene, ficou falando")
    end,
    device_rules_fog_kind_single_point = function()
        assert(R.fogKind({ on = true, red = false }) == "white")
        assert(R.fogKind({ on = true, red = true }) == "red")
    end,
    -- lista de sons por névoa: caixa e carro usam a branca até ganharem a vermelha
    device_rules_sounds_by_fog = function()
        assert(R.sound("tv", "white") == "NOM_DevTv")
        assert(R.sound("tv", "red") == "NOM_DevTvRed")
        assert(R.sound("tv", "black") == "NOM_DevTvBlack")
        assert(R.sound("radio", "white") == "NOM_DevRadio")
        assert(R.sound("radio", "red") == "NOM_DevRadioRed")
        assert(R.sound("radio", "black") == "NOM_DevRadioBlack")
        assert(R.sound("speaker", "white") == "NOM_DevSpeaker")
        assert(R.sound("speaker", "red") == "NOM_DevSpeaker", "caixa vermelha ainda não existe")
        assert(R.sound("car", "red") == "NOM_DevCar", "carro vermelho ainda não existe")
    end,
    -- "voz" estável por coordenada: o mesmo aparelho sempre tem a mesma; tem rádio e tem caixa
    device_rules_voice_stable = function()
        local seen = {}
        for x = 10000, 10040 do
            local v = R.voice(x, 5000, 0)
            assert(v == R.voice(x, 5000, 0) and v == R.voice(x + 0.5, 5000.5, 0), "voz mudou no mesmo aparelho")
            assert(v == "radio" or v == "speaker", v)
            seen[v] = (seen[v] or 0) + 1
        end
        assert(seen.radio and seen.speaker and seen.radio > seen.speaker, "sorteio sem as duas vozes")
        assert(R.kind(true, false, 1, 1, 0) == "tv")
        assert(R.kind(false, true, 1, 1, 0) == "car")
        assert(R.kind(false, false, 10000, 5000, 0) == R.voice(10000, 5000, 0))
    end,
    -- regra vanilla de "pode ligar" (ISRadioAction.lua:57)
    device_rules_powered = function()
        assert(R.powered(true, 0.5, false))
        assert(not R.powered(true, 0, false), "pilha vazia")
        assert(R.powered(false, 0, true), "tomada ou gerador")
        assert(not R.powered(false, 0, false))
    end,
    -- intervalo do chamado: 90 a 180 s, e nunca menos de 60 s depois do último som
    device_rules_call_interval = function()
        assert(R.nextCall(1000, 0) == 1000 + 90000)
        assert(R.nextCall(1000, R.CALL_MAX_MS - R.CALL_MIN_MS - 1) < 1000 + 180000)
        assert(not R.callDue(5000, nil, nil), "sem agenda")
        assert(not R.callDue(5000, 6000, nil), "antes da hora")
        assert(R.callDue(6000, 6000, nil))
        assert(not R.callDue(100000, 90000, 100000 - R.GAP_MS + 1), "menos de 60 s depois do último")
        assert(R.callDue(100000, 90000, 100000 - R.GAP_MS))
    end,
    -- o mais perto entre 6 e 18 tiles; ligado tem prioridade
    device_rules_pick_nearest_in_band = function()
        local close = cand({ d = 4 })
        local mid = cand({ d = 9, sound = "NOM_DevCar" })
        local far = cand({ d = 15, sound = "NOM_DevSpeaker" })
        local out = cand({ d = 19 })
        assert(R.pick({ close, far, mid, out }, {}, 0) == mid, "não pegou o mais perto da faixa")
        assert(R.pick({ close, out }, {}, 0) == nil, "fora da faixa falou")
        local on = cand({ d = 17, live = true, sound = "NOM_DevTv", tv = true })
        assert(R.pick({ mid, on, far }, {}, 0) == on, "ligado sem prioridade")
    end,
    -- o mesmo arquivo não repete em menos de 3 chamados
    device_rules_no_repeat_in_three_calls = function()
        local radio = cand({ d = 8, sound = "NOM_DevRadio" })
        local car = cand({ d = 12, sound = "NOM_DevCar" })
        local recent = R.remember({}, "NOM_DevRadio")
        assert(R.pick({ radio, car }, recent, 0) == car, "repetiu no chamado seguinte")
        recent = R.remember(recent, "NOM_DevCar")
        local c, blocked = R.pick({ radio, car }, recent, 0)
        assert(c == nil and blocked, "repetiu dentro de 3 chamados")
        recent = R.remember(recent, false) -- o chamado em silêncio conta
        assert(R.pick({ radio, car }, recent, 0) == radio, "não voltou no 3º chamado")
        local _, none = R.pick({}, recent, 0)
        assert(not none, "sem aparelho na faixa não é chamado bloqueado")
    end,
    -- a TV é mais rara: perde a vez em parte dos sorteios, e perder conta como chamado
    device_rules_tv_rarer = function()
        local tv = cand({ d = 8, tv = true, sound = "NOM_DevTv" })
        assert(R.pick({ tv }, {}, R.TV_CHANCE - 0.01) == tv)
        local c, blocked = R.pick({ tv }, {}, R.TV_CHANCE)
        assert(c == nil and blocked, "TV sem sorteio")
        local radio = cand({ d = 14 })
        assert(R.pick({ tv, radio }, {}, 0.99) == radio, "a TV que perdeu a vez travou o rádio")
    end,
    -- estouro no presságio: todo aparelho a até 25 tiles, os mais perto primeiro, com teto
    device_rules_omen_targets = function()
        local list = {}
        for i = 1, R.OMEN_MAX + 3 do list[#list + 1] = cand({ d = i }) end
        list[#list + 1] = cand({ d = 26 })
        local t = R.omenTargets(list)
        assert(#t == R.OMEN_MAX, "teto: " .. #t)
        assert(t[1].d2 == 1 and t[2].d2 == 4, "não começou pelo mais perto")
        for _, c in ipairs(R.omenTargets({ cand({ d = 2 }), cand({ d = 24.9 }), cand({ d = 25.1 }) })) do
            assert(c.d2 <= 25 * 25, "estouro fora dos 25 tiles")
        end
        assert(#R.omenTargets({ cand({ d = 2 }), cand({ d = 24.9 }), cand({ d = 25.1 }) }) == 2)
    end,
    -- Sem-rosto a até 10 tiles do aparelho; grito a até 20
    device_rules_semrosto_and_scream = function()
        local a = cand({ d = 5 })
        local b = cand({ d = 12 })
        b.semRosto = true
        assert(R.pickSemRosto({ a, b }) == b)
        a.semRosto = true
        assert(R.pickSemRosto({ a, b }) == a, "não pegou o mais perto")
        assert(R.pickSemRosto({ cand({ d = 5 }) }) == nil)
        local near = cand({ d = 10, x = 110, y = 100 })
        local farFromScream = cand({ d = 3, x = 100, y = 103 })
        assert(R.pickScream({ near, farFromScream }, 125, 100) == near, "aparelho longe do grito respirou")
        assert(R.pickScream({ farFromScream }, 125, 100) == nil)
    end,
    device_rules_stop_range_and_volume = function()
        assert(not R.outOfRange(20 * 20))
        assert(R.outOfRange(20 * 20 + 1))
        assert(R.volume(true) == 1 and R.volume(false) < 1 and R.volume(false) > 0, "ligado mais alto")
    end,
    -- todo som de aparelho declarado: one-shot, distanceMin 2, distanceMax 18, 0,35 a 0,5
    -- do volume da sirene (que é 1), TV mais baixa
    device_rules_sounds_declared = function()
        local block = soundsBlock()
        local names = { R.BURST }
        for _, byFog in pairs(R.SOUNDS) do
            for _, name in pairs(byFog) do names[#names + 1] = name end
        end
        assert(#names == 9, "sons: " .. #names)
        local vol = {}
        for _, name in ipairs(names) do
            local b = assert(block(name), "som sem declaração: " .. name)
            assert(not b:find("loop", 1, true), name .. " em loop")
            assert(b:match("distanceMin = (%d+)") == "2", name .. ": distanceMin")
            assert(b:match("distanceMax = (%d+)") == "18", name .. ": distanceMax")
            vol[name] = tonumber(b:match("volume = ([%d%.]+)"))
            assert(vol[name] and vol[name] >= 0.35 and vol[name] <= 0.5, name .. ": volume")
        end
        assert(vol.NOM_DevTv < vol.NOM_DevRadio, "TV não é mais baixa")
    end,
}
