# Bifrost Hub

Hub de automacao para o framework Omni (Roblox). UI vanilla, zero dependencias, otimizado para AFK farming noturno.

## Executar

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/SouthExecute/Bifrost-Hub/main/BifrostHub_AutoRoll.lua?t=" .. tostring(tick())))()
```

## Funcionalidades

| Feature | Descricao |
|---|---|
| Auto-Roll | Renomeia pets automaticamente ate atingir buff desejado (Power/Damage/Crystals) |
| Auto-Farm | Ataca o boss selecionado automaticamente com sistema de anchor |
| Auto Server-Hop | Troca de servidor quando boss nao esta presente |
| Position Anchor | Trava posicao para nao ser empurrado durante AFK |
| Minimize/Restore | Minimiza UI para icone flutuante arrastavel |
| Hotkey | Toggle da UI com tecla configuravel (padrao: RightShift) |
| Delete UI | Destroi UI com confirmacao de duplo clique |

## Estrutura do Projeto

```
Bifrost-Hub/
|-- BifrostHub_AutoRoll.lua    Script principal (loadstring compativel)
|-- game-data/                 Dados coletados do jogo (spy/dex)
|   |-- remotes/               Remote Spy captures
|   |-- services/              Service tree dumps
|   |-- modules/               Omni framework dumps
|   +-- inventory/             Pet/item data structures
|-- docs/
|   +-- structure.md           Mapa detalhado do codigo
+-- README.md                  Este arquivo
```

## Adicionar Novas Features

1. Abra `BifrostHub_AutoRoll.lua`
2. Crie uma nova tab: `local TabNova = CreateTab("Nome", ">")`
3. Adicione UI elements usando `Btn()`, `Toggle()`, `Label()`
4. Adicione game logic na secao STATE MACHINE
5. Push para GitHub

## Notas Tecnicas

- **UI Vanilla**: Zero libs externas, zero TweenService, zero memory leaks
- **Single File**: Executors nao suportam require() remoto, tudo fica num arquivo
- **State Machine**: Um unico BindToRenderStep controla toda a logica
- **Auto Hop Safe**: UI se esconde durante hop, conexoes sao rastreadas para cleanup
