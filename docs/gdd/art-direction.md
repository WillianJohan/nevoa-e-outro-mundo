# Direção de arte dos monstros

| Campo | Valor |
|-------|-------|
| Status | `accepted` |
| Sprint | 0012 (monstros), 0013 (tela na névoa), 0014 (contraste dos monstros), 0016 (monstro sem roupa comum), 0018 (dissolve), 0022 (brasa no corpo inteiro), 0035 (Outro Mundo estilo Silent Hill) |
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
- **Uma pele e peças do mod por variante, e nada da roupa comum vanilla (sprint 0016;
  emenda 0060).** Enquanto é variante, a roupa vanilla some; ficam a pele do mod, a peça
  de cabeça e **a roupa cotidiana/hospitalar do mod** no corpo (`NOM_*Roupa` / manto),
  mais feridas `ZedDmg_*`/`Wound_*`. A 0054 deixou o corpo nu com pele P&B binária e leu
  como grade UV no playtest — a 0060 corrige com midtones + camada de tecido. Quando a
  variante acaba, a roupa vanilla volta. **O monstro larga tudo** no sentido de combate
  (Johan, 05/10/2026): a roupa vanilla escondida não vale (morde através de máscara, etc.).
- Texturas: `scripts/gen_textures.py`. Técnica: [ADR-012](../architecture/adr-012-visual-das-variantes.md).

## Os monstros

| Monstro | Pele | Peça (modelo vanilla, ou nosso desde a 0041) | Cor que lê de longe |
|---|---|---|---|
| Estalador | The Pale (0054): cera pálida, rachadura esparsa, órbitas fracas (sem sangue) | venda de atadura **em 3D** (sprint 0041, modelo nosso de `scripts/gen_models.py`): faixa com volume em volta dos olhos, três voltas branco-sujas com frestas escuras, sangue seco em cada olho, dois arames farpados ferrugem-escuros enrolados por cima com farpas, nó atrás com as duas pontas caindo. Até a 0040 era a mesma ideia pintada nos óculos de esqui (`Glasses_SkiGoggles`) | cera trincada + atadura com arame nos olhos |
| Corredor | The Misaligned (0054): pele clara, placa/veias assimétricas, sombra facial deslocada | boca rasgada **em 3D** (sprint 0042, modelo nosso): buraco quase preto largo demais colado no rosto, lábio vermelho vivo rasgado e irregular, oito dentes em ponta, dois rasgos subindo até perto das orelhas. Até a 0041 era pintada na máscara cirúrgica (`Hat_SurgicalMask`) | assimetria + boca vermelha e preta |
| Sem-rosto | a do zumbi | Wrong Person (0054): vazios claros + manchas pretas orgânicas e chiado residual numa **casca lisa** sem feição (sprint 0042, modelo nosso; até a 0041 na balaclava, `Hat_BalaclavaFull`) | cabeça vazia que imita gente |
| Carpideira | Forgotten Patient (0054): pele clínica fria, órbitas suaves, escorridos finos (sem Jeff/sangue) | cabelo preto de piche **em mechas 3D** (sprint 0042) + **manto hospitalar desbotado** orgânico no corpo (0054; camada como `Gown_Hospital` / Eco cinza): capuz escuro + tecido sujo, **sem** blocos/faixas (a 0052 em grade lia como película wrap). Até a 0041 o cabelo era véu de noiva (`Hat_WeddingVeil`); até a 0052 o corpo ficava nu sob as mechas | silhueta errada: capuz escuro + corpo claro + mechas |
| Eco | coberta: quase branca, salpicos pequenos e esparsos de cinza e poucos escorridos finos na vertical | véu do mesmo jeito, mais escuro só nas bordas (véu de noiva) | o mais claro da névoa: fantasma coberto de cinza |
| Tição | carvão em placas pequenas, rachaduras finas de brasa viva e apagando (sprint 0038) | **crosta de carvão 3D** (sprint 0043, modelo nosso): a cabeça inteira em placas de alturas diferentes com rachaduras de brasa, dois olhos de brasa acesos na frente, lascas de carvão no alto e atrás, três fitas de fumaça clara subindo. Da 0038 à 0042 usava o véu de fumaça do Eco | preto com fio laranja e dois pontos acesos |

**Por quê, um por um:**

- **Estalador** — cego que vive de som: os olhos tapados dizem "não te vê"; a pele de
  porcelana rachada sugere que o corpo ressoa e trinca quando ele estala.
- **Corredor** — corre, grita e chama a horda: a boca rasgada larga demais é feita pro grito,
  e a pele esticada com veias diz esforço.
- **Sem-rosto** — some quando visto, e o rádio chia quando ele está perto: o rosto é o mesmo
  chiado do rádio, o aviso que o jogador já aprendeu a temer.
- **Carpideira** — chora e às vezes anda (Witch do Outro Mundo, 0052): mechas no rosto, manto
  hospitalar desbotado (0054) e órbitas frias leem "paciente esquecido / silhueta errada". Sem
  cruz, sem freira de franquia, sem película wrap. O visual é o mesmo quando ela grita.
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

### O corpo inteiro em brasa (sprint 0022)

Johan (05/10/2026), depois de ver a peça queimar no jogo: "o personagem inteiro em brasa".

- **Na mutação, o zumbi inteiro queima e o monstro aparece embaixo.** No mesmo instante em que o
  zumbi vira monstro, uma casca de carvão com rachaduras em brasa (a silhueta da roupa de proteção
  vanilla, pintada pelo mod) cobre o corpo todo e se desfaz em ~1 s, em manchas com a borda
  laranja, revelando a pele e a peça do monstro já prontas. Brasas sobem do pé dele.
- **Na volta, o espelho:** a casca se forma por cima do monstro, a troca pro zumbi comum acontece
  escondida embaixo dela, e ela se desfaz revelando o zumbi de antes, com a roupa dele.
- Com a casca, a peça do monstro não se forma sozinha (todo item com o efeito no zumbi queima
  junto, e a casca vai no sentido contrário): ela já está inteira embaixo.
- **Só o que está à vista queima inteiro:** atrás de parede ou fora da visão, nada de casca nem
  de brasa (as brasas são desenhadas por cima da tela e entregariam o zumbi).
- **Na horda (névoa vermelha), só os 6 primeiros queimam inteiros**; os seguintes queimam só a
  peça, como na 0018, e o resto troca na hora.
- A casca é mais larga que o corpo (é a roupa de proteção): no segundo da queima a silhueta
  incha um pouco. Sem máscara de corpo, a pele ou a roupa podem atravessar a malha em algum
  ponto (conferir no jogo).
- Opção "Brasa no corpo inteiro" (Opções > Mods, ligada, dentro de "Monstros queimam ao surgir e
  sumir"): desligada, só a peça queima, como na 0018. Técnica: [emenda da ADR-016](../architecture/adr-016-dissolve-e-bloom.md#emenda-de-2026-10-05--sprint-0022-o-corpo-inteiro-em-brasa).

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

- **Sangue nas paredes, escorrido.** No chão não tem sangue: as poças e rastros (sprints 0015 a
  0023) saíram na 0034, depois que o Johan os viu no jogo ("parecendo jogo dos anos 2000 com
  textura ruim").
- **Erosão no máximo:** sujeira e rachadura no chão e nas paredes; trepadeira subindo as paredes de
  fora e mato rasteiro no chão de fora; dentro, o chão queimado da casa destruída (o miolo do cômodo
  carbonizado, a borda só marcada). O que a natureza levaria anos pra fazer, a névoa faz em
  segundos. A sujeira vem em manchas, nunca um losango por tile (lia como xadrez, print de 05/10).
  Desde a sprint 0023 tudo vai colado no chão e na parede de verdade: embaixo dos pés, com a luz e o
  recorte do jogo.
- **Vermelha é pior:** mais chão marcado, mais parede suja.
- Sprites vanilla pelo nome (nada copiado), com a luz do lugar (desde a 0023 o breu esconde de
  verdade; a lanterna revela). Desde a 0035 também texturas próprias, geradas (seção seguinte).
  Técnica: [ADR-015](../architecture/adr-015-outro-mundo-sangrento.md),
  [ADR-017](../architecture/adr-017-outro-mundo-anexado.md).

## O Outro Mundo Silent Hill (sprint 0035)

Decisão do Johan (06/10/2026): o Outro Mundo fica **mais Silent Hill**, com ferrugem, tinta
descascando, grade metálica e lascas subindo. A inspiração é o ambiente (a pele do lugar
descascando e mostrando metal por baixo); a regra de cima continua valendo pros monstros, sem
enfermeira nem Pyramid Head.

- **Texturas próprias:** 50 PNG gerados por `scripts/gen_tiles.py` (semente fixa), nada copiado nem
  tirado do jogo. Chão: grade, ferrugem, chapa e tinta lascada. Parede (oeste e norte): tinta
  descascando, descasca (quase toda a tinta caída) e ferrugem escorrida. Cinco variações de cada,
  pra não repetir padrão à vista.
- **A tinta que fica é a parede do jogo.** O decalque só tem o buraco: uma demão velha de outra cor
  e, no fundo, reboco ou chapa enferrujada. Na borda, fio escuro, luz do lado da luz, lascas
  enroladas com o avesso claro e sombra no buraco; em volta, sujeira salpicada, craquelê e água
  escorrendo. Assim serve em parede de qualquer cor; uma tinta nossa por cima viraria adesivo onde a
  cor não bate.
- **Descasca:** o mesmo desenho com quase todo o buraco (68–80%), sobrando ilhas da parede do jogo.
  As bordas verticais do tile guardam tinta, pra emenda com o vizinho não ser um corte reto.
- **Grade:** o vão é escuro e meio transparente, então o chão do jogo aparece apagado por baixo; a
  grade faz sombra no vão e em volta. Quadrados, losangos ou barras, às vezes com o canto arrancado.
- **Ferrugem na parede:** escorridos que afinam e apagam, com uma cortina lavada abrindo em leque,
  saindo de parafusos, de uma emenda rebitada ou do alto, com bolhas de ferrugem em cacho. Mancha de
  óxido com contorno lia como adesivo e saiu.
- **Luz do alto à esquerda da tela** em tudo, como o jogo; sombra embaixo à direita.
- **Paleta dessaturada:** ferrugem marrom apagada, nada de laranja vivo (o laranja é da brasa).
  **Nada vermelho no chão:** a tinta de chão é amarelo industrial desbotado, porque vermelho no chão
  leria como o sangue que saiu na 0034.
- **Lascas e cinza:** sprite sheet de 8 quadros de lasca girando (borda serrilhada, tinta velha, fio
  claro falhado, verso ferrugem) e pontos de cinza, por `scripts/gen_textures.py`. A primeira versão
  parecia adesivo e foi refeita mais orgânica.
- **Pesos:** a branca favorece metal no chão e tinta descascando na parede; a vermelha mantém o
  sangue de parede e ganha ferrugem; a preta fica pra 0038 ([atmosphere.md](atmosphere.md#outro-mundo-estilo-silent-hill-sprint-0035)).
- **Metal só onde faz sentido** (hotfix depois do teste do Johan, 06/10): grama, terra e areia
  nunca ganham metal, ferrugem nem tinta (na grama a ferrugem em todo tile virou uma grade de
  bolotas marrons). Na calçada e na rua, só peça solta e rara, como bueiro; painel inteiro de
  metal lia como quadrado escuro em xadrez. Dentro de casa o metal fica, mas em mancha quebrada,
  sem bloco cheio.
- Técnica: [ADR-018](../architecture/adr-018-sprite-proprio-em-runtime.md) (sprite criado em
  runtime a partir do PNG). Nitidez no zoom longe e a grade em piso escuro ficam pro teste no jogo.
