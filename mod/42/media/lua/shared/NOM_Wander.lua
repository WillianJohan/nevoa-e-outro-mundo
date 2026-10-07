-- Perambular na névoa (sprint 0036, spec §5), lado de quem simula (ADR-005). O servidor
-- decide a onda e a semente (server/NOM_WanderServer.lua): no solo chama wave aqui mesmo;
-- no MP manda "wander" e cada cliente (client/NOM_VariantsClient.lua) aplica nos zumbis
-- dele. Só o dono sabe se o zumbi está parado e sem alvo (o alvo não viaja, pz-api-notes
-- §3.3), então a escolha entre os zumbis é daqui, pela regra pura (NOM_WanderRules).
-- Jogadores: os locais deste processo; os zumbis de um cliente ficam perto do jogador dele.
-- Andar: z:pathToLocationF(x, y, z) no dono. IsoZombie.pathToLocationF (bytecode 0–47) só
-- recusa com allowRepathDelay > 0 em quem já anda; IsoGameCharacter.pathToLocationF (0–17)
-- põe o destino no PathFindBehavior2 e o pathToAux (0–274) liga bPathfind ou bMoving
-- sozinho. Uso vanilla no zumbi: client/DebugUIs/DebugContextMenu.lua:640 (pathToLocation,
-- a versão de tile inteiro do mesmo caminho, IsoGameCharacter.pathToLocation 0–28).
-- Fora: variantes (comportamento delas), Sem-rostos, Ecos, cegos e vigiados da visão curta, Carpideira
-- parada, congelados da sirene e todo useless; sem névoa, com a sirene ou com a opção
-- FogWander desligada, não sai onda.
require "NOM_WanderRules"
require "NOM_Math"
require "NOM_Config"
require "NOM_FogState"
require "NOM_NightStats"
require "NOM_Carpideira"
require "NOM_SirenFreeze"
require "NOM_VariantAI"
require "NOM_SemRosto"
require "NOM_VariantRules"

NOM_Wander = { last = nil }
local R = NOM_WanderRules

-- Jogadores vivos: os locais (getSpecificPlayer), que puxam grupo, e todos os conhecidos, que
-- o destino respeita: no cliente de MP também os do getOnlinePlayers (o local vem repetido,
-- não atrapalha); no solo a lista vem vazia (o mesmo do NOM_SirenFreeze, pz-api-notes §23).
local function players()
    local locals, all = {}, {}
    local function pos(p) return { x = p:getX(), y = p:getY(), z = p:getZ() } end
    for i = 0, getNumActivePlayers() - 1 do
        local p = getSpecificPlayer(i)
        if p and not p:isDead() then
            locals[#locals + 1] = pos(p)
            all[#all + 1] = locals[#locals]
        end
    end
    if isClient() then
        local list = getOnlinePlayers()
        for i = 0, list:size() - 1 do
            local p = list:get(i)
            if p and not p:isDead() then all[#all + 1] = pos(p) end
        end
    end
    return locals, all
end

local function nearAny(ps, x, y)
    local r2 = R.NEAR_MAX * R.NEAR_MAX
    for _, p in ipairs(ps) do
        if (p.x - x) * (p.x - x) + (p.y - y) * (p.y - y) <= r2 then return true end
    end
    return false
end

-- Regra própria lida em tabela Lua, antes de qualquer chamada no zumbi.
local function ruled(z)
    return NOM_NightStats.variants[z] ~= nil or NOM_VariantAI.blinded[z] ~= nil or NOM_VariantAI.watched[z] ~= nil
        or NOM_Carpideira.still[z] ~= nil or NOM_SirenFreeze.frozen[z] ~= nil
end

-- Parado e livre: sem alvo, perto de algum jogador, local, vivo, sem useless, sem andar, nem
-- fingindo de morto nem sentado no chão (isFakeDead/isSitOnGround, os do log do
-- NOM_NightStats), não Eco e não Sem-rosto (o NOM_NightStats não o põe em variants: só o
-- sorteio pelo ID diz; decisão do Johan: o Sem-rosto não perambula). Devolve o candidato (ou
-- nil) e se passou da distância (custo: getTarget + getX/getY em quem passa da tabela; até
-- ~10 a mais nos perto).
local function idle(z, ps, cfg)
    if z:getTarget() ~= nil then return nil, false end
    local x, y = z:getX(), z:getY()
    if not nearAny(ps, x, y) then return nil, false end
    if not z:isLocal() or z:isDead() or z:isUseless() or z:isMoving() or z:isFakeDead() or z:isSitOnGround()
        or NOM_NightStats.isEco(z, z:getModData()) then
        return nil, true
    end
    if NOM_SemRosto.isSemRosto(z, NOM_FogState.period, cfg, NOM_FogState.red) then return nil, true end
    return { x = x, y = y, z = z:getZ() }, true
end

local function floorOk(x, y, zz)
    return NOM_SemRosto.floorOk(getCell():getGridSquare(x, y, zz))
end

-- Onda em andamento (fatiada): a coleta segue no OnTick até a lista acabar ou juntar
-- SCAN_MAX candidatos. TICK_CALLS: chamadas Java estimadas por tick (4 por zumbi olhado,
-- FAR_CALLS; NEAR_CALLS a mais no que está perto), pra a onda de 300 zumbis caber em 2–3
-- ticks em vez de ~1200 chamadas num só.
NOM_Wander.TICK_CALLS = 600
NOM_Wander.FAR_CALLS = 4
NOM_Wander.NEAR_CALLS = 10
local job = nil

function NOM_Wander.pending() return job ~= nil end

local function finish(j, size)
    job = nil
    local plan = R.plan(j.ps, j.cands, j.rand, floorOk, j.all)
    for _, g in ipairs(plan) do
        local z = j.objs[g.i]
        if not z:isDead() then z:pathToLocationF(g.x + 0.5, g.y + 0.5, g.z) end -- pode ter morrido entre os ticks
    end
    NOM_Wander.last = { groups = plan, candidates = #j.cands, players = #j.ps, size = size }
    if getDebug() then
        print("[NOM] perambular zumbis=" .. #plan .. " candidatos=" .. #j.cands .. " jogadores=" .. #j.ps .. " lista=" .. size)
    end
    return plan
end

-- Uma fatia da coleta. Devolve o plano quando termina; nil enquanto segue (ou cancelada: a
-- névoa fechou ou a sirene tocou no meio).
local function step()
    local j = job
    if not NOM_FogState.on or NOM_SirenFreeze.active then
        job = nil
        return nil
    end
    local list = getCell():getZombieList()
    local size = list:size()
    local spent = 0
    while j.k < size and #j.cands < R.SCAN_MAX and spent < NOM_Wander.TICK_CALLS do
        local z = list:get(NOM_Math.mod(j.start + j.k, size))
        j.k = j.k + 1
        spent = spent + NOM_Wander.FAR_CALLS
        if not ruled(z) then
            local c, near = idle(z, j.ps, j.cfg)
            if near then spent = spent + NOM_Wander.NEAR_CALLS end
            if c then
                j.cands[#j.cands + 1] = c
                j.objs[#j.cands] = z
            end
        end
    end
    if j.k >= size or #j.cands >= R.SCAN_MAX then return finish(j, size) end
    return nil
end

-- Uma onda com a semente do servidor. Junta até SCAN_MAX candidatos, começando num ponto
-- sorteado da lista (cada onda olha outros), e manda os grupos andarem. Devolve o plano se
-- a coleta coube neste tick; senão segue nos próximos (NOM_Wander.pending). Uma onda nova
-- no meio de outra toma o lugar dela.
function NOM_Wander.wave(seed)
    job = nil
    if not NOM_FogState.on or NOM_SirenFreeze.active or not NOM_Config.get("FogWander") then return nil end
    local ps, all = players()
    if #ps == 0 then return nil end
    local rand = R.rng(seed)
    local size = getCell():getZombieList():size()
    job = { ps = ps, all = all, rand = rand, cfg = NOM_VariantRules.config(NOM_Config.get), cands = {}, objs = {},
        k = 0, start = math.floor(rand() * size) }
    return step()
end

function NOM_Wander.tick()
    if job then step() end
end

Events.OnTick.Add(NOM_Wander.tick)

return NOM_Wander
