-- Lista das texturas próprias do Outro Mundo (sprint 0035, Tarefa 4a): shared/NOM_OwnSpriteList.lua,
-- escrita pelo scripts/gen_tiles.py. O nome do sprite é o caminho do PNG (o mesmo do getTexture,
-- spike-sprite-proprio.md §1b). A lista tem de bater com os arquivos: nada citado que não exista,
-- nenhum PNG sem entrada, lado e tipo de acordo com o nome. Os pixels são conferidos em
-- tests/test_om_tiles.py.
local ROOT = "mod/42/"
local FILE = ROOT .. "media/lua/shared/NOM_OwnSpriteList.lua"
local DIR = "media/textures/NOM/OutroMundo/"
local KINDS = {
    F = { Grade = true, Ferrugem = true, Chapa = true, Tinta = true, Cinza = true, Brasa = true, Tentaculo = true },
    W = { Tinta = true, Ferrugem = true, Descasca = true, Fuligem = true, Tentaculo = true },
    N = { Tinta = true, Ferrugem = true, Descasca = true, Fuligem = true, Tentaculo = true },
}

local function read(path)
    local f = assert(io.open(path, "rb"), "falta " .. path)
    local s = f:read("*a")
    f:close()
    return s
end

-- IHDR: largura, altura e tipo de cor (6 = RGBA)
local function png(path)
    local s = read(path)
    assert(s:sub(2, 4) == "PNG", path .. " não é PNG")
    local function u32(i) return s:byte(i) * 16777216 + s:byte(i + 1) * 65536 + s:byte(i + 2) * 256 + s:byte(i + 3) end
    return u32(17), u32(21), s:byte(26)
end

-- carrega o arquivo num ambiente vazio: lógica pura, nenhum global do jogo nem do Lua
local function load()
    local env = {}
    local chunk = assert(loadfile(FILE))
    setfenv(chunk, env)
    local ret = chunk()
    return ret, env
end

local function onDisk()
    local out = {}
    local p = io.popen("find " .. ROOT .. DIR .. " -name '*.png'")
    for line in p:lines() do out[line:sub(#ROOT + 1)] = true end
    p:close()
    return out
end

return {
    own_sprite_list_pure = function()
        local ret, env = load()
        assert(ret == env.NOM_OwnSpriteList, "o arquivo não devolve NOM_OwnSpriteList")
        for k in pairs(env) do
            assert(k == "NOM_OwnSpriteList", "global a mais no arquivo: " .. tostring(k))
        end
        assert(ret.DIR == DIR, "DIR = " .. tostring(ret.DIR))
    end,

    own_sprite_list_matches_files = function()
        local L = load()
        local disk, seen = onDisk(), {}
        assert(#L.SPRITES > 0, "lista vazia")
        for _, s in ipairs(L.SPRITES) do
            assert(not seen[s.name], "repetido: " .. s.name)
            seen[s.name] = true
            assert(disk[s.name], "na lista e sem arquivo: " .. s.name)
            local w, h, color = png(ROOT .. s.name)
            assert(w == 128 and h == 256 and color == 6, s.name .. ": " .. w .. "x" .. h .. " tipo " .. color)
        end
        for name in pairs(disk) do
            assert(seen[name], "PNG sem entrada na lista: " .. name)
        end
    end,

    own_sprite_list_side_and_kind = function()
        local L = load()
        local count = {}
        for _, s in ipairs(L.SPRITES) do
            local kind, side, n = s.name:match("^" .. DIR:gsub("%p", "%%%0") .. "NOM_OM_(%a+)_([FWN])_(%d%d)%.png$")
            assert(kind, "nome fora do padrão: " .. s.name)
            assert(s.side == side and s.kind == kind, s.name .. ": lado/tipo " .. tostring(s.side) .. "/" .. tostring(s.kind))
            assert(KINDS[side][kind], "tipo " .. kind .. " não existe no lado " .. side)
            local key = kind .. "_" .. side
            count[key] = (count[key] or 0) + 1
            assert(tonumber(n) == count[key], s.name .. ": numeração fora de ordem")
        end
        for side, kinds in pairs(KINDS) do
            for kind in pairs(kinds) do
                local c = count[kind .. "_" .. side] or 0
                assert(c >= 4 and c <= 6, kind .. "_" .. side .. ": " .. c .. " variações (4 a 6)")
            end
        end
    end,
}
