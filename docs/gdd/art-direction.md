# Direção de arte dos monstros

| Campo | Valor |
|-------|-------|
| Status | `accepted` |
| Sprint | 0012 (monstros), 0013 (tela na névoa), 0014 (contraste dos monstros), 0016 (monstro sem roupa comum), 0018 (dissolve) |
| Decisão | Johan, 05/10/2026: cada monstro com visual próprio, feito de **texturas procedurais originais em modelos 3D vanilla** (máscaras, capuzes, véus, camadas no corpo), citados pelo nome. Sem modelo 3D novo (pode vir depois). "Não quero ser igual TLOU... quero me inspirar, então pode ser criativo." |

## Regra

- **O visual conta o que o monstro faz**, ligado aos temas do mod: névoa, chiado de rádio, o
  Outro Mundo. Nada de cabeça de fungo de *clicker*/cordyceps, nada de enfermeira ou
  Pyramid Head de Silent Hill.
- **Legível no zoom normal, de frente:** um zumbi tem uns 60–100 px na tela. Conta a cor e
  a silhueta da peça na cabeça, não o detalhe. Cada monstro tem uma cor dominante própria.
- **Contraste cheio, formas grandes (sprint 0014).** Visto no jogo (05/10/2026), o chiado
  fino da 0012 virou uma balaclava de lã cinza: na câmera isométrica, com o tom escuro da
  névoa cortando 30–50% do brilho (ADR-008/010), ruído fino e cinza médio somem. Toda
  textura de monstro usa quase preto e quase branco, formas de 1/8 da largura pra cima,
  poucas cores e brilho puxado pra cima. `tests/test_look_contrast.py` reprova a textura
  que voltar a ser "lã"; `scripts/preview_textures.py` mostra cada uma a 64 px, normal e
  escurecida/avermelhada como na névoa
  ([prévia](../sprints/sprint-0014-contraste-visual/preview.png)).
- **O Eco fica fora da regra das formas grandes.** Mancha grande preta e branca no corpo
  todo leu como couro de vaca na prévia. O Eco lê por ser **muito mais claro** que qualquer
  outro zumbi, não pelo desenho: base quase branca, salpico pequeno e esparso, escorrido
  fino. O teste dele confere média de luminância alta, pouco cinza médio e pouca área
  escura, no lugar do desvio de longe.
- **Nada de grade em diagonal.** A venda do Estalador em X repetido leu como toalha de
  piquenique; atadura é faixa horizontal. O teste da venda exige que a luminância varie
  bem mais de linha pra linha do que de coluna pra coluna.
- **Desenho que não depende do mapa UV:** rachadura, veia, chiado, fio, escorrido. Vale em
  qualquer ponto da textura, então a peça inteira vira o material e nada é copiado nem
  "decalcado" da textura vanilla (dela só se usa o tamanho). Única exceção: a fuligem nos
  olhos da Carpideira, posta onde fica o rosto na pele de zumbi vanilla (o layout, visto a
  olho, é o mesmo no masculino e no feminino). A balaclava vanilla é um tricô uniforme, sem
  região de rosto visível: o chiado do Sem-rosto vale na cabeça inteira.
- **Uma pele e uma peça por variante, e nada da roupa comum (sprint 0016).** ~~A roupa do
  zumbi fica.~~ Visto no jogo pelo Johan (05/10/2026): "os zombies quando se transformam
  devem ficar sem roupa ... tudo que contribui pro monstro fica, mas de resto não ... tem
  monstro que tem coisa na cabeça e fica estranho". Enquanto é variante, a roupa vanilla
  (camiseta, calça, chapéu, óculos, atadura) some do desenho; ficam a pele e a peça do mod
  e as feridas do corpo (camadas `ZedDmg_*` e `Wound_*`, que são carne, não roupa). Quando
  a variante acaba (fim da névoa, troca de tipo, reaproveitamento, morte), a roupa volta, e
  o corpo e o loot são os do zumbi comum. Exceção de roupa (o Johan gostou de "uma saia
  estranha", sem saber qual): um padrão na lista `NOM_VariantLook.KEEP`. O Eco não muda (já
  só veste itens do mod). **O monstro larga tudo** (Johan, 05/10/2026): a roupa escondida
  também não vale no jogo (morde através de máscara e capacete, sem armadura nem modificador
  de visão/audição, chapéu não cai), até a variante acabar.
- Texturas: `scripts/gen_textures.py`. Técnica: [ADR-012](../architecture/adr-012-visual-das-variantes.md).

## Os monstros

| Monstro | Pele | Peça (modelo vanilla) | Cor que lê de longe |
|---|---|---|---|
| Estalador | porcelana quase branca em placas grandes, rachaduras grossas pretas | venda de atadura: faixas horizontais branco-sujas com frestas escuras, dois arames farpados ferrugem-escuros enrolados de lado a lado e uma mancha de sangue seco (óculos de esqui, `Glasses_SkiGoggles`) | branco trincado + atadura com arame nos olhos |
| Corredor | cinza de cinza clara, veias grossas roxo-pretas | boca rasgada: vermelho escuro saturado, um rasgo preto de lado a lado com dentes brancos grandes e escorridos pretos (máscara cirúrgica, `Hat_SurgicalMask`) | cinza com veias + boca vermelha e preta |
| Sem-rosto | a do zumbi | chiado de TV em blocos preto/branco, faixas de varredura e imagem rasgada na horizontal, quase sem cinza, a cabeça inteira (balaclava inteira, `Hat_BalaclavaFull`) | cabeça de TV fora do ar |
| Carpideira | muito pálida, escorridos grossos de fuligem de cima pra baixo, fuligem debaixo dos olhos | cabelo preto de piche com três mechas brancas, caindo no rosto (véu de noiva, `Hat_WeddingVeil`) | cabeça preta caída sobre corpo quase branco |
| Eco | coberta: quase branca, salpicos pequenos e esparsos de cinza e poucos escorridos finos na vertical | véu do mesmo jeito, mais escuro só nas bordas (véu de noiva) | o mais claro da névoa: fantasma coberto de cinza |

**Por quê, um por um:**

- **Estalador** — cego que vive de som: os olhos tapados dizem "não te vê"; a pele de
  porcelana rachada sugere que o corpo ressoa e trinca quando ele estala.
- **Corredor** — corre, grita e chama a horda: a boca rasgada larga demais é feita pro grito,
  e a pele esticada com veias diz esforço.
- **Sem-rosto** — some quando visto, e o rádio chia quando ele está perto: o rosto é o mesmo
  chiado do rádio, o aviso que o jogador já aprendeu a temer.
- **Carpideira** — parada, chorando, e depois o grito: o cabelo caído sobre o rosto baixo e as
  mãos e o rosto sujos de fuligem como quem enxugou lágrimas de cinza leem "não chegue perto".
  O visual é o mesmo quando ela grita (sem animação): a imobilidade e o cabelo bastam.
- **Eco** — alma fraca de um morto, some no amanhecer: cinza e fumaça com forma de gente, sem
  rosto, claro no escuro.

## Queimar ao surgir e ao sumir (sprint 0018)

Pedido do Johan (05/10/2026): o efeito de *dissolve* (o limiar sobre ruído com a borda acesa, do
tutorial clássico de Unity) quando o Eco morre e quando o zumbi vira monstro e volta.

- **A peça do monstro queima pra existir e queima pra sumir.** Na mutação, a venda, a boca, o
  rosto de chiado e o cabelo se formam em ~1 s, em manchas grandes com a borda em brasa laranja;
  no fim da variante, se desfazem do mesmo jeito, e só então a roupa comum volta. A pele troca de
  uma vez: o corpo do zumbi não queima (limite do jogo, o corpo usa o shader vanilla) e fica a no
  mínimo 85% de opacidade durante o efeito.
- **O Eco queima até a cinza.** Ao morrer, o corpo vira uma casca de cinza (a roupa de proteção
  vanilla, pintada com a cinza do Eco), que queima com o véu em ~1 s; o que sobra some em meio
  segundo, brasas e cinza sobem, e nada fica no chão. **Casca: decisão de arte do Johan
  pendente** (ela muda a silhueta no segundo da morte; sem ela, só o véu queima e o corpo some em
  fade).
- **Só o laranja da brasa** é cor nova: é o fogo do Outro Mundo, não magia. A borda é estreita
  (lê como papel queimando, não como contorno de videogame).
- Efeito colateral aceito: um monstro que sai da vista (o fade vanilla) também queima a peça no
  começo do fade. Combina com a névoa.
- Opção do jogador ("Monstros queimam ao surgir e sumir", Opções > Mods): desligada, a troca é
  instantânea, como antes. Técnica: [ADR-016](../architecture/adr-016-dissolve-e-bloom.md).

## Limites conhecidos

- **Chiado parado:** o item de roupa do B42 só aponta texturas fixas (`textureChoices`,
  `m_BaseTextures` no XML; nenhum campo de animação); trocar a peça a cada quadro refaria o
  modelo inteiro. O Sem-rosto usa um quadro de chiado.
- ~~**Peça por cima de peça.**~~ Resolvido na sprint 0016: a roupa do zumbi some enquanto ele
  é variante, então a peça do mod não atravessa mais chapéu, máscara nem óculos. Na morte, o
  corpo fica com a roupa dele (a do mod sai).
- **Rosto da pele:** a pele do mod não tem olhos nem boca desenhados (o desenho não usa o mapa
  UV, fora a fuligem da Carpideira); o rosto fica coberto pela peça (Estalador, Corredor,
  Carpideira) ou é o próprio tema.

## A tela na névoa (sprint 0013)

Pedido do Johan depois do primeiro teste: a névoa ficou "LINDA", falta a tela. A direção:
**filme velho achado no Outro Mundo**, não câmera de celular nem videogame.

- **Grão** fino, claro, que só se nota no escuro: é a película, não sujeira. Some fora da névoa.
- **Vinheta que respira** devagar, preta: a névoa aperta e afrouxa em volta de quem anda nela.
  Na vermelha, a borda é sangue escuro e aperta mais.
- **Chiado** em linhas horizontais, como imagem de TV fora de sintonia: o mesmo aviso do rádio e
  do rosto do Sem-rosto. Quem já aprendeu a temer o chiado lê na tela que ele está perto.
- **Pulso vermelho** curto no grito da Carpideira: a tela "sente" o grito.
- **Shader opcional:** a película se desalinha (aberração cromática), escorrega (distorção) e
  perde o foco nas bordas. Mesma ideia, mais forte.
- Nada disso tem cor fora da paleta do mod: preto, cinza, sépia da névoa e o vermelho da
  vermelha. Texturas: `scripts/gen_textures.py` (branco com alfa, pintado no desenho).

## O Outro Mundo sangrento (sprint 0015)

Pedido do Johan (05/10): "o Outro Mundo eu imaginei com bastante sangue e com a erosão no máximo".
Na névoa, o lugar em volta é o mesmo lugar, abandonado há décadas e onde alguma coisa sangrou muito.

- **Sangue que conta história:** poças (o miolo escuro, de camadas sobrepostas) com um rastro
  saindo, como algo arrastado; respingo solto entre elas. Nas paredes, escorrido. Não é carpete
  uniforme: é onde aconteceu alguma coisa.
- **Erosão no máximo:** sujeira, rachadura e musgo no chão; rachadura, sujeira e trepadeira nas
  paredes. O que a natureza levaria anos pra fazer, a névoa faz em segundos.
- **Vermelha é pior:** mais poças, mais rastro, mais parede suja.
- Só sprites vanilla pelo nome (nada copiado nem gerado); escurecidos pela luz do lugar, com um
  piso pra ainda se lerem no breu. Técnica: [ADR-015](../architecture/adr-015-outro-mundo-sangrento.md).
