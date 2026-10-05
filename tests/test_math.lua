-- shared/NOM_Math.lua (review da 0017): resto que dá o mesmo no Kahlua e no luajit.
require "NOM_Math"

local M = NOM_Math

-- O % do Kahlua (KahluaThread.primitiveMath): a - (double)(int)(a/b)*b, com o (int) do
-- Java (trunca pra zero e satura em ±2^31).
local function kahluaMod(a, b)
    local q = a / b
    q = q < 0 and math.ceil(q) or math.floor(q)
    if q > 2147483647 then q = 2147483647 elseif q < -2147483648 then q = -2147483648 end
    return a - q * b
end

return {
    math_mod_floored_and_exact = function()
        assert(M.mod(5, 2) == 1 and M.mod(4, 2) == 0)
        assert(M.mod(-1, 2) == 1 and M.mod(-3, 2) == 1 and M.mod(-4, 2) == 0, "negativo")
        assert(kahluaMod(-1, 2) == -1, "o fake do Kahlua não trunca: teste não prova nada")
        assert(M.mod(-7, 3) == 2)
        assert(M.mod(2.5, 1) == 0.5, "float")
        local now = 1760000000123 -- getTimestampMs de 2025
        assert(M.mod(now, 1000) == 123)
        assert(kahluaMod(now * 7, 64) ~= M.mod(now * 7, 64), "o fake do Kahlua não satura")
        assert(M.mod(now * 7, 64) == (now * 7) % 64, "grande, abaixo de 2^53")
        -- ID feminino com o bit do chapéu: paridade certa nos dois sentidos
        local female = 3 * 65536 + 77 - 2147483648
        assert(M.mod(math.floor((female + 32768) / 32768), 2) == 1)
        assert(M.mod(math.floor(female / 32768), 2) == 0)
    end,
}
