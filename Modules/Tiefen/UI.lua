local _, Buddy = ...
local TB = Buddy.Tiefen
local GOLD, WHITE, GREY = "|cffffd100", "|cfff1eee6", "|cffaaa79f"
local GREEN, AMBER = "|cff85d9a0", "|cffffb66b"
local panel, title, context, explanation, status
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

local function Label(parent, text, x, y, width, height, font)
    local label = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
    label:SetPoint("TOPLEFT", x, y)
    label:SetSize(width, height)
    label:SetJustifyH("LEFT"); label:SetJustifyV("TOP")
    label:SetWordWrap(true)
    label:SetShadowColor(0,0,0,1); label:SetShadowOffset(1,-1)
    label:SetText(text or "")
    return label
end

local function Button(parent, text, x, y, width, action)
    local button=CreateFrame("Button", nil, parent, text=="×" and "UIPanelCloseButton" or "UIPanelButtonTemplate")
    if text~="×" then Buddy.Style.Button(button) end
    button:SetSize(width, 27); button:SetPoint("TOPLEFT", x, y)
    local bg=button:CreateTexture(nil,"BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(1,.8,.4,.07)
    button.bg=bg
    button.text=Label(button, text=="×" and "" or text, 6, -6, width-12, 18, "GameFontNormal")
    button:SetScript("OnClick", function() if not TB.InCombat() then action() end end)
    TB.buttons[#TB.buttons+1]=button
    return button
end

local function Line(parent, y)
    local line=parent:CreateTexture(nil,"ARTWORK")
    line:SetPoint("TOPLEFT",14,y); line:SetSize(WIDTH-28,1); line:SetColorTexture(.8,.7,.5,.2)
end

local function Tooltip(owner, option)
    if TB.InCombat() or not option or not option.spell then return end
    Buddy.Foreign(GameTooltip, function(t)
        t:SetOwner(owner,"ANCHOR_LEFT"); t:SetSpellByID(option.spell); t:Show()
    end)
end

function TB.CreateUI()
    if panel then return end
    panel=CreateFrame("Frame","AzerothBuddyDelvesFrame",UIParent,"BackdropTemplate")
    TB.panel=panel
    panel:SetSize(WIDTH,HEIGHT); panel:SetFrameStrata("MEDIUM"); panel:SetClampedToScreen(true)
    panel:SetMovable(true); panel:EnableMouse(true)
    Buddy.Style.Window(panel)
    local accent=panel:CreateTexture(nil,"ARTWORK"); accent:SetSize(3,34); accent:SetPoint("TOPLEFT",0,-14); accent:SetColorTexture(.95,.73,.3,.9)
    title=Label(panel,GOLD.."AzerothBuddy · Valeera|r",16,-16,350,24,"GameFontNormalLarge")
    context=Label(panel,"",16,-44,WIDTH-32,32,"GameFontHighlightSmall")
    Button(panel,"×",WIDTH-36,-11,25,function() TB.visibility=false; panel:Hide() end)
    local drag=CreateFrame("Frame",nil,panel); drag:SetPoint("TOPLEFT",0,0); drag:SetSize(WIDTH-42,42); drag:EnableMouse(true)
    drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart",function() if not TB.InCombat() and TB.db.unlocked then panel:StartMoving() end end)
    drag:SetScript("OnDragStop",function()
        panel:StopMovingOrSizing()
        local point,_,relative,x,y=panel:GetPoint()
        TB.db.position={point,relative,x,y}
    end)
    TB.drag=drag
    Line(panel,-70)
    styleButtons={}
    for i,key in ipairs({"relaxed","safe","fast"}) do
        styleButtons[key]=Button(panel,TB.styles[key],14+(i-1)*137,-82,133,function() TB.SetStyle(key) end)
    end
    explanation=Label(panel,"",16,-122,WIDTH-32,54,"GameFontHighlightSmall")
    rows={}
    for i,slot in ipairs(TB.order) do
        local frame=CreateFrame("Frame",nil,panel)
        frame:SetPoint("TOPLEFT",14,-177-(i-1)*74); frame:SetSize(WIDTH-28,70)
        local tint=frame:CreateTexture(nil,"BACKGROUND"); tint:SetAllPoints(); tint:SetColorTexture(1,1,1,.025)
        frame.label=Label(frame,TB.labels[slot],9,-5,WIDTH-52,15,"GameFontDisableSmall")
        frame.name=Label(frame,"",9,-22,WIDTH-52,21,"GameFontNormal")
        frame.detail=Label(frame,"",9,-47,WIDTH-52,18,"GameFontHighlightSmall")
        frame:EnableMouse(true)
        frame:SetScript("OnEnter",function(self) Tooltip(self,self.option) end)
        frame:SetScript("OnLeave",Buddy.HideTooltip)
        rows[i]=frame
    end
    Button(panel,"Neu einlesen",14,-483,245,function() TB.Refresh() end)
    Button(panel,"Valeera öffnen",264,-483,160,function() TB.OpenCompanion() end)
    status=Label(panel,"",16,-518,WIDTH-32,41,"GameFontHighlightSmall")
    panel:SetScript("OnHide", Buddy.HideTooltip)
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
    for _,b in ipairs(TB.buttons) do b:EnableMouse(enabled) end
    for _,r in ipairs(rows) do r:EnableMouse(enabled) end
    if not enabled then Buddy.HideTooltip() end
end

function TB.Render()
    if not panel or not TB.player then return end
    local player,snapshot,recommendation=TB.player,TB.snapshot or {},TB.recommendation
    title:SetText(GOLD .. "AzerothBuddy · Valeera|r")
    local className, playerName = plain(player.className), plain(player.name) or "Unbekannt"
    local level = integer(snapshot.level)
    context:SetText(WHITE .. (className and className.." · " or "") .. playerName .. "|r\n" .. GREY
        .. (level and "Valeera · Stufe "..level or "Valeera · Begleitervorräte") .. "|r")
    local style=TB.style
    for key,b in pairs(styleButtons) do b.bg:SetColorTexture(1,.8,.4,key==style and .17 or .04) end
    if recommendation then
        explanation:SetText(GREY .. TB.styles[style] .. " · " .. (plain(recommendation.reason) or "") .. "|r")
        for i,row in ipairs(recommendation.rows) do
            local frame=rows[i]
            local marker=row.match and GREEN.."Passt" or row.choice and AMBER.."Ändern" or GREY.."Offen"
            local rank=integer(row.choice and row.choice.rank)
            rank = rank and " · Rang "..rank or ""
            frame.name:SetText((row.match and GREEN or GOLD) .. (plain(row.name) or "Unbekannt") .. rank .. "|r")
            local current=row.current and (plain(row.current.name) or "Noch nicht erkannt") or "Noch nicht erkannt"
            local message
            if row.match then message="Passt bereits"
            elseif row.choice then message="Aktuell: "..current
            else message=(plain(snapshot.error) and "Noch keine Live-Daten") or "Nicht freigeschaltet oder nicht erkannt" end
            frame.label:SetText(TB.labels[row.slot] .. "   " .. marker .. (row.fallback and " · Alternative" or "") .. "|r")
            frame.detail:SetText(GREY .. message .. "|r"); frame.option=row.choice or row.current
        end
        local text=plain(TB.status) or plain(snapshot.error)
        if not text then
            if recommendation.changes==0 and recommendation.missing==0 then text="Alles passt. Viel Spaß in der Tiefe!"
            elseif recommendation.missing>0 then text="Offene Auswahl: "..recommendation.missing..". Verfügbare Alternativen werden berücksichtigt."
            else text=recommendation.changes.." Empfehlungen weichen ab. Bitte selbst in Valeeras Begleitervorräten auswählen." end
        end
        local members=GetNumGroupMembers and GetNumGroupMembers()
        if integer(members) and members>=5 then text="Volle Fünfergruppe: Valeera begleitet dich hier nicht."
        elseif IsInGroup and IsInGroup() then text="Gruppenlauf: Empfehlung ist für solo gedacht. Rollen mit deiner Gruppe abstimmen." end
        status:SetText(GREY..(plain(text) or "").."|r")
    end
    TB.CombatUI()
end

function TB.UpdateVisibility()
    if not panel then return end
    local show=TB.visibility
    if show==nil then show=TB.db.autoShow end
    panel:SetShown(TB.active and show==true)
end
