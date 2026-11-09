local loadfile = dofile("tests/load_locales.lua")
local B={db={omnium={}}}
SlashCmdList={}
local queue={}
C_Timer={After=function(delay,fn) queue[#queue+1]={delay,fn} end}
function CreateFrame() return {RegisterEvent=function() end,SetScript=function(self,_,fn) self.handler=fn end} end
local spec,role,class=66,'TANK','PALADIN'
local inCombat=false
function GetSpecialization() return 1 end
function GetSpecializationInfo() return spec,'Spec',nil,nil,role end
function UnitClass() return 'Class',class end
function InCombatLockdown() return inCombat end
local secret={}
function issecretvalue(v) return v==secret end
for _,name in ipairs({'Presets','Main'}) do assert(loadfile('Modules/Omnium/'..name..'.lua'))('AzerothBuddy',B) end
B.LoadOmnium()
local O=B.Omnium
local rows={{'fire','orbs'},{'mend','shell'},{'lingering'},{'crit','haste','mastery','versatility'},{'overload','echoes','residual'}}
local nodes,entries={},{}
for i,keys in ipairs(rows) do
 local n={entryIDs={},activeRank=0,isAvailable=true,isVisible=true};nodes[i]=n
 for j,key in ipairs(keys) do local id=i*100+j;n.entryIDs[j]=id;entries[id]={definitionID=O.runes[key],isAvailable=true} end
end
local wrong,staged,reject,hold=false,false,false,false
local writes,commits,rollbacks=0,0,0
local snapshot
local function copyNodes()
 local out={};for i,n in ipairs(nodes) do out[i]={rank=n.activeRank,entry=n.activeEntry and n.activeEntry.entryID} end;return out
end
local function begin() if not staged then snapshot=copyNodes() end;staged=true end
C_Traits={
 GetConfigIDByTreeID=function(tree) assert(tree==1186);return 77 end,
 GetConfigInfo=function() return {treeIDs={wrong and 999 or 1186}} end,
 GetTreeNodes=function() return {1,2,3,4,5} end,
 GetNodeInfo=function(_,id) return nodes[id] end,
 GetEntryInfo=function(_,id) return entries[id] end,
 GetDefinitionInfo=function(id) return {spellID=id} end,
 ConfigHasStagedChanges=function() return staged end,
 CanEditConfig=function() return true end,
 CanPurchaseRank=function(_,id) return nodes[id].isAvailable end,
 SetSelection=function(id,node,entry) assert(id==77);writes=writes+1;begin();nodes[node].activeEntry={entryID=entry};return true end,
 PurchaseRank=function(id,node) assert(id==77);writes=writes+1;begin();local n=nodes[node];n.activeRank=1;n.activeEntry=n.activeEntry or {entryID=n.entryIDs[1]};return true end,
 IsReadyForCommit=function() return true end,
 CommitConfig=function(id) assert(id==77);commits=commits+1;if reject then return false end;if not hold then staged=false end;return true end,
 RollbackConfig=function() rollbacks=rollbacks+1;if snapshot then for i,v in ipairs(snapshot) do nodes[i].activeRank=v.rank;nodes[i].activeEntry=v.entry and {entryID=v.entry} or nil end end;staged=false;return true end,
}
local function drain()
 local count=0
 while #queue>0 do
  table.sort(queue,function(a,b)return a[1]<b[1] end)
  local task=table.remove(queue,1);task[2]();count=count+1;assert(count<100,'unbounded loop')
 end
end
O.Apply(true);drain();assert(commits==5 and not O.pending and not O.running)
for _,row in ipairs(O.Read().rows) do assert(row.match) end
local before=writes;O.Apply(true);drain();assert(writes==before,'idempotent')
spec=253;role='DAMAGER';class='HUNTER'
inCombat=true;O.Apply(false);assert(writes==before)
inCombat=false;O.events.handler(nil,'PLAYER_REGEN_ENABLED');drain();assert(commits==6,'role switch updates secondary stat')
staged=true;spec=66;role='TANK';class='PALADIN';before=writes;O.Apply(true);drain();assert(writes==before and staged,'manual staging preserved')
staged=false;wrong=true;O.Apply(true);drain();assert(writes==before,'wrong tree untouched')
wrong=false;reject=true;O.Apply(true);drain();assert(rollbacks==1 and not staged and not O.pending,'rejection rolls back own edit')
reject=false;hold=true;O.Apply(true);drain();assert(not O.pending and not O.running and O.status:find('Speicherbestätigung'),'timeout stops')
C_Traits.RollbackConfig();hold=false
GenericTraitFrame={IsShown=function() return true end};before=writes;O.Apply(false);assert(writes==before,'automatic editor pause')
-- F-05: geschützte oder nicht lesbare Fenster dürfen die Automatik nicht werfen.
GenericTraitFrame={IsForbidden=function() return true end,IsShown=function() error('protected frame read') end}
before=writes;assert(pcall(O.Apply,false) and writes==before,'protected editor frame pauses without error')
GenericTraitFrame={IsForbidden=function() error('access denied') end}
before=writes;assert(pcall(O.Apply,false) and writes==before,'unreadable editor frame pauses without error')
GenericTraitFrame=nil;O.db.auto=false;O.Apply(false);assert(writes==before,'auto off')
O.db.auto=true
nodes[1].activeEntry={entryID=102};nodes[1].isAvailable=false;O.Apply(true);drain();assert(O.status:find('Nicht erkannt oder gesperrt'),'locked row skipped')
nodes[1].isAvailable=true
-- Changing spec before confirmation stops the old profile's remaining steps.
O.Apply(true);spec=253;class='HUNTER';role='DAMAGER';drain()
for _,row in ipairs(O.Read().rows) do assert(row.match) end
local profile,source=O.Preset(257,'PRIEST','HEALER')
assert(profile[1]=='orbs' and profile[4]=='haste' and source:find('Heiler'))
assert(O.Preset(66,'PALADIN','TANK','versatility')[4]=='versatility')
entries[101].definitionID=secret;assert(pcall(O.Read),'secret definition ignored')
print('PASS: five commits, idempotence, spec change, combat, staging, tree isolation, rejection, timeout, editor pause, locked rows, presets, secrets')

-- Talent spells can differ from their effect spell while using identical names.
entries[101].definitionID=O.runes.fire
C_Spell={GetSpellInfo=function(id)
 local names={[O.runes.lingering]='Rune des Nachklangs',[O.runes.versatility]='Rune der kritischen Macht',
 [900001]='Rune des Nachklangs',[900002]='Rune der kritischen Macht',[900003]='Rune der kritischen Macht verbessert'}
 if names[id] then return {name=names[id]} end
end}
local original=C_Traits.GetDefinitionInfo
C_Traits.GetDefinitionInfo=function(id)
 if id==O.runes.lingering then return {spellID=900001} end
 if id==O.runes.versatility then return {spellID=900002} end
 return original(id)
end
spec=66;role='TANK';class='PALADIN'
O.Apply(true);drain()
local state=O.Read()
assert(state.rows[3].match and state.rows[4].match,'alternate spell IDs recognized and applied')
assert(not O.Matches({spellID=900003},'crit'),'no substring match')
assert(not O.Matches({spellID=secret,overrideName=secret},'crit'),'secret values rejected')
entries[499]={definitionID=900002,isAvailable=true};table.insert(nodes[4].entryIDs,499)
assert(O.Read().rows[4].ambiguous and not O.Read().rows[4].available,'duplicate name blocks writes')
print('PASS: alternate talent/effect IDs, exact localized names, secret rejection and ambiguity guard')

local count=0
for role,keys in pairs(O.profiles) do
 count=count+1;assert(#keys==5 and O.roleLabels[role])
 for _,key in ipairs(keys) do assert(O.runes[key] and O.labels[key]) end
end
assert(count==3 and #O.roles==3)
assert(O.Preset(999)==nil)
O.db.role='HEALER'
assert(O.Preset(66,'PALADIN','TANK')[1]=='orbs')
assert(not O.SelectRole('custom'))
O.db.role=nil
-- Overview must show the selected rune, not the recommended replacement.
C_Spell.GetSpellInfo=function(id) return {name='Spell '..id,iconID=id} end
nodes[1].activeEntry={entryID=101};nodes[1].activeRank=1
local active=O.Read().rows[1]
assert(active.key=='fire' and active.match)
assert(active.activeSpell==O.runes.fire and active.activeIcon==O.runes.fire)
assert(active.activeName=='Spell '..O.runes.fire)
nodes[1].activeRank=0
assert(O.Read().rows[1].activeSpell==nil)
print('PASS: overview shows actual selection, handles unlearned rune')

-- Audit 1.0: auch erfolgreich gelesene Sichtbarkeit kann geheim sein.
local previousStep=O.Step
local steps=0
O.Step=function() steps=steps+1;O.running=nil end
O.pending=nil;O.running=nil;O.db.auto=true
local checkedSecret=false
function issecretvalue(v) if rawequal(v,secret) then checkedSecret=true;return true end return false end
GenericTraitFrame={IsForbidden=function() return false end,IsShown=function() return secret end}
assert(pcall(O.Apply,false) and checkedSecret and steps==0,'secret visibility pauses automatic writes')
GenericTraitFrame={IsForbidden=function() return false end,IsShown=function() return false end}
O.Apply(false);assert(steps==1,'public hidden editor permits automatic processing')
GenericTraitFrame=nil;O.Step=previousStep
print('PASS: secret editor visibility pauses, public hidden editor resumes')

-- Jede der drei sichtbaren Rollen wird über dieselbe Schreiblogik übernommen.
C_Traits.GetDefinitionInfo=original
nodes[4].entryIDs={401,402,403,404}
for _,roleKey in ipairs(O.roles) do
 assert(O.SelectRole(roleKey));drain()
 for _,row in ipairs(O.Read().rows) do assert(row.match,roleKey..': incomplete selection') end
 local before=writes;assert(O.SelectRole(roleKey));drain();assert(writes==before)
end
O.pending={};local before=writes;assert(O.SelectRole('TANK') and writes==before and O.requestedRole=='TANK','role choice queued without writing');O.pending=nil;O.requestedRole=nil
print('PASS: all three role selections commit fully and idempotently')

-- Benutzerwahl während einer laufenden automatischen Übernahme darf nicht verloren gehen.
O.db.role='DAMAGER';O.pending=nil;O.running=nil;hold=true
nodes[4].activeEntry={entryID=404};nodes[4].activeRank=1
nodes[5].activeEntry={entryID=502};nodes[5].activeRank=1
O.Apply(false)
assert(O.pending,'automatic write awaiting confirmation')
assert(O.SelectRole('HEALER'),'first role click must be accepted while saving')
assert(O.db.role=='DAMAGER','do not change an in-flight transaction')
local writesPending=writes
assert(O.SelectRole('TANK'),'latest explicit selection replaces earlier request')
assert(writes==writesPending,'no concurrent writes')
hold=false;staged=false
O.events.handler(nil,'TRAIT_CONFIG_UPDATED',77);drain()
assert(O.db.role=='TANK','queued choice applied without second click')
for _,row in ipairs(O.Read().rows) do assert(row.match,'queued profile fully confirmed') end
assert(not O.pending and not O.running and not O.requestedRole)
print('PASS: first click during automatic commit retained; latest choice applied after confirmation')

-- Ablehnung darf die gemerkte Wahl nicht als automatischen Wiederholungsauftrag behalten.
O.db.role='DAMAGER';nodes[4].activeEntry={entryID=404};hold=true
O.Apply(false);assert(O.pending);assert(O.SelectRole('HEALER'))
local failureWrites=writes
O.events.handler(nil,'CONFIG_COMMIT_FAILED',77)
assert(not O.requestedRole and not O.pending and not O.running)
drain();assert(writes==failureWrites,'no retry after failed commit')
print('PASS: rejected save clears queued selection without retry')
