local addonName, addon = ...

-- Localize global functions
local C_AddOns = C_AddOns
local GetClassInfo = GetClassInfo
local tremove = tremove
local next = next
local pairs = pairs
local ipairs = ipairs
local tinsert = tinsert
local string = string
local select = select
local type = type
local strsplit = strsplit

local AceGUI = LibStub("AceGUI-3.0")

local LibSerialize = LibStub("LibSerialize")
local LibDeflate = LibStub("LibDeflate")

local importQueue = {}

local missingManagerFrame

---Shows missing manager warnings if required managers aren't present
---@param managerType string The type of manager to check for ("Addon" or "Talent")
---@return boolean|nil True if managers are missing, nil otherwise
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
    
    if missingManagerFrame then
        AceGUI:Release(missingManagerFrame)
    end
    
    if isAddonManager and addonManager and isTalentManager and talentManager then
        return
    elseif isAddonManager and addonManager and not isTalentManager then
        return
    elseif isTalentManager and talentManager and not isAddonManager then
        return
    end

    missingManagerFrame = AceGUI:Create("Frame")
    local frame = missingManagerFrame
    frame:SetCallback("OnClose", function(widget)
        AceGUI:Release(widget)
        missingManagerFrame = nil
    end)
    frame:SetTitle(addonName)
    frame:SetLayout("Flow")
    frame:SetHeight(300)
    frame:SetWidth(500)

    local scrollcontainer = AceGUI:Create("SimpleGroup")
    scrollcontainer:SetLayout("Fill")
    scrollcontainer:SetFullWidth(true)
    scrollcontainer:SetFullHeight(true)
    frame:AddChild(scrollcontainer)

    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetLayout("Flow")
    scrollcontainer:AddChild(scroll)
    if isAddonManager and not addonManager then
        local addonContainer = AceGUI:Create("InlineGroup")
        addonContainer:SetLayout("Flow")
        addonContainer:SetFullWidth(true)
        scroll:AddChild(addonContainer)

        local addonHeader = AceGUI:Create("Label")
        addonHeader:SetText("Missing Addon Manager")
        addonHeader:SetFullWidth(true)
        addonHeader:SetFont("Fonts\\FRIZQT__.TTF", 30, "OUTLINE")
        addonContainer:AddChild(addonHeader)

        local addonLabel = AceGUI:Create("Label")
        addonLabel:SetText("Supported Addon Managers:")
        addonLabel:SetFullWidth(true)
        addonLabel:SetFont("Fonts\\FRIZQT__.TTF", 18, "OUTLINE")
        addonContainer:AddChild(addonLabel)
        
        local ACPLabel = AceGUI:Create("Label")
        ACPLabel:SetText("- Addon Control Panel")
        ACPLabel:SetFullWidth(true)
        ACPLabel:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
        addonContainer:AddChild(ACPLabel)

        local BALLabel = AceGUI:Create("Label")
        BALLabel:SetText("- Better Addon List (Does not support Import/Export)")
        BALLabel:SetFullWidth(true)
        BALLabel:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
        addonContainer:AddChild(BALLabel)

        local SAMLabel = AceGUI:Create("Label")
        SAMLabel:SetText("- Simple Addon Manager (Does not support Import/Export)")
        SAMLabel:SetFullWidth(true)
        SAMLabel:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
        addonContainer:AddChild(SAMLabel)
    end
    if isTalentManager and not talentManager then
        local talentContainer = AceGUI:Create("InlineGroup")
        talentContainer:SetLayout("Flow")
        talentContainer:SetFullWidth(true)
        scroll:AddChild(talentContainer)

        local talentHeader = AceGUI:Create("Label")
        talentHeader:SetText("Missing Talent Manager")
        talentHeader:SetFullWidth(true)
        talentHeader:SetFont("Fonts\\FRIZQT__.TTF", 30, "OUTLINE")
        talentContainer:AddChild(talentHeader)

        local talentLabel = AceGUI:Create("Label")
        talentLabel:SetText("Supported Talent Managers:")
        talentLabel:SetFullWidth(true)
        talentLabel:SetFont("Fonts\\FRIZQT__.TTF", 18, "OUTLINE")
        talentContainer:AddChild(talentLabel)

        local talentManagerList = AceGUI:Create("Label")
        talentManagerList:SetText("Talent Loadout Manager")
        talentManagerList:SetFullWidth(true)
        talentManagerList:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
        talentContainer:AddChild(talentManagerList)
    end
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
    local frame = AceGUI:Create("Frame")
    frame:SetCallback("OnClose", function(widget)
        AceGUI:Release(widget)
        addon:getNextImport()
    end)
    frame:SetTitle(addonName)
    frame:SetLayout("Flow")

    local addonHeader = AceGUI:Create("Label")
    addonHeader:SetText("Addon Sets")
    addonHeader:SetRelativeWidth(0.5)
    addonHeader:SetFont("Fonts\\FRIZQT__.TTF", 30, "OUTLINE")
    frame:AddChild(addonHeader)

    local continueButton = AceGUI:Create("Button")
    continueButton:SetText("Import Addons sets Now")
    continueButton:SetRelativeWidth(0.5)
    continueButton:SetHeight(40)
    continueButton:SetCallback("OnClick", function()
        AceGUI:Release(frame)
        addon:importAddons(loadouts, loadoutInfo, partialImport)
        addon:getNextImport()
    end)
    frame:AddChild(continueButton)

    local scrollcontainer = AceGUI:Create("SimpleGroup")
    scrollcontainer:SetLayout("Fill")
    scrollcontainer:SetFullWidth(true)
    scrollcontainer:SetFullHeight(true)
    frame:AddChild(scrollcontainer)

    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetLayout("Flow")
    scrollcontainer:AddChild(scroll)

    local addonSetHeader = AceGUI:Create("Label")
    addonSetHeader:SetText("Imported Addon sets")
    addonSetHeader:SetFullWidth(true)
    addonSetHeader:SetFont("Fonts\\FRIZQT__.TTF", 24, "OUTLINE")
    scroll:AddChild(addonSetHeader)

    local addonContainer = AceGUI:Create("InlineGroup")
    addonContainer:SetLayout("Flow")
    addonContainer:SetTitle("Addon Set Names")
    addonContainer:SetFullWidth(true)
    scroll:AddChild(addonContainer)

    local addonCurrentName = AceGUI:Create("Label")
    addonCurrentName:SetText("Current set name")
    addonCurrentName:SetRelativeWidth(0.5)
    addonCurrentName:SetFont("Fonts\\FRIZQT__.TTF", 20, "OUTLINE")
    addonContainer:AddChild(addonCurrentName)

    local addonNewName = AceGUI:Create("Label")
    addonNewName:SetText("New set name")
    addonNewName:SetRelativeWidth(0.5)
    addonNewName:SetFont("Fonts\\FRIZQT__.TTF", 20, "OUTLINE")
    addonContainer:AddChild(addonNewName)
    
    local line = AceGUI:Create("Heading")
    line:SetFullWidth(true)
    line:SetHeight(10)
    addonContainer:AddChild(line)

    local missingAddonsHeader
    for setAddonName, addonSet in pairs(loadoutInfo.Addons) do
        local addonCurrentlLabel = AceGUI:Create("Label")
        addonCurrentlLabel:SetText(setAddonName)
        addonCurrentlLabel:SetRelativeWidth(0.5)
        addonCurrentlLabel:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
        addonContainer:AddChild(addonCurrentlLabel)
        
        local oldAddonName = setAddonName
        local addonNewEditBox = AceGUI:Create("EditBox")
        addonNewEditBox:SetText(setAddonName)
        addonNewEditBox:SetRelativeWidth(0.5)
        addonNewEditBox:SetCallback("OnEnterPressed", function(widget, callback, newAddonName)
            loadoutInfo.Addons[newAddonName] = addonSet
            loadoutInfo.Addons[newAddonName].name = newAddonName
            loadoutInfo.Addons[oldAddonName] = nil
            loadouts = addon:updateLoadoutName(loadouts, oldAddonName, newAddonName)
            oldAddonName = newAddonName
        end)
        addonContainer:AddChild(addonNewEditBox)
        
        local missingAddons = self:checkMissingAddonsInAddonSet(addonSet, loadoutInfo.ProtectedAddons)
        if missingAddons then
            if not missingAddonsHeader then
                missingAddonsHeader = AceGUI:Create("Label")
                missingAddonsHeader:SetText("Missing addons in imported Addon sets")
                missingAddonsHeader:SetFullWidth(true)
                missingAddonsHeader:SetFont("Fonts\\FRIZQT__.TTF", 24, "OUTLINE")
                scroll:AddChild(missingAddonsHeader)
            end
            local missingAddonContainer = AceGUI:Create("InlineGroup")
            missingAddonContainer:SetLayout("Flow")
            missingAddonContainer:SetTitle(addonName)
            missingAddonContainer:SetFullWidth(true)
            for missingAddonName, _ in pairs(missingAddons) do
                local missingAddonLabel = AceGUI:Create("Label")
                missingAddonLabel:SetText(missingAddonName)
                missingAddonLabel:SetRelativeWidth(0.5)
                missingAddonLabel:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
                missingAddonContainer:AddChild(missingAddonLabel)
            end
            scroll:AddChild(missingAddonContainer)

        end
    end
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
    local frame = AceGUI:Create("Frame")
    frame:SetCallback("OnClose", function(widget)
        AceGUI:Release(widget)
        addon:getNextImport()
    end)
    frame:SetTitle(addonName)
    frame:SetLayout("Flow")

    local talentHeader = AceGUI:Create("Label")
    talentHeader:SetText("Talent Loadouts")
    talentHeader:SetRelativeWidth(0.5)
    talentHeader:SetFont("Fonts\\FRIZQT__.TTF", 30, "OUTLINE")
    frame:AddChild(talentHeader)

    local continueButton = AceGUI:Create("Button")
    continueButton:SetText("Import Talents Now")
    continueButton:SetRelativeWidth(0.5)
    continueButton:SetHeight(40)
    continueButton:SetCallback("OnClick", function()
        AceGUI:Release(frame)
        addon:importTalents(loadouts, loadoutInfo, partialImport)
        addon:getNextImport()
    end)
    frame:AddChild(continueButton)

    local scrollcontainer = AceGUI:Create("SimpleGroup")
    scrollcontainer:SetLayout("Fill")
    scrollcontainer:SetFullWidth(true)
    scrollcontainer:SetFullHeight(true)
    frame:AddChild(scrollcontainer)

    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetLayout("Flow")
    scrollcontainer:AddChild(scroll)

    local talentContainer = AceGUI:Create("InlineGroup")
    talentContainer:SetLayout("Flow")
    talentContainer:SetTitle("Talent Loadout Names")
    talentContainer:SetFullWidth(true)
    scroll:AddChild(talentContainer)

    local talentCurrentName = AceGUI:Create("Label")
    talentCurrentName:SetText("Current talent name")
    talentCurrentName:SetRelativeWidth(0.5)
    talentCurrentName:SetFont("Fonts\\FRIZQT__.TTF", 20, "OUTLINE")
    talentContainer:AddChild(talentCurrentName)

    local talentNewName = AceGUI:Create("Label")
    talentNewName:SetText("New talent name")
    talentNewName:SetRelativeWidth(0.5)
    talentNewName:SetFont("Fonts\\FRIZQT__.TTF", 20, "OUTLINE")
    talentContainer:AddChild(talentNewName)
    
    local line = AceGUI:Create("Heading")
    line:SetFullWidth(true)
    line:SetHeight(10)
    talentContainer:AddChild(line)

    for talentName, talentLoadout in pairs(loadoutInfo.Talents) do
        local talentCurrentlLabel = AceGUI:Create("Label")
        talentCurrentlLabel:SetText(talentName)
        talentCurrentlLabel:SetRelativeWidth(0.5)
        talentCurrentlLabel:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
        talentContainer:AddChild(talentCurrentlLabel)
        
        local oldTalentName = talentName
        local talentNewEditBox = AceGUI:Create("EditBox")
        talentNewEditBox:SetText(talentName)
        talentNewEditBox:SetRelativeWidth(0.5)
        talentNewEditBox:SetCallback("OnEnterPressed", function(widget, callback, newTalentName)
            local displayName = select(2, {strsplit("|", newTalentName)}) or newTalentName
            loadoutInfo.Talents[newTalentName] = talentLoadout
            loadoutInfo.Talents[newTalentName].name = newTalentName
            loadoutInfo.Talents[newTalentName].displayName = displayName
            loadoutInfo.Talents[oldTalentName] = nil
            loadouts = addon:updateLoadoutName(loadouts, oldTalentName, newTalentName)
            oldTalentName = newTalentName
        end)
        talentContainer:AddChild(talentNewEditBox)
    end
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
function addon:ShowImportFrame()
    local frame = self.frame
    if self.frame and self.frameType == "Import" then
        self.frame:ReleaseChildren()
    else
        if self.frame then
            AceGUI:Release(self.frame)
            self.frame = nil
        end
        self.frameType = "Import"
        frame = AceGUI:Create("Frame")
        frame:SetTitle(addonName)
        frame:SetLayout("Flow")
        frame:SetCallback("OnClose", function(widget)
            AceGUI:Release(widget)
            self.frame = nil
        end)
    end
    self:createOptionsButton(frame)

    local container = AceGUI:Create("SimpleGroup")
    container:SetLayout("Flow")
    container:SetFullWidth(true)
    frame:AddChild(container)

    local container = AceGUI:Create("SimpleGroup")
    container:SetLayout("Flow")
    container:SetRelativeWidth(0.25)
    frame:AddChild(container)

    local continueButton = AceGUI:Create("Button")
    continueButton:SetText("Invalid Import")
    continueButton:SetDisabled(true)
    continueButton:SetRelativeWidth(0.5)
    continueButton:SetHeight(40)
    frame:AddChild(continueButton)

    local partialImport = AceGUI:Create("CheckBox")
    partialImport:SetValue(false)
    partialImport:SetDisabled(true)
    partialImport:SetLabel("Partial Import")
    partialImport:SetRelativeWidth(0.33)
    partialImport:SetDescription("If checked then only loadouts that are defined (Not set to none) will be imported")
    frame:AddChild(partialImport)

    local autoAddonImport = AceGUI:Create("CheckBox")
    autoAddonImport:SetValue(false)
    autoAddonImport:SetDisabled(true)
    autoAddonImport:SetLabel("Auto Import Addons")
    autoAddonImport:SetRelativeWidth(0.33)
    autoAddonImport:SetDescription("If checked then addon sets will override sets in Addon Control Panel and any missing addons will be removed from the sets without warning")
    frame:AddChild(autoAddonImport)

    local autoTalentImport = AceGUI:Create("CheckBox")
    autoTalentImport:SetValue(false)
    autoTalentImport:SetDisabled(true)
    autoTalentImport:SetLabel("Auto Import Talents")
    autoTalentImport:SetRelativeWidth(0.33)
    autoTalentImport:SetDescription("If checked then talent loadouts will override loadouts in Talent Loadout Manager without warning")
    frame:AddChild(autoTalentImport)


    local multiEditbox = AceGUI:Create("MultiLineEditBox")
    multiEditbox:SetCallback("OnTextChanged", function(widget, callback, payload)
        local importType, loadouts, loadoutInfo = addon:isValidImportString(payload)
        local missingManagers = addon:showMissingManagers(importType)
        if importType and not missingManagers then
            partialImport:SetValue(true)
            partialImport:SetDisabled(false)
            local isAddonImport = string.find(importType, "Addon")
            local isTalentImport = string.find(importType, "Talent")

            autoAddonImport:SetValue(isAddonImport)
            autoAddonImport:SetDisabled(not isAddonImport)
            autoTalentImport:SetValue(isTalentImport)
            autoTalentImport:SetDisabled(not isTalentImport)
            continueButton:SetText("Import " .. importType .. " Loadouts")
            continueButton:SetDisabled(false)
            continueButton:SetCallback("OnClick", function()
                addon:importJournalIDs(loadoutInfo.journalIDs)
                if autoAddonImport:GetValue()then
                    addon:importAddons(loadouts, {Addons = loadoutInfo.Addons, ProtectedAddons = loadoutInfo.ProtectedAddons}, partialImport:GetValue())
                elseif isAddonImport then
                    tinsert(importQueue, {func = "Addon", loadouts = loadouts, loadoutInfo = {Addons = loadoutInfo.Addons, ProtectedAddons = loadoutInfo.ProtectedAddons}, partialImport = partialImport:GetValue()})
                end
                if autoTalentImport:GetValue() then
                    addon:importTalents(loadouts, {Talents = loadoutInfo.Talents}, partialImport:GetValue())
                elseif isTalentImport then
                    tinsert(importQueue, {func = "Talent", loadouts = loadouts, loadoutInfo = {Talents = loadoutInfo.Talents}, partialImport = partialImport:GetValue()})
                end
                AceGUI:Release(frame)
                self.frame = nil
                addon:getNextImport()
            end)

            if isTalentImport then
                local importedClassName
                local currentClass =  self.db.keys.class
                for _, configInfo in pairs(loadoutInfo.Talents) do
                    local className, classFile = GetClassInfo(configInfo.classID)
                    if currentClass ~= classFile then
                        importedClassName = className
                        break
                    end
                end
                if importedClassName then
                    partialImport:SetValue(false)
                    partialImport:SetDisabled(true)
                    autoAddonImport:SetValue(false)
                    autoAddonImport:SetDisabled(true)
                    autoTalentImport:SetValue(false)
                    autoTalentImport:SetDisabled(true)
                    continueButton:SetText("Can not import Talents for " .. importedClassName)
                    continueButton:SetDisabled(true)
                end
            end
        else
            partialImport:SetValue(false)
            partialImport:SetDisabled(true)
            autoAddonImport:SetValue(false)
            autoAddonImport:SetDisabled(true)
            autoTalentImport:SetValue(false)
            autoTalentImport:SetDisabled(true)
            continueButton:SetText("Invalid Import")
            continueButton:SetDisabled(true)
        end
    end)
    multiEditbox:SetLabel("Import String")
    multiEditbox:SetFullHeight(true)
    multiEditbox:SetFullWidth(true)
    frame:AddChild(multiEditbox)
    self.frame = frame
end

---Toggles the import UI open/closed
function addon:toggleImport()
    if addon.frame and addon.frameType == "Import" then
        AceGUI:Release(addon.frame)
        addon.frame = nil
    else
        addon:ShowImportFrame()
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
function addon:ShowExportFrame()
    local frame = self.frame
    if self.frame and self.frameType == "Export" then
        self.frame:ReleaseChildren()
    else
        if self.frame then
            AceGUI:Release(self.frame)
            self.frame = nil
        end
        self.frameType = "Export"
        frame = AceGUI:Create("Frame")
        frame:SetTitle(addonName)
        frame:SetLayout("Flow")
        frame:SetCallback("OnClose", function(widget)
            AceGUI:Release(widget)
            self.frame = nil
        end)
    end
    self:createOptionsButton(frame)

    local header = AceGUI:Create("Label")
    header:SetText("Export Loadouts")
    header:SetFullWidth(true)
    header:SetFont("Fonts\\FRIZQT__.TTF", 30, "OUTLINE")
    frame:AddChild(header)
    
    local addonsCheckbox = AceGUI:Create("CheckBox")
    addonsCheckbox:SetValue(false)
    addonsCheckbox:SetLabel("Addon Loadouts")
    frame:AddChild(addonsCheckbox)
    
    local talentsCheckbox = AceGUI:Create("CheckBox")
    talentsCheckbox:SetValue(false)
    talentsCheckbox:SetLabel("Talent Loadouts")
    frame:AddChild(talentsCheckbox)

    local multiEditbox = AceGUI:Create("MultiLineEditBox")
    multiEditbox:SetLabel("Export String")
    multiEditbox:DisableButton(true)
    multiEditbox:SetFullHeight(true)
    multiEditbox:SetFullWidth(true)
    frame:AddChild(multiEditbox)
    
    local function getExportString(exportType, checkbox)
        if exportType then
            local missingManagers = addon:showMissingManagers(exportType)
            if not missingManagers then
                local exportString = exportFunctions[exportType](addon)
                if exportString == "" then
                    header:SetText("No Loadouts to Export")
                else
                    header:SetText("Export Loadouts")
                end
                multiEditbox:SetText(exportString)
                multiEditbox:SetCallback("OnTextChanged", function()
                    multiEditbox:SetText(exportString)
                end)
            else
                checkbox:SetValue(false)
            end
        else
            multiEditbox:SetText("")
            multiEditbox:SetCallback("OnTextChanged", function()
                multiEditbox:SetText("")
            end)
        end
    end
    addonsCheckbox:SetCallback("OnValueChanged", function(widget, callback, value)
        local exportType
        if value and talentsCheckbox:GetValue() then
            exportType = "Addon and Talent"
        elseif value then
            exportType = "Addon"
        elseif talentsCheckbox:GetValue() then
            exportType = "Talent"
        end
        getExportString(exportType, addonsCheckbox)
    end)
    talentsCheckbox:SetCallback("OnValueChanged", function(widget, callback, value)
        local exportType
        if value and addonsCheckbox:GetValue() then
            exportType = "Addon and Talent"
        elseif value then
            exportType = "Talent"
        elseif addonsCheckbox:GetValue() then
            exportType = "Addon"
        end
        getExportString(exportType, talentsCheckbox)
    end)
    self.frame = frame
end

---Toggles the export UI open/closed
function addon:toggleExport()
    if addon.frame and addon.frameType == "Export" then
        AceGUI:Release(addon.frame)
        addon.frame = nil
    else
        addon:ShowExportFrame()
    end
end
