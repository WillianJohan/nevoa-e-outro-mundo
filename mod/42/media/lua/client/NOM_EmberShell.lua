-- Casca de brasa (sprint 0022, emenda da ADR-016), só no jogo de quem vê (solo e cliente de
-- MP): na mutação e na volta da variante o corpo inteiro queima. O corpo é sempre
-- basicEffect (sem Java), então a técnica é a da casca do Eco (sprint 0018) no zumbi VIVO: um
-- ItemVisual Base.NOM_Brasa (malha Hazmat vanilla sem máscara, carvão e brasa, shader
-- NOM_Dissolve) entra na lista getItemVisuals() por ~1 s e o client/NOM_Dissolve.lua dirige o
-- Alpha. Quem decide quando é o client/NOM_VariantLook.lua:
-- * mutação: o monstro já está embaixo; reveal desfaz a casca ("out") e a tira no fim;
-- * volta: cover forma a casca ("in"); no fim o VariantLook troca embaixo e chama reveal.
-- Todo item com shader no zumbi lê o MESMO Alpha: com casca, a peça da variante é a sem
-- shader (a 0018 a formaria ao mesmo tempo que a casca some).
--
-- Por que é seguro (bytecode B42.21, pz-api-notes §17.5):
-- * a lista de ItemVisual do zumbi vivo é local: ZombiePacket.set leva só outfitId e
--   skinTextureIndex, e IsoZombie.save (só do ReanimatedPlayers) não a escreve; nunca em
--   jogador reanimado (o VariantLook não pinta quem tem isReanimatedPlayer);
-- * nada vai pro inventário enquanto vivo; na morte no solo o DoZombieInventory faz item e
--   loot de toda a lista ANTES do OnZombieDead: a morte aqui tira a casca da lista, do
--   WornItems e do inventário (o VariantLook refaz o resto do loot, sprint 0016);
-- * base:zeddmg é multi-item: a casca não expulsa nada no WornItems.setItem; sem
--   BloodLocation nem defesa, getBodyPartClothingDefense e o som de armadura a pulam.
if isServer() then return end

require "NOM_DissolveRules"
require "NOM_Dissolve"
require "NOM_Embers"
require "NOM_ScreenFxOptions"
-- NOM_BrasaLook é carregado depois; yieldForShell é opcional (pcall-safe via nil check)

NOM_EmberShell = { ITEM = "Base.NOM_Brasa" }

local S = NOM_EmberShell
local R = NOM_DissolveRules
-- [zumbi] = o ItemVisual que este processo pôs. Só em memória.
local shells = {}
local count = 0

function S.has(z)
    return shells[z] ~= nil
end

function S.count()
    return count
end

-- À vista do jogador 0: o alvo do alfa que a visão dá (IsoObject.getTargetAlpha(I) 0–14; o
-- mundo anda o alfa até ele). Fora da vista, nem casca (não prende vaga) nem brasa: o overlay
-- desenha na tela sem saber de parede nem de visão e revelaria o zumbi. O overlay das brasas
-- é só do jogador 0, como o resto da 0013.
local function seen(z)
    return z:getTargetAlpha(0) > 0
end

-- Pode usar a casca agora: opção ligada e (já tem uma, ou está à vista e há vaga nas cascas
-- e no dissolve).
function S.can(z)
    if not NOM_ScreenFxOptions.bodyEmbers() then return false end
    if shells[z] then return true end
    return count < R.SHELL_CAP and (NOM_Dissolve.busy(z) or NOM_Dissolve.count() < R.CAP) and seen(z)
end

local function wear(z)
    if shells[z] then return end
    -- 0067: casca permanente BoilerSuit não pode empilhar com a da mutação
    if NOM_BrasaLook and NOM_BrasaLook.yieldForShell then
        NOM_BrasaLook.yieldForShell(z)
    end
    local iv = ItemVisual.new()
    iv:setItemType(S.ITEM)
    z:getItemVisuals():add(iv)
    shells[z] = iv
    count = count + 1
    z:resetModelNextFrame()
end

-- Tira da lista (o objeto que este processo pôs). Não mexe no efeito do dissolve.
function S.remove(z)
    local iv = shells[z]
    if not iv then return end
    shells[z] = nil
    count = count - 1
    z:getItemVisuals():remove(iv)
    z:resetModelNextFrame()
end

-- Veste (se ainda não tem) e desfaz; tira no fim. false: sem vaga (nada vestido).
function S.reveal(z)
    wear(z)
    if NOM_Dissolve.run(z, "out", S.remove) then return true end
    S.remove(z)
    return false
end

-- Veste e forma; done(z) no fim (a troca embaixo da casca). false: sem vaga.
function S.cover(z, done)
    wear(z)
    if NOM_Dissolve.run(z, "in", done) then return true end
    S.remove(z)
    return false
end

-- Brasas no pé do zumbi à vista, no começo de uma transição (o NOM_Embers tem o teto dele).
function S.burst(z)
    if seen(z) then NOM_Embers.burst(z:getX(), z:getY(), z:getZ()) end
end

-- Morte com a casca (no meio da mutação ou depois da troca da volta). No solo o
-- DoZombieInventory já fez da casca um item vestido e do inventário; no fogo e no cliente
-- de MP não há item dela. WornItems.remove e ItemContainer.Remove são locais.
local function dead(z)
    if not shells[z] then return end
    NOM_Dissolve.stop(z)
    S.remove(z)
    local inv = z:getInventory()
    local it = inv:FindAndReturn(S.ITEM)
    if it then
        inv:Remove(it)
        z:getWornItems():remove(it)
    end
end

-- Objeto reaproveitado (resetForReuse → OnZombieCreate): a lista só é limpa quando o jogo
-- veste de novo; a casca sai agora.
Events.OnZombieCreate.Add(S.remove)
Events.OnZombieDead.Add(dead)
Events.OnMainMenuEnter.Add(function()
    shells = {}
    count = 0
end)

return NOM_EmberShell
