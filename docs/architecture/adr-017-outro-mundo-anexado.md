# ADR-017 — Outro Mundo anexado ao piso e à parede, tirado antes de todo save

| Campo | Valor |
|-------|-------|
| Status | `accepted` |
| Data | 2026-10-05 |
| Substitui | o **como** da [ADR-015](adr-015-outro-mundo-sangrento.md) (decisões 3 e 4 e a emenda da 0021: `IsoMarker`, fantasma de parede, chão apagado debaixo de personagem, visibilidade por prédio). A regra pura (decisões 1, 2 e 5 sem o teto) continua |
| Emenda | [ADR-007](adr-007-sem-rosto-e-atmosfera-local.md): "nada no mapa" vira "nada no **save**" — o anexo é do objeto do mapa, mas só enquanto o jogo não grava |

## Contexto

O `IsoMarker` sai depois dos personagens (`performRenderTiles` 784 contra `renderPlayers` 241):
pinta por cima de quem está no tile de trás. A sprint 0021 apagava 4 tiles debaixo de cada
personagem; no jogo, o buraco limpo andando com o jogador foi recusado pelo Johan. As paredes
estavam desligadas (o fantasma não tem profundidade).

O jogo tem o caminho certo: a erosão vanilla **anexa** o sprite ao `IsoObject` (piso, parede), e o
FBO do chunk o desenha junto com o objeto (`renderOneChunk` 157, antes dos personagens), com a luz,
o recorte de parede e o prédio apagado. O Johan confirmou no jogo (05/10): sujeira anexada ao piso
sai embaixo do jogador; trepadeira anexada à parede funciona.

O preço: `IsoObject.save` grava a lista de anexos inteira. Tudo que estiver anexado quando o chunk
for gravado vira parte do mapa daquele save, pra sempre. Evidência:
[pz-api-notes §16.6](pz-api-notes.md#166-anexado-ao-objeto-sprint-0023).

## Decisão

1. **Anexar** com `obj:addAttachedAnimSpriteByName(nome)` no piso (`sq:getFloor()`) e nas paredes
   N/W (`sq:getWall(north)`), só em objeto simples do mapa (não `IsoThumpable`, `IsoDoor`,
   `IsoWindow`; sem batente de porta/janela no lado; sem água). Nome sem sprite não faz nada no jogo
   (`IsoSprite.getSprite` volta nil): o mod só registra o que entrou.
2. **Registro** por alvo (square + `F`/`N`/`W`): objeto, square e cada instância que o mod pôs, com
   o nome. **Tirar = só essas**: de trás pra frente, a mesma instância **e** o mesmo nome,
   `RemoveAttachedAnim(i)`. Nunca `RemoveAttachedAnims()` (apaga blend e decalque do mapa), nunca
   `AttachExistingAnim` (mexe no `IsoSprite` compartilhado), nunca `transmit*`.
3. **Save:**
   - `OnSave` (sai antes do `IsoCell.save` gravar os chunks, na mesma thread): tira tudo, sem lote.
     A atualização seguinte põe de volta. O mod **não** depende do `OnPostSave` (só sai na saída do
     jogo; o save de acordar não o dispara).
   - **Raio pela tela** (emenda da sprint 0034; era 15 fixo): o canto da tela do jogador 0 mais
     longe, no chão, + 2, entre 15 e 30, relido a cada atualização. O que sai dele sai em lotes de
     80 alvos; além de 30 + 8 sai na hora, qualquer zoom, **no tick** em que o jogador passa de 2
     tiles desde o último corte (review final da 0034: a margem não depende do FPS). O chunk que
     sai do mapa (e vai pra fila de gravação) está a ≥ 48 tiles; com o carro a 2 tiles por tick
     (15 FPS), o pior caso é 38 + 2 + 2 + 1 = 43. Evidência: pz-api-notes §16.6 (raio pela tela).
   - **Morte**: tudo sai no tick. **Teleporte**: cai no mesmo corte (tudo passa de 38). O salto
     de 8 tiles num tick (que tirava tudo) saiu: um engasgo de FPS no carro o disparava.
   - **Fim da névoa**: tudo sai em lotes de 80 por atualização (sem fade). Desde a sprint 0035,
     em manchas (item 9).
   - **Hot save** (solo, sem evento): o chunk pode ser gravado com anexos do mod; isso só fica no
     disco se o jogo cair antes do próximo save daquele chunk (que sai limpo). Coberto pelo item 5.
   - Cliente de MP: o chunk nunca é gravado (`IsoChunk.Save` sai com `GameClient.client`) e o mod
     não manda nada; o risco é o vanilla do cliente mandar a lista (item 6).
4. **Lista mexida por baixo** (pá, erosão, pacote do servidor no MP): conferida em rodízio (20 alvos
   por atualização). Objeto trocado: o velho é esquecido (fora do mundo, não se toca nele), o novo é
   vestido de novo. Instância do mod que sumiu: só ela é posta de novo.
5. **Dono do nome.** Os sprites de sangue, sujeira, rachadura, trepadeira e paredes são **vanilla**
   e o mapa/a erosão também os anexam: um anexo com esses nomes que o mod não registrou é
   indistinguível de um do jogo. **Só `floors_burnt_01_*` é do mod** (ninguém no vanilla anexa: o
   `CellLoader` troca o sprite do piso, não anexa; o fogo e o worldgen usam como piso). O
   `LoadGridsquare` tira todo `floors_burnt_01_*` anexado que não está no registro, com névoa ou
   sem (um square recém-carregado nunca tem anexo vivo do mod). Os nomes vanilla vazados ficam.
   Pichação e mensagem (emenda da sprint 0034) são `WallOverlay` com `attachedW/N`: o mapa as
   anexa à parede (`CellLoader`), então **não** são do mod. O lixo (`trash_01_*`) ficou de fora,
   não virou prefixo próprio: a coleta vanilla lê os nomes anexados ao objeto e o lixo é afinidade
   dela (pz-api-notes §16.6).
6. **Ação do jogador**: a ação atual (`ISTimedActionQueue.queues[jogador].queue[1]`, lida a cada
   atualização) segura limpo o square de todo campo dela que é square ou objeto do mapa (não
   personagem). Cobre a marreta que copia os anexos pra parede de canto nova no solo, a pá, pegar
   móvel, desmontar piso (que no MP manda a lista pro servidor). Sem remendo de código vanilla.
7. **Conteúdo:** chão queimado (`floors_burnt_01_*`, em manchas, cheio no miolo) só em square de
   dentro; mato e folha rasteiros só fora; trepadeira só em parede de square de fora. A
   regra pura continua por square e período (ADR-006): andar e voltar dá o mesmo desenho.
   **Sem sangue no chão (emenda da sprint 0034):** o Johan testou e as poças e rastros pareciam
   "jogo dos anos 2000 com textura ruim". Saem as poças, os rastros e o respingo; o chão fica com
   queimado ou mato, rachadura e sujeira (`MAX_LAYERS` = 2, mais a sujeira à parte). O sangue fica
   só na parede, dentro e fora. Na densidade 1 o chão vestido cai de ~82% pra ~66%.
   **Casa destruída (emenda da sprint 0034, pedido do Johan: "apagadas, acabadas, sujas,
   pichadas"):**
   - Parede de dentro: a 1ª camada quase sempre (`WALL_IN` 1, presa em 0,95; sorteio sujeira
     0,4, rachadura 0,3, sangue 0,3). Depois, até mais duas de outro tipo (`WALL_IN_2` 0,5,
     `WALL_IN_3` 0,25, × densidade) e a peça de pichação ou mensagem em cima, até `WALL_LAYERS` = 3.
     A ordem, de baixo pra cima: rachadura, sujeira, sangue, escrita.
   - Parede de fora: continua com uma camada, a peça de pichação do trecho ou o sorteio de antes
     (sangue manda).
   - Pichação e mensagem são desenhos de 1 a 5 paredes que o pack corta em peças de um tile. A
     fileira de paredes vai em trechos de 6 (`RUN_SLOT`), e um trecho pode ter **um desenho
     inteiro**, na ordem da tela.
   - O tipo e o desenho do trecho não dependem de dentro/fora; só a chance de aparecer depende:
     pichação 0,45 fora e 0,35 dentro, mensagem 0,15 fora e 0,6 dentro, × densidade. Uma fileira
     que cruza dentro/fora perde peças, mas nunca emenda dois desenhos.
8. **Sai** o que só existia por causa do marcador: chão apagado debaixo de personagem, visibilidade
   por prédio e sombra de prédio (o anexo é cortado e apagado com o objeto), luz relida (o chunk tem
   a luz), fade (alfa do anexo não refaz o FBO; o anexo surge e some com o lote), teto e raio
   efetivo, `RenderGhostTileColor`.
9. **Revelação em manchas (emenda da sprint 0035, transição descascando):**
   - Quando a névoa abre ao vivo (a borda do `on` chega com a fuga correndo), cada square espera
     `NOM_DressingRules.reveal` × 6 s reais antes de ser vestido. O que espera fica num pendente
     barato, fora do lote de 80.
   - No fim da névoa, cada alvo sai na vez dele pelo mesmo ruído, ao contrário, ao longo de 4 s.
     Continua no lote de 80.
   - Quem carrega o save com névoa, entra no MP no meio ou teleporta não espera.
   - É só visual. O `OnSave`, a morte e o corte a 38 tiles continuam tirando na hora, no meio da
     retirada também. O que espera ainda não foi anexado, então não tem nada pra vazar.

## Consequências

- O Outro Mundo fica embaixo dos personagens, com a luz e o recorte do jogo; as paredes voltam.
- **Custo do vazamento (se der errado):** um crash depois de um hot save deixa no mapa daquele save
  os decalques vanilla do mod que estavam no chunk (sujeira, rachadura, trepadeira, sangue de
  parede; até a sprint 0034, sangue de chão também). Ficam pra sempre, iguais à erosão e ao sangue do mapa. O chão queimado vazado sai
  sozinho no próximo carregamento. Janela: entre um hot save e o próximo save do mesmo chunk
  (sair do raio, sair do jogo, dormir).
- **Instância reusada:** se o vanilla tirar uma instância do mod (vai pro pool) e anexar outra com o
  **mesmo nome** no mesmo objeto e o pool devolver a mesma instância, o mod a tiraria depois. Com
  nome diferente (o caso real: blend novo depois da pá) ela fica. Aceito: exige mesmo objeto, mesmo
  nome e a mesma instância do pool global.
- Ação que guarda o alvo fora dos campos da tabela da ação (só coordenadas, tabela aninhada) não
  segura o square; na marreta de canto no solo, a parede nova levaria os anexos do mod pro save.
- Sem fade: o desenho surge e some em anéis, lote a lote (~1,5 s pra encher ou esvaziar). Na
  abertura e no fim da névoa (0035), em manchas, ao longo de 6 s e 4 s.
- Só o andar do jogador; só o jogador 0 na tela dividida (os outros veem o mesmo mapa).
- Remover a trepadeira do mod com a ação vanilla "remover trepadeira" funciona, e ela volta
  (o rodízio põe de novo o que falta): o Outro Mundo cresce de novo.
- Custo novo: enchendo, ~2000 chamadas Java e ~410 invalidações de nível de chunk por atualização
  (umas 9 atualizações; no raio 30 da 0034, até 36); parado, ~165; `LoadGridsquare`, ~3–7
  chamadas por square carregado.
- Casa destruída (0034): fora, quase igual (~2060 chamadas, ~417 invalidações). Na casa de
  estresse do teste (parede N e W em todo square, densidade 3,2), o enchimento vai de ~1980 pra
  ~2360 chamadas e de 387 pra 656 invalidações por atualização (teto teórico: 80 squares × 11
  anexos). Num lote, uma casa de verdade tem bem menos paredes. O vazamento de um crash depois do
  hot save também pode levar pichação e mensagem (vanilla, ficam como as do mapa).
