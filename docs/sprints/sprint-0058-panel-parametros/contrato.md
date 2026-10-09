# Contrato NOM_PanelParams (0058)

Cópia no repo do contrato para os agents 0054–0057. A versão canônica no store do
projeto fica em `internal/panel-parametros-contrato.md`.

## API

`get` / `set` / `reset` / `isLive` / `snapshot` / `format` em
`mod/42/media/lua/shared/NOM_PanelParams.lua`.

Helpers: `almaCrawlerChance()`, `estaladorBeats(rhythm?)`, `cinzaRate(base)`,
`cinzaDensity(base)`, `lookForce()`.

## Chaves

| Seção | Chaves |
|-------|--------|
| Almas | `AlmaPopMin`(4), `AlmaPopMax`(20), `AlmaCrawlerPct`(68), `AlmaFogWhite/Red/Black`(true) |
| Estalador | `EstaladorRhythm`(`rotate`\|A\|B\|C), `EstaladorGapMinMs`(5000), `EstaladorGapMaxMs`(30000) |
| Cinzas | `CinzaRateMult`(1.0), `CinzaDensityMult`(1.0) |
| Look | `LookForce`(`""`\|pale\|misaligned\|patient\|wrong\|silhouette) |

Ritmos B/C e defaults: ver o módulo `RHYTHMS` e o README desta sprint.

Live = sessão (memória). Sem SandboxVars nesta sprint.
