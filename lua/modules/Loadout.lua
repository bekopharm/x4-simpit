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
    uint32_t GetNumCountermeasures();
    bool CanHaveCountermeasures();
    const char* GetComponentHUDIcon(const UniverseID componentid);
	const char* GetComponentIcon(const UniverseID componentid);
    const char* GetFactionNameForTargetMonitorHack(UniverseID componentid);
]]

local L = {
    debug = false
}

local function log(message)
    if L.debug then DebugError("[SimPit][Loadout] " ..message) end
end

-- FIXME: on load this isn't executed or executed to early so nothing is sent because player is not yet in a ship
function L.get()
    local playersector = C.GetContextByClass(C.GetPlayerID(), "sector", false)
    local player = {
    }

    --ConvertIDTo64Bit()
    local ship_id = C.GetPlayerControlledShipID()
    target_formatted = ffi.string(C.GetObjectIDCode(ship_id))
    log("ShipID: "..tostring(ship_id) .." " ..target_formatted)

    local UniverseID = ConvertStringTo64Bit(tostring(ship_id))

    -- factionName     = ffi.string(C.GetFactionNameForTargetMonitorHack(UniverseID))
    -- log("faction: " ..factionName)

    local ship_class, hullPercent, shieldPercent, shipName, rawShipName = GetComponentData(UniverseID, "macro", "hullpercent", "shieldpercent", "name", "rawname")
    
    -- local ship_class = ffi.string(C.GetComponentClass(UniverseID))
    -- oddly enough the icon has more information on the ship type - using that maybe?
    -- ship_class = ship_class.."_"..ffi.string(C.GetComponentIcon(UniverseID))

    -- remove the brackets and comma of e.g. {888888,10105} so we end up with something like ship_arg_s_scout_01_a_macro_888888_10101
    -- ship_class = ship_class.."_" .. string.gsub(string.sub(rawShipName, 2, -2), ',', '_')


    log("macro: " .. ship_class .. " Hull: " ..tostring(hullPercent) .."% Shield: " ..tostring(shieldPercent) .."% shipName: " ..tostring(shipName) .. " shipClass: "..ship_class)

    local storagearray = GetStorageData(UniverseID)
    cargo_capacity = storagearray.capacity

    local loadout = C.GetCurrentLoadoutStatistics3(UniverseID)
    hullValue = loadout.HullValue or 0

    -- TODO: find out how Elite lists this in Modules of Loadout
    -- https://elite-journal.readthedocs.io/en/latest/Startup/#loadout
    local countermeasureCapacity = loadout.CountermeasureCapacity or 0
    local numCountermeasures = 0
    if C.CanHaveCountermeasures() then
        numCountermeasures = tonumber(C.GetNumCountermeasures()) or 0
    end
    log("Countermeasures " ..tostring(numCountermeasures) .."/" ..tostring(countermeasureCapacity))


    buf = ffi.new("UIShipMod")
    hasinstalledmod = C.GetInstalledShipMod(UniverseID, buf)
    if hasinstalledmod then
        log("Additional mass??: " ..tostring(buf.MassFactor))
        hullValue = hullValue * buf.MassFactor
    end


    player.factionname = ffi.string(C.GetPlayerFactionName(true))
    player.credits = GetPlayerMoney()
    player.playersector = ffi.string(C.GetComponentName(playersector))

    log("Sending Loadout event")

    -- TODO: there's a lot missing like Docked, StationName and StationType. See `Docked.lua`
    -- https://elite-journal.readthedocs.io/en/latest/Startup/#loadout
    return {
        event = "Loadout",
        Ship = ship_class, --current ship type
        ShipID = tostring(ship_id), --ship id number (indicates which of your ships you are in)
        ShipName = shipName, --user-defined ship name
        ShipIdent = target_formatted, --user-defined ship ID string
        HullValue = hullValue, --may not always be present
        ModulesValue = 0, --may not always be present
        HullHealth = hullPercent / 100,
        ShieldHealth = shieldPercent / 100,
        UnladenMass = hullValue, --TODO: Mass of Hull and Modules, excludes fuel and cargo
        FuelCapacity = { Main = 0 , Reserve = 0 },
        CargoCapacity = cargo_capacity,
        MaxJumpRange = 0, --based on zero cargo, and just enough fuel for 1 jump
        Rebuy = 0,
        Hot = 0, --if wanted at startup – may not always be present)
        Modules = {
            { Slot = "TinyHardpoint1", Item = "hpt_plasmapointdefence_turret_tiny", On = 1, Priority = 0, AmmoInClip = numCountermeasures, MaxAmmoInClip = countermeasureCapacity, AmmoInHopper = 0, Health = 1.000000, Value = 0}
        },
    };
end

return L