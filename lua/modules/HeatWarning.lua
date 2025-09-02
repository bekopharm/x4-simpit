local ffi = require("ffi")
local C = ffi.C
ffi.cdef[[
    typedef uint64_t UniverseID;
]]

local L = {
    debug = false
}

local function log(message)
    if L.debug then DebugError("[SimPit][HeatWarning] " ..message) end
end

function L.get()
    log("Sending overheat warning")

    return {
        event = "HeatWarning",
        -- bust cache
        timestamp = GetDate('%Y-%m-%dT%XZ')
    }
end

return L