local _,B=...
local O=B.Omnium
local function label(p,text,x,y,w)
 local f=p:CreateFontString(nil,"OVERLAY","GameFontHighlight")
 f:SetPoint("TOPLEFT",x,y);f:SetWidth(w);f:SetJustifyH("LEFT");f:SetText(text);return f
end
local function button(p,text,x,y,w,action)
 local b=B.Style.Button(CreateFrame("Button",nil,p,"UIPanelButtonTemplate"))
 b:SetSize(w,28);b:SetPoint("TOPLEFT",x,y);b:SetText(text);b:SetScript("OnClick",action);return b
end
local function safeText(v)
 return not (issecretvalue and issecretvalue(v)) and type(v)=="string" and v or nil
end
local function overview(p)
 local card=CreateFrame("Frame",nil,p,"BackdropTemplate")
 card:SetSize(450,100);card:SetPoint("TOPLEFT",20,-78)
 B.Style.Inset(card)
 label(card,"|cffffd100Omniumfoliant · Aktive Runen|r",12,-9,420)
 O.icons={}
 local tip=CreateFrame("GameTooltip","AzerothBuddyOmniumTooltip",UIParent,"GameTooltipTemplate")
 for i=1,5 do
  local b=CreateFrame("Button",nil,card);b:SetSize(44,44);b:SetPoint("TOPLEFT",36+(i-1)*84,-33)
  b.icon=b:CreateTexture(nil,"ARTWORK");b.icon:SetAllPoints();b.icon:SetTexCoord(.07,.93,.07,.93)
  b.status=label(card,"",0,0,80)
  b.status:ClearAllPoints()
  b.status:SetPoint("TOP",b,"BOTTOM",0,-3)
  b.status:SetJustifyH("CENTER")
  b:SetScript("OnEnter",function(self)
   local row=self.row
   tip:SetOwner(self,"ANCHOR_RIGHT");tip:ClearLines()
   tip:AddLine(row and row.activeName or "Keine aktive Rune erkannt",1,.82,.3)
   if row and row.activeSpell and C_Spell and C_Spell.GetSpellDescription then
    local ok,desc=pcall(C_Spell.GetSpellDescription,row.activeSpell)
    if ok and safeText(desc) then tip:AddLine(desc,1,1,1,true) end
   end
   if row then tip:AddLine("Empfehlung: "..(O.labels[row.key] or row.key),.8,.8,.8,true);tip:AddLine(row.status,1,1,1) end
   tip:Show()
  end)
  b:SetScript("OnLeave",function() tip:Hide() end)
  O.icons[i]=b
 end
 p:SetScript("OnHide",function() tip:Hide() end)
end
function O.Render()
 if not O.panel or not O.panel:IsShown() then return end
 local s=O.Read()
 local _,_,_,playerRole=O.Player()
 for i,role in ipairs(O.roles) do
  O.roleButtons[i]:SetText(((O.db.role or playerRole)==role and "✓ " or "")..O.roleLabels[role])
 end
 -- name/source sind API-Strings; vor der Verkettung auf Typ prüfen.
 local name=type(s.name)=="string" and s.name~="" and s.name or nil
 local source=type(s.source)=="string" and s.source~="" and s.source or nil
 O.heading:SetText(name and source and (name.." · "..source) or "Spezialisierung lädt …")

 for i,f in ipairs(O.labelsUI) do
  local row=s.rows and s.rows[i]
  local icon=O.icons[i]
  icon.row=row
  icon.icon:SetTexture(row and row.activeIcon or "Interface\\Icons\\INV_Misc_QuestionMark")
  icon.icon:SetDesaturated(not (row and row.activeIcon))
  icon.status:SetText(row and row.match and "|cff77dd88Passt|r" or row and row.rank and row.rank>0 and "|cffffcc66Abweichend|r" or "|cffaaaaaaOffen|r")
  if row then
   local name=row.name
   if issecretvalue and issecretvalue(name) then name=nil end
   f:SetText(i..". "..(name or O.labels[row.key]).."\n|cffaaaaaa"..row.status.."|r")
  else f:SetText("") end
 end
 O.note:SetText(s.error or O.status or "Rolle wählen: verfügbare Runen werden übernommen. Gesperrte Runen bleiben offen.")

end
function O.Toggle()
 if not O.panel then
  local p=CreateFrame("Frame","AzerothBuddyOmniumFrame",UIParent,"BackdropTemplate");O.panel=p
  p:SetSize(490,655);p:SetFrameStrata("DIALOG");p:SetFrameLevel(100);p:SetClampedToScreen(true)
  B.Style.Window(p)
  p:SetMovable(true);p:EnableMouse(true)
  -- Gleiche Position wie der Tiefenberater nutzen
  local pos=B.db.tiefen and B.db.tiefen.position or (B.Tiefen and B.Tiefen.db and B.Tiefen.db.position)
  if pos then p:SetPoint(pos[1],UIParent,pos[2],pos[3],pos[4])
  else p:SetPoint("TOPRIGHT",UIParent,"TOPRIGHT",-310,-180); if B.PlaceAutomatic then B.PlaceAutomatic() end end
  local drag=CreateFrame("Frame",nil,p); drag:SetPoint("TOPLEFT",0,0); drag:SetSize(448,42); drag:EnableMouse(true)
  drag:RegisterForDrag("LeftButton")
  drag:SetScript("OnDragStart",function() p:StartMoving() end)
  drag:SetScript("OnDragStop",function()
   p:StopMovingOrSizing()
   local point,_,relative,x,y=p:GetPoint()
   B.db.tiefen=B.db.tiefen or {}
   B.db.tiefen.position={point,relative,x,y}
   if B.Tiefen and B.Tiefen.db then B.Tiefen.db.position=B.db.tiefen.position end
  end)
  label(p,"|cffffd100AzerothBuddy · Omniumfoliant|r",20,-20,440)
  O.heading=label(p,"",20,-52,450)
  overview(p)
  O.roleButtons={}
  for i,role in ipairs(O.roles) do
   O.roleButtons[i]=button(p,O.roleLabels[role],20+(i-1)*152,-189,146,function() O.SelectRole(role) end)
  end
  O.labelsUI={};for i=1,5 do O.labelsUI[i]=label(p,"",22,-230-(i-1)*45,445) end
  button(p,"Jetzt übernehmen",20,-497,220,function() O.Apply(true) end)
  button(p,"Neu einlesen",250,-497,220,function() O.status=nil;O.Render() end)
  O.note=label(p,"",20,-538,450)
  label(p,"Method · Stand 06.11.2026 · fünf ursprüngliche Reihen\nDrei Rollenstandards, keine Ausrüstungssimulation.",20,-590,450)
  local close=CreateFrame("Button",nil,p,"UIPanelCloseButton");close:SetPoint("TOPRIGHT",-3,-3)
  UISpecialFrames[#UISpecialFrames+1]="AzerothBuddyOmniumFrame"
 else O.panel:SetShown(not O.panel:IsShown()) end
 O.Render()
end
