local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local Omni = require(ReplicatedStorage:WaitForChild("Omni"))

-- ==========================================
-- STATE MACHINE & GLOBALS
-- ==========================================
local ConfigName = "BifrostHub_Config.json"
local HubConfig = {
    SelectedBuff = "Power",
    TargetValue = 1.00,
    SelectedBoss = "Yuje",
    AutoHop = false,
    AutoFarm = false,
    AnchorX = nil,
    AnchorY = nil,
    AnchorZ = nil,
}

local AppState = {
    IsHopping = false,
    LastHopAttempt = 0,
    FarmText = "",
    TokenText = "",
    AutoRollEnabled = false,
    SelectedPetUUIDs = {},
    LastRollTick = 0,
    LastFarmTick = 0,
    LastTokenTick = 0,
    StartupTick = tick()
}

local BossNameMapping = { ["Yuje"] = "Yuji", ["Satoro"] = "Goujo", ["Sakana"] = "Meguna" }
local Bosses = {"Yuje", "Satoro", "Sakana"}
local Buffs = {"Power", "Damage", "Crystals"}
local OptionsToUUIDs = {}

-- ==========================================
-- CORE FUNCTIONS
-- ==========================================
local function SaveConfig()
    if writefile then pcall(function() writefile(ConfigName, HttpService:JSONEncode(HubConfig)) end) end
end

local function LoadConfig()
    if readfile then
        local s, d = pcall(function() return HttpService:JSONDecode(readfile(ConfigName)) end)
        if s and type(d) == "table" then
            for k, v in pairs(d) do HubConfig[k] = v end
        end
    end
end

-- ==========================================
-- CUSTOM VANILLA UI ENGINE (ANTI-LEAK)
-- ==========================================
-- Limpeza de UI anterior (se re-executado)
pcall(function()
    if CoreGui:FindFirstChild("BifrostLiteUI") then
        CoreGui.BifrostLiteUI:Destroy()
    end
    if Players.LocalPlayer:WaitForChild("PlayerGui"):FindFirstChild("BifrostLiteUI") then
        Players.LocalPlayer.PlayerGui.BifrostLiteUI:Destroy()
    end
end)

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "BifrostLiteUI"
ScreenGui.ResetOnSpawn = false
if not pcall(function() ScreenGui.Parent = CoreGui end) then
    ScreenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size = UDim2.new(0, 320, 0, 400)
MainFrame.Position = UDim2.new(0.5, -160, 0.5, -200)
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true

local Title = Instance.new("TextLabel", MainFrame)
Title.Size = UDim2.new(1, 0, 0, 30)
Title.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
Title.TextColor3 = Color3.fromRGB(200, 200, 255)
Title.Text = "  Bifrost Hub Lite (Anti-Leak)"
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Font = Enum.Font.GothamBold
Title.TextSize = 14
Title.BorderSizePixel = 0

local TabContainer = Instance.new("Frame", MainFrame)
TabContainer.Size = UDim2.new(1, 0, 0, 30)
TabContainer.Position = UDim2.new(0, 0, 0, 30)
TabContainer.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
TabContainer.BorderSizePixel = 0
local TabLayout = Instance.new("UIListLayout", TabContainer)
TabLayout.FillDirection = Enum.FillDirection.Horizontal

local ContentContainer = Instance.new("Frame", MainFrame)
ContentContainer.Size = UDim2.new(1, -20, 1, -70)
ContentContainer.Position = UDim2.new(0, 10, 0, 70)
ContentContainer.BackgroundTransparency = 1

local Tabs = {}
local function CreateTab(name)
    local btn = Instance.new("TextButton", TabContainer)
    btn.Size = UDim2.new(1/3, 0, 1, 0)
    btn.Text = name
    btn.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    btn.TextColor3 = Color3.fromRGB(200, 200, 200)
    btn.Font = Enum.Font.GothamSemibold
    btn.TextSize = 12
    btn.BorderSizePixel = 0
    
    local content = Instance.new("ScrollingFrame", ContentContainer)
    content.Size = UDim2.new(1, 0, 1, 0)
    content.BackgroundTransparency = 1
    content.ScrollBarThickness = 4
    content.Visible = false
    content.BorderSizePixel = 0
    
    local layout = Instance.new("UIListLayout", content)
    layout.Padding = UDim.new(0, 8)
    
    Tabs[name] = {Button = btn, Content = content}
    
    btn.MouseButton1Click:Connect(function()
        for tName, tabData in pairs(Tabs) do
            tabData.Content.Visible = (tName == name)
            tabData.Button.BackgroundColor3 = (tName == name) and Color3.fromRGB(50, 50, 60) or Color3.fromRGB(30, 30, 35)
            tabData.Button.TextColor3 = (tName == name) and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(200, 200, 200)
        end
    end)
    return content
end

local function CreateLabel(parent, text)
    local lbl = Instance.new("TextLabel", parent)
    lbl.Size = UDim2.new(1, 0, 0, 20)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = Color3.fromRGB(200, 200, 200)
    lbl.Text = text
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 13
    return lbl
end

local function CreateButton(parent, text, callback)
    local btn = Instance.new("TextButton", parent)
    btn.Size = UDim2.new(1, 0, 0, 30)
    btn.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Text = text
    btn.Font = Enum.Font.GothamSemibold
    btn.TextSize = 13
    btn.BorderSizePixel = 0
    local corner = Instance.new("UICorner", btn)
    corner.CornerRadius = UDim.new(0, 4)
    btn.MouseButton1Click:Connect(callback)
    return btn
end

local function CreateToggle(parent, text, default, callback)
    local state = default
    local btn = CreateButton(parent, text .. ": " .. (state and "ON" or "OFF"), nil)
    btn.BackgroundColor3 = state and Color3.fromRGB(50, 120, 50) or Color3.fromRGB(120, 50, 50)
    btn.MouseButton1Click:Connect(function()
        state = not state
        btn.Text = text .. ": " .. (state and "ON" or "OFF")
        btn.BackgroundColor3 = state and Color3.fromRGB(50, 120, 50) or Color3.fromRGB(120, 50, 50)
        callback(state)
    end)
    return function(newState)
        state = newState
        btn.Text = text .. ": " .. (state and "ON" or "OFF")
        btn.BackgroundColor3 = state and Color3.fromRGB(50, 120, 50) or Color3.fromRGB(120, 50, 50)
    end
end

local function SafeSetUI(label, stateKey, newText)
    if AppState[stateKey] ~= newText then
        AppState[stateKey] = newText
        if label then pcall(function() label.Text = newText end) end
    end
end

-- ==========================================
-- LOGIC & UI BINDING
-- ==========================================
LoadConfig()

local TabRoll = CreateTab("Auto-Roll")
local TabFarm = CreateTab("Global Farm")
local TabConfig = CreateTab("Config")

-- Ativa a primeira tab
Tabs["Auto-Roll"].Button.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
Tabs["Auto-Roll"].Button.TextColor3 = Color3.fromRGB(255, 255, 255)
Tabs["Auto-Roll"].Content.Visible = true

-- [ AUTO-ROLL TAB ]
local TokenLabel = CreateLabel(TabRoll, "Rename Tokens: Procurando...")

local PetsContainer = Instance.new("Frame", TabRoll)
PetsContainer.Size = UDim2.new(1, 0, 0, 100)
PetsContainer.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
PetsContainer.BorderSizePixel = 0
local PetsCorner = Instance.new("UICorner", PetsContainer)
PetsCorner.CornerRadius = UDim.new(0, 4)
local PetsScroll = Instance.new("ScrollingFrame", PetsContainer)
PetsScroll.Size = UDim2.new(1, -10, 1, -10)
PetsScroll.Position = UDim2.new(0, 5, 0, 5)
PetsScroll.BackgroundTransparency = 1
PetsScroll.ScrollBarThickness = 3
local PetsLayout = Instance.new("UIListLayout", PetsScroll)
PetsLayout.Padding = UDim.new(0, 2)

local function RefreshPetsUI()
    for _, child in ipairs(PetsScroll:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end
    AppState.SelectedPetUUIDs = {}
    
    local pets = {}
    table.clear(OptionsToUUIDs)
    pcall(function()
        local units = Omni.Data.Inventory.Units
        if units then
            for uuid, pet in pairs(units) do
                local dName = pet.CustomName or pet.Name or "Unknown"
                local p = pet.RenameBuffs and pet.RenameBuffs["Power"] or 0
                local d = pet.RenameBuffs and pet.RenameBuffs["Damage"] or 0
                local c = pet.RenameBuffs and pet.RenameBuffs["Crystals"] or 0
                local opt = string.format("%s (P:%.1f D:%.1f C:%.1f)", dName, p, d, c)
                
                local btn = Instance.new("TextButton", PetsScroll)
                btn.Size = UDim2.new(1, 0, 0, 25)
                btn.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
                btn.TextColor3 = Color3.fromRGB(150, 150, 150)
                btn.Text = "[ ] " .. opt
                btn.Font = Enum.Font.Gotham
                btn.TextSize = 11
                btn.BorderSizePixel = 0
                
                local selected = false
                btn.MouseButton1Click:Connect(function()
                    selected = not selected
                    if selected then
                        btn.Text = "[X] " .. opt
                        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
                        btn.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
                        table.insert(AppState.SelectedPetUUIDs, uuid)
                    else
                        btn.Text = "[ ] " .. opt
                        btn.TextColor3 = Color3.fromRGB(150, 150, 150)
                        btn.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
                        for i, v in ipairs(AppState.SelectedPetUUIDs) do
                            if v == uuid then table.remove(AppState.SelectedPetUUIDs, i) break end
                        end
                    end
                end)
            end
        end
    end)
    PetsScroll.CanvasSize = UDim2.new(0, 0, 0, PetsLayout.AbsoluteContentSize.Y)
end

CreateButton(TabRoll, "Refresh Pet List", function() RefreshPetsUI() end)
RefreshPetsUI()

local function NextInArray(arr, current)
    for i, v in ipairs(arr) do
        if v == current then return arr[i+1] or arr[1] end
    end
    return arr[1]
end

local BuffBtn
BuffBtn = CreateButton(TabRoll, "Target Buff: " .. HubConfig.SelectedBuff, function()
    HubConfig.SelectedBuff = NextInArray(Buffs, HubConfig.SelectedBuff)
    BuffBtn.Text = "Target Buff: " .. HubConfig.SelectedBuff
    SaveConfig()
end)

local ValFrame = Instance.new("Frame", TabRoll)
ValFrame.Size = UDim2.new(1, 0, 0, 30)
ValFrame.BackgroundTransparency = 1

local ValSub = CreateButton(ValFrame, "-", function()
    HubConfig.TargetValue = math.max(0.10, HubConfig.TargetValue - 0.05)
    ValFrame:FindFirstChild("ValLbl").Text = string.format("Value: %.2f", HubConfig.TargetValue)
    SaveConfig()
end)
ValSub.Size = UDim2.new(0.2, 0, 1, 0)
ValSub.Position = UDim2.new(0, 0, 0, 0)

local ValLbl = CreateLabel(ValFrame, string.format("Value: %.2f", HubConfig.TargetValue))
ValLbl.Name = "ValLbl"
ValLbl.Size = UDim2.new(0.6, 0, 1, 0)
ValLbl.Position = UDim2.new(0.2, 0, 0, 0)
ValLbl.TextXAlignment = Enum.TextXAlignment.Center

local ValAdd = CreateButton(ValFrame, "+", function()
    HubConfig.TargetValue = math.min(3.00, HubConfig.TargetValue + 0.05)
    ValLbl.Text = string.format("Value: %.2f", HubConfig.TargetValue)
    SaveConfig()
end)
ValAdd.Size = UDim2.new(0.2, 0, 1, 0)
ValAdd.Position = UDim2.new(0.8, 0, 0, 0)

local SetAutoRoll
SetAutoRoll = CreateToggle(TabRoll, "Auto-Roll", false, function(val)
    if val and #AppState.SelectedPetUUIDs == 0 then
        -- Notify visual nativo
        local t = Title.Text
        Title.Text = "  SELECIONE UM PET!"
        Title.TextColor3 = Color3.fromRGB(255, 100, 100)
        task.delay(2, function() Title.Text = t Title.TextColor3 = Color3.fromRGB(200, 200, 255) end)
        SetAutoRoll(false)
        return
    end
    AppState.AutoRollEnabled = val
end)

-- [ GLOBAL FARM TAB ]
local BossBtn
BossBtn = CreateButton(TabFarm, "Selected Boss: " .. HubConfig.SelectedBoss, function()
    HubConfig.SelectedBoss = NextInArray(Bosses, HubConfig.SelectedBoss)
    BossBtn.Text = "Selected Boss: " .. HubConfig.SelectedBoss
    SaveConfig()
end)

local SetAutoHop = CreateToggle(TabFarm, "Auto Server-Hop", HubConfig.AutoHop, function(val)
    HubConfig.AutoHop = val
    SaveConfig()
end)

local SetAutoFarm = CreateToggle(TabFarm, "Auto-Farm Boss", HubConfig.AutoFarm, function(val)
    HubConfig.AutoFarm = val
    SaveConfig()
end)

local FarmStatusLabel = CreateLabel(TabFarm, "Status: Aguardando...")

local AnchorBtn
AnchorBtn = CreateButton(TabFarm, "Set Farm Anchor (Stand here)", function()
    local char = Players.LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp then
        HubConfig.AnchorX = hrp.Position.X
        HubConfig.AnchorY = hrp.Position.Y
        HubConfig.AnchorZ = hrp.Position.Z
        SaveConfig()
        
        SafeSetUI(FarmStatusLabel, "FarmText", "Status: Âncora gravada com sucesso!")
        
        local oldText = AnchorBtn.Text
        AnchorBtn.Text = "✓ Posição Salva!"
        AnchorBtn.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
        task.delay(1.5, function()
            AnchorBtn.Text = oldText
            AnchorBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
        end)
    end
end)

local function TeardownAndHop(placeId, serverId)
    AppState.LastHopAttempt = tick()
    AppState.IsHopping = true
    
    -- Esconde a UI em vez de destruir, permitindo recuperação se falhar
    if ScreenGui then pcall(function() ScreenGui.Enabled = false end) end
    
    task.wait(1)
    pcall(function() task.spawn(function() TeleportService:TeleportToPlaceInstance(placeId, serverId, Players.LocalPlayer) end) end)
    
    task.wait(60)
    -- Se chegou aqui e não teleportou, o TeleportService falhou silenciosamente
    AppState.IsHopping = false
    if ScreenGui then pcall(function() ScreenGui.Enabled = true end) end
end

local function ForceServerHop()
    -- Cooldown seguro de 20s para evitar IP Ban/Rate Limit (Erro 429) da API do Roblox
    if tick() - AppState.LastHopAttempt < 20 then return end
    if AppState.IsHopping then return end
    
    AppState.LastHopAttempt = tick()
    AppState.IsHopping = true
    
    SafeSetUI(FarmStatusLabel, "FarmText", "Status: Procurando novo servidor...")
    
    local placeId = game.PlaceId
    local url = string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Desc&limit=100", placeId)
    local s, r = pcall(function() return game:HttpGet(url) end)
    if s then
        local ds, d = pcall(function() return HttpService:JSONDecode(r) end)
        if ds and d and d.data then
            local valid = {}
            for _, server in ipairs(d.data) do
                if type(server) == "table" and server.playing and server.maxPlayers then
                    if server.playing >= 1 and server.playing <= server.maxPlayers - 2 and server.id ~= game.JobId then
                        table.insert(valid, server.id)
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
    SafeSetUI(FarmStatusLabel, "FarmText", "Status: Nenhum servidor encontrado.")
end

CreateButton(TabFarm, "Force Server Hop", function() ForceServerHop() end)

-- [ CONFIG TAB ]
CreateButton(TabConfig, "Save Settings", function()
    SaveConfig()
    local t = Title.Text
    Title.Text = "  Salvo com Sucesso!"
    Title.TextColor3 = Color3.fromRGB(100, 255, 100)
    task.delay(2, function() Title.Text = t Title.TextColor3 = Color3.fromRGB(200, 200, 255) end)
end)

-- [ STATE MACHINE LOGIC ]
local function GetBossInWorkspace()
    local key = HubConfig.SelectedBoss
    local map = BossNameMapping[key] or key
    local roots = { Workspace, Workspace:FindFirstChild("Mobs"), Workspace:FindFirstChild("Entities"), Workspace:FindFirstChild("Bosses"), Workspace:FindFirstChild("LiveBosses") }
    for _, root in ipairs(roots) do
        if root then
            for _, obj in ipairs(root:GetChildren()) do
                if obj:IsA("Model") and obj:FindFirstChild("Humanoid") and obj.Humanoid.MaxHealth > 100 then
                    if not Players:GetPlayerFromCharacter(obj) and obj.Humanoid.Health > 0 then
                        local oName = string.lower(obj.Name)
                        if string.find(oName, string.lower(map)) or string.find(oName, string.lower(key)) then return obj end
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
    for i=1,len do local r = math.random(1, #chars) name = name .. string.sub(chars, r, r) end
    return name
end

RunService:BindToRenderStep("Bifrost_StateMachine", Enum.RenderPriority.Camera.Value, function()
    local currentTick = tick()
    
    if currentTick - AppState.LastTokenTick >= 1.5 then
        AppState.LastTokenTick = currentTick
        local found, tokens = GetTokens()
        if found then SafeSetUI(TokenLabel, "TokenText", "Rename Tokens: " .. tostring(tokens)) end
    end
    
    if HubConfig.AutoFarm and not AppState.IsHopping then
        if currentTick - AppState.StartupTick < 15 then
            SafeSetUI(FarmStatusLabel, "FarmText", "Status: Aguardando mapa (" .. math.floor(15 - (currentTick - AppState.StartupTick)) .. "s)")
        elseif currentTick - AppState.LastFarmTick >= 0.5 then
            AppState.LastFarmTick = currentTick
            
            -- Âncora Absoluta (Funciona com ou sem Boss)
            if HubConfig.AnchorX and HubConfig.AnchorY and HubConfig.AnchorZ then
                local char = Players.LocalPlayer.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                local hum = char and char:FindFirstChild("Humanoid")
                if hrp and hum and hum.Health > 0 then
                    local anchorPos = Vector3.new(HubConfig.AnchorX, HubConfig.AnchorY, HubConfig.AnchorZ)
                    if (hrp.Position - anchorPos).Magnitude > 5 then
                        -- Prevenção de Crash de Física (NaN Velocity)
                        hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                        hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                        char:PivotTo(CFrame.new(anchorPos))
                    end
                end
            end
            
            pcall(function()
                local boss = GetBossInWorkspace()
                if boss then
                    SafeSetUI(FarmStatusLabel, "FarmText", "Status: Atacando " .. boss.Name)
                    local dataRemote = ReplicatedStorage:FindFirstChild("BridgeNet") and ReplicatedStorage.BridgeNet:FindFirstChild("dataRemoteEvent")
                    if dataRemote then dataRemote:FireServer(unpack({ { { "General", "Attack", "Click", {}, n = 4 }, "\002" } })) end
                else
                    if HubConfig.AutoHop then
                        if tick() - AppState.LastHopAttempt > 5 then ForceServerHop() end
                    else
                        SafeSetUI(FarmStatusLabel, "FarmText", "Status: Boss ausente.")
                    end
                end
            end)
        end
    elseif not HubConfig.AutoFarm and not AppState.IsHopping then
        SafeSetUI(FarmStatusLabel, "FarmText", "Status: Parado")
    end
    
    if AppState.AutoRollEnabled and #AppState.SelectedPetUUIDs > 0 then
        if currentTick - AppState.LastRollTick >= 0.8 then
            AppState.LastRollTick = currentTick
            pcall(function()
                local targetUuid = nil
                for i, uuid in ipairs(AppState.SelectedPetUUIDs) do
                    local petData = Omni.Data.Inventory.Units[uuid]
                    if petData then
                        local currentBuffValue = (petData.RenameBuffs and petData.RenameBuffs[HubConfig.SelectedBuff]) or 0
                        if currentBuffValue < HubConfig.TargetValue - 0.001 then
                            targetUuid = uuid
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
                if targetUuid then Omni.Signal:Fire("General", "Units", "Rename", targetUuid, generateRandomName()) end
            end)
        end
    end
end)

TeleportService.TeleportInitFailed:Connect(function(player)
    if player == Players.LocalPlayer then
        task.spawn(function() 
            task.wait(5) 
            AppState.IsHopping = false 
            AppState.LastHopAttempt = 0 -- Zera o cooldown para tentar um novo servidor imediatamente
            if ScreenGui then pcall(function() ScreenGui.Enabled = true end) end
            SafeSetUI(FarmStatusLabel, "FarmText", "Status: Falha no Hop. Tentando de novo...")
        end)
    end
end)
