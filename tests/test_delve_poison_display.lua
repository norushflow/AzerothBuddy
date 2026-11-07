local B={Tiefen={}}
local T=B.Tiefen
local combat,staged=false,false
function InCombatLockdown() return combat end
local secret={}
function issecretvalue(v) return rawequal(v,secret) end
local refreshes=0
local slot={configID=77,selectionNodeID=12,selectionNodeInfo={activeEntry={entryID=201}}}
function slot:IsForbidden() return false end
function slot:IsShown() return true end
function slot:Refresh()
 refreshes=refreshes+1
 self.selectionNodeInfo={activeEntry={entryID=202}}
end
local panel={CompanionSlots={CompanionFlavorSlot=slot}}
function panel:IsForbidden() return false end
function panel:IsShown() return true end
DelvesCompanionConfigurationFrame=panel
C_Traits={ConfigHasStagedChanges=function(id) assert(id==77);return staged end,
 GetNodeInfo=function(id,node) assert(id==77 and node==12);return {activeEntry={entryID=202}} end}
assert(loadfile('Modules/Tiefen/Game.lua'))('AzerothBuddy',B)
assert(loadfile('Modules/Tiefen/Apply.lua'))('AzerothBuddy',B)
assert(T.SyncPoisonDisplay,'native poison display synchronization missing')
T.SyncPoisonDisplay();assert(refreshes==1,'stale Blizzard poison display refreshed')
T.SyncPoisonDisplay();assert(refreshes==1,'matching display not refreshed repeatedly')
slot.selectionNodeInfo.activeEntry.entryID=201
combat=true;T.SyncPoisonDisplay();assert(refreshes==1)
combat=false;staged=true;T.SyncPoisonDisplay();assert(refreshes==1,'uncommitted choice not displayed as saved')
staged=false;slot.IsForbidden=function() return true end
T.SyncPoisonDisplay();assert(refreshes==1,'forbidden slot skipped')
slot.IsForbidden=function() return false end
slot.selectionNodeInfo.activeEntry.entryID=secret
T.SyncPoisonDisplay();assert(refreshes==1,'secret cache not compared')
slot.selectionNodeInfo.activeEntry.entryID=201
panel.IsShown=function() return false end
T.SyncPoisonDisplay();assert(refreshes==1,'hidden panel skipped')
panel.IsShown=function() return true end
slot.Refresh=function() error('native failure') end
assert(pcall(T.SyncPoisonDisplay),'native errors contained')
print('PASS: stale poison cache, idempotence, combat, staged edits, forbidden/secret/hidden frames, errors')
