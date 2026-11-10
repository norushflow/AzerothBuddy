local loadfile = dofile("tests/load_locales.lua")
local frames={}
local methods={}
function methods:SetScript(k,v) self.scripts[k]=v end
function methods:GetScript(k) return self.scripts[k] end
function methods:RegisterEvent(e) self.events[e]=true end
function methods:UnregisterEvent(e) self.events[e]=nil end
function methods:UnregisterAllEvents() self.events={} end
function methods:Show() self.shown=true end
function methods:Hide() self.shown=false end
function methods:SetShown(v) self.shown=v end
function methods:IsShown() return self.shown end
function methods:SetFrameLevel(v) self.frameLevel=v end
function methods:SetFrameStrata(v) self.frameStrata=v end
function methods:SetText(v) self.text=v end
function methods:SetPoint(point,...)
 self.point={point,...};self.points[point]=self.point
end
function methods:GetStringHeight() return self.text:find('Häkchen:',1,true) and 56 or 11 end
function methods:SetChecked(v) self.checked=v end
function methods:GetChecked() return self.checked end
function methods:SetOwner(owner) self.tooltipOwner=owner end
function methods:GetOwner() return rawget(self,'tooltipOwner') end
function methods:ClearLines() self.lines={} end
function methods:AddLine(line) self.lines[#self.lines+1]=line end
function methods:GetWidth() return 140 end
function methods:GetHeight() return 140 end
function methods:GetEffectiveScale() return 1 end
function methods:GetCenter() return 100,100 end
local object
function methods:GetFontString() self.fontString=rawget(self,"fontString") or object(); return self.fontString end
function methods:SetHeight(v) self.height=v end
function methods:SetSize(w,h) self.width=w;self.height=h end
object = function()
 return setmetatable({events={},scripts={},points={},textures={},shown=true},{__index=function(_,k) return methods[k] or function() end end})
end
function CreateFrame(_,name)
 local f=object();frames[#frames+1]=f;if name then _G[name]=f end;return f
end
function methods:CreateTexture()
 local texture=object();self.textures[#self.textures+1]=texture;return texture
end
function methods:CreateFontString()
 local font=object();font.parent=self;frames[#frames+1]=font;return font
end
for _,state in ipairs({"Normal","Pushed","Disabled"}) do
 methods["Set"..state.."Atlas"]=function(self,atlas)
  self[state]=self:CreateTexture();self[state].atlas=atlas
 end
 methods["Get"..state.."Texture"]=function(self) return self[state] end
end
UIParent=object();Minimap=object();GameTooltip=object();UISpecialFrames={};SlashCmdList={}
NineSliceUtil={ApplyLayoutByName=function(frame, layout) frame.sliceLayout=layout end}
local tickers={}
local afterCalls=0
STANDARD_TEXT_FONT='font';C_Timer={After=function() afterCalls=afterCalls+1 end,NewTicker=function(_,fn) tickers[#tickers+1]=fn;return {Cancel=function() end} end}
local combat,inside=false,false
function InCombatLockdown() return combat end
function IsInInstance() return inside end
C_PartyInfo={IsDelveInProgress=function() return inside end}
function GetServerTime() return 1000 end
function date() return '12:00' end
function UnitClass() return 'Hunter','HUNTER' end
function GetClassColor() return 1,1,1 end
AzerothBuddyDB={clock={hidden=true},schedule={position={}},enabled={clock=true,schedule=true}}
if arg[1]=='disabled' then AzerothBuddyDB={enabled={characters=false,schedule=false,clock=false,delves=false,omnium=false,transmog=false,meters=false,bars=false}} end
local Buddy={}
for line in io.lines('AzerothBuddy.toc') do
 if line:match('%.lua$') then assert(loadfile(''..line))('AzerothBuddy',Buddy) end
end
local init=frames[#frames]
init.scripts.OnEvent(init,'ADDON_LOADED','AzerothBuddy')
if arg[1]=='disabled' then
 assert(next(Buddy.loaded)==nil and not SlashCmdList.ALTM and not SlashCmdList.MIDNIGHTEVENTFEED and not SlashCmdList.TIEFENBEGLEITER and not SlashCmdList.AZEROTHBUDDYBARS)
 init.scripts.OnEvent(init,'PLAYER_LOGIN')
 assert(AzerothBuddyMinimapButton)
 assert(afterCalls==0 and #tickers==0,'disabled modules must schedule no background work')
 for _,f in ipairs(frames) do
  assert(next(f.events)==nil and not f.scripts.OnUpdate,'disabled modules leave no event processing/polling')
 end
 print('PASS: disabled modules do not initialize; minimap remains available')
 return
end
assert(Buddy.loaded.characters and Buddy.loaded.delves and Buddy.loaded.bars)
assert(not Buddy.Tiefen.active,'delves inactive outside')
assert(not Buddy.Schedule and not Buddy.LoadClock and not Buddy.LoadSchedule)
assert(not Buddy.db.clock and not Buddy.db.schedule and not Buddy.db.enabled.clock and not Buddy.db.enabled.schedule)
assert(not SlashCmdList.MIDNIGHTEVENTFEED and not AzerothBuddyClockFrame and not AzerothBuddySchedulePanel)
for _,f in ipairs(frames) do assert(not f.events.EVENT_SCHEDULER_UPDATE) end
local expected={characters=true,delves=true,omnium=true,transmog=true,meters=true,bars=true}
assert(#Buddy.modules==6)
for _,m in ipairs(Buddy.modules) do assert(expected[m.key] and type(Buddy[m.loader])=='function');expected[m.key]=nil end
assert(next(expected)==nil)
local originalOpen=Buddy.OpenModule
local aliases={chars='characters',tiefen='delves',omnium='omnium',transmog='transmog',meter='meters'}
for alias,key in pairs(aliases) do
 Buddy.OpenModule=function(m) assert(m.key==key) end
 SlashCmdList.AZEROTHBUDDY(alias)
end
Buddy.OpenModule=originalOpen
init.scripts.OnEvent(init,'PLAYER_LOGIN')
assert(AzerothBuddyMinimapButton and not AltMiniMinimapButton)
AzerothBuddyMinimapButton.scripts.OnClick(AzerothBuddyMinimapButton,'LeftButton');assert(Buddy.panel:IsShown())
local hint, title, nameplateButtons
nameplateButtons=0
for _,frame in ipairs(frames) do
 if rawget(frame,'parent')==Buddy.panel and type(frame.text)=='string' and frame.text:find('Häkchen:',1,true) then hint=frame end
 if rawget(frame,'parent')==Buddy.panel and frame.text=='AzerothBuddy' then title=frame end
 if rawget(frame,'Normal') then
  assert(frame.Normal.atlas=='UI-HUD-CoolDownManager-Bar')
  nameplateButtons=nameplateButtons+1
 end
end
assert(nameplateButtons==9,'use the nameplate atlas on the nine central buttons')
assert(title and title.point[2]==Buddy.Style.Spacing.panel and title.point[3]==-25,
    'main title aligns to the panel inset below the metal strip')
assert(hint and hint.point[2]==Buddy.Bars.menu and hint.point[3]=='BOTTOMLEFT' and hint.point[5]==-16)
assert(Buddy.panel.height==553,'a longer help text leaves space for the reload button')
assert(Buddy.panel.sliceLayout=='ButtonFrameTemplateNoPortrait')
for _,background in ipairs({Buddy.panel.textures[1],Buddy.panel.textures[2]}) do
 local top,bottom=background.points.TOPLEFT,background.points.BOTTOMRIGHT
 assert(top[4]==6 and top[5]==-21 and bottom[4]==-2 and bottom[5]==2,'keep the rock and tint inside the native frame')
end
SlashCmdList.AZEROTHBUDDY('');assert(not Buddy.panel:IsShown())
-- Character UI regression: compact sizing, filters, sorting and tab transitions.
function UnitFullName() return 'Buddy','Realm' end
function UnitFactionGroup() return 'Alliance' end
function GetProfessions() return nil,nil end
function GetAverageItemLevel() return 275,275 end
function UnitLevel() return 90 end
local xpReads,restedReads=0,0
function UnitXPMax() xpReads=xpReads+1;return 1000 end
function GetXPExhaustion() restedReads=restedReads+1;return 251 end
function time() return 1000 end
function FauxScrollFrame_Update() end
function FauxScrollFrame_GetOffset(f) return rawget(f,"offset") or 0 end
function FauxScrollFrame_SetOffset(f,v) f.offset=v end
LOCALIZED_CLASS_NAMES_MALE={HUNTER='Jäger',MAGE='Magier',EVOKER='Rufer'}
SlashCmdList.ALTM()
local characters=AzerothBuddyCharactersFrame
assert(characters:IsShown() and characters.height==420,'compact character view')
assert(characters.tab1.Normal.atlas=='UI-HUD-CoolDownManager-Bar','all panel buttons use the brown atlas by default')
assert(characters.rows[1].cells[3].text=='Jäger','localized class label')
local snapshot=Buddy.db.characters.chars['Realm-Buddy']
assert(xpReads==1 and restedReads==1,'read XP and rested XP once per character snapshot')
assert(snapshot.xpmax==1000 and snapshot.rested_xp==251 and snapshot.restxp_pct==25.1)
for i=1,20 do Buddy.db.characters.chars['alt'..i]={name='Alt'..i,realm='Realm',class='MAGE',level=i,playtime_sec=i*60} end
characters.Render();assert(characters.height==630,'row cap at twelve')
characters.scroll.offset=9
Buddy.db.characters.filters.class='HUNTER'
characters.Render();assert(characters.scroll.offset==0 and characters.rows[1]:IsShown(),'filter clamps scroll offset')
Buddy.db.characters.filters.class='WARRIOR'
characters.Render();assert(characters.empty:IsShown(),'empty filter state')
characters.clearBtn.scripts.OnClick();assert(not characters.empty:IsShown())
characters.headers[7].scripts.OnClick();assert(Buddy.db.characters.sort.key=='level' and Buddy.db.characters.sort.asc)
characters.tab2.scripts.OnClick();assert(characters.headers[1].text.text=='Klasse' and characters.rows[1].cells[1].text=='Magier')
for _,class in ipairs({'WARRIOR','PALADIN','HUNTER','ROGUE','PRIEST','DEATHKNIGHT','SHAMAN','WARLOCK','MONK','DRUID','DEMONHUNTER','EVOKER'}) do
    Buddy.db.characters.chars[class]={name=class,realm='Realm',class=class,playtime_sec=class=='EVOKER' and 0 or 60}
end
characters.Render()
assert(characters.height==660 and characters.scroll.offset==0, 'class statistics fit thirteen rows without scrolling')
assert(characters.rows[13]:IsShown() and characters.rows[13].cells[1].text=='Rufer', 'last class is visible')
characters.tab1.scripts.OnClick();assert(characters.headers[1].text.text=='Realm' and characters.scroll.offset==0
    and characters.height==630 and not characters.rows[13]:IsShown())
print('PASS: character layout, localization, row cap, filtering, empty state, sorting and tabs')
SlashCmdList.AZEROTHBUDDYOMNIUM('')
assert(AzerothBuddyOmniumFrame:IsShown())
assert(#Buddy.Omnium.roleButtons==3 and not Buddy.Omnium.stat and not Buddy.Omnium.auto,'three role choices, no stat submenu')
assert(AzerothBuddyOmniumFrame.frameLevel==100 and AzerothBuddyOmniumFrame.frameStrata=="DIALOG", "Omnium above central menu like character window")
SlashCmdList.AZEROTHBUDDYOMNIUM('')
assert(not AzerothBuddyOmniumFrame:IsShown())
print('PASS: Omnium panel opens/closes with missing live specialization APIs')

-- Berufssnapshot: fehlende Login-/Logoutdaten dürfen gespeicherte Berufe nicht löschen.
local charEvents
for _,f in ipairs(frames) do if f.events.SKILL_LINES_CHANGED then charEvents=f end end
assert(charEvents)
local c=Buddy.db.characters.chars['Realm-Buddy']
c.prof1_name,c.prof1_lvl='Alchemie',70
c.prof2_name,c.prof2_lvl='Kräuterkunde',80
GetProfessions=function() return nil,nil end
charEvents.scripts.OnEvent(charEvents,'PLAYER_LOGIN')
assert(c.prof1_name=='Alchemie' and c.prof2_lvl==80,'login erased saved professions')
local professionQueue={}
local oldAfter=C_Timer.After
C_Timer.After=function(_,fn) professionQueue[#professionQueue+1]=fn end
local function skills()
 charEvents.scripts.OnEvent(charEvents,'SKILL_LINES_CHANGED')
 while #professionQueue>0 do table.remove(professionQueue,1)() end
end
GetProfessions=function() return 1,2 end
GetProfessionInfo=function(i) return i==1 and 'Alchemie' or 'Kräuterkunde',123,90,100 end
skills();assert(c.prof1_lvl==90 and c.prof2_lvl==90)
GetProfessionInfo=function(i) if i==1 then return 'Alchemie',123,95,100 end end
skills();assert(c.prof1_lvl==90 and c.prof2_lvl==90,'partial response overwrote snapshot')
GetProfessions=function() return nil,nil end
charEvents.scripts.OnEvent(charEvents,'PLAYER_LOGOUT')
assert(c.prof1_name=='Alchemie' and c.prof2_name=='Kräuterkunde','logout erased professions')
-- Beruf wechseln bzw. verlernen, auch bei leerem ersten Slot.
GetProfessions=function() return nil,2 end
GetProfessionInfo=function() return 'Bergbau',456,25,100 end
skills();assert(c.prof1_name=='—' and c.prof2_name=='Bergbau')
GetProfessions=function() return nil,nil end
skills();assert(c.prof2_name=='—','unlearning left a stale profession')
C_Timer.After=oldAfter
print('PASS: saved professions survive missing/partial data and logout; learning/unlearning updates')

-- Audit 1.0: Offline-Erholung beginnt auch bei null; gespeicherte Daten bleiben gleich.
local originalTime=time
function time() return 100000 end
Buddy.db.characters.filters={class='HUNTER'}
local offline={name='Offline',realm='Realm',class='HUNTER',level=20,xpmax=1000,
 rested_xp=0,rested_ts=time()-86400}
Buddy.db.characters.chars['Realm-Offline']=offline
SlashCmdList.ALTM()
local characters=AzerothBuddyCharactersFrame
if not characters:IsShown() then SlashCmdList.ALTM() end
characters.Render()
local found=false
for _,row in ipairs(characters.rows) do
 if row:IsShown() and row.cells[2].text=='Offline' then
  assert(row.cells[9].text=='~15.0%','one day must add estimated rest from zero')
  found=true
 end
end
assert(found and offline.rested_xp==0,'estimate must not overwrite snapshot')
time=originalTime
-- Ein eigener Tooltip bleibt sichtbar, bis sein tatsächlicher Besitzer ihn schließt.
local minimapButton=AzerothBuddyMinimapButton
GameTooltip.Hide=function() error('Blizzard tooltip touched') end
GameTooltip.SetOwner=function() error('Blizzard tooltip touched') end
minimapButton.scripts.OnEnter(minimapButton)
local tooltip=AzerothBuddyDesignTooltip
assert(tooltip:IsShown() and tooltip:GetOwner()==minimapButton and #tooltip.lines==4)
Buddy.Style.HideTooltip(characters)
assert(tooltip:IsShown(),'unrelated frame closed the tooltip')
minimapButton.scripts.OnLeave(minimapButton)
assert(not tooltip:IsShown())
print('PASS: zero-rested offline estimate and addon-owned tooltip')

-- Reiner Valeera-Berater: bisherige Speicherdaten bleiben unangetastet/ungenutzt.
local TB=Buddy.Tiefen
local oldProfiles={specs={['0']={style='custom',favorite={role={entry=42}}}}}
Buddy.char.delves=oldProfiles
local position={'TOPRIGHT','TOPRIGHT',-300,-150}
Buddy.db.delves.tab='delves';Buddy.db.delves.position=position
inside=true;combat=false
Buddy.LoadDelves()
assert(TB.active and TB.panel:IsShown(),'Valeera panel activates inside a delve')
assert(TB.db.tab==nil and TB.db.position==position and Buddy.char.delves==oldProfiles,
 'migration preserves window and leaves obsolete personal profiles untouched')
assert(TB.style=='relaxed' and not TB.char and not TB.Profile,'no saved character profile used')
assert(TB.panel.height==578 and #TB.buttons==6,'six display controls, no selection or save buttons')
assert(not TB.events.events.AREA_POIS_UPDATED and not TB.events.events.CURRENCY_DISPLAY_UPDATE
 and not TB.events.events.UPDATE_UI_WIDGET and not TB.events.events.BAG_UPDATE_DELAYED
 and not TB.events.events.CONFIG_COMMIT_FAILED,'removed features must not register events')
assert(not TB.Apply and not TB.ApplyStep and not TB.CheckCommit and not TB.SaveFavorite and not TB.CanChange)
SlashCmdList.TIEFENBEGLEITER('');assert(not TB.panel:IsShown())
SlashCmdList.TIEFENBEGLEITER('');assert(TB.panel:IsShown())
TB.SetStyle('safe');assert(TB.style=='safe' and oldProfiles.specs['0'].style=='custom')
combat=true;TB.events.scripts.OnEvent(nil,'PLAYER_REGEN_DISABLED')
inside=false;TB.events.scripts.OnEvent(nil,'PLAYER_ENTERING_WORLD')
assert(not TB.active and not TB.panel:IsShown(),'exit hides advisor immediately even in combat')
combat=false
print('PASS: read-only Valeera UI, legacy data isolation, controls, style, toggle and exit')

-- Menu items close the hub; the inline action bar controls stay accessible.
for _,module in ipairs(Buddy.modules) do
    local handler=SlashCmdList[module.command]
    local called=false
    SlashCmdList[module.command]=function() called=true end
    Buddy.panel:Show()
    Buddy.OpenModule(module)
    if module.key=="bars" then
        assert(Buddy.panel:IsShown(),"bars must keep the hub open")
    else
        assert(called and not Buddy.panel:IsShown(),"module must close the hub: "..module.key)
    end
    SlashCmdList[module.command]=handler
end
print('PASS: menu closes for modules and stays open for action bars')
