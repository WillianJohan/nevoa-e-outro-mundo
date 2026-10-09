# Créditos

**Nada de terceiros.** Todo arquivo de som, imagem e textura do mod é original, gerado por
script deste repositório, menos a **arte de lançamento, que é do Johan** (pôster, preview, ícone
e banner; [ADR-019](docs/architecture/adr-019-arte-de-lancamento.md)) e só é redimensionada e
tingida por script; o resto do que o mod mostra é conteúdo vanilla do Project
Zomboid **referenciado por nome ou GUID**, sem nenhum arquivo do jogo copiado. Nenhum
código, som ou imagem de outro mod foi usado. Licença de tudo que está aqui:
[MIT](LICENSE), a mesma do mod.

`tests/test_credits.lua` falha se aparecer no mod qualquer arquivo que não seja
código ou texto (`.lua .txt .xml .json .info`, `.gitkeep`), ou uma imagem em
`docs/workshop/`, que não esteja nesta página; e com GUID vanilla não listado.

## Sons

Gerados por síntese procedural pelo script [`scripts/gen_sounds.py`](scripts/gen_sounds.py)
(numpy + ffmpeg, semente fixa). Nenhuma amostra de terceiros, do jogo ou de outro mod. A
síntese das sirenes está em `scripts/sirenes/` (os protótipos nossos que o Johan aprovou); o
`gen_sounds.py` as encurta sem mudar o tom e põe a distância e o eco de cidade.

| Arquivo | Som | Uso |
|---|---|---|
| `mod/42/media/sound/NOM_EstaladorClick.ogg` | burst clicker rítmico (~12 cliques secos em ~1,4 s; último mais forte) | estalo/sonar do Estalador (sprint 0048) |
| `mod/42/media/sound/NOM_CorredorScream.ogg` | grito curto humano-morto: pulso glotal + formantes, raspagem e eco de rua (~1,7 s) | grito do Corredor (sprint 0048) |
| `mod/42/media/sound/NOM_CorredorScream2.ogg` | variante do grito do Corredor | grito do Corredor |
| `mod/42/media/sound/NOM_CorredorScream3.ogg` | variante do grito do Corredor | grito do Corredor |
| `mod/42/media/sound/NOM_FogDrone.ogg` | drone grave em loop (senos graves + ronco filtrado) | ambiente da névoa |
| `mod/42/media/sound/NOM_FogMetal.ogg` | pancada metálica distante (parciais inarmônicos + ecos) | ruídos metálicos da névoa |
| `mod/42/media/sound/NOM_RadioStatic.ogg` | chiado de rádio em loop (ruído filtrado, estalos, zumbido de 60 Hz) | rádio "na cabeça" perto do Sem-rosto |
| `mod/42/media/sound/NOM_SirenWhite1.ogg` | "o chamado e a resposta" (11,8 s): sirene de rotor no poste e uma segunda que responde meio tom abaixo, de dentro da névoa, cada vez mais perto | sirene da névoa branca (coro de 5, a 150–500 tiles) |
| `mod/42/media/sound/NOM_SirenWhite2.ogg` | "o som que a névoa engole" (11,8 s): sirene de defesa civil que a névoa abafa sem baixar o volume, até sobrar um sopro grave, um zumbido de ouvido e um estalo seco de madeira | sirene da névoa branca |
| `mod/42/media/sound/NOM_SirenWhite3.ogg` | sirene pelo rádio de emergência (11,8 s): squelch, três bipes de alerta, a sirene em banda estreita com chiado e a rajada de squelch no fim | sirene da névoa branca |
| `mod/42/media/sound/NOM_SirenWhite4.ogg` | sirene de defesa civil numa fita velha (11,8 s): wow leve, chiado, uma subida, uma segurada e a descida até parar | sirene da névoa branca |
| `mod/42/media/sound/NOM_SirenWhite5.ogg` | sirene de manivela gravada em fita (11,8 s): o tom sobe em surtos a cada volta, perde o fôlego, ganha um segundo e larga; o rotor roda livre até parar | sirene da névoa branca |
| `mod/42/media/sound/NOM_SirenWhite6.ogg` | sirene de defesa civil clássica (11,8 s): uma volta (sobe, segura, cai) com corneta, alto-falante velho saturando e eco de cidade vazia | sirene da névoa branca |
| `mod/42/media/sound/NOM_SirenWhite7.ogg` | "alerta contínuo" (11,8 s): sirene de rotor que sobe e segura o tom, com a corneta girando no poste; cada passada chega mais apagada até o contator desligar | sirene da névoa branca |
| `mod/42/media/sound/NOM_SirenWhite8.ogg` | "a caixa da estação" (11,8 s): wail eletrônico de fita velha num alto-falante de corneta, com falhas de contato; a fita acaba no topo e sobra o zumbido do amplificador | sirene da névoa branca |
| `mod/42/media/sound/NOM_SirenWhite9.ogg` | "duas notas" (11,8 s): sirene de dois rotores em terça menor; quando o motor desliga, a névoa engole primeiro a voz aguda | sirene da névoa branca |
| `mod/42/media/sound/NOM_SirenRed1.ogg` | "garganta" (11,8 s): sinal de ataque ondulante com o rotor desbalanceando (rosna a 70–120 Hz), a estática devolvendo a sirene invertida e a última resposta quebrando uma quinta | sirene da névoa vermelha (coro de 5, a 150–500 tiles) |
| `mod/42/media/sound/NOM_SirenRed2.ogg` | sinal de ataque (11,8 s): tom ondulante sem parar, segunda sirene de outro bairro fora de fase e estática agressiva crescendo até o motor desligar | sirene da névoa vermelha |
| `mod/42/media/sound/NOM_SirenRed3.ogg` | uivo pelo megafone longe, com 40% do efeito (11,8 s): a sirene se dobra num uivo quase orgânico, com mais corpo | sirene da névoa vermelha |
| `mod/42/media/sound/NOM_SirenRed4.ogg` | uivo pelo megafone longe, efeito cheio (11,8 s): a mesma dobra em banda estreita, saturada e com chiado | sirene da névoa vermelha |
| `mod/42/media/sound/NOM_SirenRed5.ogg` | uivo (11,8 s): vibrato irregular, quebras de registro, formantes largos que derivam sem formar vogal e um rosnado grave antes da cauda | sirene da névoa vermelha |
| `mod/42/media/sound/NOM_SirenRed6.ogg` | duas fitas (11,8 s): duas gravações da mesma sirene que se desencontram até o batimento virar ronco | sirene da névoa vermelha |
| `mod/42/media/sound/NOM_SirenRed7.ogg` | "toque de fogo" (11,8 s): sirene de quartel em pulsos que encurtam, rotor rosnando e estática nas pausas; o último toque passa do topo e o motor larga | sirene da névoa vermelha |
| `mod/42/media/sound/NOM_SirenRed8.ogg` | "megafone rasgado" (11,8 s): wail que vira yelp acelerando num cone rasgado, com a aba solta batendo a ~88 Hz; volta ao wail caindo e o amplificador desliga | sirene da névoa vermelha |
| `mod/42/media/sound/NOM_SirenRed9.ogg` | "motor disparado" (11,8 s): a tensão dispara e o rotor passa do topo, com mancal guinchando e rajadas de estática, até o disjuntor cair | sirene da névoa vermelha |
| `mod/42/media/sound/NOM_SirenBlack1.ogg` | "a resposta no escuro" (11,8 s): zumbido da rede, o disjuntor desarma, responde uma sirene uma oitava abaixo; a cidade tenta religar e cai de novo; sobram brasas | sirene da névoa preta (sprint 0038) |
| `mod/42/media/sound/NOM_SirenBlack2.ogg` | "a buzina afogada" (11,8 s): três toques de buzina de névoa cada vez mais graves e escuros; o último engasga, a lâmpada queima e fica o escuro | sirene da névoa preta |
| `mod/42/media/sound/NOM_SirenBlack3.ogg` | "apagão" (11,8 s): três quedas de tensão roubam o brilho, o disjuntor desarma com baque seco e, no chiado, o motivo de três bipes | sirene da névoa preta |
| `mod/42/media/sound/NOM_SirenBlack4.ogg` | "a luz sendo sugada" (11,8 s): hum da iluminação, a sirene ao contrário em swells cada vez mais graves, a grande inspiração e a brasa no escuro | sirene da névoa preta |
| `mod/42/media/sound/NOM_SirenBlack5.ogg` | apagão pelo megafone, 40% do efeito (11,8 s): a energia cai em degraus e a sirene fica lenta e grave até sobrar o hum | sirene da névoa preta |
| `mod/42/media/sound/NOM_SirenBlack6.ogg` | brasa pelo megafone, 40% do efeito (11,8 s): sirene grave, quase um sopro, por baixo de uma brasa perto que cresce | sirene da névoa preta |
| `mod/42/media/sound/NOM_SirenBlack7.ogg` | brasa pelo megafone, efeito cheio (11,8 s): a mesma, mais longe e em banda estreita | sirene da névoa preta |
| `mod/42/media/sound/NOM_SirenBlack8.ogg` | apagão pelo megafone, efeito cheio (11,8 s): cinco degraus de energia com baque de disjuntor até o rotor parar | sirene da névoa preta |
| `mod/42/media/sound/NOM_SirenBlack9.ogg` | fita morrendo (11,8 s): wow forte e chiado de rádio, o tom escorrega, cortes cada vez maiores e um grave arrastado no fim | sirene da névoa preta |
| `mod/42/media/sound/NOM_SirenBlack10.ogg` | quase silêncio (11,8 s): zumbido elétrico com surtos, rádio varrendo o dial e sirenes distantes tocadas ao contrário | sirene da névoa preta |
| `mod/42/media/sound/NOM_SirenBlack11.ogg` | "bateria morrendo" (11,8 s): a rede cai, a sirene eletrônica passa pra bateria e fica lenta e grave, até o amplificador oscilar em pulsos graves que espaçam | sirene da névoa preta |
| `mod/42/media/sound/NOM_SirenBlack12.ogg` | "o gerador" (11,8 s): sirene ligada num gerador a diesel que tosse três vezes, dá tiros no escapamento e afoga; sobram os tiques do metal esfriando | sirene da névoa preta |
| `mod/42/media/sound/NOM_SirenBlack13.ogg` | "uma por uma" (11,8 s): três sirenes graves de bairros diferentes; os transformadores estouram de fora pra dentro e o zumbido da rede some | sirene da névoa preta |
| `mod/42/media/sound/NOM_CarpideiraSob.ogg` | choro baixo em loop (~7 s): soluços de voz aguda que treme e cai, com ar e inspirações chiadas (harmônicos filtrados em formantes + ruído) | Carpideira calma, perto dela |
| `mod/42/media/sound/NOM_CarpideiraScream.ogg` | lamento feminino de pânico (~3,5 s): glotal + formantes, falha de garganta, aspiração (vibe Witch) | grito da Carpideira acordada (sprint 0048) |
| `mod/42/media/sound/NOM_CarpideiraScream2.ogg` | variante do grito da Carpideira | grito da Carpideira |
| `mod/42/media/sound/NOM_CarpideiraScream3.ogg` | variante do grito da Carpideira | grito da Carpideira |
| `mod/42/media/sound/NOM_AmbientScream1.ogg` | grito humano distante + eco de cidade | gritos ambiente da névoa (sprint 0048) |
| `mod/42/media/sound/NOM_AmbientScream2.ogg` | sofrimento/aflição distante (gemido que sobe e quebra) | gritos ambiente |
| `mod/42/media/sound/NOM_AmbientScream3.ogg` | choro de desespero distante (soluços em série) | gritos ambiente |
| `mod/42/media/sound/NOM_AmbientScream4.ogg` | grito de desespero distante (crescendo + queda) | gritos ambiente |
| `mod/42/media/sound/NOM_DevTv.ogg` | TV fora do ar (8 s): neve no alto-falante, quase-palavras formadas pela estática, tom de teste de 1 kHz que corta com estalo | TV na névoa branca |
| `mod/42/media/sound/NOM_DevTvRed.ogg` | TV áspera (8 s): respiração rouca por baixo da neve, sirene tocada ao contrário, corte seco pro silêncio | TV na névoa vermelha |
| `mod/42/media/sound/NOM_DevTvBlack.ogg` | TV no escuro (8 s): zumbido do tubo, neve caindo em degraus, motivo de três bipes, a TV desligando sozinha | TV na névoa preta (sprint 0038) |
| `mod/42/media/sound/NOM_DevRadio.ogg` | rádio varrendo estações mortas (9 s): assobios de sintonia, trava numa portadora e uma "voz que não é voz" (pulso glotal em formantes que derivam) | rádio na névoa branca |
| `mod/42/media/sound/NOM_DevRadioRed.ogg` | dial desesperado (8 s) que trava numa respiração rouca, sirene invertida longe, corte seco | rádio na névoa vermelha |
| `mod/42/media/sound/NOM_DevRadioBlack.ogg` | portadora morta (9 s): contagem de cinco bipes descendo e o motivo, e o rádio morre | rádio na névoa preta (sprint 0038) |
| `mod/42/media/sound/NOM_DevSpeaker.ogg` | caixa de som de poste (7 s): zumbido de terra na corneta, pulsos graves de passada, microfonia cortada seca, eco de rua | caixa de som na névoa |
| `mod/42/media/sound/NOM_DevCar.ogg` | rádio de carro ligando sozinho, ouvido de fora (8 s): relé, busca de estação, contagem de cinco sílabas, abafado pela lataria | rádio de carro na névoa |
| `mod/42/media/sound/NOM_DevBurst.ogg` | estouro de estática de aparelho (3 s): chiado na banda AM que cresce, crepitação e rajadas de arco, corte seco | presságio da sirene e aparelho perto do Sem-rosto |

Pra regerar: `python3 scripts/gen_sounds.py` (ou só alguns: `python3 scripts/gen_sounds.py NOM_DevTv`).
A síntese dos aparelhos usa as peças de [`scripts/nom_synth.py`](scripts/nom_synth.py). Os sons
são declarados em `mod/42/media/scripts/NOM_sounds.txt`.

## Imagens

**Arte de lançamento: Johan** (sprint 0037b, [ADR-019](docs/architecture/adr-019-arte-de-lancamento.md)).
Exceção à regra de tudo gerado por script, por decisão dele (AGENTS.md, 2026-10-06). As fontes
ficam reduzidas em `docs/art/`; o script [`scripts/gen_images.py`](scripts/gen_images.py)
(numpy + Pillow) só redimensiona, separa as cores e tinge. Nenhuma captura de tela do jogo,
nada de outro mod.

| Arquivo | Tamanho | Uso |
|---|---|---|
| `docs/art/NOM_Post.png` | 768×768 | fonte do pôster oficial: a parede descascando com "NOISE OF MIST" |
| `docs/art/NOM_Preview_Cinza.png` | 768×768 | fonte da preview oficial do Workshop (cinza) |
| `docs/art/NOM_Preview_Vermelha.png` | 768×768 | fonte do pôster de staging (vermelha) |
| `docs/art/NOM_Icon.png` | 768×768 | fonte do ícone: "NOM" enferrujado na névoa |
| `docs/art/NOM_Banner.png` | 1280×720 | banner do README e da descrição do Workshop |
| `mod/42/poster.png` | 512×512 | painel de informações do mod no jogo (`mod.info`, `poster=`) |
| `mod/42/icon.png` | 64×64 | ícone na lista de mods (`mod.info`, `icon=`) |
| `docs/workshop/preview.png` | 512×512 | imagem do item no Steam Workshop (copiada pelo `scripts/build-workshop.sh`) |
| `docs/workshop/release-v1.0.0.md` | texto | notas de release da v1.0.0 (Workshop / GitHub); não é asset |
| `mod2/42/poster.png`, `mod3/42/poster.png` | 512×512 | painel dos mods opcionais (shader e volumétrica): o pôster com as cores separadas |
| `mod2/42/icon.png`, `mod3/42/icon.png` | 64×64 | ícone dos mods opcionais: o ícone com as cores separadas |
| `docs/art/staging/poster.png` | 512×512 | pôster do mod de staging (a preview vermelha), aplicado só na cópia do `scripts/dev-sync.sh` |
| `docs/art/staging/icon.png` | 64×64 | ícone do mod de staging: o oficial avermelhado, aplicado só na cópia do `scripts/dev-sync.sh` |

Pra regerar: `python3 scripts/gen_images.py` (com arte nova do Johan:
`python3 scripts/gen_images.py --importar ~/Downloads`, que reduz os originais pra `docs/art/`).

## Texturas

Geradas pelo script [`scripts/gen_textures.py`](scripts/gen_textures.py) (numpy + Pillow,
semente fixa; rodar de novo dá os mesmos bytes): rachaduras de Voronoi, veias em
isolinhas de ruído, chiado em blocos, fios e escorridos desenhados por código, em contraste
cheio (sprint 0014). Nenhum pixel do jogo: da textura vanilla que cada modelo usa só se
conferiu o **tamanho** (e, na pele de zumbi, onde fica o rosto, pra fuligem da Carpideira).
Direção de arte em [docs/gdd/art-direction.md](docs/gdd/art-direction.md).

| Arquivo | Tamanho | Uso |
|---|---|---|
| `mod/42/media/textures/Body/NOM_Estalador.png` | 256×256 | pele do Estalador: porcelana quase branca, rachaduras grossas pretas |
| `mod/42/media/textures/Body/NOM_Corredor.png` | 256×256 | pele do Corredor: cinza clara, veias grossas quase pretas |
| `mod/42/media/textures/Body/NOM_Carpideira.png` | 256×256 | pele da Carpideira: muito pálida, escorridos de fuligem, fuligem nos olhos |
| `mod/42/media/textures/Body/NOM_Ticao.png` | 256×256 | pele do Tição (sprint 0038): carvão em placas pequenas, rachaduras finas de brasa viva e apagando |
| `mod/42/media/textures/NOM/NOM_EstaladorVenda.png` | 128×128 | venda do Estalador até a 0040 (nos óculos de esqui vanilla): atadura em faixas, arame farpado ferrugem, sangue seco. Fica pra voltar a venda 3D da 0041 com três linhas por XML |
| `mod/42/media/textures/NOM/NOM_CorredorBoca.png` | 128×128 | boca rasgada do Corredor até a 0041 (na máscara cirúrgica vanilla): vermelho escuro, rasgo preto, dentes brancos. Fica pra voltar a boca 3D da 0042 pelo XML |
| `mod/42/media/textures/NOM/NOM_SemRostoEstatica.png` | 128×128 | rosto do Sem-rosto: chiado de TV em blocos preto/branco, faixas rasgadas (na balaclava vanilla até a 0041; na casca 3D desde a 0042) |
| `mod/42/media/textures/NOM/NOM_CarpideiraCabelo.png` | 128×128 | cabelo preto da Carpideira com mechas brancas, caindo no rosto (no véu de noiva vanilla até a 0041). Fica pra voltar o cabelo 3D da 0042 pelo XML |
| `mod/42/media/textures/NOM/NOM_EcoCinza.png` | 256×256 | quase branco com salpicos pequenos e escorridos finos de cinza, no corpo todo do Eco |
| `mod/42/media/textures/NOM/NOM_EcoVeu.png` | 128×128 | véu quase branco do Eco, salpicado, mais escuro nas bordas |
| `mod/42/media/textures/NOM/NOM_Brasa.png` | 256×256 | casca de brasa da mutação (sprint 0022): carvão quase preto em placas, rachaduras largas em brasa laranja |
| `mod/42/media/textures/NOM/ScreenFx/NOM_Grain1.png` … `NOM_Grain4.png` (`mod/42/media/textures/NOM/ScreenFx/NOM_Grain2.png`, `mod/42/media/textures/NOM/ScreenFx/NOM_Grain3.png`, `mod/42/media/textures/NOM/ScreenFx/NOM_Grain4.png`) | 256×256 | grão de filme da névoa, quatro quadros de ruído (efeitos de tela, sprint 0013) |
| `mod/42/media/textures/NOM/ScreenFx/NOM_Vignette.png` | 512×512 | vinheta da tela: transparente no centro, opaca nas bordas |
| `mod/42/media/textures/NOM/ScreenFx/NOM_Lines.png` | 512×256 | linhas horizontais de chiado (perto do Sem-rosto) |
| `mod/42/media/textures/NOM/ScreenFx/NOM_White.png` | 8×8 | branco opaco, tingido de vermelho no pulso do grito da Carpideira |
| `mod/42/media/textures/NOM/ScreenFx/NOM_NevoaEstatica.png` | 256×256 | estática da névoa na tela: chiado fino em tons de cinza, em mosaico, tingido pela cor da névoa (sprint 0034) |
| `mod/42/media/textures/NOM/NOM_Lascas.png` | 256×128 | lascas de tinta do Outro Mundo (sprint 0035): sprite sheet de 8 quadros de giro × 4 formatos, contorno serrilhado e lascado, tinta velha suja com craquelê e fio de borda clara falhado, ferrugem marrom escamando, verso ferrugem, de perfil mais escura, fundo transparente; tingidas pela cor da névoa no desenho |
| `mod/42/media/textures/NOM/NOM_Cinza.png` | 16×16 | cinza do Outro Mundo (sprint 0035): floco torto, claro e macio em tons de cinza, tingido pela cor da névoa |
| `mod/42/media/textures/NOM/ScreenFx/NOM_SonarAnel.png` | 256×256 | anel do sonar do Estalador (sprint 0037): frente branca fina com rastro macio pra dentro e falhas suaves, fundo transparente; achatado 2:1 no chão e tingido pela cor da névoa no desenho |

Pra regerar: `python3 scripts/gen_textures.py`.

### Outro Mundo: decalques da erosão (sprint 0035)

Gerados pelo script [`scripts/gen_tiles.py`](scripts/gen_tiles.py) (numpy + Pillow, semente fixa;
rodar de novo dá os mesmos bytes e não mexe em nenhuma outra textura). Cada desenho é feito num
plano (o chão visto de cima, a parede de frente) e mapeado pro losango do chão ou pra face
isométrica da parede com sub-amostras (alfa antisserrilhado, o RGB transparente herda o dos
vizinhos). Do jogo só a **geometria** do quadro 128×256, medida no spike
([spike-sprite-proprio.md](docs/sprints/sprint-0035-silent-hill/spike-sprite-proprio.md) §3);
nenhum pixel. A lista com lado e tipo vai em `mod/42/media/lua/shared/NOM_OwnSpriteList.lua`,
escrita pelo mesmo script.

| Arquivo | Tamanho | Uso |
|---|---|---|
| `mod/42/media/textures/NOM/OutroMundo/NOM_OM_Grade_F_01.png`, `mod/42/media/textures/NOM/OutroMundo/NOM_OM_Grade_F_02.png`, `mod/42/media/textures/NOM/OutroMundo/NOM_OM_Grade_F_03.png`, `mod/42/media/textures/NOM/OutroMundo/NOM_OM_Grade_F_04.png`, `mod/42/media/textures/NOM/OutroMundo/NOM_OM_Grade_F_05.png` | 128×256 | Outro Mundo (sprint 0035), chão: grade de piso industrial (quadrados, losangos ou barras) num quadro de cantoneira com parafusos, ferrugem e entulho; o vão é escuro com alfa parcial (o chão do jogo aparece apagado por baixo), a grade faz sombra; duas com o canto arrancado |
| `mod/42/media/textures/NOM/OutroMundo/NOM_OM_Ferrugem_F_01.png`, `mod/42/media/textures/NOM/OutroMundo/NOM_OM_Ferrugem_F_02.png`, `mod/42/media/textures/NOM/OutroMundo/NOM_OM_Ferrugem_F_03.png`, `mod/42/media/textures/NOM/OutroMundo/NOM_OM_Ferrugem_F_04.png`, `mod/42/media/textures/NOM/OutroMundo/NOM_OM_Ferrugem_F_05.png` | 128×256 | Outro Mundo (sprint 0035), chão: mancha de ferrugem no chão: auréola de óxido, marca de maré seca, miolo em escamas com trinca e farelo em volta |
| `mod/42/media/textures/NOM/OutroMundo/NOM_OM_Chapa_F_01.png`, `mod/42/media/textures/NOM/OutroMundo/NOM_OM_Chapa_F_02.png`, `mod/42/media/textures/NOM/OutroMundo/NOM_OM_Chapa_F_03.png`, `mod/42/media/textures/NOM/OutroMundo/NOM_OM_Chapa_F_04.png`, `mod/42/media/textures/NOM/OutroMundo/NOM_OM_Chapa_F_05.png` | 128×256 | Outro Mundo (sprint 0035), chão: chapa de aço rebitada (lisa escovada ou xadrez antiderrapante; uma ou duas), riscos, óleo seco, ferrugem na borda e nos rebites, canto amassado, sombra no chão |
| `mod/42/media/textures/NOM/OutroMundo/NOM_OM_Tinta_F_01.png`, `mod/42/media/textures/NOM/OutroMundo/NOM_OM_Tinta_F_02.png`, `mod/42/media/textures/NOM/OutroMundo/NOM_OM_Tinta_F_03.png`, `mod/42/media/textures/NOM/OutroMundo/NOM_OM_Tinta_F_04.png`, `mod/42/media/textures/NOM/OutroMundo/NOM_OM_Tinta_F_05.png` | 128×256 | Outro Mundo (sprint 0035), chão: película de tinta velha lascada no chão (creme, verde, amarelo industrial, cinza-azulado), craquelê, lascas com o avesso claro; o chão aparece nos buracos |
| `mod/42/media/textures/NOM/OutroMundo/NOM_OM_Tinta_W_01.png`, `mod/42/media/textures/NOM/OutroMundo/NOM_OM_Tinta_W_02.png`, `mod/42/media/textures/NOM/OutroMundo/NOM_OM_Tinta_W_03.png`, `mod/42/media/textures/NOM/OutroMundo/NOM_OM_Tinta_W_04.png`, `mod/42/media/textures/NOM/OutroMundo/NOM_OM_Tinta_W_05.png` | 128×256 | Outro Mundo (sprint 0035), parede oeste: tinta descolando em placas: demão velha de outra cor e reboco ou chapa enferrujada por baixo, borda levantada (avesso claro, sombra no buraco), sujeira, craquelê e água escorrendo; a tinta que fica é a parede do jogo (transparente) |
| `mod/42/media/textures/NOM/OutroMundo/NOM_OM_Ferrugem_W_01.png`, `mod/42/media/textures/NOM/OutroMundo/NOM_OM_Ferrugem_W_02.png`, `mod/42/media/textures/NOM/OutroMundo/NOM_OM_Ferrugem_W_03.png`, `mod/42/media/textures/NOM/OutroMundo/NOM_OM_Ferrugem_W_04.png`, `mod/42/media/textures/NOM/OutroMundo/NOM_OM_Ferrugem_W_05.png` | 128×256 | Outro Mundo (sprint 0035), parede oeste: escorridos de ferrugem em leque saindo de parafusos, de uma emenda rebitada ou do alto, e bolhas de ferrugem furando a tinta |
| `mod/42/media/textures/NOM/OutroMundo/NOM_OM_Descasca_W_01.png`, `mod/42/media/textures/NOM/OutroMundo/NOM_OM_Descasca_W_02.png`, `mod/42/media/textures/NOM/OutroMundo/NOM_OM_Descasca_W_03.png`, `mod/42/media/textures/NOM/OutroMundo/NOM_OM_Descasca_W_04.png`, `mod/42/media/textures/NOM/OutroMundo/NOM_OM_Descasca_W_05.png` | 128×256 | Outro Mundo (sprint 0035), parede oeste: a parede quase toda descascada (reboco, chapa rebitada enferrujada ou os dois), só ilhas da tinta do jogo |
| `mod/42/media/textures/NOM/OutroMundo/NOM_OM_Tinta_N_01.png`, `mod/42/media/textures/NOM/OutroMundo/NOM_OM_Tinta_N_02.png`, `mod/42/media/textures/NOM/OutroMundo/NOM_OM_Tinta_N_03.png`, `mod/42/media/textures/NOM/OutroMundo/NOM_OM_Tinta_N_04.png`, `mod/42/media/textures/NOM/OutroMundo/NOM_OM_Tinta_N_05.png` | 128×256 | Outro Mundo (sprint 0035), parede norte: tinta descolando em placas: demão velha de outra cor e reboco ou chapa enferrujada por baixo, borda levantada (avesso claro, sombra no buraco), sujeira, craquelê e água escorrendo; a tinta que fica é a parede do jogo (transparente) |
| `mod/42/media/textures/NOM/OutroMundo/NOM_OM_Ferrugem_N_01.png`, `mod/42/media/textures/NOM/OutroMundo/NOM_OM_Ferrugem_N_02.png`, `mod/42/media/textures/NOM/OutroMundo/NOM_OM_Ferrugem_N_03.png`, `mod/42/media/textures/NOM/OutroMundo/NOM_OM_Ferrugem_N_04.png`, `mod/42/media/textures/NOM/OutroMundo/NOM_OM_Ferrugem_N_05.png` | 128×256 | Outro Mundo (sprint 0035), parede norte: escorridos de ferrugem em leque saindo de parafusos, de uma emenda rebitada ou do alto, e bolhas de ferrugem furando a tinta |
| `mod/42/media/textures/NOM/OutroMundo/NOM_OM_Descasca_N_01.png`, `mod/42/media/textures/NOM/OutroMundo/NOM_OM_Descasca_N_02.png`, `mod/42/media/textures/NOM/OutroMundo/NOM_OM_Descasca_N_03.png`, `mod/42/media/textures/NOM/OutroMundo/NOM_OM_Descasca_N_04.png`, `mod/42/media/textures/NOM/OutroMundo/NOM_OM_Descasca_N_05.png` | 128×256 | Outro Mundo (sprint 0035), parede norte: a parede quase toda descascada (reboco, chapa rebitada enferrujada ou os dois), só ilhas da tinta do jogo |
| `mod/42/media/textures/NOM/OutroMundo/NOM_OM_Cinza_F_01.png`, `mod/42/media/textures/NOM/OutroMundo/NOM_OM_Cinza_F_02.png`, `mod/42/media/textures/NOM/OutroMundo/NOM_OM_Cinza_F_03.png`, `mod/42/media/textures/NOM/OutroMundo/NOM_OM_Cinza_F_04.png`, `mod/42/media/textures/NOM/OutroMundo/NOM_OM_Cinza_F_05.png` | 128×256 | Outro Mundo queimado (névoa preta, sprint 0039), chão: monte de cinza assentada, grão claro, pedacinho de carvão e farelo em volta |
| `mod/42/media/textures/NOM/OutroMundo/NOM_OM_Brasa_F_01.png`, `mod/42/media/textures/NOM/OutroMundo/NOM_OM_Brasa_F_02.png`, `mod/42/media/textures/NOM/OutroMundo/NOM_OM_Brasa_F_03.png`, `mod/42/media/textures/NOM/OutroMundo/NOM_OM_Brasa_F_04.png`, `mod/42/media/textures/NOM/OutroMundo/NOM_OM_Brasa_F_05.png` | 128×256 | Outro Mundo queimado (névoa preta, sprint 0039), chão: pedaços de carvão rachado com brasa fraca em metade das trincas (apagando), casca de cinza |
| `mod/42/media/textures/NOM/OutroMundo/NOM_OM_Fuligem_W_01.png`, `mod/42/media/textures/NOM/OutroMundo/NOM_OM_Fuligem_W_02.png`, `mod/42/media/textures/NOM/OutroMundo/NOM_OM_Fuligem_W_03.png`, `mod/42/media/textures/NOM/OutroMundo/NOM_OM_Fuligem_W_04.png`, `mod/42/media/textures/NOM/OutroMundo/NOM_OM_Fuligem_W_05.png` | 128×256 | Outro Mundo queimado (névoa preta, sprint 0039), parede oeste: fuligem subindo do rodapé em plumas que afinam, escura embaixo |
| `mod/42/media/textures/NOM/OutroMundo/NOM_OM_Fuligem_N_01.png`, `mod/42/media/textures/NOM/OutroMundo/NOM_OM_Fuligem_N_02.png`, `mod/42/media/textures/NOM/OutroMundo/NOM_OM_Fuligem_N_03.png`, `mod/42/media/textures/NOM/OutroMundo/NOM_OM_Fuligem_N_04.png`, `mod/42/media/textures/NOM/OutroMundo/NOM_OM_Fuligem_N_05.png` | 128×256 | Outro Mundo queimado (névoa preta, sprint 0039), parede norte: fuligem subindo do rodapé em plumas que afinam, escura embaixo |
| `mod/42/media/textures/NOM/OutroMundo/NOM_OM_Tentaculo_F_01.png`, `mod/42/media/textures/NOM/OutroMundo/NOM_OM_Tentaculo_F_02.png`, `mod/42/media/textures/NOM/OutroMundo/NOM_OM_Tentaculo_F_03.png`, `mod/42/media/textures/NOM/OutroMundo/NOM_OM_Tentaculo_F_04.png`, `mod/42/media/textures/NOM/OutroMundo/NOM_OM_Tentaculo_F_05.png` | 128×256 | Outro Mundo da névoa vermelha (sprint 0040), chão: buraco escuro de onde saem tentáculos pretos que se arrastam e enrolam, com gomos e brilho molhado |
| `mod/42/media/textures/NOM/OutroMundo/NOM_OM_Tentaculo_W_01.png`, `mod/42/media/textures/NOM/OutroMundo/NOM_OM_Tentaculo_W_02.png`, `mod/42/media/textures/NOM/OutroMundo/NOM_OM_Tentaculo_W_03.png`, `mod/42/media/textures/NOM/OutroMundo/NOM_OM_Tentaculo_W_04.png`, `mod/42/media/textures/NOM/OutroMundo/NOM_OM_Tentaculo_W_05.png` | 128×256 | Outro Mundo da névoa vermelha (sprint 0040), parede oeste: tentáculos pretos subindo do rodapé, com ramos finos e mancha úmida |
| `mod/42/media/textures/NOM/OutroMundo/NOM_OM_Tentaculo_N_01.png`, `mod/42/media/textures/NOM/OutroMundo/NOM_OM_Tentaculo_N_02.png`, `mod/42/media/textures/NOM/OutroMundo/NOM_OM_Tentaculo_N_03.png`, `mod/42/media/textures/NOM/OutroMundo/NOM_OM_Tentaculo_N_04.png`, `mod/42/media/textures/NOM/OutroMundo/NOM_OM_Tentaculo_N_05.png` | 128×256 | Outro Mundo da névoa vermelha (sprint 0040), parede norte: tentáculos pretos subindo do rodapé, com ramos finos e mancha úmida |

Pra regerar: `python3 scripts/gen_tiles.py` (com `--preview`, só monta a prévia em
`/tmp/om_tiles_preview.png`).

## Modelos 3D (sprints 0041 a 0043)

Gerados pelo script [`scripts/gen_models.py`](scripts/gen_models.py) (Python puro, numpy +
Pillow, sem sorteio: rodar de novo dá os mesmos bytes): malha varrida por código (perfil
arredondado em volta da cabeça, tubos do arame, tetraedros das farpas, nó e pontas), escrita em
`.x` texto. Do jogo só **números** medidos nos `.x` vanilla: o quadro do osso da cabeça, o
winding das faces e as medidas da cabeça tiradas de peças vanilla (óculos de esqui na altura
dos olhos; touca de banho, máscara de hóquei, máscara cirúrgica, piercing de nariz e capacete
fechado pro alto do crânio, nariz, queixo e boca). Nenhum vértice copiado. A textura sai do
mesmo script, casada com o UV. Os XML das peças (e os gêmeos `*Fx.xml`) citam pelo nome curto:
`static\clothes\NOM_M_EstaladorVenda`, `static\clothes\NOM_F_EstaladorVenda` (`NOM_EstaladorVenda.xml`),
`static\clothes\NOM_M_CorredorBoca`, `static\clothes\NOM_F_CorredorBoca` (`NOM_CorredorBoca.xml`),
`static\clothes\NOM_M_SemRostoEstatica`, `static\clothes\NOM_F_SemRostoEstatica` (`NOM_SemRostoEstatica.xml`),
`static\clothes\NOM_M_CarpideiraCabelo`, `static\clothes\NOM_F_CarpideiraCabelo` (`NOM_CarpideiraCabelo.xml`),
`static\clothes\NOM_M_TicaoCrosta`, `static\clothes\NOM_F_TicaoCrosta` (`NOM_TicaoCrosta.xml`).
Nenhum modelo aqui foi gerado por IA (o teste de IA da 0043 ficou fora do repositório; ADR-020).

| Arquivo | Tamanho | Uso |
|---|---|---|
| `mod/42/media/models_X/Static/Clothes/NOM_M_EstaladorVenda.x`, `mod/42/media/models_X/Static/Clothes/NOM_F_EstaladorVenda.x` | ~1900 vértices | venda do Estalador em 3D: atadura com volume em volta dos olhos, dois arames farpados enrolados por cima, nó atrás com as duas pontas caindo; um por sexo |
| `mod/42/media/textures/NOM/NOM_EstaladorVenda3D.png` | 128×128 | textura da venda 3D: pano em faixas com sangue seco nos olhos (espelhado em cima e embaixo) e a ferrugem do arame numa faixa no meio |
| `mod/42/media/models_X/Static/Clothes/NOM_M_CorredorBoca.x`, `mod/42/media/models_X/Static/Clothes/NOM_F_CorredorBoca.x` | ~700 vértices | boca do Corredor em 3D (sprint 0042): cavidade escura em lente colada no rosto, lábio em tubo rasgado e irregular, oito dentes em ponta, dois rasgos subindo pras orelhas; um por sexo |
| `mod/42/media/textures/NOM/NOM_CorredorBoca3D.png` | 128×128 | textura da boca 3D: dente sujo, lábio vermelho vivo, carne escura e o fundo quase preto em faixas (espelhado em cima e embaixo) |
| `mod/42/media/models_X/Static/Clothes/NOM_M_SemRostoEstatica.x`, `mod/42/media/models_X/Static/Clothes/NOM_F_SemRostoEstatica.x` | ~500 vértices | casca do Sem-rosto (sprint 0042): superelipsoide liso em volta da cabeça inteira, sem nariz, olho nem boca; usa a textura de chiado `NOM_SemRostoEstatica.png` de cima |
| `mod/42/media/models_X/Static/Clothes/NOM_M_CarpideiraCabelo.x`, `mod/42/media/models_X/Static/Clothes/NOM_F_CarpideiraCabelo.x` | ~1650 vértices | cabelo da Carpideira em 3D (sprint 0042): 36 mechas em fita saindo do alto da cabeça e caindo como cortina na frente do rosto, três delas brancas; um por sexo |
| `mod/42/media/textures/NOM/NOM_CarpideiraCabelo3D.png` | 128×128 | textura do cabelo 3D: fios pretos com brilho fraco e a faixa das mechas brancas no meio (espelhado em cima e embaixo) |
| `mod/42/media/models_X/Static/Clothes/NOM_M_TicaoCrosta.x`, `mod/42/media/models_X/Static/Clothes/NOM_F_TicaoCrosta.x` | ~1500 vértices | crosta do Tição (sprint 0043): casca de carvão em placas de alturas diferentes na cabeça inteira, dois olhos de brasa saindo da frente, 14 lascas no alto e atrás, três fitas de fumaça subindo; um por sexo |
| `mod/42/media/textures/NOM/NOM_TicaoCrosta3D.png` | 128×128 | textura da crosta: carvão com rachaduras de brasa (Voronoi que fecha na volta da cabeça), faixa de carvão liso, fumaça clara e brasa no meio (espelhado em cima e embaixo) |

Pra regerar: `python3 scripts/gen_models.py` (prévia: `python3 scripts/preview_models.py`).

## Shader

| Arquivo | O que é |
|---|---|
| `mod2/42/media/shaders/screen.frag` | pós-processo de tela do mod opcional `NevoaEOutroMundo_Shader` (sprint 0013): **código original**, escrito pro mod (MIT). Do jogo só a interface: nomes e tipos dos uniforms que o `WeatherShader` manda, a entrada `vUV` do `screen.vert` vanilla e a saída `gl_FragColor`. Nenhuma linha do `screen.frag` da The Indie Stone (`tests/test_shader.lua` confere contra o arquivo instalado) |
| `mod/42/media/shaders/NOM_Dissolve.vert`, `mod/42/media/shaders/NOM_Dissolve_static.vert`, `mod/42/media/shaders/NOM_Dissolve.frag` | dissolve das peças do mod (sprint 0018, ADR-016), pelo `<m_Shader>` dos itens `*Fx`, da casca do Eco e da casca de brasa (sprint 0022): **código original**, escrito pro mod (MIT). Do jogo só a interface: atributos pelo índice, paleta de ossos, nomes e tipos dos uniforms que o Java do `skinnedmodel.Shader` manda e a saída `gl_FragColor`. Nenhuma linha do `basicEffect*.vert/.frag` da The Indie Stone (`tests/test_dissolve_shader.lua` confere contra os arquivos instalados) |

## Conteúdo vanilla referenciado (nada copiado)

| Onde | O que | Referência |
|---|---|---|
| `mod/42/media/clothing/clothing.xml` (outfit `NOM_Eco`) | cinza no corpo todo (item do mod, sem modelo: camada no corpo como a do `Gown_Hospital`) | GUID `e8a21b0f-4b56-4b3d-8fab-2ea78dd84e8d` (`NOM_EcoCinza`, do mod) |
| `mod/42/media/clothing/clothing.xml` (outfit `NOM_Eco`) | véu de fumaça (item do mod) | GUID `82f80e18-a7cf-4312-949c-23879a1e3820` (`NOM_EcoVeu`, do mod) |
| `clothingItems/NOM_EcoVeu.xml` | modelo do véu de noiva (`Hat_WeddingVeil`) | `skinned\clothes\m_weddingveil`, `skinned\clothes\f_weddingveil` |
| `clothingItems/NOM_EcoVeuFx.xml` (sprint 0018) | gêmeo do véu do Eco com o shader do dissolve | o mesmo modelo vanilla do véu, pelo nome (as peças dos monstros usam modelos do mod desde a 0041 e a 0042) |
| `clothingItems/NOM_Brasa.xml` (sprint 0022) | modelo da roupa de proteção (`HazmatSuit`), casca de brasa do corpo inteiro na mutação, sem máscara | `media\models_X\Skinned\Clothes\Bob_Hazmat.X`, `media\models_X\Skinned\Clothes\Kate_Hazmat.X` |
| `clothingItems/NOM_EcoCasca.xml` (sprint 0018) | modelo da roupa de proteção (`HazmatSuit`), casca de cinza do Eco na morte, e a lista de máscaras de corpo dele (números) | `media\models_X\Skinned\Clothes\Bob_Hazmat.X`, `media\models_X\Skinned\Clothes\Kate_Hazmat.X` |
| `clothingItems/NOM_*.xml` (menos `NOM_EcoCinza`) | máscaras de corpo dos chapéus | pasta `media/textures/Clothes/Hat/Masks`, pelo caminho |
| `scripts/NOM_clothing.txt` | ícones dos itens | `SkiGogglesWhite`, `SurgicalMaskBlue`, `Balaclava`, `VeilWedding`, `HospitalGown`, `Hazmatsuit`, pelo nome |
| `NOM_FogOverlays.lua` | sujeira tingida de ferrugem | sprites `overlay_grime_floor_01_0` a `_95`, por nome |
| `NOM_FogVignette.lua` | vinheta da névoa | efeito de tela do modo de busca do jogo (`getSearchMode()`), sem textura própria |
| `NOM_ScreenFx.lua` | efeitos de tela | desenho pela UI do jogo (`ISUIElement`), com as texturas originais acima |
| Variantes, Eco, Sem-rosto, Carpideira | corpo e animação | zumbis vanilla; o mod muda comportamento, pele e peças por cima (texturas acima) |
