local ffi = require("ffi")
local C = ffi.C
ffi.cdef[[
    typedef uint64_t UniverseID;
    typedef struct {
		const float x;
		const float y;
		const float z;
		const float yaw;
		const float pitch;
		const float roll;
	} UIPosRot;
	typedef struct {
		const char* name;
		const char* typeclass;
		const char* geology;
		const char* atmosphere;
		const char* population;
		const char* settlements;
		uint32_t nummoons;
		bool hasterraforming;
	} UICelestialBodyInfo2;
	typedef struct {
		UISpaceInfo space;
		uint32_t numsuns;
		UISunInfo* suns;
		uint32_t numplanets;
		UICelestialBodyInfo2* planets;
	} UISystemInfo2;
    typedef struct {
		const char* name;
		const char* typeclass;
	} UISunInfo;
	typedef struct {
		const char* environment;
	} UISpaceInfo;
	typedef struct {
		uint32_t numsuns;
		uint32_t numplanets;
	} UISystemInfoCounts;
    bool GetUISystemInfo2(UISystemInfo2* result, UniverseID clusterid);
    UIPosRot GetObjectPositionInSector(UniverseID objectid);
    bool IsUnit(UniverseID controllableid);
    UniverseID GetPlayerOccupiedShipID(void);
    UniverseID GetPlayerControlledShipID(void);
    const char* GetObjectEngineStatus(const UniverseID objectid);
    bool IsShipAtExternalDock(UniverseID shipid);
	uint32_t GetNumCountermeasures();
    bool IsFlightAssistActive(void);
	size_t GetNumPrimaryWeapons();
	size_t GetNumSecondaryWeapons();
	size_t GetNumTurrets();
	size_t GetNumTurretSlots();
	size_t GetNumWeaponSlots();
    UniverseID GetPlayerContainerID(void);
    UniverseID GetContextByClass(UniverseID componentid, const char* classname, bool includeself);
    bool CanActivateSeta(bool checkcontext);
    bool HasSeta();
	bool IsSetaActive();
	bool IsMissileIncoming();
	bool IsMissileLockingOn();
    bool IsLowOnOxygen();
    bool IsCurrentlyScanning();
    float GetRemainingOxygen();
    const char* GetPlayerShipSize();
    uint32_t GetActivePrimaryWeaponGroup();
    UISystemInfoCounts GetNumUISystemInfo(UniverseID clusterid);
    typedef struct {
		uint32_t numsuns;
		uint32_t numplanets;
	} UISystemInfoCounts;
    bool IsFullscreenMenuDisplayed(bool anymenu, const char* menuname);
    float GetDistanceBetween(UniverseID component1id, UniverseID component2id);

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
    debug = false
}

local private = {
    lastPos = nil,
    lastCluster = nil,
    bodyName = ""
}

GuiFocus = enum {
    "NoFocus",
    "InternalPanel", -- "right side"
    "ExternalPanel", -- "left side"
    "CommsPanel",
    "RolePanel",
    "StationServices",
    "GalaxyMap",
    "SystemMap",
    "Orrery",
    "FSSMode",
    "SAAMode",
    "Codex"
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

local function log(message)
    if L.debug then DebugError("[SimPit][Status] " ..message) end
end

-- https://elite-journal.readthedocs.io/en/latest/Status%20File/
-- /games/linux/X4_Foundations_extracted/ui/addons/ego_detailmonitor/menu_map.lua

function L.get()

    local flags = 0

    local shipSize = ffi.string(C.GetPlayerShipSize())
	if shipSize ~= "ship_l" and shipSize ~= "ship_xl" then
		local numTurretSlots = tonumber(C.GetNumTurretSlots())
		local numTurrets     = tonumber(C.GetNumTurrets())
	end

    local isScanning = C.IsCurrentlyScanning()
    local isDocked = false

    local curPlayerHull = 0
    local curPlayerShield = 0
    local curOxygen = C.GetRemainingOxygen()

    local latitude = 0
    local longitude = 0
    local altitude = 0

    local cargo = 0

    local manualSpeedPerSecond = 0
    local angle = 0
    local travelMode = false

    -- local toJSON = require ("extensions.x4-simpit.lua.vendor.lunajson.encoder")()

    --[[
        What's the difference between GetPlayerControlledShipID and GetPlayerOccupiedShipID ??? 
    ]]--
    if C.GetPlayerOccupiedShipID() > 0 then

        local shipId = ConvertStringTo64Bit(tostring(C.GetPlayerControlledShipID()))
        curPlayerHull, curPlayerShield = GetPlayerShipHullShield()

        curPlayerHull = curPlayerHull or 0
        curPlayerShield = curPlayerShield or 0

        -- read ship storage manifest so we know what's loaded
        local storagemodules = GetStorageData(shipId)
        local sortedwarelist = {}
        local simplewarelist = {}
        -- using volume as mass. IF I could that correct it's volume that is used to determine available cargo space
        -- see e.g energycells occupying a volume of 1 with an amount between 1 and 10
        -- Ware: {"ware":"energycells","amount":10,"name":"Energy Cells","consumption":0,"volume":1}
        -- https://www.egosoft.com:8444/confluence/display/XRWIKI/Lua+function+overview => GetWareData(ware, ...)

        for _, storagemodule in ipairs(storagemodules) do
			for _, ware in ipairs(storagemodule) do
                -- log("Ware: " .._ ..": "..toJSON(ware))
                cargo = cargo + ware.volume
				table.insert(sortedwarelist, ware)
				simplewarelist[ware.ware] = true
			end
		end

        -- log("SimPit: Player in Ship: " ..tostring(shipId) .." Size: " ..shipSize)

        -- Docked, (on a landing pad)
        if C.IsShipAtExternalDock(C.GetPlayerControlledShipID()) then
            -- DockedOnPad
            flags = flags + 1
            -- Landing Gear Down / Landing gear is completely automated in X4
            flags = flags + 4
            isDocked = true
        else
        end

        -- Shields Up
        -- player hull is always active (if the crosshair is active) - hence update the state always
        if curPlayerShield >= 1 then
            flags = flags + 8
        else
        end

        -- FlightAssist Off
        if not C.IsFlightAssistActive() then
            flags = flags + 32
        end

        -- TODO: Hardpoints Deployed
        -- Consider reading turret status and when they are live we count that as hardpoints
        -- Alternatively we may check for selected weapons and if none are life we have none deployed
        -- For now - since we can not retract them - we count them as always deployed
        flags = flags + 64

        -- In Wing
        local locplayersubordinates = GetSubordinates(shipId, nil, true)
        if locplayersubordinates ~= nil and #locplayersubordinates > 0 then
            flags = flags + 128
            -- log("SimPit: In Wing")
        end

        -- LightsOn / X4 has always lights on
        flags = flags + 256

	    -- speed is always returned between -1 and 1 (1 meaning full forward speed, -1 meaning full reverse speed)
	    local actualSpeed, targetedSpeed, actualSpeedPerSecond, boosting, _travelMode, matchSpeed, targetSpeed, normalTargetSpeed = GetPlayerSpeed()
        manualSpeedPerSecond = actualSpeedPerSecond

        travelMode = _travelMode

        -- pos.y is "altitude"
        local pos = C.GetObjectPositionInSector(C.GetPlayerOccupiedShipID())
        latitude = pos.x
        longitude = pos.z
        altitude = math.floor(pos.y)

        -- log("Position x " ..pos.x .." y " ..pos.z)
        -- log("Position x " ..pos.x .." y " ..pos.z)

        -- get the airspeed when actual speed is 0 (does not take thruster movement into account o0)
        if private.lastPos ~= nil and manualSpeedPerSecond == 0 then
            local x = pos.x - private.lastPos.x
            local y = pos.y - private.lastPos.y
            local z = pos.z - private.lastPos.z
            manualSpeedPerSecond = math.sqrt(x^2 + y^2 + z^2)
        end

        manualSpeedPerSecond = math.floor(manualSpeedPerSecond)

        -- calculate the heading
        if private.lastPos ~= nil then
            -- TODO: check if I got this right
            local delta_z = private.lastPos.z - pos.z
            local delta_x = private.lastPos.x - pos.x
            angle = math.atan2(delta_z, delta_x) * (180/math.pi)
            angle = math.floor(angle)
        end

        -- if we have a target we set our altitude to this because that's the only thing that matters: distance
        -- TODO: we may find out what is near us and automatically select the closest object
        local target_id = ConvertIDTo64Bit(GetPlayerTarget()) or 0
        if target_id > 0 and C.GetPlayerOccupiedShipID() > 0 and target_id ~= C.GetPlayerOccupiedShipID() then
            altitude = C.GetDistanceBetween(C.GetPlayerOccupiedShipID(), ConvertIDTo64Bit(target_id))
            -- round it so we don't invalidate the cache for each fractional move
            altitude = math.floor(altitude)

        end


        private.lastPos = pos

    else
        -- OnFoot
        -- log("SimPit: On Foot")
    end

    if C.GetPlayerOccupiedShipID() > 0 then
        --[[
            "normal"
            "notravel"
            "restricted"
            "noboost"
            "disabled"
            "disabled2"
        ]]--
        local engineStatus = ffi.string(C.GetObjectEngineStatus(C.GetPlayerOccupiedShipID()))

        if engineStatus == "disabled" or engineStatus == "disabled2" or engineStatus == "notravel" or engineStatus == "restricted" then
            -- Fsd MassLocked
            flags = flags + 65536
        elseif engineStatus == "noboost" then
            -- Fsd Charging
            flags = flags + 131072
        end

        -- log("SimPit: Engine status " ..tostring(engineStatus))

        -- Has Lat Long - we always do in X4
        flags = flags + 2097152

    end


    if boosting then 

    end
    -- HasJumpDrive()

    -- Supercruise
    if travelMode then
        flags = flags + 16
        -- log("SimPit: Supercruise")
    end

    -- log("SimPit: Supercruise: " ..tostring(travelMode))


    if C.HasSeta() then
        flags = flags + 65536
    end

    if C.IsMissileIncoming() or C.IsMissileLockingOn() or C.IsLowOnOxygen() then
        flags = flags + 4194304
        -- log("SimPit: in danger")
    end

    -- TODO: active weapon group
	-- activate the weapon group indicators
	-- updateWeaponGroup(private.weaponPanel.primary, C.GetActivePrimaryWeaponGroup(), false)
	--updateWeaponGroup(private.weaponPanel.secondary, C.GetActiveSecondaryWeaponGroup(), false)

    -- In Fighter / Spacesuit (EVA)
    if shipSize == "ship_s" or shipSize == "ship_xs" then
        flags = flags + 33554432
    elseif shipSize == "" then
        -- OnFoot
    else 
        -- In MainShip
        flags = flags + 16777216
    end

    -- In SRV / no SRVs in X4

    -- Hud in Analysis mode
    -- none, scan, scan_longrange, travel
    local playerActivity = GetPlayerActivity()
    if playerActivity == "scan" or playerActivity == "scan_longrange" then
        flags = flags + 134217728
    end

    -- Night Vision  / no NS in X4
    -- Altitude from Average radius / no altitude in X4

    -- fsdCharging always nil and probably completely unused in X4
    -- local isjumpdrivecharging, isjumpdrivebusy = GetComponentData(target_id, "isjumpdrivecharging", "isjumpdrivebusy")
    -- log("isjumpdrivecharging: " ..tostring(isjumpdrivecharging))
    -- log("isjumpdrivebusy: " ..tostring(isjumpdrivebusy))

    if C.IsSetaActive() then
        flags = flags + 1073741824
        -- log("SimPit: fsdJump on")
    end

    -- log("SimPit: Hull: " ..tostring(curPlayerHull) .."% Shield: " ..tostring(curPlayerShield) .."% Oxygen: " ..tostring(curOxygen) .."% Cargo: " ..cargo .."t Activity: " ..playerActivity .." Docked: " ..tostring(isDocked))

    local guiFocus = GuiFocus.NoFocus

    if C.IsFullscreenMenuDisplayed(false, "MapMenu") then
        guiFocus = GuiFocus.GalaxyMap
    elseif C.IsFullscreenMenuDisplayed(false, "ShipConfigurationMenu") then
        guiFocus = GuiFocus.StationServices
    elseif C.IsFullscreenMenuDisplayed(false, "StationConfigurationMenu") then
        guiFocus = GuiFocus.StationServices
    elseif C.IsFullscreenMenuDisplayed(false, "StationOverviewMenu") then
        guiFocus = GuiFocus.StationServices
    elseif C.IsFullscreenMenuDisplayed(false, "OptionsMenu") then
        guiFocus = GuiFocus.StationServices
    elseif C.IsFullscreenMenuDisplayed(false, "PlayerInfoMenu") then
        guiFocus = GuiFocus.RolePanel
    elseif C.IsFullscreenMenuDisplayed(false, "EncyclopediaMenu") then
        guiFocus = GuiFocus.Codex
    elseif C.IsFullscreenMenuDisplayed(false, "DockedMenu") then
        guiFocus = GuiFocus.InternalPanel
    end


    -- FIXME: get cluster
    local clusterID = C.GetContextByClass(C.GetPlayerID(), "cluster", false)
    local cluster = ConvertStringTo64Bit(tostring(clusterID))
    if private.lastCluster == cluster then
        -- no changes
    else
        private.lastCluster = cluster
        local sector = C.GetContextByClass(C.GetPlayerID(), "sector", false)
        log("New cluster " ..tostring(cluster))
        log("New sector " ..ConvertStringTo64Bit(tostring(sector)))
        local counts = C.GetNumUISystemInfo(clusterID)
        local info = ffi.new("UISystemInfo2")
        info.numplanets = counts.numplanets
        info.space = Helper.ffiNewHelper("UISpaceInfo")
        info.numsuns = counts.numsuns
        info.suns = Helper.ffiNewHelper("UISunInfo[?]", info.numsuns)
        info.planets = Helper.ffiNewHelper("UICelestialBodyInfo2[?]", info.numplanets)
    
        local result = {}
    
        if C.GetUISystemInfo2(info, clusterID) then
            result.space = { environment = ffi.string(info.space.environment) }
            log("Reading space " ..tostring(result.space.environment))
            for i = 0, info.numplanets - 1 do
                local planetName = info.planets[i].name
                -- assign some bodyName - we do not have any coordinates anyway. We MIGHT create a manual lookup tables with NEARSAY data
                private.bodyName = ffi.string(planetName)
            end
        end
    end


    local pos = {0, 0, 0}
    if private.lastPos ~= nil then
        pos = { private.lastPos.x, private.lastPos.y, private.lastPos.z }
    end

    return {
        event = "Status",
        -- X4 does not have pips so we report a neutral default
        Pips = {4,4,4},
        GuiFocus = guiFocus,
        Flags = flags,
        Latitude = latitude,
        Longitude = longitude,
        Altitude = altitude,
        Heading = angle,
        Pos = pos,
        -- FIXME: Implement IllegalCargo
        LegalState = LegalState.Clean,
        Speed = tostring(manualSpeedPerSecond),
        Oxygen = curOxygen / 100,
        Health = curPlayerHull / 100,
        Shield = curPlayerShield / 100,
        FireGroup = C.GetActivePrimaryWeaponGroup() or 0,
        Cargo = cargo,
        BodyName = private.bodyName,
        Balance = GetPlayerMoney(),
        Fuel =  {
            FuelMain = 0,
            FuelReservoir = 0
        }
    }
end


return L