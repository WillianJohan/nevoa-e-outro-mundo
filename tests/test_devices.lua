-- client/NOM_Devices.lua (solo e cliente de MP) contra o mundo falso de tests/fog_world.lua
-- mais os aparelhos. O que os fakes imitam (bytecode B42, docs/architecture/pz-api-notes.md §22):
-- * getZomboidRadio():getDevices(): ArrayList<WaveSignalDevice> (size/get) com todo
--   IsoWaveSignal (TV, rádio) e toda VehiclePart com DeviceData em chunk carregado.
-- * WaveSignalDevice: getX/getY/getZ (float; a parte do carro devolve a posição do carro),
--   getDeviceData(). VehiclePart: getVehicle(), getInventoryItem() (nil = sem rádio instalado).
-- * DeviceData: getIsTelevision, getIsTurnedOn, getIsBatteryPowered, getPower,
--   canBePoweredHere, isVehicleDevice. Mudar o estado (setIsTurnedOn, playSoundSend...) explode:
--   vai pro save e pra rede.
-- * getWorld():getFreeEmitter(x, y, z) e o emitter do pool: tests/fog_world.lua (G.newEmitter).
-- * BaseVehicle: playSoundImpl(nome, nil) = getEmitter():playSoundImpl; playSound explode.
-- * addSound (chama zumbi) explode: é só atmosfera.
local W = dofile("tests/fog_world.lua")
local FILE = "mod/42/media/lua/client/NOM_Devices.lua"

local function jlist(items)
    return { size = function() return #items end, get = function(_, i) return items[i + 1] end }
end

local function boom(what)
    return function() error(what, 2) end
end

local function world(G)
    G.devices = {}
    G.devicesCalls = 0
    getZomboidRadio = function()
        return { getDevices = function()
            G.devicesCalls = G.devicesCalls + 1
            return jlist(G.devices)
        end }
    end
    addSound = boom("addSound chama zumbi: aparelho é só atmosfera")

    local function data(o)
        local dd = {
            getIsTelevision = function() return o.tv == true end,
            getIsTurnedOn = function() return o.on == true end,
            getIsBatteryPowered = function() return o.battery ~= nil end,
            getPower = function() return o.battery or 0 end,
            canBePoweredHere = function() return o.grid == true end,
            isVehicleDevice = function() return o.car == true end,
            setIsTurnedOn = boom("setIsTurnedOn muda o aparelho (save e rede)"),
            setTurnedOnRaw = boom("setTurnedOnRaw muda o aparelho"),
            playSoundSend = boom("playSoundSend manda pacote"),
            playSoundLocal = boom("o emitter do aparelho só existe ligado e perto"),
        }
        return dd
    end

    -- TV ou rádio no chão: { x, y, z, tv, on, grid, battery }
    function G.device(o)
        local d = { o = o }
        function d:getX() return o.x end
        function d:getY() return o.y end
        function d:getZ() return o.z or 0 end
        function d:getDeviceData() return self.dd end
        d.dd = data(o)
        G.devices[#G.devices + 1] = d
        return d
    end

    -- carro com a peça "Radio": { x, y, z, installed, on, battery }
    function G.car(o)
        local v = { x = o.x + 0.5, y = o.y + 0.5, z = o.z or 0 }
        v.emitter = G.newEmitter({ x = v.x, y = v.y, z = v.z, vehicle = v })
        function v:getEmitter() return self.emitter end
        function v:playSoundImpl(name, obj) return self.emitter:playSoundImpl(name, obj) end
        v.playSound = boom("vehicle:playSound manda pacote")
        local part = { vehicle = v }
        function part:getX() return v.x end
        function part:getY() return v.y end
        function part:getZ() return v.z end
        function part:getVehicle() return v end
        function part:getInventoryItem() return o.installed ~= false and { radio = true } or nil end
        function part:getDeviceData() return self.dd end
        part.dd = data({ car = true, on = o.on, grid = (o.battery or 0) > 0 })
        G.devices[#G.devices + 1] = part
        return v, part
    end
end

local function setup(opts)
    opts = opts or {}
    local G = W.new(opts)
    world(G)
    G.reload({ "NOM_FogState", "NOM_SemRosto", "NOM_NightStats", "NOM_Carpideira", "NOM_DeviceRules", "NOM_Devices" })
    require "NOM_SemRosto"
    require "NOM_Carpideira"
    NOM_SemRosto.install(function() end) -- no solo o server/NOM_Fog.lua instala
    G.ticksBefore = #(G.handlers.OnTick or {})
    dofile(FILE)
    G.p = G.player({ x = 100, y = 100, face = 0 })
    return G
end

local DEV = { NOM_DevTv = true, NOM_DevTvRed = true, NOM_DevTvBlack = true, NOM_DevRadio = true,
    NOM_DevRadioRed = true, NOM_DevRadioBlack = true, NOM_DevSpeaker = true, NOM_DevCar = true }

local function talking(G)
    local out = {}
    for _, s in pairs(G.sounds) do
        if DEV[s.name] and s.playing then out[#out + 1] = s end
    end
    return out
end

local function bursts(G)
    return G.playing("NOM_DevBurst")
end

-- som tocando no tile (x, y) do aparelho
local function at(s, x, y) return s.at.x == x + 0.5 and s.at.y == y + 0.5 end

local function open(G, red)
    NOM_FogState.set(true, 1, red)
    G.seconds(NOM_DeviceRules.CALL_MIN_MS / 1000 + 2)
end

return {
    devices_inert_on_dedicated = function()
        local G = setup({ server = true })
        assert(#G.handlers.OnTick == G.ticksBefore, "servidor dedicado registrou aparelhos")
    end,
    -- presságio: todo aparelho a até 25 tiles estoura; a sirene corta
    devices_omen_burst_cut_by_siren = function()
        local G = setup()
        G.device({ x = 110, y = 100 })
        G.device({ x = 100, y = 120, tv = true })
        G.device({ x = 130, y = 100 }) -- 30 tiles: fora
        G.car({ x = 95, y = 100, battery = 0 })
        NOM_FogState.setOmen(false)
        G.seconds(0.5)
        local b = bursts(G)
        assert(#b == 3, "estouros: " .. #b)
        for _, s in ipairs(b) do assert(not at(s, 130, 100), "estourou a 30 tiles") end
        G.seconds(0.5)
        assert(G.played("NOM_DevBurst") == 3, "estourou de novo no mesmo presságio")
        NOM_FogState.setRising(true) -- a sirene
        G.seconds(0.3)
        assert(#bursts(G) == 0, "o estouro passou da sirene")
        G.seconds(40)
        assert(#talking(G) == 0 and G.played("NOM_DevBurst") == 3, "aparelho falou na fuga")
    end,
    -- toca no aparelho certo: o mais perto entre 6 e 18 tiles, no tile dele
    devices_call_plays_on_right_device = function()
        local G = setup()
        G.device({ x = 103, y = 100 })            -- perto demais
        G.device({ x = 100, y = 109 })            -- o certo
        G.device({ x = 115, y = 100, tv = true })
        NOM_FogState.set(true, 1)
        G.seconds(NOM_DeviceRules.CALL_MIN_MS / 1000 - 5)
        assert(#talking(G) == 0, "falou antes do intervalo")
        G.seconds(7)
        local t = talking(G)
        assert(#t == 1, "falando: " .. #t)
        assert(at(t[1], 100, 109) and t[1].name == NOM_DeviceRules.sound(NOM_DeviceRules.voice(100, 109, 0), "white"),
            "som errado ou no lugar errado: " .. t[1].name)
        assert(t[1].volume < 1, "desligado falando alto")
    end,
    -- nunca dois ao mesmo tempo; o mesmo arquivo não repete em 3 chamados
    devices_one_at_a_time = function()
        local G = setup()
        G.device({ x = 108, y = 100, tv = true })
        G.device({ x = 100, y = 110, tv = true })
        G.car({ x = 90, y = 90, battery = 1 })
        NOM_FogState.set(true, 1)
        local order = {}
        for _ = 1, 30 * 60 do
            G.seconds(1)
            assert(#talking(G) <= 1, "dois aparelhos ao mesmo tempo")
            for _, s in ipairs(talking(G)) do
                if order[#order] ~= s then order[#order + 1] = s end
            end
            for _, s in ipairs(talking(G)) do s.playing = false end -- o som acaba (one-shot)
        end
        assert(#order >= 6, "chamados em 30 min: " .. #order)
        for i = 2, #order do
            assert(order[i].name ~= order[i - 1].name, "repetiu no chamado seguinte")
        end
    end,
    -- ligado com energia tem prioridade e fala mais alto
    devices_live_priority = function()
        local G = setup()
        G.device({ x = 107, y = 100 })
        G.device({ x = 100, y = 116, on = true, grid = true })
        open(G)
        local t = talking(G)
        assert(#t == 1 and at(t[1], 100, 116), "ligado sem prioridade")
        assert(t[1].volume == 1, "ligado sem volume cheio")
    end,
    -- rádio de carro: pela peça Radio, no emitter do carro (segue o carro); sem rádio, nada
    devices_car_radio = function()
        local G = setup()
        local v = G.car({ x = 110, y = 100, battery = 0 })
        G.car({ x = 100, y = 108, installed = false })
        open(G)
        local t = talking(G)
        assert(#t == 1 and t[1].name == "NOM_DevCar", "carro não falou")
        assert(t[1].vehicle == v, "não tocou no emitter do carro")
    end,
    devices_red_fog_sounds = function()
        local G = setup()
        G.device({ x = 108, y = 100, tv = true })
        open(G, true)
        local t = talking(G)
        assert(#t == 1 and t[1].name == "NOM_DevTvRed", tostring(t[1] and t[1].name))
    end,
    -- para fora do raio: o FMOD não zera depois do distanceMax
    devices_stop_out_of_range = function()
        local G = setup()
        local _, part = G.car({ x = 110, y = 100, battery = 1 })
        open(G)
        assert(#talking(G) == 1)
        part.vehicle.x = 125 -- o carro andou: 25 tiles
        G.seconds(1)
        assert(#talking(G) == 0, "continuou tocando a 25 tiles")
    end,
    devices_stop_when_fog_ends = function()
        local G = setup()
        G.device({ x = 108, y = 100 })
        open(G)
        assert(#talking(G) == 1)
        NOM_FogState.set(false, 1)
        G.seconds(0.3)
        assert(#talking(G) == 0, "aparelho falando na calmaria")
        G.seconds(400)
        assert(#talking(G) == 0 and G.played("NOM_DevRadio") + G.played("NOM_DevSpeaker") == 1, "falou sem névoa")
    end,
    devices_stop_when_player_dies = function()
        local G = setup()
        G.device({ x = 108, y = 100 })
        open(G)
        G.p.dead = true
        G.seconds(0.3)
        assert(#talking(G) == 0, "aparelho falando pro morto")
    end,
    -- Sem-rosto a até 10 tiles de um aparelho: ele chia junto, sem esperar o chamado
    devices_semrosto_near_device = function()
        local G = setup()
        G.device({ x = 112, y = 100 })
        G.device({ x = 100, y = 108 })
        NOM_FogState.set(true, 1)
        G.zombie({ x = 118, y = 100, id = W.semRostoID(1, true) })
        G.seconds(2)
        local b = bursts(G)
        assert(#b == 1 and at(b[1], 112, 100), "o aparelho perto do Sem-rosto não chiou")
        assert(#talking(G) == 0, "dois ao mesmo tempo")
    end,
    -- grito da Carpideira na vermelha: o aparelho perto respira (som vermelho)
    devices_scream_breath_red = function()
        local G = setup()
        G.device({ x = 112, y = 100 }) -- voz de rádio (R.voice)
        NOM_FogState.set(true, 1, true)
        G.seconds(2)
        local z = G.zombie({ x = 120, y = 100, id = 7 })
        NOM_Carpideira.scream(z, G.p)
        G.seconds(0.3)
        local t = talking(G)
        assert(#t == 1 and t[1].name == "NOM_DevRadioRed" and at(t[1], 112, 100), "não respirou")
    end,
    devices_no_scream_breath_in_white = function()
        local G = setup()
        G.device({ x = 110, y = 100 })
        NOM_FogState.set(true, 1)
        G.seconds(2)
        NOM_Carpideira.scream(G.zombie({ x = 120, y = 100, id = 7 }), G.p)
        G.seconds(0.3)
        assert(#talking(G) == 0, "respirou na branca")
    end,
    devices_off_with_fog_ambience = function()
        local G = setup({ sandbox = { FogAmbience = false } })
        G.device({ x = 108, y = 100 })
        NOM_FogState.setOmen(false)
        G.seconds(1)
        NOM_FogState.set(true, 1)
        G.seconds(400)
        assert(#G.pool == 0 and #talking(G) == 0, "ambiente desligado e o aparelho falou")
    end,
    -- custo: a lista do jogo no máximo uma vez por segundo, nada de varrer quadrados
    devices_scan_cost = function()
        local G = setup()
        for i = 1, 50 do G.device({ x = 50 + i, y = 140 }) end
        NOM_FogState.set(true, 1)
        G.devicesCalls = 0
        local sq = G.sqCalls
        G.seconds(30)
        assert(G.devicesCalls <= 31, "lista lida " .. G.devicesCalls .. " vezes em 30 s")
        assert(G.sqCalls == sq, "varreu quadrados")
    end,
}
