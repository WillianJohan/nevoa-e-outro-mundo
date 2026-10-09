# ADR-006 — Variantes determinísticas

| Campo | Valor |
|-------|-------|
| Status | `accepted` |
| Data | 2026-10-04 |
| Substitui | o mecanismo da [ADR-001](adr-001-variantes-por-moddata.md) (`NOM_variant`/`NOM_orig`/`NOM_rolledAt` no `modData`) |
| Emenda | 2026-10-05 (sprint 0008): o período é o da **névoa**, não o da noite; um sorteio só pra todas as variantes. 2026-10-05 (sprint 0010): na névoa vermelha todo zumbi é variante, por igual ([ADR-010](adr-010-nevoa-vermelha.md)). 2026-10-05 (sprint 0011): Carpideira, 4º tipo no fim de `KINDS` ([ADR-011](adr-011-carpideira.md)). 2026-10-05 (sprint 0012): a variante ganha visual (pele e peça) sem trocar o outfit ([ADR-012](adr-012-visual-das-variantes.md)). 2026-10-05 (sprint 0017): o bit do chapéu caído sai do ID antes do sorteio e de toda tabela chaveada pelo ID ([abaixo](#emenda-de-2026-10-05--sprint-0017-o-chapéu-caído-não-é-identidade)). 2026-10-09 (sprint 0049): na névoa **branca** todo zumbi com outfit também vira monstro — pesos do sandbox renormalizados pra 100%; vermelha/preta inalteradas; identidade por cor em `NOM_ColorIdentityRules` |

> **Emenda de 2026-10-05.** Decisão do Johan: todo monstro, menos o Eco, só existe na
> névoa. A entrada do sorteio passou a ser o **número do período de névoa**
> (`NOM_Fog.period()` no servidor, `NOM_FogState.period` em quem simula e vê), e
> Estalador, Corredor e Sem-rosto saem de **um sorteio só**: `roll` 0–99, faixas
> contíguas na ordem de `NOM_VariantRules.KINDS` (`estalador`, `corredor`,
> `semrosto`, `carpideira`; variante nova entra no fim, sem mexer nas de antes). O tipo desligado
> mantém a faixa vazia. O perfil vale enquanto a névoa durar (`NOM_FogState.on`), de
> dia ou de noite; à noite ele vai por cima dos stats da noite. Onde o texto abaixo
> diz "noite", leia "período de névoa" para as variantes; o contador de noites
> continua existindo pro Eco.

## Contexto

A [ADR-001](adr-001-variantes-por-moddata.md) decidiu que Estalador, Corredor e
Sem-rosto são zumbis existentes marcados, sorteados uma vez por período, com o
estado original guardado no `modData` do zumbi. As sprints 0002 e 0003 mostraram
que esse mecanismo não se sustenta no B42.20:

- O `modData` do zumbi **não é salvo nem sincronizado**: o zumbi que vai pro
  virtual volta como objeto novo, com `modData` vazio e stats re-sorteados do
  sandbox (`createZombieOutsideWorld` → `DoZombieStats`). `NOM_orig` e
  `NOM_rolledAt` sumiriam no primeiro descarregamento de chunk.
- No MP, quem aplica é o cliente dono ([ADR-005](adr-005-quem-simula-aplica.md)),
  e o cliente não vê o `modData` do servidor. Marcar no servidor exigiria
  mandar cada variante pela rede, zumbi a zumbi.
- O que sobrevive ao virtual **e chega igual ao cliente** é o
  `persistentOutfitID`: o popman guarda, o `ZombiePacket` leva (`ZombiePacket.set`
  → `outfitId`) e o cliente recria o zumbi com ele
  (`NetworkZombieSimulator.parseZombie` → `createRealZombieAlways(outfitId, …)`).

## Decisão

**A variante é derivada, não guardada.**
`NOM_VariantRules.variant(persistentOutfitID, noite, sandbox)` é uma função pura
e determinística: mesma entrada, mesma resposta, em qualquer máquina.

- **Noite**: o servidor conta as noites no `ModData` global
  (`server/NOM_NightCount.lua`, o mesmo contador do Eco, salvo com o mundo) e
  manda o número junto da flag: `sendServerCommand(…, "night", { on, night })`,
  inclusive na resposta ao `nightState`. Sem número (cliente que ainda não ouviu
  o servidor), não há variante.
- **Sorteio**: mistura não linear do ID com a noite (quadrados módulo um primo
  < 2^26, exata em double, sem operadores de bit do Kahlua; uma mistura linear
  correlacionava noites seguidas), `roll` 0–99 contra `EstaladorChance` e depois `CorredorChance`. "Uma vez por
  noite" sai de graça: a noite seguinte é outra entrada. "Preguiçoso" também: o
  zumbi de chunk carregado depois é calculado na primeira passada do laço.
- **Quem calcula**: quem simula o zumbi, no laço do `NOM_NightStats` (ADR-005),
  a cada passada e com o ID **atual** (o spawn por outfit troca o ID depois do
  `OnZombieCreate`). O resultado vai pra `modData.NOM_variant`, cache em memória
  como o `NOM_night`, apagado no dia e na morte. O servidor recalcula quando
  precisa decidir (grito do Corredor) e não confia no cliente.
- **Ecos nunca são variantes**: o perfil "eco" é testado antes do sorteio.
- **Amanhecer**: o perfil volta a "dia" e o jogo fica com os stats do sandbox.
  Nada a restaurar, porque nada foi guardado.

## Alternativas recusadas

| Alternativa | Por que não |
|---|---|
| `modData` do zumbi (ADR-001 original) | Não é salvo nem sincronizado; o zumbi volta do virtual sem a marca e sem `NOM_orig`. |
| Lista de IDs no `ModData` global (como o Eco) | Cresce com a população inteira e precisa ser mandada aos clientes; o Eco só faz isso porque é poucos e nasce do mod. |
| Mandar a variante de cada zumbi pros clientes | Uma mensagem por zumbi por noite, e o zumbi que chega depois precisaria de outra. |
| Semente do mundo no lugar da noite | Daria a mesma variante toda noite: não é "sorteio por noite". |

## Consequências

- Zumbis com o mesmo `persistentOutfitID` (mesmo outfit, sexo e semente
  1..500) têm a mesma variante na mesma noite. Com a população toda, o efeito é
  só estatístico; a taxa bate com o sandbox (`variant_rules_rate_matches_chance`).
- Zumbi sem outfit (ID 0) nunca é variante.
- A variante não tem **outfit** próprio: vestir outro outfit troca o
  `persistentOutfitID` e, com ele, a variante. O visual (sprint 0012) vai por cima, na
  cópia local, sem mexer no outfit ([ADR-012](adr-012-visual-das-variantes.md)).
- O laço do `NOM_NightStats` passa a ler o ID e sortear a cada zumbi processado:
  custo de aritmética, dentro do mesmo lote de 20 por tick.
- A mudança da lista de outfits (outro mod, update) muda os IDs e, com eles, quem
  é variante: sem efeito duradouro, a próxima noite sorteia de novo.
- O contador de noites é do servidor; se o servidor cair entre contar e salvar,
  a mesma noite pode ganhar outro número e outro sorteio (custo já registrado no
  Eco, sprint 0002).

## Emenda de 2026-10-05 — sprint 0017: o chapéu caído não é identidade

O `PersistentOutfits.setFallenHat` liga o bit `0x8000` do `persistentOutfitID`
(bytecode 0–36: `setPersistentOutfitID(id | 32768, isPersistentOutfitInit())`). Quem
liga no zumbi: o servidor dedicado no golpe que derruba o chapéu (`hit/Zombie.react`
20–57, só `GameServer.server`) e o cliente no `ZombieHelmetFallingPacket.processClient`
238. No solo o jogo não liga no zumbi (`IsoGameCharacter.helmetFall` 81–97 pula zumbi),
mas o bit volta salvo no popman. Como o ID é a entrada do sorteio, um zumbi que perdia
o chapéu na névoa podia virar ou deixar de ser variante, e a Carpideira que gritou, o
Eco e o forçado do debug deixavam de ser achados pelo ID.

**Decisão:** `NOM_VariantRules.baseId(id)` tira o bit (`math.floor(id / 32768) % 2`,
deslocamento aritmético exato em double também no ID negativo; subtrai 32768). O
`variant()` usa ele por dentro (sorteio, vermelha, `forced`), e toda tabela chaveada
pelo ID lê por ele: Eco (`data.eco.ids`), Carpideira que gritou (`ModData` e
`NOM_Carpideira.screamed`), `pid` do grito no cliente, ID que o `NightStats` passa pro
visual, ID forçado do debug. O ID cru fica onde o jogo precisa dele: vestir
(`dressInPersistentOutfitID`, que com o bit não devolve o chapéu caído) e o
`hatFallen` do visual.

**Consequências:** o visual não repinta quando só o bit muda; o jogo não re-veste o
zumbi por isso (`setFallenHat` mantém o init; o `outfitId` do `ZombiePacket` só é usado
na criação, `NetworkZombieSimulator.parseZombie` 144–152), e o `processClient` refaz a
lista com os mesmos objetos. Marcas antigas salvas com o bit (Carpideira de uma névoa
em curso quando o mod atualizou) param de casar: o custo é um grito a mais, uma vez.

**Adendo do review (0017): o `%` do Kahlua trunca.** `KahluaThread.primitiveMath` faz
`a - (double)(int)(a/b)*b`; o luajit dos testes arredonda pra baixo. O `baseId` testa a
paridade pelo `NOM_Math.mod` (o `% 2` daria `-1` no ID feminino). O `hash` **não** foi
normalizado: no jogo `id % Q` e `floor(id / Q) % Q` saem negativos pro ID feminino, e
normalizar re-sortearia todo zumbi feminino. Os testes de distribuição no luajit exercitam o
`%` arredondado pra baixo nos IDs femininos, enquanto o jogo usa o truncado: a taxa e a
independência entre períodos estão provadas pros masculinos exatamente e pros femininos só
pela mesma mistura com outra entrada. O determinismo entre solo, servidor e clientes vale
porque todos rodam Kahlua, e todo produto fica abaixo de `2^53` (os quocientes do `%`, longe
de `2^31`).
