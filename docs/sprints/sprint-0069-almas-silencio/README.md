# Sprint 0069: almas em silêncio

| Campo | Valor |
|---|---|
| Branch | `sprint/0069-almas-silencio` (sai da `staging`) |
| Origem | Johan, 2026-10-12: "quem tá gritando o tempo todo" na névoa vermelha |
| Plano | [plan.md](plan.md) |

## O que o log mostrou

`console.txt` da sessão de 2026-10-12 (17:59), névoa vermelha, com `-debug`:

- **Gritos de verdade:** 2 `scream played` (1 Carpideira, 1 ambiente) e 27 `scream blocked`. O gate funciona.
- **Almas:** ~40 vivas o tempo todo (25–56), mas com TTL de 5–15 s. Em ~38 levas foram 634
  nascimentos e 597 sumiços (572 por TTL).
- **Quem soava:**
  - `NOM_AlmaDespawn` em cada alma que sumia;
  - `NOM_AlmaGroup` a cada leva (a leva sai a cada 5 s, o som dura 3,9 s, alcance 50);
  - o gemido de evento (`NOM_AlmaCrawl` / `NOM_AlmaShamble`) de cada alma a cada 8 s.
  São gemidos de sofrimento com voz humana (ElevenLabs, sprint 0053). Somados, davam ~10 por
  segundo: de longe soava como grito sem parar.
- O `NOM_AlmaSpawn` individual já não tocava: a leva nasce quieta e só manda o grupo.
- O Estalador (548 estalos na sessão) ficou de fora por decisão do Johan.

## O que mudou

- **Nascer e sumir de cada alma:** só o visual (a rajada de cinza preta); nenhum som
  (`NOM_AlmaRules.fxSound`).
- **Gemido de grupo da leva:** no máximo **1 a cada 60 s** (`GROUP_SOUND_GAP_MS`,
  `NOM_AlmaRules.groupSoundDue`). A leva continua a cada 5 s. O botão "Leva de almas agora"
  do painel toca sempre, pra dar pra ouvir.
- **Gemido de evento de cada alma:** a cada **90 s** (era 8 s; `SOUND_EVENT_MS`). O primeiro sai
  num ponto sorteado dentro desses 90 s, então com TTL de 5–15 s a maioria das almas da branca
  e da vermelha não geme. Na preta (TTL ilimitado) cada alma geme uma vez a cada 90 s.

Conta grosseira na vermelha (40 almas, TTL médio 10 s): de ~10 gemidos/s pra ~0,5/s, metade
fora do alcance de 22 tiles.

**Voltar atrás:** `SOUND_EVENT_MS = 8000`, `GROUP_SOUND_GAP_MS = 0` e `fxSound` devolvendo
`R.SOUND[kind]`.

## Roteiro no jogo

1. Staging com `-debug`, `NOM.setRedFog()` (ou o botão do painel).
2. Ficar 2–3 min parado na rua: as almas aparecem e somem (cinza preta), quase sem gemido;
   um coro de grupo de vez em quando (não mais que 1 por minuto).
3. Painel → Almas → "Leva de almas agora": o coro de grupo toca na hora.
4. Névoa preta: muitas almas; gemidos espaçados, sem coro contínuo.
5. Se ainda houver "grito constante": `python3 scripts/analyze_scream_log.py` no `console.txt` e
   contar `[NOM] sonar estalo` (o Estalador ficou como estava).

## Testes

`./run-tests.sh`: `test_alma_rules.lua` (`alma_fx_sound_only_group`, `alma_group_sound_gap`,
`alma_event_sound_spaced`) e `test_alma.lua` (`alma_group_fx_spaced`).
