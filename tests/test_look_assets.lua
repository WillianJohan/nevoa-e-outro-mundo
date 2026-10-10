-- Visual das variantes e do Eco (sprint 0012): os dados que o jogo junta sozinho.
-- * Item de script `ClothingItem = X` → OutfitManager acha `X` pela fileGuidTable
--   (ZomboidFileSystem.loadFileGuidTable junta a do mod, mergeFrom) → o XML em
--   media/clothing/clothingItems/X.xml.
-- * textureChoices/m_BaseTextures `A\B` → media/textures/A/B.png
--   (ModelInstanceTextureCreator: 'media/textures/\1.png'); pele → media/textures/Body/<nome>.png.
-- * Item que cai da cabeça só com ChanceToFall > 0 (IsoZombie.helmetFallFromVisuals):
--   item do mod não pode cair no chão.
-- * Tamanho da textura = o da textura vanilla que o modelo usa (só o tamanho é lido).
local MEDIA = "mod/42/media/"

local function read(path)
    local f = assert(io.open(path, "rb"), "não abriu " .. path)
    local s = f:read("*a")
    f:close()
    return s
end

-- largura e altura do PNG pelo cabeçalho IHDR (bytes 17–24, big endian)
local function pngSize(path)
    local s = read(path)
    assert(s:sub(2, 4) == "PNG", path .. " não é PNG")
    local function u32(i)
        local a, b, c, d = s:byte(i, i + 3)
        return ((a * 256 + b) * 256 + c) * 256 + d
    end
    return u32(17), u32(21)
end

local function items()
    local out = {}
    for name, body in read(MEDIA .. "scripts/NOM_clothing.txt"):gmatch("item%s+([%w_]+)%s*(%b{})") do
        out[name] = body
    end
    return out
end

local function guidTable()
    local out = {}
    for path, guid in read(MEDIA .. "fileGuidTable.xml"):gmatch("<path>([^<]+)</path>%s*<guid>([^<]+)</guid>") do
        out[guid] = path
    end
    return out
end

-- tamanho da textura vanilla que cada modelo usa (file(1) na textura do jogo)
local SIZE = {
    ["static\\clothes\\m_glasses_skigoggles"] = 128, -- SkiGoggles_White.png
    ["static\\clothes\\m_surgicalmask"] = 128,       -- Clothes/Hat/SurgicalMaskBlue.png
    ["skinned\\hair\\m_balaclavafull"] = 128,        -- Clothes/Hat/Balaclava_Full2.png
    ["skinned\\clothes\\m_weddingveil"] = 128,       -- Clothes/Hat/WeddingVeil.png
    [""] = 256,                                       -- camada no corpo: Dress_Textures/HospitalGown.png
    ["media\\models_X\\Skinned\\Clothes\\Bob_Hazmat.X"] = 256, -- Clothes/Hazmat/Hazmat_Yellow.png
    ["skinned\\clothes\\bob_boilersuit"] = 256,               -- Clothes/BolierSuit/Boilersuit_Grey.png
    ["skinned\\hair\\m_balaclavafull"] = 128,                 -- NOM_EmbrulhadaBalaclava (K2 caminho A)
    -- modelos nossos (scripts/gen_models.py, sprints 0041 e 0042): textura nossa, 128 como as outras peças
    ["static\\clothes\\NOM_M_EstaladorVenda"] = 128,
    ["static\\clothes\\NOM_M_CorredorBoca"] = 128,
    ["static\\clothes\\NOM_M_SemRostoEstatica"] = 128,
    ["static\\clothes\\NOM_M_CarpideiraCabelo"] = 128,
    ["static\\clothes\\NOM_M_CarpideiraCapuz"] = 128,
    ["static\\clothes\\NOM_M_CarpideiraLaco"] = 128,
    ["static\\clothes\\NOM_M_TicaoCrosta"] = 128,
}

-- Modelo nosso → arquivo no mod. O jogo monta media/models_x/<nome>.x e acha pelo
-- activeFileMap em minúsculas (FileTask_AbstractLoadModel + ZomboidFileSystem.getString,
-- pz-api-notes §32): o caminho tem que bater ignorando caixa.
local OWN_MODELS = {}
for _, piece in ipairs({ "EstaladorVenda", "CorredorBoca", "SemRostoEstatica", "CarpideiraCabelo",
    "CarpideiraCapuz", "CarpideiraLaco", "TicaoCrosta" }) do
    for _, sex in ipairs({ "M", "F" }) do
        OWN_MODELS["static\\clothes\\NOM_" .. sex .. "_" .. piece] = "models_X/Static/Clothes/NOM_" .. sex .. "_" .. piece .. ".x"
    end
end

-- Sprint 0018: gêmeo *Fx de cada peça com o shader do dissolve (a original fica sem,
-- pra opção desligada e pro shader que não compila) e a casca do Eco.
-- I1/I7: só gêmeos *Fx de peça com modelo (sem Manto/Roupa 2D).
local FX = {
    "NOM_EstaladorVenda", "NOM_CorredorBoca", "NOM_SemRostoEstatica", "NOM_CarpideiraCabelo",
    "NOM_CarpideiraCapuz", "NOM_CarpideiraLaco", "NOM_TicaoCrosta", "NOM_EcoVeu",
}
local HAZMAT = "/mnt/stuff/steam/steamapps/common/ProjectZomboid/projectzomboid/media/clothing/clothingItems/HazmatSuit.xml"

local function xmlOf(name) return read(MEDIA .. "clothing/clothingItems/" .. name .. ".xml") end
local function tag(xml, t) return xml:match("<" .. t .. ">([^<]*)</" .. t .. ">") end

return {
    look_assets_items_resolve = function()
        local guids = guidTable()
        local n = 0
        for name, body in pairs(items()) do
            n = n + 1
            assert(body:find("ItemType = base:clothing", 1, true), name .. " não é roupa")
            assert(not body:find("ChanceToFall", 1, true), name .. " pode cair da cabeça")
            local ci = body:match("ClothingItem = ([%w_]+)")
            assert(ci == name, name .. ": ClothingItem " .. tostring(ci))
            local xml = read(MEDIA .. "clothing/clothingItems/" .. ci .. ".xml")
            local guid = xml:match("<m_GUID>([^<]+)</m_GUID>")
            assert(guids[guid] == "media/clothing/clothingItems/" .. ci .. ".xml", ci .. ": GUID fora da fileGuidTable")
            local model = xml:match("<m_MaleModel>([^<]*)</m_MaleModel>")
            local tex = xml:match("<textureChoices>([^<]+)</textureChoices>") or xml:match("<m_BaseTextures>([^<]+)</m_BaseTextures>")
            assert(SIZE[model], ci .. ": modelo sem tamanho conhecido " .. tostring(model))
            local w, h = pngSize(MEDIA .. "textures/" .. tex:gsub("\\", "/") .. ".png")
            assert(w == SIZE[model] and h == SIZE[model], ci .. ": textura " .. w .. "x" .. h)
        end
        assert(n == 25, "esperava 25 itens (+BrasaCasca×2), achou " .. n)
    end,

    -- sprint 0041: modelo do mod (NOM_ no nome) existe no mod no caminho que o jogo monta
    look_assets_own_models_resolve = function()
        local n = 0
        for name in pairs(items()) do
            local xml = xmlOf(name)
            for _, t in ipairs({ "m_MaleModel", "m_FemaleModel" }) do
                local model = tag(xml, t)
                if model:find("NOM_", 1, true) then
                    n = n + 1
                    local file = OWN_MODELS[model]
                    assert(file, name .. ": modelo próprio sem arquivo conhecido " .. model)
                    local want = ("media/models_x/" .. model:gsub("\\", "/") .. ".x"):lower()
                    assert(("media/" .. file):lower() == want, name .. ": " .. file .. " não bate com " .. want)
                    assert(read(MEDIA .. file):sub(1, 16) == "xof 0303txt 0032", file .. " não é .x texto")
                end
            end
        end
        -- Capuz K2 caminho A = balaclava vanilla (não conta como modelo NOM_); 24 = 6×2×2.
        assert(n == 24, "esperava 6 peças e os gêmeos Fx nos dois sexos, achou " .. n)
    end,

    look_assets_guids_unique = function()
        local seen = {}
        for guid in read(MEDIA .. "fileGuidTable.xml"):gmatch("<guid>([^<]+)</guid>") do
            assert(not seen[guid], "GUID repetido " .. guid)
            seen[guid] = true
        end
    end,

    -- pele em uso (I7): só Tição; mesmo tamanho da pele vanilla (256)
    look_assets_skins = function()
        local w, h = pngSize(MEDIA .. "textures/Body/NOM_Ticao.png")
        assert(w == 256 and h == 256, "NOM_Ticao " .. w .. "x" .. h)
        for _, skin in ipairs({ "NOM_Estalador", "NOM_Corredor", "NOM_Carpideira", "NOM_SemRosto" }) do
            local f = io.open(MEDIA .. "textures/Body/" .. skin .. ".png", "rb")
            assert(f == nil, skin .. " morta ainda no repo (I7)")
            if f then f:close() end
        end
    end,

    look_assets_item_names = function()
        for _, lang in ipairs({ "EN", "PTBR" }) do
            local names = read(MEDIA .. "lua/shared/Translate/" .. lang .. "/ItemName.json")
            for name in pairs(items()) do
                assert(names:find('"Base.' .. name .. '"', 1, true), lang .. ": sem nome pra Base." .. name)
            end
        end
    end,

    -- rodar o gerador de novo não muda um byte das texturas do visual (semente fixa)
    look_assets_deterministic = function()
        local paths = { "textures/Body/NOM_Ticao.png" }
        for _, n in ipairs({ "EstaladorVenda", "CorredorBoca", "SemRostoEstatica", "SemRostoRosto",
            "CarpideiraCabelo", "CarpideiraManto", "CorredorRisco", "EcoCinza", "EcoVeu", "Brasa",
            "EmbrulhadaCasca" }) do
            paths[#paths + 1] = "textures/NOM/NOM_" .. n .. ".png"
        end
        local before = {}
        for _, p in ipairs(paths) do before[p] = read(MEDIA .. p) end
        local ok = os.execute("python3 scripts/gen_textures.py >/dev/null 2>&1")
        assert(ok == 0 or ok == true, "gen_textures.py falhou")
        for _, p in ipairs(paths) do assert(read(MEDIA .. p) == before[p], p .. " mudou ao regerar") end
    end,

    -- o Eco é spawnado com o outfit do mod: o visual dele é só dado (nada de Lua)
    look_assets_eco_outfit_uses_mod_items = function()
        local guids = guidTable()
        local n = 0
        for guid in read(MEDIA .. "clothing/clothing.xml"):gmatch("<itemGUID>([%x%-]+)</itemGUID>") do
            n = n + 1
            local path = guids[guid]
            assert(path and path:find("NOM_Eco", 1, true), "outfit NOM_Eco com item que não é do Eco: " .. guid)
        end
        assert(n == 4, "NOM_Eco feminino e masculino com 2 itens cada, achou " .. n)
    end,

    look_assets_fx_twins = function()
        local all = items()
        for _, name in ipairs(FX) do
            local a, b = xmlOf(name), xmlOf(name .. "Fx")
            assert(all[name .. "Fx"], name .. "Fx fora do script")
            assert(all[name .. "Fx"]:match("BodyLocation = ([%w:]+)") == all[name]:match("BodyLocation = ([%w:]+)"), name .. "Fx em outro lugar")
            assert(not tag(a, "m_Shader"), name .. " ganhou shader (a opção desligada perde o fallback)")
            assert(tag(b, "m_Shader") == "NOM_Dissolve", name .. "Fx sem o shader")
            for _, t in ipairs({ "m_MaleModel", "m_FemaleModel", "m_Static", "m_AttachBone", "textureChoices", "m_MasksFolder", "m_HatCategory" }) do
                assert(tag(a, t) == tag(b, t), name .. "Fx: " .. t .. " diferente")
            end
            assert(tag(a, "m_GUID") ~= tag(b, "m_GUID"))
        end
    end,

    -- a casca do Eco: a malha Hazmat vanilla com as mesmas máscaras do corpo do
    -- HazmatSuit.xml (o buraco da casca mostra o fundo, não a pele), cinza do mod, shader
    look_assets_eco_shell = function()
        local x = xmlOf("NOM_EcoCasca")
        assert(tag(x, "m_MaleModel") == "media\\models_X\\Skinned\\Clothes\\Bob_Hazmat.X")
        assert(tag(x, "m_FemaleModel") == "media\\models_X\\Skinned\\Clothes\\Kate_Hazmat.X")
        assert(tag(x, "m_Shader") == "NOM_Dissolve" and tag(x, "textureChoices") == "NOM\\NOM_EcoCinza")
        local masks = {}
        for m in x:gmatch("<m_Masks>(%d+)</m_Masks>") do masks[#masks + 1] = m end
        local f = io.open(HAZMAT, "rb")
        if f then
            local van = {}
            for m in f:read("*a"):gmatch("<m_Masks>(%d+)</m_Masks>") do van[#van + 1] = m end
            f:close()
            assert(table.concat(masks, ",") == table.concat(van, ","), "máscaras diferentes do HazmatSuit.xml")
        end
        assert(#masks == 14)
        assert(items().NOM_EcoCasca:find("BodyLocation = base:zeddmg", 1, true), "casca fora do zeddmg (expulsaria a cinza)")
    end,

    -- sprint 0022 / 0067: casca de brasa da mutação em BoilerSuit (sem hood Hazmat —
    -- hood empilhava na crosta e inflava a silhueta). SEM máscara (buraco mostra o monstro),
    -- shader dissolve, zeddmg multi-item, sem BloodLocation.
    look_assets_ember_shell = function()
        local x = xmlOf("NOM_Brasa")
        assert(tag(x, "m_MaleModel") == "skinned\\clothes\\bob_boilersuit",
            "mutação também BoilerSuit (sem hood)")
        assert(tag(x, "m_FemaleModel") == "skinned\\clothes\\kate_boilersuit")
        assert(tag(x, "m_Shader") == "NOM_Dissolve", "casca sem o shader")
        assert(tag(x, "textureChoices") == "NOM\\NOM_Brasa")
        assert(not x:find("<m_Masks>", 1, true), "máscara esconderia o monstro embaixo da casca")
        local body = items().NOM_Brasa
        assert(body, "NOM_Brasa fora do script")
        assert(body:find("BodyLocation = base:zeddmg", 1, true), "casca fora do zeddmg (expulsaria a peça)")
        assert(not body:find("BloodLocation", 1, true), "casca com BloodLocation viraria armadura")
        assert(not body:find("Defense", 1, true), "casca com defesa")
    end,

    -- 0067: casca permanente BoilerSuit + fissuras α + shader NOM_Brasa (+ gêmeo estático).
    look_assets_brasa_casca = function()
        local x = xmlOf("NOM_BrasaCasca")
        assert(tag(x, "m_MaleModel") == "skinned\\clothes\\bob_boilersuit")
        assert(tag(x, "m_FemaleModel") == "skinned\\clothes\\kate_boilersuit")
        assert(tag(x, "m_Shader") == "NOM_Brasa")
        assert(tag(x, "textureChoices") == "NOM\\NOM_BrasaCasca")
        local masks = {}
        for m in x:gmatch("<m_Masks>(%d+)</m_Masks>") do masks[#masks + 1] = m end
        assert(#masks == 14, "máscaras corpo: " .. #masks)
        local st = xmlOf("NOM_BrasaCascaStatic")
        assert(tag(st, "m_MaleModel") == "skinned\\clothes\\bob_boilersuit")
        assert(not st:find("<m_Shader>", 1, true), "estático não leva shader")
        assert(items().NOM_BrasaCasca:find("BodyLocation = base:zeddmg", 1, true))
        assert(items().NOM_BrasaCascaStatic:find("BodyLocation = base:zeddmg", 1, true))
        assert(io.open("mod/42/media/textures/NOM/NOM_BrasaCasca.png", "rb"), "textura casca")
        assert(io.open("mod/42/media/shaders/NOM_Brasa.frag", "r"), "frag")
        assert(io.open("mod/42/media/shaders/NOM_Brasa.vert", "r"), "vert")
        assert(io.open("mod/42/media/shaders/NOM_Brasa_static.vert", "r"), "static vert")
    end,

    -- 0064 K2 caminho A: balaclava vanilla + casca BoilerSuit com máscaras Hazmat (sem hood)
    look_assets_embrulhada_shell = function()
        local x = xmlOf("NOM_EmbrulhadaCasca")
        assert(tag(x, "m_MaleModel") == "skinned\\clothes\\bob_boilersuit",
            "corpo BoilerSuit (Hazmat hood = ovo)")
        assert(tag(x, "m_FemaleModel") == "skinned\\clothes\\kate_boilersuit")
        assert(tag(x, "textureChoices") == "NOM\\NOM_EmbrulhadaCasca")
        local masks = {}
        for m in x:gmatch("<m_Masks>(%d+)</m_Masks>") do masks[#masks + 1] = m end
        assert(#masks == 14, "máscaras corpo (como Hazmat): " .. #masks)
        assert(items().NOM_EmbrulhadaCasca:find("BodyLocation = base:zeddmg", 1, true))
        local cap = xmlOf("NOM_CarpideiraCapuz")
        assert(tag(cap, "m_MaleModel") == "skinned\\hair\\m_balaclavafull", "caminho A: balaclava")
        assert(tag(cap, "m_FemaleModel") == "skinned\\hair\\f_balaclavafull")
        assert(tag(cap, "m_Static") == "false", "balaclava é skinned, não static 3D")
        assert(tag(cap, "textureChoices") == "NOM\\NOM_EmbrulhadaBalaclava")
        assert(tag(cap, "m_HatCategory") == "nohairnobeard")
        assert(io.open("mod/42/media/textures/NOM/NOM_EmbrulhadaBalaclava.png", "rb"), "textura balaclava")
    end,
}
