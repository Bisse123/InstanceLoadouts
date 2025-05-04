local addonName, addon = ...

-- Add addon functions to global table
_G[addonName] = addon

-- create addon in AceAddon environment
LibStub("AceAddon-3.0"):NewAddon(addon, addonName, "AceConsole-3.0", "AceEvent-3.0", "AceHook-3.0")

-- Ace3 libs
local AceGUI = LibStub("AceGUI-3.0")
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

local LibSerialize = LibStub("LibSerialize")
local LibDeflate = LibStub("LibDeflate")

local changelogTable
local updatedChangelog

local function createChangelog()
    local orderCount = CreateCounter(1)
    local function versionChanges(name, changes)
        local change = {
            order = orderCount(),
            name = name,
            type = "group",
            inline = true,
        }
        local args = {}
        for idx, text in ipairs(changes) do
            local change = {
                order = orderCount(),
                name = "- " .. text,
                type = "description",
                fontSize = "medium",
            }
            args["versionChange" .. idx] = change
        end
        change.args = args
        return change
    end
    local changelog = {
        name = addonName .. " Changelog",
        type = "group",
        args = {
            changelogHeader = {
                order = orderCount(),
                name = "Changelog",
                type = "description",
                fontSize = "large",
            },
            version213 = versionChanges("Version 2.1.3", {
                "More frames fixes",
            }),
            version212 = versionChanges("Version 2.1.2", {
                "Changes in the Blizzard Options panel",
                "Renamed Custom Groups to Custom Instances",
                "Fixed frames repositioning after certain actions",
                "Fixed frames not closing properly",
            }),
            version211 = versionChanges("Version 2.1.1", {
                "Added Garrison IDs to make them work as Open World",
            }),
            version210 = versionChanges("Version 2.1.0", {
                "Added support for Simple Addon Manager. Does not currently support the import/export feature.",
            }),
            version202 = versionChanges("Version 2.0.2", {
                "Fixed issue when entering a raid that is not being tracked",
                "Fixed issue caused when saving, deleting or changing gearsets",
                "Fixed a bug which occured if a player removed an encounter from custom groups while being inside the instance of that encounter",
                "Changed name of button in reminder from Options to Loadouts Config",
                "Fixed Loadouts Config button in reminder for dungeons and raids",
            }),
            version201 = versionChanges("Version 2.0.1", {
                "Fixed Raid Loadouts",
            }),
            version200 = versionChanges("Version 2.0.0", {
                "NEW FEATURE: Custom groups -> Add Loadouts for any Dungeon or Raid from the Encounter Journal",
                "NOTE: When adding a custom Raid remember to input npcIDs for each boss if you wish to get reminded to swap loadouts for that boss",
                "Added button in Encounter Journal to add custom instances to loadouts",
                "Now uses IDs instead of names for tracking, this means it now works for non english users",
                "Converted database from names to IDs",
                "Default instances will always be current season (Not considered custom groups so cannot be removed)",
                "Created Custom Groups Config window to remove custom instances from loadouts",
                "Changed the UI to be better suited for custom groups",
                "Dungeon groups will all share the same Default Loadout",
                "Duplicate Dungeons will share the same Loadout",
                "Export now includes custom groups",
                "Import now includes custom groups and will use appropiate Locale names",
            }),
            version101 = versionChanges("Version 1.0.1", {
                "Added Better Addon List as an Addon Manager. Does not currently support the import/export feature.",
                "Swapping between Addon Managers will reset the addon loadouts each time",
            }),
            version100 = versionChanges("Version 1.0.0", {
                "Added option to automatically show changelog on new update (Enabled by default)",
                "Added feature to import Addons/Talents loadouts (/il import)",
                "Added feature to Export Addons/Talents loadouts (/il export)",
                "Importing/Exporting addon loadouts requires an Addon manager",
                "Importing/Exporting talents loadouts requires a Talent manager",
                "Restructure of codebase",
            }),
            version010 = versionChanges("Version 0.1.0", {
                "Added Changelog window (/il log)",
                "Added loadouts for Delves",
                "Added loadouts for Arenas",
                "Added loadouts for Battlegrounds",
                "Added scroll container to options config window",
                "Added scroll container to reminder window",
                "Fixed bug with Operation: Mechagon - Workshop not showing loadout when entering dungeon",
                "Ensured that only one GUI element can be open at a time",
            }),
            version001 = versionChanges("Version 0.0.1", {
                "Fixed a bug when turning off override spec but still having override talents on where it would choose the talent override instead of the default",
            }),
            version000 = versionChanges("Version 0.0.0", {
                "Initial release",
            }),
        },
    }
    return changelog
end

function addon:showChangelog()
    self.frameType = "Changelog"
    AceConfigDialog:Open(addonName .. "-Changelog")
end

function addon:toggleChangelog()
    if updatedChangelog then
        AceGUI:Release(addon.frame)
        addon.frame = nil
    elseif AceConfigDialog.OpenFrames[addonName .. "-Changelog"] then
        AceConfigDialog:Close(addonName .. "-Changelog")
        addon.frame = nil
    else
        if addon.frame then
            AceGUI:Release(addon.frame)
            addon.frame = nil
        end
        addon:showChangelog()
    end
end

-- Creates blizzard options tab
local function createBlizzOptions()
    local orderCount = CreateCounter(1)
    local nextSpace = 1
    local function newSpace()
        nextSpace = nextSpace + 1
        return {
            order = orderCount(),
            name = " ",
            type = "description",
            fontSize = "large",
        }
    end
    local function showManagers(managers)
        local args = {}
        for _, name in pairs(managers) do
            local arg = {
                order = orderCount(),
                name = "- " .. name,
                type = "description",
                fontSize = "medium",
            }
            args[name] = arg
        end
        return args
    end
    local aboutTable = {
        name = addonName,
        type = "group",
        handler = addon,
        args = {
            -- About the addon
            author = {
                order = orderCount(),
                name = "Author: " .. C_AddOns.GetAddOnMetadata(addonName, "Author"),
                type = "description",
                fontSize = "large",
            },
            version = {
                order = orderCount(),
                name = "Version: " .. C_AddOns.GetAddOnMetadata(addonName, "Version"),
                type = "description",
                fontSize = "large",
            },
            patch = {
                order = orderCount(),
                name = "Patch: " .. C_AddOns.GetAddOnMetadata(addonName, "X-Patch"),
                type = "description",
                fontSize = "large",
            },
            discord = {
                order = orderCount(),
                name = "Discord link",
                type = "input",
                width = 1.2,
                get = function()
                    return "https://discord.gg/esUtXwdQ"
                end,
                cmdHidden = true,
            },
            ["space" .. nextSpace] = newSpace(),
            slashCommandHeader = {
                order = orderCount(),
                name = "Slash commands",
                type = "description",
                fontSize = "large",
            },
            slashCommand = {
                order = orderCount(),
                name = "/instanceloadouts\n/il",
                type = "description",
                fontSize = "medium",
            },
            ["space" .. nextSpace] = newSpace(),
            externalsAddonsHeader = {
                order = orderCount(),
                name = "Supported Addon Managers",
                type = "description",
                fontSize = "large",
            },
            externalsAddonsText = {
                order = orderCount(),
                name = "",
                type = "group",
                inline = true,
                args = showManagers(addon:getSupportedAddonManagers())
            },
            ["space" .. nextSpace] = newSpace(),
            externalsTalentHeader = {
                order = orderCount(),
                name = "Supported Talent Managers",
                type = "description",
                fontSize = "large",
            },
            externalsTalentText = {
                order = orderCount(),
                name = "",
                type = "group",
                inline = true,
                args = showManagers(addon:getSupportedTalentManagers())
            },
        }
    }
    return aboutTable
end

function addon:showOptions()
    self.frameType = "Options"
    AceConfigDialog:Open(addonName)
end

function addon:toggleOptions()
    if AceConfigDialog.OpenFrames[addonName] then
        AceConfigDialog:Close(addonName)
        addon.frame = nil
    else
        if addon.frame then
            AceGUI:Release(addon.frame)
            addon.frame = nil
        end
        addon:showOptions()
    end
end

local optionFunctions = {
    ["Options"] = addon.toggleOptions,
    ["Changelog"] = addon.toggleChangelog,
    ["Custom Instances"] = addon.toggleCustomInstanceUI,
    ["Loadouts"] = addon.toggleConfig,
    ["Import"] = addon.toggleImport,
    ["Export"] = addon.toggleExport,
}

function addon:executeOptionsFunction(info, button)
    if AceConfigDialog.OpenFrames[addonName] then
        AceConfigDialog:Close(addonName)
    end
    if AceConfigDialog.OpenFrames[addonName .. "-Changelog"] then
        AceConfigDialog:Close(addonName .. "-Changelog")
    end
    if self.frame then
        AceGUI:Release(self.frame)
    end
    optionFunctions[info.option.name]()
end

local function createOptionstable()
    local orderCount = CreateCounter(1)
    local nextSpace = 1
    local function newSpace()
        nextSpace = nextSpace + 1
        return {
            order = orderCount(),
            name = " ",
            type = "description",
            fontSize = "large",
        }
    end
    local optionsTable = {
        name = addonName .. " Options",
        type = "group",
        handler = addon,
        args = {
            options = {
                order = orderCount(),
                name = "Options",
                type = "execute",
                desc = "Open Options",
                func = "executeOptionsFunction",
                guiHidden = true,
            },
            o = {
                order = orderCount(),
                name = "Options",
                type = "execute",
                desc = "Open Options",
                func = "executeOptionsFunction",
                guiHidden = true,
            },
            changelogHeader = {
                order = orderCount(),
                name = "Changelog",
                type = "description",
                fontSize = "large",
            },
            changelog = {
                order = orderCount(),
                name = "Changelog",
                type = "execute",
                desc = "Open Changelog",
                func = "executeOptionsFunction",
            },
            log = {
                order = orderCount(),
                name = "Changelog",
                type = "execute",
                desc = "Open Changelog",
                func = "executeOptionsFunction",
                guiHidden = true,
            },
            autoShowChangelog = {
                order = orderCount(),
                name = "Auto show changelog on update",
                type = "toggle",
                desc = "Automatically show changelog when new update is detected",
                width = 2,
                set = function (info, val)
                    addon.db.global.autoShowChangelog = val
                end,
                get = function(info)
                    return addon.db.global.autoShowChangelog
                end,
            },
            ["space" .. nextSpace] = newSpace(),
            ImportExport = {
                order = orderCount(),
                name = "Import/Export loadouts",
                type = "description",
                fontSize = "large",
            },
            import = {
                order = orderCount(),
                name = "Import",
                type = "execute",
                desc = "Import Loadout",
                func = "executeOptionsFunction",
            },
            export = {
                order = orderCount(),
                name = "Export",
                type = "execute",
                desc = "Export Loadout",
                func = "executeOptionsFunction",
            },
            ["space" .. nextSpace] = newSpace(),
            customGroupsHeader = {
                order = orderCount(),
                name = "Manage Custom Instances",
                type = "description",
                fontSize = "large",
            },
            custominstance = {
                order = orderCount(),
                name = "Custom Instances",
                type = "execute",
                desc = "Open Custom Instances",
                func = "executeOptionsFunction",
            },
            ci = {
                order = orderCount(),
                name = "Custom Instances",
                type = "execute",
                desc = "Open Custom Instances",
                func = "executeOptionsFunction",
                guiHidden = true,
            },
            ["space" .. nextSpace] = newSpace(),
            OptionsHeader = {
                order = orderCount(),
                name = "Configure Loadouts",
                type = "description",
                fontSize = "large",
            },
            config = {
                order = orderCount(),
                name = "Loadouts",
                type = "execute",
                desc = "Open Loadouts",
                func = "executeOptionsFunction",
            },
            c = {
                order = orderCount(),
                name = "Loadouts",
                type = "execute",
                desc = "Open Loadouts",
                func = "executeOptionsFunction",
                guiHidden = true,
            },
        }
    }
    return optionsTable
end

function addon:createOptionsButton(frame)
    local container = AceGUI:Create("SimpleGroup")
    container:SetLayout("Flow")
    container:SetRelativeWidth(0.25)
    frame:AddChild(container)
    local button = AceGUI:Create("Button")
    button:SetText("Open Options")
    button:SetRelativeWidth(0.5)
    button:SetCallback("OnClick", function(widget, callback)
        AceGUI:Release(frame)
        self:toggleOptions()
    end)
    frame:AddChild(button)
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

-- Generates the database default profile
-- self.db.char.loadouts = {
--     ["Dungeon / Raid / Open World"] = {
--         ["Default"] = {
--             ["Specialization"] = -1,
--             ["Talents"] = -1,
--             ["Gearset"] = -1,
--             ["Addons"] = -1,
--         },
--         ["Dungeon Instance / Raid Boss"] = {
--             ["Override Default Specialization"] = false,
--             ["Specialization"] = -1,
--             ["Override Default Talents"] = false,
--             ["Talents"] = -1,
--             ["Override Default Gearset"] = false,
--             ["Gearset"] = -1,
--             ["Override Default Addons"] = false,
--             ["Addons"] = -1,
--         },
--     }
-- }

function addon:generateGlobalDefaults()
    local global = {
        ["autoShowChangelog"] = true,
        ["journalIDs"] = CopyTable(self.defaultJournalIDs),
    }
    return global
end

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

function addon:generateDefaults()
    self.ConvertIDToName = {}
    local db = {
        ["global"] = self:generateGlobalDefaults(),
        ["char"] = self:generateCharDefaults(),
    }
    return db
end

-- Init data for the addon
-- ChallengeMaps
-- Battlegrounds
-- Detect external addons
-- Populate ExternalInfo with data
function addon:InitData()
    self:getCurrentSeason()
    self:getCustomEncounterJournals()
    self:convertDB()
    local default = self:generateDefaults()
    self.db:RegisterDefaults(default)
    

    self:RegisterEvent("PLAYER_ENTERING_WORLD", function(event, isLogin, isReload)
        if not isLogin and not isReload then
            addon:UnregisterEvent("SPELL_CONFIRMATION_TIMEOUT")
            self:checkIfIsTrackedInstance()
            return
        end
        local oldChangelog = self.db.global.changelog
        local serializedhangelog = LibSerialize:Serialize(changelogTable)
        local compressedhangelog = LibDeflate:CompressDeflate(serializedhangelog)
        local encodedChangelog = LibDeflate:EncodeForPrint(compressedhangelog)
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
        local frame = AceGUI:Create("Frame")
        updatedChangelog = true
        frame:SetCallback("OnClose", function(widget)
            AceGUI:Release(widget)
            self.frame = nil
            updatedChangelog = false
            self:checkIfIsTrackedInstance()
        end)
        self.frame = frame
        AceConfigDialog:Open(addonName .. "-Changelog", self.frame)
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

-- Initializing function
function addon:OnInitialize()
    local globalDefaults = {
        ["global"] = {
            ["autoShowChangelog"] = true,
            ["journalIDs"] = {
                ["Dungeon"] = {},
                ["Raid"] = {},
            },
        }
    }
    self.db = LibStub("AceDB-3.0"):New("InstanceLoadoutsDB", globalDefaults)

    local aboutTable = createBlizzOptions()
    AceConfig:RegisterOptionsTable(addonName .. "-About", aboutTable)
    AceConfigDialog:AddToBlizOptions(addonName .. "-About", addonName)
    local optionsTable = createOptionstable()
    AceConfig:RegisterOptionsTable(addonName, optionsTable, {"instanceloadouts", "il"})
    AceConfigDialog:AddToBlizOptions(addonName, "Options", addonName)
    changelogTable = createChangelog()
    AceConfig:RegisterOptionsTable(addonName .. "-Changelog", changelogTable)
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
