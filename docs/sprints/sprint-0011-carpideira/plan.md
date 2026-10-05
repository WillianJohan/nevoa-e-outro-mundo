# Carpideira — Plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Um 4º monstro da névoa, a **Carpideira**: parada e soluçando baixinho; acordada (jogador perto, lanterna apontada ou barulho alto perto), solta um grito ensurdecedor que chama a horda de longe e vira uma corredora que caça quem a acordou. Um grito por Carpideira por névoa.

**Architecture:** A Carpideira é mais uma variante determinística (ADR-006): entra **no fim** de `NOM_VariantRules.KINDS` (faixa `[12, 15)` com o padrão; a névoa vermelha passa a 1/4 de cada). Quem simula o zumbi (solo: o processo; MP: o cliente dono) a deixa `useless` enquanto calma (a mesma alavanca do Estalador, sprint 0004) e quem a tem carregada toca o soluço local. Quem vê e ouve (solo: o processo; MP: cada cliente) detecta proximidade e lanterna e avisa (`carpideiraWoke`); o servidor confere (variante, névoa, distância, lanterna acesa, limite por jogador) e ouve o barulho sozinho (`Events.OnWorldSound`, bytecode). O servidor decide o grito: marca o `persistentOutfitID` no `ModData` (um por período), chama a horda (`NOM_Night.call`, audição compensada) e espalha `carpideiraScream`; cada cliente toca o grito local, para o soluço, e o dono solta o `useless` e força o spot no jogador.

**Tech Stack:** Lua 5.1 (Kahlua no jogo, luajit nos testes), Python + numpy + ffmpeg pro som.

**Spec:** brief da sprint 0011 (pedido do Johan, desenho aprovado em 05/10/2026), [README da sprint](README.md).

## Global Constraints

- Kahlua: sem `//`, `goto`, operador de bit, `next()`; `unpack`, não `table.unpack`; nada de `%d` com float.
- Lógica autoritativa no servidor (`if isClient() then return end`); lógica pura em `shared/` sem API do jogo; testes contra fakes que imitam o jogo.
- Toda chamada de API com evidência (Lua vanilla arquivo:linha ou bytecode `Classe.metodo` + offset).
- Texto do jogador por tradução PT-BR e EN, sem `%` sozinho; sandbox no namespace `NevoaEOutroMundo`.
- Nada copiado de outro mod nem do jogo; som gerado por `scripts/gen_sounds.py` e listado no `CREDITS.md`.
- Sandbox: `CarpideiraEnabled` (true), `CarpideiraChance` (3), `CarpideiraTriggerRadius` (4), `CarpideiraScreamRadius` (60).
- Soma padrão da névoa: Estalador 5 + Corredor 2 + Sem-rosto 5 + Carpideira 3 = 15%, faixas sem sobreposição.

## Pesquisa (bytecode B42.21) que decide o desenho

- **Barulho no servidor: `Events.OnWorldSound(x, y, z, radius, volume, source)`.**
  `WorldSoundManager$WorldSound.init(Object,IIIIIFFS)` 129–155 dispara o evento com esses
  argumentos; todo `addSound` passa por ele (`WorldSoundManager.addSound` → `getNew` →
  `init`, 16–34). Som de cliente de MP chega ao servidor como `WorldSoundPacket`, e o
  `processServer` 90–139 chama `WorldSoundManager.addSound` com o personagem do pacote
  como `source` (`CharacterID.getCharacter`): o evento dispara no servidor com o jogador
  como fonte. No solo, mesmo processo.
- **Alto ≠ tarefa de casa.** O Lua vanilla chama `addSound` com raio 6–20 em tarefas
  (`shared/TimedActions/ISRemoveBush.lua:41` 20, `ISRemoveGrass.lua:30` 10,
  `ISPickupBrokenGlass.lua:22` 20, `ISDestroyStuffAction.lua:69` 20); armas de fogo têm
  `SoundRadius` de 50 a 200 nos scripts. Corte: raio ≥ 30.
- **Os chamados do próprio mod também são `addSound` com o jogador de fonte** (caça e
  lanterna, `NOM_Night.call`): marcados com `NOM_Night.calling` durante a chamada e
  ignorados.
- **Parada: `setUseless(true)`** (CONFIRMED `client/DebugUIs/DebugContextMenu.lua:566`;
  sprint 0004): o idle não perambula, `WalkTowardState.enter` volta pro idle,
  `RespondToSound` volta cedo, e o `spottedNew` 191–208 zera o alvo. Viaja no pacote do
  zumbi (o dono manda; quem assume a posse herda). Mais `setTarget(nil)` uma vez, pra
  largar uma caçada em andamento.
- **Caçar quem acordou: `z:spotted(p, true)`** (público, `IsoZombie.spotted(IsoMovingObject,Z)`
  → `spottedNew`): com `forced` a chance vira 1 000 000 (1114–1120) e o spot grava alvo e
  última posição vista (1909–1950); é o mesmo spot forçado que o jogo usa pra manter a
  caçada (`updateInternal` 956–991). Só vale sem `useless` (191–208): soltar antes.
- **Soluço em loop no zumbi:** `z:playSoundLocal(nome)` (`IsoGameCharacter.playSoundLocal`
  = `getEmitter().playSoundImpl(nome, null)`, sem pacote; sprint 0005),
  `z:getEmitter()` = `BaseCharacterSoundEmitter` com `isPlaying(J)` e `stopSoundLocal(J)`
  (abstratos, implementados pelo `CharacterSoundEmitter`). `IsoZombie.removeFromWorld`
  **não** para os sons do emitter (só `stopOrTriggerSoundByName`): a varredura para o
  soluço de quem sumiu da lista.
- **Lanterna:** `player:getActiveLightItem()` (EXISTS, liga/desliga sincronizado:
  pz-api-notes §2.4) e `square:isCanSee(pn)` (linha de visão + cone + luz, usado no
  Sem-rosto, §3.4). "Apontada pra ela" ≈ lanterna acesa e ela vista (no cone e iluminada)
  a até 10 tiles. A direção do jogador no servidor não foi confirmada (o
  `Prediction.direction` viaja, quem aplica não foi seguido): o servidor confere só
  lanterna acesa e distância.
- **Achar o jogador pelo ID no cliente:** `getPlayerByOnlineID(id)` (CONFIRMED
  `client/ServerCommands.lua:10`).

## Review Focus

1. Recarregar o save no meio da névoa depois do grito — a Carpideira não grita de novo (o `ModData` guarda os IDs do período).
2. A Carpideira descarrega (vai pro virtual) com o soluço tocando — o loop não fica preso no lugar.
3. Tiro longe (fora de 10 tiles) ou tarefa barulhenta (raio < 30) — não acorda; tiro perto acorda.
4. Fim da névoa com a Carpideira calma — ela volta a andar (useless solto), soluço para.
5. Cliente que entra no meio da névoa depois de um grito — sabe quem já gritou (não toca soluço nela, o dono não a congela de novo).

---

### Task 1: Regras, sorteio e sandbox

**Files:**
- Create: `mod/42/media/lua/shared/NOM_CarpideiraRules.lua`, `tests/test_carpideira_rules.lua`
- Modify: `NOM_VariantRules.lua` (KINDS, CHANCE, ON, config), `NOM_Config.lua`, `sandbox-options.txt`, `Translate/{PTBR,EN}/Sandbox.json`, `NOM_DebugRules.lua` (KINDS), `tests/run.lua`, `tests/test_variant_rules.lua`, `tests/test_config.lua`, `tests/test_debug_rules.lua`

**Interfaces — Produces:**
- `NOM_VariantRules.KINDS = { "estalador", "corredor", "semrosto", "carpideira" }`; `config()` ganha `carpideiraOn`, `carpideiraChance`.
- `NOM_CarpideiraRules`: `ALERT_RANGE = 10`, `LOUD_RADIUS = 30`, `SLACK = 2`, `RATE_MS = 1000`, `REPORT_GAP_MS = 2000`;
  `woke(why, dist, triggerRadius, lit) -> bool` (why = "near" | "light");
  `loud(dist, radius) -> bool`; `screamed(data, period) -> { [pid] = true }` (zera quando o período muda).

- [ ] Testes que falham: `variant_rules_default_total_15` (4 tipos, padrão 5/2/5/3, total 15 ± 1,5 e faixa da Carpideira `[12, 15)`), `variant_rules_red_fog_splits_evenly` (1/4), `carpideira_rules_*` (woke, loud, screamed por período), `config_carpideira_defaults`, `debug_rules_parse_carpideira`.
- [ ] Implementar; `./run-tests.sh` verde (traduções e sandbox conferidos pelos testes existentes).
- [ ] Commit `feat: Carpideira no sorteio da névoa, regras puras e sandbox`.

### Task 2: Perfil — corredora

**Files:** `NOM_NightRules.lua` (`wanted`: `kind == "carpideira"` → `CORREDOR_SPEED`), `tests/test_night_rules.lua`, `tests/test_night_stats.lua` (vermelha 1/4).

- [ ] `night_rules_wanted_carpideira_sprints` falha → implementar → verde → commit.

### Task 3: Carpideira onde é simulada e ouvida

**Files:**
- Create: `mod/42/media/lua/shared/NOM_Carpideira.lua`, `tests/test_carpideira.lua`
- Modify: `NOM_VariantAI.lua` (despacho por frame), `tests/fog_world.lua` (zumbi com emitter, `setUseless`, `spotted`; jogador com `getActiveLightItem`), `tests/test_variant_ai.lua`

**Interfaces — Produces:**
- `NOM_Carpideira.screamed` (`{ [pid] = true }`, período atual, deste processo), `NOM_Carpideira.still` (`{ [zumbi] = true }`).
- `NOM_Carpideira.hold(z, md)` (por frame, dono, na névoa), `NOM_Carpideira.letGo(z)`, `NOM_Carpideira.forget(z)`.
- `NOM_Carpideira.scream(z, p)`: efeitos locais do grito (marca, para o soluço, toca o grito; no dono solta e `spotted(p, true)`).
- `NOM_Carpideira.install(report)`; `report(z, p, why)`.

- [ ] Testes que falham (`test_variant_ai`): `ai_carpideira_still_while_calm` (jogador a 2 tiles, sem mordida e sem andar; controle: zumbi comum morde), `ai_carpideira_scream_hunts_trigger_player`, `ai_carpideira_released_when_fog_ends`, `ai_carpideira_remote_untouched`, `ai_carpideira_reloaded_after_scream_stays_furious`; orçamento vermelho com 4 tipos.
- [ ] Testes que falham (`test_carpideira`): `carpideira_sobs_locally_while_calm`, `carpideira_sob_stops_on_scream_fog_end_and_unload`, `carpideira_reports_proximity`, `carpideira_reports_light_only_when_lit_and_seen`, `carpideira_report_gap`, `carpideira_scan_budget`.
- [ ] Implementar; verde; commit `feat: Carpideira parada, soluço local e aviso de quem a acorda`.

### Task 4: Servidor decide o grito

**Files:** `server/NOM_Variants.lua` (grito, `carpideiraWoke`, `OnWorldSound`, lista pra quem entra), `server/NOM_Night.lua` (`NOM_Night.calling`), `tests/test_variants.lua`.

- [ ] Testes que falham: `carpideira_sp_scream_once_per_period` (som, chamado com raio compensado, `spotted`, segundo aviso nada, período novo grita de novo), `carpideira_scream_survives_reload` (ModData), `carpideira_mp_validates_report` (variante, névoa, distância com folga, andar, lanterna acesa, Eco, morto), `carpideira_rate_limit_per_player`, `carpideira_noise_wakes` (tiro perto sim; longe, baixo, fonte não-jogador, chamado do mod não), `carpideira_noise_scan_one_call_per_common_zombie`, `carpideira_joiner_gets_list`.
- [ ] Implementar; verde; commit `feat: servidor decide o grito da Carpideira (aviso conferido, barulho, um por névoa)`.

### Task 5: Cliente de MP

**Files:** `client/NOM_VariantsClient.lua`, `tests/test_variants_client.lua`.

- [ ] Testes que falham: `variants_client_reports_carpideira`, `variants_client_scream_applies_to_owner`, `variants_client_takes_list`.
- [ ] Implementar; verde; commit.

### Task 6: Sons e debug

**Files:** `scripts/gen_sounds.py` (`sob`, `wail`), `media/scripts/NOM_sounds.txt`, `media/sound/NOM_Carpideira{Sob,Scream}.ogg`, `CREDITS.md`, `client/NOM_Debug.lua` (contagem no status).

- [ ] `config_sound_scripts_point_to_files` e `credits_*` cobrem; `debug_status_counts_carpideiras` falha → implementar → verde → commit.

### Task 7: Docs

GDD (monsters, sandbox com presets, Overview), ADR-011 (Carpideira: quem acorda, quem decide, quem congela), índice e orçamento no `architecture/README.md`, pz-api-notes §13, README da sprint (`em teste`, roteiro in-game), roadmap, README do repo, teste-in-game.
