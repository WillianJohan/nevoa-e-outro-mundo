# Sandbox options

| Campo | Valor |
|-------|-------|
| Status | `accepted` |

Página própria no sandbox ("Névoa e Outro Mundo"). Default entre parênteses
quando já decidido. Cada sprint adiciona as opções dos sistemas que entrega.

## Toggles

- Clima dark
- Noite: mais rápidos (`NightFaster`) · sentidos aguçados (`NightSharperSenses`) · caça ativa (`NightHunt`), todos padrão ligado
- Monstros: Estalador · Corredor · Sem-rosto · Eco (`EcoEnabled`, padrão ligado)
- Overlays de névoa

## Números

| Opção | Sistema |
|---|---|
| `FogThreshold` (0.5, faixa 0.1–1) | [world-states.md](world-states.md) |
| `DarkIntensity` (1.0, faixa 0–2) | [atmosphere.md](atmosphere.md) |
| `NightSpeedMult` (1.5, faixa 1–3, em degraus: 1.5 sobe um, 2.5 sobe dois) | [night.md](night.md) |
| `NightSenseMult` (1.5, faixa 1–3, mesmos degraus; lanterna = 20 × valor tiles) | [night.md](night.md) |
| `HuntIntervalMinutes` (60, faixa 10–720 minutos de jogo), `HuntRadius` (30 tiles, faixa 5–100) | [night.md](night.md) |
| ~~`NightDamageMult`~~ — fora: o jogo não tem dano por zumbi ([night.md](night.md#limites-conhecidos)) | — |
| `EstaladorChance`, `CorredorChance`, `SemRostoChance` | [monsters.md](monsters.md) |
| `CorredorScreamRadius` | [monsters.md](monsters.md) |
| `EcoMaxPerPlayer` (30, faixa 0–200), `EcoRadius` (40 tiles, faixa 5–60) | [monsters.md](monsters.md#eco) |
