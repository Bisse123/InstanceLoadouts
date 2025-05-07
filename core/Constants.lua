local addonName, addon = ...

-- Localize global functions
local EJ_GetTierInfo = EJ_GetTierInfo
local EJ_GetNumTiers = EJ_GetNumTiers
local EJ_GetInstanceByIndex = EJ_GetInstanceByIndex
local EJ_SelectInstance = EJ_SelectInstance
local EJ_GetEncounterInfoByIndex = EJ_GetEncounterInfoByIndex
local EJ_SelectTier = EJ_SelectTier
local GetRealZoneText = GetRealZoneText
local GetNumBattlegroundTypes = GetNumBattlegroundTypes
local GetBattlegroundInfo = GetBattlegroundInfo
local tinsert = tinsert
local CopyTable = CopyTable

addon.ConvertIDToName = {}

-- Raid boss npc IDs
addon.raidBossIDs = {
    [2769] = { -- Liberation of Undermine
        [3009] = {225822, 225821}, -- Vexie and the Geargrinder
        [3010] = {229181, 229177}, -- Cauldron of Carnage
        [3011] = {228652}, -- Rik Reverb
        [3012] = {230322}, -- Stix Bunkjunker
        [3013] = {230583}, -- Sprocketmonger Lockenstock
        [3014] = {228458}, -- One-Armed Bandit
        [3015] = {229953}, -- Mug'zee
        [3016] = {237194}, -- Chrome King Gallywix
    },
}

addon.defaultJournalIDs = {
    ["Dungeon"] = {},
    ["Raid"] = {},
}
addon.instanceGroups ={
    ["Dungeon"] = {},
    ["Raid"] = {},
    ["Delve"] = {},
    ["Arena"] = {},
    ["Battleground"] = {},
    ["Open World"] = {},
}

-- Populate with current season M+ Dungeons
function addon:getCurrentSeasonDungeons()
    local dungeonJournalIDs = self.db.global.journalIDs.Dungeon
    local dungeon = self.instanceGroups.Dungeon
    local currentSeason = EJ_GetNumTiers()
    local currentSeasonName = EJ_GetTierInfo(currentSeason)
    self.defaultJournalIDs.Dungeon[currentSeason] = {}
    if not dungeonJournalIDs[currentSeason] then
        dungeonJournalIDs[currentSeason] = {}
    end
    local instanceIDs = {{instanceID = -1, instanceName = "Default"}}
    for instanceIdx = 1, 99 do
        local journalInstanceID, instanceName, _, _, _, _, _, _, _, _, instanceID = EJ_GetInstanceByIndex(instanceIdx, false)
        if not journalInstanceID then
            break
        end
        self.defaultJournalIDs.Dungeon[currentSeason][journalInstanceID] = true
        if not dungeonJournalIDs[currentSeason][journalInstanceID] then
            dungeonJournalIDs[currentSeason][journalInstanceID] = true
        end
        tinsert(instanceIDs, {instanceID = instanceID, instanceName = instanceName})
    end
    tinsert(dungeon, {tierID = currentSeason, tierName = currentSeasonName, instanceIDs = instanceIDs})
end

-- Populate with current season Raids
function addon:getCurrentSeasonRaids()
    local raidJournalIDs = self.db.global.journalIDs.Raid
    local raid = self.instanceGroups.Raid
    for instanceIdx = 2, 99 do
        local journalInstanceID, instanceName, _, _, _, _, _, _, _, _, instanceID = EJ_GetInstanceByIndex(instanceIdx, true)
        if not journalInstanceID then
            break
        end
        self.defaultJournalIDs.Raid[journalInstanceID] = {}
        if not raidJournalIDs[journalInstanceID] then
            raidJournalIDs[journalInstanceID] = {}
        end
        EJ_SelectInstance(journalInstanceID)
        local encounterIDs = {{encounterID = -1, encounterName = "Default"}}
        for encounterIdx = 1, 99 do
            local encounterName, _, journalEncounterID, _, _, _, encounterID = EJ_GetEncounterInfoByIndex(encounterIdx)
            if not journalEncounterID then
                break
            end
            local npcIDs = {}
            if self.raidBossIDs[instanceID] and self.raidBossIDs[instanceID][encounterID] then
                npcIDs = CopyTable(self.raidBossIDs[instanceID][encounterID])
            end
            self.defaultJournalIDs.Raid[journalInstanceID][journalEncounterID] = CopyTable(npcIDs)
            if not raidJournalIDs[journalInstanceID][journalEncounterID] then
                raidJournalIDs[journalInstanceID][journalEncounterID] = npcIDs
            else
                npcIDs = raidJournalIDs[journalInstanceID][journalEncounterID]
            end
            tinsert(encounterIDs, {encounterID = encounterID, encounterName = encounterName, npcIDs = npcIDs})
        end
        tinsert(raid, {instanceID = instanceID, instanceName = instanceName, encounterIDs = encounterIDs})
    end
end

-- Populate with current season Delves
function addon:getCurrentSeasonDelves()
    local instanceIDs = {
        2664, -- Fungal Folly
        2679, -- Mycomancer Cavern
        2680, -- Earthcrawl Mines
        2681, -- Kriegval's Rest
        -- 2682, -- Zekvir's Lair TWW Season 1
        2683, -- The Waterworks
        2684, -- The Dread Pit
        2685, -- Skittering Breach
        2686, -- Nightfall Sanctum
        2687, -- The Sinkhole
        2688, -- The Spiral Weave
        2689, -- Tak-Rethan Abyss
        2690, -- The Underkeep
        2815, -- Excavation Site 9
        2826, -- Sidestreet Sluice
        2831, -- Demolition Dome TWW Season 2
    }

    local delve = self.instanceGroups.Delve
    tinsert(delve, {instanceID = -1, instanceName = "Default"})
    
    for _, instanceID in ipairs(instanceIDs) do
        local instanceName = GetRealZoneText(instanceID)
        tinsert(delve, {instanceID = instanceID, instanceName = instanceName})
    end
end

-- Populate with current season Arenas
function addon:getCurrentSeasonArenas()
    local  instanceIDs = {
        572, -- Ruins of Lordaeron
        617, -- Dalaran Sewers
        618, -- The Ring of Valor
        980, -- Tol'Viron Arena
        1134, -- Tiger's Peak
        1504, -- Black Rook Hold Arena
        1505, -- Nagrand Arena
        1552, -- Ashamane's Fall
        1672, -- Blade's Edge Arena
        1825, -- Hook Point
        1911, -- Mugambala
        2167, -- The Robodrome
        2373, -- Empyrean Domain
        2509, -- Maldraxxus Coliseum
        2547, -- Enigma Crucible
        2563, -- Nokhudon Proving Grounds
        2759, -- Cage of Carnage

    }

    local arena = self.instanceGroups.Arena
    tinsert(arena, {instanceID = -1, instanceName = "Default"})

    for _, instanceID in ipairs(instanceIDs) do
        local instanceName = GetRealZoneText(instanceID)
        tinsert(arena, {instanceID = instanceID, instanceName = instanceName})
    end

end

-- Populate with current season Battlegrounds
function addon:getCurrentSeasonBattlegrounds()
    local battleground = self.instanceGroups.Battleground
    tinsert(battleground, {instanceID = -1, instanceName = "Default"})
    for idx = 1, GetNumBattlegroundTypes() do
        local instanceName, _, _, _, _, _, instanceID = GetBattlegroundInfo(idx)
        tinsert(battleground, {instanceID = instanceID, instanceName = instanceName})
    end
end

-- Populate with current season Open World
function addon:getCurrentSeasonOpenWorld()
    local openWorld = self.instanceGroups["Open World"]
    tinsert(openWorld, {instanceID = -1, instanceName = "Default"})
end

function addon:getCurrentSeason()
    EJ_SelectTier(EJ_GetNumTiers())
    self:getCurrentSeasonDungeons()
    self:getCurrentSeasonRaids()
    self:getCurrentSeasonDelves()
    self:getCurrentSeasonArenas()
    self:getCurrentSeasonBattlegrounds()
    self:getCurrentSeasonOpenWorld()
end
