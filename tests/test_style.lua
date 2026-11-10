local function loadStyle(name, locale)
    GetLocale = function() return locale end
    local addon = {}
    assert(loadfile("Style.lua"))(name, addon)
    return addon.Style
end

local function newFont(setFont)
    return {
        SetFont = setFont or function(self, path, size, flags)
            self.path, self.size, self.flags = path, size, flags
            return true
        end,
        SetTextColor = function(self, ...) self.color = {...} end,
    }
end

local clientFont = "Fonts\\ClientFont.ttf"
GameFontNormal = {GetFont = function() return clientFont end}
local style = loadStyle("AzerothBuddy", "deDE")
local attempts = 0
local fallback = newFont(function(self, path)
    if path:find("Expressway", 1, true) then
        attempts = attempts + 1
        error("Font file unavailable")
    end
    self.path = path
    return true
end)
style.Font(fallback, "body")
style.Font(fallback, "small")
assert(fallback.path == clientFont and attempts == 1, "Cache the localized fallback after a missing font")

local available = loadStyle("AzerothBuddyUI", "deDE")
local regular = newFont()
available.Font(regular, "heading", "OUTLINE")
assert(regular.path == "Interface\\AddOns\\AzerothBuddyUI\\Media\\Expressway.ttf")
assert(regular.size == 15 and regular.flags == "OUTLINE")

local localized = loadStyle("AzerothBuddy", "koKR")
localized.Font(regular, "body")
assert(regular.path == clientFont, "Keep the client font for scripts outside Expressway's coverage")

CreateFont = function() return newFont() end
local button = {}
for _, state in ipairs({"Normal", "Highlight", "Disabled"}) do
    button["Set" .. state .. "FontObject"] = function(self, font) self[state] = font end
end
available.Button(button)
assert(button.Normal.path:find("Expressway", 1, true))
assert(button.Highlight.color[2] == available.Color.gold[2] and button.Disabled.color[1] == available.Color.disabled[1])

function hooksecurefunc(frame, method, after)
    local original = assert(frame[method])
    frame[method] = function(self, ...)
        original(self, ...)
        after(self)
    end
end

local creations = 0
InCombatLockdown = function() return false end
function CreateFrame(kind, name, _, template)
    assert(kind == "GameTooltip" and name == "AzerothBuddyDesignTooltip" and template == "GameTooltipTemplate")
    creations = creations + 1
    local function addLine(self)
        self.lines = self.lines + 1
        local line = "TextLeft" .. self.lines
        _G[name .. line] = newFont()
    end
    return {
        SetOwner = function(self, owner) self.owner = owner end,
        GetOwner = function(self) return self.owner end,
        ClearLines = function(self) self.lines = 0 end,
        NumLines = function(self) return self.lines end,
        AddLine = addLine, AddDoubleLine = addLine, SetText = addLine,
        IsShown = function(self) return not self.hidden end,
        RefreshData = function(self) self.refreshed = true end,
        HookScript = function(self, event, callback) self[event] = callback end,
        Hide = function(self) self.hidden = true end,
    }
end

local first, second = {}, {}
local tooltip = style.Tooltip(first)
tooltip:AddLine("Überschrift")
tooltip:AddLine("Erklärung")
assert(AzerothBuddyDesignTooltipTextLeft1.size == 15)
assert(AzerothBuddyDesignTooltipTextLeft2.size == 13)
tooltip.shouldRefreshData = true
tooltip:OnEvent("TOOLTIP_DATA_UPDATE")
assert(tooltip.refreshed, "Refresh late Blizzard tooltip data through its event")
assert(style.Tooltip(second) == tooltip and tooltip:NumLines() == 0 and creations == 1)
style.HideTooltip(first)
assert(not tooltip.hidden, "Leaving an earlier owner must not hide the current tooltip")
style.HideTooltip(second)
assert(tooltip.hidden)

print("PASS: optional font, fallback, native button font states and private tooltip ownership")
