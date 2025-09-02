local ffi = require("ffi")
local C = ffi.C
ffi.cdef[[
    typedef uint64_t UniverseID;
    UniverseID GetPlayerID(void);
    UniverseID GetPlayerOccupiedShipID(void);
    UniverseID GetContextByClass(UniverseID componentid, const char* classname, bool includeself);
    const char* GetComponentName(UniverseID componentid);
    UniverseID GetPlayerControlledShipID(void);
]]

local L = {
    debug = false
}

local function log(message)
    if L.debug then DebugError("[SimPit][Undocked] " ..message) end
end

function L.get(param)
    local stationName = "Unknown"

    if param ~= nil then
        -- this converted hex to dec (0x241da22e => 605921838) so we can use it with Lua
        local dec = tostring(ConvertIDTo64Bit(param))
        local macro, name = GetComponentData(dec, "macro", "name")
        if name ~= nil then
            stationName = name
        end
        log( "Undocking from macro: " ..macro .. " name: " ..name)
    else
        log("Ship undocked")
    end

    local ship_id = C.GetPlayerControlledShipID()
    local istaxi = false
    if ship_id == nil then
        istaxi = true
    end
    
    return {
        event = "Undocked",
        -- FIXME: bust cache (at least during dev)
        timestamp = GetDate('%Y-%m-%dT%XZ'),
        -- TODO: - not sure if we can still access this - may have to cache it from `Docked.lua`
        StationName = stationName,
        StationType = macro,
        MarketID = dec,
        Taxi = istaxi,
        Multicrew = false,
    }
end

return L