local loadfile = dofile("tests/load_locales.lua")
local function frame(l,r,t,b,scale)
 local f={l=l,r=r,t=t,b=b,scale=scale or 1,children={},shown=true}
 function f:GetWidth() return self.r-self.l end
 function f:GetLeft() return self.l end
 function f:GetRight() return self.r end
 function f:GetTop() return self.t end
 function f:GetBottom() return self.b end
 function f:GetEffectiveScale() return self.scale end
 function f:IsShown() return self.shown end
 function f:GetChildren() return unpack(self.children) end
 function f:ClearAllPoints() end
 function f:SetPoint(_,_,_,x,y) self.x=x;self.y=y end
 return f
end
UIParent=frame(0,1920,1080,0)
local rootScaleReads=0
function UIParent:GetEffectiveScale() rootScaleReads=rootScaleReads+1;return self.scale end
Minimap=frame(1700,1900,1050,850)
MinimapCluster=frame(1700,1900,1050,820)
local bar=frame(1750,1900,830,806)
local unrelated=frame(1600,1900,840,200)
UIParent.children={bar,unrelated}
local delve=frame(0,438,660,0,0.8)
local Buddy={db={delves={}},Tiefen={panel=delve,db={}}}
local combat=false
function InCombatLockdown() return combat end
assert(loadfile('Layout.lua'))('AzerothBuddy',Buddy)
Buddy.PlaceAutomatic()
assert(delve.x*0.8==1918 and delve.y*0.8==810,'delve uses free minimap anchor')
assert(rootScaleReads==1,'placement reuses the validated root scale')
Buddy.Tiefen.db.position={};delve.x=10
Buddy.PlaceAutomatic();assert(delve.x==10,'manual position respected')
Buddy.Tiefen.db.position=nil;Buddy.Tiefen.db.unlocked=true
Buddy.PlaceAutomatic();assert(delve.x==10,'unlocked window can be dragged')
Buddy.Tiefen.db.unlocked=false;combat=true
Buddy.PlaceAutomatic();assert(delve.x==10,'no reanchoring during combat')
assert(rootScaleReads==1,'manual, unlocked and combat layouts skip geometry reads')
combat=false;bar.shown=false
local x,y=Buddy.MinimapAnchor();assert(x==1918 and y==810,'hidden icon bar ignored')
print('PASS: minimap/icon clearance, scaled alignment, manual positions, dragging and combat')

-- Never traverse unrelated UIParent dialogs, even if they appear readable.
local dialog=frame(0,300,400,100)
function dialog:GetChildren() error('unrelated dialog traversed') end
UIParent.children={bar,dialog}
Buddy.MinimapAnchor()
-- Forbidden children must not receive geometry/visibility/children calls.
local forbidden={IsForbidden=function() return true end}
setmetatable(forbidden,{__index=function() error('forbidden object accessed') end})
Minimap.children={forbidden}
UIParent.children={forbidden,bar,dialog}
Buddy.MinimapAnchor()
-- Enumeration failures must not break the periodic layout callback.
local broken=frame(1750,1800,830,810)
function broken:GetChildren() error('enumeration rejected') end
Minimap.children={broken}
assert(pcall(Buddy.MinimapAnchor))
print('PASS: forbidden objects skipped, unrelated dialogs not traversed, enumeration errors contained')

function UIParent:GetChildren() error('frame searching forbidden') end
function Minimap:GetChildren() error('frame searching forbidden') end
function MinimapCluster:GetChildren() error('frame searching forbidden') end
assert(pcall(Buddy.MinimapAnchor))
print('PASS: fixed offsets work without any frame search')

-- Upgrade must discard old coordinates and unlock flags that override anchoring.
function CreateFrame() return {RegisterEvent=function() end,SetScript=function() end} end
C_Timer={After=function() end}
Buddy.db.layoutVersion=1
Buddy.db.delves.position={}; Buddy.db.delves.unlocked=true
Buddy.Tiefen.db=Buddy.db.delves
Buddy.StartLayout()
print('PASS: upgrade resets stale delve positioning')

assert(Buddy.db.layoutVersion==2 and not Buddy.db.delves.position and not Buddy.db.delves.unlocked)
assert(delve.x*0.8==1918 and delve.y*0.8==810)
