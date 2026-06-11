local addonName, addon = ...

local C = addon.Components

local changelogData = {
    {
        version = "Version 3.1",
        changes = {
            "Add Midnight Delves",
            "Remove The Ring of Valor Arena",
            "Allow overriding default talents without requiring overriding default specialization",
            "Redesigned the UI (again) as AbstractFramework maintenance has diminished",
        }
    },
    {
        version = "Version 3.0",
        changes = {
            "Updated for Midnight Pre-Patch",
            "Migrated the UI to AbstractFramework (thanks Enderneko!)",
        }
    },
    {
        version = "Version 2.1.5",
        changes = {
            "Added a timeout on reminders showing again for the same targeted NPC (default with no timeout)",
            "Fixed configs updating on deleted talent loadouts",
            "Added Manaforge Omega NPC IDs",
            "Added Season 3 Delves",
            "Loadout reminder now only appears when targeting living NPCs",
        }
    },
    {
        version = "Version 2.1.4", 
        changes = {
            "Chrome King Gallywix npcID fixed",
            "Export frame fix",
            "Fixed issue with wrongfully telling to swap talents after swapping specialization",
            "Added safety check in reminder logic"
        }
    },
    {
        version = "Version 2.1.3",
        changes = {
            "More frames fixes"
        }
    },
    {
        version = "Version 2.1.2",
        changes = {
            "Changes in the Blizzard Options panel",
            "Renamed Custom Groups to Custom Instances", 
            "Fixed frames repositioning after certain actions",
            "Fixed frames not closing properly"
        }
    },
    {
        version = "Version 2.1.1",
        changes = {
            "Added Garrison IDs to make them work as Open World"
        }
    },
    {
        version = "Version 2.1.0",
        changes = {
            "Added support for Simple Addon Manager. Does not currently support the import/export feature."
        }
    },
    {
        version = "Version 2.0.2",
        changes = {
            "Fixed issue when entering a raid that is not being tracked",
            "Fixed issue caused when saving, deleting or changing gearsets",
            "Fixed a bug which occured if a player removed an encounter from custom groups while being inside the instance of that encounter",
            "Changed name of button in reminder from Options to Loadouts Config",
            "Fixed Loadouts Config button in reminder for dungeons and raids"
        }
    },
    {
        version = "Version 2.0.1",
        changes = {
            "Fixed Raid Loadouts"
        }
    },
    {
        version = "Version 2.0.0",
        changes = {
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
            "Import now includes custom groups and will use appropiate Locale names"
        }
    },
    {
        version = "Version 1.0.1",
        changes = {
            "Added Better Addon List as an Addon Manager. Does not currently support the import/export feature.",
            "Swapping between Addon Managers will reset the addon loadouts each time"
        }
    },
    {
        version = "Version 1.0.0",
        changes = {
            "Added option to automatically show changelog on new update (Enabled by default)",
            "Added feature to import Addons/Talents loadouts (/il import)",
            "Added feature to Export Addons/Talents loadouts (/il export)",
            "Importing/Exporting addon loadouts requires an Addon manager",
            "Importing/Exporting talents loadouts requires a Talent manager",
            "Restructure of codebase"
        }
    },
    {
        version = "Version 0.1.0",
        changes = {
            "Added Changelog window (/il log)",
            "Added loadouts for Delves",
            "Added loadouts for Arenas", 
            "Added loadouts for Battlegrounds",
            "Added scroll container to options config window",
            "Added scroll container to reminder window",
            "Fixed bug with Operation: Mechagon - Workshop not showing loadout when entering dungeon",
            "Ensured that only one GUI element can be open at a time"
        }
    },
    {
        version = "Version 0.0.1",
        changes = {
            "Fixed a bug when turning off override spec but still having override talents on where it would choose the talent override instead of the default"
        }
    },
    {
        version = "Version 0.0.0",
        changes = {
            "Initial release"
        }
    }
}

function addon:GetChangelog()
    return changelogData
end

---Creates the changelog content with a card for each version
---@param parent table The parent frame to add content to
local function CreateChangelogContent(parent)
    local scroller = C:CreateTabScroller(parent)

    -- pre-size cards so AddLabel measures wrapped text against the final width
    local cardWidth = math.max(220, parent:GetWidth() - 24)

    for _, versionData in ipairs(changelogData) do
        local card = C:CreateCard(scroller, versionData.version)
        card:SetWidth(cardWidth)

        local changesStr = "• " .. table.concat(versionData.changes, "\n• ")
        card:AddLabel(changesStr)

        scroller:AddCard(card)
    end

    scroller:Commit()
end

---Opens the changelog window
---@param onCloseCallback function|nil Optional callback to execute when the window closes
function addon:openChangelog(onCloseCallback)
    local _, content = self.UI.AcquireWindow("Changelog", {
        width = 560,
        height = 420,
        icon = addon.icon,
        onHide = function()
            if onCloseCallback then
                onCloseCallback()
            end
        end,
    })

    CreateChangelogContent(content)
end

---Shows the changelog window (for compatibility)
---@param onCloseCallback function|nil Optional callback to execute when the window closes
function addon:showChangelog(onCloseCallback)
    self:openChangelog(onCloseCallback)
end

---Toggles the changelog window open/closed
function addon:toggleChangelog()
    if addon.frame and addon.frameType == "Changelog" then
        addon.frame:Hide()
        addon.frame = nil
    else
        addon:openChangelog()
    end
end