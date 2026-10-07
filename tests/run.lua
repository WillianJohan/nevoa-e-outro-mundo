local print = print -- teste que captura o print global não engole o relatório
package.path = "mod/42/media/lua/shared/?.lua;mod/42/media/lua/server/?.lua;mod/42/media/lua/client/?.lua;" .. package.path

local FILES = {
    "tests/test_smoke.lua",
    "tests/test_kahlua_compat.lua",
    "tests/test_script_comments.lua",
    "tests/test_math.lua",
    "tests/test_dissolve_rules.lua",
    "tests/test_ember_rules.lua",
    "tests/test_dissolve.lua",
    "tests/test_dissolve_shader.lua",
    "tests/test_eco_fx.lua",
    "tests/test_rules.lua",
    "tests/test_ticao_rules.lua",
    "tests/test_light_rules.lua",
    "tests/test_flicker_rules.lua",
    "tests/test_ticao_light.lua",
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
    "tests/test_carpideira_rules.lua",
    "tests/test_variant_ai.lua",
    "tests/test_wander_rules.lua",
    "tests/test_wander.lua",
    "tests/test_sonar_rules.lua",
    "tests/test_sonar.lua",
    "tests/test_sonar_fx.lua",
    "tests/test_mod3_sonar.lua",
    "tests/test_mod3_light.lua",
    "tests/test_mod3_censor.lua",
    "tests/test_carpideira.lua",
    "tests/test_variants_client.lua",
    "tests/test_variants.lua",
    "tests/test_semrosto_rules.lua",
    "tests/test_atmosphere_rules.lua",
    "tests/test_screen_fx_rules.lua",
    "tests/test_screen_fx_assets.lua",
    "tests/test_screen_fx_options.lua",
    "tests/test_fog_quality_sync.lua",
    "tests/test_screen_fx.lua",
    "tests/test_shader.lua",
    "tests/test_semrosto.lua",
    "tests/test_fog.lua",
    "tests/test_fog_event.lua",
    "tests/test_siren_spots_rules.lua",
    "tests/test_siren.lua",
    "tests/test_siren_freeze.lua",
    "tests/test_fog_client.lua",
    "tests/test_fog_sound.lua",
    "tests/test_device_rules.lua",
    "tests/test_devices.lua",
    "tests/test_fog_vignette.lua",
    "tests/test_dressing_rules.lua",
    "tests/test_own_sprites.lua",
    "tests/test_fog_overlays.lua",
    "tests/test_flake_rules.lua",
    "tests/test_flakes.lua",
    "tests/test_night_and_fog.lua",
    "tests/test_fog_event_rules.lua",
    "tests/test_debug_rules.lua",
    "tests/test_debug.lua",
    "tests/test_debug_panel.lua",
    "tests/test_translations.lua",
    "tests/test_credits.lua",
    "tests/test_own_sprite_list.lua",
    "tests/test_look_assets.lua",
    "tests/test_variant_look.lua",
}

local pass, fail = 0, 0
-- luajit tests/run.lua [trecho]: só os arquivos com o trecho no nome
local only = arg and arg[1]
for _, file in ipairs(FILES) do
    local tests = (not only or file:find(only, 1, true)) and dofile(file) or {}
    for name, fn in pairs(tests) do
        NOM_ShaderMod = nil -- flag do mod do shader (mod2): só quem testa liga
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
