-- Auditoria das traduções: toda chave usada (sandbox e Lua) existe em todo
-- idioma, nenhuma sobra, e os JSON passam no leitor do jogo.
--
-- O jogo lê Translate/<LANG>/<Arquivo>.json em modo estrito
-- (Translator.tryFillMapFromFile: JSONParserConfiguration.withStrictMode(true))
-- e, no EN, lança IllegalStateException com caractere "parecido" com ASCII
-- (cryAboutUnicodeConfusables), menos no Mod.json. Mod.json troca nome e
-- descrição do mod.info (Translator.readModTranslation).

local MEDIA = "mod/42/media/"
local DIR = MEDIA .. "lua/shared/Translate/"
local LANGS = { "EN", "PTBR" }

local function read(path)
    local f = assert(io.open(path, "r"), "não abriu " .. path)
    local s = f:read("*a")
    f:close()
    return s
end

local function lines(cmd)
    local out = {}
    local p = io.popen(cmd)
    for l in p:lines() do out[#out + 1] = l end
    p:close()
    table.sort(out)
    return out
end

-- Objeto plano de strings, uma entrada por linha (o formato dos JSON do jogo).
local function parse(path)
    local entries, keys = {}, {}
    for line in read(path):gmatch("[^\n]+") do
        local k, v, comma = line:match('^%s*"([^"]+)"%s*:%s*"(.*)"(,?)%s*$')
        if k then
            assert(keys[k] == nil, path .. ": chave repetida " .. k)
            keys[k] = v
            entries[#entries + 1] = { key = k, comma = comma == "," }
        else
            assert(line:match("^%s*[{}]%s*$"), path .. ": linha fora do formato: " .. line)
        end
    end
    return keys, entries
end

local function used()
    local keys = {}
    local opts = read(MEDIA .. "sandbox-options.txt")
    for page in opts:gmatch("page%s*=%s*([%w_%.]+)") do keys["Sandbox_" .. page] = true end
    for t in opts:gmatch("translation%s*=%s*([%w_%.]+)") do
        keys["Sandbox_" .. t] = true
        keys["Sandbox_" .. t .. "_tooltip"] = true
    end
    return keys
end

local function luaKeys()
    local keys = {}
    for _, file in ipairs(lines("find " .. MEDIA .. "lua -name '*.lua'")) do
        for k in read(file):gmatch('getText%w*%(%s*"([^"]+)"') do keys[k] = file end
        -- chaves passadas a quem chama getText por nós (PZAPI.ModOptions: nomes e dicas)
        for k in read(file):gmatch('"(UI_NOM_[%w_]+)"') do keys[k] = file end
    end
    return keys
end

local function sorted(set)
    local out = {}
    for k in pairs(set) do out[#out + 1] = k end
    table.sort(out)
    return out
end

local function eachFile(fn)
    for _, lang in ipairs(LANGS) do
        for _, name in ipairs(lines("ls " .. DIR .. lang)) do fn(lang, name, DIR .. lang .. "/" .. name) end
    end
end

return {
    translations_no_lone_percent = function()
        -- o jogo passa o texto pelo java.util.Formatter: "%" sozinho lança
        -- UnknownFormatConversionException (visto no console.txt); vanilla usa "%%"
        for _, lang in ipairs({ "EN", "PTBR" }) do
            for _, f in ipairs({ "Sandbox.json", "UI.json" }) do
                local path = "mod/42/media/lua/shared/Translate/" .. lang .. "/" .. f
                local h = io.open(path)
                if h then
                    local text = h:read("*a"); h:close()
                    local stripped = text:gsub("%%%%", "")
                    local bad = stripped:match('"[^"\n]*%%[^"\n]*"')
                    assert(not bad, path .. ": % sozinho em " .. tostring(bad))
                end
            end
        end
    end,

    -- sprint 0008: monstros (menos o Eco) só na névoa; Eco só de quem morreu antes
    -- do anoitecer. O texto do menu tem que dizer isso, nos dois idiomas
    translations_variants_say_fog_and_eco_says_dusk = function()
        local words = {
            -- "de dia ou de noite" pode; o que não pode é a noite como condição
            EN = { fog = "fog", night = { "at night", "each night" }, dusk = "before dusk" },
            PTBR = { fog = "névoa", night = { "à noite", "a cada noite" }, dusk = "antes do anoitecer" },
        }
        for lang, w in pairs(words) do
            local keys = parse("mod/42/media/lua/shared/Translate/" .. lang .. "/Sandbox.json")
            for _, opt in ipairs({ "EstaladorEnabled", "CorredorEnabled", "EstaladorChance", "CorredorChance", "SemRostoChance" }) do
                local t = keys["Sandbox_NevoaEOutroMundo." .. opt .. "_tooltip"]:lower()
                assert(t:find(w.fog, 1, true), lang .. " " .. opt .. " não fala da névoa: " .. t)
                for _, n in ipairs(w.night) do
                    assert(not t:find(n, 1, true), lang .. " " .. opt .. " ainda fala da noite: " .. t)
                end
            end
            local eco = keys["Sandbox_NevoaEOutroMundo.EcoEnabled_tooltip"]:lower()
            assert(eco:find(w.dusk, 1, true), lang .. " Eco sem a regra do anoitecer: " .. eco)
        end
    end,

    -- sprint 0023: o Outro Mundo vai anexado ao chão e às paredes (de volta), com chão queimado
    -- dentro e mato e trepadeira fora; e continua sem nada no save
    translations_overlays_promise_floor_and_walls = function()
        local want = { EN = { "walls", "burnt", "vines", "save" }, PTBR = { "paredes", "queimado", "trepadeira", "save" } }
        for lang, words in pairs(want) do
            local sandbox = parse(DIR .. lang .. "/Sandbox.json")
            local ui = parse(DIR .. lang .. "/UI.json")
            local tip = sandbox["Sandbox_NevoaEOutroMundo.FogOverlays_tooltip"]:lower()
            for _, w in ipairs(words) do assert(tip:find(w, 1, true), lang .. " não fala de " .. w .. ": " .. tip) end
            local opt = ui["UI_NOM_FogOverlayDensity_tooltip"]:lower()
            assert(opt:find(words[1], 1, true), lang .. " opção sem as paredes: " .. opt)
        end
    end,

    translations_same_files_per_language = function()
        local ref = table.concat(lines("ls " .. DIR .. LANGS[1]), ",")
        for _, lang in ipairs(LANGS) do
            assert(table.concat(lines("ls " .. DIR .. lang), ",") == ref, lang .. " tem arquivos diferentes de " .. LANGS[1])
        end
        assert(ref:find("Mod.json", 1, true), "falta Mod.json")
        assert(ref:find("Sandbox.json", 1, true), "falta Sandbox.json")
    end,

    translations_sandbox_keys_exact = function()
        local want = used()
        for _, lang in ipairs(LANGS) do
            local have = parse(DIR .. lang .. "/Sandbox.json")
            for _, k in ipairs(sorted(want)) do assert(have[k], lang .. ": falta " .. k) end
            for _, k in ipairs(sorted(have)) do assert(want[k], lang .. ": chave sem uso " .. k) end
        end
    end,

    translations_lua_keys_defined = function()
        for k, file in pairs(luaKeys()) do
            for _, lang in ipairs(LANGS) do
                local found = false
                for _, name in ipairs(lines("ls " .. DIR .. lang)) do
                    if parse(DIR .. lang .. "/" .. name)[k] then found = true end
                end
                assert(found, lang .. ": falta " .. k .. " (usada em " .. file .. ")")
            end
        end
    end,

    translations_mod_json = function()
        local ref
        for _, lang in ipairs(LANGS) do
            local keys = parse(DIR .. lang .. "/Mod.json")
            for k, v in pairs(keys) do
                assert(k == "name" or k == "description", lang .. "/Mod.json: chave que o jogo não lê: " .. k)
                assert(v ~= "", lang .. "/Mod.json: " .. k .. " vazio")
            end
            local list = table.concat(sorted(keys), ",")
            assert(list ~= "", lang .. "/Mod.json vazio")
            ref = ref or list
            assert(list == ref, lang .. "/Mod.json com chaves diferentes")
        end
    end,

    translations_no_empty_values = function()
        eachFile(function(lang, name, path)
            for k, v in pairs(parse(path)) do assert(v:match("%S"), lang .. "/" .. name .. ": vazio " .. k) end
        end)
    end,

    translations_en_is_ascii = function()
        for _, name in ipairs(lines("ls " .. DIR .. "EN")) do
            if name ~= "Mod.json" then
                local s = read(DIR .. "EN/" .. name)
                local at = s:find("[\128-\255]")
                assert(not at, "EN/" .. name .. ": caractere não ASCII perto de: " .. s:sub(math.max(1, at or 1) - 20, (at or 1) + 5))
            end
        end
    end,

    -- parser estrito de verdade (o daqui de cima só confere o formato por linha):
    -- aspas sem escape, escape inválido e vírgula sobrando falham
    translations_strict_json = function()
        eachFile(function(lang, name, path)
            local ok = os.execute("python3 -c 'import json,sys; json.load(open(sys.argv[1], encoding=\"utf-8\"))' '"
                .. path .. "' 2>/dev/null")
            assert(ok == 0 or ok == true, lang .. "/" .. name .. ": JSON inválido (python3 -m json.tool " .. path .. ")")
        end)
    end,

    translations_json_commas = function()
        eachFile(function(lang, name, path)
            local _, entries = parse(path)
            for i, e in ipairs(entries) do
                local last = i == #entries
                assert(e.comma ~= last, lang .. "/" .. name .. ": vírgula errada em " .. e.key)
            end
        end)
    end,

    -- sprint 0037b: o nome exibido é "NOM: Noise of Mist"; as chaves (Sandbox_NevoaEOutroMundo etc.) ficam
    translations_new_mod_name = function()
        local OLD = { "Névoa e Outro Mundo", "Fog and Otherworld" }
        local files = lines("find " .. DIR .. " mod2/42/media/lua/shared/Translate -name '*.json'")
        for _, path in ipairs(files) do
            for k, v in pairs(parse(path)) do
                for _, old in ipairs(OLD) do assert(not v:find(old, 1, true), path .. ": nome antigo em " .. k) end
            end
        end
        for _, lang in ipairs(LANGS) do
            assert(parse(DIR .. lang .. "/Sandbox.json").Sandbox_NevoaEOutroMundo == "NOM: Noise of Mist", lang)
            assert(parse(DIR .. lang .. "/UI.json").UI_NOM_Options == "NOM: Noise of Mist", lang)
            assert(parse(DIR .. lang .. "/UI.json").UI_NOM_Debug_Title == "NOM: debug", lang)
        end
    end,
}
