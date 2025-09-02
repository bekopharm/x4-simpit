local ffi = require("ffi")
local C = ffi.C
ffi.cdef[[
    typedef uint64_t UniverseID;
    bool IsMissileIncoming();
	bool IsMissileLockingOn();
]]

local L = {
    debug = false
}

local function log(message)
    if L.debug then DebugError("[SimPit][UnderAttack] " ..message) end
end

function L.get()
    log("Sending under attack warning")

    local _type = 'Unknown'
	if C.IsMissileIncoming() or C.IsMissileLockingOn() then
		_type = 'Missile'
	end

    return {
        event = "UnderAttack",
        Type = _type,
        Target = 'You',
        -- bust cache
        timestamp = GetDate('%Y-%m-%dT%XZ')
    }
end

return L