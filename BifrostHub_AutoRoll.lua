local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local UIS = game:GetService("UserInputService")

if not game:IsLoaded() then game.Loaded:Wait() end
local Omni = require(ReplicatedStorage:WaitForChild("Omni"))

-- ========== STATE ==========
local ConfigName = "BifrostHub_Config.json"
local HubConfig = {
    SelectedBuff = "Power", TargetValue = 1.00, SelectedBoss = "Yuje",
    AutoHop = false, AutoFarm = false,
    AnchorX = nil, AnchorY = nil, AnchorZ = nil,
    UIKeybind = "RightShift",
}
local AppState = {
    IsHopping = false, LastHopAttempt = 0, FarmText = "", TokenText = "",
    AutoRollEnabled = false, SelectedPetUUIDs = {}, LastRollTick = 0,
    LastFarmTick = 0, LastTokenTick = 0, StartupTick = tick(),
    UIVisible = true, UIDestroyed = false,
}
local BossNameMapping = {["Yuje"]="Yuji",["Satoro"]="Goujo",["Sakana"]="Meguna"}
local Bosses = {"Yuje","Satoro","Sakana"}
local Buffs = {"Power","Damage","Crystals"}
local OptionsToUUIDs = {}
local Connections = {}

local function SaveConfig()
    if writefile then pcall(function() writefile(ConfigName, HttpService:JSONEncode(HubConfig)) end) end
end
local function LoadConfig()
    if readfile then
        local s,d = pcall(function() return HttpService:JSONDecode(readfile(ConfigName)) end)
        if s and type(d)=="table" then for k,v in pairs(d) do HubConfig[k]=v end end
    end
end

-- ========== THEME ==========
local T = {
    BG=Color3.fromRGB(14,14,18), Sidebar=Color3.fromRGB(18,18,24),
    Content=Color3.fromRGB(22,22,28), TitleBar=Color3.fromRGB(10,10,14),
    Accent=Color3.fromRGB(130,110,220), AccentDim=Color3.fromRGB(80,65,150),
    Btn=Color3.fromRGB(30,30,38), BtnH=Color3.fromRGB(40,40,50),
    On=Color3.fromRGB(40,105,65), Off=Color3.fromRGB(105,38,38),
    T1=Color3.fromRGB(220,220,230), T2=Color3.fromRGB(140,140,160),
    T3=Color3.fromRGB(80,80,100), Sep=Color3.fromRGB(35,35,45),
    TabA=Color3.fromRGB(28,28,36), TabI=Color3.fromRGB(18,18,24),
    Input=Color3.fromRGB(24,24,32), PetS=Color3.fromRGB(38,36,56),
    PetN=Color3.fromRGB(26,26,34),
}

-- ========== CLEANUP ==========
pcall(function()
    local old = CoreGui:FindFirstChild("BifrostHubV2") or CoreGui:FindFirstChild("BifrostLiteUI")
    if old then old:Destroy() end
    local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
    local old2 = pg:FindFirstChild("BifrostHubV2") or pg:FindFirstChild("BifrostLiteUI")
    if old2 then old2:Destroy() end
end)

-- ========== SCREENGUI ==========
local SG = Instance.new("ScreenGui")
SG.Name = "BifrostHubV2"
SG.ResetOnSpawn = false
SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
if not pcall(function() SG.Parent = CoreGui end) then
    SG.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

-- ========== MAIN FRAME ==========
local MF = Instance.new("Frame",SG)
MF.Name="Main" MF.Size=UDim2.new(0,380,0,430) MF.Position=UDim2.new(0.5,-190,0.5,-215)
MF.BackgroundColor3=T.BG MF.BorderSizePixel=0 MF.Active=true MF.Draggable=true
Instance.new("UICorner",MF).CornerRadius=UDim.new(0,8)

-- Top accent line
local ta=Instance.new("Frame",MF) ta.Size=UDim2.new(1,0,0,2) ta.BackgroundColor3=T.Accent ta.BorderSizePixel=0

-- Title bar
local tb=Instance.new("Frame",MF) tb.Size=UDim2.new(1,0,0,32) tb.Position=UDim2.new(0,0,0,2)
tb.BackgroundColor3=T.TitleBar tb.BorderSizePixel=0

local tl=Instance.new("TextLabel",tb) tl.Size=UDim2.new(1,-80,1,0) tl.Position=UDim2.new(0,14,0,0)
tl.BackgroundTransparency=1 tl.Text="Bifrost Hub" tl.TextColor3=T.Accent
tl.TextXAlignment=Enum.TextXAlignment.Left tl.Font=Enum.Font.GothamBold tl.TextSize=14

local vl=Instance.new("TextLabel",tb) vl.Size=UDim2.new(0,24,0,14) vl.Position=UDim2.new(0,102,0.5,-7)
vl.BackgroundColor3=T.AccentDim vl.BackgroundTransparency=0.5 vl.Text="v2" vl.TextColor3=T.T2
vl.Font=Enum.Font.Gotham vl.TextSize=9 vl.BorderSizePixel=0
Instance.new("UICorner",vl).CornerRadius=UDim.new(0,4)

-- Close btn
local cb=Instance.new("TextButton",tb) cb.Size=UDim2.new(0,26,0,26) cb.Position=UDim2.new(1,-30,0.5,-13)
cb.BackgroundColor3=T.TitleBar cb.Text="âœ•" cb.TextColor3=T.T2 cb.Font=Enum.Font.GothamBold
cb.TextSize=13 cb.BorderSizePixel=0 cb.AutoButtonColor=false
Instance.new("UICorner",cb).CornerRadius=UDim.new(0,4)

-- Minimize btn
local mb=Instance.new("TextButton",tb) mb.Size=UDim2.new(0,26,0,26) mb.Position=UDim2.new(1,-58,0.5,-13)
mb.BackgroundColor3=T.TitleBar mb.Text="â€”" mb.TextColor3=T.T2 mb.Font=Enum.Font.GothamBold
mb.TextSize=13 mb.BorderSizePixel=0 mb.AutoButtonColor=false
Instance.new("UICorner",mb).CornerRadius=UDim.new(0,4)

-- ========== SIDEBAR ==========
local SW=52
local sb=Instance.new("Frame",MF) sb.Size=UDim2.new(0,SW,1,-34) sb.Position=UDim2.new(0,0,0,34)
sb.BackgroundColor3=T.Sidebar sb.BorderSizePixel=0
local sbl=Instance.new("UIListLayout",sb) sbl.Padding=UDim.new(0,2)
local sbp=Instance.new("UIPadding",sb) sbp.PaddingTop=UDim.new(0,6) sbp.PaddingLeft=UDim.new(0,4) sbp.PaddingRight=UDim.new(0,4)

-- Divider
local dv=Instance.new("Frame",MF) dv.Size=UDim2.new(0,1,1,-34) dv.Position=UDim2.new(0,SW,0,34)
dv.BackgroundColor3=T.Sep dv.BorderSizePixel=0

-- ========== CONTENT AREA ==========
local CA=Instance.new("Frame",MF) CA.Size=UDim2.new(1,-(SW+1),1,-34) CA.Position=UDim2.new(0,SW+1,0,34)
CA.BackgroundColor3=T.Content CA.BorderSizePixel=0 CA.ClipsDescendants=true

-- ========== FLOATING ICON ==========
local FI=Instance.new("TextButton",SG) FI.Size=UDim2.new(0,34,0,34) FI.Position=UDim2.new(0,20,0.5,-17)
FI.BackgroundColor3=T.Accent FI.Text="B" FI.TextColor3=Color3.new(1,1,1) FI.Font=Enum.Font.GothamBold
FI.TextSize=15 FI.BorderSizePixel=0 FI.Visible=false FI.Active=true FI.Draggable=true FI.AutoButtonColor=false
Instance.new("UICorner",FI).CornerRadius=UDim.new(0.5,0)

-- ========== TAB SYSTEM ==========
local Tabs = {}
local function CreateTab(name, short)
    local bt=Instance.new("TextButton",sb) bt.Name="T_"..name bt.Size=UDim2.new(1,0,0,38)
    bt.BackgroundColor3=T.TabI bt.Text=short bt.TextColor3=T.T3 bt.Font=Enum.Font.GothamSemibold
    bt.TextSize=10 bt.BorderSizePixel=0 bt.AutoButtonColor=false
    Instance.new("UICorner",bt).CornerRadius=UDim.new(0,6)
    local ind=Instance.new("Frame",bt) ind.Size=UDim2.new(0,3,0.55,0) ind.Position=UDim2.new(0,-1,0.225,0)
    ind.BackgroundColor3=T.Accent ind.BorderSizePixel=0 ind.Visible=false
    Instance.new("UICorner",ind).CornerRadius=UDim.new(0,2)
    local ct=Instance.new("ScrollingFrame",CA) ct.Name="C_"..name ct.Size=UDim2.new(1,-14,1,-6)
    ct.Position=UDim2.new(0,7,0,3) ct.BackgroundTransparency=1 ct.ScrollBarThickness=3
    ct.ScrollBarImageColor3=T.AccentDim ct.Visible=false ct.BorderSizePixel=0
    ct.CanvasSize=UDim2.new(0,0,0,0) ct.AutomaticCanvasSize=Enum.AutomaticSize.Y
    local ly=Instance.new("UIListLayout",ct) ly.Padding=UDim.new(0,5)
    Tabs[name]={Button=bt,Content=ct,Indicator=ind}
    bt.MouseButton1Click:Connect(function()
        for n,d in pairs(Tabs) do
            local a=(n==name) d.Content.Visible=a
            d.Button.BackgroundColor3=a and T.TabA or T.TabI
            d.Button.TextColor3=a and T.T1 or T.T3
            d.Indicator.Visible=a
        end
    end)
    return ct
end

-- ========== HELPERS ==========
local function Header(p,t)
    local h=Instance.new("TextLabel",p) h.Size=UDim2.new(1,0,0,16) h.BackgroundTransparency=1
    h.Text=string.upper(t) h.TextColor3=T.T3 h.TextXAlignment=Enum.TextXAlignment.Left
    h.Font=Enum.Font.GothamBold h.TextSize=9 return h
end
local function Label(p,t)
    local l=Instance.new("TextLabel",p) l.Size=UDim2.new(1,0,0,18) l.BackgroundTransparency=1
    l.TextColor3=T.T2 l.Text=t l.TextXAlignment=Enum.TextXAlignment.Left
    l.Font=Enum.Font.Gotham l.TextSize=11 return l
end
local function Btn(p,t,cb2)
    local b=Instance.new("TextButton",p) b.Size=UDim2.new(1,0,0,28) b.BackgroundColor3=T.Btn
    b.TextColor3=T.T1 b.Text=t b.Font=Enum.Font.GothamSemibold b.TextSize=11
    b.BorderSizePixel=0 b.AutoButtonColor=false
    Instance.new("UICorner",b).CornerRadius=UDim.new(0,5)
    b.MouseEnter:Connect(function() b.BackgroundColor3=T.BtnH end)
    b.MouseLeave:Connect(function() if not b:GetAttribute("IT") then b.BackgroundColor3=T.Btn end end)
    if cb2 then b.MouseButton1Click:Connect(cb2) end
    return b
end
local function Toggle(p,t,def,cb2)
    local st=def
    local b=Instance.new("TextButton",p) b.Size=UDim2.new(1,0,0,28)
    b.BackgroundColor3=st and T.On or T.Off b.TextColor3=T.T1
    b.Text=t..": "..(st and "ON" or "OFF") b.Font=Enum.Font.GothamSemibold b.TextSize=11
    b.BorderSizePixel=0 b.AutoButtonColor=false b:SetAttribute("IT",true)
    Instance.new("UICorner",b).CornerRadius=UDim.new(0,5)
    b.MouseButton1Click:Connect(function()
        st=not st b.Text=t..": "..(st and "ON" or "OFF")
        b.BackgroundColor3=st and T.On or T.Off cb2(st)
    end)
    return function(ns) st=ns b.Text=t..": "..(st and "ON" or "OFF") b.BackgroundColor3=st and T.On or T.Off end
end
local function SafeSetUI(lbl,key,txt)
    if AppState[key]~=txt then AppState[key]=txt if lbl then pcall(function() lbl.Text=txt end) end end
end
-- ========== UI STATE ==========
local function MinimizeUI() MF.Visible=false FI.Visible=true AppState.UIVisible=false end
local function RestoreUI() MF.Visible=true FI.Visible=false AppState.UIVisible=true end
local function ToggleUI() if AppState.UIDestroyed then return end if AppState.UIVisible then MinimizeUI() else RestoreUI() end end
local function DestroyUI()
    AppState.UIDestroyed=true
    for _,c in ipairs(Connections) do pcall(function() c:Disconnect() end) end
    table.clear(Connections)
    pcall(function() RunService:UnbindFromRenderStep("Bifrost_StateMachine") end)
    pcall(function() SG:Destroy() end)
end

-- Close with confirmation
local ccf=false
cb.MouseButton1Click:Connect(function()
    if ccf then DestroyUI() else
        ccf=true cb.Text="?" cb.TextColor3=Color3.fromRGB(255,80,80)
        task.delay(3,function() if not AppState.UIDestroyed then ccf=false pcall(function() cb.Text="âœ•" cb.TextColor3=T.T2 end) end end)
    end
end)
mb.MouseButton1Click:Connect(function() MinimizeUI() end)
FI.MouseButton1Click:Connect(function() RestoreUI() end)

-- ========== LOAD & TABS ==========
LoadConfig()
local TabRoll=CreateTab("Roll","Roll")
local TabFarm=CreateTab("Farm","Farm")
local TabSet=CreateTab("Settings","Set.")
Tabs["Roll"].Content.Visible=true Tabs["Roll"].Button.BackgroundColor3=T.TabA
Tabs["Roll"].Button.TextColor3=T.T1 Tabs["Roll"].Indicator.Visible=true

-- ========== [TAB] AUTO-ROLL ==========
Header(TabRoll,"INVENTORY")
local TokenLabel=Label(TabRoll,"Rename Tokens: Searching...")
Header(TabRoll,"PET SELECTION")
local PC=Instance.new("Frame",TabRoll) PC.Size=UDim2.new(1,0,0,100) PC.BackgroundColor3=T.Input PC.BorderSizePixel=0
Instance.new("UICorner",PC).CornerRadius=UDim.new(0,5)
local PS=Instance.new("ScrollingFrame",PC) PS.Size=UDim2.new(1,-6,1,-6) PS.Position=UDim2.new(0,3,0,3)
PS.BackgroundTransparency=1 PS.ScrollBarThickness=2 PS.ScrollBarImageColor3=T.AccentDim PS.BorderSizePixel=0
local PL=Instance.new("UIListLayout",PS) PL.Padding=UDim.new(0,2)

local function RefreshPetsUI()
    for _,c in ipairs(PS:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
    AppState.SelectedPetUUIDs={} table.clear(OptionsToUUIDs)
    pcall(function()
        local units=Omni.Data.Inventory.Units
        if units then for uuid,pet in pairs(units) do
            local dn=pet.CustomName or pet.Name or "?"
            local p=pet.RenameBuffs and pet.RenameBuffs["Power"] or 0
            local d=pet.RenameBuffs and pet.RenameBuffs["Damage"] or 0
            local c2=pet.RenameBuffs and pet.RenameBuffs["Crystals"] or 0
            local opt=string.format("%s (P:%.1f D:%.1f C:%.1f)",dn,p,d,c2)
            local pb=Instance.new("TextButton",PS) pb.Size=UDim2.new(1,0,0,22) pb.BackgroundColor3=T.PetN
            pb.TextColor3=T.T2 pb.Text="  â—‹  "..opt pb.TextXAlignment=Enum.TextXAlignment.Left
            pb.Font=Enum.Font.Gotham pb.TextSize=10 pb.BorderSizePixel=0 pb.AutoButtonColor=false
            Instance.new("UICorner",pb).CornerRadius=UDim.new(0,4)
            local sel=false
            pb.MouseButton1Click:Connect(function()
                sel=not sel
                if sel then pb.Text="  â—  "..opt pb.TextColor3=T.T1 pb.BackgroundColor3=T.PetS table.insert(AppState.SelectedPetUUIDs,uuid)
                else pb.Text="  â—‹  "..opt pb.TextColor3=T.T2 pb.BackgroundColor3=T.PetN
                    for i,v in ipairs(AppState.SelectedPetUUIDs) do if v==uuid then table.remove(AppState.SelectedPetUUIDs,i) break end end
                end
            end)
        end end
    end)
    PS.CanvasSize=UDim2.new(0,0,0,PL.AbsoluteContentSize.Y)
end
Btn(TabRoll,"Refresh Pet List",function() RefreshPetsUI() end)
RefreshPetsUI()

Header(TabRoll,"ROLL CONFIG")
local function NextArr(a,c) for i,v in ipairs(a) do if v==c then return a[i+1] or a[1] end end return a[1] end
local BB
BB=Btn(TabRoll,"Buff: "..HubConfig.SelectedBuff,function()
    HubConfig.SelectedBuff=NextArr(Buffs,HubConfig.SelectedBuff) BB.Text="Buff: "..HubConfig.SelectedBuff SaveConfig()
end)

local VF=Instance.new("Frame",TabRoll) VF.Size=UDim2.new(1,0,0,28) VF.BackgroundTransparency=1
local VS=Btn(VF,"-",function()
    HubConfig.TargetValue=math.max(0.10,HubConfig.TargetValue-0.05)
    VF:FindFirstChild("VL").Text=string.format("Value: %.2f",HubConfig.TargetValue) SaveConfig()
end) VS.Size=UDim2.new(0.2,0,1,0)
local VLbl=Label(VF,string.format("Value: %.2f",HubConfig.TargetValue))
VLbl.Name="VL" VLbl.Size=UDim2.new(0.6,0,1,0) VLbl.Position=UDim2.new(0.2,0,0,0) VLbl.TextXAlignment=Enum.TextXAlignment.Center
local VA=Btn(VF,"+",function()
    HubConfig.TargetValue=math.min(3.00,HubConfig.TargetValue+0.05)
    VLbl.Text=string.format("Value: %.2f",HubConfig.TargetValue) SaveConfig()
end) VA.Size=UDim2.new(0.2,0,1,0) VA.Position=UDim2.new(0.8,0,0,0)

local SetAutoRoll
SetAutoRoll=Toggle(TabRoll,"Auto-Roll",false,function(val)
    if val and #AppState.SelectedPetUUIDs==0 then
        local ot=tl.Text tl.Text="  SELECT A PET!" tl.TextColor3=Color3.fromRGB(255,100,100)
        task.delay(2,function() tl.Text=ot tl.TextColor3=T.Accent end)
        SetAutoRoll(false) return
    end
    AppState.AutoRollEnabled=val
end)

-- ========== [TAB] FARM ==========
Header(TabFarm,"BOSS")
local BBtn
BBtn=Btn(TabFarm,"Boss: "..HubConfig.SelectedBoss,function()
    HubConfig.SelectedBoss=NextArr(Bosses,HubConfig.SelectedBoss) BBtn.Text="Boss: "..HubConfig.SelectedBoss SaveConfig()
end)
Header(TabFarm,"AUTOMATION")
local SetAutoHop=Toggle(TabFarm,"Auto Server-Hop",HubConfig.AutoHop,function(v) HubConfig.AutoHop=v SaveConfig() end)
local SetAutoFarm=Toggle(TabFarm,"Auto-Farm Boss",HubConfig.AutoFarm,function(v) HubConfig.AutoFarm=v SaveConfig() end)
Header(TabFarm,"STATUS")
local FSL=Label(TabFarm,"Status: Waiting...")
Header(TabFarm,"POSITION")
local ABtn
ABtn=Btn(TabFarm,"Set Farm Anchor (Stand here)",function()
    local ch=Players.LocalPlayer.Character local hr=ch and ch:FindFirstChild("HumanoidRootPart")
    if hr then
        HubConfig.AnchorX=hr.Position.X HubConfig.AnchorY=hr.Position.Y HubConfig.AnchorZ=hr.Position.Z SaveConfig()
        SafeSetUI(FSL,"FarmText","Status: Anchor saved!")
        local ot=ABtn.Text ABtn.Text="âœ“ Saved!" ABtn.BackgroundColor3=Color3.fromRGB(40,130,50)
        task.delay(1.5,function() pcall(function() ABtn.Text=ot ABtn.BackgroundColor3=T.Btn end) end)
    end
end)
Btn(TabFarm,"Force Server Hop",function() ForceServerHop() end)

-- ========== [TAB] SETTINGS ==========
Header(TabSet,"UI CONTROLS")
Btn(TabSet,"Minimize UI",function() MinimizeUI() end)
local delBtn
delBtn=Btn(TabSet,"Delete UI (Destroy)",function()
    if delBtn:GetAttribute("confirm") then DestroyUI() else
        delBtn:SetAttribute("confirm",true) delBtn.Text="Click again to confirm" delBtn.BackgroundColor3=Color3.fromRGB(140,40,40)
        task.delay(3,function() if not AppState.UIDestroyed then pcall(function()
            delBtn:SetAttribute("confirm",false) delBtn.Text="Delete UI (Destroy)" delBtn.BackgroundColor3=T.Btn
        end) end end)
    end
end)
Header(TabSet,"KEYBIND")
local kbKey = HubConfig.UIKeybind or "RightShift"
local kbBtn
local kbListening = false
kbBtn=Btn(TabSet,"Toggle Key: "..kbKey,function()
    if kbListening then return end
    kbListening=true kbBtn.Text="Press any key..." kbBtn.BackgroundColor3=T.Accent
end)
table.insert(Connections, UIS.InputBegan:Connect(function(inp,gpe)
    if AppState.UIDestroyed then return end
    if kbListening and not gpe then
        kbListening=false kbKey=inp.KeyCode.Name HubConfig.UIKeybind=kbKey SaveConfig()
        pcall(function() kbBtn.Text="Toggle Key: "..kbKey kbBtn.BackgroundColor3=T.Btn end)
        return
    end
    if not gpe and inp.KeyCode.Name==kbKey then ToggleUI() end
end))
Header(TabSet,"CONFIG")
Btn(TabSet,"Save Settings",function()
    SaveConfig() local ot=tl.Text tl.Text="  Saved!" tl.TextColor3=Color3.fromRGB(100,255,100)
    task.delay(2,function() pcall(function() tl.Text=ot tl.TextColor3=T.Accent end) end)
end)
Header(TabSet,"INFO")
Label(TabSet,"Bifrost Hub v2.0 â€” Vanilla UI")
Label(TabSet,"Performance-first â€¢ Zero dependencies")
-- ========== GAME LOGIC (preserved) ==========
local function TeardownAndHop(placeId, serverId)
    AppState.LastHopAttempt = tick()
    AppState.IsHopping = true
    if SG then pcall(function() SG.Enabled = false end) end
    task.wait(1)
    pcall(function() task.spawn(function() TeleportService:TeleportToPlaceInstance(placeId, serverId, Players.LocalPlayer) end) end)
    task.wait(60)
    AppState.IsHopping = false
    if SG then pcall(function() SG.Enabled = true end) end
end

local function ForceServerHop()
    if tick() - AppState.LastHopAttempt < 20 then return end
    if AppState.IsHopping then return end
    AppState.LastHopAttempt = tick()
    AppState.IsHopping = true
    SafeSetUI(FSL, "FarmText", "Status: Searching server...")
    local placeId = game.PlaceId
    local url = string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Desc&limit=100", placeId)
    local s, r = pcall(function() return game:HttpGet(url) end)
    if s then
        local ds, d = pcall(function() return HttpService:JSONDecode(r) end)
        if ds and d and d.data then
            local valid = {}
            for _, sv in ipairs(d.data) do
                if type(sv) == "table" and sv.playing and sv.maxPlayers then
                    if sv.playing >= 1 and sv.playing <= sv.maxPlayers - 2 and sv.id ~= game.JobId then
                        table.insert(valid, sv.id)
                    end
                end
            end
            if #valid > 0 then
                TeardownAndHop(placeId, valid[math.random(1, #valid)])
                return
            end
        end
    end
    AppState.IsHopping = false
    SafeSetUI(FSL, "FarmText", "Status: No server found.")
end

local function GetBossInWorkspace()
    local key = HubConfig.SelectedBoss
    local map = BossNameMapping[key] or key
    local roots = { Workspace, Workspace:FindFirstChild("Mobs"), Workspace:FindFirstChild("Entities"), Workspace:FindFirstChild("Bosses"), Workspace:FindFirstChild("LiveBosses") }
    for _, root in ipairs(roots) do
        if root then
            for _, obj in ipairs(root:GetChildren()) do
                if obj:IsA("Model") and obj:FindFirstChild("Humanoid") and obj.Humanoid.MaxHealth > 100 then
                    if not Players:GetPlayerFromCharacter(obj) and obj.Humanoid.Health > 0 then
                        local oN = string.lower(obj.Name)
                        if string.find(oN, string.lower(map)) or string.find(oN, string.lower(key)) then return obj end
                    end
                end
            end
        end
    end
    return nil
end

local function GetTokens()
    local tokens = 0
    local found = false
    pcall(function()
        local items = Omni.Data.Inventory.Items
        if items then
            for k, v in pairs(items) do
                if type(k) == "string" and string.find(string.lower(k), "rename token") then
                    found = true
                    tokens = tokens + (type(v) == "table" and (v.Amount or v.Count or v.Quantity or 1) or (type(v) == "number" and v or 1))
                end
            end
        end
    end)
    return found, tokens
end

local function generateRandomName()
    local len = math.random(5, 15)
    local chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    local name = ""
    for i=1,len do local r=math.random(1,#chars) name=name..string.sub(chars,r,r) end
    return name
end

-- ========== STATE MACHINE ==========
RunService:BindToRenderStep("Bifrost_StateMachine", Enum.RenderPriority.Camera.Value, function()
    local ct = tick()

    if ct - AppState.LastTokenTick >= 1.5 then
        AppState.LastTokenTick = ct
        local found, tokens = GetTokens()
        if found then SafeSetUI(TokenLabel, "TokenText", "Rename Tokens: " .. tostring(tokens)) end
    end

    if HubConfig.AutoFarm and not AppState.IsHopping then
        if ct - AppState.StartupTick < 15 then
            SafeSetUI(FSL, "FarmText", "Status: Loading map (" .. math.floor(15 - (ct - AppState.StartupTick)) .. "s)")
        elseif ct - AppState.LastFarmTick >= 0.5 then
            AppState.LastFarmTick = ct
            if HubConfig.AnchorX and HubConfig.AnchorY and HubConfig.AnchorZ then
                local ch = Players.LocalPlayer.Character
                local hr = ch and ch:FindFirstChild("HumanoidRootPart")
                local hm = ch and ch:FindFirstChild("Humanoid")
                if hr and hm and hm.Health > 0 then
                    local ap = Vector3.new(HubConfig.AnchorX, HubConfig.AnchorY, HubConfig.AnchorZ)
                    if (hr.Position - ap).Magnitude > 5 then
                        hr.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                        hr.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                        ch:PivotTo(CFrame.new(ap))
                    end
                end
            end
            pcall(function()
                local boss = GetBossInWorkspace()
                if boss then
                    SafeSetUI(FSL, "FarmText", "Status: Attacking " .. boss.Name)
                    local dr = ReplicatedStorage:FindFirstChild("BridgeNet") and ReplicatedStorage.BridgeNet:FindFirstChild("dataRemoteEvent")
                    if dr then dr:FireServer(unpack({ { { "General", "Attack", "Click", {}, n = 4 }, "\002" } })) end
                else
                    if HubConfig.AutoHop then
                        if tick() - AppState.LastHopAttempt > 5 then ForceServerHop() end
                    else
                        SafeSetUI(FSL, "FarmText", "Status: Boss absent.")
                    end
                end
            end)
        end
    elseif not HubConfig.AutoFarm and not AppState.IsHopping then
        SafeSetUI(FSL, "FarmText", "Status: Stopped")
    end

    if AppState.AutoRollEnabled and #AppState.SelectedPetUUIDs > 0 then
        if ct - AppState.LastRollTick >= 0.8 then
            AppState.LastRollTick = ct
            pcall(function()
                for i, uuid in ipairs(AppState.SelectedPetUUIDs) do
                    local pd = Omni.Data.Inventory.Units[uuid]
                    if pd then
                        local cv = (pd.RenameBuffs and pd.RenameBuffs[HubConfig.SelectedBuff]) or 0
                        if cv < HubConfig.TargetValue - 0.001 then
                            Omni.Signal:Fire("General", "Units", "Rename", uuid, generateRandomName())
                            break
                        else
                            table.remove(AppState.SelectedPetUUIDs, i)
                            RefreshPetsUI()
                            return
                        end
                    else
                        table.remove(AppState.SelectedPetUUIDs, i)
                    end
                end
            end)
        end
    end
end)

-- ========== TELEPORT RECOVERY ==========
table.insert(Connections, TeleportService.TeleportInitFailed:Connect(function(player)
    if player == Players.LocalPlayer then
        task.spawn(function()
            task.wait(5)
            AppState.IsHopping = false
            AppState.LastHopAttempt = 0
            if SG then pcall(function() SG.Enabled = true end) end
            SafeSetUI(FSL, "FarmText", "Status: Hop failed. Retrying...")
        end)
    end
end))
