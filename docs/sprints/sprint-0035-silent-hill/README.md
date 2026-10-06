# Sprint 0035 — Outro Mundo estilo Silent Hill

| Campo | Valor |
|-------|-------|
| Status | em teste |
| Branch | `sprint/0035-silent-hill` |
| Plano | [plan.md](plan.md) |
| Spike | [spike-sprite-proprio.md](spike-sprite-proprio.md) (sprite próprio anexado na erosão) |
| GDD | [atmosphere.md](../../gdd/atmosphere.md), [art-direction.md](../../gdd/art-direction.md) |
| ADR | [ADR-018](../../architecture/adr-018-sprite-proprio-em-runtime.md) (sprite próprio de runtime), [ADR-017](../../architecture/adr-017-outro-mundo-anexado.md) (emenda da 0035: teto de custo do carro, margem por tick) |
| Spec | [modelo novo](../../superpowers/specs/2026-10-06-modelo-novo-design.md) |
| API | [pz-api-notes §25](../../architecture/pz-api-notes.md#25-lascas-do-outro-mundo-sprint-0035) (lascas), [§26](../../architecture/pz-api-notes.md#26-sprite-próprio-em-runtime-texturas-do-outro-mundo-sprint-0035) (sprite próprio em runtime) |

## Objetivo

Quando a névoa abre, o mundo **descasca** e vira o Outro Mundo do Silent Hill: a erosão se espalha em
manchas, lascas de tinta e cinza sobem do chão e das paredes, a tela ondula uns segundos e o chão e as
paredes ganham tinta descascando, ferrugem escorrendo e grade metálica. Tudo continua sendo visual
local do cliente (ADR-005, ADR-017).

## O que entrou

- **Lascas e cinza subindo** (Tarefa 1, `shared/NOM_FlakeRules.lua`, `client/NOM_Flakes.lua`): saem do
  que a erosão vestiu, até 14 tiles do jogador, com peso 3 pra parede. Sobem devagar, derivam com um
  vento leve, giram e somem em 3 a 7 s. Até 160 vivas, nascendo a 14/s vezes a densidade do Outro
  Mundo e a intensidade dos efeitos de tela (no máximo 48/s). Na vermelha a lasca fica mais escura e
  avermelhada. Texturas próprias `NOM_Lascas.png` (sprite sheet de 8 quadros, borda serrilhada, tinta
  velha, ferrugem) e `NOM_Cinza.png`, pelo `scripts/gen_textures.py`. Sem profundidade, como as brasas.
- **Transição descascando** (Tarefa 2, `NOM_DressingRules.reveal`, `client/NOM_FogOverlays.lua`):
  - ao abrir, cada square espera um atraso pelo ruído (manchas de 6 tiles) ao longo de **6 s**, e
    solta 2 lascas quando é vestido;
  - ao fechar, os squares saem pelo mesmo ruído em **4 s**, o último a abrir saindo primeiro;
  - quem carrega o save com névoa, entra no MP no meio ou teleporta vê o mundo já virado, sem atraso;
  - o `OnSave`, a morte e o corte duro a 38 tiles continuam tirando tudo na hora.
- **Tontura na transição** (Tarefa 3, `NOM_ScreenFxRules.dizzy`, `client/NOM_ScreenFx.lua`, mod2):
  ~5 s começando com a revelação ao vivo (sobe em 0,6 s, segura 1,4 s, desce). Com o shader, a cena
  ondula, desdobra numa imagem dupla leve e turva; sem shader, a vinheta pulsa e a tela escurece um
  pouco. Opção nova **"Tontura na transição" (`Dizzy`), ligada por padrão**, em Opções > Mods,
  dependente dos efeitos de tela. Quem entra no meio da névoa não tem tontura.
- **Borda da tela ao andar** (Tarefa 5c): a varredura lembra o que já viu (`seen`) e não recomeça a
  cada 8 tiles. Andando a 3 tiles/s, a faixa de 25–30 tiles foi de 28% pra 87% vestida; a 6 tiles/s,
  de 18% pra 67%. O corte esquece do `seen` o que passou do raio mais a folga, então a memória fica
  presa ao disco.
- **Teto de custo do carro** em área densa: no tick em que o corte tira alguma coisa, a atualização
  vai pro tick seguinte, e a 2 tiles por tick ela veste e retira 20 em vez de 80 (`LIGHT_DIV` = 4). O
  pior tick no estresse caiu de ~3900 pra ~2250 chamadas ao Java (teto do teste: 2500).
- **50 texturas próprias Silent Hill** (Tarefa 4, `scripts/gen_tiles.py`, `client/NOM_OwnSprites.lua`):
  - PNG RGBA 128×256 em `mod/42/media/textures/NOM/OutroMundo/`, 5 variações por tipo e lado: chão
    `Grade`, `Ferrugem`, `Chapa`, `Tinta`; paredes W e N `Tinta`, `Ferrugem`, `Descasca`;
  - viram sprite em runtime (`getSprite` + `setName` + flags do lado) e são anexadas como os sprites
    vanilla; lista pura em `shared/NOM_OwnSpriteList.lua`, escrita pelo script;
  - o sorteio da branca favorece metal no chão (~1/3 do chão vestido) e tinta descascando na parede;
    a vermelha mantém o sangue de parede e ganha ferrugem; nada de sangue nem de vermelho no chão.
- **Debug:** `NOM.ownSprites()` diz quantas das 50 estão registradas e quais PNG faltam, com o botão
  "Texturas próprias no console" no `NOM.panel()`. Todo comando do `NOM.HELP` ganhou botão no painel
  (Tarefa 5b), e o teste `debug_panel_every_help_command_has_button` fica vermelho se faltar um.
- **Cobertura além da tela: medida e não feita** (Tarefa 5). Raios 30, 34, 36, 40 e 45 medidos no
  mundo falso. A margem do save (corte duro antes dos 48 tiles em que o chunk sai do mapa) só aceita
  raio + folga ≤ 42, o ganho na tela é pequeno em 1080p e nenhum raio dentro da margem cobre 1440p ou
  4K. Andando, quem limitava a borda era a varredura, não o raio (resolvido na 5c). O teste
  `overlays_save_margin_invariant` trava a margem.

## Decisões do Johan (2026-10-06)

- **Mais Silent Hill que Upside Down:** "paredes descamando, partículas saindo do chão, das paredes";
  ferrugem, tinta descascando, grade, lascas subindo.
- **Sprint própria logo depois da 0034:** a transição escondida e a tontura vieram da antiga 0036, e
  o equilíbrio passa a ser a 0036.
- **Sangue no chão não volta** (saiu na 0034).
- **Todo comando de debug ganha botão no `NOM.panel()`** (regra no `AGENTS.md`).
- **"Quero tela toda"** pra erosão andando: virou a Tarefa 5c.

O Johan deu autonomia pro resto. Decisões tomadas em nome dele, pra revisar no teste:

- **Não cobrir além da tela:** a margem do save manda (Tarefa 5).
- **Caminho 1b** (sprite de runtime) em vez de tile pack ([ADR-018](../../architecture/adr-018-sprite-proprio-em-runtime.md)).
- **A tinta da parede só desenha o buraco:** a tinta que fica é a própria parede do jogo, então o
  decalque serve em parede de qualquer cor.
- **Sem vermelho no chão:** a tinta de chão é amarelo industrial desbotado, pra não ser lida como sangue.
- **Preta fica pra 0038:** a regra só conhece branca e vermelha (sugestão: Descasca e Ferrugem
  escuras, sem Grade e sem sangue).
- **Tontura ligada por padrão**, com opção própria, presa à intensidade 1 (o slider em 2 não dobra).
- **Pesos do sorteio:** branca no chão com metal 0,4 (Grade 0,4, Ferrugem 0,25, Chapa 0,2, Tinta 0,15
  por painel de 4×4 tiles); parede de fora com tinta 0,35, ferrugem 0,25; parede de dentro com tinta
  0,45. Vermelha: ferrugem 0,25 no chão, sangue 0,4 na parede de fora.
- **Teto de custo do carro** (`LIGHT_DIV` = 4): trocar de desenho dirigindo tira o desenho velho mais
  devagar, 20 alvos por atualização.

## Critérios de aceite

- [ ] As lascas e a cinza se leem e sobem do chão e das paredes vestidas — roteiro, passo 2
- [ ] A erosão abre em manchas em ~6 s e recua em ~4 s, sem derrubar o FPS — roteiro, passos 2 e 8
- [ ] A tontura dura o bastante sem incomodar, e a opção desliga — roteiro, passo 3
- [ ] Grade, ferrugem, chapa e tinta aparecem nítidas, com profundidade certa — roteiro, passos 4 a 6
- [ ] Nada vaza pro save — roteiro, passo 7
- [ ] A borda da tela enche andando — roteiro, passo 8
- [x] Regras puras, cliente, texturas, lints e docs — testes verdes (`./run-tests.sh`: 1004 testes
  Lua, 9 de contraste, 11 das texturas do Outro Mundo, os do mod3 e 29 de build); **não** confirma
  nada no jogo

Marcar cada item sem evidência não vale: ao marcar, escrever como foi confirmado.

## Roteiro de teste no jogo

Solo, com `-debug`, jogo reiniciado depois do `scripts/dev-sync.sh`. Acompanhe o console com:

```bash
tail -F ~/.var/app/com.valvesoftware.Steam/Zomboid/console.txt | grep "\[NOM\]"
```

Abra o painel com `NOM.panel()` (ou Insert). Os nomes entre aspas abaixo são os botões dele; o
comando ao lado faz o mesmo no console. "Modo deus" (`NOM.godMode()`) ajuda a testar sem morrer.

1. **Texturas registradas.** Logo depois de carregar, "Texturas próprias no console"
   (`NOM.ownSprites()`).
   - Log: `[NOM] debug sprites próprios: 50 de 50 registrados` e nenhuma linha `debug sem textura`.
   - Se faltar alguma, o registro também avisa `[NOM] outro mundo: N texturas próprias faltando`.
2. **Transição descascando e lascas.** Num lugar com casas, "Sirene branca" (`NOM.setFog()`) e espere
   os 30 s da fuga.
   - A erosão abre em manchas, perto e longe ao mesmo tempo, em ~6 s, não toda de uma vez.
   - Cada mancha que abre solta lascas; depois disso lascas e cinza continuam subindo do chão e das
     paredes vestidas.
   - Conferir: a lasca (10–16 px no zoom 1) e a cinza (3–6 px) se leem? A rajada enche o teto de 160
     lascas cedo demais, ficando uma nuvem uniforme?
   - Anote o FPS durante a transição.
   - **Logo depois de carregar o save**, esta primeira névoa: alguma textura nossa sai vazia (buraco)
     no primeiro quadro?
3. **Tontura.** Na mesma abertura, a tela ondula e turva por ~5 s.
   - 5 s é longo? A ondulação "pula" em vez de correr lisa? A imagem dupla incomoda?
   - Sem o mod2, a vinheta pulsa e a tela escurece: incomoda demais?
   - Desligue "Tontura na transição" em Opções > Mods, "Fim da névoa" (`NOM.setEndFog()`) e "Branca
     já" (`NOM.setFog(true)`): sem tontura nenhuma. Religue depois.
   - "Branca já" com a névoa já aberta recomeça sem fuga: o mundo aparece já virado, sem atraso e sem
     tontura (mesmo caso de quem carrega o save no meio).
4. **Chão Silent Hill.** Com a névoa branca aberta, ande pela rua e por dentro de casas.
   - Grade, ferrugem, chapa e tinta lascada em painéis; cerca de 1/3 do chão vestido com metal. O peso
     está bom de olho?
   - A grade (vão com alfa 0,6) fica escura demais em piso escuro?
   - Fique em cima da grade e da ferrugem e puxe um zumbi ("Puxar zumbi", `NOM.getZombie()`): o
     decalque fica **embaixo** do jogador e do zumbi, nunca por cima.
   - Zoom de 0,5 a 2,5: a textura fica nítida, sem borrão nem serrilhado forte?
5. **Parede Silent Hill.** Paredes oeste (W), norte (N) e de canto, de fora e de dentro.
   - Tinta descascando (o buraco mostra demão velha e reboco ou chapa), Descasca (sobram ilhas da
     parede do jogo), ferrugem escorrendo.
   - O escorrido de ferrugem aparece de longe ou some?
   - A emenda rebitada da ferrugem, com o tracejado dos rebites, parece artificial?
   - O peso da tinta na parede está bom?
   - Passe atrás da casa com o recorte (cutaway) ligado: o decalque acompanha a parede, no lado certo
     no canto, sem passar por cima de personagem.
6. **Vermelha.** "Fim da névoa" e "Vermelha já" (`NOM.setRedFog(true)`).
   - Parede com sangue e ferrugem; chão com queimado, sujeira, rachadura e manchas de ferrugem, sem
     grade, chapa ou tinta e **sem sangue no chão**.
   - Lascas mais escuras e avermelhadas.
7. **Save limpo.** Com a névoa aberta e as texturas à vista, salve e saia pro menu, depois volte.
   - Log ao sair: `[NOM] outro mundo: N alvos limpos pro save`.
   - Ao voltar, nada sobrou do Outro Mundo antes de a névoa vestir de novo (nem sprite vanilla, nem
     textura nossa). Se aparecer `[NOM] outro mundo: N anexos vazados limpos em ...`, anote.
   - "Texturas próprias no console" de novo: 50 de 50 (o registro refaz a cada mundo).
8. **Borda da tela e FPS.** Com a névoa aberta e o zoom no máximo, ande em linha reta por uns 20 s.
   - A borda da tela vai enchendo enquanto você anda, sem ficar um quadrado vestido em volta.
   - Pegue um carro e dirija rápido por área densa de casas: anote se o FPS engasga mais que a pé.
   - "Fim da névoa": a erosão recua pro miolo das manchas em ~4 s, soltando poucas lascas. A
     retirada aparece antes de a névoa sumir?

### Pendências da 0034 pra conferir no mesmo teste

- **Congelamento da sirene** depois da correção `isLocal`: com "10 zumbis" (`NOM.spawn(10)`) e "Sirene
  branca", todos param virados pra você; no log
  `[NOM] sirene congelados=N andando=0 jogadores=1 ... pulados morto/remoto/jogo=0/0/0`, com `remoto` 0.
- **IA das variantes no solo**, com a névoa aberta: "Vira Estalador" (`NOM.turnZombie(1)`) não te vê
  a mais de alguns tiles se você ficar quieto; "Vira Carpideira" (`NOM.turnZombie(4)`) fica parada
  soluçando até ser acordada.
- **Chão sem sangue:** com metal no lugar, o chão ainda parece vazio?

## UNKNOWNs que só o jogo responde

- **Legibilidade das lascas** e da cinza, e se a rajada satura o teto de 160 cedo demais.
- **FPS** na transição, no zoom longe e de carro em área densa.
- **Tontura:** duração de 5 s, ondulação que "pula" (o `timer` do shader é inteiro, ~15 passos/s) e
  imagem dupla.
- **Textura vazia** na primeira névoa logo depois de carregar (carga assíncrona).
- **Nitidez** das texturas nossas no zoom 0,5 a 2,5 (se ficar ruim, o plano B é o tile pack, ADR-018).
- **Grade com alfa 0,6** em piso escuro.
- **Escorrido de ferrugem** (3–14% da parede) visível de longe.
- **Profundidade** na parede W, N e de canto, com e sem recorte.
- **Grade e ferrugem embaixo** do jogador e do zumbi.
- **Save:** nada vazado depois de sair e voltar com névoa.
- **Duração da transição:** 6 s pra abrir e 4 s pra fechar.
- **Pesos:** um terço de metal no chão e o peso da tinta na parede.
- **Emenda rebitada** da ferrugem de parede, que pode parecer artificial.

## Ajustes fáceis

| Onde | Constante | Efeito |
|---|---|---|
| `NOM_FlakeRules` | `MAX`, `RADIUS`, `RATE` | teto de lascas vivas, alcance das fontes e quantidade |
| `NOM_FogOverlays` | `REVEAL_MS`, `REVEAL_TAIL_MS`, `UNREVEAL_MS`, `IN_FLAKES`, `OUT_FLAKES` | duração da transição e rajada |
| `NOM_DressingRules` | `REVEAL_CELL`, `METAL`, `RUST`, pesos de parede | tamanho das manchas e peso de cada textura |
| `NOM_ScreenFxRules` | `DIZZY_MS`, `DIZZY_RISE_MS`, `DIZZY_HOLD_MS`, `DIZZY_VIGNETTE`, `DIZZY_DARK` | tontura |
| `NOM_FogOverlays` | `LIGHT_DIV`, `MOVE_TILES` | custo do carro e margem do corte |
| `scripts/gen_tiles.py` | desenho de cada tipo | regera as 50 texturas (mesma semente, mesmos bytes) |

## Decisões técnicas

- **Sprite de runtime (1b):** o anexo vazado tem ID 20000000 e é descartado no load, com ou sem o mod.
  O `setName` é obrigatório: sem ele o mod não acha o que pôs ([ADR-018](../../architecture/adr-018-sprite-proprio-em-runtime.md)).
- **Tontura no `darkness` do shader:** não havia canal livre; vai na parte inteira do `VarInfo.y`
  (pz-api-notes §15.4).
- **Revelação ao vivo** é a borda do `NOM_FogState.on` com a fuga correndo; carregar o save com névoa
  não conta como borda.
- **Lascas sem profundidade:** desenhadas no overlay de tela, como as brasas do Eco.
- **O raio fica em 30** com `SLACK` 8: cada tile tirado da folga sairia da proteção contra engasgo.

## Aprendizados

- O ruído de valor fica quase todo no meio: pra espalhar a revelação, ele é esticado de [0,25; 0,75]
  pra 0..1.
- Lembrar o que já viu só ajuda se o square visto não gastar o lote que vai ao Java.
- O pior tick do carro vinha de corte e atualização caindo no mesmo tick, não de nenhum dos dois
  sozinho.
- Textura com cor própria por cima de parede do jogo vira adesivo; desenhar só o buraco serve em
  qualquer parede.

## Limitações conhecidas

- Lascas sem profundidade: passam por cima de parede e personagem.
- Névoa preta sem visual próprio até a 0038.
- O Outro Mundo continua só no andar do jogador e só pro jogador 0 na tela dividida.
- Em 1440p e 4K com zoom longe a erosão não chega aos cantos (margem do save).

## Pendências que a próxima sprint herda

- Os UNKNOWNs acima.
- A 0036 (Equilíbrio: visão de ~4 tiles e vaguear) segue a fila da
  [spec](../../superpowers/specs/2026-10-06-modelo-novo-design.md).
- Visual da névoa preta na 0038.

## Sessões

- 2026-10-06 — Cursor, spike e tarefas 0 a 5c (subagentes).
- 2026-10-06 — Cursor, documentação da sprint (subagente).
