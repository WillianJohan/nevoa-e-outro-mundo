-- Regras puras da luz que congela o Tição (sprint 0038): sem API do jogo, testável com
-- ./run-tests.sh. Quem lê as luzes no jogo é o server/NOM_TicaoLight.lua; aqui só a
-- geometria e o ritmo.
--
-- Luz = { kind = "beam" | "radius", x, y, z, fx, fy (direção, unitária), range, dot }.
-- Os números das lanternas vêm dos scripts vanilla (media/scripts/generated/items/drainable.txt):
-- HandTorch LightDistance 15, TorchCone true, TorchDot 0,5; Torch 25 / 0,66; PenLight 11 / 0,75;
-- lampiões 15 (elétrico 10) sem cone; isqueiro 5 sem cone. O TorchDot é o cosseno do meio
-- ângulo do cone (0,5 = 60° pra cada lado).
NOM_LightRules = {}

local R = NOM_LightRules

-- Lampião (sem cone) só conta com alcance a partir de LANTERN_MIN; vira um raio pequeno em volta
-- do jogador. Isqueiro e vela (alcance 5) não congelam ninguém.
R.LANTERN_MIN = 10
R.LANTERN_RADIUS = 4
-- Farol de carro: um raio em volta do carro (o Lua não tem a direção do carro sem Vector3f).
R.HEADLIGHT_RADIUS = 8
-- Folga do corpo do zumbi (tiles): a borda do cone pega quem está meio dentro.
R.BODY = 0.6
-- Ritmo: o rodízio cobre todos os zumbis a cada SWEEP_MS; aceso fica congelado até HOLD_MS
-- depois de sair da luz; sem lista do servidor por SILENCE_MS, o dono solta todos.
R.SWEEP_MS = 250
R.HOLD_MS = 500
R.SILENCE_MS = 1500
-- Lanterna que pisca (tarefa 5): a cada FLICKER_CHECK_MS, cada lanterna acesa na preta tem
-- FLICKER_CHANCE% de apagar por FLICKER_MIN_MS..FLICKER_MAX_MS. Apagada, não congela ninguém.
R.FLICKER_CHECK_MS = 10000
R.FLICKER_CHANCE = 25
R.FLICKER_MIN_MS = 700
R.FLICKER_MAX_MS = 1600

-- Luz do item na mão (sem posição): nil quando não congela.
function R.fromItem(cone, distance, dot)
    distance = tonumber(distance) or 0
    if cone then
        if distance <= 0 then return nil end
        return { kind = "beam", range = distance, dot = tonumber(dot) or 0.5 }
    end
    if distance < R.LANTERN_MIN then return nil end
    return { kind = "radius", range = R.LANTERN_RADIUS }
end

function R.headlight()
    return { kind = "radius", range = R.HEADLIGHT_RADIUS }
end

-- O zumbi em (zx, zy, zz) está na luz l?
function R.lit(l, zx, zy, zz)
    if math.floor(zz) ~= l.z then return false end
    local dx, dy = zx - l.x, zy - l.y
    local d2 = dx * dx + dy * dy
    local reach = l.range + R.BODY
    if d2 > reach * reach then return false end
    if l.kind ~= "beam" or d2 <= R.BODY * R.BODY then return true end
    local proj = dx * l.fx + dy * l.fy
    if proj <= 0 then return false end
    local dot = math.max(0.05, math.min(l.dot, 0.999))
    local perp = math.abs(dx * l.fy - dy * l.fx)
    return perp <= proj * math.sqrt(1 - dot * dot) / dot + R.BODY
end

-- Quantos zumbis conferir neste tick pra cobrir size a cada SWEEP_MS, com dtMs desde o último.
function R.batch(size, dtMs)
    if size <= 0 then return 0 end
    local n = math.ceil(size * math.max(dtMs or 0, 0) / R.SWEEP_MS)
    return math.max(1, math.min(size, n))
end

-- Luz fixa (sprint 0039): poste, abajur e fogo (IsoLightSource da lista de postes) viram um raio
-- de até FIXED_MAX tiles; abaixo de FIXED_MIN (vela) não congelam. A lista é varrida em fatias de
-- FIXED_BATCH por tick, uma volta a cada FIXED_EVERY_MS, e só fica quem está a até FIXED_NEAR
-- tiles de um jogador.
R.FIXED_MIN = 3
R.FIXED_MAX = 8
R.FIXED_BATCH = 40
R.FIXED_EVERY_MS = 2000
R.FIXED_NEAR = 40

-- Luz fixa com raio radius: nil quando não congela. hydro: ligada à rede; powered: o square tem
-- rede ou gerador (a mesma regra do IsoLightSource.update, pz-api-notes §31).
function R.fixed(radius, active, hydro, powered)
    radius = tonumber(radius) or 0
    if not active or (hydro and not powered) or radius < R.FIXED_MIN then return nil end
    return { kind = "radius", range = math.min(radius, R.FIXED_MAX) }
end

-- Interruptor do cômodo aceso? Ligado, com lâmpada, e bateria com carga (abajur a pilha) ou
-- rede/gerador (mains).
function R.switchLit(on, bulb, battery, charge, mains)
    if not on or not bulb then return false end
    if battery then return (tonumber(charge) or 0) > 0 end
    return mains == true
end

-- roll: 0..99 (ZombRand(100)); rollMs: 0..1 (sorteio da duração). Devolve a duração ou nil.
function R.flicker(roll, rollMs)
    if roll >= R.FLICKER_CHANCE then return nil end
    return math.floor(R.FLICKER_MIN_MS + (R.FLICKER_MAX_MS - R.FLICKER_MIN_MS) * (rollMs or 0))
end

return NOM_LightRules
