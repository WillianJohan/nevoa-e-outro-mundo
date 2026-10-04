# ADR-003 — Eco é spawnado

| Campo | Valor |
|-------|-------|
| Status | `accepted` |
| Data | 2026-10-04 |

## Contexto

O Eco é a alma de um morto: nasce de um corpo, não de um zumbi vivo. A regra do
[ADR-001](adr-001-variantes-por-moddata.md) (marcar zumbi existente) não se aplica.

## Decisão

O Eco é **spawnado** perto de um `IsoDeadBody` durante a noite. O corpo recebe
`modData.NOM_ecoReleased = true` e nunca gera outro Eco. O Eco morre sem
cadáver e sem loot, e todos são removidos ao amanhecer.

## Alternativas recusadas

| Alternativa | Por que não |
|---|---|
| Corpo some ao virar Eco | Decisão do autor: o corpo fica, e queimar/enterrar é o que previne. |
| Um Eco por corpo por noite | Decisão do autor: uma vez na vida. |

## Consequências

- Corpo queimado ou enterrado não existe mais como `IsoDeadBody` → não gera Eco,
  sem regra extra.
- "Morrer sem cadáver" não é nativo e precisa de spike na sprint 0002 (ver
  [monsters.md](../gdd/monsters.md#eco)).
- Teto por jogador (`EcoMaxPerPlayer`) é obrigatório: vala comum sem teto trava
  o servidor.
