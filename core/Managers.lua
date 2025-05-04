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

-- Gets ACP set names
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

local function getACPSetName(addonSet)
    return ACP:GetSetName(addonSet)
end

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

local function loadACPAddons(addonSet)
    ACP:ClearSelectionAndLoadSet(addonSet)
end

-- Gets BAL set names
local function getBALAddonPreset()
    local setNames = {}
    for setName, _ in pairs(balDB.sets) do
        setNames[setName] = setName
    end
    return setNames
end

local function getBALSetName(addonSet)
    return addonSet
end

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

local function loadBALAddons(addonSet)
    DEFAULT_CHAT_FRAME.editBox:SetText("/addons load " .. addonSet) 
    ChatEdit_SendText(DEFAULT_CHAT_FRAME.editBox, 0)
end

-- Gets SAM set names
local function getSAMAddonPreset()
    local setNames = {}
    for setName, _ in pairs(SAM:GetDb().sets) do
        setNames[setName] = setName
    end
    return setNames
end

local function getSAMSetName(addonSet)
    return addonSet
end

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

local function loadSAMAddons(addonSet)
    local samProfile = SAM:GetModule("Profile")
    samProfile:LoadAddonsFromProfile(addonSet)
    ReloadUI()
end

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

-- Get TLM configIDs and names
local function getTLMLoadouts(specID)
    local talentLoadouts = {}
    local configIDs = TalentLoadoutManagerAPI.GlobalAPI:GetLoadoutIDs(specID)
    for _, configID in pairs(configIDs) do
        local configInfo = TalentLoadoutManagerAPI.GlobalAPI:GetLoadoutInfoByID(configID)
        talentLoadouts[configID] = configInfo.displayName
    end
    return talentLoadouts
end

-- Talent Loadout Manager hook
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
-- Checks for addon manager
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

-- Checks for specialization
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

-- Checks for talent manager or default talent sets
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

-- Checks for gearsets
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
            for _, encounterID in pairs(encounters) do
                if db[instanceType][encounterID].Talents == configID then
                    db[instanceType][encounterID].Talents = -1
                end
            end
        end
        self:checkTalentManager()
        if self.frame and self.frameType == "Config" then
            addon:openConfig()
        end
    end)
end

-- Addon Manager
function addon.manager:getAddonManager()
    for addonManager, _ in pairs(addonManagers) do
        if C_AddOns.IsAddOnLoaded(addonManager) then
            return addonManager
        end
    end
    return nil
end

function addon.manager:getAddonSetName(addonSet)
    local addonManager = self:getAddonManager()
    return addonManagerFunctions[addonManager].getAddonSetName(addonSet)
end

function addon.manager:isActiveAddonSet(addonSet)
    local addonManager = self:getAddonManager()
    return addonManagerFunctions[addonManager].isActiveAddonSet(addonSet)
end

function addon.manager:loadAddons(addonSet)
    local addonManager = self:getAddonManager()
    addonManagerFunctions[addonManager].loadAddons(addonSet)
end

-- For Import/Export - Only ACP supported for now
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
    -- ACP_Data.AddonSet[set] = addonSet
end

function addon.manager.getAddonManagerSet(set)
    return ACP_Data.AddonSet[set]
end

function addon.manager:setProtectedAddons(ProtectedAddons)
    for idx = 1, C_AddOns.GetNumAddOns() do
        local IdxAddonName = C_AddOns.GetAddOnInfo(idx)
        if (ACP:IsAddOnProtected(IdxAddonName) and not ProtectedAddons[IdxAddonName]) or (not ACP:IsAddOnProtected(IdxAddonName) and ProtectedAddons[IdxAddonName]) then
            ACP:Security_OnClick(IdxAddonName)
        end
    end
    -- ACP_Data.ProtectedAddons = ProtectedAddons
end

function addon.manager:getProtectedAddons()
    return ACP_Data.ProtectedAddons
end

-- Talent Manager
function addon.manager:getTalentManager()
    for talentManager, _ in pairs(talentManagers) do
        if C_AddOns.IsAddOnLoaded(talentManager) then
            return talentManager
        end
    end
    return nil
end

function addon.manager:getActiveTalentLoadoutID()
    return TalentLoadoutManagerAPI.CharacterAPI:GetActiveLoadoutID()
end

function addon.manager.loadTalentLoadout(talentSet, autoApply)
    TalentLoadoutManagerAPI.CharacterAPI:LoadLoadout(talentSet, autoApply)
end

-- For Import/Export - Only TLM supported
function addon.manager:getTalentLoadouts(specID, classID)
    return TalentLoadoutManagerAPI.GlobalAPI:GetLoadouts(specID, classID)
end

function addon.manager.updateTalentLoadout(loadoutID, exportString)
    return TalentLoadoutManagerAPI.GlobalAPI:UpdateCustomLoadoutWithImportString(loadoutID, exportString)
end

function addon.manager.importTalentLoadout(exportString, name)
    return TalentLoadoutManagerAPI.GlobalAPI:ImportCustomLoadout(exportString, name)
end

function addon.manager:getTalentLoadoutInfoByID(loadoutID)
    return TalentLoadoutManagerAPI.GlobalAPI:GetLoadoutInfoByID(loadoutID)
end

function addon.manager:getTalentExportString(loadoutID)
    return TalentLoadoutManagerAPI.GlobalAPI:GetExportString(loadoutID)
end

function addon:getSupportedAddonManagers()
    return addonManagers
end

function addon:getSupportedTalentManagers()
    return talentManagers
end