# ADR-006 — Variantes determinísticas

| Campo | Valor |
|-------|-------|
| Status | `accepted` |
| Data | 2026-10-04 |
| Substitui | o mecanismo da [ADR-001](adr-001-variantes-por-moddata.md) (`NOM_variant`/`NOM_orig`/`NOM_rolledAt` no `modData`) |

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
- **Sorteio**: mistura minstd do ID com a noite, sem operadores de bit (Kahlua),
  `roll % 100` contra `EstaladorChance` e depois `CorredorChance`. "Uma vez por
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
- A variante não tem roupa própria: vestir outro outfit troca o
  `persistentOutfitID` e, com ele, a variante. O aviso é sonoro (estalo, grito).
- O laço do `NOM_NightStats` passa a ler o ID e sortear a cada zumbi processado:
  custo de aritmética, dentro do mesmo lote de 20 por tick.
- A mudança da lista de outfits (outro mod, update) muda os IDs e, com eles, quem
  é variante: sem efeito duradouro, a próxima noite sorteia de novo.
- O contador de noites é do servidor; se o servidor cair entre contar e salvar,
  a mesma noite pode ganhar outro número e outro sorteio (custo já registrado no
  Eco, sprint 0002).
