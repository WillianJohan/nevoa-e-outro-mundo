# Créditos

**Nada de terceiros.** Todo arquivo de som, imagem e textura do mod é original, gerado por
script deste repositório; o resto do que o mod mostra é conteúdo vanilla do Project
Zomboid **referenciado por nome ou GUID**, sem nenhum arquivo do jogo copiado. Nenhum
código, som ou imagem de outro mod foi usado. Licença de tudo que está aqui:
[MIT](LICENSE), a mesma do mod.

`tests/test_credits.lua` falha se aparecer no mod qualquer arquivo que não seja
código ou texto (`.lua .txt .xml .json .info`, `.gitkeep`), ou uma imagem em
`docs/workshop/`, que não esteja nesta página; e com GUID vanilla não listado.

## Sons

Gerados por síntese procedural pelo script [`scripts/gen_sounds.py`](scripts/gen_sounds.py)
(numpy + ffmpeg, semente fixa). Nenhuma amostra de terceiros, do jogo ou de outro mod.

| Arquivo | Som | Uso |
|---|---|---|
| `mod/42/media/sound/NOM_EstaladorClick.ogg` | três estalos secos (ruído filtrado em ressonância) | estalo de aviso do Estalador |
| `mod/42/media/sound/NOM_CorredorScream.ogg` | grito rasgado (onda serra com formantes e saturação) | grito do Corredor |
| `mod/42/media/sound/NOM_FogDrone.ogg` | drone grave em loop (senos graves + ronco filtrado) | ambiente da névoa |
| `mod/42/media/sound/NOM_FogMetal.ogg` | pancada metálica distante (parciais inarmônicos + ecos) | ruídos metálicos da névoa |
| `mod/42/media/sound/NOM_RadioStatic.ogg` | chiado de rádio em loop (ruído filtrado, estalos, zumbido de 60 Hz) | rádio "na cabeça" perto do Sem-rosto |
| `mod/42/media/sound/NOM_Siren.ogg` | sirene de ataque aéreo, sobe e cai duas vezes (~24 s; rotor de harmônicos ímpares, segundo rotor desafinado, ecos) | aviso do evento de névoa, 30 s reais antes |
| `mod/42/media/sound/NOM_SirenRed.ogg` | a sirene mais grave (~30%), rasgada e longa (~28 s): rotor com desafinação que oscila, ronco uma oitava abaixo, saturação, chiado filtrado, ecos longos | aviso da névoa vermelha, 30 s reais antes |
| `mod/42/media/sound/NOM_CarpideiraSob.ogg` | choro baixo em loop (~7 s): soluços de voz aguda que treme e cai, com ar e inspirações chiadas (harmônicos filtrados em formantes + ruído) | Carpideira calma, perto dela |
| `mod/42/media/sound/NOM_CarpideiraScream.ogg` | grito agudo que sobe até um guincho e rasga (~3,5 s): duas vozes desafinadas, formantes, saturação forte, ecos curtos | grito da Carpideira acordada |

Pra regerar: `python3 scripts/gen_sounds.py`. Os sons são declarados em
`mod/42/media/scripts/NOM_sounds.txt`.

## Imagens

Geradas pelo script [`scripts/gen_images.py`](scripts/gen_images.py) (numpy + Pillow,
semente fixa): névoa em camadas de ruído suavizado, um poste e uma figura sem rosto,
desenhados por código. Nenhuma captura de tela do jogo. O texto usa a fonte embutida do
Pillow (Aileron Regular, de dotcolon.net, domínio público CC0); o acento do "É" é
desenhado à mão porque a fonte embutida não tem o caractere.

| Arquivo | Tamanho | Uso |
|---|---|---|
| `mod/42/poster.png` | 512×512 | painel de informações do mod no jogo (`mod.info`, `poster=`) |
| `mod/42/icon.png` | 64×64 | ícone na lista de mods (`mod.info`, `icon=`): o "N" na névoa |
| `docs/workshop/preview.png` | 256×256 | imagem do item no Steam Workshop (copiada pelo `scripts/build-workshop.sh`) |
| `mod2/42/poster.png` | 512×512 | painel do mod opcional do shader: o pôster com as cores separadas e "SHADER" |
| `mod2/42/icon.png` | 64×64 | ícone do mod opcional do shader: o "N" com as cores separadas |

Pra regerar: `python3 scripts/gen_images.py`.

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
| `mod/42/media/textures/NOM/NOM_EstaladorVenda.png` | 128×128 | venda do Estalador: atadura em faixas, arame farpado ferrugem, sangue seco |
| `mod/42/media/textures/NOM/NOM_CorredorBoca.png` | 128×128 | boca rasgada do Corredor: vermelho escuro, rasgo preto, dentes brancos |
| `mod/42/media/textures/NOM/NOM_SemRostoEstatica.png` | 128×128 | rosto do Sem-rosto: chiado de TV em blocos preto/branco, faixas rasgadas |
| `mod/42/media/textures/NOM/NOM_CarpideiraCabelo.png` | 128×128 | cabelo preto da Carpideira com mechas brancas, caindo no rosto |
| `mod/42/media/textures/NOM/NOM_EcoCinza.png` | 256×256 | quase branco com salpicos pequenos e escorridos finos de cinza, no corpo todo do Eco |
| `mod/42/media/textures/NOM/NOM_EcoVeu.png` | 128×128 | véu quase branco do Eco, salpicado, mais escuro nas bordas |
| `mod/42/media/textures/NOM/ScreenFx/NOM_Grain1.png` … `NOM_Grain4.png` (`mod/42/media/textures/NOM/ScreenFx/NOM_Grain2.png`, `mod/42/media/textures/NOM/ScreenFx/NOM_Grain3.png`, `mod/42/media/textures/NOM/ScreenFx/NOM_Grain4.png`) | 256×256 | grão de filme da névoa, quatro quadros de ruído (efeitos de tela, sprint 0013) |
| `mod/42/media/textures/NOM/ScreenFx/NOM_Vignette.png` | 512×512 | vinheta da tela: transparente no centro, opaca nas bordas |
| `mod/42/media/textures/NOM/ScreenFx/NOM_Lines.png` | 512×256 | linhas horizontais de chiado (perto do Sem-rosto) |
| `mod/42/media/textures/NOM/ScreenFx/NOM_White.png` | 8×8 | branco opaco, tingido de vermelho no pulso do grito da Carpideira |

Pra regerar: `python3 scripts/gen_textures.py`.

## Shader

| Arquivo | O que é |
|---|---|
| `mod2/42/media/shaders/screen.frag` | pós-processo de tela do mod opcional `NevoaEOutroMundo_Shader` (sprint 0013): **código original**, escrito pro mod (MIT). Do jogo só a interface: nomes e tipos dos uniforms que o `WeatherShader` manda, a entrada `vUV` do `screen.vert` vanilla e a saída `gl_FragColor`. Nenhuma linha do `screen.frag` da The Indie Stone (`tests/test_shader.lua` confere contra o arquivo instalado) |
| `mod/42/media/shaders/NOM_Dissolve.vert`, `mod/42/media/shaders/NOM_Dissolve_static.vert`, `mod/42/media/shaders/NOM_Dissolve.frag` | dissolve das peças do mod (sprint 0018, ADR-016), pelo `<m_Shader>` dos itens `*Fx` e da casca do Eco: **código original**, escrito pro mod (MIT). Do jogo só a interface: atributos pelo índice, paleta de ossos, nomes e tipos dos uniforms que o Java do `skinnedmodel.Shader` manda e a saída `gl_FragColor`. Nenhuma linha do `basicEffect*.vert/.frag` da The Indie Stone (`tests/test_dissolve_shader.lua` confere contra os arquivos instalados) |

## Conteúdo vanilla referenciado (nada copiado)

| Onde | O que | Referência |
|---|---|---|
| `mod/42/media/clothing/clothing.xml` (outfit `NOM_Eco`) | cinza no corpo todo (item do mod, sem modelo: camada no corpo como a do `Gown_Hospital`) | GUID `e8a21b0f-4b56-4b3d-8fab-2ea78dd84e8d` (`NOM_EcoCinza`, do mod) |
| `mod/42/media/clothing/clothing.xml` (outfit `NOM_Eco`) | véu de fumaça (item do mod) | GUID `82f80e18-a7cf-4312-949c-23879a1e3820` (`NOM_EcoVeu`, do mod) |
| `clothingItems/NOM_EstaladorVenda.xml` | modelo dos óculos de esqui (`Glasses_SkiGoggles`) | `static\clothes\m_glasses_skigoggles`, `static\clothes\f_glasses_skigoggles` |
| `clothingItems/NOM_CorredorBoca.xml` | modelo da máscara cirúrgica (`Hat_SurgicalMask`) | `static\clothes\m_surgicalmask`, `static\clothes\f_surgicalmask` |
| `clothingItems/NOM_SemRostoEstatica.xml` | modelo da balaclava inteira (`Hat_BalaclavaFull`) | `skinned\hair\m_balaclavafull`, `skinned\hair\f_balaclavafull` |
| `clothingItems/NOM_CarpideiraCabelo.xml`, `NOM_EcoVeu.xml` | modelo do véu de noiva (`Hat_WeddingVeil`) | `skinned\clothes\m_weddingveil`, `skinned\clothes\f_weddingveil` |
| `clothingItems/NOM_*Fx.xml` (sprint 0018) | gêmeos das peças com o shader do dissolve | os mesmos modelos vanilla das peças acima, pelo nome |
| `clothingItems/NOM_EcoCasca.xml` (sprint 0018) | modelo da roupa de proteção (`HazmatSuit`), casca de cinza do Eco na morte, e a lista de máscaras de corpo dele (números) | `media\models_X\Skinned\Clothes\Bob_Hazmat.X`, `media\models_X\Skinned\Clothes\Kate_Hazmat.X` |
| `clothingItems/NOM_*.xml` (menos `NOM_EcoCinza`) | máscaras de corpo dos chapéus | pasta `media/textures/Clothes/Hat/Masks`, pelo caminho |
| `scripts/NOM_clothing.txt` | ícones dos itens | `SkiGogglesWhite`, `SurgicalMaskBlue`, `Balaclava`, `VeilWedding`, `HospitalGown`, `Hazmatsuit`, pelo nome |
| `NOM_FogOverlays.lua` | manchas de sangue no chão | sprites `overlay_blood_floor_01_0` a `_27`, por nome |
| `NOM_FogOverlays.lua` | sujeira tingida de ferrugem | sprites `overlay_grime_floor_01_0` a `_95`, por nome |
| `NOM_FogVignette.lua` | vinheta da névoa | efeito de tela do modo de busca do jogo (`getSearchMode()`), sem textura própria |
| `NOM_ScreenFx.lua` | efeitos de tela | desenho pela UI do jogo (`ISUIElement`), com as texturas originais acima |
| Variantes, Eco, Sem-rosto, Carpideira | corpo e animação | zumbis vanilla; o mod muda comportamento, pele e peças por cima (texturas acima) |
