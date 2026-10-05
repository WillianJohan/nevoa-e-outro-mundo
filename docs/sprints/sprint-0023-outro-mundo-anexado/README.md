# Sprint 0023 — Outro Mundo anexado

| Campo | Valor |
|-------|-------|
| Status | concluída |
| Branch | `sprint/0023-outro-mundo-anexado` |
| Plano | [plan.md](plan.md) |
| GDD | [atmosphere.md](../../gdd/atmosphere.md#outro-mundo-sangrento-só-na-névoa), [art-direction.md](../../gdd/art-direction.md#o-outro-mundo-sangrento-sprint-0015), [Overview.md](../../gdd/Overview.md#decisões-do-autor) |
| ADR | [ADR-017](../../architecture/adr-017-outro-mundo-anexado.md) (nova; substitui o como da [ADR-015](../../architecture/adr-015-outro-mundo-sangrento.md)); [pz-api-notes §16.6](../../architecture/pz-api-notes.md#166-anexado-ao-objeto-sprint-0023) |
| Base | [sprint 0021](../sprint-0021-outro-mundo-ajustes/README.md) (chão por `IsoMarker`, 4 tiles apagados por personagem, paredes desligadas) |

## Objetivo

Na névoa, o sangue, a sujeira, a rachadura, o chão queimado (dentro) e o mato (fora) do Outro Mundo
saem presos ao chão e às paredes de verdade, como a erosão do jogo: embaixo dos personagens, com a
luz e o recorte do jogo, sem buraco debaixo do jogador; as paredes voltam (trepadeira, rachadura,
sujeira, sangue); e nada disso fica no save.

Evidência do Johan (05/10/2026): o buraco limpo de 4 tiles debaixo do jogador (sprint 0021) ficou
visível no jogo e foi recusado; no console, `floor:addAttachedAnimSpriteByName("overlay_grime_floor_01_5")`
saiu embaixo do jogador e `wall:addAttachedAnimSpriteByName("f_wallvines_1_2")` funcionou.

## Critérios de aceite

- [x] **Causa e caminho com evidência** ([pz-api-notes §16.6](../../architecture/pz-api-notes.md#166-anexado-ao-objeto-sprint-0023)):
      `performRenderTiles` desenha o FBO do chunk (`renderOneChunk` 157: piso e anexos) antes de
      `renderPlayers` (241) e o `IsoMarker` em 784; `addAttachedAnimSpriteByName` não cria sprite pra
      nome desconhecido e não marca hot save; `RemoveAttachedAnim(i)` desloca e devolve a instância
      pro pool; o anexo é cortado com a parede (`CutawayAttachedModifier`) e apagado com o prédio
      (`isBlackedOutBuildingSquare`) — bytecode B42.21.
- [x] **Anexado ao piso e às paredes N/W**, exatamente o que a regra pede, dentro e fora —
      `overlays_attach_floor_and_walls`; só piso e parede simples (nada em `IsoThumpable`, porta,
      janela, batente, água) — `overlays_targets_only_plain_objects`; nome sem sprite não entra e
      nada explode — `overlays_missing_sprites`; sujeira mais leve (`SetAlpha`/`SetTargetAlpha`) —
      `overlays_grime_lighter`.
- [x] **Nunca tira anexo vanilla:** blend de grama em todo piso, trepadeira de erosão e sujeira do
      mapa sobrevivem a sair do raio, voltar, ação, save, densidade nova e fim da névoa —
      `overlays_vanilla_attachments_survive_every_path`; decalque do mapa com o **mesmo nome**, antes
      e depois do do mod na lista — `overlays_same_name_vanilla_decal_survives`; instância do mod que
      voltou pro pool e foi reusada por um blend novo — `overlays_pool_reuse_never_removes_vanilla`.
      Testes com mutação conferidos: comparar só a instância, ou só o nome, quebra um deles.
- [x] **Save:** depois do `OnSave` (antes do `IsoCell.save` gravar), nada do mod em objeto nenhum e o
      vanilla intacto — `overlays_on_save_nothing_ours`; volta igual na atualização seguinte, sem
      depender do `OnPostSave` (que só sai na saída do jogo, por bytecode) — `overlays_back_after_save`;
      save no meio do lote (enchendo ou esvaziando) — `overlays_save_mid_batch_clean`.
- [x] **Raio:** andando de carro (meio tile por tick, 80 tiles), nada do mod passa de 15 + 8 + o que
      o carro anda numa atualização (< 40, o chunk gravado está a ≥ 48); parado, de 16 —
      `overlays_leaving_radius_strips`; trocar de andar tira o andar velho —
      `overlays_other_floor_stripped`; teleporte e morte tiram tudo no tick —
      `overlays_jump_strips_now`, `overlays_death_strips_now`.
- [x] **Fim da névoa tira tudo**, em lotes de 80 alvos — `overlays_fog_end_strips_all`.
- [x] **Limpeza do vazado no carregamento:** `floors_burnt_01_*` anexado e fora do registro sai no
      `LoadGridsquare`, com e sem névoa, no piso e na parede; o vanilla do square fica; o nome
      vanilla vazado fica (custo da ADR-017) — `overlays_load_scrub_removes_own_prefix`.
      `floors_burnt_01_*` é o nome que só o mod anexa (bytecode: `CellLoader` troca o sprite do piso,
      não anexa; fogo e worldgen usam como piso) — `dressing_rules_own_prefix_only_burnt`.
- [x] **Ação do jogador** (`square`, `object`, `thumpable` na ação atual): o square do alvo fica
      limpo enquanto ela dura e volta depois; o personagem da ação não conta —
      `overlays_timed_action_holds_square`.
- [x] **Lista mexida por baixo** (pá, servidor): o que falta volta, sem duplicar —
      `overlays_reapply_after_list_wiped`; objeto trocado: o novo é vestido, o velho não é tocado —
      `overlays_reapply_after_object_replaced`.
- [x] **Nada pela rede:** nenhum comando, e o fake explode em `transmit*`, `RemoveAttachedAnims`,
      `AttachExistingAnim` — `overlays_never_touch_the_network`; inerte no dedicado —
      `overlays_inert_on_dedicated`.
- [x] **Conteúdo:** chão queimado em manchas (cheio no miolo) só dentro; mato e folha rasteiros só
      fora; trepadeira só em parede de fora — `dressing_rules_burnt_only_inside_plants_only_outside`,
      `dressing_rules_burnt_patches`, `dressing_rules_vines_only_outside`,
      `overlays_burnt_inside_plants_outside`; todo sprite de chão deitado no diamante (decalque) ou
      rasteiro (mato: ≥ 80% no diamante e ≤ 8 px acima), medido no pack por
      `scripts/audit_floor_sprites.py` (só leitura) — `dressing_rules_floor_pools_lie_on_floor`. Hash
      por square e período, sujeira sem xadrez, densidade e vermelha — suíte `dressing_rules_*` e
      `overlays_period_and_density_redraw`, `overlays_density_debounced`,
      `overlays_deterministic_and_stable_while_walking` (o que fica no raio não é refeito andando).
- [x] **Código morto fora:** `IsoMarker`, chão apagado debaixo de personagem, visibilidade por prédio
      e sombra, luz, fade, teto e raio efetivo, paredes por `RenderGhostTileColor` e os testes deles.
      Textos falam das paredes de novo — `translations_overlays_promise_floor_and_walls`.
- [x] Orçamento — `overlays_budget` (enchendo ≤ ~2000 chamadas e ~410 invalidações por atualização,
      parado ~165); tabela no [architecture/README.md](../../architecture/README.md#orçamento-por-sistema).
- [ ] Embaixo dos personagens, sem buraco, com a luz do lugar — **falta o jogo:** roteiro, passos 1–2.
- [ ] Paredes cortadas e telhado: o anexo some junto, sem laje preta; chão de dentro não aparece por
      cima do telhado — **falta o jogo:** passo 3.
- [ ] Mato anexado ao piso fica bem (sai antes do que está atrás dele) — **falta o jogo:** passo 1.
- [ ] Save + sair + voltar na névoa e depois dela: nada sobra — **falta o jogo:** passos 4–5.
- [ ] Andar 100 tiles e voltar; ação num square vestido — **falta o jogo:** passos 6–7.
- [ ] MP — **falta o jogo:** passo 8.

`./run-tests.sh`: `total=707 passou=707 falhou=0` (Lua), `contraste total=4 passou=4 falhou=0`,
`build total=25 passou=25 falhou=0`.

## Roteiro in-game

**Antes:** `scripts/dev-sync.sh`, jogo em `-debug`, **save descartável** (o teste mexe no mapa do
save). Console em `~/.var/app/com.valvesoftware.Steam/Zomboid/console.txt`. Opções > Mods: "Sangue e
erosão na névoa" em 1.

1. **Névoa.** Na rua, perto de casas: `NOM_Debug.fog(true, true)`. **Esperado:** em ~1,5 s o chão em
   volta (até ~15 tiles) ganha poças e rastros de sangue, rachaduras, manchas de sujeira, mato e
   folhas rasteiros; as paredes de fora ganham sangue escorrido, sujeira, rachadura e trepadeira.
   `NOM_Debug.status()` com `chao=` e `paredes=` > 0. Nenhuma linha com `ERROR` e `NOM_FogOverlays`.
   Olhar o mato: **se** alguma planta aparecer por baixo de uma parede ou de um personagem que está
   atrás dela, registrar o nome (`d_plants_1_*`) — sai do pool.
2. **Embaixo dos personagens.** Andar em cima das poças e parar; um zumbi em pé numa poça.
   **Esperado:** o sangue fica **embaixo** dos pés e das pernas, sem nenhum buraco limpo em volta
   (era o defeito da 0021). De noite (`NOM.time(23)`): o sangue escurece com o lugar e a
   lanterna o clareia.
3. **Casa.** Entrar numa casa. **Esperado:** chão queimado em manchas nos cômodos (miolo carbonizado,
   borda marcada), sangue e sujeira; nas paredes de dentro, sangue, sujeira e rachadura (sem
   trepadeira). As paredes que o jogo corta somem **com** o que está nelas; nenhuma laje preta. Sair:
   o chão de dentro **não** aparece por cima do telhado.
4. **Save na névoa.** Com a névoa e o chão cheio: Esc > Salvar e sair. **Esperado no console:**
   `[NOM] outro mundo: N alvos limpos pro save` (N > 0). Carregar o save: na névoa, o chão e as
   paredes voltam iguais em ~1,5 s. Dormir numa cama até acordar (o jogo salva ao acordar): a mesma
   linha no console e o desenho volta.
5. **Depois da névoa.** `NOM_Debug.fog(false)`. **Esperado:** em ~1,5 s nada sobra (`chao=0
   paredes=0`). Salvar e sair, carregar, andar pela área que estava vestida: **nada** do Outro
   Mundo em lugar nenhum (o mapa normal tem seus próprios decalques; comparar com um print de antes
   da névoa).
6. **Andar.** Na névoa, andar (ou dirigir) 100 tiles em linha reta e voltar. **Esperado:** o desenho
   acompanha, sem buraco perto; voltando, o mesmo desenho no mesmo lugar. Depois `NOM_Debug.fog(false)`,
   salvar, sair, carregar com a névoa desligada e refazer o caminho: nada sobrou.
7. **Ação.** Na névoa, num square vestido: pegar um móvel (ou marretar uma parede de canto, ou cavar
   com a pá). **Esperado:** o square do alvo fica limpo enquanto a ação dura e volta quando ela
   acaba; a parede nova ou o chão novo não ficam com sangue depois do fim da névoa + save + carregar.
8. **MP** (servidor local + 2 clientes). Névoa: cada cliente vê o próprio desenho (em lugares
   diferentes). Um cliente desmonta um piso vestido. **Esperado:** depois do fim da névoa e de
   reiniciar o servidor, ninguém vê sangue que tenha ficado (o cliente nunca grava chunk e o mod não
   manda nada; o risco é o desmontar mandar a lista, coberto pelo passo de ação).
9. **(Opcional) Crash.** Na névoa, mexer em contêineres numa casa vestida (marca o chunk pra hot
   save), esperar ~1 min e matar o processo do jogo. Carregar com a névoa desligada. **Esperado:**
   `[NOM] outro mundo: K anexos vazados limpos em x,y,z` pro chão queimado; sangue, sujeira ou
   trepadeira que sobrar nesse chunk é o custo aceito da ADR-017 — registrar quanto.
10. **Custo.** Densidade 2 e névoa vermelha, andar 30 s entrando e saindo de casas. **Esperado:** sem
    queda de FPS perceptível contra a densidade 0 (cada lote invalida até ~400 níveis de chunk).

## Rulings do Claude

- **Só `floors_burnt_01_*` é do mod; o resto usa nomes vanilla.** Não há sprite vanilla de sangue,
  sujeira ou trepadeira que o jogo não anexe; fazer sprites próprios é escopo de arte (próxima
  sprint). Custo se errado: um crash logo depois de um hot save deixa sangue, sujeira, rachadura ou
  trepadeira no mapa daquele save, iguais aos do jogo e pra sempre; o queimado sai sozinho.
- **Não depender do `OnPostSave`.** Por bytecode ele só sai na saída do jogo; o save de acordar não
  o dispara. O desenho volta na atualização seguinte ao `OnSave`. Custo se errado: nenhum visível
  (no pior caso o desenho volta 10 ticks depois).
- **Raio 15 + folga 8 com retirada imediata além disso.** O lote de 80 não acompanha um carro (meio
  tile por tick). Custo se errado: o chão a mais de 15 tiles fica limpo (no zoom mais aberto, a borda
  da tela).
- **Sem fade e sem luz própria.** O alfa do anexo não refaz o FBO do chunk e a luz já vem do jogo.
  Custo se errado: o desenho surge e some em anéis, lote a lote, em ~1,5 s.
- **Sem regra de visibilidade por prédio.** O anexo é cortado e apagado com o objeto (bytecode).
  Custo se errado: chão de dentro por cima do telhado (passo 3).
- **Mato só rasteiro** (≥ 80% no diamante e ≤ 8 px acima do chão): o anexo do piso sai antes do que
  está atrás dele. Custo se errado: menos "erosão" lá fora; se nem esses ficarem bem, o mato sai.
- **Ação do jogador pela fila, sem remendar código vanilla.** Lê a ação atual a cada atualização e
  segura o square de todo campo que é square ou objeto do mapa. Custo se errado: uma ação que guarda
  o alvo só em coordenadas não segura o square; a marreta de canto no solo copiaria os anexos do mod
  pra parede nova (vai pro save).
- **A lista mexida volta a ganhar o que falta** (não tira o resto). Custo se errado: a trepadeira
  que o jogador arranca com a ação vanilla volta (o Outro Mundo cresce de novo).
- **`LoadGridsquare` limpa o queimado sempre, não só sem névoa:** square recém-carregado nunca tem
  anexo vivo do mod. Custo se errado: nenhum (o mod põe de novo na varredura).
- **Só o andar do jogador e o jogador 0 na tela dividida**, como antes.
- **Checkpoints datados de 05/10**, o dia do brief.

## Checkpoints

- **05/10/2026** — Sprint aberta: o buraco de 4 tiles recusado no jogo e o anexo confirmado pelo
  Johan. Bytecode: ordem do quadro, anexo e retirada (pool), `IsoObject.save`, `GameWindow.save`
  (`OnSave` antes do `IsoCell.save`; `OnPostSave` só na saída; save de acordar), `IsoChunk.Save` no
  cliente de MP, fila de gravação ao sair do mapa (≥ 48 tiles), hot save, quem anexa no vanilla
  (`floors_burnt_01_*` não). Auditoria do pack refeita pro anexo. Plano escrito.
- **05/10/2026** — Regras (queimado dentro, mato fora, trepadeira fora, pools medidos); cliente
  reescrito (registro, retirada só do nosso, `OnSave`, raio com folga, salto, morte, `LoadGridsquare`,
  ação, re-aplicação); mundo falso com anexos e pool. Testes com mutação. Textos. Docs: ADR-017,
  pz-api-notes §16.6, GDD, orçamento. Em teste.

## Aprendizados

- **`OnPostSave` não é "depois de todo save".** Só sai na saída do jogo (`GameWindow.exit`,
  `IngameState.updateInternal`); acordar no solo chama `GameWindow.save` sem ele. Quem tira algo no
  `OnSave` tem de pôr de volta por conta própria.
- **`IsoSpriteInstance` vem de um pool global.** `RemoveAttachedAnim` devolve a instância; o próximo
  anexo de qualquer objeto pode receber a mesma. Guardar só a referência não basta pra saber de quem
  ela é: confira também o nome.
- **`addAttachedAnimSpriteByName` com nome desconhecido não faz nada** (o `getSprite` do Lua, ao
  contrário, cria sprite vazio): dá pra saber se entrou pelo tamanho da lista.
- **O chunk que sai do mapa é gravado depois, noutra thread** (`ChunkSaveWorker`), e o hot save do
  solo grava na hora, sem evento. Pra algo local no objeto não ir pro disco, tire antes de o chunk
  chegar perto da borda do mapa carregado, não "quando ele sair".
- **Tabela do Kahlua é um `Map` do Java percorrido por iterador:** juntar e apagar depois, nunca
  apagar chave no meio do `pairs`.
- **A descrição do Workshop tem teto de 7900 bytes** (`build-workshop.sh`); a frase nova estourou por
  19 bytes e derrubou 21 testes do build de uma vez.

## Pendências que a próxima sprint herda

- Tudo do roteiro acima; em especial o mato anexado (passo 1), o telhado (passo 3) e o save (4–6).
- Sprites próprios do Outro Mundo (próxima sprint, arte do "Mundo Invertido"): com nomes só do mod,
  o `LoadGridsquare` passaria a limpar tudo que vazasse, não só o queimado.
- Medir no jogo o custo de ~400 invalidações de nível de chunk por lote; se pesar, baixar o
  `SCAN_BUDGET`.

### Limites conhecidos

- Crash depois de um hot save: decalques vanilla vazados ficam no mapa daquele save (ADR-017).
- Mesma instância do pool, mesmo nome, mesmo objeto: o mod tiraria a do vanilla (ADR-017).
- Ação que guarda o alvo só em coordenadas não segura o square.
- Só o andar do jogador; tela dividida montada pro jogador 0.

## Sessões

- 2026-10-05 — abd764e2-7a9a-416b-b9b3-1630ab9e761f — bytecode (anexo, save, chunk, hot save), plano, regras, cliente anexado com save seguro, mundo falso com anexos, textos, docs

## Checkpoint 2026-10-05 — teste no jogo (Johan)

Confirmado: decalque embaixo do pé sem buraco e com luz; chão de dentro não vaza sobre o telhado; save/sair/carregar durante a névoa sem sobra depois; FPS ok.
