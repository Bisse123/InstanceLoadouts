local addonName, addon = ...

if WoWUnit then
    local WoWUnit = WoWUnit
    local Tests = WoWUnit("IL Tests")

    function Tests:CheckReminder()
        local status, count = addon.testData.Reminder:Status()
        WoWUnit.IsTrue(status <= 2)
        if status <= 2 then
            local idx, group = WoWUnit:HasGroup("IL Reminder")
            if idx then
                tremove(WoWUnit.children, idx)
            end
        end
    end
end
