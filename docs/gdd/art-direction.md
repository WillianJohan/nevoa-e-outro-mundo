# Direção de arte dos monstros

| Campo | Valor |
|-------|-------|
| Status | `accepted` |
| Sprint | 0012 (monstros), 0013 (tela na névoa), 0014 (contraste dos monstros) |
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
- **Desenho que não depende do mapa UV:** rachadura, veia, chiado, fio, escorrido. Vale em
  qualquer ponto da textura, então a peça inteira vira o material e nada é copiado nem
  "decalcado" da textura vanilla (dela só se usa o tamanho). Única exceção: a fuligem nos
  olhos da Carpideira, posta onde fica o rosto na pele de zumbi vanilla (o layout, visto a
  olho, é o mesmo no masculino e no feminino). A balaclava vanilla é um tricô uniforme, sem
  região de rosto visível: o chiado do Sem-rosto vale na cabeça inteira.
- **Uma pele e uma peça por variante.** A roupa do zumbi fica: aquele zumbi qualquer *era* a
  coisa. Some quando a névoa baixa.
- Texturas: `scripts/gen_textures.py`. Técnica: [ADR-012](../architecture/adr-012-visual-das-variantes.md).

## Os monstros

| Monstro | Pele | Peça (modelo vanilla) | Cor que lê de longe |
|---|---|---|---|
| Estalador | porcelana quase branca em placas grandes, rachaduras grossas pretas | venda de atadura branco-suja com arame ferrugem viva em X, contornado de preto (óculos de esqui, `Glasses_SkiGoggles`) | branco trincado + X laranja nos olhos |
| Corredor | cinza de cinza clara, veias grossas roxo-pretas | boca rasgada: vermelho escuro saturado, um rasgo preto de lado a lado com dentes brancos grandes e escorridos pretos (máscara cirúrgica, `Hat_SurgicalMask`) | cinza com veias + boca vermelha e preta |
| Sem-rosto | a do zumbi | chiado de TV em blocos preto/branco, faixas de varredura e imagem rasgada na horizontal, quase sem cinza, a cabeça inteira (balaclava inteira, `Hat_BalaclavaFull`) | cabeça de TV fora do ar |
| Carpideira | muito pálida, escorridos grossos de fuligem de cima pra baixo, fuligem debaixo dos olhos | cabelo preto de piche com três mechas brancas, caindo no rosto (véu de noiva, `Hat_WeddingVeil`) | cabeça preta caída sobre corpo quase branco |
| Eco | coberta: quase branca com salpico escuro no corpo todo | véu quase branco com salpico escuro (véu de noiva) | gente de fumaça e cinza |

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

## Limites conhecidos

- **Chiado parado:** o item de roupa do B42 só aponta texturas fixas (`textureChoices`,
  `m_BaseTextures` no XML; nenhum campo de animação); trocar a peça a cada quadro refaria o
  modelo inteiro. O Sem-rosto usa um quadro de chiado.
- **Peça por cima de peça:** o zumbi que já usa algo no mesmo lugar (chapéu, máscara, óculos)
  fica com as duas, e elas podem atravessar uma na outra. Tirar a dele exigiria guardar e
  devolver a roupa; não vale o risco agora. Na morte, o corpo fica com a dele (a do mod sai).
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
