# Sprint 0034: sons I, sirene e fuga (plano de implementação)

> Para agentes: executar tarefa por tarefa (superpowers:subagent-driven-development). Code review só no fim da entrega (decisão do Johan, 2026-10-06).

**Objetivo:**
- a sirene toca 15 s e a névoa visual já começa a subir com ela;
- os 30 s seguintes à sirene são a FUGA: o jogador se mexe, os zumbis ficam parados e ainda não há monstro;
- no fim da fuga a névoa de verdade abre (bichos, comportamento, Sem-rosto e Outro Mundo);
- sirenes novas, sintetizadas por nós.

**Decisões do Johan (2026-10-06):**
- **Sirene de 15 s:** "45 segundos é tempo demais, o jogador vai ficar surdo".
- **Fuga de 30 s:** "quando a sirene toca, já começa a névoa, não precisa esperar segundos... o tempo de 30/45 segundos é o tempo pro jogador se movimentar antes dos bichos começarem". Escolheu 30 s fixos, sem sandbox.
- **O que vem já na sirene:** a névoa visual sobe aos poucos durante a fuga, com mais escuridão e os sons de ambiente.
- **O que espera o fim da fuga:** zumbis soltos, monstros, comportamento de névoa, Sem-rosto e Outro Mundo.
- **Sirene branca:** `branca_engolida` (a névoa engole o som). A vermelha e a preta estão em escolha; o Johan pediu "sirene de verdade, com estática".

## Restrições globais

As do `AGENTS.md`:
- Kahlua;
- ADR-005;
- evidência de API;
- fakes fiéis;
- textos PTBR + EN;
- PT-BR com acento.

Sons e texturas só pelos nossos `scripts/gen_*.py`.

---

### Tarefa 1: sirene de 15 s (FEITA, `37d7bfc`)

---

### Tarefa 2: a névoa sobe na sirene; 30 s de fuga antes dos bichos

**Arquivos:**
- Modificar:
  - `shared/NOM_FogEventRules.lua`
  - `shared/NOM_World.lua`
  - `shared/NOM_FogState.lua`
  - `server/NOM_FogEvent.lua`
  - `server/NOM_ClimateLook.lua`
  - `server/NOM_Fog.lua` (resposta `fogState`)
  - `client/NOM_FogClient.lua`
  - `client/NOM_FogOverlays.lua`
  - `client/NOM_FogVignette.lua`
  - `client/NOM_FogSound.lua`
  - `client/NOM_Console.lua` e `client/NOM_Debug.lua` (textos de ajuda)
- Traduções: `Translate/PTBR|EN/Sandbox.json` (`FogDailyChance_tooltip`) e `Mod.json`.
- Testes:
  - `tests/test_fog_event_rules.lua`
  - `tests/test_fog_event.lua`
  - `tests/test_fog_client.lua`
  - `tests/test_world.lua`
  - o teste do ClimateLook (se existir; senão o mais próximo que cobre a rampa)
  - os testes de overlays, vinheta e som, se existirem

**Modelo:**
- **Contagem:** a contagem que existe hoje (`countdown`) passa a ser a FUGA. `R.SIREN_MS` é renomeado pra `R.GRACE_MS = 30000`, e todos os usos acompanham (`NOM_SirenFreeze.start(dir, R.GRACE_MS)` no solo e no cliente). O som da sirene dura 15 s, e a contagem não depende dele.
- **Flag nova no mundo** (servidor; no solo, o mesmo processo):
  - `NOM_World.rising` (bool) e `NOM_World.risingRed` (bool), com `NOM_World.setRising(on, red)` e borda `notify("rising", was)`;
  - `risingRed` só vale com `rising`.
- **`NOM_FogEvent`:**
  - `siren()` chama `NOM_World.setRising(true, s.red)` (também na recarga no meio da contagem, porque a sirene toca de novo);
  - `begin()` faz `setFog(true, red)` e depois `setRising(false)`;
  - `stop()` com a sirene contando (cancelar) chama `setRising(false)`;
  - o `force` do debug passa por `stop`/`siren` e funciona sozinho; o `skip` dá contagem 0, a névoa abre no próximo tick e a subida dura um tick, o que está certo.
  - `NOM_World.fog` CONTINUA abrindo só no `begin()`: toda a regra de jogo (variantes, stats, Sem-rosto, Carpideira, VariantAI, Eco, Outro Mundo, ScreenFx) não muda.
- **`NOM_ClimateLook`** (o visual do clima, que também alimenta o mod2 e o mod3 via `getFogIntensity`):
  - o alvo das rampas `eventRamp` e `fogRamp` passa a ser `w.fog or w.rising`;
  - o de `redRamp`, `(w.fog and w.red) or (w.rising and w.risingRed)`.
  - A rampa de 20 minutos de jogo fica: com 30 s reais (cerca de 12 minutos de jogo na duração de dia padrão) a névoa chega a uns 60% quando os bichos soltam e completa logo depois, que é a subida que o Johan escolheu.
  - Sirene cancelada: a rampa desce.
- **`NOM_FogState`** (quem vê e ouve):
  - campos `rising` e `risingRed`, mais `NOM_FogState.setRising(on, red)`;
  - helpers `NOM_FogState.visible()`, que devolve `on or rising`, e `NOM_FogState.visibleRed()`, que devolve `(on and red) or (rising and risingRed)`.
  - **Quem liga:**
    - no solo, o `NOM_FogEvent` (ramo `not isServer()`, nos mesmos pontos em que chama `NOM_SirenFreeze.start/stop`, e no `begin()`);
    - no MP, o `NOM_FogClient`: `siren` faz `setRising(true, args.red)`, e `fog` com `on=true` e `sirenStop` fazem `setRising(false)`.
- **Visuais e sons de ambiente** trocam `NOM_FogState.on` por `visible()` (e `red` por `visibleRed()` onde a cor importa):
  - `NOM_FogOverlays`;
  - `NOM_FogVignette`;
  - o drone e o metal do `NOM_FogSound`. O rádio do Sem-rosto continua em `on`.
  - `NOM_ScreenFx` NÃO muda: o Outro Mundo espera a fuga.
- **Quem entra no meio da fuga (MP):** o `fogState` já reenvia `siren`, então o cliente liga a subida. Confira que funciona.
- **Textos:**
  - `FogDailyChance_tooltip` (PTBR/EN): "anunciada por uma sirene; a névoa começa a subir na hora e, 30 segundos depois, os monstros acordam" (EN equivalente);
  - `Mod.json` no mesmo espírito;
  - ajuda do `NOM.setFog`/`NOM.fog` no console: "sirene, a névoa sobe e os bichos soltam em 30 s".

- [ ] **Passo 1: testes que falham.**
  - `R.GRACE_MS == 30000`;
  - na sirene, `NOM_World.rising == true` e `NOM_World.fog == false`;
  - aos 29,9 s, ainda `fog == false`; aos 30 s, `fog == true` e `rising == false`;
  - cancelar a sirene desliga `rising`;
  - recarregar no meio da contagem religa `rising`;
  - sirene vermelha deixa `risingRed == true`;
  - ClimateLook: a rampa sobe com `rising` sem `fog`;
  - cliente MP: `siren` liga `FogState.rising`, e `fog on` e `sirenStop` desligam;
  - `visible()` e `visibleRed()`;
  - overlays, vinheta e drone ligam com `rising` (onde houver teste);
  - Sem-rosto e ScreenFx NÃO ligam com `rising`.
- [ ] **Passo 2:** rodar `luajit tests/run.lua`. Esperado: FAIL.
- [ ] **Passo 3:** implementar.
- [ ] **Passo 4:** rodar `./run-tests.sh`. Esperado: verde. O teste de desempenho do mod3 "escala 2" pode falhar por carga; ele falha igual na `main`.
- [ ] **Passo 5: commit.** `git commit -m "Sirene: a névoa sobe na hora e os bichos soltam depois de 30 s de fuga"`

---

### Tarefa 3: sirenes novas no `gen_sounds.py`

Depende da escolha do Johan pra vermelha. Vem dos protótipos em `.superpowers/sirens/` (não versionados).

- `scripts/gen_sounds.py`: as funções `siren` e `siren_red` passam a gerar as escolhidas, com 15 s e o mesmo formato. Porte o código numpy dos protótipos; nada copiado de terceiros.
- Rodar o script e commitar os `.ogg` gerados, como os outros sons.
- Conferir que o `NOM_Siren` não depende da duração antiga.

---

### Tarefa 5: estática na tela, 3 s antes da sirene e sutil durante a névoa

Pedido do Johan (2026-10-06):
- 3 segundos ANTES da sirene, a tela do jogador começa a ganhar estática, sutil no início e depois com mais destaque;
- a estática tem a cor da névoa;
- ela continua sutil a névoa toda, como efeito auxiliar.

Depende da Tarefa 2 (mesmos arquivos do evento).

**Arquivos:**
- Modificar:
  - `server/NOM_FogEvent.lua` (fase de presságio)
  - `server/NOM_Fog.lua` (se precisar)
  - `client/NOM_FogClient.lua` (comando `presage`)
  - `shared/NOM_FogState.lua` (presságio e marcas de tempo)
  - `client/NOM_ScreenFx.lua` (camada nova)
- Criar ou modificar a regra pura da curva: `shared/NOM_ScreenFxRules.lua` (`R.staticLevel`), ou um `shared/NOM_FogStaticRules.lua` se ficar mais limpo.
- Textura: `scripts/gen_textures.py` gera `NOM/NOM_NevoaEstatica.png`, um chiado fino em tons de cinza que fecha em mosaico. Commitar o PNG e atualizar a lista do topo do script.
- Testes: regra da curva, `test_fog_event` (presságio), `test_fog_client` (comando) e o teste do ScreenFx que existir.

**Comportamento:**
- **Presságio no servidor:** quando `R.update` devolve `"siren"`, o evento não toca a sirene na hora.
  - Decide a cor (o `decideRed` que hoje está no `siren()` passa pra cá; a sirene reaproveita a cor salva).
  - Abre uma contagem real de `R.PRESAGE_MS = 3000`, com o mesmo `R.countdown` (para com o jogo pausado).
  - Avisa quem vê: no dedicado, `sendServerCommand("presage", { red })`; no solo, direto no `NOM_FogState`.
  - No fim da contagem, chama `siren(false)`.
  - `stop()` durante o presságio cancela como a sirene (com o `R.cancel` e o `sirenStop` que já existem).
  - No `status()`, o presságio conta como sirene pendente, pros toggles do debug.
  - O debug `force(red, skip)` sem skip passa pelo presságio, pra dar pra testar; com skip, vai direto.
  - Recarregar no meio do presságio: ele está só em memória, e o próximo `R.update` devolve `"siren"` de novo. Confira que é isso que acontece.
- **Estado de quem vê:** `NOM_FogState.setOmen(red)` guarda `omenAt` (getTimestampMs) e a cor. O `siren` guarda `sirenAt`. O fim da névoa e o `sirenStop` limpam o presságio.
- **Curva** (regra pura, testada com luajit), devolvendo o alfa base de 0 a 1:
  - **Presságio (0 a 3 s depois de `omenAt`):** de 0,03 a 0,22 em curva que acelera (`t^2`), sutil no começo e com destaque no fim.
  - **Da sirene em diante:** desce de 0,22 até o nível SUTIL de 0,05 em ~4 s.
  - **Durante a subida e a névoa** (`NOM_FogState.visible()`): fica em 0,05.
  - **Fim da névoa ou sirene cancelada:** desce a 0 em ~3 s.
  - Os valores são constantes nomeadas, pra ajustar no teste do Johan.
- **Cor:** a da névoa.
  - Branca: `NOM_Rules.FOG_COLOR`.
  - Vermelha: `NOM_Rules.RED_FOG_COLOR`, usando o RGB e ignorando o alfa da cor do clima.
  - Deixe um ponto único (`R.staticColor(kind)`) pra preta entrar na 0038.
- **Desenho:**
  - camada nova no `NOM_ScreenFx`: `drawTextureTiled` da textura, com deslocamento aleatório por frame, como o granulado (`R.grainFrame`), pra chiar;
  - multiplicada pela intensidade das opções (`NOM_ScreenFxOptions`) e desligada junto com o toggle `ScreenFx`, que vale como opção de acessibilidade;
  - tem que funcionar FORA do Outro Mundo também: o presságio vem antes de qualquer névoa;
  - evidência: as chamadas de desenho já usadas no próprio `NOM_ScreenFx.lua`.
- **MP:** quem entra no meio da névoa recebe só o nível sutil (pelo `fog` e `visible()`), sem presságio.

- [ ] **Passo 1: testes que falham.**
  - Curva: 0,03 em t=0, cresce até 0,22 em 3 s, desce a 0,05 depois da sirene, fica em 0,05 na névoa e chega a 0 depois do fim.
  - Cor por tipo.
  - `R.update` dá `"siren"`, mas a sirene só toca 3 s reais depois, com o `presage` enviado no dedicado.
  - Pausa congela o presságio.
  - `stop` no presságio cancela sem tocar a sirene.
  - `force` sem skip passa pelo presságio.
  - Cliente: `presage` liga o presságio.
- [ ] **Passo 2:** rodar `luajit tests/run.lua`. Esperado: FAIL.
- [ ] **Passo 3:** implementar, gerar a textura com `python3 scripts/gen_textures.py` e conferir o contraste (`./run-tests.sh` roda o teste de contraste).
- [ ] **Passo 4:** rodar `./run-tests.sh`. Esperado: verde.
- [ ] **Passo 5: commit.** `git commit -m "Estática na tela: presságio 3 s antes da sirene e chiado sutil na névoa, na cor dela"`

---

### Tarefa 4: documentação da sprint (por último, depois da Tarefa 5)

- `README.md` da sprint, com o roteiro de teste;
- GDD (`world-states`, `atmosphere`, `Overview`);
- emenda na ADR-009 (fuga de 30 s, névoa visual na sirene);
- `HANDOFF`;
- `sprints/README`.
