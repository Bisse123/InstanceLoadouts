local addonName, addon = ...

local AF = _G.AbstractFramework

local LibSerialize = LibStub("LibSerialize")
local LibDeflate = LibStub("LibDeflate")

local importQueue = {}

---Shows missing manager warnings if required managers aren't present
---@param managerType string The type of manager to check for ("Addon" or "Talent")
---@return boolean|nil missingManager True if managers are missing, nil otherwise
function addon:showMissingManagers(managerType)
    if not managerType then
        return
    end
    local addonManager = self.manager:getAddonManager()
    if addonManager == "BetterAddonList" or addonManager == "SimpleAddonManager" then
        addonManager = nil
    end
    local talentManager = self.manager:getTalentManager()
    local isAddonManager = string.find(managerType, "Addon")
    local isTalentManager = string.find(managerType, "Talent")
    
    if isAddonManager and addonManager and isTalentManager and talentManager then
        return
    elseif isAddonManager and addonManager and not isTalentManager then
        return
    elseif isTalentManager and talentManager and not isAddonManager then
        return
    end

    local message = AF.WrapTextInColor("Missing Required Managers", "firebrick") .. "\n\n"
    
    if isAddonManager and not addonManager then
        message = message .. AF.WrapTextInColor("Missing Addon Manager", "orange") .. "\n"
        message = message .. "Supported Addon Managers:\n"
        message = message .. "• Addon Control Panel\n"
        message = message .. "• Better Addon List " .. AF.WrapTextInColor("(Does not support Import/Export)", "gray") .. "\n"
        message = message .. "• Simple Addon Manager " .. AF.WrapTextInColor("(Does not support Import/Export)", "gray") .. "\n\n"
    end
    
    if isTalentManager and not talentManager then
        message = message .. AF.WrapTextInColor("Missing Talent Manager", "orange") .. "\n"
        message = message .. "Supported Talent Managers:\n"
        message = message .. "• Talent Loadout Manager\n\n"
    end
    
    message = message .. AF.WrapTextInColor("Please install the required manager addons to use Import/Export functionality.", "yellow")

    -- Show dialog with the current frame as parent
    local parentFrame = self.frame or UIParent
    local dialog = AF.GetMessageDialog(parentFrame, message, 350)
    AF.SetPoint(dialog, "CENTER", parentFrame, "CENTER", 0, 0)
    
    return true
end

---Validates an import string format
---@param payload string The import string to validate
---@return string|nil importType The type of import if valid
---@return table|nil loadouts The loadouts table if valid
---@return table|nil loadoutInfo Additional import info if valid
function addon:isValidImportString(payload)
	local decoded = LibDeflate:DecodeForPrint(payload)
    if not decoded then
		return
	end
    local decompressed = LibDeflate:DecompressDeflate(decoded)
    if not decompressed then
		return
	end
	local success, data = LibSerialize:Deserialize(decompressed)
	if not success then
		return
	end
    local importTypes = {
        ["Addon and Talent"] = true,
        ["Addon"] = true,
        ["Talent"] = true
    }
    local importType, loadouts, loadoutInfo = unpack(data)
    if not importTypes[importType] then
        return
    end
    return importType, loadouts, loadoutInfo
end

---Checks for missing addons in an addon set
---@param addonSet table The addon set to check
---@param ProtectedAddons table Protected addons to check
---@return table|nil Table of missing addon names or nil if none missing
function addon:checkMissingAddonsInAddonSet(addonSet, ProtectedAddons)
    local missingAddons = {}
    local isMissingAddon = false
    for ProtectedAddonName, _ in pairs(ProtectedAddons) do
        local _, reason = C_AddOns.IsAddOnLoadable(ProtectedAddonName)
        if reason == "MISSING" then
            isMissingAddon = true
            missingAddons[ProtectedAddonName] = true
        end
    end
    for idx, idxAddonName in pairs(addonSet) do
        if idx ~= "name"  then
            local _, reason = C_AddOns.IsAddOnLoadable(idxAddonName)
            if reason == "MISSING" then
                isMissingAddon = true
                missingAddons[idxAddonName] = true
            end
        end
    end
    return isMissingAddon and missingAddons or nil
end

---Updates loadout references after renaming
---@param loadouts table The loadouts to update
---@param oldName string The old loadout name
---@param newName string The new loadout name
---@return table The updated loadouts
function addon:updateLoadoutName(loadouts, oldName, newName)
    for _, encounters in pairs(loadouts) do
        for _, configTable in pairs(encounters) do
            if configTable.Addons == oldName then
                configTable.Addons = newName
            end
            if configTable.Talents == oldName then
                configTable.Talents = newName
            end
        end
    end
    return loadouts
end

---Imports journal IDs from import data
---@param journalIDs table The journal IDs to import
function addon:importJournalIDs(journalIDs)
    local journalIDsDB = self.db.global.journalIDs
    for instanceType, journalInstanceIDs in pairs(journalIDs) do
        if not journalIDsDB[instanceType] then
            journalIDsDB[instanceType] = journalInstanceIDs
        else
            for journalInstanceID, journalEncounterIDs in pairs(journalInstanceIDs) do
                if not journalIDsDB[instanceType][journalInstanceID] then
                    journalIDsDB[instanceType][journalInstanceID] = journalEncounterIDs
                else
                    for journalEncounterID, npcIDs in ipairs(journalEncounterIDs) do
                        if not journalIDsDB[instanceType][journalInstanceID][journalEncounterID] then
                            journalIDsDB[instanceType][journalInstanceID][journalEncounterID] = npcIDs
                        elseif type(npcIDs) == "table" then
                            tinsert(journalIDsDB[instanceType][journalInstanceID][journalEncounterID], npcIDs)
                        end
                    end
                end
            end
        end
    end
    self:getCustomEncounterJournals()
end

---Imports addon loadouts
---@param loadouts table The loadouts to import
---@param loadoutInfo table Additional import info
---@param partialImport boolean Whether this is a partial import
function addon:importAddons(loadouts, loadoutInfo, partialImport)
    local addonNameToSetID = {}
    self.manager:setProtectedAddons(loadoutInfo.ProtectedAddons)
    for setAddonName, addonSet in pairs(loadoutInfo.Addons) do
        local firstEmptySet
        for set = 1, 25 do
            local addonManagerSet = self.manager.getAddonManagerSet(set)
            if not firstEmptySet and (not addonManagerSet or next(addonManagerSet)) == "name" then
                firstEmptySet = set
            end
            local setName = addon.manager:getAddonSetName(set)
            if setName == setAddonName then
                self.manager.setAddonManagerSet(set, addonSet)
                addonNameToSetID[setAddonName] = set
                break
            end
        end
        if firstEmptySet and not addonNameToSetID[setAddonName] then
            self.manager.setAddonManagerSet(firstEmptySet, addonSet)
            addonNameToSetID[setAddonName] = firstEmptySet
        end
    end
    if not partialImport then
        for instance, encounters in pairs(self.db.char.loadouts) do
            for encounter, _ in pairs(encounters) do
                self.db.char.loadouts[instance][encounter].Addons = -1
                if encounter ~= "Default" then
                    self.db.char.loadouts[instance][encounter]["Override Default Addons"] = false
                end
            end
        end
    end
    for instance, encounters in pairs(loadouts) do
        for encounter, configTable in pairs(encounters) do
            if addonNameToSetID[configTable.Addons] then
                self.db.char.loadouts[instance][encounter].Addons = addonNameToSetID[configTable.Addons]
            else
                self.db.char.loadouts[instance][encounter].Addons = -1
            end
            if configTable["Override Default Addons"] then
                self.db.char.loadouts[instance][encounter]["Override Default Addons"] = true
            elseif encounter ~= "Default" then
                self.db.char.loadouts[instance][encounter]["Override Default Addons"] = false
            end
        end
    end
    self:checkAddonManager()
end

---Shows the addon import UI
---@param loadouts table The loadouts to import
---@param loadoutInfo table Additional import info
---@param partialImport boolean Whether this is a partial import
function addon:showImportAddons(loadouts, loadoutInfo, partialImport)
    -- Build message for dialog
    local message = AF.WrapTextInColor("Import Addon Sets", "accent") .. "\n\n"
    
    local addonSetCount = 0
    local missingAddonsCount = 0
    local addonSetsList = {}
    
    for setAddonName, addonSet in pairs(loadoutInfo.Addons) do
        addonSetCount = addonSetCount + 1
        table.insert(addonSetsList, "• " .. setAddonName)
        
        local missingAddons = self:checkMissingAddonsInAddonSet(addonSet, loadoutInfo.ProtectedAddons)
        if missingAddons then
            for missingAddonName, _ in pairs(missingAddons) do
                missingAddonsCount = missingAddonsCount + 1
            end
        end
    end
    
    message = message .. "Addon sets to import (" .. addonSetCount .. "):\n"
    message = message .. table.concat(addonSetsList, "\n") .. "\n\n"
    
    if missingAddonsCount > 0 then
        message = message .. AF.WrapTextInColor("Warning: " .. missingAddonsCount .. " missing addons found!", "orange") .. "\n"
        message = message .. AF.WrapTextInColor("Missing addons will be removed from imported sets.", "gray") .. "\n\n"
    end
    
    message = message .. AF.WrapTextInColor("Import these addon sets now?", "white")

    -- Show confirmation dialog
    local parentFrame = self.frame or UIParent
    local dialog = AF.GetDialog(parentFrame, message, 350)
    AF.SetPoint(dialog, "CENTER", UIParent, "CENTER", 0, 0)
    dialog:SetOnConfirm(function()
        addon:importAddons(loadouts, loadoutInfo, partialImport)
        addon:getNextImport()
    end)
    dialog:SetOnCancel(function()
        addon:getNextImport()
    end)
end

---Imports talent loadouts
---@param loadouts table The loadouts to import
---@param loadoutInfo table Additional import info
---@param partialImport boolean Whether this is a partial import
function addon:importTalents(loadouts, loadoutInfo, partialImport)
    local talentNameToLoadoutID = {}
    for name, talentInfo in pairs(loadoutInfo.Talents) do
        local classID, specID = talentInfo.classID, talentInfo.specID
        -- local name = talentInfo.name
        local currentLoadouts = self.manager:getTalentLoadouts(specID, classID)
        for _, currentLoadout in pairs(currentLoadouts) do
            if name == currentLoadout.name then
                local updatedLoadout = self.manager.updateTalentLoadout(currentLoadout.id, talentInfo.exportString)
                if updatedLoadout then
                    talentNameToLoadoutID[name] = currentLoadout.id
                end
                break
            end
        end
        if not talentNameToLoadoutID[name] then
            local newLoadout = self.manager.importTalentLoadout(talentInfo.exportString, name)
            if newLoadout then
                talentNameToLoadoutID[name] = newLoadout.id
            end
        end
    end
    if not partialImport then
        for instance, encounters in pairs(self.db.char.loadouts) do
            for encounter, _ in pairs(encounters) do
                self.db.char.loadouts[instance][encounter].Specialization = -1
                if encounter ~= "Default" then
                    self.db.char.loadouts[instance][encounter]["Override Default Specialization"] = false
                end
                self.db.char.loadouts[instance][encounter].Talents = -1
                if encounter ~= "Default" then
                    self.db.char.loadouts[instance][encounter]["Override Default Talents"] = false
                end
            end
        end
    end
    for instance, encounters in pairs(loadouts) do
        for encounter, configTable in pairs(encounters) do
            if talentNameToLoadoutID[configTable.Talents] then
                self.db.char.loadouts[instance][encounter].Specialization = configTable.Specialization
                self.db.char.loadouts[instance][encounter].Talents = talentNameToLoadoutID[configTable.Talents]
            else
                self.db.char.loadouts[instance][encounter].Talents = -1
            end
            if configTable["Override Default Specialization"] then
                self.db.char.loadouts[instance][encounter]["Override Default Specialization"] = true
            elseif encounter ~= "Default" then
                self.db.char.loadouts[instance][encounter]["Override Default Specialization"] = false
            end
            if configTable["Override Default Talents"] then
                self.db.char.loadouts[instance][encounter]["Override Default Talents"] = true
            elseif encounter ~= "Default" then
                self.db.char.loadouts[instance][encounter]["Override Default Talents"] = false
            end
        end
    end
    self:checkTalentManager()
end

---Shows the talent import UI
---@param loadouts table The loadouts to import
---@param loadoutInfo table Additional import info
---@param partialImport boolean Whether this is a partial import
function addon:showImportTalents(loadouts, loadoutInfo, partialImport)
    -- Build message for dialog
    local message = AF.WrapTextInColor("Import Talent Loadouts", "accent") .. "\n\n"
    
    local talentCount = 0
    local talentList = {}
    
    for talentName, talentLoadout in pairs(loadoutInfo.Talents) do
        talentCount = talentCount + 1
        local displayName = talentLoadout.displayName or talentName
        table.insert(talentList, "• " .. displayName)
    end
    
    message = message .. "Talent loadouts to import (" .. talentCount .. "):\n"
    message = message .. table.concat(talentList, "\n") .. "\n\n"
    message = message .. AF.WrapTextInColor("Import these talent loadouts now?", "white")

    -- Show confirmation dialog
    local parentFrame = self.frame or UIParent
    local dialog = AF.GetDialog(parentFrame, message, 350)
    AF.SetPoint(dialog, "CENTER", UIParent, "CENTER", 0, 0)
    dialog:SetOnConfirm(function()
        addon:importTalents(loadouts, loadoutInfo, partialImport)
        addon:getNextImport()
    end)
    dialog:SetOnCancel(function()
        addon:getNextImport()
    end)
end

local importFunctions = {
    ["Addon"] = addon.showImportAddons,
    ["Talent"] = addon.showImportTalents,
}

---Processes the next queued import
function addon:getNextImport()
    if next(importQueue) then
        local nextImport = tremove(importQueue, (next(importQueue)))
        local func = nextImport.func
        local loadouts = nextImport.loadouts
        local loadoutInfo = nextImport.loadoutInfo
        local partialImport = nextImport.partialImport
        importFunctions[func](addon, loadouts, loadoutInfo, partialImport)
    end
end

---Shows the import frame UI
function addon:ShowImportFrame(onCloseCallback)
    local frame = self.frame
    if self.frame and self.frameType == "Import" then
        if self.frame.content then
            self.frame.content:Hide()
            self.frame.content = nil
        end
    else
        if self.frame then
            self.frame:Hide()
            self.frame = nil
        end
        self.frameType = "Import"
        frame = AF.CreateHeaderedFrame(AF.UIParent, "InstanceLoadouts_Import",
            AF.GetIconString("IL", 14, 14, "InstanceLoadouts") .. " " .. addonName, 350, 400)
        AF.SetPoint(frame, "CENTER", UIParent, "CENTER", 0, 0)
        frame:SetTitleColor("white")
        frame:SetFrameLevel(100)
        frame:SetTitleJustify("LEFT")

        local pageName = AF.CreateFontString(frame.header, nil, "white", "AF_FONT_TITLE")
        AF.SetPoint(pageName, "CENTER", frame.header, "CENTER", 0, 0)
        pageName:SetJustifyH("CENTER")
        pageName:SetText(self.frameType)

        local optionsButton = AF.CreateButton(frame.header, "", addonName, 20, 20)
        AF.ApplyDefaultBackdropWithColors(optionsButton, "header")
        AF.SetPoint(optionsButton, "TOPRIGHT", -19, 0)

        optionsButton:SetTexture("OptionsIcon-Brown", {12, 12}, {"CENTER", 0, 0}, true)
        optionsButton:SetFrameLevel(frame:GetFrameLevel() + 10)
        optionsButton:SetOnClick(function()
            self.transitioning = true
            addon:openConfig()
        end)

        frame:SetScript("OnHide", function()
            self.frame = nil
            -- Only call onCloseCallback if we're not transitioning to another window
            if onCloseCallback and not self.transitioning then
                onCloseCallback()
            end
        end)

        _G["InstanceLoadouts_Import"] = frame
        table.insert(UISpecialFrames, "InstanceLoadouts_Import")
        frame:Show()
    end

    local yOffset = -80

    local continueButton = AF.CreateButton(frame, "Invalid Import", "red", 200, 40)
    AF.SetPoint(continueButton, "TOPLEFT", frame, "TOPLEFT", 20, yOffset)
    continueButton:SetEnabled(false)

    local partialImport = AF.CreateCheckButton(frame, "Partial Import", function(checked)
        -- Checkbox callback handled in OnTextChanged
    end)
    AF.SetPoint(partialImport, "TOPLEFT", continueButton, "TOPRIGHT", 20, -5)
    partialImport:SetChecked(false)
    partialImport:SetEnabled(false)
    
    -- Add description for partial import
    local partialImportDesc = AF.CreateFontString(frame, "Only loadouts that are not set to default (-1) (Not set to none) will be imported", "gray", "AF_FONT_SMALL")
    AF.SetPoint(partialImportDesc, "TOPLEFT", partialImport, "BOTTOMLEFT", 20, -2)

    yOffset = yOffset - 70
    local autoAddonImport = AF.CreateCheckButton(frame, "Auto Import Addons", function(checked)
        -- Checkbox callback handled in OnTextChanged
    end)
    AF.SetPoint(autoAddonImport, "TOPLEFT", frame, "TOPLEFT", 20, yOffset)
    autoAddonImport:SetChecked(false)
    autoAddonImport:SetEnabled(false)
    
    -- Add description for auto addon import
    local autoAddonDesc = AF.CreateFontString(frame, "Addon sets will override sets in Addon Control Panel and missing addons will be removed", "gray", "AF_FONT_SMALL")
    AF.SetPoint(autoAddonDesc, "TOPLEFT", autoAddonImport, "BOTTOMLEFT", 20, -2)

    local autoTalentImport = AF.CreateCheckButton(frame, "Auto Import Talents", function(checked)
        -- Checkbox callback handled in OnTextChanged
    end)
    AF.SetPoint(autoTalentImport, "TOPLEFT", frame, "TOPLEFT", 400, yOffset)
    autoTalentImport:SetChecked(false)
    autoTalentImport:SetEnabled(false)
    
    -- Add description for auto talent import
    local autoTalentDesc = AF.CreateFontString(frame, "Talent loadouts will override loadouts in Talent Loadout Manager", "gray", "AF_FONT_SMALL")
    AF.SetPoint(autoTalentDesc, "TOPLEFT", autoTalentImport, "BOTTOMLEFT", 20, -2)

    yOffset = yOffset - 80
    local editboxLabel = AF.CreateFontString(frame, "Import String", "white")
    AF.SetPoint(editboxLabel, "TOPLEFT", frame, "TOPLEFT", 20, yOffset)

    yOffset = yOffset - 25
    local multiEditbox = AF.CreateEditBox(frame, "", 760, 320)
    AF.SetPoint(multiEditbox, "TOPLEFT", frame, "TOPLEFT", 20, yOffset)
    -- Enable multiline behavior
    multiEditbox:SetMultiLine(true)
    multiEditbox:EnableMouse(true)
    multiEditbox:SetAutoFocus(false)
    multiEditbox:SetMaxLetters(0)
    multiEditbox:SetScript("OnTextChanged", function(self)
        local payload = self:GetText()
        local importType, loadouts, loadoutInfo = addon:isValidImportString(payload)
        local missingManagers = addon:showMissingManagers(importType)
        if importType and not missingManagers then
            partialImport:SetChecked(true)
            partialImport:SetEnabled(true)
            local isAddonImport = string.find(importType, "Addon")
            local isTalentImport = string.find(importType, "Talent")

            autoAddonImport:SetChecked(isAddonImport)
            autoAddonImport:SetEnabled(isAddonImport)
            autoTalentImport:SetChecked(isTalentImport)
            autoTalentImport:SetEnabled(isTalentImport)
            continueButton:SetText("Import " .. importType .. " Loadouts")
            continueButton:SetEnabled(true)
            continueButton:SetOnClick(function()
                if loadoutInfo and loadoutInfo.journalIDs then
                    addon:importJournalIDs(loadoutInfo.journalIDs)
                end
                if autoAddonImport:GetChecked() then
                    addon:importAddons(loadouts, {Addons = loadoutInfo.Addons, ProtectedAddons = loadoutInfo.ProtectedAddons}, partialImport:GetChecked())
                elseif isAddonImport then
                    tinsert(importQueue, {func = "Addon", loadouts = loadouts, loadoutInfo = {Addons = loadoutInfo.Addons, ProtectedAddons = loadoutInfo.ProtectedAddons}, partialImport = partialImport:GetChecked()})
                end
                if autoTalentImport:GetChecked() then
                    addon:importTalents(loadouts, {Talents = loadoutInfo.Talents}, partialImport:GetChecked())
                elseif isTalentImport then
                    tinsert(importQueue, {func = "Talent", loadouts = loadouts, loadoutInfo = {Talents = loadoutInfo.Talents}, partialImport = partialImport:GetChecked()})
                end
                frame:Hide()
                addon.frame = nil
                addon:getNextImport()
            end)

            if isTalentImport and loadoutInfo and loadoutInfo.Talents then
                local importedClassName
                local currentClass = addon.db.keys.class
                for _, configInfo in pairs(loadoutInfo.Talents) do
                    local className, classFile = GetClassInfo(configInfo.classID)
                    if currentClass ~= classFile then
                        importedClassName = className
                        break
                    end
                end
                if importedClassName then
                    partialImport:SetChecked(false)
                    partialImport:SetEnabled(false)
                    autoAddonImport:SetChecked(false)
                    autoAddonImport:SetEnabled(false)
                    autoTalentImport:SetChecked(false)
                    autoTalentImport:SetEnabled(false)
                    continueButton:SetText("Can not import Talents for " .. importedClassName)
                    continueButton:SetEnabled(false)
                end
            end
        else
            partialImport:SetChecked(false)
            partialImport:SetEnabled(false)
            autoAddonImport:SetChecked(false)
            autoAddonImport:SetEnabled(false)
            autoTalentImport:SetChecked(false)
            autoTalentImport:SetEnabled(false)
            continueButton:SetText("Invalid Import")
            continueButton:SetEnabled(false)
        end
    end)
    
    self.frame = frame
end

---Toggles the import UI open/closed
---@param onCloseCallback function|nil Optional callback to execute when the window closes
function addon:toggleImport(onCloseCallback)
    if addon.frame and addon.frameType == "Import" then
        addon.frame:Hide()
        addon.frame = nil
    else
        addon:ShowImportFrame(onCloseCallback)
    end
end

---Creates an export string
---@param exportType string The type of export
---@param loadouts table The loadouts to export
---@param loadoutInfo table Additional export info
---@return string The encoded export string
function addon:export(exportType, loadouts, loadoutInfo)
    local data = {exportType, loadouts, loadoutInfo}
    local serialized = LibSerialize:Serialize(data)
    local compressed = LibDeflate:CompressDeflate(serialized)
	local encoded = LibDeflate:EncodeForPrint(compressed)
    return encoded
end

---Exports both addon and talent loadouts
---@return string The export string
function addon:exportAddonsAndTalents()
    if self.manager:getAddonManager() == "BetterAddonList" then
        return
    end
    if not self.manager:getAddonManager() then
        return
    end
    if not self.manager:getTalentManager() then
        return
    end
    
    local loadouts = {}
    local loadoutInfo = {}
    loadoutInfo.Addons = {}
    loadoutInfo.Talents = {}
    loadoutInfo.journalIDs = self.db.global.journalIDs
    if self.manager:getProtectedAddons() then
        loadoutInfo.ProtectedAddons = self.manager:getProtectedAddons()
    end
    for instanceID, encounterIDs in pairs(self.db.char.loadouts) do
        local instanceTable = {}
        local loadoutFound = false
        for encounterID, configTable in pairs(encounterIDs) do
            local encounterTable = {}
            local configFound = false
            if configTable.Addons ~= -1 then
                configFound = true
                local addonSet = addon.manager.getAddonManagerSet(configTable.Addons)
                local setAddonName = addonSet.name
                loadoutInfo.Addons[setAddonName] = addonSet
                encounterTable.Addons = setAddonName
            end
            if configTable["Override Default Addons"] then
                configFound = true
                encounterTable["Override Default Addons"] = true
            end
            if configTable.Specialization ~= -1 then
                configFound = true
                encounterTable.Specialization =  configTable.Specialization
            end
            if configTable["Override Default Specialization"] then
                configFound = true
                encounterTable["Override Default Specialization"] = true
            end
            if configTable.Talents ~= -1 then
                configFound = true
                local talentLoadoutInfo = self.manager:getTalentLoadoutInfoByID(configTable.Talents)
                local exportString = self.manager:getTalentExportString(configTable.Talents)
                loadoutInfo.Talents[talentLoadoutInfo.name] = {classID = talentLoadoutInfo.classID, specID = talentLoadoutInfo.specID, exportString = exportString}
                encounterTable.Talents = talentLoadoutInfo.name
            end
            if configTable["Override Default Talents"] then
                configFound = true
                encounterTable["Override Default Talents"] = true
            end
            if configFound then
                loadoutFound = true
                instanceTable[encounterID] = encounterTable
            end
        end
        if loadoutFound then
            loadouts[instanceID] = instanceTable
        end
    end
    if not next(loadouts) then
        return ""
    end
    return self:export("Addon and Talent", loadouts, loadoutInfo)
end

---Exports addon loadouts only
---@return string The export string 
function addon:exportAddons()
    if self.manager:getAddonManager() == "BetterAddonList" then
        return
    end
    if not self.manager:getAddonManager() then
        return
    end
    
    local loadouts = {}
    local loadoutInfo = {}
    loadoutInfo.Addons = {}
    loadoutInfo.journalIDs = self.db.global.journalIDs
    if self.manager:getProtectedAddons() then
        loadoutInfo.ProtectedAddons = self.manager:getProtectedAddons()
    end
    for instance, encounters in pairs(self.db.char.loadouts) do
        local instanceTable = {}
        local loadoutFound = false
        for encounter, configTable in pairs(encounters) do
            local encounterTable = {}
            local configFound = false
            if configTable.Addons ~= -1 then
                configFound = true
                local addonSet = addon.manager.getAddonManagerSet(configTable.Addons)
                local setAddonName = addonSet.name
                loadoutInfo.Addons[setAddonName] = addonSet
                encounterTable.Addons = setAddonName
            end
            if configTable["Override Default Addons"] then
                configFound = true
                encounterTable["Override Default Addons"] = true
            end
            if configFound then
                loadoutFound = true
                instanceTable[encounter] = encounterTable
            end
        end
        if loadoutFound then
            loadouts[instance] = instanceTable
        end
    end
    if not next(loadouts) then
        return ""
    end
    return self:export("Addon", loadouts, loadoutInfo)
end

---Exports talent loadouts only
---@return string The export string
function addon:ExportTalents()
    if not self.manager:getTalentManager() then
        return
    end
    
    local loadouts = {}
    local loadoutInfo = {}
    loadoutInfo.Talents = {}
    loadoutInfo.journalIDs = self.db.global.journalIDs
    for instance, encounters in pairs(self.db.char.loadouts) do
        local instanceTable = {}
        local loadoutFound = false
        for encounter, configTable in pairs(encounters) do
            local encounterTable = {}
            local configFound = false
            if configTable.Specialization ~= -1 then
                configFound = true
                encounterTable.Specialization =  configTable.Specialization
            end
            if configTable["Override Default Specialization"] then
                configFound = true
                encounterTable["Override Default Specialization"] = true
            end
            if configTable.Talents ~= -1 then
                configFound = true
                local talentLoadoutInfo = self.manager:getTalentLoadoutInfoByID(configTable.Talents)
                local exportString = self.manager:getTalentExportString(configTable.Talents)
                loadoutInfo.Talents[talentLoadoutInfo.name] = {classID = talentLoadoutInfo.classID, specID = talentLoadoutInfo.specID, exportString = exportString}
                encounterTable.Talents = talentLoadoutInfo.name
            end
            if configTable["Override Default Talents"] then
                configFound = true
                encounterTable["Override Default Talents"] = true
            end
            if configFound then
                loadoutFound = true
                instanceTable[encounter] = encounterTable
            end
        end
        if loadoutFound then
            loadouts[instance] = instanceTable
        end
    end
    if not next(loadouts) then
        return ""
    end
    return self:export("Talent", loadouts, loadoutInfo)
end

local exportFunctions = {
    ["Addon and Talent"] = addon.exportAddonsAndTalents,
    ["Addon"] = addon.exportAddons,
    ["Talent"] = addon.ExportTalents,
}

---Shows the export frame UI
function addon:ShowExportFrame(onCloseCallback)
    local frame = self.frame
    if self.frame and self.frameType == "Export" then
        if self.frame.content then
            self.frame.content:Hide()
            self.frame.content = nil
        end
    else
        if self.frame then
            self.frame:Hide()
            self.frame = nil
        end
        self.frameType = "Export"
        frame = AF.CreateHeaderedFrame(AF.UIParent, "InstanceLoadouts_Export",
            AF.GetIconString("IL", 14, 14, "InstanceLoadouts") .. " " .. addonName, 400, 400)
        AF.SetPoint(frame, "CENTER", UIParent, "CENTER", 0, 0)
        frame:SetTitleColor("white")
        frame:SetFrameLevel(100)
        frame:SetTitleJustify("LEFT")

        local pageName = AF.CreateFontString(frame.header, nil, "white", "AF_FONT_TITLE")
        AF.SetPoint(pageName, "CENTER", frame.header, "CENTER", 0, 0)
        pageName:SetJustifyH("CENTER")
        pageName:SetText(self.frameType)

        local optionsButton = AF.CreateButton(frame.header, "", addonName, 20, 20)
        AF.ApplyDefaultBackdropWithColors(optionsButton, "header")
        AF.SetPoint(optionsButton, "TOPRIGHT", -19, 0)

        optionsButton:SetTexture("OptionsIcon-Brown", {12, 12}, {"CENTER", 0, 0}, true)
        optionsButton:SetFrameLevel(frame:GetFrameLevel() + 10)
        optionsButton:SetOnClick(function()
            self.transitioning = true
            addon:openConfig()
        end)

        frame:SetScript("OnHide", function()
            self.frame = nil
            -- Only call onCloseCallback if we're not transitioning to another window
            if onCloseCallback and not self.transitioning then
                onCloseCallback()
            end
        end)

        _G["InstanceLoadouts_Export"] = frame
        table.insert(UISpecialFrames, "InstanceLoadouts_Export")
        frame:Show()
    end

    local exportSettings = AF.CreateBorderedFrame(frame, nil, frame:GetWidth() - 10, 45, "background2", "black")
    AF.SetPoint(exportSettings, "TOPLEFT", 5, -20)
    exportSettings:SetLabel("Export Settings")

    local versionPane = AF.CreateTitledPane(exportSettings, "Export String", exportSettings:GetWidth(), 20)
    AF.SetPoint(versionPane, "TOPLEFT", exportSettings, "BOTTOMLEFT", 0, -5)

    local height = frame:GetHeight() - exportSettings:GetHeight() - versionPane:GetHeight() - exportSettings.label:GetStringHeight() - 5*3
    local multiEditbox = AF.CreateEditBox(versionPane, "", versionPane:GetWidth(), height)
    AF.SetPoint(multiEditbox, "TOPLEFT", versionPane, "BOTTOMLEFT", 0, -5)
    multiEditbox:SetEnabled(false)
    
    local function getExportString(exportType, checkbox)
        if exportType then
            local missingManagers = addon:showMissingManagers(exportType)
            if not missingManagers then
                local exportString = exportFunctions[exportType](addon)
                if exportString == "" then
                    multiEditbox.label:SetText("No Loadouts to Export")
                else
                    multiEditbox.label:SetText("Export Loadouts")
                end
                multiEditbox:SetEnabled(true)
                multiEditbox:SetText(exportString)
                multiEditbox:SetScript("OnTextChanged", function(self)
                    self:SetText(exportString)
                end)
            else
                checkbox:SetChecked(false)
            end
        else
            multiEditbox:SetEnabled(false)
            multiEditbox:SetText("")
            multiEditbox:SetScript("OnTextChanged", function(self)
                self:SetText("")
            end)
        end
    end

    local addonsCheckbox, talentsCheckbox
    
    addonsCheckbox = AF.CreateCheckButton(exportSettings, "Addon Loadouts", function(checked)
        local exportType
        if checked and talentsCheckbox and talentsCheckbox:GetChecked() then
            exportType = "Addon and Talent"
        elseif checked then
            exportType = "Addon"
        elseif talentsCheckbox and talentsCheckbox:GetChecked() then
            exportType = "Talent"
        end
        getExportString(exportType, addonsCheckbox)
    end)
    AF.SetPoint(addonsCheckbox, "TOPLEFT", exportSettings, "TOPLEFT", 5, -5)
    
    talentsCheckbox = AF.CreateCheckButton(exportSettings, "Talent Loadouts", function(checked)
        local exportType
        if checked and addonsCheckbox:GetChecked() then
            exportType = "Addon and Talent"
        elseif checked then
            exportType = "Talent"
        elseif addonsCheckbox:GetChecked() then
            exportType = "Addon"
        end
        getExportString(exportType, talentsCheckbox)
    end)
    AF.SetPoint(talentsCheckbox, "TOPLEFT", addonsCheckbox, "BOTTOMLEFT", 0, -5)
    
    self.frame = frame
end

---Toggles the export UI open/closed
---Toggles the export UI open/closed
---@param onCloseCallback function|nil Optional callback to execute when the window closes
function addon:toggleExport(onCloseCallback)
    if addon.frame and addon.frameType == "Export" then
        addon.frame:Hide()
        addon.frame = nil
    else
        addon:ShowExportFrame(onCloseCallback)
    end
end
