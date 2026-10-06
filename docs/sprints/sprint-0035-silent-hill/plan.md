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

- [ ] Testes que falham (curva; liga na revelação; não liga pra quem entra no meio; opção desligada = nada).
- [ ] Implementar, `./run-tests.sh` verde, commit.

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

- [ ] Testes que falham, implementar, `./run-tests.sh` verde, commit.

---

### Tarefa 5: cobertura além da tela

Hoje (0034) o raio é o da tela, de 15 a 30 tiles. A spec pede todos os tiles carregados.
- **Medir primeiro**, no mundo falso: chamadas por tick e anexos vivos com raio 30, 40 e o limite que a margem do save permite (o corte duro a 38 tiles e o chunk sai do mapa a ≥48: ver pz-api-notes §16.6).
- A margem do save manda: se cobrir mais longe exigir passar do corte duro, NÃO fazer. Registrar a conta e a decisão.

---

### Tarefa 6: docs

- `README.md` da sprint com o roteiro de teste e os pontos que só o jogo responde (legibilidade das lascas, FPS, tontura incomoda?, texturas no zoom do Johan);
- GDD (`atmosphere`, `art-direction`), ADR-017 (emenda), ADR nova se o sprite próprio entrar (formato e limpeza);
- `HANDOFF`, `sprints/README`, CREDITS (texturas novas).
