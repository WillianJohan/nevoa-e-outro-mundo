# Monstros

| Campo | Valor |
|-------|-------|
| Status | `accepted` |
| Sprints | 0002 (Eco), 0004 (Estalador, Corredor), 0005 (Sem-rosto) |

## Regra geral

Monstro = zumbi com outfit/textura própria e comportamento via Lua. Sem modelo
3D novo, sem animação nova.

Estalador, Corredor e Sem-rosto são **zumbis existentes marcados**
([ADR-001](../architecture/adr-001-variantes-por-moddata.md)). O Eco é a única
exceção: ele é **spawnado** ([ADR-003](../architecture/adr-003-eco-spawnado.md)).

Cada zumbi é sorteado **uma vez por período**, na primeira vez que o loop de
comportamento o processa. Assim zumbis de chunks carregados depois também entram.

## Estalador

| Quando | Origem | Sandbox |
|---|---|---|
| noite | marcado | `EstaladorChance` % |

- Cego: ignora visão, reage só a som. Agachado e em silêncio, o jogador passa.
- Agarrão letal rápido.
- Estalo periódico audível, que serve de aviso.
- Ao amanhecer, volta a ser zumbi comum.

## Corredor noturno

| Quando | Origem | Sandbox |
|---|---|---|
| noite | marcado | `CorredorChance` %, `CorredorScreamRadius` |

- De dia é zumbi comum; à noite é sprinter.
- Ao ver o jogador, grita e atrai os zumbis num raio. É ele que começa a horda.
- Ao amanhecer, volta a ser zumbi comum.

## Sem-rosto

| Quando | Origem | Sandbox |
|---|---|---|
| névoa | marcado | `SemRostoChance` % |

- Só existe com névoa forte.
- Quando entra no campo de visão do jogador ou é iluminado, some e reaparece mais
  perto, fora da visão.
- O rádio chia "na cabeça" do jogador, mais forte quanto mais perto (não exige
  rádio no inventário).
- Quando a névoa baixa, volta a ser zumbi comum: aquele zumbi qualquer *era* a coisa.

## Eco

| Quando | Origem | Sandbox |
|---|---|---|
| noite | spawnado de corpo | `EcoMaxPerPlayer` (30), `EcoRadius` (40) |

A alma de um morto. Fraco sozinho; perigoso onde há muitos corpos.

- Durante a noite, todo `IsoDeadBody` a até `EcoRadius` tiles de um jogador gera
  um Eco, respeitando o teto por jogador. A checagem é periódica, não só no
  início da noite: quem anda até um cemitério às 2h também é pego.
- **Cada corpo gera Eco uma única vez na vida.** O cadáver continua no chão.
- **Corpo queimado ou enterrado não gera Eco**, porque deixa de existir como
  `IsoDeadBody`. Nenhuma regra extra.
- Vida baixa, lento, dano baixo. Textura fantasmagórica própria.
- Ao morrer: **sem cadáver e sem loot**.
- Ao amanhecer: **todos os Ecos somem**, onde quer que estejam.

Sem cadáver: o corpo do Eco é removido pelo servidor logo depois que nasce
(técnica na [ADR-003](../architecture/adr-003-eco-spawnado.md)). Validação em MP
no roteiro da [sprint 0002](../sprints/sprint-0002-eco/README.md#roteiro-in-game).

Visual atual (placeholder): camisola de hospital e véu de noiva vanilla, outfit
`NOM_Eco`. Por enquanto só a vida é baixa; lento e dano baixo chegam com a
sprint 0003.

## Sobreposição

Noite + névoa ao mesmo tempo: valem todas as regras juntas.
