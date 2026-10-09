# Sprint 0048: Sons II (plano de implementação)

> TDD primeiro. Code review só no fim da entrega (Johan, 2026-10-06).

**Objetivo** ([produto §3.1](../../proximos-passos-refinamento.md#31-sons-ii--gritos-monstro--ambiente--estalador-clicker-rítmico)):

- gritos de monstro (Corredor + Carpideira) com timbre novo;
- gritos ambiente distantes, só cliente, sem horda;
- Estalador clicker rítmico + ripples na névoa no ritmo dos cliques;
- achado do sonar = **um** evento por burst (0037 intacta na regra).

Fora: almas, Witch/look, fog visual (salvo blocker).

## O que já existe

- Sons: `gen_sounds.py` (`click` ~3 tec, `scream`/`wail` sintéticos), `NOM_sounds.txt`,
  `NOM_FogSound` (drone/metal/rádio), `FogAmbience`.
- Sonar 0037: servidor agenda estalo 5–30 s → um anel RANGE=8 / 1,5 s; `NOM_Sonar.ring` toca
  `NOM_EstaladorClick` + `NOM_SonarFx` / `NOMRender_sonar`.
- Gritos gameplay: `server/NOM_Variants.lua` (Corredor), `NOM_Carpideira` (um por névoa).

## Restrições

`AGENTS.md`: Kahlua; servidor decide (find); sons só `gen_*`; evidência de API; todo `NOM.*`
com botão no painel; textos PTBR+EN.

## Ordem

| # | Tarefa | Depende |
|---|---|---|
| 1 | Docs sprint + índice / HANDOFF | — |
| 2 | Regra pura: `BEAT_MS`, ripple (raio/duração/alfa/teto) + testes | — |
| 3 | Regra pura: agenda gritos ambiente por cor + testes | — |
| 4 | `gen_sounds`: burst clicker + gritos monstro + banco ambiente; CREDITS; `NOM_sounds.txt` | 2, 3 |
| 5 | Cliente ripples (`NOM_SonarFx`) + mod3 impulso curto; testes fx / contrato | 2, 4 |
| 6 | Cliente `NOM_AmbientScream` + debug/painel/traduções | 3, 4 |
| 7 | Wiring variantes (variantes de grito se houver); testes config/fog_sound | 4, 6 |
| 8 | `./run-tests.sh` verde; PR draft → staging | todas |

---

### Tarefa 2 — batidas e ripples (regra)

`shared/NOM_SonarRules.lua`:

- `BEAT_MS`: offsets fixos do burst (espelho do OGG; 6–12 batidas em ~1–2 s).
- `RIPPLE_RANGE` (~3), `RIPPLE_DURATION_MS`, `RIPPLE_ALPHA`, `RIPPLE_FADE_MS`.
- `MAX_RINGS` sobe (vários ripples × vários Estaladores).
- `rippleRadius` / `rippleAlpha` / `rippleDone` (espelho da curva do anel grande).
- Find: `RANGE`/`DURATION_MS` **inalterados** (servidor).

Testes em `tests/test_sonar_rules.lua` (+ contrato gen_sounds ↔ `BEAT_MS`).

### Tarefa 3 — ambiente (regra)

`shared/NOM_AmbientScreamRules.lua`:

- gap ms por cor (branca raro, vermelha um pouco mais frequente, preta off ou raro);
- distância de emitter (longe; vermelha um pouco mais perto);
- `enabled(color, FogAmbience)`; validação de índice de clip.

Testes `tests/test_ambient_scream_rules.lua`.

### Tarefa 4 — síntese

- `click()`: burst nos `BEAT_MS`, último mais forte; identidade clicker (não animal).
- `scream` / `wail`: raspagem+ar+eco / lamento que desafina; opcional 2–3 variantes.
- `ambient_scream(rng)`: “gente” longe, passa-baixa + eco.
- Declarar em `NOM_sounds.txt` (ambiente: `master = Ambient`, `distanceMax` alto).

### Tarefa 5 — ripples no cliente / mod3

- `NOM_SonarFx`: no anel, agenda N ripples em `born = now + BEAT_MS[i]`; desenha com curva ripple;
  no instante do beat tenta `NOMRender_sonarRipple` (ou `NOMRender_sonar` com raio curto).
- `Sonar.java` / `Flow.addSonarRipple`: RANGE/DURATION curtos; `MAX_RINGS` alinhado ao Lua.
- Find no servidor: um anel como hoje (sem N finds).

### Tarefa 6 — ambiente no cliente

- `client/NOM_AmbientScream.lua`: OnTick, névoa visível + FogAmbience; sorteia gap; toca clip
  num `getFreeEmitter` longe do jogador (pz-api-notes §22 / padrão sirene/aparelho).
- `NOM.ambientScream()` + cartão no painel + chaves UI.

### Tarefa 7 — monstro

- Corredor: se variantes, `ZombRand` no nome do som; Carpideira idem no `SCREAM`.
- Sem mudar cooldown / um grito por névoa / `NOM_Night.call`.

## Resultado

| Tarefa | Status | Testes |
|---|---|---|
| 1 docs | feita | — |
| 2 ripples regra | feita | `test_sonar_rules` (beats + ripple) |
| 3 ambiente regra | feita | `test_ambient_scream_rules` |
| 4 sons | feita | `gen_sounds` + `test_config` / CREDITS |
| 5 fx/mod3 | feita | `test_sonar_fx`, `test_mod3_sonar`, FlowSonarTest |
| 6 cliente ambiente | feita | `test_ambient_scream` + debug/painel |
| 7 monstro | feita | variantes Corredor/Carpideira; testes variants/carpideira |

Fora (próximas sprints): almas, Witch/look, calibração fina do soluço, escuta A/B do Johan.
