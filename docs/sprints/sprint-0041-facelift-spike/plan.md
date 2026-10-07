# Sprint 0041 — Facelift, spike: a venda do Estalador em 3D

## Objetivo

Provar o caminho inteiro de uma peça 3D nossa até o jogo, com a peça mais simples do
facelift: a venda de atadura com arame farpado do Estalador. Hoje ela é textura
pintada em cima dos óculos de esqui vanilla (sprint 0012). Na 0041 vira malha
própria: faixa com volume em volta da cabeça, dois arames farpados de verdade enrolados
por cima e as pontas do nó caindo atrás.

O que a 0041 prova pras próximas (0042: os outros monstros):

1. gerar `.x` (DirectX texto) em Python puro, sem Blender e sem arquivo do jogo;
2. o jogo achar o modelo do mod pelo nome curto (`static\clothes\NOM_…`);
3. medir a cabeça vanilla (só números) pra encaixar a peça sem atravessar a pele.

## Evidência (pz-api-notes §32)

- `FileTask_LoadMesh` (bytecode) passa `media/models_x` pro
  `FileTask_AbstractLoadModel.checkExtensionType`, que monta `media/models_x/<nome>` +
  `.fbx`/`.glb`/`.x` e resolve por `ZomboidFileSystem.getString`. Esse método procura
  no `activeFileMap` (caminho em minúsculas), o mesmo mapa que deixa o mod sobrepor
  textura e som. Por isso `mod/42/media/models_X/Static/Clothes/NOM_M_EstaladorVenda.x`
  atende `static\clothes\NOM_M_EstaladorVenda`.
- `.x` vai pro Assimp (`Jassimp.importFile`) sem rotação nem escala. O `.fbx` gira −90°
  e escala 0,01; o `.x` não.
- Peça estática presa ao osso: `m_Static`, `m_AttachBone Bip01_Head` (como a venda de hoje).
- Medido nos `.x` vanilla (só números, nada copiado):
  - quadro do osso da cabeça em metros; X sobe pela cabeça, Y vai de orelha a orelha,
    Z aponta pra frente (a lente dos óculos de esqui fica em z +0,077 com y = 0);
  - winding: nas 280 faces de `M_HeadBandage` e `M_Glasses_SkiGoggles`,
    `cross(b−a, c−a)` aponta pro mesmo lado da normal gravada;
  - os óculos de esqui (masculino):
    - x vai de 0,055 a 0,108; y fica em ±0,060; z vai de −0,073 a 0,077;
    - atrás a tira sobe até x ≈ 0,10;
  - os óculos de esqui (feminino):
    - x vai de 0,048 a 0,098; y fica em ±0,057; z vai de −0,062 a 0,081.

## Decisões (tomadas pelo Johan ausente; conservadoras e fáceis de voltar)

- **Mesmo item, outro modelo.** `NOM_EstaladorVenda` e o gêmeo `Fx` continuam com o
  mesmo GUID e a mesma textura nas duas pontas. Só `m_MaleModel`/`m_FemaleModel`
  apontam pros nossos `.x` e `textureChoices` pra textura nova. Não muda Lua nem
  `fileGuidTable`. Voltar pra 0012 é trocar três linhas por XML.
- A textura antiga `NOM_EstaladorVenda.png` fica gerada no repo, pronta pra volta.
- **Dois modelos**, `NOM_M_` e `NOM_F_`, cada um encaixado nos óculos de esqui do
  mesmo sexo (cabeças diferentes, como o vanilla faz).
- **Gerador em Python puro** (`scripts/gen_models.py`): escreve o `.x` e a textura,
  porque o UV e o desenho andam juntos. Usar o Blender não vale o custo pra peça
  estática.
- **Textura que sobrevive às duas convenções de V.** O pano fica espelhado em volta do
  meio e a faixa de ferrugem do arame no centro (v 0,4–0,6). Assim tanto faz se o
  jogo lê v de cima ou de baixo.
- **Malha fechada** (cada aresta em duas faces): o culling de face de trás nunca mostra
  buraco.
- **Sem templates no `.x`.** O Assimp não precisa deles, e o arquivo fica só com o
  que é nosso.

## TDD (tests/test_models.py, no run-tests.sh)

1. O gerador é determinístico: rodar de novo não muda um byte.
2. O `.x` tem cabeçalho `xof 0303txt 0032` e contagens batendo (vértices, faces,
   normais, UV) com índices válidos.
3. Winding igual ao vanilla: `cross(b−a, c−a)·normal > 0` em toda face.
4. A malha é fechada: soldando por posição, cada aresta tem duas faces.
5. Encaixe:
   - nada entra na elipse da cabeça medida;
   - tudo fica dentro de uma caixa perto dos óculos;
   - a frente da faixa fica em +Z.
6. UV do arame cai na faixa de ferrugem, e o da atadura no pano, nas duas convenções de V.
7. Textura: 128 px, entra nos limites de contraste (`test_look_contrast.py`).
8. `test_look_assets.lua`: modelo próprio do XML existe em `media/models_X`.

## Fora do escopo

- Os outros monstros (0042).
- Teste de IA 3D no Tição (0043).
- Rosto censurado do Sem-rosto (0044).
