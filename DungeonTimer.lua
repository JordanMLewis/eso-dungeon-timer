DungeonTimer = {
	name = "DungeonTimer",

	zoneIds = {
		--[[
		Format: [zoneId] = { mode, speedrun }
			 0 - timer starts upon initial engagement
			-1 - timer starts when group crosses undetectable threshold (as subsitute, treat as "mode 0")
			-2 - timer starts upon a certain combat event
			 N - timer starts when group enters subzone designated by N
		--]]
		[ 144] = {     0, 20 }, -- Spindleclutch I
		[ 936] = {     0, 20 }, -- Spindleclutch II
		[ 380] = {    -1, 20 }, -- The Banished Cells I
		[ 935] = {     0, 20 }, -- The Banished Cells II
		[ 283] = {    -1, 15 }, -- Fungal Grotto I
		[ 934] = {     0, 20 }, -- Fungal Grotto II
		[ 146] = {    -1, 15 }, -- Wayrest Sewers I
		[ 933] = {     0, 20 }, -- Wayrest Sewers II
		[ 126] = {     0, 20 }, -- Elden Hollow I
		[ 931] = {     0, 20 }, -- Elden Hollow II
		[  63] = {    -1, 20 }, -- Darkshade Caverns I
		[ 930] = {     0, 20 }, -- Darkshade Caverns II
		[ 130] = {     0, 20 }, -- Crypt of Hearts I
		[ 932] = {    -1, 30 }, -- Crypt of Hearts II
		[ 176] = {     0, 20 }, -- City of Ash I
		[ 681] = {  8388, 30 }, -- City of Ash II (Inner Grove)
		[ 148] = {     0, 20 }, -- Arx Corinium
		[  22] = {     0, 20 }, -- Volenfell
		[ 131] = {     0, 20 }, -- Tempest Island
		[ 449] = {    -1, 20 }, -- Direfrost Keep
		[  38] = {    -1, 20 }, -- Blackheart Haven
		[  31] = {     0, 20 }, -- Selene's Web
		[  64] = {    -1, 20 }, -- Blessed Crucible
		[  11] = {     0, 20 }, -- Vaults of Madness
		[ 678] = {  8748, 45 }, -- Imperial City Prison (Bastion)
		[ 688] = {  8982, 30 }, -- White-Gold Tower (Green Emperor Way)
		[ 843] = {    -1, 30 }, -- Ruins of Mazzatun
		[ 848] = {    -1, 30 }, -- Cradle of Shadows
		[ 973] = {    -1, 20 }, -- Bloodroot Forge
		[ 974] = {     0, 20 }, -- Falkreath Hold
		[1009] = {     0, 30 }, -- Fang Lair
		[1010] = {     0, 30 }, -- Scalecaller Peak
		[1052] = {     0, 30 }, -- Moon Hunter Keep
		[1055] = { 13161, 30 }, -- March of Sacrifices (Bloodscent Pass)
		[1080] = {     0, 30 }, -- Frostvault
		[1081] = {     0, 30 }, -- Depths of Malatar
		[1122] = {     0, 30 }, -- Moongrave Fane
		[1123] = {     0, 35 }, -- Lair of Maarselok
		[1152] = {     0, 30 }, -- Icereach
		[1153] = {    -2, 30 }, -- Unhallowed Grave
		[1197] = {     0, 25 }, -- Stone Garden
		[1201] = {     0, 30 }, -- Castle Thorn
	},

	pollingInterval = 750, -- 0.75 seconds

	-- Default settings
	defaults = {
		left = 0,
		top = 0,
		zoneId = 0,
		startTime = 0,
	},

	dungeon_in_progress = true,

	initialized = false,
	active = false,
	combatEvents = false,
	mode = 0,
	speedrun = 0,
	lastQueue = 0,
}

local function OnAddOnLoaded( eventCode, addonName )
	if (addonName ~= DungeonTimer.name) then return end

	EVENT_MANAGER:UnregisterForEvent(DungeonTimer.name, EVENT_ADD_ON_LOADED)

	DungeonTimer.vars = ZO_SavedVars:NewAccountWide("DungeonTimerSavedVariables", 1, nil, DungeonTimer.defaults, nil, "$InstallationWide")

	EVENT_MANAGER:RegisterForEvent(DungeonTimer.name, EVENT_PLAYER_ACTIVATED, DungeonTimer.OnPlayerActivated)
	EVENT_MANAGER:RegisterForEvent(DungeonTimer.name, EVENT_ACTIVITY_FINDER_STATUS_UPDATE, DungeonTimer.OnActivityFinderStatusUpdate)
	EVENT_MANAGER:RegisterForEvent(DungeonTimer.name, EVENT_ACTIVITY_FINDER_ACTIVITY_COMPLETE, DungeonTimer.OnDungeonComplete)
end

function DungeonTimer.OnPlayerActivated( eventCode, initial )
	if (not DungeonTimer.initialized) then
		DungeonTimer.initialized = true
		DungeonTimer.InitializeUI()
	end

	DungeonTimer.dungeon_in_progress = true

	local zoneId = GetZoneId(GetUnitZoneIndex("player"))
	local dungeon = DungeonTimer.zoneIds[zoneId]

	if (dungeon and GetCurrentZoneDungeonDifficulty() == DUNGEON_DIFFICULTY_VETERAN or GetCurrentZoneDungeonDifficulty() == DUNGEON_DIFFICULTY_NORMAL) then
		DungeonTimer.mode = (dungeon[1] == -1) and 0 or dungeon[1]
		DungeonTimer.speedrun = dungeon[2] * 60

		if (DungeonTimer.vars.zoneId ~= zoneId or GetTimeStamp() - DungeonTimer.lastQueue < 180000) then
			DungeonTimer.vars.zoneId = zoneId
			DungeonTimer.vars.startTime = 0
			DungeonTimer.lastQueue = 0
		end

		DungeonTimer.ToggleCombatEvents(true)

		if (not DungeonTimer.active) then
			DungeonTimer.active = true

			EVENT_MANAGER:RegisterForEvent(DungeonTimer.name, EVENT_PLAYER_COMBAT_STATE, DungeonTimer.OnPlayerCombatState)
			EVENT_MANAGER:RegisterForEvent(DungeonTimer.name, EVENT_ZONE_CHANGED, DungeonTimer.OnZoneChanged)
			EVENT_MANAGER:RegisterForUpdate(DungeonTimer.name, DungeonTimer.pollingInterval, DungeonTimer.Poll)

			if (IsUnitInCombat("player")) then
				DungeonTimer.OnPlayerCombatState(nil, true)
			end

			DungeonTimer.Poll()

			SCENE_MANAGER:GetScene("hud"):AddFragment(DungeonTimer.fragment)
			SCENE_MANAGER:GetScene("hudui"):AddFragment(DungeonTimer.fragment)
		end
	else
		DungeonTimer.vars.zoneId = 0
		DungeonTimer.vars.startTime = 0

		DungeonTimer.ToggleCombatEvents(false)

		if (DungeonTimer.active) then
			DungeonTimer.active = false

			EVENT_MANAGER:UnregisterForEvent(DungeonTimer.name, EVENT_PLAYER_COMBAT_STATE)
			EVENT_MANAGER:UnregisterForEvent(DungeonTimer.name, EVENT_ZONE_CHANGED)
			EVENT_MANAGER:UnregisterForUpdate(DungeonTimer.name)

			SCENE_MANAGER:GetScene("hud"):RemoveFragment(DungeonTimer.fragment)
			SCENE_MANAGER:GetScene("hudui"):RemoveFragment(DungeonTimer.fragment)
		end
	end
end

function DungeonTimer.OnActivityFinderStatusUpdate( eventCode, result )
	-- Cover the case where a group requeues directly into the same dungeon.
	-- The forming group signal is the closest approximation to the start of a
	-- queued instance since ACTIVITY_FINDER_STATUS_IN_PROGRESS can be signaled
	-- by a reload.
	if (result == ACTIVITY_FINDER_STATUS_FORMING_GROUP or result == ACTIVITY_FINDER_STATUS_READY_CHECK) then
		DungeonTimer.lastQueue = GetTimeStamp()
	end
end

function DungeonTimer.OnCombatEvent( eventCode, result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId, overflow )
	if (DungeonTimer.vars.zoneId == 1153) then
		-- Unhallowed Grave
		if (result == ACTION_RESULT_EFFECT_GAINED and abilityId == 131774) then
			DungeonTimer.StartTimer()
			DungeonTimer.ToggleCombatEvents(false)
		end
	end
end

function DungeonTimer.OnPlayerCombatState( eventCode, inCombat )
	if (inCombat and DungeonTimer.mode == 0) then
		DungeonTimer.StartTimer()
	end
end

function DungeonTimer.OnZoneChanged( eventCode, zoneName, subZoneName, newSubzone, zoneId, subZoneId )
	if (subZoneId ~= 0 and DungeonTimer.mode == subZoneId) then
		DungeonTimer.StartTimer()
	end
end

function DungeonTimer.OnMoveStop()
	DungeonTimer.vars.left = DungeonTimerFrame:GetLeft()
	DungeonTimer.vars.top = DungeonTimerFrame:GetTop()
end

function DungeonTimer.OnDungeonComplete(eventCode)
	DungeonTimer.dungeon_in_progress = false
end

function DungeonTimer.Poll( )
	if (true == DungeonTimer.dungeon_in_progress) then
		local elapsed = (DungeonTimer.vars.startTime > 0) and GetTimeStamp() - DungeonTimer.vars.startTime or 0

		DungeonTimer.label:SetText(string.format("%02d:%02d", zo_floor(elapsed / 60), elapsed % 60))

		if (elapsed < DungeonTimer.speedrun) then
			DungeonTimer.label:SetColor(1, 1, 1, 1)
		else
			DungeonTimer.label:SetColor(1, 0.2, 0.2, 1)
		end
	end
end

function DungeonTimer.StartTimer( )
	if (DungeonTimer.vars.startTime == 0) then
		DungeonTimer.vars.startTime = GetTimeStamp()
		GetAddOnManager():RequestAddOnSavedVariablesPrioritySave(DungeonTimer.name)
	end
end

function DungeonTimer.InitializeUI( )
	DungeonTimerFrame:ClearAnchors()
	DungeonTimerFrame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, DungeonTimer.vars.left, DungeonTimer.vars.top)

	DungeonTimerFrame:GetNamedChild("Icon"):SetTexture("/esoui/art/miscellaneous/timer_32.dds")

	DungeonTimer.fragment = ZO_HUDFadeSceneFragment:New(DungeonTimerFrame)
	DungeonTimer.label = DungeonTimerFrame:GetNamedChild("Label")
end

function DungeonTimer.ToggleCombatEvents( enable )
	if (enable) then
		if (not DungeonTimer.combatEvents and DungeonTimer.mode == -2 and DungeonTimer.vars.startTime == 0) then
			DungeonTimer.combatEvents = true
			EVENT_MANAGER:RegisterForEvent(DungeonTimer.name, EVENT_COMBAT_EVENT, DungeonTimer.OnCombatEvent)
		end
	else
		if (DungeonTimer.combatEvents) then
			DungeonTimer.combatEvents = false
			EVENT_MANAGER:UnregisterForEvent(DungeonTimer.name, EVENT_COMBAT_EVENT)
		end
	end
end

EVENT_MANAGER:RegisterForEvent(DungeonTimer.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
