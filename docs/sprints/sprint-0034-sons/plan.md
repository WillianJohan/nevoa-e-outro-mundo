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
- **Sangue no chão removido** (Johan, 06/10: parecia textura ruim de jogo antigo); sangue de parede fica. Feito no `NOM_DressingRules` (saíram poças, rastros, respingo e o set `bloodFloor`; `MAX_LAYERS` 4 → 2), com o teste `dressing_rules_no_blood_on_floor`; docs na ADR-017 (item 7), GDD e tooltip do sandbox. Na densidade 1 o chão vestido cai de ~82% pra ~66% (vermelha: ~93% → ~83%).

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

### Tarefa 3: sirenes novas no `gen_sounds.py` (FEITA, falta o commit)

Depende da escolha do Johan pra vermelha. Vem dos protótipos em `.superpowers/sirens/` (não versionados).

- `scripts/gen_sounds.py`: as funções `siren` e `siren_red` passam a gerar as escolhidas, com 15 s e o mesmo formato. Porte o código numpy dos protótipos; nada copiado de terceiros.
- Rodar o script e commitar os `.ogg` gerados, como os outros sons.
- Conferir que o `NOM_Siren` não depende da duração antiga.

**Decisões do Johan (2026-10-06), que trocaram o pedido acima:**
- 23 protótipos aprovados como oficiais (7 brancos, 6 vermelhos, 10 pretos); a `branca_engolida` da v7 é a mesma da v5, então ficam 22 sons.
- 10 a 12 s com fim natural, em vez de 15 s; eco de cidade embutido no arquivo.
- 5 sirenes por jogador, todas a 150–500 tiles, em direções diferentes e desencontradas; o perto/longe da Tarefa 7 sai.
- Depois, as 9 da V9 (3 por névoa, feitas pro coro) também viraram oficiais: 31 sons.
- Cada sirene do coro toca com afinação levemente diferente.

**Como ficou:**
- Síntese dos protótipos em `scripts/sirenes/` (v1 a v8, idêntica ao protótipo a 15 s; a v1 refeita pra caber em 10,6 s; a v9 idêntica à versão seca do protótipo, de 10,4 a 10,8 s). O `gen_sounds.py` corta no fim útil, encurta pra 10,6 s sem mudar o tom (WSOLA nosso), aplica a distância (passa-baixa de 4 kHz, 5 reflexões de 0,31 a 1,47 s, cauda de reverb) e termina num fade: 11,8 s cada.
- Sons `NOM_SirenWhite1`–`9`, `NOM_SirenRed1`–`9` e `NOM_SirenBlack1`–`13` (a preta só toca na 0038; os 7–9 e 11–13 são da V9), `distanceMin` 50 e `distanceMax` 500 (conta na [pz-api-notes §23](../../architecture/pz-api-notes.md#23-sirenes-posicionais-sprint-0034)). Saíram `NOM_Siren`, `NOM_SirenRed`, `NOM_SirenFar` e `NOM_SirenRedFar`.
- `NOM_SirenSpotsRules`: `COUNT` 5, 150–500 tiles, pelo menos 40° entre vizinhas pra qualquer sorteio, a primeira em 0 e as outras em janelas até 4 s, sons sem repetir no coro, e afinação sorteada por sirene entre 0,95 e 1,05 (`pitch`, aplicado pelo `NOM_Siren` com `emitter:setPitch`; evidência na §23).

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

### Tarefa 6: aparelhos do Outro Mundo (TV, rádio, caixa de som, carro)

**Pedido do Johan (2026-10-06):** "onde tem rádio, caixa de som, até carro, dá pra colocar sons de estática... coisas que venham de outro mundo tentando se comunicar".

**Decisões do Johan:**
- entra nesta sprint;
- qualquer aparelho fala, ligado ou não, e o ligado tem prioridade e fala mais alto.

**Material de base** (não versionado; leia antes):
- **Proposta:** `.superpowers/sound/guia-sonoro.md`, §4.
- **Pesquisa de API, com evidência:** `.superpowers/sound/api-aparelhos.md`.
- **Protótipos:** `.superpowers/sound/aparelhos/` (`proto_aparelhos.py`, `nom_synth.py` em `.superpowers/sound/`).

**Arquivos:**
- Criar:
  - `shared/NOM_DeviceRules.lua`: regras puras, testadas com luajit;
  - `client/NOM_Devices.lua`: varredura e reprodução, só no cliente; no solo, o mesmo processo;
  - `tests/test_device_rules.lua` e `tests/test_devices.lua`, registrados em `tests/run.lua`.
- Modificar:
  - `scripts/gen_sounds.py`: porte da síntese dos protótipos. A base comum (`nom_synth.py`) pode virar `scripts/nom_synth.py`, importada pelo `gen_sounds.py`;
  - o arquivo de sons em `media/scripts` que já declara os sons do mod;
  - `docs/architecture/pz-api-notes.md` (§ nova com as evidências usadas).
- Opção: se for preciso desligar a feature, use a opção de sandbox de ambiente que já existe (`FogAmbience`). Não crie opção nova sem necessidade.

**Comportamento** (§4 do guia, com estes cortes):
- **Quem fala:**
  - **TV** (`IsoTelevision`): sons `tv*`.
  - **Rádio e aparelho de som** (`IsoRadio`/`IsoWaveSignal` que não é TV): sons `radio*`, ou `caixa_de_som` pra alguns. Sorteio estável por coordenada, pra o mesmo aparelho sempre ter a mesma "voz".
  - **Rádio de carro** (peça `"Radio"`): som `carro`.
  - Tudo vem da lista do jogo (`getZomboidRadio():getDevices()`). Se o rádio do carro não aparecer nela, percorra os veículos com `:iterator()`.
  - Ligado com energia tem prioridade e volume maior (a regra de energia vanilla está na pesquisa).
- **Quando fala:**
  1. **Presságio** (`NOM_FogState`, Tarefa 5): todo aparelho num raio de 25 tiles toca um estouro curto de estática (som novo de ~3 s, `NOM_DevBurst`), cortado quando a sirene chega.
  2. **Fuga** (`rising` sem `on`): nada.
  3. **Névoa aberta (`on`):** a cada 90 a 180 s reais (mínimo de 60 s), o aparelho elegível mais perto entre 6 e 18 tiles toca um evento. Nunca dois ao mesmo tempo pro mesmo jogador. O mesmo arquivo não repete em menos de 3 chamados.
  4. **Sem-rosto a até 10 tiles de um aparelho:** esse aparelho chia junto, com o `NOM_SemRosto.nearest` que o cliente já tem.
     - A respiração depois do grito da vermelha só entra se o cliente já receber um sinal de grito (o `NOM_ScreenFx` tem um flash de grito; confira). Se não houver, fica pra depois e vai no relatório.
  5. **Calmaria, sem névoa ou jogador morto:** silêncio, e o som que estiver tocando para.
- **Som por névoa:**
  - branca: `tv`, `radio`, `caixa_de_som`, `carro`;
  - vermelha: `tv_vermelha`, `radio_vermelha`; caixa e carro usam a versão branca até ganharem a vermelha.
  - Os da preta (`tv_preta`, `radio_preta`) são gerados e declarados, mas só tocam na 0038. Deixe o ponto único de escolha por tipo de névoa pronto.
- **Tocar:**
  - `getWorld():getFreeEmitter(x+0.5, y+0.5, z):playSoundImpl(nome, nil)`, local, sem pacote; no carro, `vehicle:playSoundImpl`;
  - guardar o emissor e o id e parar com `stopSoundLocal(id)`;
  - parar também se o jogador passar de 20 tiles, porque o FMOD não zera depois do `distanceMax`.
  - Os sons são declarados com `distanceMin` 2 e `distanceMax` 18 (veja como os sons do mod já são declarados) e volume de 0,35 a 0,5 do da sirene. A TV é mais baixa e mais rara.
- **Custo:** varrer a lista no máximo a cada ~1 s, filtrando por distância ao quadrado. Nada de varrer quadrados.
- **ADR-005/007:** é atmosfera local do cliente. Não chama zumbi (nada de `addSound`) e não muda o estado do aparelho.

- [ ] **Passo 1: testes que falham.**
  - **Regras:**
    - elegibilidade por distância;
    - o mais perto na faixa de 6 a 18 tiles;
    - intervalo entre 90 e 180 s com mínimo de 60;
    - sem repetição em 3 chamados;
    - nada na fuga, na calmaria ou sem névoa;
    - estouro no presságio em 25 tiles;
    - ligado com prioridade;
    - lista de sons por névoa;
    - "voz" estável por coordenada.
  - **Cliente**, com fakes fiéis (lista de dispositivos, emissor com `playSoundImpl`/`stopSoundLocal`, veículo com a peça `Radio`):
    - toca no aparelho certo;
    - para fora do raio;
    - para quando a névoa acaba;
    - o estouro corta na sirene.
- [ ] **Passo 2:** rodar `luajit tests/run.lua`. Esperado: FAIL.
- [ ] **Passo 3:** implementar.
  - Portar a síntese pro `scripts/gen_sounds.py` (nomes `NOM_DevTv`, `NOM_DevTvRed`, `NOM_DevTvBlack`, `NOM_DevRadio`, `NOM_DevRadioRed`, `NOM_DevRadioBlack`, `NOM_DevSpeaker`, `NOM_DevCar`, `NOM_DevBurst`).
  - Gerar os sons e commitar os `.ogg`, como os outros.
- [ ] **Passo 4:** rodar `./run-tests.sh`. Esperado: verde.
- [ ] **Passo 5: commit.** `git commit -m "Aparelhos do Outro Mundo: TV, rádio, caixa de som e carro chiam na névoa"`

---

### Tarefa 7: sirenes posicionais (3 por jogador) e zumbis olhando pro jogador

> A Tarefa 3 trocou a quantidade, as distâncias e os sons: 5 sirenes a 150–500 tiles, sem perto/longe.

**Pedido do Johan (2026-10-06):** "se a gente tiver múltiplas sirenes no mapa, o som não é mais 2D chapado, ele vem de alguma posição... podem vir longe, podem vir perto, mas sempre num range do jogador".

**Decisões do Johan:**
- pega o jogador e sorteia uma distância entre 40 e 200 tiles; tocam 3 sirenes em paralelo;
- no máximo 1 perto, as outras longe;
- os zumbis congelados viram pro jogador mais próximo.

Depende da Tarefa 6 (as duas mexem em `gen_sounds.py` e `NOM_sounds.txt`): só comece depois que ela estiver commitada.

**Arquivos:**
- Criar:
  - `shared/NOM_SirenSpotsRules.lua`: posições, variantes e atrasos, regra pura;
  - `tests/test_siren_spots_rules.lua`.
- Modificar:
  - `shared/NOM_Siren.lua`: toca nas posições, em vez do som chapado;
  - `shared/NOM_SirenFreeze.lua`: virar pro jogador mais próximo;
  - `server/NOM_FogEvent.lua` e `client/NOM_FogClient.lua`: chamadas, e o `dir` sai;
  - `scripts/gen_sounds.py`: versão "longe" de cada sirene;
  - `media/scripts/NOM_sounds.txt`: `distanceMin`/`distanceMax` das sirenes;
  - os testes de sirene, congelamento, evento e cliente;
  - `docs/architecture/pz-api-notes.md`.

**Comportamento:**
- **Posições (por jogador, local no cliente; no solo, o mesmo processo):** na hora da sirene, a partir da posição do jogador local:
  - **Perto:** 1 sirene a 40–80 tiles, versão perto.
  - **Longe:** 2 sirenes a 80–200 tiles, versão longe.
  - **Ângulos:** sorteados, com pelo menos 60° entre elas, pra virem de lados diferentes.
  - **Variante:** sorteada sem repetir entre as três, quando houver mais de uma na lista do tipo de névoa.
  - **Entradas desencontradas:** a mais perto em 0 s e as outras com atraso de 0,4 a 2,5 s, em coro desencontrado.
  - O sorteio é aleatório local (`ZombRand` ou o rand do mod); não precisa ser igual entre jogadores.
- **Tocar:**
  - `getWorld():getFreeEmitter(x, y, z):playSoundImpl(nome, nil)`, só local (evidência em `.superpowers/sound/api-aparelhos.md` e a mesma técnica da Tarefa 6);
  - os emissores ficam parados no mundo enquanto o jogador anda;
  - parar todas (`stopSoundLocal(id)`) no `sirenStop` ou no cancelamento;
  - a sirene termina sozinha, porque o arquivo tem 15 s.
- **Audibilidade a 200 tiles:**
  - declare as sirenes com `distanceMin` e `distanceMax` largos (sirene é fonte alta: comece com `distanceMin` 20 e `distanceMax` 220) e a versão "longe" com a distância embutida (passa-baixa e reverb, gerada no `gen_sounds.py`);
  - se a pesquisa ou o bytecode mostrar que o jogo corta som 3D além de um raio fixo, aproxime o emissor na MESMA direção até o limite, e deixe a distância embutida no arquivo fazer o resto.
  - Registre a decisão e a evidência.
- **Sons:**
  - por enquanto, a lista de cada tipo de névoa tem as sirenes que já existem (`NOM_Siren`, `NOM_SirenRed`) mais as versões `...Far`;
  - a Tarefa 3 troca e amplia a lista quando o Johan escolher as sirenes novas;
  - deixe um ponto único (`R.SOUNDS[kind] = { near = {...}, far = {...} }`).
- **Congelamento:**
  - em vez de `dirDeg`, cada zumbi congelado vira pro jogador vivo mais próximo dele, e o giro é atualizado no lote de cada tick, pra acompanhar o jogador andando;
  - no solo, os jogadores locais;
  - no MP, quem simula é o cliente dono, que olha os jogadores que conhece (busque a evidência de como listar jogadores no cliente, ex.: `getOnlinePlayers()`, no Lua vanilla);
  - sem jogador por perto, ele fica como está.
  - `NOM_FogEventRules.sirenDir`, `s.sirenDir` e o `dir` do comando saem, se nada mais usar.

- [ ] **Passo 1: testes que falham.**
  - **Regra pura:**
    - 3 posições, 1 entre 40 e 80 e 2 entre 80 e 200;
    - ângulos com pelo menos 60° entre si;
    - atrasos na faixa;
    - variantes sem repetir;
    - perto usa `near` e longe usa `far`.
  - **Tocar:** a sirene toca 3 emissores nas posições e `sirenStop` para todos.
  - **Congelamento:**
    - o zumbi congelado olha pro jogador mais próximo;
    - com dois jogadores, cada zumbi olha pro dele;
    - o jogador se mexe e o giro acompanha.
  - Os testes antigos de `dir` saem ou mudam.
- [ ] **Passo 2:** rodar `luajit tests/run.lua`. Esperado: FAIL.
- [ ] **Passo 3:** implementar.
  - Gerar as versões "longe" (`NOM_SirenFar`, `NOM_SirenRedFar`) no `gen_sounds.py` com uma função `far(sinal)` reutilizável.
  - Gerar os sons e commitar os `.ogg`.
- [ ] **Passo 4:** rodar `./run-tests.sh`. Esperado: verde.
- [ ] **Passo 5: commit.** `git commit -m "Sirenes posicionais: 3 por jogador, uma perto e duas longe; zumbis congelados olham pro jogador"`

### Correção: a sirene não congelava ninguém no solo (`isRemoteZombie`)

**Visto no jogo (solo, `-debug`, 2026-10-06):** `[NOM] sirene congelados=0 ... lista=104 pulados morto/remoto/jogo=0/20/0`. O lote inteiro foi pulado como cópia remota.

**Causa (bytecode, [pz-api-notes §24](../../architecture/pz-api-notes.md)):** `isRemoteZombie()` é `authOwner == nil` no `NetworkZombieComponent`, e no solo ninguém chama `setOwner`: dá `true` pra todo zumbi. O teste de dono certo é `isLocal()` (`(not isClient() and not isServer()) or not isRemote()`): `true` no solo, e no cliente de MP o mesmo de antes. Não era só a sirene: no solo a IA das variantes (`NOM_VariantAI`), a reaplicação da velocidade re-rolada (`NOM_NightStats`) e a soltura da Carpideira depois do grito também não rodavam. Os fakes dos testes devolviam `remote = false` no solo, por isso nada pegou.

**Correção:**
- todo `z:isRemoteZombie()` do mod virou `not z:isLocal()` (`NOM_SirenFreeze`, `NOM_VariantAI`, `NOM_NightStats`, `NOM_Carpideira`, `client/NOM_FogClient.lua`, `client/NOM_Debug.lua`);
- os fakes de zumbi (`tests/fog_world.lua`, `test_variant_ai`, `test_night_stats`, `test_variant_look`, `test_variants`, `test_debug`) perderam o `isRemoteZombie` e ganharam `isLocal` com a fórmula do jogo; `remote = true` agora só faz sentido em cliente de MP, e os testes de cópia remota passaram a rodar como cliente;
- lint `api_no_is_remote_zombie` (`tests/test_kahlua_compat.lua`) falha se `isRemoteZombie` voltar em `mod/` ou `mod2/`;
- regressão: `siren_freeze_solo_freezes_all` (`tests/test_siren_freeze.lua`); com o fake fiel e o código antigo, ele, os outros testes solo do congelamento, `fog_event_solo_siren_freezes` e `night_and_fog_together` (Estalador no solo) ficavam vermelhos.

**Falta no jogo:** a sirene congela no solo (log `congelados=N`, `pulados remoto=0`); Estalador cega e Carpideira para no solo.

---

### Correções do review final

Code review do fim da entrega (2026-10-06). Todas com TDD: o teste novo ficou vermelho no código
antigo pelo motivo certo antes da correção.

1. **Margem do save dependia do FPS** (importante; `client/NOM_FogOverlays.lua`). O corte de 38
   tiles rodava só no `prune`, a cada 10 ticks, e o tick é por quadro: a conta "38 + ~5 < 48" supunha
   60 FPS. A 30 FPS e ~30 tiles/s o anexo visto a 38 chegava aos 48 com o chunk saindo do mapa e ia
   pro save (ADR-017).
   - **Desenho:** no `OnTick`, o deslocamento desde o último corte; passou de `MOVE_TILES` (2),
     o corte de `MAX_RADIUS + SLACK` (38) roda na hora, sem lote. O lote de 80 continua só pra
     quem sai do raio da tela.
   - **Conta nova, sem FPS:** entre cortes nada passa de 38 + 2; no tick do corte o chunk pode sair
     antes do `OnTick`, com o passo daquele tick a mais. Carro a 2 tiles por tick (~30 tiles/s a
     15 FPS): 38 + 2 + 2 + 1 (square inteiro) = 43 < 48. Aguenta até ~6 tiles num tick.
   - **Salto (item 7 do review) saiu:** `JUMP_TILES` 8 disparava com um engasgo de FPS no carro
     (tirava tudo e revestia). O teleporte cai no mesmo corte.
   - Testes: `overlays_fast_car_low_fps_never_past_hard` (1, 2 e 2,24 tiles por tick por 90 ticks:
     anexo mais longe 38,6–39,5), `overlays_fps_hitch_not_jump`, `overlays_teleport_strips_now`;
     `overlays_leaving_radius_strips` com o limite novo. Docs: pz-api-notes §16.6, ADR-017
     (decisão 3), cabeçalho do arquivo, GDD `atmosphere`.
2. **Vinheta com o mod2 não subia na fuga** (`client/NOM_FogVignette.lua`, `client/NOM_ScreenFx.lua`).
   O canal do shader seguia o fade do `NOM_ScreenFx` (`on`). Agora há um segundo fade (`S.seen`) que
   segue `visible()`/`visibleRed()`, lido só pelo canal (`S.sampleSeen`); as camadas do Outro Mundo
   da tela seguem esperando a névoa. Teste `vignette_channel_rises_with_siren`.
3. **`setRed` do debug no meio da fuga não avisava os clientes de MP** (`server/NOM_FogEvent.lua`).
   Comando leve novo `sirenColor { red }`: o cliente troca a cor do presságio e da subida que já
   correm (`NOM_FogState.recolor`), sem tocar a sirene de novo nem recomeçar nada. No solo, direto.
   Vale também no presságio (antes a cor do presságio ficava velha, no solo e no MP). Testes
   `fog_event_set_red_mid_siren_tells_clients`, `fog_event_set_red_mid_presage_solo_recolors`,
   `fog_client_siren_color_recolors`.
4. **`setRed(true)` sem nada aberto pulava o presságio**: passa pelo `presage()`, como o `force`.
   Teste `fog_event_set_red_starts_red_event` (ajustado).
5. **Zumbi useless preso no MP quando a posse chega logo depois do fim da fuga**
   (`shared/NOM_SirenFreeze.lua`). Por `SWEEP_MS` (10 s reais) depois do stop, o tick segue em
   rodízio (`BATCH` por tick) soltando zumbi local useless, menos a Carpideira parada, o Estalador
   que este processo cegou (`NOM_VariantAI.blinded`, exposta só pra leitura) e o useless do jogo. A
   passada do próprio stop ganhou o mesmo filtro. Testes `siren_freeze_sweeps_late_inherited_useless`,
   `siren_freeze_sweep_in_batches`, `siren_freeze_stop_keeps_blinded_estalador`.
6. **Sirenes atrasadas tocavam com o jogo pausado** (`shared/NOM_Siren.lua`). O atraso conta como a
   fuga (`NOM_FogEventRules.countdown`): para com `isGamePaused()` e desconta no máximo 1 s por tick
   (o `OnTick` some no dedicado vazio). Teste `siren_delayed_wait_while_paused`.
7. Junto com o 1.
8. **Evidências:** `z:isMoving()` na pz-api-notes §21 (`IsoGameCharacter.isMoving()Z`, `javap`); a
   referência ao `ISCoordConversion.lua:19-24` diz a pasta `media/lua/server/` (§16.6 e cabeçalho
   do `NOM_FogOverlays`).

Commits: `8ced58b` (1 e 7), `8ffc5cb` (2), `ca01ca8` (3 e 4), `5433832` (5), `fcc3f55` (6),
`43f309c` (8). `./run-tests.sh` verde: 906 testes Lua, 5 de contraste, 29 de build, mod3.

---

### Tarefa 4: documentação da sprint (por último, depois das Tarefas 5, 6 e 7)

- `README.md` da sprint, com o roteiro de teste;
- GDD (`world-states`, `atmosphere`, `Overview`);
- emenda na ADR-009 (fuga de 30 s, névoa visual na sirene);
- `HANDOFF`;
- `sprints/README`.
