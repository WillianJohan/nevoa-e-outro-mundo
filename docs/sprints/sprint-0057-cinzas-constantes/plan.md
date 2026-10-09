# Plano — sprint 0057 cinzas constantes

## Objetivo

Partículas de cinza mais constantes em toda névoa ativa (branca, vermelha, preta), com knobs live no `NOM.panel()` / `NOM.ash`.

## Auditoria (antes)

| Peça | Estado |
|------|--------|
| Lascas/cinza do chão e parede | `NOM_FlakeRules` + `NOM_Flakes`; nas três cores via Outro Mundo |
| Cinza no ar | Só `NOM_FogState.red` (0040); `AIR_PER_RATE=0.3` esporádico |
| Painel | Só botões; sem seção Cinzas / sliders |

## Desenho

1. Subir `RATE` / `ASH_SHARE` / `AIR_PER_RATE` (e tetos leves) sem passar de dry-ice legível.
2. `R.air` com névoa aberta (`FogState.on`), não só vermelha.
3. Multiplicadores de sessão `dbg.{density,rate,air}` em `R.rate` / `R.air`.
4. `NOM.ash` + seção Cinzas com trilhos clicáveis/arrastáveis no `NOM_DebugPanel`.
5. TDD nos defaults, knobs, ar nas 3 cores, painel e HELP.

## Arquivos

- `shared/NOM_FlakeRules.lua`, `client/NOM_Flakes.lua`
- `client/NOM_Console.lua`, `client/NOM_DebugPanel.lua`
- `Translate/{PTBR,EN}/UI.json`
- `tests/test_flake_rules.lua`, `test_flakes.lua`, `test_debug.lua`, `test_debug_panel.lua`
- docs desta pasta
