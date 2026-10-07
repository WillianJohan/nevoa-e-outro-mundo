# Sprint 0035: Outro Mundo estilo Silent Hill (plano de implementação)

> Para agentes: executar tarefa por tarefa (superpowers:subagent-driven-development). Code review só no fim da entrega (decisão do Johan, 2026-10-06).

**Objetivo:** quando a névoa abre, o mundo "descasca" e vira o Outro Mundo do Silent Hill:
- lascas e cinza saem do chão e das paredes e sobem;
- a erosão aparece espalhando em manchas, não toda de uma vez;
- a tela ondula uns segundos (tontura);
- o Outro Mundo ganha cara de Silent Hill: tinta descascando, ferrugem, grade metálica.

**Decisões do Johan (2026-10-06):**
- "Upside Down e Silent Hill... paredes descamando, partículas saindo do chão, das paredes". Escolheu **mais Silent Hill**: ferrugem, tinta descascando, grade, lascas subindo.
- Sprint própria logo depois da 0034, no lugar da antiga 0036 (que trazia a transição escondida e a tontura; elas vêm pra cá). O equilíbrio vira a 0036.
- Sangue no chão saiu na 0034 ("parecia textura ruim de jogo antigo"). Não volta.
- Johan saiu e deu autonomia: decisões de detalhe ficam registradas aqui e no README da sprint pra ele revisar no teste.

## Restrições globais

As do `AGENTS.md`:
- Kahlua;
- ADR-005 (o Outro Mundo é visual local do cliente, ADR-017);
- evidência de API;
- fakes fiéis;
- textos PTBR + EN;
- PT-BR com acento.

Texturas, sprites e partículas só pelos nossos `scripts/gen_*.py`. Nada de outros mods.

## Ordem

| # | Tarefa | Depende de |
|---|---|---|
| 0 | Spike: sprite próprio anexado na erosão | — |
| 1 | Lascas e cinza subindo do chão e das paredes | — |
| 2 | Transição descascando: erosão se espalha em manchas, com rajada de lascas | 1 |
| 3 | Tontura na transição (shader e sem shader), desligável | 2 |
| 4 | Texturas Silent Hill na erosão (ferrugem, tinta descascando, grade) | 0 |
| 5 | Cobertura além da tela (medir primeiro) | 4 |
| 5c | Borda ao andar: a varredura lembra o que já viu | 5 |
| 6 | Docs da sprint | todas |

---

### Tarefa 0: spike do sprite próprio

Saída: `spike-sprite-proprio.md` nesta pasta, com o caminho recomendado (tile pack nosso, sprite em runtime, ou plano B com sprites vanilla tingidos) e as evidências. A Tarefa 4 segue o que ele recomendar.

---

### Tarefa 1: lascas e cinza subindo

**Modelo:** igual às brasas do Eco (`client/NOM_Embers.lua` + `shared/NOM_EmberRules.lua`): regra pura em `shared/`, projeção e desenho no cliente pelo overlay de tela (`NOM_ScreenFx.extra`), sem profundidade (limite já aceito na spike-dissolve §D).

- **Regra pura nova** `shared/NOM_FlakeRules.lua`:
  - fontes: squares de chão e de parede perto do jogador (até ~14 tiles, dentro da tela); a parede solta mais que o chão;
  - cada lasca: nasce no square (no pé da parede, ou a meia altura dela), sobe devagar com deriva lateral de vento leve, gira (quadro do sprite sheet), some com fade; vida de 3 a 7 s;
  - dois tipos: **lasca** (pedaço de tinta, escuro com borda clara ou ferrugem) e **cinza** (ponto pequeno, mais numerosa);
  - teto de partículas vivas (`MAX` ~160) e de nascimentos por segundo; densidade escalada pela densidade da névoa e pela opção de intensidade do overlay;
  - névoa vermelha: lasca mais escura e borda avermelhada; preta fica pra 0038 (ponto único `R.palette(kind)`).
  - Determinismo não é preciso (é atmosfera local), mas a regra recebe o rand por parâmetro pra ser testável.
- **Cliente** `client/NOM_Flakes.lua`: projeta com `isoToScreenX/Y` e zoom como o `NOM_Embers`, desenha com `drawTexture` com cor/alfa; registra em `NOM_ScreenFx.extra`. Liga com `NOM_FogState.on` (Outro Mundo), não na fuga. Respeita o toggle `FogOverlays` e a opção de efeitos.
- **Textura:** `scripts/gen_textures.py` gera `NOM/NOM_Lascas.png` (sprite sheet: 8 quadros de lasca girando, 4 formatos; refeita orgânica depois da prévia parecer adesivo: contorno serrilhado, tinta velha, fio claro falhado, ferrugem dessaturada) e `NOM/NOM_Cinza.png`. Commitar os PNG e atualizar a lista do script.
- **Fontes de parede:** use o que o `NOM_FogOverlays` já sabe das paredes vestidas (registro dele) ou um teste barato por square; sem varrer o mapa todo por quadro.
- **Custo:** teto de chamadas por quadro medido em teste, como o do `NOM_FogOverlays`.

- [x] Testes que falham (regra: teto, vida, subida, deriva, quadros, paleta por névoa, densidade 0 = nada; cliente: liga com `on`, não com `rising`, para no fim, respeita toggle).
- [x] Implementar, gerar texturas, `./run-tests.sh` verde, commit.

**Feito (2026-10-06).** O que saiu diferente ou foi decidido no caminho:
- **Fontes:** o registro do `NOM_FogOverlays` (`NOM_FogOverlays.targets()`, só Lua), relido 1 vez por segundo e filtrado na regra (`R.sources`: andar do jogador, até `RADIUS` = 14 tiles, peso 3 pra parede). Só solta lasca o que a erosão vestiu: com o Outro Mundo desligado no sandbox ou densidade 0 não há fonte.
- **Densidade:** `R.rate(densidade, intensidade)` = 14/s × `NOM_DressingRules.density` (a opção de densidade do Outro Mundo, × 1,6 na vermelha) × `NOM_ScreenFxOptions.intensity()` (0 com os efeitos de tela desligados), presa em 48/s; teto de 160 vivas. O que não cabe no teto se perde (não acumula pra depois).
- **Rajada pra Tarefa 2:** `NOM_Flakes.burst(x, y, z, kind, n)` (`R.burst`), devolve quantas nasceram, respeita o teto.
- **Desenho:** o sprite sheet é recortado com `drawSubTexture` (recorte em pixels da textura, pz-api-notes §25); sempre com cor, porque sem `r` o vanilla desenha o sheet inteiro. A cinza é uma textura própria com `drawTextureScaled`. As texturas já vêm coloridas (tinta escura, borda clara ou ferrugem, verso ferrugem) e a paleta multiplica: branca quase neutra, vermelha mais escura e avermelhada (`R.palette("white"|"red")`; a preta da 0038 entra ali).
- **Projeção:** `isoToScreenX/Y` é afim no quadro (bytecode, §25): 4 pontos por quadro (8 chamadas) dão a base e cada lasca sai em Lua, em vez de 2 chamadas por lasca. Fora da tela não vai ao Java.
- **Sorteio:** o Kahlua não tem `math.random`; `R.rng(semente)` (Park–Miller), semeado com `getTimestampMs()`.
- **Custo medido** (`flakes_budget`, vermelha, densidade e intensidade 2): até 160 vivas, pior quadro ~175 idas ao Java (até 20 de base + 1 por lasca na tela). Sem névoa e sem lasca: 0.
- **Pra ver no jogo:** legibilidade do tamanho (lasca 10–16 px, cinza 3–6 px no zoom 1), a quantidade com o padrão, e as lascas passando por cima de parede e personagem (sem profundidade, como as brasas).

---

### Tarefa 2: transição descascando

**Hoje:** quando a névoa abre (`on`), o `NOM_FogOverlays` veste do perto pro longe com orçamento por tick. Quando acaba, tira tudo.

**Novo:**
- **Abrir:** cada square ganha um atraso de revelação pelo ruído (`R.reveal(x, y, period)` em `NOM_DressingRules`, 0..1) vezes `REVEAL_MS` (~6 s reais). O square só é vestido depois do atraso: a erosão se espalha em manchas, como tinta descascando.
- **Rajada:** quando um square é revelado, ele solta algumas lascas a mais (Tarefa 1), limitadas pelo teto.
- **Fechar:** no fim da névoa, o contrário: os squares saem pelo mesmo ruído ao longo de `UNREVEAL_MS` (~4 s), soltando poucas lascas. Atenção ao save: o `OnSave` continua tirando tudo na hora (ADR-017); a retirada em manchas é só visual quando não há save.
- Quem entra no meio da névoa, ou o jogador que teleporta: sem atraso (o mundo já está virado).
- A margem do save (corte a 38 tiles a cada 2 tiles andados, 0034) não muda.

- [x] Testes que falham (atraso pelo ruído dentro da faixa; nada vestido antes do atraso; tudo vestido depois de `REVEAL_MS`; entrada no meio sem atraso; fim em manchas; save tira tudo na hora; rajada respeita o teto).
- [x] Implementar, `./run-tests.sh` verde, commit.

**Feito (2026-10-06).** O que foi decidido no caminho:
- **Ruído:** `R.reveal(x, y, z, period)` em `NOM_DressingRules`, no mesmo ruído de valor da sujeira, numa rede de 6 tiles (`REVEAL_CELL`). O ruído de valor fica quase todo no meio, então ele é esticado de [0,25; 0,75] pra 0..1, com 12% de sorteio por square (borda irregular). Fica bem espalhado: ~22% abre no primeiro décimo do tempo e ~14% no último.
- **"Ao vivo":** a borda `false → true` do `NOM_FogState.on` (`onChange`) que chega **com a fuga correndo** (`NOM_FogState.rising`). No solo o `NOM_FogEvent.begin` liga a névoa antes de descer a subida; no MP o comando `fog` faz o `set` antes do `dropRising`. Carregar o save com névoa (o primeiro `OnClimateTick` liga a flag e parece uma borda) e entrar no MP no meio (`fogState`) chegam sem a fuga: sem atraso. "Primeiro estado do cliente" não serviria: no solo, carregar sem névoa e ver a névoa abrir depois também é a primeira chamada do `set`.
- **Custo:** o square cuja vez não chegou vai pra um pendente por fatia de 200 ms (`BUCKET_MS`) e sai de lá sozinho quando a fatia vence. Não gasta o `SCAN_BUDGET`, e a volta olha até 4× o lote (`LOOK_MULT`) só em Lua. Cada square passa pelo ruído uma vez: no raio 30, 2821 squares, no máximo 320 por atualização. Java no pior lote revelando (zoom 2,5): 1337 chamadas e 216 invalidações por atualização, abaixo do enchimento sem transição (~1950). Fora da janela, a varredura é a de antes.
- **Janela:** `REVEAL_MS` = 6 s, mais 2 s de folga (`REVEAL_TAIL_MS`) pro que o lote atrasou. Depois disso o que ainda espera volta pra varredura sem atraso.
- **Rajada:** cada alvo vestido na janela pede 2 lascas (`IN_FLAKES`) ao `NOM_Flakes.burst`, que respeita o teto (160). Nada com os efeitos de tela desligados (intensidade 0). `NOM_Flakes.lua` não mudou.
- **Fechar:** cada alvo sai depois de (1 − ruído) × `UNREVEAL_MS` (4 s): o último a abrir sai primeiro e a erosão recua pro miolo das manchas. Continua no lote de 80 por atualização, com até 6 lascas por atualização (`OUT_FLAKES`). O `OnSave`, a morte e o corte duro a 38 tiles tiram na hora, como antes.
- **Teleporte:** na janela, um tick que anda mais de 38 tiles (nenhum carro faz isso) fecha a janela: o lugar novo sai sem atraso. O sinal da tontura continua.
- **Sinal pra Tarefa 3:** `NOM_FogOverlays.revealStartedAt()` (hora da borda ao vivo, até o fim da névoa; nil pra quem entrou no meio), `NOM_FogOverlays.onReveal(fn)` (chamado uma vez na borda, com a hora) e `NOM_FogOverlays.revealing()` (a janela está aberta). Saem mesmo com o Outro Mundo desligado no sandbox: é o sinal da transição, não do desenho.
- **Pra ver no jogo:** se 6 s ficou longo ou curto, o tamanho das manchas (6 tiles), se a rajada satura o teto cedo demais (a cinza nasce junto) e se a retirada de 4 s aparece antes de a névoa sumir.

---

### Tarefa 3: tontura

- ~5 s reais começando com a revelação, por jogador local.
- **Com o shader (mod2):** a imagem ondula e turva. Procure um canal livre no `screen.frag` (hoje: `SearchMode.x/y`, `ParamInfo.w`, `VarInfo.y`; o gradiente marca o canal como nosso). Se não houver canal livre limpo, codifique a tontura junto de outro canal (documente a escolha). Evidência do que o jogo manda em cada uniform (bytecode `WeatherShader`).
- **Sem shader:** a vinheta pulsa e a tela escurece um pouco (`NOM_ScreenFx`).
- **Opção:** desligável em Opções > Mods (`NOM_ScreenFxOptions`), ligada por padrão. Texto PTBR + EN.
- Curva pura (`NOM_ScreenFxRules.dizzy(t)`), testada.

- [x] Testes que falham (curva; liga na revelação; não liga pra quem entra no meio; opção desligada = nada).
- [x] Implementar, `./run-tests.sh` verde, commit.

**Feito (2026-10-06).** O que foi decidido no caminho:
- **Sinal:** `NOM_FogOverlays.revealStartedAt()`, lido no quadro pelo `NOM_ScreenFx.dizzy(now)` (só Lua, sem ida ao Java). Quem entra no meio não tem o sinal e não tem tontura. Não usa o `onReveal`: a hora basta e o `NOM_ScreenFx` não precisa carregar o `NOM_FogOverlays` (sem ele, sem tontura).
- **Curva:** `NOM_ScreenFxRules.dizzy(t)`, sobe em 0,6 s (`DIZZY_RISE_MS`, smoothstep), segura 1,4 s (`DIZZY_HOLD_MS`) e desce até 5 s (`DIZZY_MS`). `R.dizzyLevel(t, i)` multiplica pela intensidade dos efeitos presa em 1: o slider reduz a tontura, mas o 2 não dobra (tontura incomoda).
- **Opção:** "Tontura na transição" (`Dizzy`, ligada), sub-opção dos efeitos de tela: com `ScreenFx` desligado ou intensidade 0, nada. Não depende do sandbox `FogOverlays` nem do `FogVignette` (decisão: a tontura segue a própria opção).
- **Sem shader:** a vinheta soma um pulso (`DIZZY_VIGNETTE` = 0,35, ciclo de 1,1 s) e uma camada preta (`NOM_White` tingida, `DIZZY_DARK` = 0,18) escurece a tela. +1 desenho por quadro; pior quadro 12 idas ao Java, o teto da névoa.
- **Com shader:** não havia canal livre (os 5 floats que o Lua alcança estão em uso; `VarInfo.z/w` o jogo nunca escreve). A tontura vai na **parte inteira do `darkness` (`VarInfo.y`)**: `pulso (0..2) + 4·round(tontura·256)`; o shader tira com `floor(v/4)`. Ninguém além do `WeatherShader` lê esse float, e o jogo não o prende (pz-api-notes §15.4). A cena ondula (ondas largas e um balanço lentos), desdobra numa imagem dupla leve (35%, deslocada ~1% da tela) e turva (`nomSoft` 0,6). Não passa pelo `DrunkFactor`. O canal é tomado só pela tontura também com o sandbox `FogVignette` desligado, como o bloom, e solta zerado.
- **Pra ver no jogo:** se 5 s é longo; se a ondulação "pula" (o `timer` do shader é inteiro, ~15 passos/s com o FPS travado em 60 ou mais: a fase é lenta, ~2 px por passo); se a imagem dupla e o escuro sem shader incomodam demais.

---

### Tarefa 4: texturas Silent Hill na erosão

Segue o caminho do spike.

- `scripts/gen_textures.py` (ou um `gen_tiles.py` novo) gera, por script nosso:
  - **parede (N e W):** tinta descascando em placas (manchas claras soltando, fundo escuro), ferrugem escorrendo, mancha de óxido;
  - **chão:** grade metálica enferrujada (losango no formato do tile), placas de ferrugem, tinta lascada;
  - várias variações de cada, sem padrão repetido visível.
- `NOM_DressingRules`: sets novos e o sorteio passa a favorecer o visual Silent Hill na branca; a vermelha mantém o sangue de parede e ganha ferrugem; nada de sangue no chão.
- O prefixo de limpeza (`OWN_PREFIX`) e o `LoadGridsquare` passam a reconhecer os nomes nossos.
- Teste de auditoria das texturas novas (cobertura, lado da parede), como `tests/floor_sprites.lua` e `tests/wall_sprites.lua`.

Dividida em duas: **4a** gera as texturas e a lista; **4b** liga na erosão (`NOM_OwnSprites.ensure`, `NOM_DressingRules`, `OWN_PREFIX`, fake do `getSprite`).

- [x] **4a:** testes que falham, gerar as texturas e a lista, `./run-tests.sh` verde, commit.
- [x] **4b:** testes que falham, integrar na erosão, `./run-tests.sh` verde, commit.

**4a feita (2026-10-06).** O que saiu e o que foi decidido:
- **Script novo** `scripts/gen_tiles.py` (não o `gen_textures.py`): rodar de novo não sorteia nenhuma outra textura do mod. Semente fixa, gerador por textura; duas rodadas dão os mesmos bytes.
- **50 PNG** em `mod/42/media/textures/NOM/OutroMundo/NOM_OM_<tipo>_<lado>_<nn>.png`, 5 variações por tipo e lado, RGBA 128×256, quadro inteiro (~1 MB no total):
  - chão (`F`): `Grade`, `Ferrugem`, `Chapa`, `Tinta`;
  - paredes (`W` e `N`): `Tinta`, `Ferrugem`, `Descasca`.
- **Como é desenhado:** cada textura é feita num plano (o chão visto de cima, a parede de frente), em px de tela com 4 amostras por px, e mapeada pro losango ou pra face com 4×4 sub-amostras por pixel. Na parede a vertical continua vertical e a horizontal segue ±x/2. Luz do alto à esquerda da tela em tudo (sombra embaixo à direita). O RGB do pixel transparente é a média dos vizinhos pesada pelo alfa; o que sobra fica com a média do desenho (o mipmap não puxa preto).
- **Decisões de desenho:**
  - **Tinta na parede:** a tinta que fica é a **parede do jogo** (transparente). O decalque só tem o buraco, com uma demão velha de outra cor e, no fundo, reboco ou chapa enferrujada. Por cima, a borda: fio escuro, luz no lado da luz, lascas enroladas com o avesso claro e sombra no buraco. Em volta, sujeira salpicada, craquelê e água escorrendo. Serve em parede de qualquer cor; a tinta nossa por cima viraria adesivo onde a cor não bate.
  - **Descasca:** o mesmo desenho com 68–80% do buraco: sobram ilhas da parede do jogo. As bordas verticais do tile guardam tinta, pra emenda com o vizinho não ser um corte reto.
  - **Grade:** o vão é escuro com alfa ~0,6, então o chão do jogo aparece apagado por baixo. A grade faz sombra no vão e no chão em volta. Tem três desenhos: quadrados, losangos e barras. Duas variações têm o canto arrancado.
  - **Ferrugem na parede:** escorridos paramétricos que afinam e apagam, com uma cortina lavada que abre em leque, saindo de parafusos, de uma emenda rebitada ou do alto. Ganharam bolhas de ferrugem em cacho. A mancha de óxido com contorno lia como adesivo e saiu.
  - **Sem vermelho no chão:** a tinta vermelha-sangue virou amarelo industrial desbotado, pra não ser lida como o sangue que saiu na 0034.
- **Lista:** `shared/NOM_OwnSpriteList.lua` (só dados, `DIR` + `SPRITES` com `name`, `side` e `kind`), escrita pelo script. O nome é o caminho completo, o mesmo do `getTexture`.
- **Testes:**
  - `tests/test_om_tiles.py`, no `run-tests.sh`: nomes e tipos por lado, 128×256 RGBA, nada fora da máscara do lado (geometria do spike reescrita no teste), cobertura parcial por tipo, Descasca cobrindo bem mais que Tinta, variações diferentes, saturação média < 0,42 com < 1% de laranja vivo, sem halo (o critério pega a borda preta), não chapado, a lista igual à do gerador e duas texturas regeradas iguais ao arquivo;
  - `tests/test_own_sprite_list.lua`: a lista carrega num ambiente vazio (pura), bate com os PNG nos dois sentidos, 128×256 RGBA pelo cabeçalho, lado e tipo de acordo com o nome, 4 a 6 por tipo e lado.
- **Medido:**
  - cobertura do lado: Grade 0,72–0,77; Chapa 0,31–0,63; Ferrugem 0,23–0,32 (chão) e 0,03–0,14 (parede); Tinta 0,29–0,40 (chão) e 0,14–0,30 (parede); Descasca 0,83–0,89;
  - saturação média até 0,39 (Ferrugem do chão); halo até 0,003.
- **Prévia:** `python3 scripts/gen_tiles.py --preview` monta `/tmp/om_tiles_preview.png`: um quarto 5×5 com paredes W e N sobre chão e parede neutros, em escala de jogo e ampliado 2×, e a folha de todas as texturas.
- **Pra ver no jogo (4b):** a nitidez no zoom 0,5 a 2,5; se a grade com alfa 0,6 fica escura demais em piso escuro; e se o escorrido de ferrugem (3–14% da parede) aparece de longe.

**4b feita (2026-10-06).** O que saiu e o que foi decidido:
- **Registro:** `client/NOM_OwnSprites.lua` (`ensure`, `total`, `missing`). Por sprite: `getTexture` (nil: pula e loga uma vez), `getSprite`, `setName` e as flags do lado. Roda no `OnGameStart` e, preguiçoso, no primeiro `update` com névoa da sessão; o `OnMainMenuEnter` marca pra registrar de novo (o `namedMap` zera por mundo). Evidência na pz-api-notes §26.
- **Custo:** ~280 chamadas ao Java uma vez por sessão. O enchimento em regime ficou igual (1942 por atualização antes e depois; casa 2250 → 2240); o `[budget]` mostra ~2100 porque no mundo falso o registro cai na primeira atualização (ninguém dispara o `OnGameStart`).
- **Regra (`NOM_DressingRules`), agora com a cor** (`floor`/`wall` recebem `red`; o `NOM_FogOverlays` passa `NOM_FogState.red` e troca de cor redesenha, pelo `gen`):
  - **Branca, chão:** manchas de metal pelo ruído (`METAL` 0,4, até 0,45, rede de 5 tiles) e um tipo só por painel de 4×4 tiles: Grade 0,4, Ferrugem 0,25, Chapa 0,2, Tinta 0,15. Onde tem metal não vai rachadura de rua. Medido com densidade 1: 79% dos squares vestidos, ~34% com metal (Grade 13%, Ferrugem 9%, Chapa 7%, Tinta 5%). **Trocado pelo hotfix do chão** (abaixo da Tarefa 5c).
  - **Branca, parede de fora:** tinta 0,35 (Tinta ou, em 35%, Descasca), ferrugem 0,25, trepadeira 0,15, sangue 0,1, sujeira 0,1, rachadura 0,05.
  - **Branca, parede de dentro:** tinta 0,45, ferrugem 0,2, sujeira 0,2, rachadura 0,15 (camadas: tinta, ferrugem, rachadura, sujeira).
  - **Vermelha, chão:** o de antes (queimado, sujeira, rachadura), mais manchas de Ferrugem (`RUST` 0,25, até 0,35, rede de 4 tiles) por cima. Nada de Grade, Chapa ou Tinta, e nada de sangue no chão (as duas cores).
  - **Vermelha, parede de fora:** sangue 0,4, ferrugem 0,2, sujeira 0,15, rachadura 0,1, trepadeira 0,15.
  - **Vermelha, parede de dentro:** sujeira 0,35, rachadura 0,25, sangue 0,25, ferrugem 0,15 (camadas: ferrugem, rachadura, sujeira, sangue).
  - Lado: sprite `W` só em parede oeste, `N` só em parede norte; o canto ganha os dois. `MAX_LAYERS` e `WALL_LAYERS` iguais.
- **Preta:** não existe estado de névoa preta ainda (sprint 0038; `NOM.setBlackFog` só avisa). A regra recebe só `red`; sem ele, é branca. Sugestão pra 0038: Descasca e Ferrugem escuras, sem Grade e sem sangue.
- **Limpeza:** `OWN_PREFIXES = { "floors_burnt_01_", NOM_OwnSpriteList.DIR }`; o `D.own` e o `LoadGridsquare` reconhecem `media/textures/NOM/OutroMundo/`. O anexo vazado já é descartado no load (ID 20000000), isso é defesa.
- **Debug:** `NOM.ownSprites()` diz quantos de 50 estão registrados e quais PNG faltam; botão "Texturas próprias no console" no `NOM.panel()`.
- **Fake fiel** (`tests/attached_world.lua`): `getSprite` de nome novo cria sprite sem nome e sem flag (ID 20000000, sem textura se o PNG não existe), o `addAttachedAnimSpriteByName` só acha o que está no `namedMap`, o `getTexture` dá nil pra caminho que não existe, e o load descarta o anexo de runtime. Testes novos: `tests/test_own_sprites.lua`; em `test_dressing_rules.lua`, `test_fog_overlays.lua`, `test_debug.lua` e `test_debug_panel.lua` (setName esquecido, lado errado, textura faltando, branca sem Silent Hill, sangue no chão, prefixo, troca de cor, registro uma vez).
- **Só o jogo responde** (roteiro do Johan):
  - Grade e Ferrugem do chão por baixo do jogador e do zumbi (`FloorOverlay`), sem passar por cima;
  - Tinta e Descasca na parede W, N e de canto, com e sem recorte (cutaway);
  - nitidez no zoom 0,5 a 2,5, e se a grade com alfa 0,6 fica escura demais em piso escuro;
  - a primeira névoa logo depois de carregar (textura carregada assíncrona pode sair vazia no primeiro quadro);
  - sair e voltar pro save com névoa: nada vazou (nem nome vanilla, nem textura nossa);
  - se o peso do metal (~1/3 do chão vestido) e da tinta na parede está bom de olho.

---

### Tarefa 5: cobertura além da tela

Hoje (0034) o raio é o da tela, de 15 a 30 tiles. A spec pede todos os tiles carregados.
- **Medir primeiro**, no mundo falso: chamadas por tick e anexos vivos com raio 30, 40 e o limite que a margem do save permite (o corte duro a 38 tiles e o chunk sai do mapa a ≥48: ver pz-api-notes §16.6).
- A margem do save manda: se cobrir mais longe exigir passar do corte duro, NÃO fazer. Registrar a conta e a decisão.

- [x] Medir (mundo falso), fazer a conta da margem, decidir.
- [x] Teste que trava a margem (`overlays_save_margin_invariant`), `./run-tests.sh` verde, commit.

**Decidido (2026-10-06): não fazer.** `MAX_RADIUS` 30, `MARGIN` 2 e `SLACK` 8 ficam. Os motivos:
- o maior raio que a margem aceita mal passa de 30;
- o ganho visual é pequeno;
- e esse ganho custaria a folga contra engasgo de FPS no carro.

**Medição.** Script descartável sobre `tests/fog_world.lua` + `tests/attached_world.lua`, com o `setup` dos testes e `MAX_RADIUS` trocado antes do load (o `OFFSETS` é montado no load). Zoom 2,5, o máximo do jogo (`MultiTextureFBO2.<init>`: `zoomLevelsDefault` = 2,5 … 0,25). Tela 1920×1080; o raio 45 só é alcançado numa tela 2560×1440 (em 1080p o canto fica a 40,4 tiles e o raio vira 43). Campo aberto (só piso), densidade 3,2 (vermelha, opção 2). Chamadas = idas ao Java (`G.java + G.sqCalls`). "A pé" = 0,1 tile por tick (6 tiles/s); "carro" = 1 e 2 tiles por tick.

| Raio | Squares na volta | Alvos / anexos vivos | Volta (atualizações) | Enchendo / parado (por atualização) | A pé (pior atualização) | Carro 1 / 2 t/tick (pior tick) | Invalidações: enchendo / a pé / carro | Pior caso com SLACK 8 |
|---|---|---|---|---|---|---|---|---|
| 30 | 2821 | 2771 / 4694 | 36 (~6 s) | 1052 / 136 | 919 | 1880 / 1885 | 158 / 172 / 393 | 43 |
| 34 | 3625 | 3555 / 6066 | 46 | 1052 / 136 | 945 | 2057 / 2069 | 158 / 187 / 444 | 47 |
| 36 | 4053 | 3974 / 6802 | 51 | 1052 / 136 | 969 | 2036 / 2114 | 158 / 191 / 459 | 49 ✗ |
| 40 | 5025 | 4923 / 8481 | 63 (~10,5 s) | 1052 / 136 | 1020 | 2176 / 2194 | 158 / 208 / 511 | 53 ✗ |
| 45 | 6361 | 6234 / 10704 | 80 | 1052 / 134 | 1072 | 2230 / 2201 | 158 / 216 / 505 | 58 ✗ |

Com parede N e W em todo square (estresse, bloco de 61×61):
- anexos vivos: 10136 (30), 15573 (40) e 17869 (45);
- enchendo: 1959 chamadas; parado: ~128;
- a pé: 1338 (30) a 1584 (40);
- carro: 2738 (30), 2963 (40) e 3046 (45) por tick;
- invalidações: 310 enchendo e 614 a 698 no carro.

As chamadas por atualização quase não mudam com o raio: o `SCAN_BUDGET` e o `STRIP_BUDGET` mandam. O que cresce com R² é o resto:
- os anexos vivos (o que o jogo desenha e o FBO do chunk invalida; UNKNOWN no jogo);
- a volta da varredura, de 6 s pra 10,5 s no raio 40;
- o registro que o corte percorre em Lua a cada 2 tiles andados.

O anexo mais longe no carro fica em R + SLACK + 1,5 (39,5 no 30/8), como a conta prevê.

**A conta da margem** (§16.6). Raio R, corte duro em R + SLACK, com o carro a 2 tiles por tick: R + SLACK + `MOVE_TILES` (2) + 2 + 1 < 48, ou seja, **R + SLACK ≤ 42**.
- Com `SLACK` 8, o maior R seguro é **34**. Com `SLACK` 2, 40. O 45 não cabe nem com `SLACK` 0 (45 + 0 + 2 + 2 + 1 = 50).
- Hoje (30 + 8 = 38) o corte aguenta até ~6 tiles num tick (38 + 2 + 6 + 1 = 47). Em 42 só aguenta 2 tiles por tick. Um engasgo pra 10 FPS com o carro a ~30 tiles/s já dá 3 tiles num tick e grava anexo no save.
- **Diminuir o SLACK não causa pisca-pisca.** O mod só põe anexo a até r ≤ `MAX_RADIUS` e o corte só tira acima de `MAX_RADIUS` + `SLACK`, então as duas faixas nunca se cruzam. O custo do carro também não sobe: no raio 40, 2081 chamadas com `SLACK` 2 contra 2176 com `SLACK` 8.
- Só que cada tile tirado do `SLACK` pra dar ao raio sai da folga contra engasgo. Não vale.

**O ganho.** Fração da tela coberta pelo disco do raio, câmera centrada:

| Tela, zoom | Canto | R30 | R34 | R40 | R45 |
|---|---|---|---|---|---|
| 1920×1080, 2,0 | 32,5 | 99,0% | 100% | 100% | 100% |
| 1920×1080, 2,25 | 36,5 | 93,8% | 99,3% | 100% | 100% |
| 1920×1080, 2,5 | 40,4 | 84,6% | 95,0% | 100% | 100% |
| 2560×1440, 2,5 | 53,6 | 50,2% | 64,5% | 84,8% | 94,7% |
| 3840×2160, 2,5 | 80,0 | 22,3% | 28,6% | 39,7% | 50,2% |

- Em 1080p, o 34 só fecha os cantos nos zooms 2,25 e 2,5, e só com o jogador parado.
- Em 1440p e 4K, nenhum raio dentro da margem cobre a tela: o canto passa dos 48 tiles do chunk que sai do mapa.
- "Todos os tiles carregados" (13 × 13 chunks, ~52 tiles em Chebyshev) está fora da margem por definição.
- **Andando, o raio não muda nada.** Cobertura dos pisos que a regra pede, por faixa de distância, depois de 20 s andando no zoom 2,5:
  - a 3 tiles/s: 15–20 tiles 66%, 20–25 37%, 25–30 25%;
  - a 6 tiles/s: 30%, 21% e 18%;
  - os números são iguais nos raios 30, 36, 40 e 45.
- Quem limita a borda andando é a vazão da varredura, não o raio. A cada 8 tiles (`RESEEN_TILES`), o `reseen()` zera o `seen` e a volta recomeça pelos squares já vestidos (cada um gasta orçamento). A volta de 36 atualizações nunca chega ao anel de fora.
- Subir o raio piora o que dá pra ver: a volta parada fica mais longa (o zoom out enche mais devagar) e há 29% (34) a 81% (40) mais anexos vivos.

**Fica pra depois (proposta, não feita):** a borda ao andar (feita na Tarefa 5c). Variante medida numa cópia descartável:
- a âncora só volta o cursor (`cursor = 1`), sem zerar o `seen` (a chave já é absoluta);
- a 3 tiles/s, a faixa de 20–25 tiles vai de 37% pra 97% e a de 25–30, de 25% pra 88%;
- a 6 tiles/s, a de 15–20 vai de 30% pra 91% e a de 20–25, de 21% pra 85%;
- custo a pé: 919 → 1372 chamadas por atualização (estresse: 1338 → 2102), dentro do teto de 2500;
- falta limitar o `seen`, que cresce com o caminho: por exemplo, apagar as chaves além de `MAX_RADIUS` + `SLACK` no corte.

É uma tarefa própria, com TDD.

**Trava:** `overlays_save_margin_invariant` falha se `MAX_RADIUS` + `SLACK` + `MOVE_TILES` + 3 ≥ 48. Ela confere também que o `OFFSETS` vai até o `MAX_RADIUS`.

---

### Tarefa 5b: todos os comandos de debug no `NOM.panel()`

Pedido do Johan (2026-10-06): "não esquece de adicionar todos os comandos de debug no NOM.panel()".
- Faltam no painel: `setFog`, `setFog(true)`, `setRedFog`, `setRedFog(true)`, `setEndFog`, `setBlackFog` (só avisa), `getZombie`, `turnZombie(0)` (desfaz), `godMode`, `wind`, `status`. Os comandos que a 0035 criar também entram.
- Teste novo: todo comando do `NOM.HELP` (menos `panel` e `help`) tem botão no `P.ROWS`. Comando novo sem botão deixa o teste vermelho.
- Textos dos botões por chave PTBR + EN.

- [x] Teste que falha (`debug_panel_every_help_command_has_button`), implementar, `./run-tests.sh` verde, commit.

**Feito (2026-10-06).** Oito linhas no painel:
1. Névoa de verdade: Sirene branca (`setFog()`), Branca já (`setFog(true)`), Sirene vermelha (`setRedFog()`), Vermelha já (`setRedFog(true)`), Preta (`setBlackFog()`, só avisa até a 0038).
2. Toggles antigos: Névoa (liga/desliga) (`fog()`), Névoa já (`fog(true, true)`), Fim da névoa (agora `setEndFog()`, o mesmo `NOM_Debug.fog(false)` de antes), Vermelha (liga/desliga) (`redFog()`).
3. Noite, Dia, Relógio.
4. 00h, 06h, 12h, 18h, 22h.
5. 1, 5 e 10 zumbis, Eco aqui, Puxar zumbi (`getZombie()`).
6. As 4 variantes e Desfaz variante (`turnZombie(0)`).
7. Deus, Noclip, Invisível e Modo deus (`godMode()`), os quatro com sim/não (Modo deus pelo `isGodMod`).
8. Vento (liga/desliga) (`wind()`; sem o mod3 o comando só avisa no console) e Status no console (`status()`).
- **Teste:** carrega o `NOM_Console` de verdade pra ler o `NOM.HELP`, troca cada `NOM.*` por espião, aperta todos os botões e cobra que cada comando do HELP (menos `panel` e `help`) foi chamado: "comando sem botão no NOM.panel(): NOM.x (regra do AGENTS.md)".

---

### Tarefa 5c: borda ao andar

Pedido do Johan (2026-10-06): "a erosão... ainda tá aqueles chunks limitados... quero tela toda". A medição da Tarefa 5 mostrou o porquê: a cada 8 tiles a varredura zerava o `seen` e recomeçava pelos squares já vestidos.

- [x] Testes que falham (cobertura por faixa andando, memória do `seen`), implementar, `./run-tests.sh` verde, commit.

**Feito (2026-10-06).** Em `client/NOM_FogOverlays.lua`:
- a âncora e o `RESEEN_TILES` saíram. Andando, a volta é contínua e o `seen` fica;
- o square já visto custa só a chave: entra nas olhadas (`SCAN_BUDGET` × `LOOK_MULT`, só Lua), mas não no lote de 80 que vai ao Java;
- o corte no tick (a cada `MOVE_TILES`) esquece do `seen` o que passou de `radius` + `SLACK`. O valor do `seen` guarda x e y num número só. Se o corte esquece mais do que guarda (teleporte), a volta recomeça do mais perto;
- o pendente da revelação que o corte esqueceu, o `drain` pula: a volta o põe de novo se ele voltar pro raio;
- no fim da névoa, o `seen` é zerado: a próxima névoa olha tudo de novo.

Desvio do protótipo: o protótipo só voltava o cursor (`cursor = 1`) e mantinha o `seen`. Sozinho, isso não mudou nada no mundo falso (78%, 39% e 28%): o square já visto ainda gastava o lote de 80, e a volta parava em ~20 tiles. Voltar ao centro a cada 8 tiles também atrapalha a 6 tiles/s: a 3 tiles/s dá 77% no anel de fora contra 87% sem voltar; a 6 tiles/s, 44% contra 67%.

Medição (zoom 2,5, raio 30, campo aberto, densidade 3,2; média de 10 amostras depois de 10 s andando em linha). A cobertura é a fração dos pisos que a regra pede que estão vestidos:

| | 15–20 | 20–25 | 25–30 | Chamadas por atualização |
|---|---|---|---|---|
| Antes, 3 tiles/s | 78% | 39% | 28% | ~900 |
| Depois, 3 tiles/s | 100% | 99% | 87% | ~1400 |
| Antes, 6 tiles/s | 32% | 22% | 18% | ~900 |
| Depois, 6 tiles/s | 95% | 88% | 67% | ~1430 |

- **Estresse** (parede N e W em todo square do caminho): a pé, de ~1360 pra ~2400 chamadas por atualização (100 rodadas: 2335 a 2434; o teto é 2500). De carro a 2 tiles por tick, de ~3270 pra ~3900 por tick: o lote de 80 agora vai inteiro pra square novo. Em campo aberto, até ~2090 por tick (teto 2500, cobrado agora no `overlays_fast_car_low_fps_never_past_hard`).
- **Memória do `seen`** depois de 520 tiles a pé (teto: o disco de raio 30 + 8 + 2 + 1,5, 5417 squares): com piso, até 2821 em linha e em círculo; sem piso (nada a vestir, só o corte esquece), até 3234. Sem o esquecimento seriam 33212.
- **Testes novos:** `overlays_walking_covers_screen_edge`, `overlays_seen_memory_bounded`, `overlays_leave_and_return_redressed` (sai do raio e volta, a 25 e a 60 tiles), `overlays_walking_cost_stress` e `overlays_reveal_walking_far`. A `overlays_save_margin_invariant` não mudou; nada passa do corte duro em nenhuma atualização andando.

- [x] **Teto de custo do carro na área densa** (2026-10-06). Teste que falha (`overlays_car_cost_stress`: 3888 a 0,5 tile/tick), implementar, `./run-tests.sh` verde, commit.

Estresse (parede N e W em todo square, densidade 3,2, zoom 2,5, raio 30), saindo do disco cheio, 220 ticks. Maior de cada parte num tick, em chamadas Java (uma rodada; a ordem do `pairs` varia, a faixa do pior tick em 12 rodadas vem embaixo):

| Carro | Corte duro | Retirada em lote | Conferência | Vestir | Pior tick |
|---|---|---|---|---|---|
| Antes, 0,5 tile/tick | 1581 | 1086 | 100 | 1872 | 3751 |
| Antes, 1 tile/tick | 1598 | 455 | 86 | 1878 | 3898 |
| Antes, 2 tiles/tick | 1628 | 431 | 80 | 1864 | 3851 |
| Depois, 0,5 tile/tick | 1657 | 140 | 112 | 1865 | 2081 |
| Depois, 1 tile/tick | 1646 | 137 | 106 | 1860 | 2088 |
| Depois, 2 tiles/tick | 1650 | 116 | 64 | 1892 (446 no tick do corte) | 2248 |

- **Onde ia o custo:** nos primeiros ~30 ticks, o corte de um anel cheio custa ~1600. A atualização inteira (~2300) caía no mesmo tick. A 0,5 tile/tick, a retirada em lote também tirava, sem lote, o que passava de 38 entre dois cortes (até 1086).
- **O corte sozinho fica em ~1650**, abaixo da meta: continua inteiro, sem orçamento.
- **O que mudou** (`LIGHT_DIV` = 4):
  - no tick em que o corte tirou alguma coisa, a atualização vai pro tick seguinte. A 0,5 e a 1 tile/tick ela nunca cai em cima do corte;
  - a 2 tiles/tick o corte roda em todo tick, e a atualização veste 20 squares em vez de 80;
  - quem andou `MOVE_TILES` desde a atualização anterior tira 20 alvos em lote em vez de 80;
  - o que passou de 38 deixou de ter saída própria no lote: é do corte no tick, que já garante "nada além de 38 + 2".
- **Teto alcançado** (pior tick em 12 rodadas): 2005–2050 a 0,5 tile/tick, 1992–2059 a 1, 2216–2284 a 2. O teste cobra 2500.
- **Margem do save:** anexo mais longe 40,0 / 39,5 / 38,6 tiles, dentro de 38 + 2 + 1,5. A `overlays_save_margin_invariant` não mudou.
- **A pé, nada muda:** cobertura 100/99/87% (3 tiles/s) e 95/88/67% (6 tiles/s); estresse a pé 2331–2436 por atualização (antes, 2335–2434).
- **Custo aceito:** trocar de desenho dirigindo tira o desenho velho a 20 alvos por atualização.

---

### Hotfix do chão depois do teste do Johan

Branch `hotfix/0035-chao` (06/10). No jogo, as paredes ficaram boas, mas o chão da branca não. A
regra punha metal em qualquer chão, dentro e fora. Na calçada, o painel de 4×4 com um tipo só
virava quadrados escuros em xadrez. Na grama, a ferrugem e a tinta saíam em todo tile da mancha;
como cada decalque é centrado no losango, ficava uma grade regular de bolotas marrons.

- **Piso natural** (grama, terra, areia, barro): nada de metal, ferrugem nem tinta, nas duas
  cores. Fica o de antes da 0035 (mato, folha, sujeira, rachadura). O nome do piso começa com
  `blends_natural_01` ou `floors_exterior_natural`: a conta do `IsoGridSquare.hasNaturalFloor`.
  O cliente lê com `getFloor():getTextureName()` só quando a regra pôs textura nossa, uma ida ao
  Java nesses squares (pz-api-notes §16.7). `R.floor` ganhou o parâmetro `natural`.
- **Calçada e rua** (fora, não natural): peça solta. Cada tile é candidato com
  `METAL_OUT` × densidade (0,035, até `METAL_OUT_MAX` 0,07). Só vira peça o candidato sem candidato
  nos 4 vizinhos, então nunca há dois lado a lado. Grade 0,5, Ferrugem 0,4, Tinta 0,1; sem Chapa.
  **Teto: 6% do chão** em qualquer densidade da branca. O máximo esperado é 0,07 × 0,93⁴ ≈ 5,2%.
- **Dentro de casa:** a mancha e o painel de antes, mas quebrados. Grade e Chapa ficam em
  `METAL_FILL` (0,75) dos tiles da mancha; Ferrugem e Tinta em `METAL_SPOT` (0,3), pra não virar
  grade de manchas. Um tile de cada bloco 2×2 (sorteado) nunca tem metal, então nenhum 3×3 fica
  cheio.
- **Vermelha:** a ferrugem do chão não vai no piso natural. Na mancha, fica em `RUST_SPOT` (0,45)
  dos tiles, pelo mesmo motivo da tinta e da ferrugem de dentro.

Medido (quadrado de 120×120 tiles, só textura nossa; antes → depois):

| Onde | Opção de densidade 1 | Opção de densidade 2 |
|---|---|---|
| Branca, piso natural (dentro ou fora) | 37% → 0 | 46% → 0 |
| Branca, fora, pavimento | 37% → 3,1% (grade 1,5%), 0 pares vizinhos | 46% → 5,3%, 0 pares vizinhos |
| Branca, dentro | 37% → 16% (grade e chapa 13%), 1780 → 0 janelas 4×4 cheias | 46% → 19% |
| Vermelha, fora do piso natural | 25% → 11,5% | igual (a mancha já satura) |

- **Testes novos** (`test_dressing_rules.lua`): `dressing_rules_natural_names`,
  `dressing_rules_natural_floor_no_metal`, `dressing_rules_natural_only_drops_own`,
  `dressing_rules_pavement_metal_isolated` (disco de raio 60, d = 0,5/1/2) e
  `dressing_rules_inside_metal_broken` (100×100, sem 3×3 cheio, teto de 22%, ferrugem e tinta
  ≤ 5%). Em `test_fog_overlays.lua`: `overlays_natural_floor_no_metal`, com a grama limpa nas
  duas cores, o asfalto sem vizinho e `getTextureName` ≤ squares com textura nossa.
- **Testes reajustados:** `dressing_rules_white_favors_silent_hill` (dentro 10–22%, fora
  1,5–6%, sem chapa fora) e `dressing_rules_metal_patches`. Neste, a troca entre vizinhos fica
  < 0,85 do sorteio por tile (medido 0,72). A mancha agora aparece no bloco: a variância em
  blocos 6×6 é ~5,5× a de tiles independentes (trava > 3). Os limiares de textura própria no
  chão de `overlays_white_fog_own_sprites`, `overlays_own_sprites_out_before_save` e
  `overlays_own_missing_texture_skipped` também mudaram; este último ganhou uma casa.
- **Fake fiel:** o piso do mundo falso tem sprite de verdade (`newtiledefinitions.tiles.txt`).
  Dentro, `floors_interior_tilesandwood_01_0`; fora, quadras de 8 tiles em xadrez de grama
  (`blends_natural_01_16`) e asfalto (`blends_street_01_0`). Tem também `getTextureName`.
- **Pra ver no jogo:** a grama sem nada de metal; na calçada, uma grade ou ferrugem solta de vez
  em quando; dentro de casa, se o metal quebrado ainda lê como Silent Hill ou ficou ralo demais.

---

### Tarefa 6: docs

- `README.md` da sprint com o roteiro de teste e os pontos que só o jogo responde (legibilidade das lascas, FPS, tontura incomoda?, texturas no zoom do Johan);
- GDD (`atmosphere`, `art-direction`), ADR-017 (emenda), ADR nova se o sprite próprio entrar (formato e limpeza);
- `HANDOFF`, `sprints/README`, CREDITS (texturas novas).

---

### Code review final

O que o review da entrega achou e o que foi corrigido (um commit por item):

- **O esquecimento do `seen` rodava a cada tick no carro** (importante). Ele percorria a memória da varredura inteira dentro do corte, que de carro roda todo tick: só Lua, então o teste de chamadas Java não via. Agora roda na atualização, antes da varredura, quando o jogador andou `MOVE_TILES` desde o último. A margem do save não depende dele: é o `stripWhere` do corte, que não mudou. O `overlays_car_cost_stress` conta as chaves percorridas (`NOM_FogOverlays.seenVisits`) e trava no máximo uma volta por atualização. Voltas em 220 ticks: antes 55, 110 e 220 (0,5, 1 e 2 tiles/tick); depois 21, 21 e 20. Cobertura (100/99/87% a 3 tiles/s), margem e chamadas Java iguais (pz-api-notes §16.6).
- **Testes da janela ao vivo:** troca de cor aos 2 s, fim da névoa aos 2,5 s, a névoa que volta no meio da retirada e a densidade 0 que volta, todos com `liveOpen` e 0 squares errados no fim. O código já fazia certo: são travas.
- **A tontura cortava seco** quando a névoa acabava no meio dela. A tontura agora lê `NOM_FogOverlays.lastRevealAt()`, a última borda ao vivo, que o fim da névoa não apaga (carregar ou ir pro menu apaga). `revealStartedAt()` e `revealing()` continuam como eram. ADR-013 emendada.
- **Lint do `math.random`** no `test_kahlua_compat.lua`. Não há uso em `mod/` nem `mod2/`; o lint tira o comentário antes de casar.
- **Folga do `overlays_walking_cost_stress`** (2341–2423 contra 2500 em 12 rodadas). A variação é da ordem do `pairs` no registro do próprio mod, não do fake. Fixar a ordem no fake não a tira, e ordenar no mod custaria no jogo. A margem ficou documentada no teste.
- **Um extra do overlay com erro derrubava o desenho:** cada extra roda em `pcall`. O que falha sai da lista e vai pro log uma vez, com o prefixo `[NOM]`.
- **As fontes das lascas copiavam o registro inteiro a cada segundo.** Agora `NOM_FogOverlays.targets(px, py, pz, r)` devolve só o andar e o raio pedidos. No teste denso, a cópia caiu de 8227 alvos pra 1781.
