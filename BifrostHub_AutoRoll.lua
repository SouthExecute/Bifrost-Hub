local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

if not game:IsLoaded() then
    game.Loaded:Wait()
end

-- ==========================================
-- ANTI-CRASH TELEPORT HANDLER
-- ==========================================
-- Captura erros de teleporte (como Erro 279 ou servidor lotado) e impede que o Roblox feche abruptamente.
local connectionFailed
connectionFailed = TeleportService.TeleportInitFailed:Connect(function(player, teleportResult, errorMessage)
    if player == Players.LocalPlayer then
        warn("Teleport Falhou! Tentando cancelar estado de Hop. Motivo: " .. tostring(errorMessage))
        -- Se o teleporte falhar, aguardamos bastante tempo para não criar conflito com o Client
        task.spawn(function()
            task.wait(20)
            if getfenv().isHopping ~= nil then
                getfenv().isHopping = false
            end
        end)
    end
end)

repeat task.wait() until Players.LocalPlayer
repeat task.wait() until Players.LocalPlayer.Character

local Omni = require(ReplicatedStorage:WaitForChild("Omni"))

-- ==========================================
-- SAVE SYSTEM (CONFIGURAÇÕES)
-- ==========================================
local ConfigName = "BifrostHub_Config.json"
local HubConfig = {
    SelectedBuff = "Power",
    TargetValue = 1.00,
    SelectedBoss = "Yuje",
    AutoHop = false,
    AutoFarm = false,
}

local function SaveConfig()
    if writefile then
        local success, err = pcall(function()
            writefile(ConfigName, HttpService:JSONEncode(HubConfig))
        end)
        if success then
            Rayfield:Notify({Title="Config", Content="Configurações salvas com sucesso!", Duration=3})
        else
            Rayfield:Notify({Title="Erro", Content="Falha ao salvar: " .. tostring(err), Duration=3})
        end
    end
end

local function LoadConfig()
    if readfile then
        local success, data = pcall(function()
            return HttpService:JSONDecode(readfile(ConfigName))
        end)
        if success and type(data) == "table" then
            for k, v in pairs(data) do
                HubConfig[k] = v
            end
        end
    end
end

-- Carregar configs antes de criar a UI para preencher os valores padrão
LoadConfig()

local Window = Rayfield:CreateWindow({
    Name = "Bifrost Hub | Modular Omni",
    LoadingTitle = "Bifrost Hub",
    LoadingSubtitle = "Auto-Roll & Boss Farm",
    ConfigurationSaving = {
        Enabled = false,
    },
    Discord = {
        Enabled = false,
    },
    KeySystem = false,
    ToggleUIKeybind = "L",
})

local MainTab = Window:CreateTab("Auto-Roll", 4483362458)
local BossTab = Window:CreateTab("Global Farm", 4483362458)
local ConfigTab = Window:CreateTab("Config", 4483362458)

-- ==========================================
-- AUTO-ROLL TAB
-- ==========================================
local selectedPetUUIDs = {}
local autoRollEnabled = false
local autoRollTask = nil
local OptionsToUUIDs = {}

local function getPets()
    local pets = {}
    table.clear(OptionsToUUIDs)
    
    local success, units = pcall(function() return Omni.Data.Inventory.Units end)
    if not success or not units then return pets end

    for uuid, pet in pairs(units) do
        local displayName = pet.CustomName or pet.Name or "Unknown"
        
        local pVal, dVal, cVal = 0, 0, 0
        if pet.RenameBuffs then
            pVal = pet.RenameBuffs["Power"] or 0
            dVal = pet.RenameBuffs["Damage"] or 0
            cVal = pet.RenameBuffs["Crystals"] or 0
        end
        
        local optionName = string.format("%s - %s - (P=%.2f D=%.2f C=%.2f)", displayName, string.sub(uuid, 1, 6), pVal, dVal, cVal)
        table.insert(pets, optionName)
        OptionsToUUIDs[optionName] = uuid
    end
    return pets
end

local function generateRandomName()
    local length = math.random(5, 15)
    local chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    local name = ""
    for i = 1, length do
        local r = math.random(1, #chars)
        name = name .. string.sub(chars, r, r)
    end
    return name
end

local TokenLabel = MainTab:CreateLabel("Rename Tokens: Procurando...")
task.spawn(function()
    while task.wait(1.5) do
        local tokens = 0
        local found = false
        
        local success, err = pcall(function()
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
        
        if success and found then
            TokenLabel:Set("Rename Tokens: " .. tostring(tokens))
        else
            TokenLabel:Set("Rename Tokens: ??? (Não encontrado automaticamente)")
        end
    end
end)

local PetDropdown = MainTab:CreateDropdown({
    Name = "Select Pets",
    Options = getPets(),
    CurrentOption = {},
    MultipleOptions = true,
    Flag = "PetDropdown",
    Callback = function(Option)
        selectedPetUUIDs = {}
        if type(Option) == "table" then
            for _, optStr in ipairs(Option) do
                local uuid = OptionsToUUIDs[optStr]
                if uuid then
                    table.insert(selectedPetUUIDs, uuid)
                end
            end
        end
    end,
})

MainTab:CreateButton({
    Name = "Refresh Pets",
    Callback = function()
        PetDropdown:Refresh(getPets(), true)
        selectedPetUUIDs = {}
        Rayfield:Notify({Title = "Refreshed", Content = "Pet list has been updated.", Duration = 2})
    end,
})

local function generateOptions(min, max)
    local opts = {}
    for i = math.floor(min * 100), math.floor(max * 100) do
        table.insert(opts, string.format("%.2f", i / 100))
    end
    return opts
end

local buffOptions = {
    Power = generateOptions(1.00, 1.75),
    Damage = generateOptions(0.10, 0.75),
    Crystals = generateOptions(0.10, 0.75)
}

local TargetDropdown

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
                local found = false
                for _, v in ipairs(buffOptions[HubConfig.SelectedBuff]) do
                    if v == defaultVal then found = true break end
                end
                
                if not found then defaultVal = buffOptions[HubConfig.SelectedBuff][1] end
                
                TargetDropdown:Set({defaultVal})
                HubConfig.TargetValue = tonumber(defaultVal)
            end
            SaveConfig()
        end
    end,
})

local initialTarget = string.format("%.2f", HubConfig.TargetValue)

TargetDropdown = MainTab:CreateDropdown({
    Name = "Target Buff Value (Minimum)",
    Options = buffOptions[HubConfig.SelectedBuff] or buffOptions["Power"],
    CurrentOption = initialTarget,
    MultipleOptions = false,
    Flag = "TargetDropdown",
    Callback = function(Option)
        if Option and Option[1] then
            HubConfig.TargetValue = tonumber(Option[1])
            SaveConfig()
        end
    end,
})

local AutoRollToggle
AutoRollToggle = MainTab:CreateToggle({
    Name = "Auto-Roll",
    CurrentValue = false,
    Flag = "AutoRollToggle",
    Callback = function(Value)
        autoRollEnabled = Value
        if autoRollEnabled then
            if #selectedPetUUIDs == 0 then
                Rayfield:Notify({Title="Erro", Content="Nenhum pet selecionado!", Duration=3})
                AutoRollToggle:Set(false)
                return
            end
            
            local activeRolls = {}
            for _, uuid in ipairs(selectedPetUUIDs) do
                table.insert(activeRolls, uuid)
            end
            
            autoRollTask = task.spawn(function()
                while autoRollEnabled do
                    if #activeRolls == 0 then
                        Rayfield:Notify({Title="Concluído", Content="Todos os pets selecionados atingiram a meta!", Duration=5})
                        AutoRollToggle:Set(false)
                        autoRollEnabled = false
                        if PetDropdown then
                            PetDropdown:Refresh(getPets(), true)
                            selectedPetUUIDs = {}
                        end
                        break
                    end
                    
                    for i = #activeRolls, 1, -1 do
                        if not autoRollEnabled then break end
                        
                        local uuid = activeRolls[i]
                        local didRoll = false
                        
                        local success, err = pcall(function()
                            local petData = Omni.Data.Inventory.Units[uuid]
                            if not petData then
                                table.remove(activeRolls, i)
                                return
                            end
                            
                            local currentBuffValue = 0
                            if petData.RenameBuffs and petData.RenameBuffs[HubConfig.SelectedBuff] then
                                currentBuffValue = petData.RenameBuffs[HubConfig.SelectedBuff]
                            end
                            
                            if currentBuffValue >= HubConfig.TargetValue - 0.001 then
                                local petName = petData.CustomName or petData.Name or "Unknown"
                                Rayfield:Notify({
                                    Title = "Sucesso! 🎉",
                                    Content = string.format("%s alcançou %.2f de %s!", petName, currentBuffValue, HubConfig.SelectedBuff),
                                    Duration = 6,
                                })
                                table.remove(activeRolls, i)
                                return
                            end
                            
                            local newName = generateRandomName()
                            Omni.Signal:Fire("General", "Units", "Rename", uuid, newName)
                            didRoll = true
                        end)
                        
                        if not success then
                            warn("Auto-roll error: " .. tostring(err))
                        end
                        
                        if didRoll then
                            task.wait(0.8) -- Segurança: delay para evitar spam/kick
                        end
                    end
                    task.wait(0.1)
                end
            end)
        else
            if autoRollTask then
                task.cancel(autoRollTask)
                autoRollTask = nil
                if PetDropdown then
                    PetDropdown:Refresh(getPets(), true)
                    selectedPetUUIDs = {}
                end
            end
        end
    end,
})

-- ==========================================
-- GLOBAL FARM TAB (BOSSES + SERVER HOP)
-- ==========================================

local autoFarmEnabled = false
local farmTask = nil

local Bosses = {"Yuje", "Satoro", "Sakana"}
-- Mapeamento com os nomes exatos extraídos do Dex e da Screenshot (Meguna, Goujo)
local BossNameMapping = {
    ["Yuje"] = "Yuji", 
    ["Satoro"] = "Goujo", 
    ["Sakana"] = "Meguna"
}

local cachedBoss = nil

local function GetBossInWorkspace()
    local bossKey = HubConfig.SelectedBoss
    local mappedName = BossNameMapping[bossKey] or bossKey
    
    -- Retorna o boss em cache se ele ainda existir, estiver vivo e bater com o nome atual
    if cachedBoss and cachedBoss.Parent and cachedBoss:FindFirstChild("Humanoid") and cachedBoss.Humanoid.Health > 0 then
        local cName = string.lower(cachedBoss.Name)
        if string.find(cName, string.lower(mappedName)) or string.find(cName, string.lower(bossKey)) then
            return cachedBoss
        end
    end
    
    local possibleFolders = {
        Workspace, 
        Workspace:FindFirstChild("Mobs"), 
        Workspace:FindFirstChild("Entities"), 
        Workspace:FindFirstChild("Bosses"),
        Workspace:FindFirstChild("LiveBosses")
    }
    
    -- Busca otimizada com GetChildren nas pastas raízes (Evita Crash de Executor por excesso de peças)
    for _, folder in ipairs(possibleFolders) do
        if folder then
            for _, obj in ipairs(folder:GetChildren()) do
                if obj:IsA("Model") and obj:FindFirstChild("Humanoid") and obj.Humanoid.MaxHealth > 100 then
                    -- Ignora jogadores
                    if not Players:GetPlayerFromCharacter(obj) then
                        local objName = string.lower(obj.Name)
                        if string.find(objName, string.lower(mappedName)) or string.find(objName, string.lower(bossKey)) then
                            cachedBoss = obj
                            return obj
                        end
                    end
                end
            end
        end
    end
    
    return nil
end

getfenv().isHopping = false
local LastHopAttempt = 0

local function ForceServerHop()
    -- Hard Cooldown de 60 segundos absoluto entre tentativas de hop
    -- Isso garante 100% que o executor nunca vai spammar Teleport e crashar o jogo, mesmo se houver falhas.
    if tick() - LastHopAttempt < 60 then return end
    
    if getfenv().isHopping then return end
    getfenv().isHopping = true
    LastHopAttempt = tick()
    
    Rayfield:Notify({Title="Server Hop", Content="Procurando novo servidor público...", Duration=5})
    
    local placeId = game.PlaceId
    local url = string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Desc&limit=100", placeId)
    
    local success, result = pcall(function()
        return game:HttpGet(url)
    end)
    
    if success then
        local decodeSuccess, data = pcall(function()
            return HttpService:JSONDecode(result)
        end)
        
        if decodeSuccess and data and data.data then
            local validServers = {}
            for _, server in ipairs(data.data) do
                if type(server) == "table" and server.playing and server.maxPlayers then
                    -- Filtra: Evita "Ghost Servers" (menos de 5 players) e evita Servidores Lotados por causa de Cache de API (margem de 5 vagas)
                    local pingOk = (server.ping ~= nil and server.ping < 300) or true
                    if server.playing >= 5 and server.playing <= server.maxPlayers - 5 and server.id ~= game.JobId and pingOk then
                        table.insert(validServers, server.id)
                    end
                end
            end
            
            if #validServers > 0 then
                local randomServerId = validServers[math.random(1, #validServers)]
                pcall(function()
                    TeleportService:TeleportToPlaceInstance(placeId, randomServerId, Players.LocalPlayer)
                end)
                
                -- Se o teleport foi acionado, não podemos destravar o isHopping rapidamente.
                -- Se o jogador cair numa fila de "Server Full", ele pode ficar lá por minutos.
                -- Tentar teleportar de novo com a fila aberta causa CRASH instantâneo.
                task.wait(60) 
                getfenv().isHopping = false
                return
            end
        end
    end
    
    getfenv().isHopping = false
    Rayfield:Notify({Title="Server Hop", Content="Nenhum servidor adequado encontrado.", Duration=3})
end

BossTab:CreateDropdown({
    Name = "Select Global Boss",
    Options = Bosses,
    CurrentOption = HubConfig.SelectedBoss,
    MultipleOptions = false,
    Flag = "BossDropdown",
    Callback = function(Option)
        if Option and Option[1] then
            HubConfig.SelectedBoss = Option[1]
            SaveConfig()
        end
    end,
})

BossTab:CreateToggle({
    Name = "Auto Server-Hop (If Boss Dead/Not Found)",
    CurrentValue = HubConfig.AutoHop,
    Flag = "AutoHopToggle",
    Callback = function(Value)
        HubConfig.AutoHop = Value
        SaveConfig()
    end,
})

local FarmStatusLabel = BossTab:CreateLabel("Status: Aguardando...")

local FarmBossToggle

local function HandleFarmToggle(Value)
    autoFarmEnabled = Value
    HubConfig.AutoFarm = Value
    SaveConfig()
    
    if autoFarmEnabled then
        if farmTask then
            task.cancel(farmTask)
        end
        
        FarmStatusLabel:Set("Status: Iniciando rotina...")
        
        farmTask = task.spawn(function()
            -- Espera inicial LONGA para garantir que o mapa carregue.
            -- Teleportar rápido demais logo ao entrar no jogo causa Crash no Client do Roblox!
            task.wait(15) 
            
            while autoFarmEnabled do
                local success, err = pcall(function()
                    local boss = GetBossInWorkspace()
                    local humanoid = boss and boss:FindFirstChildOfClass("Humanoid")
                    
                    if boss and humanoid and humanoid.Health > 0 then
                        -- Boss encontrado e vivo
                        FarmStatusLabel:Set("Status: Atacando " .. boss.Name .. " (" .. math.floor(humanoid.Health) .. " HP)")
                        pcall(function()
                            local dataRemote = ReplicatedStorage:FindFirstChild("BridgeNet") and ReplicatedStorage.BridgeNet:FindFirstChild("dataRemoteEvent")
                            if dataRemote then
                                local args = { { { "General", "Attack", "Click", {}, n = 4 }, "\002" } }
                                dataRemote:FireServer(unpack(args))
                            end
                        end)
                        task.wait(0.2) -- Otimizado: sem lag
                    else
                        -- Boss não encontrado ou morto
                        if HubConfig.AutoHop then
                            FarmStatusLabel:Set("Status: Boss ausente. Iniciando Server Hop...")
                            ForceServerHop()
                            task.wait(10) -- Aguarda o tempo de teleporte
                        else
                            FarmStatusLabel:Set("Status: Boss ausente. Aguardando spawn...")
                            task.wait(1) -- Delay seguro
                        end
                    end
                end)
                
                if not success then
                    warn("Erro no FarmLoop: ", tostring(err))
                    task.wait(1)
                end
            end
        end)
    else
        if farmTask then
            task.cancel(farmTask)
            farmTask = nil
        end
        FarmStatusLabel:Set("Status: Farm Parado.")
    end
end

FarmBossToggle = BossTab:CreateToggle({
    Name = "Auto-Farm Boss",
    CurrentValue = HubConfig.AutoFarm,
    Flag = "FarmBossToggle",
    Callback = HandleFarmToggle,
})

BossTab:CreateButton({
    Name = "Force Server Hop",
    Callback = function()
        ForceServerHop()
    end,
})

-- ==========================================
-- CONFIG TAB
-- ==========================================

ConfigTab:CreateButton({
    Name = "Save Settings",
    Callback = function()
        SaveConfig()
    end,
})

ConfigTab:CreateButton({
    Name = "Reset Settings",
    Callback = function()
        HubConfig = {
            SelectedBuff = "Power",
            TargetValue = 1.00,
            SelectedBoss = "Yuje",
            AutoHop = false,
            AutoFarm = false,
        }
        SaveConfig()
        Rayfield:Notify({Title="Config", Content="Configurações resetadas com sucesso!", Duration=3})
        Rayfield:Notify({Title="Aviso", Content="Re-execute o script para aplicar o reset completo.", Duration=4})
    end,
})

-- ==========================================
-- AUTO-EXECUTION HANDLER (BugFix Rayfield)
-- ==========================================
-- Força a execução do farm caso o AutoFarm esteja ativado no load
if HubConfig.AutoFarm then
    task.spawn(function()
        -- Aguardar firmemente a UI do jogo terminar de carregar (previne o Crash do "Menu Principal")
        local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui", 30)
        task.wait(2) -- Tempo extra de carência para os scripts do jogo iniciarem
        
        if HubConfig.AutoFarm then
            HandleFarmToggle(true)
        end
    end)
end
