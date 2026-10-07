-- Regras puras da luz que pisca (sprint 0045): padrão = durações alternando apagado/aceso,
-- começando apagado e terminando aceso.
require "NOM_FlickerRules"

local R = NOM_FlickerRules

local function seq(...)
    local v, i = { ... }, 0
    return function()
        i = i + 1
        return v[(i - 1) % #v + 1]
    end
end

local function shape(segs)
    assert(#segs % 2 == 1, "padrão tem que terminar num trecho apagado (aceso depois do fim)")
    for _, ms in ipairs(segs) do assert(ms > 0 and ms == math.floor(ms), "duração inválida: " .. tostring(ms)) end
end

return {
    flicker_torch_stutters_goes_dark_and_comes_back = function()
        for _, r in ipairs({ 0, 0.5, 0.999 }) do
            local segs = R.torch(1000, seq(r))
            shape(segs)
            local stutters = 0
            local dark = false
            for i, ms in ipairs(segs) do
                if ms == 1000 then
                    dark = true
                    assert(i % 2 == 1, "o escuro tem que ser um trecho apagado")
                else
                    assert(ms >= R.STUTTER_MIN_MS and ms <= R.STUTTER_MAX_MS, "gagueira fora da faixa: " .. ms)
                    stutters = stutters + 1
                end
            end
            assert(dark, "sem o escuro do meio")
            assert(stutters >= 2 * (R.TORCH_STUTTER[1] + R.TORCH_BACK[1]) - 1, "gagueira curta demais: " .. stutters)
            assert(R.total(segs) <= R.torchMax(1000), "torchMax subestima")
        end
    end,
    flicker_lamp_stutters_and_sometimes_goes_dark = function()
        local plain = R.lamp(seq(0.9))
        shape(plain)
        for _, ms in ipairs(plain) do assert(ms <= R.STUTTER_MAX_MS, "escuro sem sortear: " .. ms) end
        assert(#plain >= 2 * R.LAMP_STUTTER[1] + 1)
        local dark = R.lamp(seq(0.1))
        shape(dark)
        local long = 0
        for _, ms in ipairs(dark) do if ms >= R.LAMP_DARK_MIN_MS then long = long + 1 end end
        assert(long == 1, "o escuro do poste tem que aparecer uma vez")
        assert(R.total(dark) <= R.lampMax() and R.total(plain) <= R.lampMax())
    end,
    flicker_state_at = function()
        local segs = { 100, 50, 200 }
        local on, done = R.stateAt(segs, -5)
        assert(on == true and done == false, "antes de começar: aceso")
        on = R.stateAt(segs, 0)
        assert(on == false, "começa apagado")
        assert(R.stateAt(segs, 99) == false and R.stateAt(segs, 100) == true and R.stateAt(segs, 149) == true)
        assert(R.stateAt(segs, 150) == false and R.stateAt(segs, 349) == false)
        on, done = R.stateAt(segs, 350)
        assert(on == true and done == true, "no fim: aceso e acabou")
        assert(R.total(segs) == 350)
    end,
}
