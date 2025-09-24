local addonName, addon = ...

-- Populated with external information
-- ExternalInfo = {
--     ["Specialization"] = {[specIdx] = spec Name},
--     ["Talents"] = {[configID] = config Name},
--     ["Gearset"] = {[gearsetID] = gearset Name},
--     ["Addons"] = {[ACPSetIdx] = ACP Set Name},
-- }
addon.externalInfo = {}

addon.manager = {}

-- external Addons
local ACP = ACP
local ACP_Data = ACP_Data
local balDB = BetterAddonListDB
local SAM = SimpleAddonManager
local TalentLoadoutManagerAPI = TalentLoadoutManagerAPI

local addonManagers = {
    ["ACP"] = "Addon Control Panel",
    ["BetterAddonList"] = "Better Addon List",
    ["SimpleAddonManager"] = "Simple Addon Manager",
}

local talentManagers = {
    ["TalentLoadoutManager"] = "Talent Loadout Manager",
}

---Gets ACP set names for addon presets
---@return table Dictionary of set index to set name
local function getACPAddonPreset()
    local setNames = {}
    for i = 1, 25 do
        if ACP_Data.AddonSet[i] then
            local setName = ACP:GetSetName(i)
            setNames[i] = setName
        end
    end
    return setNames
end

---Sets up hook for ACP rename set functionality
local function setACPHook()
    if not addon:IsHooked(ACP, "RenameSet") then
        addon:Hook(ACP, "RenameSet", function()
            if addon.frame and addon.frameType == "Config" then
                C_Timer.After(0, function()
                    addon:openConfig()
                end)
            elseif addon.frame and addon.frameType == "Reminder" then
                C_Timer.After(0, function()
                    addon:checkIfIsTrackedInstance()
                end)
            end
        end)
    end
end

---Gets name of ACP addon set by ID
---@param addonSet number The addon set ID
---@return string The name of the addon set
local function getACPSetName(addonSet)
    return ACP:GetSetName(addonSet)
end

---Checks if specified ACP addon set is currently active
---@param addonSet number The addon set ID to check
---@return boolean True if addon set is active
local function isActiveACPAddonSet(addonSet)
    local activeAddons = ACP_Data.AddonSet[addonSet]
    for idx = 1, C_AddOns.GetNumAddOns() do
        local IdxAddonName = C_AddOns.GetAddOnInfo(idx)
        if C_AddOns.GetAddOnEnableState(IdxAddonName, UnitGUID("player")) == 0 then
            for _, activeAddon in ipairs(activeAddons) do
                if IdxAddonName == activeAddon then
                    return false
                end
            end
        elseif not ACP:IsAddOnProtected(IdxAddonName) and not C_AddOns.IsAddOnLoadOnDemand(IdxAddonName) then
            local isSetActive = false
            for _, activeAddon in ipairs(activeAddons) do
                if IdxAddonName == activeAddon then
                    isSetActive = true
                    break
                end
            end
            if not isSetActive then
                return false
            end
        end
    end
    return true
end

---Loads the specified ACP addon set
---@param addonSet number The addon set ID to load
local function loadACPAddons(addonSet)
    ACP:ClearSelectionAndLoadSet(addonSet)
end

---Gets BAL set names for addon presets
---@return table Dictionary of set name to set name
local function getBALAddonPreset()
    local setNames = {}
    for setName, _ in pairs(balDB.sets) do
        setNames[setName] = setName
    end
    return setNames
end

---Gets name of BAL addon set by name
---@param addonSet string The addon set name
---@return string The name of the addon set
local function getBALSetName(addonSet)
    return addonSet
end

---Checks if specified BAL addon set is currently active
---@param addonSet string The addon set name to check
---@return boolean True if addon set is active
local function isActiveBALAddonSet(addonSet)
    local activeAddons = balDB.sets[addonSet]
    for idx = 1, C_AddOns.GetNumAddOns() do
        local IdxAddonName = C_AddOns.GetAddOnInfo(idx)
        if IdxAddonName ~= "BetterAddonList" then
            if C_AddOns.GetAddOnEnableState(IdxAddonName, UnitGUID("player")) == 0 then
                for _, activeAddon in ipairs(activeAddons) do
                    if IdxAddonName == activeAddon then
                        return false
                    end
                end
            elseif not balDB.protected[IdxAddonName] and not C_AddOns.IsAddOnLoadOnDemand(IdxAddonName) then
                local isSetActive = false
                for _, activeAddon in ipairs(activeAddons) do
                    if IdxAddonName == activeAddon then
                        isSetActive = true
                        break
                    end
                end
                if not isSetActive then
                    return false
                end
            end
        end
    end
    return true
end

---Loads the specified BAL addon set
---@param addonSet string The addon set name to load
local function loadBALAddons(addonSet)
    DEFAULT_CHAT_FRAME.editBox:SetText("/addons load " .. addonSet) 
    ChatEdit_SendText(DEFAULT_CHAT_FRAME.editBox, 0)
end

---Gets SAM set names for addon presets
---@return table Dictionary of set name to set name
local function getSAMAddonPreset()
    local setNames = {}
    for setName, _ in pairs(SAM:GetDb().sets) do
        setNames[setName] = setName
    end
    return setNames
end

---Gets name of SAM addon set by name
---@param addonSet string The addon set name
---@return string The name of the addon set
local function getSAMSetName(addonSet)
    return addonSet
end

---Checks if specified SAM addon set is currently active
---@param addonSet string The addon set name to check
---@return boolean True if addon set is active
local function isActiveSAMAddonSet(addonSet)
    local checkedAddonSets = {}
    local function activeSAMAddons(setName)
        if not checkedAddonSets[setName] then
            checkedAddonSets[setName] = true
            local addons = {}
            local activeSet = SAM:GetDb().sets[setName]
            local activeAddons = activeSet.addons
            for addonName, _ in pairs(activeAddons) do
                tinsert(addons, addonName)
            end
            if activeSet.subSets then
                for setName, enabled in pairs(activeSet.subSets) do
                    if enabled then
                        tinsert(addons, activeSAMAddons(setName))
                    end
                end
            end
            return addons
        end
    end

    local charGuid = SAM:GetLoggedCharGuid()
    local initialState = SAM:GetAddonsInitialState(charGuid)
    local samLock = SAM:GetModule("Lock")
    local activeAddons = activeSAMAddons(addonSet)
    for idx = 1, C_AddOns.GetNumAddOns() do
        local IdxAddonName = C_AddOns.GetAddOnInfo(idx)
        if C_AddOns.GetAddOnEnableState(IdxAddonName, UnitGUID("player")) == 0 then
            for _, activeAddon in ipairs(activeAddons) do
                if IdxAddonName == activeAddon and not initialState[IdxAddonName] then
                    return false
                end
            end
        elseif not samLock:IsAddonLocked(IdxAddonName) and not C_AddOns.IsAddOnLoadOnDemand(IdxAddonName) then
            local isSetActive = false
            for _, activeAddon in ipairs(activeAddons) do
                if IdxAddonName == activeAddon then
                    isSetActive = true
                    break
                end
            end
            if not isSetActive then
                return false
            end
        end
    end
    return true
end

---Loads the specified SAM addon set
---@param addonSet string The addon set name to load
local function loadSAMAddons(addonSet)
    local samProfile = SAM:GetModule("Profile")
    samProfile:LoadAddonsFromProfile(addonSet)
    ReloadUI()
end

---Resets addon loadouts to default state
local function resetAddonLoadouts()
    local loadouts = addon.db.char.loadouts
    for _, encounterIDs in pairs(loadouts) do
        for _, encounterConfig in pairs(encounterIDs) do
            encounterConfig.Addons = -1
        end
    end
end

local addonManagerFunctions = {
    ["ACP"] = {
        ["getAddonPreset"] = getACPAddonPreset,
        ["setHook"] = setACPHook,
        ["getAddonSetName"] = getACPSetName,
        ["isActiveAddonSet"] = isActiveACPAddonSet,
        ["loadAddons"] = loadACPAddons,
    },
    ["BetterAddonList"] = {
        ["getAddonPreset"] = getBALAddonPreset,
        ["getAddonSetName"] = getBALSetName,
        ["isActiveAddonSet"] = isActiveBALAddonSet,
        ["loadAddons"] = loadBALAddons,
    },
    ["SimpleAddonManager"] = {
        ["getAddonPreset"] = getSAMAddonPreset,
        ["getAddonSetName"] = getSAMSetName,
        ["isActiveAddonSet"] = isActiveSAMAddonSet,
        ["loadAddons"] = loadSAMAddons,

    }
}

---Gets TLM configIDs and names for talent loadouts
---@param specID number The specialization ID
---@return table Dictionary of config ID to loadout name
local function getTLMLoadouts(specID)
    local talentLoadouts = {}
    local configIDs = TalentLoadoutManagerAPI.GlobalAPI:GetLoadoutIDs(specID)
    for _, configID in pairs(configIDs) do
        local configInfo = TalentLoadoutManagerAPI.GlobalAPI:GetLoadoutInfoByID(configID)
        talentLoadouts[configID] = configInfo.displayName
    end
    return talentLoadouts
end

---Sets up hook for TLM loadout list update event
local function setTLMHook()
    TalentLoadoutManagerAPI:RegisterCallback(TalentLoadoutManagerAPI.Event.LoadoutListUpdated, function()
        for instance, encounters in pairs(addon.db.char.loadouts) do
            for encounter, configInfo in pairs(encounters) do
                if configInfo.Specialization ~= -1 and configInfo.Talents ~= -1 then
                    local talentsFound = false
                    local specID = GetSpecializationInfo(configInfo.Specialization)
                    local configIDs = TalentLoadoutManagerAPI.GlobalAPI:GetLoadoutIDs(specID)
                    for _, configID in pairs(configIDs) do
                        if configInfo.Talents == configID then
                            talentsFound = true
                            break
                        end
                    end
                    if not talentsFound then
                        addon.db.char.loadouts[instance][encounter].Talents = -1
                    end
                end
            end
        end
        if addon.frame and addon.frameType == "Config" then
            addon:openConfig()
        end
    end)
end

local talentManagerFunctions = {
    ["TalentLoadoutManager"] = {
        ["getTalentLoadouts"] = getTLMLoadouts,
        ["setHook"] = setTLMHook,
    },
}

---Checks for an available addon manager
---@return string|nil Name of detected addon manager or nil if none found
function addon:checkAddonManager()
    self.externalInfo.Addons = {}
    local addonManager = addon.manager:getAddonManager()
    if addonManager then
        self.externalInfo.Addons = addonManagerFunctions[addonManager].getAddonPreset()
    end
    if next(self.externalInfo.Addons) then
        self.externalInfo.Addons[-1] = "None"
    end
end

---Checks for available specializations
function addon:checkSpecializationManager()
    self.externalInfo.Specialization = {}
    for specIdx = 1, GetNumSpecializations() do
        local _, name = GetSpecializationInfo(specIdx)
        self.externalInfo.Specialization[specIdx] = name
    end
    if next(self.externalInfo.Specialization) then
        self.externalInfo.Specialization[-1] = "None"
    end
end

---Checks for talent manager or default talent sets
---@param specIdx number|nil Index of specialization to check
function addon:checkTalentManager(specIdx)
    local specID
    if specIdx then
        specID = GetSpecializationInfo(specIdx)
    end
    self.externalInfo.Talents = {}
    local talentManager = addon.manager:getTalentManager()
    if talentManager then
        self.externalInfo.Talents = talentManagerFunctions[talentManager].getTalentLoadouts(specID)
    end
    if not next(self.externalInfo.Talents) then
        local configIDs = C_ClassTalents.GetConfigIDsBySpecID(specID)
        for _, configID in ipairs(configIDs) do
            local configInfo = C_Traits.GetConfigInfo(configID)
            self.externalInfo.Talents[configID] = configInfo.name
        end
    end
    if next(self.externalInfo.Talents) then
        self.externalInfo.Talents[-1] = "None"
    end
end

---Checks for available gear sets
function addon:checkGearsetManager()
    local gearsetIDs = C_EquipmentSet.GetEquipmentSetIDs()
    self.externalInfo.Gearset = {}
    if #gearsetIDs > 0 then
        for _, gearsetID in ipairs(gearsetIDs) do
            local gearsetName = C_EquipmentSet.GetEquipmentSetInfo(gearsetID)
            self.externalInfo.Gearset[gearsetID] = gearsetName
        end
    end
    if next(self.externalInfo.Gearset) then
        self.externalInfo.Gearset[-1] = "None"
    end
end

---Populates external addon/talent info and sets up required hooks
function addon:populateExternalInfo()
    local addonManager = self.manager:getAddonManager()
    if addonManager then
        if self.db.char.addonManager ~= addonManager then
            resetAddonLoadouts()
            self.db.char.addonManager = addonManager
        end
        if addonManagerFunctions[addonManager].setHook then
            addonManagerFunctions[addonManager].setHook()
        end
        self:Print(addonManagers[addonManager] .. " detected")
    end
    local talentManager = self.manager:getTalentManager()
    if talentManager then
        if talentManagerFunctions[talentManager].setHook then
            talentManagerFunctions[talentManager].setHook()
        end
        self:Print(talentManagers[talentManager] .. " detected")
    end

    self:checkSpecializationManager()
    self:checkTalentManager()
    self:checkGearsetManager()
    self:checkAddonManager()
    self:RegisterEvent("EQUIPMENT_SETS_CHANGED", function()
        self:checkGearsetManager()
        local db = self.db.char.loadouts
        for _, instanceInfo in pairs(db) do
            for _, encounterInfo in pairs(instanceInfo) do
                local gearsetFound = false
                for gearsetID, _ in pairs(self.externalInfo.Gearset) do
                    if encounterInfo.Gearset == gearsetID then
                            gearsetFound = true
                            break
                        end
                end
                if not gearsetFound then
                    encounterInfo.Gearset = -1
                end
            end
        end
        if self.frame and self.frameType == "Config" then
            self:openConfig()
        end
    end)
    self:RegisterEvent("TRAIT_CONFIG_CREATED", function(event, configInfo)
        self:checkTalentManager()
        if self.frame and self.frameType == "Config" then
            addon:openConfig()
        end
    end)
    self:RegisterEvent("TRAIT_CONFIG_DELETED", function(event, configID)
        local db = addon.db.char.loadouts
        for instanceType, encounters in pairs(db) do
            for encounterID, _ in pairs(encounters) do
                if db[instanceType][encounterID].Talents == configID then
                    local encounter = self.ConvertIDToName[encounterID] or encounterID
                    if configID ~= -1 then
                        self:Print(string.format("Talents deleted, reset %s %s", instanceType, encounter))
                    end
                    db[instanceType][encounterID].Talents = -1
                    db[instanceType][encounterID]["Override Default Talents"] = false
                end
            end
        end
        self:checkTalentManager()
        if self.frame and self.frameType == "Config" then
            addon:openConfig()
        end
    end)
end

---Gets the name of the detected addon manager
---@return string|nil Name of detected addon manager or nil if none found
function addon.manager:getAddonManager()
    for addonManager, _ in pairs(addonManagers) do
        if C_AddOns.IsAddOnLoaded(addonManager) then
            return addonManager
        end
    end
    return nil
end

---Gets the name of the specified addon set
---@param addonSet number The addon set ID
---@return string The name of the addon set
function addon.manager:getAddonSetName(addonSet)
    local addonManager = self:getAddonManager()
    return addonManagerFunctions[addonManager].getAddonSetName(addonSet)
end

---Checks if the specified addon set is currently active
---@param addonSet number The addon set ID
---@return boolean True if addon set is active
function addon.manager:isActiveAddonSet(addonSet)
    local addonManager = self:getAddonManager()
    return addonManagerFunctions[addonManager].isActiveAddonSet(addonSet)
end

---Loads the specified addon set
---@param addonSet number The addon set ID
function addon.manager:loadAddons(addonSet)
    local addonManager = self:getAddonManager()
    addonManagerFunctions[addonManager].loadAddons(addonSet)
end

---Sets the specified addon manager set
---@param set number The set ID
---@param addonSet table The addon set to apply
function addon.manager.setAddonManagerSet(set, addonSet)
    local enabledAddons = {}
    for idx = 1, C_AddOns.GetNumAddOns() do
        local IdxAddonName = C_AddOns.GetAddOnInfo(idx)
        if C_AddOns.GetAddOnEnableState(IdxAddonName, UnitGUID("player")) ~= 0 then
            tinsert(enabledAddons, IdxAddonName)
        end
    end
    local guid = UnitGUID("player")
    C_AddOns.DisableAllAddOns(guid)
    for _, addonName in ipairs(addonSet) do
        C_AddOns.EnableAddOn(addonName, guid)
    end
    ACP:SaveSet(set)
    C_AddOns.DisableAllAddOns(guid)
    for _, addonName in ipairs(enabledAddons) do
        C_AddOns.EnableAddOn(addonName, guid)
    end
end

---Gets the specified addon manager set
---@param set number The set ID
---@return table The addon set
function addon.manager.getAddonManagerSet(set)
    return ACP_Data.AddonSet[set]
end

---Sets the protected addons
---@param ProtectedAddons table The protected addons to set
function addon.manager:setProtectedAddons(ProtectedAddons)
    for idx = 1, C_AddOns.GetNumAddOns() do
        local IdxAddonName = C_AddOns.GetAddOnInfo(idx)
        if (ACP:IsAddOnProtected(IdxAddonName) and not ProtectedAddons[IdxAddonName]) or (not ACP:IsAddOnProtected(IdxAddonName) and ProtectedAddons[IdxAddonName]) then
            ACP:Security_OnClick(IdxAddonName)
        end
    end
end

---Gets the protected addons
---@return table The protected addons
function addon.manager:getProtectedAddons()
    return ACP_Data.ProtectedAddons
end

---Gets the name of the detected talent manager
---@return string|nil Name of detected talent manager or nil if none found
function addon.manager:getTalentManager()
    for talentManager, _ in pairs(talentManagers) do
        if C_AddOns.IsAddOnLoaded(talentManager) then
            return talentManager
        end
    end
    return nil
end

---Gets the active talent loadout ID
---@return number|string The active talent loadout ID
function addon.manager:getActiveTalentLoadoutID()
    return TalentLoadoutManagerAPI.CharacterAPI:GetActiveLoadoutID()
end

---Loads the specified talent loadout
---@param talentSet number The talent set ID
---@param autoApply boolean Whether to auto-apply the loadout
function addon.manager.loadTalentLoadout(talentSet, autoApply)
    TalentLoadoutManagerAPI.CharacterAPI:LoadLoadout(talentSet, autoApply)
end

---Gets the talent loadouts for the specified specialization and class
---@param specID number The specialization ID
---@param classID number The class ID
---@return table The talent loadouts
function addon.manager:getTalentLoadouts(specID, classID)
    return TalentLoadoutManagerAPI.GlobalAPI:GetLoadouts(specID, classID)
end

---Updates the specified talent loadout with the provided export string
---@param loadoutID number|string The loadout ID
---@param exportString string The export string
---@return table|boolean The loadout info if update was successful
function addon.manager.updateTalentLoadout(loadoutID, exportString)
    return TalentLoadoutManagerAPI.GlobalAPI:UpdateCustomLoadoutWithImportString(loadoutID, exportString)
end

---Imports a talent loadout from the provided export string
---@param exportString string The export string
---@param name string The name of the loadout
---@return table|boolean The loadout info if import was successful
function addon.manager.importTalentLoadout(exportString, name)
    return TalentLoadoutManagerAPI.GlobalAPI:ImportCustomLoadout(exportString, name)
end

---Gets the talent loadout info by ID
---@param loadoutID number|string The loadout ID
---@return table The loadout info
function addon.manager:getTalentLoadoutInfoByID(loadoutID)
    return TalentLoadoutManagerAPI.GlobalAPI:GetLoadoutInfoByID(loadoutID)
end

---Gets the export string for the specified talent loadout
---@param loadoutID number|string The loadout ID
---@return string The export string
function addon.manager:getTalentExportString(loadoutID)
    return TalentLoadoutManagerAPI.GlobalAPI:GetExportString(loadoutID)
end

---Gets the supported addon managers
---@return table The supported addon managers
function addon:getSupportedAddonManagers()
    return addonManagers
end

---Gets the supported talent managers
---@return table The supported talent managers
function addon:getSupportedTalentManagers()
    return talentManagers
end