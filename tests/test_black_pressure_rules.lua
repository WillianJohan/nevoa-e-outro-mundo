-- Pressão da névoa preta (sprint 0051): perfis Leve / Padrão / Pesadelo.
require "NOM_BlackPressureRules"

local R = NOM_BlackPressureRules

return {
    -- 1..3; fora da faixa vira Padrão ou prende no limite
    black_pressure_level_clamp = function()
        assert(R.level(nil) == R.PADRAO)
        assert(R.level(0) == R.LEVE and R.level(1) == R.LEVE)
        assert(R.level(2) == R.PADRAO and R.level(2.9) == R.PADRAO)
        assert(R.level(3) == R.PESADELO and R.level(99) == R.PESADELO)
    end,
    -- Padrão aperta mais que Leve; Pesadelo aperta mais que Padrão; nunca corredor
    black_pressure_profiles_tighten = function()
        local a, b, c = R.profile(R.LEVE), R.profile(R.PADRAO), R.profile(R.PESADELO)
        assert(a.flickerCheckMs > b.flickerCheckMs and b.flickerCheckMs > c.flickerCheckMs)
        assert(a.flickerChance < b.flickerChance and b.flickerChance < c.flickerChance)
        assert(a.flickerMinMs <= b.flickerMinMs and b.flickerMinMs <= c.flickerMinMs)
        assert(a.holdMs > b.holdMs and b.holdMs > c.holdMs)
        assert(a.huntMinutes > b.huntMinutes and b.huntMinutes > c.huntMinutes)
        assert(b.huntOnFlickerReach > 0 and c.huntOnFlickerReach >= b.huntOnFlickerReach)
        assert(a.huntOnFlickerReach == 0, "Leve sem caça no piscar")
        assert(a.fastBias == 0.5 and b.fastBias == 0.5)
        assert(c.fastBias > 0.5 and c.fastBias < 1, "Pesadelo mais rápido, sem 100%")
        assert(b.holdMs < b.flickerMinMs, "Tição solto pelo flicker não congela de novo no mesmo apagão")
        -- postes: na preta o Pesadelo apaga mais / por mais tempo
        assert(a.lampCheckMs >= b.lampCheckMs and b.lampCheckMs >= c.lampCheckMs)
        assert(a.lampChance <= b.lampChance and b.lampChance <= c.lampChance)
        assert(a.lampDarkMaxMs <= b.lampDarkMaxMs and b.lampDarkMaxMs <= c.lampDarkMaxMs)
    end,
    -- current() lê o sandbox; default = Padrão
    black_pressure_current_from_config = function()
        require "NOM_Config"
        SandboxVars = nil
        local p = R.current()
        assert(p.huntMinutes == R.profile(R.PADRAO).huntMinutes)
        SandboxVars = { NevoaEOutroMundo = { BlackFogPressure = 3 } }
        assert(R.current().fastBias == R.profile(R.PESADELO).fastBias)
        SandboxVars = { NevoaEOutroMundo = { BlackFogPressure = 1 } }
        assert(R.current().huntOnFlickerReach == 0)
        SandboxVars = nil
    end,
    -- identidade: nenhum perfil inventa horda / velocidade de corredor
    black_pressure_keeps_black_identity = function()
        for _, lv in ipairs({ R.LEVE, R.PADRAO, R.PESADELO }) do
            local p = R.profile(lv)
            assert(p.fastBias < 1, "corredor disfarçado no nível " .. lv)
            assert(p.huntReach >= 20 and p.huntReach <= 60)
            assert(p.visionTiles == nil or p.visionTiles == 3)
        end
    end,
}
