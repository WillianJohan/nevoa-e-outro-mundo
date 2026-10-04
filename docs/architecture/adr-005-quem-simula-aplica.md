# ADR-005 — O servidor decide, quem simula aplica

| Campo | Valor |
|-------|-------|
| Status | `accepted` |
| Data | 2026-10-04 |
| Emenda | [ADR-002](adr-002-autoridade-servidor.md) (para comportamento de zumbi) |

## Contexto

A [ADR-002](adr-002-autoridade-servidor.md) põe toda decisão no servidor e deixa
o cliente só renderizar. Isso vale pra decidir, mas não pra **aplicar** ajuste de
IA de zumbi no MP do B42, porque quem simula o zumbi não é o servidor:

- O servidor dá a posse de cada zumbi a uma conexão (`NetworkZombieManager.updateAuth`,
  `IsoZombie.setOwner`), e o cliente dono roda a IA.
- O zumbi remoto (não dono) copia `walkType` e `speedMod` do pacote
  (`NetworkZombieAI.parse`, só com `isRemoteZombie()`); o servidor aceita o
  `walkType` que o dono manda (`NetworkZombiePacker.applyZombie`). Velocidade
  mudada só no servidor é sobrescrita no pacote seguinte.
- Visão e audição são campos locais de cada cópia (`IsoZombie.sight/hearing`),
  lidos por quem simula (`getVisionRadiusAdjusted`, `WorldSoundManager.getHearingMultiplier`).
  Não viajam no pacote.
- O cliente recebe `OnZombieCreate` pros zumbis da rede
  (`NetworkZombieSimulator.parseZombie` → `createRealZombieAlways`).

E o `modData` do zumbi não é salvo nem sincronizado; os stats são re-sorteados do
sandbox sempre que o zumbi volta do virtual (`createZombieOutsideWorld` →
`DoZombieStats`).

## Decisão

**O servidor decide, quem simula aplica.**

- **Servidor** (`server/NOM_Night.lua`): calcula a noite (`NOM_World`), chama os
  zumbis com `addSound` (caça e lanterna), e no dedicado avisa os clientes:
  `sendServerCommand("NevoaEOutroMundo", "night", { on })` na borda, e responde
  `nightState` pra quem entra no meio da noite. `addSound` no servidor vai pro
  popman e pros clientes (`WorldSoundManager.addSound` → `GameServer.sendWorldSound`):
  o zumbi reage onde é simulado.
- **Quem simula** aplica os stats (`shared/NOM_NightStats.lua`): no solo, o próprio
  processo (`not isServer()`); no dedicado, `client/NOM_NightClient.lua` em todas
  as cópias locais. Zumbi remoto recebe os sentidos (valem quando a posse muda),
  mas a velocidade dele não é conferida: o pacote do dono manda.
- **Nada noturno fica guardado no zumbi.** O perfil (dia, noite, Eco) é derivado de
  `night` + sandbox a cada passada do laço; `modData.NOM_night` é só cache em
  memória do que já foi aplicado, perdido exatamente quando o jogo re-sorteia os
  stats (virtual, `resetForReuse`).

## Alternativas recusadas

| Alternativa | Por que não |
|---|---|
| Aplicar só no servidor | Velocidade sobrescrita pelo pacote do dono; sentidos ignorados (não são do servidor). |
| Cliente calcular a noite sozinho | Duas fontes da verdade; foge da ADR-002. A flag é barata de mandar. |
| Aplicar só no zumbi dono (`not isRemoteZombie()`) | A posse troca sem evento; o novo dono ficaria com sentidos do dia até a próxima passada. Aplicar em todas as cópias custa o mesmo lote. |
| Mandar os IDs dos Ecos pro cliente | O outfit `NOM_Eco` já chega ao cliente; `getOutfitName()` basta. |

## Consequências

- O servidor do dedicado não aplica stats nos zumbis que ele mesmo simula (os sem
  dono, longe de jogadores). Custo baixo: ninguém está vendo.
- Teste de MP com dois clientes é obrigatório pra fechar a sprint 0003.
- Variantes (sprints 0004/0005) seguem o mesmo desenho: o servidor decide e avisa,
  quem simula aplica.
