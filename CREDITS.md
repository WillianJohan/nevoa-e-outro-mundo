# Créditos

## Sons

Todos os sons do mod são **originais**, gerados por síntese procedural pelo
script [`scripts/gen_sounds.py`](scripts/gen_sounds.py) (numpy + ffmpeg, semente
fixa). Nenhuma amostra de terceiros, do jogo ou de outro mod foi usada.
Licença: [MIT](LICENSE), a mesma do mod.

| Arquivo | Som | Uso |
|---|---|---|
| `mod/42/media/sound/NOM_EstaladorClick.ogg` | três estalos secos (ruído filtrado em ressonância) | estalo de aviso do Estalador |
| `mod/42/media/sound/NOM_CorredorScream.ogg` | grito rasgado (onda serra com formantes e saturação) | grito do Corredor |
| `mod/42/media/sound/NOM_FogDrone.ogg` | drone grave em loop (senos graves + ronco filtrado) | ambiente da névoa |
| `mod/42/media/sound/NOM_FogMetal.ogg` | pancada metálica distante (parciais inarmônicos + ecos) | ruídos metálicos da névoa |
| `mod/42/media/sound/NOM_RadioStatic.ogg` | chiado de rádio em loop (ruído filtrado, estalos, zumbido de 60 Hz) | rádio "na cabeça" perto do Sem-rosto |

Pra regerar: `python3 scripts/gen_sounds.py`. Os sons são declarados em
`mod/42/media/scripts/NOM_sounds.txt`.

## Visual

Outfits do mod (`mod/42/media/clothing/clothing.xml`) só referenciam itens
vanilla por GUID; nenhum arquivo do jogo é copiado.
