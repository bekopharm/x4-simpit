local ffi = require("ffi")
local C = ffi.C
ffi.cdef[[
    typedef uint64_t UniverseID;
]]

local L = {
    debug = false
}

local nextTimestamp = nil
local from = ""
local message = ""
-- wing/local/voicechat/friend/player/npc/squadron/starsystem
local channel = ""

local function log(message)
    if L.debug then DebugError("[SimPit][ReceiveText] " ..message) end
end

local function toChannel(category)
    if category == "general" then
        return "local"
    end
    if category == "missions" then
        return "friend"
    end
    if category == "news" then
        return "starsystem"
    end
    if category == "upkeep" then
        return "wing"
    end
    if category == "alerts" then
        return "voicechat"
    end
    if category == "tips" then
        return "npc"
    end

    DebugError("[SimPit][ReceiveText] Unknown category " ..category)

    return "local"
end

function L.get()
    -- logbook restriction
    -- * general => local
    -- * missions => friend
    -- * news => starsystem
    -- * upkeep => wing
    -- * alerts => voicechat
    -- * tips => npc
    -- * all

    local maxEntries = 5
    local logbookCategory = "all"
    local logbookNumEntries = GetNumLogbook(logbookCategory)
    local numQuery = math.min(maxEntries, logbookNumEntries)

    local startIndex = math.max(1, logbookNumEntries - maxEntries + 1)
    local logbook = GetLogbook(startIndex, numQuery, logbookCategory) or {}
    local logbookSize = #logbook
    local data = {}
    local wasFound = false

    if logbookSize > 0 then
        for i = 1, logbookSize, 1 do
            local entry = logbook[i]
            -- use timestamp as id

            if wasFound then
                log("Next up: "..entry.time)
                nextTimestamp = entry.time
                channel = toChannel(entry.category or "unknown")
                from = entry.factionname or "Unknown"
                message = entry.title.."\n"..entry.text
                if entry.money ~= 0 then
                    message = message.."\n"..entry.money
                end
                if entry.bonus ~= 0 then
                    message = message.."\n"..entry.bonus
                end
                if entry.highlighted then
                    message = "<b>"..message.."</b>"
                end
                break
            end
            -- init
            if nextTimestamp == nil then
                nextTimestamp = entry.time
            end

            local found = "[ ] "
            if nextTimestamp == entry.time then
                found = "[x] "
                wasFound = true
            end
            log(found ..i .."/"..logbookSize.." " ..Helper.getPassedTime(entry.time).." id "..entry.time.. " msg "..entry.text)
        end
        if not wasFound then
            -- we lost our index - perhaps the log was cleared?
            nextTimestamp = nil
        end
    else
        -- log was cleared, reset index
        nextTimestamp = nil
    end
    
    -- https://elite-journal.readthedocs.io/en/latest/Other%20Events/#receivetext
    -- When written: when a text message is received from another player or npc
    return {
        event = "ReceiveText",
        From = from,
        Message = message,
        Channel = channel,
    }
end

return L