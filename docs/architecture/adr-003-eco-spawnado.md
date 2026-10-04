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

Como (sprint 0002, evidência em [pz-api-notes §1](pz-api-notes.md#1-eco-sprint-0002)):

- **Spawn:** `addZombiesInOutfit(x, y, z, 1, "NOM_Eco", 50)` no servidor, a cada
  10 minutos de jogo, no raio de cada jogador, corpos mais perto primeiro, até o
  teto. `NOM_Eco` é um outfit do mod (`media/clothing/clothing.xml`) feito só de
  itens vanilla referenciados por GUID.
- **Identidade:** o `modData` do zumbi não é salvo. O Eco é reconhecido pela
  chave do `persistentOutfitID` (outfit + sexo), aprendida no spawn e guardada
  no `ModData` global; no `OnZombieCreate` a chave é confirmada vestindo o zumbi
  pelo próprio ID. Em memória, `modData.NOM_eco = true`, que o corpo herda.
- **Morte:** `OnZombieDead` limpa o inventário; o `OnTick` procura o corpo com
  `NOM_eco` no 3×3 e chama `removeCorpse(body, false)`. A varredura periódica
  remove o que escapar. (`OnDeadBodySpawn` não dispara no dedicado.)
- **Amanhecer:** borda `night → false` do `NOM_World` remove os Ecos carregados
  (`removeFromWorld` + `removeFromSquare`); em MP o servidor manda `ecoGone` com
  os `onlineID`s e o cliente apaga o fantasma local. Eco que volta de chunk de
  dia sai no tick seguinte ao `OnZombieCreate`.
- **Fraco:** só vida baixa (0.3) por enquanto; velocidade e força dependem do
  swap de `ZombieLore` da sprint 0003.

## Alternativas recusadas

| Alternativa | Por que não |
|---|---|
| Corpo some ao virar Eco | Decisão do autor: o corpo fica, e queimar/enterrar é o que previne. |
| Um Eco por corpo por noite | Decisão do autor: uma vez na vida. |
| Outfit vanilla (`HospitalPatient`) | Pode ser trocado pelo estágio do apocalipse (`ZombiesStageDefinitions`) e não distingue Eco de paciente comum. |
| Lista de corpos liberados no `ModData` global | Desnecessária: o `modData` do corpo vai pro save (bytecode `IsoMovingObject.save`). |

## Consequências

- Corpo queimado ou enterrado não existe mais como `IsoDeadBody` → não gera Eco,
  sem regra extra.
- "Morrer sem cadáver" não é nativo: remoção do corpo no servidor depois da
  morte, a confirmar no jogo em solo e MP (roteiro da
  [sprint 0002](../sprints/sprint-0002-eco/README.md#roteiro-in-game)).
- O raro zumbi de zona sem definição pode sortear o outfit `NOM_Eco`
  (`OutfitManager.GetRandomOutfit` usa todos os outfits) e vira Eco. Aceito.
- Teto por jogador (`EcoMaxPerPlayer`) é obrigatório: vala comum sem teto trava
  o servidor.
