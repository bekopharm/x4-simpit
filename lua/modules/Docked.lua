local ffi = require("ffi")
local C = ffi.C
ffi.cdef [[
    typedef uint64_t UniverseID;
    UniverseID GetPlayerID(void);
    UniverseID GetPlayerControlledShipID(void);
    UniverseID GetPlayerOccupiedShipID(void);
    bool IsShipAtExternalDock(UniverseID shipid);
    UniverseID GetContextByClass(UniverseID componentid, const char* classname, bool includeself);
    bool IsContestedSector(UniverseID sectorid);
    const char* GetComponentName(UniverseID componentid);
    UniverseID GetPlayerComputerID(void);
]]

local L = {
    debug = false
}

local function log(message)
    if L.debug then
        DebugError("[SimPit][Docked] " .. message)
    end
end

local toJSON = require("extensions.x4-simpit.lua.vendor.lunajson.encoder")()

function L.get()
    local isDocked = false

    if C.IsShipAtExternalDock(C.GetPlayerControlledShipID()) then
        log("Ship is docked at external dock")
        isDocked = true
    else
        -- we may want to get this always
        DebugError("[SimPit][Docked] Ship is not docked??")
    end

    -- get sector logic
    -- there can be several sectors in one cluster so I guess cluster is our `SystemAddress`
    local clusterID = C.GetContextByClass(C.GetPlayerID(), "cluster", false)
    local cluster = ConvertStringTo64Bit(tostring(clusterID))
    local sector = C.GetContextByClass(C.GetPlayerID(), "sector", false)
    log("cluster: " .. tostring(cluster))

    -- mebbe this can be used to determine FactionState (e.g. CivilWar)
    local isContested = C.IsContestedSector(sector)
    log("isContested: " .. tostring(isContested))
    local factionState = "None"
    if isContested then
        factionState = "Contested"
    end

    -- lifted right from `menu_docked.lua`
    local currentcontainer = 0
    local currentplayership = ConvertStringTo64Bit(tostring(C.GetPlayerOccupiedShipID()))
    if currentplayership ~= 0 then
        if GetComponentData(currentplayership, "isdocked") then
            -- "docked"
            currentcontainer =
                ConvertStringTo64Bit(tostring(C.GetContextByClass(currentplayership, "container", false)))
        else
            -- = "cockpit"
            currentcontainer = currentplayership
        end
    else
        currentcontainer = ConvertStringTo64Bit(tostring(C.GetContextByClass(C.GetPlayerID(), "container", false)))
    end

    log("currentcontainer: " .. currentcontainer)
    log(
        "current player ship: " ..
            ffi.string(C.GetComponentName(currentplayership)) ..
                ", currentcontainer: " .. ffi.string(C.GetComponentName(currentcontainer))
    )

    local stationServices = {
        "Dock",
        "Autodock",
        "Refuel"
    }

    -- collect possible services
    local ownericon,
        owner,
        ownername,
        ownershortname,
        shiptrader,
        isdock,
        canbuildships,
        isplayerowned,
        issupplyship,
        canhavetradeoffers,
        aipilot =
        GetComponentData(
        currentcontainer,
        "ownericon",
        "owner",
        "ownername",
        "ownershortname",
        "shiptrader",
        "isdock",
        "canbuildships",
        "isplayerowned",
        "issupplyship",
        "canhavetradeoffers",
        "aipilot"
    )
    log("owner: " .. owner .. " ownername: " .. ownername .. " ownershortname: " .. ownershortname)

    --relation number
    local relation = GetUIRelation(owner)
    log("relation: " .. relation)

    local cantrade = canhavetradeoffers and isdock
    local canwareexchange = isplayerowned and ((not C.IsComponentClass(currentcontainer, "ship")) or aipilot)
    local canmodifyship = (shiptrader ~= nil) and isdock

    if cantrade then
        table.insert(stationServices, "Commodities")
    end

    if canmodifyship then
        table.insert(stationServices, "Tuning")
        table.insert(stationServices, "Workshop")
        table.insert(stationServices, "Outfitting")
        table.insert(stationServices, "Rearm")
        table.insert(stationServices, "Repair")
    end

    local canbuyship = (shiptrader ~= nil) and canbuildships and isdock
    log(
        "cantrade: " ..
            tostring(cantrade) ..
                ", canbuyship: " .. tostring(canbuyship) .. ", canmodifyship: " .. tostring(canmodifyship)
    )

    -- macro holds at least the known model reference - doubt we have to know this any more detailled from here
    local stationmacro = GetComponentData(currentcontainer, "macro")
    log("stationmacro: " .. stationmacro)

    -- lifted straight from `menu_interactionmenu.lua`
    local ismilitary = false

    if C.IsComponentClass(currentcontainer, "station") then
        -- almost sure this is the order of importance with factory as last option
        local iswharf, isshipyard, isdefencestation, istradestation =
            GetComponentData(currentcontainer, "iswharf", "isshipyard", "isdefencestation", "istradestation")
        log(
            "iswharf: " ..
                tostring(iswharf) ..
                    ", isshipyard: " .. tostring(isshipyard) .. ", isdefencestation: " .. tostring(isdefencestation)
        )

        if isshipyard or iswharf then
            table.insert(stationServices, "Shipyard")
        end

        ismilitary = (iswharf or isshipyard or isdefencestation) and not istradestation
    elseif C.IsComponentClass(currentcontainer, "ship") then
        local purpose = GetComponentData(currentcontainer, "primarypurpose")
        ismilitary = (purpose == "fight" or purpose == "auxiliary")
        if purpose == "auxiliary" then
            table.insert(stationServices, "Outfitting")
            table.insert(stationServices, "Rearm")
            table.insert(stationServices, "Repair")
        end
    end
    log("ismilitary: " .. tostring(ismilitary))

    if ismilitary then
        table.insert(stationServices, "Powerplay")
    end

    policefaction = GetComponentData(GetComponentData(currentcontainer, "zoneid"), "policefaction")
    policefaction = policefaction or "anarchy"
    log("policefaction: " .. policefaction)

    -- TODO: StationState can be any of the following: UnderRepairs, Damaged, Abandoned, UnderAttack
    local stationState = ""
    if GetComponentData(currentcontainer, "hullpercent") < 100 then
        stationState = "Damaged"
    end

    -- TODO: currently unused 
    if cantrade then
        local products = GetComponentData(currentcontainer, "availableproducts")
        local wareTypeBuffer = {
            products = {}
        }
        for _, productware in ipairs(products) do
            wareTypeBuffer.products[productware] = true
            local warename, avgprice = GetWareData(productware, "name", "avgprice")
            warename = warename or "Unknown"
            avgprice = avgprice or 0
            log("Read productware ware " .. warename .. " (" .. productware .. ") avgprice: " .. avgprice)
        end

        log("wareTypeBuffer: " .. toJSON(wareTypeBuffer))
    end

    -- e.g.: sectorOwner: Gottesreich von Paranid
    -- local sectorOwner = GetComponentData(ConvertStringTo64Bit(tostring(sector)), "ownername") or ""
    --  log("sectorOwner: " ..sectorOwner)

    -- yeah, to string is needed or this can be a nil value??
    local sectorName = GetComponentData(ConvertStringTo64Bit(tostring(sector)), "name")
    log("sector " .. ConvertStringTo64Bit(tostring(sector)) .. " Name: " .. sectorName)

    local data = {
        event = "Docked",
        -- FIXME: bust cache (at least during dev)
        timestamp = GetDate("%Y-%m-%dT%XZ"),
        -- TODO:
        StationName = ffi.string(C.GetComponentName(currentcontainer)),
        -- TODO: still don't know how to access wares by id so currentcontainer may be wrong
        MarketID = currentcontainer,
        SystemAddress = cluster, --number
        StationType = stationmacro, --number
        StarSystem = sectorName, -- name of system/sector
        -- only if landing with breached cockpit
        -- this is strictly ED only and always false
        -- trying to stay as compatible as possible
        CockpitBreach = false,
        -- station's controlling faction
        StationFaction = {
            Name = ownername,
            FactionState = factionState
        },
        StationAllegiance = policefaction,
        -- station's primary economy
        StationEconomy = "",
        -- TODO: array of name and proportion values
        -- TODO: find out how the menu_map.lua view does this (shows a bunch of wares maybe)
        StationEconomies = {},
        StationGoverment = "",
        StationGovernment_Localised = "",
        -- also ED only, no use in X4, can mebbe calculate next Gate/Highway distance
        DistFromStarLS = 0,
        -- Array of strings
        StationServices = stationServices,
        -- only if docking when wanted locally - probably never in X4
        Wanted = false,
        ActiveFine = false,
        -- TODO: Add LandingPads informations
        LandingPads = {
            Small = 0,
            Medium = 0,
            Large = 0
        },
        StationState = stationState
    }
    log("Result: " .. toJSON(data))

    return data
end

return L
