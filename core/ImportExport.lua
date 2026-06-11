local addonName, addon = ...

local C = addon.Components

local LibSerialize = LibStub("LibSerialize")
local LibDeflate = LibStub("LibDeflate")

local importQueue = {}

local function Color(text, color)
    return color:WrapTextInColorCode(text)
end

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

    local theme = self.Theme
    local message = Color("Missing Required Managers", theme.error) .. "\n\n"

    if isAddonManager and not addonManager then
        message = message .. Color("Missing Addon Manager", theme.orange) .. "\n"
        message = message .. "Supported Addon Managers:\n"
        message = message .. "• Addon Control Panel\n"
        message = message .. "• Better Addon List " .. Color("(Does not support Import/Export)", theme.text.muted) .. "\n"
        message = message .. "• Simple Addon Manager " .. Color("(Does not support Import/Export)", theme.text.muted) .. "\n\n"
    end

    if isTalentManager and not talentManager then
        message = message .. Color("Missing Talent Manager", theme.orange) .. "\n"
        message = message .. "Supported Talent Managers:\n"
        message = message .. "• Talent Loadout Manager\n\n"
    end

    message = message .. Color("Please install the required manager addons to use Import/Export functionality.", theme.warning)

    C.ShowConfirm(message, nil, false, 350)

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
        if idx ~= "name" then
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
    local theme = self.Theme
    local message = Color("Import Addon Sets", theme.accent) .. "\n\n"

    local addonSetCount = 0
    local missingAddonsCount = 0
    local addonSetsList = {}

    for setAddonName, addonSet in pairs(loadoutInfo.Addons) do
        addonSetCount = addonSetCount + 1
        table.insert(addonSetsList, "• " .. setAddonName)

        local missingAddons = self:checkMissingAddonsInAddonSet(addonSet, loadoutInfo.ProtectedAddons)
        if missingAddons then
            for _ in pairs(missingAddons) do
                missingAddonsCount = missingAddonsCount + 1
            end
        end
    end

    message = message .. "Addon sets to import (" .. addonSetCount .. "):\n"
    message = message .. table.concat(addonSetsList, "\n") .. "\n\n"

    if missingAddonsCount > 0 then
        message = message .. Color("Warning: " .. missingAddonsCount .. " missing addons found!", theme.orange) .. "\n"
        message = message .. Color("Missing addons will be removed from imported sets.", theme.text.muted) .. "\n\n"
    end

    message = message .. Color("Import these addon sets now?", theme.text.primary)

    C.ShowConfirm(message, function()
        addon:importAddons(loadouts, loadoutInfo, partialImport)
        addon:getNextImport()
    end, function()
        addon:getNextImport()
    end, 350)
end

---Imports talent loadouts
---@param loadouts table The loadouts to import
---@param loadoutInfo table Additional import info
---@param partialImport boolean Whether this is a partial import
function addon:importTalents(loadouts, loadoutInfo, partialImport)
    local talentNameToLoadoutID = {}
    for name, talentInfo in pairs(loadoutInfo.Talents) do
        local classID, specID = talentInfo.classID, talentInfo.specID
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
    local theme = self.Theme
    local message = Color("Import Talent Loadouts", theme.accent) .. "\n\n"

    local talentCount = 0
    local talentList = {}

    for talentName, talentLoadout in pairs(loadoutInfo.Talents) do
        talentCount = talentCount + 1
        local displayName = talentLoadout.displayName or talentName
        table.insert(talentList, "• " .. displayName)
    end

    message = message .. "Talent loadouts to import (" .. talentCount .. "):\n"
    message = message .. table.concat(talentList, "\n") .. "\n\n"
    message = message .. Color("Import these talent loadouts now?", theme.text.primary)

    C.ShowConfirm(message, function()
        addon:importTalents(loadouts, loadoutInfo, partialImport)
        addon:getNextImport()
    end, function()
        addon:getNextImport()
    end, 350)
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
---@param onCloseCallback function|nil Optional callback to execute when the window closes
function addon:ShowImportFrame(onCloseCallback)
    local _, content = self.UI.AcquireWindow("Import", {
        width = 460,
        height = 500,
        icon = addon.icon,
        onGear = function()
            self.transitioning = true
            addon:openConfig()
        end,
        onHide = function()
            if onCloseCallback and not self.transitioning then
                onCloseCallback()
            end
        end,
    })

    local theme = self.Theme
    local scroller = C:CreateTabScroller(content)
    local cardWidth = math.max(220, content:GetWidth() - 24)

    local continueButton

    local settingsCard = C:CreateCard(scroller, "Import Settings")
    settingsCard:SetWidth(cardWidth)

    local partialToggle = C:CreateToggle(settingsCard, "Partial Import", false)
    settingsCard:AddWidget(partialToggle, nil, 28)
    settingsCard:AddLabel("Only loadouts that are not set to default (-1) (Not set to none) will be imported", theme.text.muted)

    local autoAddonToggle = C:CreateToggle(settingsCard, "Auto Import Addons", false)
    settingsCard:AddWidget(autoAddonToggle, nil, 28)
    settingsCard:AddLabel("Addon sets will override sets in Addon Control Panel and missing addons will be removed", theme.text.muted)

    local autoTalentToggle = C:CreateToggle(settingsCard, "Auto Import Talents", false)
    settingsCard:AddWidget(autoTalentToggle, nil, 28)
    settingsCard:AddLabel("Talent loadouts will override loadouts in Talent Loadout Manager", theme.text.muted)

    partialToggle:SetEnabled(false)
    autoAddonToggle:SetEnabled(false)
    autoTalentToggle:SetEnabled(false)

    local function SetTogglesDisabled()
        partialToggle:SetValue(false, true)
        partialToggle:SetEnabled(false)
        autoAddonToggle:SetValue(false, true)
        autoAddonToggle:SetEnabled(false)
        autoTalentToggle:SetValue(false, true)
        autoTalentToggle:SetEnabled(false)
    end

    local importCard = C:CreateCard(scroller, "Import String")
    importCard:SetWidth(cardWidth)

    local textArea = C:CreateTextArea(importCard, "", function(payload)
        local importType, loadouts, loadoutInfo = addon:isValidImportString(payload)
        local missingManagers = addon:showMissingManagers(importType)
        if importType and not missingManagers then
            partialToggle:SetValue(true, true)
            partialToggle:SetEnabled(true)
            local isAddonImport = string.find(importType, "Addon") ~= nil
            local isTalentImport = string.find(importType, "Talent") ~= nil

            autoAddonToggle:SetValue(isAddonImport, true)
            autoAddonToggle:SetEnabled(isAddonImport)
            autoTalentToggle:SetValue(isTalentImport, true)
            autoTalentToggle:SetEnabled(isTalentImport)
            continueButton:SetLabel("Import " .. importType .. " Loadouts")
            continueButton:SetEnabled(true)
            continueButton:SetCallback(function()
                if loadoutInfo and loadoutInfo.journalIDs then
                    addon:importJournalIDs(loadoutInfo.journalIDs)
                end
                if autoAddonToggle:GetValue() then
                    addon:importAddons(loadouts, {Addons = loadoutInfo.Addons, ProtectedAddons = loadoutInfo.ProtectedAddons}, partialToggle:GetValue())
                elseif isAddonImport then
                    tinsert(importQueue, {func = "Addon", loadouts = loadouts, loadoutInfo = {Addons = loadoutInfo.Addons, ProtectedAddons = loadoutInfo.ProtectedAddons}, partialImport = partialToggle:GetValue()})
                end
                if autoTalentToggle:GetValue() then
                    addon:importTalents(loadouts, {Talents = loadoutInfo.Talents}, partialToggle:GetValue())
                elseif isTalentImport then
                    tinsert(importQueue, {func = "Talent", loadouts = loadouts, loadoutInfo = {Talents = loadoutInfo.Talents}, partialImport = partialToggle:GetValue()})
                end
                addon.frame:Hide()
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
                    SetTogglesDisabled()
                    continueButton:SetLabel("Can not import Talents for " .. importedClassName)
                    continueButton:SetEnabled(false)
                end
            end
        else
            SetTogglesDisabled()
            continueButton:SetLabel("Invalid Import")
            continueButton:SetEnabled(false)
        end
    end)
    textArea:SetHeight(120)
    importCard:AddWidget(textArea, nil, 120)

    continueButton = C:CreateButton(scroller, "Invalid Import", {height = 28})
    continueButton:SetEnabled(false)

    scroller:AddCard(importCard)
    scroller:AddCard(settingsCard)
    scroller:AddCard(continueButton)
    scroller:Commit()
end

---Toggles the import UI open/closed
---@param onCloseCallback function|nil Optional callback to execute when the window closes
function addon:toggleImport(onCloseCallback)
    if addon.frame and addon.frameType == "Import" then
        addon.frame:Hide()
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
---@return string|nil The export string
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
                encounterTable.Specialization = configTable.Specialization
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
---@return string|nil The export string
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
---@return string|nil The export string
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
                encounterTable.Specialization = configTable.Specialization
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
---@param onCloseCallback function|nil Optional callback to execute when the window closes
function addon:ShowExportFrame(onCloseCallback)
    local _, content = self.UI.AcquireWindow("Export", {
        width = 440,
        height = 460,
        icon = addon.icon,
        onGear = function()
            self.transitioning = true
            addon:openConfig()
        end,
        onHide = function()
            if onCloseCallback and not self.transitioning then
                onCloseCallback()
            end
        end,
    })

    local scroller = C:CreateTabScroller(content)
    local cardWidth = math.max(220, content:GetWidth() - 24)

    local settingsCard = C:CreateCard(scroller, "Export Settings")
    settingsCard:SetWidth(cardWidth)

    local exportCard = C:CreateCard(scroller, "Export String")
    exportCard:SetWidth(cardWidth)

    local currentExport = ""
    local exportArea
    exportArea = C:CreateTextArea(exportCard, "", function(text, userInput)
        if userInput and text ~= currentExport then
            exportArea:SetValue(currentExport)
        end
    end)
    exportArea:GetEditBox():HookScript("OnEditFocusGained", function(eb)
        eb:HighlightText()
    end)
    exportArea:SetHeight(200)
    exportArea:SetEnabled(false)
    exportCard:AddWidget(exportArea, nil, 200)

    local function getExportString(exportType, toggle)
        if exportType then
            local missingManagers = addon:showMissingManagers(exportType)
            if not missingManagers then
                local exportString = exportFunctions[exportType](addon) or ""
                if exportString == "" then
                    exportCard.titleText:SetText("No Loadouts to Export")
                else
                    exportCard.titleText:SetText("Export String")
                end
                currentExport = exportString
                exportArea:SetEnabled(true)
                exportArea:SetValue(exportString)
            else
                toggle:SetValue(false, true)
            end
        else
            exportCard.titleText:SetText("Export String")
            currentExport = ""
            exportArea:SetValue("")
            exportArea:SetEnabled(false)
        end
    end

    local addonsToggle, talentsToggle

    addonsToggle = C:CreateToggle(settingsCard, "Addon Loadouts", false, function(checked)
        local exportType
        if checked and talentsToggle and talentsToggle:GetValue() then
            exportType = "Addon and Talent"
        elseif checked then
            exportType = "Addon"
        elseif talentsToggle and talentsToggle:GetValue() then
            exportType = "Talent"
        end
        getExportString(exportType, addonsToggle)
    end)
    settingsCard:AddWidget(addonsToggle, nil, 28)

    talentsToggle = C:CreateToggle(settingsCard, "Talent Loadouts", false, function(checked)
        local exportType
        if checked and addonsToggle:GetValue() then
            exportType = "Addon and Talent"
        elseif checked then
            exportType = "Talent"
        elseif addonsToggle:GetValue() then
            exportType = "Addon"
        end
        getExportString(exportType, talentsToggle)
    end)
    settingsCard:AddWidget(talentsToggle, nil, 28)

    scroller:AddCard(settingsCard)
    scroller:AddCard(exportCard)
    scroller:Commit()
end

---Toggles the export UI open/closed
---@param onCloseCallback function|nil Optional callback to execute when the window closes
function addon:toggleExport(onCloseCallback)
    if addon.frame and addon.frameType == "Export" then
        addon.frame:Hide()
    else
        addon:ShowExportFrame(onCloseCallback)
    end
end
