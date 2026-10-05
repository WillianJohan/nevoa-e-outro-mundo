-- Todo asset do mod tem origem no CREDITS.md: gerado por script nosso ou
-- vanilla referenciado por nome/GUID. E o mod.info aponta pra imagens que existem.

local function read(path)
    local f = assert(io.open(path, "r"), "não abriu " .. path)
    local s = f:read("*a")
    f:close()
    return s
end

local function find(cmd)
    local out = {}
    local p = io.popen(cmd)
    for l in p:lines() do out[#out + 1] = l end
    p:close()
    return out
end

local CREDITS = read("CREDITS.md")

local function listed(text) return CREDITS:find(text, 1, true) ~= nil end

return {
    credits_every_binary_asset_listed = function()
        local files = find("find mod docs/workshop -type f \\( -name '*.png' -o -name '*.ogg' -o -name '*.wav' \\)")
        assert(#files >= 8, "esperava sons e imagens, achou " .. #files)
        for _, path in ipairs(files) do assert(listed(path), "CREDITS.md não cita " .. path) end
    end,

    credits_generators_exist = function()
        for _, script in ipairs({ "scripts/gen_sounds.py", "scripts/gen_images.py" }) do
            assert(io.open(script, "r"), "falta " .. script)
            assert(listed(script), "CREDITS.md não cita " .. script)
        end
    end,

    credits_vanilla_guids_listed = function()
        local n = 0
        for guid in read("mod/42/media/clothing/clothing.xml"):gmatch("<itemGUID>([%x%-]+)</itemGUID>") do
            n = n + 1
            assert(listed(guid), "CREDITS.md não cita o GUID vanilla " .. guid)
        end
        assert(n > 0)
    end,

    -- ChooseGameInfo.readModInfoAux: poster=/icon= resolvem em 42/ (e caem em common/)
    credits_modinfo_assets_exist = function()
        local info = read("mod/42/mod.info")
        local poster, icon = info:match("\nposter=([^\n]+)"), info:match("\nicon=([^\n]+)")
        assert(poster and icon, "mod.info sem poster= ou icon=")
        assert(io.open("mod/42/" .. poster, "r"), "falta mod/42/" .. poster)
        assert(io.open("mod/42/" .. icon, "r"), "falta mod/42/" .. icon)
        assert(info:find("\nurl=https://github.com/WillianJohan/nevoa-e-outro-mundo\n", 1, true), "url= errada")
        assert(info:find("\nversionMin=42.20\n", 1, true), "versionMin= errada")
    end,

    -- readModInfoAux casa cada linha por contains, numa cadeia if/else nesta ordem
    -- (bytecode 152–1325): linha cujo valor contém uma chave anterior vira essa chave
    modinfo_lines_match_own_key = function()
        local ORDER = { "name=", "poster=", "description=", "require=", "incompatible=", "loadModAfter=",
            "loadModBefore=", "id=", "author=", "modversion=", "icon=", "category=", "url=", "pack=",
            "type=", "tiledef=", "versionMax=", "versionMin=" }
        for line in read("mod/42/mod.info"):gmatch("[^\n]+") do
            local own = line:match("^(%w+=)")
            assert(own, "linha sem chave: " .. line)
            for _, key in ipairs(ORDER) do
                if line:find(key, 1, true) then
                    assert(key == own, "o jogo lê '" .. line .. "' como " .. key)
                    break
                end
            end
        end
    end,
}
