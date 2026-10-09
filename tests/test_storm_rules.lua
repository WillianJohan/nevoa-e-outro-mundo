-- Regras puras da tempestade da névoa preta e da vermelha (sprint 0045).
require "NOM_StormRules"

local R = NOM_StormRules

return {
    storm_next_thunder_in_range = function()
        assert(R.nextThunder(0) == R.THUNDER_MIN_MS)
        assert(R.nextThunder(0.999999) <= R.THUNDER_MAX_MS and R.nextThunder(0.999999) > R.THUNDER_MAX_MS - 10)
        local mid = R.nextThunder(0.5)
        assert(mid > R.THUNDER_MIN_MS and mid < R.THUNDER_MAX_MS)
    end,
    storm_thunder_point_far_from_player = function()
        for _, a in ipairs({ 0, 0.25, 0.5, 0.75, 0.999 }) do
            for _, d in ipairs({ 0, 0.5, 0.999 }) do
                local x, y = R.thunderPoint(100, 200, a, d)
                assert(x == math.floor(x) and y == math.floor(y), "ponto fora do tile")
                local dist = math.sqrt((x - 100) ^ 2 + (y - 200) ^ 2)
                assert(dist >= R.DIST_MIN - 1 and dist <= R.DIST_MAX + 1, "distância: " .. dist)
            end
        end
        -- o clarão do jogo some a 7500 (ThunderStorm.enqueueThunderEvent, pz-api-notes §34)
        assert(R.DIST_MAX < 7500 / 2)
    end,
    -- chuva: sorteio fixo por período (a mesma névoa não liga e desliga), ~30% das névoas
    storm_rain_per_period = function()
        local n, differ = 0, 0
        for p = 1, 1000 do
            local r = R.rains(p, 12345)
            assert(r == R.rains(p, 12345), "sorteio não é fixo")
            if r then n = n + 1 end
            if r ~= R.rains(p, 999) then differ = differ + 1 end
        end
        assert(n >= 250 and n <= 350, "chuva em " .. n .. " de 1000")
        assert(differ > 100, "a semente do mundo não muda o sorteio")
        assert(R.rains(nil, 1) == false)
        assert(R.RAIN_INTENSITY > 0 and R.RAIN_INTENSITY <= 1)
    end,
    -- sprint 0053: clarão vermelho só na preta; vermelha/branca brancas
    storm_lightning_tint_black_only = function()
        local wr, wg, wb = R.lightningTint(false)
        assert(wr == 1 and wg == 1 and wb == 1, "vermelha/branca brancas")
        local br, bg, bb = R.lightningTint(true)
        assert(br == R.LIGHTNING_BLACK.r and bg == R.LIGHTNING_BLACK.g and bb == R.LIGHTNING_BLACK.b)
        assert(bg < 0.3 and bb < 0.3, "preta bem vermelha")
        assert(R.stormFlash(1000, nil) == 0)
        assert(R.stormFlash(1000, 1000) == 1)
        assert(R.stormFlash(1000 + R.STORM_FLASH_MS, 1000) == 0)
        local mid = R.stormFlash(1000 + R.STORM_FLASH_MS / 2, 1000)
        assert(mid > 0 and mid < 1)
    end,
}
