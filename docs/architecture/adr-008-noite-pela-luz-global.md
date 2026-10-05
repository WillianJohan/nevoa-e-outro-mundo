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
  luz global. A vanilla de madrugada é cinza 0.33 com alfa 0.4 (`mod` 0.73). O tint
  antigo puxava a cor pra um azul claro com o alfa vanilla: `mod` subia, e a noite do
  mod ficava levemente **mais clara**.

## Decisão

O visual do clima escreve só nos canais que o render usa, no mesmo mecanismo da
ADR-004 (servidor, `OnClimateTick`, valor absoluto, `setModdedInterpolate(1)`):

| Canal | Noite | Névoa | Por quê |
|---|---|---|---|
| `COLOR_GLOBAL_LIGHT` (cor **e alfa**) | azul escuro (0.10, 0.14, 0.30), alfa 0.85, peso 0.6 | sépia escura (0.45, 0.40, 0.32), alfa 0.75, peso 0.5 | único canal com folga de madrugada; o alfa é a força |
| `FLOAT_AMBIENT` | → 0, peso 0.5 | → 0, peso 0.3 | escurece o anoitecer e a névoa de dia |
| `FLOAT_DESATURATION` | — | → 1, peso 0.6 | só vale de dia |
| `FLOAT_FOG_INTENSITY` | — | → 1, peso 0.3 | a névoa vanilla lê o final |

Os pesos são multiplicados por `DarkIntensity` (teto 1). Com 1, a luz do céu da
noite cai ~37% no vermelho e ~26% no azul (mais escura e mais fria); com 2, ~68% e
~45%. Testes: `rules_night_darker_and_colder_than_vanilla`, `rules_sky_mod_matches_render`.

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
