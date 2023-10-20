local ffi = require("ffi")
local C = ffi.C

local L = {
}

function L.get()
    local playersector = C.GetContextByClass(C.GetPlayerID(), "sector", false)
    local player = {
        event = "Player"
    }

    player.name = ffi.string(C.GetPlayerName())
    player.factionname = ffi.string(C.GetPlayerFactionName(true))
    player.credits = GetPlayerMoney()
    player.playersector = ffi.string(C.GetComponentName(playersector))

    return player;
end

return L