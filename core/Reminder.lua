local addonName, addon = ...

local C = addon.Components

local isGarrison = {
    1152, -- Horde Garrison lvl 1
    1330, -- Horde Garrison lvl 2
    1153, -- Horde Garrison lvl 3
    1158, -- Alliance Garrison lvl 1
    1331, -- Alliance Garrison lvl 2
    1159, -- Alliance Garrison lvl 3
}

---Creates a reminder section card showing either a status line or an action button
---@param scroller table The scroll content to add the card to
---@param title string The card title
---@return table card The card with SetStatus/SetAction methods
local function CreateSection(scroller, title)
    local card = C:CreateCard(scroller, title)

    local row = CreateFrame("Frame", nil, card)
    row:SetHeight(24)

    local status = row:CreateFontString(nil, "OVERLAY")
    C.ApplyFont(status, "normal")
    status:SetPoint("LEFT", row, "LEFT", 0, 0)
    status:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    status:SetJustifyH("LEFT")
    status:Hide()

    local button = C:CreateButton(row, "", {height = 24})
    button:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    button:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
    button:Hide()
    card.button = button

    card:AddWidget(row, nil, 24)
    scroller:AddCard(card)

    function card:SetStatus(text, value, color)
        button:Hide()
        local theme = addon.Theme
        local c = color or theme.text.primary
        if value then
            status:SetText(text .. " " .. theme.accent:WrapTextInColorCode(value))
            status:SetTextColor(c.r, c.g, c.b, 1)
        else
            status:SetTextColor(c.r, c.g, c.b, 1)
            status:SetText(text)
        end
        status:Show()
    end

    function card:SetAction(text, onClick)
        status:Hide()
        button:SetLabel(text)
        button:SetCallback(onClick)
        button:Show()
    end

    return card
end

---Creates the reminder GUI for Specializations
---@param parent table The scroll content to add elements to
---@param instanceType string The instance type (e.g. "Dungeon", "Raid")
---@param instance number The instance ID
---@return boolean True if specialization needs to be changed
function addon:createSpecializationFrame(parent, instanceType, instance)
    local dbLoadouts = self.db.char.loadouts
    local change = false
    local theme = self.Theme

    local section = CreateSection(parent, "Specialization")

    if next(self.externalInfo.Specialization) then
        local currentSpec = GetSpecialization()
        local specializationSet = dbLoadouts[instanceType][instance].Specialization
        local overrideSpecializationSet = dbLoadouts[instanceType][instance]["Override Default Specialization"]
        if not overrideSpecializationSet then
            specializationSet = dbLoadouts[instanceType][-1].Specialization
        end
        if specializationSet == -1 then
            section:SetStatus("Specialization not set", nil, theme.text.muted)
        elseif specializationSet ~= currentSpec then
            change = true
            local _, name = GetSpecializationInfo(specializationSet)
            section:SetAction("Change Specialization to " .. name, function()
                section.button:SetEnabled(false)
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
                    section.button:SetEnabled(true)
                    addon:UnregisterEvent("ACTIVE_PLAYER_SPECIALIZATION_CHANGED")
                    addon:UnregisterEvent("SPECIALIZATION_CHANGE_CAST_FAILED")
                end)
            end)
        else
            local _, name = GetSpecializationInfo(currentSpec)
            section:SetStatus("Current Specialization is", name)
        end
    else
        section:SetStatus("No Specialization Manager Found", nil, theme.text.muted)
    end

    return change
end

---Creates the reminder GUI for Talents
---@param parent table The scroll content to add elements to
---@param instanceType string The instance type
---@param instance number The instance ID
---@return boolean True if talents need to be changed
function addon:createTalentsFrame(parent, instanceType, instance)
    local dbLoadouts = self.db.char.loadouts
    local change = false
    local theme = self.Theme

    local section = CreateSection(parent, "Talents")

    if next(self.externalInfo.Talents) then
        local specializationSet = dbLoadouts[instanceType][instance].Specialization
        local overrideSpecializationSet = dbLoadouts[instanceType][instance]["Override Default Specialization"]
        local talentSet = dbLoadouts[instanceType][instance].Talents
        local overrideTalentSet = dbLoadouts[instanceType][instance]["Override Default Talents"]
        if not overrideSpecializationSet then
            specializationSet = dbLoadouts[instanceType][-1].Specialization
        end
        if not overrideTalentSet then
            talentSet = dbLoadouts[instanceType][-1].Talents
        end

        if talentSet == -1 then
            section:SetStatus("Talents not set", nil, theme.text.muted)
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
                    section:SetAction("Change Talents to " .. name, function()
                        if talentManager then
                            self.manager.loadTalentLoadout(talentSet, true)
                            section.button:SetEnabled(false)
                            addon:RegisterEvent("TRAIT_CONFIG_UPDATED", function()
                                section:SetStatus("Current Talents are", name)
                                addon:UnregisterEvent("TRAIT_CONFIG_UPDATED")
                                addon:UnregisterEvent("CONFIG_COMMIT_FAILED")
                            end)
                            addon:RegisterEvent("CONFIG_COMMIT_FAILED", function()
                                section.button:SetEnabled(true)
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
                                section:SetStatus("Current Talents are", name)
                            elseif result == 2 then
                                section.button:SetEnabled(false)
                                addon:RegisterEvent("TRAIT_CONFIG_UPDATED", function()
                                    if specializationSet == GetSpecialization() then
                                        C_ClassTalents.UpdateLastSelectedSavedConfigID(specID, talentSet)
                                        section:SetStatus("Current Talents are", name)
                                        addon:UnregisterEvent("TRAIT_CONFIG_UPDATED")
                                        addon:UnregisterEvent("CONFIG_COMMIT_FAILED")
                                    end
                                end)
                                addon:RegisterEvent("CONFIG_COMMIT_FAILED", function()
                                    section.button:SetEnabled(true)
                                    addon:UnregisterEvent("TRAIT_CONFIG_UPDATED")
                                    addon:UnregisterEvent("CONFIG_COMMIT_FAILED")
                                end)
                            end
                        end
                    end)
                else
                    local name = self.externalInfo.Talents[talentSet]
                    section:SetStatus("Current Talents are", name)
                end
            else
                section:SetStatus("Change Specialization", nil, theme.orange)
            end
        end
    else
        section:SetStatus("No Talents Manager Found", nil, theme.text.muted)
    end

    return change
end

---Creates the reminder GUI for Gearsets
---@param parent table The scroll content to add elements to
---@param instanceType string The instance type
---@param instance number The instance ID
---@return boolean True if gearset needs to be changed
function addon:createGearsetFrame(parent, instanceType, instance)
    local dbLoadouts = self.db.char.loadouts
    local change = false
    local theme = self.Theme

    local section = CreateSection(parent, "Gearset")

    if next(self.externalInfo.Gearset) then
        local gearSet = dbLoadouts[instanceType][instance].Gearset
        local overrideGearSet = dbLoadouts[instanceType][instance]["Override Default Gearset"]
        if gearSet == -1 or not overrideGearSet then
            gearSet = dbLoadouts[instanceType][-1].Gearset
        end
        if gearSet == -1 then
            section:SetStatus("Gearset not set", nil, theme.text.muted)
        else
            local name, _, _, isEquipped = C_EquipmentSet.GetEquipmentSetInfo(gearSet)
            if name and not isEquipped then
                change = true
                section:SetAction("Change Gearset to " .. name, function()
                    C_EquipmentSet.UseEquipmentSet(gearSet)
                    section:SetStatus("Current Gearset is", name)
                end)
            elseif isEquipped then
                section:SetStatus("Current Gearset is", name)
            end
        end
    else
        section:SetStatus("No Gearset Manager Found", nil, theme.text.muted)
    end

    return change
end

---Creates the reminder GUI for Addons
---@param parent table The scroll content to add elements to
---@param instanceType string The instance type
---@param instance number The instance ID
---@return boolean True if addons need to be changed
function addon:createAddonsFrame(parent, instanceType, instance)
    local dbLoadouts = self.db.char.loadouts
    local change = false
    local theme = self.Theme

    local section = CreateSection(parent, "AddOns")

    if next(self.externalInfo.Addons) then
        local addonSet = dbLoadouts[instanceType][instance].Addons
        local overrideAddonSet = dbLoadouts[instanceType][instance]["Override Default Gearset"]
        if addonSet == -1 or not overrideAddonSet then
            addonSet = dbLoadouts[instanceType][-1].Addons
        end
        if addonSet == -1 then
            section:SetStatus("AddOns not set", nil, theme.text.muted)
        else
            local name = self.manager:getAddonSetName(addonSet)
            local isSetActive = self.manager:isActiveAddonSet(addonSet)
            if not isSetActive then
                change = true
                section:SetAction("Change AddOns to " .. name, function()
                    C.ShowConfirm(theme.error:WrapTextInColorCode("Reload UI now?"), function()
                        addon.manager:loadAddons(addonSet)
                    end, nil, 260, addon.frame)
                end)
            else
                section:SetStatus("Current AddOns are", name)
            end
        end
    else
        section:SetStatus("No AddOns Manager Found", nil, theme.text.muted)
    end

    return change
end

---Shows the reminder window for a specific instance
---@param instanceType string The instance type
---@param instance number The instance ID
---@param forceShow boolean|nil Show the window even if nothing needs changing (debug)
function addon:showLoadoutForInstance(instanceType, instance, forceShow)
    local dbLoadouts = self.db.char.loadouts
    if not dbLoadouts[instanceType] or not dbLoadouts[instanceType][instance] then
        if forceShow then
            self:Print("No loadout configured for " .. tostring(self.ConvertIDToName[instance] or instance))
        end
        if self.frame then
            self.frame:Hide()
        end
        return
    end

    local win, content = self.UI.AcquireWindow("Reminder", {
        width = 425,
        height = "auto",
        icon = addon.icon,
        title = "",
        pageTitle = (function()
            if strfind(instanceType, "Encounter") then
                local idStr = strsplit(" ", instanceType)
                local id = tonumber(idStr)
                return self.ConvertIDToName[id]
            end
            if instanceType == "Open World" then return "Open World" end
            return self.ConvertIDToName[instance]
        end)(),
        onGear = function()
            local encounter = instance
            local configInstanceType = instanceType
            local configInstance = instance
            if strfind(configInstanceType, "Encounter") then
                local instanceStr = strsplit(" ", configInstanceType)
                configInstance = tonumber(instanceStr)
                configInstanceType = "Raid"
            elseif configInstanceType == "Dungeon" then
                for _, tierInfo in ipairs(addon.instanceGroups.Dungeon) do
                    if tierInfo.instanceIDs then
                        for _, instanceInfo in ipairs(tierInfo.instanceIDs) do
                            if instanceInfo.instanceID and instanceInfo.instanceID == configInstance then
                                configInstance = tierInfo.tierID
                                break
                            end
                        end
                    end
                    if configInstance ~= encounter then
                        break
                    end
                end
            end

            addon.ConfigView.instanceType = configInstanceType
            addon.ConfigView.instance = configInstance
            addon.ConfigView.encounter = encounter
            addon:openConfig()
        end,
    })

    local scroller = C:CreateTabScroller(content)

    local gearsetChange = self:createGearsetFrame(scroller, instanceType, instance)
    local specializationChange = self:createSpecializationFrame(scroller, instanceType, instance)
    local talentsChange = self:createTalentsFrame(scroller, instanceType, instance)
    local addonsChange = self:createAddonsFrame(scroller, instanceType, instance)

    scroller:Commit(nil, win.FitToContent)

    if not specializationChange and not talentsChange and not gearsetChange and not addonsChange and not forceShow then
        win:Hide()
    end
end

---Checks if current instance is tracked and shows reminder if needed
---@param forceShow boolean|nil Show the reminder even if nothing needs changing (debug)
function addon:checkIfIsTrackedInstance(forceShow)
    local dbLoadouts = self.db.char.loadouts
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
        self:showLoadoutForInstance(instance, encounter, forceShow)
    elseif forceShow then
        self:Print("Current instance is not tracked" .. (instance and (" (" .. instance .. ")") or ""))
    end
end
