local addonName, addon = ...

---@type AbstractFramework
local AF = _G.AbstractFramework

local isGarrison = {
    1152, -- Horde Garrison lvl 1
    1330, -- Horde Garrison lvl 2
    1153, -- Horde Garrison lvl 3
    1158, -- Alliance Garrison lvl 1
    1331, -- Alliance Garrison lvl 2
    1159, -- Alliance Garrison lvl 3
}

---Creates the reminder GUI for Specializations
---@param parent Frame The parent frame to add elements to
---@param instanceType string The instance type (e.g. "Dungeon", "Raid")  
---@param instance number The instance ID
---@return boolean True if specialization needs to be changed
function addon:createSpecializationFrame(parent, instanceType, instance)
    local dbLoadouts = self.db.char.loadouts
    local change = false
    
    local container = AF.CreateTitledPane(parent, "Specialization", parent:GetWidth() - 10, 40)
    AF.SetPoint(container, "TOPLEFT", 5, -60)
    
    if next(self.externalInfo.Specialization) then
        local currentSpec = GetSpecialization()
        local specializationSet = dbLoadouts[instanceType][instance].Specialization
        local overrideSpecializationSet = dbLoadouts[instanceType][instance]["Override Default Specialization"]
        if not overrideSpecializationSet then
            specializationSet = dbLoadouts[instanceType][-1].Specialization
        end
        if specializationSet == -1 then
            local label = AF.CreateFontString(container, "Specialization not set", "gray")
            AF.SetPoint(label, "TOPLEFT", 0, -25)
        elseif specializationSet ~= currentSpec then
            change = true
            local _, name = GetSpecializationInfo(specializationSet)
            local button = AF.CreateButton(container, "Change Specialization to " .. name, "static", parent:GetWidth() - 10, 25)
            AF.SetPoint(button, "TOPLEFT", 0, -25)
            button:SetTextHighlightColor(addonName)
            button:SetBorderHighlightColor(addonName)
            button:SetOnClick(function()
                button:SetEnabled(false)
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
                    button:SetEnabled(true)
                    addon:UnregisterEvent("ACTIVE_PLAYER_SPECIALIZATION_CHANGED")
                    addon:UnregisterEvent("SPECIALIZATION_CHANGE_CAST_FAILED")
                end)
            end)
        else
            local _, name = GetSpecializationInfo(currentSpec)
            local label = AF.CreateFontString(container, "Current Specialization is " .. name, "white")
            AF.SetPoint(label, "TOPLEFT", 0, -25)
        end
    else
        local label = AF.CreateFontString(container, "No Specialization Manager Found", "gray")
        AF.SetPoint(label, "TOPLEFT", 0, -25)
    end
    
    return change
end

---Creates the reminder GUI for Talents
---@param parent Frame The parent frame to add elements to
---@param instanceType string The instance type
---@param instance number The instance ID 
---@return boolean True if talents need to be changed
function addon:createTalentsFrame(parent, instanceType, instance)
    local dbLoadouts = self.db.char.loadouts
    local change = false
    
    local container = AF.CreateTitledPane(parent, "Talents", parent:GetWidth() - 10, 40)
    AF.SetPoint(container, "TOPLEFT", 5, -115)
    
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
            local label = AF.CreateFontString(container, "Talents not set", "gray")
            AF.SetPoint(label, "TOPLEFT", 0, -25)
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
                    local button = AF.CreateButton(container, "Change Talents to " .. name, "static", parent:GetWidth() - 10, 25)
                    AF.SetPoint(button, "TOPLEFT", 0, -25)
                    button:SetTextHighlightColor(addonName)
                    button:SetBorderHighlightColor(addonName)
                    button:SetOnClick(function()
                        if talentManager then
                            self.manager.loadTalentLoadout(talentSet, true)
                            button:SetEnabled(false)
                            addon:RegisterEvent("TRAIT_CONFIG_UPDATED", function()
                                for _, child in ipairs({container:GetChildren()}) do
                                    child:Hide()
                                end
                                
                                local label = AF.CreateFontString(container, "Current Talents are " .. name, "white")
                                AF.SetPoint(label, "TOPLEFT", 10, -25)
                                
                                addon:UnregisterEvent("TRAIT_CONFIG_UPDATED")
                                addon:UnregisterEvent("CONFIG_COMMIT_FAILED")
                            end)
                            addon:RegisterEvent("CONFIG_COMMIT_FAILED", function()
                                button:SetEnabled(true)
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
                                for _, child in ipairs({container:GetChildren()}) do
                                    child:Hide()
                                end
                                
                                local label = AF.CreateFontString(container, "Current Talents are " .. name, "white")
                                AF.SetPoint(label, "TOPLEFT", 0, -25)
                            elseif result == 2 then
                                button:SetEnabled(false)
                                addon:RegisterEvent("TRAIT_CONFIG_UPDATED", function()
                                    if specializationSet == GetSpecialization() then
                                        C_ClassTalents.UpdateLastSelectedSavedConfigID(specID, talentSet)
                                        for _, child in ipairs({container:GetChildren()}) do
                                            child:Hide()
                                        end
                                        
                                        local label = AF.CreateFontString(container, "Current Talents are " .. name, "white")
                                        AF.SetPoint(label, "TOPLEFT", 0, -25)

                                        addon:UnregisterEvent("TRAIT_CONFIG_UPDATED")
                                        addon:UnregisterEvent("CONFIG_COMMIT_FAILED")
                                    end
                                end)
                                addon:RegisterEvent("CONFIG_COMMIT_FAILED", function()
                                    button:SetEnabled(true)
                                    addon:UnregisterEvent("TRAIT_CONFIG_UPDATED")
                                    addon:UnregisterEvent("CONFIG_COMMIT_FAILED")
                                end)
                            end
                        end
                    end)
                else
                    local name = self.externalInfo.Talents[talentSet]
                    local label = AF.CreateFontString(container, "Current Talents are " .. name, "white")
                    AF.SetPoint(label, "TOPLEFT", 0, -25)
                end
            else
                local label = AF.CreateFontString(container, "Change Specialization", "orange")
                AF.SetPoint(label, "TOPLEFT", 0, -25)
            end
        end
    else
        local label = AF.CreateFontString(container, "No Talents Manager Found", "gray")
        AF.SetPoint(label, "TOPLEFT", 0, -25)
    end
    return change
end

---Creates the reminder GUI for Gearsets
---@param parent Frame The parent frame to add elements to
---@param instanceType string The instance type
---@param instance number The instance ID
---@return boolean True if gearset needs to be changed
function addon:createGearsetFrame(parent, instanceType, instance)
    local dbLoadouts = self.db.char.loadouts
    local change = false
    
    local container = AF.CreateTitledPane(parent, "Gearset", parent:GetWidth() - 10, 40)
    AF.SetPoint(container, "TOPLEFT", 5, -5)
    
    if next(self.externalInfo.Gearset) then
        local gearSet = dbLoadouts[instanceType][instance].Gearset
        local overrideGearSet = dbLoadouts[instanceType][instance]["Override Default Gearset"]
        if gearSet == -1 or not overrideGearSet then
            gearSet = dbLoadouts[instanceType][-1].Gearset
        end
        if gearSet == -1 then
            local label = AF.CreateFontString(container, "Gearset not set", "gray")
            AF.SetPoint(label, "TOPLEFT", 0, -25)
        else
            local name, _, _, isEquipped = C_EquipmentSet.GetEquipmentSetInfo(gearSet)
            if name and not isEquipped then
                change = true
                local button = AF.CreateButton(container, "Change Gearset to " .. name, "static", parent:GetWidth() - 10, 25)
                AF.SetPoint(button, "TOPLEFT", 0, -25)
                button:SetTextHighlightColor(addonName)
                button:SetBorderHighlightColor(addonName)
                button:SetOnClick(function()
                    C_EquipmentSet.UseEquipmentSet(gearSet)
                    for _, child in ipairs({container:GetChildren()}) do
                        child:Hide()
                    end
                    
                    local label = AF.CreateFontString(container, "Current Gearset is " .. name, "white")
                    AF.SetPoint(label, "TOPLEFT", 0, -25)
                end)
            elseif isEquipped then
                local label = AF.CreateFontString(container, "Current Gearset is " .. name, "white")
                AF.SetPoint(label, "TOPLEFT", 0, -25)
            end
        end
    else
        local label = AF.CreateFontString(container, "No Gearset Manager Found", "gray")
        AF.SetPoint(label, "TOPLEFT", 0, -25)
    end
    return change
end

---Creates the reminder GUI for Addons
---@param parent Frame The parent frame to add elements to
---@param instanceType string The instance type
---@param instance number The instance ID
---@return boolean True if addons need to be changed 
function addon:createAddonsFrame(parent, instanceType, instance)
    local dbLoadouts = self.db.char.loadouts
    local change = false
    
    local container = AF.CreateTitledPane(parent, "AddOns", parent:GetWidth() - 10, 40)
    AF.SetPoint(container, "TOPLEFT", 5, -170)
    
    if next(self.externalInfo.Addons) then
        local addonSet = dbLoadouts[instanceType][instance].Addons
        local overrideAddonSet = dbLoadouts[instanceType][instance]["Override Default Gearset"]
        if addonSet == -1 or not overrideAddonSet then
            addonSet = dbLoadouts[instanceType][-1].Addons
        end
        if addonSet == -1 then
            local label = AF.CreateFontString(container, "AddOns not set", "gray")
            AF.SetPoint(label, "TOPLEFT", 0, -25)
        else
            local name = self.manager:getAddonSetName(addonSet)
            local isSetActive = self.manager:isActiveAddonSet(addonSet)
            if not isSetActive then
                change = true
                local button = AF.CreateButton(container, "Change AddOns to " .. name, "static", parent:GetWidth() - 10, 25)
                AF.SetPoint(button, "TOPLEFT", 0, -25)
                button:SetTextHighlightColor(addonName)
                button:SetBorderHighlightColor(addonName)
                button:SetScript("OnClick", function()
                    local text = AF.WrapTextInColor("Reload UI now?", "firebrick")
                    local dialog = AF.GetDialog(parent:GetParent(), text, 200)
                    AF.SetPoint(dialog, "CENTER", 0, 0)
                    dialog:SetOnConfirm(function()
                        addon.manager:loadAddons(addonSet)
                    end)
                end)
            else
                local label = AF.CreateFontString(container, "Current AddOns are " .. name, "white")
                AF.SetPoint(label, "TOPLEFT", 0, -25)
            end
        end
    else
        local label = AF.CreateFontString(container, "No AddOns Manager Found", "gray")
        AF.SetPoint(label, "TOPLEFT", 0, -25)
    end
    return change
end

---Shows the reminder window for a specific instance
---@param instanceType string The instance type
---@param instance number The instance ID
function addon:showLoadoutForInstance(instanceType, instance)
    local dbLoadouts = self.db.char.loadouts
    if not dbLoadouts[instanceType] or not dbLoadouts[instanceType][instance] then
        if self.frame then
            self.frame:Hide()
            self.frame = nil
        end
        return
    end
    
    local frame = self.frame
    if self.frame and self.frameType == "Reminder" then
        for _, child in ipairs({self.frame:GetChildren()}) do
            child:Hide()
        end
    else
        if self.frame then
            self.frame:Hide()
            self.frame = nil
        end
        self.frameType = "Reminder"
        frame = AF.CreateHeaderedFrame(AF.UIParent, "InstanceLoadouts_Reminder",
            addonName, 400, 260)
        AF.SetPoint(frame, "CENTER")
        frame:SetTitleColor("white")

        local optionsButton = AF.CreateButton(frame.header, "", addonName, 20, 20)
        AF.ApplyDefaultBackdropWithColors(optionsButton, "header")
        AF.SetPoint(optionsButton, "TOPRIGHT", -19, 0)

        optionsButton:SetTexture("OptionsIcon-Brown", {14, 14}, {"CENTER", 0, 0}, true)
        optionsButton:SetFrameLevel(frame:GetFrameLevel() + 10)
        optionsButton:SetOnClick(function()
            local encounter = instance
            if strfind(instanceType, "Encounter") then
                local instanceStr = strsplit(" ", instanceType)
                instance = tonumber(instanceStr)
                instanceType = "Raid"
            elseif instanceType == "Dungeon" then
                for _, tierInfo in ipairs(addon.instanceGroups.Dungeon) do
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
            
            if addon.frame then
                addon.frame:Hide()
                addon.frame = nil
            end
            addon.ConfigView.instanceType = instanceType
            addon.ConfigView.instance = instance
            addon.ConfigView.encounter = encounter
            addon:openConfig()
        end)
        
        frame:SetScript("OnHide", function()
            self.frame = nil
        end)

        _G["InstanceLoadouts_Reminder"] = frame
        table.insert(UISpecialFrames, "InstanceLoadouts_Reminder")
    end
    
    local header = AF.CreateFontString(frame, self.ConvertIDToName[instance], "white", "IL_HEADER_FONT")
    AF.SetPoint(header, "TOP", 0, -5)

    local box = AF.CreateBorderedFrame(frame, nil, frame:GetWidth() - 10, frame:GetHeight() - 35, "background2", "black")
    AF.SetPoint(box, "TOPLEFT", 5, -30)
    
    local gearsetChange = self:createGearsetFrame(box, instanceType, instance)
    local specializationChange = self:createSpecializationFrame(box, instanceType, instance)
    local talentsChange = self:createTalentsFrame(box, instanceType, instance)
    local addonsChange = self:createAddonsFrame(box, instanceType, instance)

    self.frame = frame

    if not specializationChange and not talentsChange and not gearsetChange and not addonsChange then
        if self.frame then
            self.frame:Hide()
            self.frame = nil
        end
    else
        frame:Show()
    end
end

--Checks the current unit if within target timeout to avoid multiple popups
---@param unit string The unit to check (e.g. "target")
---@return boolean True if within timeout
function addon:checkUnitTimeout(unit)
    local guid = UnitGUID(unit)
    if not guid then return false end
    
    local timeout = self.db.global.targetTimeout
    local currentTime = GetTime()
    if not self.lastTargetTime then
        self.lastTargetTime = {}
    end
    
    if self.lastTargetTime[guid] and (currentTime - self.lastTargetTime[guid]) < timeout then
        return true
    end
    
    self.lastTargetTime[guid] = currentTime
    return false
end

---Checks if target is a tracked raid boss
---@param instanceID number The instance ID to check
---@param encounterIDs table The encounter IDs to check against
function addon:checkIfTrackedTarget(instanceID, encounterIDs)
    if InCombatLockdown() then return end
    local dbLoadouts = self.db.char.loadouts
    if not encounterIDs then
        return
    end
    local guid = UnitGUID("target")
    if guid and not UnitIsDead("target") then
        if self:checkUnitTimeout("target") then return end

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