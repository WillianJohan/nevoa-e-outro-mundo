# Sprint 0016 — Monstro sem roupa comum

| Campo | Valor |
|-------|-------|
| Status | em teste |
| Branch | `sprint/0016-monstro-sem-roupa` |
| Plano | [plan.md](plan.md) |
| GDD | [art-direction.md](../../gdd/art-direction.md#regra) (regra nova), [monsters.md](../../gdd/monsters.md), [Overview.md](../../gdd/Overview.md#decisões-do-autor) |
| ADR | [ADR-012](../../architecture/adr-012-visual-das-variantes.md#emenda-de-2026-10-05--sprint-0016-a-roupa-comum-some-na-variante) (emenda); [pz-api-notes §14.4](../../architecture/pz-api-notes.md#144-esconder-a-roupa-sprint-0016) |

## Objetivo

Na névoa, o Estalador, o Corredor, o Sem-rosto e a Carpideira aparecem só com a pele e a peça
do mod, sem a camiseta, a calça, o chapéu ou os óculos do zumbi que eles eram. Quando a
variante acaba, a roupa volta, e quem mata uma variante acha no corpo o loot de um zumbi comum.

Decisão do Johan (05/10/2026), depois de ver as variantes no jogo: "os zombies quando se
transformam devem ficar sem roupa ... tudo que contribui pro monstro fica, mas de resto não
... tem monstro que tem coisa na cabeça e fica estranho". Ele gostou de "uma saia estranha" sem
saber qual era: por padrão toda roupa vanilla some, e uma lista curta (`NOM_VariantLook.KEEP`)
guarda exceções. O Eco não muda (já veste só itens do mod).

## Critérios de aceite

- [x] A roupa vanilla some quando a variante começa; ficam a pele, a peça do mod e as feridas
      do corpo (`ZedDmg_*`, `Wound_*`); o `persistentOutfitID` não muda —
      `nude_hidden_on_variant_start` (com chapéu, ferida, atadura), `look_applied_when_variant_starts`,
      `look_red_fog_everyone` (vermelha: só a peça), `look_waits_until_dressed`.
- [x] A roupa volta quando a variante acaba, os mesmos objetos na mesma ordem: fim da névoa,
      troca de tipo, período novo, reaproveitamento — `nude_restored_on_fog_end` (os 4 tipos),
      `look_removed_when_fog_ends`, `look_debug_forced_and_undone`, `look_period_change_without_edge`,
      `look_semrosto_removed_at_day`, `nude_reuse_restores_nothing_stale`, `look_reused_object_clean`.
- [x] Variante morta no solo deixa no corpo e no inventário **exatamente** os itens vanilla —
      `nude_dead_loot_exact`: pra cada tipo, um gêmeo que nunca foi variante morre primeiro e o
      corpo da variante tem que ter os mesmos vestidos, o mesmo inventário (com o item preso) e
      a mesma lista, sem pele. O fake segue o jogo: `DoZombieInventory` antes do `OnZombieDead`
      (`IsoZombie.onKilled` 38–52), `setFromItemVisuals` que limpa e veste com `setItem`
      (expulsando em lugar comum), presos no inventário, corpo copiando pele e vestidos
      (`IsoDeadBody.<init>` 661–710). Também `look_dead_leaves_no_loot`, `look_dead_keeps_vanilla_headgear`.
- [x] Morte por fogo não inventa nem perde loot — `nude_burn_death_no_invented_loot` (bytecode:
      `FireCheck` 268–290 dispara `OnZombieDead` sem `DoZombieInventory`; `BurntToDeath.execute`
      47–58 faz o corpo direto).
- [x] MP: o servidor nunca pinta (corpo dele certo); o cliente não refaz loot e o corpo local
      veste o que o servidor mandou, sem a pele do mod — `nude_mp_client_death_keeps_server_items`,
      `look_not_on_dedicated_server`, `look_remote_copy_gets_it_and_nothing_sent`. Bytecode:
      `DeadZombiePacket.parse` lê vestidos e inventário do servidor; `processClient` 514 →
      `dieNetwork` 0–10 (`Kill` com o `OnZombieDead`, depois `becomeCorpse`).
- [x] Nada preso nem salvo: jogador reanimado nunca pintado; erro da API não esconde nada; o
      jogo re-vestir não traz a roupa velha por cima — `look_skips_reanimated_player`,
      `nude_api_error_hides_nothing`, `look_api_error_does_not_leak_or_stall`,
      `nude_redressed_does_not_restore_old_clothes`, `look_redressed_zombie_repainted`. Estado só
      na tabela Lua; sair pro menu reinicia o Lua (`IngameState.exit` 986 `LuaManager.init`).
- [x] Fim da névoa espalhado pelos lotes do `NightStats`, não num tick só —
      `nude_fog_end_spread_in_batches` (40 variantes: um tick devolve ≤ 20). Zumbi pulado pelo
      cursor da passada fica até 1 hora de jogo sem a roupa (passada de conferência do
      `NightStats`): **aceito** pelo coordenador (review da 0016).
- [x] Review: chapéu derrubado pelo servidor no MP não volta pra cabeça no fim —
      `nude_fallen_hat_not_restored` (o fake liga o bit `0x8000` do ID e refaz a lista como o
      `ZombieHelmetFallingPacket.processClient` 130–238); item do mod só por `módulo.NOM_` —
      `nude_keep_only_mod_module_prefix`; `visuais=N` conta só os zumbis carregados —
      `nude_count_only_loaded_zombies`.
- [x] **O monstro larga tudo** (decisão do Johan, 05/10/2026): enquanto é variante, morde através
      de máscara e capacete, sem armadura nem modificador de visão/audição da roupa, e o chapéu
      escondido não cai; tudo volta no fim — `nude_monster_bites_through_hidden_mask` (fake do
      `IsoZombie.cantBite` 140–319 pela lista); resto pelo bytecode na
      [emenda da ADR-012](../../architecture/adr-012-visual-das-variantes.md#emenda-de-2026-10-05--sprint-0016-a-roupa-comum-some-na-variante).
- Limite aceito (review): o loot é exato pra quem **não apanhou** como variante; sangue,
  buraco e sujeira da luta só pegam o que estava à mostra, então a roupa escondida volta limpa
  daquela luta.
- [x] Orçamento — `look_budget` (pôr ≤ 11 + 3·N, tirar ≤ 5 + 2·N, passada sem troca 0, contados
      em cada chamada aos objetos falsos); tabela no
      [architecture/README.md](../../architecture/README.md#orçamento-por-sistema).
- [ ] No jogo, a variante aparece sem roupa e a pele cobre o corpo todo sem buraco — **falta o
      jogo:** roteiro, passos 2–3.
- [ ] A roupa volta no fim da névoa e o corpo de uma variante morta tem a roupa e o loot
      normais — **falta o jogo:** passos 4–5.
- [ ] MP: os dois clientes veem a variante sem roupa e o corpo com a roupa — **falta o jogo:** passo 6.
- [ ] Sem engasgo no começo e no fim de uma névoa vermelha com horda — **falta o jogo:** passo 7.

`./run-tests.sh`: `total=516 passou=516 falhou=0` (Lua), `contraste total=4 passou=4`,
`build total=25 passou=25`.

## Roteiro in-game

Jogo em `-debug`, **save descartável**. Console em
`~/.var/app/com.valvesoftware.Steam/Zomboid/console.txt` (Flatpak).

1. **Copiar e carregar.** `scripts/dev-sync.sh`, fechar o jogo se estiver aberto, abrir e
   carregar o save. **Esperado:** nenhuma linha com `NOM_` e `ERROR`, nem `[NOM] visual: erro`.
2. **Variante sem roupa.** De dia, Spawn Horde com 5 zumbis a ~6 tiles (pegar um de chapéu ou
   capacete), `NOM_Debug.fog(true, true)`, `NOM_Debug.variant("estalador")` no de chapéu.
   **Esperado:** em até 1 s ele fica branco-osso, com a venda, **sem camiseta, calça nem
   chapéu**; feridas de zumbi (rasgos de sangue) podem aparecer na pele. `NOM_Debug.status()`
   com `visuais=1` ou mais. **Se** aparecer `[NOM] visual: erro` no console: anotar a linha.
   **Se** o corpo ficar com partes invisíveis ou pretas onde estava a roupa: a pele do mod não
   cobre aquela região (registrar com print).
3. **Os outros.** `NOM_Debug.variant("corredor")`, `("semrosto")`, `("carpideira")` em outros
   três. **Esperado:** cada um só com a pele e a peça dele; o Sem-rosto com a pele de zumbi
   normal, pelado, e a cabeça de chiado.
4. **Volta.** `NOM_Debug.fog(false)`. **Esperado:** em ~1 s (lotes de 20) todos voltam com a
   roupa e o chapéu de antes; `visuais=0`. **Se** a roupa não voltar: o `remove(Object)` do
   Kahlua não devolveu `true` (pz-api-notes §14.4; registrar). O `visuais=` conta só os
   zumbis carregados nesta tela.
5. **Morte e loot.** Nova névoa, `NOM_Debug.variant("estalador")` no zumbi de chapéu, matar.
   **Esperado:** o corpo caído **de roupa e chapéu**, pele normal; no inventário do corpo os
   itens de roupa dele (camiseta, calça, chapéu…), nenhum "Venda de arame enferrujado" e
   nada repetido. Matar outra variante com fogo (coquetel molotov): corpo
   queimado normal, sem a peça.
   **O monstro larga tudo:** uma variante que era de máscara ou capacete morde mesmo assim
   (deixar ela pegar o personagem num save de teste, sem God Mode).
6. **MP** (dedicado + 2 clientes). Repetir 2 com o cliente A. **Esperado:** o cliente B vê o
   mesmo zumbi sem roupa. Matar pelo cliente B: nos dois clientes, o corpo de roupa, e o loot
   igual nos dois. Console do servidor sem linha do visual.
7. **Vermelha.** `NOM_Debug.redFog(true)` com ~30 zumbis à vista: em ~1–2 s todos pelados com
   o visual; `NOM_Debug.fog(false)`: anotar se há engasgo no começo ou na volta (agora
   espalhada em lotes).

## Checkpoints

- **04/10/2026** — Sprint aberta pela decisão do Johan (05/10). Bytecode: sem flag de esconder
  em `ItemVisual`; nenhum evento antes do `DoZombieInventory` na morte; o `WornItems` refaz os
  vestidos sem tocar em presos nem `itemsToSpawnAtDeath`; no cliente de MP o `OnZombieDead`
  vem antes do corpo local. Plano escrito.
- **04/10/2026** — Esconder e devolver a roupa no `NOM_VariantLook`; morte com loot exato
  (solo, fogo, cliente de MP); fim da névoa pelos lotes do `NightStats`. Testes verdes.
- **04/10/2026** — Docs: art-direction, monsters, Overview, emenda da ADR-012, pz-api-notes
  §14.4, orçamento, roteiro. Em teste.
- **04/10/2026** — Review: chapéu derrubado pelo servidor no MP não volta; `módulo.NOM_`;
  status só dos carregados; limite do dano escondido documentado; decisão do Johan "o monstro
  larga tudo" registrada e travada por teste.

## Aprendizados

- **Não há como esconder um item de roupa sem tirá-lo.** `ItemVisual` não tem flag de render;
  tirar da lista é o único jeito, e aí a morte vira problema: o `DoZombieInventory` faz o loot
  da lista **antes** do `OnZombieDead`, e não existe evento Lua antes dele.
- **Não chame `DoZombieInventory()` duas vezes.** Ele limpa o inventário inteiro e a lista
  `itemsToSpawnAtDeath` no fim: a segunda chamada perde esses itens. Refazer só os vestidos
  pelo `WornItems` (`setFromItemVisuals` + `addItemsToItemContainer`) é exato.
- **O `OnZombieDead` dispara sem inventário em dois caminhos:** fogo (`FireCheck`) e cliente de
  MP (o inventário vem do servidor). A peça do mod no inventário é a prova barata de que o
  `DoZombieInventory` rodou.
- **Guardar a lista e devolver por cima pode duplicar roupa** se o jogo vestiu de novo no meio
  (`dressInPersistentOutfitID` limpa a lista). A peça do mod some junto: se o `remove` dela
  falha, a lista é nova e a guardada vai fora.

## Pendências que a próxima sprint herda

- Tudo do roteiro acima, em especial o `remove(Object)` devolvendo booleano no Kahlua e a pele
  do mod cobrindo o corpo inteiro sem roupa por cima.
- A "saia estranha": quando o Johan achar qual item é, entra um padrão na `NOM_VariantLook.KEEP`.
- Zumbi que sai da lista no meio da passada do fim da névoa fica pelado até a passada de
  conferência de hora em hora do `NightStats` (aceito).
- O bit de chapéu caído muda o `persistentOutfitID`, base do sorteio (ADR-006): um zumbi que
  perde o chapéu na névoa pode virar ou deixar de ser variante. Vem desde a 0004; decidir à parte.
- Herdadas da 0012 que seguem: chiado parado do Sem-rosto; modelos 3D próprios (`later`).

## Sessões

- 2026-10-05 — abd764e2-7a9a-416b-b9b3-1630ab9e761f — plano, esconder/devolver, loot exato, lotes, docs
