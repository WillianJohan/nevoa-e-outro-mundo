-- O jogo roda Lua no Kahlua, não no luajit dos testes. O que o luajit tem e o
-- Kahlua não tem passa nos testes e quebra no jogo: varre o código do mod.
local FORBIDDEN = {
    -- visto no console.txt: "Object tried to call nil in prune" (next é nil no Kahlua)
    { "[^%w_%.:]next%s*%(", "next() não existe no Kahlua; use um laço pairs" },
    { "^next%s*%(", "next() não existe no Kahlua; use um laço pairs" },
    { "table%.unpack", "table.unpack não existe no Lua 5.1; use unpack" },
    { "[^%w_]goto%s", "goto não existe no Lua 5.1" },
    { "[^/%-]//[^/]", "// (divisão inteira) não existe no Lua 5.1" },
}

-- % do Kahlua trunca (KahluaThread.primitiveMath: a - (double)(int)(a/b)*b): com
-- operando negativo o resto sai negativo (-1 % 2 = -1; o luajit dá 1), e (int) satura em
-- 2^31-1 quando a/b passa disso (getTimestampMs ~1.76e12). O luajit dos testes arredonda
-- pra baixo e não satura, então o teste passa e o jogo erra. Toda conta assim vai por
-- NOM_Math.mod; o que não precisa leva "-- kahlua-%-ok: <motivo>".
-- Suspeitos: paridade (% n == 1, % n ~= 0) e % numa linha com ID de outfit ou tempo real.
local RISKY = { "%f[%w_]now%f[^%w_]", "%f[%w_]id%f[^%w_]", "%f[%w_]pid%f[^%w_]", "%f[%w_][%w_]*Ms%f[^%w_]",
    "getTimestampMs", "getPersistentOutfitID" }
local function percentProblem(line)
    if line:find("kahlua%-%%%-ok:") then return nil end
    local code = line:gsub("%-%-.*$", ""):gsub('"[^"]*"', '""'):gsub("'[^']*'", "''")
    if not code:find("%", 1, true) then return nil end
    if code:find("%%%s*[%w_%.]+%s*==%s*1%f[^%w_%.]") or code:find("%%%s*[%w_%.]+%s*~=%s*0%f[^%w_%.]") then
        return "paridade com %: no Kahlua o resto de negativo é negativo; use NOM_Math.mod"
    end
    local rest = code:gsub("NOM_Math%.mod", "")
    for _, pat in ipairs(RISKY) do
        if rest:find(pat) then
            return "% em ID de outfit ou tempo real: o Kahlua trunca e satura em 2^31; use NOM_Math.mod"
        end
    end
    return nil
end

local function luaFiles()
    local out = {}
    local p = io.popen("find mod mod2 -name '*.lua'")
    for line in p:lines() do out[#out + 1] = line end
    p:close()
    return out
end

return {
    kahlua_no_missing_builtins = function()
        local bad = {}
        for _, path in ipairs(luaFiles()) do
            local n = 0
            for line in io.lines(path) do
                n = n + 1
                local code = line:gsub("%-%-.*$", "")
                for _, rule in ipairs(FORBIDDEN) do
                    if code:find(rule[1]) then
                        bad[#bad + 1] = path .. ":" .. n .. ": " .. rule[2]
                    end
                end
            end
        end
        assert(#bad == 0, "\n  " .. table.concat(bad, "\n  "))
    end,
    -- review da 0017: o lint pega os dois casos que quebraram no jogo, e deixa passar o resto
    kahlua_percent_lint_catches_known_bugs = function()
        assert(percentProblem("    return id ~= nil and math.floor(id / HAT_FALLEN) % 2 == 1"), "hatFallen")
        assert(percentProblem("    local ox, oy = (now * 7) % S.GRAIN_JITTER, (now * 13) % S.GRAIN_JITTER"), "grão")
        assert(percentProblem("    return math.floor(now / R.GRAIN_FRAME_MS) % R.GRAIN_FRAMES + 1"), "quadro do grão")
        assert(percentProblem("if x % n ~= 0 then"), "paridade ~= 0")
        assert(not percentProblem("    cursor = size > 0 and (cursor + n) % size or 0"))
        assert(not percentProblem('    print(string.format("%d %s", now, id))'), "string de formato")
        assert(not percentProblem("    return NOM_Math.mod(now, R.BREATH_MS)"))
        assert(not percentProblem("    h = h % Q -- kahlua-%-ok: motivo"))
    end,
    -- visto no jogo (sprint 0034): a sirene não congelou ninguém no solo
    api_no_is_remote_zombie = function()
        local bad = {}
        for _, path in ipairs(luaFiles()) do
            local n = 0
            for line in io.lines(path) do
                n = n + 1
                if line:gsub("%-%-.*$", ""):find("isRemoteZombie") then
                    bad[#bad + 1] = path .. ":" .. n .. ": isRemoteZombie() devolve true pra todo zumbi no solo"
                        .. " (NetworkZombieComponent.isRemote = authOwner == nil, e no solo ninguém chama setOwner);"
                        .. " use isLocal() (pz-api-notes §24)"
                end
            end
        end
        assert(#bad == 0, "\n  " .. table.concat(bad, "\n  "))
    end,
    kahlua_percent_safe = function()
        local bad = {}
        for _, path in ipairs(luaFiles()) do
            local n = 0
            for line in io.lines(path) do
                n = n + 1
                local why = percentProblem(line)
                if why then bad[#bad + 1] = path .. ":" .. n .. ": " .. why end
            end
        end
        assert(#bad == 0, "\n  " .. table.concat(bad, "\n  "))
    end,
}
