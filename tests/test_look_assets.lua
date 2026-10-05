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
}

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
        assert(n == 6, "esperava 6 itens, achou " .. n)
    end,

    look_assets_guids_unique = function()
        local seen = {}
        for guid in read(MEDIA .. "fileGuidTable.xml"):gmatch("<guid>([^<]+)</guid>") do
            assert(not seen[guid], "GUID repetido " .. guid)
            seen[guid] = true
        end
    end,

    -- pele: mesmo tamanho da pele de zumbi vanilla (Body/M_ZedBody01_level1.png, 256)
    look_assets_skins = function()
        for _, skin in ipairs({ "NOM_Estalador", "NOM_Corredor", "NOM_Carpideira" }) do
            local w, h = pngSize(MEDIA .. "textures/Body/" .. skin .. ".png")
            assert(w == 256 and h == 256, skin .. " " .. w .. "x" .. h)
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
}
