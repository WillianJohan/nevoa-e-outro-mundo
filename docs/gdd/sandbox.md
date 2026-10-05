# Sandbox options

| Campo | Valor |
|-------|-------|
| Status | `accepted` |

Página própria no sandbox ("Névoa e Outro Mundo"). Default entre parênteses
quando já decidido. Cada sprint adiciona as opções dos sistemas que entrega.

## Toggles

- Clima dark
- Noite: mais rápidos (`NightFaster`) · sentidos aguçados (`NightSharperSenses`) · caça ativa (`NightHunt`), todos padrão ligado
- Monstros: Estalador (`EstaladorEnabled`) · Corredor (`CorredorEnabled`) · Sem-rosto (`SemRostoEnabled`) · Eco (`EcoEnabled`), todos padrão ligado
- Névoa: som ambiente (`FogAmbience`) · sangue e ferrugem no chão (`FogOverlays`) · vinheta (`FogVignette`), todos padrão ligado

## Números

| Opção | Sistema |
|---|---|
| `FogThreshold` (0.5, faixa 0.1–1) | [world-states.md](world-states.md) |
| `DarkIntensity` (1.0, faixa 0–2) | [atmosphere.md](atmosphere.md) |
| `NightSpeedMult` (1.5, faixa 1–3, em degraus: 1.5 sobe um, 2.5 sobe dois) | [night.md](night.md) |
| `NightSenseMult` (1.5, faixa 1–3, mesmos degraus; lanterna = 20 × valor tiles, a cada 5 minutos) | [night.md](night.md) |
| `HuntIntervalMinutes` (60, faixa 10–720 minutos de jogo), `HuntRadius` (30 tiles, faixa 5–100) | [night.md](night.md) |
| Sem multiplicador de dano: decisão do autor ([night.md](night.md#sem-força-e-sem-dano-à-noite)) | — |
| `EstaladorChance` (5 %, faixa 0–100), `CorredorChance` (10 %, faixa 0–100; somadas acima de 100, o Corredor fica com o resto) | [monsters.md](monsters.md#estalador) |
| `CorredorScreamRadius` (40 tiles, faixa 5–100) | [monsters.md](monsters.md#corredor-noturno) |
| `SemRostoChance` (5 %, faixa 0–100) | [monsters.md](monsters.md#sem-rosto) |
| `FogVignetteIntensity` (1.0, faixa 0–2; 0 desliga) | [atmosphere.md](atmosphere.md#vinheta-só-na-névoa) |
| `EcoMaxPerPlayer` (30, faixa 0–200), `EcoRadius` (40 tiles, faixa 5–60) | [monsters.md](monsters.md#eco) |
