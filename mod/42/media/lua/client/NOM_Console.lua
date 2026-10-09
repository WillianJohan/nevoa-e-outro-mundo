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

-- Perambular (sprint 0036): uma onda agora. O servidor decide (névoa aberta) e quem simula
-- manda os grupos andarem; com -debug, o log diz quantos saíram.
function NOM.wander() NOM_Debug.send({ op = "wander" }) end

-- Sprint 0052: próxima passada do hold da Carpideira calma começa uma caminhada chorando.
function NOM.carpWalk()
    require "NOM_Carpideira"
    NOM_Carpideira.forceWalk = true
    NOM_DebugLog.say("[NOM] carpWalk: próxima Carpideira calma anda chorando")
end

-- Sonar do Estalador (sprint 0037): um estalo agora. O servidor escolhe o Estalador mais perto
-- de você (na névoa, até 60 tiles) ou solta o anel nos seus pés; o anel faz o resto.
function NOM.sonar() NOM_Debug.send({ op = "sonar" }) end

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
    { "NOM.eco()", "um Eco nos seus pés (só à noite)" },
    { "NOM.alma()", "repor almas esqueléticas agora (névoa com a cor ligada): rua, ciclo 4–20, maioria crawler" },
    { "NOM.almaStatus()", "pop min/max, % crawler, cores ligadas e quantas almas vivas" },
    { "NOM.almaReset()", "volta pop/crawler/cores das almas pro padrão (4–20, 68%, 3 cores)" },
    { "NOM.almaCfg(campo, valor)", "ajusta almas: popMin/popMax/crawler (0–1) / white|red|black (bool ou nil=toggle)" },
    { "NOM.god(on)", "modo deus; sem argumento inverte" },
    { "NOM.noclip(on)", "atravessa paredes; sem argumento inverte" },
    { "NOM.invisible(on)", "zumbis não te veem; sem argumento inverte" },
    { "NOM.status()", "estado do mod, local e do servidor" },
    { "NOM.ownSprites()", "quantas texturas próprias do Outro Mundo (Silent Hill) estão registradas e quais faltam" },
    { "NOM.wander()", "uma onda de perambular agora (só com névoa aberta): grupos de 1 a 3 zumbis parados perto de você saem andando" },
    { "NOM.carpWalk()", "próxima Carpideira calma (dona neste processo) anda chorando agora — pra testar o piloto Witch (0052)" },
    { "NOM.sonar()", "o Estalador mais perto (na névoa, até 60 tiles) estala agora; sem ele, o anel sai dos seus pés. Em pé ou andando o anel te acha; agachado e parado passa" },
    { "NOM.ambientScream()", "grito ambiente distante agora (só neste cliente; zero horda; precisa névoa + FogAmbience; preta = off)" },
    { "NOM.thunder()", "relâmpago e trovão agora perto de você (na preta, o clarão congela os Tições por 1 s)" },
    { "NOM.flickerLamp()", "um poste aceso de fora perto de você (até 25 tiles) pisca agora" },
    { "NOM.rain()", "força a chuva nas névoas pretas e vermelhas (liga/desliga); desligado, chove em 30% delas" },
    { "NOM.ticao()", "névoa preta: quantos Tições este processo simula e quantos a luz congela agora" },
    { "NOM.blackPressure()", "névoa preta: nível de pressão do sandbox (Leve/Padrão/Pesadelo) e números ativos" },
    { "NOM.blind()", "visão curta da névoa: quantos zumbis estão cegos e vigiados agora, e a última onda de perambular" },
    { "NOM.panel()", "abre ou fecha o painel de debug (tecla nas opções do mod, padrão Insert)" },
    { "NOM.help()", "esta lista" },
}

function NOM.help()
    for _, h in ipairs(NOM.HELP) do NOM_DebugLog.say("[NOM] " .. h[1] .. " - " .. h[2]) end
end

return NOM
