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
--
-- Dissolve (sprint 0018, ADR-016), com a opção do jogador ligada: a peça é o gêmeo *Fx
-- (o mesmo item com <m_Shader>NOM_Dissolve</m_Shader>), que se forma na mutação e se
-- desfaz no fim antes de sair da lista (client/NOM_Dissolve.lua dirige o Alpha). A pele
-- e a roupa trocam de uma vez, no começo da mutação e no fim do desfazer. Desligada:
-- peça sem shader e troca instantânea, como nas sprints 0012–0017.
--
-- Brasa no corpo inteiro (sprint 0022), com a sub-opção ligada e vaga
-- (client/NOM_EmberShell.lua): na mutação a peça é a SEM shader e uma casca de brasa cobre o
-- corpo e se desfaz revelando o monstro; na volta a casca se forma por cima, a troca vem no
-- fim dela e ela se desfaz revelando o zumbi comum. Brasas sobem no começo de cada uma.
-- Sem vaga de casca: o dissolve da peça (0018); sem vaga nenhuma: na hora.
if isServer() then return end

require "NOM_NightStats"
require "NOM_VariantRules"
require "NOM_Dissolve"
require "NOM_EmberShell"
require "NOM_ScreenFxRules"

-- Itens em media/scripts/NOM_clothing.txt; peles em media/textures/Body/.
-- Direção de arte: docs/gdd/art-direction.md.
NOM_VariantLook = {
    LOOKS = {
        -- Sprint 0060b: NÃO troca Body (UNKNOWN/RGB → manequim P&B no playtest). Peça de
        -- cabeça + roupa vanilla do corpo. Roupa NOM_*Roupa da 0060 fica fora do look.
        estalador = { item = "Base.NOM_EstaladorVenda", fx = "Base.NOM_EstaladorVendaFx" },
        corredor = { item = "Base.NOM_CorredorBoca", fx = "Base.NOM_CorredorBocaFx" },
        semrosto = { item = "Base.NOM_SemRostoEstatica", fx = "Base.NOM_SemRostoEstaticaFx" },
        -- Carpideira: manto hospitalar do mod no corpo (caminho Eco/Gown); sem pele Body.
        carpideira = {
            item = "Base.NOM_CarpideiraCabelo", fx = "Base.NOM_CarpideiraCabeloFx",
            body = "Base.NOM_CarpideiraManto", bodyFx = "Base.NOM_CarpideiraMantoFx",
        },
        -- Tição: ainda usa pele carvão (preta); se falhar no playtest, sai no próximo lote.
        ticao = { skin = "NOM_Ticao", item = "Base.NOM_TicaoCrosta", fx = "Base.NOM_TicaoCrostaFx" },
    },
    -- 0060b: roupa do CORPO fica (camisa/calça/…). Só some acessório de cabeça que tapa a
    -- peça do monstro. Feridas ZedDmg_/Wound_ sempre. Itens %.NOM_ sempre.
    KEEP = { "^Base%.ZedDmg_", "^Base%.Wound_" },
    -- Padrões de tipo vanilla que SOMEM na variante (chapéu/máscara/óculos).
    STRIP_HEAD = {
        "Hat_", "Glasses_", "Balaclava", "Bandana", "Scarf", "WeddingVeil",
        "Mask", "MakeUp_", "Nose", "Earrings", "EarRing",
    },
    -- 0060c: com LookForce, prova no print — camisa esportiva colorida + calça branca.
    PROOF_BODY = { "Base.Tshirt_Sport", "Base.Trousers_WhiteTEXTURE" },
    -- Tipos de corpo que a prova substitui (pra não empilhar tshirt+shirt).
    PROOF_STRIP = { "Tshirt_", "Shirt_", "Trousers_", "Skirt_", "Dress_", "Shorts_" },
}

local LOOKS = NOM_VariantLook.LOOKS
local KEEP = NOM_VariantLook.KEEP
local STRIP_HEAD = NOM_VariantLook.STRIP_HEAD
local PROOF_BODY = NOM_VariantLook.PROOF_BODY
local PROOF_STRIP = NOM_VariantLook.PROOF_STRIP
-- [zumbi] = { kind, id, item, iv, all, leaving, proof }: só o que este processo pôs (all = a
-- lista de ItemVisual original, na ordem, quando alguma roupa foi escondida; leaving = a
-- peça está se desfazendo e o strip vem no fim do efeito; proof = camisa/calça do look limpo).
-- A tabela evita qualquer chamada Java quando nada muda. Só em memória: nada disto vai pro save.
local worn = {}

local function keep(t)
    if t == nil or t:find("%.NOM_") then return true end -- item do mod (módulo.NOM_*)
    for _, p in ipairs(KEEP) do
        if t:find(p) then return true end
    end
    -- 0060b: corpo vestido; só tira acessório de cabeça que compete com a peça do monstro
    for _, p in ipairs(STRIP_HEAD) do
        if t:find(p, 1, true) then return false end
    end
    return true
end

local function isProofStrip(t)
    if t == nil or t:find("%.NOM_") then return false end
    for _, p in ipairs(PROOF_STRIP) do
        if t:find(p, 1, true) then return true end
    end
    return false
end

-- Esconde acessórios de cabeça vanilla (não a roupa do corpo). ItemVisual sem flag de
-- esconder (§14.4): sai da lista e a original fica guardada.
local function hide(list, w)
    local all, gone = {}, {}
    for i = 0, list:size() - 1 do
        local iv = list:get(i)
        if iv ~= w.iv and iv ~= w.bodyIv then
            all[#all + 1] = iv
            if not keep(iv:getItemType()) then gone[#gone + 1] = iv end
        end
    end
    if #gone == 0 then return end
    w.all = all
    for _, iv in ipairs(gone) do list:remove(iv) end
end

-- 0060c LookForce: troca camisa/calça por vanilla colorida (prova legível no print).
-- Carpideira com manto: só calça (o manto já é o torso).
local function proofBody(list, w)
    if not NOM_ScreenFxRules.lookClean() then return end
    if not w.all then
        local all = {}
        for i = 0, list:size() - 1 do
            local iv = list:get(i)
            if iv ~= w.iv and iv ~= w.bodyIv then all[#all + 1] = iv end
        end
        w.all = all
    end
    local gone = {}
    for i = 0, list:size() - 1 do
        local iv = list:get(i)
        if iv ~= w.iv and iv ~= w.bodyIv and isProofStrip(iv:getItemType()) then
            gone[#gone + 1] = iv
        end
    end
    for _, iv in ipairs(gone) do list:remove(iv) end
    w.proof = {}
    for _, typ in ipairs(PROOF_BODY) do
        if w.body and typ:find("Tshirt_", 1, true) then
            -- manto no torso: não empilha camisa
        else
            local iv = ItemVisual.new()
            iv:setItemType(typ)
            list:add(iv)
            w.proof[#w.proof + 1] = iv
        end
    end
end

-- Chapéu caído: PersistentOutfits.setFallenHat liga o bit 0x8000 do persistentOutfitID
-- (isHatFallen(I) testa esse bit). O baseId tira o bit; se tirou, estava ligado. Aqui o
-- ID cru: o bit é o que se quer ler (o sorteio e o worn.id usam o ID sem ele).
local function hatFallen(id)
    return id ~= nil and NOM_VariantRules.baseId(id) ~= id
end

-- Devolve a lista original, na ordem. Se a peça do mod já não está lá, o jogo vestiu
-- de novo (dressInPersistentOutfitID limpa a lista) e a lista nova é a verdade.
-- Cliente de MP: o servidor derruba o chapéu (ZombieHelmetFallingPacket.processClient
-- 130–238 não acha o escondido, mas cria a roupa caindo e liga o bit). Com o bit ligado,
-- o que tem ChanceToFall > 0 não volta, como o PersistentOutfits.removeFallenHat faz
-- (18–92) ao vestir.
local function unhide(z, list, w)
    if not list:remove(w.iv) then return end
    if w.bodyIv then list:remove(w.bodyIv) end
    if not w.all then return end
    local fallen = hatFallen(z:getPersistentOutfitID())
    for _, iv in ipairs(w.all) do list:remove(iv) end -- os que ficaram à mostra
    for _, iv in ipairs(w.all) do
        local item = fallen and iv:getScriptItem()
        if not (item and item:getChanceToFall() > 0) then list:add(iv) end
    end
end

-- Zumbi ainda não vestido (longe da tela): o ModelManager veste pelo ID na criação do
-- modelo e dressInPersistentOutfitID limpa pele e lista. Pinta na próxima passada.
-- Jogador reanimado: o ReanimatedPlayers salva o zumbi (IsoZombie.save →
-- HumanVisual.save, com o skinTextureName); a pele do mod iria pro save.
-- A marca vem antes de tocar no zumbi: se a API falhar no meio, o fim da névoa tira.
local function put(z, kind, id)
    if not z:isPersistentOutfitInit() or z:isReanimatedPlayer() then return end
    local look = LOOKS[kind]
    local fx = NOM_Dissolve.enabled()
    local shell = fx and NOM_EmberShell.can(z)
    local w = { kind = kind, id = id, item = (fx and not shell) and look.fx or look.item }
    if look.body then
        w.body = (fx and not shell and look.bodyFx) and look.bodyFx or look.body
    end
    worn[z] = w
    -- a casca de uma volta que ainda queima sai antes do hide (não pode virar roupa
    -- guardada); o efeito dela segue e o reveal abaixo continua do limiar em que estava
    NOM_EmberShell.remove(z)
    if look.skin then z:getHumanVisual():setSkinTextureName(look.skin) end
    local iv = ItemVisual.new()
    iv:setItemType(w.item)
    local list = z:getItemVisuals()
    list:add(iv)
    w.iv = iv
    -- Corpo (sprint 0052): segundo ItemVisual; KEEP já deixa %.NOM_ à mostra.
    if w.body then
        local biv = ItemVisual.new()
        biv:setItemType(w.body)
        list:add(biv)
        w.bodyIv = biv
    end
    hide(list, w)
    proofBody(list, w)
    z:resetModelNextFrame()
    if shell then
        if NOM_EmberShell.reveal(z) then NOM_EmberShell.burst(z) end
    elseif fx then
        NOM_Dissolve.run(z, "in") -- no teto, a peça já vem inteira
    end
end

local function strip(z)
    local w = worn[z]
    if not w then return end
    worn[z] = nil
    NOM_Dissolve.stop(z)
    NOM_EmberShell.remove(z)
    local list = z:getItemVisuals()
    if w.proof then
        for _, iv in ipairs(w.proof) do list:remove(iv) end
    end
    if w.iv then unhide(z, list, w) end -- remove(Object): os objetos que este processo tirou e pôs
    if LOOKS[w.kind].skin then z:getHumanVisual():setSkinTextureName(nil) end
    z:resetModelNextFrame()
    return w
end

-- Fim da variante: com o gêmeo, desfaz a peça e só tira no fim do efeito; com a peça sem
-- shader e vaga de casca, a casca se forma e a troca vem no fim dela (o strip tira a casca
-- e o reveal a veste de novo pra desfazer). Os efeitos nascem nos lotes da passada (BATCH
-- por tick) e duram o mesmo tempo: os strips do fim continuam espalhados. Sem efeito
-- (desligado, teto): na hora.
local function leave(z)
    local w = worn[z]
    if w.leaving then return end
    local function done(x)
        if worn[x] == w and w.leaving then strip(x) end
    end
    if w.item == LOOKS[w.kind].item and NOM_EmberShell.can(z) then
        local function swap(x)
            if worn[x] == w and w.leaving then
                strip(x)
                NOM_EmberShell.reveal(x)
            end
        end
        if NOM_EmberShell.cover(z, swap) then
            w.leaving = true
            NOM_EmberShell.burst(z)
            return
        end
    end
    if w.item == LOOKS[w.kind].fx and NOM_Dissolve.run(z, "out", done) then
        w.leaving = true
        return
    end
    strip(z)
end

-- kind: variante na névoa ou nil (comum, Eco, fora da névoa). id: o
-- persistentOutfitID que deu a variante (o NightStats já leu): o jogo vestir de novo
-- com outro ID apaga a pele e a lista, e aí pinta de novo.
function NOM_VariantLook.sync(z, kind, id)
    local w = worn[z]
    if w and w.kind == kind and w.id == id then
        if w.leaving then -- voltou antes de sumir: do limiar em que estava
            w.leaving = nil
            if NOM_EmberShell.has(z) then
                NOM_EmberShell.reveal(z) -- a casca que se formava se desfaz de novo
            elseif not NOM_Dissolve.run(z, "in") then
                NOM_Dissolve.stop(z) -- a peça se forma de novo
            end
        elseif NOM_ScreenFxRules.lookClean() and not w.proof then
            -- LookForce ligado depois da mutação: aplica prova colorida sem re-strip
            proofBody(z:getItemVisuals(), w)
            z:resetModelNextFrame()
        end
        return
    end
    if not w and kind == nil then return end
    if w and kind == nil then return leave(z) end
    strip(z)
    if kind and LOOKS[kind] then put(z, kind, id) end
end

-- Pro status do debug: só os zumbis carregados nesta tela. Quem saiu do mundo fica na
-- tabela até ser reaproveitado ou morrer, e ninguém o desenha.
function NOM_VariantLook.count()
    local list = getCell():getZombieList()
    local n = 0
    for i = 0, list:size() - 1 do
        if worn[list:get(i)] then n = n + 1 end
    end
    return n
end

-- 0060b: prova runtime — pele e ItemVisuals do zumbi mais perto (ou o passado).
function NOM_VariantLook.inspect(z)
    if not z then
        local p = getPlayer()
        if not p then return "sem jogador" end
        local best, bestD
        local list = getCell():getZombieList()
        for i = 0, list:size() - 1 do
            local cand = list:get(i)
            local d = cand:DistToProper(p)
            if not bestD or d < bestD then best, bestD = cand, d end
        end
        z = best
    end
    if not z then return "sem zumbi" end
    local hv = z:getHumanVisual()
    local skin = hv and hv:getSkinTexture() or nil
    local w = worn[z]
    local kinds = w and w.kind or "-"
    local parts = {}
    local list = z:getItemVisuals()
    for i = 0, list:size() - 1 do
        parts[#parts + 1] = tostring(list:get(i):getItemType())
    end
    return string.format("kind=%s skin=%s items=%s", kinds, tostring(skin), table.concat(parts, ","))
end

-- Morte. Solo (IsoZombie.onKilled 38–52): o DoZombieInventory já fez vestidos e
-- inventário da lista escondida (só a peça do mod e o que ficou à mostra) antes do
-- OnZombieDead, e o corpo copia pele, WornItems e inventário depois. Devolve a lista e
-- refaz só a parte vestida pelo próprio WornItems, como o DoZombieInventory faz
-- (setFromItemVisuals + addItemsToItemContainer): o loot fica o do zumbi vanilla. Chamar
-- o DoZombieInventory de novo perderia os itemsToSpawnAtDeath (ele limpa a lista).
-- A peça do mod no inventário é a prova de que o DoZombieInventory rodou: no fogo
-- (FireCheck: OnZombieDead sem inventário) e no cliente de MP (vestidos e inventário
-- vêm do servidor, que nunca pinta) só a lista e a pele voltam.
-- WornItems e ItemContainer.Remove são locais (o removeWornItem do personagem manda
-- SyncClothing no cliente de MP).
local function dead(z)
    local w = worn[z]
    if not w then return end
    local inv = z:getInventory()
    local ran = inv:FindAndReturn(w.item)
    strip(z)
    if not ran then return end
    local wi = z:getWornItems()
    for i = 0, wi:size() - 1 do inv:Remove(wi:get(i):getItem()) end
    wi:setFromItemVisuals(z:getItemVisuals())
    wi:addItemsToItemContainer(inv)
end

NOM_NightStats.look = NOM_VariantLook.sync
-- Objeto reaproveitado (resetForReuse → OnZombieCreate): o jogo limpa a pele e só
-- veste de novo quando cria o modelo; a peça sai agora.
Events.OnZombieCreate.Add(strip)
Events.OnZombieDead.Add(dead)
-- Fim da névoa: a passada do NightStats, que a borda acorda, chama o gancho com nil em
-- cada zumbi, BATCH por tick (sprint 0016): devolver todo mundo no mesmo tick refazia
-- todos os modelos de uma vez. Quem saiu da lista sai da tabela quando o objeto for
-- reaproveitado (OnZombieCreate) ou morrer; até lá ninguém o desenha.

return NOM_VariantLook
