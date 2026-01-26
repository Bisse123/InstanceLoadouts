local addonName, addon = ...

---@type AbstractFramework
local AF = _G.AbstractFramework

local instanceTypeButtons = {}
local instanceButtons = {}
local encounterButtons = {}
local lastShownInstanceType = nil
local lastShownInstance = nil
local lastShownEncounter = nil

local externalOrder = {
    "Gearset",
    "Specialization",
    "Talents",
    "Addons",
}

local instanceTypeOrder = {
    "Dungeon",
    "Raid",
    "Delve",
    "Arena",
    "Battleground",
    "Open World",
}

addon.ConfigView = {
    ["instanceType"] = instanceTypeOrder[1],
    ["instance"] = -1,
    ["encounter"] = -1,
}

local instanceSelectionArea = nil
local encounterSelectionArea = nil
local optionsArea = nil

local function CreateLayoutAreas(frame, showMiddlePanel)
    if not frame then
        print("Error: CreateLayoutAreas called with nil frame")
        return nil, nil, nil
    end
    
    local buttonHeight = 21
    local spacing = 5
    local panelTop = -(buttonHeight + spacing)
    local panelHeight = frame:GetHeight() - buttonHeight - (spacing * 2)
    local totalWidth = frame:GetWidth() - (spacing * 2)
    local leftPanelWidth = 200
    local middlePanelWidth = showMiddlePanel and 200 or 0
    local rightPanelWidth = totalWidth - leftPanelWidth - middlePanelWidth - (showMiddlePanel and spacing or 0)

    if not instanceSelectionArea or instanceSelectionArea:GetParent() ~= frame then
        if instanceSelectionArea then instanceSelectionArea:Hide() end
        instanceSelectionArea = AF.CreateFrame(frame, nil, leftPanelWidth, panelHeight)
        instanceSelectionArea:SetPoint("TOPLEFT", frame, "TOPLEFT", spacing, panelTop)
        instanceSelectionArea:Show()
    end

    if showMiddlePanel then
        if not encounterSelectionArea or encounterSelectionArea:GetParent() ~= frame then
            if encounterSelectionArea then encounterSelectionArea:Hide() end
            encounterSelectionArea = AF.CreateFrame(frame, nil, middlePanelWidth, panelHeight)
            encounterSelectionArea:SetPoint("TOPLEFT", instanceSelectionArea, "TOPRIGHT", spacing, 0)
            encounterSelectionArea:Show()
        else
            encounterSelectionArea:Show()
        end
    else
        if encounterSelectionArea then
            encounterSelectionArea:Hide()
        end
    end

    if not optionsArea or optionsArea:GetParent() ~= frame then
        if optionsArea then optionsArea:Hide() end
        optionsArea = AF.CreateFrame(frame, nil, rightPanelWidth, panelHeight)
        optionsArea:Show()
    else
        AF.SetWidth(optionsArea, rightPanelWidth)
    end

    optionsArea:ClearAllPoints()
    if showMiddlePanel and encounterSelectionArea then
        optionsArea:SetPoint("TOPLEFT", encounterSelectionArea, "TOPRIGHT", spacing, 0)
    else
        optionsArea:SetPoint("TOPLEFT", instanceSelectionArea, "TOPRIGHT", spacing, 0)
    end
    
    return instanceSelectionArea, encounterSelectionArea, optionsArea
end

local function CleanupLayoutAreas()
    if instanceSelectionArea then
        instanceSelectionArea:Hide()
        instanceSelectionArea = nil
    end
    if encounterSelectionArea then
        encounterSelectionArea:Hide()
        encounterSelectionArea = nil
    end
    if optionsArea then
        optionsArea:Hide()
        optionsArea = nil
    end
end

local function ClearOptionsArea()
    if optionsArea then
        local children = {optionsArea:GetChildren()}
        for _, child in ipairs(children) do
            child:Hide()
        end
    end
end

local function ClearInstanceButtons()
    for _, button in pairs(instanceButtons) do
        button:Hide()
    end
    instanceButtons = {}

    if instanceSelectionArea then
        local children = {instanceSelectionArea:GetChildren()}
        for _, child in ipairs(children) do
            child:Hide()
        end
    end
end

local function ClearEncounterButtons()
    for _, button in pairs(encounterButtons) do
        button:Hide()
    end
    encounterButtons = {}

    if encounterSelectionArea then
        local children = {encounterSelectionArea:GetChildren()}
        for _, child in ipairs(children) do
            child:Hide()
        end
    end
end

---Populates the options area with configuration options (without managing layout)
---@param targetWidget table The target widget to populate
---@param instanceTypeValue string The type of instance (e.g. "Dungeon", "Raid")
---@param instanceValue number The instance ID
function addon:populateOptionsArea(targetWidget, instanceTypeValue, instanceValue)
    if not targetWidget then return end

    local actualInstanceValue = instanceValue
    if type(instanceValue) == "table" and instanceValue.instanceID then
        actualInstanceValue = instanceValue.instanceID
    elseif type(instanceValue) == "table" and instanceValue.id then
        actualInstanceValue = instanceValue.id
    end

    local dbLoadouts = self.db.char.loadouts
    local dbLoadout = dbLoadouts[instanceTypeValue][actualInstanceValue]

    local scrollFrame = AF.CreateScrollFrame(targetWidget, nil, nil, nil, "background2")
    AF.SetPoint(scrollFrame, "TOPLEFT", targetWidget, "TOPLEFT", 0, 0)
    AF.SetPoint(scrollFrame, "BOTTOMRIGHT", targetWidget, "BOTTOMRIGHT", -5, 0)

    local scrollContent = scrollFrame.scrollContent or scrollFrame

    local yOffset = -5

    for _, type in pairs(externalOrder) do
        local info = self.externalInfo[type]

        if instanceValue == -1 and next(info) then
            local container = AF.CreateTitledPane(scrollContent, type, scrollContent:GetWidth() - 10, 20)
            AF.SetPoint(container, "TOPLEFT", 5, yOffset)

            local dropdown = AF.CreateDropdown(container, 150)
            AF.SetPoint(dropdown, "TOPLEFT", container, "BOTTOMLEFT", 0, -5)

            local items = {}
            for key, value in pairs(info) do
                table.insert(items, {text = value, value = key})
            end
            dropdown:SetItems(items)
            dropdown:SetSelectedValue(dbLoadout[type])

            if type == "Specialization" then
                dropdown:SetOnSelect(function(value)
                    dbLoadout[type] = value
                    dbLoadout["Talents"] = -1
                    addon:openConfig()
                end)
            elseif type == "Talents" then
                dropdown:SetEnabled(dbLoadout.Specialization ~= -1)
                dropdown:SetOnSelect(function(value)
                    dbLoadout[type] = value
                end)
            else
                dropdown:SetOnSelect(function(value)
                    dbLoadout[type] = value
                end)
            end

            dropdown:Show()
            yOffset = yOffset - 50

        elseif next(info) then
            local container = AF.CreateTitledPane(scrollContent, type, scrollContent:GetWidth() - 10, 20)
            AF.SetPoint(container, "TOPLEFT", 5, yOffset)

            local checkbox = AF.CreateCheckButton(container, "Override Default " .. type, function(checked)
                dbLoadout["Override Default " .. type] = checked
                addon:openConfig()
            end)
            AF.SetPoint(checkbox, "TOPLEFT", container, "BOTTOMLEFT", 0, -5)

            local dropdown = AF.CreateDropdown(container, 150)
            AF.SetPoint(dropdown, "TOPLEFT", checkbox, "BOTTOMLEFT", 0, -5)

            if type == "Specialization" then
                local items = {}
                for key, value in pairs(info) do
                    table.insert(items, {text = value, value = key})
                end
                dropdown:SetItems(items)
                dropdown:SetSelectedValue(dbLoadout["Override Default " .. type] and dbLoadout[type] or self.db.char.loadouts[instanceTypeValue][-1][type])
                dropdown:SetEnabled(dbLoadout["Override Default " .. type])
                dropdown:SetOnSelect(function(value)
                    dbLoadout[type] = value
                    dbLoadout["Talents"] = -1
                    addon:openConfig()
                end)
                checkbox:SetChecked(dbLoadout["Override Default " .. type])
            elseif type == "Talents" then
                local items = {}
                for key, value in pairs(info) do
                    table.insert(items, {text = value, value = key})
                end
                dropdown:SetItems(items)
                dropdown:SetSelectedValue(dbLoadout["Override Default Specialization"] and dbLoadout["Override Default " .. type] and dbLoadout[type] or self.db.char.loadouts[instanceTypeValue][-1][type])
                dropdown:SetEnabled(dbLoadout["Override Default " .. type] and dbLoadout["Override Default Specialization"] and dbLoadout.Specialization ~= -1)
                dropdown:SetOnSelect(function(value)
                    dbLoadout[type] = value
                end)
                checkbox:SetChecked(dbLoadout["Override Default " .. type] and dbLoadout["Override Default Specialization"] and dbLoadout.Specialization ~= -1)
                checkbox:SetEnabled(dbLoadout["Override Default Specialization"] and dbLoadout.Specialization ~= -1)
            else
                local items = {}
                for key, value in pairs(info) do
                    table.insert(items, {text = value, value = key})
                end
                dropdown:SetItems(items)
                dropdown:SetSelectedValue(dbLoadout["Override Default " .. type] and dbLoadout[type] or self.db.char.loadouts[instanceTypeValue][-1][type])
                dropdown:SetEnabled(dbLoadout["Override Default " .. type])
                dropdown:SetOnSelect(function(value)
                    dbLoadout[type] = value
                end)
                checkbox:SetChecked(dbLoadout["Override Default " .. type])
            end

            dropdown:Show()
            checkbox:Show()
            yOffset = yOffset - 70
        end
    end

    if strfind(instanceTypeValue, "Encounter") then
        local raidInstanceIDStr = strsplit(" ", instanceTypeValue)
        local raidInstanceID = tonumber(raidInstanceIDStr)
        local npcIDs = ""
        local journalInstance
        local journalEncounter
        for journalInstanceID, journalEncounterIDs in pairs(self.db.global.journalIDs.Raid) do
            local _, _, _, _, _, _, _, _, _, instanceID = EJ_GetInstanceInfo(journalInstanceID)
            if instanceID == raidInstanceID then
                journalInstance = journalInstanceID
                for journalEncounterID, journalNpcIDs in pairs(journalEncounterIDs) do
                    local _, _, _, _, _, _, encounterID = EJ_GetEncounterInfo(journalEncounterID)
                    if encounterID == instanceValue then
                        journalEncounter = journalEncounterID
                        for idx, npcID in ipairs(journalNpcIDs) do
                            if idx == 1 then
                                npcIDs = npcID
                            else
                                npcIDs = npcIDs .. ", " .. npcID
                            end
                        end
                        break   
                    end
                end
                break
            end
        end
        if journalInstance and journalEncounter then
            local container = AF.CreateTitledPane(scrollContent, "NPC IDs", scrollContent:GetWidth() - 10, 20)
            AF.SetPoint(container, "TOPLEFT", 5, yOffset)

            local npcIDsEditBox = AF.CreateEditBox(container, "Comma separated NPC IDs", scrollContent:GetWidth() - 10, 20, "trim")
            AF.SetPoint(npcIDsEditBox, "TOPLEFT", container, "BOTTOMLEFT", 0, -5)
            npcIDsEditBox:SetText(npcIDs)
            npcIDsEditBox:SetConfirmButton(function(text)
                local rawNpcIDs = {strsplit(",", text)}
                local npcIDs = {}
                for i, npcID in ipairs(rawNpcIDs) do
                    local trimmedID = npcID:gsub("^%s*(.-)%s*$", "%1")
                    if trimmedID ~= "" then
                        table.insert(npcIDs, trimmedID)
                    end
                end
                self.db.global.journalIDs.Raid[journalInstance][journalEncounter] = npcIDs
                for _, instanceInfo in ipairs(self.instanceGroups.Raid) do
                    if instanceInfo.instanceID == raidInstanceID then
                        for _, encounterInfo in ipairs(instanceInfo.encounterIDs) do
                            if encounterInfo.encounterID == instanceValue then
                                encounterInfo.npcIDs = npcIDs
                                break
                            end
                        end
                        break
                    end
                end
            end)
        end
    end

    scrollContent:SetHeight(math.abs(yOffset))
end

---Creates configuration options for a specific instance or encounter
---@param widget table The AbstractFramework widget to add elements to
---@param instanceTypeValue string The type of instance (e.g. "Dungeon", "Raid")
---@param instanceValue number The instance ID
function addon:createOptionsConfig(widget, instanceTypeValue, instanceValue)
    if not widget then
        print("Error: createOptionsConfig called with nil widget")
        return
    end

    ClearOptionsArea()
    local _, _, targetWidget = CreateLayoutAreas(widget, false)

    if not targetWidget then return end

    self:populateOptionsArea(targetWidget, instanceTypeValue, instanceValue)
end

---Creates encounter button group for raids (vertical layout)
---@param frame table The AbstractFramework frame to add elements to  
---@param instanceTypeValue string The type of instance
---@param instanceValue number The raid instance ID
local function CreateRaidEncounterButtons(frame, instanceTypeValue, instanceValue)
    if not frame then
        print("Error: CreateRaidEncounterButtons called with nil frame")
        return
    end

    local _, encounterArea, _ = CreateLayoutAreas(frame, true)

    if not encounterArea then return end

    if #encounterButtons > 0 then
        ClearEncounterButtons()
    end

    local encounters = {}
    for _, instanceInfo in ipairs(addon.instanceGroups[instanceTypeValue]) do
        if instanceInfo.instanceID == instanceValue then
            for _, encounterInfo in ipairs(instanceInfo.encounterIDs) do
                table.insert(encounters, {id = encounterInfo.encounterID, text = encounterInfo.encounterName})
            end
            break
        end
    end

    if #encounters == 0 then return end

    local scrollList = AF.CreateScrollList(encounterArea, nil, 5, 5, 12, 25, 2, "background2")
    AF.SetWidth(scrollList, encounterArea:GetWidth())
    AF.SetHeight(scrollList, encounterArea:GetHeight())
    scrollList:SetPoint("TOPLEFT", encounterArea, "TOPLEFT", 0, 0)
    scrollList:Show()

    local widgets = {}
    for i, encounter in ipairs(encounters) do
        local button = AF.CreateButton(scrollList, encounter.text, addonName, 20, 25)
        button.id = encounter.id
        table.insert(encounterButtons, button)
        table.insert(widgets, button)
    end

    scrollList:SetWidgets(widgets)

    local function ShowEncounter(tab)
        if lastShownEncounter ~= tab then
            AF.Fire("ShowEncounter", tab.id, instanceTypeValue, instanceValue)
            lastShownEncounter = tab
        end
    end

    AF.CreateButtonGroup(encounterButtons, ShowEncounter, function() end, function() end, function() end, function() end)

    local foundButton = false
    for _, button in pairs(encounterButtons) do
        if button.id == addon.ConfigView.encounter then
            button:Click()
            foundButton = true
            break
        end
    end

    if not foundButton and #encounterButtons > 0 then
        encounterButtons[1]:Click()
    end
end

---Creates configuration tree group for raid encounters
---@param widget table The AbstractFramework widget to add elements to  
---@param instanceTypeValue string The type of instance
---@param instanceValue number The raid instance ID
function addon:createRaidEncounterConfig(widget, instanceTypeValue, instanceValue)
    CreateRaidEncounterButtons(widget, instanceTypeValue, instanceValue)
end

---Creates dungeon instance button group (vertical layout)
---@param frame table The AbstractFramework frame to add elements to
---@param instanceTypeValue string The type of instance
---@param tierValue number The tier ID
local function CreateDungeonInstanceButtons(frame, instanceTypeValue, tierValue)
    if not frame then
        print("Error: CreateDungeonInstanceButtons called with nil frame")
        return
    end

    local _, encounterArea, _ = CreateLayoutAreas(frame, true)

    if not encounterArea then return end

    ClearEncounterButtons()

    local dungeonInstances = {}
    for _, instanceInfo in pairs(addon.instanceGroups[instanceTypeValue]) do
        if instanceInfo.tierID == tierValue then
            for _, instanceData in pairs(instanceInfo.instanceIDs) do
                local instanceID = instanceData.instanceID or instanceData.id
                local instanceName = instanceData.instanceName or instanceData.text or instanceData.name

                if not instanceName and instanceID then
                    instanceName = addon.ConvertIDToName[instanceID]
                end

                if not instanceName then
                    instanceName = "Unknown Instance"
                end

                table.insert(dungeonInstances, {id = instanceID, text = instanceName})
            end
            break
        end
    end

    if #dungeonInstances == 0 then return end

    local scrollList = AF.CreateScrollList(encounterArea, nil, 5, 5, 12, 25, 2, "background2")
    AF.SetWidth(scrollList, encounterArea:GetWidth())
    AF.SetHeight(scrollList, encounterArea:GetHeight())
    scrollList:SetPoint("TOPLEFT", encounterArea, "TOPLEFT", 0, 0)
    scrollList:Show()

    local widgets = {}
    for i, instance in ipairs(dungeonInstances) do
        local button = AF.CreateButton(scrollList, instance.text, addonName, 20, 25)
        button.id = instance.id
        table.insert(encounterButtons, button)
        table.insert(widgets, button)
    end

    scrollList:SetWidgets(widgets)

    local function ShowDungeonInstance(tab)
        if lastShownEncounter ~= tab then
            AF.Fire("ShowDungeonInstance", tab.id, instanceTypeValue)
            lastShownEncounter = tab
        end
    end

    AF.CreateButtonGroup(encounterButtons, ShowDungeonInstance, function() end, function() end, function() end, function() end)

    local foundButton = false
    for _, button in pairs(encounterButtons) do
        if button.id == addon.ConfigView.encounter then
            button:Click()
            foundButton = true
            break
        end
    end

    if not foundButton and #encounterButtons > 0 then
        encounterButtons[1]:Click()
    end
end

---Creates configuration tree group for dungeon instances
---@param widget table The AbstractFramework widget to add elements to
---@param instanceTypeValue string The type of instance
---@param tierValue number The tier ID
function addon:createDungeonInstanceConfig(widget, instanceTypeValue, tierValue)
    CreateDungeonInstanceButtons(widget, instanceTypeValue, tierValue)
end

---Creates instance button group (vertical layout)
---@param frame table The AbstractFramework frame to add elements to
---@param instanceTypeValue string The type of instance
local function CreateInstanceButtons(frame, instanceTypeValue)
    if not frame then
        print("Error: CreateInstanceButtons called with nil frame")
        return
    end

    local showMiddlePanel = instanceTypeValue == "Raid" or instanceTypeValue == "Dungeon"
    local instanceArea, _, _ = CreateLayoutAreas(frame, showMiddlePanel)

    if not instanceArea then return end

    ClearInstanceButtons()
    ClearEncounterButtons()

    local instances = {}
    for _, instanceInfo in pairs(addon.instanceGroups[instanceTypeValue]) do
        if instanceInfo.instanceID then
            table.insert(instances, {id = instanceInfo.instanceID, text = instanceInfo.instanceName})
        else
            table.insert(instances, {id = instanceInfo.tierID, text = instanceInfo.tierName})
        end
    end

    if #instances == 0 then return end

    local scrollList = AF.CreateScrollList(instanceArea, nil, 5, 5, 12, 25, 2, "background2")
    AF.SetWidth(scrollList, instanceArea:GetWidth())
    AF.SetHeight(scrollList, instanceArea:GetHeight())
    scrollList:SetPoint("TOPLEFT", instanceArea, "TOPLEFT", 0, 0)
    scrollList:Show()

    local widgets = {}
    for i, instance in ipairs(instances) do
        local button = AF.CreateButton(scrollList, instance.text, addonName, 20, 25)
        button.id = instance.id
        table.insert(instanceButtons, button)
        table.insert(widgets, button)
    end

    scrollList:SetWidgets(widgets)

    local function ShowInstance(tab)
        if lastShownInstance ~= tab then
            lastShownInstance = tab
            addon.ConfigView.instance = tab.id

            if not addon.frame then
                print("Error: ShowInstance called but addon.frame is nil")
                return
            end

            if instanceTypeValue == "Raid" then
                CreateRaidEncounterButtons(addon.frame, instanceTypeValue, tab.id)
            elseif instanceTypeValue == "Dungeon" then
                CreateDungeonInstanceButtons(addon.frame, instanceTypeValue, tab.id)
            else
                addon:createOptionsConfig(addon.frame, instanceTypeValue, tab.id)
            end
        end
    end

    AF.CreateButtonGroup(instanceButtons, ShowInstance, function() end, function() end, function() end, function() end)

    local foundButton = false
    for _, button in pairs(instanceButtons) do
        if button.id == addon.ConfigView.instance then
            button:Click()
            foundButton = true
            break
        end
    end

    if not foundButton and #instanceButtons > 0 then
        instanceButtons[1]:Click()
    end
end

---Creates configuration tree group for instances
---@param frame table The AbstractFramework frame to add elements to
---@param instanceTypeValue string The type of instance
function addon:createInstanceConfig(frame, instanceTypeValue)
    CreateInstanceButtons(frame, instanceTypeValue)
end

local function ShowInstanceType(callback, instanceTypeValue)
    addon.ConfigView.instanceType = instanceTypeValue
    if addon.frame then
        ClearInstanceButtons()
        ClearEncounterButtons()
        ClearOptionsArea()
        addon:createInstanceConfig(addon.frame, instanceTypeValue)
    end
end

local function ShowInstance(callback, instanceValue, instanceTypeValue)
    addon.ConfigView.instance = instanceValue
    if not addon.frame then return end

    if instanceTypeValue == "Raid" then
        addon:createRaidEncounterConfig(addon.frame, instanceTypeValue, instanceValue)
    elseif instanceTypeValue == "Dungeon" then
        addon:createDungeonInstanceConfig(addon.frame, instanceTypeValue, instanceValue)
    else
        if not addon.db.char.loadouts[instanceTypeValue] then
            addon.db.char.loadouts[instanceTypeValue] = {}
        end
        if not addon.db.char.loadouts[instanceTypeValue][-1] then
            addon.db.char.loadouts[instanceTypeValue][-1] = {
                Specialization = -1,
                ["Override Default Specialization"] = false,
                ["Override Default Talents"] = false,
                Gearset = 0,
                Talents = -1,
                Addons = ""
            }
        end
        if not addon.db.char.loadouts[instanceTypeValue][instanceValue] then
            addon.db.char.loadouts[instanceTypeValue][instanceValue] = {
                Specialization = -1,
                ["Override Default Specialization"] = false,
                ["Override Default Talents"] = false,
                Gearset = 0,
                Talents = -1,
                Addons = ""
            }
        end

        local dbLoadouts = addon.db.char.loadouts
        local specializationSet = dbLoadouts[instanceTypeValue][instanceValue].Specialization
        local overrideSpecializationSet = dbLoadouts[instanceTypeValue][instanceValue]["Override Default Specialization"]
        local overrideTalentSet = dbLoadouts[instanceTypeValue][instanceValue]["Override Default Talents"]
        if not overrideSpecializationSet or not overrideTalentSet then
            specializationSet = dbLoadouts[instanceTypeValue][-1].Specialization
        end
        if specializationSet ~= -1 then
            addon:checkTalentManager(specializationSet)
        end
        addon:createOptionsConfig(addon.frame, instanceTypeValue, instanceValue)
    end
end

local function ShowEncounter(callback, encounterValue, instanceTypeValue, instanceValue)
    addon.ConfigView.encounter = encounterValue
    if not addon.frame then return end

    local dbKey = instanceTypeValue .. " Encounter " .. instanceValue
    if not addon.db.char.loadouts[dbKey] then
        addon.db.char.loadouts[dbKey] = {}
    end
    if not addon.db.char.loadouts[dbKey][encounterValue] then
        addon.db.char.loadouts[dbKey][encounterValue] = {
            Specialization = -1,
            ["Override Default Specialization"] = false,
            ["Override Default Talents"] = false,
            Gearset = 0,
            Talents = -1,
            Addons = ""
        }
    end

    if not addon.db.char.loadouts[instanceTypeValue] then
        addon.db.char.loadouts[instanceTypeValue] = {}
    end
    if not addon.db.char.loadouts[instanceTypeValue][-1] then
        addon.db.char.loadouts[instanceTypeValue][-1] = {
            Specialization = -1,
            ["Override Default Specialization"] = false,
            ["Override Default Talents"] = false,
            Gearset = 0,
            Talents = -1,
            Addons = ""
        }
    end

    local dbLoadouts = addon.db.char.loadouts
    local instanceEncounter = instanceValue .. " Encounter"
    local specializationSet = dbLoadouts[instanceEncounter][encounterValue].Specialization
    local overrideSpecializationSet = dbLoadouts[instanceEncounter][encounterValue]["Override Default Specialization"]
    local overrideTalentSet = dbLoadouts[instanceEncounter][encounterValue]["Override Default Talents"]
    if not overrideSpecializationSet or not overrideTalentSet then
        specializationSet = dbLoadouts[instanceEncounter][-1].Specialization
    end
    if specializationSet ~= -1 then
        addon:checkTalentManager(specializationSet)
    end
    -- For raids, we want to show options in right panel but keep middle panel visible
    -- Don't call createOptionsConfig as it hides the middle panel
    -- Instead, just populate the right panel directly
    ClearOptionsArea()
    local _, _, targetWidget = CreateLayoutAreas(addon.frame, true)
    if targetWidget then
        addon:populateOptionsArea(targetWidget, instanceEncounter, encounterValue)
    end
end

local function ShowDungeonInstance(callback, instanceID, instanceTypeValue)
    addon.ConfigView.encounter = instanceID
    if not addon.frame then return end

    if not addon.db.char.loadouts[instanceTypeValue] then
        addon.db.char.loadouts[instanceTypeValue] = {}
    end
    if not addon.db.char.loadouts[instanceTypeValue][-1] then
        addon.db.char.loadouts[instanceTypeValue][-1] = {
            Specialization = -1,
            ["Override Default Specialization"] = false,
            ["Override Default Talents"] = false,
            Gearset = 0,
            Talents = -1,
            Addons = ""
        }
    end
    if not addon.db.char.loadouts[instanceTypeValue][instanceID] then
        addon.db.char.loadouts[instanceTypeValue][instanceID] = {
            Specialization = -1,
            ["Override Default Specialization"] = false,
            ["Override Default Talents"] = false,
            Gearset = 0,
            Talents = -1,
            Addons = ""
        }
    end

    local dbLoadouts = addon.db.char.loadouts
    local specializationSet = dbLoadouts[instanceTypeValue][instanceID].Specialization
    local overrideSpecializationSet = dbLoadouts[instanceTypeValue][instanceID]["Override Default Specialization"]
    local overrideTalentSet = dbLoadouts[instanceTypeValue][instanceID]["Override Default Talents"]
    if not overrideSpecializationSet or not overrideTalentSet then
        specializationSet = dbLoadouts[instanceTypeValue][-1].Specialization
    end
    if specializationSet ~= -1 then
        addon:checkTalentManager(specializationSet)
    end
    -- For dungeons, we want to show options in right panel but keep middle panel visible
    -- Don't call createOptionsConfig as it hides the middle panel
    -- Instead, just populate the right panel directly
    ClearOptionsArea()
    local _, _, targetWidget = CreateLayoutAreas(addon.frame, true)
    if targetWidget then
        addon:populateOptionsArea(targetWidget, instanceTypeValue, instanceID)
    end
end

AF.RegisterCallback("ShowInstanceType", ShowInstanceType, "medium")
AF.RegisterCallback("ShowInstance", ShowInstance, "medium")
AF.RegisterCallback("ShowEncounter", ShowEncounter, "medium")
AF.RegisterCallback("ShowDungeonInstance", ShowDungeonInstance, "medium")

---Creates instance type button group
---@param frame table The AbstractFramework frame to add elements to
local function CreateInstanceTypeButtons(frame)
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
            button:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        else
            button:SetPoint("LEFT", instanceTypeButtons[i-1], "RIGHT", -1, 0)
        end
        button.id = instanceType
        table.insert(instanceTypeButtons, button)
    end

    local function ShowInstanceType(tab)
        if lastShownInstanceType ~= tab then
            AF.Fire("ShowInstanceType", tab.id)
            lastShownInstanceType = tab
        end
    end

    if #instanceTypeButtons > 0 then
        AF.CreateButtonGroup(instanceTypeButtons, ShowInstanceType, function() end, function() end, function() end, function() end)
    end

    if not addon.ConfigView.instanceType or addon.ConfigView.instanceType == "" then
        addon.ConfigView.instanceType = "Dungeon"
    end

    for _, button in pairs(instanceTypeButtons) do
        if button.id == addon.ConfigView.instanceType then
            button:Click()
            break
        end
    end

    if addon.ConfigView.instanceType == "Dungeon" then
        addon:createInstanceConfig(frame, "Dungeon")
    end
end

---Creates configuration tab group for instance types
---@param frame table The AbstractFramework frame to add elements to
function addon:createInstanceTypeConfig(frame)
    CreateInstanceTypeButtons(frame)
end

---Opens the main configuration window
function addon:openConfig()
    if not GetSpecialization() or GetSpecialization() == 5 then
        self:Print("No specialization found")
        return
    end
    if self.manager:getAddonManager() then
        self:checkAddonManager()
    end
    local frame = self.frame
    if self.frame and self.frameType == "Config" then
        if self.frame.content then
            self.frame.content:Hide()
            self.frame.content = nil
        end
    else
        if self.frame then
            self.frame:Hide()
            self.frame = nil
        end
        self.frameType = "Config"
        frame = AF.CreateHeaderedFrame(AF.UIParent, "InstanceLoadouts_Config",
            AF.GetIconString("IL", 14, 14, "InstanceLoadouts") .. " " .. addonName, 651, 380)
        AF.SetPoint(frame, "CENTER", UIParent, "CENTER", 0, 0)
        frame:SetTitleColor("white")
        frame:SetFrameLevel(100)
        frame:SetTitleJustify("LEFT")

        local pageName = AF.CreateFontString(frame.header, nil, "white", "AF_FONT_TITLE")
        AF.SetPoint(pageName, "CENTER", frame.header, "CENTER", 0, 0)
        pageName:SetJustifyH("CENTER")
        pageName:SetText("Config")

        local optionsButton = AF.CreateButton(frame.header, "", addonName, 20, 20)
        AF.ApplyDefaultBackdropWithColors(optionsButton, "header")
        AF.SetPoint(optionsButton, "TOPRIGHT", -19, 0)

        optionsButton:SetTexture("OptionsIcon-Brown", {12, 12}, {"CENTER", 0, 0}, true)
        optionsButton:SetFrameLevel(frame:GetFrameLevel() + 10)
        optionsButton:SetOnClick(function()
            -- Set flag to prevent config OnHide from calling checkIfIsTrackedInstance
            self.transitioning = true
            addon:toggleOptions(function()
                self.transitioning = nil
                addon:checkIfIsTrackedInstance()
            end)
        end)

        frame:SetScript("OnHide", function()
            CleanupLayoutAreas()
            self.frame = nil
            -- Only call checkIfIsTrackedInstance if we're not transitioning to another window
            if not self.transitioning then
                addon:checkIfIsTrackedInstance()
            end
        end)

        _G["InstanceLoadouts_Config"] = frame
        table.insert(UISpecialFrames, "InstanceLoadouts_Config")
        frame:Show()
        
        -- Clear transition flag since we've successfully opened the config window
        self.transitioning = nil
    end

    self.frame = frame
   self:createInstanceTypeConfig(frame)
end

function addon:toggleConfig()
    if addon.frame and addon.frameType == "Config" then
        addon.frame:Hide()
        addon.frame = nil
    else
        addon:openConfig()
    end
end