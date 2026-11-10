local _, Buddy = ...
local L = Buddy.L
local TB = Buddy.Tiefen
local Style = Buddy.Style
local Color = Style.Color
local GOLD, GREY, GREEN = Style.Hex(Color.gold), Style.Hex(Color.muted), Style.Hex(Color.success)
local panel, context, explanation, status
local rows, styleButtons
local WIDTH, HEIGHT = 438, 578
TB.buttons = {}

-- API-Strings und Zahlen vor jeder Verkettung prüfen (Secret Values).
local function plain(value)
    if TB.Public(value) and type(value)=="string" and value~="" then return value end
end
local function integer(value)
    if TB.Public(value) and type(value)=="number" then return value end
end

local function Label(parent, text, x, y, width, height, role, color)
    local label = Style.Text(parent, role, color)
    label:SetPoint("TOPLEFT", x, y)
    label:SetSize(width, height)
    label:SetJustifyH("LEFT"); label:SetJustifyV("TOP")
    label:SetWordWrap(true)
    label:SetText(text or "")
    return label
end

local function Button(parent, text, x, y, width, action)
    local button=CreateFrame("Button", nil, parent, text and "UIPanelButtonTemplate" or "UIPanelCloseButton")
    if text then
        Style.Button(button)
        button:SetText(text)
    else
        Style.Close(button)
    end
    button:SetSize(width, 27); button:SetPoint("TOPLEFT", x, y)
    button:SetScript("OnClick", function() if not TB.InCombat() then action() end end)
    TB.buttons[#TB.buttons+1]=button
    return button
end

local function Tooltip(owner, option)
    if TB.InCombat() or not option or not option.spell then return end
    Buddy.Foreign(Style.Tooltip(owner,"ANCHOR_LEFT"), function(t)
        t:SetSpellByID(option.spell); t:Show()
    end)
end

function TB.CreateUI()
    if panel then return end
    panel=CreateFrame("Frame","AzerothBuddyDelvesFrame",UIParent,"BackdropTemplate")
    TB.panel=panel
    panel:SetSize(WIDTH,HEIGHT); panel:SetFrameStrata("MEDIUM"); panel:SetClampedToScreen(true)
    panel:SetMovable(true); panel:EnableMouse(true)
    Style.Window(panel,78)
    Label(panel,L["AzerothBuddy · Valeera"],16,-25,350,24,"title")
    context=Label(panel,"",16,-51,WIDTH-32,26,"small")
    Button(panel,nil,WIDTH-36,-11,25,function() TB.visibility=false; panel:Hide() end)
    local drag=CreateFrame("Frame",nil,panel); drag:SetPoint("TOPLEFT",0,0); drag:SetSize(WIDTH-42,50); drag:EnableMouse(true)
    drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart",function() if not TB.InCombat() and TB.db.unlocked then panel:StartMoving() end end)
    drag:SetScript("OnDragStop",function()
        panel:StopMovingOrSizing()
        local point,_,relative,x,y=panel:GetPoint()
        TB.db.position={point,relative,x,y}
    end)
    TB.drag=drag
    styleButtons={}
    for i,key in ipairs({"relaxed","safe","fast"}) do
        styleButtons[key]=Button(panel,TB.styles[key],14+(i-1)*137,-82,133,function() TB.SetStyle(key) end)
    end
    explanation=Label(panel,"",16,-122,WIDTH-32,54,"body",Color.muted)
    rows={}
    for i,slot in ipairs(TB.order) do
        local frame=CreateFrame("Frame",nil,panel)
        frame:SetPoint("TOPLEFT",14,-177-(i-1)*74); frame:SetSize(WIDTH-28,70)
        Style.Inset(frame)
        frame.label=Label(frame,TB.labels[slot],10,-7,WIDTH-52,15,"small",Color.muted)
        frame.name=Label(frame,"",10,-24,WIDTH-52,21,"heading")
        frame.detail=Label(frame,"",10,-47,WIDTH-52,18,"small",Color.muted)
        frame:EnableMouse(true)
        frame:SetScript("OnEnter",function(self) Tooltip(self,self.option) end)
        frame:SetScript("OnLeave",Style.HideTooltip)
        frame:SetScript("OnHide",Style.HideTooltip)
        rows[i]=frame
    end
    Button(panel,L["Neu einlesen"],14,-483,245,function() TB.Refresh() end)
    Button(panel,L["Valeera öffnen"],264,-483,160,function() TB.OpenCompanion() end)
    status=Label(panel,"",16,-518,WIDTH-32,41,"body",Color.muted)
    panel:Hide()
end

function TB.Place()
    if not panel then return end
    panel:ClearAllPoints()
    local height=UIParent:GetHeight() or 1080
    local width=UIParent:GetWidth() or 1920
    panel:SetScale(math.min(TB.db.scale,(height-28)/HEIGHT,(width-28)/WIDTH))
    local p=TB.db.position
    if p then panel:SetPoint(p[1],UIParent,p[2],p[3],p[4])
    else panel:SetPoint("TOPRIGHT",UIParent,"TOPRIGHT",-310,-180); Buddy.PlaceAutomatic() end
end

function TB.CombatUI()
    if not panel then return end
    local enabled=not TB.InCombat()
    Buddy.FadeTo(panel,enabled and TB.db.alpha or TB.db.combatAlpha)
    panel:EnableMouse(enabled); TB.drag:EnableMouse(enabled)
    for _,b in ipairs(TB.buttons) do b:SetEnabled(enabled); b:EnableMouse(enabled) end
    for _,r in ipairs(rows) do
        r:EnableMouse(enabled)
        if not enabled then Style.HideTooltip(r) end
    end
end

function TB.Render()
    if not panel or not TB.player then return end
    local player,snapshot,recommendation=TB.player,TB.snapshot or {},TB.recommendation
    local className, playerName = plain(player.className), plain(player.name) or L["Unbekannt"]
    local level = integer(snapshot.level)
    context:SetText((className and className.." · " or "") .. playerName .. "\n" .. GREY
        .. (level and L["Valeera · Stufe "]..level or L["Valeera · Begleitervorräte"]) .. "|r")
    local style=TB.style
    for key,b in pairs(styleButtons) do Style.Select(b,key==style) end
    if recommendation then
        explanation:SetText(TB.styles[style] .. " · " .. (plain(recommendation.reason) or ""))
        for i,row in ipairs(recommendation.rows) do
            local frame=rows[i]
            local marker=row.match and GREEN..L["Passt"] or row.choice and GOLD..L["Ändern"] or GREY..L["Offen"]
            local rank=integer(row.choice and row.choice.rank)
            rank = rank and L[" · Rang "]..rank or ""
            frame.name:SetText((plain(row.name) or L["Unbekannt"]) .. rank)
            frame.name:SetTextColor(unpack(row.match and Color.success or Color.gold))
            local current=row.current and (plain(row.current.name) or L["Noch nicht erkannt"]) or L["Noch nicht erkannt"]
            local message
            if row.match then message=L["Passt bereits"]
            elseif row.choice then message=L["Aktuell: "]..current
            else message=(plain(snapshot.error) and L["Noch keine Live-Daten"]) or L["Nicht freigeschaltet oder nicht erkannt"] end
            frame.label:SetText(TB.labels[row.slot] .. "   " .. marker .. (row.fallback and L[" · Alternative"] or "") .. "|r")
            frame.detail:SetText(message); frame.option=row.choice or row.current
        end
        local text=plain(TB.status) or plain(snapshot.error)
        if not text then
            if recommendation.changes==0 and recommendation.missing==0 then text=L["Alles passt. Viel Spaß in der Tiefe!"]
            elseif recommendation.missing>0 then text=L["Offene Auswahl: "]..recommendation.missing..L[". Verfügbare Alternativen werden berücksichtigt."]
            else text=recommendation.changes..L[" Empfehlungen weichen ab. Bitte selbst in Valeeras Begleitervorräten auswählen."] end
        end
        local members=GetNumGroupMembers and GetNumGroupMembers()
        if integer(members) and members>=5 then text=L["Volle Fünfergruppe: Valeera begleitet dich hier nicht."]
        elseif IsInGroup and IsInGroup() then text=L["Gruppenlauf: Empfehlung ist für solo gedacht. Rollen mit deiner Gruppe abstimmen."] end
        status:SetText(plain(text) or "")
    end
    TB.CombatUI()
end

function TB.UpdateVisibility()
    if not panel then return end
    local show=TB.visibility
    if show==nil then show=TB.db.autoShow end
    panel:SetShown(TB.active and show==true)
end
