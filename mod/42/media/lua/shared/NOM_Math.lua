-- Resto que dá o mesmo no jogo e nos testes (review da 0017). O % do Kahlua trunca:
-- KahluaThread.primitiveMath faz a - (double)(int)(a/b)*b, então com operando negativo o
-- resto sai negativo (-1 % 2 = -1) e o (int) satura em 2^31-1 quando a/b passa disso
-- (getTimestampMs ~1.76e12). O luajit dos testes arredonda pra baixo e não satura.
-- math.floor do Kahlua é Math.floor em double (MathLib.floor 23–32), sem (int): exato
-- pra todo inteiro abaixo de 2^53. Lint: tests/test_kahlua_compat.lua.
NOM_Math = {}

-- Resto com o sinal de b (o % do Lua 5.1 de referência).
function NOM_Math.mod(a, b)
    return a - math.floor(a / b) * b
end

return NOM_Math
