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
- **Identidade:** o `modData` do zumbi não é salvo. O `ModData` global guarda o
  `persistentOutfitID` **exato** (com a semente) de cada Eco e as noites em que
  um Eco com esse ID nasceu (`{ [id] = { [noite] = true } }`). Conjunto porque a
  semente é `Rand.Next(500)+1`: dois Ecos do mesmo sexo dividem o ID em ~19% das
  noites, e um não pode apagar o outro. No `OnZombieCreate`, ID conhecido é
  confirmado vestindo o zumbi pelo próprio ID (`getOutfitName() == "NOM_Eco"`).
  Em memória, `modData.NOM_eco = true`, que o corpo herda. Noite se conta pelo
  estado salvo (`inNight`), não pela borda, pra reinício no meio da noite não
  abrir noite nova. Noites com mais de 7 noites saem do conjunto e
  conjunto vazio sai da lista; **morte e remoção não apagam o ID** (o gêmeo
  descarregado ainda precisa dele). Só sai antes da poda o ID cujo outfit não
  bate mais. Custo dos gêmeos: um gêmeo de noite passada que volta na noite em
  que o outro nasceu conta como da noite atual e só some no amanhecer.
- **Morte:** `OnZombieDead` limpa o inventário; o `OnTick` procura o corpo com
  `NOM_eco` no 3×3 e chama `removeCorpse(body, false)`. A varredura periódica
  remove o que escapar. (`OnDeadBodySpawn` não dispara no dedicado.)
- **Amanhecer:** borda `night → false` do `NOM_World` remove os Ecos carregados
  (`removeFromWorld` + `removeFromSquare`); em MP o servidor manda `ecoGone` com
  os `onlineID`s e o cliente apaga o fantasma local. Eco que volta de chunk de
  dia **ou de outra noite** sai no tick seguinte ao `OnZombieCreate` (GDD: "ao
  amanhecer, todos os Ecos somem, onde quer que estejam").
- **Fraco:** só vida baixa (0.3) por enquanto; velocidade e força dependem do
  swap de `ZombieLore` da sprint 0003.

## Alternativas recusadas

| Alternativa | Por que não |
|---|---|
| Corpo some ao virar Eco | Decisão do autor: o corpo fica, e queimar/enterrar é o que previne. |
| Um Eco por corpo por noite | Decisão do autor: uma vez na vida. |
| Outfit vanilla (`HospitalPatient`) | Pode ser trocado pelo estágio do apocalipse (`ZombiesStageDefinitions`) e não distingue Eco de paciente comum. |
| Lista de corpos liberados no `ModData` global | Desnecessária: o `modData` do corpo vai pro save (bytecode `IsoMovingObject.save`). |
| Reconhecer pela chave do outfit (índice + sexo, sem semente) | Pegava os zumbis vanilla que sorteiam `NOM_Eco` no fallback de zona, e não sabia de que noite o Eco era. |

## Consequências

- Corpo queimado ou enterrado não existe mais como `IsoDeadBody` → não gera Eco,
  sem regra extra.
- "Morrer sem cadáver" não é nativo: remoção do corpo no servidor depois da
  morte, a confirmar no jogo em solo e MP (roteiro da
  [sprint 0002](../sprints/sprint-0002-eco/README.md#roteiro-in-game)).
- Definição de zona que nomeia outfit inexistente pro sexo sorteado cai em
  `OutfitManager.GetRandomOutfit` (`ZombiesZoneDefinition.applyDefinition`), que
  sorteia entre todos os outfits, inclusive `NOM_Eco`. No vanilla: `Hunter`,
  `GuitarGuy`, `Stripclub` — um punhado de zumbis por mundo de camisola e véu.
  Não viram Eco: o reconhecimento é pelo ID exato, que só o spawn grava (a
  chance de um desses repetir a semente de um Eco guardado é ~1/500 por ID).
- **Instabilidade do índice do outfit.** O `persistentOutfitID` carrega o índice
  do outfit na lista ordenada por nome, refeita a cada boot. Adicionar ou
  remover um outfit que ordena antes de `NOM_Eco` (outro mod, update do jogo)
  desloca o índice. Com o ID exato, o que sobra: Ecos **virtuais** naquele
  momento voltam vestidos com o outfit que agora ocupa o índice antigo, como
  zumbis comuns (vida normal, deixam cadáver); a confirmação pelo nome descarta
  o ID. Nada quebra; Ecos novos já nascem com o índice novo. O mesmo
  deslocamento troca a roupa de todo zumbi virtual vanilla, então é custo do
  jogo, não só do mod.
- Teto por jogador (`EcoMaxPerPlayer`) é obrigatório: vala comum sem teto trava
  o servidor.
