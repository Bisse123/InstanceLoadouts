local addonName, addon = ...

if WoWUnit then
    local WoWUnit = WoWUnit
    -- Mock setup helper functions
    local function CreateMockAceGUI()
        local widgets = {}
        local mockAceGUI = {
            Create = function(self, widgetType)
                local widget = {
                    SetTitle = function() end,
                    SetLayout = function() end,
                    SetWidth = function() end,
                    SetHeight = function() end,
                    SetCallback = function() end,
                    AddChild = function() end,
                    ReleaseChildren = function() end,
                    SetText = function() end,
                    SetFont = function() end,
                    SetFullWidth = function() end,
                    SetRelativeWidth = function() end,
                }
                table.insert(widgets, widget)
                return widget
            end,
            Release = function() end,
            widgets = widgets
        }
        return mockAceGUI
    end

    addon.testData = {
        config = {
            db = {
                default = {
                    char = {
                        loadouts = {
                            ["Open World"] = {
                                [-1] = {
                                    Specialization = 1,
                                    Gearset = 1,
                                    Talents = 1,
                                    Addons = 1
                                },
                                [1] = {
                                    Specialization = 2,
                                    Gearset = 2,
                                    Talents = 2,
                                    Addons = 2,
                                    ["Override Default Specialization"] = true,
                                    ["Override Default Gearset"] = true,
                                    ["Override Default Talents"] = true,
                                    ["Override Default Addons"] = true
                                },
                                [2] = {
                                    Specialization = 2,
                                    Gearset = 2,
                                    Talents = 2,
                                    Addons = 2,
                                    ["Override Default Specialization"] = false,
                                    ["Override Default Gearset"] = false,
                                    ["Override Default Talents"] = false,
                                    ["Override Default Addons"] = false
                                }
                            }
                        }
                    }
                }
            },
            gearset = {
                default = {
                    equipped = true,
                    name = "Test Set 1"
                },
                different = {
                    equipped = false,
                    name = "Different Set"
                },
            },
            specialization = {
                default = {
                    current = 1,
                    name = "Test Spec 1"
                },
                different = {
                    current = 2,
                    name = "Different Spec"
                }
            },
            talents = {
                default = {
                    current = 1,
                    name = "Test Talent Config 1"
                },
                different = {
                    current = 2,
                    name = "Different Config"
                }
            },
            addons = {
                default = {
                    active = true,
                    name = "Test Addon Set 1"
                },
                different = {
                    active = false,
                    name = "Different Set"
                }
            },
            externalInfo = {
                default = {
                    Specialization = {
                        [1] = "Test Spec 1",
                        [2] = "Test Spec 2",
                        [3] = "Test Spec 3",
                        [-1] = "None"},
                    Talents = {
                        [1] = "Test Talent Config 1",
                        [2] = "Test Talent Config 2",
                        [3] = "Test Talent Config 3",
                        [-1] = "None"},
                    Gearset = {
                        [1] = "Test Gear Set 1",
                        [2] = "Test Gear Set 2",
                        [3] = "Test Gear Set 3",
                        [-1] = "None"},
                    Addons = {
                        [1] = "Test Addon Set 1",
                        [2] = "Test Addon Set 2",
                        [3] = "Test Addon Set 3",
                        [-1] = "None"}
                },
                noDefault = {
                    Specialization = {},
                    Talents = {},
                    Gearset = {},
                    Addons = {}
                }
            },
            manager = {
                default = {
                    talents = {
                        hasTalentManager = true,
                        manager = "TalentLoadoutManager",
                        hasClassicTalents = true,
                        configIDs = {1, 2, 3}
                    },
                    addons = {
                        hasAddonManager = true,
                        manager = "ACP"
                    }
                },
                noDefault = {
                    talents = {
                        hasTalentManager = false,
                        manager = nil,
                        hasClassicTalents = false,
                        configIDs = {}
                    },
                    addons = {
                        hasAddonManager = false,
                        manager = nil
                    }
                },
                classicTalents = {
                    talents = {
                        hasTalentManager = false,
                        manager = nil,
                        hasClassicTalents = true,
                        configIDs = {1, 2, 3}
                    },
                    addons = {
                        hasAddonManager = true,
                        manager = "ACP"
                    }
                }
            }
        },

        Load = function(self, config)
            config = config or {}
            
            -- Initialize frame properties
            WoWUnit.Replace(addon, 'frame', false)
            WoWUnit.Replace(addon, 'frameType', "")
            
            -- Setup basic addon structure using selected db config or default
            local dbConfig = config.db or self.config.db.default
            WoWUnit.Replace(addon, 'db', dbConfig)

            -- Mock external info structure with configurable managers
            local externalConfig = config.externalInfo or self.config.externalInfo.default
            WoWUnit.Replace(addon, 'externalInfo', externalConfig)

            -- Mock AceGUI
            local mockAceGUI = CreateMockAceGUI()
            WoWUnit.Replace(_G, 'LibStub', function() return mockAceGUI end)

            -- Mock C_EquipmentSet with configurable values
            local gearConfig = config.gearset or self.config.gearset.default
            WoWUnit.Replace(_G, 'C_EquipmentSet', {
                GetEquipmentSetInfo = function(id)
                    return gearConfig.name, nil, nil, gearConfig.equipped
                end
            })
            
            -- Mock specialization with configurable values
            local specConfig = config.specialization or self.config.specialization.default
            WoWUnit.Replace(_G, 'GetSpecialization', function()
                return specConfig.current
            end)
            
            WoWUnit.Replace(_G, 'GetSpecializationInfo', function(specId)
                return nil, specConfig.name
            end)
            
            -- Mock talents with configurable values
            local talentConfig = config.talents or self.config.talents.default
            WoWUnit.Replace(_G, 'C_ClassTalents', {
                GetLastSelectedSavedConfigID = function(specID)
                    return talentConfig.current
                end,
                LoadConfig = function(configID, useCurrentLocation)
                    return 1
                end,
                UpdateLastSelectedSavedConfigID = function(specID, configID) end
            })

            -- Mock manager with configurable values
            local managerConfig = config.manager or self.config.manager.default
            local addonConfig = config.addons or self.config.addons.default
            WoWUnit.Replace(addon, 'manager', {
                getAddonSetName = function(self, setID)
                    return addonConfig.name
                end,
                isActiveAddonSet = function(self, setID)
                    return addonConfig.active
                end,
                getAddonManager = function(self)
                    if managerConfig.addons.hasAddonManager then
                        return managerConfig.addons.manager
                    end
                    return nil
                end,
                getTalentManager = function(self)
                    if managerConfig.talents.hasTalentManager then
                        return managerConfig.talents.manager
                    end
                    return nil
                end,
                getActiveTalentLoadoutID = function(self)
                    return talentConfig.current
                end,
                loadAddons = function(self, setID) end,
                loadTalentLoadout = function(self, talentSet, autoApply) end
            })

            -- Mock C_Traits for default talent system
            if not managerConfig.talents.hasTalentManager and managerConfig.talents.configIDs then
                WoWUnit.Replace(_G, 'C_Traits', {
                    GetConfigInfo = function(configID)
                        return {name = "Config " .. configID}
                    end
                })
                WoWUnit.Replace(_G, 'C_ClassTalents', {
                    GetConfigIDsBySpecID = function(specID)
                        return managerConfig.talents.configIDs
                    end,
                    GetLastSelectedSavedConfigID = function(specID)
                        return talentConfig.current
                    end,
                    LoadConfig = function(configID, useCurrentLocation)
                        return 1
                    end,
                    UpdateLastSelectedSavedConfigID = function(specID, configID) end
                })
            end
            
            return mockAceGUI
        end
    }
end
