# Sprint 0001 — Estado do mundo e clima dark

| Campo | Valor |
|-------|-------|
| Status | em teste |
| Branch | `sprint/0001-estado-e-clima` |
| Plano | [plan.md](plan.md) |
| GDD | [world-states.md](../../gdd/world-states.md), [atmosphere.md](../../gdd/atmosphere.md#clima), [sandbox.md](../../gdd/sandbox.md) |

## Objetivo

Ao anoitecer ou quando a névoa sobe, o jogo escurece e muda de cor sozinho —
em solo e em MP.

## Critérios de aceite

- [ ] Ambiente de dev pronto: jogo instalado, `-debug` funcionando, pasta `mod/` linkada em `~/Zomboid/mods` (como foi feito, registrado em Aprendizados)
- [ ] Mod aparece e ativa no menu de mods do B42 sem erro no `console.txt`
- [ ] Flags `night` e `fog` mudam na hora certa (forçando hora e névoa no `-debug`)
- [ ] Noite: luz menor, leve dessaturação, tint azulado
- [ ] Névoa: dessaturação forte, tint sépia/cinza, névoa mais densa
- [ ] Transição suave (~30s), sem corte seco
- [ ] Toggle e `DarkIntensity` no sandbox alteram o efeito
- [ ] Em MP (servidor local + 2 clientes), os dois clientes escurecem juntos
- [ ] Todo texto visível sai de chave de tradução (`Translate/PTBR`), nunca string solta no Lua
- [ ] `./run-tests.sh` cobre a máquina de estado de `NOM_Rules.lua` e devolve exit code

## Checkpoints

- **04/10** — Design aprovado em brainstorming; GDD, ADRs e roadmap escritos.
- **04/10** — Tasks 1-5 implementadas na branch: runner `luajit` (exit 0/1 provado nas duas direções), `NOM_Rules` (18 testes), `NOM_Config` + sandbox + traduções PT-BR/EN (22 testes), `NOM_World`, `NOM_Atmosphere`. Falta o roteiro in-game e o MP.

## Aprendizados

1. **Nascer e pôr do sol ficam na estação, não no `ClimateManager`.** É `getClimateManager():getSeason():getDawn()` / `getDusk()` — é o que o próprio jogo usa em `Foraging/forageSystem.lua`. O plano tinha `clim:getDawn()`.
2. **Layout de mod do B42.20:** `mod.info` e `media/` dentro de `42/`, pasta `common/` existindo do lado, e tradução em **JSON** (`Translate/<LANG>/Sandbox.json`), não mais `.txt`. Tooltip de sandbox é a chave com sufixo `_tooltip`.
3. **`ClimateManager.FLOAT_GLOBAL_LIGHT_INTENSITY` e `ClimateColorInfo.new` nunca aparecem no Lua vanilla**, então não há garantia de que o Kahlua os exponha. O código usa id numérico de fallback e `pcall` com caminho alternativo; o teste in-game diz qual dos dois rodou (procurar `[NOM] ClimateColorInfo.new indisponível` no console).

## Pendências que a próxima sprint herda

## Sessões

- 2026-10-04 — abd764e2-7a9a-416b-b9b3-1630ab9e761f — brainstorming, GDD, ADRs, repo
