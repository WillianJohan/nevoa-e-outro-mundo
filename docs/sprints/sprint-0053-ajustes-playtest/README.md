# Sprint 0053 — Ajustes do playtest Johan (0048–0052)

| Campo | Valor |
|-------|-------|
| Status | `em andamento` |
| Branch | `sprint/0053-ajustes-playtest` (saiu da `staging`) |
| Plano | [plan.md](plan.md) |
| Origem | playtest 2026-10-09; store `docs/playtest-ajustes-0048-0052.md` |

## Objetivo

Corrigir o que o Johan apontou depois do overnight 0048–0052: onda do Estalador
imersiva, sons das almas e da Screamer sutis, gritos ambiente ~1/min, rename
Carpideira→Screamer na UI, looks creepypasta (sem “película”), e raios vermelhos
só na névoa preta.

## Critérios de aceite

- [ ] Onda Estalador: sem anéis brancos de ScreenFx (só ripple de mundo / alpha
      baixo) — print de antes em store `media/playtest-estalador-onda.png`
- [ ] Sons das almas: gemidos de sofrimento, bem baixos (script + amplitude)
- [ ] Ambient scream: média ~1/min na branca (vermelha um pouco mais apertada)
- [ ] Screamer: áudio ElevenLabs (mysterious female etc.), volume sutil
- [ ] Rename display Carpideira → Screamer / Gritadora (IDs Lua `carpideira` ok)
- [ ] Texturas monstro: pele suja / sangue / hoodie manchado; sem listras wrap
- [ ] Névoa preta: clarão do relâmpago vermelho (mod3 tint + overlay fallback)
- [ ] `./run-tests.sh` verde; `scripts/dev-sync.sh` da branch

## Rename (documentado)

| Camada | Nome |
|--------|------|
| UI / sandbox / debug (PT) | **Gritadora** |
| UI / sandbox / debug (EN) | **Screamer** |
| IDs internos Lua / sons / ModData | `carpideira`, `NOM_Carpideira*`, sandbox `Carpideira*` |

Trocar IDs quebraria saves e rede; display completo nas traduções.

## Roteiro de teste no jogo

1. `scripts/dev-sync.sh` nesta branch; reiniciar; só Staging.
2. Estalador / `NOM.sonar()`: ripples na névoa sem anéis brancos no chão.
3. Almas / `NOM.alma()`: gemidos baixos, não ossos.
4. Névoa branca 2–3 min: ~1 grito ambiente por minuto (`NOM.ambientScream()` força).
5. Screamer: soluço/grito ElevenLabs baixo; painel diz Gritadora/Screamer.
6. Looks: pele/manto sem listras de película; contraste alto.
7. Preta / `NOM.thunder()`: clarão vermelho; Tições ainda congelam 1 s.
