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

-- largura, altura e bytes de um PNG (cabeçalho IHDR)
local function png(path)
    local f = assert(io.open(path, "rb"), "falta " .. path)
    local data = f:read("*a")
    f:close()
    assert(data:sub(2, 4) == "PNG", path .. " não é PNG")
    local function u32(i) return data:byte(i) * 16777216 + data:byte(i + 1) * 65536 + data:byte(i + 2) * 256 + data:byte(i + 3) end
    return u32(17), u32(21), data
end

return {
    -- invertido: todo arquivo do mod que não é código/texto/script precisa de origem
    credits_every_asset_listed = function()
        local TEXT = { lua = true, txt = true, xml = true, json = true, info = true }
        local files = find("find mod mod2 docs/workshop docs/art -type f")
        for _, path in ipairs(find("find mod3/42 -maxdepth 1 -name '*.png'")) do files[#files + 1] = path end
        local n = 0
        for _, path in ipairs(files) do
            local ext = path:match("%.(%w+)$")
            local name = path:match("[^/]+$")
            local isText = (path:find("^mod/") or path:find("^mod2/")) and (TEXT[ext] or name == ".gitkeep")
            if not isText and not path:find("%.txt$") then
                n = n + 1
                assert(listed(path), "CREDITS.md não cita " .. path)
            end
        end
        assert(n >= 8, "esperava sons e imagens, achou " .. n)
    end,

    credits_generators_exist = function()
        for _, script in ipairs({ "scripts/gen_sounds.py", "scripts/gen_images.py", "scripts/gen_textures.py", "scripts/gen_tiles.py" }) do
            assert(io.open(script, "r"), "falta " .. script)
            assert(listed(script), "CREDITS.md não cita " .. script)
        end
    end,

    -- outfit do Eco (itens do mod desde a sprint 0012) e modelos vanilla citados por
    -- nome nos itens de roupa do mod: tudo na tabela do CREDITS.md
    credits_clothing_listed = function()
        local n = 0
        for guid in read("mod/42/media/clothing/clothing.xml"):gmatch("<itemGUID>([%x%-]+)</itemGUID>") do
            n = n + 1
            assert(listed(guid), "CREDITS.md não cita o GUID " .. guid)
        end
        assert(n > 0)
        local models = 0
        for _, path in ipairs(find("find mod/42/media/clothing/clothingItems -name '*.xml'")) do
            local xml = read(path)
            for tag in ("m_MaleModel m_FemaleModel"):gmatch("%S+") do
                local model = xml:match("<" .. tag .. ">([^<]+)</" .. tag .. ">")
                if model then
                    models = models + 1
                    assert(listed(model), "CREDITS.md não cita o modelo " .. model .. " (" .. path .. ")")
                end
            end
        end
        assert(models > 0)
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

    -- Arte de lançamento do Johan (sprint 0037b, ADR-019): fontes reduzidas em docs/art/, finais gerados
    -- pelo scripts/gen_images.py. As de staging ficam fora de mod*/42/ (o repo e o build usam só as oficiais).
    launch_art_images = function()
        for _, m in ipairs({ "mod", "mod2", "mod3" }) do
            local w, h = png(m .. "/42/poster.png")
            assert(w == 512 and h == 512, m .. ": pôster não é 512")
            w, h = png(m .. "/42/icon.png")
            assert(w == 64 and h == 64, m .. ": ícone não é 64")
        end
        assert(select(3, png("mod3/42/poster.png")) == select(3, png("mod2/42/poster.png")), "mod3 sem o pôster do mod2")
        assert(select(3, png("mod3/42/icon.png")) == select(3, png("mod2/42/icon.png")), "mod3 sem o ícone do mod2")
        -- SteamWorkshopItem.validatePreviewImage: PNG quadrado de 256 ou 512, < 1 024 000 bytes
        local w, h, data = png("docs/workshop/preview.png")
        assert(w == 512 and h == 512 and #data < 1024000, "preview do Workshop")
        for _, name in ipairs({ "NOM_Post.png", "NOM_Preview_Cinza.png", "NOM_Preview_Vermelha.png", "NOM_Icon.png" }) do
            w, h = png("docs/art/" .. name)
            assert(w == h and w <= 1024, "docs/art/" .. name .. " grande demais")
        end
        w = png("docs/art/NOM_Banner.png")
        assert(w <= 1600, "banner grande demais")
        local sw, sh, poster = png("docs/art/staging/poster.png")
        assert(sw == 512 and sh == 512, "pôster de staging")
        local iw, ih, icon = png("docs/art/staging/icon.png")
        assert(iw == 64 and ih == 64, "ícone de staging")
        for _, m in ipairs({ "mod", "mod2", "mod3" }) do
            assert(select(3, png(m .. "/42/poster.png")) ~= poster, m .. " com o pôster de staging")
            assert(select(3, png(m .. "/42/icon.png")) ~= icon, m .. " com o ícone de staging")
        end
        -- o ícone de staging é o oficial avermelhado: vermelho bem acima do verde e do azul
        local ok = os.execute("python3 -c \"import sys; from PIL import Image, ImageStat; "
            .. "r, g, b = ImageStat.Stat(Image.open('docs/art/staging/icon.png').convert('RGB')).mean; "
            .. "sys.exit(0 if r > 1.6 * g and r > 1.6 * b else 1)\"")
        assert(ok == 0 or ok == true, "ícone de staging não é avermelhado")
        assert(listed("Johan"), "CREDITS.md sem a arte de lançamento do Johan")
    end,

    -- "NOM: Noise of Mist" (sprint 0037b): IDs, nomes e dependências dos três mods do item.
    -- Os nomes de espaço no Lua (canal, ModData, opções) continuam NevoaEOutroMundo.
    modinfo_ids_and_names = function()
        local WANT = {
            { "mod", "NoiseOfMist", "NOM: Noise of Mist", nil },
            { "mod2", "NoiseOfMist_Shader", "NOM: Noise of Mist — Shader (incompatível com ShadowZ)", "NoiseOfMist" },
            { "mod3", "NoiseOfMist_Volumetrica", "NOM: Noise of Mist — Volumétrica (Java, ZombieBuddy)",
                "NoiseOfMist,\\ZombieBuddy" },
        }
        for _, w in ipairs(WANT) do
            local info = read(w[1] .. "/42/mod.info")
            assert(info:find("\nid=" .. w[2] .. "\n", 1, true), w[1] .. ": id= errado")
            assert(info:match("^name=([^\n]+)") == w[3], w[1] .. ": name= errado")
            assert(info:match("\nrequire=([^\n]+)") == w[4], w[1] .. ": require= errado")
            assert(not info:find("Névoa e Outro Mundo", 1, true), w[1] .. ": nome antigo no mod.info")
        end
        assert(read("mod3/42/mod.info"):find("\njavaJarFile=media/java/client/NoiseOfMist_Volumetrica.jar\n", 1, true),
            "mod3: javaJarFile= errado")
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
