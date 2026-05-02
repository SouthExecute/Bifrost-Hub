# Mapa do Codigo - BifrostHub_AutoRoll.lua

O script e monolitico (arquivo unico) por necessidade do executor. Internamente esta organizado em blocos claros.

## Secoes do Arquivo

| Linhas (aprox) | Secao | Responsabilidade |
|---|---|---|
| 1-8 | SERVICES | game:GetService() centralizados |
| 10-11 | INIT | game:IsLoaded, require Omni |
| 13-41 | STATE & CONFIG | HubConfig, AppState, SaveConfig, LoadConfig |
| 43-64 | THEME | Paleta de cores (tabela T) |
| 66-77 | CLEANUP | Destroi UI antiga antes de recriar |
| 79-211 | UI ENGINE | ScreenGui, MainFrame, Sidebar, ContentArea, FloatingIcon, botoes minimize/close |
| 213-255 | TAB SYSTEM | CreateTab() - sistema generico de tabs |
| 257-335 | HELPERS | Label(), Btn(), Toggle(), SafeSetUI() |
| 337-365 | UI STATE | MinimizeUI, RestoreUI, ToggleUI, DestroyUI + wire-up |
| 367-496 | TAB BINDINGS | Conteudo de cada tab (Auto-Roll, Farm, Settings) |
| 498-637 | GAME LOGIC | TeardownAndHop, ForceServerHop, GetBoss, GetTokens, generateRandomName |
| 639-754 | STATE MACHINE | BindToRenderStep - loop principal |
| 756-768 | TELEPORT RECOVERY | TeleportInitFailed handler |

## Como Adicionar uma Nova Tab

```lua
-- 1. Crie a tab (na secao LOAD & TABS)
local TabTeleport = CreateTab("Teleport", ">")

-- 2. Adicione elementos na tab
Btn(TabTeleport, "Ir para Boss", function()
    -- logica aqui
end)

Toggle(TabTeleport, "Auto-Teleport", false, function(val)
    HubConfig.AutoTeleport = val
    SaveConfig()
end)

-- 3. Adicione ao HubConfig se precisar persistir
-- Na tabela HubConfig inicial, adicione:
-- AutoTeleport = false,
```

## Como Adicionar Nova Logica de Farm

Adicione dentro do `BindToRenderStep` callback, na secao STATE MACHINE:

```lua
-- Dentro do callback do BindToRenderStep:
if HubConfig.AlgumaNovaFeature then
    if ct - AppState.LastNovaFeatureTick >= 1.0 then
        AppState.LastNovaFeatureTick = ct
        -- logica aqui
    end
end
```

## Regras de Performance

1. **NUNCA** usar TweenService
2. **NUNCA** criar loops `while true do` para UI
3. **NUNCA** recriar UI elements dentro de loops
4. **NUNCA** usar `Workspace:GetDescendants()` (crasha o client)
5. **SEMPRE** usar pcall em chamadas de rede
6. **SEMPRE** rastrear conexoes no array `Connections`
7. **SEMPRE** usar `SafeSetUI()` para atualizar texto

## Dados do Jogo

Coloque dumps na pasta `game-data/`. Esses dados ajudam a:
- Descobrir novos remotes para features
- Entender estruturas de inventario
- Mapear bosses e mobs
- Encontrar modulos uteis do Omni
