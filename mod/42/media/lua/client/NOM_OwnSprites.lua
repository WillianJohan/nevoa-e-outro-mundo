-- Sprites próprios do Outro Mundo estilo Silent Hill (sprint 0035, Tarefa 4b): as texturas de
-- scripts/gen_tiles.py (shared/NOM_OwnSpriteList.lua) viram sprites de runtime, que o
-- client/NOM_FogOverlays.lua anexa pelo nome como os vanilla. Só no jogo de quem vê (ADR-017).
-- Spike: docs/sprints/sprint-0035-silent-hill/spike-sprite-proprio.md; pz-api-notes §26.
--
-- Por sprite (bytecode B42.21):
-- * getTexture(caminho) antes: caminho que não existe dá nil (Texture.getSharedTexture), e o
--   getSprite de um nome desconhecido CRIA um sprite vazio (pz-api-notes §16.2). Faltou: pula.
-- * getSprite(caminho) = IsoSpriteManager.getSprite: no namedMap, ou AddSprite (sprite novo, ID
--   20000000, LoadSingleTexture, namedMap; LuaManager$GlobalObject.getSprite 0–7,
--   IsoSpriteManager.AddSprite 0–26). O addAttachedAnimSpriteByName acha ele pelo namedMap.
-- * setName(caminho): o AddSprite não dá nome. Sem ele getParentSprite():getName() é nil e o
--   registro do NOM_FogOverlays nunca acha a instância que pôs (nem pra tirar antes do save).
-- * Flags (profundidade, spike §2): chão FloorOverlay (setupFloorDepth); parede WallOverlay +
--   attachedW ou attachedN (profundidade da parede pai, setupWallDepth do lado; o recorte da
--   parede de canto decide o lado por elas). props:set(IsoFlagType.X) como em
--   shared/Util/CustomTileProps.lua:333-338.
--
-- O namedMap é esvaziado a cada carga de mundo (IsoWorld.init 2182–2185): registra de novo no
-- OnGameStart (CustomTileProps.lua:318-341 mexe em sprite no mesmo evento) e, preguiçoso, antes
-- do primeiro anexo da sessão (NOM_FogOverlays). Na mesma sessão a chamada não vai ao Java.
-- O anexo que vazar pro save é descartado no load (ID 20000000 fora do intMap, spike §5).
if isServer() then return end

require "NOM_OwnSpriteList"

NOM_OwnSprites = {}

local S = NOM_OwnSprites
local done, ok, missing = false, 0, {}

local function flag(props, side)
    if side == "F" then
        props:set(IsoFlagType.FloorOverlay)
    else
        props:set(IsoFlagType.WallOverlay)
        props:set(side == "W" and IsoFlagType.attachedW or IsoFlagType.attachedN)
    end
end

-- Registra os sprites da lista (uma vez por sessão). Devolve quantos estão registrados.
function S.ensure()
    if done then return ok end
    done, ok, missing = true, 0, {}
    for _, s in ipairs(NOM_OwnSpriteList.SPRITES) do
        if getTexture(s.name) then
            local sprite = getSprite(s.name)
            sprite:setName(s.name)
            flag(sprite:getProperties(), s.side)
            ok = ok + 1
        else
            missing[#missing + 1] = s.name
        end
    end
    if #missing > 0 then
        print("[NOM] outro mundo: " .. #missing .. " texturas próprias faltando (ex.: " .. missing[1] .. ")")
    end
    return ok
end

function S.total()
    return #NOM_OwnSpriteList.SPRITES
end

-- Os caminhos sem textura na última vez que registrou (debug).
function S.missing()
    return missing
end

Events.OnGameStart.Add(function()
    done = false
    S.ensure()
end)
Events.OnMainMenuEnter.Add(function() done = false end) -- o mundo já se foi

return NOM_OwnSprites
