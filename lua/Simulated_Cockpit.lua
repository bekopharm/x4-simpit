-- https://www.egosoft.com:8444/confluence/display/XRWIKI/FFI+function+overview
local ffi = require("ffi")
local C = ffi.C
local Lib = require("extensions.sn_mod_support_apis.lua_interface").Library

-- https://www.egosoft.com:8444/confluence/display/XRWIKI/Lua+function+overview


local function dump(o)
    if type(o) == 'table' then
       local s = '{ '
       for k,v in pairs(o) do
          if type(k) ~= 'number' then k = '"'..k..'"' end
          s = s .. '['..k..'] = ' .. dump(v) .. ','
       end
       return s .. '} '
    else
       return tostring(o)
    end
 end

-- a shallow copy is enough for our stuff
function shallow_copy(t)
    local u = {}
    for k, v in pairs(t) do
        u[k] = v
    end
    return setmetatable(u, getmetatable(t))
end
  
 

local SimPit = {}
SimPit.__index = SimPit

function SimPit.new()
    local self = {}
    
    -- private variables
    cache = {}
    
    -- public variables
    self._VERSION = 0.1
    
    -- private functions
    local function equals(o1, o2, ignore_mt)
        if o1 == o2 then return true end
        local o1Type = type(o1)
        local o2Type = type(o2)
        if o1Type ~= o2Type then return false end
        if o1Type ~= 'table' then return false end

        if not ignore_mt then
            local mt1 = getmetatable(o1)
            if mt1 and mt1.__eq then
                --compare using built in method
                return o1 == o2
            end
        end

        local keySet = {}

        for key1, value1 in pairs(o1) do
            local value2 = o2[key1]
            if value2 == nil or equals(value1, value2, ignore_mt) == false then
                return false
            end
            keySet[key1] = true
        end

        for key2, _ in pairs(o2) do
            if not keySet[key2] then return false end
        end
        return true
    end
    local toJSON = require ("extensions.x4-simpit.lua.vendor.lunajson.encoder")()
    local function format(data)
        if data == nil then
            return "null"
        else
            local buffer = {}
            -- "timestamp": "2016-06-10T14:32:03Z",
            data.timestamp = GetDate('%Y-%m-%dT%XZ')
            
            local result = toJSON(data)
            result = result .. "\n"
            DebugError("DATA: ", result)
            return result
            -- return table.concat(output)
        end
    end

    -- public functions
    function self.get(_, mod)
        -- DebugError("Simulated_Cockpit.lua: Gathering data " ..mod or self._VERSION)

        if mod == nil then
            DebugError("Simulated_Cockpit.lua: Missing parameter mod")
            return
        end

        local Module = require("extensions.x4-simpit.lua.modules." ..mod)

        if Module ~= nil then
            local data = Module.get()
            local cache_hit = equals(cache[mod], data, true)

            -- debug:
            -- cache_hit = false

            -- cache data and only write if something changed
            if cache_hit then
                DebugError("Simulated_Cockpit.lua: " ..mod .." cache hit")
            else
                DebugError("Simulated_Cockpit.lua: " ..mod .." cache missed")
                cache[mod] = shallow_copy(data)
                -- FIXME: apparently write does write everything from a single event
                -- loop to the pipe and writing several datasets in the same loop
                -- results in broken jsons. We need a way to backlog this.
                -- Pipe would be a good place but Pipe does not know what data
                -- we write (it's all just text there) so we may have to keep track
                -- of this here
                AddUITriggeredEvent("simPit.write", "data_feed", format(data))
            end
        end
    end
    
    return self
end

local simPit = SimPit.new()

local function init()
    DebugError("Simulated_Cockpit.lua: INIT " ..simPit._VERSION)
    RegisterEvent("simPit.get", simPit.get)
end

init()