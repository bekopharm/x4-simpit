local ffi = require("ffi")
local C = ffi.C
ffi.cdef[[
    typedef uint64_t UniverseID;
    typedef struct {
        const char* factionID;
        const char* factionName;
        const char* factionIcon;
    } FactionDetails;
    typedef struct {
        float HullValue;
        float ShieldValue;
        double ShieldDelay;
        float ShieldRate;
        float GroupedShieldValue;
        double GroupedShieldDelay;
        float GroupedShieldRate;
        float BurstDPS;
        float SustainedDPS;
        float TurretBurstDPS;
        float TurretSustainedDPS;
        float GroupedTurretBurstDPS;
        float GroupedTurretSustainedDPS;
        float ForwardSpeed;
        float BoostSpeed;
        float TravelSpeed;
        float YawSpeed;
        float PitchSpeed;
        float RollSpeed;
        float HorizontalStrafeSpeed;
        float VerticalStrafeSpeed;
        float ForwardAcceleration;
        float HorizontalStrafeAcceleration;
        float VerticalStrafeAcceleration;
        uint32_t NumDocksShipMedium;
        uint32_t NumDocksShipSmall;
        uint32_t ShipCapacityMedium;
        uint32_t ShipCapacitySmall;
        uint32_t CrewCapacity;
        uint32_t ContainerCapacity;
        uint32_t SolidCapacity;
        uint32_t LiquidCapacity;
        uint32_t UnitCapacity;
        uint32_t MissileCapacity;
        uint32_t CountermeasureCapacity;
        uint32_t DeployableCapacity;
        float RadarRange;
    } UILoadoutStatistics3;
    UILoadoutStatistics3 GetCurrentLoadoutStatistics3(UniverseID shipid);
    UniverseID GetPlayerOccupiedShipID(void);
    float GetDistanceBetween(UniverseID component1id, UniverseID component2id);
    bool IsShip(UniverseID shipid);
    bool IsEntity(UniverseID shipid);
    bool IsPointingWithinAimingRange();
    const char* GetObjectIDCode(UniverseID objectid);
    FactionDetails GetOwnerDetails(UniverseID componentid);
    int32_t GetEntityCombinedSkill(UniverseID entityid, const char* role, const char* postid);
]]


function enum(tbl)
    local length = #tbl
    for i = 1, length do
        local v = tbl[i]
        tbl[v] = i
    end

    return tbl
end

local L = {
    debug = true
}

LegalState = enum {
    "Clean",
    "IllegalCargo",
    "Speeding",
    "Wanted",
    "Hostile",
    "PassengerWanted",
    "Warrant"
}

CombatRanks = enum {
    "Harmless",
    "MostlyHarmless",
    "Novince",
    "Competent",
    "Expert",
    "Master",
    "Dangerous",
    "Deadly",
    "Elite"
}

local function log(message)
    if L.debug then DebugError("[SimPit][ShipTargeted] " ..message) end
end

-- https://elite-journal.readthedocs.io/en/latest/Combat/#shiptargetted
function L.get()
    local targetLock = false -- when losing target; don't think we have anything equal in X4 (IsInScanRange would be an alternative but that is no longer available)
    local shipName = ""
    local scanStage = 0
    local pilotName = ""
    local pilotRank = ""
    local shieldPercent = 0
    local hullPercent = 0
    local factionName= ""
    local legalStatus = LegalState.Clean
    local bounty = ""
    local power = ""

    local target_id = ConvertIDTo64Bit(GetPlayerTarget())
    target_formatted = ""
    local isShip = false
    local pilot_id = nil

    if target_id ~= nil then
        pilot_id = GetComponentData(target_id, "controlentity")
        isShip = C.IsShip(target_id)
        -- target_formatted = string.format(" (%s)", ffi.string(C.GetObjectIDCode(ConvertIDTo64Bit(target_id))))
        target_formatted = ffi.string(C.GetObjectIDCode(ConvertIDTo64Bit(target_id)))
        log("Target " ..target_formatted .."; isShip " ..tostring(isShip))

        -- ANY components
        shipName, uiname, description, owner, ownername, ownershortname, ownericon, size, scanStage, isfriend, isenemy = GetComponentData(target_id, "name", "uiname", "description", "image", "owner", "ownername", "ownershortname", "ownericon", "size", "revealpercent", "isfriend", "isenemy")
        log("" ..shipName .." uiname " ..uiname .." "..description .." " ..tostring(owner) .." " ..tostring(ownername) .." ownershortname " ..ownershortname .." ownericon " ..ownericon .." ownername " ..ownername)
        shipName = string.format(shipName .." (%s)", target_formatted)
        factionName = ownershortname
        power = ownericon

        -- 1: factionID: scaleplate factionName: Scale Plate Pact factionIcon: faction_scaleplate
        local owner_details = C.GetOwnerDetails(ConvertIDTo64Bit(target_id))
        log("Faction Details 1: " ..ffi.string(owner_details.factionID) .. " "..ffi.string(owner_details.factionName).. " "..ffi.string(owner_details.factionIcon))

        -- FIXME: wantedmoney seems to be always "empty" on a ship? And nil on it's piloting entity??
        local wantedmoney = GetComponentData(target_id, "wantedmoney")
        if wantedmoney ~= nil then
            bounty = ConvertMoneyString(GetComponentData(target_id, "wantedmoney"))
            if bounty ~= "" then legalStatus = LegalState.Wanted end
        end
        log("Legal status: " ..legalStatus .. " bounty " ..tostring(bounty))

        -- Get own radar range and compare with distance to target to check if we have a radar lock
        -- example: 40000 = 40km
        if C.GetPlayerOccupiedShipID() > 0 then
            local loadout = C.GetCurrentLoadoutStatistics3(C.GetPlayerOccupiedShipID())
            local distance = C.GetDistanceBetween(C.GetPlayerOccupiedShipID(), ConvertIDTo64Bit(target_id))
            -- target in scanning range so we can lock it (and show data)
            if loadout.RadarRange > distance then targetLock = true end
        end
    end

    if pilot_id ~= nil and C.IsEntity(ConvertIDTo64Bit(pilot_id)) then
        log("pilot_id: " ..tostring(pilot_id))
        pilotName, ownershortname, npctype, npcoccupationname, skills = GetComponentData(pilot_id, "name", "ownershortname", "typestring", "occupationname", "skills")
        log("pilotName: " ..pilotName .." " ..ownershortname .." " ..npctype .." " ..tostring(npcoccupationname))

        --[[
            PilotRank - seems to be an int probably between 0 and 100
            Example yielded "65" on a Raider, not sure how to map this but
            we can probably just apply math
        ]]--
        skills = C.GetEntityCombinedSkill(ConvertIDTo64Bit(pilot_id), nil, "aipilot") or 0
        pilotRank = math.floor(skills / 10)
        if pilotRank > CombatRanks.Elite then pilotRank = CombatRanks.Elite end

        -- rank… like officer
        local typestring = GetComponentData(pilot_id, "typestring")
        log("typestring: " ..tostring(typestring) .. " skills" ..tostring(skills))
    end

    -- seems to work always?
    hullPercent, shieldPercent = GetComponentData(target_id, "hullpercent", "shieldpercent", "skills", "typestring")
    log("Hull: " ..tostring(hullPercent) .."% Shield: " ..tostring(shieldPercent) .."%")


    if isShip then
        -- isenemy: bool
        -- isfriend: FLOAT!
        log("Size " ..size .." Scan: " ..scanStage .."% Friend: " ..tostring(isfriend) .." Enemy: " ..tostring(isenemy))

        if isfriend == 0 then legalStatus = LegalState.Hostile end
        -- criminal transports
        if size == "faction_criminal" or size == "faction_scaleplate" then 
            legalStatus = LegalState.Wanted
            -- TODO: check if this is always 500 or where to obtain data
            -- observed value from killing a criminal transport vessel
            bounty = "500"
        end

        hullPercent, shieldPercent, skills, typestring = GetComponentData(target_id, "hullpercent", "shieldpercent", "skills", "typestring")
        log("Hull: " ..tostring(hullPercent) .."% Shield: " ..tostring(shieldPercent) .."% Skill: " ..tostring(skills) .." typestring" ..tostring(typestring))

        -- local macro = GetComponentData(target_id, "macro")
        -- log("macro: " ..tostring(macro))
    
    end

    return {
        event = "ShipTargeted",
        TargetLocked = targetLock,
        Ship = shipName,
        -- scan stage >=1
        ScanStage = scanStage,
        PilotName = pilotName,
        PilotRank = pilotRank,
        -- scan stage >=2
        ShieldHealth = shieldPercent,
        HullHealth = hullPercent,
        -- scan stage >=3
        Faction = factionName,
        LegalStatus = legalStatus,
        Bounty = bounty,
        SubSystem = "",
        SubSystemHealth = "",
        Power = power
    }
end

return L