# Sprint 0048 — Sons II: gritos + Estalador clicker

| Campo | Valor |
|-------|-------|
| Status | em andamento |
| Branch | `sprint/0048-sons-ii` |
| Plano | [plan.md](plan.md) |
| Produto | [proximos-passos-refinamento.md](../../proximos-passos-refinamento.md) §3.1 / §3.1.1 / §3.1.2 |
| Âncoras | sprint [0034](../sprint-0034-sons/README.md) (Sons I), [0037](../sprint-0037-sonar-estalador/README.md) (sonar), `scripts/gen_sounds.py`, ADR-002/005 |

## Objetivo

Depois do P0 fog (0047), a névoa deixa de ficar muda fora dos eventos e o Estalador vira
**clicker rítmico** com a névoa em pulsos:

1. **Gritos de monstro** novos (Corredor + Carpideira) — timbre com terror, sem “blehhh”.
2. **Gritos ambiente** distantes (spec §5 / §3.1.1) — só cliente, zero horda, agenda 1–3 min.
3. **Estalador:** burst de cliques rápidos + **várias ondulações pequenas** no ritmo (mod3 ou anéis na tela).

Fora desta sprint (vêm depois, pedido do Johan): Carpideira Witch/look, almas esqueléticas /
choro de alma (§3.9.1), transform 100%, aperto da preta. **Não reabrir fog visual** salvo bug blocker.

## O que entra

- `NOM_EstaladorClick` por `gen_sounds.py`; gritos Corredor / Carpideira / Ambient a partir dos
  MP3 ElevenLabs do Johan (`scripts/import_elevenlabs_screams.py`); banco `NOM_AmbientScream1`…`4`.
- Regras puras: batidas do burst / ripples (`NOM_SonarRules`); agenda ambiente por cor
  (`NOM_AmbientScreamRules`).
- Cliente: ripples sincronizados aos cliques; agenda de gritos ambiente (`NOM_AmbientScream`).
- mod3: impulsos curtos de sonar (reuso `FlowGrid.sonar`), teto de anéis revisado.
- Gameplay do achado: **um** evento de sonar por burst (como 0037); ripples = presença.
- Debug: `NOM.ambientScream()` + botão no painel; `NOM.sonar()` continua.

## Critérios de aceite

- [ ] Burst do Estalador soa série rápida de cliques (não 3 “tec” nem latido) — escuta Johan
- [ ] Na névoa, várias ondulações pequenas no tempo dos cliques (mod3 ou anéis)
- [ ] Agachado+parado / casa / MP intactos (um find por burst)
- [ ] Corredor e Carpideira: gritos novos; horda / um grito por névoa intactos
- [ ] Gritos ambiente audíveis na branca e na vermelha; zero horda; respeitam `FogAmbience`
- [ ] Preta: ambiente rarefeito ou off (não compete com Tição)
- [x] Regras e wiring com testes verdes (`./run-tests.sh`) — não confirma escuta no jogo

## Roteiro de teste no jogo

1. `scripts/dev-sync.sh` na branch; reiniciar o jogo; só o mod **Staging**.
2. Névoa branca: ouvir drone +, a cada 1–3 min, grito humano longe (`NOM.ambientScream()` força).
3. `NOM.sonar()` / Estalador perto: burst rítmico + ripples na névoa; em pé o acha; agachado parado passa.
4. Corredor grita → horda; Carpideira um grito por névoa.
5. Vermelha: ambiente um pouco mais perto/frequente; gritos de monstro presentes.
6. Preta: sem wall of screams; Tição/crepitar mandam.
7. Escuta A/B do Johan **antes** de merge (como 0034).
