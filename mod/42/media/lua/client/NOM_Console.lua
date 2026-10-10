-- Atalhos curtos do debug (sprint 0020): a tabela global NOM, só no cliente com o jogo
-- em -debug (a mesma porta do NOM_Debug). O autocomplete do console do debug é Java
-- (UIDebugConsole.InitSuggestionEngine lista só os métodos Java do GlobalObject), então
-- função Lua nunca aparece lá: NOM.help() lista tudo. Toggle chamado sem argumento
-- inverte o estado atual. O que mexe no mundo vai pro servidor pelo NOM_Debug
-- (server/NOM_DebugServer.lua confere -debug e a permissão); god, noclip e invisível são
-- do jogador local, como no painel de admin do vanilla. NOM_Debug.* continuam valendo.
if isServer() or not getDebug() then return end

require "NOM_Debug"
require "NOM_DebugRules"
require "NOM_DebugLog"
require "NOM_Math"
require "NOM_NightStats"
require "NOM_FogState"
require "NOM_VariantRules"
require "NOM_Config"

NOM = {}

local SPAWN_AHEAD = 3 -- tiles na frente do jogador

local function player() return getSpecificPlayer(0) end

-- on nil: inverte. skip: com a névoa nova, sem esperar a sirene.
-- Sem argumento quem decide é o servidor (sabe se a sirene está contando).
function NOM.fog(on, skip)
    if on == nil then return NOM_Debug.send({ op = "fog", toggle = true }) end
    NOM_Debug.fog(on, skip)
end

-- Sem argumento quem decide é o servidor (sabe da sirene vermelha contando).
function NOM.redFog(on)
    if on == nil then return NOM_Debug.send({ op = "redFog", toggle = true }) end
    NOM_Debug.redFog(on)
end

-- Noite forçada (true) ou dia forçado (false); NOM_Debug.night() devolve pro relógio.
function NOM.night(on)
    if on == nil then on = not NOM_NightStats.night end
    NOM_Debug.night(on)
end

-- Hora do relógio do jogo; 25 vira 1, -1 vira 23. Sempre pra frente: hora que já
-- passou hoje é a de amanhã (server/NOM_DebugServer.lua).
function NOM.time(hour)
    if type(hour) ~= "number" or hour ~= hour or hour == math.huge or hour == -math.huge then
        NOM_DebugLog.say("[NOM] debug uso: NOM.time(hora), ex.: NOM.time(22)")
        return
    end
    NOM_Debug.send({ op = "time", hour = NOM_Math.mod(hour, 24) })
end

-- n zumbis (1 a 50) com o outfit (nil: sorteado) espalhados em 3×3 a 3 tiles na frente do jogador.
function NOM.spawn(n, outfit)
    local p = player()
    if not p then return end
    local count = NOM_DebugRules.clampSpawn(n == nil and 1 or n)
    if not count then
        NOM_DebugLog.say("[NOM] debug uso: NOM.spawn(quantos, outfit), ex.: NOM.spawn(5)")
        return
    end
    local a = p:getForwardDirection():getDirection() -- radianos (FishingRod.lua:286)
    NOM_Debug.send({ op = "spawn", n = count, outfit = outfit,
        x = p:getX() + math.cos(a) * SPAWN_AHEAD, y = p:getY() + math.sin(a) * SPAWN_AHEAD, z = p:getZ() })
end

function NOM.variant(kind) NOM_Debug.variant(kind) end
function NOM.eco() NOM_Debug.spawnEco() end
function NOM.status() NOM_Debug.status() end

-- Sprint 0054: cicla o look horror no zumbi mais perto (Pale→Misaligned→Wrong→Patient→desfaz).
-- Forçar um arquétipo isolado já é NOM.variant / os botões do painel; aqui é só o ciclo compacto.
local LOOK_CYCLE = { "estalador", "corredor", "semrosto", "carpideira" }
local LOOK_LABEL = { estalador = "Pale", corredor = "Misaligned", semrosto = "Wrong", carpideira = "Patient" }
local lookCycleI = 0

function NOM.lookCycle()
    lookCycleI = lookCycleI + 1
    if lookCycleI > #LOOK_CYCLE then lookCycleI = 0 end
    local kind = lookCycleI > 0 and LOOK_CYCLE[lookCycleI] or nil
    if kind and not NOM_FogState.on then
        NOM_DebugLog.say("[NOM] debug look só aparece com névoa (NOM.setFog(true))")
    end
    if kind then
        NOM_DebugLog.say("[NOM] debug lookCycle → " .. LOOK_LABEL[kind] .. " (" .. kind .. ")")
    else
        NOM_DebugLog.say("[NOM] debug lookCycle → desfazer")
    end
    NOM_Debug.variant(kind)
end

-- Sprint 0060b: dump pele + ItemVisuals do zumbi mais perto (prova no console).
function NOM.lookInspect()
    require "NOM_VariantLook"
    local s = NOM_VariantLook.inspect()
    NOM_DebugLog.say("[NOM] lookInspect " .. s)
    return s
end

local function nearestZombies(n)
    local p = player()
    if not p then return {} end
    local list = getCell():getZombieList()
    local ranked = {}
    for i = 0, list:size() - 1 do
        local cand = list:get(i)
        ranked[#ranked + 1] = { z = cand, d = cand:DistToProper(p) }
    end
    table.sort(ranked, function(a, b) return a.d < b.d end)
    local out = {}
    for i = 1, math.min(n or 1, #ranked) do
        out[#out + 1] = ranked[i].z
    end
    return out
end

-- 0060f: força kind + índice de guarda-roupa (1–5) no mais perto.
-- Sem args: cicla o índice da variante atual. kind omitido → kind do zumbi (ou estalador).
function NOM.lookVariant(kind, idx)
    require "NOM_VariantLook"
    require "NOM_VariantWardrobe"
    local near = nearestZombies(1)
    local z = near[1]
    if not z then
        NOM_DebugLog.say("[NOM] lookVariant: sem zumbi")
        return nil
    end
    local info = NOM_VariantLook.inspect(z)
    local curKind = kind
    if curKind == nil or curKind == "" then
        local k = info:match("kind=([%w_]+)")
        curKind = (k and k ~= "-") and k or "estalador"
    end
    local n = NOM_VariantWardrobe.count(curKind)
    if n == 0 then
        NOM_VariantLook.forceVariant(z, curKind, 1)
        NOM_DebugLog.say("[NOM] lookVariant " .. curKind .. " → " .. NOM_VariantLook.inspect(z))
        return curKind
    end
    if idx == nil then
        local cur = tonumber(info:match("var=[A-Z](%d+)")) or 0
        idx = NOM_Math.mod(cur, n) + 1
    end
    local k, i = NOM_VariantLook.forceVariant(z, curKind, idx)
    NOM_Debug.send({ op = "variant", id = z:getPersistentOutfitID(), kind = k })
    NOM_DebugLog.say(string.format("[NOM] lookVariant %s #%s → %s",
        tostring(k), tostring(i), NOM_VariantLook.inspect(z)))
    return k, i
end

-- Ajuste 7: grupo forçado um-de-cada + lookInspect de cada. Spawna se faltar gente.
-- Branca/vermelha: E/C/S/K (+alma). Preta: T1/T2/T3 + alma.
function NOM.lookGroup()
    require "NOM_VariantLook"
    require "NOM_FogState"
    local plan
    if NOM_FogState.black then
        plan = {
            { "ticao", 1 }, { "ticao", 2 }, { "ticao", 3 },
        }
    else
        plan = {
            { "estalador", 1 }, -- E1 massa clara
            { "corredor", 1 },
            { "semrosto", 1 },
            { "carpideira", 2 }, -- K2 escura (K3 é rara)
        }
    end
    local need = #plan
    local zs = nearestZombies(need)
    if #zs < need then
        NOM.spawn(need - #zs)
        zs = nearestZombies(need)
    end
    if #zs == 0 then
        NOM_DebugLog.say("[NOM] lookGroup: sem zumbi")
        return nil
    end
    local lines = {}
    for i = 1, math.min(need, #zs) do
        local kind, idx = plan[i][1], plan[i][2]
        NOM_VariantLook.forceVariant(zs[i], kind, idx)
        -- força kind no servidor (exceto preta: todo mundo já é ticao)
        if not NOM_FogState.black then
            NOM_Debug.send({ op = "variant", id = zs[i]:getPersistentOutfitID(), kind = kind })
        end
        local s = NOM_VariantLook.inspect(zs[i])
        lines[#lines + 1] = s
        NOM_DebugLog.say("[NOM] lookGroup[" .. i .. "] " .. s)
    end
    NOM.alma() -- repor almas (preta: causa do print 04)
    NOM_DebugLog.say("[NOM] lookGroup pronto — cole o lookInspect acima no print")
    return lines
end

-- Sprint 0060d/e: isolamento debug — SÓ a flag lookClean (não mexer em LookForce).
-- Sem args: liga/desliga. on=false desliga. Prova Sport+White só com a flag ligada.
function NOM.lookClean(on)
    require "NOM_PanelParams"
    require "NOM_ScreenFxRules"
    require "NOM_VariantLook"
    if on == nil then on = not NOM_ScreenFxRules.lookClean() end
    NOM_ScreenFxRules.setLookClean(on == true)
    if NOM_VariantLook.refreshClean then NOM_VariantLook.refreshClean() end
    local lf = NOM_PanelParams.lookForce()
    if lf == "" then lf = "auto" end
    local s = string.format("clean=%s LookForce=%s (prova só se clean)",
        tostring(NOM_ScreenFxRules.lookClean()), tostring(lf))
    NOM_DebugLog.say("[NOM] lookClean " .. s)
    return s
end

-- I6: seletor Glitch de tela (off / original / bordas). Sem args: cicla. Live → canal no próximo tick.
function NOM.glitch(mode)
    require "NOM_PanelParams"
    local modes = NOM_PanelParams.GLITCH_MODES
    if mode == nil or mode == "" then
        local cur = NOM_PanelParams.glitchMode()
        local i = 1
        for k = 1, #modes do if modes[k] == cur then i = k end end
        mode = modes[(i % #modes) + 1]
    end
    local v = NOM.param("GlitchMode", mode)
    return v
end

-- I6: intensidade 0–200% do glitch do modo. Sem args: mostra. Live → SearchMode.y no próximo tick.
function NOM.glitchIntensity(pct)
    require "NOM_PanelParams"
    if pct == nil then
        local v = NOM_PanelParams.get("GlitchIntensity")
        NOM_DebugLog.say("[NOM] glitchIntensity " .. NOM_PanelParams.format("GlitchIntensity", v))
        return v
    end
    return NOM.param("GlitchIntensity", pct)
end

-- Truques do jogador local (ISAdminPowerUI.lua:31-53): muda e manda pro servidor
-- (sendPlayerExtraInfo, :403); no MP o servidor aplica as regras dele.
local function cheat(name, getter, setter)
    return function(on)
        local p = player()
        if not p then return end
        if on == nil then on = not p[getter](p) end
        p[setter](p, on == true)
        sendPlayerExtraInfo(p)
        NOM_DebugLog.say("[NOM] debug " .. name .. "=" .. tostring(on == true))
    end
end

NOM.god = cheat("god", "isGodMod", "setGodMod")
NOM.noclip = cheat("noclip", "isNoClip", "setNoClip")
NOM.invisible = cheat("invisible", "isInvisible", "setInvisible")

function NOM.panel()
    if NOM_DebugPanel then NOM_DebugPanel.toggle() end
end

-- Névoa branca de verdade (sprint 0033): um pedido só, o servidor decide
-- (NOM_FogEvent.force). Presságio de 3 s (estática na tela), sirene (com o congelamento), a
-- névoa sobe e abre 30 s depois; skip abre já, sem presságio. Com névoa aberta ou sirene
-- contando, fecha e recomeça na cor pedida.
function NOM.setFog(skip)
    NOM_Debug.send({ op = "setFog", red = false, skip = skip })
end

-- Névoa vermelha de verdade: o mesmo pedido, na cor vermelha.
function NOM.setRedFog(skip)
    NOM_Debug.send({ op = "setFog", red = true, skip = skip })
end

-- Névoa preta de verdade (sprint 0038): o mesmo pedido, na cor preta.
function NOM.setBlackFog(skip)
    NOM_Debug.send({ op = "setFog", black = true, skip = skip })
end

-- Termina a névoa aberta ou cancela a sirene (sirenStop no MP).
function NOM.setEndFog() NOM_Debug.fog(false) end

-- O zumbi vivo mais perto, no mesmo andar, vai pro tile do jogador. O servidor move (solo)
-- ou manda o dono mover (dedicado): server/NOM_DebugServer.lua, op pull.
function NOM.getZombie()
    local p = player()
    if not p then return end
    local z = NOM_Debug.nearest(p)
    if not z then
        NOM_DebugLog.say("[NOM] debug nenhum zumbi perto")
        return
    end
    NOM_Debug.send({ op = "pull", id = z:getOnlineID(),
        x = math.floor(p:getX()), y = math.floor(p:getY()), z = math.floor(p:getZ()) })
end

-- Zumbi mais perto vira o tipo número i da lista de NOM_VariantRules.KINDS; 0 desfaz.
function NOM.turnZombie(i)
    local kinds = NOM_VariantRules.KINDS
    if i == nil then i = 0 end
    if type(i) ~= "number" or i ~= math.floor(i) or i < 0 or i > #kinds then
        local list = {}
        for n, k in ipairs(kinds) do list[#list + 1] = n .. " " .. k end
        NOM_DebugLog.say("[NOM] debug uso: NOM.turnZombie(i), 0 desfaz, " .. table.concat(list, ", "))
        return
    end
    if i > 0 and not NOM_FogState.on then
        NOM_DebugLog.say("[NOM] debug variante só aparece com névoa (NOM.setFog(true))")
    end
    NOM_Debug.variant(i > 0 and kinds[i] or nil)
end

-- Modo deus de verdade: god, invisível e zumbis não atacam juntos (ISAdminPowerUI.lua:44,
-- 36, 178); sem argumento inverte pelo isGodMod (:41).
function NOM.godMode(on)
    local p = player()
    if not p then return end
    if on == nil then on = not p:isGodMod() end
    on = on == true
    p:setGodMod(on)
    p:setInvisible(on)
    p:setZombiesDontAttack(on)
    sendPlayerExtraInfo(p)
    NOM_DebugLog.say("[NOM] debug godMode=" .. tostring(on))
end

-- Cinzas / lascas (sprint 0057): sem args imprime; dens,taxa,ar em 0..3 multiplicam o padrão;
-- "reset" volta aos 1. Live só nesta sessão (-debug).
function NOM.ash(density, rate, air)
    require "NOM_FlakeRules"
    local R = NOM_FlakeRules
    if density == "reset" then
        R.resetDebug()
        NOM_DebugLog.say("[NOM] debug cinzas: reset dens=1 taxa=1 ar=1")
        return
    end
    if density ~= nil or rate ~= nil or air ~= nil then
        R.setDebug(density, rate, air)
    end
    local d = R.debugMul()
    local n = (NOM_Flakes and NOM_Flakes.count and NOM_Flakes.count()) or 0
    NOM_DebugLog.say(string.format(
        "[NOM] debug cinzas dens=%.2f taxa=%.2f ar=%.2f vivas=%d baseRate=%d airPer=%.2f",
        d.density, d.rate, d.air, n, R.RATE, R.AIR_PER_RATE))
end

-- Clímax fog (sprint 0047g): imprime look da cor ativa e empurra de novo pro mod3.
function NOM.fogLook()
    require "NOM_FogClimaxRules"
    require "NOM_FogState"
    local color = NOM_FogState.color and NOM_FogState.color() or "white"
    local L = NOM_FogClimaxRules.fromConfig(color)
    NOM_DebugLog.say(string.format(
        "[NOM] debug fogLook color=%s baseH=%.2f haze=%.2f pocketH=%.2f cov=%.3f boost=%.2f agg=%.2f",
        L.color or color, L.baseHeight, L.baseHaze, L.pocketHeight, L.pocketCoverage, L.pocketBoost,
        L.pocketAggression))
    if NOM_FogQualitySync and NOM_FogQualitySync.push then
        NOM_FogQualitySync.push()
        NOM_DebugLog.say("[NOM] debug fogLook: params empurrados pro mod3 (se houver)")
    end
end

-- Foco de vento do mod Volumétrica (tarefa 8 da sprint 0033): parâmetro 11 do mod3.
-- O global só existe com o mod3 carregado (client/NOM_FogQualitySync.lua).
local windOn = false
function NOM.wind(on)
    if NOMRender_setParam == nil then
        NOM_DebugLog.say("[NOM] debug vento precisa do mod Volumétrica (mod3)")
        return
    end
    if on == nil then on = not windOn end
    windOn = on == true
    NOMRender_setParam(11, windOn and 1 or 0)
    NOM_DebugLog.say("[NOM] debug vento=" .. tostring(windOn))
end

-- Texturas próprias do Outro Mundo (sprint 0035): registra se o mundo mudou (o ensure é barato
-- na mesma sessão) e diz quantas estão registradas e quais PNG faltam.
function NOM.ownSprites()
    if not NOM_OwnSprites then
        NOM_DebugLog.say("[NOM] debug sprites próprios: NOM_OwnSprites não carregou")
        return
    end
    local n = NOM_OwnSprites.ensure()
    NOM_DebugLog.say("[NOM] debug sprites próprios: " .. n .. " de " .. NOM_OwnSprites.total() .. " registrados")
    for _, m in ipairs(NOM_OwnSprites.missing()) do NOM_DebugLog.say("[NOM] debug sem textura: " .. m) end
end

-- Almas esqueléticas (sprint 0055): repor / status / reset / cfg (pop, crawler, cores).
require "NOM_AlmaRules"
function NOM.alma() NOM_Debug.send({ op = "alma" }) end
function NOM.almaStatus() NOM_Debug.send({ op = "almaStatus" }) end
function NOM.almaReset()
    NOM_AlmaRules.apply("reset") -- painel atualiza na hora (solo)
    NOM_Debug.send({ op = "almaReset" })
end
-- field: "popMin"|"popMax"|"crawler"|"white"|"red"|"black"; value nil nas cores = toggle.
-- Aplica local (rótulo do painel) e manda valor absoluto ao servidor (evita toggle duplo no solo).
function NOM.almaCfg(field, value)
    if field ~= "popMin" and field ~= "popMax" and field ~= "crawler"
        and field ~= "white" and field ~= "red" and field ~= "black" then
        NOM_DebugLog.say("[NOM] debug uso: NOM.almaCfg(campo, valor) — popMin/popMax/crawler/white/red/black")
        return
    end
    NOM_AlmaRules.apply(field, value)
    if field == "white" or field == "red" or field == "black" then
        value = NOM_AlmaRules.colorEnabled(field)
    elseif field == "popMin" then
        value = NOM_AlmaRules.POP_MIN
    elseif field == "popMax" then
        value = NOM_AlmaRules.POP_MAX
    elseif field == "crawler" then
        value = NOM_AlmaRules.CRAWLER_CHANCE
    end
    NOM_Debug.send({ op = "almaCfg", field = field, value = value })
end

-- Arrasto / Rastejante (sprint 0059, §3.5 caminho A): o zumbi vivo mais perto vira
-- crawler lento (só névoa vermelha/preta). O servidor marca; no solo é o mesmo processo.
function NOM.arrasto()
    local p = player()
    if not p then return end
    local z = NOM_Debug.nearest(p)
    if not z then
        NOM_DebugLog.say("[NOM] debug nenhum zumbi perto")
        return
    end
    local id = z:getOnlineID()
    if id == nil then id = -1 end
    NOM_Debug.send({ op = "arrasto", id = id })
end

-- Perambular (sprint 0036): uma onda agora. O servidor decide (névoa aberta) e quem simula
-- manda os grupos andarem; com -debug, o log diz quantos saíram.
function NOM.wander() NOM_Debug.send({ op = "wander" }) end

-- Sprint 0052: próxima passada do hold da Carpideira calma começa uma caminhada chorando.
function NOM.carpWalk()
    require "NOM_Carpideira"
    NOM_Carpideira.forceWalk = true
    NOM_DebugLog.say("[NOM] carpWalk: próxima Gritadora/Screamer calma anda chorando")
end

-- Sonar do Estalador (sprint 0037): um estalo agora. O servidor escolhe o Estalador mais perto
-- de você (na névoa, até 60 tiles) ou solta o anel nos seus pés; o anel faz o resto.
function NOM.sonar() NOM_Debug.send({ op = "sonar" }) end

-- Ritmo do burst (sprint 0056): "auto" rodízio A→B→C; "A"/"B"/"C" ou 1/2/3 força.
-- Sem argumento só mostra o estado. Aplica local e manda pro servidor.
function NOM.sonarBurst(mode)
    require "NOM_SonarRules"
    if mode == nil then
        NOM_DebugLog.say("[NOM] sonarBurst " .. NOM_SonarRules.burstStatus())
        return
    end
    NOM_SonarRules.setForceBurst(mode)
    NOM_Debug.send({ op = "sonarBurst", mode = mode })
    local f = NOM_SonarRules.forceBurst()
    NOM_DebugLog.say("[NOM] sonarBurst " .. NOM_SonarRules.burstStatus() ..
        (f and (" forçado=" .. NOM_SonarRules.burstId(f)) or " rodízio"))
end

-- Gaps do ritmo alvo (forçado, ou B no auto): delta ms em todos os gaps, ou "reset".
function NOM.sonarGaps(delta)
    require "NOM_SonarRules"
    if delta == "reset" or delta == true then
        NOM_SonarRules.resetGaps()
        NOM_Debug.send({ op = "sonarGaps", reset = true })
        NOM_DebugLog.say("[NOM] sonarGaps reset " .. NOM_SonarRules.burstStatus())
        return
    end
    if type(delta) ~= "number" then
        NOM_DebugLog.say("[NOM] sonarGaps " .. NOM_SonarRules.burstStatus())
        return
    end
    NOM_SonarRules.nudgeGaps(delta)
    NOM_Debug.send({ op = "sonarGaps", delta = delta })
    NOM_DebugLog.say("[NOM] sonarGaps " .. tostring(delta) .. " " .. NOM_SonarRules.burstStatus())
end

-- Grito ambiente agora (sprint 0048): só neste cliente; zero horda.
function NOM.ambientScream()
    if not NOM_AmbientScream then
        NOM_DebugLog.say("[NOM] ambient scream: módulo não carregou")
        return
    end
    local msg = NOM_AmbientScream.play(getSpecificPlayer(0))
    NOM_DebugLog.say("[NOM] ambient scream " .. tostring(msg or "falhou"))
end

-- Tempestade da preta e da vermelha (sprint 0045): relâmpago já perto de você, um poste de fora
-- perto pisca já, e a chuva forçada (liga/desliga) em vez do sorteio de 30% por névoa.
function NOM.thunder() NOM_Debug.send({ op = "thunder" }) end
function NOM.flickerLamp() NOM_Debug.send({ op = "lampFlicker" }) end
function NOM.rain() NOM_Debug.send({ op = "rain" }) end

-- Visão curta (sprint 0036): cegos e vigiados neste processo, que é quem simula os zumbis
-- dele (no solo, todos), e a última onda de perambular que ele aplicou.
-- Tição (sprint 0038): a preta neste processo, quantos Tições ele simula e quantos a luz congela.
-- Luzes fixas perto (sprint 0039): só onde o servidor roda (solo); no cliente de MP, "-".
function NOM.ticao()
    local n = 0
    for _, k in pairs(NOM_NightStats and NOM_NightStats.variants or {}) do
        if k == "ticao" then n = n + 1 end
    end
    local frozen = NOM_TicaoFreeze and NOM_TicaoFreeze.count() or 0
    local fixed = NOM_TicaoLight and NOM_TicaoLight.fixedCount() or "-"
    NOM_DebugLog.say("[NOM] debug ticao preta=" .. tostring(NOM_FogState.black == true) .. " ticoes=" .. n .. " congelados=" .. frozen
        .. " luzes_fixas=" .. fixed)
end

-- Pressão da preta (sprint 0051): nível do sandbox e números ativos (piscar, hold, caça).
function NOM.blackPressure()
    require "NOM_BlackPressureRules"
    local lv = NOM_BlackPressureRules.level(NOM_Config.get("BlackFogPressure"))
    local p = NOM_BlackPressureRules.profile(lv)
    local names = { "leve", "padrao", "pesadelo" }
    NOM_DebugLog.say(string.format(
        "[NOM] debug pressao preta nivel=%d (%s) piscar=%dms chance=%d%% escuro=%d-%dms hold=%dms caca=%dmin/%dtile piscar_caca=%d bias=%.2f poste=%dms/%d%%",
        lv, names[lv] or "?", p.flickerCheckMs, p.flickerChance, p.flickerMinMs, p.flickerMaxMs,
        p.holdMs, p.huntMinutes, p.huntReach, p.huntOnFlickerReach, p.fastBias, p.lampCheckMs, p.lampChance))
end

-- Sprint 0058: knobs live do painel (Almas / Estalador / Cinzas / Look).
function NOM.params()
    require "NOM_PanelParams"
    local s = NOM_PanelParams.snapshot()
    NOM_DebugLog.say("[NOM] debug params:")
    for i = 1, #NOM_PanelParams.KEYS do
        local k = NOM_PanelParams.KEYS[i]
        local mark = NOM_PanelParams.isLive(k) and "*" or " "
        NOM_DebugLog.say(string.format("[NOM] debug params %s %s = %s", mark, k, NOM_PanelParams.format(k, s[k])))
    end
end

-- Empurra NOM_PanelParams pros sistemas reais (0055–0057). Sem isso o dump do
-- copyParams mostrava knobs live que AlmaRules/SonarRules/FlakeRules ignoravam.
local function syncPanelToSystems(which)
    require "NOM_PanelParams"
    local P = NOM_PanelParams
    local all = which == nil or which == "all"
    if (all or which == "almas") and NOM_AlmaRules and NOM_AlmaRules.apply then
        NOM_AlmaRules.apply("popMin", P.get("AlmaPopMin"))
        NOM_AlmaRules.apply("popMax", P.get("AlmaPopMax"))
        NOM_AlmaRules.apply("crawler", P.get("AlmaCrawlerPct") / 100)
        NOM_AlmaRules.apply("white", P.get("AlmaFogWhite") == true)
        NOM_AlmaRules.apply("red", P.get("AlmaFogRed") == true)
        NOM_AlmaRules.apply("black", P.get("AlmaFogBlack") == true)
    end
    if (all or which == "estalador") and NOM_SonarRules then
        local rhythm = P.get("EstaladorRhythm")
        if NOM_SonarRules.setForceBurst then
            if rhythm == "rotate" then
                NOM_SonarRules.setForceBurst("auto")
            else
                NOM_SonarRules.setForceBurst(rhythm)
            end
        end
        local gmin, gmax = P.get("EstaladorGapMinMs"), P.get("EstaladorGapMaxMs")
        if type(gmin) == "number" and type(gmax) == "number" and gmax >= gmin then
            NOM_SonarRules.GAP_MIN_MS = gmin
            NOM_SonarRules.GAP_MAX_MS = gmax
            NOM_SonarRules.GAP_ROLL = gmax - gmin + 1
        end
    end
    if (all or which == "cinzas") and NOM_FlakeRules and NOM_FlakeRules.setDebug then
        NOM_FlakeRules.setDebug(P.get("CinzaDensityMult"), P.get("CinzaRateMult"), nil)
    end
    -- Look: VariantRules.variant() já lê lookKind(); aqui aplica no zumbi mais perto
    -- pra feedback imediato no painel (igual lookCycle / NOM.variant).
    if (all or which == "look") and NOM.variant then
        local kind = P.lookKind and P.lookKind() or nil
        NOM.variant(kind)
    end
end

local function sectionOfParam(key)
    if key == nil then return "all" end
    if key:find("^Alma", 1, false) then return "almas" end
    if key:find("^Estalador", 1, false) then return "estalador" end
    if key:find("^Cinza", 1, false) then return "cinzas" end
    if key == "LookForce" or key == "GlitchMode" or key == "GlitchIntensity" then return "look" end
    return nil
end

function NOM.param(key, value)
    require "NOM_PanelParams"
    if key == nil or key == "" then
        NOM.params()
        return
    end
    if key == "reset" then
        NOM_PanelParams.reset(value) -- value opcional: chave ou nil = tudo
        syncPanelToSystems(sectionOfParam(value))
        NOM_DebugLog.say("[NOM] debug param reset " .. (value and tostring(value) or "all"))
        return NOM_PanelParams.snapshot()
    end
    if value == nil then
        local v = NOM_PanelParams.get(key)
        NOM_DebugLog.say("[NOM] debug param " .. tostring(key) .. " = " .. NOM_PanelParams.format(key, v))
        return v
    end
    local v = NOM_PanelParams.set(key, value)
    -- 0060e: mudar LookForce sai do isolamento (Look limpo ≠ Force)
    if key == "LookForce" then
        require "NOM_ScreenFxRules"
        if NOM_ScreenFxRules.lookClean() then
            NOM_ScreenFxRules.setLookClean(false)
            require "NOM_VariantLook"
            if NOM_VariantLook.refreshClean then NOM_VariantLook.refreshClean() end
            NOM_DebugLog.say("[NOM] lookClean off (LookForce mudou)")
        end
    end
    syncPanelToSystems(sectionOfParam(key))
    NOM_DebugLog.say("[NOM] debug param " .. tostring(key) .. " = " .. NOM_PanelParams.format(key, v) ..
        (NOM_PanelParams.isLive(key) and " (live)" or ""))
    return v
end

-- Sprint 0058b: dump plain dos knobs (e extras ash/sonar/alma se carregados) pra colar no chat.
-- Sem API PZ de clipboard com evidência (pz-api-notes UNKNOWN): imprime no log do painel;
-- tenta Clipboard.setClipboard / Java AWT só via pcall, sem depender disso.
function NOM.copyParams()
    require "NOM_PanelParams"
    local text = NOM_PanelParams.dumpText()
    if NOM_AlmaRules and NOM_AlmaRules.describe then
        text = text .. "\n# AlmaRules\nalma.describe=" .. NOM_AlmaRules.describe()
    end
    if NOM_SonarRules and NOM_SonarRules.burstStatus then
        local force = NOM_SonarRules.forceBurst and NOM_SonarRules.forceBurst()
        local forceId = force and NOM_SonarRules.burstId(force) or "auto"
        text = text .. "\n# SonarRules\nsonar.force=" .. forceId
            .. "\nsonar.status=" .. NOM_SonarRules.burstStatus()
    end
    if NOM_FlakeRules and NOM_FlakeRules.debugMul then
        local d = NOM_FlakeRules.debugMul()
        text = text .. string.format(
            "\n# FlakeRules (ash)\nash.density=%.2f\nash.rate=%.2f\nash.air=%.2f",
            d.density, d.rate, d.air)
    end

    local via = "log"
    if Clipboard ~= nil and type(Clipboard.setClipboard) == "function" then
        local ok = pcall(Clipboard.setClipboard, text)
        if ok then via = "Clipboard.setClipboard" end
    end
    if via == "log" then
        -- Tentativa Java AWT (desktop): sem evidência no repo; se falhar, fica só o log.
        local ok = pcall(function()
            local Toolkit = luajava and luajava.bindClass and luajava.bindClass("java.awt.Toolkit")
            if not Toolkit then error("sem luajava") end
            local clip = Toolkit:getDefaultToolkit():getSystemClipboard()
            local StrSel = luajava.bindClass("java.awt.datatransfer.StringSelection")
            clip:setContents(StrSel:new(text), nil)
        end)
        if ok then via = "java.awt.Clipboard" end
    end

    NOM_DebugLog.say("[NOM] debug copyParams via=" .. via .. " — cole do log se o clipboard falhar:")
    for line in string.gmatch(text, "[^\n]+") do
        NOM_DebugLog.say(line)
    end
    return text
end

function NOM.blind()
    if not NOM_VariantAI then
        NOM_DebugLog.say("[NOM] debug visão curta: NOM_VariantAI não carregou")
        return
    end
    local c = NOM_VariantAI.counts()
    NOM_DebugLog.say("[NOM] debug visão curta ligada=" .. tostring(c.on) .. " raio=" .. tostring(NOM_Config.get("FogZombieVision")) ..
        " cegos=" .. c.common .. " vigiados=" .. c.watched .. " estaladores=" .. c.estalador)
    local w = NOM_Wander and NOM_Wander.last
    if w then
        NOM_DebugLog.say("[NOM] debug perambular última zumbis=" .. #w.groups .. " candidatos=" .. w.candidates ..
            " jogadores=" .. w.players .. " lista=" .. w.size)
    else
        NOM_DebugLog.say("[NOM] debug perambular: nenhuma onda neste processo ainda")
    end
end

NOM.HELP = {
    { "NOM.setFog(skip)", "névoa sempre branca: 3 s de estática na tela, sirene (zumbis congelam), a névoa sobe e os bichos soltam em 30 s; setFog(true) abre na hora; com névoa aberta ou sirene contando, recomeça" },
    { "NOM.setRedFog(skip)", "névoa sempre vermelha: 3 s de estática na tela, sirene vermelha, a névoa sobe e os bichos soltam em 30 s; setRedFog(true) abre na hora; com névoa aberta ou sirene contando, recomeça" },
    { "NOM.setBlackFog(skip)", "névoa sempre preta: presságio, sirene fora de sintonia, escuridão e Tições; skip abre já" },
    { "NOM.setEndFog()", "termina a névoa aberta ou cancela a sirene" },
    { "NOM.getZombie()", "puxa o zumbi vivo mais perto (mesmo andar) pra cima de você" },
    { "NOM.turnZombie(i)", "zumbi mais perto vira o tipo i: 1 estalador, 2 corredor, 3 semrosto, 4 carpideira; 0 desfaz (só na névoa)" },
    { "NOM.godMode(on)", "deus + invisível + zumbis não atacam, juntos; sem argumento inverte" },
    { "NOM.fogLook()", "clímax fog: imprime altura da base, véu e bolsões do sandbox e empurra pro mod3" },
    { "NOM.wind(on)", "foco de vento do mod Volumétrica (mod3); sem argumento inverte" },
    { "NOM.fog(on, skip)", "névoa: true sirene, a névoa sobe e os bichos soltam em 30 s, (true, true) já, false termina; sem argumento inverte (e cancela a sirene)" },
    { "NOM.redFog(on)", "névoa vermelha: true força (com névoa aberta vira na hora), false desfaz; sem argumento inverte" },
    { "NOM.night(on)", "noite forçada (true) ou dia forçado (false); sem argumento inverte; NOM_Debug.night() volta pro relógio" },
    { "NOM.time(hora)", "muda a hora do relógio do jogo, sempre pra frente (hora que já passou é a de amanhã), ex.: NOM.time(22)" },
    { "NOM.spawn(n, outfit)", "n zumbis (até 50) espalhados 3 tiles na sua frente; outfit opcional, ex.: NOM.spawn(5, \"Police\")" },
    { "NOM.variant(tipo)", "zumbi mais perto vira \"estalador\", \"corredor\", \"semrosto\" ou \"carpideira\" (só na névoa); sem tipo desfaz" },
    { "NOM.lookCycle()", "cicla looks horror 0054 no mais perto: Pale→Misaligned→Wrong→Patient→desfaz (só na névoa)" },
    { "NOM.lookInspect()", "dump pele + ItemVisuals do zumbi mais perto (0060b)" },
    { "NOM.lookVariant(kind, idx)", "guarda-roupa E1–E5 / C/T/S/K/A no mais perto; sem args cicla o índice" },
    { "NOM.lookGroup()", "força 1 de cada monstro (+alma) e imprime lookInspect de cada" },
    { "NOM.lookClean()", "liga/desliga isolamento (FX off + Sport/White); não muda LookForce" },
    { "NOM.glitch(mode)", "Glitch de tela: \"off\" / \"original\" / \"bordas\"; sem args cicla; live no canal do shader" },
    { "NOM.glitchIntensity(pct)", "intensidade do glitch 0–200% (padrão 100); multiplica tear/scanline/static do modo" },
    { "NOM.eco()", "um Eco nos seus pés (só à noite)" },
    { "NOM.alma()", "repor almas esqueléticas agora (névoa com a cor ligada): rua, ciclo 4–20, maioria crawler" },
    { "NOM.almaStatus()", "pop min/max, % crawler, cores ligadas e quantas almas vivas" },
    { "NOM.almaReset()", "volta pop/crawler/cores das almas pro padrão (4–20, 68%, 3 cores)" },
    { "NOM.almaCfg(campo, valor)", "ajusta almas: popMin/popMax/crawler (0–1) / white|red|black (bool ou nil=toggle)" },
    { "NOM.arrasto()", "zumbi mais perto vira Arrasto (crawler lento; só névoa vermelha ou preta) — spike §3.5" },
    { "NOM.ash(dens, taxa, ar)", "cinzas: sem args mostra knobs e vivas; dens/taxa/ar em 0..3 multiplicam (live); ash(\"reset\") volta ao padrão" },
    { "NOM.god(on)", "modo deus; sem argumento inverte" },
    { "NOM.noclip(on)", "atravessa paredes; sem argumento inverte" },
    { "NOM.invisible(on)", "zumbis não te veem; sem argumento inverte" },
    { "NOM.status()", "estado do mod, local e do servidor" },
    { "NOM.ownSprites()", "quantas texturas próprias do Outro Mundo (Silent Hill) estão registradas e quais faltam" },
    { "NOM.wander()", "uma onda de perambular agora (só com névoa aberta): grupos de 1 a 3 zumbis parados perto de você saem andando" },
    { "NOM.carpWalk()", "próxima Gritadora/Screamer calma (dona neste processo) anda chorando agora — piloto Witch (0052)" },
    { "NOM.sonar()", "o Estalador mais perto (na névoa, até 60 tiles) estala agora; sem ele, o anel sai dos seus pés. Em pé ou andando o anel te acha; agachado e parado passa" },
    { "NOM.sonarBurst(mode)", "ritmo do Estalador: \"auto\" (rodízio A→B→C), \"A\", \"B\", \"C\" (ou 1/2/3) força a variação; sem argumento mostra o estado" },
    { "NOM.sonarGaps(delta)", "gaps do ritmo alvo (forçado, ou B no auto): +50/−50 ms em todos; \"reset\" devolve o padrão; sem argumento mostra" },
    { "NOM.ambientScream()", "grito ambiente distante agora (só neste cliente; zero horda; precisa névoa + FogAmbience; preta = off)" },
    { "NOM.thunder()", "relâmpago e trovão agora perto de você (na preta, o clarão congela os Tições por 1 s)" },
    { "NOM.flickerLamp()", "um poste aceso de fora perto de você (até 25 tiles) pisca agora" },
    { "NOM.rain()", "força a chuva nas névoas pretas e vermelhas (liga/desliga); desligado, chove em 30% delas" },
    { "NOM.ticao()", "névoa preta: quantos Tições este processo simula e quantos a luz congela agora" },
    { "NOM.blackPressure()", "névoa preta: nível de pressão do sandbox (Leve/Padrão/Pesadelo) e números ativos" },
    { "NOM.blind()", "visão curta da névoa: quantos zumbis estão cegos e vigiados agora, e a última onda de perambular" },
    { "NOM.params()", "lista os knobs live do painel (Almas, Estalador, Cinzas, Look); * = override da sessão" },
    { "NOM.param(key, value)", "lê ou grava um knob live; NOM.param(\"reset\") limpa tudo; NOM.param(\"reset\", chave) limpa uma" },
    { "NOM.copyParams()", "copia as definições live (chave=valor) pro clipboard se der; senão imprime no log do painel pra colar no chat" },
    { "NOM.panel()", "abre ou fecha o painel de debug (tecla nas opções do mod, padrão Insert)" },
    { "NOM.help()", "esta lista" },
}

function NOM.help()
    for _, h in ipairs(NOM.HELP) do NOM_DebugLog.say("[NOM] " .. h[1] .. " - " .. h[2]) end
end

return NOM
