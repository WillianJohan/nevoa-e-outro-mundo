# Plano da sprint 0045: luz que pisca e tempestade

**Origem:** teste do Johan no jogo em 2026-10-07, depois da pilha 0039–0044. "A lanterna não ficou
piscando: às vezes desligou, às vezes ligou de volta. Os postes ficaram acesos, mas não piscando.
Seria interessante colocar tempestade, relâmpago, na névoa preta ou vermelha. A branca está perfeita."

**Decisões do Johan (2026-10-07):**
- postes: alguns perto do jogador piscam de vez em quando, na preta e na vermelha;
- o clarão do relâmpago congela os Tições perto por ~1 s (a luz congela);
- tempestade com relâmpago e trovão na preta e na vermelha; chuva "pode levar, mas não é regra": 30%
  das névoas;
- a lanterna pisca de verdade (gagueira), não só apaga e volta.

**Evidência** ([pz-api-notes §34](../../architecture/pz-api-notes.md)):
- `ThunderStorm.triggerThunderEvent(x, y, strike, lightning, rumble)`: no servidor transmite pros
  clientes sozinho; o clarão só sai com `strike` ou `rumble`; força = 1 − distância/7500. Vanilla em
  `server/ClientCommands.lua:657-664`.
- Poste: `IsoLightSource.setActive` não serve (o `LightingJNI.checkLights` recalcula o `active` do poste
  da rede antes de passar pro JNI). A cor serve: `setR/G/B` muda `r/g/b`, e o `checkLights` manda
  `setLightColor` quando difere do `rJni`. O `update()` só reescreve a cor da luz de dentro de prédio
  (`getLocalToBuilding() ~= nil`), então só piscam luzes de fora.
- Chuva: `ClimateManager.FLOAT_PRECIPITATION_INTENSITY`, a mesma camada modded da névoa;
  `isRaining()` = intensidade final > 0 e não neve.

## Arquitetura

O servidor decide (ADR-002/005), quem desenha aplica:

1. **`shared/NOM_FlickerRules.lua`** (puro): padrão de pisca como lista de durações que alterna
   apagado/aceso, começa apagado e termina aceso. `torch(escuroMs, rnd)`: gagueira, escuro, gagueira
   de volta. `lamp(rnd)`: gagueira, às vezes um escuro no meio. `stateAt(segs, t)`, `total(segs)`.
2. **Lanterna:** `server/NOM_TicaoLight.lua` monta o padrão e conta a janela inteira como apagada
   (o Tição solta); `shared/NOM_TicaoFreeze.flicker(p, segs)` toca o padrão no dono. Quem mexe na
   lanterna no meio (desliga, guarda) interrompe.
3. **Postes:** `server/NOM_LampFlicker.lua` (preta e vermelha) sorteia de tempos em tempos um poste
   de fora perto de um jogador e manda o padrão ("lampFlicker"; no solo direto);
   `client/NOM_LampFlickerFx.lua` acha a luz e toca o padrão na cor. Na preta, poste piscando não
   congela (o `NOM_TicaoLight` pula ele na janela).
4. **Tempestade:** `shared/NOM_StormRules.lua` (puro: intervalo, ponto do raio, chuva por período);
   `server/NOM_Storm.lua` dispara relâmpago e trovão longe do jogador (sem raio caindo) e, na preta,
   `NOM_TicaoLight.flash`; `server/NOM_ClimateLook.lua` liga a chuva na camada modded quando o
   período sorteou chuva.
5. **Debug:** `NOM.thunder()` e `NOM.flickerLamp()`, com botão no painel (PTBR e EN).

## Tarefas (TDD, teste antes)

1. `tests/test_flicker_rules.lua` → `NOM_FlickerRules`.
2. Lanterna: `test_ticao_light` (gagueira no dono, janela inteira solta, quem guarda interrompe) →
   `NOM_TicaoLight` + `NOM_TicaoFreeze` + `NOM_FogClient`.
3. Postes: `tests/test_lamp_flicker.lua` (só na preta/vermelha, só luz de fora e perto, teto de 2,
   cor volta no fim e no fim da névoa, Tição solta na janela) → servidor + cliente.
4. Tempestade: `tests/test_storm.lua` (só preta/vermelha com névoa aberta, intervalo, ponto longe,
   sem raio caindo, clarão congela na preta) e `test_climate_look` (chuva só no período sorteado,
   rampa, desliga no fim) → `NOM_StormRules`, `NOM_Storm`, `NOM_ClimateLook`.
5. Debug: `test_debug`, `test_debug_panel`.
6. Evidência §34, README, índice, HANDOFF, `./run-tests.sh`, review.
