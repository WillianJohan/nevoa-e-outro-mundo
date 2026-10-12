# Plano — sprint 0058 panel-parametros

## Contexto

Johan pediu knobs unificados no `NOM.panel` enquanto rodam em paralelo looks (0054),
almas (0055), estalador (0056) e cinzas (0057). Nenhuma dessas PRs tinha API de config
live ainda → a 0058 define o contrato e a UI.

## Desenho

1. **`NOM_PanelParams` (shared, puro)** — store de sessão com DEFAULTS = alvos de produto
   dos prompts paralelos; SCHEMA pra clamp/step/enum; sem SandboxVars nesta sprint.
2. **UI compacta** — quatro seções novas; slider = − / trilha / +; bool = LIGADO/DESLIGADO;
   enum = pills com a ativa acesa.
3. **Console** — `NOM.params` / `NOM.param` (regra AGENTS.md: botão no painel).
4. **Contrato** — store `internal/panel-parametros-contrato.md` pra 0054–0057 ligarem leitores.

## TDD

1. `tests/test_panel_params.lua` (defaults, clamp, ritmos, helpers).
2. Ajustes em `tests/test_debug_panel.lua` (HELP, Params, mínimo da janela).
3. Implementação mínima + traduções.

## Fora de escopo

- Merge nas outras branches / staging.
- Persistência sandbox.
- Ligar leitores em AlmaRules / FlakeRules / Sonar / Look (fica com cada sprint).
