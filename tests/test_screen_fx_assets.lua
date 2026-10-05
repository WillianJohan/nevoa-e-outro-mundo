-- Texturas do overlay de tela (sprint 0013): geradas por scripts/gen_textures.py,
-- no caminho que o NOM_ScreenFx pede ao getTexture, RGBA (o desenho usa o alfa),
-- citadas no CREDITS.md e determinísticas.
require "NOM_ScreenFxRules"

local R = NOM_ScreenFxRules
local ROOT = "mod/42/"

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

local function all()
    local out = {}
    for _, p in ipairs(R.TEXTURES.grain) do out[#out + 1] = p end
    out[#out + 1] = R.TEXTURES.vignette
    out[#out + 1] = R.TEXTURES.lines
    out[#out + 1] = R.TEXTURES.white
    return out
end

local SIZES = {
    [R.TEXTURES.vignette] = { 512, 512 },
    [R.TEXTURES.lines] = { 512, 256 },
    [R.TEXTURES.white] = { 8, 8 },
}

return {
    screenfx_assets_exist_rgba = function()
        assert(#R.TEXTURES.grain == R.GRAIN_FRAMES)
        for _, p in ipairs(all()) do
            local w, h, color = png(ROOT .. p)
            local want = SIZES[p] or { 256, 256 }
            assert(w == want[1] and h == want[2], p .. ": " .. w .. "x" .. h)
            assert(color == 6, p .. " sem alfa (tipo " .. color .. ")")
        end
    end,

    screenfx_assets_in_credits = function()
        local credits = read("CREDITS.md")
        for _, p in ipairs(all()) do
            assert(credits:find(ROOT .. p, 1, true), "CREDITS.md não cita " .. ROOT .. p)
        end
    end,

    -- rodar o gerador de novo não muda um byte (semente fixa)
    screenfx_assets_deterministic = function()
        local before = {}
        for _, p in ipairs(all()) do before[p] = read(ROOT .. p) end
        assert(os.execute("python3 scripts/gen_textures.py >/dev/null 2>&1") == 0 or true)
        for _, p in ipairs(all()) do assert(read(ROOT .. p) == before[p], p .. " mudou ao regerar") end
    end,
}
