local addonName, addon = ...

_G[addonName] = addon

LibStub("AceAddon-3.0"):NewAddon(addon, addonName, "AceConsole-3.0", "AceEvent-3.0", "AceHook-3.0")

local LibSerialize = LibStub("LibSerialize")
local LibDeflate = LibStub("LibDeflate")

addon.Setup(addonName)
addon.InitTheme()

---Shows the changelog window
---@param onCloseCallback function|nil Optional callback to execute when the window closes
function addon:showChangelog(onCloseCallback)
    addon:openChangelog(onCloseCallback)
end

---Shows general addon options/information
function addon:showOptions()
    self:openConfig()
end

---Toggles the options window open/closed 
---@param onCloseCallback function|nil Optional callback to execute when the window closes
function addon:toggleOptions(onCloseCallback)
    self:openOptions(onCloseCallback)
end

function addon:convertDB()
    if not self.db.char.loadouts then
        self.db.char.loadouts = {}
    end
    for instanceType, instanceTypeInfo in pairs(self.instanceGroups) do
        if instanceType ~= "addonManager" and instanceType ~= "loadouts" then
            for _, instanceInfo in ipairs(instanceTypeInfo) do
                if self.db.char[instanceType] then
                    if instanceType == "Raid" then
                        if instanceInfo.encounterIDs then
                            for _, encounterInfo in ipairs(instanceInfo.encounterIDs) do
                                for encounterName, encounterConfig in pairs(self.db.char[instanceType]) do
                                    if encounterInfo.encounterName == encounterName then
                                        if not self.db.char.loadouts[instanceInfo.instanceID .. "Encounter"] then
                                            self.db.char.loadouts[instanceInfo.instanceID .. " Encounter"] = {}
                                        end
                                        self.db.char.loadouts[instanceInfo.instanceID .. " Encounter"][encounterInfo.encounterID] = encounterConfig
                                    end
                                end
                            end
                        end
                    else
                        for instanceName, instanceConfig in pairs(self.db.char[instanceType]) do
                            if instanceInfo.instanceName == instanceName then
                                if not self.db.char.loadouts[instanceType] then
                                    self.db.char.loadouts[instanceType] = {}
                                end
                                self.db.char.loadouts[instanceType][instanceInfo.instanceID] = instanceConfig
                            end
                        end
                    end
                end
            end
            self.db.char[instanceType] = nil
        end
    end
end

---Generates default options for the global database
---@return table The global defaults table
function addon:generateGlobalDefaults()
    local global = {
        ["autoShowChangelog"] = true,
        ["targetTimeout"] = 0,
        ["journalIDs"] = CopyTable(self.defaultJournalIDs),
    }
    return global
end

---Generates default options for the character database
---@return table The character defaults table
function addon:generateCharDefaults()
    local char = {
            ["loadouts"] = {}
    }
    local loadouts = char.loadouts
    for instanceType, instanceTypeInfo in pairs(self.instanceGroups) do
        local instanceTbl = {}
        for _, instanceInfo in ipairs(instanceTypeInfo) do
            if instanceInfo.instanceID then
                self.ConvertIDToName[instanceInfo.instanceID] = instanceInfo.instanceName
                if instanceInfo.instanceID == -1 then
                    instanceTbl[instanceInfo.instanceID] = {
                        ["Specialization"] = -1,
                        ["Talents"] = -1,
                        ["Gearset"] = -1,
                        ["Addons"] = -1,
                    }
                else
                    instanceTbl[instanceInfo.instanceID] = {
                        ["Override Default Specialization"] = false,
                        ["Specialization"] = -1,
                        ["Override Default Talents"] = false,
                        ["Talents"] = -1,
                        ["Override Default Gearset"] = false,
                        ["Gearset"] = -1,
                        ["Override Default Addons"] = false,
                        ["Addons"] = -1,
                    }
                end
            end
            if instanceInfo.instanceIDs then
                for _, dungeonInstanceInfo in ipairs(instanceInfo.instanceIDs) do
                    self.ConvertIDToName[dungeonInstanceInfo.instanceID] = dungeonInstanceInfo.instanceName
                    if dungeonInstanceInfo.instanceID == -1 then
                        instanceTbl[dungeonInstanceInfo.instanceID] = {
                            ["Specialization"] = -1,
                            ["Talents"] = -1,
                            ["Gearset"] = -1,
                            ["Addons"] = -1,
                        }
                    else
                        instanceTbl[dungeonInstanceInfo.instanceID] = {
                            ["Override Default Specialization"] = false,
                            ["Specialization"] = -1,
                            ["Override Default Talents"] = false,
                            ["Talents"] = -1,
                            ["Override Default Gearset"] = false,
                            ["Gearset"] = -1,
                            ["Override Default Addons"] = false,
                            ["Addons"] = -1,
                        }
                    end
                end
            end
            if instanceInfo.encounterIDs then
                local encounterTbl = {}
                for _, encounterInfo in ipairs(instanceInfo.encounterIDs) do
                    self.ConvertIDToName[encounterInfo.encounterID] = encounterInfo.encounterName
                    if encounterInfo.encounterID == -1 then
                        encounterTbl[encounterInfo.encounterID] = {
                            ["Specialization"] = -1,
                            ["Talents"] = -1,
                            ["Gearset"] = -1,
                            ["Addons"] = -1,
                        }
                    else
                        encounterTbl[encounterInfo.encounterID] = {
                            ["Override Default Specialization"] = false,
                            ["Specialization"] = -1,
                            ["Override Default Talents"] = false,
                            ["Talents"] = -1,
                            ["Override Default Gearset"] = false,
                            ["Gearset"] = -1,
                            ["Override Default Addons"] = false,
                            ["Addons"] = -1,
                        }
                    end
                end
                loadouts[instanceInfo.instanceID .. " Encounter"] = encounterTbl
            end
        end
        loadouts[instanceType] = instanceTbl
    end
    return char
end

---Generates all default database options
---@return table The complete defaults table
function addon:generateDefaults()
    self.ConvertIDToName = {}
    local db = {
        ["global"] = self:generateGlobalDefaults(),
        ["char"] = self:generateCharDefaults(),
    }
    return db
end

function addon:PLAYER_ENTERING_WORLD(isLogin, isReload)
    if not isLogin and not isReload then
        addon:UnregisterEvent("SPELL_CONFIRMATION_TIMEOUT")
        self:checkIfIsTrackedInstance()
        return
    end
    local oldChangelog = self.db.global.changelog

    local serializedChangelog = LibSerialize:Serialize(addon:GetChangelog())
    local compressedChangelog = LibDeflate:CompressDeflate(serializedChangelog)
    local encodedChangelog = LibDeflate:EncodeForPrint(compressedChangelog)
    local newChangelog = LibDeflate:Adler32(encodedChangelog)

    self.db.global.changelog = newChangelog
    if oldChangelog and oldChangelog == newChangelog then
        self:checkIfIsTrackedInstance()
        return
    end
    if not self.db.global.autoShowChangelog then
        self:checkIfIsTrackedInstance()
        return
    end
    self:showChangelog(function()
        self:checkIfIsTrackedInstance()
    end)
end

-- Init data for the addon
-- ChallengeMaps
-- Battlegrounds
-- Detect external addons
-- Populate ExternalInfo with data
---Initializes core addon data
function addon:InitData()
    self:getCurrentSeason()
    self:getCustomEncounterJournals()
    self:convertDB()
    local default = self:generateDefaults()
    self.db:RegisterDefaults(default)

    self:RegisterEvent("PLAYER_ENTERING_WORLD", function(event, isLogin, isReload)
        C_Timer.After(1, function()
            self:PLAYER_ENTERING_WORLD(isLogin, isReload)
        end)
    end)
    self:RegisterEvent("ACTIVE_DELVE_DATA_UPDATE", function()
        addon:checkIfIsTrackedInstance()
        addon:RegisterEvent("SPELL_CONFIRMATION_TIMEOUT", function(event, spellID)
            if spellID == 424700 then
                addon:UnregisterEvent("SPELL_CONFIRMATION_TIMEOUT")
                C_Timer.After(1.5, function()
                    addon:checkIfIsTrackedInstance()
                end)
            end
        end)
    end)
    self:populateExternalInfo()

    self:RegisterEvent("ADDON_LOADED", function(event, name)
        if name == "Blizzard_EncounterJournal" then
            self:CreateInstanceButtons()
            self:UnregisterEvent("ADDON_LOADED")
        end
    end)
end

---Called when the addon is initialized
function addon:OnInitialize()
    local globalDefaults = {
        ["global"] = {
            ["autoShowChangelog"] = true,
            ["targetTimeout"] = 20,
            ["journalIDs"] = {
                ["Dungeon"] = {},
                ["Raid"] = {},
            },
        }
    }
    self.db = LibStub("AceDB-3.0"):New("InstanceLoadoutsDB", globalDefaults)

    self:RegisterEvent("PLAYER_LOGIN", function()
        if not GetSpecialization() or GetSpecialization() == 5 then
            self:Print("No specialization found")
            self:RegisterEvent("ACTIVE_PLAYER_SPECIALIZATION_CHANGED", function()
                if not GetSpecialization() or GetSpecialization() == 5 then
                    return
                end
                self:UnregisterEvent("ACTIVE_PLAYER_SPECIALIZATION_CHANGED")
                self:InitData()
            end)
            return
        end
        self:InitData()
    end)
end

SLASH_INSTANCELOADOUTS1 = "/instanceloadouts"
SLASH_INSTANCELOADOUTS2 = "/il"
SlashCmdList["INSTANCELOADOUTS"] = function(msg)
    local command = strlower(msg or "")
    
    if command == "config" or command == "c" then
        addon:toggleConfig()
    elseif command == "changelog" or command == "log" then
        addon:toggleChangelog()
    -- elseif command == "import" then
    --     addon:toggleImport()
    -- elseif command == "export" then
    --     addon:toggleExport()
    elseif command == "options" or command == "o" then
        addon:toggleOptions()
    elseif command == "custominstance" or command == "ci" then
        addon:toggleCustomInstanceUI()
    elseif command == "target" or command == "t" then
        -- Manual target testing for reminder system
        addon:checkIfIsTrackedInstance()
    elseif command == "debug" or command == "d" then
        -- Force-show the reminder for the current instance even if nothing needs changing
        addon:checkIfIsTrackedInstance(true)
    elseif command == "testconfirm" or command == "tc" then
        local C = addon.Components
        C.ShowConfirm("This is a test confirm dialog.", function()
            addon:Print("Confirmed!")
        end, function()
            addon:Print("Cancelled!")
        end, 260, addon.frame)
    elseif command == "scan" then
        local targets = {
            ["Collegiate Calamity"] = true,
            ["Atal'Aman"] = true,
            ["Twilight Crypts"] = true,
            ["Torment's Rise"] = true,
            ["Shadowguard Point"] = true,
            ["The Grudge Pit"] = true,
            ["The Gulf of Memory"] = true,
            ["The Shadow Enclave"] = true,
            ["Parhelion Plaza"] = true,
            ["Sunkiller Sanctum"] = true,
            ["The Darkway"] = true,
        }
        addon:Print("Scanning instance IDs 0-4000...")
        local found = {}
        for i = 0, 4000 do
            local name = GetRealZoneText(i)
            if name and targets[name] then
                found[#found+1] = i .. ", -- " .. name
            end
        end
        if #found == 0 then
            addon:Print("No matches found.")
        else
            for _, line in ipairs(found) do
                addon:Print(line)
            end
        end
    else
        -- Show help/default action
        addon:toggleOptions()
    end
end
