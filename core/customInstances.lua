local addonName, addon = ...

---@type AbstractFramework
local AF = _G.AbstractFramework

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

---Creates the add instance button in the Encounter Journal
---@return table addButton The created button frame
function addon:CreateAddInstanceButton()
    local addButton = AF.CreateButton(EncounterJournal, "", addonName, 200, 40)
    AF.SetPoint(addButton, "TOPRIGHT", EncounterJournal, "BOTTOMRIGHT", 0, 0)

    addButton:SetOnClick(function(self, button, down)
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
        if addon.frame and addon.frameType == "Custom" then
            addon:openCustomInstances()
        end
        if addon.frame and addon.frameType == "Config" then
            addon:openConfig()
        end
    end)
    return addButton
end

---Creates the remove instance button in the Encounter Journal
---@param addButton table The add button frame to position relative to
---@return table removebutton The created button frame
function addon:CreateRemoveInstanceButton(addButton)
    local removeButton = AF.CreateButton(EncounterJournal, "", addonName, 200, 40)
    AF.SetPoint(removeButton, "TOPRIGHT", addButton, "BOTTOMRIGHT", 0, 0)

    removeButton:SetOnClick(function(self, button, down)
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
        if addon.frame and addon.frameType == "Custom" then
            addon:openCustomInstances()
        end
        if addon.frame and addon.frameType == "Config" then
            addon:openConfig()
        end
    end)
    return removeButton
end

---Creates both add and remove instance buttons in the Encounter Journal
function addon:CreateInstanceButtons()
    local addButton = self:CreateAddInstanceButton()
    local currentTierName = EJ_GetTierInfo(EJ_GetCurrentTier())
    local title = ""

    EventRegistry:RegisterCallback("EncounterJournal.TabSet", function(info, tbl, tab)
        if EJ_GetCurrentTier() ~= EJ_GetNumTiers() and (tab == 3 or tab == 4) then
            journalInstance = nil
            title = EncounterJournal.instanceSelect.Title:GetText()
            addButton:SetText("Instance Loadouts Add:\n" .. currentTierName .. " " .. title)
            local width = addButton.text:GetStringWidth() + 25
            print(addButton.text:GetStringWidth())
            addButton:SetWidth(width)
            addButton:Show()
        else
            addButton:Hide()
        end
    end)

    self:RegisterEvent("CVAR_UPDATE", function(event, cvar)
        if cvar == "EJSelectedTier" then
            if EJ_GetCurrentTier() ~= EJ_GetNumTiers() then
                currentTierName = EJ_GetTierInfo(EJ_GetCurrentTier())
                addButton:SetText("Instance Loadouts Add:\n" .. currentTierName .. " " .. title)
                local width = addButton:GetTextWidth() + 25
                addButton:SetWidth(width)
                addButton:Show()
            else
                addButton:Hide()
            end
        end
    end)
    
    self:SecureHook("EncounterJournal_DisplayInstance", function(journalInstanceID)
        journalInstance = journalInstanceID
        title = EncounterJournal.encounter.instance.title:GetText()
        addButton:SetText("Instance Loadouts Add:\n" .. title)
        local width = addButton:GetTextWidth() + 25
        addButton:SetWidth(width)
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

---Creates encounter config options for custom groups within an instance frame
---@param instanceFrame table The instance frame to add encounter configs to
---@param instanceTypeValue string The type of instance
---@param journalInstanceID number The journal instance ID
---@param startYOffset number? Optional starting Y offset for positioning
---@return number totalHeight The total height needed for all encounter elements
function addon:createCustomGroupsEncounterConfig(instanceFrame, instanceTypeValue, journalInstanceID, startYOffset)
    local journalEncounterIDs = self.db.global.journalIDs[instanceTypeValue][journalInstanceID]
    local yOffset = startYOffset or -30
    local totalHeight = 0
    
    for journalEncounterID, _ in pairs(journalEncounterIDs) do
        if not self.defaultJournalIDs[instanceTypeValue][journalEncounterID] then
            yOffset = yOffset - 25
            
            local _, _, _, _, _, _, _, _, _, instanceID = EJ_GetInstanceInfo(journalInstanceID)
            local encounterName, _, _, _, _, _, encounterID = EJ_GetEncounterInfo(journalEncounterID)
            
            local label = AF.CreateFontString(instanceFrame, encounterName, "white", "AF_FONT_NORMAL", "ARTWORK")
            AF.SetPoint(label, "TOPLEFT", instanceFrame, "TOPLEFT", 0, yOffset)

            local xOffset = 200
            local button = AF.CreateButton(instanceFrame, "Remove", "red", instanceFrame:GetWidth() - xOffset, 20)
            AF.SetPoint(button, "TOPLEFT", instanceFrame, "TOPLEFT", xOffset, yOffset + 2)
            button:SetOnClick(function()
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
            button:Show()
            
            totalHeight = totalHeight + 25
        end
    end
    
    return totalHeight
end

---Creates instance config options for custom groups within a tier frame
---@param tierFrame table The tier frame to add instance configs to
---@param instanceTypeValue string The type of instance
---@param journalInstanceIDs table The journal instance IDs to create configs for
---@param tierID number|nil The optional tier ID for dungeons
---@return number totalHeight The total height needed for all instance elements
function addon:createCustomGroupsInstanceConfig(tierFrame, instanceTypeValue, journalInstanceIDs, tierID)
    local yOffset = -30
    local totalHeight = 0
    
    for journalInstanceID, journalInstanceInfo in pairs(journalInstanceIDs) do
        if not self.defaultJournalIDs[instanceTypeValue][journalInstanceID] then
            yOffset = yOffset - 25
            
            local instanceName, _, _, _, _, _, _, _, _, instanceID = EJ_GetInstanceInfo(journalInstanceID)
            
            local label = AF.CreateFontString(tierFrame, instanceName, "white", "AF_FONT_NORMAL", "ARTWORK")
            AF.SetPoint(label, "TOPLEFT", tierFrame, "TOPLEFT", 0, yOffset)
            
            local button = AF.CreateButton(tierFrame, "Remove", "red", tierFrame:GetWidth() - 200, 20)
            AF.SetPoint(button, "TOPLEFT", tierFrame, "TOPLEFT", 200, yOffset + 2)
            button:SetOnClick(function()
                journalInstanceIDs[journalInstanceID] = nil
                local customJournalInstances = addon.instanceGroups[instanceTypeValue]
                for instanceIdx, instanceInfo in ipairs(customJournalInstances) do
                    if tierID and instanceInfo.tierID == tierID then
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
            button:Show()
            
            if type(journalInstanceInfo) == "table" then
                local encounterHeight = self:createCustomGroupsEncounterConfig(tierFrame, instanceTypeValue, journalInstanceID, yOffset - 5)
                yOffset = yOffset - encounterHeight
                totalHeight = totalHeight + 25 + encounterHeight
            else
                totalHeight = totalHeight + 25
            end
        end
    end
    
    return totalHeight
end

---Creates tier config options for custom groups
---@param scroll table The AbstractFramework scroll content to add elements to
---@param instanceTypeValue string The type of instance
function addon:createCustomGroupsTierConfig(scroll, instanceTypeValue)
    local tierIDs = self.db.global.journalIDs[instanceTypeValue]
    local previousTierFrame = nil
    local totalHeight = 0
    
    for tierID, tierInfo in pairs(tierIDs) do
        if not self.defaultJournalIDs[instanceTypeValue][tierID] then
            local tierName = EJ_GetTierInfo(tierID)
            
            local tierFrame = AF.CreateTitledPane(scroll, tierName, scroll:GetWidth() - 15, 100)
            
            if previousTierFrame then
                AF.SetPoint(tierFrame, "TOPLEFT", previousTierFrame, "BOTTOMLEFT", 0, -5)
            else
                AF.SetPoint(tierFrame, "TOPLEFT", scroll, "TOPLEFT", 5, -5)
            end
            
            local button = AF.CreateButton(tierFrame, "Remove " .. tierName, "red", scroll:GetWidth() - 15, 20)
            AF.SetPoint(button, "TOPLEFT", tierFrame, "TOPLEFT", 0, -25)
            button:SetOnClick(function()
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
            end)
            button:Show()
            
            if type(tierInfo) == "table" then
                local instanceHeight = self:createCustomGroupsInstanceConfig(tierFrame, instanceTypeValue, tierIDs[tierID], tierID)
                tierFrame:SetHeight(50 + instanceHeight)
                totalHeight = totalHeight + 50 + instanceHeight + 5
            else
                tierFrame:SetHeight(50)
                totalHeight = totalHeight + 50 + 5
            end
            
            previousTierFrame = tierFrame
        end
    end
    
    scroll:SetHeight(totalHeight + 5)
end

local instanceTypeButtons = {}
local lastShownInstanceType = nil

local instanceTypeOrder = {
    "Dungeon",
    "Raid",
}

---Creates instance type button group for custom instances
---@param frame table The AbstractFramework frame to add elements to
local function CreateCustomInstanceTypeButtons(frame)
    if #instanceTypeButtons > 0 then
        for _, button in pairs(instanceTypeButtons) do
            button:Hide()
        end
        instanceTypeButtons = {}
    end

    local totalWidth = frame:GetWidth()
    local totalButtons = #instanceTypeOrder
    local overlapWidth = (totalButtons - 1) * 1
    local availableWidth = totalWidth
    local buttonWidth = math.floor((availableWidth + overlapWidth) / totalButtons)

    for i, instanceType in ipairs(instanceTypeOrder) do
        local currentButtonWidth = buttonWidth
        if i == totalButtons then
            local usedWidth = (buttonWidth * (totalButtons - 1)) - (overlapWidth)
            currentButtonWidth = totalWidth - usedWidth
        end
        
        local button = AF.CreateButton(frame, instanceType, addonName, currentButtonWidth, 21)
        button:SetFrameLevel(frame:GetFrameLevel() + 2)
        if i == 1 then
            AF.SetPoint(button, "TOPLEFT", frame, "TOPLEFT", 0, 0)
        else
            AF.SetPoint(button, "LEFT", instanceTypeButtons[i-1], "RIGHT", -1, 0)
        end
        button.id = instanceType
        table.insert(instanceTypeButtons, button)
    end

    local function ShowCustomInstanceType(tab)
        if lastShownInstanceType ~= tab then
            customGroupsConfigView.instanceType = tab.id
            addon:showCustomInstanceType(frame, tab.id)
            lastShownInstanceType = tab
        end
    end

    if #instanceTypeButtons > 0 then
        AF.CreateButtonGroup(instanceTypeButtons, ShowCustomInstanceType, function() end, function() end, function() end, function() end)
    end

    if not customGroupsConfigView.instanceType then
        customGroupsConfigView.instanceType = instanceTypeOrder[1]
    end

    for _, button in pairs(instanceTypeButtons) do
        if button.id == customGroupsConfigView.instanceType then
            button:Click()
            break
        end
    end
end

---Shows the content area for a specific instance type
---@param frame table The main frame
---@param instanceTypeValue string The instance type to show
function addon:showCustomInstanceType(frame, instanceTypeValue)
    local children = {frame:GetChildren()}
    for _, child in ipairs(children) do
        if child ~= frame.header and not child.id then
            child:Hide()
        end
    end
    local buttonHeight = 21
    local spacing = 5
    local fromTop = -(buttonHeight + spacing)
    local panelHeight = frame:GetHeight() - buttonHeight - (spacing * 2)
    local scrollFrame = AF.CreateScrollFrame(frame, nil, frame:GetWidth() - 10, panelHeight, "background2")
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 5, fromTop)
    
    local scrollContent = scrollFrame.scrollContent or scrollFrame
    
    if instanceTypeValue == "Dungeon" then
        self:createCustomGroupsTierConfig(scrollContent, instanceTypeValue)
    else
        local previousInstanceFrame = nil
        local totalHeight = 0
        
        for journalInstanceID, journalInstanceInfo in pairs(self.db.global.journalIDs[instanceTypeValue]) do
            if not self.defaultJournalIDs[instanceTypeValue][journalInstanceID] then
                local instanceName = EJ_GetInstanceInfo(journalInstanceID)
                
                local instanceFrame = AF.CreateTitledPane(scrollContent, instanceName, scrollContent:GetWidth() - 15, 60)
                
                if previousInstanceFrame then
                    AF.SetPoint(instanceFrame, "TOPLEFT", previousInstanceFrame, "BOTTOMLEFT", 0, -5)
                else
                    AF.SetPoint(instanceFrame, "TOPLEFT", scrollContent, "TOPLEFT", 5, -5)
                end
                
                local button = AF.CreateButton(instanceFrame, "Remove " .. instanceName, "red", scrollContent:GetWidth() - 15, 20)
                AF.SetPoint(button, "TOPLEFT", instanceFrame, "TOPLEFT", 0, -25)
                button:SetOnClick(function()
                    self.db.global.journalIDs[instanceTypeValue][journalInstanceID] = nil
                    local default = self:generateDefaults()
                    self.db:RegisterDefaults(default)
                    self:openCustomInstances()
                end)
                button:Show()
                
                if type(journalInstanceInfo) == "table" then
                    local encounterHeight = self:createCustomGroupsEncounterConfig(instanceFrame, instanceTypeValue, journalInstanceID, nil)
                    instanceFrame:SetHeight(50 + encounterHeight)
                    totalHeight = totalHeight + 50 + encounterHeight + 5
                else
                    instanceFrame:SetHeight(50)
                    totalHeight = totalHeight + 50 + 5
                end
                
                previousInstanceFrame = instanceFrame
            end
        end
        
        scrollContent:SetHeight(totalHeight + 5)
    end
end

---Creates configuration for custom instance types
---@param frame table The AbstractFramework frame to add elements to
function addon:createCustomInstanceTypeConfig(frame)
    CreateCustomInstanceTypeButtons(frame)
end

---Opens the custom instances configuration window
function addon:openCustomInstances()
    local frame = self.frame
    if self.frame and self.frameType == "Custom" then
        for _, child in ipairs({self.frame:GetChildren()}) do
            child:Hide()
        end
    else
        if self.frame then
            self.frame:Hide()
            self.frame = nil
        end
        self.frameType = "Custom"
        frame = AF.CreateHeaderedFrame(AF.UIParent, "InstanceLoadouts_CustomInstances",
            AF.GetIconString("IL", 14, 14, "InstanceLoadouts") .. " " .. addonName, 400, 400)
        AF.SetPoint(frame, "CENTER", UIParent, "CENTER", 0, 0)
        frame:SetTitleColor("white")
        frame:SetFrameLevel(100)
        frame:SetTitleJustify("LEFT")

        local pageName = AF.CreateFontString(frame.header, nil, "white", "AF_FONT_TITLE")
        AF.SetPoint(pageName, "CENTER", frame.header, "CENTER", 0, 0)
        pageName:SetJustifyH("CENTER")
        pageName:SetText(self.frameType .. " Instances")

        local optionsButton = AF.CreateButton(frame.header, "", addonName, 20, 20)
        AF.ApplyDefaultBackdropWithColors(optionsButton, "header")
        AF.SetPoint(optionsButton, "TOPRIGHT", -19, 0)

        optionsButton:SetTexture("OptionsIcon-Brown", {12, 12}, {"CENTER", 0, 0}, true)
        optionsButton:SetFrameLevel(frame:GetFrameLevel() + 10)
        optionsButton:SetOnClick(function()
            addon:openConfig()
        end)

        frame:SetScript("OnHide", function()
            self.frame = nil
        end)

        _G["InstanceLoadouts_CustomInstances"] = frame
        table.insert(UISpecialFrames, "InstanceLoadouts_CustomInstances")
        frame:Show()
    end

    self:createCustomInstanceTypeConfig(frame)

    self.frame = frame
end

---Toggles the custom instances UI open/closed
function addon:toggleCustomInstanceUI()
    if addon.frame and addon.frameType == "Custom" then
        addon.frame:Hide()
        addon.frame = nil
    else
        addon:openCustomInstances()
    end
end