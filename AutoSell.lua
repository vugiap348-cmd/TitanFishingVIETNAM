-- ================================================================
-- TITAN FISHING v18  |  GUI kieu Hub (sidebar + content) 
-- Logic: 2 mang click doc lap | Token stop | Fix tam click
-- ================================================================
local Players = game:GetService("Players")
local UIS     = game:GetService("UserInputService")
local RS      = game:GetService("RunService")
local PFS     = game:GetService("PathfindingService")
local TS      = game:GetService("TweenService")
local VIM     = game:GetService("VirtualInputManager")
local GS      = game:GetService("GuiService")
local LP      = Players.LocalPlayer

-- ================================================================
-- STATE
-- ================================================================
local isRunning    = false
local statusText   = "Chua bat"
local sellCount    = 0
local fishCaught   = 0
local fishSession  = 0
local fishMinutes  = 1
local countdownSec = 0
local isSelling    = false

local savedFishPos  = nil
local savedNPCPos   = nil
local savedSellPos  = nil
local savedClosePos = nil
local savedCastPos  = nil
local zxcvPos       = {nil,nil,nil,nil}
local zxcvCooldown  = {1.0,1.0,1.0,1.0}
local zxcvNames     = {"Z","X","C","V"}
local zxcvColors    = {
    Color3.fromRGB(80,160,255),
    Color3.fromRGB(200,80,255),
    Color3.fromRGB(255,110,40),
    Color3.fromRGB(40,220,170),
}

-- ================================================================
-- CLICK (2 mang doc lap, token stop)
-- ================================================================
local castActive  = false
local skillActive = false
local castToken   = 0
local skillTokens = {0,0,0,0}

local function doClick(x, y)
    VIM:SendMouseButtonEvent(x, y, 0, true,  game, 0)
    task.wait(0.06)
    VIM:SendMouseButtonEvent(x, y, 0, false, game, 0)
end

local function startCastLoop()
    castToken = castToken + 1
    local tk = castToken
    task.spawn(function()
        while castActive and castToken == tk do
            if savedCastPos and not isSelling then
                pcall(doClick, savedCastPos.X, savedCastPos.Y)
            end
            task.wait(0.45)
        end
    end)
end

local function startSkillLoop(idx)
    skillTokens[idx] = skillTokens[idx] + 1
    local tk = skillTokens[idx]
    task.spawn(function()
        task.wait((idx-1)*0.08)
        while skillActive and skillTokens[idx] == tk do
            if zxcvPos[idx] and not isSelling then
                pcall(doClick, zxcvPos[idx].X, zxcvPos[idx].Y)
                local cd = zxcvCooldown[idx] or 1.0
                local t  = 0
                while t < cd do
                    task.wait(0.05); t = t+0.05
                    if not skillActive or skillTokens[idx] ~= tk then return end
                end
            else
                task.wait(0.1)
                if not skillActive or skillTokens[idx] ~= tk then return end
            end
        end
    end)
end

local function startAllSkills()
    for i=1,4 do startSkillLoop(i) end
end

local function stopAllSpam()
    castActive  = false
    skillActive = false
    castToken   = castToken + 1
    for i=1,4 do skillTokens[i] = skillTokens[i]+1 end
end

-- ================================================================
-- WALK
-- ================================================================
local function walkTo(pos, lbl)
    local char = LP.Character; if not char then return end
    local hrp  = char:FindFirstChild("HumanoidRootPart")
    local hum  = char:FindFirstChild("Humanoid")
    if not hrp or not hum then return end
    statusText = lbl or "Dang di..."
    hum.WalkSpeed = 24
    local path = PFS:CreatePath({AgentHeight=5,AgentRadius=2,AgentCanJump=true})
    local ok   = pcall(function() path:ComputeAsync(hrp.Position, pos) end)
    if ok and path.Status == Enum.PathStatus.Success then
        for _, wp in ipairs(path:GetWaypoints()) do
            if not isRunning then return end
            if wp.Action == Enum.PathWaypointAction.Jump then hum.Jump = true end
            hum:MoveTo(wp.Position); hum.MoveToFinished:Wait(3)
            if (hrp.Position-pos).Magnitude < 8 then break end
        end
    else
        hum:MoveTo(pos); local t=0
        while t<12 and isRunning do
            task.wait(0.2); t=t+0.2
            if (hrp.Position-pos).Magnitude < 8 then break end
        end
    end
end

local function stopWalk()
    local c=LP.Character
    local h=c and c:FindFirstChild("Humanoid")
    local r=c and c:FindFirstChild("HumanoidRootPart")
    if h and r then h:MoveTo(r.Position) end
end

-- ================================================================
-- INTERACT + SELL
-- ================================================================
local function uiClick(x, y)
    pcall(function() VIM:SendMouseMoveEvent(x, y, game) end)
    task.wait(0.04)
    pcall(function() VIM:SendMouseButtonEvent(x, y, 0, true,  game, 0) end)
    task.wait(0.1)
    pcall(function() VIM:SendMouseButtonEvent(x, y, 0, false, game, 0) end)
    task.wait(0.05)
end

local function doInteract()
    statusText = "Mo cua hang..."
    local char=LP.Character; local hrp=char and char:FindFirstChild("HumanoidRootPart")
    if hrp then
        local best,bestD=nil,math.huge
        for _,v in ipairs(workspace:GetDescendants()) do
            if v:IsA("ProximityPrompt") then
                local p=v.Parent
                if p and p:IsA("BasePart") then
                    local d=(hrp.Position-p.Position).Magnitude
                    if d<bestD then bestD=d; best=v end
                end
            end
        end
        if best and bestD<20 then
            pcall(function() fireproximityprompt(best) end); task.wait(0.5)
        end
    end
    task.wait(0.8)
end

local function doSellAll()
    if not savedSellPos or not savedClosePos then
        statusText="Chua luu SellAll/X!"; task.wait(2); return
    end
    statusText="Cho popup..."; task.wait(0.8)
    uiClick(savedSellPos.X, savedSellPos.Y); task.wait(1.2)
    uiClick(savedClosePos.X, savedClosePos.Y); task.wait(0.5)
    statusText="Da ban xong!"
end

-- ================================================================
-- MAIN LOOP
-- ================================================================
local function mainLoop()
    local miss={}
    if not savedFishPos  then table.insert(miss,"Vi tri cau") end
    if not savedNPCPos   then table.insert(miss,"Vi tri NPC") end
    if not savedSellPos  then table.insert(miss,"SellAll") end
    if not savedClosePos then table.insert(miss,"X dong") end
    if not savedCastPos  then table.insert(miss,"Nut Fishing") end
    local hz=false; for i=1,4 do if zxcvPos[i] then hz=true end end
    if not hz then table.insert(miss,"ZXCV") end
    if #miss>0 then
        statusText="Thieu: "..table.concat(miss,", ").."!"
        isRunning=false; return
    end

    while isRunning do
        isSelling=false; stopAllSpam(); task.wait(0.15)
        local char=LP.Character
        local hrp=char and char:FindFirstChild("HumanoidRootPart")
        if hrp and savedFishPos and (hrp.Position-savedFishPos).Magnitude>5 then
            walkTo(savedFishPos,"Di ve vi tri cau...")
            if not isRunning then break end
            stopWalk(); task.wait(0.5)
        end

        castActive=true; skillActive=true
        startCastLoop(); startAllSkills()

        countdownSec=fishMinutes*60
        while countdownSec>0 and isRunning do
            local m=math.floor(countdownSec/60)
            local s=countdownSec%60
            statusText=m..":"..string.format("%02d",s).." | Ca:"..fishCaught.." Ban:"..sellCount
            task.wait(1); countdownSec=countdownSec-1
        end
        if not isRunning then break end

        isSelling=true; stopAllSpam(); task.wait(0.2)
        statusText="Het gio! Di ban..."
        fishCaught=fishCaught+1; fishSession=fishSession+1

        walkTo(savedNPCPos,"Di toi NPC...")
        if not isRunning then break end
        task.wait(0.3); stopWalk(); task.wait(0.5)
        doInteract(); task.wait(0.5)
        doSellAll();  task.wait(0.5)

        sellCount=sellCount+1
        statusText="Da ban lan "..sellCount.."! Quay lai..."
        task.wait(1)
    end

    stopAllSpam(); isSelling=false; countdownSec=0; statusText="Da tat"
end

-- ================================================================
-- GUI - KHFRESH HUB STYLE
-- ================================================================
local old=LP.PlayerGui:FindFirstChild("TFHub"); if old then old:Destroy() end
local sg=Instance.new("ScreenGui")
sg.Name="TFHub"; sg.ResetOnSpawn=false
sg.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; sg.Parent=LP.PlayerGui

local INSET = GS:GetGuiInset()

-- ===== MARKERS (giong v17, draggable, tam chinh xac) =====
local function makeMarker(col, tag)
    local S=70
    local m=Instance.new("TextButton")
    m.Size=UDim2.new(0,S,0,S); m.Position=UDim2.new(0.5,-S/2,0.5,-S/2)
    m.BackgroundColor3=col; m.BackgroundTransparency=0.3
    m.BorderSizePixel=0; m.Text=""; m.ZIndex=80
    m.Active=true; m.Draggable=true; m.Visible=false; m.Parent=sg
    Instance.new("UICorner",m).CornerRadius=UDim.new(1,0)
    Instance.new("UIStroke",m).Color=Color3.new(1,1,1)
    local ch=Instance.new("Frame",m); ch.Size=UDim2.new(1,0,0,2); ch.Position=UDim2.new(0,0,0.5,-1)
    ch.BackgroundColor3=Color3.fromRGB(255,255,0); ch.BorderSizePixel=0; ch.ZIndex=81
    local cv=Instance.new("Frame",m); cv.Size=UDim2.new(0,2,1,0); cv.Position=UDim2.new(0.5,-1,0,0)
    cv.BackgroundColor3=Color3.fromRGB(255,255,0); cv.BorderSizePixel=0; cv.ZIndex=81
    local dot=Instance.new("Frame",m); dot.Size=UDim2.new(0,10,0,10); dot.Position=UDim2.new(0.5,-5,0.5,-5)
    dot.BackgroundColor3=Color3.fromRGB(255,0,0); dot.BorderSizePixel=0; dot.ZIndex=82
    Instance.new("UICorner",dot).CornerRadius=UDim.new(1,0)
    local tl=Instance.new("TextLabel",m); tl.Size=UDim2.new(1,0,0,16); tl.Position=UDim2.new(0,0,1,2)
    tl.BackgroundColor3=Color3.fromRGB(0,0,0); tl.BackgroundTransparency=0.4
    tl.Text=tag; tl.TextColor3=Color3.fromRGB(255,255,0)
    tl.Font=Enum.Font.GothamBlack; tl.TextSize=11; tl.ZIndex=82
    Instance.new("UICorner",tl).CornerRadius=UDim.new(0,4)
    RS.Heartbeat:Connect(function()
        if m.Visible then m.BackgroundTransparency=0.1+math.abs(math.sin(tick()*2.5))*0.35 end
    end)
    return m
end

local markerSell  = makeMarker(Color3.fromRGB(20,200,100),"SELL")
local markerClose = makeMarker(Color3.fromRGB(220,40,60),"CLOSE")
local markerCast  = makeMarker(Color3.fromRGB(255,200,0),"FISHING")
local zxcvMarkers = {}
for i=1,4 do zxcvMarkers[i]=makeMarker(zxcvColors[i],zxcvNames[i]) end

local function getCenter(m)
    local ap=m.AbsolutePosition; local as=m.AbsoluteSize
    return ap.X+as.X*0.5+INSET.X, ap.Y+as.Y*0.5+INSET.Y
end

-- ================================================================
-- HUB WINDOW
-- ================================================================
local HW, HH = 500, 340   -- kich thuoc cua so hub

local hub = Instance.new("Frame")
hub.Name = "HubWindow"
hub.Size = UDim2.new(0,HW,0,HH)
hub.Position = UDim2.new(0.5,-HW/2, 0.5,-HH/2)
hub.BackgroundColor3 = Color3.fromRGB(18,18,28)
hub.BorderSizePixel = 0
hub.Active = true; hub.Draggable = true
hub.ClipsDescendants = false
hub.ZIndex = 10; hub.Parent = sg
Instance.new("UICorner",hub).CornerRadius = UDim.new(0,14)
local hubStroke = Instance.new("UIStroke",hub)
hubStroke.Color = Color3.fromRGB(50,50,80); hubStroke.Thickness = 1.5

-- Drop shadow (gott image)
local shadow = Instance.new("Frame",hub)
shadow.Size = UDim2.new(1,20,1,20); shadow.Position = UDim2.new(0,-10,0,8)
shadow.BackgroundColor3 = Color3.fromRGB(0,0,0); shadow.BackgroundTransparency = 0.6
shadow.BorderSizePixel = 0; shadow.ZIndex = 9
Instance.new("UICorner",shadow).CornerRadius = UDim.new(0,18)

-- ================================================================
-- HEADER BAR
-- ================================================================
local SIDEBAR_W = 130
local header = Instance.new("Frame",hub)
header.Size = UDim2.new(1,0,0,48)
header.Position = UDim2.new(0,0,0,0)
header.BackgroundColor3 = Color3.fromRGB(12,12,22)
header.BorderSizePixel = 0; header.ZIndex = 11
Instance.new("UICorner",header).CornerRadius = UDim.new(0,14)

-- gradient header
local hg = Instance.new("UIGradient",header)
hg.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(30,20,60)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(12,12,22)),
}); hg.Rotation = 90

-- Avatar circle
local ava = Instance.new("Frame",header)
ava.Size = UDim2.new(0,32,0,32); ava.Position = UDim2.new(0,10,0.5,-16)
ava.BackgroundColor3 = Color3.fromRGB(255,140,0); ava.BorderSizePixel = 0; ava.ZIndex = 12
Instance.new("UICorner",ava).CornerRadius = UDim.new(1,0)
local avaLbl = Instance.new("TextLabel",ava)
avaLbl.Size = UDim2.new(1,0,1,0); avaLbl.BackgroundTransparency = 1
avaLbl.Text = "TF"; avaLbl.Font = Enum.Font.GothamBlack; avaLbl.TextSize = 11
avaLbl.TextColor3 = Color3.new(1,1,1); avaLbl.ZIndex = 13

-- Title
local titleLbl = Instance.new("TextLabel",header)
titleLbl.Size = UDim2.new(0,160,0,22); titleLbl.Position = UDim2.new(0,48,0,6)
titleLbl.BackgroundTransparency = 1; titleLbl.Text = "Titan Fishing"
titleLbl.Font = Enum.Font.GothamBlack; titleLbl.TextSize = 14
titleLbl.TextColor3 = Color3.new(1,1,1); titleLbl.TextXAlignment = Enum.TextXAlignment.Left
titleLbl.ZIndex = 12

local subLbl = Instance.new("TextLabel",header)
subLbl.Size = UDim2.new(0,160,0,16); subLbl.Position = UDim2.new(0,48,0,26)
subLbl.BackgroundTransparency = 1; subLbl.Text = "Auto v18"
subLbl.Font = Enum.Font.Gotham; subLbl.TextSize = 10
subLbl.TextColor3 = Color3.fromRGB(150,150,200); subLbl.TextXAlignment = Enum.TextXAlignment.Left
subLbl.ZIndex = 12

-- Status pill (header giua)
local statusPill = Instance.new("Frame",header)
statusPill.Size = UDim2.new(0,160,0,26); statusPill.Position = UDim2.new(0.5,-80,0.5,-13)
statusPill.BackgroundColor3 = Color3.fromRGB(8,8,18); statusPill.BorderSizePixel = 0; statusPill.ZIndex = 12
Instance.new("UICorner",statusPill).CornerRadius = UDim.new(0,13)
Instance.new("UIStroke",statusPill).Color = Color3.fromRGB(50,50,80)

local sDot = Instance.new("Frame",statusPill)
sDot.Size = UDim2.new(0,7,0,7); sDot.Position = UDim2.new(0,8,0.5,-3.5)
sDot.BackgroundColor3 = Color3.fromRGB(255,80,80); sDot.BorderSizePixel = 0; sDot.ZIndex = 13
Instance.new("UICorner",sDot).CornerRadius = UDim.new(1,0)

local sLbl = Instance.new("TextLabel",statusPill)
sLbl.Size = UDim2.new(1,-22,1,0); sLbl.Position = UDim2.new(0,20,0,0)
sLbl.BackgroundTransparency = 1; sLbl.Text = "Chua bat"
sLbl.TextColor3 = Color3.fromRGB(255,100,100)
sLbl.Font = Enum.Font.GothamBold; sLbl.TextSize = 10
sLbl.TextXAlignment = Enum.TextXAlignment.Left
sLbl.TextTruncate = Enum.TextTruncate.AtEnd; sLbl.ZIndex = 13

-- Stats pills phai header
local function mkStatPill(xOff, icon)
    local p = Instance.new("Frame",header)
    p.Size = UDim2.new(0,58,0,26); p.Position = UDim2.new(1,xOff,0.5,-13)
    p.BackgroundColor3 = Color3.fromRGB(8,8,18); p.BorderSizePixel = 0; p.ZIndex = 12
    Instance.new("UICorner",p).CornerRadius = UDim.new(0,13)
    local il = Instance.new("TextLabel",p); il.Size = UDim2.new(0,18,1,0)
    il.BackgroundTransparency = 1; il.Text = icon; il.TextScaled = true; il.ZIndex = 13
    local vl = Instance.new("TextLabel",p)
    vl.Size = UDim2.new(1,-20,1,0); vl.Position = UDim2.new(0,19,0,0)
    vl.BackgroundTransparency = 1; vl.Font = Enum.Font.GothamBold; vl.TextSize = 11
    vl.TextColor3 = Color3.new(1,1,1); vl.TextXAlignment = Enum.TextXAlignment.Left; vl.ZIndex = 13
    return vl
end
local stFish = mkStatPill(-186, "đŸŸ")
local stSell = mkStatPill(-122, "đŸ›’")
local stTime = mkStatPill(-58,  "â±")

-- Nut X dong hub
local xBtn = Instance.new("TextButton",header)
xBtn.Size = UDim2.new(0,28,0,28); xBtn.Position = UDim2.new(1,-36,0.5,-14)
xBtn.BackgroundColor3 = Color3.fromRGB(200,45,45); xBtn.BorderSizePixel = 0
xBtn.Text = "X"; xBtn.TextColor3 = Color3.new(1,1,1)
xBtn.Font = Enum.Font.GothamBlack; xBtn.TextSize = 13; xBtn.ZIndex = 13
Instance.new("UICorner",xBtn).CornerRadius = UDim.new(0,8)

local hubVisible = true
xBtn.MouseButton1Click:Connect(function()
    hubVisible = false
    TS:Create(hub, TweenInfo.new(0.18,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),
        {Size=UDim2.new(0,0,0,0), Position=UDim2.new(0.5,0,0.5,0)}):Play()
end)

-- Nut mo lai (nho, o goc)
local openBtn = Instance.new("TextButton")
openBtn.Size = UDim2.new(0,60,0,28); openBtn.Position = UDim2.new(0,8,0,8)
openBtn.BackgroundColor3 = Color3.fromRGB(255,130,0); openBtn.BorderSizePixel = 0
openBtn.Text = "OPEN"; openBtn.TextColor3 = Color3.new(1,1,1)
openBtn.Font = Enum.Font.GothamBlack; openBtn.TextSize = 12
openBtn.ZIndex = 20; openBtn.Visible = false; openBtn.Active = true; openBtn.Parent = sg
Instance.new("UICorner",openBtn).CornerRadius = UDim.new(0,8)
Instance.new("UIStroke",openBtn).Color = Color3.fromRGB(255,200,80)

openBtn.MouseButton1Click:Connect(function()
    hubVisible = true; openBtn.Visible = false
    hub.Size = UDim2.new(0,0,0,0); hub.Position = UDim2.new(0.5,0,0.5,0)
    TS:Create(hub, TweenInfo.new(0.22,Enum.EasingStyle.Back,Enum.EasingDirection.Out),
        {Size=UDim2.new(0,HW,0,HH), Position=UDim2.new(0.5,-HW/2,0.5,-HH/2)}):Play()
end)

xBtn.MouseButton1Click:Connect(function()
    task.delay(0.2, function() openBtn.Visible = true end)
end)

-- ================================================================
-- SIDEBAR (tabs)
-- ================================================================
local sidebar = Instance.new("Frame",hub)
sidebar.Size = UDim2.new(0,SIDEBAR_W,1,-48); sidebar.Position = UDim2.new(0,0,0,48)
sidebar.BackgroundColor3 = Color3.fromRGB(12,12,22); sidebar.BorderSizePixel = 0; sidebar.ZIndex = 11

-- Bo goc duoi sidebar
local sbCorner = Instance.new("UICorner",sidebar)
sbCorner.CornerRadius = UDim.new(0,14)

-- Ngan cach sidebar/content
local divLine = Instance.new("Frame",hub)
divLine.Size = UDim2.new(0,1,1,-52); divLine.Position = UDim2.new(0,SIDEBAR_W,0,50)
divLine.BackgroundColor3 = Color3.fromRGB(35,35,55); divLine.BorderSizePixel = 0; divLine.ZIndex = 11

-- Tab data
local tabs = {
    {id="fishing",  icon="đŸ£", label="Fishing"},
    {id="skills",   icon="â¡", label="Skills"},
    {id="setup",    icon="đŸ“Œ", label="Setup"},
    {id="settings", icon="â™",  label="Settings"},
}

local activeTab    = "fishing"
local tabBtns      = {}
local contentPanes = {}

-- Tao tab button
local TAB_H = 44
for idx, t in ipairs(tabs) do
    local btn = Instance.new("TextButton",sidebar)
    btn.Size = UDim2.new(1,-8,0,TAB_H); btn.Position = UDim2.new(0,4,0, 8 + (idx-1)*(TAB_H+4))
    btn.BackgroundColor3 = Color3.fromRGB(20,20,36); btn.BackgroundTransparency = 1
    btn.BorderSizePixel = 0; btn.Text = ""; btn.ZIndex = 12
    btn.Active = true
    Instance.new("UICorner",btn).CornerRadius = UDim.new(0,10)

    local ic = Instance.new("TextLabel",btn)
    ic.Size = UDim2.new(0,28,1,0); ic.Position = UDim2.new(0,8,0,0)
    ic.BackgroundTransparency = 1; ic.Text = t.icon; ic.TextScaled = true; ic.ZIndex = 13

    local lb = Instance.new("TextLabel",btn)
    lb.Size = UDim2.new(1,-40,1,0); lb.Position = UDim2.new(0,38,0,0)
    lb.BackgroundTransparency = 1; lb.Text = t.label
    lb.Font = Enum.Font.GothamBold; lb.TextSize = 12
    lb.TextColor3 = Color3.fromRGB(160,160,200)
    lb.TextXAlignment = Enum.TextXAlignment.Left; lb.ZIndex = 13

    -- Active indicator bar
    local bar = Instance.new("Frame",btn)
    bar.Size = UDim2.new(0,3,0.6,0); bar.Position = UDim2.new(0,0,0.2,0)
    bar.BackgroundColor3 = Color3.fromRGB(255,140,0); bar.BorderSizePixel = 0; bar.ZIndex = 13
    bar.Visible = false
    Instance.new("UICorner",bar).CornerRadius = UDim.new(0,2)

    tabBtns[t.id] = {btn=btn, lb=lb, bar=bar}
end

-- Content area
local contentArea = Instance.new("Frame",hub)
contentArea.Size = UDim2.new(1,-SIDEBAR_W-2, 1,-50)
contentArea.Position = UDim2.new(0,SIDEBAR_W+2, 0,50)
contentArea.BackgroundTransparency = 1; contentArea.BorderSizePixel = 0
contentArea.ClipsDescendants = true; contentArea.ZIndex = 11

-- Helper: tao ScrollFrame cho moi tab
local function makeContentPane(id)
    local f = Instance.new("ScrollingFrame",contentArea)
    f.Size = UDim2.new(1,0,1,0); f.Position = UDim2.new(0,0,0,0)
    f.BackgroundTransparency = 1; f.BorderSizePixel = 0
    f.ScrollBarThickness = 3; f.ScrollBarImageColor3 = Color3.fromRGB(255,140,0)
    f.ZIndex = 12; f.Visible = false; f.Name = id
    return f
end

for _, t in ipairs(tabs) do
    contentPanes[t.id] = makeContentPane(t.id)
end

-- Tab switch logic
local function switchTab(id)
    activeTab = id
    for _, t in ipairs(tabs) do
        local ti   = tabBtns[t.id]
        local isAc = (t.id == id)
        ti.bar.Visible = isAc
        if isAc then
            TS:Create(ti.btn, TweenInfo.new(0.15), {BackgroundTransparency=0}):Play()
            ti.lb.TextColor3 = Color3.new(1,1,1)
            ti.btn.BackgroundColor3 = Color3.fromRGB(28,28,48)
        else
            TS:Create(ti.btn, TweenInfo.new(0.15), {BackgroundTransparency=1}):Play()
            ti.lb.TextColor3 = Color3.fromRGB(160,160,200)
        end
        contentPanes[t.id].Visible = (t.id == id)
    end
end

for _, t in ipairs(tabs) do
    local id = t.id
    tabBtns[id].btn.MouseButton1Click:Connect(function() switchTab(id) end)
end

-- ================================================================
-- WIDGET HELPERS (content pane)
-- ================================================================
local function mkBtn(parent, Y, W, h, bg, txt, fs)
    local b = Instance.new("TextButton",parent)
    b.Size = UDim2.new(0,W,0,h); b.Position = UDim2.new(0,8,0,Y)
    b.BackgroundColor3 = bg; b.BorderSizePixel = 0
    b.Text = txt; b.TextColor3 = Color3.new(1,1,1)
    b.Font = Enum.Font.GothamBold; b.TextSize = fs or 12
    b.TextWrapped = true; b.ZIndex = 13
    Instance.new("UICorner",b).CornerRadius = UDim.new(0,8)
    return b
end

local function mkLabel(parent, Y, W, h, txt, col, fs, xa)
    local l = Instance.new("TextLabel",parent)
    l.Size = UDim2.new(0,W,0,h); l.Position = UDim2.new(0,8,0,Y)
    l.BackgroundTransparency = 1; l.Text = txt
    l.TextColor3 = col or Color3.new(1,1,1)
    l.Font = Enum.Font.GothamBold; l.TextSize = fs or 11
    l.TextXAlignment = xa or Enum.TextXAlignment.Left
    l.TextWrapped = true; l.ZIndex = 13
    return l
end

local function mkRow(parent, Y, W, h, bg)
    local f = Instance.new("Frame",parent)
    f.Size = UDim2.new(0,W,0,h); f.Position = UDim2.new(0,8,0,Y)
    f.BackgroundColor3 = bg or Color3.fromRGB(18,18,32); f.BorderSizePixel = 0; f.ZIndex = 12
    Instance.new("UICorner",f).CornerRadius = UDim.new(0,8)
    Instance.new("UIStroke",f).Color = Color3.fromRGB(40,40,64)
    return f
end

local function mkStepper(parent, Y, W, label, initVal, col)
    local f = mkRow(parent, Y, W, 32)
    local ll = Instance.new("TextLabel",f)
    ll.Size = UDim2.new(0,100,1,0); ll.Position = UDim2.new(0,8,0,0)
    ll.BackgroundTransparency = 1; ll.Text = label
    ll.TextColor3 = Color3.fromRGB(180,180,220); ll.Font = Enum.Font.GothamBold; ll.TextSize = 11
    ll.TextXAlignment = Enum.TextXAlignment.Left; ll.ZIndex = 13
    local vl = Instance.new("TextLabel",f)
    vl.Size = UDim2.new(0,36,1,0); vl.Position = UDim2.new(0,108,0,0)
    vl.BackgroundTransparency = 1; vl.Text = initVal
    vl.TextColor3 = col or Color3.fromRGB(255,220,80)
    vl.Font = Enum.Font.GothamBold; vl.TextSize = 12; vl.ZIndex = 13
    local bm = Instance.new("TextButton",f)
    bm.Size = UDim2.new(0,26,0,24); bm.Position = UDim2.new(1,-58,0.5,-12)
    bm.BackgroundColor3 = Color3.fromRGB(160,30,30); bm.BorderSizePixel = 0
    bm.Text = "-"; bm.TextColor3 = Color3.new(1,1,1)
    bm.Font = Enum.Font.GothamBold; bm.TextSize = 16; bm.ZIndex = 13
    Instance.new("UICorner",bm).CornerRadius = UDim.new(0,6)
    local bp = Instance.new("TextButton",f)
    bp.Size = UDim2.new(0,26,0,24); bp.Position = UDim2.new(1,-30,0.5,-12)
    bp.BackgroundColor3 = Color3.fromRGB(25,140,50); bp.BorderSizePixel = 0
    bp.Text = "+"; bp.TextColor3 = Color3.new(1,1,1)
    bp.Font = Enum.Font.GothamBold; bp.TextSize = 16; bp.ZIndex = 13
    Instance.new("UICorner",bp).CornerRadius = UDim.new(0,6)
    return vl, bm, bp, f
end

local function mkDivider(parent, Y, W)
    local d = Instance.new("Frame",parent)
    d.Size = UDim2.new(0,W,0,1); d.Position = UDim2.new(0,8,0,Y)
    d.BackgroundColor3 = Color3.fromRGB(35,35,55); d.BorderSizePixel = 0; d.ZIndex = 12
end

local function mkSectionTitle(parent, Y, W, txt)
    local l = Instance.new("TextLabel",parent)
    l.Size = UDim2.new(0,W,0,18); l.Position = UDim2.new(0,8,0,Y)
    l.BackgroundTransparency = 1; l.Text = txt
    l.TextColor3 = Color3.fromRGB(255,140,0)
    l.Font = Enum.Font.GothamBlack; l.TextSize = 11
    l.TextXAlignment = Enum.TextXAlignment.Left; l.ZIndex = 13
end

local CW = HW - SIDEBAR_W - 20   -- content width

-- ================================================================
-- TAB 1: FISHING
-- ================================================================
local pFish = contentPanes["fishing"]
local fY = 8

-- START/STOP big button
local toggleBtn = mkBtn(pFish, fY, CW, 42, Color3.fromRGB(30,180,65), "START AUTO", 14)
local tGrad = Instance.new("UIGradient",toggleBtn); tGrad.Rotation = 90
tGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0,Color3.fromRGB(50,220,85)),
    ColorSequenceKeypoint.new(1,Color3.fromRGB(18,145,48)),
})
fY = fY + 48

-- Sell Now
local sellNowBtn = mkBtn(pFish, fY, CW, 30, Color3.fromRGB(200,100,0), "BAN NGAY", 12)
fY = fY + 36

mkDivider(pFish, fY, CW); fY = fY + 8
mkSectionTitle(pFish, fY, CW, "SPAM DOC LAP"); fY = fY + 22

-- Cast toggle
local castToggleBtn = mkBtn(pFish, fY, CW, 30, Color3.fromRGB(160,110,0), "NEM CAN: TAT", 11)
fY = fY + 36

-- Skill toggle
local skillToggleBtn = mkBtn(pFish, fY, CW, 30, Color3.fromRGB(70,30,180), "CHIEU ZXCV: TAT", 11)
fY = fY + 36

mkDivider(pFish, fY, CW); fY = fY + 8
mkSectionTitle(pFish, fY, CW, "THOI GIAN CAU"); fY = fY + 22

local timLbl,timMin,timPlus = mkStepper(pFish, fY, CW, "Cau (phut):", fishMinutes.."p", Color3.fromRGB(255,220,80))
fY = fY + 38

timMin.MouseButton1Click:Connect(function()
    fishMinutes=math.max(1,fishMinutes-1); timLbl.Text=fishMinutes.."p"
end)
timPlus.MouseButton1Click:Connect(function()
    fishMinutes=fishMinutes+1; timLbl.Text=fishMinutes.."p"
end)

pFish.CanvasSize = UDim2.new(0,0,0,fY+8)

-- ================================================================
-- TAB 2: SKILLS (ZXCV)
-- ================================================================
local pSkill = contentPanes["skills"]
local skY = 8

mkSectionTitle(pSkill, skY, CW, "CHIEU Z X C V"); skY = skY + 24

local zxcvToggleBtns = {}
local zxcvInfoLbls   = {}
local zxcvCdLbls     = {}

for i=1,4 do
    local nm  = zxcvNames[i]
    local col = zxcvColors[i]

    -- Row header: badge + toa do
    local rowF = Instance.new("Frame",pSkill)
    rowF.Size = UDim2.new(0,CW,0,24); rowF.Position = UDim2.new(0,8,0,skY)
    rowF.BackgroundTransparency = 1; rowF.ZIndex = 12

    local badge = Instance.new("Frame",rowF)
    badge.Size = UDim2.new(0,24,0,24); badge.BackgroundColor3 = col
    badge.BorderSizePixel = 0; badge.ZIndex = 13
    Instance.new("UICorner",badge).CornerRadius = UDim.new(0,6)
    local bl = Instance.new("TextLabel",badge)
    bl.Size = UDim2.new(1,0,1,0); bl.BackgroundTransparency = 1
    bl.Text = nm; bl.Font = Enum.Font.GothamBlack; bl.TextSize = 13
    bl.TextColor3 = Color3.new(1,1,1); bl.ZIndex = 14

    local sl = Instance.new("TextLabel",rowF)
    sl.Size = UDim2.new(1,-28,1,0); sl.Position = UDim2.new(0,28,0,0)
    sl.BackgroundTransparency = 1; sl.Text = "Chua luu"
    sl.TextColor3 = Color3.fromRGB(140,140,180)
    sl.Font = Enum.Font.GothamBold; sl.TextSize = 10
    sl.TextXAlignment = Enum.TextXAlignment.Left
    sl.TextTruncate = Enum.TextTruncate.AtEnd; sl.ZIndex = 13
    zxcvInfoLbls[i] = sl
    skY = skY + 28

    -- Hien marker btn
    local tb = mkBtn(pSkill, skY, CW, 26, col, "HIEN "..nm, 11)
    zxcvToggleBtns[i] = tb
    skY = skY + 30

    -- CD stepper
    local cdL,cdM,cdP = mkStepper(pSkill, skY, CW, "CD "..nm..":", string.format("%.1fs",zxcvCooldown[i]), col)
    zxcvCdLbls[i] = cdL
    skY = skY + 38

    local idx = i
    cdM.MouseButton1Click:Connect(function()
        zxcvCooldown[idx]=math.max(0.1,math.floor((zxcvCooldown[idx]-0.1)*10+0.5)/10)
        cdL.Text=string.format("%.1fs",zxcvCooldown[idx])
    end)
    cdP.MouseButton1Click:Connect(function()
        zxcvCooldown[idx]=math.floor((zxcvCooldown[idx]+0.1)*10+0.5)/10
        cdL.Text=string.format("%.1fs",zxcvCooldown[idx])
    end)

    if i<4 then mkDivider(pSkill, skY, CW); skY=skY+10 end
end

pSkill.CanvasSize = UDim2.new(0,0,0,skY+8)

-- ================================================================
-- TAB 3: SETUP (markers + vi tri)
-- ================================================================
local pSetup = contentPanes["setup"]
local stY = 8

mkSectionTitle(pSetup, stY, CW, "VI TRI TRONG GAME"); stY = stY + 22

-- Vi tri cau
local p1Lbl = mkLabel(pSetup, stY, CW, 16, "Cau: Chua luu", Color3.fromRGB(120,180,255), 10)
stY = stY + 18
local saveFishBtn = mkBtn(pSetup, stY, CW, 28, Color3.fromRGB(25,100,210), "SAVE vi tri cau hien tai", 11)
stY = stY + 34

-- Vi tri NPC
local p2Lbl = mkLabel(pSetup, stY, CW, 16, "NPC: Chua luu", Color3.fromRGB(255,180,80), 10)
stY = stY + 18
local saveNPCBtn = mkBtn(pSetup, stY, CW, 28, Color3.fromRGB(110,35,180), "SAVE vi tri NPC hien tai", 11)
stY = stY + 34

mkDivider(pSetup, stY, CW); stY = stY + 10
mkSectionTitle(pSetup, stY, CW, "NUT BAN CA (danh dau)"); stY = stY + 22

local p3Lbl      = mkLabel(pSetup, stY, CW, 16, "SellAll: Chua luu", Color3.fromRGB(80,255,180), 10)
stY = stY + 18
local showSellBtn  = mkBtn(pSetup, stY, CW, 28, Color3.fromRGB(18,140,72), "HIEN vong SellAll", 11)
stY = stY + 34

local p4Lbl      = mkLabel(pSetup, stY, CW, 16, "X dong: Chua luu", Color3.fromRGB(255,130,180), 10)
stY = stY + 18
local showCloseBtn = mkBtn(pSetup, stY, CW, 28, Color3.fromRGB(175,35,55), "HIEN vong X dong", 11)
stY = stY + 34

mkDivider(pSetup, stY, CW); stY = stY + 10
mkSectionTitle(pSetup, stY, CW, "NUT NEM CAN"); stY = stY + 22

local p5Lbl     = mkLabel(pSetup, stY, CW, 16, "Fishing: Chua luu", Color3.fromRGB(255,230,80), 10)
stY = stY + 18
local showCastBtn = mkBtn(pSetup, stY, CW, 28, Color3.fromRGB(155,115,0), "HIEN vong Fishing", 11)
stY = stY + 34

pSetup.CanvasSize = UDim2.new(0,0,0,stY+8)

-- ================================================================
-- TAB 4: SETTINGS (checklist)
-- ================================================================
local pSettings = contentPanes["settings"]
local seY = 8

mkSectionTitle(pSettings, seY, CW, "TRANG THAI SETUP"); seY = seY + 24

local checkLabels = {}
local chkData = {
    {k="fish",  l="Vi tri cau"},
    {k="npc",   l="Vi tri NPC"},
    {k="sell",  l="SellAll"},
    {k="close", l="X dong"},
    {k="cast",  l="Nut Fishing"},
    {k="zxcv",  l="ZXCV"},
}
for _, c in ipairs(chkData) do
    local f = mkRow(pSettings, seY, CW, 28)
    local dot = Instance.new("Frame",f)
    dot.Size = UDim2.new(0,10,0,10); dot.Position = UDim2.new(0,8,0.5,-5)
    dot.BackgroundColor3 = Color3.fromRGB(200,60,60); dot.BorderSizePixel = 0; dot.ZIndex = 13
    Instance.new("UICorner",dot).CornerRadius = UDim.new(1,0)
    local lbl = Instance.new("TextLabel",f)
    lbl.Size = UDim2.new(1,-26,1,0); lbl.Position = UDim2.new(0,24,0,0)
    lbl.BackgroundTransparency = 1; lbl.Text = c.l
    lbl.TextColor3 = Color3.fromRGB(200,60,60)
    lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.ZIndex = 13
    checkLabels[c.k] = {lbl=lbl, dot=dot}
    seY = seY + 34
end

mkDivider(pSettings, seY, CW); seY = seY + 10
mkSectionTitle(pSettings, seY, CW, "PHIM TAT"); seY = seY + 22
mkLabel(pSettings, seY, CW, 16, "F = Bat / Tat auto", Color3.fromRGB(160,160,200), 10); seY = seY + 18
mkLabel(pSettings, seY, CW, 16, "H = An / Hien menu", Color3.fromRGB(160,160,200), 10); seY = seY + 18

pSettings.CanvasSize = UDim2.new(0,0,0,seY+8)

-- Activate first tab
switchTab("fishing")

-- ================================================================
-- MARKER BINDINGS
-- ================================================================
local function getCenter(m)
    local ap=m.AbsolutePosition; local as=m.AbsoluteSize
    return ap.X+as.X*0.5+INSET.X, ap.Y+as.Y*0.5+INSET.Y
end

local function bindMarker(marker, showBtn, infoLbl, onSave)
    showBtn.MouseButton1Click:Connect(function()
        marker.Visible = not marker.Visible
        if marker.Visible then showBtn.BackgroundColor3=Color3.fromRGB(120,50,10) end
    end)
    marker.MouseButton1Click:Connect(function()
        local cx,cy = getCenter(marker)
        onSave(Vector2.new(cx,cy), cx, cy)
        marker.BackgroundColor3 = Color3.fromRGB(30,60,170)
        showBtn.BackgroundColor3 = Color3.fromRGB(18,80,18)
        statusText = "Luu ("..math.floor(cx)..","..math.floor(cy)..")"
    end)
end

bindMarker(markerSell, showSellBtn, p3Lbl, function(v2,x,y)
    savedSellPos=v2; p3Lbl.Text="âœ“ ("..math.floor(x)..","..math.floor(y)..")"
    p3Lbl.TextColor3=Color3.fromRGB(80,255,180); showSellBtn.Text="âœ“ SellAll da luu"
end)
bindMarker(markerClose, showCloseBtn, p4Lbl, function(v2,x,y)
    savedClosePos=v2; p4Lbl.Text="âœ“ ("..math.floor(x)..","..math.floor(y)..")"
    p4Lbl.TextColor3=Color3.fromRGB(255,150,200); showCloseBtn.Text="âœ“ X dong da luu"
end)
bindMarker(markerCast, showCastBtn, p5Lbl, function(v2,x,y)
    savedCastPos=v2; p5Lbl.Text="âœ“ ("..math.floor(x)..","..math.floor(y)..")"
    p5Lbl.TextColor3=Color3.fromRGB(255,230,80); showCastBtn.Text="âœ“ Fishing da luu"
end)

for i=1,4 do
    local m=zxcvMarkers[i]; local tb=zxcvToggleBtns[i]
    local sl=zxcvInfoLbls[i]; local col=zxcvColors[i]; local nm=zxcvNames[i]
    tb.MouseButton1Click:Connect(function()
        m.Visible=not m.Visible
        tb.Text=m.Visible and ("AN "..nm) or ("HIEN "..nm)
        if m.Visible then tb.BackgroundColor3=Color3.fromRGB(120,50,10) else tb.BackgroundColor3=col end
    end)
    m.MouseButton1Click:Connect(function()
        local cx,cy=getCenter(m)
        zxcvPos[i]=Vector2.new(cx,cy)
        sl.Text="âœ“ ("..math.floor(cx)..","..math.floor(cy)..")"
        sl.TextColor3=Color3.fromRGB(150,255,150)
        m.BackgroundColor3=Color3.fromRGB(30,60,170)
        tb.Text="âœ“ "..nm; tb.BackgroundColor3=Color3.fromRGB(18,80,18)
        statusText="Luu "..nm.." OK"
    end)
end

-- Save vi tri
saveFishBtn.MouseButton1Click:Connect(function()
    local c=LP.Character; local r=c and c:FindFirstChild("HumanoidRootPart")
    if r then
        savedFishPos=r.Position
        p1Lbl.Text="âœ“ X:"..math.floor(r.Position.X).." Z:"..math.floor(r.Position.Z)
        p1Lbl.TextColor3=Color3.fromRGB(80,255,120)
        saveFishBtn.Text="âœ“ Da luu vi tri cau"
        saveFishBtn.BackgroundColor3=Color3.fromRGB(12,90,40)
    end
end)
saveNPCBtn.MouseButton1Click:Connect(function()
    local c=LP.Character; local r=c and c:FindFirstChild("HumanoidRootPart")
    if r then
        savedNPCPos=r.Position
        p2Lbl.Text="âœ“ X:"..math.floor(r.Position.X).." Z:"..math.floor(r.Position.Z)
        p2Lbl.TextColor3=Color3.fromRGB(255,220,60)
        saveNPCBtn.Text="âœ“ Da luu vi tri NPC"
        saveNPCBtn.BackgroundColor3=Color3.fromRGB(70,15,120)
    end
end)

-- ================================================================
-- BUTTON EVENTS
-- ================================================================
toggleBtn.MouseButton1Click:Connect(function()
    isRunning=not isRunning
    if isRunning then
        fishCaught=0; fishSession=0; sellCount=0
        statusText="Dang khoi dong..."
        task.spawn(mainLoop)
    else
        stopAllSpam(); stopWalk(); isSelling=false; statusText="Da tat"
    end
end)

sellNowBtn.MouseButton1Click:Connect(function()
    if not isRunning then statusText="Bat tu dong truoc!"; return end
    countdownSec=0
    sellNowBtn.BackgroundColor3=Color3.fromRGB(255,60,0)
    task.delay(0.8,function() sellNowBtn.BackgroundColor3=Color3.fromRGB(200,100,0) end)
end)

castToggleBtn.MouseButton1Click:Connect(function()
    if castActive then
        castActive=false; castToken=castToken+1
    else
        castActive=true; startCastLoop()
    end
end)

skillToggleBtn.MouseButton1Click:Connect(function()
    if skillActive then
        skillActive=false; for i=1,4 do skillTokens[i]=skillTokens[i]+1 end
    else
        skillActive=true; startAllSkills()
    end
end)

UIS.InputBegan:Connect(function(inp,gp)
    if gp then return end
    if inp.KeyCode==Enum.KeyCode.F then toggleBtn.MouseButton1Click:Fire() end
    if inp.KeyCode==Enum.KeyCode.H then
        if hubVisible then
            hubVisible=false
            TS:Create(hub,TweenInfo.new(0.18,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),
                {Size=UDim2.new(0,0,0,0),Position=UDim2.new(0.5,0,0.5,0)}):Play()
            task.delay(0.2,function() openBtn.Visible=true end)
        else
            hubVisible=true; openBtn.Visible=false
            hub.Size=UDim2.new(0,0,0,0); hub.Position=UDim2.new(0.5,0,0.5,0)
            TS:Create(hub,TweenInfo.new(0.22,Enum.EasingStyle.Back,Enum.EasingDirection.Out),
                {Size=UDim2.new(0,HW,0,HH),Position=UDim2.new(0.5,-HW/2,0.5,-HH/2)}):Play()
        end
    end
end)

-- ================================================================
-- UPDATE LOOP (4fps, chi update khi thay doi)
-- ================================================================
local _pStatus=""; local _pRunning=nil; local _pCd=-1
local _pFish=-1; local _pSell=-1; local _pCast=nil; local _pSkill=nil; local _pSelling=nil

local COL_ON  = ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(225,50,50)),ColorSequenceKeypoint.new(1,Color3.fromRGB(155,18,18))})
local COL_OFF = ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(50,220,85)),ColorSequenceKeypoint.new(1,Color3.fromRGB(18,145,48))})
local _chkPrev = {}

task.spawn(function()
    while true do
        task.wait(0.25)

        if statusText~=_pStatus then _pStatus=statusText; sLbl.Text=statusText end

        if isRunning~=_pRunning then
            _pRunning=isRunning
            if isRunning then
                sLbl.TextColor3=Color3.fromRGB(80,255,140)
                sDot.BackgroundColor3=Color3.fromRGB(60,255,80)
                toggleBtn.Text="STOP AUTO"
                tGrad.Color=COL_ON
            else
                sLbl.TextColor3=Color3.fromRGB(255,100,100)
                sDot.BackgroundColor3=Color3.fromRGB(255,80,80)
                toggleBtn.Text="START AUTO"
                tGrad.Color=COL_OFF
            end
        end

        local cdNow = isSelling and -1 or countdownSec
        if cdNow~=_pCd or isSelling~=_pSelling then
            _pCd=cdNow; _pSelling=isSelling
            stTime.Text = isSelling and "Ban..." or (math.floor(countdownSec/60)..":"..string.format("%02d",countdownSec%60))
        end
        if fishCaught~=_pFish then _pFish=fishCaught; stFish.Text=tostring(fishCaught) end
        if sellCount~=_pSell  then _pSell=sellCount;  stSell.Text=tostring(sellCount) end

        if castActive~=_pCast then
            _pCast=castActive
            castToggleBtn.Text=castActive and "NEM CAN: BAT" or "NEM CAN: TAT"
            castToggleBtn.BackgroundColor3=castActive and Color3.fromRGB(220,160,0) or Color3.fromRGB(160,110,0)
        end
        if skillActive~=_pSkill then
            _pSkill=skillActive
            skillToggleBtn.Text=skillActive and "CHIEU ZXCV: BAT" or "CHIEU ZXCV: TAT"
            skillToggleBtn.BackgroundColor3=skillActive and Color3.fromRGB(120,60,255) or Color3.fromRGB(70,30,180)
        end

        local checks={
            fish=savedFishPos~=nil, npc=savedNPCPos~=nil,
            sell=savedSellPos~=nil, close=savedClosePos~=nil,
            cast=savedCastPos~=nil,
            zxcv=(function() for i=1,4 do if zxcvPos[i] then return true end end return false end)(),
        }
        for k,v in pairs(checks) do
            if v~=_chkPrev[k] and checkLabels[k] then
                _chkPrev[k]=v
                local c=checkLabels[k]
                c.lbl.Text=(v and "âœ“ " or "âœ— ")..({fish="Vi tri cau",npc="Vi tri NPC",sell="SellAll",close="X dong",cast="Nut Fishing",zxcv="ZXCV"})[k]
                local green=Color3.fromRGB(80,255,120); local red=Color3.fromRGB(200,60,60)
                c.lbl.TextColor3=v and green or red
                c.dot.BackgroundColor3=v and green or red
            end
        end
    end
end)

print("[TF v18] Hub style | F=bat/tat | H=an/hien | 2 mang click")
