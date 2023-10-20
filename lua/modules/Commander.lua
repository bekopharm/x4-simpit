local ffi = require("ffi")
local C = ffi.C

local L = {}

function L.get()
    -- https://elite-journal.readthedocs.io/en/latest/Startup/#commander
    return {
        event = "Commander",
        Name = ffi.string(C.GetPlayerName()),
        FID = ConvertStringTo64Bit(tostring(C.GetPlayerID()))
    }
end


return L