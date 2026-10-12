-- Teto visual do Sem-rosto (bíblia §7.3): máx 1/6 no grupo e 2 por tela.
-- Excedentes ficam Sem-rosto no gameplay, mas look F1+S5.
require "NOM_SemRostoCap"

local C = NOM_SemRostoCap

return {
    semrosto_cap_defaults = function()
        assert(C.MAX_SCREEN == 2)
        assert(C.PER_GROUP == 6)
        assert(C.CLUSTER_RADIUS == 8)
    end,

    -- Grupo pequeno (< 6): ninguém ganha look completo (só F1+S5).
    semrosto_cap_small_group_all_capped = function()
        local entries = {
            { id = 10, x = 0, y = 0 },
            { id = 20, x = 1, y = 0 },
        }
        local crowd = {
            { x = 0, y = 0 }, { x = 1, y = 0 }, { x = 2, y = 0 },
            { x = 0, y = 1 }, { x = 1, y = 1 },
        }
        local full = C.fullLook(entries, crowd)
        assert(full[10] == nil and full[20] == nil)
        assert(C.isCapped(10, full) == true)
    end,

    -- Grupo de 12: floor(12/6)=2 full no cluster, mas teto de tela = 2.
    semrosto_cap_screen_and_group = function()
        local entries = {}
        local crowd = {}
        for i = 1, 12 do
            crowd[#crowd + 1] = { x = i * 0.3, y = 0 }
        end
        for _, id in ipairs({ 100, 200, 300, 400 }) do
            entries[#entries + 1] = { id = id, x = 0, y = 0 }
        end
        local full = C.fullLook(entries, crowd)
        local n = 0
        for _ in pairs(full) do n = n + 1 end
        assert(n == 2, "tela max 2: " .. n)
        assert(full[100] and full[200], "menores IDs primeiro (ADR-006)")
        assert(full[300] == nil and full[400] == nil)
    end,

    -- Determinístico: mesma entrada → mesma máscara.
    semrosto_cap_deterministic = function()
        local entries = {
            { id = 9, x = 0, y = 0 },
            { id = 3, x = 0.5, y = 0 },
            { id = 7, x = 1, y = 0 },
        }
        local crowd = {}
        for i = 1, 18 do crowd[i] = { x = i * 0.2, y = 0 } end
        local a = C.fullLook(entries, crowd)
        local b = C.fullLook(entries, crowd)
        assert(a[3] == b[3] and a[7] == b[7] and a[9] == b[9])
        local n = 0
        for _ in pairs(a) do n = n + 1 end
        assert(n == 2)
        assert(a[3] and a[7] and not a[9])
    end,

    -- Clusters longe: cada um tem o próprio teto 1/6.
    semrosto_cap_separate_clusters = function()
        local crowdA, crowdB = {}, {}
        for i = 1, 6 do
            crowdA[i] = { x = i * 0.2, y = 0 }
            crowdB[i] = { x = 100 + i * 0.2, y = 0 }
        end
        local crowd = {}
        for _, p in ipairs(crowdA) do crowd[#crowd + 1] = p end
        for _, p in ipairs(crowdB) do crowd[#crowd + 1] = p end
        local entries = {
            { id = 1, x = 0.5, y = 0 },
            { id = 2, x = 100.5, y = 0 },
            { id = 3, x = 1, y = 0 },
            { id = 4, x = 101, y = 0 },
        }
        local full = C.fullLook(entries, crowd)
        -- cada cluster de 6 → 1 full; tela ainda limita a 2
        local n = 0
        for _ in pairs(full) do n = n + 1 end
        assert(n == 2, "dois clusters × 1: " .. n)
        assert(full[1] and full[2])
        assert(not full[3] and not full[4])
    end,
}
