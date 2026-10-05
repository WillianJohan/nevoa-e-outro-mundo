# Direção de arte dos monstros

| Campo | Valor |
|-------|-------|
| Status | `accepted` |
| Sprint | 0012 |
| Decisão | Johan, 05/10/2026: cada monstro com visual próprio, feito de **texturas procedurais originais em modelos 3D vanilla** (máscaras, capuzes, véus, camadas no corpo), citados pelo nome. Sem modelo 3D novo (pode vir depois). "Não quero ser igual TLOU... quero me inspirar, então pode ser criativo." |

## Regra

- **O visual conta o que o monstro faz**, ligado aos temas do mod: névoa, chiado de rádio, o
  Outro Mundo. Nada de cabeça de fungo de *clicker*/cordyceps, nada de enfermeira ou
  Pyramid Head de Silent Hill.
- **Legível no zoom normal, de frente:** um zumbi tem uns 60–100 px na tela. Conta a cor e
  a silhueta da peça na cabeça, não o detalhe. Cada monstro tem uma cor dominante própria.
- **Desenho que não depende do mapa UV:** rachadura, veia, chiado, fio, escorrido. Vale em
  qualquer ponto da textura, então a peça inteira vira o material e nada é copiado nem
  "decalcado" da textura vanilla (dela só se usa o tamanho).
- **Uma pele e uma peça por variante.** A roupa do zumbi fica: aquele zumbi qualquer *era* a
  coisa. Some quando a névoa baixa.
- Texturas: `scripts/gen_textures.py`. Técnica: [ADR-012](../architecture/adr-012-visual-das-variantes.md).

## Os monstros

| Monstro | Pele | Peça (modelo vanilla) | Cor que lê de longe |
|---|---|---|---|
| Estalador | porcelana branco-osso rachada, costuras quase pretas | venda de atadura manchada com arame enferrujado em X (óculos de esqui, `Glasses_SkiGoggles`) | branco rachado + faixa ferrugem nos olhos |
| Corredor | cinza de cinza, esticada na vertical, veias roxo-pretas | boca rasgada: carne vermelho-escura, rasgos e pontas de dente (máscara cirúrgica, `Hat_SurgicalMask`) | cinza + mancha vermelha na boca |
| Sem-rosto | a do zumbi | rosto de chiado de TV cinza, a cabeça inteira (balaclava inteira, `Hat_BalaclavaFull`) | cabeça cinza granulada |
| Carpideira | pálida azulada, escorridos de fuligem de cima pra baixo, manchas onde esfregou | cabelo preto embolado caindo no rosto (véu de noiva, `Hat_WeddingVeil`) | cabeça preta caída sobre corpo pálido |
| Eco | coberta: cinza clara e fumaça no corpo todo | véu de fumaça clara (véu de noiva) | quase branco, sem rosto |

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
  UV); o rosto fica coberto pela peça (Estalador, Corredor, Carpideira) ou é o próprio tema.
