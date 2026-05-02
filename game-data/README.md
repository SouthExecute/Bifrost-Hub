# Game Data - Guia de Coleta

Esta pasta serve para armazenar dados coletados do jogo usando ferramentas como Remote Spy, Dex Explorer, e similares.

## Estrutura

```
game-data/
|-- remotes/      -> Capturas do Remote Spy (FireServer, InvokeServer)
|-- services/     -> Dumps de services do jogo (ReplicatedStorage, etc)
|-- modules/      -> Dumps de modulos do framework Omni
|-- inventory/    -> Estruturas de inventario, pets, items
```

## O que coletar

### remotes/
Salve aqui os logs do Remote Spy. Foco em:
- **Attack remotes** (como o BridgeNet/dataRemoteEvent funciona)
- **Rename remotes** (como o sistema de rename de pets funciona)
- **Teleport remotes** (se existirem atalhos de teleport)
- **Shop/Gacha remotes** (para futuras features)

Formato sugerido: `remote_nome_acao.txt`

### services/
Salve dumps da arvore de services:
- `ReplicatedStorage` children tree
- `Workspace` mob/boss structure
- `Players.LocalPlayer` data structure

Formato sugerido: `service_nome.txt`

### modules/
Salve dumps de modulos do framework Omni:
- `Omni.Data` structure completa
- `Omni.Signal` methods disponiveis
- `Omni.Data.Inventory` schema
- Qualquer modulo util encontrado

Formato sugerido: `omni_modulo.lua` ou `.txt`

### inventory/
Salve exemplos de estruturas de dados:
- Pet data (`Omni.Data.Inventory.Units`)
- Item data (`Omni.Data.Inventory.Items`)
- Buff structures (`RenameBuffs`)
- Boss data structures

Formato sugerido: `inventory_tipo.json` ou `.txt`

## Como coletar

1. **Remote Spy**: Execute no jogo, filtre por "BridgeNet" ou "dataRemoteEvent"
2. **Dex Explorer**: Navegue services e copie a estrutura
3. **Console**: Use `print(game:GetService("HttpService"):JSONEncode(data))` para exportar tabelas
