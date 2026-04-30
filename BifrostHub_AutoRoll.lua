local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

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
    LastTokenTick = 0
}

local BossNameMapping = {
    ["Yuje"] = "Yuji", 
    ["Satoro"] = "Goujo", 
    ["Sakana"] = "Meguna"
}
local Bosses = {"Yuje", "Satoro", "Sakana"}
local OptionsToUUIDs = {}

-- UI Elements
local Window, MainTab, BossTab, ConfigTab
local TokenLabel, FarmStatusLabel, PetDropdown, TargetDropdown

-- ==========================================
-- CORE FUNCTIONS
-- ==========================================
local function SaveConfig()
    if writefile then
        pcall(function() writefile(ConfigName, HttpService:JSONEncode(HubConfig)) end)
    end
end

local function LoadConfig()
    if readfile then
        local s, d = pcall(function() return HttpService:JSONDecode(readfile(ConfigName)) end)
        if s and type(d) == "table" then
            for k, v in pairs(d) do HubConfig[k] = v end
        end
    end
end

local function SafeSetUI(label, stateKey, newText)
    if AppState[stateKey] ~= newText then
        AppState[stateKey] = newText
        if label then pcall(function() label:Set(newText) end) end
    end
end

-- Limpeza total de memória para evitar Crash do Executor no Hop
local function TeardownAndHop(placeId, serverId)
    AppState.LastHopAttempt = tick()
    AppState.IsHopping = true
    
    -- Destrói a Interface Gráfica e libera a RAM ocupada por Tweens e Sinais da Rayfield
    if Rayfield then
        pcall(function() Rayfield:Destroy() end)
    end
    
    -- Desconecta o loop principal (State Machine)
    RunService:UnbindFromRenderStep("Bifrost_StateMachine")
    
    task.wait(1)
    
    pcall(function()
        task.spawn(function()
            TeleportService:TeleportToPlaceInstance(placeId, serverId, Players.LocalPlayer)
        end)
    end)
    
    task.wait(60)
    AppState.IsHopping = false -- Apenas destrava se o TeleportService falhar silenciosamente
end

local function ForceServerHop()
    if tick() - AppState.LastHopAttempt < 60 then return end
    if AppState.IsHopping then return end
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
                    local pingOk = (server.ping ~= nil and server.ping < 300) or true
                    if server.playing >= 1 and server.playing <= server.maxPlayers - 2 and server.id ~= game.JobId and pingOk then
                        table.insert(valid, server.id)
                    end
                end
            end
            if #valid > 0 then
                local randomServerId = valid[math.random(1, #valid)]
                TeardownAndHop(placeId, randomServerId)
                return
            end
        end
    end
    
    AppState.IsHopping = false
    SafeSetUI(FarmStatusLabel, "FarmText", "Status: Nenhum servidor encontrado. Aguardando...")
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
                        local oName = string.lower(obj.Name)
                        if string.find(oName, string.lower(map)) or string.find(oName, string.lower(key)) then
                            return obj
                        end
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
        if not found then
            local consumables = Omni.Data.Inventory.Consumables
            if consumables then
                for k, v in pairs(consumables) do
                    if type(k) == "string" and string.find(string.lower(k), "rename token") then
                        found = true
                        tokens = tokens + (type(v) == "table" and (v.Amount or v.Count or v.Quantity or 1) or (type(v) == "number" and v or 1))
                    end
                end
            end
        end
    end)
    return found, tokens
end

local function getPets()
    local pets = {}
    table.clear(OptionsToUUIDs)
    local s, units = pcall(function() return Omni.Data.Inventory.Units end)
    if not s or not units then return pets end
    for uuid, pet in pairs(units) do
        local dName = pet.CustomName or pet.Name or "Unknown"
        local p, d, c = 0, 0, 0
        if pet.RenameBuffs then p = pet.RenameBuffs["Power"] or 0 d = pet.RenameBuffs["Damage"] or 0 c = pet.RenameBuffs["Crystals"] or 0 end
        local opt = string.format("%s - %s - (P=%.2f D=%.2f C=%.2f)", dName, string.sub(uuid, 1, 6), p, d, c)
        table.insert(pets, opt)
        OptionsToUUIDs[opt] = uuid
    end
    return pets
end

local function generateRandomName()
    local len = math.random(5, 15)
    local chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    local name = ""
    for i=1,len do local r = math.random(1, #chars) name = name .. string.sub(chars, r, r) end
    return name
end

-- ==========================================
-- UI INITIALIZATION
-- ==========================================
LoadConfig()
Window = Rayfield:CreateWindow({
    Name = "Bifrost Hub | Modular Omni",
    LoadingTitle = "Bifrost Hub",
    LoadingSubtitle = "Auto-Roll & Boss Farm",
    ConfigurationSaving = { Enabled = false },
    KeySystem = false,
    ToggleUIKeybind = "L"
})

MainTab = Window:CreateTab("Auto-Roll", 4483362458)
BossTab = Window:CreateTab("Global Farm", 4483362458)
ConfigTab = Window:CreateTab("Config", 4483362458)

TokenLabel = MainTab:CreateLabel("Rename Tokens: Procurando...")

PetDropdown = MainTab:CreateDropdown({
    Name = "Select Pets",
    Options = getPets(),
    CurrentOption = {},
    MultipleOptions = true,
    Flag = "PetDropdown",
    Callback = function(Option)
        AppState.SelectedPetUUIDs = {}
        if type(Option) == "table" then
            for _, optStr in ipairs(Option) do
                local uuid = OptionsToUUIDs[optStr]
                if uuid then table.insert(AppState.SelectedPetUUIDs, uuid) end
            end
        end
    end,
})

MainTab:CreateButton({
    Name = "Refresh Pets",
    Callback = function()
        PetDropdown:Refresh(getPets(), true)
        AppState.SelectedPetUUIDs = {}
        Rayfield:Notify({Title = "Refreshed", Content = "Pet list updated.", Duration = 2})
    end,
})

local function generateOptions(min, max)
    local opts = {}
    for i = math.floor(min*100), math.floor(max*100) do table.insert(opts, string.format("%.2f", i/100)) end
    return opts
end
local buffOptions = { Power = generateOptions(1.00, 1.75), Damage = generateOptions(0.10, 0.75), Crystals = generateOptions(0.10, 0.75) }

MainTab:CreateDropdown({
    Name = "Select Buff",
    Options = {"Power", "Damage", "Crystals"},
    CurrentOption = HubConfig.SelectedBuff,
    MultipleOptions = false,
    Flag = "BuffDropdown",
    Callback = function(Option)
        if Option and Option[1] then
            HubConfig.SelectedBuff = Option[1]
            if TargetDropdown then
                TargetDropdown:Refresh(buffOptions[HubConfig.SelectedBuff])
                local defaultVal = string.format("%.2f", HubConfig.TargetValue)
                TargetDropdown:Set({defaultVal})
            end
            SaveConfig()
        end
    end,
})

TargetDropdown = MainTab:CreateDropdown({
    Name = "Target Buff Value (Minimum)",
    Options = buffOptions[HubConfig.SelectedBuff] or buffOptions["Power"],
    CurrentOption = string.format("%.2f", HubConfig.TargetValue),
    MultipleOptions = false,
    Flag = "TargetDropdown",
    Callback = function(Option)
        if Option and Option[1] then HubConfig.TargetValue = tonumber(Option[1]); SaveConfig() end
    end,
})

local AutoRollToggle
AutoRollToggle = MainTab:CreateToggle({
    Name = "Auto-Roll",
    CurrentValue = false,
    Flag = "AutoRollToggle",
    Callback = function(Value)
        if Value and #AppState.SelectedPetUUIDs == 0 then
            Rayfield:Notify({Title="Erro", Content="Selecione pets primeiro!", Duration=3})
            AutoRollToggle:Set(false)
            return
        end
        AppState.AutoRollEnabled = Value
    end,
})

BossTab:CreateDropdown({
    Name = "Select Global Boss",
    Options = Bosses,
    CurrentOption = HubConfig.SelectedBoss,
    MultipleOptions = false,
    Flag = "BossDropdown",
    Callback = function(Option)
        if Option and Option[1] then HubConfig.SelectedBoss = Option[1]; SaveConfig() end
    end,
})

BossTab:CreateToggle({
    Name = "Auto Server-Hop (If Boss Dead)",
    CurrentValue = HubConfig.AutoHop,
    Flag = "AutoHopToggle",
    Callback = function(Value) HubConfig.AutoHop = Value; SaveConfig() end,
})

FarmStatusLabel = BossTab:CreateLabel("Status: Aguardando...")

BossTab:CreateToggle({
    Name = "Auto-Farm Boss",
    CurrentValue = HubConfig.AutoFarm,
    Flag = "FarmBossToggle",
    Callback = function(Value) HubConfig.AutoFarm = Value; SaveConfig() end,
})

BossTab:CreateButton({
    Name = "Force Server Hop",
    Callback = function() ForceServerHop() end,
})

ConfigTab:CreateButton({ Name = "Save Settings", Callback = function() SaveConfig() end })
ConfigTab:CreateButton({
    Name = "Reset Settings",
    Callback = function()
        HubConfig = { SelectedBuff = "Power", TargetValue = 1.00, SelectedBoss = "Yuje", AutoHop = false, AutoFarm = false }
        SaveConfig()
        Rayfield:Notify({Title="Config", Content="Configurações resetadas!", Duration=3})
    end,
})

-- ==========================================
-- STATE MACHINE (HEARTBEAT LOOP)
-- ==========================================
-- Uma única thread gerencia tudo. Sem vazamento de memória.
RunService:BindToRenderStep("Bifrost_StateMachine", Enum.RenderPriority.Camera.Value, function()
    local currentTick = tick()
    
    -- 1. Atualizador de UI de Tokens (A cada 1.5s)
    if currentTick - AppState.LastTokenTick >= 1.5 then
        AppState.LastTokenTick = currentTick
        local found, tokens = GetTokens()
        if found then
            SafeSetUI(TokenLabel, "TokenText", "Rename Tokens: " .. tostring(tokens))
        else
            SafeSetUI(TokenLabel, "TokenText", "Rename Tokens: ???")
        end
    end
    
    -- 2. Lógica de Auto-Farm & Server Hop (A cada 0.5s)
    if HubConfig.AutoFarm and not AppState.IsHopping then
        if currentTick - AppState.LastFarmTick >= 0.5 then
            AppState.LastFarmTick = currentTick
            
            pcall(function()
                local boss = GetBossInWorkspace()
                if boss then
                    SafeSetUI(FarmStatusLabel, "FarmText", "Status: Atacando " .. boss.Name .. " (" .. math.floor(boss.Humanoid.Health) .. " HP)")
                    local dataRemote = ReplicatedStorage:FindFirstChild("BridgeNet") and ReplicatedStorage.BridgeNet:FindFirstChild("dataRemoteEvent")
                    if dataRemote then
                        dataRemote:FireServer(unpack({ { { "General", "Attack", "Click", {}, n = 4 }, "\002" } }))
                    end
                else
                    if HubConfig.AutoHop then
                        -- Apenas tenta o Hop se passou o delay seguro pra não encavalar requests
                        if tick() - AppState.LastHopAttempt > 5 then
                            ForceServerHop()
                        end
                    else
                        SafeSetUI(FarmStatusLabel, "FarmText", "Status: Boss ausente. Aguardando spawn...")
                    end
                end
            end)
        end
    elseif not HubConfig.AutoFarm and AppState.FarmText ~= "Status: Parado" and not AppState.IsHopping then
        SafeSetUI(FarmStatusLabel, "FarmText", "Status: Parado")
    end
    
    -- 3. Lógica de Auto-Roll (A cada 0.8s)
    if AppState.AutoRollEnabled and #AppState.SelectedPetUUIDs > 0 then
        if currentTick - AppState.LastRollTick >= 0.8 then
            AppState.LastRollTick = currentTick
            pcall(function()
                -- Encontra o primeiro pet que ainda precisa rolar
                local targetUuid = nil
                local targetIndex = nil
                
                for i, uuid in ipairs(AppState.SelectedPetUUIDs) do
                    local petData = Omni.Data.Inventory.Units[uuid]
                    if petData then
                        local currentBuffValue = 0
                        if petData.RenameBuffs and petData.RenameBuffs[HubConfig.SelectedBuff] then
                            currentBuffValue = petData.RenameBuffs[HubConfig.SelectedBuff]
                        end
                        if currentBuffValue < HubConfig.TargetValue - 0.001 then
                            targetUuid = uuid
                            targetIndex = i
                            break
                        else
                            Rayfield:Notify({Title = "Sucesso!", Content = petData.Name .. " atingiu a meta!", Duration = 5})
                            table.remove(AppState.SelectedPetUUIDs, i)
                            return -- Dá break no loop e pula pro próximo tick
                        end
                    else
                        table.remove(AppState.SelectedPetUUIDs, i)
                    end
                end
                
                if targetUuid then
                    local newName = generateRandomName()
                    Omni.Signal:Fire("General", "Units", "Rename", targetUuid, newName)
                end
            end)
        end
    end
end)

-- Handle Teleport Failure
TeleportService.TeleportInitFailed:Connect(function(player)
    if player == Players.LocalPlayer then
        task.spawn(function()
            task.wait(10)
            AppState.IsHopping = false
        end)
    end
end)
