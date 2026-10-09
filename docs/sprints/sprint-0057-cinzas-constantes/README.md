# Sprint 0057: cinzas mais constantes

| Campo | Valor |
|-------|-------|
| Status | `em teste` |
| Branch | `sprint/0057-cinzas-constantes` (de `staging`) |
| Origem | Pedido do Johan 2026-10-09 + knobs no `NOM.panel()` |
| Plano | [plan.md](plan.md) |

## O que entrou

- **Cinzas mais constantes** enquanto a névoa está aberta (Silent Hill / dry-ice, sem ensurdecer):
  - `RATE` 14 → 24, `ASH_SHARE` 0,7 → 0,78, `BIRTHS_PER_S` 48 → 56, `MAX` 160 → 180;
  - cinza no ar: `AIR_PER_RATE` 0,3 → 0,5, `AIR_MAX` 40 → 48;
  - **cinza no ar nas três cores** (antes só na vermelha, 0040).
- **Knobs live** (`shared/NOM_FlakeRules` + `NOM.ash` + seção **Cinzas** no painel):
  - densidade, frequência (taxa) e cinza no ar, multiplicadores 0…2 no painel (0…3 no console);
  - sliders compactos no cartão + Mostrar / Reset;
  - só sessão de debug (não grava sandbox).

## Como voltar

- Defaults: `NOM_FlakeRules.RATE`, `ASH_SHARE`, `AIR_*`, `MAX`, `BIRTHS_PER_S`.
- Ar só na vermelha: em `NOM_Flakes.lua`, trocar `NOM_FogState.on` por `NOM_FogState.red` no bloco do `R.air`.
- Knobs: `NOM.ash("reset")` ou `NOM_FlakeRules.resetDebug()`.

## Testes

- `test_flake_rules`: defaults mais densos; knobs dens×taxa e ar×2.
- `test_flakes`: `flakes_air_all_fog_colors` (branca/vermelha/preta; some com intensidade 0).
- `test_debug`: `NOM.ash` set/reset + HELP.
- `test_debug_panel`: botões da seção Cinzas, sliders clicáveis, regra do HELP.

## Roteiro no jogo

1. Staging, `-debug`, Insert → seção **Cinzas**.
2. `NOM.setFog(true)` / vermelha / preta: cinza no ar e lascas mais frequentes nas três.
3. Sliders: subir frequência e densidade; baixar ar pra 0 (só chão/parede); Reset volta a 1.
4. Console: `NOM.ash()`, `NOM.ash(1.5, 2, 1)`, `NOM.ash("reset")`.
5. Conferir FPS e legibilidade (não deve virar neve sólida).
