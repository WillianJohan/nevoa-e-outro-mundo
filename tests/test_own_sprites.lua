-- client/NOM_OwnSprites.lua (sprint 0035, Tarefa 4b): registra as texturas próprias do Outro
-- Mundo como sprites de runtime. Contra o namedMap falso de tests/attached_world.lua, que imita o
-- B42.21 (spike-sprite-proprio §1b, §2, §5): getSprite de nome novo cria sprite SEM nome e SEM
-- flags (ID 20000000), getTexture de caminho que não existe é nil, o namedMap zera a cada mundo.
local W = dofile("tests/fog_world.lua")
local A = dofile("tests/attached_world.lua")
local FILE = "mod/42/media/lua/client/NOM_OwnSprites.lua"

local function setup(opts)
    opts = opts or {}
    local G = W.new(opts)
    G.reload({ "NOM_OwnSpriteList" })
    A.install(G)
    require "NOM_OwnSpriteList"
    G.printed = {}
    local realPrint = print
    G.restore = function() print = realPrint end
    print = function(s) G.printed[#G.printed + 1] = tostring(s) end
    local ok, err = pcall(dofile, FILE)
    if not ok then
        G.restore()
        error(err, 0)
    end
    return G
end

local function run(G, fn)
    local ok, err = pcall(fn)
    G.restore()
    assert(ok, err)
end

local L = function() return NOM_OwnSpriteList end

local function flagsOf(s)
    local out = {}
    for f in pairs(s.flags) do out[#out + 1] = f end
    table.sort(out)
    return table.concat(out, ",")
end

local WANT = { F = "FloorOverlay", W = "WallOverlay,attachedW", N = "WallOverlay,attachedN" }

return {
    -- cada PNG da lista vira sprite com o nome dele (sem o setName, getParentSprite():getName()
    -- é nil e o mod nunca acha o que pôs) e a flag do lado (profundidade, spike §2)
    own_sprites_ensure_names_and_flags = function()
        local G = setup()
        run(G, function()
            local n = NOM_OwnSprites.ensure()
            assert(n == #L().SPRITES, "registrados " .. tostring(n) .. " de " .. #L().SPRITES)
            for _, s in ipairs(L().SPRITES) do
                local sp = G.sprites[s.name]
                assert(sp and sp.runtime, "sem sprite: " .. s.name)
                assert(sp.name == s.name, "sem setName: " .. s.name)
                assert(sp.texture, "sprite vazio: " .. s.name)
                assert(flagsOf(sp) == WANT[s.side], s.name .. " com " .. flagsOf(sp) .. ", pede " .. WANT[s.side])
            end
            assert(#G.printed == 0, "logou sem faltar nada: " .. table.concat(G.printed, "\n"))
        end)
    end,

    -- barato: a segunda chamada na mesma sessão não vai ao Java
    own_sprites_ensure_once_per_session = function()
        local G = setup()
        run(G, function()
            NOM_OwnSprites.ensure()
            local j = G.java
            for _ = 1, 100 do NOM_OwnSprites.ensure() end
            assert(G.java == j, "ensure repetido foi ao Java: " .. G.java - j)
        end)
    end,

    -- o namedMap zera a cada mundo (IsoWorld.init → IsoSpriteManager.Dispose): voltar ao menu e
    -- carregar outro jogo registra de novo no OnGameStart
    own_sprites_new_world_registers_again = function()
        local G = setup()
        run(G, function()
            G.fire("OnGameStart")
            assert(G.sprites[L().SPRITES[1].name], "OnGameStart não registrou")
            G.fire("OnMainMenuEnter")
            G.sprites = {} -- mundo novo: namedMap vazio
            G.fire("OnGameStart")
            for _, s in ipairs(L().SPRITES) do
                assert(G.sprites[s.name] and G.sprites[s.name].name == s.name, "mundo novo sem: " .. s.name)
            end
            -- e sem o OnMainMenuEnter (MP: conectar de novo), o OnGameStart sozinho também
            G.sprites = {}
            G.fire("OnGameStart")
            assert(G.sprites[L().SPRITES[1].name], "OnGameStart sem menu não registrou")
        end)
    end,

    -- PNG que falta (getTexture nil): pula, sem criar sprite vazio no namedMap (getSprite de
    -- nome que não existe cria um, invisível), e loga uma vez por sessão
    own_sprites_missing_texture_skipped = function()
        local G = setup()
        run(G, function()
            local gone = { L().SPRITES[1].name, L().SPRITES[#L().SPRITES].name }
            for _, n in ipairs(gone) do G.missingTex[n] = true end
            local n = NOM_OwnSprites.ensure()
            assert(n == #L().SPRITES - 2, "registrados " .. n)
            for _, g in ipairs(gone) do assert(G.sprites[g] == nil, "sprite vazio criado: " .. g) end
            NOM_OwnSprites.ensure()
            assert(#G.printed == 1, "logs: " .. #G.printed .. "\n" .. table.concat(G.printed, "\n"))
            assert(G.printed[1]:find("^%[NOM%]") and G.printed[1]:find("2", 1, true), G.printed[1])
            local missing = NOM_OwnSprites.missing()
            assert(#missing == 2 and missing[1] == gone[1], "missing()")
            assert(NOM_OwnSprites.total() == #L().SPRITES)
        end)
    end,

    -- servidor dedicado: nada (o Outro Mundo é visual do cliente, ADR-017)
    own_sprites_inert_on_dedicated = function()
        local G = setup({ server = true })
        run(G, function()
            assert(NOM_OwnSprites == nil and G.handlers.OnGameStart == nil, "carregou no dedicado")
        end)
    end,
}
