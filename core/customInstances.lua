local addonName, addon = ...

local C = addon.Components

local customGroupsConfigView = {
    ["instanceType"] = nil,
}

local journalInstance

---Adds a raid instance to the custom instances list
---@param journalInstanceID number The journal instance ID of the raid to add
function addon:addRaidInstance(journalInstanceID)
    local raidJournalIDs = self.db.global.journalIDs.Raid
    if not raidJournalIDs[journalInstanceID] then
        raidJournalIDs[journalInstanceID] = {}
    end
    for encounterIdx = 1, 99 do
        local _, _, journalEncounterID = EJ_GetEncounterInfoByIndex(encounterIdx, journalInstanceID)
        if not journalEncounterID then
            break
        end
        if not raidJournalIDs[journalInstanceID][journalEncounterID] then
            raidJournalIDs[journalInstanceID][journalEncounterID] = {}
        end
    end
    self:getCustomEncounterJournalRaids()
end

---Adds a dungeon instance to the custom instances list
---@param journalInstanceID number The journal instance ID of the dungeon to add
function addon:addDungeonInstance(journalInstanceID)
    local dungeonJournalIDs = self.db.global.journalIDs.Dungeon
    local currentTier = EJ_GetCurrentTier()
    if not dungeonJournalIDs[currentTier] then
        dungeonJournalIDs[currentTier] = {}
    end
    if not dungeonJournalIDs[currentTier][journalInstanceID] then
        dungeonJournalIDs[currentTier][journalInstanceID] = true
    end
    self:getCustomEncounterJournalDungeons()
end

---Removes a raid instance from the custom instances list
---@param journalInstanceID number The journal instance ID of the raid to remove
function addon:removeRaidInstance(journalInstanceID)
    local raidJournalIDs = self.db.global.journalIDs.Raid
    if raidJournalIDs[journalInstanceID] then
        for encounterIdx = 1, 99 do
            local _, _, journalEncounterID = EJ_GetEncounterInfoByIndex(encounterIdx, journalInstanceID)
            if not journalEncounterID then
                break
            end
            raidJournalIDs[journalInstanceID][journalEncounterID] = nil
        end
        self:getCustomEncounterJournalRaids()
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

---Refreshes open windows after a custom instance change
local function RefreshAfterJournalChange()
    local default = addon:generateDefaults()
    addon.db:RegisterDefaults(default)
    if addon.frame and addon.frameType == "Custom" then
        addon:openCustomInstances()
    end
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
            if journalInstance then
                if isRaidTab then
                    addon:addRaidInstance(journalInstance)
                else
                    addon:addDungeonInstance(journalInstance)
                end
            else
                for instanceIdx = 1, 99 do
                    local journalInstanceID = EJ_GetInstanceByIndex(instanceIdx, isRaidTab)
                    if not journalInstanceID then
                        break
                    end
                    if not isRaidTab then
                        addon:addDungeonInstance(journalInstanceID)
                    elseif instanceIdx > 1 then
                        EncounterJournal_DisplayInstance(journalInstanceID)
                        addon:addRaidInstance(journalInstanceID)
                        EJ_ContentTab_Select(EncounterJournal.raidsTab:GetID())
                    end
                end
            end
            RefreshAfterJournalChange()
        end,
    })
    addButton:SetPoint("TOPRIGHT", EncounterJournal, "BOTTOMRIGHT", 0, 0)
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
    local currentTierName = EJ_GetTierInfo(EJ_GetCurrentTier())
    local title = ""

    local function UpdateAddButton(text)
        addButton:SetLabel(text)
        addButton:SetWidth(addButton.label:GetStringWidth() + 25)
    end

    EventRegistry:RegisterCallback("EncounterJournal.TabSet", function(info, tbl, tab)
        if EJ_GetCurrentTier() ~= EJ_GetNumTiers() and (tab == 3 or tab == 4) then
            journalInstance = nil
            title = EncounterJournal.instanceSelect.Title:GetText()
            UpdateAddButton("Instance Loadouts Add:\n" .. currentTierName .. " " .. title)
            addButton:Show()
        else
            addButton:Hide()
        end
    end)

    self:RegisterEvent("CVAR_UPDATE", function(event, cvar)
        if cvar == "EJSelectedTier" then
            if EJ_GetCurrentTier() ~= EJ_GetNumTiers() then
                currentTierName = EJ_GetTierInfo(EJ_GetCurrentTier())
                UpdateAddButton("Instance Loadouts Add:\n" .. currentTierName .. " " .. title)
                addButton:Show()
            else
                addButton:Hide()
            end
        end
    end)

    self:SecureHook("EncounterJournal_DisplayInstance", function(journalInstanceID)
        journalInstance = journalInstanceID
        title = EncounterJournal.encounter.instance.title:GetText()
        UpdateAddButton("Instance Loadouts Add:\n" .. title)
    end)
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
            local instanceName, _, _, _, _, _, _, _, _, instanceID = EJ_GetInstanceInfo(dungeonJournalID)
            if not instanceID then
                break
            end
            tinsert(instanceIDs, {instanceID = instanceID, instanceName = instanceName})
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
        local instanceName, _, _, _, _, _, _, _, _, instanceID = EJ_GetInstanceInfo(journalInstanceID)
        if not instanceID then
            break
        end
        local alreadyExist = false
        for _, instanceInfo in ipairs(raid) do
            if instanceInfo.instanceID == instanceID then
                alreadyExist = true
                break
            end
        end
        if not alreadyExist then
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

---Gets and populates all custom instances from the journal
function addon:getCustomEncounterJournals()
    self:getCustomEncounterJournalDungeons()
    self:getCustomEncounterJournalRaids()
end

---Adds a label + remove button row to a card
---@param card table The card to add the row to
---@param text string The row label
---@param onRemove function Called when the remove button is clicked
local function AddRemoveRow(card, text, onRemove)
    local theme = addon.Theme

    local row = CreateFrame("Frame", nil, card)
    row:SetHeight(22)

    local removeButton = C:CreateButton(row, "Remove", {
        width = 80,
        height = 20,
        callback = onRemove,
    })
    removeButton:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    removeButton.label:SetTextColor(theme.error.r, theme.error.g, theme.error.b, 1)

    local label = row:CreateFontString(nil, "OVERLAY")
    C.ApplyFont(label, "normal")
    label:SetPoint("LEFT", row, "LEFT", 0, 0)
    label:SetPoint("RIGHT", removeButton, "LEFT", -6, 0)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)
    label:SetText(text)
    local color = theme.text.primary
    label:SetTextColor(color.r, color.g, color.b, 1)

    card:AddWidget(row, nil, 22)
end

---Adds remove rows for the custom encounters of a raid instance to a card
---@param card table The card to add encounter rows to
---@param instanceTypeValue string The type of instance
---@param journalInstanceID number The journal instance ID
function addon:createCustomGroupsEncounterConfig(card, instanceTypeValue, journalInstanceID)
    local journalEncounterIDs = self.db.global.journalIDs[instanceTypeValue][journalInstanceID]

    for journalEncounterID, _ in pairs(journalEncounterIDs) do
        if not self.defaultJournalIDs[instanceTypeValue][journalEncounterID] then
            local _, _, _, _, _, _, _, _, _, instanceID = EJ_GetInstanceInfo(journalInstanceID)
            local encounterName, _, _, _, _, _, encounterID = EJ_GetEncounterInfo(journalEncounterID)

            AddRemoveRow(card, encounterName, function()
                journalEncounterIDs[journalEncounterID] = nil
                local customJournalInstances = addon.instanceGroups[instanceTypeValue]
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
                local default = addon:generateDefaults()
                addon.db:RegisterDefaults(default)
                addon:openCustomInstances()
            end)
        end
    end
end

---Builds the dungeon tab cards (one card per custom tier)
---@param scroller table The scroll content to add cards to
local function BuildDungeonTab(scroller)
    local instanceTypeValue = "Dungeon"
    local tierIDs = addon.db.global.journalIDs[instanceTypeValue]
    local theme = addon.Theme

    for tierID, tierInfo in pairs(tierIDs) do
        if not addon.defaultJournalIDs[instanceTypeValue][tierID] then
            local tierName = EJ_GetTierInfo(tierID)

            local card = C:CreateCard(scroller, tierName)

            local removeTierButton = C:CreateButton(card, "Remove " .. tierName, {
                height = 22,
                callback = function()
                    tierIDs[tierID] = nil
                    local customJournalTiers = addon.instanceGroups[instanceTypeValue]
                    for tierIdx, customJournalInstances in ipairs(customJournalTiers) do
                        if customJournalInstances.tierID == tierID then
                            table.remove(customJournalTiers, tierIdx)
                            break
                        end
                    end
                    local default = addon:generateDefaults()
                    addon.db:RegisterDefaults(default)
                    addon:openCustomInstances()
                end,
            })
            removeTierButton.label:SetTextColor(theme.error.r, theme.error.g, theme.error.b, 1)
            card:AddWidget(removeTierButton, nil, 22)

            if type(tierInfo) == "table" then
                for journalInstanceID, journalInstanceInfo in pairs(tierInfo) do
                    if not addon.defaultJournalIDs[instanceTypeValue][journalInstanceID] then
                        local instanceName, _, _, _, _, _, _, _, _, instanceID = EJ_GetInstanceInfo(journalInstanceID)

                        AddRemoveRow(card, instanceName, function()
                            tierInfo[journalInstanceID] = nil
                            local customJournalInstances = addon.instanceGroups[instanceTypeValue]
                            for instanceIdx, instanceInfo in ipairs(customJournalInstances) do
                                if instanceInfo.tierID == tierID then
                                    for idx, instInfo in ipairs(instanceInfo.instanceIDs) do
                                        if instInfo.instanceID == instanceID then
                                            table.remove(instanceInfo.instanceIDs, idx)
                                            break
                                        end
                                    end
                                elseif instanceInfo.instanceID == instanceID then
                                    table.remove(customJournalInstances, instanceIdx)
                                    break
                                end
                            end
                            local default = addon:generateDefaults()
                            addon.db:RegisterDefaults(default)
                            addon:openCustomInstances()
                        end)

                        if type(journalInstanceInfo) == "table" then
                            addon:createCustomGroupsEncounterConfig(card, instanceTypeValue, journalInstanceID)
                        end
                    end
                end
            end

            scroller:AddCard(card)
        end
    end
end

---Builds the raid tab cards (one card per custom raid instance)
---@param scroller table The scroll content to add cards to
local function BuildRaidTab(scroller)
    local instanceTypeValue = "Raid"
    local theme = addon.Theme

    for journalInstanceID, journalInstanceInfo in pairs(addon.db.global.journalIDs[instanceTypeValue]) do
        if not addon.defaultJournalIDs[instanceTypeValue][journalInstanceID] then
            local instanceName = EJ_GetInstanceInfo(journalInstanceID)

            local card = C:CreateCard(scroller, instanceName)

            local removeButton = C:CreateButton(card, "Remove " .. instanceName, {
                height = 22,
                callback = function()
                    addon.db.global.journalIDs[instanceTypeValue][journalInstanceID] = nil
                    local default = addon:generateDefaults()
                    addon.db:RegisterDefaults(default)
                    addon:openCustomInstances()
                end,
            })
            removeButton.label:SetTextColor(theme.error.r, theme.error.g, theme.error.b, 1)
            card:AddWidget(removeButton, nil, 22)

            if type(journalInstanceInfo) == "table" then
                addon:createCustomGroupsEncounterConfig(card, instanceTypeValue, journalInstanceID)
            end

            scroller:AddCard(card)
        end
    end
end

---Opens the custom instances configuration window
function addon:openCustomInstances()
    local _, content = self.UI.AcquireWindow("Custom", {
        width = 440,
        height = 440,
        icon = addon.icon,
        pageTitle = "Custom Instances",
        onGear = function()
            addon:openConfig()
        end,
    })

    local savedInstanceType = customGroupsConfigView.instanceType or "Dungeon"

    local function BuildTab(host, instanceType, builder)
        customGroupsConfigView.instanceType = instanceType
        if host.inner then
            host.inner:Hide()
            host.inner:SetParent(nil)
        end
        local inner = CreateFrame("Frame", nil, host)
        inner:SetAllPoints(host)
        host.inner = inner

        local scroller = C:CreateTabScroller(inner)
        builder(scroller)
        scroller:Commit()
    end

    local tabs = {
        {
            key = "Dungeon",
            title = "Dungeon",
            onSelect = function(tabContent)
                BuildTab(tabContent, "Dungeon", BuildDungeonTab)
            end,
        },
        {
            key = "Raid",
            title = "Raid",
            onSelect = function(tabContent)
                BuildTab(tabContent, "Raid", BuildRaidTab)
            end,
        },
    }

    local _, _, controller = C.CreateVerticalTabs(content, tabs)
    controller.Select(savedInstanceType)
end

---Toggles the custom instances UI open/closed
function addon:toggleCustomInstanceUI()
    if addon.frame and addon.frameType == "Custom" then
        addon.frame:Hide()
    else
        addon:openCustomInstances()
    end
end
