local _, Buddy = ...
-- Questwatcher-Vorlage: transparente Flächen und feine goldene Trennlinien.
-- Ausschließlich eigene Frames; keine Größenabfragen, Hooks oder Timer.
Buddy.Style={BAR="Interface\\TargetingFrame\\UI-StatusBar"}
local function line(frame, anchor, inset, alpha)
    local edge=frame:CreateTexture(nil,"BORDER")
    edge:SetColorTexture(.75,.58,.12,alpha)
    edge:SetPoint(anchor.."LEFT",frame,anchor.."LEFT",inset,0)
    edge:SetPoint(anchor.."RIGHT",frame,anchor.."RIGHT",-inset,0)
    edge:SetHeight(1)
end
function Buddy.Style.Window(frame, headerHeight, opacity)
    headerHeight=headerHeight or 38
    frame:SetBackdrop(nil)
    local bg=frame:CreateTexture(nil,"BACKGROUND")
    bg:SetAllPoints(frame);bg:SetColorTexture(.025,.022,.012,opacity or .72)
    local header=frame:CreateTexture(nil,"BACKGROUND",nil,1)
    header:SetPoint("TOPLEFT");header:SetPoint("TOPRIGHT");header:SetHeight(headerHeight)
    header:SetColorTexture(.16,.12,.025,.32)
    line(frame,"TOP",0,.85);line(frame,"BOTTOM",0,.55)
    local divider=frame:CreateTexture(nil,"BORDER")
    divider:SetPoint("TOPLEFT",8,-headerHeight);divider:SetPoint("TOPRIGHT",-8,-headerHeight)
    divider:SetHeight(1);divider:SetColorTexture(.75,.58,.12,.45)
end
function Buddy.Style.Inset(frame)
    frame:SetBackdrop(nil)
    local bg=frame:CreateTexture(nil,"BACKGROUND")
    bg:SetAllPoints(frame);bg:SetColorTexture(.04,.035,.015,.35)
    line(frame,"BOTTOM",0,.35)
end
function Buddy.Style.Button(button)
    button:SetNormalTexture("");button:SetPushedTexture("");button:SetDisabledTexture("")
    -- UIPanelButtonTemplate zeichnet seine rote Fläche je nach Client in Teiltexturen.
    for _,key in ipairs({"Left","Middle","Right","LeftDisabled","MiddleDisabled","RightDisabled"}) do
        local region=button[key]
        if (type(region)=="table" or type(region)=="userdata") and region.Hide then region:Hide() end
    end
    local bg=button:CreateTexture(nil,"BACKGROUND")
    bg:SetAllPoints(button);bg:SetColorTexture(.10,.08,.015,.48)
    line(button,"BOTTOM",3,.6)
    button:SetHighlightTexture("Interface\\Buttons\\WHITE8X8","ADD")
    local highlight=button:GetHighlightTexture()
    if highlight then highlight:SetVertexColor(.65,.48,.08,.18) end
    return button
end
