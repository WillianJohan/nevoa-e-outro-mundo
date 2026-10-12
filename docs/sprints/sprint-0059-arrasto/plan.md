# Plano — sprint 0059 Arrasto / Rastejante

## Objetivo

Spike do caminho **A** do [refinamento §3.5](../../proximos-passos-refinamento.md): uma criatura
"baixa" no mesmo `IsoZombie` — sempre crawler, lenta, só névoa vermelha/preta — pra o Johan
julgar se “não parece um zumbi andando na minha direção”.

## Escopo desta entrega

1. **Regras puras** — `NOM_ArrastoRules` (cor, speedDeg 3, ATTACK_RANGE, sons stub, mark/is).
2. **Apply** — `NOM_Arrasto.apply` (`setCrawler` + `doZombieSpeed(3)` + ModData) no processo que simula.
3. **Debug** — `NOM.arrasto()` → servidor `ops.arrasto` → `NOM_ArrastoServer.force`; botão no painel.
4. **Docs + testes** — README, índice, luajit.

## Fora desta entrega

- Spawn automático / levas / IA de arrasto no chão (só o protótipo forçado no mais perto).
- Sons gerados (`NOM_ArrastoDrag` / `NOM_ArrastoLunge` = stubs de nome).
- Caminho B (animal) ou C (malha própria).
- Peça visual “agachado permanente” além do crawler vanilla.

## Ordem TDD

1. `test_arrasto_rules` (vermelho).
2. `NOM_ArrastoRules` + verde.
3. `test_arrasto` (apply + force).
4. Wire Console / DebugRules / DebugServer / painel / traduções.
5. `./run-tests.sh`.
