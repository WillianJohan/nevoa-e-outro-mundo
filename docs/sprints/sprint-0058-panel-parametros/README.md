# Sprint 0058 — painel: parâmetros unificados

| Campo | Valor |
|-------|-------|
| Status | `em andamento` (PR draft → staging) |
| Branch | `feature/0058-panel-parametros-cd25` (sprint 0058) |
| Base | `staging` |
| Plano | [plan.md](plan.md) |
| Contrato (store) | `internal/panel-parametros-contrato.md` |

## Objetivo

O `NOM.panel()` ganha seções compactas com sliders e toggles para os knobs dos
ajustes em curso (Almas, Estalador, Cinzas, Look), sobre um contrato shared
(`NOM_PanelParams`) que os sprints 0054–0057 implementam nos sistemas.

## O que entrou

- **`shared/NOM_PanelParams.lua`:** defaults, SCHEMA, get/set/reset, ritmos A/B/C,
  helpers (`almaCrawlerChance`, `estaladorBeats`, `cinzaRate`, `lookForce`).
- **Seções no painel:** Almas | Estalador | Cinzas | Look (compactas; sliders com
  −/+/trilha; toggles; enums).
- **Console:** `NOM.params()`, `NOM.param(key, value)` (+ reset) no HELP e em Diagnóstico.
- **Traduções** PTBR + EN.

Storm já tinha seção de ações; sem knobs novos aqui.

## Coordenação de sprints

| Sprint | Tema | Relação com 0058 |
|--------|------|------------------|
| 0054 | Look horror | lê `LookForce` / `lookForce()` |
| 0055 | Almas ciclo | lê `Alma*` |
| 0056 | Estalador ritmos | lê `Estalador*` + `RHYTHMS` |
| 0057 | Cinzas constantes | lê `Cinza*Mult` |
| **0058** | **Painel** | UI + contrato + stubs |

Não mergear esta PR nas outras; cada uma fecha no próprio draft → staging.

## Critérios de aceite

- [x] Seções Almas / Estalador / Cinzas / Look no painel
- [x] Sliders e toggles gravam via `NOM_PanelParams`
- [x] `NOM.params` / `NOM.param` no HELP e no painel
- [x] Contrato documentado para os outros agents
- [x] Testes Lua verdes (`test_panel_params`, `test_debug_panel`, traduções)
- [ ] Johan confere no jogo (staging sync)

## Roteiro de teste no jogo

1. `-debug`, mod Staging, Insert → painel.
2. Seção **Almas**: subir pop min/max, % crawler; toggles W/R/B.
3. **Estalador**: ritmo B, gaps; `NOM.sonar()`.
4. **Cinzas**: taxa 2× com névoa aberta (efeito pleno quando 0057 ligar o leitor).
5. **Look**: forçar Pale (efeito pleno quando 0054 ligar o leitor).
6. Diagnóstico → Parâmetros live / Resetar; `NOM.params()` no console.
