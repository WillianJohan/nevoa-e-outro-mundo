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
require "NOM_VariantWardrobe"
require "NOM_SemRostoFace"
require "NOM_SemRostoCap"
require "NOM_Math"
require "NOM_Dissolve"
require "NOM_EmberShell"
require "NOM_ScreenFxRules"

-- Itens em media/scripts/NOM_clothing.txt; peles em media/textures/Body/.
-- Direção de arte: bíblia look (store) + docs/gdd/art-direction.md.
NOM_VariantLook = {
    LOOKS = {
        -- 0060f lote A: peça de cabeça + guarda-roupa vanilla por variante (C1).
        estalador = { item = "Base.NOM_EstaladorVenda", fx = "Base.NOM_EstaladorVendaFx" },
        -- Corredor: boca 3D + risco claro N4 (NOM_CorredorRisco) sobre tronco escuro.
        corredor = {
            item = "Base.NOM_CorredorBoca", fx = "Base.NOM_CorredorBocaFx",
            body = "Base.NOM_CorredorRisco",
        },
        -- 0060f A′: remendo 2D no rosto (sem casca-ovo). Censor via ModData NOM_semrosto.
        semrosto = { item = NOM_SemRostoFace.ITEM },
        -- Screamer (carpideira): mechas (K1) ou capuz via wardrobe.headItem (K2 Embrulhada).
        -- body/manto ainda no LOOKS pra K futuras que queiram keepBody; K1/K2 tiram.
        carpideira = {
            item = "Base.NOM_CarpideiraCabelo", fx = "Base.NOM_CarpideiraCabeloFx",
            body = "Base.NOM_CarpideiraManto",
        },
        -- I5: pele carvão lisa (gen_textures); crosta 3D leva a brasa.
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
    -- 0060c: só no look limpo (debug) — camisa esportiva + calça branca pra provar no print.
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

-- Bíblia §7.3: teto visual — excedentes Sem-rosto usam F1+S5 (gameplay intacto).
local function semrostoCapped(z, id)
    local cell = getCell and getCell()
    if not cell or not cell.getZombieList then return false end
    local zlist = cell:getZombieList()
    if not zlist then return false end
    local entries, crowd = {}, {}
    local seen = {}
    for i = 0, zlist:size() - 1 do
        local o = zlist:get(i)
        if o and (not o.isAlive or o:isAlive()) then
            local x, y = o:getX(), o:getY()
            crowd[#crowd + 1] = { x = x, y = y }
            local oid = 0
            if o.getPersistentOutfitID then oid = o:getPersistentOutfitID() or 0 end
            oid = NOM_VariantRules.baseId(oid)
            local w = worn[o]
            local marked = false
            if o.hasModData and o:hasModData() then
                marked = o:getModData().NOM_semrosto
            end
            if o == z or (w and w.kind == "semrosto") or marked then
                if oid and oid ~= 0 and not seen[oid] then
                    seen[oid] = true
                    entries[#entries + 1] = { id = oid, x = x, y = y }
                end
            end
        end
    end
    if not seen[id] then
        entries[#entries + 1] = { id = id, x = z:getX(), y = z:getY() }
    end
    local full = NOM_SemRostoCap.fullLook(entries, crowd)
    return NOM_SemRostoCap.isCapped(id, full)
end

-- Lava / carboniza a roupa que já está na lista (S5, Tição keepOwn).
local function treatOwnClothes(list, w, variant)
    if not list or not variant then return end
    for i = 0, list:size() - 1 do
        local iv = list:get(i)
        if iv and iv ~= w.iv and iv ~= w.bodyIv then
            local t = iv:getItemType()
            if t and not t:find("%.NOM_", 1, true) then
                if variant.wash and iv.setDirt and BloodBodyPartType then
                    for _, partName in ipairs({ "Torso_Upper", "Torso_Lower", "UpperArm_L", "UpperArm_R",
                        "UpperLeg_L", "UpperLeg_R", "LowerLeg_L", "LowerLeg_R" }) do
                        local part = BloodBodyPartType[partName]
                        if part then
                            iv:setDirt(part, 0)
                            if iv.setBlood then iv:setBlood(part, 0) end
                        end
                    end
                end
                if variant.charcoal and ImmutableColor and ImmutableColor.new and iv.setTint then
                    local c = variant.charcoal
                    iv:setTint(ImmutableColor.new(c[1], c[2], c[3], 1))
                end
                if variant.holes and BloodBodyPartType and iv.setHole then
                    for hi = 1, #variant.holes do
                        local part = BloodBodyPartType[variant.holes[hi]]
                        if part then iv:setHole(part) end
                    end
                end
                if variant.dirt then
                    NOM_VariantWardrobe.treat(iv, {}, variant)
                end
            end
        end
    end
end

-- Casca NOM_Brasa órfã (dissolve parado / mid-reveal) lê como almofada branca/rosa.
local function stripOrphanBrasa(list, w)
    if not list then return end
    local gone = {}
    for i = 0, list:size() - 1 do
        local iv = list:get(i)
        if iv and iv:getItemType() == "Base.NOM_Brasa" then
            if not (NOM_EmberShell.has and NOM_EmberShell.has(w and w._z)) then
                gone[#gone + 1] = iv
            end
        end
    end
    for _, iv in ipairs(gone) do list:remove(iv) end
end

-- Guarda-roupa da variante (lote A/2): tira slot conflitante, põe peças vanilla + tratamento.
-- Sem-rosto capped: força S5 (roupa própria lavada). NOM_wardForce: índice debug sticky.
local function applyWardrobe(list, w, id)
    local variant, idx
    local forceIdx = w.forceWardIdx
    if not forceIdx and w._z and w._z.hasModData and w._z:hasModData() then
        forceIdx = w._z:getModData().NOM_wardForce
    end
    if w.kind == "semrosto" and w.capped then
        local cat = NOM_VariantWardrobe.CATALOG.semrosto
        if cat then
            for i = 1, #cat do
                if cat[i].id == "S5" then variant, idx = cat[i], i break end
            end
        end
        if not variant then return end
    elseif forceIdx then
        local cat = NOM_VariantWardrobe.CATALOG[w.kind]
        idx = math.floor(tonumber(forceIdx) or 1)
        if cat and cat[idx] then variant = cat[idx] else variant, idx = NOM_VariantWardrobe.pick(w.kind, id) end
    else
        variant, idx = NOM_VariantWardrobe.pick(w.kind, id)
    end
    if not variant then return end
    w.wardVar = variant.id
    w.wardIdx = idx
    stripOrphanBrasa(list, w)
    if variant.keepOwn then
        treatOwnClothes(list, w, variant)
        if not variant.pieces or #variant.pieces == 0 then return end
    end
    if not w.all then
        local all = {}
        for i = 0, list:size() - 1 do
            local iv = list:get(i)
            if iv ~= w.iv and iv ~= w.bodyIv then all[#all + 1] = iv end
        end
        w.all = all
    end
    local gone = {}
    local patterns = variant.strip
    for i = 0, list:size() - 1 do
        local iv = list:get(i)
        local t = iv and iv:getItemType()
        if iv ~= w.iv and iv ~= w.bodyIv then
            if t == "Base.NOM_Brasa" or NOM_VariantWardrobe.isStrip(t, patterns) then
                gone[#gone + 1] = iv
            end
        end
    end
    for _, iv in ipairs(gone) do list:remove(iv) end
    -- K2–K5 / Corredor: keepBody=false tira a camada N4 (manto/risco).
    if w.bodyIv and variant.keepBody == false then
        list:remove(w.bodyIv)
        w.bodyIv = nil
        w.body = nil
    end
    -- Embrulhada (e futuras): cabeça própria no lugar das mechas / LOOKS.item.
    if variant.headItem then
        local fxOn = NOM_Dissolve.enabled()
        local shellOn = fxOn and NOM_EmberShell.can(w._z)
        local piece = (fxOn and not shellOn and variant.headFx) and variant.headFx or variant.headItem
        if w.iv then list:remove(w.iv) end
        local hiv = ItemVisual.new()
        hiv:setItemType(piece)
        list:add(hiv)
        w.iv = hiv
        w.item = piece
        w.lookItem = variant.headItem
        w.lookFx = variant.headFx or variant.headItem
    end
    w.wardrobe = {}
    if not variant.pieces then return end
    for _, piece in ipairs(variant.pieces) do
        local iv = ItemVisual.new()
        iv:setItemType(piece.type)
        NOM_VariantWardrobe.treat(iv, piece, variant)
        list:add(iv)
        w.wardrobe[#w.wardrobe + 1] = iv
    end
end

local function clearWardrobe(list, w)
    if not w.wardrobe then return end
    for _, iv in ipairs(w.wardrobe) do list:remove(iv) end
    w.wardrobe = nil
    w.wardVar = nil
    w.wardIdx = nil
end

-- 0060c/e: só com flag lookClean — prova camisa/calça coloridas (não é LookForce).
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

-- Sai do look limpo: tira prova e devolve camisa/calça de w.all.
local function clearProof(z, list, w)
    if not w.proof then return end
    for _, iv in ipairs(w.proof) do list:remove(iv) end
    w.proof = nil
    if not w.all then return end
    local fallen = hatFallen(z:getPersistentOutfitID())
    for _, iv in ipairs(w.all) do
        local t = iv:getItemType()
        if isProofStrip(t) and keep(t) then
            local item = fallen and iv:getScriptItem()
            if not (item and item:getChanceToFall() > 0) and not list:contains(iv) then
                list:add(iv)
            end
        end
    end
end

-- Devolve a lista original, na ordem. Se a peça do mod já não está lá, o jogo vestiu
-- de novo (dressInPersistentOutfitID limpa a lista) e a lista nova é a verdade.
-- Cliente de MP: o servidor derruba o chapéu (ZombieHelmetFallingPacket.processClient
-- 130–238 não acha o escondido, mas cria a roupa caindo e liga o bit). Com o bit ligado,
-- o que tem ChanceToFall > 0 não volta, como o PersistentOutfits.removeFallenHat faz
-- (18–92) ao vestir.
local function unhide(z, list, w)
    -- Sem peça (ex.: Sem-rosto 0060d): ainda devolve a lista escondida.
    if w.iv and not list:remove(w.iv) then return end
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
    local piece = look.item and ((fx and not shell and look.fx) and look.fx or look.item) or nil
    local forceWard = z:hasModData() and z:getModData().NOM_wardForce or nil
    local w = {
        kind = kind, id = id, item = piece, _z = z, forceWardIdx = forceWard,
        lookItem = look.item, lookFx = look.fx,
    }
    if look.body then
        w.body = (fx and not shell and look.bodyFx) and look.bodyFx or look.body
    end
    worn[z] = w
    -- a casca de uma volta que ainda queima sai antes do hide (não pode virar roupa
    -- guardada); o efeito dela segue e o reveal abaixo continua do limiar em que estava
    NOM_EmberShell.remove(z)
    stripOrphanBrasa(z:getItemVisuals(), w)
    if look.skin then z:getHumanVisual():setSkinTextureName(look.skin) end
    local list = z:getItemVisuals()
    if w.item then
        local iv = ItemVisual.new()
        iv:setItemType(w.item)
        list:add(iv)
        w.iv = iv
    end
    -- Corpo (sprint 0052): segundo ItemVisual; KEEP já deixa %.NOM_ à mostra.
    if w.body then
        local biv = ItemVisual.new()
        biv:setItemType(w.body)
        list:add(biv)
        w.bodyIv = biv
    end
    hide(list, w)
    -- Censor (mod3): ModData NOM_semrosto. A′: tint do remendo ANTES do reset (senão
    -- pickUninitializedValues sorteia; pz-api-notes §14.4a).
    if kind == "semrosto" then
        z:getModData().NOM_semrosto = true
        w.capped = semrostoCapped(z, id)
        z:getModData().NOM_semrosto_capped = w.capped or nil
        local face, faceIdx = NOM_SemRostoFace.pick(id, w.capped)
        w.face = face
        w.faceIdx = faceIdx
        z:getModData().NOM_semrosto_face = face
        if w.iv and ImmutableColor and ImmutableColor.new then
            local base = z:getHumanVisual():getSkinTexture()
            w.skinBase = base
            local r, g, b = NOM_SemRostoFace.tintFor(base)
            w.iv:setTint(ImmutableColor.new(r, g, b, 1))
            if w.iv.setTextureChoice then
                w.iv:setTextureChoice(NOM_SemRostoFace.textureChoice(faceIdx))
            end
        end
    else
        z:getModData().NOM_semrosto = nil
        z:getModData().NOM_semrosto_capped = nil
        z:getModData().NOM_semrosto_face = nil
    end
    applyWardrobe(list, w, id)
    proofBody(list, w)
    z:resetModelNextFrame()
    if w.item and shell then
        if NOM_EmberShell.reveal(z) then NOM_EmberShell.burst(z) end
    elseif w.item and fx then
        NOM_Dissolve.run(z, "in") -- no teto, a peça já vem inteira
    end
end

local function strip(z)
    local w = worn[z]
    if not w then return end
    worn[z] = nil
    NOM_Dissolve.stop(z)
    NOM_EmberShell.remove(z)
    if w.kind == "semrosto" and z:hasModData() then
        z:getModData().NOM_semrosto = nil
        z:getModData().NOM_semrosto_capped = nil
        z:getModData().NOM_semrosto_face = nil
    end
    local list = z:getItemVisuals()
    stripOrphanBrasa(list, w)
    if w.proof then
        for _, iv in ipairs(w.proof) do list:remove(iv) end
    end
    clearWardrobe(list, w)
    if w.iv or w.all or w.bodyIv then unhide(z, list, w) end
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
    local baseItem = w.lookItem or LOOKS[w.kind].item
    local fxItem = w.lookFx or LOOKS[w.kind].fx
    if w.item and w.item == baseItem and NOM_EmberShell.can(z) then
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
    if w.item and fxItem and w.item == fxItem and NOM_Dissolve.run(z, "out", done) then
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
            proofBody(z:getItemVisuals(), w)
            z:resetModelNextFrame()
        elseif w.proof and not NOM_ScreenFxRules.lookClean() then
            clearProof(z, z:getItemVisuals(), w)
            z:resetModelNextFrame()
        end
        return
    end
    if not w and kind == nil then return end
    if w and kind == nil then
        if z:hasModData() then z:getModData().NOM_wardForce = nil end
        return leave(z)
    end
    strip(z)
    if kind and LOOKS[kind] then put(z, kind, id) end
end

-- Aplica/remove prova Sport+White em quem já está na variante (toggle lookClean).
function NOM_VariantLook.refreshClean()
    local list = getCell():getZombieList()
    for i = 0, list:size() - 1 do
        local z = list:get(i)
        local w = worn[z]
        if w and not w.leaving then
            local ivs = z:getItemVisuals()
            if NOM_ScreenFxRules.lookClean() and not w.proof then
                proofBody(ivs, w)
                z:resetModelNextFrame()
            elseif w.proof and not NOM_ScreenFxRules.lookClean() then
                clearProof(z, ivs, w)
                z:resetModelNextFrame()
            end
        end
    end
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

-- 0060b/d: prova runtime — pele, ItemVisuals, lookClean/LookForce.
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
    local lf = "-"
    if NOM_PanelParams and NOM_PanelParams.lookForce then lf = tostring(NOM_PanelParams.lookForce()) end
    if lf == "" then lf = "auto" end
    local ward = (w and w.wardVar) or "-"
    local face = (w and w.face) or (z:hasModData() and z:getModData().NOM_semrosto_face) or "-"
    local skinBase = (w and w.skinBase) or "-"
    return string.format("kind=%s var=%s face=%s skin=%s base=%s clean=%s force=%s items=%s",
        kinds, ward, tostring(face), tostring(skin), tostring(skinBase),
        tostring(NOM_ScreenFxRules.lookClean()), lf, table.concat(parts, ","))
end

-- Debug: força monstro + índice de variante (1-based). Bíblia §11.
-- NOM_wardForce gruda o índice no ModData (NightStats re-sync não sorteia outra).
function NOM_VariantLook.forceVariant(z, kind, idx)
    if not z or not kind or not LOOKS[kind] then return nil end
    local n = NOM_VariantWardrobe.count(kind)
    if n == 0 then
        NOM_VariantLook.sync(z, kind, z:getPersistentOutfitID())
        return kind
    end
    idx = math.floor(tonumber(idx) or 1)
    if idx < 1 then idx = 1 end
    if idx > n then idx = n end
    if z.getModData then z:getModData().NOM_wardForce = idx end
    local base = NOM_VariantRules.baseId(z:getPersistentOutfitID())
    -- Mesmo kind+id: sync faz early-return e o índice sticky não troca a roupa
    -- (lookVariant cicla C1→C3). Strip força put+applyWardrobe de novo.
    if worn[z] then strip(z) end
    -- id compatível com pick ponderado não é trivial; wardForce manda no applyWardrobe
    NOM_VariantLook.sync(z, kind, base)
    return kind, idx
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
    -- Sem peça (Sem-rosto 0060d): DoZombieInventory já rodou sem o que estava escondido;
    -- devolve a lista e refaz vestidos/loot como no caminho com peça.
    local ran = w.item and inv:FindAndReturn(w.item)
    strip(z)
    if w.item and not ran then return end
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
