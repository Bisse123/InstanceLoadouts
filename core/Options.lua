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

---Creates the import/export loadouts options card
---@param scroller table The scroll content to add the card to
local function CreateImportExportOptions(scroller)
    local card = C:CreateCard(scroller, "Import/Export Loadouts")

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

---Creates the manage custom instances options card
---@param scroller table The scroll content to add the card to
local function CreateCustomInstancesOptions(scroller)
    local card = C:CreateCard(scroller, "Manage Custom Instances")

    local customInstancesButton = C:CreateButton(card, "Custom Instances", {
        height = 24,
        callback = function()
            addon:toggleCustomInstanceUI()
        end,
    })
    card:AddWidget(customInstancesButton, nil, 24)

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
        width = 400,
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
    CreateImportExportOptions(scroller)
    CreateCustomInstancesOptions(scroller)
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
