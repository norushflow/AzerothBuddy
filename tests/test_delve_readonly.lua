-- Controller-Lebenszyklus: normale Aktualisierungen bleiben lesend, Schreibversuche
-- laufen nur über Moduswechsel und nachweisliche Begleiter-Interaktionen.
local queue,frames={},{}
local combat,inside=false,false
local function frame()
 local f={events={},scripts={},shown=false}
 function f:RegisterEvent(e) self.events[e]=true end
 function f:UnregisterEvent(e) self.events[e]=nil end
 function f:SetScript(k,fn) self.scripts[k]=fn end
 function f:IsShown() return self.shown end
 function f:Hide() self.shown=false end
 frames[#frames+1]=f;return f
end
function CreateFrame() return frame() end
C_Timer={After=function(_,fn) queue[#queue+1]=fn end}
local function drain() local q=queue;queue={};for _,fn in ipairs(q) do fn() end end
local B={Tiefen={},db={delves={}},Message=function() end}
local TB=B.Tiefen
TB.Context=function() return {inside=inside} end
TB.InCombat=function() return combat end
TB.styles={relaxed='Entspannt',safe='Sicher',fast='Tempo'}
TB.Player=function() return {spec=253,role='DAMAGER'} end
local reads,renders,applies=0,0,0
local interactions,clears=0,0
TB.Snapshot=function() reads=reads+1;return {slots={}} end
TB.Recommend=function() return {rows={}} end
TB.TryApply=function() applies=applies+1;return true end
TB.ApplyMode=function(style) applies=applies+1;assert(style=='safe');return true end
TB.NoteInteraction=function(treeID) interactions=interactions+1;return treeID==nil or treeID==1223 end
TB.ClearInteraction=function() clears=clears+1 end
TB.CreateUI=function() TB.panel=frame() end
TB.Place=function() end
TB.UpdateVisibility=function()
 local show=TB.visibility;if show==nil then show=TB.db.autoShow end
 TB.panel.shown=TB.active and show==true
end
TB.Render=function() renders=renders+1 end
TB.CombatUI=function() end
SlashCmdList={}
assert(loadfile('Modules/Tiefen/Main.lua'))('AzerothBuddy',B)
assert(#frames==1 and next(TB.events.events)==nil,'disabled module registers no events')
B.LoadDelves();assert(reads==0 and not TB.active and TB.events.events.PLAYER_ENTERING_WORLD)
inside=true;combat=true
TB.events.scripts.OnEvent(nil,'PLAYER_ENTERING_WORLD');drain()
assert(not TB.active and reads==0,'entry in combat stays deferred')
combat=false;TB.events.scripts.OnEvent(nil,'PLAYER_REGEN_ENABLED');drain()
assert(TB.active and reads==1 and renders==1)
assert(applies==1,'combat end triggers the pending takeover')
for i=1,100 do TB.events.scripts.OnEvent(nil,'TRAIT_CONFIG_UPDATED') end
assert(#queue==1,'one controller coalesces event bursts');drain();assert(reads==2)
SlashCmdList.TIEFENBEGLEITER('');assert(not TB.panel:IsShown())
for i=1,100 do TB.events.scripts.OnEvent(nil,'TRAIT_CONFIG_UPDATED') end
drain();assert(reads==2,'hidden advisor does not rescan recommendations')
SlashCmdList.TIEFENBEGLEITER('');assert(reads==3 and TB.panel:IsShown())
TB.SetStyle('safe');assert(TB.style=='safe' and reads==4)
assert(applies==2,'mode switch triggers the takeover')
TB.SetStyle('custom');assert(TB.style=='safe','favorites cannot be restored')
combat=true;TB.events.scripts.OnEvent(nil,'TRAIT_CONFIG_UPDATED');drain();assert(reads==4)
-- Nur Moduswechsel und nachweisliche Begleiter-Interaktionen lösen einen
-- Schreibversuch aus; fremde Traitbäume und Addon-Ladevorgänge nicht.
combat=false
TB.events.scripts.OnEvent(nil,'SHOW_DELVES_COMPANION_CONFIGURATION_UI')
assert(applies==3 and interactions==1,'payload-free UI interaction triggers takeover')
TB.events.scripts.OnEvent(nil,'TRAIT_SYSTEM_INTERACTION_STARTED',1223)
assert(applies==4 and interactions==2,'companion trait interaction triggers takeover')
TB.events.scripts.OnEvent(nil,'TRAIT_SYSTEM_INTERACTION_STARTED',999)
assert(applies==4 and interactions==3,'foreign trait tree does not trigger takeover')
TB.events.scripts.OnEvent(nil,'TRAIT_SYSTEM_NPC_CLOSED')
assert(clears==2 and applies==4,'closing interaction clears write permission')
TB.events.scripts.OnEvent(nil,'ADDON_LOADED','Other_Addon')
TB.events.scripts.OnEvent(nil,'ADDON_LOADED','Blizzard_DelvesCompanionConfiguration')
assert(applies==4,'foreign addon load does not trigger takeover')
inside=false;TB.events.scripts.OnEvent(nil,'ZONE_CHANGED')
assert(not TB.active and not TB.panel:IsShown() and not TB.events.events.TRAIT_CONFIG_UPDATED and clears==3)
drain();assert(reads==4 and TB.events.events.ZONE_CHANGED,'outside retains only lifecycle watchers')
-- Schreib- und Interaktionszugriffe liegen ausschließlich in Apply.lua.
for _,name in ipairs({'Rules','Game','UI','Main'}) do
 local f=assert(io.open('Modules/Tiefen/'..name..'.lua'));local source=f:read('*a');f:close()
 for _,write in ipairs({'SetSelection','CommitConfig','RollbackConfig','PurchaseRank','ConfigHasStagedChanges','SaveFavorite'}) do
  assert(not source:find(write,1,true),'write path outside Apply.lua: '..write)
 end
end
local f=assert(io.open('Modules/Tiefen/Apply.lua'));local apply=f:read('*a');f:close()
for _,write in ipairs({'SetSelection','CommitConfig','RollbackConfig','CanEditConfig','ConfigHasStagedChanges','IsTraitTreeForCompanion'}) do
 assert(apply:find(write,1,true),'Apply.lua missing API: '..write)
end
assert(not apply:find('ClosestUnitPosition(',1,true) and not apply:find('SuppliesDistance',1,true),
 'unreliable proximity API is not called')
assert(not apply:find('C_Timer.After',1,true) and not apply:find('"OnUpdate"',1,true)
 and not apply:find("'OnUpdate'",1,true),'takeover uses no timer or polling')
assert(not apply:find('PurchaseRank',1,true) and not apply:find('SaveFavorite',1,true),
 'takeover uses only selection APIs, no purchases or unrelated storage')
assert(not TB.ApplyStep and not TB.CheckCommit and not TB.SaveFavorite,
 'no hidden write loop or favorites')
print('PASS: controller lifecycle, interaction triggers, write isolation and deferred entry')
