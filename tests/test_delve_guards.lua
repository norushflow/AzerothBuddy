-- Fremde Blizzard-Fenster und API-Felder im Tiefen-Modul nur gesichert lesen.
-- Belegt Aufrufverträge und Rückfälle; kein Client-, Taint- oder Sichtnachweis.
local B={Tiefen={}}
local TB=B.Tiefen
local secret=setmetatable({}, {__tostring=function() error('secret formatted') end,
 __lt=function() error('secret compared') end,__le=function() error('secret compared') end,
 __concat=function() error('secret concatenated') end,__add=function() error('secret arithmetic') end})
function issecretvalue(v) return rawequal(v,secret) end
function InCombatLockdown() return false end
function UnitAffectingCombat() return false end
function GetSpecialization() return 1 end
function GetSpecializationInfo() return 66,'Valeera',nil,nil,'HEALER' end
function UnitClass() return 'Priester','PRIEST' end
function GetNumGroupMembers() return 2 end
function IsInGroup() return false end
function IsInInstance() return true end
DELVES_LABEL='Tiefen'
Enum={UIWidgetVisualizationType={TextWithState=1,ScenarioHeaderDelves=2},WidgetShownState={Hidden=0},
 CurioType={Combat=0,Utility=1},CompanionRoleType={Dps=0,Heal=1,Tank=2},CurioRarity={Common=1}}

local panel
local messages={}
local shownPanels=0
function ShowUIPanel(frame) shownPanels=shownPanels+1;panel=frame end
C_DelvesUI={
 GetCompanionInfoForActivePlayer=function() return 1 end,
 GetFactionForCompanion=function(id) assert(id==1);return 2744 end,
 GetTraitTreeForCompanion=function() return 1223 end,
 GetRoleNodeForCompanion=function() return nil end,
 GetFlavorNodeForCompanion=function() return nil end,
 GetCurioNodeForCompanion=function() return nil end,
 GetRoleSubtreeForCompanion=function() return 0 end,
 GetActiveDelveTier=function() return {tier='7'} end}
C_Traits={GetConfigIDByTreeID=function(tree) return tree==1223 and 77 or nil end,
 GetConfigInfo=function() return {treeIDs={1223}} end,
 GetNodeInfo=function() return nil end,
 SetSelection=function() return true end,CommitConfig=function() return true end,
 ConfigHasStagedChanges=function() return false end,IsReadyForCommit=function() return true end}
C_GossipInfo={GetFriendshipReputationRanks=function() return {currentLevel=42} end}
C_Scenario={GetInfo=function() return nil end}
C_PartyInfo={IsDelveInProgress=function() return true end}
C_Map={GetBestMapForUnit=function() return 1 end,
 GetMapInfo=function() return {parentMapID=99,name='Tiefe'} end}
C_AreaPoiInfo={GetDelvesForMap=function() return {} end,GetAreaPOIInfo=function() return nil end}
C_UIWidgetManager={GetAllWidgetsBySetID=function() return {} end}

assert(loadfile('Modules/Tiefen/Game.lua'))('AzerothBuddy',B)
TB.active=true;TB.preview=false;TB.context={inside=true}
TB.delves={{map=1,regular=10,rich=11},{map=2,regular=20,rich=21}}
TB.Normalize=function(v) return type(v)=='string' and v:lower() or '' end
TB.order={'role','poison','combat','utility'}
TB.Identify=function(option) return option.key end
TB.Message=function(text) messages[#messages+1]=tostring(text) end

-- Fehlt das Fenster vollständig, bleibt Foreign erfolglos statt zu werfen.
assert(TB.Foreign(nil,function() return true end)==false,'missing frame rejected')
assert(TB.Foreign({},function() return true end)==false,'unreadable frame rejected')

-- F-01: wirft der Zugriff auf das Blizzard-Fenster, arbeitet die Erkennung
-- vollständig über die Begleiter-API weiter.
DelvesCompanionConfigurationFrame={IsForbidden=function() error('frame access denied') end}
local apiSnapshot=TB.Snapshot()
assert(apiSnapshot.companion==1 and apiSnapshot.source=='Begleiter-API','guarded panel falls back to the companion API')
assert(apiSnapshot.config==77 and apiSnapshot.level==42,'fallback keeps configuration and level')

-- Geschützte Fenster liefern kein IsShown; auch dann kein Fehler.
DelvesCompanionConfigurationFrame={IsForbidden=function() return true end,
 IsShown=function() error('protected show state') end,companionInfo={name='Valeera'},playerCompanionID=5}
local forbiddenSnapshot=TB.Snapshot()
assert(forbiddenSnapshot.source=='Begleiter-API' and forbiddenSnapshot.companion==1,'forbidden panel falls back to the API')

-- Der Gutfall bleibt unverändert: sichtbares Valeera-Fenster wird gelesen,
-- geheime Slotwerte werden übersprungen.
local function slot(selection,id)
 return {IsForbidden=function() return false end,configID=id or 77,selectionNodeID=selection}
end
DelvesCompanionConfigurationFrame={IsForbidden=function() return false end,
 IsShown=function() return true end,playerCompanionID=5,companionInfo={name='Valeera'},
 CompanionSlots={CompanionCombatRoleSlot=slot(11),CompanionFlavorSlot=slot(secret),
  CompanionCombatTrinketSlot=slot(13),CompanionUtilityTrinketSlot=slot(14)}}
local nativeSnapshot=TB.Snapshot()
assert(nativeSnapshot.source=='Valeera-Fenster' and nativeSnapshot.config==77,'visible panel still used')

-- F-03: ShowUIPanel bekommt ein geschütztes Fenster nie zu sehen.
messages={};DelvesCompanionConfigurationFrame={IsForbidden=function() error('frame access denied') end}
assert(pcall(TB.OpenCompanion) and shownPanels==0 and #messages==1,'protected panel never passed to ShowUIPanel')
messages={};DelvesCompanionConfigurationFrame={IsForbidden=function() return false end,IsShown=function() return true end}
assert(pcall(TB.OpenCompanion) and shownPanels==1 and #messages==0,'regular panel still opened')

assert(not TB.DelveList and not TB.Resources and not TB.Waypoint and not TB.ActiveTier,
 'Valeera module must not expose removed overview functions')

-- Audit 1.0: bereits die Slotauflösung muss geschützt sein.
DelvesCompanionConfigurationFrame={IsForbidden=function() return false end,IsShown=function() return true end,
 playerCompanionID=1,companionInfo={name='Valeera'},
 CompanionSlots=setmetatable({CompanionCombatRoleSlot=slot(11)},
 {__index=function() error('slot access denied') end})}
local safeSnapshot=TB.Snapshot()
assert(safeSnapshot.config==77,'inaccessible slots must not abort snapshot')
DelvesCompanionConfigurationFrame=nil
-- Secret-Markierung an Grenzen erkennen, bevor Werte an APIs/Indizes gelangen.
local marked={}
function issecretvalue(v) return rawequal(v,secret) or (type(v)=='table' and marked[v]) or false end
local privateIDs={123};marked[privateIDs]=true
C_DelvesUI.GetRoleNodeForCompanion=function() return 11 end
C_Traits.GetNodeInfo=function() return {entryIDs=privateIDs} end
C_Traits.GetEntryInfo=function() error('secret entryIDs traversed') end
assert(pcall(TB.Snapshot),'secret entry list must be skipped')
local entriesRead=0
C_Traits.GetNodeInfo=function() return {entryIDs={22},isVisible=true,isAvailable=secret,activeEntry=secret} end
C_Traits.GetEntryInfo=function() entriesRead=entriesRead+1;return {isAvailable=true,definitionID=secret,conditionIDs=privateIDs} end
C_Traits.GetDefinitionInfo=function() error('secret definition passed to API') end
C_Traits.GetConditionInfo=function() error('secret condition IDs traversed') end
safeSnapshot=TB.Snapshot()
assert(entriesRead==1 and safeSnapshot.slots.role.options[1].available==false and not safeSnapshot.slots.role.current)
GetSpecializationInfo=function() return secret,secret,nil,nil,secret end
UnitClass=function() return secret,secret end
local player=TB.Player()
assert(player.spec==0 and player.role=='DAMAGER' and player.class==nil and type(player.name)=='string')
local inspected=false
function issecretvalue(v) if rawequal(v,secret) then inspected=true;return true end return false end
DelvesCompanionConfigurationFrame={IsForbidden=function() return false end,IsShown=function() return secret end}
assert(TB.Snapshot().source=='Begleiter-API' and inspected,'secret native visibility uses API fallback')
assert(not TB.CanChange and not TB.SaveFavorite and not TB.PurchaseRank,
 'Game.lua exposes no unrelated state or write helpers')
print('PASS: slot-container fallback, nested secret data, sanitized player and visibility')
