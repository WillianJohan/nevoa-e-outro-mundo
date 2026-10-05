# ADR-008 — A noite escurece pela cor e força da luz global

| Campo | Valor |
|-------|-------|
| Status | `accepted` |
| Data | 2026-10-05 |
| Emenda | [ADR-004](adr-004-clima-antes-de-shader.md) (quais canais do clima) |

## Contexto

No primeiro teste no jogo (05/10/2026) o console mostrou `[NOM] nightRamp=1.00` e a
noite "clara igual dia", sem diferença nenhuma da vanilla. O mod escrevia
dessaturação, intensidade da luz global e um tint azulado. O bytecode do B42.21
explica por quê ([pz-api-notes §10](pz-api-notes.md#10-render-da-noite-e-hora-da-morte-sprint-0008)):

- `FLOAT_GLOBAL_LIGHT_INTENSITY` não é lido pelo render; só o relâmpago usa.
- A dessaturação é multiplicada por `1 − darkness` (`darkness = 1 − dayLightStrength`):
  de madrugada vale zero.
- De madrugada o jogo já põe `ambient = 0`, `dayLightStrength = 0` e
  `nightStrength = 1`. O que clareia a noite é o piso do sandbox `NightDarkness`
  (0 / 0.07 / 0.15 / 0.25, mais o luar), somado **depois** do clima.
- A luz do céu por canal é `2 × mod × ambient`, com `mod = 1 − alfa × (1 − cor)` da
  luz global. A vanilla de madrugada **não** é a do construtor (0.33, alfa 0.4): o
  `server/Climate/ClimateMain.lua:14-22` troca as cores no `OnClimateManagerInit`
  (disparado no `ClimateManager.<init>`, 590, a cada carga) e o `updateValues`
  (1794–1841) mistura pela lua: sem lua cinza 0.25, lua cheia 0.33, **alfa 0.8** nas
  duas (`mod` 0.40 e 0.46). O tint antigo puxava a cor pra um azul claro e o alfa pra
  0.85: contra a vanilla real tirava só 19–29% do vermelho e 0–8% do azul, quase nada.

## Decisão

O visual do clima escreve só nos canais que o render usa, no mesmo mecanismo da
ADR-004 (servidor, `OnClimateTick`, valor absoluto, `setModdedInterpolate(1)`):

| Canal | Noite | Névoa | Por quê |
|---|---|---|---|
| `COLOR_GLOBAL_LIGHT` (cor **e alfa**) | quase preto, puxado pro azul (0.00, 0.03, 0.06), alfa 0.95, peso 0.55 | sépia escura (0.45, 0.40, 0.32), alfa 0.75, peso 0.5 | único canal com folga de madrugada; o alfa é a força |
| `FLOAT_AMBIENT` | → 0, peso 0.5 | → 0, peso 0.3 | escurece o anoitecer e a névoa de dia |
| `FLOAT_DESATURATION` | — | → 1, peso 0.6 | só vale de dia |
| `FLOAT_FOG_INTENSITY` | — | → 1, peso 0.3 | a névoa vanilla lê o final |

Os pesos são multiplicados por `DarkIntensity` (teto 1). Como a vanilla já usa alfa
0.8, quem escurece é a cor. Queda da luz do céu contra a vanilla real:

| | sem lua (vanilla `mod` 0.40) | lua cheia (vanilla `mod` 0.46) |
|---|---|---|
| `DarkIntensity` 1 | R −46%, G −42%, B −39% | R −46%, G −43%, B −40% |
| `DarkIntensity` 2 | R −87%, G −80%, B −73% | R −89%, G −83%, B −77% |

Mais escura e um pouco mais fria (o azul cai menos). Testes:
`rules_night_darker_and_colder_than_vanilla` (≥ 35% em todo canal com 1, ≥ 60% com 2,
nas duas luas) e `rules_sky_mod_matches_render`.

Em `-debug`, o servidor loga canal a canal (vanilla, escrito, `getFinalValue()` e o
multiplicador da luz) na borda da rampa e uma vez por hora de jogo à noite.

## Alternativas recusadas

| Alternativa | Por que não |
|---|---|
| Subir `NIGHT_STRENGTH` / baixar `DAYLIGHT_STRENGTH` | Já estão no extremo de madrugada; `nightStrength` maior ainda aumenta o termo do luar no piso (`0.075 × lua × night`). |
| Trocar o `NightDarkness` do sandbox | É opção do jogador e vai pro save; o piso é somado no render, depois de qualquer camada do clima. |
| Shader próprio | Mesmos motivos da ADR-004 e do [spike](../sprints/spike-shader/README.md). |

## Consequências

- A noite do mod escurece por cima de qualquer `NightDarkness`, porque o `mod`
  multiplica o piso também; mas não o tira.
- Luzes de lanterna, poste e carro não mudam (o `mod` só entra na luz do céu e nas
  luzes "de prédio" sem fonte, `IsoLightSource.update` 145–209).
- Quadrado mais escuro encurta a visão do zumbi que persegue (`IsoZombie.updateVisionRadius`
  usa a luz do alvo) e esconde zumbi do jogador. Intencional.
- Em chuva, o `WeatherPeriod` mistura a cor das nuvens por cima da nossa
  (`setOverride` sem ser de valor): a noite chuvosa do mod fica um pouco menos azul.
- O efeito exato é do código nativo (`LightingJNI.stateEndFrame`): só o jogo confirma
  quanto escurece. Roteiro na [sprint 0008](../sprints/sprint-0008-ajustes-teste/README.md#roteiro-in-game).
