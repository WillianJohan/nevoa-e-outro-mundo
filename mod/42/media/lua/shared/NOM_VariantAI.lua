-- Comportamento das variantes onde o zumbi é simulado (ADR-005): Estalador cego,
-- Corredor que avisa, Carpideira parada (NOM_Carpideira). No solo, o
-- próprio processo (server/NOM_Variants.lua instala); no MP, o cliente
-- (client/NOM_VariantsClient.lua instala). A variante vem do NOM_NightStats
-- (modData.NOM_variant, só em memória, ADR-006). Variante só age na névoa (decisão
-- do Johan, 05/10), de dia ou de noite: tudo aqui olha o NOM_FogState. O grito do Corredor é decisão
-- do servidor: aqui só se avisa, pelo report passado no install.
require "NOM_NightStats"
require "NOM_FogState"
require "NOM_Carpideira"
require "NOM_SirenFreeze"
require "NOM_TicaoFreeze"
require "NOM_VariantRules"
require "NOM_Config"
require "NOM_Math"

require "NOM_SonarRules"
require "NOM_FogEventRules"
require "NOM_TicaoRules"

NOM_VariantAI = {}

-- O estalo do Estalador é decisão do servidor desde a sprint 0037 (é o sonar):
-- server/NOM_SonarServer.lua sorteia, shared/NOM_Sonar.lua toca no ponto e desenha o anel.

-- Estaladores que o sonar fez achar um jogador: { [zumbi] = { left = ms } }. Nessa janela
-- (NOM_SonarRules.FOUND_MS) ele não é cegado de novo, nem se o jogador se agachar. O left
-- desconta o tempo real do OnTick (getTimestampMs) como as sirenes atrasadas
-- (NOM_FogEventRules.countdown): parado com isGamePaused (pz-api-notes §11.2), no máximo
-- MAX_STEP_MS por tick.
NOM_VariantAI.found = {}
local found = NOM_VariantAI.found
local foundMs -- getTimestampMs do último tick com janela aberta

-- Janela de cegueira, em updates do zumbi, não em tempo real (~1 s a 60 FPS). Fecha sozinha e abre
-- de novo no update seguinte se o jogador ainda estiver agachado à vista: useless
-- também é surdo (RespondToSound volta cedo, bytecode 8–15), e a janela curta é o
-- que deixa o Estalador ouvir entre uma e outra.
NOM_VariantAI.BLIND_FRAMES = 60

-- Zumbis que ESTE mod deixou useless: { [zumbi] = { p = jogador, n = updates, t = tick do
-- último update, common = visão curta, x, y = onde o cego comum parou } }. Só esses são
-- desligados; useless de outro (tutorial, debug, outro mod) fica.
-- Exposta só pra leitura: o rodízio do NOM_SirenFreeze não solta o cego.
NOM_VariantAI.blinded = {}
local blinded = NOM_VariantAI.blinded

-- Visão curta da névoa (sprint 0036, spec §5): o jogo prende o raio de visão do zumbi em
-- 10–20 tiles (IsoZombie.updateVisionRadius, pz-api-notes §3.2), então a visão menor é a
-- cegueira do Estalador em todo zumbi sem mira própria (o comum e o Sem-rosto): jogador de
-- alvo, quieto e a mais de VISION_TILES fica fora. O raio de verdade vem do sandbox
-- (FogZombieVision; 0 desliga); VISION_TILES é o padrão, ajustado no NOM_Config e no
-- media/sandbox-options.txt. Medição na Tarefa 0 da sprint:
-- perguntar pra todo zumbi todo frame passa do teto com a multidão; o rodízio no OnTick,
-- VISION_BATCH por tick, custa ~1/7 e não toca no OnZombieUpdate do comum.
-- CHECK_FRAMES: o cego comum confere a distância a cada tantos frames, não todo frame.
-- WATCH_FRAMES: depois da janela, por quantos frames o zumbi é vigiado todo frame (o spot
-- volta no frame seguinte; o rodízio levaria uma volta na lista).
-- Barulho (OnWorldSound) do jogador, ou no pé dele (a até NOISE_NEAR tiles): quem está no
-- raio do som não fica cego pra ele por raio × NOISE_PER_TILE ticks (o tempo de chegada de
-- um zumbi lento, ~0,5 tile/s a 60 FPS), entre NOISE_TICKS e NOISE_MAX. Som com raio abaixo
-- de NOISE_MIN_RADIUS não denuncia: o passo andando de sapato na rua tem raio ~7
-- (IsoPlayer.DoFootstepSound(F), bytecode 0–296: ceil(volume × 1,4 × 10), "walk" = 0,5),
-- e andar conta como quieto. Correr (raio ~19) já denuncia pelo isRunning.
NOM_VariantAI.VISION_TILES = NOM_Config.DEFAULTS.FogZombieVision
NOM_VariantAI.VISION_BATCH = 30
NOM_VariantAI.CHECK_FRAMES = 10
NOM_VariantAI.WATCH_FRAMES = 30
NOM_VariantAI.NOISE_TICKS = 180
NOM_VariantAI.NOISE_PER_TILE = 120
NOM_VariantAI.NOISE_MAX = 7200
NOM_VariantAI.NOISE_MIN_RADIUS = 10
NOM_VariantAI.NOISE_NEAR = 3
NOM_VariantAI.LOG_TICKS = 300 -- no -debug, a contagem no console (~5 s a 60 FPS)
-- Zumbi descarregado não tem OnZombieUpdate: sem atualização há STALE_TICKS, sai de blinded
-- e watched (a cada LOG_TICKS no rodízio e na hora no counts).
NOM_VariantAI.STALE_TICKS = 600
-- Recém-soltos da visão curta, vigiados todo frame: { [zumbi] = tick em que foi solto }.
NOM_VariantAI.watched = {}
local watched = NOM_VariantAI.watched
-- Ticks (OnTick) desde o install: o relógio da visão curta e da validade das entradas.
local tick = 0

-- Agachado e sem correr: o Estalador não tem como saber que o jogador está ali.
local function silent(p)
    return p:isSneaking() and not p:isRunning() and not p:isSprinting()
end

local function release(z)
    blinded[z] = nil
    z:setUseless(false)
end

-- Por que useless e não só setTarget(nil): o spot dá bonusSpotTime = 720
-- (spottedNew 1909–1917), e o updateInternal refaz o spot forçado depois do
-- OnZombieUpdate e antes da máquina de estados (956–991), com setTarget e
-- pathToCharacter. Zumbi useless leva setTarget(null) e spottedLast = null no
-- spottedNew (191–208): o laço do spot forçado morre ali. A caminhada até a
-- última posição vista (WalkTowardState) continua, mas sem alvo não há ataque.
local function estalador(z, md, blind)
    local f = found[z]
    if f ~= nil then
        if f.left > 0 then return end
        found[z] = nil
    end
    if blind then
        blind.n = blind.n + 1
        if blind.n < NOM_VariantAI.BLIND_FRAMES and silent(blind.p) then return end
        release(z)
        return -- o spot volta no próximo frame; se ainda for silencioso, fecha de novo
    end
    -- useless viaja no pacote do zumbi (NetworkZombieAI.set → getBooleanVariables
    -- 86–89; parse 204–252): se a posse trocou no meio da janela, este dono herdou
    -- o useless sem a entrada em blinded. Desliga, salvo o useless do próprio jogo
    -- (outfit de debug com "Useless", updateInternal 47–58). O do menu de debug e
    -- do tutorial não dá pra distinguir: num Estalador na névoa, também cai.
    -- Custo: uma chamada Java por Estalador local por frame.
    if z:isUseless() then
        if not NOM_Carpideira.gameUseless(z) then z:setUseless(false) end
        return
    end
    if md.NOM_alert then return end
    local t = z:getTarget()
    if t ~= nil and instanceof(t, "IsoPlayer") and silent(t) then
        z:setTarget(nil)
        z:setUseless(true)
        blinded[z] = { p = t, n = 0, t = tick }
    end
end

-- Visão curta ---------------------------------------------------------------------

local r2, cursor = nil, 0
-- Lista de trabalho reaproveitada (sem tabela nova por som nem por passada): mexer na
-- tabela no meio do pairs não é seguro no Kahlua (NOM_SemRosto.reserve), então junta aqui
-- e mexe depois.
local scratch = {}
-- Por jogador, uma vez por tick: { f = tick, x, y, quiet }. noisy[p] = { t = até que tick,
-- x, y = ponto do som, rr = raio² }: o último barulho que denuncia o jogador.
-- ponytail: chave é o objeto do jogador; quem sai fica até reiniciar (um por jogador).
local seen, noisy = {}, {}

-- Raio² da visão curta agora, ou nil (névoa fechada ou opção em 0). Na preta (sprint 0038), o
-- raio do Tição, com a opção ligada ou não: a preta tem o próprio toggle.
local function visionR2()
    if not NOM_FogState.on then return nil end
    if NOM_FogState.black then return NOM_TicaoRules.VISION_TILES * NOM_TicaoRules.VISION_TILES end
    local v = tonumber(NOM_Config.get("FogZombieVision")) or 0
    if v <= 0 then return nil end
    return v * v
end

local function about(p)
    local c = seen[p]
    if c == nil then
        c = {}
        seen[p] = c
    end
    if c.f ~= tick then
        c.f, c.x, c.y = tick, p:getX(), p:getY()
        c.quiet = not p:isRunning() and not p:isSprinting()
    end
    return c
end

-- Posição do zumbi lida no último unseen (o blindCommon guarda: o cego fica parado).
local ux, uy = 0, 0

-- Jogador quieto e longe do zumbi, e o zumbi fora do raio do último barulho dele.
local function unseen(z, p)
    local c = about(p)
    if not c.quiet then return false end
    ux, uy = z:getX(), z:getY()
    local n = noisy[p]
    if n ~= nil and n.t >= tick then
        local nx, ny = ux - n.x, uy - n.y
        if nx * nx + ny * ny <= n.rr then return false end
    end
    local dx, dy = ux - c.x, uy - c.y
    return dx * dx + dy * dy > r2
end

local function aimsUnseen(z, t)
    return t ~= nil and instanceof(t, "IsoPlayer") and unseen(z, t)
end

-- O useless não interrompe quem já anda atrás do jogador (PathFindState.execute não o lê):
-- o mesmo halt do NOM_SirenFreeze (pz-api-notes §21).
local function halt(z)
    z:getPathFindBehavior2():cancel()
    z:setPath2(nil)
    z:setVariable("bPathfind", false)
    z:setVariable("bMoving", false)
end

-- Logo depois de um unseen verdadeiro pra z: x, y são os dele (ux, uy). Parado pelo halt, o
-- cego fica ali, e o som (heard) confere a distância sem chamar o Java.
local function blindCommon(z, p)
    z:setTarget(nil)
    z:setUseless(true)
    halt(z)
    watched[z] = nil
    blinded[z] = { p = p, n = 0, common = true, x = ux, y = uy, t = tick }
end

-- Cego comum, por frame: a cada CHECK_FRAMES confere se o jogador chegou perto ou fez
-- barulho (e atualiza o x, y guardado); no fim da janela solta (ouve de novo) e vigia.
local function commonBlind(z, b)
    if r2 == nil then return release(z) end
    b.n = b.n + 1
    local done = b.n >= NOM_VariantAI.BLIND_FRAMES
    if not done and NOM_Math.mod(b.n, NOM_VariantAI.CHECK_FRAMES) ~= 0 then return end
    if not done and unseen(z, b.p) then
        b.x, b.y = ux, uy
        return
    end
    release(z)
    watched[z] = tick
end

-- Recém-solto: o spot volta no frame seguinte; se o jogador ainda está longe e quieto, fecha.
local function watch(z, since)
    if r2 == nil or tick - since >= NOM_VariantAI.WATCH_FRAMES then
        watched[z] = nil
        return
    end
    if NOM_TicaoFreeze.frozen[z] then return end
    local t = z:getTarget()
    if aimsUnseen(z, t) and z:isLocal() then blindCommon(z, t) end
end

-- Tira de blinded e watched quem não é atualizado desde antes de `old` (descarregado: o
-- OnZombieUpdate parou). O objeto vai pro pool do jogo e o resetForReuse não limpa o useless:
-- solta junto. old nil: tira todo mundo (fim da névoa).
local function purge(old)
    local n = 0
    for z, b in pairs(blinded) do
        if old == nil or (b.t or 0) < old then
            n = n + 1
            scratch[n] = z
        end
    end
    for i = 1, n do
        release(scratch[i])
        scratch[i] = nil
    end
    n = 0
    for z, since in pairs(watched) do
        if old == nil or since < old then
            n = n + 1
            scratch[n] = z
        end
    end
    for i = 1, n do
        watched[scratch[i]] = nil
        scratch[i] = nil
    end
end

local function purgeStale() purge(tick - NOM_VariantAI.STALE_TICKS) end

-- O rodízio: até VISION_BATCH zumbis por tick, em volta na lista. Tabela Lua antes de
-- qualquer chamada: variante com mira própria, cego, vigiado, Carpideira parada e
-- congelado pela sirene não custam nada. O Tição (sprint 0038) entra como o comum: é a visão curta dele. O Sem-rosto entra como o comum: o NOM_NightStats
-- não o põe em variants (kind vira nil antes do apply), e ele tem visão curta (decisão do
-- Johan); perguntar o NOM_SemRosto.isSemRosto custaria uma chamada por zumbi do lote.
-- As janelas do sonar andam (só o campo muda: a tabela não é mexida no meio do pairs). Sem
-- janela, nenhuma chamada.
local function ageFound()
    local now, dt, paused
    for _, f in pairs(found) do
        if now == nil then
            now, paused = getTimestampMs(), isGamePaused()
            dt = foundMs and now - foundMs or 0
            foundMs = now
        end
        f.left = NOM_FogEventRules.countdown(f.left, dt, paused)
    end
    if now == nil then foundMs = nil end
end

local function sweep()
    tick = tick + 1
    ageFound()
    r2 = visionR2()
    if r2 == nil then return end
    local logTick = NOM_Math.mod(tick, NOM_VariantAI.LOG_TICKS) == 0
    if logTick then purgeStale() end
    local list = getCell():getZombieList()
    local size = list:size()
    if size == 0 then return end
    local n = math.min(NOM_VariantAI.VISION_BATCH, size)
    for k = 0, n - 1 do
        local z = list:get(NOM_Math.mod(cursor + k, size))
        local kind = NOM_NightStats.variants[z]
        if (kind == nil or kind == "ticao") and blinded[z] == nil and watched[z] == nil
            and NOM_Carpideira.still[z] == nil and not NOM_SirenFreeze.frozen[z] and not NOM_TicaoFreeze.frozen[z] then
            local t = z:getTarget()
            if aimsUnseen(z, t) and z:isLocal() and not NOM_NightStats.isEco(z, z:getModData()) then blindCommon(z, t) end
        end
    end
    cursor = NOM_Math.mod(cursor + n, size)
    if getDebug() and logTick then
        local c = NOM_VariantAI.counts()
        print("[NOM] visao curta cegos=" .. c.common .. " vigiados=" .. c.watched .. " estaladores=" .. c.estalador ..
            " lista=" .. size .. " raio=" .. math.floor(math.sqrt(r2) + 0.5))
    end
end

-- Barulho do jogador p no ponto (x, y): quem está no raio não fica cego pra ele até o fim
-- da janela. O som maior fica até vencer; um igual ou maior toma o lugar.
local function mark(p, x, y, radius)
    local n = noisy[p]
    if n == nil then
        n = {}
        noisy[p] = n
    end
    local rr = radius * radius
    if n.t ~= nil and n.t >= tick and rr < n.rr then return end
    local span = math.floor(radius * NOM_VariantAI.NOISE_PER_TILE)
    n.t = tick + math.max(NOM_VariantAI.NOISE_TICKS, math.min(NOM_VariantAI.NOISE_MAX, span))
    n.x, n.y, n.rr = x, y, rr
end

-- Som: o cego é surdo (useless; RespondToSound 8–15). Events.OnWorldSound(x, y, z, raio,
-- volume, fonte) sai de todo addSound (WorldSoundManager$WorldSound.init 129), antes de o
-- zumbi ouvir: o som vive 16 atualizações (life, init 6–8). Solta o cego no raio (ouve e
-- vai) e, se o som denuncia (raio ≥ NOISE_MIN_RADIUS), marca barulhento a fonte, se for
-- jogador (como o server/NOM_Variants.lua no barulho que acorda a Carpideira), e o jogador
-- local que está no ponto do som agora (carro, som sem fonte). Custo: o laço nos cegos é só
-- Lua (o x, y que cada um guardou), com a lista de trabalho reaproveitada.
local function heard(x, y, _, radius, _, source)
    if r2 == nil or type(radius) ~= "number" then return end
    local rr, n = radius * radius, 0
    for z, b in pairs(blinded) do
        if b.common then
            local dx, dy = b.x - x, b.y - y
            if dx * dx + dy * dy <= rr then
                n = n + 1
                scratch[n] = z
            end
        end
    end
    for i = 1, n do
        local z = scratch[i]
        scratch[i] = nil
        release(z)
        watched[z] = tick
    end
    if radius < NOM_VariantAI.NOISE_MIN_RADIUS then return end
    if source ~= nil and instanceof(source, "IsoPlayer") then mark(source, x, y, radius) end
    local near = NOM_VariantAI.NOISE_NEAR * NOM_VariantAI.NOISE_NEAR
    for i = 0, getNumActivePlayers() - 1 do
        local p = getSpecificPlayer(i)
        if p ~= nil and p ~= source then
            local c = about(p)
            local dx, dy = c.x - x, c.y - y
            if dx * dx + dy * dy <= near then mark(p, x, y, radius) end
        end
    end
end

-- Contagem pro debug (NOM.blind): cegos da visão curta, Estaladores cegos, vigiados. Tira
-- antes os descarregados, pra não contar quem já saiu.
function NOM_VariantAI.counts()
    purgeStale()
    local common, estalador, w = 0, 0, 0
    for _, b in pairs(blinded) do
        if b.common then common = common + 1 else estalador = estalador + 1 end
    end
    for _ in pairs(watched) do w = w + 1 end
    return { common = common, estalador = estalador, watched = w, on = r2 ~= nil }
end

local function corredor(z, md, report)
    local t = z:getTarget()
    local player = t ~= nil and instanceof(t, "IsoPlayer")
    if player and not md.NOM_hunting then report(z) end
    md.NOM_hunting = player or nil
end

-- OnZombieUpdate roda por zumbi a cada frame: o zumbi comum sai na primeira
-- linha, com quatro consultas de tabela Lua e nenhuma chamada Java. O cego e o vigiado
-- da visão curta saem antes de qualquer outra chamada. O Tição (sprint 0038) sai como o comum.
local function onUpdate(z, report)
    local kind, blind, still, w = NOM_NightStats.variants[z], blinded[z], NOM_Carpideira.still[z], watched[z]
    if (kind == nil or kind == "ticao") and blind == nil and still == nil and w == nil then return end
    if blind ~= nil then
        blind.t = tick -- carregado (purge)
        if blind.common then return commonBlind(z, blind) end
    end
    if w ~= nil then return watch(z, w) end
    local md = z:getModData()
    if kind ~= nil and md.NOM_variant ~= kind then -- objeto reaproveitado
        NOM_NightStats.variants[z] = nil
        kind = nil
    end
    local on = NOM_FogState.on and z:isLocal() -- dono (pz-api-notes §24)
    if kind == "estalador" and on then
        estalador(z, md, blind)
    elseif blind then
        release(z) -- névoa baixou, deixou de ser Estalador ou virou remoto
    elseif kind == "corredor" and on then
        corredor(z, md, report)
    end
    -- Carpideira (sprint 0011): parada enquanto calma; solta quando a névoa baixa,
    -- deixa de ser Carpideira ou vira remota (aí o pacote do dono manda).
    if kind == "carpideira" and on then
        NOM_Carpideira.hold(z, md)
    elseif still then
        NOM_Carpideira.letGo(z)
    end
end

-- Golpe é barulho: o Estalador acertado passa a seguir quem bateu.
-- ponytail: alerta até o zumbi ir pro virtual ou a névoa baixar; esfriar com o tempo se pedirem.
local function onHit(z)
    if blinded[z] then release(z) end
    watched[z] = nil
    if NOM_NightStats.variants[z] ~= "estalador" then return end
    z:getModData().NOM_alert = true
end

-- Useless herdado (review da 0011): o useless viaja no pacote do zumbi
-- (NetworkZombieAI.set → getBooleanVariables 86–89; parse 204–252) e o
-- resetForReuse não o limpa. Se o dono que parou a Carpideira (ou cegou o Estalador)
-- perde a posse, a névoa acaba ou o objeto é reaproveitado, o novo dono fica com um
-- zumbi useless que nada aqui marcou, e o onUpdate sai cedo (kind, blind e still nil).
-- Solta o useless de zumbi local que este processo não ligou, mas só de quem o mod
-- pode ter deixado useless: Carpideira ou Estalador no período de névoa atual ou no
-- anterior (o sorteio é determinístico, ADR-006), normal ou vermelha (a cor de um
-- período passado não é guardada: as duas contam). Fica: o do próprio jogo (outfit
-- "Useless"), o do tutorial (client/Tutorial/Steps.lua:847, 1107; e nada no modo
-- tutorial, getCore():getGameMode() == "Tutorial", shared/TimedActions/
-- ISGrabCorpseAction.lua:140) e o de outro mod num zumbi que nunca foi variante. O
-- useless do menu de debug numa ex-variante cai na passada seguinte.
-- Chamado pela passada do NOM_NightStats e no OnZombieCreate.
local HELD = { carpideira = true, estalador = true }

-- Visão curta no cliente de MP: a posse pode chegar com o useless logo depois que a névoa
-- fecha. Por AFTER_FOG_MS reais (getTimestampMs, como o SWEEP_MS do NOM_SirenFreeze) a
-- soltura ampla segue. afterFogUntil: marcado no fim da névoa (install).
NOM_VariantAI.AFTER_FOG_MS = 10000
local afterFogUntil = nil

local function heldByMod(id)
    -- visão curta (sprint 0036): no cliente de MP, na névoa, qualquer zumbi pode ter chegado
    -- cego pela troca de posse. O useless de outro mod num zumbi comum também cai, só enquanto
    -- a névoa durar (e AFTER_FOG_MS depois). No solo não há posse pra trocar (o cego daqui
    -- está em blinded, e o reaproveitado passa pelo forget): o de outro mod e o do debug ficam
    if isClient() and (visionR2() ~= nil or (afterFogUntil ~= nil and getTimestampMs() <= afterFogUntil)) then
        return true
    end
    local period = NOM_FogState.period
    if not period then return false end
    local cfg = NOM_VariantRules.config(NOM_Config.get)
    for n = period - 1, period do
        if HELD[NOM_VariantRules.variant(id, n, cfg) or ""] or HELD[NOM_VariantRules.variant(id, n, cfg, true) or ""] then
            return true
        end
    end
    return false
end

local function unstick(z)
    if blinded[z] or NOM_Carpideira.still[z] or NOM_SirenFreeze.frozen[z] or NOM_TicaoFreeze.frozen[z] or not z:isLocal()
        or not z:isUseless() then return end
    if getCore():getGameMode() == "Tutorial" or NOM_Carpideira.gameUseless(z) then return end
    if heldByMod(z:getPersistentOutfitID()) then z:setUseless(false) end
end

-- Objeto reaproveitado pra outro zumbi (resetForReuse → OnZombieCreate) não
-- herda a cegueira nem a parada. Morto também sai da tabela.
local function forget(z)
    if blinded[z] then release(z) end
    watched[z] = nil
    found[z] = nil
    NOM_Carpideira.forget(z)
end

local function created(z)
    forget(z)
    unstick(z)
end

-- O anel do sonar passou pelo jogador p em pé ou andando (o servidor decidiu, sprint 0037):
-- no dono, o Estalador z solta a cegueira e acha p pelo mesmo spot forçado do grito da
-- Carpideira (spotted(p, true) → spottedNew com chance 1 000 000, 1114–1120; só vale sem
-- useless, 191–208: solta antes). O useless que este dono não marcou (herdado na troca de
-- posse, como no estalador()) também sai; fica o do próprio jogo (gameUseless) e o congelado
-- da sirene. Por FOUND_MS reais o estalador() não o cega de novo.
-- Devolve se aplicou (só o dono aplica, pz-api-notes §24).
function NOM_VariantAI.sonarFound(z, p)
    if z == nil or p == nil or not z:isLocal() or z:isDead() then return false end
    if blinded[z] then release(z) end
    watched[z] = nil
    if z:isUseless() and not NOM_SirenFreeze.frozen[z] and not NOM_Carpideira.gameUseless(z) then z:setUseless(false) end
    found[z] = { left = NOM_SonarRules.FOUND_MS }
    z:spotted(p, true)
    if getDebug() then print("[NOM] sonar estalador achou o jogador (alvo=" .. tostring(z:getTarget() == p) .. ")") end
    return true
end

local function forgetFound()
    local n = 0
    for z in pairs(found) do
        n = n + 1
        scratch[n] = z
    end
    for i = 1, n do
        found[scratch[i]] = nil
        scratch[i] = nil
    end
end

-- report(z): Corredor dono passou a ter um jogador como alvo.
function NOM_VariantAI.install(report)
    Events.OnZombieUpdate.Add(function(z) onUpdate(z, report) end)
    Events.OnHitZombie.Add(onHit)
    Events.OnZombieCreate.Add(created)
    NOM_NightStats.unstick = unstick
    Events.OnZombieDead.Add(forget)
    Events.OnTick.Add(sweep)
    Events.OnWorldSound.Add(heard)
    NOM_FogState.onChange(function(on)
        afterFogUntil = nil
        -- o carregado soltaria no próximo update; o descarregado não tem update
        if not on then
            purge(nil)
            forgetFound()
        end
        if not on and isClient() and (tonumber(NOM_Config.get("FogZombieVision")) or 0) > 0 then
            afterFogUntil = getTimestampMs() + NOM_VariantAI.AFTER_FOG_MS
        end
    end)
end

return NOM_VariantAI
