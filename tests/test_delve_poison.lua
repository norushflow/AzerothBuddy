local loadfile = dofile("tests/load_locales.lua")
-- Integration: echte Snapshot-/Empfehlungs-/Schreiblogik, nur WoW-APIs ersetzt.
local B={Tiefen={}}
local T=B.Tiefen
function InCombatLockdown() return false end
function UnitAffectingCombat() return false end
C_DelvesUI={GetCompanionInfoForActivePlayer=function() return 1 end,
 GetFactionForCompanion=function() return 2744 end,GetTraitTreeForCompanion=function() return 1223 end,
 GetRoleNodeForCompanion=function() return 11 end,GetFlavorNodeForCompanion=function() return 12 end,
 GetCurioNodeForCompanion=function(kind) return kind==0 and 13 or 14 end}
local active={[11]=101,[12]=202,[13]=301,[14]=401}
local options={[11]={101},[12]={201,202},[13]={301},[14]={401}}
local names={[101]='Heiler',[201]='Frostherzgift',[202]='Aufplatzendes Krötengift',[301]='Viperwindgötze',[401]='Dunduns Gunst'}
local staged,writes={},0
local locked,hold=false,false
C_Spell={GetSpellInfo=function(id) return {name=names[id]} end}
C_Traits={GetConfigIDByTreeID=function() return 77 end,
 GetNodeInfo=function(_,id) return {entryIDs=options[id],activeEntry={entryID=active[id]},isVisible=true,isAvailable=true} end,
 GetEntryInfo=function(_,id) return {subTreeID=0,definitionID=id,isAvailable=not (locked and (id==201 or id==202))} end,
 GetDefinitionInfo=function(id) return {spellID=id,overriddenSpellID=0} end,
 GetSubTreeInfo=function() error('zero is not a subtree') end,
 CanEditConfig=function() return true end,ConfigHasStagedChanges=function() return next(staged)~=nil end,
 SetSelection=function(_,node,entry) writes=writes+1;staged[node]=entry;return true end,
 IsReadyForCommit=function() return true end,
 CommitConfig=function() if not hold then for n,e in pairs(staged) do active[n]=e end;staged={} end;return true end,
 RollbackConfig=function() staged={} end}
for _,file in ipairs({'Game','Rules','Apply'}) do assert(loadfile('Modules/Tiefen/'..file..'.lua'))('AzerothBuddy',B) end
T.db={};T.style='relaxed';T.Context=function() return {inside=true} end
T.Player=function() return {role='DAMAGER',spec=253} end
T.NoteInteraction()
assert(T.Snapshot().slots.poison.options[1].key=='frost','zero subtree/override must read poison spell')
assert(T.ApplyMode('relaxed') and writes==1 and active[12]==201,'only poison differs, actually committed')
assert(active[11]==101 and active[13]==301 and active[14]==401,'other selections preserved')
active[12]=202;locked=true
assert(not T.ApplyMode('relaxed') and writes==1 and T.pendingStyle,'locked poison remains pending')
locked=false;hold=true
assert(not T.TryApply() and T.pendingStyle,'unconfirmed poison never reports success')
print('PASS: real poison discovery, zero IDs, independent commit, locked and unconfirmed poison')

-- GetNodeInfo kann bereits den Entwurf liefern: Das ist keine Speicherbestätigung.
staged={};active[12]=202
C_Traits.CommitConfig=function()
 for node,entry in pairs(staged) do active[node]=entry end
 return true -- staged bleibt gesetzt
end
assert(not T.TryApply() and T.pendingStyle,'staged activeEntry must not confirm success')
T.CheckPending(T.Snapshot(),T.Recommend(T.Player(),T.style,T.Snapshot()))
assert(T.pendingStyle,'read refresh cannot confirm staged selection')
staged={}
T.CheckPending(T.Snapshot(),T.Recommend(T.Player(),T.style,T.Snapshot()))
assert(not T.pendingStyle,'confirmation clears pending only after staged state ends')
