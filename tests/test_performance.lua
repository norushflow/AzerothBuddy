-- Deterministic API-call counts; does not claim in-game FPS measurements.
local root=arg[1] or '.'
local B={}
assert(loadfile(root..'/Core.lua'))('AzerothBuddy',B)
if B.FadeTo then
 local f={alpha=1}
 function f:GetAlpha() return self.alpha end
 function f:SetAlpha(v) self.alpha=v end
 function f:SetScript(_,fn) self.update=fn end
 B.FadeTo(f,.12)
 for i=1,120 do if f.update then f:update(1/60) end end
 assert(f.alpha==.12 and not f.update,'fade callback detaches when complete')
 B.FadeTo(f,1)
 for i=1,120 do if f.update then f:update(1/60) end end
 assert(f.alpha==1 and not f.update,'fade resumes on target change')
end
function InCombatLockdown() return false end
function GetSpecialization() return 1 end
function GetSpecializationInfo() return 66,'Protection',nil,nil,'TANK' end
function UnitClass() return 'Paladin','PALADIN' end
local reads=0
C_Spell={GetSpellInfo=function(id) reads=reads+1;return {name='Spell '..id,iconID=id} end}
assert(loadfile(root..'/Modules/Omnium/Presets.lua'))('AzerothBuddy',B)
assert(loadfile(root..'/Modules/Omnium/Main.lua'))('AzerothBuddy',B)
local O=B.Omnium;O.db={stats={}}
local nodes,entries={},{}
for i,keys in ipairs({{'fire','orbs'},{'mend','shell'},{'lingering'},{'crit','haste','mastery','versatility'},{'overload','echoes','residual'}}) do
 local n={entryIDs={},activeRank=1,isAvailable=true,isVisible=true};nodes[i]=n
 for j,key in ipairs(keys) do local id=i*100+j;n.entryIDs[j]=id;entries[id]={definitionID=O.runes[key],isAvailable=true} end
 n.activeEntry={entryID=n.entryIDs[1]}
end
C_Traits={GetConfigIDByTreeID=function() return 77 end,GetConfigInfo=function() return {treeIDs={1186}} end,
 GetTreeNodes=function() return {1,2,3,4,5} end,GetNodeInfo=function(_,id) return nodes[id] end,
 GetEntryInfo=function(_,id) return entries[id] end,GetDefinitionInfo=function(id) return {spellID=id} end}
local state=O.Read();assert(#state.rows==5 and state.rows[1].activeSpell==O.runes.fire)
print('Omnium spell API calls per scan: '..reads)
if not arg[1] then assert(reads<=20,'per-scan spell name cache') end
print('PASS: performance counters and fade lifecycle')
