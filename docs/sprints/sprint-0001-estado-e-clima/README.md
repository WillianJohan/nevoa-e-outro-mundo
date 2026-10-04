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
- [ ] Transição suave (~20 minutos de jogo), sem corte seco
- [ ] Toggle e `DarkIntensity` no sandbox alteram o efeito
- [ ] Em MP (servidor local + 2 clientes), os dois clientes escurecem juntos
- [ ] Todo texto visível sai de chave de tradução (`Translate/PTBR`), nunca string solta no Lua
- [ ] `./run-tests.sh` cobre a máquina de estado de `NOM_Rules.lua` e devolve exit code

## Checkpoints

- **04/10** — Design aprovado em brainstorming; GDD, ADRs e roadmap escritos.
- **04/10** — Tasks 1-5 implementadas na branch: runner `luajit` (exit 0/1 provado nas duas direções), `NOM_Rules` (18 testes), `NOM_Config` + sandbox + traduções PT-BR/EN (22 testes), `NOM_World`, `NOM_Atmosphere`. Falta o roteiro in-game e o MP.
- **04/10** — Review achou o modelo do clima errado (efeito saturava, névoa travava, `DarkIntensity` só mudava a velocidade, cliente de MP sobrescrito pelo servidor). Aplicação do clima movida pro servidor: `server/NOM_ClimateLook.lua` no `OnClimateTick`, valor absoluto com interpolate 1. `client/NOM_Atmosphere.lua` e `NOM_Rules.unmix` removidos. Teste novo simula o jogo (lerp in-place, K frames por minuto). Roteiro in-game: a transição leva 20 minutos de jogo — no solo, ~50 s reais com o dia de 1 h; no MP, mesma cadência do anoitecer vanilla (pacote de clima a cada 10 minutos de jogo, fade de ~5 s no cliente). Log `[NOM]` sai no console do **servidor** em MP. Névoa forçada pelo admin não liga o estado de névoa (esperado).

## Aprendizados

1. **Nascer e pôr do sol ficam na estação, não no `ClimateManager`.** É `getClimateManager():getSeason():getDawn()` / `getDusk()` — é o que o próprio jogo usa em `Foraging/forageSystem.lua`. O plano tinha `clim:getDawn()`.
2. **Layout de mod do B42.20:** `mod.info` e `media/` dentro de `42/`, pasta `common/` existindo do lado, e tradução em **JSON** (`Translate/<LANG>/Sandbox.json`), não mais `.txt`. Tooltip de sandbox é a chave com sufixo `_tooltip`.
3. **A camada modded do clima não é uma mistura: é um lerp em cima do próprio interno, todo frame.** `ClimateFloat.calculate()` roda a cada update e faz `internal = lerp(modInterpolate, internal, modded)` e depois `final = internal` (sem override). O interno só volta pro vanilla em `updateValues()`, **uma vez por minuto de jogo**, e só no SP/servidor. Com interpolate < 1 o valor anda pro alvo a cada frame: escurecia até o máximo, a névoa do mod travava a detecção ligada e o `DarkIntensity` só mudava a velocidade. Desfazer a mistura (o antigo `unmix`) não tinha como acertar. Em MP, o cliente recebe o valor **final** do servidor e aplica como override (`readPacketContents`), então o que o cliente escreve na camada modded é ignorado. E a névoa tem dois tipos de override: o do sandbox (FogCycle "sem névoa"/"névoa eterna", ou ClimateCycle "nevasca eterna") é **de valor**, o final não depende do interno; o do `WeatherPeriod` (`setOverride(0, linearT)` durante uma frente de chuva/tempestade) **não é**, e o jogo faz `final = lerp(t, internal, 0)` — com a névoa do mod dentro do interno, ler o final travava a flag de névoa ligada. Correção: escrever **só no servidor**, no `OnClimateTick` (que roda logo depois de `updateValues()`, com o interno limpo), o valor já misturado com `setModdedInterpolate(1)` — aí todo frame até o próximo minuto dá o mesmo resultado. Névoa pra detecção: sem override, `getInternalValue()`; override de valor do sandbox, `getFinalValue()`; override do `WeatherPeriod`, `blend(getInternalValue(), getOverride(), getOverrideInterpolate())` refeito com o interno limpo. Rampa conta minutos de jogo (um passo por `OnClimateTick`), não tempo real.
   Evidência (bytecode B42.20, `zombie/iso/weather/`):
   - `ClimateManager.update`: `if tickIsClimateTick && !GameClient.client { updateSandboxOverrides(); updateValues(); weatherPeriod.update() }` → `if tickIsClimateTick: LuaEventManager.triggerEvent("OnClimateTick", this)` → loops `ClimateColor.calculate()`, `ClimateFloat.calculate()`, `ClimateBool.calculate()`. `tickIsClimateTick` liga quando `GameTime.getMinutesStamp()` muda. O evento dispara também no cliente de MP, por isso o `if isClient() then return end`.
   - `ClimateFloat.calculate`: `if isModded && modInterpolate > 0: internalValue = lerp(modInterpolate, internalValue, moddedValue)`; `if isOverride && interpolate > 0: finalValue = isOverrideValue ? lerp(interpolate, overrideInternal, override) : lerp(interpolate, internalValue, override)`, senão `finalValue = internalValue`. `ClimateColor.calculate` faz o mesmo com `ClimateColorInfo.interp`.
   - `ClimateManager.readPacketContents` (cliente de MP): cada float vira `setOverride(valorDoServidor, …)` e cada cor `ClimateColor.setOverride(reader, …)` — o cliente mostra o final do servidor.
   - `ClimateColor.setModdedValue` copia (`moddedValue.setTo(info)`), então um `ClimateColorInfo` só, reaproveitado, basta.
   - `updateSandboxOverrides`: `fogOverride = (ClimateCycle == 6 && FogCycle != 2) ? 4 : FogCycle`; com `fogOverride > 1` chama `setEnableOverride(true)` e `setOverrideValue(true)` na névoa. Não existe getter de `isOverrideValue`, por isso o mod olha o sandbox.
   - `WeatherPeriod.updateCurrentStage`: `fogIntensity.setOverride(0, currentStage.linearT)` (e `setOverride(0, 1)`), sem `setOverrideValue`. Roda no `weatherPeriod.update()`, antes do `OnClimateTick`.
   - `ClimateFloat` expõe `getInternalValue`, `getFinalValue`, `isEnableOverride`; **não** expõe `isEnableModded` (nem `ClimateColor`). Limite conhecido: se outro mod desligar a nossa camada, ela só volta quando o peso passar por 0 de novo.
4. **A camada modded do clima é compartilhada.** Desligar (`setEnableModded(false)`) todo tick apaga o que outro mod pôs ali. Só desligamos o que nós ligamos, uma vez.
5. **Constantes `ClimateManager.FLOAT_*` / `COLOR_*` e `ClimateColorInfo` são expostas ao Lua** (vanilla usa em `PopupColorEdit.lua` e `ClimateColorsDebug.lua`), e o construtor de 8 floats existe no bytecode.
6. **Histerese precisa de piso.** Com limite 0.05 e histerese 0.05, a condição de saída virava `>= 0`, sempre verdadeira. Sandbox agora começa em 0.1 e a regra tem piso de 0.01.

## Pendências que a próxima sprint herda

- **Roteiro in-game e MP inteiros** (Task 6 do plano): merge feito antes do teste in-game por decisão do Johan; testar em lote depois.
- Teste do ramo `ClimateCycle == 6` (nevasca eterna) em `tests/test_climate_look.lua` não existe — review round 4, minor.
- Conferir no jogo o efeito da névoa do mod no combate à distância (`CombatManager` lê `getFogIntensity()`).

## Sessões

- 2026-10-04 — abd764e2-7a9a-416b-b9b3-1630ab9e761f — brainstorming, GDD, ADRs, repo
