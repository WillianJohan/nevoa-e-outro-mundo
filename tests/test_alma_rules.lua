-- Regras puras das almas (sprint 0050).
require "NOM_AlmaRules"

local R = NOM_AlmaRules

return {
    alma_active_only_white_fog = function()
        assert(R.active({ fog = true, red = false, black = false }) == true)
        assert(R.active({ fog = false }) == false, "sem névoa")
        assert(R.active({ fog = true, red = true }) == false, "vermelha")
        assert(R.active({ fog = true, black = true }) == false, "preta")
        assert(R.active({ fog = true, red = true, black = true }) == false)
        assert(R.active(nil) == false)
    end,

    alma_gap_45_to_120_seconds = function()
        assert(R.GAP_MIN_MS == 45000 and R.GAP_MAX_MS == 120000)
        assert(R.gap(0) == 45000)
        local hi = R.gap(0.999999)
        assert(hi >= 119990 and hi <= 120000, "teto: " .. hi)
        local mid = R.gap(0.5)
        assert(mid > 45000 and mid < 120000, "meio: " .. mid)
    end,

    alma_wave_sizes_organic = function()
        local seen = {}
        for i = 0, 99 do
            local n = R.waveSize(i / 100, 0.5)
            seen[n] = true
            assert(n >= 10 - R.WAVE_JITTER and n <= 20 + R.WAVE_JITTER)
        end
        assert(seen[10] or seen[15] or seen[20], "bases da leva")
    end,

    alma_ttl_bands = function()
        assert(R.ttl(0) == 10000)
        assert(R.ttl(0.34) == 30000 or R.ttl(0.34) == 10000)
        assert(R.ttl(0.99) == 60000)
        local got = {}
        for i = 0, 99 do got[R.ttl(i / 100)] = true end
        assert(got[10000] and got[30000] and got[60000], "três faixas")
    end,

    alma_crawler_about_70_percent = function()
        assert(R.CRAWLER_CHANCE == 0.70)
        local n = 0
        for i = 0, 999 do
            if R.isCrawler(i / 1000) then n = n + 1 end
        end
        assert(n == 700, "crawlers: " .. n)
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
}
