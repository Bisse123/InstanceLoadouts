local addonName, addon = ...

local C = addon.Components

local journalInstance

---Adds a raid instance to the custom instances list
---@param journalInstanceID number The journal instance ID of the raid to add
---@return number instanceID The game instance ID, as used by the config list
function addon:addRaidInstance(journalInstanceID)
    local raidJournalIDs = self.db.global.journalIDs.Raid
    if not raidJournalIDs[journalInstanceID] then
        raidJournalIDs[journalInstanceID] = {}
    end
    EJ_SelectInstance(journalInstanceID)
    for encounterIdx = 1, 99 do
        local _, _, journalEncounterID = EJ_GetEncounterInfoByIndex(encounterIdx, journalInstanceID)
        if not journalEncounterID then
            break
        end
        if not raidJournalIDs[journalInstanceID][journalEncounterID] then
            raidJournalIDs[journalInstanceID][journalEncounterID] = {}
        end
    end
    local _, _, _, _, _, _, _, _, _, instanceID = EJ_GetInstanceInfo(journalInstanceID)
    self:getCustomEncounterJournalRaids()
    return instanceID
end

---Adds a dungeon instance to the custom instances list
---@param journalInstanceID number The journal instance ID of the dungeon to add
---@param tierID number|nil The tier to file under; defaults to the journal's current tier
---@param wantInstanceID boolean|nil Look up the game instance ID; this selects the
---  instance in the journal, so batch adds leave it off to avoid moving the view
---@return number tierID The tier the dungeon was added to, as used by the config list
---@return number|nil instanceID The game instance ID, as used by the config's dungeon list
function addon:addDungeonInstance(journalInstanceID, tierID, wantInstanceID)
    local dungeonJournalIDs = self.db.global.journalIDs.Dungeon
    local currentTier = tierID or EJ_GetCurrentTier()
    if not dungeonJournalIDs[currentTier] then
        dungeonJournalIDs[currentTier] = {}
    end
    if not dungeonJournalIDs[currentTier][journalInstanceID] then
        dungeonJournalIDs[currentTier][journalInstanceID] = true
    end
    local instanceID
    if wantInstanceID then
        EJ_SelectInstance(journalInstanceID)
        local _
        _, _, _, _, _, _, _, _, _, instanceID = EJ_GetInstanceInfo(journalInstanceID)
    end
    self:getCustomEncounterJournalDungeons()
    return currentTier, instanceID
end

---Removes a raid instance from the custom instances list
---@param journalInstanceID number The journal instance ID of the raid to remove
function addon:removeRaidInstance(journalInstanceID)
    local raidJournalIDs = self.db.global.journalIDs.Raid
    if raidJournalIDs[journalInstanceID] then
        EJ_SelectInstance(journalInstanceID)
        local _, _, _, _, _, _, _, _, _, instanceID = EJ_GetInstanceInfo(journalInstanceID)
        raidJournalIDs[journalInstanceID] = nil
        local raid = self.instanceGroups.Raid
        for idx, instanceInfo in ipairs(raid) do
            if instanceInfo.instanceID == instanceID then
                table.remove(raid, idx)
                break
            end
        end
    end
end

---Removes a dungeon instance from the custom instances list
---@param journalInstanceID number The journal instance ID of the dungeon to remove
function addon:removeDungeonInstance(journalInstanceID)
    local dungeonJournalIDs = self.db.global.journalIDs.Dungeon
    local currentTier = EJ_GetCurrentTier()
    if dungeonJournalIDs[currentTier] then
        dungeonJournalIDs[currentTier][journalInstanceID] = nil
        self:getCustomEncounterJournalDungeons()
    end
end

---Adds the player's current zone as a custom Open World location
function addon:addCurrentOpenWorldLocation()
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then return end
    local mapInfo = C_Map.GetMapInfo(mapID)
    if not mapInfo then return end
    local openWorldIDs = self.db.global.journalIDs["Open World"]
    openWorldIDs[mapID] = mapInfo.name
    self:getCustomOpenWorldLocations()
end

---Removes a custom Open World location
---@param mapID number The map ID of the location to remove
function addon:removeOpenWorldLocation(mapID)
    local openWorldIDs = self.db.global.journalIDs["Open World"]
    openWorldIDs[mapID] = nil
    self:getCustomOpenWorldLocations()
end

---Refreshes the Config window after a custom instance change, if it's open
local function RefreshAfterJournalChange()
    local default = addon:generateDefaults()
    addon.db:RegisterDefaults(default)
    if addon.frame and addon.frameType == "Config" then
        addon:openConfig()
    end
end

---Creates the add instance button in the Encounter Journal
---@return table addButton The created button frame
function addon:CreateAddInstanceButton()
    local addButton = C:CreateButton(EncounterJournal, "", {
        width = 200,
        height = 40,
        callback = function()
            if EJ_GetCurrentTier() == EJ_GetNumTiers() then
                return
            end
            local isRaidTab = EncounterJournal_IsRaidTabSelected(EncounterJournal)
            -- The config list is selected by game instance ID for raids and by
            -- tier ID for dungeons; when adding a whole expansion, select the
            -- first instance that got added
            local addedID, addedDungeonID
            if journalInstance then
                if isRaidTab then
                    addedID = addon:addRaidInstance(journalInstance)
                else
                    addedID, addedDungeonID = addon:addDungeonInstance(journalInstance, nil, true)
                end
            else
                -- EJ_GetInstanceByIndex enumerates the selected tier, and adding
                -- selects instances (which can move the tier), so snapshot the
                -- list first and restore the tier around each add
                local tier = EJ_GetCurrentTier()
                local contentTab = EncounterJournal.selectedTab
                local journalInstanceIDs = {}
                for instanceIdx = 1, 99 do
                    local journalInstanceID = EJ_GetInstanceByIndex(instanceIdx, isRaidTab)
                    if not journalInstanceID then
                        break
                    end
                    -- index 1 of the raid list is not an addable instance
                    if not isRaidTab or instanceIdx > 1 then
                        tinsert(journalInstanceIDs, journalInstanceID)
                    end
                end
                for _, journalInstanceID in ipairs(journalInstanceIDs) do
                    local id
                    if isRaidTab then
                        EncounterJournal_DisplayInstance(journalInstanceID)
                        id = addon:addRaidInstance(journalInstanceID)
                    else
                        id = addon:addDungeonInstance(journalInstanceID, tier)
                    end
                    addedID = addedID or id
                end
                -- Rebuilding the instance lists selects instances in the journal;
                -- put it back on this expansion's instance list
                EJ_SelectTier(tier)
                EJ_ContentTab_Select(contentTab)
            end
            addon.ConfigView.instanceType = isRaidTab and "Raid" or "Dungeon"
            if addedID then
                addon.ConfigView.instance = addedID
            end
            -- Adding one dungeon selects it; adding a whole expansion leaves the
            -- tier's Default entry selected
            if not isRaidTab and addedID then
                addon.ConfigView.encounter[addedID] = addedDungeonID or -1
            end
            RefreshAfterJournalChange()
            addon:openConfig()
        end,
    })
    addButton:SetPoint("TOPRIGHT", EncounterJournal, "BOTTOMRIGHT", 0, -1)

    -- The button floats over the world rather than sitting on a window, so give
    -- it an opaque backing to match the theme's translucent bg.med against
    local backing = addButton:CreateTexture(nil, "BACKGROUND", nil, -1)
    backing:SetAllPoints()
    local bg = addon.Theme.bg.dark
    backing:SetColorTexture(bg.r, bg.g, bg.b, 1)

    return addButton
end

---Creates the remove instance button in the Encounter Journal
---@param addButton table The add button frame to position relative to
---@return table removeButton The created button frame
function addon:CreateRemoveInstanceButton(addButton)
    local removeButton = C:CreateButton(EncounterJournal, "", {
        width = 200,
        height = 40,
        callback = function()
            if EJ_GetCurrentTier() == EJ_GetNumTiers() then
                return
            end
            local isRaidTab = EncounterJournal_IsRaidTabSelected(EncounterJournal)
            if journalInstance then
                if isRaidTab then
                    addon:removeRaidInstance(journalInstance)
                else
                    addon:removeDungeonInstance(journalInstance)
                end
            else
                for instanceIdx = 1, 99 do
                    local journalInstanceID = EJ_GetInstanceByIndex(instanceIdx, isRaidTab)
                    if not journalInstanceID then
                        break
                    end
                    if not isRaidTab then
                        addon:removeDungeonInstance(journalInstanceID)
                    elseif instanceIdx > 1 then
                        EncounterJournal_DisplayInstance(journalInstanceID)
                        addon:removeRaidInstance(journalInstanceID)
                        EJ_ContentTab_Select(EncounterJournal.raidsTab:GetID())
                    end
                end
            end
            RefreshAfterJournalChange()
        end,
    })
    removeButton:SetPoint("TOPRIGHT", addButton, "BOTTOMRIGHT", 0, 0)
    return removeButton
end

---Creates both add and remove instance buttons in the Encounter Journal
function addon:CreateInstanceButtons()
    local addButton = self:CreateAddInstanceButton()

    ---Recomputes the add button's label and visibility from the journal's current state
    local function RefreshAddButton()
        if EJ_GetCurrentTier() == EJ_GetNumTiers() then
            addButton:Hide()
            return
        end

        local text
        if EncounterJournal.encounter:IsShown() then
            text = EncounterJournal.encounter.instance.title:GetText()
        elseif EncounterJournal.instanceSelect:IsShown() then
            journalInstance = nil
            text = EJ_GetTierInfo(EJ_GetCurrentTier()) .. " " .. EncounterJournal.instanceSelect.Title:GetText()
        else
            addButton:Hide()
            return
        end

        addButton:SetLabel("Instance Loadouts Add:\n" .. text)
        addButton:SetWidth(addButton.label:GetStringWidth() + 25)
        addButton:Show()
    end

    EventRegistry:RegisterCallback("EncounterJournal.TabSet", RefreshAddButton)

    self:RegisterEvent("CVAR_UPDATE", function(event, cvar)
        if cvar == "EJSelectedTier" then
            RefreshAddButton()
        end
    end)

    self:SecureHook("EncounterJournal_DisplayInstance", function(journalInstanceID)
        journalInstance = journalInstanceID
        RefreshAddButton()
    end)
    EncounterJournal.instanceSelect:HookScript("OnShow", RefreshAddButton)
    EncounterJournal:HookScript("OnShow", RefreshAddButton)
end

---Gets and populates custom dungeon instances from the journal
function addon:getCustomEncounterJournalDungeons()
    local dungeonJournalIDs = self.db.global.journalIDs.Dungeon
    local dungeon = self.instanceGroups.Dungeon
    for tierID, journalInstanceIDs in pairs(dungeonJournalIDs) do
        local tierName = EJ_GetTierInfo(tierID)
        if not tierName then
            break
        end
        local tierIdx
        local instanceIDs = {{instanceID = -1, instanceName = "Default"}}
        for tierIndex, tierInfo in ipairs(dungeon) do
            if tierInfo.tierID == tierID then
                tierIdx = tierIndex
                break
            end
        end
        for dungeonJournalID, _ in pairs(journalInstanceIDs) do
            -- EJ_GetInstanceInfo only returns data for the selected instance, and
            -- a single miss must not abandon the rest of the tier
            EJ_SelectInstance(dungeonJournalID)
            local instanceName, _, _, _, _, _, _, _, _, instanceID = EJ_GetInstanceInfo(dungeonJournalID)
            if instanceID then
                tinsert(instanceIDs, {instanceID = instanceID, instanceName = instanceName})
            end
        end
        if tierIdx then
            dungeon[tierIdx] = {tierID = tierID, tierName = tierName, instanceIDs = instanceIDs}
        else
            tinsert(dungeon, {tierID = tierID, tierName = tierName, instanceIDs = instanceIDs})
        end
    end
end

---Gets and populates custom raid instances from the journal
function addon:getCustomEncounterJournalRaids()
    local raidJournalIDs = self.db.global.journalIDs.Raid
    local raid = self.instanceGroups.Raid
    for journalInstanceID, journalEncounterIDs in pairs(raidJournalIDs) do
        -- EJ_GetInstanceInfo only returns data for the selected instance, and a
        -- single miss must not abandon the rest of the rebuild
        EJ_SelectInstance(journalInstanceID)
        local instanceName, _, _, _, _, _, _, _, _, instanceID = EJ_GetInstanceInfo(journalInstanceID)
        local alreadyExist = false
        for _, instanceInfo in ipairs(raid) do
            if instanceInfo.instanceID == instanceID then
                alreadyExist = true
                break
            end
        end
        if instanceID and not alreadyExist then
            local encounterIDs = {{encounterID = -1, encounterName = "Default"}}
            for journalEncounterID, npcIDs in pairs(journalEncounterIDs) do
                local encounterName, _, _, _, _, _, encounterID = EJ_GetEncounterInfo(journalEncounterID)
                if not encounterID then
                    break
                end
                tinsert(encounterIDs, {encounterID = encounterID, encounterName = encounterName, npcIDs = npcIDs})
            end
            tinsert(raid, {instanceID = instanceID, instanceName = instanceName, encounterIDs = encounterIDs})
        end
    end
end

---Gets and populates custom Open World locations
function addon:getCustomOpenWorldLocations()
    local openWorldIDs = self.db.global.journalIDs["Open World"]
    local openWorld = self.instanceGroups["Open World"]
    for idx = #openWorld, 1, -1 do
        if openWorld[idx].instanceID ~= -1 then
            table.remove(openWorld, idx)
        end
    end
    for mapID, mapName in pairs(openWorldIDs) do
        tinsert(openWorld, {instanceID = mapID, instanceName = mapName})
    end
end

---Gets and populates all custom instances from the journal
function addon:getCustomEncounterJournals()
    self:getCustomEncounterJournalDungeons()
    self:getCustomEncounterJournalRaids()
    self:getCustomOpenWorldLocations()
end

---Removes a custom dungeon instance from a specific tier
---@param tierID number The tier ID
---@param journalInstanceID number The journal instance ID of the dungeon to remove
function addon:removeDungeonInstanceFromTier(tierID, journalInstanceID)
    local tierInfo = self.db.global.journalIDs.Dungeon[tierID]
    if not tierInfo then return end
    EJ_SelectInstance(journalInstanceID)
    local _, _, _, _, _, _, _, _, _, instanceID = EJ_GetInstanceInfo(journalInstanceID)
    tierInfo[journalInstanceID] = nil
    local customJournalInstances = self.instanceGroups.Dungeon
    for instanceIdx, instanceInfo in ipairs(customJournalInstances) do
        if instanceInfo.tierID == tierID then
            for idx, instInfo in ipairs(instanceInfo.instanceIDs) do
                if instInfo.instanceID == instanceID then
                    table.remove(instanceInfo.instanceIDs, idx)
                    break
                end
            end
            break
        elseif instanceInfo.instanceID == instanceID then
            table.remove(customJournalInstances, instanceIdx)
            break
        end
    end
    local default = self:generateDefaults()
    self.db:RegisterDefaults(default)
end

---Removes an entire custom dungeon tier
---@param tierID number The tier ID to remove
function addon:removeDungeonTier(tierID)
    self.db.global.journalIDs.Dungeon[tierID] = nil
    local customJournalTiers = self.instanceGroups.Dungeon
    for tierIdx, customJournalInstances in ipairs(customJournalTiers) do
        if customJournalInstances.tierID == tierID then
            table.remove(customJournalTiers, tierIdx)
            break
        end
    end
    local default = self:generateDefaults()
    self.db:RegisterDefaults(default)
end

---Removes a custom encounter from a raid, keeping the raid itself if other encounters remain
---@param journalInstanceID number The journal instance ID of the raid
---@param journalEncounterID number The journal encounter ID to remove
function addon:removeEncounterFromRaid(journalInstanceID, journalEncounterID)
    local journalEncounterIDs = self.db.global.journalIDs.Raid[journalInstanceID]
    if not journalEncounterIDs then return end
    EJ_SelectInstance(journalInstanceID)
    local _, _, _, _, _, _, _, _, _, instanceID = EJ_GetInstanceInfo(journalInstanceID)
    local _, _, _, _, _, _, encounterID = EJ_GetEncounterInfo(journalEncounterID)
    journalEncounterIDs[journalEncounterID] = nil
    local customJournalInstances = self.instanceGroups.Raid
    for _, instanceInfo in ipairs(customJournalInstances) do
        if instanceInfo.instanceID == instanceID then
            for encounterIdx, encounterInfo in ipairs(instanceInfo.encounterIDs) do
                if encounterInfo.encounterID == encounterID then
                    table.remove(instanceInfo.encounterIDs, encounterIdx)
                    break
                end
            end
            break
        end
    end
    local default = self:generateDefaults()
    self.db:RegisterDefaults(default)
end
