-- ================================================================
-- TITAN FISHING v19  |  Mobile Hub  |  No Teleport
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
-- CLICK â€” 2 mang doc lap, token stop
-- ================================================================
local castActive  = false
local skillActive = false
local castToken   = 0
local skillTokens = {0,0,0,0}

local function doClick(x,y)
    VIM:SendMouseButtonEvent(x,y,0,true, game,0)
    task.wait(0.06)
    VIM:SendMouseButtonEvent(x,y,0,false,game,0)
end

local function startCastLoop()
    castToken = castToken+1; local tk=castToken
    task.spawn(function()
        while castActive and castToken==tk do
            if savedCastPos and not isSelling then pcall(doClick,savedCastPos.X,savedCastPos.Y) end
            task.wait(0.45)
        end
    end)
end

local function startSkillLoop(idx)
    skillTokens[idx]=skillTokens[idx]+1; local tk=skillTokens[idx]
    task.spawn(function()
        task.wait((idx-1)*0.08)
        while skillActive and skillTokens[idx]==tk do
            if zxcvPos[idx] and not isSelling then
                pcall(doClick,zxcvPos[idx].X,zxcvPos[idx].Y)
                local cd=zxcvCooldown[idx] or 1.0; local t=0
                while t<cd do
                    task.wait(0.05); t=t+0.05
                    if not skillActive or skillTokens[idx]~=tk then return end
                end
            else
                task.wait(0.1)
                if not skillActive or skillTokens[idx]~=tk then return end
            end
        end
    end)
end

local function startAllSkills() for i=1,4 do startSkillLoop(i) end end

local function stopAllSpam()
    castActive=false; skillActive=false
    castToken=castToken+1
    for i=1,4 do skillTokens[i]=skillTokens[i]+1 end
end

-- ================================================================
-- WALK
-- ================================================================
local function walkTo(pos,lbl)
    local char=LP.Character; if not char then return end
    local hrp=char:FindFirstChild("HumanoidRootPart")
    local hum=char:FindFirstChild("Humanoid")
    if not hrp or not hum then return end
    statusText=lbl or "Dang di..."
    hum.WalkSpeed=24
    local path=PFS:CreatePath({AgentHeight=5,AgentRadius=2,AgentCanJump=true})
    local ok=pcall(function() path:ComputeAsync(hrp.Position,pos) end)
    if ok and path.Status==Enum.PathStatus.Success then
        for _,wp in ipairs(path:GetWaypoints()) do
            if not isRunning then return end
            if wp.Action==Enum.PathWaypointAction.Jump then hum.Jump=true end
            hum:MoveTo(wp.Position); hum.MoveToFinished:Wait(3)
            if (hrp.Position-pos).Magnitude<8 then break end
        end
    else
        hum:MoveTo(pos); local t=0
        while t<12 and isRunning do
            task.wait(0.2); t=t+0.2
            if (hrp.Position-pos).Magnitude<8 then break end
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
local function uiClick(x,y)
    pcall(function() VIM:SendMouseMoveEvent(x,y,game) end); task.wait(0.04)
    pcall(function() VIM:SendMouseButtonEvent(x,y,0,true, game,0) end); task.wait(0.1)
    pcall(function() VIM:SendMouseButtonEvent(x,y,0,false,game,0) end); task.wait(0.05)
end

local function doInteract()
    statusText="Mo cua hang..."
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
        if best and bestD<20 then pcall(function() fireproximityprompt(best) end); task.wait(0.5) end
    end
    task.wait(0.8)
end

local function doSellAll()
    if not savedSellPos or not savedClosePos then statusText="Chua luu SellAll/X!"; task.wait(2); return end
    statusText="Cho popup..."; task.wait(0.8)
    uiClick(savedSellPos.X,savedSellPos.Y); task.wait(1.2)
    uiClick(savedClosePos.X,savedClosePos.Y); task.wait(0.5)
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
    if #miss>0 then statusText="Thieu: "..table.concat(miss,", ").."!"; isRunning=false; return end

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
            local m=math.floor(countdownSec/60); local s=countdownSec%60
            statusText=m..":"..string.format("%02d",s).." Ca:"..fishCaught.." Ban:"..sellCount
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
        statusText="Da ban lan "..sellCount.."!"
        task.wait(1)
    end
    stopAllSpam(); isSelling=false; countdownSec=0; statusText="Da tat"
end

-- ================================================================
-- GUI
-- ================================================================
local old=LP.PlayerGui:FindFirstChild("TFHub"); if old then old:Destroy() end
local sg=Instance.new("ScreenGui")
sg.Name="TFHub"; sg.ResetOnSpawn=false
sg.IgnoreGuiInset=true                   -- dung toa do tuyet doi tu (0,0)
sg.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
sg.Parent=LP.PlayerGui

-- Viet port size thuc
local VP   = workspace.CurrentCamera.ViewportSize
local INSET = GS:GetGuiInset()

-- ================================================================
-- MARKERS
-- ================================================================
local function makeMarker(col,tag)
    local S=70
    local m=Instance.new("TextButton")
    m.Size=UDim2.new(0,S,0,S)
    m.Position=UDim2.new(0.5,-S/2,0.5,-S/2)
    m.BackgroundColor3=col; m.BackgroundTransparency=0.3
    m.BorderSizePixel=0; m.Text=""; m.ZIndex=80
    m.Active=true; m.Draggable=true; m.Visible=false; m.Parent=sg
    Instance.new("UICorner",m).CornerRadius=UDim.new(1,0)
    Instance.new("UIStroke",m).Color=Color3.new(1,1,1)
    -- crosshair
    local ch=Instance.new("Frame",m)
    ch.Size=UDim2.new(1,0,0,2); ch.Position=UDim2.new(0,0,0.5,-1)
    ch.BackgroundColor3=Color3.fromRGB(255,255,0); ch.BorderSizePixel=0; ch.ZIndex=81
    local cv=Instance.new("Frame",m)
    cv.Size=UDim2.new(0,2,1,0); cv.Position=UDim2.new(0.5,-1,0,0)
    cv.BackgroundColor3=Color3.fromRGB(255,255,0); cv.BorderSizePixel=0; cv.ZIndex=81
    -- diem do tam
    local dot=Instance.new("Frame",m)
    dot.Size=UDim2.new(0,10,0,10); dot.Position=UDim2.new(0.5,-5,0.5,-5)
    dot.BackgroundColor3=Color3.fromRGB(255,0,0); dot.BorderSizePixel=0; dot.ZIndex=82
    Instance.new("UICorner",dot).CornerRadius=UDim.new(1,0)
    -- nhan
    local tl=Instance.new("TextLabel",m)
    tl.Size=UDim2.new(1,0,0,16); tl.Position=UDim2.new(0,0,1,2)
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

-- Tinh toa do viewport chinh xac (co tinh INSET)
local function getCenter(m)
    local ap=m.AbsolutePosition; local as=m.AbsoluteSize
    -- IgnoreGuiInset=true nen AbsolutePosition la viewport coords thang
    return ap.X+as.X*0.5, ap.Y+as.Y*0.5
end

-- ================================================================
-- HUB WINDOW  â€” kich thuoc nho, phu hop mobile doc
-- HW x HH = 310 x 380 (vua man hinh ~400px mobile)
-- ================================================================
local HW = 310
local HH = 380
local SBW = 90   -- sidebar width

local hub=Instance.new("Frame",sg)
hub.Name="Hub"
hub.Size=UDim2.new(0,HW,0,HH)
hub.Position=UDim2.new(0,8,0,50)   -- goc trai, tranh UI game
hub.BackgroundColor3=Color3.fromRGB(14,14,24)
hub.BackgroundTransparency=0.05
hub.BorderSizePixel=0
hub.Active=true; hub.Draggable=true
hub.ClipsDescendants=true
hub.ZIndex=10
Instance.new("UICorner",hub).CornerRadius=UDim.new(0,12)
local hubStroke=Instance.new("UIStroke",hub)
hubStroke.Color=Color3.fromRGB(50,50,90); hubStroke.Thickness=1.5

-- ================================================================
-- HEADER (cao 40px)
-- ================================================================
local HDR=40
local header=Instance.new("Frame",hub)
header.Size=UDim2.new(1,0,0,HDR); header.Position=UDim2.new(0,0,0,0)
header.BackgroundColor3=Color3.fromRGB(10,10,20); header.BorderSizePixel=0; header.ZIndex=11
Instance.new("UICorner",header).CornerRadius=UDim.new(0,12)
local hg=Instance.new("UIGradient",header)
hg.Color=ColorSequence.new({
    ColorSequenceKeypoint.new(0,Color3.fromRGB(35,20,70)),
    ColorSequenceKeypoint.new(1,Color3.fromRGB(10,10,20)),
}); hg.Rotation=90

-- Logo text
local logoF=Instance.new("Frame",header)
logoF.Size=UDim2.new(0,28,0,28); logoF.Position=UDim2.new(0,6,0.5,-14)
logoF.BackgroundColor3=Color3.fromRGB(255,140,0); logoF.BorderSizePixel=0; logoF.ZIndex=12
Instance.new("UICorner",logoF).CornerRadius=UDim.new(1,0)
local logoL=Instance.new("TextLabel",logoF)
logoL.Size=UDim2.new(1,0,1,0); logoL.BackgroundTransparency=1
logoL.Text="TF"; logoL.Font=Enum.Font.GothamBlack; logoL.TextSize=10
logoL.TextColor3=Color3.new(1,1,1); logoL.ZIndex=13

-- Title
local titleL=Instance.new("TextLabel",header)
titleL.Size=UDim2.new(0,110,0,20); titleL.Position=UDim2.new(0,40,0,6)
titleL.BackgroundTransparency=1; titleL.Text="Titan Fishing"
titleL.Font=Enum.Font.GothamBlack; titleL.TextSize=12
titleL.TextColor3=Color3.new(1,1,1); titleL.TextXAlignment=Enum.TextXAlignment.Left; titleL.ZIndex=12
local subL=Instance.new("TextLabel",header)
subL.Size=UDim2.new(0,110,0,14); subL.Position=UDim2.new(0,40,0,23)
subL.BackgroundTransparency=1; subL.Text="v19 Auto"
subL.Font=Enum.Font.Gotham; subL.TextSize=9
subL.TextColor3=Color3.fromRGB(140,140,200); subL.TextXAlignment=Enum.TextXAlignment.Left; subL.ZIndex=12

-- Status dot + text (header giua)
local sDot=Instance.new("Frame",header)
sDot.Size=UDim2.new(0,7,0,7); sDot.Position=UDim2.new(0.5,-50,0.5,-3.5)
sDot.BackgroundColor3=Color3.fromRGB(255,80,80); sDot.BorderSizePixel=0; sDot.ZIndex=12
Instance.new("UICorner",sDot).CornerRadius=UDim.new(1,0)
local sLbl=Instance.new("TextLabel",header)
sLbl.Size=UDim2.new(0,90,1,0); sLbl.Position=UDim2.new(0.5,-40,0,0)
sLbl.BackgroundTransparency=1; sLbl.Text="Chua bat"
sLbl.TextColor3=Color3.fromRGB(255,100,100)
sLbl.Font=Enum.Font.GothamBold; sLbl.TextSize=9
sLbl.TextXAlignment=Enum.TextXAlignment.Left
sLbl.TextTruncate=Enum.TextTruncate.AtEnd; sLbl.ZIndex=12

-- Stats (phai header)
local function mkStat(xOff,icon)
    local p=Instance.new("Frame",header)
    p.Size=UDim2.new(0,44,0,26); p.Position=UDim2.new(1,xOff,0.5,-13)
    p.BackgroundColor3=Color3.fromRGB(8,8,18); p.BorderSizePixel=0; p.ZIndex=12
    Instance.new("UICorner",p).CornerRadius=UDim.new(0,10)
    local il=Instance.new("TextLabel",p); il.Size=UDim2.new(0,14,1,0)
    il.BackgroundTransparency=1; il.Text=icon; il.TextScaled=true; il.ZIndex=13
    local vl=Instance.new("TextLabel",p)
    vl.Size=UDim2.new(1,-16,1,0); vl.Position=UDim2.new(0,15,0,0)
    vl.BackgroundTransparency=1; vl.Font=Enum.Font.GothamBold; vl.TextSize=10
    vl.TextColor3=Color3.new(1,1,1); vl.TextXAlignment=Enum.TextXAlignment.Left; vl.ZIndex=13
    return vl
end
local stFish=mkStat(-138,"đŸŸ")
local stSell=mkStat(-92, "đŸ›’")
local stTime=mkStat(-46, "â±")

-- Nut X
local xBtn=Instance.new("TextButton",header)
xBtn.Size=UDim2.new(0,26,0,26); xBtn.Position=UDim2.new(1,-32,0.5,-13)
xBtn.BackgroundColor3=Color3.fromRGB(200,40,40); xBtn.BorderSizePixel=0
xBtn.Text="X"; xBtn.TextColor3=Color3.new(1,1,1)
xBtn.Font=Enum.Font.GothamBlack; xBtn.TextSize=12; xBtn.ZIndex=13
Instance.new("UICorner",xBtn).CornerRadius=UDim.new(0,7)

-- ================================================================
-- NUT OPEN (chi hien khi hub da dong)
-- ================================================================
local openBtn=Instance.new("TextButton",sg)
openBtn.Size=UDim2.new(0,62,0,28)
openBtn.Position=UDim2.new(0,8,0,50)
openBtn.BackgroundColor3=Color3.fromRGB(255,130,0); openBtn.BorderSizePixel=0
openBtn.Text="OPEN"; openBtn.TextColor3=Color3.new(1,1,1)
openBtn.Font=Enum.Font.GothamBlack; openBtn.TextSize=12
openBtn.ZIndex=30; openBtn.Visible=false; openBtn.Active=true
Instance.new("UICorner",openBtn).CornerRadius=UDim.new(0,8)
Instance.new("UIStroke",openBtn).Color=Color3.fromRGB(255,200,80)

local hubOpen=true

local function showHub()
    hubOpen=true
    hub.Visible=true
    openBtn.Visible=false
    hub.Size=UDim2.new(0,0,0,0)
    hub.Position=UDim2.new(0,8+HW/2,0,50+HH/2)
    TS:Create(hub,TweenInfo.new(0.2,Enum.EasingStyle.Back,Enum.EasingDirection.Out),
        {Size=UDim2.new(0,HW,0,HH), Position=UDim2.new(0,8,0,50)}):Play()
end

local function hideHub()
    hubOpen=false
    TS:Create(hub,TweenInfo.new(0.15,Enum.EasingStyle.Quart,Enum.EasingDirection.In),
        {Size=UDim2.new(0,0,0,0), Position=UDim2.new(0,8+HW/2,0,50+HH/2)}):Play()
    task.delay(0.18,function()
        hub.Visible=false
        openBtn.Visible=true
    end)
end

xBtn.MouseButton1Click:Connect(hideHub)
openBtn.MouseButton1Click:Connect(showHub)

-- ================================================================
-- SIDEBAR + TABS
-- ================================================================
local sidebar=Instance.new("Frame",hub)
sidebar.Size=UDim2.new(0,SBW,1,-HDR); sidebar.Position=UDim2.new(0,0,0,HDR)
sidebar.BackgroundColor3=Color3.fromRGB(10,10,20); sidebar.BorderSizePixel=0; sidebar.ZIndex=11

local sbDiv=Instance.new("Frame",hub)
sbDiv.Size=UDim2.new(0,1,1,-HDR); sbDiv.Position=UDim2.new(0,SBW,0,HDR+1)
sbDiv.BackgroundColor3=Color3.fromRGB(35,35,55); sbDiv.BorderSizePixel=0; sbDiv.ZIndex=11

local tabs={
    {id="fishing", icon="đŸ£", label="Fishing"},
    {id="skills",  icon="â¡", label="Skills"},
    {id="setup",   icon="đŸ“Œ", label="Setup"},
    {id="info",    icon="đŸ“‹", label="Info"},
}

local activeTab="fishing"
local tabBtns={}
local contentPanes={}

local TAB_H=52
for idx,t in ipairs(tabs) do
    local btn=Instance.new("TextButton",sidebar)
    btn.Size=UDim2.new(1,-6,0,TAB_H); btn.Position=UDim2.new(0,3,0,6+(idx-1)*(TAB_H+3))
    btn.BackgroundColor3=Color3.fromRGB(20,20,38); btn.BackgroundTransparency=1
    btn.BorderSizePixel=0; btn.Text=""; btn.ZIndex=12; btn.Active=true
    Instance.new("UICorner",btn).CornerRadius=UDim.new(0,8)

    local ic=Instance.new("TextLabel",btn)
    ic.Size=UDim2.new(1,0,0,26); ic.Position=UDim2.new(0,0,0,6)
    ic.BackgroundTransparency=1; ic.Text=t.icon; ic.TextScaled=true; ic.ZIndex=13

    local lb=Instance.new("TextLabel",btn)
    lb.Size=UDim2.new(1,0,0,16); lb.Position=UDim2.new(0,0,0,32)
    lb.BackgroundTransparency=1; lb.Text=t.label
    lb.Font=Enum.Font.GothamBold; lb.TextSize=10
    lb.TextColor3=Color3.fromRGB(140,140,190)
    lb.TextXAlignment=Enum.TextXAlignment.Center; lb.ZIndex=13

    local bar=Instance.new("Frame",btn)
    bar.Size=UDim2.new(0,3,0.6,0); bar.Position=UDim2.new(0,0,0.2,0)
    bar.BackgroundColor3=Color3.fromRGB(255,140,0); bar.BorderSizePixel=0; bar.ZIndex=13
    bar.Visible=false
    Instance.new("UICorner",bar).CornerRadius=UDim.new(0,2)

    tabBtns[t.id]={btn=btn,lb=lb,bar=bar}

    local pane=Instance.new("ScrollingFrame",hub)
    pane.Size=UDim2.new(1,-SBW-2,1,-HDR); pane.Position=UDim2.new(0,SBW+2,0,HDR)
    pane.BackgroundTransparency=1; pane.BorderSizePixel=0
    pane.ScrollBarThickness=3; pane.ScrollBarImageColor3=Color3.fromRGB(255,140,0)
    pane.ZIndex=12; pane.Visible=false; pane.Name=t.id
    contentPanes[t.id]=pane
end

local CW=HW-SBW-18

local function switchTab(id)
    activeTab=id
    for _,t in ipairs(tabs) do
        local ti=tabBtns[t.id]; local on=(t.id==id)
        ti.bar.Visible=on
        ti.lb.TextColor3=on and Color3.new(1,1,1) or Color3.fromRGB(140,140,190)
        if on then
            ti.btn.BackgroundTransparency=0
            ti.btn.BackgroundColor3=Color3.fromRGB(22,22,40)
        else
            ti.btn.BackgroundTransparency=1
        end
        contentPanes[t.id].Visible=(t.id==id)
    end
end

for _,t in ipairs(tabs) do
    local id=t.id
    tabBtns[id].btn.MouseButton1Click:Connect(function() switchTab(id) end)
end

-- ================================================================
-- WIDGET HELPERS
-- ================================================================
local function mkBtn(pane,Y,h,bg,txt,fs)
    local b=Instance.new("TextButton",pane)
    b.Size=UDim2.new(0,CW,0,h); b.Position=UDim2.new(0,6,0,Y)
    b.BackgroundColor3=bg; b.BorderSizePixel=0
    b.Text=txt; b.TextColor3=Color3.new(1,1,1)
    b.Font=Enum.Font.GothamBold; b.TextSize=fs or 12
    b.TextWrapped=true; b.ZIndex=13
    Instance.new("UICorner",b).CornerRadius=UDim.new(0,8)
    return b
end

local function mkRow(pane,Y,h)
    local f=Instance.new("Frame",pane)
    f.Size=UDim2.new(0,CW,0,h); f.Position=UDim2.new(0,6,0,Y)
    f.BackgroundColor3=Color3.fromRGB(16,16,30); f.BorderSizePixel=0; f.ZIndex=12
    Instance.new("UICorner",f).CornerRadius=UDim.new(0,8)
    Instance.new("UIStroke",f).Color=Color3.fromRGB(38,38,60)
    return f
end

local function mkSec(pane,Y,txt)
    local l=Instance.new("TextLabel",pane)
    l.Size=UDim2.new(0,CW,0,16); l.Position=UDim2.new(0,6,0,Y)
    l.BackgroundTransparency=1; l.Text=txt
    l.TextColor3=Color3.fromRGB(255,140,0)
    l.Font=Enum.Font.GothamBlack; l.TextSize=10
    l.TextXAlignment=Enum.TextXAlignment.Left; l.ZIndex=13
end

local function mkDiv(pane,Y)
    local d=Instance.new("Frame",pane)
    d.Size=UDim2.new(0,CW,0,1); d.Position=UDim2.new(0,6,0,Y)
    d.BackgroundColor3=Color3.fromRGB(35,35,55); d.BorderSizePixel=0; d.ZIndex=12
end

local function mkStepper(pane,Y,lbl,initVal,col)
    local f=mkRow(pane,Y,30)
    local ll=Instance.new("TextLabel",f)
    ll.Size=UDim2.new(0,90,1,0); ll.Position=UDim2.new(0,6,0,0)
    ll.BackgroundTransparency=1; ll.Text=lbl
    ll.TextColor3=Color3.fromRGB(180,180,220); ll.Font=Enum.Font.GothamBold; ll.TextSize=10
    ll.TextXAlignment=Enum.TextXAlignment.Left; ll.ZIndex=13
    local vl=Instance.new("TextLabel",f)
    vl.Size=UDim2.new(0,30,1,0); vl.Position=UDim2.new(0,96,0,0)
    vl.BackgroundTransparency=1; vl.Text=initVal
    vl.TextColor3=col or Color3.fromRGB(255,220,80)
    vl.Font=Enum.Font.GothamBold; vl.TextSize=11; vl.ZIndex=13
    local bm=Instance.new("TextButton",f)
    bm.Size=UDim2.new(0,24,0,22); bm.Position=UDim2.new(1,-52,0.5,-11)
    bm.BackgroundColor3=Color3.fromRGB(160,30,30); bm.BorderSizePixel=0
    bm.Text="-"; bm.TextColor3=Color3.new(1,1,1)
    bm.Font=Enum.Font.GothamBold; bm.TextSize=15; bm.ZIndex=13
    Instance.new("UICorner",bm).CornerRadius=UDim.new(0,5)
    local bp=Instance.new("TextButton",f)
    bp.Size=UDim2.new(0,24,0,22); bp.Position=UDim2.new(1,-26,0.5,-11)
    bp.BackgroundColor3=Color3.fromRGB(25,140,50); bp.BorderSizePixel=0
    bp.Text="+"; bp.TextColor3=Color3.new(1,1,1)
    bp.Font=Enum.Font.GothamBold; bp.TextSize=15; bp.ZIndex=13
    Instance.new("UICorner",bp).CornerRadius=UDim.new(0,5)
    return vl,bm,bp
end

local function mkInfoRow(pane,Y,txt,col)
    local f=mkRow(pane,Y,24)
    local l=Instance.new("TextLabel",f)
    l.Size=UDim2.new(1,-8,1,0); l.Position=UDim2.new(0,6,0,0)
    l.BackgroundTransparency=1; l.Text=txt
    l.TextColor3=col or Color3.fromRGB(160,160,200)
    l.Font=Enum.Font.GothamBold; l.TextSize=10
    l.TextXAlignment=Enum.TextXAlignment.Left
    l.TextTruncate=Enum.TextTruncate.AtEnd; l.ZIndex=13
    return l
end

-- ================================================================
-- TAB 1: FISHING
-- ================================================================
local pF=contentPanes["fishing"]; local fY=8

local toggleBtn=mkBtn(pF,fY,42,Color3.fromRGB(30,180,65),"START AUTO",14)
local tGrad=Instance.new("UIGradient",toggleBtn); tGrad.Rotation=90
tGrad.Color=ColorSequence.new({
    ColorSequenceKeypoint.new(0,Color3.fromRGB(50,220,85)),
    ColorSequenceKeypoint.new(1,Color3.fromRGB(18,145,48)),
})
fY=fY+48

local sellNowBtn=mkBtn(pF,fY,28,Color3.fromRGB(200,100,0),"BAN NGAY",11); fY=fY+34

mkDiv(pF,fY); fY=fY+8
mkSec(pF,fY,"SPAM DOC LAP"); fY=fY+20

local castToggleBtn=mkBtn(pF,fY,28,Color3.fromRGB(160,110,0),"NEM CAN: TAT",11); fY=fY+34
local skillToggleBtn=mkBtn(pF,fY,28,Color3.fromRGB(70,30,180),"CHIEU ZXCV: TAT",11); fY=fY+34

mkDiv(pF,fY); fY=fY+8
mkSec(pF,fY,"THOI GIAN CAU"); fY=fY+20

local timLbl,timMin,timPlus=mkStepper(pF,fY,"Cau (phut):",fishMinutes.."p",Color3.fromRGB(255,220,80)); fY=fY+36

timMin.MouseButton1Click:Connect(function()
    fishMinutes=math.max(1,fishMinutes-1); timLbl.Text=fishMinutes.."p"
end)
timPlus.MouseButton1Click:Connect(function()
    fishMinutes=fishMinutes+1; timLbl.Text=fishMinutes.."p"
end)

pF.CanvasSize=UDim2.new(0,0,0,fY+8)

-- ================================================================
-- TAB 2: SKILLS
-- ================================================================
local pSk=contentPanes["skills"]; local skY=8

mkSec(pSk,skY,"CHIEU Z X C V"); skY=skY+20

local zxcvToggleBtns={}; local zxcvInfoLbls={}; local zxcvCdLbls={}

for i=1,4 do
    local nm=zxcvNames[i]; local col=zxcvColors[i]

    local rf=Instance.new("Frame",pSk)
    rf.Size=UDim2.new(0,CW,0,22); rf.Position=UDim2.new(0,6,0,skY)
    rf.BackgroundTransparency=1; rf.ZIndex=12
    local badge=Instance.new("Frame",rf)
    badge.Size=UDim2.new(0,22,0,22); badge.BackgroundColor3=col
    badge.BorderSizePixel=0; badge.ZIndex=13
    Instance.new("UICorner",badge).CornerRadius=UDim.new(0,5)
    local bl=Instance.new("TextLabel",badge)
    bl.Size=UDim2.new(1,0,1,0); bl.BackgroundTransparency=1
    bl.Text=nm; bl.Font=Enum.Font.GothamBlack; bl.TextSize=12
    bl.TextColor3=Color3.new(1,1,1); bl.ZIndex=14
    local sl=Instance.new("TextLabel",rf)
    sl.Size=UDim2.new(1,-26,1,0); sl.Position=UDim2.new(0,26,0,0)
    sl.BackgroundTransparency=1; sl.Text="Chua luu"
    sl.TextColor3=Color3.fromRGB(140,140,180)
    sl.Font=Enum.Font.GothamBold; sl.TextSize=9
    sl.TextXAlignment=Enum.TextXAlignment.Left
    sl.TextTruncate=Enum.TextTruncate.AtEnd; sl.ZIndex=13
    zxcvInfoLbls[i]=sl; skY=skY+26

    local tb=mkBtn(pSk,skY,24,col,"HIEN "..nm,10)
    zxcvToggleBtns[i]=tb; skY=skY+30

    local cdL,cdM,cdP=mkStepper(pSk,skY,"CD "..nm..":",string.format("%.1fs",zxcvCooldown[i]),col)
    zxcvCdLbls[i]=cdL; skY=skY+36

    local idx=i
    cdM.MouseButton1Click:Connect(function()
        zxcvCooldown[idx]=math.max(0.1,math.floor((zxcvCooldown[idx]-0.1)*10+0.5)/10)
        cdL.Text=string.format("%.1fs",zxcvCooldown[idx])
    end)
    cdP.MouseButton1Click:Connect(function()
        zxcvCooldown[idx]=math.floor((zxcvCooldown[idx]+0.1)*10+0.5)/10
        cdL.Text=string.format("%.1fs",zxcvCooldown[idx])
    end)

    if i<4 then mkDiv(pSk,skY); skY=skY+10 end
end

pSk.CanvasSize=UDim2.new(0,0,0,skY+8)

-- ================================================================
-- TAB 3: SETUP
-- ================================================================
local pSt=contentPanes["setup"]; local stY=8

mkSec(pSt,stY,"VI TRI TRONG GAME"); stY=stY+20
local p1Lbl=mkInfoRow(pSt,stY,"Cau: Chua luu",Color3.fromRGB(120,180,255)); stY=stY+30
local saveFishBtn=mkBtn(pSt,stY,26,Color3.fromRGB(25,100,210),"SAVE vi tri cau",11); stY=stY+32
local p2Lbl=mkInfoRow(pSt,stY,"NPC: Chua luu",Color3.fromRGB(255,180,80)); stY=stY+30
local saveNPCBtn=mkBtn(pSt,stY,26,Color3.fromRGB(110,35,180),"SAVE vi tri NPC",11); stY=stY+32

mkDiv(pSt,stY); stY=stY+8
mkSec(pSt,stY,"NUT BAN CA"); stY=stY+20
local p3Lbl=mkInfoRow(pSt,stY,"SellAll: Chua luu",Color3.fromRGB(80,255,180)); stY=stY+30
local showSellBtn=mkBtn(pSt,stY,26,Color3.fromRGB(18,140,72),"HIEN vong SellAll",11); stY=stY+32
local p4Lbl=mkInfoRow(pSt,stY,"X dong: Chua luu",Color3.fromRGB(255,130,180)); stY=stY+30
local showCloseBtn=mkBtn(pSt,stY,26,Color3.fromRGB(175,35,55),"HIEN vong X dong",11); stY=stY+32

mkDiv(pSt,stY); stY=stY+8
mkSec(pSt,stY,"NUT NEM CAN"); stY=stY+20
local p5Lbl=mkInfoRow(pSt,stY,"Fishing: Chua luu",Color3.fromRGB(255,230,80)); stY=stY+30
local showCastBtn=mkBtn(pSt,stY,26,Color3.fromRGB(155,115,0),"HIEN vong Fishing",11); stY=stY+32

pSt.CanvasSize=UDim2.new(0,0,0,stY+8)

-- ================================================================
-- TAB 4: INFO (checklist + phim tat)
-- ================================================================
local pIn=contentPanes["info"]; local inY=8

mkSec(pIn,inY,"TRANG THAI SETUP"); inY=inY+20
local checkLabels={}
local chkList={
    {k="fish",l="Vi tri cau"},{k="npc",l="Vi tri NPC"},
    {k="sell",l="SellAll"},{k="close",l="X dong"},
    {k="cast",l="Nut Fishing"},{k="zxcv",l="ZXCV"},
}
for _,c in ipairs(chkList) do
    local f=mkRow(pIn,inY,26)
    local dot=Instance.new("Frame",f)
    dot.Size=UDim2.new(0,9,0,9); dot.Position=UDim2.new(0,7,0.5,-4.5)
    dot.BackgroundColor3=Color3.fromRGB(200,60,60); dot.BorderSizePixel=0; dot.ZIndex=13
    Instance.new("UICorner",dot).CornerRadius=UDim.new(1,0)
    local lbl=Instance.new("TextLabel",f)
    lbl.Size=UDim2.new(1,-22,1,0); lbl.Position=UDim2.new(0,20,0,0)
    lbl.BackgroundTransparency=1; lbl.Text=c.l
    lbl.TextColor3=Color3.fromRGB(200,60,60)
    lbl.Font=Enum.Font.GothamBold; lbl.TextSize=10
    lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.ZIndex=13
    checkLabels[c.k]={lbl=lbl,dot=dot}; inY=inY+32
end

mkDiv(pIn,inY); inY=inY+8
mkSec(pIn,inY,"PHIM TAT"); inY=inY+20
mkInfoRow(pIn,inY,"F = Bat / Tat auto",Color3.fromRGB(160,160,200)); inY=inY+30
mkInfoRow(pIn,inY,"H = An / Hien menu",Color3.fromRGB(160,160,200)); inY=inY+30

pIn.CanvasSize=UDim2.new(0,0,0,inY+8)

switchTab("fishing")

-- ================================================================
-- MARKER BINDINGS
-- ================================================================
local function bindMarker(marker,showBtn,infoLbl,onSave)
    showBtn.MouseButton1Click:Connect(function()
        marker.Visible=not marker.Visible
        if marker.Visible then showBtn.BackgroundColor3=Color3.fromRGB(120,50,10) end
    end)
    marker.MouseButton1Click:Connect(function()
        local cx,cy=getCenter(marker)
        onSave(Vector2.new(cx,cy),cx,cy)
        marker.BackgroundColor3=Color3.fromRGB(30,60,170)
        showBtn.BackgroundColor3=Color3.fromRGB(18,80,18)
        statusText="Luu ("..math.floor(cx)..","..math.floor(cy)..")"
    end)
end

bindMarker(markerSell,showSellBtn,p3Lbl,function(v2,x,y)
    savedSellPos=v2; p3Lbl.Text="OK ("..math.floor(x)..","..math.floor(y)..")"
    p3Lbl.TextColor3=Color3.fromRGB(80,255,180); showSellBtn.Text="âœ“ SellAll da luu"
end)
bindMarker(markerClose,showCloseBtn,p4Lbl,function(v2,x,y)
    savedClosePos=v2; p4Lbl.Text="OK ("..math.floor(x)..","..math.floor(y)..")"
    p4Lbl.TextColor3=Color3.fromRGB(255,150,200); showCloseBtn.Text="âœ“ X dong da luu"
end)
bindMarker(markerCast,showCastBtn,p5Lbl,function(v2,x,y)
    savedCastPos=v2; p5Lbl.Text="OK ("..math.floor(x)..","..math.floor(y)..")"
    p5Lbl.TextColor3=Color3.fromRGB(255,230,80); showCastBtn.Text="âœ“ Fishing da luu"
end)

for i=1,4 do
    local m=zxcvMarkers[i]; local tb=zxcvToggleBtns[i]
    local sl=zxcvInfoLbls[i]; local col=zxcvColors[i]; local nm=zxcvNames[i]
    tb.MouseButton1Click:Connect(function()
        m.Visible=not m.Visible
        tb.Text=m.Visible and ("AN "..nm) or ("HIEN "..nm)
        tb.BackgroundColor3=m.Visible and Color3.fromRGB(120,50,10) or col
    end)
    m.MouseButton1Click:Connect(function()
        local cx,cy=getCenter(m)
        zxcvPos[i]=Vector2.new(cx,cy)
        sl.Text="OK ("..math.floor(cx)..","..math.floor(cy)..")"
        sl.TextColor3=Color3.fromRGB(150,255,150)
        m.BackgroundColor3=Color3.fromRGB(30,60,170)
        tb.Text="âœ“ "..nm; tb.BackgroundColor3=Color3.fromRGB(18,80,18)
        statusText="Luu "..nm.." OK"
    end)
end

saveFishBtn.MouseButton1Click:Connect(function()
    local c=LP.Character; local r=c and c:FindFirstChild("HumanoidRootPart")
    if r then
        savedFishPos=r.Position
        p1Lbl.Text="OK "..math.floor(r.Position.X)..","..math.floor(r.Position.Z)
        p1Lbl.TextColor3=Color3.fromRGB(80,255,120)
        saveFishBtn.Text="âœ“ Da luu vi tri cau"
        saveFishBtn.BackgroundColor3=Color3.fromRGB(12,90,40)
    end
end)
saveNPCBtn.MouseButton1Click:Connect(function()
    local c=LP.Character; local r=c and c:FindFirstChild("HumanoidRootPart")
    if r then
        savedNPCPos=r.Position
        p2Lbl.Text="OK "..math.floor(r.Position.X)..","..math.floor(r.Position.Z)
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
        statusText="Khoi dong..."
        task.spawn(mainLoop)
    else
        stopAllSpam(); stopWalk(); isSelling=false; statusText="Da tat"
    end
end)

sellNowBtn.MouseButton1Click:Connect(function()
    if not isRunning then statusText="Bat tu dong truoc!"; return end
    countdownSec=0
    sellNowBtn.BackgroundColor3=Color3.fromRGB(255,60,0)
    task.delay(0.6,function() sellNowBtn.BackgroundColor3=Color3.fromRGB(200,100,0) end)
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
        if hubOpen then hideHub() else showHub() end
    end
end)

-- ================================================================
-- UPDATE LOOP â€” 4fps, chi update khi thay doi
-- ================================================================
local _pSt=""; local _pRun=nil; local _pCd=-1
local _pFish=-1; local _pSell=-1
local _pCast=nil; local _pSkill=nil; local _pSelling=nil

local COL_ON=ColorSequence.new({
    ColorSequenceKeypoint.new(0,Color3.fromRGB(225,50,50)),
    ColorSequenceKeypoint.new(1,Color3.fromRGB(155,18,18)),
})
local COL_OFF=ColorSequence.new({
    ColorSequenceKeypoint.new(0,Color3.fromRGB(50,220,85)),
    ColorSequenceKeypoint.new(1,Color3.fromRGB(18,145,48)),
})
local _chkPrev={}
local chkNames={fish="Vi tri cau",npc="Vi tri NPC",sell="SellAll",close="X dong",cast="Fishing",zxcv="ZXCV"}

task.spawn(function()
    while true do
        task.wait(0.25)

        if statusText~=_pSt then _pSt=statusText; sLbl.Text=statusText end

        if isRunning~=_pRun then
            _pRun=isRunning
            if isRunning then
                sLbl.TextColor3=Color3.fromRGB(80,255,140)
                sDot.BackgroundColor3=Color3.fromRGB(60,255,80)
                toggleBtn.Text="STOP AUTO"; tGrad.Color=COL_ON
            else
                sLbl.TextColor3=Color3.fromRGB(255,100,100)
                sDot.BackgroundColor3=Color3.fromRGB(255,80,80)
                toggleBtn.Text="START AUTO"; tGrad.Color=COL_OFF
            end
        end

        local cdNow=isSelling and -1 or countdownSec
        if cdNow~=_pCd or isSelling~=_pSelling then
            _pCd=cdNow; _pSelling=isSelling
            stTime.Text=isSelling and "Ban" or (math.floor(countdownSec/60)..":"..string.format("%02d",countdownSec%60))
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
            skillToggleBtn.Text=skillActive and "ZXCV: BAT" or "CHIEU ZXCV: TAT"
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
                local ck=checkLabels[k]
                ck.lbl.Text=(v and "âœ“ " or "âœ— ")..chkNames[k]
                local green=Color3.fromRGB(80,255,120); local red=Color3.fromRGB(200,60,60)
                ck.lbl.TextColor3=v and green or red
                ck.dot.BackgroundColor3=v and green or red
            end
        end
    end
end)

print("[TF v19] Mobile Hub | F=bat/tat | H=an/hien")
