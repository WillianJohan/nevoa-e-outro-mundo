-- Sangue e ferrugem no chão durante a névoa, só na tela de quem vê (solo e
-- cliente de MP). Cada jogador vê o próprio pesadelo.
--
-- IsoMarkers e nada mais (pz-api-notes §5): getIsoMarkers():addIsoMarker(nome,
-- square, r, g, b, a) guarda o marcador numa lista Java em memória (a classe não
-- tem save/load), não manda pacote e volta nil no servidor; não mexe no square
-- nem nos objetos do mapa. Uso vanilla: client/Foraging/ISBaseIcon.lua:577.
-- Sangue de verdade (addBloodSplat) é salvo no chunk: proibido aqui.
if isServer() then return end

require "NOM_Config"
require "NOM_FogState"
require "NOM_AtmosphereRules"

NOM_FogOverlays = {
    SPAWN_MS = 1500, -- uma mancha nova a cada 1,5 s real
    MAX = 40,
    MIN_R = 3,       -- tiles do jogador
    MAX_R = 12,
    DROP_R = 20,     -- mais longe que isso, some
    ALPHA = 0.8,
    FADE_MS = 6000,  -- surgir e sumir
    UPDATE_TICKS = 10,
}

local O = NOM_FogOverlays
-- Sprites vanilla de overlay de chão, por nome (media/tileDepthTextureAssignments.txt).
local BLOOD = { "overlay_blood_floor_01_", 27 }
local RUST = { "overlay_grime_floor_01_", 95 }
local RUST_TINT = { 0.75, 0.45, 0.3 } -- sujeira cinza puxada pra ferrugem

local sprites -- { { name, tint } }, só os que o jogo acha (lazy: texturas carregam depois do Lua)
local marks = {} -- { m, x, y, z, a }
local taken = {} -- "x,y,z" = true
local nextSpawn, lastMs

local function loadSprites()
    sprites = {}
    for _, set in ipairs({ { BLOOD, { 1, 1, 1 } }, { RUST, RUST_TINT } }) do
        local prefix, last = set[1][1], set[1][2]
        for i = 0, last do
            local name = prefix .. i
            -- IsoMarker.init acha a textura com Texture.trygetTexture(nome);
            -- getTexture = Texture.getSharedTexture (LuaManager.GlobalObject)
            if getTexture(name) then sprites[#sprites + 1] = { name = name, tint = set[2] } end
        end
    end
    if #sprites == 0 and getDebug() then print("[NOM] overlays: nenhum sprite encontrado") end
end

local function key(x, y, z) return x .. "," .. y .. "," .. z end

local function spawn(p)
    if not sprites then loadSprites() end
    if #sprites == 0 then return end
    local a = math.rad(ZombRand(360))
    local r = O.MIN_R + ZombRand(O.MAX_R - O.MIN_R + 1)
    local x = math.floor(p:getX() + r * math.cos(a))
    local y = math.floor(p:getY() + r * math.sin(a))
    local z = math.floor(p:getZ())
    local k = key(x, y, z)
    if taken[k] then return end
    local sq = getCell():getGridSquare(x, y, z)
    -- isFree(false): client/ISUI/ISWorldObjectContextMenu.lua:2199
    if not sq or not sq:isFree(false) then return end
    local s = sprites[ZombRand(#sprites) + 1]
    local m = getIsoMarkers():addIsoMarker(s.name, sq, s.tint[1], s.tint[2], s.tint[3], 0)
    if not m then return end
    taken[k] = true
    marks[#marks + 1] = { m = m, x = x, y = y, z = z, a = 0, k = k }
end

local function update()
    local now = getTimestampMs()
    local dt = lastMs and now - lastMs or 0
    lastMs = now
    local p = getPlayer()
    local on = NOM_FogState.on and NOM_Config.get("FogOverlays") and p ~= nil and not p:isDead()
    local fade = O.FADE_MS / O.ALPHA -- approach anda 1 por fadeMs
    for i = #marks, 1, -1 do
        local mk = marks[i]
        local near = on and mk.z == math.floor(p:getZ())
            and math.abs(mk.x - p:getX()) <= O.DROP_R and math.abs(mk.y - p:getY()) <= O.DROP_R
        local target = near and O.ALPHA or 0
        mk.a = NOM_AtmosphereRules.approach(mk.a, target, dt, fade)
        if mk.a <= 0 and target == 0 then
            mk.m:remove()
            taken[mk.k] = nil
            table.remove(marks, i)
        else
            mk.m:setAlpha(mk.a)
        end
    end
    if not on then
        nextSpawn = nil
        return
    end
    nextSpawn = nextSpawn or now
    if now >= nextSpawn and #marks < O.MAX then
        spawn(p)
        nextSpawn = now + O.SPAWN_MS
    end
end

local ticks = 0
Events.OnTick.Add(function()
    ticks = ticks + 1
    if ticks < O.UPDATE_TICKS then return end
    ticks = 0
    update()
end)

return NOM_FogOverlays
