-- shared/NOM_EmberRules.lua (sprint 0018): brasas e cinza da morte do Eco, puro.
-- Posição em pixels de tela no zoom 1, relativa ao pé do Eco (y negativo = pra cima).
require "NOM_EmberRules"

local E = NOM_EmberRules

return {
    embers_deterministic = function()
        local a, b = E.burst(42), E.burst(42)
        assert(#a == E.COUNT and #b == E.COUNT)
        for i = 1, #a do
            local x1, y1 = E.at(a[i], 300)
            local x2, y2 = E.at(b[i], 300)
            assert(x1 == x2 and y1 == y2, "mesma semente, brasa diferente")
        end
        local c = E.burst(43)
        local same = 0
        for i = 1, #a do if E.at(a[i], 300) == E.at(c[i], 300) then same = same + 1 end end
        assert(same < #a, "semente não muda nada")
    end,

    -- sobem, apagam no fim da vida, nascem laranja e viram cinza
    embers_rise_and_fade = function()
        for _, p in ipairs(E.burst(7)) do
            local _, y0, a0, r0, _, b0 = E.at(p, 50)
            local _, y1, a1, r1, _, b1 = E.at(p, p.life * 0.8)
            assert(y1 < y0, "não subiu")
            assert(a0 > 0 and a1 < a0 and a1 >= 0, "não apagou")
            assert(r0 > b0 + 0.4, "não nasceu laranja")
            assert(r1 - b1 < r0 - b0, "não acinzentou")
            assert(E.at(p, p.life) == nil, "viva depois da vida")
            assert(p.life <= E.LIFE_MS)
        end
    end,

    -- semente vinda do tempo real (~1.76e12) não estoura a conta
    embers_big_seed = function()
        for _, p in ipairs(E.burst(1759999999123)) do
            local x, y, a = E.at(p, 100)
            assert(x == x and y == y and a == a and math.abs(x) < 200 and math.abs(y) < 300, "brasa fora")
        end
    end,
}
