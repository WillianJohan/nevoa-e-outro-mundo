package.path = "mod/42/media/lua/shared/?.lua;" .. package.path

local FILES = {
    "tests/test_smoke.lua",
}

local pass, fail = 0, 0
for _, file in ipairs(FILES) do
    local tests = dofile(file)
    for name, fn in pairs(tests) do
        local ok, err = pcall(fn)
        if ok then
            pass = pass + 1
        else
            fail = fail + 1
            print("FAIL " .. file .. " :: " .. name .. "\n  " .. tostring(err))
        end
    end
end

print(string.format("total=%d passou=%d falhou=%d", pass + fail, pass, fail))
os.exit(fail == 0 and 0 or 1)
