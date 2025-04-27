local addonName, addon = ...

local AceGUI = LibStub("AceGUI-3.0")

local customGroupsConfigView = {
    ["instanceType"] = nil,
}

local journalInstance

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

function addon:removeDungeonInstance(journalInstanceID)
    local dungeonJournalIDs = self.db.global.journalIDs.Dungeon
    local currentTier = EJ_GetCurrentTier()
    if dungeonJournalIDs[currentTier] then
        dungeonJournalIDs[currentTier][journalInstanceID] = nil
        self:getCustomEncounterJournalDungeons()
    end
end

function addon:CreateAddInstanceButton()
    local addButton = CreateFrame("Button", nil, EncounterJournal, "UIPanelButtonTemplate")
    addButton:SetHeight(40)
    addButton:SetPoint("TOPRIGHT", EncounterJournal, "BOTTOMRIGHT", 0, 0)

    addButton:SetScript("OnClick", function(self, button, down)
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
        local default = addon:generateDefaults()
        addon.db:RegisterDefaults(default)
        if addon.customGroupFrame and addon.customGroupFrame:IsShown() then
            addon:openCustomGroups()
        end
        if addon.frame and addon.frame:IsShown() then
            addon:openConfig()
        end
    end)
    return addButton
end


function addon:CreateRemoveInstanceButton(addButton)
    local removeButton = CreateFrame("Button", nil, EncounterJournal, "UIPanelButtonTemplate")
    removeButton:SetHeight(40)
    removeButton:SetPoint("TOPRIGHT", addButton, "BOTTOMRIGHT", 0, 0)

    removeButton:SetScript("OnClick", function(self, button, down)
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
        local default = addon:generateDefaults()
        addon.db:RegisterDefaults(default)
        if addon.customGroupFrame and addon.customGroupFrame:IsShown() then
            addon:openCustomGroups()
        end
        if addon.frame and addon.frame:IsShown() then
            addon:openConfig()
        end
    end)
    return removeButton
end

function addon:CreateInstanceButtons()
    local addButton = self:CreateAddInstanceButton()
    -- local removeButton = self:CreateRemoveInstanceButton(addButton)
    local currentTierName = EJ_GetTierInfo(EJ_GetCurrentTier())
    local title = ""

    EventRegistry:RegisterCallback("EncounterJournal.TabSet", function(info, tbl, tab)
        if EJ_GetCurrentTier() ~= EJ_GetNumTiers() and (tab == 3 or tab == 4) then
            journalInstance = nil
            title = EncounterJournal.instanceSelect.Title:GetText()
            addButton:SetText("Instance Loadouts Add:\n" .. currentTierName .. " " .. title)
            -- removeButton:SetText("Instance Loadouts Remove:\n" .. currentTierName .. " " .. title)
            local width = addButton:GetTextWidth() + 25
            -- if removeButton:GetTextWidth() + 25 > width then
            --     width = removeButton:GetTextWidth() + 25
            -- end
            addButton:SetWidth(width)
            -- removeButton:SetWidth(width)
            addButton:Show()
            -- removeButton:Show()
        else
            addButton:Hide()
            -- removeButton:Hide()
        end
    end)

    self:RegisterEvent("CVAR_UPDATE", function(event, cvar)
        if cvar == "EJSelectedTier" then
            if EJ_GetCurrentTier() ~= EJ_GetNumTiers() then
                currentTierName = EJ_GetTierInfo(EJ_GetCurrentTier())
                addButton:SetText("Instance Loadouts Add:\n" .. currentTierName .. " " .. title)
                -- removeButton:SetText("Instance Loadouts Remove:\n" .. currentTierName .. " " .. title)
                local width = addButton:GetTextWidth() + 25
                -- if removeButton:GetTextWidth() + 25 > width then
                --     width = removeButton:GetTextWidth() + 25
                -- end
                addButton:SetWidth(width)
                -- removeButton:SetWidth(width)
                addButton:Show()
                -- removeButton:Show()
            else
                addButton:Hide()
                -- removeButton:Hide()
            end
        end
    end)
    
    self:SecureHook("EncounterJournal_DisplayInstance", function(journalInstanceID)
        journalInstance = journalInstanceID
        title = EncounterJournal.encounter.instance.title:GetText()
        addButton:SetText("Instance Loadouts Add:\n" .. title)
        -- removeButton:SetText("Instance Loadouts Remove:\n" .. title)
        local width = addButton:GetTextWidth() + 25
        -- if removeButton:GetTextWidth() + 25 > width then
        --     width = removeButton:GetTextWidth() + 25
        -- end
        addButton:SetWidth(width)
        -- removeButton:SetWidth(width)
    end)
end

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

function addon:getCustomEncounterJournals()
    self:getCustomEncounterJournalDungeons()
    self:getCustomEncounterJournalRaids()
end

function addon:createCustomGroupsEncounterConfig(widget, instanceTypeValue, journalInstanceID)
    local journalEncounterIDs = self.db.global.journalIDs[instanceTypeValue][journalInstanceID]
    local container = AceGUI:Create("InlineGroup")
    container:SetLayout("Flow")
    container:SetFullWidth(true)
    for journalEncounterID, _ in pairs(journalEncounterIDs) do
        local _, _, _, _, _, _, _, _, _, instanceID = EJ_GetInstanceInfo(journalInstanceID)
        local encounterName, _, _, _, _, _, encounterID = EJ_GetEncounterInfo(journalEncounterID)
        local label = AceGUI:Create("Label")
        label:SetText(encounterName)
        label:SetRelativeWidth(0.5)
        label:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
        container:AddChild(label)
        local button = AceGUI:Create("Button")
        button:SetText("Remove " .. encounterName .. " from custom groups")
        button:SetRelativeWidth(0.5)
        button:SetCallback("OnClick", function(widget, callback)
            journalEncounterIDs[journalEncounterID] = nil
            local customJournalInstances = addon.instanceGroups[instanceTypeValue]
            for _, instanceInfo in ipairs(customJournalInstances) do
                if instanceInfo.instanceID == instanceID then
                    for encounterIdx, encounterInfo in ipairs(instanceInfo.encounterIDs) do
                        if encounterInfo.encounterID == encounterID then
                            tremove(instanceInfo.encounterIDs, encounterIdx)
                            break
                        end
                    end
                    break
                end
            end
            local default = addon:generateDefaults()
            addon.db:RegisterDefaults(default)
            addon:openCustomGroups()
        end)
        container:AddChild(button)
    end
    widget:AddChild(container)
end

function addon:createCustomGroupsInstanceConfig(scroll, instanceTypeValue, journalInstanceIDs, tierID)
    local container
    if instanceTypeValue == "Dungeon" then
        container = AceGUI:Create("InlineGroup")
        container:SetLayout("Flow")
        container:SetFullWidth(true)
    end
    for journalInstanceID, journalInstanceInfo in pairs(journalInstanceIDs) do
        if not self.defaultJournalIDs[instanceTypeValue][journalInstanceID] then
            if instanceTypeValue == "Raid" then
                container = AceGUI:Create("InlineGroup")
                container:SetLayout("Flow")
                container:SetFullWidth(true)
            end
            local instanceName, _, _, _, _, _, _, _, _, instanceID = EJ_GetInstanceInfo(journalInstanceID)
            local label = AceGUI:Create("Label")
            label:SetText(instanceName)
            label:SetRelativeWidth(0.5)
            label:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
            container:AddChild(label)
            local button = AceGUI:Create("Button")
            button:SetText("Remove " .. instanceName .. " from custom groups")
            button:SetRelativeWidth(0.5)
            button:SetCallback("OnClick", function(widget, callback)
                journalInstanceIDs[journalInstanceID] = nil
                local customJournalInstances = addon.instanceGroups[instanceTypeValue]
                for instanceIdx, instanceInfo in ipairs(customJournalInstances) do
                    if tierID and instanceInfo.tierID == tierID then
                        for idx, instInfo in ipairs(instanceInfo.instanceIDs) do
                            if instInfo.instanceID == instanceID then
                                tremove(instanceInfo.instanceIDs, idx)
                                break
                            end
                        end
                    elseif instanceInfo.instanceID == instanceID then
                        tremove(customJournalInstances, instanceIdx)
                        break
                    end
                end
                local default = addon:generateDefaults()
                addon.db:RegisterDefaults(default)
                addon:openCustomGroups()
            end)
            container:AddChild(button)
            if type(journalInstanceInfo) == "table" then
                self:createCustomGroupsEncounterConfig(container, instanceTypeValue, journalInstanceID)
            end
            if instanceTypeValue == "Raid" then
                scroll:AddChild(container)
            end
        end
    end
    if instanceTypeValue == "Dungeon" then
        scroll:AddChild(container)
    end
end

function addon:createCustomGroupsTierConfig(scroll, instanceTypeValue)
    local tierIDs = self.db.global.journalIDs[instanceTypeValue]
    for tierID, tierInfo in pairs(tierIDs) do
        if not self.defaultJournalIDs[instanceTypeValue][tierID] then
            local container = AceGUI:Create("InlineGroup")
            container:SetLayout("Flow")
            container:SetFullWidth(true)
            local tierName = EJ_GetTierInfo(tierID)
            local label = AceGUI:Create("Label")
            label:SetText(tierName)
            label:SetRelativeWidth(0.5)
            label:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
            container:AddChild(label)
            local button = AceGUI:Create("Button")
            button:SetText("Remove " .. tierName .. " from custom groups")
            button:SetRelativeWidth(0.5)
            button:SetCallback("OnClick", function(widget, callback)
                tierIDs[tierID] = nil
                local customJournalTiers = addon.instanceGroups[instanceTypeValue]
                for tierIdx, customJournalInstances in ipairs(customJournalTiers) do
                    if customJournalInstances.tierID == tierID then
                        tremove(customJournalTiers, tierIdx)
                        break
                    end
                end
                local default = addon:generateDefaults()
                addon.db:RegisterDefaults(default)
                addon:openCustomGroups()
            end)
            container:AddChild(button)
            if type(tierInfo) == "table" then
                self:createCustomGroupsInstanceConfig(container, instanceTypeValue, tierIDs[tierID], tierID)
            end
            scroll:AddChild(container)
        end
    end
end

function addon:createCustomGroupsTabGroup(frame)
    local customGroupsTabs = AceGUI:Create("TabGroup")
    customGroupsTabs:SetFullHeight(true)
    customGroupsTabs:SetFullWidth(true)
    local tabs = {}
    for instanceType, _ in pairs(self.defaultJournalIDs) do
        tinsert(tabs, {value = instanceType, text = instanceType})
    end
    if not customGroupsConfigView.instanceType then
        customGroupsConfigView.instanceType = tabs[1].value
    end
    customGroupsTabs:SetTabs(tabs)
    customGroupsTabs:SetLayout("Flow")
    customGroupsTabs:SetCallback("OnGroupSelected", (function(widget, callback, instanceTypeValue)
        widget:ReleaseChildren()
        customGroupsConfigView.instanceType = instanceTypeValue
        local scrollContainer = AceGUI:Create("SimpleGroup")
        scrollContainer:SetFullWidth(true)
        scrollContainer:SetFullHeight(true)
        scrollContainer:SetLayout("Fill")
        widget:AddChild(scrollContainer)
        local scroll = AceGUI:Create("ScrollFrame")
        scroll:SetLayout("Flow")
        scrollContainer:AddChild(scroll)
        if instanceTypeValue == "Dungeon" then
            addon:createCustomGroupsTierConfig(scroll, instanceTypeValue)
        else
            addon:createCustomGroupsInstanceConfig(scroll, instanceTypeValue, self.db.global.journalIDs[instanceTypeValue])
        end
    end))
    customGroupsTabs:SelectTab(customGroupsConfigView.instanceType)
    frame:AddChild(customGroupsTabs)
end

function addon:openCustomGroups()
    if self.frame and self.frame:IsShown() then
        AceGUI:Release(self.frame)
    end
    if self.loadoutFrame and self.loadoutFrame:IsShown() then
        AceGUI:Release(self.loadoutFrame)
    end
    if self.changelogFrame and self.changelogFrame:IsShown() then
        AceGUI:Release(self.changelogFrame)
    end
    
    local frame = self.customGroupFrame
    if self.customGroupFrame and self.customGroupFrame:IsShown() then
        self.customGroupFrame:ReleaseChildren()
    else
        frame = AceGUI:Create("Frame")
        frame:SetCallback("OnClose", function(widget)
            AceGUI:Release(widget)
            self.customGroupFrame = nil
        end)
        frame:SetTitle(addonName)
        frame:SetLayout("Flow")
    end
    
    local container = AceGUI:Create("SimpleGroup")
    container:SetLayout("Flow")
    container:SetRelativeWidth(0.25)
    frame:AddChild(container)
    local button = AceGUI:Create("Button")
    button:SetText("Loadouts Config")
    button:SetRelativeWidth(0.5)
    button:SetCallback("OnClick", function(widget, callback)
        AceGUI:Release(frame)
        addon:openConfig()
    end)
    frame:AddChild(button)

    self:createCustomGroupsTabGroup(frame)

    self.customGroupFrame = frame
end

function addon:toggleCustomGroups()
    if self.customGroupFrame and self.customGroupFrame:IsShown() then
        AceGUI:Release(self.customGroupFrame)
    else
        self:openCustomGroups()
    end
end