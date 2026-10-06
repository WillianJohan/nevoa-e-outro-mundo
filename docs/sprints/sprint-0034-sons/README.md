# Sprint 0034 — Sons I: sirene e fuga

| Campo | Valor |
|-------|-------|
| Status | em teste |
| Branch | `sprint/0034-sons` |
| Plano | [plan.md](plan.md) |
| GDD | [world-states.md](../../gdd/world-states.md), [atmosphere.md](../../gdd/atmosphere.md), [Overview.md](../../gdd/Overview.md), [ADR-009](../../architecture/adr-009-nevoa-evento-do-mod.md) (emendas da 0034), [ADR-017](../../architecture/adr-017-outro-mundo-anexado.md) (raio pela tela, casa destruída, sem sangue no chão) |
| Spec | [modelo novo](../../superpowers/specs/2026-10-06-modelo-novo-design.md), seções 3 e 7 |
| API | [pz-api-notes §16.6](../../architecture/pz-api-notes.md#166-anexado-ao-objeto-sprint-0023) (raio pela tela, casa destruída), [§22](../../architecture/pz-api-notes.md#22-aparelhos-do-outro-mundo-sprint-0034) (aparelhos), [§23](../../architecture/pz-api-notes.md#23-sirenes-posicionais-sprint-0034) (sirenes posicionais), [§24](../../architecture/pz-api-notes.md#24-dono-do-zumbi-islocal-não-isremotezombie-sprint-0034) (`isLocal`) |

## Objetivo

A sirene vira um **coro de 5 sirenes ao longe**, vindas de lados diferentes, e a névoa começa a subir
na hora em que ela toca. Os 30 s seguintes são a **fuga**: o jogador se mexe, os zumbis ficam parados
virados pra ele e ainda não há monstro. Três segundos antes da sirene a tela ganha estática, e na
névoa TVs, rádios e carros chiam como se outro mundo tentasse falar. O Outro Mundo passa a cobrir a
tela toda, as casas por dentro ficam destruídas e pichadas, e o sangue sai do chão.

## O que entrou

- **Sirene de 11,8 s** (T1 e T3): primeiro encurtada de 45 pra 15 s, depois trocada pelos sons
  oficiais, que têm 11,8 s cada (10,6 s de sirene mais o eco da cidade e um fade).
- **Fuga de 30 s** (T2, `shared/NOM_FogEventRules.lua`, `R.GRACE_MS = 30000`): a contagem da sirene
  passou a ser a fuga e não depende mais da duração do som. Flag nova `NOM_World.rising`/`risingRed`:
  a névoa do clima (`server/NOM_ClimateLook.lua`), a vinheta e o drone sobem já na sirene. Os bichos,
  o comportamento de névoa, o Sem-rosto, o Outro Mundo e os efeitos de tela esperam o fim da fuga
  (`NOM_World.fog` continua abrindo só no `begin()`).
- **Estática na tela** (T5, `shared/NOM_ScreenFxRules.lua`, `client/NOM_ScreenFx.lua`): presságio de
  3 s antes da sirene (`R.PRESAGE_MS`), que sobe de 0,1 a 0,6 de alfa, desce a 0,14 em 4 s depois da
  sirene e fica nesse nível sutil durante a fuga e a névoa. Tem a cor da névoa (branca ou vermelha) e
  textura própria (`NOM_NevoaEstatica.png`, gerada pelo `scripts/gen_textures.py`). Desliga junto com
  os efeitos de tela nas Opções > Mods.
- **Aparelhos do Outro Mundo** (T6, `client/NOM_Devices.lua`, regras em `shared/NOM_DeviceRules.lua`):
  TV, rádio, caixa de som e rádio de carro, ligados ou não (ligado fala mais alto).
  - No presságio, todo aparelho a até 25 tiles dá um estouro curto de estática (no máximo 8 juntos),
    cortado quando a sirene chega.
  - Na fuga, nada.
  - Na névoa aberta, a cada 90 a 180 s reais o aparelho mais perto entre 6 e 18 tiles toca um evento;
    o Sem-rosto a até 10 tiles de um aparelho o faz chiar; o grito da Carpideira faz o aparelho
    "respirar" na vermelha.
  - Sons próprios: `NOM_DevTv`, `NOM_DevRadio`, `NOM_DevSpeaker`, `NOM_DevCar`, `NOM_DevBurst` e as
    versões vermelha e preta da TV e do rádio (a preta só toca na 0038). Desliga com `FogAmbience`.
- **Coro de 5 sirenes posicionais** (T3 e T7, `shared/NOM_Siren.lua`, `shared/NOM_SirenSpotsRules.lua`):
  - cada jogador ouve 5 sirenes sorteadas no próprio jogo, a 150–500 tiles, com pelo menos 40° entre
    vizinhas;
  - a primeira entra na hora e as outras desencontradas até 4 s depois, sem repetir som no coro;
  - cada uma com afinação sorteada entre 0,95 e 1,05;
  - os emitters ficam parados no mundo enquanto o jogador anda.
- **31 sons de sirene** (`scripts/gen_sounds.py` e `scripts/sirenes/v1.py`–`v9.py`): 9 brancas
  (`NOM_SirenWhite1`–`9`), 9 vermelhas (`NOM_SirenRed1`–`9`) e 13 pretas (`NOM_SirenBlack1`–`13`, que só
  tocam na 0038). Declaradas com `distanceMin` 50 e `distanceMax` 500. Saíram `NOM_Siren`,
  `NOM_SirenRed`, `NOM_SirenFar` e `NOM_SirenRedFar`.
- **Zumbis congelados viram pro jogador** (`shared/NOM_SirenFreeze.lua`): no lugar da direção única da
  0033, cada zumbi olha pro jogador vivo mais perto dele (até 100 tiles), refeito a cada passada do
  lote, então acompanha o jogador andando. O congelamento também para quem já estava andando
  (o `useless` sozinho não parava).
- **Correção do solo: dono do zumbi é `isLocal()`** (pz-api-notes §24): no solo, `isRemoteZombie()` dá
  `true` pra todo zumbi, e a sirene não congelava ninguém. A troca em todo o mod também destravou, no
  solo, a IA das variantes (Estalador cego, Carpideira parada), a velocidade re-rolada da noite e a
  soltura da Carpideira depois do grito. Lint novo `api_no_is_remote_zombie`.
- **Outro Mundo na tela toda** (`NOM_DressingRules.radius`, `client/NOM_FogOverlays.lua`): o raio
  segue o canto da tela mais longe, entre 15 e 30 tiles, relido a cada atualização; além de 38 tiles
  sai na hora, a cada 2 tiles andados (review final: a margem do save não depende do FPS), e o
  salto que limpava tudo saiu.
- **Casa destruída** (`NOM_DressingRules`): parede de dentro com até 3 camadas (rachadura, sujeira,
  sangue e escrita por cima) e pichações e mensagens vanilla inteiras, montadas em trechos de várias
  paredes (mensagem mais comum dentro, pichação mais comum fora).
- **Sem sangue no chão**: saíram poças, rastros e respingo; o sangue fica só na parede. Na densidade 1
  o chão vestido cai de ~82% pra ~66% (vermelha: ~93% pra ~83%).
- **Textos:** o tooltip do `FogDailyChance` e a descrição do mod (`Mod.json`), em PTBR e EN, e a ajuda
  do console falam de sirenes ao longe e dos 30 s.

## Decisões do Johan (2026-10-06)

- **Sirene curta:** "45 segundos é tempo demais, o jogador vai ficar surdo". Primeiro 15 s, depois os
  sons oficiais de 10 a 12 s com fim natural (11,8 s cada).
- **Fuga de 30 s, fixa e sem sandbox:** "quando a sirene toca, já começa a névoa, não precisa esperar
  segundos... o tempo de 30/45 segundos é o tempo pro jogador se movimentar antes dos bichos
  começarem".
- **Na sirene já vêm** a névoa visual subindo, a escuridão e os sons de ambiente. **No fim da fuga
  vêm** os zumbis soltos, os monstros, o comportamento de névoa, o Sem-rosto e o Outro Mundo.
- **Sirenes:** a primeira escolha da branca foi a `branca_engolida` (a névoa engole o som); depois os
  23 protótipos aprovados viraram oficiais (22 sons, porque um se repetia), com eco de cidade embutido
  no arquivo, e as 9 da V9, feitas pro coro, também: 31 sons.
- **Coro posicional:** "se a gente tiver múltiplas sirenes no mapa, o som não é mais 2D chapado, ele
  vem de alguma posição". Primeiro 3 (uma perto, duas longe); depois 5, todas a 150–500 tiles: "não
  quero que fique gritando no ouvido do jogador". Cada uma com afinação levemente diferente.
- **Zumbis congelados** viram pro jogador mais próximo.
- **Estática na tela** 3 s antes da sirene, sutil no começo e com destaque no fim, na cor da névoa, e
  sutil durante a névoa toda. Os níveis do plano (0,22 de pico e 0,05 sutil) sumiram no teste do Johan
  e subiram pra 0,6 e 0,14.
- **Aparelhos:** "onde tem rádio, caixa de som, até carro, dá pra colocar sons de estática... coisas
  que venham de outro mundo tentando se comunicar". Qualquer aparelho fala, ligado ou não; o ligado
  tem prioridade e fala mais alto.
- **Outro Mundo:** o limite de 15 tiles aparecia com o zoom longe, e o raio passou a seguir a tela. As
  casas por dentro: "apagadas, acabadas, sujas, pichadas".
- **Sangue no chão removido:** as poças e rastros pareciam "jogo dos anos 2000 com textura ruim". O
  sangue de parede fica.
- **Fila nova depois desta sprint:** a 0035 passa a ser o Outro Mundo estilo Silent Hill e a 0036, o
  equilíbrio (visão de ~4 tiles e perambular) ([spec §10](../../superpowers/specs/2026-10-06-modelo-novo-design.md#10-fila-de-sprints)).

## Critérios de aceite

- [ ] A estática aparece 3 s antes da sirene, cresce e fica sutil na névoa, na cor dela — roteiro, passo 1
- [ ] Na sirene tocam 5 sirenes ao longe, de lados diferentes e desencontradas — roteiro, passo 2
- [ ] A névoa visual sobe durante a fuga e os bichos só aparecem 30 s depois da sirene — roteiro, passo 3
- [ ] No solo todo zumbi congela, virado pro jogador e acompanhando quando ele anda — roteiro, passo 4
- [ ] Estalador cega e Carpideira para no solo — roteiro, passo 5
- [ ] TV, rádio e carro chiam no presságio e falam na névoa — roteiro, passo 7
- [ ] O Outro Mundo chega nas bordas da tela no zoom longe, sem derrubar o FPS — roteiro, passo 8
- [ ] As casas por dentro aparecem destruídas e as pichações se leem — roteiro, passo 9
- [ ] O chão sem sangue não ficou vazio demais — roteiro, passo 9
- [x] Regras puras, servidor, cliente, sons e lints — testes verdes (`./run-tests.sh`: 897 testes Lua,
  5 de contraste, 29 de build, os do mod3 em Python e Java); **não** confirma nada no jogo

Marcar cada item sem evidência não vale: ao marcar, escrever como foi confirmado.

## Roteiro de teste no jogo

Solo, com `-debug`, jogo reiniciado depois do `scripts/dev-sync.sh`. Acompanhe o console com:

```bash
tail -F ~/.var/app/com.valvesoftware.Steam/Zomboid/console.txt | grep "\[NOM\]"
```

`NOM.help()` lista os comandos. `NOM.godMode(true)` ajuda a testar sem morrer.

1. **Presságio e estática.** Com uns 10 zumbis por perto (`NOM.spawn(10)`), digite `NOM.setFog()`.
   - Conferir: a tela ganha chiado na cor da névoa, fraco no começo e forte no fim, por 3 s.
   - Log: `[NOM] nevoa presagio vermelha=false ...` e, no primeiro quadro desenhado,
     `[NOM] tela: estatica desenhada alfa=0.10` (com a intensidade dos efeitos de tela em 1).
   - Depois da sirene, o chiado desce em ~4 s e fica sutil a névoa toda. Repetir com `NOM.setRedFog()`:
     o chiado fica vermelho.
2. **Coro de sirenes.** Logo depois do presságio:
   - Log: `[NOM] nevoa sirene contagem=30000 vermelha=false dias=... chance=...` e cinco linhas
     `[NOM] sirene tocando som=NOM_SirenWhiteN x=... y=... tom=0.9xx a 1.0xx id=...`, a primeira na hora e
     as outras em até 4 s, com sons diferentes. Cada `setPitch` também solta uma linha
     `Set pitch for ToStart/Instance` do próprio jogo.
   - Ouvir: cinco sirenes longe, de lados diferentes, desencontradas, nenhuma gritando no ouvido. Gire a
     câmera e ande um pouco: elas ficam paradas no mundo. Cada uma dura ~12 s.
3. **Fuga de 30 s.** Desde a sirene, a névoa do clima sobe aos poucos, as bordas da tela escurecem
   (vinheta do modo de busca) e o drone entra. Nenhum monstro, nenhum Outro Mundo e nenhum grão de
   filme até o fim da fuga. As sirenes acabam em ~12 s; os 18 s restantes são só a névoa subindo.
   - Aos 30 s: `[NOM] nevoa evento inicio periodo=N fim=... vermelha=false`. A névoa fica pelo meio
     nessa hora e completa logo depois; os efeitos de tela e o Outro Mundo entram.
4. **Todos congelados, virados pra você.** Durante a fuga, a cada 3 s:
   `[NOM] sirene congelados=N andando=0 jogadores=1 lista=L pulados morto/remoto/jogo=0/0/0 modo=...`.
   - No solo, `remoto` tem que ser **0** (era 20 antes da correção), `congelados` perto de `lista` e
     `andando` perto de 0.
   - Todo zumbi à vista para em pé, olha pra você e ignora você, mesmo apanhando. Ande em volta: eles
     viram junto. Comece a sirene com um zumbi te perseguindo: ele tem que parar.
   - No fim da fuga todos voltam juntos.
5. **IA das variantes no solo.** Com névoa aberta (`NOM.setFog(true)`), `NOM.turnZombie(1)` (Estalador)
   e `NOM.turnZombie(4)` (Carpideira). O Estalador não te vê a mais de alguns tiles se você ficar quieto;
   a Carpideira fica parada soluçando até ser acordada e, depois do grito, caça.
6. **Cancelar e recarregar.**
   - `NOM.setEndFog()` durante o presságio ou a fuga: as sirenes param, a névoa desce, a estática some
     em ~3 s e os zumbis soltam na hora.
   - Salvar e carregar com a fuga correndo: a sirene toca de novo (coro novo) e os 30 s recomeçam.
   - Salvar e carregar durante o presságio: ele só vive na memória; o esperado é o presságio
     recomeçar no minuto de jogo seguinte. Anote se isso acontece.
7. **Aparelhos.** Perto de uma casa com TV ou rádio, ou de um carro com rádio:
   - no presságio, os aparelhos a até 25 tiles dão um estouro curto de estática, cortado pela sirene;
   - na fuga, silêncio;
   - com a névoa aberta, fique entre 6 e 18 tiles de um aparelho e espere 90 a 180 s: ele chia ou
     "fala". Afaste-se pra mais de 20 tiles e o som para. Ligado fala mais alto que desligado;
   - um Sem-rosto perto do aparelho faz o aparelho chiar junto.
8. **Outro Mundo na tela toda.** Com névoa aberta, afaste o zoom ao máximo: rachadura, sujeira, mato e
   chão queimado chegam nas bordas da tela. Anote o FPS com zoom perto e longe. De carro rápido, veja se
   a borda que entra enche a tempo. Dormir ou sair com o zoom longe e voltar: nada sobrando
   (`[NOM] outro mundo: N alvos limpos pro save`).
9. **Casa destruída e chão sem sangue.** Entre numa casa na névoa: paredes com várias camadas
   (rachadura, sujeira, sangue) e pichações ou mensagens inteiras, como "KEEP OUT" e "ALIVE INSIDE",
   espalhadas por várias paredes seguidas. No chão, nenhuma poça nem rastro de sangue. Dizer se o chão
   ficou vazio demais e se as pichações se leem sob a névoa.

## UNKNOWNs que só o jogo responde

- **Audibilidade a 500 tiles:** a sirene mais longe sai a ~−20 dB; ainda se ouve sobre o drone e a
  chuva? O coro de 5 incomoda? (pz-api-notes §23)
- **Direção:** o pan do FMOD dá direção clara com o emitter a 150–500 tiles, fora da célula carregada?
- **Afinação:** 0,95 a 1,05 soa como aparelhos diferentes, sem parecer desafinado nem "fita acelerada"?
  O `tom=` de cada sirene sai no console.
- **Canais cortados:** o FMOD não corta canal baixo com 5 sirenes, drone e aparelhos juntos, na cidade?
- **FPS da erosão em tela toda:** ~2800 squares com anexo no zoom mais longe (pz-api-notes §16.6).
- **Legibilidade das pichações** sob a névoa e a luz do Outro Mundo.
- **Nível da estática:** 0,6 de pico e 0,14 sutil já subiram uma vez; ainda está fraco ou forte demais?
- **Chão sem sangue:** com ~66% do chão vestido (antes ~82%), o Outro Mundo não ficou vazio demais?
- **Aparelhos:** quantos a lista do jogo traz numa cidade; atenuação real com `distanceMin` 2 e
  `distanceMax` 18 e oclusão atrás de parede (pz-api-notes §22).
- **Zumbi parado:** se o `useless` mantém o `faceLocationF` entre as passadas do lote (herdado da 0033).
- **MP:** quem entra no meio da fuga recebe a sirene e a subida; o `getOnlinePlayers()` do cliente traz a
  posição dos jogadores longe dele.

## Ajustes fáceis

| Onde | Constante | Efeito |
|---|---|---|
| `NOM_FogEventRules` | `GRACE_MS`, `PRESAGE_MS` | fuga (30 s) e presságio (3 s) |
| `NOM_SirenSpotsRules` | `COUNT`, `DIST_MIN`/`DIST_MAX`, `MIN_GAP_DEG`, `DELAY_MAX_MS`, `PITCH_MIN`/`PITCH_MAX` | tamanho do coro, distância, espalhamento, desencontro e afinação |
| `media/scripts/NOM_sounds.txt` | `distanceMin`/`distanceMax` das sirenes (50/500) | queda do volume com a distância |
| `NOM_ScreenFxRules` | `STATIC_START`, `STATIC_PEAK`, `STATIC_SUBTLE`, `STATIC_SETTLE_MS`, `STATIC_FADE_MS` | estática da tela |
| `NOM_DeviceRules` | `OMEN_RANGE`, `CALL_NEAR`/`CALL_FAR`, `CALL_MIN_MS`/`CALL_MAX_MS`, `TV_CHANCE`, `OFF_VOLUME` | aparelhos |
| `NOM_SirenFreeze` | `BATCH`, `RANGE`, `SAFETY_MS` | zumbis por tick, alcance do "olhar pro jogador" e rede de segurança |
| `NOM_DressingRules` | `MIN_RADIUS`/`MAX_RADIUS`, `WALL_LAYERS`, `RUN` | raio do Outro Mundo, camadas da parede de dentro e chance de pichação e mensagem |

## Decisões técnicas

- **Fuga separada do som.** A contagem é `GRACE_MS` e o som tem a duração que tiver: trocar a sirene
  não mexe na regra de jogo.
- **Subida sem mexer na regra.** `rising` é uma flag à parte; tudo o que é regra (variantes, stats,
  Sem-rosto, Carpideira, Outro Mundo) continua lendo `fog`.
- **Sirene local, sem rede.** Cada jogo sorteia as próprias posições (`getFreeEmitter` +
  `playSoundImpl(nome, false, nil)`, sem pacote). O `(nome, nil)` cai no overload do `IsoGridSquare` e
  dá NPE (pz-api-notes §22).
- **O jogo não corta som 3D por distância** (bytecode, §23): o emitter fica na posição sorteada, sem
  aproximar, e a distância que o FMOD não faz vem embutida no arquivo (passa-baixa, reflexões, reverb).
- **Afinação em tempo de execução** (`setPitch`) em vez de variantes declaradas (seriam 5 × 31 sons).

## Aprendizados

- `isRemoteZombie()` não quer dizer "outro cliente é dono": é "não tem dono de rede", e no solo
  ninguém tem. O teste certo de dono é `isLocal()`. Fake de teste que devolvia `remote = false` no solo
  escondeu isso por várias sprints.
- O `useless` não para zumbi que já está andando: o `PathFindState` não lê a flag. É preciso cancelar o
  caminho como o próprio jogo faz quando o zumbi chega.
- `setPitch(id, fator)` afina **todo** som do emitter, não só o do id. Funciona porque o emitter do
  pool vem vazio e a sirene é o único som nele.
- Estática com alfa baixo some sobre a névoa clara: a textura já tem alfa médio ~0,43.

## Limitações conhecidas

- O rádio instalado num carro durante a sessão pode só entrar na lista do jogo quando o carro voltar
  ao mundo (pz-api-notes §22).
- O grito do Corredor não chega ao cliente pelo Lua: só o da Carpideira faz o aparelho respirar.
- O Outro Mundo continua só no andar do jogador e só pro jogador 0 na tela dividida.

## Pendências que a próxima sprint herda

- Os UNKNOWNs acima, principalmente audibilidade, FPS da erosão e nível da estática.
- As sirenes pretas e os sons pretos dos aparelhos já estão gerados; só tocam na 0038.
- O resto dos "sons" da spec (gritos dos monstros, gritos de gente, crepitar) não entrou aqui.
- A 0035 (Outro Mundo estilo Silent Hill) pega o Outro Mundo desta sprint como base: sem sangue no
  chão, casa destruída e raio pela tela.

## Sessões

- 2026-10-06 — Cursor, execução das tarefas 1 a 7, da correção do `isLocal`, do Outro Mundo (raio pela
  tela, casa destruída, sem sangue no chão) e desta documentação (subagentes).
