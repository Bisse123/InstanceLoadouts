local addonName, addon = ...

local C = addon.Components

local externalOrder = {
    "Gearset",
    "Specialization",
    "Talents",
    "Addons",
}

local instanceTypeOrder = {
    "Dungeon",
    "Raid",
    "Delve",
    "Arena",
    "Battleground",
    "Open World",
}

addon.ConfigView = {
    ["instanceType"] = instanceTypeOrder[1],
    ["instance"] = -1,
    ["encounter"] = -1,
}

local LIST_PANEL_W = 170
local LIST_ITEM_H = 26

---Ensures a loadout table exists in the database for the given key/id
---@param dbKey string The loadouts table key (e.g. "Dungeon", "2769 Encounter")
---@param id number The instance/encounter ID
local function EnsureLoadout(dbKey, id)
    local loadouts = addon.db.char.loadouts
    if not loadouts[dbKey] then
        loadouts[dbKey] = {}
    end
    if not loadouts[dbKey][id] then
        loadouts[dbKey][id] = {
            Specialization = -1,
            ["Override Default Specialization"] = false,
            ["Override Default Talents"] = false,
            Gearset = 0,
            Talents = -1,
            Addons = ""
        }
    end
end

---Builds sorted dropdown items from an externalInfo table ("None" first)
---@param info table Map of value -> display name
---@return table items List of {text, value} dropdown items
local function BuildDropdownItems(info)
    local items = {}
    for key, value in pairs(info) do
        table.insert(items, {text = value, value = key})
    end
    table.sort(items, function(a, b)
        if (a.value == -1) ~= (b.value == -1) then
            return a.value == -1
        end
        return tostring(a.text) < tostring(b.text)
    end)
    return items
end

---Replaces the inner content frame of a host so it can be rebuilt
---@param host table The host frame
---@return table inner A fresh frame filling the host
local function ResetInner(host)
    if host.inner then
        host.inner:Hide()
        host.inner:SetParent(nil)
    end
    local inner = CreateFrame("Frame", nil, host)
    inner:SetAllPoints(host)
    host.inner = inner
    return inner
end

---Creates a scrollable selection list panel
---@param parent table The parent frame
---@return table panel The list panel with SetItems/Select methods
local function CreateListPanel(parent)
    local theme = addon.Theme

    local panel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    C.SetBackdrop(panel, theme.bg.med, theme.border.color)

    local scrollChild = C:CreateTabScroller(panel)

    local buttons = {}

    function panel:Select(id)
        if self._selected == id then return end
        self._selected = id
        for _, btn in ipairs(buttons) do
            local isSelected = btn.id == id
            if isSelected then
                btn.indicator:Show()
                btn.bg:SetColorTexture(theme.accent.r * 0.15, theme.accent.g * 0.15, theme.accent.b * 0.15, 1)
                btn.label:SetTextColor(1, 1, 1, 1)
            else
                btn.indicator:Hide()
                btn.bg:SetColorTexture(0, 0, 0, 0)
                local color = theme.text.secondary
                btn.label:SetTextColor(color.r, color.g, color.b, 1)
            end
        end
        if self._onSelect then self._onSelect(id) end
    end

    function panel:SetItems(items, selectedID, onSelect)
        for _, btn in ipairs(buttons) do btn:Hide() end
        wipe(buttons)
        self._selected = nil
        self._onSelect = onSelect

        for i, item in ipairs(items) do
            local btn = CreateFrame("Button", nil, scrollChild)
            btn:SetHeight(LIST_ITEM_H)
            btn:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -(i - 1) * LIST_ITEM_H)
            btn:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", 0, -(i - 1) * LIST_ITEM_H)
            btn.id = item.id

            local bg = btn:CreateTexture(nil, "ARTWORK")
            bg:SetAllPoints()
            bg:SetColorTexture(0, 0, 0, 0)
            btn.bg = bg

            local indicator = btn:CreateTexture(nil, "OVERLAY")
            indicator:SetWidth(3)
            indicator:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
            indicator:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, 0)
            indicator:SetColorTexture(theme.accent.r, theme.accent.g, theme.accent.b, 1)
            indicator:Hide()
            btn.indicator = indicator

            local label = btn:CreateFontString(nil, "OVERLAY")
            C.ApplyFont(label, "normal")
            label:SetPoint("LEFT", btn, "LEFT", 8, 0)
            label:SetPoint("RIGHT", btn, "RIGHT", -4, 0)
            label:SetJustifyH("LEFT")
            label:SetWordWrap(false)
            label:SetText(item.text)
            local color = theme.text.secondary
            label:SetTextColor(color.r, color.g, color.b, 1)
            btn.label = label

            btn:SetScript("OnEnter", function()
                if panel._selected ~= btn.id then bg:SetColorTexture(1, 1, 1, 0.04) end
            end)
            btn:SetScript("OnLeave", function()
                if panel._selected ~= btn.id then bg:SetColorTexture(0, 0, 0, 0) end
            end)
            btn:SetScript("OnClick", function() panel:Select(btn.id) end)

            table.insert(buttons, btn)
        end

        scrollChild:SetHeight(#items * LIST_ITEM_H)

        local found = false
        for _, item in ipairs(items) do
            if item.id == selectedID then
                found = true
                break
            end
        end
        local target = found and selectedID or (items[1] and items[1].id)
        if target ~= nil then
            self:Select(target)
        end
    end

    return panel
end

---Populates the options area with configuration options for a loadout
---@param host table The host frame to populate
---@param instanceTypeValue string The loadouts table key (e.g. "Dungeon", "2769 Encounter")
---@param instanceValue number The instance/encounter ID
function addon:populateOptionsArea(host, instanceTypeValue, instanceValue)
    if not host then return end

    local theme = addon.Theme

    local actualInstanceValue = instanceValue
    if type(instanceValue) == "table" and instanceValue.instanceID then
        actualInstanceValue = instanceValue.instanceID
    elseif type(instanceValue) == "table" and instanceValue.id then
        actualInstanceValue = instanceValue.id
    end

    local dbLoadouts = self.db.char.loadouts
    local dbLoadout = dbLoadouts[instanceTypeValue][actualInstanceValue]

    local inner = ResetInner(host)
    local scroller = C:CreateTabScroller(inner)

    -- pre-size message cards so AddLabel measures wrapped text against the final width
    local cardWidth = math.max(120, host:GetWidth() - 24)

    if strfind(instanceTypeValue, "Encounter") and actualInstanceValue ~= -1 then
        local messageCard = C:CreateCard(scroller, "Boss Loadouts Unavailable")
        messageCard:SetWidth(cardWidth)
        messageCard:AddLabel("Midnight's secret values prevent the addon from detecting which boss you are targeting, even outside of combat.", theme.text.muted)
        messageCard:AddLabel("Only the Default loadout is available for raids.\n\nPlease select \"Default\" to configure raid settings.")
        scroller:AddCard(messageCard)

        local supportCard = C:CreateCard(scroller, "Support")
        supportCard:SetWidth(cardWidth)
        supportCard:AddLabel("If you have any ideas on how to get this working, please reach out on GitHub or Discord (@lolswirl)", theme.text.muted)
        scroller:AddCard(supportCard)

        scroller:Commit()
        return
    end

    for _, type in ipairs(externalOrder) do
        local info = self.externalInfo[type]

        if next(info) then
            local card = C:CreateCard(scroller, type)
            local items = BuildDropdownItems(info)

            if actualInstanceValue == -1 then
                local dropdown
                if type == "Specialization" then
                    dropdown = C:CreateDropdown(card, nil, items, dbLoadout[type], function(value)
                        dbLoadout[type] = value
                        dbLoadout["Talents"] = -1
                        addon:openConfig()
                    end)
                elseif type == "Talents" then
                    dropdown = C:CreateDropdown(card, nil, items, dbLoadout[type], function(value)
                        dbLoadout[type] = value
                    end)
                    dropdown:SetEnabled(dbLoadout.Specialization ~= -1)
                else
                    dropdown = C:CreateDropdown(card, nil, items, dbLoadout[type], function(value)
                        dbLoadout[type] = value
                    end)
                end
                card:AddWidget(dropdown, -8, 34)
            else
                local overrideKey = "Override Default " .. type
                local toggle
                local dropdown

                if type == "Specialization" then
                    toggle = C:CreateToggle(card, overrideKey, dbLoadout[overrideKey], function(checked)
                        dbLoadout[overrideKey] = checked
                        addon:openConfig()
                    end)
                    dropdown = C:CreateDropdown(card, nil, items,
                        dbLoadout[overrideKey] and dbLoadout[type] or dbLoadouts[instanceTypeValue][-1][type],
                        function(value)
                            dbLoadout[type] = value
                            dbLoadout["Talents"] = -1
                            addon:openConfig()
                        end)
                    dropdown:SetEnabled(dbLoadout[overrideKey])
                elseif type == "Talents" then
                    toggle = C:CreateToggle(card, overrideKey, dbLoadout[overrideKey], function(checked)
                        dbLoadout[overrideKey] = checked
                        addon:openConfig()
                    end)
                    dropdown = C:CreateDropdown(card, nil, items,
                        dbLoadout[overrideKey] and dbLoadout[type] or dbLoadouts[instanceTypeValue][-1][type],
                        function(value)
                            dbLoadout[type] = value
                        end)
                    dropdown:SetEnabled(dbLoadout[overrideKey])
                else
                    toggle = C:CreateToggle(card, overrideKey, dbLoadout[overrideKey], function(checked)
                        dbLoadout[overrideKey] = checked
                        addon:openConfig()
                    end)
                    dropdown = C:CreateDropdown(card, nil, items,
                        dbLoadout[overrideKey] and dbLoadout[type] or dbLoadouts[instanceTypeValue][-1][type],
                        function(value)
                            dbLoadout[type] = value
                        end)
                    dropdown:SetEnabled(dbLoadout[overrideKey])
                end

                card:AddWidget(toggle, nil, 26)
                card:AddWidget(dropdown, -8, 34)
            end

            scroller:AddCard(card)
        end
    end

    if strfind(instanceTypeValue, "Encounter") then
        local raidInstanceIDStr = strsplit(" ", instanceTypeValue)
        local raidInstanceID = tonumber(raidInstanceIDStr)
        local npcIDs = ""
        local journalInstance
        local journalEncounter
        for journalInstanceID, journalEncounterIDs in pairs(self.db.global.journalIDs.Raid) do
            local _, _, _, _, _, _, _, _, _, instanceID = EJ_GetInstanceInfo(journalInstanceID)
            if instanceID == raidInstanceID then
                journalInstance = journalInstanceID
                for journalEncounterID, journalNpcIDs in pairs(journalEncounterIDs) do
                    local _, _, _, _, _, _, encounterID = EJ_GetEncounterInfo(journalEncounterID)
                    if encounterID == instanceValue then
                        journalEncounter = journalEncounterID
                        for idx, npcID in ipairs(journalNpcIDs) do
                            if idx == 1 then
                                npcIDs = npcID
                            else
                                npcIDs = npcIDs .. ", " .. npcID
                            end
                        end
                        break
                    end
                end
                break
            end
        end
        if journalInstance and journalEncounter then
            local card = C:CreateCard(scroller, "NPC IDs")

            local npcIDsEditBox = C:CreateEditBox(card, "Comma separated NPC IDs", npcIDs, function(text)
                local rawNpcIDs = {strsplit(",", text)}
                local newNpcIDs = {}
                for _, npcID in ipairs(rawNpcIDs) do
                    local trimmedID = npcID:gsub("^%s*(.-)%s*$", "%1")
                    if trimmedID ~= "" then
                        table.insert(newNpcIDs, trimmedID)
                    end
                end
                self.db.global.journalIDs.Raid[journalInstance][journalEncounter] = newNpcIDs
                for _, instanceInfo in ipairs(self.instanceGroups.Raid) do
                    if instanceInfo.instanceID == raidInstanceID then
                        for _, encounterInfo in ipairs(instanceInfo.encounterIDs) do
                            if encounterInfo.encounterID == instanceValue then
                                encounterInfo.npcIDs = newNpcIDs
                                break
                            end
                        end
                        break
                    end
                end
            end)
            card:AddWidget(npcIDsEditBox, nil, 36)

            scroller:AddCard(card)
        end
    end

    scroller:Commit()
end

---Checks the talent manager for the effective specialization of a loadout
---@param dbKey string The loadouts table key
---@param id number The instance/encounter ID
local function CheckManagersForLoadout(dbKey, id)
    local dbLoadouts = addon.db.char.loadouts
    local specializationSet = dbLoadouts[dbKey][id].Specialization
    local overrideSpecializationSet = dbLoadouts[dbKey][id]["Override Default Specialization"]
    if not overrideSpecializationSet then
        specializationSet = dbLoadouts[dbKey][-1].Specialization
    end
    if specializationSet ~= -1 then
        addon:checkTalentManager(specializationSet)
    end
end

---Populates the middle list panel with raid encounters
---@param panel table The list panel
---@param optionsHost table The options area frame
---@param instanceTypeValue string The instance type ("Raid")
---@param instanceValue number The raid instance ID
local function PopulateEncounterList(panel, optionsHost, instanceTypeValue, instanceValue)
    local encounters = {}
    for _, instanceInfo in ipairs(addon.instanceGroups[instanceTypeValue]) do
        if instanceInfo.instanceID == instanceValue then
            for _, encounterInfo in ipairs(instanceInfo.encounterIDs) do
                table.insert(encounters, {id = encounterInfo.encounterID, text = encounterInfo.encounterName})
            end
            break
        end
    end

    panel:SetItems(encounters, addon.ConfigView.encounter, function(encounterValue)
        addon.ConfigView.encounter = encounterValue

        local instanceEncounter = instanceValue .. " Encounter"
        EnsureLoadout(instanceEncounter, -1)
        EnsureLoadout(instanceEncounter, encounterValue)
        CheckManagersForLoadout(instanceEncounter, encounterValue)

        addon:populateOptionsArea(optionsHost, instanceEncounter, encounterValue)
    end)
end

---Populates the middle list panel with the dungeons of a tier
---@param panel table The list panel
---@param optionsHost table The options area frame
---@param instanceTypeValue string The instance type ("Dungeon")
---@param tierValue number The tier ID
local function PopulateDungeonList(panel, optionsHost, instanceTypeValue, tierValue)
    local dungeonInstances = {}
    for _, instanceInfo in pairs(addon.instanceGroups[instanceTypeValue]) do
        if instanceInfo.tierID == tierValue then
            for _, instanceData in pairs(instanceInfo.instanceIDs) do
                local instanceID = instanceData.instanceID or instanceData.id
                local instanceName = instanceData.instanceName or instanceData.text or instanceData.name

                if not instanceName and instanceID then
                    instanceName = addon.ConvertIDToName[instanceID]
                end

                if not instanceName then
                    instanceName = "Unknown Instance"
                end

                table.insert(dungeonInstances, {id = instanceID, text = instanceName})
            end
            break
        end
    end

    panel:SetItems(dungeonInstances, addon.ConfigView.encounter, function(instanceID)
        addon.ConfigView.encounter = instanceID

        EnsureLoadout(instanceTypeValue, -1)
        EnsureLoadout(instanceTypeValue, instanceID)
        CheckManagersForLoadout(instanceTypeValue, instanceID)

        addon:populateOptionsArea(optionsHost, instanceTypeValue, instanceID)
    end)
end

---Builds the panel layout and instance list for an instance type tab
---@param host table The tab content frame
---@param instanceTypeValue string The instance type
local function BuildTypeContent(host, instanceTypeValue)
    local theme = addon.Theme
    local pad = theme.padding.small

    local inner = ResetInner(host)

    local showMiddlePanel = instanceTypeValue == "Raid" or instanceTypeValue == "Dungeon"

    local instancePanel = CreateListPanel(inner)
    instancePanel:SetWidth(LIST_PANEL_W)
    instancePanel:SetPoint("TOPLEFT", inner, "TOPLEFT", pad, -pad)
    instancePanel:SetPoint("BOTTOMLEFT", inner, "BOTTOMLEFT", pad, pad)

    local middlePanel
    if showMiddlePanel then
        middlePanel = CreateListPanel(inner)
        middlePanel:SetWidth(LIST_PANEL_W)
        middlePanel:SetPoint("TOPLEFT", instancePanel, "TOPRIGHT", pad, 0)
        middlePanel:SetPoint("BOTTOMLEFT", instancePanel, "BOTTOMRIGHT", pad, 0)
    end

    local optionsHost = CreateFrame("Frame", nil, inner)
    optionsHost:SetPoint("TOPLEFT", middlePanel or instancePanel, "TOPRIGHT", pad, 0)
    optionsHost:SetPoint("BOTTOMRIGHT", inner, "BOTTOMRIGHT", -pad, pad)

    local instances = {}
    for _, instanceInfo in pairs(addon.instanceGroups[instanceTypeValue]) do
        if instanceInfo.instanceID then
            table.insert(instances, {id = instanceInfo.instanceID, text = instanceInfo.instanceName})
        else
            table.insert(instances, {id = instanceInfo.tierID, text = instanceInfo.tierName})
        end
    end

    instancePanel:SetItems(instances, addon.ConfigView.instance, function(instanceValue)
        addon.ConfigView.instance = instanceValue

        if instanceTypeValue == "Raid" then
            PopulateEncounterList(middlePanel, optionsHost, instanceTypeValue, instanceValue)
        elseif instanceTypeValue == "Dungeon" then
            PopulateDungeonList(middlePanel, optionsHost, instanceTypeValue, instanceValue)
        else
            EnsureLoadout(instanceTypeValue, -1)
            EnsureLoadout(instanceTypeValue, instanceValue)
            CheckManagersForLoadout(instanceTypeValue, instanceValue)

            addon:populateOptionsArea(optionsHost, instanceTypeValue, instanceValue)
        end
    end)
end

---Opens the main configuration window
function addon:openConfig()
    if not GetSpecialization() or GetSpecialization() == 5 then
        self:Print("No specialization found")
        return
    end
    if self.manager:getAddonManager() then
        self:checkAddonManager()
    end

    local _, content = self.UI.AcquireWindow("Config", {
        width = 760,
        height = 500,
        icon = addon.icon,
        pageTitle = "Config",
        onGear = function()
            self.transitioning = true
            addon:toggleOptions(function()
                self.transitioning = nil
                addon:checkIfIsTrackedInstance()
            end)
        end,
        onHide = function()
            if not self.transitioning then
                addon:checkIfIsTrackedInstance()
            end
        end,
    })

    if not self.ConfigView.instanceType or self.ConfigView.instanceType == "" then
        self.ConfigView.instanceType = instanceTypeOrder[1]
    end
    local savedInstanceType = self.ConfigView.instanceType
    local savedInstance = self.ConfigView.instance
    local savedEncounter = self.ConfigView.encounter

    local tabs = {}
    for _, instanceType in ipairs(instanceTypeOrder) do
        table.insert(tabs, {
            key = instanceType,
            title = instanceType,
            onSelect = function(tabContent)
                addon.ConfigView.instanceType = instanceType
                BuildTypeContent(tabContent, instanceType)
            end,
        })
    end

    -- CreateVerticalTabs auto-selects the first tab, which overwrites the
    -- saved view state; restore it before selecting the saved tab
    local _, _, controller = C.CreateVerticalTabs(content, tabs)
    self.ConfigView.instance = savedInstance
    self.ConfigView.encounter = savedEncounter
    controller.Select(savedInstanceType)

    self.transitioning = nil
end

---Toggles the main configuration window open/closed
function addon:toggleConfig()
    if addon.frame and addon.frameType == "Config" then
        addon.frame:Hide()
    else
        addon:openConfig()
    end
end
