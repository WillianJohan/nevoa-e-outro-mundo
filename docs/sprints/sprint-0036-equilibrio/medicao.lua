-- Tarefa 0 da sprint 0036: quanto custa, por tick, estender a cegueira do Estalador
-- a todo zumbi comum, com 300 zumbis carregados. Rodar da raiz do repo:
--   luajit -joff docs/sprints/sprint-0036-equilibrio/medicao.lua
-- Conta idas ao Java (toda chamada de método em objeto do jogo, mais instanceof) e o
-- tempo do Lua puro no luajit sem JIT (só pra comparar as versões entre si: o Kahlua é
-- bem mais lento, a proporção é o que vale).
local N, FRAMES = 300, 600
local calls = 0

local function obj(fields)
    local o = {}
    for k, v in pairs(fields) do
        if type(v) == "function" then
            o[k] = function(...) calls = calls + 1; return v(...) end
        else
            o[k] = v
        end
    end
    return o
end

local player = obj({ x = 0, y = 0, class = "IsoPlayer",
    getX = function(s) return s.x end, getY = function(s) return s.y end,
    isRunning = function() return false end, isSprinting = function() return false end,
    isSneaking = function() return false end })

-- cenário: "idle" (ninguém com alvo) ou "crowd" (todos com o jogador de alvo, a 6–10 tiles)
local function world(scene)
    local zs = {}
    for i = 1, N do
        local z = obj({ x = 6 + (i % 5), y = i % 7,
            getX = function(s) return s.x end, getY = function(s) return s.y end,
            isLocal = function() return true end, getTarget = function(s) return s.target end,
            getModData = function(s) return s.md end, isUseless = function() return false end })
        z.md = {}
        z.target = scene == "crowd" and player or nil
        zs[i] = z
    end
    local list = obj({ size = function() return #zs end, get = function(_, i) return zs[i + 1] end })
    return zs, list
end

local function instanceof(o, cls) calls = calls + 1; return o.class == cls end

-- a pergunta da cegueira estendida, por zumbi: alvo jogador, longe e quieto?
local R2 = 4 * 4
local function far(z, t)
    local dx, dy = z:getX() - t:getX(), z:getY() - t:getY()
    return dx * dx + dy * dy > R2
end
local function quiet(t) return not t:isRunning() and not t:isSprinting() end
local function check(z)
    if not z:isLocal() then return end
    local t = z:getTarget()
    if t ~= nil and instanceof(t, "IsoPlayer") and quiet(t) and far(z, t) then return true end
end

local variants, blinded, still = {}, {}, {}

-- hoje: OnZombieUpdate, o comum sai com três consultas de tabela
local function today(z)
    if variants[z] == nil and blinded[z] == nil and still[z] == nil then return end
end

-- ingênuo: OnZombieUpdate pergunta pra todo zumbi comum, todo frame
local function naive(z)
    if variants[z] ~= nil or blinded[z] ~= nil or still[z] ~= nil then return end
    check(z)
end

-- em fatias: OnTick, BATCH zumbis por tick em volta na lista; o resto do tempo, o
-- OnZombieUpdate do comum segue como hoje (sem Java)
local function sliced(list, batch, cursor)
    local size = list:size()
    local n = math.min(batch, size)
    for k = 0, n - 1 do
        local z = list:get((cursor + k) % size)
        if variants[z] == nil and blinded[z] == nil and still[z] == nil then check(z) end
    end
    return (cursor + n) % size
end

local function run(label, scene, perTick)
    local zs, list = world(scene)
    calls = 0
    local t0 = os.clock()
    local cursor = 0
    for _ = 1, FRAMES do cursor = perTick(zs, list, cursor) or cursor end
    local dt = os.clock() - t0
    print(string.format("%-28s %-6s %7.1f chamadas/tick  %6.2f us Lua/tick", label, scene,
        calls / FRAMES, dt * 1e6 / FRAMES))
end

for _, scene in ipairs({ "idle", "crowd" }) do
    run("hoje (variantes)", scene, function(zs) for _, z in ipairs(zs) do today(z) end end)
    run("ingenuo (todo frame)", scene, function(zs) for _, z in ipairs(zs) do naive(z) end end)
    for _, b in ipairs({ 20, 30, 50 }) do
        run("fatias BATCH=" .. b, scene, function(zs, list, c)
            for _, z in ipairs(zs) do today(z) end
            return sliced(list, b, c)
        end)
    end
end
