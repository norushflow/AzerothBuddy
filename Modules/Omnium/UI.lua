local _,B=...
local L = B.L
local O=B.Omnium
local Style=B.Style
local Color=Style.Color
local MUTED=Style.Hex(Color.muted)
local function label(p,text,x,y,w,role,color)
 local f=Style.Text(p,role,color)
 f:SetPoint("TOPLEFT",x,y);f:SetWidth(w);f:SetJustifyH("LEFT");f:SetText(text);return f
end
local function button(p,text,x,y,w,action)
 local b=Style.Button(CreateFrame("Button",nil,p,"UIPanelButtonTemplate"))
 b:SetSize(w,28);b:SetPoint("TOPLEFT",x,y);b:SetText(text);b:SetScript("OnClick",action);return b
end
local function safeText(v)
 return not (issecretvalue and issecretvalue(v)) and type(v)=="string" and v or nil
end
local function overview(p)
 local card=CreateFrame("Frame",nil,p,"BackdropTemplate")
 card:SetSize(450,100);card:SetPoint("TOPLEFT",20,-78)
 Style.Inset(card)
 label(card,L["Omniumfoliant · Aktive Runen"],12,-9,420,"heading")
 O.icons={}
 for i=1,5 do
  local b=Style.Icon(CreateFrame("Button",nil,card));b:SetSize(44,44);b:SetPoint("TOPLEFT",36+(i-1)*84,-33)
  b.icon=b:CreateTexture(nil,"ARTWORK");b.icon:SetPoint("TOPLEFT",2,-2);b.icon:SetPoint("BOTTOMRIGHT",-2,2)
  b.icon:SetTexCoord(.07,.93,.07,.93)
  b.status=label(card,"",0,0,80,"small")
  b.status:ClearAllPoints()
  b.status:SetPoint("TOP",b,"BOTTOM",0,-3)
  b.status:SetJustifyH("CENTER")
  b:SetScript("OnEnter",function(self)
   local tip=Style.Tooltip(self,"ANCHOR_RIGHT")
   if not tip then return end
   local row=self.row
   tip:AddLine(row and row.activeName or L["Keine aktive Rune erkannt"],unpack(Color.gold,1,3))
   if row and row.activeSpell and C_Spell and C_Spell.GetSpellDescription then
    local ok,desc=pcall(C_Spell.GetSpellDescription,row.activeSpell)
    if ok and safeText(desc) then tip:AddLine(desc,Color.text[1],Color.text[2],Color.text[3],true) end
   end
   if row then
    tip:AddLine(L["Empfehlung: "]..(O.labels[row.key] or row.key),Color.muted[1],Color.muted[2],Color.muted[3],true)
    tip:AddLine(row.status,unpack(Color.text,1,3))
   end
   tip:Show()
  end)
  b:SetScript("OnLeave",Style.HideTooltip)
  b:SetScript("OnHide",Style.HideTooltip)
  O.icons[i]=b
 end
end
function O.Render()
 if not O.panel or not O.panel:IsShown() then return end
 local s=O.Read()
 local _,_,_,playerRole=O.Player()
 for i,role in ipairs(O.roles) do
  Style.Select(O.roleButtons[i],(O.db.role or playerRole)==role)
 end
 -- name/source sind API-Strings; vor der Verkettung auf Typ prüfen.
 local name=type(s.name)=="string" and s.name~="" and s.name or nil
 local source=type(s.source)=="string" and s.source~="" and s.source or nil
 O.heading:SetText(name and source and (name.." · "..source) or L["Spezialisierung lädt …"])

 for i,f in ipairs(O.labelsUI) do
  local row=s.rows and s.rows[i]
  local icon=O.icons[i]
  icon.row=row
  icon.icon:SetTexture(row and row.activeIcon or "Interface\\Icons\\INV_Misc_QuestionMark")
  icon.icon:SetDesaturated(not (row and row.activeIcon))
  local status,statusColor=L["Offen"],Color.muted
  if row and row.match then status,statusColor=L["Passt"],Color.success
  elseif row and row.rank and row.rank>0 then status,statusColor=L["Abweichend"],Color.gold end
  icon.status:SetText(status)
  icon.status:SetTextColor(unpack(statusColor))
  if row then
   local name=row.name
   if issecretvalue and issecretvalue(name) then name=nil end
   f:SetText(i..". "..(name or O.labels[row.key]).."\n"..MUTED..row.status.."|r")
  else f:SetText("") end
 end
 O.note:SetText(s.error or O.status or L["Rolle wählen: verfügbare Runen werden übernommen. Gesperrte Runen bleiben offen."])

end
function O.Toggle()
 if not O.panel then
  local p=CreateFrame("Frame","AzerothBuddyOmniumFrame",UIParent,"BackdropTemplate");O.panel=p
  p:SetSize(490,655);p:SetFrameStrata("DIALOG");p:SetFrameLevel(100);p:SetClampedToScreen(true)
  Style.Window(p,68)
  p:SetMovable(true);p:EnableMouse(true)
  -- Gleiche Position wie der Tiefenberater nutzen
  local pos=B.db.tiefen and B.db.tiefen.position or (B.Tiefen and B.Tiefen.db and B.Tiefen.db.position)
  if pos then p:SetPoint(pos[1],UIParent,pos[2],pos[3],pos[4])
  else p:SetPoint("TOPRIGHT",UIParent,"TOPRIGHT",-310,-180); if B.PlaceAutomatic then B.PlaceAutomatic() end end
  local drag=CreateFrame("Frame",nil,p); drag:SetPoint("TOPLEFT",0,0); drag:SetSize(448,48); drag:EnableMouse(true)
  drag:RegisterForDrag("LeftButton")
  drag:SetScript("OnDragStart",function() p:StartMoving() end)
  drag:SetScript("OnDragStop",function()
   p:StopMovingOrSizing()
   local point,_,relative,x,y=p:GetPoint()
   B.db.tiefen=B.db.tiefen or {}
   B.db.tiefen.position={point,relative,x,y}
   if B.Tiefen and B.Tiefen.db then B.Tiefen.db.position=B.db.tiefen.position end
  end)
  label(p,L["AzerothBuddy · Omniumfoliant"],20,-25,440,"title")
  O.heading=label(p,"",20,-49,450,"body",Color.muted)
  overview(p)
  O.roleButtons={}
  for i,role in ipairs(O.roles) do
   O.roleButtons[i]=button(p,O.roleLabels[role],20+(i-1)*152,-189,146,function() O.SelectRole(role) end)
  end
  local recommendations=CreateFrame("Frame",nil,p)
  recommendations:SetPoint("TOPLEFT",20,-225);recommendations:SetSize(450,228)
  Style.Inset(recommendations)
  O.labelsUI={}
  for i=1,5 do
   O.labelsUI[i]=label(recommendations,"",12,-10-(i-1)*45,426)
  end
  button(p,L["Jetzt übernehmen"],20,-497,220,function() O.Apply(true) end)
  button(p,L["Neu einlesen"],250,-497,220,function() O.status=nil;O.Render() end)
  O.note=label(p,"",20,-538,450)
  label(p,L["Method · Stand 06.11.2026 · fünf ursprüngliche Reihen\nDrei Rollenstandards, keine Ausrüstungssimulation."],20,-590,450,"small",Color.muted)
  local close=Style.Close(CreateFrame("Button",nil,p,"UIPanelCloseButton"));close:SetPoint("TOPRIGHT",-3,-3)
  UISpecialFrames[#UISpecialFrames+1]="AzerothBuddyOmniumFrame"
 else O.panel:SetShown(not O.panel:IsShown()) end
 O.Render()
end
