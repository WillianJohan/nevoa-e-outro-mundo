# Sprint 0053: ajustes playtest (plano)

> TDD onde há regra pura. Code review só no fim da entrega.

## Ordem

| # | Tarefa | Depende |
|---|--------|---------|
| 1 | Docs + índice | — |
| 2 | Onda Estalador: `SCREEN_DRAW=false`, alpha baixo | — |
| 3 | Ambient ~1/min (`NOM_AmbientScreamRules.GAP`) | — |
| 4 | Sons almas: gemidos sutis + volume baixo | — |
| 5 | Screamer áudio ElevenLabs + volume | — |
| 6 | Rename display Carpideira→Screamer/Gritadora | — |
| 7 | Texturas creepypasta (`gen_textures.py`) | — |
| 8 | Raios vermelhos na preta (`NOM_StormFx` + mod3) | — |
| 9 | Testes, PR draft, `dev-sync` | todas |

## Notas

- Refs (fora do repo do jogo): Agent Store `media/creepypasta-refs/`,
  `media/elevenlabs-refs/`, `media/playtest-estalador-onda.png`.
- Almas: trocar ossos skeleton por gemidos (exhausted / distant / faint) com
  amplitude baixa; `volume` no `NOM_sounds.txt`.
- Carpideira: reimport mysterious female; `volume` baixo como ambiente.
