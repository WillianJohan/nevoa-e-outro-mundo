-- Regras puras das almas (sprint 0055: ciclo constante, 3 cores, 68% crawler).
require "NOM_AlmaRules"

local R = NOM_AlmaRules

return {
    -- Qualquer névoa aberta (branca, vermelha ou preta).
    alma_active_any_fog_color = function()
        R.reset()
        assert(R.active({ fog = true, red = false, black = false }) == true, "branca")
        assert(R.active({ fog = true, red = true }) == true, "vermelha")
        assert(R.active({ fog = true, black = true }) == true, "preta")
        assert(R.active({ fog = true, red = true, black = true }) == true)
        assert(R.active({ fog = false }) == false, "sem névoa")
        assert(R.active(nil) == false)
    end,

    alma_population_bounds_4_to_20 = function()
        R.reset()
        assert(R.POP_MIN == 4 and R.POP_MAX == 20)
        assert(R.POP_MIN < R.POP_MAX)
    end,

    -- Abaixo do mínimo: repõe até um alvo em [POP_MIN, POP_MAX]; no intervalo: 0.
    alma_refill_when_below_min = function()
        assert(R.refillCount(0, 0) == 4, "piso com u=0")
        assert(R.refillCount(0, 0.9999) == 20, "teto com u alto")
        assert(R.refillCount(3, 0) == 1, "falta 1 pro mínimo")
        local mid = R.refillCount(2, 0.5)
        assert(mid >= 2 and mid <= 18, "meio: " .. mid)
        assert(2 + mid >= R.POP_MIN and 2 + mid <= R.POP_MAX)
        assert(R.refillCount(4, 0.5) == 0, "já no mínimo")
        assert(R.refillCount(10, 0.9) == 0, "no intervalo")
        assert(R.refillCount(20, 0) == 0, "no máximo")
        assert(R.refillCount(25, 0) == 0, "acima do máximo")
    end,

    alma_refill_never_exceeds_max = function()
        for alive = 0, 20 do
            for i = 0, 99 do
                local n = R.refillCount(alive, i / 100)
                assert(n >= 0)
                assert(alive + n <= R.POP_MAX, "estouro: alive=" .. alive .. " n=" .. n)
                if alive >= R.POP_MIN then
                    assert(n == 0)
                elseif n > 0 then
                    assert(alive + n >= R.POP_MIN)
                end
            end
        end
    end,

    alma_crawler_about_68_percent = function()
        R.reset()
        assert(R.CRAWLER_CHANCE == 0.68)
        local n = 0
        for i = 0, 999 do
            if R.isCrawler(i / 1000) then n = n + 1 end
        end
        assert(n == 680, "crawlers: " .. n)
    end,

    alma_ttl_bands = function()
        assert(R.ttl(0) == 10000)
        assert(R.ttl(0.99) == 60000)
        local got = {}
        for i = 0, 99 do got[R.ttl(i / 100)] = true end
        assert(got[10000] and got[30000] and got[60000], "três faixas")
    end,

    alma_health_low = function()
        assert(R.HEALTH > 0 and R.HEALTH <= 0.4, "vida baixa: " .. R.HEALTH)
    end,

    alma_street_only = function()
        assert(R.streetOk(true) == true)
        assert(R.streetOk(false) == false)
        assert(R.streetOk(nil) == false)
    end,

    alma_pick_spawn_respects_outside = function()
        local u = 0
        local function rand()
            u = u + 0.17
            if u >= 1 then u = u - 1 end
            return u
        end
        local hits = {}
        local p = R.pickSpawn(100, 200, 0, rand, function(x, y, z)
            hits[#hits + 1] = { x = x, y = y, z = z }
            return false
        end, 5)
        assert(p == nil and #hits == 5, "tentou e falhou")
        local ok = R.pickSpawn(100, 200, 0, rand, function() return true end, 3)
        assert(ok and ok.z == 0)
        local d = math.sqrt((ok.x - 100) ^ 2 + (ok.y - 200) ^ 2)
        assert(d >= R.SPAWN_MIN - 1 and d <= R.SPAWN_MAX + 1, "anel: " .. d)
    end,

    alma_sounds_mapped = function()
        assert(R.SOUND.spawn == "NOM_AlmaSpawn")
        assert(R.SOUND.crawl == "NOM_AlmaCrawl")
        assert(R.SOUND.shamble == "NOM_AlmaShamble")
        assert(R.SOUND.group == "NOM_AlmaGroup")
        assert(R.SOUND.despawn == "NOM_AlmaDespawn")
        assert(R.loopSound(true) == "NOM_AlmaCrawl")
        assert(R.loopSound(false) == "NOM_AlmaShamble")
    end,

    alma_refill_throttle_ms = function()
        assert(type(R.REFILL_MS) == "number" and R.REFILL_MS > 0 and R.REFILL_MS <= 10000)
    end,

    -- Cores ligáveis/desligáveis (debug/painel); padrão: as três.
    alma_colors_default_all_on = function()
        R.reset()
        assert(R.colorEnabled("white") and R.colorEnabled("red") and R.colorEnabled("black"))
        assert(R.active({ fog = true }) == true)
        assert(R.active({ fog = true, red = true }) == true)
        assert(R.active({ fog = true, black = true }) == true)
    end,

    alma_colors_gate_active = function()
        R.reset()
        R.apply("white", false)
        assert(R.active({ fog = true, red = false, black = false }) == false, "branca off")
        assert(R.active({ fog = true, red = true }) == true, "vermelha ainda on")
        R.apply("red", false)
        R.apply("black", false)
        assert(R.active({ fog = true, red = true }) == false)
        assert(R.active({ fog = true, black = true }) == false)
        R.reset()
    end,

    alma_apply_pop_and_crawler = function()
        R.reset()
        assert(R.apply("popMin", 6) == 6)
        assert(R.POP_MIN == 6)
        assert(R.apply("popMax", 12) == 12)
        assert(R.POP_MAX == 12)
        -- min não passa do max
        assert(R.apply("popMin", 30) == 12)
        R.apply("popMax", 20)
        R.apply("popMin", 4)
        assert(R.apply("crawler", 0.5) == 0.5)
        assert(R.CRAWLER_CHANCE == 0.5)
        assert(R.apply("crawler", 2) == 1)
        assert(R.apply("crawler", -1) == 0)
        R.reset()
        assert(R.POP_MIN == 4 and R.POP_MAX == 20 and R.CRAWLER_CHANCE == 0.68)
    end,

    alma_apply_toggle_color_nil = function()
        R.reset()
        R.apply("white", nil) -- toggle
        assert(R.colorEnabled("white") == false)
        R.apply("white", nil)
        assert(R.colorEnabled("white") == true)
        R.reset()
    end,
}
