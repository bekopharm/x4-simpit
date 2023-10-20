local ffi = require("ffi")
local C = ffi.C
ffi.cdef[[
    typedef uint64_t UniverseID;
    typedef struct {
        const char* Name;
        const char* RawName;
        const char* Ware;
        uint32_t Quality;
        const char* PropertyType;
        float MassFactor;
        float DragFactor;
        float MaxHullFactor;
        float RadarRangeFactor;
        uint32_t AddedUnitCapacity;
        uint32_t AddedMissileCapacity;
        uint32_t AddedCountermeasureCapacity;
        uint32_t AddedDeployableCapacity;
    } UIShipMod;
    bool GetInstalledShipMod(UniverseID shipid, UIShipMod* shipmod);
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
    UniverseID GetPlayerControlledShipID(void);
    const char* GetObjectIDCode(UniverseID objectid);
    const char* GetComponentClass(UniverseID componentid);
]]

local L = {
    debug = false
}

local function log(message)
    if L.debug then DebugError("[SimPit][Loadout] " ..message) end
end

function L.get()
    local playersector = C.GetContextByClass(C.GetPlayerID(), "sector", false)
    local player = {
    }

    --ConvertIDTo64Bit()
    local ship_id = C.GetPlayerControlledShipID()
    target_formatted = ffi.string(C.GetObjectIDCode(ship_id))
    log("ShipID: "..tostring(ship_id) .." " ..target_formatted)

    local UniverseID = ConvertStringTo64Bit(tostring(ship_id))

    hullPercent, shieldPercent, shipName = GetComponentData(UniverseID, "hullpercent", "shieldpercent", "name")
    local ship_class = ffi.string(C.GetComponentClass(UniverseID))
    log("Hull: " ..tostring(hullPercent) .."% Shield: " ..tostring(shieldPercent) .."% shipName: " ..tostring(shipName) .. " shipClass: "..ship_class)

    local storagearray = GetStorageData(UniverseID)
    cargo_capacity = storagearray.capacity

    local loadout = C.GetCurrentLoadoutStatistics3(UniverseID)
    hullValue = loadout.HullValue or 0

    buf = ffi.new("UIShipMod")
    hasinstalledmod = C.GetInstalledShipMod(UniverseID, buf)
    if hasinstalledmod then
        log("Additional mass??: " ..tostring(buf.MassFactor))
        hullValue = hullValue * buf.MassFactor
    end


    player.factionname = ffi.string(C.GetPlayerFactionName(true))
    player.credits = GetPlayerMoney()
    player.playersector = ffi.string(C.GetComponentName(playersector))

    -- https://elite-journal.readthedocs.io/en/latest/Startup/#loadout
    return {
        event = "Loadout",
        Ship = ship_class, --current ship type
        ShipID = tostring(ship_id), --ship id number (indicates which of your ships you are in)
        ShipName = shipName, --user-defined ship name
        ShipIdent = target_formatted, --user-defined ship ID string
        HullValue = hullValue, --may not always be present
        ModulesValue = 0, --may not always be present
        HullHealth = hullPercent,
        ShieldHealth = shieldPercent,
        UnladenMass = hullValue, --TODO: Mass of Hull and Modules, excludes fuel and cargo
        FuelCapacity = { Main = 0 , Reserve = 0 },
        CargoCapacity = cargo_capacity,
        MaxJumpRange = 0, --based on zero cargo, and just enough fuel for 1 jump
        Rebuy = 0,
        Hot = 0, --if wanted at startup – may not always be present)
        Modules = {},
    };
end

return L