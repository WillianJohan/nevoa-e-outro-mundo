package.path = "mod/42/media/lua/shared/?.lua;mod/42/media/lua/server/?.lua;" .. package.path

local FILES = {
    "tests/test_smoke.lua",
    "tests/test_rules.lua",
    "tests/test_config.lua",
    "tests/test_climate_look.lua",
    "tests/test_eco_rules.lua",
    "tests/test_world.lua",
    "tests/test_eco.lua",
    "tests/test_eco_client.lua",
    "tests/test_night_rules.lua",
    "tests/test_night_stats.lua",
    "tests/test_night.lua",
    "tests/test_night_client.lua",
    "tests/test_variant_rules.lua",
    "tests/test_variant_ai.lua",
    "tests/test_variants_client.lua",
    "tests/test_variants.lua",
    "tests/test_semrosto_rules.lua",
    "tests/test_atmosphere_rules.lua",
    "tests/test_semrosto.lua",
    "tests/test_fog.lua",
    "tests/test_fog_client.lua",
    "tests/test_fog_sound.lua",
    "tests/test_fog_vignette.lua",
    "tests/test_fog_overlays.lua",
}

local pass, fail = 0, 0
for _, file in ipairs(FILES) do
    local tests = dofile(file)
    for name, fn in pairs(tests) do
        local ok, err = pcall(fn)
        if ok then
            pass = pass + 1
        else
            fail = fail + 1
            print("FAIL " .. file .. " :: " .. name .. "\n  " .. tostring(err))
        end
    end
end

print(string.format("total=%d passou=%d falhou=%d", pass + fail, pass, fail))
os.exit(fail == 0 and 0 or 1)
