-- Visual das variantes da névoa (sprint 0012, ADR-012): pele e uma peça por cima
-- enquanto a névoa dura, em toda cópia local do zumbi (solo: o processo; MP: cada
-- cliente, dona ou remota). Nada vai pela rede nem pro save, e o outfit não muda
-- (a variante sai do persistentOutfitID, ADR-006).
--
-- Como (bytecode, pz-api-notes §14):
-- * pele: HumanVisual.setSkinTextureName(nome) → media/textures/Body/<nome>.png
--   (getSkinTexture devolve o nome quando há; zumbi normal tem nil, então tirar é nil);
-- * peça: ItemVisual.new() + setItemType na lista getItemVisuals() (ArrayList), e
--   resetModelNextFrame() refaz o modelo, como o tutorial vanilla faz no zumbi
--   (client/Tutorial/Steps.lua:832-838);
-- * ZombiePacket leva só outfitId e skinTextureIndex: nada disto viaja.
-- Quem decide a variante é o NOM_NightStats, na passada em lotes: ele chama o
-- gancho NOM_NightStats.look(z, kind) instalado aqui.
if isServer() then return end

require "NOM_NightStats"
require "NOM_FogState"

-- Itens em media/scripts/NOM_clothing.txt; peles em media/textures/Body/.
-- Direção de arte: docs/gdd/art-direction.md.
NOM_VariantLook = {
    LOOKS = {
        estalador = { skin = "NOM_Estalador", item = "Base.NOM_EstaladorVenda" },
        corredor = { skin = "NOM_Corredor", item = "Base.NOM_CorredorBoca" },
        semrosto = { item = "Base.NOM_SemRostoEstatica" },
        carpideira = { skin = "NOM_Carpideira", item = "Base.NOM_CarpideiraCabelo" },
    },
}

local LOOKS = NOM_VariantLook.LOOKS
-- [zumbi] = { kind, iv, item }: só o que este processo pôs. A tabela evita
-- qualquer chamada Java quando nada muda.
local worn = {}

-- Zumbi ainda não vestido (longe da tela): o ModelManager veste pelo ID na criação do
-- modelo e dressInPersistentOutfitID limpa pele e lista. Pinta na próxima passada.
-- Jogador reanimado: o ReanimatedPlayers salva o zumbi (IsoZombie.save →
-- HumanVisual.save, com o skinTextureName); a pele do mod iria pro save.
-- A marca vem antes de tocar no zumbi: se a API falhar no meio, o fim da névoa tira.
local function put(z, kind, id)
    if not z:isPersistentOutfitInit() or z:isReanimatedPlayer() then return end
    local look = LOOKS[kind]
    local w = { kind = kind, id = id, item = look.item }
    worn[z] = w
    if look.skin then z:getHumanVisual():setSkinTextureName(look.skin) end
    local iv = ItemVisual.new()
    iv:setItemType(look.item)
    z:getItemVisuals():add(iv)
    w.iv = iv
    z:resetModelNextFrame()
end

local function strip(z)
    local w = worn[z]
    if not w then return end
    worn[z] = nil
    if w.iv then z:getItemVisuals():remove(w.iv) end -- remove(Object): o objeto que este processo pôs
    if LOOKS[w.kind].skin then z:getHumanVisual():setSkinTextureName(nil) end
    z:resetModelNextFrame()
    return w
end

-- kind: variante na névoa ou nil (comum, Eco, fora da névoa). id: o
-- persistentOutfitID que deu a variante (o NightStats já leu): o jogo vestir de novo
-- com outro ID apaga a pele e a lista, e aí pinta de novo.
function NOM_VariantLook.sync(z, kind, id)
    local w = worn[z]
    if w and w.kind == kind and w.id == id then return end
    if not w and kind == nil then return end
    strip(z)
    if kind and LOOKS[kind] then put(z, kind, id) end
end

function NOM_VariantLook.count()
    local n = 0
    for _ in pairs(worn) do n = n + 1 end
    return n
end

-- Morte: o DoZombieInventory já fez item vestido e no inventário a partir da lista
-- (IsoZombie.onKilled 45 → OnZombieDead 52), e o corpo copia pele, WornItems e
-- inventário depois. Tira tudo antes: nada de loot nem de pele no save.
-- WornItems.remove e ItemContainer.Remove são locais (o removeWornItem do personagem
-- manda SyncClothing no cliente de MP).
local function dead(z)
    local w = strip(z)
    if not w then return end
    local inv = z:getInventory()
    local item = inv:FindAndReturn(w.item)
    if item then
        z:getWornItems():remove(item)
        inv:Remove(item)
    end
end

NOM_NightStats.look = NOM_VariantLook.sync
-- Objeto reaproveitado (resetForReuse → OnZombieCreate): o jogo limpa a pele e só
-- veste de novo quando cria o modelo; a peça sai agora.
Events.OnZombieCreate.Add(strip)
Events.OnZombieDead.Add(dead)
-- Fim da névoa: tudo sai na borda (o Sem-rosto não tem stats e a passada de dia
-- não volta nele).
NOM_FogState.onChange(function(on)
    if on then return end
    for z in pairs(worn) do strip(z) end
end)

return NOM_VariantLook
