# ADR-007 — Sem-rosto: quem vê avisa, o dono move; atmosfera só local

| Campo | Valor |
|-------|-------|
| Status | `accepted` |
| Data | 2026-10-04 |
| Emenda | [ADR-002](adr-002-autoridade-servidor.md) e [ADR-005](adr-005-quem-simula-aplica.md) (Sem-rosto e efeitos da névoa) |

## Contexto

O Sem-rosto some quando é visto ou iluminado e reaparece mais perto, fora da
vista ([monsters.md](../gdd/monsters.md#sem-rosto)). Três fatos do B42.20
(bytecode, [pz-api-notes §3.4](pz-api-notes.md#34-sem-rosto-some-quando-visto-ou-iluminado)):

- **Ver é do cliente.** A luz e a linha de visão por jogador são calculadas no
  cliente (`LightingJNI`); o servidor dedicado não tem `isCanSee(pn)`.
- **Posição é do dono.** O servidor descarta pacote de zumbi de quem não é dono e
  aplica a posição do dono sem conferir distância (`NetworkZombiePacker.parseZombie`
  64–88, `applyZombie` 41–97). Teleporte só no servidor volta no pacote seguinte.
  Cópias remotas recebem a posição como alvo e andam até ela, até 2× mais rápido
  (`NetworkZombieAI.parse` 51–80, `IsoZombie.moveUnmodded` 181–283).
- **Remover e spawnar troca a identidade** (`persistentOutfitID`, base da variante
  na [ADR-006](adr-006-variantes-deterministicas.md)) e o servidor não avisa o
  cliente da remoção ([ADR-003](adr-003-eco-spawnado.md)).

E os efeitos da névoa (som, chão, tela) precisam ser de cada jogador, sem rede e
sem save: um overlay que vaza pro save é pior que nenhum.

## Decisão

**Sem-rosto: o cliente que vê avisa, o servidor confere, o dono move.**

- Quem é Sem-rosto: `NOM_VariantRules.semRosto(persistentOutfitID, período de névoa)`,
  determinístico como as variantes da noite e independente delas (sal próprio). O
  servidor conta os períodos de névoa no `ModData` global (`data.fog`, pelo
  estado, como as noites) e manda `fog { on, period }`.
- Quem vê (solo: o processo; MP: cada cliente) varre os Sem-rosto a cada 10 ticks:
  visto = `square do zumbi:isCanSee(pn)` a até 30 tiles; destino = primeiro tile
  atrás do jogador, `nextRadius` mais perto, livre e `not isCouldSee(pn)`.
- O servidor confere névoa, variante, destino (mais perto, não colado, zumbi a até
  30 tiles de quem viu) e o cooldown de 4 s por zumbi. No solo move ali mesmo. No
  dedicado move a própria cópia (vale quando ninguém é dono) e manda
  `semRostoMove { id, x, y, z }` a todos; só a cópia local (`not isRemoteZombie()`)
  faz `teleportTo`.
- **Fallback:** se o mesmo zumbi é visto de novo a ≤ 1,5 tile de onde saiu, até
  20 s depois, o dono não aplicou: o servidor spawna outro no destino, veste com
  `dressInPersistentOutfitID(id)` (mesma variante), remove o original e manda
  `semRostoGone` (o cliente apaga como o Eco).
- Fim da névoa: nada a desfazer. O Sem-rosto não tem stats próprios.

**Atmosfera: local e sem save.**

- Som: `player:playSoundLocal` + `emitter:setVolume/stopSoundLocal/isPlaying`.
  `emitter:playSound`/`stopSound` mandam pacote no cliente de MP e ficam de fora.
- Chão: `getIsoMarkers():addIsoMarker` (lista em memória, sem save, sem rede, nil
  no servidor). Sangue de verdade (`addBloodSplat`) é salvo no chunk: recusado.
- Tela: `SearchMode` com `ISSearchManager.isOverride` só durante a névoa e só
  quando o jogador não forrageia ([spike](../sprints/spike-shader/README.md)).

## Alternativas recusadas

| Alternativa | Por que não |
|---|---|
| Teleportar só no servidor | O pacote seguinte do dono devolve a posição antiga (`applyZombie`). |
| Remover e spawnar sempre | Troca o ID (a variante), precisa de aviso de remoção, mexe na população; fica de fallback. |
| O cliente que vê teleportar a cópia dele | Cópia remota volta andando até a posição do dono. |
| Servidor decidir "visto" com `CanSee` + cone | Sem luz (`CanSee` é só `LosUtil.lineClear`): no escuro todo zumbi à frente "seria visto". |
| `setInvisible(true)` | Efeito em zumbi UNKNOWN; não aproxima o zumbi. |
| Overlay com `addBloodSplat` ou sprite no objeto do square | Vai pro save (e o segundo, pra rede). |
| Override de `screen.frag` pra vinheta | Arquivado no spike: só na 1ª carga, troca o shader de todos, quebra no patch. |

## Consequências

- No MP, outros jogadores podem ver o Sem-rosto **deslizar** até o novo ponto
  (cópias remotas andam até a posição do dono). Só quem o viu tem a garantia de que
  o destino está fora da vista. A confirmar no jogo.
- Quem viu e quem é dono podem ser clientes diferentes: o sumiço tem a latência de
  ida e volta ao servidor.
- O destino é conferido pelo servidor só por distância; "fora da vista" é palavra
  do cliente. Um cliente malicioso consegue puxar o Sem-rosto pra perto de si
  (no máximo a cada 4 s por zumbi, e só pra mais perto dele mesmo).
- Overlays e vinheta são de cada processo: em tela dividida, os overlays em volta
  do jogador 1 aparecem pros dois.
- `moved` (servidor) e `lastReport` (cliente) são chaveados pelo objeto do zumbi
  e esvaziam no fim da névoa.
