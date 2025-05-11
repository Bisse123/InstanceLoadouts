local addonName, addon = ...

if WoWUnit then
    local Reminder = WoWUnit("IL Reminder")
    addon.testData.Reminder = Reminder
    
    -- Gearset Tests
    function Reminder:Gearset_IsActive()
        local mockAceGUI = addon.testData:Load({
            gearset = addon.testData.config.gearset.default
        })
        local testFrame = mockAceGUI:Create("Frame")
        local changed = addon:createGearsetFrame(testFrame, "Open World", -1)
        WoWUnit.IsFalse(changed)
    end

    function Reminder:Gearset_IsDifferent()
        local mockAceGUI = addon.testData:Load({
            gearset = addon.testData.config.gearset.different
        })
        local testFrame = mockAceGUI:Create("Frame")
        local changed = addon:createGearsetFrame(testFrame, "Open World", -1)
        WoWUnit.IsTrue(changed)
    end

    function Reminder:Gearset_IsOverride()
        local mockAceGUI = addon.testData:Load({
            gearset = addon.testData.config.gearset.different,
        })
        local testFrame = mockAceGUI:Create("Frame")
        local changed = addon:createGearsetFrame(testFrame, "Open World", 1)
        WoWUnit.IsTrue(changed)
    end

    function Reminder:Gearset_isNotOverride()
        local mockAceGUI = addon.testData:Load({
            gearset = addon.testData.config.gearset.default,
        })
        local testFrame = mockAceGUI:Create("Frame")
        local changed = addon:createGearsetFrame(testFrame, "Open World", 2)
        WoWUnit.IsFalse(changed)
    end

    function Reminder:Gearset_NoManager()
        local mockAceGUI = addon.testData:Load({
            externalInfo = addon.testData.config.externalInfo.noDefault
        })
        local testFrame = mockAceGUI:Create("Frame")
        local changed = addon:createGearsetFrame(testFrame, "Open World", -1)
        WoWUnit.IsFalse(changed)
    end

    -- Specialization Tests
    function Reminder:Spec_IsActive()
        local mockAceGUI = addon.testData:Load({
            specialization = addon.testData.config.specialization.default
        })
        local testFrame = mockAceGUI:Create("Frame")
        local changed = addon:createSpecializationFrame(testFrame, "Open World", -1)
        WoWUnit.IsFalse(changed)
    end

    -- ...remaining spec tests...

    -- Talents Tests
    function Reminder:Talents_IsActive()
        local mockAceGUI = addon.testData:Load({
            talents = addon.testData.config.talents.default
        })
        local testFrame = mockAceGUI:Create("Frame")
        local changed = addon:createTalentsFrame(testFrame, "Open World", -1)
        WoWUnit.IsFalse(changed)
    end

    -- ...remaining talent tests...

    -- Addons Tests
    function Reminder:Addons_IsActive()
        local mockAceGUI = addon.testData:Load({
            addons = addon.testData.config.addons.default
        })
        local testFrame = mockAceGUI:Create("Frame")
        local changed = addon:createAddonsFrame(testFrame, "Open World", -1)
        WoWUnit.IsFalse(changed)
    end

    -- ...remaining addon tests...

    -- Loadout Tests
    local function cleanupShowLoadoutFrame()
        if addon.frame then
            AceGUI:Release(addon.frame)
            addon.frame = nil
        end
    end

    function Reminder:Loadout_AllSame()
        local mockAceGUI = addon.testData:Load({
            gearset = addon.testData.config.gearset.default,
            specialization = addon.testData.config.specialization.default,
            talents = addon.testData.config.talents.default,
            addons = addon.testData.config.addons.default
        })
        addon:showLoadoutForInstance("Open World", -1)
        WoWUnit.IsTrue(addon.frame == nil)
        cleanupShowLoadoutFrame()
    end

    -- ...remaining loadout tests...
end
