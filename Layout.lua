local _, Buddy = ...
-- Fixed offsets in UI points: increase DOWN for more room below minimap icons.
local RIGHT = 2
local DOWN = 40
-- Check before indexing or traversing restricted frames. Keep method lookup
-- inside pcall as well: third-party/Blizzard objects may reject access itself.
local function accessible(frame)
    if not frame then return false end
    local ok, forbidden = pcall(function()
        return frame.IsForbidden and frame:IsForbidden() or false
    end)
    return ok and not (issecretvalue and issecretvalue(forbidden)) and forbidden == false
end
local function invoke(frame, method)
    if not accessible(frame) then return false end
    return pcall(function()
        local fn = frame[method]
        if type(fn) ~= "function" then return end
        return fn(frame)
    end)
end
local function read(frame, method)
    local ok, value = invoke(frame, method)
    if ok and not (issecretvalue and issecretvalue(value)) and type(value)=="number" then return value end
end
function Buddy.MinimapAnchor()
    local bottom = read(Minimap,"GetBottom")
    local mapScale = read(Minimap,"GetEffectiveScale")
    local rootScale = read(UIParent,"GetEffectiveScale")
    local width = read(UIParent,"GetWidth")
    if not bottom or not mapScale or not rootScale or rootScale<=0 or not width then return end
    return width-RIGHT, bottom*mapScale/rootScale-DOWN
end
function Buddy.PlaceAutomatic()
    if not Buddy.db or (InCombatLockdown and InCombatLockdown()) then return end
    if not Buddy.Tiefen.panel then return end
    local right,top=Buddy.MinimapAnchor()
    if not right then return end
    local rootScale=UIParent:GetEffectiveScale()
    local delve=Buddy.Tiefen.panel
    if delve and Buddy.Tiefen.db and not Buddy.Tiefen.db.position and not Buddy.Tiefen.db.unlocked then
        local x,y=right,top
        local factor=delve:GetEffectiveScale()/rootScale
        delve:ClearAllPoints()
        delve:SetPoint("TOPRIGHT",UIParent,"BOTTOMLEFT",x/factor,y/factor)
    end
end
function Buddy.StartLayout()
    -- Apply the requested automatic arrangement once for existing installations.
    if Buddy.db.layoutVersion ~= 2 then
        Buddy.db.delves.position=nil
        Buddy.db.delves.unlocked=false
        Buddy.db.layoutVersion=2
    end
    local frame=CreateFrame("Frame")
    for _,event in ipairs({"PLAYER_ENTERING_WORLD","UI_SCALE_CHANGED","DISPLAY_SIZE_CHANGED","PLAYER_REGEN_ENABLED"}) do
        frame:RegisterEvent(event)
    end
    frame:SetScript("OnEvent",function()
        Buddy.PlaceAutomatic()
        C_Timer.After(1,Buddy.PlaceAutomatic)
    end)
    Buddy.PlaceAutomatic()
end
