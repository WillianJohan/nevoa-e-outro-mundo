# Sprint 0049 — Transform 100% + identidade por cor

| Campo | Valor |
|-------|-------|
| Status | `em teste` (PR draft #8) |
| Branch | `sprint/0049-transform-fog` (saiu da `staging`) |
| Origem | Johan 2026-10-08: transform universal em toda fog ([refinamento §3.9](../../../proximos-passos-refinamento.md)); fila overnight 1b |
| Plano | [plan.md](plan.md) |
| GDD | [monsters.md](../../gdd/monsters.md), [sandbox.md](../../gdd/sandbox.md) |
| ADR | [ADR-006](../../architecture/adr-006-variantes-deterministicas.md) (emenda), [ADR-010](../../architecture/adr-010-nevoa-vermelha.md) |
| API | [pz-api-notes](../../architecture/pz-api-notes.md) §2.1 (`doZombieSpeed`), §27 (`pathToLocationF`), ADR-002/005 |

## Objetivo

Na névoa **branca, vermelha e preta**, todo zumbi com outfit vira monstro. A cor muda o
**clima** (cotidiano / agitação / luz), não se “ainda tem Knox”.

## O que entrega

1. **Branca 100%:** pesos do sandbox (`EstaladorChance` etc.) **renormalizados** pra cobrir
   todos os zumbis (padrão 5:3:3:3 → ~35,7% / 21,4% / 21,4% / 21,4%). Tipo desligado deixa a
   faixa vazia (vira comum), sem redistribuir — igual espírito da vermelha.
2. **Vermelha:** continua 100% split igual 1/4 (já era).
3. **Preta:** continua 100% Tição (já era).
4. **Identidade por cor** (regras puras + fio fino, sem almas nem Witch):
   - **Branca (cotidiano):** perambular ligado; Estalador parado/cego pode entrar na onda
     (senão, com 100% variantes, a onda morria); cooldown do grito do Corredor = 0,5 h.
   - **Vermelha (agitação):** sem perambular; cooldown do grito mais curto; Estalador anda
     **rápido** (`doZombieSpeed(2)`, pz-api-notes §2.1) mantendo visão ruim / audição apurada.
   - **Preta:** só Tição (inalterado).

## Fora de escopo

Sons II (PR #4), almas esqueléticas, Carpideira Witch/look, aperto da preta, fog visual.

## Critérios de aceite

- [ ] Branca: 100% variantes com pesos renormalizados — testes `variant_rules_white_*`
- [ ] Vermelha e preta intactas (100% split / Tição) — testes já existentes verdes
- [ ] Tipo desligado na branca → fatia comum; faixas dos outros não andam
- [ ] Perambular só na branca; Estalador pode perambular na branca
- [ ] Grito do Corredor mais frequente na vermelha (cooldown puro)
- [ ] Estalador rápido na vermelha (`night_rules` / `night_stats`)
- [ ] Traduções PTBR+EN dos tooltips de chance (pesos relativos)
- [ ] `./run-tests.sh` verde
- [ ] Roteiro in-game abaixo (Johan)

## Roteiro de teste no jogo

Save descartável, `-debug`, `scripts/dev-sync.sh`, reiniciar o jogo. Mod **`[STAGING]`**.

1. **Branca 100%:** `NOM.setFog(true)` (ou "Branca já"). `NOM.status()` / painel: quase todo
   zumbi com visual de monstro (pele+peça); quase nenhum Knox vestido.
2. **Mix:** com defaults, ver Estalador, Corredor, Sem-rosto e Carpideira na mesma névoa
   (pesos ~5:3:3:3).
3. **Perambular:** "Onda de perambular" — grupos andam; na vermelha (`NOM.setRedFog`) a onda
   não sai / mensagem de cor.
4. **Vermelha:** todo monstro; Corredor grita de novo mais cedo; Estalador mais ágil ao
   ouvir; sem onda de perambular.
5. **Preta:** `NOM.setBlackFog(true)` — só Tição; sem as quatro.
6. **Toggle:** desligar Estalador no sandbox → fatia vira comum na branca; os outros tipos
   não “comem” a faixa.

## Decisões (Johan dormindo — fáceis de voltar)

| Decisão | Valor | Onde |
|---------|--------|------|
| Split branca | pesos sandbox renormalizados (PO) | `NOM_VariantRules.variant` |
| Desligado | faixa vazia → comum (não redistribui) | idem |
| Wander na branca | Estalador elegível; Corredor/Carpideira/Sem-rosto fora | `NOM_ColorIdentityRules` + `NOM_Wander` |
| Wander na vermelha/preta | off | `NOM_WanderServer` / `NOM_Wander.wave` |
| Cooldown grito vermelha | 0,15 h de jogo (~9 min) | `NOM_ColorIdentityRules.SCREAM_RED` |
| Estalador na vermelha | speedType 2 (rápido) | `NOM_NightRules` |

## Aprendizados

- Com 100% variantes, helpers `idFor(nil)` precisam de ID 0 (não há mais “comum” sob defaults).
- `while variant ~= nil` em testes de look vira loop infinito — trocar por mudança de tipo.
- Code review: alinhar GDD/ADR no mesmo commit que a lógica (presets ainda citavam 14%).

## Pendências que a próxima sprint herda

- Almas esqueléticas na branca (§3.9.1)
- Agitação mais rica na vermelha (Sons II já na #4; IA de “sair correndo” em grupo)
- Aperto da preta (1d)
