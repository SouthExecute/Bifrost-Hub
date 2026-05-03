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
    AutoHop = false, AutoFarm = false, AutoFarmStones = false,
    AnchorX = nil, AnchorY = nil, AnchorZ = nil, UseAnchor = true,
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

local Connections = {}

local function SaveConfig()
    if writefile then pcall(function() writefile(ConfigName, HttpService:JSONEncode(HubConfig)) end) end
end
local function LoadConfig()
    if readfile then
        local s,d = pcall(function() return HttpService:JSONDecode(readfile(ConfigName)) end)
        if s and type(d)=="table" then 
            for k,v in pairs(d) do HubConfig[k]=v end 
            if HubConfig.UseAnchor == nil then HubConfig.UseAnchor = true end
        end
    end
end

-- ========== THEME ==========
local T = {
    BG = Color3.fromRGB(20, 20, 28),
    Sidebar = Color3.fromRGB(24, 24, 32),
    Content = Color3.fromRGB(28, 28, 36),
    TitleBar = Color3.fromRGB(24, 24, 32),
    Accent = Color3.fromRGB(140, 120, 255),
    AccentDim = Color3.fromRGB(90, 75, 170),
    Btn = Color3.fromRGB(35, 35, 45),
    BtnH = Color3.fromRGB(45, 45, 58),
    On = Color3.fromRGB(45, 120, 75),
    Off = Color3.fromRGB(120, 42, 42),
    T1 = Color3.fromRGB(230, 230, 240),
    T2 = Color3.fromRGB(160, 160, 180),
    T3 = Color3.fromRGB(90, 90, 115),
    Sep = Color3.fromRGB(40, 40, 52),
    TabA = Color3.fromRGB(32, 32, 42),
    TabI = Color3.fromRGB(24, 24, 32),
    Input = Color3.fromRGB(30, 30, 40),
    PetS = Color3.fromRGB(45, 42, 65),
    PetN = Color3.fromRGB(32, 32, 42),
}

-- ========== CLEANUP ==========
pcall(function()
    local g = CoreGui:FindFirstChild("BifrostHubV2")
    if g then g:Destroy() end
    g = CoreGui:FindFirstChild("BifrostLiteUI")
    if g then g:Destroy() end
    local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
    g = pg:FindFirstChild("BifrostHubV2")
    if g then g:Destroy() end
    g = pg:FindFirstChild("BifrostLiteUI")
    if g then g:Destroy() end
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
local SW = 155
local MF = Instance.new("Frame", SG)
MF.Name = "Main"
MF.Size = UDim2.new(0, 560, 0, 420)
MF.Position = UDim2.new(0.5, -280, 0.5, -210)
MF.BackgroundColor3 = T.BG
MF.BackgroundTransparency = 0.03
MF.BorderSizePixel = 0
MF.Active = true
MF.Draggable = true
Instance.new("UICorner", MF).CornerRadius = UDim.new(0, 10)

-- ========== SIDEBAR ==========
local SB = Instance.new("Frame", MF)
SB.Size = UDim2.new(0, SW, 1, 0)
SB.BackgroundColor3 = T.Sidebar
SB.BackgroundTransparency = 0.02
SB.BorderSizePixel = 0
Instance.new("UICorner", SB).CornerRadius = UDim.new(0, 10)

-- Title in sidebar
local SBTitle = Instance.new("TextLabel", SB)
SBTitle.Size = UDim2.new(1, -20, 0, 50)
SBTitle.Position = UDim2.new(0, 15, 0, 8)
SBTitle.BackgroundTransparency = 1
SBTitle.Text = "Bifrost Hub"
SBTitle.TextColor3 = T.T1
SBTitle.TextXAlignment = Enum.TextXAlignment.Left
SBTitle.Font = Enum.Font.GothamBold
SBTitle.TextSize = 16

-- Sidebar separator
local SBSep = Instance.new("Frame", SB)
SBSep.Size = UDim2.new(0.75, 0, 0, 1)
SBSep.Position = UDim2.new(0.125, 0, 0, 55)
SBSep.BackgroundColor3 = T.Sep
SBSep.BorderSizePixel = 0

-- Tab buttons container
local TabBtnContainer = Instance.new("Frame", SB)
TabBtnContainer.Size = UDim2.new(1, -16, 1, -68)
TabBtnContainer.Position = UDim2.new(0, 8, 0, 64)
TabBtnContainer.BackgroundTransparency = 1
local TBLayout = Instance.new("UIListLayout", TabBtnContainer)
TBLayout.Padding = UDim.new(0, 4)

-- Divider line between sidebar and content
local Dv = Instance.new("Frame", MF)
Dv.Size = UDim2.new(0, 1, 1, -20)
Dv.Position = UDim2.new(0, SW, 0, 10)
Dv.BackgroundColor3 = T.Sep
Dv.BorderSizePixel = 0

-- ========== CONTENT AREA ==========
local CA = Instance.new("Frame", MF)
CA.Size = UDim2.new(1, -(SW + 1), 1, 0)
CA.Position = UDim2.new(0, SW + 1, 0, 0)
CA.BackgroundColor3 = T.Content
CA.BackgroundTransparency = 0.02
CA.BorderSizePixel = 0
CA.ClipsDescendants = true
Instance.new("UICorner", CA).CornerRadius = UDim.new(0, 10)

-- Content header (shows current tab name)
local CHdr = Instance.new("TextLabel", CA)
CHdr.Name = "TabHeader"
CHdr.Size = UDim2.new(1, -80, 0, 40)
CHdr.Position = UDim2.new(0, 18, 0, 5)
CHdr.BackgroundTransparency = 1
CHdr.Text = "Auto-Roll"
CHdr.TextColor3 = T.T1
CHdr.TextXAlignment = Enum.TextXAlignment.Left
CHdr.Font = Enum.Font.GothamBold
CHdr.TextSize = 15

-- Minimize btn in content header
local MinB = Instance.new("TextButton", CA)
MinB.Size = UDim2.new(0, 28, 0, 28)
MinB.Position = UDim2.new(1, -62, 0, 9)
MinB.BackgroundColor3 = T.Btn
MinB.Text = "_"
MinB.TextColor3 = T.T2
MinB.Font = Enum.Font.GothamBold
MinB.TextSize = 14
MinB.BorderSizePixel = 0
MinB.AutoButtonColor = false
Instance.new("UICorner", MinB).CornerRadius = UDim.new(0, 6)

-- Close btn in content header
local ClsB = Instance.new("TextButton", CA)
ClsB.Size = UDim2.new(0, 28, 0, 28)
ClsB.Position = UDim2.new(1, -30, 0, 9)
ClsB.BackgroundColor3 = T.Btn
ClsB.Text = "X"
ClsB.TextColor3 = T.T2
ClsB.Font = Enum.Font.GothamBold
ClsB.TextSize = 14
ClsB.BorderSizePixel = 0
ClsB.AutoButtonColor = false
Instance.new("UICorner", ClsB).CornerRadius = UDim.new(0, 6)

-- Content separator
local CSep = Instance.new("Frame", CA)
CSep.Size = UDim2.new(1, -30, 0, 1)
CSep.Position = UDim2.new(0, 15, 0, 44)
CSep.BackgroundColor3 = T.Sep
CSep.BorderSizePixel = 0

-- ========== FLOATING ICON ==========
local FI = Instance.new("TextButton", SG)
FI.Size = UDim2.new(0, 40, 0, 40)
FI.Position = UDim2.new(0, 20, 0.5, -20)
FI.BackgroundColor3 = T.Accent
FI.Text = "B"
FI.TextColor3 = Color3.new(1, 1, 1)
FI.Font = Enum.Font.GothamBold
FI.TextSize = 18
FI.BorderSizePixel = 0
FI.Visible = false
FI.Active = true
FI.Draggable = true
FI.AutoButtonColor = false
Instance.new("UICorner", FI).CornerRadius = UDim.new(0.5, 0)

-- ========== TAB SYSTEM ==========
local Tabs = {}

local function CreateTab(name, icon)
    local bt = Instance.new("TextButton", TabBtnContainer)
    bt.Name = "T_" .. name
    bt.Size = UDim2.new(1, 0, 0, 36)
    bt.BackgroundColor3 = T.TabI
    bt.BackgroundTransparency = 1
    bt.Text = "  " .. (icon or "") .. "  " .. name
    bt.TextColor3 = T.T3
    bt.TextXAlignment = Enum.TextXAlignment.Left
    bt.Font = Enum.Font.GothamSemibold
    bt.TextSize = 14
    bt.BorderSizePixel = 0
    bt.AutoButtonColor = false
    Instance.new("UICorner", bt).CornerRadius = UDim.new(0, 8)

    local ct = Instance.new("ScrollingFrame", CA)
    ct.Name = "C_" .. name
    ct.Size = UDim2.new(1, -24, 1, -52)
    ct.Position = UDim2.new(0, 12, 0, 50)
    ct.BackgroundTransparency = 1
    ct.ScrollBarThickness = 3
    ct.ScrollBarImageColor3 = T.AccentDim
    ct.Visible = false
    ct.BorderSizePixel = 0
    ct.CanvasSize = UDim2.new(0, 0, 0, 0)
    ct.AutomaticCanvasSize = Enum.AutomaticSize.Y
    Instance.new("UIListLayout", ct).Padding = UDim.new(0, 6)

    Tabs[name] = {Button = bt, Content = ct}


    bt.MouseButton1Click:Connect(function()
        for n, d in pairs(Tabs) do
            local a = (n == name)
            d.Content.Visible = a
            d.Button.BackgroundColor3 = a and T.TabA or T.TabI
            d.Button.BackgroundTransparency = a and 0 or 1
            d.Button.TextColor3 = a and T.Accent or T.T3
        end
        CHdr.Text = name
    end)
    return ct
end

-- ========== HELPERS ==========

local function Label(p, t)
    local l = Instance.new("TextLabel", p)
    l.Size = UDim2.new(1, 0, 0, 22)
    l.BackgroundTransparency = 1
    l.TextColor3 = T.T2
    l.Text = t
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Font = Enum.Font.Gotham
    l.TextSize = 13
    return l
end

local function Btn(p, t, cb2)
    local b = Instance.new("TextButton", p)
    b.Size = UDim2.new(1, 0, 0, 34)
    b.BackgroundColor3 = T.Btn
    b.TextColor3 = T.T1
    b.Text = t
    b.Font = Enum.Font.GothamSemibold
    b.TextSize = 13
    b.BorderSizePixel = 0
    b.AutoButtonColor = false
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    b.MouseEnter:Connect(function() b.BackgroundColor3 = T.BtnH end)
    b.MouseLeave:Connect(function() if not b:GetAttribute("IT") then b.BackgroundColor3 = T.Btn end end)
    if cb2 then b.MouseButton1Click:Connect(cb2) end
    return b
end

local function Toggle(p, t, def, cb2)
    local st = def
    local b = Instance.new("TextButton", p)
    b.Size = UDim2.new(1, 0, 0, 34)
    b.BackgroundColor3 = st and T.On or T.Off
    b.TextColor3 = T.T1
    b.Text = t .. ": " .. (st and "ON" or "OFF")
    b.Font = Enum.Font.GothamSemibold
    b.TextSize = 13
    b.BorderSizePixel = 0
    b.AutoButtonColor = false
    b:SetAttribute("IT", true)
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    b.MouseButton1Click:Connect(function()
        st = not st
        b.Text = t .. ": " .. (st and "ON" or "OFF")
        b.BackgroundColor3 = st and T.On or T.Off
        cb2(st)
    end)
    return function(ns)
        st = ns
        b.Text = t .. ": " .. (st and "ON" or "OFF")
        b.BackgroundColor3 = st and T.On or T.Off
    end
end

local function SafeSetUI(lbl, key, txt)
    if AppState[key] ~= txt then
        AppState[key] = txt
        if lbl then pcall(function() lbl.Text = txt end) end
    end
end

-- ========== UI STATE ==========
local function MinimizeUI() MF.Visible = false FI.Visible = true AppState.UIVisible = false end
local function RestoreUI() MF.Visible = true FI.Visible = false AppState.UIVisible = true end
local function ToggleUI() if AppState.UIDestroyed then return end if AppState.UIVisible then MinimizeUI() else RestoreUI() end end
local function DestroyUI()
    AppState.UIDestroyed = true
    for _, c in ipairs(Connections) do pcall(function() c:Disconnect() end) end
    table.clear(Connections)
    pcall(function() RunService:UnbindFromRenderStep("Bifrost_StateMachine") end)
    pcall(function() SG:Destroy() end)
end

local ccf = false
ClsB.MouseButton1Click:Connect(function()
    if ccf then DestroyUI() else
        ccf = true
        ClsB.Text = "?"
        ClsB.TextColor3 = Color3.fromRGB(255, 80, 80)
        task.delay(3, function()
            if not AppState.UIDestroyed then
                ccf = false
                pcall(function() ClsB.Text = "X" ClsB.TextColor3 = T.T2 end)
            end
        end)
    end
end)
MinB.MouseButton1Click:Connect(function() MinimizeUI() end)
FI.MouseButton1Click:Connect(function() RestoreUI() end)

-- ========== LOAD & TABS ==========
LoadConfig()
local TabRoll = CreateTab("Auto-Roll", ">")
local TabFarm = CreateTab("Farm", ">")
local TabSet = CreateTab("Settings", ">")

-- Activate first tab
Tabs["Auto-Roll"].Content.Visible = true
Tabs["Auto-Roll"].Button.BackgroundColor3 = T.TabA
Tabs["Auto-Roll"].Button.BackgroundTransparency = 0
Tabs["Auto-Roll"].Button.TextColor3 = T.Accent
CHdr.Text = "Auto-Roll"

-- ========== [TAB] AUTO-ROLL ==========
local TokenLabel = Label(TabRoll, "Rename Tokens: Searching...")
local PC = Instance.new("Frame", TabRoll)
PC.Size = UDim2.new(1, 0, 0, 120)
PC.BackgroundColor3 = T.Input
PC.BorderSizePixel = 0
Instance.new("UICorner", PC).CornerRadius = UDim.new(0, 6)

local PS = Instance.new("ScrollingFrame", PC)
PS.Size = UDim2.new(1, -10, 1, -10)
PS.Position = UDim2.new(0, 5, 0, 5)
PS.BackgroundTransparency = 1
PS.ScrollBarThickness = 3
PS.ScrollBarImageColor3 = T.AccentDim
PS.BorderSizePixel = 0
local PL = Instance.new("UIListLayout", PS)
PL.Padding = UDim.new(0, 3)

local function RefreshPetsUI()
    for _, c in ipairs(PS:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
    AppState.SelectedPetUUIDs = {}

    pcall(function()
        local units = Omni.Data.Inventory.Units
        if units then
            for uuid, pet in pairs(units) do
                local dn = pet.CustomName or pet.Name or "?"
                local p = pet.RenameBuffs and pet.RenameBuffs["Power"] or 0
                local d = pet.RenameBuffs and pet.RenameBuffs["Damage"] or 0
                local c2 = pet.RenameBuffs and pet.RenameBuffs["Crystals"] or 0
                local opt = string.format("%s  (P:%.1f  D:%.1f  C:%.1f)", dn, p, d, c2)
                local pb = Instance.new("TextButton", PS)
                pb.Size = UDim2.new(1, 0, 0, 26)
                pb.BackgroundColor3 = T.PetN
                pb.TextColor3 = T.T2
                pb.Text = "   [ ]  " .. opt
                pb.TextXAlignment = Enum.TextXAlignment.Left
                pb.Font = Enum.Font.Gotham
                pb.TextSize = 12
                pb.BorderSizePixel = 0
                pb.AutoButtonColor = false
                Instance.new("UICorner", pb).CornerRadius = UDim.new(0, 5)
                local sel = false
                pb.MouseButton1Click:Connect(function()
                    sel = not sel
                    if sel then
                        pb.Text = "   [x]  " .. opt
                        pb.TextColor3 = T.T1
                        pb.BackgroundColor3 = T.PetS
                        table.insert(AppState.SelectedPetUUIDs, uuid)
                    else
                        pb.Text = "   [ ]  " .. opt
                        pb.TextColor3 = T.T2
                        pb.BackgroundColor3 = T.PetN
                        for i, v in ipairs(AppState.SelectedPetUUIDs) do
                            if v == uuid then table.remove(AppState.SelectedPetUUIDs, i) break end
                        end
                    end
                end)
            end
        end
    end)
    PS.CanvasSize = UDim2.new(0, 0, 0, PL.AbsoluteContentSize.Y)
end

Btn(TabRoll, "Refresh Pet List", function() RefreshPetsUI() end)
RefreshPetsUI()

-- spacer
local _s1 = Instance.new("Frame", TabRoll) _s1.Size = UDim2.new(1, 0, 0, 4) _s1.BackgroundTransparency = 1
local function NextArr(a, c) for i, v in ipairs(a) do if v == c then return a[i + 1] or a[1] end end return a[1] end

local function GetValueLimits()
    if HubConfig.SelectedBuff == "Power" then return 1.75, 1.70 end
    return 0.75, 0.70
end

local VF -- forward declare to use in BB

local BB
BB = Btn(TabRoll, "Buff: " .. HubConfig.SelectedBuff, function()
    HubConfig.SelectedBuff = NextArr(Buffs, HubConfig.SelectedBuff)
    BB.Text = "Buff: " .. HubConfig.SelectedBuff
    local maxV = GetValueLimits()
    if HubConfig.TargetValue > maxV then
        HubConfig.TargetValue = maxV
        if VF and VF:FindFirstChild("VL") then VF.VL.Text = string.format("Target Value: %.2f", HubConfig.TargetValue) end
    end
    SaveConfig()
end)

VF = Instance.new("Frame", TabRoll)
VF.Size = UDim2.new(1, 0, 0, 34)
VF.BackgroundTransparency = 1

local VS = Btn(VF, "-", function()
    local maxV, slowV = GetValueLimits()
    local step = (HubConfig.TargetValue > slowV + 0.001) and 0.01 or 0.05
    HubConfig.TargetValue = math.max(0.10, HubConfig.TargetValue - step)
    HubConfig.TargetValue = math.floor(HubConfig.TargetValue * 100 + 0.5) / 100
    VF:FindFirstChild("VL").Text = string.format("Target Value: %.2f", HubConfig.TargetValue)
    SaveConfig()
end)
VS.Size = UDim2.new(0.18, 0, 1, 0)

local VLbl = Label(VF, string.format("Target Value: %.2f", HubConfig.TargetValue))
VLbl.Name = "VL"
VLbl.Size = UDim2.new(0.64, 0, 1, 0)
VLbl.Position = UDim2.new(0.18, 0, 0, 0)
VLbl.TextXAlignment = Enum.TextXAlignment.Center
VLbl.TextSize = 13

local VA = Btn(VF, "+", function()
    local maxV, slowV = GetValueLimits()
    local step = (HubConfig.TargetValue >= slowV - 0.001) and 0.01 or 0.05
    HubConfig.TargetValue = math.min(maxV, HubConfig.TargetValue + step)
    HubConfig.TargetValue = math.floor(HubConfig.TargetValue * 100 + 0.5) / 100
    VLbl.Text = string.format("Target Value: %.2f", HubConfig.TargetValue)
    SaveConfig()
end)
VA.Size = UDim2.new(0.18, 0, 1, 0)
VA.Position = UDim2.new(0.82, 0, 0, 0)

local SetAutoRoll
SetAutoRoll = Toggle(TabRoll, "Auto-Roll", false, function(val)
    if val and #AppState.SelectedPetUUIDs == 0 then
        local ot = SBTitle.Text
        SBTitle.Text = "Select a pet!"
        SBTitle.TextColor3 = Color3.fromRGB(255, 100, 100)
        task.delay(2, function() SBTitle.Text = ot SBTitle.TextColor3 = T.T1 end)
        SetAutoRoll(false)
        return
    end
    AppState.AutoRollEnabled = val
end)

-- ========== [TAB] FARM ==========
local BBtn
BBtn = Btn(TabFarm, "Boss: " .. HubConfig.SelectedBoss, function()
    HubConfig.SelectedBoss = NextArr(Bosses, HubConfig.SelectedBoss)
    BBtn.Text = "Boss: " .. HubConfig.SelectedBoss
    SaveConfig()
end)


local SetAutoHop = Toggle(TabFarm, "Auto Server-Hop", HubConfig.AutoHop, function(v) HubConfig.AutoHop = v SaveConfig() end)
local SetAutoFarm = Toggle(TabFarm, "Auto-Farm Boss", HubConfig.AutoFarm, function(v) HubConfig.AutoFarm = v SaveConfig() end)
local SetAutoStones = Toggle(TabFarm, "Auto-Farm Ores (Stones)", HubConfig.AutoFarmStones, function(v) HubConfig.AutoFarmStones = v SaveConfig() end)

-- spacer
local _s2 = Instance.new("Frame", TabFarm) _s2.Size = UDim2.new(1, 0, 0, 4) _s2.BackgroundTransparency = 1
local FSL = Label(TabFarm, "Status: Waiting...")


local ABtn
local SetUseAnchor = Toggle(TabFarm, "Lock to Anchor", HubConfig.UseAnchor, function(v) HubConfig.UseAnchor = v SaveConfig() end)
ABtn = Btn(TabFarm, "Set Farm Anchor (Stand here)", function()
    local ch = Players.LocalPlayer.Character
    local hr = ch and ch:FindFirstChild("HumanoidRootPart")
    if hr then
        HubConfig.AnchorX = hr.Position.X
        HubConfig.AnchorY = hr.Position.Y
        HubConfig.AnchorZ = hr.Position.Z
        SaveConfig()
        SafeSetUI(FSL, "FarmText", "Status: Anchor saved!")
        local ot = ABtn.Text
        ABtn.Text = ">> Saved!"
        ABtn.BackgroundColor3 = Color3.fromRGB(40, 130, 50)
        task.delay(1.5, function() pcall(function() ABtn.Text = ot ABtn.BackgroundColor3 = T.Btn end) end)
    end
end)

Btn(TabFarm, "Force Server Hop", function() ForceServerHop() end)

-- ========== [TAB] SETTINGS ==========
-- ========== [TAB] SETTINGS ==========
Btn(TabSet, "Minimize UI", function() MinimizeUI() end)

local delBtn
delBtn = Btn(TabSet, "Delete UI (Destroy)", function()
    if delBtn:GetAttribute("confirm") then
        DestroyUI()
    else
        delBtn:SetAttribute("confirm", true)
        delBtn.Text = "Click again to confirm"
        delBtn.BackgroundColor3 = Color3.fromRGB(140, 40, 40)
        task.delay(3, function()
            if not AppState.UIDestroyed then
                pcall(function()
                    delBtn:SetAttribute("confirm", false)
                    delBtn.Text = "Delete UI (Destroy)"
                    delBtn.BackgroundColor3 = T.Btn
                end)
            end
        end)
    end
end)

-- spacer
local _s3 = Instance.new("Frame", TabSet) _s3.Size = UDim2.new(1, 0, 0, 4) _s3.BackgroundTransparency = 1
local kbKey = HubConfig.UIKeybind or "RightShift"
local kbBtn
local kbListening = false
kbBtn = Btn(TabSet, "Toggle Key: " .. kbKey, function()
    if kbListening then return end
    kbListening = true
    kbBtn.Text = "Press any key..."
    kbBtn.BackgroundColor3 = T.Accent
end)

table.insert(Connections, UIS.InputBegan:Connect(function(inp, gpe)
    if AppState.UIDestroyed then return end
    if kbListening and not gpe then
        kbListening = false
        kbKey = inp.KeyCode.Name
        HubConfig.UIKeybind = kbKey
        SaveConfig()
        pcall(function() kbBtn.Text = "Toggle Key: " .. kbKey kbBtn.BackgroundColor3 = T.Btn end)
        return
    end
    if not gpe and inp.KeyCode.Name == kbKey then ToggleUI() end
end))

-- spacer
local _s4 = Instance.new("Frame", TabSet) _s4.Size = UDim2.new(1, 0, 0, 4) _s4.BackgroundTransparency = 1
Btn(TabSet, "Save Settings", function()
    SaveConfig()
    local ot = SBTitle.Text
    SBTitle.Text = "Saved!"
    SBTitle.TextColor3 = Color3.fromRGB(100, 255, 100)
    task.delay(2, function() pcall(function() SBTitle.Text = ot SBTitle.TextColor3 = T.T1 end) end)
end)

-- spacer
local _s5 = Instance.new("Frame", TabSet) _s5.Size = UDim2.new(1, 0, 0, 4) _s5.BackgroundTransparency = 1
Label(TabSet, "Bifrost Hub v2.0 - Vanilla UI")
Label(TabSet, "Performance-first | Zero dependencies")

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

local function GetOreInWorkspace()
    local candidates = {}
    local c = Workspace:FindFirstChild("Client")
    if c and c:FindFirstChild("Enemies") then
        for _, obj in ipairs(c.Enemies:GetChildren()) do table.insert(candidates, obj) end
    end
    
    local s = Workspace:FindFirstChild("Server")
    if s and s:FindFirstChild("Enemies") and s.Enemies:FindFirstChild("Ores") then
        for _, oreFolder in ipairs(s.Enemies.Ores:GetChildren()) do
            if oreFolder:FindFirstChild("Drops") then
                for _, obj in ipairs(oreFolder.Drops:GetChildren()) do table.insert(candidates, obj) end
            else
                table.insert(candidates, oreFolder)
            end
        end
    end
    
    for _, obj in ipairs(candidates) do
        if obj:IsA("Model") and string.find(string.lower(obj.Name), "ore") then
            local hum = obj:FindFirstChild("Humanoid")
            if hum then
                if hum.Health > 0 then return obj end
            elseif obj.PrimaryPart then
                return obj
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

    local isFarming = (HubConfig.AutoFarm or HubConfig.AutoFarmStones)
    if isFarming and not AppState.IsHopping then
        if ct - AppState.StartupTick < 15 then
            SafeSetUI(FSL, "FarmText", "Status: Loading map (" .. math.floor(15 - (ct - AppState.StartupTick)) .. "s)")
        elseif ct - AppState.LastFarmTick >= 0.5 then
            AppState.LastFarmTick = ct
            
            pcall(function()
                local ch = Players.LocalPlayer.Character
                local hr = ch and ch:FindFirstChild("HumanoidRootPart")
                local hm = ch and ch:FindFirstChild("Humanoid")
                
                local ore = nil
                if HubConfig.AutoFarmStones then ore = GetOreInWorkspace() end
                
                if ore and hr and hm and hm.Health > 0 then
                    -- Teleport to Ore
                    hr.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                    hr.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                    ch:PivotTo(CFrame.new(ore:GetPivot().Position + Vector3.new(0, 3, 0)))
                    SafeSetUI(FSL, "FarmText", "Status: Mining " .. ore.Name)
                    
                    local dr = ReplicatedStorage:FindFirstChild("BridgeNet") and ReplicatedStorage.BridgeNet:FindFirstChild("dataRemoteEvent")
                    if dr then dr:FireServer(unpack({ { { "General", "Attack", "Click", {}, n = 4 }, "\002" } })) end
                else
                    -- Return to Anchor
                    if HubConfig.UseAnchor and HubConfig.AnchorX and HubConfig.AnchorY and HubConfig.AnchorZ then
                        if hr and hm and hm.Health > 0 then
                            local ap = Vector3.new(HubConfig.AnchorX, HubConfig.AnchorY, HubConfig.AnchorZ)
                            if (hr.Position - ap).Magnitude > 5 then
                                hr.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                                hr.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                                ch:PivotTo(CFrame.new(ap))
                            end
                        end
                    end
                    
                    -- Boss Farm fallback
                    if HubConfig.AutoFarm then
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
                    else
                        SafeSetUI(FSL, "FarmText", "Status: Waiting at Anchor...")
                    end
                end
            end)
        end
    elseif not isFarming and not AppState.IsHopping then
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
