# ADR-011 — Carpideira: quem vê avisa, o servidor ouve e decide, o dono congela

| Campo | Valor |
|-------|-------|
| Status | `accepted` |
| Data | 2026-10-05 |
| Emenda | [ADR-006](adr-006-variantes-deterministicas.md) (4º tipo em `KINDS`) e [ADR-010](adr-010-nevoa-vermelha.md) (vermelha 1/4) |

## Contexto

A Carpideira ([monsters.md](../gdd/monsters.md#carpideira)) fica parada e soluçando
até ser acordada por proximidade, lanterna ou barulho; aí grita (chama a horda) e caça
quem a acordou, uma vez por névoa. O que o B42 dá ([pz-api-notes §13](pz-api-notes.md#13-carpideira-sprint-0011)):

- **Parar um zumbi** só com `setUseless(true)` (sprint 0004): sem perambular, surdo, sem
  alvo. Vale onde ele é simulado (o dono, [ADR-005](adr-005-quem-simula-aplica.md)) e
  viaja no pacote do zumbi.
- **Barulho** é visível no servidor: todo `addSound` dispara `Events.OnWorldSound(x, y, z,
  raio, volume, fonte)`, inclusive o de cliente de MP, que o servidor refaz com o jogador
  de fonte.
- **Ver** (lanterna apontada) é do cliente: cone e luz por jogador só existem lá
  (`isCanSee(pn)`, [ADR-007](adr-007-sem-rosto-e-atmosfera-local.md)); a direção do
  jogador no servidor não foi confirmada.
- **Caçar alguém** é `z:spotted(p, true)` no dono (o spot forçado do próprio jogo).
- Som de zumbi local: `playSoundLocal` no emitter dele; o emitter não para sozinho
  quando o zumbi sai do mundo.

## Decisão

1. **Variante determinística**, 4º tipo de `NOM_VariantRules.KINDS`, no fim (faixa
   `[12, 15)` com o padrão; as de antes não andam). Na vermelha, 1/4 de cada.
   Perfil: corredora (`NOM_NightRules.wanted`), que só aparece depois do grito.
2. **Calma = useless no dono** (`NOM_Carpideira.hold`, chamado pelo `NOM_VariantAI` a
   cada frame): uma vez por objeto, `setUseless(true)` + `setTarget(nil)`. Solta
   (`letGo`) quando a névoa baixa, ela deixa de ser Carpideira, vira remota ou grita.
   Objeto que volta do virtual: confere o ID na lista de quem já gritou antes de parar.
3. **Quem vê avisa** (`NOM_Carpideira`, a cada 10 ticks, solo e cada cliente): toca o
   soluço local das calmas a até 15 tiles de um jogador local (`SOB_RANGE`; as outras e
   quem sumiu da lista ficam mudas); jogador local a
   até `CarpideiraTriggerRadius` (mesmo andar) → `near`; lanterna acesa e o square dela
   com `isCanSee(pn)` a até 10 → `light`. Um aviso por varredura e por Carpideira a cada
   2 s (`carpideiraWoke {id, why}`, com o jogador na frente: tela dividida).
   A marca de fúria no zumbi (`modData.NOM_furia`) é o número do período: vale só
   nesta névoa e sai na morte (`NOM_NightStats.forget`).
4. **O servidor confere e ouve.** Aviso: variante pelo próprio sorteio, névoa, mesmo
   andar, distância com folga de 2 tiles (`near` até o raio, `light` até 10 e lanterna
   acesa no servidor), Eco e morto fora, um aviso por jogador por segundo. Barulho:
   `OnWorldSound` com raio ≥ 30, fonte jogador, nascido a até 10 tiles dela, no andar
   dela; os chamados do mod (`NOM_Night.call`, com `NOM_Night.calling`) ficam de fora.
5. **Grito = decisão do servidor.** Uma vez por `persistentOutfitID` por período, guardado
   no `ModData` global (`data.carpideira = {period, pids}`): recarregar no meio não
   deixa gritar de novo. Chama a horda (`NOM_Night.call(z, CarpideiraScreamRadius)`,
   audição da noite compensada, como o Corredor). Solo: aplica direto. Dedicado:
   `carpideiraScream {pid, id, pl}` a todos; cada cliente marca o ID, toca o grito local
   no zumbi com esse `onlineID` e, se for o dono, solta e `spotted(getPlayerByOnlineID(pl), true)`.
   Quem entra no meio da névoa recebe `carpideiraList {pids}` junto da resposta do `fogState`.
   No solo a lista do processo é refeita do `ModData` ao carregar (`OnInitGlobalModData`)
   e na borda da névoa.

## Alternativas recusadas

| Alternativa | Por que não |
|---|---|
| Servidor detectar tudo (varredura de proximidade e lanterna) | A direção do jogador no servidor não foi confirmada, e uma varredura por zumbi no servidor custa em todo zumbi carregado no mundo. O cliente já tem cone e luz. |
| Cliente detectar o barulho | O cliente não ouve o tiro dos outros como evento confiável; o servidor recebe todos (`WorldSoundPacket`). |
| `sendPlaySound` pro grito | Só chega aos clientes perto (`sendToRelative`) e o comando já vai a todos; tocar local em quem a tem carregada evita som dobrado. |
| Estado "gritou" no `modData` do zumbi | Não é salvo nem sincronizado (ADR-006): ela voltaria do virtual calma e gritaria de novo. |
| Chave por `onlineID` | Muda quando o zumbi descarrega e volta. O `persistentOutfitID` é a identidade da variante. |
| Barulho por raio só (sem os 10 tiles) | Tiro tem raio 50–200: toda Carpideira de um bairro acordaria a cada tiro. |

## Consequências

- **Orçamento:** por frame, a calma custa 2 chamadas (as do `VariantAI`: `getModData`,
  `isLocal`) e 3 a mais no primeiro, a furiosa 3 (mais `isUseless`); a varredura, ~8 por Carpideira calma a cada
  10 ticks com um jogador local (+3 por jogador a mais), zero no resto; cada barulho alto
  no servidor, 1 chamada por zumbi carregado. Na vermelha (1/4 de cada), ~2,25·N por
  frame no `VariantAI` (era ~2,3·N com 1/3 de cada).
- No dedicado, a cópia que o servidor simula sozinha (sem dono, ninguém perto) fica no
  último useless que recebeu do dono: parada se o dono saiu com ela calma (inclusive
  depois da névoa, até alguém virar dono e a passada soltar), andando se ela nunca teve
  dono. O servidor não roda o `VariantAI`.
- **Useless herdado** (review): o useless viaja no pacote e o `resetForReuse` não o
  limpa. Quem recebe a posse de um zumbi useless que não parou solta: a furiosa no
  `hold` (como o Estalador herdado), e na passada do `NightStats`
  (`NOM_NightStats.unstick`, 2 chamadas por zumbi da passada, nos lotes de 20 por tick)
  e no `OnZombieCreate` o zumbi local (não remoto, fora de `still` e da cegueira do
  Estalador, sem outfit "Useless") **que o mod pode ter parado**: o ID dele sorteia
  Carpideira ou Estalador no período de névoa atual ou no anterior, normal ou vermelha
  (a cor de um período passado não é guardada: as duas contam). Zumbi do tutorial
  (`client/Tutorial/Steps.lua:847, 1107`) ou de outro mod que nunca foi variante fica; no
  modo tutorial (`getCore():getGameMode() == "Tutorial"`) nada é solto.
- **De dia a liberação pode esperar até 1 hora de jogo:** o `NightStats` dorme depois de
  uma passada limpa e só acorda na borda da névoa ou de hora em hora (`EveryHours`).
- O useless que o menu de debug liga numa ex-variante (Carpideira ou Estalador no período
  atual ou no anterior) volta a falso na passada seguinte; o `letGo` também derruba o
  useless do tutorial ou do debug numa Carpideira que este processo parou.
- Uma caminhada em andamento quando ela vira Carpideira segue até a última posição vista
  (`WalkTowardState`, como no Estalador): ela pode dar alguns passos antes de parar.
- Zumbis com o mesmo `persistentOutfitID` são a mesma Carpideira: o grito de uma deixa as
  outras furiosas (sem grito). Raro e aceito (ADR-006).
- Cliente malicioso perto dela consegue acordá-la (é o que um jogador honesto faria
  chegando perto). O servidor limita a um aviso por segundo por jogador.
- A lanterna é aproximada: com a lanterna acesa na mão, ela vista por outra luz também
  acorda.
