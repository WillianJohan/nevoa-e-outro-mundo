# Pesquisa: névoa volumétrica que contorna obstáculos e preenche o outro lado

Data: 2026-10-05. Escopo: simulação + renderização em tempo real de névoa/fumaça que desvia de obstáculos 3D,
se acumula contra a parede e enche o lado de trás, dentro das restrições do mod3 (thread de CPU a 20 Hz,
OpenGL 3.3 sem compute shader, câmera isométrica, tiles, andares discretos, só no cliente).

Convenção: cada afirmação traz o link da fonte. **[não confirmado]** marca o que não achei em fonte primária.
**[estimativa]** marca conta minha, feita a partir dos números das fontes ou do nosso código.

---

## Resumo

1. **O vácuo atrás da casa é provocado por nós mesmos, não sai da física.** Com vento uniforme e incompressível, névoa uniforme
   continua uniforme. A sprint 0026 mediu isso: sem `stillDecay` a densidade atrás do prédio dá 1,00. O que
   esvazia é o sorvedouro `stillDecay` em `FlowGrid.sources()`, e nada repõe a névoa (`outdoorRefill = 0`). O
   primeiro passo é tirar ou condicionar esse sorvedouro.
2. **Carro, árvore e cerca são paredes infinitas na simulação**, mas o shader desenha a névoa mais alta que eles.
   Por isso a fumaça "passa entre os objetos". Pesos fracionários nas faces resolvem barato
   ([Batty et al. 2007](https://www.cs.ubc.ca/~rbridson/docs/batty-siggraph2007-variationalcoupling.pdf)), e o
   `FlowGrid` já guarda `wu`/`wv` como `float`.
3. **O acúmulo contra a parede some no caminho**: a grade deixa a densidade chegar a 1,5 (`D_MAX`), mas a
   `writeRGBA` corta em 1. A altura do rolo também não é simulada: `rollTop` é só uma função da densidade 2D.
4. **Melhor custo/benefício a médio prazo: uma camada rasa de gás pesado (2,5D).** São as equações de águas
   rasas com profundidade `h` e terreno `H` por tile
   ([Chentanez & Müller 2010](https://matthias-research.github.io/pages/publications/hfFluid.pdf),
   [TWODEE-2](http://calliope.dem.uniud.it/CLASS/ENV-TRANSP/Twodee_ref2.pdf)). A névoa sobe na parede,
   transborda o que for mais baixo que ela e escorre pelo outro lado por gravidade. Não precisa resolver pressão, roda
   na CPU e encaixa na grade MAC que já existe.
5. **O desenho tem que andar com o fluxo local, não com o vento global** (`driftXY`/`uDrift`). Dá pra usar
   textura advectada com regeneração local ([Neyret 2003](http://evasion.imag.fr/Publications/2003/Ney03/neyret161.pdf))
   ou curl noise que respeita obstáculos ([Bridson et al. 2007](https://www.cs.ubc.ca/~rbridson/docs/bridson-siggraph2007-curlnoise.pdf)).
6. **3D em GPU com fragment shaders e textura 3D** é viável em GL 3.3
   ([GPU Gems 3 cap. 30](https://developer.nvidia.com/gpugems/gpugems3/part-v-physics-simulation/chapter-30-real-time-simulation-and-rendering-3d-fluids)),
   mas tem o maior risco e custo. Só vale se a 2,5D não convencer.
7. Pelo que se sabe, a fumaça do CS2 não é um fluido. A melhor descrição técnica disponível, que não é da
   Valve, fala em voxels preenchidos por *flood fill* com orçamento de passos **[não confirmado]**. Serve de ideia
   pra granada de fumaça, não pra névoa que viaja com o vento.

---

## Diagnóstico da simulação atual

Por que a névoa de hoje não parece volumétrica, não contorna e não enche o outro lado. Do mais importante pro menos.

### D1. O vácuo é um sorvedouro de propósito (`stillDecay`) e nada repõe (`outdoorRefill = 0`)

- Em `FlowGrid.sources()`, fora de casa, onde a velocidade fica abaixo da metade do vento, a densidade é
  multiplicada por `1 - stillDecay·dt·s²`. `Flow.newGrid` liga com `g.stillDecay = 0.08f` e `g.outdoorRefill = 0f`.
- O comentário em `Flow.newGrid` diz que `vorticity = 0.6f` foi escolhida porque "o dobro fecha o vácuo atrás do prédio".
  A 0029 e a 0030 calibraram o redemoinho **pra manter** o vazio
  ([sprint 0029](../sprints/sprint-0029-ondas-nos-obstaculos/README.md), [sprint 0030](../sprints/sprint-0030-nevoa-em-alta-resolucao/README.md)).
- A física: sem fonte nem sorvedouro, a concentração de um escalar passivo só é transportada
  ([Bridson 2007, cap. 3](https://www.cs.ubc.ca/~rbridson/fluidsimulation/fluids_notes.pdf)). Névoa uniforme
  que entra continua uniforme atrás do prédio. A sprint 0026 confirmou isso no nosso código: "com inércia e sem
  decaimento no ar parado, a névoa só fica parada atrás do prédio (densidade 1,00)"
  ([sprint 0026](../sprints/sprint-0026-nevoa-viajante/README.md)).
- Atrás de um bloco de verdade existe uma bolha de recirculação. Ela fica cheia de ar, porque o vórtice de
  recirculação *arrasta o fluido em volta pra dentro*, rumo ao eixo
  ([Martinuzzi & Tropea 1993](https://doi.org/10.1115/1.2910118)).
  Num cubo, o ponto de recolamento médio fica a ~1,4 altura atrás da face de trás
  ([estudo da Univ. de Southampton no JFM](https://eprints.soton.ac.uk/400432/1/cube_jfm_paper_final.pdf)). Em obstáculos
  largos o comprimento cresce até ~7,2 alturas
  ([Martinuzzi & Tropea 1993](https://doi.org/10.1115/1.2910118)).
- **[inferência minha]** Atrás do prédio fica mais limpo quando a camada de névoa é **mais rasa que o prédio**: o
  ar que desce do telhado pra dentro da esteira vem de cima da névoa e é limpo. Quando a névoa é mais funda que o
  prédio, a esteira enche. Uma simulação 2D de um andar não tem o caminho "por cima do telhado" e não consegue
  fazer essa distinção. Por isso o vazio foi forçado com um sorvedouro que não depende da altura.
- **[estimativa]** O `stillDecay` de 0,08/s esvazia em ~12 s, se o ar estiver parado. Atravessar a esteira de uma
  casa de 8 tiles com ar a 0,2–0,5 tile/s leva 16–40 s. O sorvedouro ganha da reposição, e a única outra entrada é
  a difusão (`diffusion = 0.15` tile²/s, que alcança ~1,7 tile em 10 s).

### D2. Todo obstáculo é infinitamente alto

- Em `Flow.buildCell`: `isSolid()`, `HasTree()` e `getVehicleContainer()` viram `F_SOLID`, e cerca, parede, porta
  e janela fechada viram face fechada (`isBlockedTo`). Em `FlowGrid.rebuildFaces`, a face fica `wu = 0` em
  qualquer altura.
- O shader desenha a camada até `top = ground + layer·1.6`, ~1,9 andar com `layer = 1.2` (`fogLook`).
  Acima de um carro de 1,5 m ou de uma cerca baixa, a névoa aparece desenhada (`writeRGBA` põe nos sólidos a média
  dos vizinhos, `neighborDensity`). A simulação, ao mesmo tempo, trata aquilo como muro até o céu e deixa um
  vazio atrás. O olho vê névoa atravessando o objeto **e** um buraco atrás dele: é a "fumaça que passa entre os objetos".
- Árvore é uma copa porosa com tronco fino, não um bloco de 1×1 tile.
- O custo de um contorno "em escada", tudo-ou-nada, é conhecido: o *solve* voxelizado equivale a massas `ρΔx³`
  ou 0 e "perde toda a informação de sub-célula da fronteira"
  ([Batty et al. 2007](https://www.cs.ubc.ca/~rbridson/docs/batty-siggraph2007-variationalcoupling.pdf)).
  A alternativa é pesar cada face pela fração aberta
  ([Bridson 2007, §4.5](https://www.cs.ubc.ca/~rbridson/fluidsimulation/fluids_notes.pdf)). O `FlowGrid` já usa
  `wu`/`wv` como peso em `cW..cS` (pressão), mas a advecção só testa `wu == 0` e não multiplica o fluxo pela fração.

### D3. A altura não é simulada: o "volume" é um perfil procedural da densidade 2D

- `rollTop` = `layer · min(fd, 1.5) · (0.25 + 0.8·puff) · (1 + pileUp(vel))`. A altura é uma função monotônica
  da densidade 2D, mais um ruído e uma heurística de velocidade. Não existe momento vertical nem pressão
  hidrostática: a névoa não *sobe* contra a parede por física, não *transborda* e não *escorre* do outro lado.
- `pileUp` sobe o rolo onde `|vel| < |vento|`. Isso vale na frente da parede (estagnação), mas **também na esteira**
  (ar parado atrás). A heurística não separa pressão alta (frente) de pressão baixa (trás). O sinal certo é a
  pressão `p`, que o `FlowGrid` já calcula em `project()` e joga fora.
- O perfil vertical exponencial (`exp(-2.8h)`, `exp(-10h)`) está alinhado com os modelos de gás pesado, que também
  usam decaimento exponencial ([TWODEE-2](http://calliope.dem.uniud.it/CLASS/ENV-TRANSP/Twodee_ref2.pdf)). O que
  falta é a **profundidade** ser uma variável simulada, não derivada.

### D4. O acúmulo contra a parede é cortado antes de chegar ao shader

- `FlowGrid` deixa a densidade ir até `D_MAX = 1.5`. `writeRGBA` grava `Math.min(1f, dens)` em RGBA8, e o shader
  faz `min(fd, 1.5)` num valor que nunca passa de 1. A massa que empilha na face de barlavento fica invisível.

### D5. O desenho anda com o vento global, não com o fluxo

- `driftXY` amostra o ruído em `xy + uDrift.xy - (vel - uDrift.zw)·WARP_S`. O padrão inteiro é levado pelo
  deslocamento **global** do vento, e o desvio local vira só uma dobra **fixa** (offset proporcional à
  diferença de velocidade). Um rolo que chega numa casa não contorna: ele "desliza" pra dentro dela e some pela
  máscara de densidade. Isso reforça a impressão de fumaça atravessando objetos.
- A sprint 0027 largou o *flow map* de duas fases porque pulsava
  ([sprint 0027](../sprints/sprint-0027-nevoa-organica/README.md)). O problema conhecido é a latência de
  regeneração ser **global**. A solução da literatura é regenerar por camadas, escolhidas pela deformação **local**
  acumulada ([Neyret 2003](http://evasion.imag.fr/Publications/2003/Ney03/neyret161.pdf)).

### D6. A projeção de pressão pode estar incompleta (hipótese a medir)

- `project()` zera `p` a cada passo (`Arrays.fill(p, 0f)`) e faz 16 iterações SOR (ω = 1,8) numa grade de até
  384² células (escala 3). A densidade usa fluxo conservativo, então ∂d/∂t + u·∇d = −d ∇·u. **Divergência que
  sobra cria névoa onde o ar converge e apaga onde o ar diverge**, o que pode ser um segundo esvaziador atrás de obstáculos.
- Com poucas iterações, os vórtices "achatam" e o volume não se conserva
  ([GPU Gems 3, §30.2.10](https://developer.nvidia.com/gpugems/gpugems3/part-v-physics-simulation/chapter-30-real-time-simulation-and-rendering-3d-fluids)).
  No Jacobi, Harris recomenda 40–80 iterações e "não menos que 20"
  ([GPU Gems cap. 38](https://developer.nvidia.com/gpugems/gpugems/part-vi-beyond-triangles/chapter-38-fast-fluid-dynamics-simulation-gpu)).
  SOR converge mais rápido que Jacobi, então os números não se transferem direto.
- Usar a pressão do passo anterior como chute inicial é "um chute muito bom" quando o fluxo não muda muito
  ([Bridson 2007, §4.3](https://www.cs.ubc.ca/~rbridson/fluidsimulation/fluids_notes.pdf)). É o nosso caso:
  o vento relaxa pra um estado quase estacionário (`windRelax = 0.15`).

### D7. Detalhes menores

- A textura do fluido usa `GL_LINEAR` (`Flow.prepare`). A densidade é interpolada através da parede fina, e a
  névoa "vaza" meia célula pra dentro ou pra fora no desenho.
- A advecção semi-lagrangiana bilinear da velocidade (`advectVelocity`) tem dissipação numérica com coeficiente
  ~`u·Δx` ([Bridson 2007, §3](https://www.cs.ubc.ca/~rbridson/fluidsimulation/fluids_notes.pdf)). Ela enfraquece o
  vórtice de recirculação, que é justamente o que levaria névoa pra trás do obstáculo.
- Câmera isométrica: o lado de trás (N/W) das casas costuma ficar escondido pelo próprio prédio. O vácuo ou o
  preenchimento só aparece quando o vento sopra "pra câmera". Isso afeta onde vale gastar qualidade.

---

## Famílias de algoritmo

### 1. Euleriano incompressível na grade (Stam, Fedkiw, Bridson): a base que já temos

**Como funciona.** Velocidade na grade, *splitting* em advecção semi-lagrangiana, forças e projeção de pressão
(Poisson). É incondicionalmente estável ([Stam 1999](https://www.dgp.toronto.edu/public_user/stam/reality/Research/pdf/ns.pdf),
[Stam 2003](https://www.dgp.toronto.edu/public_user/stam/reality/Research/pdf/GDC03.pdf)). Stam admite que a
estabilidade vem da dissipação numérica ("the fluids dampen faster than they should… This is in essence what makes
the algorithms stable") ([Stam 2003](https://www.dgp.toronto.edu/public_user/stam/reality/Research/pdf/GDC03.pdf)).

**Obstáculos.**
- Stam: grade booleana de ocupação; funciona se o objeto tiver **pelo menos duas células de espessura**, senão vaza
  ([Stam 2003](https://www.dgp.toronto.edu/public_user/stam/reality/Research/pdf/GDC03.pdf)). A MAC com faces
  fechadas (nossa parede fina) é a forma certa de fugir disso.
- Fedkiw: voxels ocupados têm velocidade de face igual à do objeto, densidade zero dentro e, nas células de borda,
  a densidade do vizinho livre mais perto, "pra evitar a queda brusca perto da fronteira"
  ([Fedkiw, Stam & Jensen 2001](http://graphics.ucsd.edu/~henrik/papers/smoke/smoke.pdf)). É o que o nosso
  `neighborDensity` faz pro desenho.
- Bridson/Batty: pesar cada face pela fração aberta (área ou comprimento). Fluido passando por fresta mais fina que
  a célula fica possível ([Batty et al. 2007](https://www.cs.ubc.ca/~rbridson/docs/batty-siggraph2007-variationalcoupling.pdf)).
  A versão de referência 2D usa pesos de área de face, "um pouco mais precisos" que os de volume
  ([FluidRigidCoupling2D](https://github.com/christopherbatty/FluidRigidCoupling2D)).

**Menos dissipação (preenchimento atrás do obstáculo).**
- *Vorticity confinement* devolve os redemoinhos que a grade grossa apaga
  ([Fedkiw et al. 2001](http://graphics.ucsd.edu/~henrik/papers/smoke/smoke.pdf)). Ele **não** age sobre a densidade
  da fumaça ([Bridson 2007, §5.2](https://www.cs.ubc.ca/~rbridson/fluidsimulation/fluids_notes.pdf)).
- BFECC reduz dissipação e difusão na advecção de velocidade e de densidade, com segunda ordem em espaço e tempo
  ([Kim et al., FlowFixer](https://www.cc.gatech.edu/~jarek/papers/FlowFixer.pdf)). O MacCormack semi-lagrangiano
  estima o erro do mesmo jeito sem a terceira advecção, então custa duas advecções em vez de três
  ([Selle et al. 2008](https://faculty.cc.gatech.edu/~jarek/papers/maccormack.pdf)).
- No escoamento em volta de um círculo, BFECC e MacCormack "chegam a escoamentos de Reynolds mais alto" que o
  semi-lagrangiano de primeira ordem. Os autores **voltam para primeira ordem** em toda célula cuja característica
  pode puxar dado de uma parede sólida, e usam limitador (clamp ou reversão)
  ([Selle et al. 2008](https://faculty.cc.gatech.edu/~jarek/papers/maccormack.pdf)).
- Na GPU, esquema de ordem mais alta costuma valer mais que aumentar a resolução, "porque conta é barata comparada
  à banda" ([GPU Gems 3 cap. 30](https://developer.nvidia.com/gpugems/gpugems3/part-v-physics-simulation/chapter-30-real-time-simulation-and-rendering-3d-fluids)).

**O que resolve da reclamação.** Contorno mais fiel (frações de face), esteira mais viva (MacCormack na
velocidade, *warm start*). Sozinha não dá altura nem "passar por cima".

**Custo.**
- Nosso: 128² com 16 iterações ≈ 0,9 ms/passo (comentário em `FlowGrid.iterations`, Ryzen 7600X); escala 2
  (256²) ≈ 5,7 ms/passo, 16% de um núcleo ([sprint 0030](../sprints/sprint-0030-nevoa-em-alta-resolucao/README.md)).
- Referência histórica: 40³ ≈ 1 s/quadro, 160×80×80 ≈ 75 s/quadro, em 2001
  ([Fedkiw et al. 2001](http://graphics.ucsd.edu/~henrik/papers/smoke/smoke.pdf)).
- MacCormack ≈ +1 advecção semi-lagrangiana por campo **[estimativa a medir: hoje uma advecção de velocidade]**.

**Encaixe.** Total: é o código atual. Pesos fracionários e *warm start* são mudanças locais no `FlowGrid`.

**Riscos.** MacCormack perto da parede fina precisa da reversão pra primeira ordem, senão cria extremos. Face
parcial na densidade precisa escalar o fluxo por `wu` pra não violar o limite `MAX_FACE_FLUX`.

### 2. Fluido 3D em GPU só com fragment shaders (Harris; Crane, Llamas & Tariq)

**Como funciona.**
- Cada campo é uma textura; cada etapa é um *fragment shader* que desenha um quad e lê a textura anterior
  (*ping-pong*) ([GPU Gems cap. 38](https://developer.nvidia.com/gpugems/gpugems/part-vi-beyond-triangles/chapter-38-fast-fluid-dynamics-simulation-gpu)).
- Em 3D, roda-se o kernel uma vez por fatia da textura 3D
  ([GPU Gems 3 cap. 30](https://developer.nvidia.com/gpugems/gpugems3/part-v-physics-simulation/chapter-30-real-time-simulation-and-rendering-3d-fluids)).
- Em GL 3.3, a fatia é presa no FBO com `glFramebufferTextureLayer` (GL 3.0+)
  ([Khronos](https://registry.khronos.org/OpenGL-Refpages/gl4/html/glFramebufferTextureLayer.xhtml)), ou escolhida
  pelo `gl_Layer` no *geometry shader* (GLSL 1.50+). O `gl_Layer` **no fragment shader só existe a partir do GLSL
  4.30** ([Khronos](https://registry.khronos.org/OpenGL-Refpages/gl4/html/gl_Layer.xhtml)), então em 3.3 a fatia
  chega por uniform ou varying.

**Obstáculos.**
- Voxelização dentro/fora numa textura 3D, mais uma textura de velocidade do obstáculo. Na pressão, vizinho sólido
  usa a pressão da própria célula (Neumann). Depois da projeção impõe-se *free-slip*, porque o Jacobi não converge
  totalmente. Na advecção, nada entra no obstáculo
  ([GPU Gems 3 cap. 30](https://developer.nvidia.com/gpugems/gpugems3/part-v-physics-simulation/chapter-30-real-time-simulation-and-rendering-3d-fluids)).
- Pra nós, a voxelização sai dos flags por tile extrudados pela altura estimada (parede = andar, carro ~1,5 m), sem malha.

**Render.** Raymarch na textura 3D, cortado pela profundidade da cena. Amostragem trilinear com jitter, duas
amostras por voxel. Desenho em baixa resolução com correção nas bordas por detecção de aresta
([GPU Gems 3 cap. 30](https://developer.nvidia.com/gpugems/gpugems3/part-v-physics-simulation/chapter-30-real-time-simulation-and-rendering-3d-fluids)).
O nosso `fogLook` já é um raymarch cortado pela profundidade; trocaria a fonte de densidade.

**O que resolve.** Tudo: contorna em 3D, passa por cima do baixo, cai do telhado, enche a esteira por cima e pelos lados.

**Custo.**
- 41 bytes/célula de simulação e 20 bytes/pixel de render. Textura de 16 bits rende ~2× a de 32 bits, sem perda
  visível. 20 iterações de Jacobi têm aparência "muito parecida" com 1000 pra fogo e fumaça
  ([GPU Gems 3 cap. 30](https://developer.nvidia.com/gpugems/gpugems3/part-v-physics-simulation/chapter-30-real-time-simulation-and-rendering-3d-fluids)).
- Referências: 2D 128² de nuvem a >80 passos/s numa GeForce FX 5950 de 2003; GPU até 6× a CPU equivalente
  ([GPU Gems cap. 38](https://developer.nvidia.com/gpugems/gpugems/part-vi-beyond-triangles/chapter-38-fast-fluid-dynamics-simulation-gpu)).
  Projeção de pressão 3D de 128×34×128 em ~9,8 ms numa GTX 480
  ([Chentanez & Müller 2011, Tab. 1–2](https://matthias-research.github.io/pages/publications/tallCells.pdf)).
- **[estimativa]** Uma grade de 128×128 tiles × 8 camadas de altura (131 mil células, metade da nossa 2D na escala 2)
  deve caber em poucos ms numa GPU atual. Não medi.

**Encaixe.** GL 3.3 dá conta: textura 3D, FBO por camada, ping-pong. É só no cliente, sem rede. A thread de CPU
ficaria só com a máscara.

**Riscos (altos).**
- Mexer em estado GL no meio do pipeline do PZ (o `Flow.prepare` já precisa salvar e restaurar PBO e *unpack*).
- Orçamento de GPU desconhecido nas máquinas dos jogadores.
- Grade 3D rolando com o personagem: o *scroll* da textura 3D é cópia na GPU.
- Depurar fluido 3D "não é tarefa simples"
  ([GPU Gems 3 cap. 30](https://developer.nvidia.com/gpugems/gpugems3/part-v-physics-simulation/chapter-30-real-time-simulation-and-rendering-3d-fluids)).
- Andar discreto: a grade vertical tem que acompanhar `z` e cortar no teto do andar.

### 3. 2,5D: camada rasa / gás pesado / colunas altas

**Como funciona.**
- **Águas rasas (Saint-Venant).** Por coluna: profundidade `h`, terreno `H`, superfície `η = H + h` e velocidade
  horizontal média `v`. Massa: `Dh/Dt = −h∇·v`. Momento: `Dv/Dt = −g∇η + a_ext`
  ([Chentanez & Müller 2010](https://matthias-research.github.io/pages/publications/hfFluid.pdf)). Na versão
  linearizada de Kass & Miller vira uma equação de onda com velocidade `√(gd)`, resolvida por ADI com uma iteração
  por quadro. Ela trata reflexão, transporte de massa e fronteiras que mudam de topologia, mas não onda quebrando
  ([Kass & Miller 1990](https://dl.acm.org/doi/10.1145/97880.97884)).
- **Grade escalonada como a nossa.** `h` no centro, `u` nas faces, fluxo *upwind* na face (conserva massa por
  construção) e velocidade atualizada pelo gradiente de `η`. Uma face é **parede** se a célula seca tiver o
  terreno acima da superfície da vizinha: "o nível da água precisa estar acima do terreno da célula seca vizinha
  pra o fluxo começar; senão a face se comporta como parede"
  ([Chentanez & Müller 2010, §2.1.4](https://matthias-research.github.io/pages/publications/hfFluid.pdf)).
  **É exatamente o "passa por cima do obstáculo baixo quando a névoa é mais alta que ele".**
- Diferente da equação de onda e do *pipe model*, águas rasas **têm vórtices**, porque carregam um campo de velocidade 2D
  ([Chentanez & Müller 2010](https://matthias-research.github.io/pages/publications/hfFluid.pdf)).
- **Gás pesado (a física da nossa névoa).**
  - Modelos de "camada rasa" pra gás mais denso que o ar resolvem águas rasas com profundidade, velocidade média e
    densidade média. Usam pressão hidrostática, terreno, rugosidade e vento ([TWODEE-2](http://calliope.dem.uniud.it/CLASS/ENV-TRANSP/Twodee_ref2.pdf);
    [tese de Hankin](https://www.repository.cam.ac.uk/items/e6590722-bc70-41a3-a434-8a28163f5321)).
  - O perfil vertical real tem **decaimento exponencial**. A profundidade `h` é a altura que contém 90–95% da
    flutuabilidade.
  - A frente da nuvem anda com número de Froude ~1 e entra ar pelo topo
    ([TWODEE-2](http://calliope.dem.uniud.it/CLASS/ENV-TRANSP/Twodee_ref2.pdf)).
  - Na fase gravitacional a nuvem "segue o chão"; depois o vento e a turbulência dominam
    ([TWODEE-2](http://calliope.dem.uniud.it/CLASS/ENV-TRANSP/Twodee_ref2.pdf)). Pra névoa de jogo usamos a mesma
    estrutura com uma gravidade reduzida `g'` calibrada pelo visual.
- **Colunas altas (*tall cells*).** A maior parte do volume fica numa célula alta por coluna, com perfil de pressão
  linear, e só a parte de cima é 3D ([Irving et al. 2006](https://physbam.stanford.edu/papers/stanford2006-01.pdf)).
  A versão restrita pra GPU (uma célula alta por coluna) roda >30 fps numa GTX 480 com grades de 64×66×64 a
  128×34×128 ([Chentanez & Müller 2011](https://matthias-research.github.io/pages/publications/tallCells.pdf)).
- **Multicamadas.** Várias camadas de Saint-Venant empilhadas, cada uma com sua velocidade. A versão com troca
  de massa entre camadas vizinhas "computa casos de recirculação com forçamento de vento"
  ([Audusse et al. 2011](https://numdam.org/articles/10.1051/m2an/2010036/)). É o meio-termo "2D em fatias".

**O que resolve da reclamação.**
- **Sobe contra a parede.** Na estagnação, `η` cresce porque a pressão é hidrostática. Não precisa mais do `pileUp`.
- **Passa por cima do baixo.** Carro de 1,5 m, cerca de 1 m e mureta viram `H` (degrau), não parede infinita. Se
  `h + H_vizinho > H`, a face abre.
- **Escorre e enche o lado de trás.** O vazio atrás do obstáculo tem `η` baixo, e o gradiente de `η` empurra a
  névoa pra dentro (corrente de gravidade). Isso substitui o `stillDecay`.
- **Vácuo onde faz sentido.** Prédio mais alto que a névoa (`H > h`) é parede, e atrás dele só chega névoa pelos
  lados: vazio curto, que se fecha. Névoa mais funda que o obstáculo cobre por cima.
- **Volume de verdade no desenho.** O topo da névoa é `H + h` por coluna, e o shader desenha o perfil exponencial a
  partir dele. A névoa "drapeja" sobre o carro e encosta na parede.
- O que **não** resolve: névoa entrando pela janela do 2º andar, caindo do telhado ou com camada dupla (névoa
  acima de ar limpo). Isso pede multicamadas ou 3D.

**Custo.**
- Explícito: sem solver de pressão. Por passo são advecção da velocidade, fluxo de `h` e gradiente de `η`; uns
  4–6 varrimentos, contra os 32 do nosso SOR (16 iterações × 2 cores) **[estimativa]**.
- Referência: 900×135 células em CPU de 2010 (i7 2,67 GHz) gastaram 42 ms/passo com 1 thread e 19 ms com 4. Isso
  incluía PML, redução de *overshooting* e coordenadas de textura advectadas. Na GPU (GTX 480) foram 2,2 ms
  ([Chentanez & Müller 2010, Tab. 2](https://matthias-research.github.io/pages/publications/hfFluid.pdf)).
- TWODEE-2: 125×125 pontos, ~200 mil passos em menos de 2 h num Pentium IV, em Fortran com esquema FCT
  ([TWODEE-2](http://calliope.dem.uniud.it/CLASS/ENV-TRANSP/Twodee_ref2.pdf)).
- **[estimativa]** Nossos 256² ≈ 65 mil células, sem PML nem extras: deve ficar abaixo dos 5,7 ms atuais num
  núcleo moderno. **Medir antes de prometer.**
- Restrição de passo (CFL): `Δt < Δx / (|u| + √(g'h))`. Com `g'` escolhido pra frente andar 1–3 tiles/s e Δx = 0,5
  tile, 2–4 subpassos a 20 Hz **[estimativa]**. Já temos subpasso em `advect()`.
- Multicamadas: custo ×N camadas, mais a troca vertical.

**Encaixe.**
- CPU, thread própria, grade MAC, fluxo *upwind* conservativo: o `FlowGrid` já tem 70% disso (`advectOnce` é
  exatamente o fluxo de `h`).
- `H` por tile sai do que o `Flow.buildCell` já lê, com uma tabela de alturas: parede = andar inteiro (efetivamente
  ∞ pra névoa de ~1–2 m), carro ~1,5 m, cerca baixa ~1 m, árvore porosa com arrasto em vez de bloco.
- Vento: vira forçamento `a_ext = k(vento − u)`, como o `windRelax` atual. O vento 2D incompressível pode
  continuar rodando a 1 célula/tile (~0,9 ms) e servir de forçamento pra camada a 2 células/tile.
- Andar: a camada é do andar da câmera, como hoje. Textura: R = `h`, GB = velocidade, mais um canal pra `H` ou a
  pressão; fica RGBA8 ou vira RGBA16F.

**Riscos.**
- Águas rasas explícitas instabilizam com `h → 0` e degraus grandes. Os autores precisaram de medidas de
  estabilidade e "não garantem estabilidade incondicional"
  ([Chentanez & Müller 2010](https://matthias-research.github.io/pages/publications/hfFluid.pdf)).
- Calibrar `g'`: alto demais e a névoa vira água (ondas, reflexão); baixo demais e não sobe na parede.
- Hipótese hidrostática quebra na frente da nuvem; o TWODEE adiciona termos de borda
  ([TWODEE-2](http://calliope.dem.uniud.it/CLASS/ENV-TRANSP/Twodee_ref2.pdf)).
- Validação de modelo de camada rasa com cerca semicircular: concentração boa no eixo e espalhamento lateral
  subestimado. Só vi o resumo, numa conferência da WIT (1995) **[não confirmado em texto integral]**
  (resumo visto numa busca, sem URL estável guardada).

### 4. Curl noise com obstáculos e detalhe sobre simulação grossa

**Como funciona.**
- O campo `v = ∇×ψ` é sem divergência por identidade; em 2D, `v = (∂ψ/∂y, −∂ψ/∂x)` ([Bridson, Hourihan & Nordenstam 2007](https://www.cs.ubc.ca/~rbridson/docs/bridson-siggraph2007-curlnoise.pdf)).
- Pra respeitar um sólido parado, multiplica-se `ψ` por uma rampa da **distância ao obstáculo**: o fluido escorrega
  tangente e não atravessa.
- Esteira turbulenta: oitavas de ruído ajustadas à geometria, modulada por uma amplitude que só existe atrás dos
  obstáculos e somada ao potencial laminar, também rampado. Os autores rodam em tempo real
  ([Bridson et al. 2007](https://www.cs.ubc.ca/~rbridson/docs/bridson-siggraph2007-curlnoise.pdf)).
- *Wavelet turbulence*: sintetiza alta frequência advectada pelo fluxo grosso, de 50×100×50 a uma resolução efetiva
  de 12800×25600×12800. Custa minutos por quadro (80×64×64 → 720×576×576 em menos de 2 min/quadro), e a qualidade
  da interação com obstáculos depende da grade grossa ([Kim et al. 2008](https://www.cs.cornell.edu/~tedkim/WTURB/wavelet_turbulence.pdf)).
- Texturas advectadas: as coordenadas são advectadas e regeneradas em camadas, escolhidas pela deformação local
  acumulada, pra evitar esticar e evitar o "pulso" de latência global
  ([Neyret 2003](http://evasion.imag.fr/Publications/2003/Ney03/neyret161.pdf)). Chentanez & Müller usam
  coordenadas de textura advectadas e misturadas pra detalhe na água
  ([2010](https://matthias-research.github.io/pages/publications/hfFluid.pdf)).

**O que resolve.** O **desenho** contorna (D5): os rolos seguem as linhas de corrente em volta da casa em vez de
deslizar pra dentro dela. A esteira ganha turbulência visual sem pagar com o fluido. **Não move massa**: não enche o
lado de trás sozinho.

**Custo.** No shader: um campo de distância por tile, calculado na CPU quando a máscara muda e enviado num canal
da textura, mais 2–3 amostras de ruído por passo do raio pra derivada finita **[estimativa]**. Wavelet turbulence
como publicada é offline.

**Encaixe.** Bom, porque fica só no shader. O campo de distância pode sair da máscara que já é montada linha a linha.

**Riscos.** O campo normal é descontínuo no eixo medial e cria picos em quinas vivas
([Bridson et al. 2007](https://www.cs.ubc.ca/~rbridson/docs/bridson-siggraph2007-curlnoise.pdf)). Casa de tile
tem quina em todo lugar; usar só a rampa escalar (eq. 3 do paper) evita isso. Texturas advectadas têm
*ghosting* e perda de contraste na mistura, e o Neyret trata isso com mistura específica
([Neyret 2003](http://evasion.imag.fr/Publications/2003/Ney03/neyret161.pdf)). É o mesmo sintoma que a 0027 viu.

### 5. Como os jogos de referência fazem

**Counter-Strike 2 ("responsive smokes").**
- Oficial (Valve): a granada cria "objetos volumétricos 3D que vivem no mundo", reage à luz, "cresce pra
  preencher espaços naturalmente" e pode ser "empurrada e escavada" por tiros e granadas. Todos os jogadores veem a
  mesma fumaça ([vídeo oficial da Valve, 2023](https://www.youtube.com/watch?v=_y9MpNcAitQ)).
- Dados do jogo: o esquema do renderizador `C_OP_RenderVolumetricEmitter` tem tipos de fumaça volumétrica
  `..._TYPE_EMISSION` e `..._TYPE_SINK`, além de criação contínua
  ([dump dos esquemas do CS2](https://github.com/SteamTracking/GameTracking-CS2/blob/master/DumpSource2/schemas/particles/C_OP_RenderVolumetricEmitter.h)).
  Que "sink" seja o tiro escavando é leitura minha **[não confirmado]**.
- Engenharia reversa (secundária, Acerola): grade de voxels que se expande em volta de objetos; um único passe de
  pós-processamento em ¼ de resolução; ruído 3D Worley + curl tileado no mundo, com mistura entre fumaças vinda do
  ruído compartilhado e "não de simulação de fluido". A reimplementação dele usa *flood fill* limitado: a semente
  recebe 16 e cada vizinho recebe `max(vizinhos) − 1`, o que "acaba o gás" e evita vazar por uma fresta só
  ([vídeo](https://www.youtube.com/watch?v=ryB8hT5TMSg), [código](https://github.com/GarrettGunnell/CS2-Smoke-Grenades)).
  O tamanho de voxel (0,5) é chute dele **[não confirmado]**.
- Lição pra nós: "encher o outro lado" ali vem de **distância pelo caminho** (flood fill), não de dinâmica. Pra
  granada de fumaça do jogador, um *flood fill* com orçamento na grade de tiles (respeitando as faces fechadas) é
  barato e dá o efeito. Pra névoa que viaja com o vento, não serve.

**Batman: Arkham Knight.**
- NVIDIA: "Fumaça e névoa reagem ao movimento nas lutas, inclusive quando uma caixa é arremessada ou parte do chão
  explode" ([vídeo da NVIDIA](https://www.youtube.com/watch?v=zsjmLNZtvxk)).
- O SDK Turbulence "aumenta técnicas de partículas existentes com resposta realista a sólidos em movimento e
  movimento turbulento", integrado às partículas PhysX ([documentação NVIDIA GameWorks](https://docs.nvidia.com/gameworks/content/artisttools/turbulence.htm)).
- Que a opção exige PhysX em GPU NVIDIA só achei num guia da comunidade Steam que cita a descrição da GeForce
  Experience **[não confirmado]**.
- **[não confirmado]** Não achei whitepaper nem talk da GDC 2015 específicos do Arkham Knight. Que seja "partículas
  advectadas por uma grade de velocidade na GPU" é inferência pela documentação genérica do Turbulence.

**Névoa volumétrica de render: froxels (Wronski 2014, Hillaire/Frostbite 2015).**
- Volume alinhado ao frustum de 160×90×64 ou 160×90×128, com profundidade exponencial e custo fixo independente da
  resolução da tela. Custo total ~1,1 ms ([Wronski 2014](https://bartwronski.com/wp-content/uploads/2014/08/bwronski_volumetric_fog_siggraph2014.pdf));
  o trecho lido não diz a plataforma **[não confirmado]**.
- Frostbite: tiles de 8×8 e 64 fatias. No PS4 a 900p custa 2,95 ms (tiles 8×8) ou 0,83 ms (16×16), com integração
  temporal ([Hillaire 2015, slides via SlideShare](https://www.slideshare.net/slideshow/physically-based-and-unified-volumetric-rendering-in-frostbite/51840934);
  [página do curso](https://advances.realtimerendering.com/s2015/)).
- O próprio Hillaire lista "volumes animados (ex.: simulação de fluido)" como problema em aberto da reprojeção temporal.
- Encaixe: com câmera iso fixa e um raymarch curto, froxel não é necessário. O que vale copiar é o **desenho em
  baixa resolução + correção nas bordas** (também no [GPU Gems 3](https://developer.nvidia.com/gpugems/gpugems3/part-v-physics-simulation/chapter-30-real-time-simulation-and-rendering-3d-fluids)),
  pra pagar a amostragem 3D ou a altura simulada.

**Horizon Zero Dawn (nuvens).** Shader volumétrico com meta de 2 ms de GPU
([Guerrilla 2015](https://www.guerrilla-games.com/read/the-real-time-volumetric-cloudscapes-of-horizon-zero-dawn)).
É referência de forma, ruído e luz, não de interação com obstáculo.

**Ghost of Tsushima (vento).** Não simulam fluido. Pra partícula não entrar na montanha fazem "a aproximação mais
básica de dinâmica de fluidos": amostram o *height map* à frente de cada partícula e dão velocidade pra cima
antecipada ([talk da GDC 2021, Bill Rockenbeck](https://www.youtube.com/watch?v=d61_o4CGQd8);
[GDC Vault](https://www.gdcvault.com/play/1027124/Blowing-from-the-West-Simulating)). Truque barato que serve pro
shader: levantar o perfil da névoa antes de obstáculos baixos, olhando `H` a barlavento.

**Teardown, Half-Life: Alyx e outros.** Teardown tem simulação de fumaça própria, reescrita na 0.7 com controle por
script. A única fonte é um tweet do autor citado pela Kotaku ([Kotaku 2021](https://kotaku.com/some-good-ass-video-game-smoke-1846507147)),
sem detalhe técnico **[não confirmado]**. Pra Half-Life: Alyx não achei fonte primária sobre névoa interativa **[não confirmado]**.

### 6. Lattice Boltzmann (LBM)

**Como funciona.** Distribuições de "pacotes" por direção em cada célula (D2Q9 em 2D, D3Q19 em 3D), com colisão
local e propagação pros vizinhos. As médias obedecem a Navier-Stokes, e obstáculo é *bounce-back* local, sem
solver global de pressão ([Wei, Li, Mueller & Kaufman, TVCG 2004](https://www3.cs.stonybrook.edu/~mueller/papers/smokeTVCG04.pdf)).
Fumaça em tempo real com obstáculos parados e móveis, em hardware de textura e com *splats* pro detalhe
([TVCG 2004](https://www3.cs.stonybrook.edu/~mueller/papers/smokeTVCG04.pdf);
[Li, Wei & Kaufman 2003](https://doi.org/10.1007/s00371-003-0210-6)).

**Custo.** D3Q19 em GPU (GeForce FX 5900) foi 8–15× a CPU; 2D D2Q9 em 256² com dois círculos de obstáculo
([GPU Gems 2 cap. 47](https://developer.nvidia.com/gpugems/gpugems2/part-vi-simulation-and-numerical-algorithms/chapter-47-flow-simulation-complex)).
Memória: 9 floats por célula em 2D.

**O que resolve.** Obstáculos complexos e móveis com regra local e boa esteira. Não dá altura (é 2D ou 3D completo).

**Encaixe.** Funciona em CPU ou em fragment shader. Mas trocaria o núcleo inteiro sem atacar D1–D5.

**Riscos.** Estabilidade com viscosidade baixa (tempo de relaxação perto de 0,5) e compressibilidade artificial
**[não confirmado em fonte primária nesta pesquisa]**. Prioridade baixa.

---

## Recomendação

Três caminhos em etapas, do mais barato pro mais caro. Cada etapa tem um critério de parada.

### Etapa 1: consertar a 2D (uma sprint curta, só CPU e shader)

1. **Acúmulo visível (D4).** `writeRGBA` grava `dens / D_MAX`, e o shader multiplica de volta, ou a textura passa
   pra RGBA16F. Assim o empilhamento contra a parede chega ao shader.
2. **Sorvedouro condicionado (D1).** `stillDecay` só atua atrás de obstáculo **mais alto que a camada**: parede,
   prédio. Carro, árvore e cerca não. Começar testando com `stillDecay = 0` pra ver a esteira encher, e mostrar ao
   Johan lado a lado (A/B), porque ele já pediu o vácuo antes.
3. **Obstáculo baixo/poroso como face parcial (D2).** Árvore, carro e cerca com `wu`/`wv` entre 0 e 1 (por exemplo
   árvore 0,7, carro 0,3, cerca 0,5) **[valores a calibrar]**. O fluxo de densidade em `advectOnce` passa a ser
   escalado por `wu` ([Batty et al. 2007](https://www.cs.ubc.ca/~rbridson/docs/batty-siggraph2007-variationalcoupling.pdf)).
4. **Warm start da pressão (D6).** Não zerar `p` entre passos
   ([Bridson 2007](https://www.cs.ubc.ca/~rbridson/fluidsimulation/fluids_notes.pdf)). Logar `max|∇·u|` e o RMS
   antes e depois.
5. **Pressão no shader.** Exportar `p` num canal e usar no lugar do `pileUp`: sobe onde `p > 0` (frente da parede),
   baixa onde `p < 0` (esteira e quinas).
6. **Desenho que segue o fluxo (D5).** Curl noise 2D com rampa pela distância a obstáculos
   ([Bridson et al. 2007](https://www.cs.ubc.ca/~rbridson/docs/bridson-siggraph2007-curlnoise.pdf)) pra deformar o
   ruído dos rolos. Ou coordenadas advectadas pela velocidade da grade com regeneração local
   ([Neyret 2003](http://evasion.imag.fr/Publications/2003/Ney03/neyret161.pdf)).
7. Opcional: MacCormack na advecção da velocidade, revertendo pra primeira ordem perto das faces fechadas
   ([Selle et al. 2008](https://faculty.cc.gatech.edu/~jarek/papers/maccormack.pdf)).

**O que medir** (no cenário de teste existente: prédio 8×8, vento 1,5 tile/s, 100 s):
- Densidade a 2, 4, 8 e 16 tiles atrás do prédio, atrás de um carro e atrás de uma árvore.
- Densidade máxima na face de barlavento.
- `max|∇·u|` e RMS de divergência, e a massa total entrando e saindo da grade.
- Custo do passo na escala 2 (meta: ≤ 5,7 ms + 10%).
- No jogo, vídeo A/B com o Johan na casa e no carro.

**Critério pra seguir pra etapa 2:** o Johan ainda achar que a névoa "não tem volume" ou "não passa por cima" do
carro e da cerca. A 2D não tem como fazer isso.

### Etapa 2: camada rasa de névoa pesada, 2,5D (1–2 sprints, só CPU, o melhor custo/benefício)

1. Classe nova e pura (por exemplo `FogLayer`), testada como o `FlowGrid`: `h` no centro, `u`/`v` nas faces,
   `H` por célula.
2. Passo: advecção da velocidade (já existe) → `u += Δt·(−g'∇(H+h) + k(vento − u))` → regra de face seca/parede de
   Chentanez & Müller ([2010, §2.1.4](https://matthias-research.github.io/pages/publications/hfFluid.pdf)) → fluxo
   *upwind* de `h` (o `advectOnce` atual) → bancos de névoa entrando pela borda como `h`.
3. `H` vem do `Flow.buildCell`: parede e prédio = ∞ (face fechada, como hoje), carro ~1,5 m, cerca ~1 m. Árvore
   fica sem `H` e ganha arrasto (porosa).
4. O vento 2D incompressível pode continuar a 1 célula/tile (~0,9 ms) só como forçamento.
5. Shader: topo = `H + h`, com perfil exponencial a partir dele
   ([TWODEE-2](http://calliope.dem.uniud.it/CLASS/ENV-TRANSP/Twodee_ref2.pdf)) e sombra pelo topo. O
   `rollTop`/`pileUp` vira ruído de superfície em cima de `h`, que agora é simulado.
6. Truque de Tsushima no shader: levantar o perfil antes de obstáculo baixo, olhando `H` a barlavento
   ([GDC 2021](https://www.youtube.com/watch?v=d61_o4CGQd8)).

**O que medir:**
- Custo/passo e número de subpassos de CFL (meta: ≤ custo atual).
- Conservação de massa (sem tiro nem porta, a massa só muda pelas bordas).
- Tempo pra a esteira da casa voltar a 80% da densidade de fora.
- Se a névoa transborda o carro quando `h > 1,5 m` e não transborda quando `h < 1,5 m`.
- Estabilidade com `h → 0` (bancos com vácuo entre eles).

**Critério de parada:** a cena casa + carro + cerca aprovada pelo Johan em vídeo. Se precisar de névoa entrando
por janela alta ou caindo de telhado, ir pra 2,5D multicamadas (2–3 camadas, [Audusse et al. 2011](https://numdam.org/articles/10.1051/m2an/2010036/))
antes de pensar em 3D.

### Etapa 3: 3D na GPU (só se as etapas 1 e 2 não bastarem; protótipo isolado primeiro)

- Grade 128×128 tiles × 6–8 camadas cobrindo ~2 andares, em texturas 3D RGBA16F com ping-pong.
- Kernels por fatia: `glFramebufferTextureLayer` com um draw por fatia e a fatia como uniform.
- Jacobi com 20–40 iterações, obstáculos voxelizados dos tiles extrudados pela altura, advecção MacCormack
  ([GPU Gems 3 cap. 30](https://developer.nvidia.com/gpugems/gpugems3/part-v-physics-simulation/chapter-30-real-time-simulation-and-rendering-3d-fluids)).
- O `fogLook` passa a amostrar a textura 3D.
- **Medir antes de integrar:** ms de GPU numa placa modesta (tipo GTX 1060/RX 580) e numa iGPU, com e sem
  resolução reduzida no raymarch; custo do *scroll* da grade; interferência com o estado GL do PZ.
- **Critério de entrada:** um requisito que a 2,5D não faz (névoa em camadas no ar, fumaça subindo em coluna,
  janela de 2º andar), e GPU com folga medida.

### Separado: granada de fumaça (se um dia entrar)

*Flood fill* com orçamento de passos na grade de tiles, respeitando as faces fechadas, como na reconstrução do CS2
([Acerola](https://www.youtube.com/watch?v=ryB8hT5TMSg)), somado como fonte de `h` (etapa 2) ou de densidade
(etapa 1). Enche o canto atrás da caixa sem depender do vento.

---

## Referências

**Fluidos para jogos e gráficos**
- Stam 1999, *Stable Fluids*: https://www.dgp.toronto.edu/public_user/stam/reality/Research/pdf/ns.pdf
- Stam 2003, *Real-Time Fluid Dynamics for Games*: https://www.dgp.toronto.edu/public_user/stam/reality/Research/pdf/GDC03.pdf
- Fedkiw, Stam & Jensen 2001, *Visual Simulation of Smoke*: http://graphics.ucsd.edu/~henrik/papers/smoke/smoke.pdf
- Bridson & Müller-Fischer 2007, *Fluid Simulation* (notas do curso SIGGRAPH; condições de contorno, fronteiras curvas, dissipação, height field): https://www.cs.ubc.ca/~rbridson/fluidsimulation/fluids_notes.pdf
- Batty, Bertails & Bridson 2007, *A Fast Variational Framework for Accurate Solid-Fluid Coupling*: https://www.cs.ubc.ca/~rbridson/docs/batty-siggraph2007-variationalcoupling.pdf (página: https://www.cs.ubc.ca/labs/imager/tr/2007/Batty_VariationalFluids/)
- Batty, *FluidRigidCoupling2D* (código de referência, pesos de área de face): https://github.com/christopherbatty/FluidRigidCoupling2D
- Selle, Fedkiw, Kim, Liu & Rossignac 2008, *An Unconditionally Stable MacCormack Method*: https://faculty.cc.gatech.edu/~jarek/papers/maccormack.pdf (DOI 10.1007/s10915-007-9166-4)
- Kim, Liu, Llamas & Rossignac 2005, *FlowFixer: Using BFECC for Fluid Simulation*: https://www.cc.gatech.edu/~jarek/papers/FlowFixer.pdf

**GPU**
- Harris 2004, GPU Gems cap. 38, *Fast Fluid Dynamics Simulation on the GPU*: https://developer.nvidia.com/gpugems/gpugems/part-vi-beyond-triangles/chapter-38-fast-fluid-dynamics-simulation-gpu
- Crane, Llamas & Tariq 2007, GPU Gems 3 cap. 30, *Real-Time Simulation and Rendering of 3D Fluids*: https://developer.nvidia.com/gpugems/gpugems3/part-v-physics-simulation/chapter-30-real-time-simulation-and-rendering-3d-fluids
- Li, Fan, Wei & Kaufman 2005, GPU Gems 2 cap. 47, *Flow Simulation with Complex Boundaries* (LBM): https://developer.nvidia.com/gpugems/gpugems2/part-vi-simulation-and-numerical-algorithms/chapter-47-flow-simulation-complex
- Khronos, `glFramebufferTextureLayer`: https://registry.khronos.org/OpenGL-Refpages/gl4/html/glFramebufferTextureLayer.xhtml
- Khronos, `gl_Layer`: https://registry.khronos.org/OpenGL-Refpages/gl4/html/gl_Layer.xhtml

**2,5D, camada rasa, gás pesado**
- Kass & Miller 1990, *Rapid, Stable Fluid Dynamics for Computer Graphics*: https://dl.acm.org/doi/10.1145/97880.97884 (li o resumo e um trecho do ePDF, não o texto integral)
- Chentanez & Müller 2010, *Real-time Simulation of Large Bodies of Water with Small Scale Details*: https://matthias-research.github.io/pages/publications/hfFluid.pdf
- Chentanez & Müller 2011, *Real-Time Eulerian Water Simulation Using a Restricted Tall Cell Grid*: https://matthias-research.github.io/pages/publications/tallCells.pdf
- Irving, Guendelman, Losasso & Fedkiw 2006, *Efficient Simulation of Large Bodies of Water by Coupling Two and Three Dimensional Techniques*: https://physbam.stanford.edu/papers/stanford2006-01.pdf
- Audusse, Bristeau, Perthame & Sainte-Marie 2011, *A multilayer Saint-Venant system with mass exchanges*: https://numdam.org/articles/10.1051/m2an/2010036/
- Folch, Costa & Hankin 2009, *TWODEE-2: a shallow layer model for dense gas dispersion on complex topography*: http://calliope.dem.uniud.it/CLASS/ENV-TRANSP/Twodee_ref2.pdf
- Hankin, tese *Heavy gas dispersion over complex terrain* (resumo): https://www.repository.cam.ac.uk/items/e6590722-bc70-41a3-a434-8a28163f5321

**Detalhe procedural**
- Bridson, Hourihan & Nordenstam 2007, *Curl-Noise for Procedural Fluid Flow*: https://www.cs.ubc.ca/~rbridson/docs/bridson-siggraph2007-curlnoise.pdf
- Kim, Thürey, James & Gross 2008, *Wavelet Turbulence for Fluid Simulation*: https://www.cs.cornell.edu/~tedkim/WTURB/wavelet_turbulence.pdf
- Neyret 2003, *Advected Textures*: http://evasion.imag.fr/Publications/2003/Ney03/neyret161.pdf

**Física de esteira**
- Martinuzzi & Tropea 1993, *The Flow Around Surface-Mounted, Prismatic Obstacles…* (lido numa cópia não oficial hospedada no studylib): https://doi.org/10.1115/1.2910118
- Estudo da Univ. de Southampton no JFM sobre o efeito da turbulência na esteira de um cubo (recolamento a 1,4 h da face de trás): https://eprints.soton.ac.uk/400432/1/cube_jfm_paper_final.pdf

**Jogos e render**
- Valve 2023, *Counter-Strike 2: Responsive Smokes* (vídeo oficial): https://www.youtube.com/watch?v=_y9MpNcAitQ
- Dump dos esquemas do CS2, `C_OP_RenderVolumetricEmitter`: https://github.com/SteamTracking/GameTracking-CS2/blob/master/DumpSource2/schemas/particles/C_OP_RenderVolumetricEmitter.h
- Acerola (Garrett Gunnell), *I Tried Recreating Counter Strike 2's Smoke Grenades* (secundária, engenharia reversa): https://www.youtube.com/watch?v=ryB8hT5TMSg; código: https://github.com/GarrettGunnell/CS2-Smoke-Grenades
- NVIDIA, vídeo GameWorks do Batman: Arkham Knight: https://www.youtube.com/watch?v=zsjmLNZtvxk
- NVIDIA GameWorks, documentação do Turbulence: https://docs.nvidia.com/gameworks/content/artisttools/turbulence.htm
- Wronski 2014, *Volumetric Fog* (SIGGRAPH): https://bartwronski.com/wp-content/uploads/2014/08/bwronski_volumetric_fog_siggraph2014.pdf
- Hillaire 2015, *Physically Based and Unified Volumetric Rendering in Frostbite*: https://advances.realtimerendering.com/s2015/ (lido pela cópia do SlideShare: https://www.slideshare.net/slideshow/physically-based-and-unified-volumetric-rendering-in-frostbite/51840934)
- Schneider 2015, *The Real-Time Volumetric Cloudscapes of Horizon Zero Dawn*: https://www.guerrilla-games.com/read/the-real-time-volumetric-cloudscapes-of-horizon-zero-dawn
- Rockenbeck 2021, *Blowing from the West: Simulating Wind in Ghost of Tsushima*: https://www.youtube.com/watch?v=d61_o4CGQd8; https://www.gdcvault.com/play/1027124/Blowing-from-the-West-Simulating
- Wei, Li, Mueller & Kaufman 2004, *The Lattice-Boltzmann Method for Simulating Gaseous Phenomena*: https://www3.cs.stonybrook.edu/~mueller/papers/smokeTVCG04.pdf

**Nosso código e sprints**
- `mod3/java/nom/render/FlowGrid.java`, `mod3/java/nom/render/Flow.java`, `mod3/42/media/shaders/NOM_VolFog.frag`,
  `mod3/42/media/shaders/NOM_RenderContext.glsl` (cópia de trabalho de 2026-10-05).
- Sprints [0024](../sprints/sprint-0024-nevoa-fluida/README.md) a [0030](../sprints/sprint-0030-nevoa-em-alta-resolucao/README.md).

### O que não confirmei em fonte primária

- **CS2:** a implementação interna (voxels, tamanho de voxel, *flood fill*, ¼ de resolução, ruído Worley + curl)
  só vem da engenharia reversa do Acerola. A Valve só descreve o efeito. A leitura do tipo `SINK` como "escavação
  por tiro" é minha.
- **Batman: Arkham Knight:** a técnica exata (grade do Turbulence + partículas PhysX). Não achei whitepaper nem talk
  da GDC 2015 específicos do jogo, só material de marketing e a documentação genérica do SDK.
- **Teardown e Half-Life: Alyx:** sem fonte técnica sobre névoa ou fumaça que interage.
- **Wronski 2014:** a plataforma do custo de ~1,1 ms não aparece no trecho lido.
- **Kass & Miller 1990:** li só o resumo e um trecho, não o artigo inteiro.
- **Camada rasa com cerca:** "espalhamento lateral subestimado" vem só do resumo de um paper de conferência da WIT.
- **LBM:** os riscos de estabilidade com viscosidade baixa.
- **Inferências e estimativas minhas:** que a esteira limpa depende da névoa ser mais rasa que o prédio; o tempo
  de esvaziamento contra o de reposição na esteira; os custos extrapolados da 2,5D e do 3D; e a hipótese de que a
  projeção incompleta esvazia a esteira (D6), que precisa de medição.
- **Martinuzzi & Tropea:** li numa cópia hospedada no studylib, não no site da ASME.
