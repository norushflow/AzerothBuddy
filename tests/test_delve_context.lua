-- Valeera-Kontext ohne Stufen-, POI-, Ressourcen- oder Journalabfragen.
local TB={}
assert(loadfile('Modules/Tiefen/Game.lua'))('AzerothBuddy',{Tiefen=TB})
local secret={}
function issecretvalue(v) return rawequal(v,secret) end
local inside,delve,scenario,map=false,true,nil,123
function IsInInstance() return inside end
C_Map={GetBestMapForUnit=function() error('no map lookup needed for advisor') end,GetMapInfo=function() error('overview read') end}
C_PartyInfo={IsDelveInProgress=function() return delve end}
C_Scenario={GetInfo=function() return scenario end,GetStepInfo=function() error('tier read') end}
DELVES_LABEL='Tiefen'
assert(not TB.Context().inside,'outside instance stays inactive')
inside=true;assert(TB.Context().inside)
delve=false;assert(not TB.Context().inside,'ordinary instance stays inactive')
scenario='Tiefen';assert(TB.Context().inside,'scenario fallback')
scenario=secret;assert(not TB.Context().inside,'secret scenario ignored')
delve=secret;map=secret;assert(not TB.Context().inside and TB.Context().map==nil)
inside=secret;delve=true;assert(not TB.Context().inside,'unknown instance status ignored')
assert(not TB.ActiveTier and not TB.DelveList and not TB.Resources and not TB.Waypoint)
print('PASS: Valeera instance context, scenario fallback, secret guards and removed overview')
