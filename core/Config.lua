local addonName, addon = ...

local AceGUI = LibStub("AceGUI-3.0")

-- Order of frames when creating GUI
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

-- Initialize the view for the config window
-- is changed later and used to save last seen configs
-- or when pressing f in the reminder window to show current instance/boss
addon.ConfigView = {
    ["instanceType"] = instanceTypeOrder[1],
    ["instance"] = -1,
    ["encounter"] = -1,
}

---Creates configuration options for a specific instance or encounter
---@param widget table The AceGUI widget to add elements to
---@param instanceTypeValue string The type of instance (e.g. "Dungeon", "Raid")
---@param instanceValue number The instance ID
function addon:createOptionsConfig(widget, instanceTypeValue, instanceValue)
    local dbLoadouts = self.db.char.loadouts
    local dbLoadout = dbLoadouts[instanceTypeValue][instanceValue]
    local instanceHeader = AceGUI:Create("Label")
    instanceHeader:SetText(instanceTypeValue)
    instanceHeader:SetFont("Fonts\\FRIZQT__.TTF", 26, "OUTLINE")
    instanceHeader:SetFullWidth(true)
    widget:AddChild(instanceHeader)

    local encounterHeader = AceGUI:Create("Label")
    encounterHeader:SetText(self.ConvertIDToName[instanceValue])
    encounterHeader:SetFont("Fonts\\FRIZQT__.TTF", 20, "OUTLINE")
    encounterHeader:SetFullWidth(true)
    widget:AddChild(encounterHeader)
    local line = AceGUI:Create("Heading")
    line:SetFullWidth(true)
    line:SetHeight(10)
    widget:AddChild(line)
    local scrollContainer = AceGUI:Create("SimpleGroup")
    scrollContainer:SetFullWidth(true)
    scrollContainer:SetFullHeight(true)
    scrollContainer:SetLayout("Fill")
    widget:AddChild(scrollContainer)
    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetLayout("Flow")
    scrollContainer:AddChild(scroll)
    for _, type in pairs(externalOrder) do
        local info = self.externalInfo[type]
        local container = AceGUI:Create("SimpleGroup")
        container:SetLayout("Flow")
        container:SetFullWidth(true)
        if instanceValue == -1 and next(info) then
            local dropdown = AceGUI:Create("Dropdown")
            dropdown:SetLabel(type)
            if type == "Specialization" then
                dropdown:SetList(info)
                dropdown:SetValue(dbLoadout[type])
                dropdown:SetCallback("OnValueChanged", function(widget, callback, key)
                    dbLoadout[type] = key
                    dbLoadout["Talents"] = -1
                    addon:openConfig()
                end)
            elseif type == "Talents" then
                dropdown:SetList(info)
                dropdown:SetValue(dbLoadout[type])
                dropdown:SetDisabled(dbLoadout.Specialization == -1)
                dropdown:SetCallback("OnValueChanged", function(widget, callback, key)
                    dbLoadout[type] = key
                end)
            else
                dropdown:SetList(info)
                dropdown:SetValue(dbLoadout[type])
                dropdown:SetCallback("OnValueChanged", function(widget, callback, key)
                    dbLoadout[type] = key
                end)
            end
            container:AddChild(dropdown)
        elseif next(info) then
            local dropdown = AceGUI:Create("Dropdown")
            dropdown:SetLabel(type)
            local checkbox = AceGUI:Create("CheckBox")
            checkbox:SetLabel("Override Default " .. type)
            if type == "Specialization" then
                dropdown:SetList(info)
                dropdown:SetValue(dbLoadout["Override Default " .. type] and dbLoadout[type] or self.db.char.loadouts[instanceTypeValue][-1][type])
                dropdown:SetDisabled(not dbLoadout["Override Default " .. type])
                dropdown:SetCallback("OnValueChanged", function(widget, callback, key)
                    dbLoadout[type] = key
                    dbLoadout["Talents"] = -1
                    addon:openConfig()
                end)
                checkbox:SetValue(dbLoadout["Override Default " .. type])
                checkbox:SetCallback("OnValueChanged", function(widget, callback, value)
                    dbLoadout["Override Default " .. type] = value
                    addon:openConfig()
                end)
            elseif type == "Talents" then
                dropdown:SetList(info)
                dropdown:SetValue(dbLoadout["Override Default Specialization"] and dbLoadout["Override Default " .. type] and dbLoadout[type] or self.db.char.loadouts[instanceTypeValue][-1][type])
                dropdown:SetDisabled(not dbLoadout["Override Default " .. type] or not dbLoadout["Override Default Specialization"] or dbLoadout.Specialization == -1)
                dropdown:SetCallback("OnValueChanged", function(widget, callback, key)
                    dbLoadout[type] = key
                end)
                checkbox:SetValue(dbLoadout["Override Default " .. type] and dbLoadout["Override Default Specialization"] and dbLoadout.Specialization ~= -1)
                checkbox:SetDisabled(not dbLoadout["Override Default Specialization"] or dbLoadout.Specialization == -1)
                checkbox:SetCallback("OnValueChanged", function(widget, callback, value)
                    dbLoadout["Override Default " .. type] = value
                    addon:openConfig()
                end)
            else
                dropdown:SetList(info)
                dropdown:SetValue(dbLoadout["Override Default " .. type] and dbLoadout[type] or self.db.char.loadouts[instanceTypeValue][-1][type])
                dropdown:SetDisabled(not dbLoadout["Override Default " .. type])
                dropdown:SetCallback("OnValueChanged", function(widget, callback, key)
                    dbLoadout[type] = key
                end)
                checkbox:SetValue(dbLoadout["Override Default " .. type])
                checkbox:SetCallback("OnValueChanged", function(widget, callback, value)
                    dbLoadout["Override Default " .. type] = value
                    dropdown:SetValue(dbLoadout["Override Default " .. type] and dbLoadout[type] or self.db.char.loadouts[instanceTypeValue][-1][type])
                    dropdown:SetDisabled(not value)
                end)
            end
            container:AddChild(checkbox)
            container:AddChild(dropdown)
        else
            local label = AceGUI:Create("Label")
            label:SetText("No " .. type .. " Manager Found")
            label:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
            label:SetFullWidth(true)
            container:AddChild(label)
        end
        scroll:AddChild(container)
    end
    if strfind(instanceTypeValue, "Encounter") then
        local raidInstanceID = strsplit(" ", instanceTypeValue)
        raidInstanceID = tonumber(raidInstanceID)
        instanceHeader:SetText(self.ConvertIDToName[raidInstanceID])
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
            local npcIDsEditBox = AceGUI:Create("MultiLineEditBox")
            npcIDsEditBox:SetLabel("npc IDs")
            npcIDsEditBox:SetFullWidth(true)
            npcIDsEditBox:SetNumLines(3)
            npcIDsEditBox:SetText(npcIDs)
            npcIDsEditBox:SetCallback("OnEnterPressed", function()
                local npcIDsText = gsub(npcIDsEditBox:GetText(), " ", "")
                local npcIDs = {strsplit(",", npcIDsText)}
                self.db.global.journalIDs.Raid[journalInstance][journalEncounter] = npcIDs
                for _, instanceInfo in ipairs(self.instanceGroups.Raid) do
                    if instanceInfo.instanceID == raidInstanceID then
                        for _, encounterInfo in ipairs(instanceInfo. encounterIDs) do
                            if encounterInfo.encounterID == instanceValue then
                                encounterInfo.npcIDs = npcIDs
                                break
                            end
                        end
                        break
                    end
                end
            end)
            scroll:AddChild(npcIDsEditBox)
        end
    end
end

---Creates configuration tree group for raid encounters
---@param widget table The AceGUI widget to add elements to  
---@param instanceTypeValue string The type of instance
---@param instanceValue number The raid instance ID
function addon:createRaidEncounterConfig(widget, instanceTypeValue, instanceValue)
    local encounterGroup = AceGUI:Create("TreeGroup")
    encounterGroup:SetFullHeight(true)
    encounterGroup:SetFullWidth(true)
    local configViewExists = false
    local tree = {}
    for _, instanceInfo in ipairs(self.instanceGroups[instanceTypeValue]) do
        if instanceInfo.instanceID == instanceValue then
            for _, encounterInfo in ipairs(instanceInfo.encounterIDs) do
                tinsert(tree, {value = encounterInfo.encounterID, text = encounterInfo.encounterName})
                if encounterInfo.encounterID == self.ConfigView.encounter then
                    configViewExists = true
                end
            end
            break
        end
    end
    if not configViewExists then
        self.ConfigView.encounter = tree[1].value
    end
    encounterGroup:SetTree(tree)
    encounterGroup:SetLayout("Flow")
    encounterGroup:EnableButtonTooltips(false)
    encounterGroup:SetCallback("OnGroupSelected", (function(widget, callback, encounterValue)
        local dbLoadouts = self.db.char.loadouts
        local instanceEncounter = instanceValue .. " Encounter"
        local specializationSet = dbLoadouts[instanceEncounter][encounterValue].Specialization
        local overrideSpecializationSet = dbLoadouts[instanceEncounter][encounterValue]["Override Default Specialization"]
        local overrideTalentSet = dbLoadouts[instanceEncounter][encounterValue]["Override Default Talents"]
        if not overrideSpecializationSet or not overrideTalentSet then
            specializationSet = dbLoadouts[instanceEncounter][-1].Specialization
        end
        if specializationSet ~= -1 then
            self:checkTalentManager(specializationSet)
        end
        widget:ReleaseChildren()
        addon.ConfigView.encounter = encounterValue
        addon:createOptionsConfig(widget, instanceEncounter, encounterValue)
    end))
    encounterGroup:SelectByValue(self.ConfigView.encounter)
    widget:AddChild(encounterGroup)
end

---Creates configuration tree group for dungeon instances
---@param widget table The AceGUI widget to add elements to
---@param instanceTypeValue string The type of instance 
---@param tierValue number The dungeon tier ID
function addon:createDungeonInstanceConfig(widget, instanceTypeValue, tierValue)
    local encounterGroup = AceGUI:Create("TreeGroup")
    encounterGroup:SetFullHeight(true)
    encounterGroup:SetFullWidth(true)
    local configViewExists = false
    local tree = {}
    for _, tierInfo in ipairs(self.instanceGroups[instanceTypeValue]) do
        if tierInfo.tierID == tierValue then
            for _, instanceInfo in ipairs(tierInfo.instanceIDs) do
                tinsert(tree, {value = instanceInfo.instanceID, text = instanceInfo.instanceName})
                if instanceInfo.instanceID == self.ConfigView.encounter then
                    configViewExists = true
                end
            end
            break
        end
    end
    if not configViewExists then
        self.ConfigView.encounter = tree[1].value
    end
    encounterGroup:SetTree(tree)
    encounterGroup:SetLayout("Flow")
    encounterGroup:EnableButtonTooltips(false)
    encounterGroup:SetCallback("OnGroupSelected", (function(widget, callback, instanceValue)
        local dbLoadouts = self.db.char.loadouts
        local specializationSet = dbLoadouts[instanceTypeValue][instanceValue].Specialization
        local overrideSpecializationSet = dbLoadouts[instanceTypeValue][instanceValue]["Override Default Specialization"]
        local overrideTalentSet = dbLoadouts[instanceTypeValue][instanceValue]["Override Default Talents"]
        if not overrideSpecializationSet or not overrideTalentSet then
            specializationSet = dbLoadouts[instanceTypeValue][-1].Specialization
        end
        if specializationSet ~= -1 then
            self:checkTalentManager(specializationSet)
        end
        widget:ReleaseChildren()
        addon.ConfigView.encounter = instanceValue
        addon:createOptionsConfig(widget, instanceTypeValue, instanceValue)
    end))
    encounterGroup:SelectByValue(self.ConfigView.encounter)
    widget:AddChild(encounterGroup)
end

---Creates configuration tree group for instances
---@param frame table The AceGUI frame to add elements to
---@param instanceTypeValue string The type of instance
function addon:createInstanceConfig(frame, instanceTypeValue)
    local instanceGroup = AceGUI:Create("TreeGroup")
    instanceGroup:SetFullHeight(true)
    instanceGroup:SetFullWidth(true)
    local configViewExists = false
    local tree = {}
    for _, instanceInfo in pairs(self.instanceGroups[instanceTypeValue]) do
        if instanceInfo.instanceID then
            tinsert(tree, {value = instanceInfo.instanceID, text = instanceInfo.instanceName})
            if instanceInfo.instanceID == self.ConfigView.instance then
                configViewExists = true
            end
        else
            tinsert(tree, {value = instanceInfo.tierID, text = instanceInfo.tierName})
            if instanceInfo.tierID == self.ConfigView.instance then
                configViewExists = true
            end
        end
    end
    if not configViewExists then
        self.ConfigView.instance = tree[1].value
    end

    instanceGroup:SetTree(tree)
    instanceGroup:SetLayout("Flow")
    instanceGroup:EnableButtonTooltips(false)
    instanceGroup:SetCallback("OnGroupSelected", (function(widget, callback, instanceValue)
        widget:ReleaseChildren()
        addon.ConfigView.instance = instanceValue
        if instanceTypeValue == "Raid" then
            addon:createRaidEncounterConfig(widget, instanceTypeValue, instanceValue)
        elseif instanceTypeValue == "Dungeon" then
            addon:createDungeonInstanceConfig(widget, instanceTypeValue, instanceValue)
        else
            local dbLoadouts = self.db.char.loadouts
            local specializationSet = dbLoadouts[instanceTypeValue][instanceValue].Specialization
            local overrideSpecializationSet = dbLoadouts[instanceTypeValue][instanceValue]["Override Default Specialization"]
            local overrideTalentSet = dbLoadouts[instanceTypeValue][instanceValue]["Override Default Talents"]
            if not overrideSpecializationSet or not overrideTalentSet then
                specializationSet = dbLoadouts[instanceTypeValue][-1].Specialization
            end
            if specializationSet ~= -1 then
                self:checkTalentManager(specializationSet)
            end
            addon:createOptionsConfig(widget, instanceTypeValue, instanceValue)
        end
    end))
    instanceGroup:SelectByValue(self.ConfigView.instance)
    frame:AddChild(instanceGroup)
end

---Creates the instance type tab group configuration
---@param frame table The AceGUI frame to add elements to
function addon:createInstanceTypeConfig(frame)
    local instanceTypeGroup = AceGUI:Create("TabGroup")
    instanceTypeGroup:SetFullHeight(true)
    instanceTypeGroup:SetFullWidth(true)
    local tabs = {}
    for _, instanceType in ipairs(instanceTypeOrder) do
        tinsert(tabs, {value = instanceType, text = instanceType})
    end
    instanceTypeGroup:SetTabs(tabs)
    instanceTypeGroup:SetLayout("Flow")
    instanceTypeGroup:SetCallback("OnGroupSelected", (function(widget, callback, instanceTypeValue)
        widget:ReleaseChildren()
        addon.ConfigView.instanceType = instanceTypeValue
        addon:createInstanceConfig(widget, instanceTypeValue)
    end))
    instanceTypeGroup:SelectTab(self.ConfigView.instanceType)
    frame:AddChild(instanceTypeGroup)
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
        self.frame:ReleaseChildren()
    else
        if self.frame then
            AceGUI:Release(self.frame)
            self.frame = nil
        end
        self.frameType = "Config"
        frame = AceGUI:Create("Frame")
        frame:SetTitle(addonName)
        frame:SetLayout("Flow")
        frame:SetHeight(550)
        frame:SetWidth(900)
        frame:SetCallback("OnClose", function(widget)
            AceGUI:Release(widget)
            self.frame = nil
            addon:checkIfIsTrackedInstance()
        end)
    end
    self:createOptionsButton(frame)

    self:createInstanceTypeConfig(frame)

    self.frame = frame
end

---Toggles the configuration window open/closed
function addon:toggleConfig()
    if addon.frame and addon.frameType == "Config" then
        AceGUI:Release(addon.frame)
        addon.frame = nil
    else
        addon:openConfig()
    end
end
