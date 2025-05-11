local addonName, addon = ...

-- Ace3 libs
local AceGUI = LibStub("AceGUI-3.0")

local isGarrison = {
    1152, -- Horde Garrison lvl 1
    1330, -- Horde Garrison lvl 2
    1153, -- Horde Garrison lvl 3
    1158, -- Alliance Garrison lvl 1
    1331, -- Alliance Garrison lvl 2
    1159, -- Alliance Garrison lvl 3
}

---Creates the reminder GUI for Specializations
---@param frame table The AceGUI frame to add elements to
---@param instanceType string The instance type (e.g. "Dungeon", "Raid")  
---@param instance number The instance ID
---@return boolean True if specialization needs to be changed
function addon:createSpecializationFrame(frame, instanceType, instance)
    local dbLoadouts = self.db.char.loadouts
    local change = false
    local container = AceGUI:Create("InlineGroup")
    container:SetLayout("Flow")
    container:SetFullWidth(true)
    local header = AceGUI:Create("Label")
    header:SetText("Specialization:")
    header:SetFont("Fonts\\FRIZQT__.TTF", 22, "OUTLINE")
    header:SetRelativeWidth(0.5)
    container:AddChild(header)
    if next(self.externalInfo.Specialization) then
        local currentSpec = GetSpecialization()
        local specializationSet = dbLoadouts[instanceType][instance].Specialization
        local overrideSpecializationSet = dbLoadouts[instanceType][instance]["Override Default Specialization"]
        if not overrideSpecializationSet then
            specializationSet = dbLoadouts[instanceType][-1].Specialization
        end
        if specializationSet == -1 then
            local label = AceGUI:Create("Label")
            label:SetText("Specialization not set")
            label:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
            label:SetRelativeWidth(0.5)
            container:AddChild(label)
        elseif specializationSet ~= currentSpec then
            change = true
            local _, name = GetSpecializationInfo(specializationSet)
            local button = AceGUI:Create("Button")
            button:SetText("Change specialization to " .. name)
            button:SetRelativeWidth(0.5)
            button:SetCallback("OnClick", function(widget, callback, mouseButton)
                button:SetDisabled(true)
                C_SpecializationInfo.SetSpecialization(specializationSet)
                addon:RegisterEvent("ACTIVE_PLAYER_SPECIALIZATION_CHANGED", function()
                    if specializationSet == GetSpecialization() then
                        addon:UnregisterEvent("ACTIVE_PLAYER_SPECIALIZATION_CHANGED")
                        addon:UnregisterEvent("SPECIALIZATION_CHANGE_CAST_FAILED")
                        C_Timer.After(0, function()
                            addon:checkIfIsTrackedInstance()
                        end)
                    end
                end)
                addon:RegisterEvent("SPECIALIZATION_CHANGE_CAST_FAILED", function()
                    button:SetDisabled(false)
                    addon:UnregisterEvent("ACTIVE_PLAYER_SPECIALIZATION_CHANGED")
                    addon:UnregisterEvent("SPECIALIZATION_CHANGE_CAST_FAILED")

                end)
            end)
            container:AddChild(button)
        else
            local _, name = GetSpecializationInfo(currentSpec)
            local label = AceGUI:Create("Label")
            label:SetText("Current Spec is " .. name)
            label:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
            label:SetRelativeWidth(0.5)
            container:AddChild(label)
        end
    else
        local label = AceGUI:Create("Label")
        label:SetText("No Specialization Manager Found")
        label:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
        label:SetFullWidth(true)
        container:AddChild(label)
    end
    frame:AddChild(container)
    return change
end

---Creates the reminder GUI for Talents
---@param frame table The AceGUI frame to add elements to
---@param instanceType string The instance type
---@param instance number The instance ID 
---@return boolean True if talents need to be changed
function addon:createTalentsFrame(frame, instanceType, instance)
    local dbLoadouts = self.db.char.loadouts
    local change = false
    local container = AceGUI:Create("InlineGroup")
    container:SetLayout("Flow")
    container:SetFullWidth(true)
    local header = AceGUI:Create("Label")
    header:SetText("Talents:")
    header:SetFont("Fonts\\FRIZQT__.TTF", 22, "OUTLINE")
    header:SetRelativeWidth(0.5)
    container:AddChild(header)
    if next(self.externalInfo.Talents) then
        local specializationSet = dbLoadouts[instanceType][instance].Specialization
        local overrideSpecializationSet = dbLoadouts[instanceType][instance]["Override Default Specialization"]
        local talentSet = dbLoadouts[instanceType][instance].Talents
        local overrideTalentSet = dbLoadouts[instanceType][instance]["Override Default Talents"]
        if not overrideSpecializationSet then
            specializationSet = dbLoadouts[instanceType][-1].Specialization
            talentSet = dbLoadouts[instanceType][-1].Talents
        elseif not overrideTalentSet then
            talentSet = dbLoadouts[instanceType][-1].Talents
        end

        if talentSet == -1 then
            local label = AceGUI:Create("Label")
            label:SetText("Talents not set")
            label:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
            label:SetRelativeWidth(0.5)
            container:AddChild(label)
        else
            if specializationSet == GetSpecialization() then
                local specID = GetSpecializationInfo(specializationSet)
                local configID
                local talentManager = self.manager:getTalentManager()
                if talentManager then
                    configID = self.manager:getActiveTalentLoadoutID()
                else
                    configID = C_ClassTalents.GetLastSelectedSavedConfigID(specID)
                end
                if talentSet ~= configID then
                    change = true
                    local name = self.externalInfo.Talents[talentSet]
                    local button = AceGUI:Create("Button")
                    button:SetText("Change Talents to " .. name)
                    button:SetRelativeWidth(0.5)
                    button:SetCallback("OnClick", function(widget, callback, mouseButton)
                        if talentManager then
                            self.manager.loadTalentLoadout(talentSet, true)
                            button:SetDisabled(true)
                            addon:RegisterEvent("TRAIT_CONFIG_UPDATED", function()
                                container:ReleaseChildren()
                                header = AceGUI:Create("Label")
                                header:SetText("Talents:")
                                header:SetFont("Fonts\\FRIZQT__.TTF", 22, "OUTLINE")
                                header:SetRelativeWidth(0.5)
                                container:AddChild(header)
                                local label = AceGUI:Create("Label")
                                label:SetText("Current Talents are " .. name)
                                label:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
                                label:SetRelativeWidth(0.5)
                                container:AddChild(label)
                                addon:UnregisterEvent("TRAIT_CONFIG_UPDATED")
                                addon:UnregisterEvent("CONFIG_COMMIT_FAILED")
                            end)
                            addon:RegisterEvent("CONFIG_COMMIT_FAILED", function()
                                button:SetDisabled(false)
                                addon:UnregisterEvent("TRAIT_CONFIG_UPDATED")
                                addon:UnregisterEvent("CONFIG_COMMIT_FAILED")
                            end)
                        else
                            local result = C_ClassTalents.LoadConfig(talentSet, true)
                            if not C_AddOns.IsAddOnLoaded("Blizzard_PlayerSpells") then
                                C_AddOns.LoadAddOn("Blizzard_PlayerSpells")
                            end 
                            PlayerSpellsFrame.TalentsFrame.LoadSystem:SetSelectionID(talentSet)
                            if result == 1 then
                                C_ClassTalents.UpdateLastSelectedSavedConfigID(specID, talentSet)
                                container:ReleaseChildren()
                                header = AceGUI:Create("Label")
                                header:SetText("Talents:")
                                header:SetFont("Fonts\\FRIZQT__.TTF", 22, "OUTLINE")
                                header:SetRelativeWidth(0.5)
                                container:AddChild(header)
                                local label = AceGUI:Create("Label")
                                label:SetText("Current Talents are " .. name)
                                label:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
                                label:SetRelativeWidth(0.5)
                                container:AddChild(label)
                            elseif result == 2 then
                                button:SetDisabled(true)
                                addon:RegisterEvent("TRAIT_CONFIG_UPDATED", function()
                                    if specializationSet == GetSpecialization() then
                                        C_ClassTalents.UpdateLastSelectedSavedConfigID(specID, talentSet)
                                        container:ReleaseChildren()
                                        header = AceGUI:Create("Label")
                                        header:SetText("Talents:")
                                        header:SetFont("Fonts\\FRIZQT__.TTF", 22, "OUTLINE")
                                        header:SetRelativeWidth(0.5)
                                        container:AddChild(header)
                                        local label = AceGUI:Create("Label")
                                        label:SetText("Current Talents are " .. name)
                                        label:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
                                        label:SetRelativeWidth(0.5)
                                        container:AddChild(label)
                                        addon:UnregisterEvent("TRAIT_CONFIG_UPDATED")
                                        addon:UnregisterEvent("CONFIG_COMMIT_FAILED")
                                    end
                                end)
                                addon:RegisterEvent("CONFIG_COMMIT_FAILED", function()
                                    button:SetDisabled(false)
                                    addon:UnregisterEvent("TRAIT_CONFIG_UPDATED")
                                    addon:UnregisterEvent("CONFIG_COMMIT_FAILED")
                                end)
                            end
                        end
                    end)
                    container:AddChild(button)
                else
                    local name = self.externalInfo.Talents[talentSet]
                    local label = AceGUI:Create("Label")
                    label:SetText("Current Talents are " .. name)
                    label:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
                    label:SetRelativeWidth(0.5)
                    container:AddChild(label)
                end
            else
                local label = AceGUI:Create("Label")
                label:SetText("Change Specialization")
                label:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
                label:SetRelativeWidth(0.5)
                container:AddChild(label)
            end
        end
    else
        local label = AceGUI:Create("Label")
        label:SetText("No Talents Manager Found")
        label:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
        label:SetFullWidth(true)
        container:AddChild(label)
    end
    frame:AddChild(container)
    return change
end

---Creates the reminder GUI for Gearsets
---@param frame table The AceGUI frame to add elements to
---@param instanceType string The instance type
---@param instance number The instance ID
---@return boolean True if gearset needs to be changed
function addon:createGearsetFrame(frame, instanceType, instance)
    local dbLoadouts = self.db.char.loadouts
    local change = false
    local container = AceGUI:Create("InlineGroup")
    container:SetLayout("Flow")
    container:SetFullWidth(true)
    local header = AceGUI:Create("Label")
    header:SetText("Gearset:")
    header:SetFont("Fonts\\FRIZQT__.TTF", 22, "OUTLINE")
    header:SetRelativeWidth(0.5)
    container:AddChild(header)
    if next(self.externalInfo.Gearset) then
        local gearSet = dbLoadouts[instanceType][instance].Gearset
        local overrideGearSet = dbLoadouts[instanceType][instance]["Override Default Gearset"]
        if gearSet == -1 or not overrideGearSet then
            gearSet = dbLoadouts[instanceType][-1].Gearset
        end
        if gearSet == -1 then
            local label = AceGUI:Create("Label")
            label:SetText("Gearset not set")
            label:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
            label:SetRelativeWidth(0.5)
            container:AddChild(label)
        else
            local name, _, _, isEquipped = C_EquipmentSet.GetEquipmentSetInfo(gearSet)
            if name and not isEquipped then
                change = true
                local button = AceGUI:Create("Button")
                button:SetText("Change Gearset to " .. name)
                button:SetRelativeWidth(0.5)
                button:SetCallback("OnClick", function(widget, callback, mouseButton)
                    C_EquipmentSet.UseEquipmentSet(gearSet)
                    container:ReleaseChildren()
                    header = AceGUI:Create("Label")
                    header:SetText("Gearset:")
                    header:SetFont("Fonts\\FRIZQT__.TTF", 22, "OUTLINE")
                    header:SetRelativeWidth(0.5)
                    container:AddChild(header)
                    local label = AceGUI:Create("Label")
                    label:SetText("Current Gearset is " .. name)
                    label:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
                    label:SetRelativeWidth(0.5)
                    container:AddChild(label)
                end)
                container:AddChild(button)
            elseif isEquipped then
                local label = AceGUI:Create("Label")
                label:SetText("Current Gearset is " .. name)
                label:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
                label:SetRelativeWidth(0.5)
                container:AddChild(label)
            end
        end
    else
        local label = AceGUI:Create("Label")
        label:SetText("No Gearset Manager Found")
        label:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
        label:SetFullWidth(true)
        container:AddChild(label)
    end
    frame:AddChild(container)
    return change
end

---Creates the reminder GUI for Addons
---@param frame table The AceGUI frame to add elements to
---@param instanceType string The instance type
---@param instance number The instance ID
---@return boolean True if addons need to be changed 
function addon:createAddonsFrame(frame, instanceType, instance)
    local dbLoadouts = self.db.char.loadouts
    local change = false
    local container = AceGUI:Create("InlineGroup")
    container:SetLayout("Flow")
    container:SetFullWidth(true)
    local header = AceGUI:Create("Label")
    header:SetText("Addons:")
    header:SetFont("Fonts\\FRIZQT__.TTF", 22, "OUTLINE")
    header:SetRelativeWidth(0.5)
    container:AddChild(header)
    if next(self.externalInfo.Addons) then
        local addonSet = dbLoadouts[instanceType][instance].Addons
        local overrideAddonSet = dbLoadouts[instanceType][instance]["Override Default Gearset"]
        if addonSet == -1 or not overrideAddonSet then
            addonSet = dbLoadouts[instanceType][-1].Addons
        end
        if addonSet == -1 then
            local label = AceGUI:Create("Label")
            label:SetText("Addons not set")
            label:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
            label:SetRelativeWidth(0.5)
            container:AddChild(label)
        else
            local name = self.manager:getAddonSetName(addonSet)
            local isSetActive = self.manager:isActiveAddonSet(addonSet)
            if not isSetActive then
                change = true
                local button = AceGUI:Create("Button")
                button:SetText("Change Addons to " .. name)
                button:SetRelativeWidth(0.5)
                button:SetCallback("OnClick", function(widget, callback, mouseButton)
                    addon.manager:loadAddons(addonSet)
                    C_UI.Reload()
                end)
                container:AddChild(button)
            else
                local label = AceGUI:Create("Label")
                label:SetText("Current Addons are " .. name)
                label:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
                label:SetRelativeWidth(0.5)
                container:AddChild(label)
            end
        end
    else
        local label = AceGUI:Create("Label")
        label:SetText("No Addons Manager Found")
        label:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
        label:SetFullWidth(true)
        container:AddChild(label)
    end
    frame:AddChild(container)
    return change
end

---Creates the Options button in the reminder GUI
---@param frame table The AceGUI frame to add elements to
---@param instanceType string The instance type
---@param instance number The instance ID
function addon:createChangeOptionsButton(frame, instanceType, instance)
    local encounter = instance
    if strfind(instanceType, "Encounter") then
        instance = strsplit(" ", instanceType)
        instance = tonumber(instance)
        instanceType = "Raid"
    elseif instanceType == "Dungeon" then
        for _, tierInfo in ipairs(self.instanceGroups.Dungeon) do
            if tierInfo.instanceIDs then
                for _, instanceInfo in ipairs(tierInfo.instanceIDs) do
                    if instanceInfo.instanceID and instanceInfo.instanceID == instance then
                        instance = tierInfo.tierID
                        break
                    end
                end
            end
            if instance ~= encounter then
                break
            end
        end
    end
    local container = AceGUI:Create("SimpleGroup")
    container:SetLayout("Flow")
    container:SetRelativeWidth(0.25)
    local button = AceGUI:Create("Button")
    button:SetText("Loadouts Config")
    button:SetRelativeWidth(0.5)
    button:SetHeight(35)
    button:SetCallback("OnClick", function(widget, callback, mouseButton)
        AceGUI:Release(addon.frame)
        addon.frame = nil
        addon.ConfigView.instanceType = instanceType
        addon.ConfigView.instance = instance
        addon.ConfigView.encounter = encounter
        addon:openConfig()
    end)
    frame:AddChild(container)
    frame:AddChild(button)
    
end

---Shows the reminder window for a specific instance
---@param instanceType string The instance type
---@param instance number The instance ID
function addon:showLoadoutForInstance(instanceType, instance)
    local dbLoadouts = self.db.char.loadouts
    if not dbLoadouts[instanceType] or not dbLoadouts[instanceType][instance] then
        if self.frame then
            AceGUI:Release(self.frame)
            self.frame = nil
        end
        return
    end
    local frame = self.frame
    if self.frame and self.frameType == "Reminder" then
        self.frame:ReleaseChildren()
    else
        if self.frame then
            AceGUI:Release(self.frame)
            self.frame = nil
        end
        self.frameType = "Reminder"
        frame = AceGUI:Create("Frame")
        frame:SetTitle(addonName)
        frame:SetLayout("Flow")
        frame:SetWidth(600)
        frame:SetHeight(425)
        frame:SetCallback("OnClose", function(widget)
            AceGUI:Release(widget)
            self.frame = nil
        end)
    end
    
    local header = AceGUI:Create("Label")
    header:SetText(self.ConvertIDToName[instance])
    header:SetFullWidth(true)
    header:SetFont("Fonts\\FRIZQT__.TTF", 30, "OUTLINE")
    frame:AddChild(header)

    local scrollContainer = AceGUI:Create("SimpleGroup")
    scrollContainer:SetFullWidth(true)
    scrollContainer:SetFullHeight(true)
    scrollContainer:SetLayout("Fill")
    frame:AddChild(scrollContainer)
    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetLayout("Flow")
    scrollContainer:AddChild(scroll)

    local gearsetChange = self:createGearsetFrame(scroll, instanceType, instance)
    local specializationChange = self:createSpecializationFrame(scroll, instanceType, instance)
    local talentsChange = self:createTalentsFrame(scroll, instanceType, instance)
    local addonsChange = self:createAddonsFrame(scroll, instanceType, instance)
    self:createChangeOptionsButton(scroll, instanceType, instance)

    self.frame = frame

    if not specializationChange and not talentsChange and not gearsetChange and not addonsChange then
        if self.frame then
            AceGUI:Release(self.frame)
            self.frame = nil
        end
    end
end

---Checks if target is a tracked raid boss
---@param instanceID number The instance ID to check
---@param encounterIDs table The encounter IDs to check against
function addon:checkIfTrackedTarget(instanceID, encounterIDs)
    local dbLoadouts = self.db.char.loadouts
    if not encounterIDs then
        return
    end
    local guid = UnitGUID("target")
    if guid then
        local unitType = strsplit("-", guid)
        if unitType == "Creature" or unitType == "Vehicle" then
            local _, _, _, _, _, npcID = strsplit("-", guid)
            for _, encounterInfo in ipairs(encounterIDs) do
                if encounterInfo.npcIDs then
                    for _, bossID in ipairs(encounterInfo.npcIDs) do
                        if npcID == tostring(bossID) then
                            local specializationSet = dbLoadouts[instanceID .. " Encounter"][encounterInfo.encounterID].Specialization
                            local overrideSpecializationSet = dbLoadouts[instanceID .. " Encounter"][encounterInfo.encounterID]["Override Default Specialization"]
                            if not overrideSpecializationSet then
                                specializationSet = dbLoadouts[instanceID .. " Encounter"][-1].Specialization
                            end 
                            if specializationSet ~= -1 then
                                self:checkTalentManager(specializationSet)
                            end
                            self:showLoadoutForInstance(instanceID .. " Encounter", encounterInfo.encounterID)
                            return
                        end
                    end
                end
            end
        end
    end
end

---Checks if current instance is tracked and shows reminder if needed
function addon:checkIfIsTrackedInstance()
    local dbLoadouts = self.db.char.loadouts
    self:UnregisterEvent("PLAYER_TARGET_CHANGED")
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    self:UnregisterEvent("PLAYER_REGEN_DISABLED")
    local _, instanceType, _, difficultyName, _, _, _, instanceID = GetInstanceInfo()
    local instance
    local encounter
    if instanceType == "none" or tContains(isGarrison, instanceID) then
        instance = "Open World"
        encounter = -1
    elseif instanceType == "party" then
        instance = "Dungeon"
        if self.ConvertIDToName[instanceID] and dbLoadouts[instance][instanceID] then
            encounter = instanceID
        end
    elseif instanceType == "raid" then
        instance = instanceID .. " Encounter"
        if self.ConvertIDToName[instanceID] and dbLoadouts[instance] and dbLoadouts[instance][-1] then
            encounter = -1
            for _, instanceInfo in ipairs(self.instanceGroups.Raid) do
                if instanceInfo.instanceID == instanceID and instanceInfo.encounterIDs then
                    self:RegisterEvent("PLAYER_TARGET_CHANGED", function()
                        addon:checkIfTrackedTarget(instanceID, instanceInfo.encounterIDs)
                    end)
                
                    self:RegisterEvent("PLAYER_REGEN_ENABLED", function()
                        addon:RegisterEvent("PLAYER_TARGET_CHANGED", function()
                            addon:checkIfTrackedTarget(instanceID, instanceInfo.encounterIDs)
                        end)
                    end)
                    self:RegisterEvent("PLAYER_REGEN_DISABLED", function()
                        addon:UnregisterEvent("PLAYER_TARGET_CHANGED")
                    end)
                    break
                end
            end
        end
    elseif difficultyName == "Delves" then
        instance = "Delve"
        if self.ConvertIDToName[instanceID] and dbLoadouts[instance][instanceID] then
            encounter = instanceID
        end
    elseif instanceType == "arena" then
        instance = "Arena"
        if self.ConvertIDToName[instanceID] and dbLoadouts[instance][instanceID] then
            encounter = instanceID
        end
    elseif instanceType == "pvp" then
        instance = "Battleground"
        if self.ConvertIDToName[instanceID] and dbLoadouts[instance][instanceID] then
            encounter = instanceID
        end
    end
    if instance and encounter then
        local specializationSet = dbLoadouts[instance][encounter].Specialization
        if not strfind(instance, "Encounter") then
            local overrideSpecializationSet = dbLoadouts[instance][encounter]["Override Default Specialization"]
            if not overrideSpecializationSet then
                specializationSet = dbLoadouts[instance][-1].Specialization
            end
        end
        if specializationSet ~= -1 then
            self:checkTalentManager(specializationSet)
        end
        self:checkAddonManager()
        self:showLoadoutForInstance(instance, encounter)
    end
end