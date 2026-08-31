local addonName, addon = ...

local C = addon.Components

---Creates the changelog options card
---@param scroller table The scroll content to add the card to
local function CreateChangelogOptions(scroller)
    local card = C:CreateCard(scroller, "Changelog")

    local changelogButton = C:CreateButton(card, "Open Changelog", {
        height = 24,
        callback = function()
            addon:toggleChangelog()
        end,
    })
    card:AddWidget(changelogButton, nil, 24)

    local autoShowToggle = C:CreateToggle(card, "Auto show changelog on update", addon.db.global.autoShowChangelog, function(checked)
        addon.db.global.autoShowChangelog = checked
    end)
    card:AddWidget(autoShowToggle, nil, 30)

    scroller:AddCard(card)
end

---Creates the boss target detection options card
---@param scroller table The scroll content to add the card to
local function CreateBossTargetOptions(scroller)
    local card = C:CreateCard(scroller, "Boss Target Detection")
    card:SetWidth(395)

    card:AddLabel("Manually pick a boss for loadout reminders when swapping to a boss target. Unfortunately, automatic selection is broken due to Midnight's secret value system.", nil, 13)

    local timeoutSlider
    local enableToggle = C:CreateToggle(card, "Enable", addon.db.global.targetTimeoutEnabled, function(checked)
        addon.db.global.targetTimeoutEnabled = checked
        timeoutSlider:SetEnabled(checked)
    end)
    card:AddWidget(enableToggle, nil, 30)

    timeoutSlider = C:CreateSlider(card, "Target Check Timeout (0 for no timeout)", 0, 60, 1,
        function() return addon.db.global.targetTimeout end,
        function(value) addon.db.global.targetTimeout = value end)
    timeoutSlider:SetEnabled(addon.db.global.targetTimeoutEnabled)
    card:AddWidget(timeoutSlider, nil, 36)

    scroller:AddCard(card)
end

---Creates the import/export loadouts options card
---@param scroller table The scroll content to add the card to
local function CreateImportExportOptions(scroller)
    local card = C:CreateCard(scroller, "Import/Export Loadouts")
    card:SetWidth(395)

    card:AddLabel("Disabled for now", addon.Theme.text.muted)

    local row = CreateFrame("Frame", nil, card)
    row:SetHeight(24)

    local importButton = C:CreateButton(row, "Import Loadouts", {
        height = 24,
        callback = function()
            addon:toggleImport()
        end,
    })
    importButton:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    importButton:SetPoint("BOTTOMRIGHT", row, "BOTTOM", -3, 0)
    importButton:SetEnabled(false)

    local exportButton = C:CreateButton(row, "Export Loadouts", {
        height = 24,
        callback = function()
            addon:toggleExport()
        end,
    })
    exportButton:SetPoint("TOPLEFT", row, "TOP", 3, 0)
    exportButton:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
    exportButton:SetEnabled(false)

    card:AddWidget(row, nil, 24)

    scroller:AddCard(card)
end

---Creates the configure loadouts options card
---@param scroller table The scroll content to add the card to
local function CreateConfigureLoadoutsOptions(scroller)
    local card = C:CreateCard(scroller, "Configure Loadouts")

    local loadoutsButton = C:CreateButton(card, "Loadouts", {
        height = 24,
        callback = function()
            addon:toggleConfig()
        end,
    })
    card:AddWidget(loadoutsButton, nil, 24)

    scroller:AddCard(card)
end

---Opens the options window
---@param onCloseCallback function|nil Optional callback to execute when the window closes
function addon:openOptions(onCloseCallback)
    local _, content = self.UI.AcquireWindow("Options", {
        width = 425,
        height = 380,
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

    CreateChangelogOptions(scroller)
    CreateBossTargetOptions(scroller)
    CreateImportExportOptions(scroller)
    CreateConfigureLoadoutsOptions(scroller)

    scroller:Commit()
end

---Toggles the options window open/closed
---@param onCloseCallback function|nil Optional callback to execute when the window closes
function addon:toggleOptions(onCloseCallback)
    if addon.frame and addon.frameType == "Options" then
        addon.frame:Hide()
    else
        addon:openOptions(onCloseCallback)
    end
end
