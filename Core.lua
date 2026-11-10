local addonName, Buddy = ...
local L = Buddy.L
Buddy.Tiefen = {}
Buddy.modules = {
    {key="characters", name=L["Charaktere"], loader="LoadCharacters", command="ALTM"},
    {key="delves", name=L["Valeera (Tiefenbegleiter)"], loader="LoadDelves", command="TIEFENBEGLEITER"},
    {key="omnium", name=L["Omniumfoliant"], loader="LoadOmnium", command="AZEROTHBUDDYOMNIUM"},
    {key="transmog", name=L["Dungeon-Transmog"], loader="LoadTransmog", command="AZEROTHBUDDYTRANSMOG"},
    {key="meters", name=L["Schaden und Heilung"], loader="LoadMeters", command="AZEROTHBUDDYMETERS"},
    {key="bars", name=L["Aktionsleisten"], loader="LoadBars", command="AZEROTHBUDDYBARS", argument="status"},
}
function Buddy.Foreign(frame, action)
    if (issecretvalue and issecretvalue(frame)) or not frame then return false end
    return pcall(function()
        local forbidden = frame:IsForbidden()
        if (issecretvalue and issecretvalue(forbidden)) or forbidden then error("forbidden") end
        return action(frame)
    end)
end
function Buddy.Message(text)
    local style=Buddy.Style
    print(style.Hex(style.Color.gold).."AzerothBuddy:|r "..text)
end
function Buddy.OpenModule(module)
    if module.key ~= "bars" and Buddy.panel then Buddy.panel:Hide() end
    if not Buddy.loaded[module.key] then Buddy.Message(L["Modul aktivieren und die Oberfläche neu laden."]); return end
    if module.key == "bars" then
        if Buddy.Bars and Buddy.Bars.SetAutomatic then
            Buddy.Bars.SetAutomatic(not Buddy.db.bars.automatic)
        end
    else
        local handler = SlashCmdList[module.command]
        if handler then
            handler(module.argument or "")
        end
    end
end
function Buddy.Toggle()
    if not Buddy.panel then
        local style = Buddy.Style
        local panel = CreateFrame("Frame", "AzerothBuddyPanel", UIParent, "BackdropTemplate")
        Buddy.panel = panel
        local barsMenu = Buddy.loaded.bars and Buddy.Bars and Buddy.Bars.BuildMenu
        local baseHeight = 158 + #Buddy.modules * 43
        panel:SetSize(390, baseHeight)
        panel:SetPoint("CENTER")
        panel:SetFrameStrata("DIALOG")
        panel:SetClampedToScreen(true)
        panel:SetMovable(true)
        panel:EnableMouse(true)
        panel:RegisterForDrag("LeftButton")
        panel:SetScript("OnDragStart", panel.StartMoving)
        panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
        style.Window(panel,66)
        local title = style.Text(panel,"title")
        title:SetPoint("TOPLEFT",style.Spacing.panel,-25); title:SetText("AzerothBuddy")
        local sub = style.Text(panel,"small",style.Color.muted)
        sub:SetPoint("TOPLEFT",style.Spacing.panel,-44); sub:SetText(L["Dein Begleiter durch Azeroth"])
        local close = style.Close(CreateFrame("Button",nil,panel,"UIPanelCloseButton"))
        close:SetPoint("TOPRIGHT",-3,-3)
        for index,module in ipairs(Buddy.modules) do
            local entry = module
            local check = CreateFrame("CheckButton",nil,panel,"UICheckButtonTemplate")
            style.Check(check)
            check:SetSize(28,28); check:SetPoint("TOPLEFT",19,-76-(index-1)*43)
            check:SetChecked(Buddy.db.enabled[entry.key])
            check:SetScript("OnClick",function(self)
                Buddy.db.enabled[entry.key] = self:GetChecked() and true or false
                Buddy.Message(L["Modulauswahl gespeichert. Mit /reload anwenden."])
            end)
            local button = style.Button(CreateFrame("Button",nil,panel,"UIPanelButtonTemplate"))
            button:SetSize(312,30); button:SetPoint("TOPLEFT",55,-76-(index-1)*43)
            if entry.key=="bars" then
                if Buddy.loaded.bars and Buddy.Bars then Buddy.Bars.menuButton=button end
                button:SetText(Buddy.loaded.bars and Buddy.Bars and Buddy.Bars.RowText and Buddy.Bars.RowText()
                    or L["Aktionsleisten · Modul aus"])
                button:SetScript("OnClick",function() Buddy.OpenModule(entry) end)
            else
                button:SetText(entry.name .. ((entry.key=="meters") and L[" ein / aus"] or L[" öffnen"]))
                button:SetScript("OnClick",function() Buddy.OpenModule(entry) end)
            end
        end
        local hintTop = -83-#Buddy.modules*43
        local hint = style.Text(panel,"small",style.Color.muted)
        hint:SetWidth(346)
        hint:SetJustifyH("LEFT")
        hint:SetWordWrap(true)
        hint:SetText(L["Häkchen: Modul beim Start laden. Änderungen mit /reload anwenden. Tiefenberater nur innerhalb einer Tiefe. Aktionsleisten-Vorlagen gelten je Klasse und Spezialisierung."])
        local hintGap = 16
        local function fitFooter(menuHeight)
            local hintBottom = -hintTop + (menuHeight > 0 and menuHeight + hintGap or 0)
                + (hint:GetStringHeight() or 0)
            local minimum = baseHeight + (menuHeight > 0 and menuHeight + 24 or 0)
            -- Keep eight points between the text and the 36-point reload area.
            panel:SetHeight(math.max(minimum, math.ceil(hintBottom + 44)))
        end
        if barsMenu then
            local height = Buddy.Bars.BuildMenu(panel,hintTop,fitFooter)
            hint:SetPoint("TOPLEFT",Buddy.Bars.menu,"BOTTOMLEFT",0,-hintGap)
            fitFooter(height)
        else
            hint:SetPoint("TOPLEFT",22,hintTop)
            fitFooter(0)
        end
        local reload = style.Button(CreateFrame("Button",nil,panel,"UIPanelButtonTemplate"))
        reload:SetSize(200,24); reload:SetPoint("BOTTOM",0,12)
        reload:SetText(L["Oberfläche neu laden"])
        reload:SetScript("OnClick",function()
            if InCombatLockdown() then Buddy.Message(L["Bitte das Kampfende abwarten."]); return end
            ReloadUI()
        end)
        UISpecialFrames[#UISpecialFrames+1] = "AzerothBuddyPanel"
    else Buddy.panel:SetShown(not Buddy.panel:IsShown()) end
end
function Buddy.CreateMinimap()
    local style = Buddy.Style
    local button = CreateFrame("Button","AzerothBuddyMinimapButton",Minimap)
    button:SetSize(32,32); button:SetFrameStrata("MEDIUM")
    local icon = button:CreateTexture(nil,"ARTWORK")
    icon:SetPoint("TOPLEFT",3,-3); icon:SetPoint("BOTTOMRIGHT",-3,3)
    icon:SetTexture("Interface\\AddOns\\AzerothBuddy\\Media\\BuddyIcon")
    local ring = button:CreateTexture(nil,"OVERLAY")
    ring:SetSize(52,52); ring:SetPoint("TOPLEFT",0,0)
    ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    ring:SetVertexColor(unpack(style.Color.gold))
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    local function place()
        Buddy.Foreign(Minimap, function(map)
        local width, height = map:GetWidth(), map:GetHeight()
        if (issecretvalue and (issecretvalue(width) or issecretvalue(height)))
            or type(width)~="number" or type(height)~="number" then return end
        local angle = math.rad(Buddy.db.minimap.angle)
        button:ClearAllPoints()
        button:SetPoint("CENTER",Minimap,"CENTER",math.cos(angle)*(width/2+8),math.sin(angle)*(height/2+8))
        end)
    end
    button:RegisterForClicks("LeftButtonUp","RightButtonUp")
    button:SetScript("OnClick",function(_,mouse)
        if mouse=="RightButton" then Buddy.OpenModule(Buddy.modules[1]) else Buddy.Toggle() end
    end)
    button:RegisterForDrag("LeftButton")
    button:SetScript("OnDragStart",function(self)
        self:SetScript("OnUpdate",function()
            Buddy.Foreign(Minimap, function(map)
            local x,y = GetCursorPosition()
            local cx,cy = Minimap:GetCenter()
            local scale = Minimap:GetEffectiveScale()
            for _,value in ipairs({x,y,cx,cy,scale}) do
                if (issecretvalue and issecretvalue(value)) or type(value)~="number" then return end
            end
            if not x or not y or not cx or not cy or not scale or scale<=0 then return end
            Buddy.db.minimap.angle = math.deg(math.atan2(y/scale-cy,x/scale-cx))
            place()
            end)
        end)
    end)
    button:SetScript("OnDragStop",function(self) self:SetScript("OnUpdate",nil) end)
    button:SetScript("OnEnter",function(self)
        local tooltip = style.Tooltip(self,"ANCHOR_LEFT")
        if not tooltip then return end
        local color = style.Color
        tooltip:AddLine("AzerothBuddy",unpack(color.gold,1,3))
        tooltip:AddLine(L["Linksklick: Zentrale"],unpack(color.text,1,3))
        tooltip:AddLine(L["Rechtsklick: Charaktere"],unpack(color.text,1,3))
        tooltip:AddLine(L["Ziehen: Position ändern"],unpack(color.muted,1,3))
        tooltip:Show()
    end)
    button:SetScript("OnLeave",style.HideTooltip)
    button:SetScript("OnHide",style.HideTooltip)
    place()
end

-- Install a per-frame callback only while opacity is actually changing.
function Buddy.FadeTo(frame,target)
    if not frame or frame.buddyAlphaTarget==target then return end
    frame.buddyAlphaTarget=target
    frame:SetScript("OnUpdate",function(self,elapsed)
        local current=self:GetAlpha()
        local goal=self.buddyAlphaTarget
        if math.abs(current-goal)<.003 then
            self:SetAlpha(goal);self:SetScript("OnUpdate",nil)
        else self:SetAlpha(current+(goal-current)*math.min(1,elapsed*10)) end
    end)
end
