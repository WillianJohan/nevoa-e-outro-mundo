# Sprint 0050: almas esqueléticas na névoa branca

| Campo | Valor |
|-------|-------|
| Status | `em teste` (PR draft → staging; **não mergear** até o Johan ouvir e jogar) |
| Branch | `sprint/0050-almas-esqueletos` (saiu da `staging`; independente da 0048 Sons II e da 0049 transform) |
| Origem | refinamento §3.9.1 (Agent Store); prefs Johan ~70% crawler, gap 45–120 s, vida baixa, só rua, TTL 10 s–1 min |
| Plano | [plan.md](plan.md) |

## O que entrou

- **Levas na névoa branca:** a cada 45–120 s reais, onda de ~10 / 15 / 20 (jitter ±3) almas na **rua** (`isOutside`). Vermelha, preta e interior: fora.
- **Mix:** ~70% crawler no spawn (`addZombiesInOutfit` longa); resto shambler mancando (`doZombieSpeed(3)`). Seek lento (`pathToLocationF` pro jogador).
- **TTL:** 10 s / 30 s / 1 min por indivíduo; despawn com FX negro + som. Entrar em casa também despawna.
- **Look mínimo:** `setSkeleton(true)` + vida `0,25` (spike de look negro/decomposto; fallback se falhar no jogo).
- **Áudio (Johan + ElevenLabs):** 5 oggs `NOM_Alma{Spawn,Crawl,Shamble,Group,Despawn}` via `scripts/import_elevenlabs_almas.py`. Não chamam horda.
- **Sandbox:** `AlmaEnabled` (ligado por padrão).
- **Debug:** `NOM.alma()` + botão no painel ("Leva de almas").

## Decisões na ausência do Johan

- Número **0050** (0048 = Sons II; 0049 reservado a transform).
- Leva de debug limitada a 8 pra não lotar o save de teste.
- Partícula negra = `NOM_Cinza.png` tingida de preto no overlay (sem textura nova).
- Outfit `nil` no spawn + `setSkeleton` (sem arquivo de roupa no repo).

## Testes

`test_alma_rules`, `test_alma`, `test_night_rules` (wanted alma), `test_debug_rules`, `test_debug_panel`, `test_credits`, `test_translations`, `./run-tests.sh`.

## Roteiro de teste no jogo

1. Staging ativo, névoa branca: `NOM.setFog(true)` e `NOM.alma()`.
2. Esperado: esqueletos na rua, maioria rastejando, vêm devagar; som de spawn/grupo; somem em até ~1 min com fumaça preta.
3. Entrar em casa: almas na soleira somem / não entram.
4. `NOM.setRedFog(true)` / `NOM.setBlackFog(true)`: sem almas novas; as vivas somem.
5. Escutar os 5 oggs (spawn, crawl, shamble, group, despawn) antes do merge.
