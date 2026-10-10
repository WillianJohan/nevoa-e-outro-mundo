-- Regras puras das almas (sprint 0068 / proposta névoas v2).
require "NOM_AlmaRules"

local R = NOM_AlmaRules

return {
    alma_active_any_fog_color = function()
        R.reset()
        assert(R.active({ fog = true, red = false, black = false }) == true, "branca")
        assert(R.active({ fog = true, red = true }) == true, "vermelha")
        assert(R.active({ fog = true, black = true }) == true, "preta")
        assert(R.active({ fog = false }) == false, "sem névoa")
    end,

    alma_population_bands_v2 = function()
        R.reset()
        assert(R.POP_MIN == 5 and R.POP_MAX == 30, "branca")
        assert(R.POP_MIN_RED == 25 and R.POP_MAX_RED == 50, "vermelha")
        assert(R.POP_MIN_BLACK == 30 and R.POP_MAX_BLACK == 100, "preta")
        local mn, mx = R.popBounds({ fog = true })
        assert(mn == 5 and mx == 30)
        mn, mx = R.popBounds({ fog = true, red = true })
        assert(mn == 25 and mx == 50)
        mn, mx = R.popBounds({ fog = true, black = true })
        assert(mn == 30 and mx == 100)
    end,

    alma_tick_target_and_spawn_need = function()
        R.reset()
        local white = { fog = true }
        assert(R.tickTarget(0, white) == 5)
        assert(R.tickTarget(0.9999, white) == 30)
        assert(R.spawnNeed(0, 0, white) == 5)
        local needMid = R.spawnNeed(10, 0.5, white)
        assert(needMid >= 0 and 10 + needMid <= R.POP_MAX)
        assert(R.spawnNeed(5, 0.9999, white) == 25, "alvo alto")
        local red = { fog = true, red = true }
        assert(R.spawnNeed(0, 0, red) == 25)
        assert(R.spawnNeed(0, 0.9999, red) == 50)
    end,

    alma_spawn_need_never_exceeds_target = function()
        R.reset()
        for alive = 0, 100 do
            for i = 0, 99 do
                local u = i / 100
                local target = R.tickTarget(u, { fog = true, black = true })
                local n = R.spawnNeed(alive, u, { fog = true, black = true })
                assert(n >= 0)
                if n > 0 then
                    assert(alive + n == target)
                else
                    assert(alive >= target)
                end
            end
        end
    end,

    alma_white_crawler_only = function()
        R.reset()
        assert(R.whiteOnlyCrawlers({ fog = true }) == true)
        assert(R.isCrawler(0.99, { fog = true }) == true)
        assert(R.isCrawler(0.99, { fog = true, red = true }) == false)
        assert(R.isCrawler(0.1, { fog = true, red = true }) == true)
    end,

    alma_ttl_v2 = function()
        R.reset()
        assert(R.ttl(0, { fog = true }) == 5000)
        assert(R.ttl(0.9999, { fog = true }) >= 14000 and R.ttl(0.9999, { fog = true }) <= 15000)
        assert(R.ttl(0.5, { fog = true, red = true }) >= 5000 and R.ttl(0.5, { fog = true, red = true }) <= 15000)
        assert(R.ttl(0, { fog = true, black = true }) == nil)
        assert(R.ttlUnlimited({ fog = true, black = true }) == true)
    end,

    alma_count_radius_and_cluster = function()
        R.reset()
        assert(R.COUNT_RADIUS == 50 and R.TICK_MS == 5000)
        local p1 = { x = 0, y = 0, z = 0 }
        local p2 = { x = 40, y = 0, z = 0 }
        local p3 = { x = 200, y = 0, z = 0 }
        local clusters = R.clusterPlayers({ p1, p2, p3 })
        assert(#clusters == 2, "dois grupos MP: " .. #clusters)
        local big, small
        for i = 1, #clusters do
            if #clusters[i] == 2 then big = clusters[i] end
            if #clusters[i] == 1 then small = clusters[i] end
        end
        assert(big and small)
        local positions = {
            { x = 10, y = 0 },
            { x = 45, y = 0 },
            { x = 190, y = 0 },
        }
        assert(R.countNearAnchors(big, positions) == 2)
        assert(R.countNearAnchors(small, positions) == 1)
    end,

    alma_health_low = function()
        assert(R.HEALTH > 0 and R.HEALTH <= 0.4)
    end,

    alma_street_only = function()
        assert(R.streetOk(true) == true)
        assert(R.streetOk(false) == false)
    end,

    alma_pick_spawn_respects_outside = function()
        local u = 0
        local function rand()
            u = u + 0.17
            if u >= 1 then u = u - 1 end
            return u
        end
        local p = R.pickSpawn(100, 200, 0, rand, function() return true end, 3)
        assert(p and p.z == 0)
        local d = math.sqrt((p.x - 100) ^ 2 + (p.y - 200) ^ 2)
        assert(d >= R.SPAWN_MIN - 1 and d <= R.SPAWN_MAX + 1, "anel: " .. d)
    end,

    alma_sounds_mapped = function()
        assert(R.SOUND.spawn == "NOM_AlmaSpawn")
        assert(R.loopSound(true) == "NOM_AlmaCrawl")
    end,

    alma_colors_default_all_on = function()
        R.reset()
        assert(R.colorEnabled("white") and R.colorEnabled("red") and R.colorEnabled("black"))
    end,

    alma_apply_pop_red_and_crawler = function()
        R.reset()
        assert(R.apply("popMin", 6) == 6)
        assert(R.apply("popMinRed", 28) == 28)
        assert(R.apply("popMaxRed", 45) == 45)
        assert(R.apply("popMinBlack", 35) == 35)
        assert(R.apply("popMaxBlack", 90) == 90)
        assert(R.apply("crawler", 0.6) == 0.6)
        R.reset()
        assert(R.POP_MIN == 5 and R.POP_MIN_RED == 25 and R.POP_MIN_BLACK == 30)
    end,
}
