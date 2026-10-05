# Créditos

**Nada de terceiros.** Todo arquivo de som e imagem do mod é original, gerado por
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

Pra regerar: `python3 scripts/gen_images.py`.

## Conteúdo vanilla referenciado (nada copiado)

| Onde | O que | Referência |
|---|---|---|
| `mod/42/media/clothing/clothing.xml` (outfit `NOM_Eco`) | camisola de hospital | GUID `ae2071bc-0d47-4041-b0a5-28c8cfa46c05` (`Gown_Hospital`) |
| `mod/42/media/clothing/clothing.xml` (outfit `NOM_Eco`) | véu de noiva | GUID `edf2b504-261e-4baf-9440-48884d80a8bb` (`Hat_WeddingVeil`) |
| `NOM_FogOverlays.lua` | manchas de sangue no chão | sprites `overlay_blood_floor_01_0` a `_27`, por nome |
| `NOM_FogOverlays.lua` | sujeira tingida de ferrugem | sprites `overlay_grime_floor_01_0` a `_95`, por nome |
| `NOM_FogVignette.lua` | vinheta da névoa | efeito de tela do modo de busca do jogo (`getSearchMode()`), sem textura própria |
| Variantes, Eco, Sem-rosto | corpo e animação | zumbis vanilla; o mod só muda comportamento |
