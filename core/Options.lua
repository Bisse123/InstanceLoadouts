local addonName, addon = ...

---@type AbstractFramework
local AF = _G.AbstractFramework

---Creates the changelog options section
---@param parent table The parent frame
---@param yOffset number The y offset for positioning
---@return number newYOffset The new y offset after adding elements
local function CreateChangelogOptions(parent, yOffset)
    local changelogPane = AF.CreateTitledPane(parent, "Changelog", parent:GetWidth() - 10, 80)
    AF.SetPoint(changelogPane, "TOPLEFT", 5, yOffset)

    local changelogButton = AF.CreateButton(changelogPane, "Open Changelog", addonName, 150, 25)
    AF.SetPoint(changelogButton, "TOPLEFT", changelogPane, "TOPLEFT", 0, -25)
    changelogButton:SetOnClick(function()
        addon:toggleChangelog()
    end)

    local autoShowCheckbox = AF.CreateCheckButton(changelogPane, "Auto show changelog on update", function(checked)
        addon.db.global.autoShowChangelog = checked
    end)
    AF.SetPoint(autoShowCheckbox, "TOPLEFT", changelogButton, "TOPRIGHT", 5, -5)
    autoShowCheckbox:SetChecked(addon.db.global.autoShowChangelog)

    return yOffset - 60
end

---Creates the import/export loadouts options section
---@param parent table The parent frame
---@param yOffset number The y offset for positioning
---@return number newYOffset The new y offset after adding elements
local function CreateImportExportOptions(parent, yOffset)
    local importExportPane = AF.CreateTitledPane(parent, "Import/Export Loadouts - disabled for now", parent:GetWidth() - 10, 80)
    AF.SetPoint(importExportPane, "TOPLEFT", 5, yOffset)

    local importButton = AF.CreateButton(importExportPane, "Import Loadouts", addonName, 150, 25)
    AF.SetPoint(importButton, "TOPLEFT", importExportPane, "TOPLEFT", 0, -25)
    importButton:SetOnClick(function()
        addon:toggleImport()
    end)
    importButton:SetEnabled(false)

    local exportButton = AF.CreateButton(importExportPane, "Export Loadouts", addonName, 150, 25)
    AF.SetPoint(exportButton, "TOPLEFT", importButton, "TOPRIGHT", 5, 0)
    exportButton:SetOnClick(function()
        addon:toggleExport()
    end)
    exportButton:SetEnabled(false)

    return yOffset - 60
end

---Creates the manage custom instances options section
---@param parent table The parent frame
---@param yOffset number The y offset for positioning
---@return number newYOffset The new y offset after adding elements
local function CreateCustomInstancesOptions(parent, yOffset)
    local customInstancesPane = AF.CreateTitledPane(parent, "Manage Custom Instances", parent:GetWidth() - 10, 80)
    AF.SetPoint(customInstancesPane, "TOPLEFT", 5, yOffset)

    local customInstancesButton = AF.CreateButton(customInstancesPane, "Custom Instances", addonName, 150, 25)
    AF.SetPoint(customInstancesButton, "TOPLEFT", customInstancesPane, "TOPLEFT", 0, -25)
    customInstancesButton:SetOnClick(function()
        addon:toggleCustomInstanceUI()
    end)

    return yOffset - 60
end

---Creates the configure loadouts options section
---@param parent table The parent frame
---@param yOffset number The y offset for positioning
---@return number newYOffset The new y offset after adding elements
local function CreateConfigureLoadoutsOptions(parent, yOffset)
    local loadoutsPane = AF.CreateTitledPane(parent, "Configure Loadouts", parent:GetWidth() - 10, 80)
    AF.SetPoint(loadoutsPane, "TOPLEFT", 5, yOffset)

    local loadoutsButton = AF.CreateButton(loadoutsPane, "Loadouts", addonName, 150, 25)
    AF.SetPoint(loadoutsButton, "TOPLEFT", loadoutsPane, "TOPLEFT", 0, -25)
    loadoutsButton:SetOnClick(function()
        addon:toggleConfig()
    end)

    return yOffset - 60
end

---Creates the extra options section
---@param parent table The parent frame
---@param yOffset number The y offset for positioning
---@return number newYOffset The new y offset after adding elements
local function CreateExtraOptions(parent, yOffset)
    local extraPane = AF.CreateTitledPane(parent, "Extra Options", parent:GetWidth() - 10, 100)
    AF.SetPoint(extraPane, "TOPLEFT", 5, yOffset)

    local timeoutSlider = AF.CreateSlider(extraPane, "Target Timeout (seconds)", 200, 0, 120, 5, nil, true)
    AF.SetPoint(timeoutSlider, "TOPLEFT", extraPane, "TOPLEFT", 5, -45)
    timeoutSlider:SetValue(addon.db.global.targetTimeout)
    timeoutSlider:SetOnValueChanged(function(value)
        addon.db.global.targetTimeout = value
    end)

    return yOffset - 80
end

---Opens the options window
---@param onCloseCallback function|nil Optional callback to execute when the window closes
function addon:openOptions(onCloseCallback)
    local frame = self.frame
    if self.frame and self.frameType == "Options" then
        if self.frame.content then
            self.frame.content:Hide()
            self.frame.content = nil
        end
    else
        if self.frame then
            self.frame:Hide()
            self.frame = nil
        end
        self.frameType = "Options"
        frame = AF.CreateHeaderedFrame(AF.UIParent, "InstanceLoadouts_Options",
            AF.GetIconString("IL", 14, 14, "InstanceLoadouts") .. " " .. addonName, 400, 350)
        AF.SetPoint(frame, "CENTER", UIParent, "CENTER", 0, 0)
        frame:SetTitleColor("white")
        frame:SetFrameLevel(100)
        frame:SetTitleJustify("LEFT")

        local pageName = AF.CreateFontString(frame.header, nil, "white", "AF_FONT_TITLE")
        AF.SetPoint(pageName, "CENTER", frame.header, "CENTER", 0, 0)
        pageName:SetJustifyH("CENTER")
        pageName:SetText(self.frameType)

        local optionsButton = AF.CreateButton(frame.header, "", addonName, 20, 20)
        AF.ApplyDefaultBackdropWithColors(optionsButton, "header")
        AF.SetPoint(optionsButton, "TOPRIGHT", -19, 0)

        optionsButton:SetTexture("OptionsIcon-Brown", {12, 12}, {"CENTER", 0, 0}, true)
        optionsButton:SetFrameLevel(frame:GetFrameLevel() + 10)
        optionsButton:SetOnClick(function()
            self.transitioning = true
            addon:openConfig()
        end)

        frame:SetScript("OnHide", function()
            self.frame = nil
            if onCloseCallback and not self.transitioning then
                onCloseCallback()
            end
        end)

        _G["InstanceLoadouts_Options"] = frame
        table.insert(UISpecialFrames, "InstanceLoadouts_Options")
        frame:Show()
    end

    local scrollFrame = AF.CreateScrollFrame(frame, nil, frame:GetWidth() - 10, frame:GetHeight() - 10, "background2")
    AF.SetPoint(scrollFrame, "TOPLEFT", frame, "TOPLEFT", 5, -5)

    local scrollContent = scrollFrame.scrollContent or scrollFrame

    local yOffset = -5

    yOffset = CreateChangelogOptions(scrollContent, yOffset)
    yOffset = CreateImportExportOptions(scrollContent, yOffset)
    yOffset = CreateCustomInstancesOptions(scrollContent, yOffset)
    yOffset = CreateConfigureLoadoutsOptions(scrollContent, yOffset)
    yOffset = CreateExtraOptions(scrollContent, yOffset)

    scrollContent:SetHeight(math.abs(yOffset))

    self.frame = frame
end

---Toggles the options window open/closed
---@param onCloseCallback function|nil Optional callback to execute when the window closes
function addon:toggleOptions(onCloseCallback)
    if addon.frame and addon.frameType == "Options" then
        addon.frame:Hide()
        addon.frame = nil
    else
        addon:openOptions(onCloseCallback)
    end
end