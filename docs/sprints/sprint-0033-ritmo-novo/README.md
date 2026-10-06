# Sprint 0033 — Ritmo novo

| Campo | Valor |
|-------|-------|
| Status | em teste |
| Branch | `sprint/0033-ritmo-novo` |
| Plano | [plan.md](plan.md) |
| GDD | [world-states.md](../../gdd/world-states.md), [sandbox.md](../../gdd/sandbox.md), [ADR-009](../../architecture/adr-009-nevoa-evento-do-mod.md) (emenda da 0033) |
| Spec | [modelo novo](../../superpowers/specs/2026-10-06-modelo-novo-design.md), seções 1 a 4 |
| API | [pz-api-notes §21](../../architecture/pz-api-notes.md#21-sirene-que-congela-sprint-0033) |

## Objetivo

A névoa vira quase diária e ganha ritmo: o servidor sorteia o dia, cada tipo dura o seu tempo, a sirene
toca 45 s e **congela todos os zumbis virados pra mesma direção**, e depois de cada névoa vêm 2 h de
calmaria. Junto vêm os comandos de debug novos pra testar tudo isso sem esperar o relógio, e um foco de
vento aleatório no mod3.

## O que mudou

- **Agenda por dia** (`shared/NOM_FogEventRules.lua`, T1):
  - à meia-noite de jogo o dia é sorteado pelo número do dia e pela semente do mundo, então salvar e
    carregar não muda nada;
  - chance de 65%, subindo em linha reta até 85% no dia 60 (`FogEscalation`);
  - segunda névoa no mesmo dia: 15%, só depois de 6 h sem névoa e começando antes da meia-noite;
  - garantia: 2 dias seguidos sem névoa e o terceiro tem com certeza;
  - saves antigos: a sirene que já estava agendada (`data.fog.next`) vale como a névoa do dia;
  - vermelha: 20%, a partir do dia 7, e **sem** a subida até o dobro da 0019 (a curva agora é só da
    chance do dia);
  - duração por tipo: branca 3–5 h, vermelha 4–6 h.
- **Sandbox** (T2): `FogDailyChance`, `FogMaxDailyChance`, `FogEscalationDays`, `FogSecondChance`,
  `FogMinGapHours`, `FogMaxDaysWithout`, `RedFogMinHours`, `RedFogMaxHours` e `FogCalmHours`.
  `FogEventEveryDays` saiu. `FogMaxHours` passou de 6 pra 5 e `RedFogChance` de 10 pra 20.
- **Servidor** (T3, `server/NOM_FogEvent.lua`):
  - sirene de **45 s reais** (era 30);
  - cada névoa sorteia uma **direção** de onde a sirene "vem" (`R.sirenDir`, igual em toda máquina), e o
    comando `siren` leva `dir`;
  - cancelar a sirene (`sirenStop`) limpa também a cor que ela tinha decidido (`R.cancel` zera `red`);
  - a **calmaria** é uma flag nova do mundo (`NOM_World.calm`), ligada quando a névoa acaba.
- **Calmaria no zumbi comum** (T4, `NOM_NightRules` / `NOM_NightStats`): por `FogCalmHours` (2 h de jogo),
  um degrau a menos de velocidade, visão e audição. Eco e variantes não sentem. A calmaria vence a noite
  no zumbi comum, e o `tick` não dorme enquanto ela dura.
- **Congelamento na sirene** (T5, `shared/NOM_SirenFreeze.lua`):
  - todo zumbi que o processo simula fica parado e virado pra direção da sirene (`setUseless`,
    `setTarget(nil)`, `faceLocationF`), e ignora o jogador, mesmo se apanhar;
  - no solo é o próprio processo; no MP, o cliente dono (comandos `siren`, `fog`, `sirenStop`);
  - a névoa começando solta todos de uma vez. Se o comando se perder, o cliente solta sozinho 15 s depois
    do fim da sirene;
  - objeto de zumbi reaproveitado que estava congelado é solto no `OnZombieCreate`; a Carpideira parada
    continua parada;
  - o `unstick` da `NOM_VariantAI` não solta quem está congelado.
- **Comandos de debug** (T7, `-debug`): `NOM.setFog`, `setRedFog`, `setBlackFog`, `setEndFog`,
  `getZombie`, `turnZombie`, `godMode` e `wind` (lista abaixo).
- **mod3** (T8): foco de vento aleatório de teste, `NOMRender_setParam(11, 1)`, em `WindSource.java`.

## Comandos de debug novos

Só com `-debug`. `NOM.help()` lista todos.

| Comando | O que faz |
|---|---|
| `NOM.setFog()` | névoa **sempre branca**: sirene de 45 s (zumbis congelam) e depois a névoa. Com névoa aberta ou sirene contando, fecha e recomeça |
| `NOM.setFog(true)` | o mesmo, sem a contagem: abre a névoa na hora |
| `NOM.setRedFog()` / `(true)` | o mesmo, **sempre vermelha** (sirene vermelha; `true` abre na hora) |
| `NOM.setBlackFog()` | só avisa que a névoa preta chega na 0038 |
| `NOM.setEndFog()` | termina a névoa aberta ou cancela a sirene (e a calmaria começa) |
| `NOM.getZombie()` | puxa o zumbi vivo mais perto, no mesmo andar, pra cima de você (no máximo 2 tiles de distância do destino) |
| `NOM.turnZombie(i)` | o zumbi mais perto vira o tipo `i`: 1 estalador, 2 corredor, 3 semrosto, 4 carpideira; 0 desfaz. Só aparece na névoa |
| `NOM.godMode(on)` | deus + invisível + zumbis não atacam, juntos; sem argumento inverte |
| `NOM.wind(on)` | foco de vento do mod3 (precisa do mod Volumétrica); sem argumento inverte |

Os antigos (`NOM.fog`, `NOM.redFog`, `NOM.night`, `NOM.time`, `NOM.spawn` etc.) continuam valendo.
`NOM.setFog` e `NOM.setRedFog` mandam um pedido só ao servidor (`NOM_FogEvent.force`), que decide a cor e
reinicia a sirene se preciso e zera a calmaria.

## Critérios de aceite

- [ ] A sirene toca por 45 s e todo zumbi à vista fica parado, virado pro mesmo lado — roteiro, passos 1 e 2
- [ ] Bater num zumbi parado não o acorda durante a sirene — roteiro, passo 2
- [ ] Quando a névoa começa, todos voltam juntos — roteiro, passo 3
- [ ] A calmaria deixa o zumbi comum visivelmente mais lento por ~2 h de jogo — roteiro, passo 5
- [ ] A vermelha dura mais que a branca — roteiro, passo 8
- [ ] O console mostra uma sirene por dia na maioria dos dias, e a garantia no terceiro — roteiro, passo 9
- [ ] O zumbi congelado **mantém a direção** do `faceLocationF` — UNKNOWN, roteiro, passo 2 (abaixo)
- [ ] O foco de vento sopra a névoa no mod3 — roteiro, passo 10
- [x] Regras puras, sandbox, servidor, calmaria, congelamento, debug e mod3 — testes verdes
  (`./run-tests.sh`: 782 testes Lua, 4 de contraste, 29 de build, os do mod3 em Python e Java);
  **não** confirma o comportamento no jogo

Marcar cada item sem evidência não vale: ao marcar, escrever como foi confirmado.

## Roteiro in-game

Com `-debug`, jogo reiniciado depois do `scripts/dev-sync.sh` (e do `scripts/build-mod3.sh` se for testar o
vento). Acompanhe o servidor com
`tail -F ~/.var/app/com.valvesoftware.Steam/Zomboid/console.txt | grep "\[NOM\]"`.

1. **Sirene e direção.** Fique perto de uns 10 zumbis (`NOM.spawn(10)` ajuda) e digite `NOM.setFog()`.
   Conferir: a sirene toca por 45 s e o console mostra `[NOM] nevoa sirene contagem=45000 vermelha=false`
   com `dir=` em graus no fim da linha.
2. **Todos parados, virados pro mesmo lado.** Durante a sirene, todo zumbi à vista para em pé e olha pra
   uma direção só, e ignora você. Bata num deles: ele não pode reagir.
   - **UNKNOWN a conferir** (pz-api-notes §21): o zumbi `useless` parado mantém a direção do
     `faceLocationF` entre as passadas do módulo (lote de 20 por tick), ou volta a girar sozinho no idle?
     Olhe com atenção os zumbis parados por uns 20 s: se um ficar rodando ou olhando pra outro lado, anote
     quantos e por quanto tempo. Isso decide se a 0034 precisa refazer a direção a cada quadro.
3. **A volta.** Quando a névoa começa (contagem zerada, `[NOM] nevoa evento inicio periodo=N …`), todos
   voltam ao normal juntos, de uma vez, sem ninguém ficar travado.
4. **Sirene recomeçada.** Repetir `NOM.setFog()` com a sirene contando: ela recomeça (sirene cancelada e
   nova), com a **mesma direção** (ela é pura da semente e do número da névoa que a sirene anuncia; o
   console mostra `dir=`). A direção só muda de uma névoa pra outra. `NOM.setEndFog()` durante a sirene
   cancela e solta todo mundo na hora.
5. **Calmaria.** Com a névoa aberta, `NOM.setEndFog()`. Os zumbis comuns passam a andar visivelmente mais
   devagar, com visão e audição menores, por ~2 h de jogo (`NOM.time(h)` anda o relógio). Variantes e Ecos
   não mudam. Depois das 2 h tudo volta (ou vai pros valores da noite).
6. **Calmaria some com névoa nova.** Dentro da calmaria, `NOM.setFog(true)`: a névoa abre e a calmaria
   termina na hora (zumbi volta à velocidade normal).
7. **Branca e vermelha de verdade.** `NOM.setFog(true)` sempre dá branca, mesmo depois do dia 7.
   `NOM.setRedFog(true)` sempre dá vermelha (sirene vermelha com `NOM.setRedFog()`). Com névoa aberta, o
   comando recomeça na cor pedida.
8. **Duração por tipo.** Em cada abertura o console mostra `fim=` e `vermelha=`. A vermelha dura de 4 a
   6 h e a branca de 3 a 5 h de jogo.
9. **Agenda por dia.** Sem forçar nada, deixe os dias passarem (`NOM.time(h)` ajuda) e leia as linhas
   `[NOM] nevoa proxima=`. Esperado: uma sirene por dia na maioria dos dias, uma segunda de vez em quando
   (depois de uma folga de pelo menos 6 h) e nunca 3 dias seguidos sem névoa.
10. **Ferramentas do teste.**
    - `NOM.getZombie()`: o zumbi vivo mais perto aparece em cima de você.
    - Com névoa aberta (`NOM.setFog(true)`), `NOM.turnZombie(1)` a `(4)` transformam o mais perto em
      Estalador, Corredor, Sem-rosto e Carpideira; `NOM.turnZombie(0)` desfaz. Sem névoa o comando avisa.
    - `NOM.godMode(true)`: invulnerável, invisível e zumbis não atacam; `NOM.godMode(false)` desliga.
    - `NOM.setBlackFog()`: só diz que a preta chega na 0038.
11. **Vento no mod3.** Com o mod Volumétrica e névoa aberta, `NOM.wind(true)`: um foco a 15–30 tiles
    sopra a névoa numa direção aleatória (2,5 tiles/s, raio 4); `NOM.wind(false)` apaga; `NOM.wind(true)`
    de novo sorteia outro. Sem o mod3 o comando só avisa. Log: `[NOM-Render] vento: foco em …`.
12. **Salvar e carregar.** Com a sirene contando, salvar e carregar: a sirene toca de novo e os 45 s
    recomeçam, com a mesma direção. Com a névoa aberta, a névoa e o mesmo período voltam.

## Ajustes fáceis

| Onde | Constante | Efeito |
|---|---|---|
| Sandbox | `FogDailyChance`, `FogMaxDailyChance`, `FogEscalationDays` | chance do dia e a subida |
| Sandbox | `FogSecondChance`, `FogMinGapHours`, `FogMaxDaysWithout` | segunda névoa, folga e garantia |
| Sandbox | `FogMinHours`/`FogMaxHours`, `RedFogMinHours`/`RedFogMaxHours` | duração branca e vermelha |
| Sandbox | `FogCalmHours` | calmaria |
| `NOM_FogEventRules` | `SIREN_MS` | tempo da sirene |
| `NOM_SirenFreeze` | `BATCH`, `FAR`, `SAFETY_MS` | zumbis virados por tick, distância e rede de segurança |
| `WindSource.java` | `MIN_DIST`, `MAX_DIST`, `SPEED`, `RADIUS` | foco de vento de teste |

## Decisões

- **Sorteio por dia, não por intervalo.** O intervalo depois do fim da névoa deixava a frequência
  imprevisível e a curva de tensão da 0019 puxava a média pra 3 dias. O sorteio por dia dá "quase todo
  dia" com garantia, e o `bornAt` da 0019 só serve agora pra carência da vermelha e pra curva da chance.
- **A curva só mexe na chance do dia.** A vermelha não sobe mais até o dobro no dia 90: o PO já
  aprovou a chance base de 20%.
- **Congelar no dono (ADR-005).** O servidor decide e avisa a direção. Quem simula o zumbi aplica, igual à
  noite e à calmaria.
- **`debugMove` próprio no `getZombie`.** O `semRostoMove` do cliente só move se nenhum jogador vê o
  destino, e o destino do pull é o tile do próprio jogador.
- **Foco de vento fora da troca de andar.** O foco fica em coordenada de mundo no andar atual; se o
  jogador troca de andar, a grade é recriada e o foco continua valendo no andar novo. É um teste, não foi
  tratado.

## Aprendizados

- O `resetForReuse` do zumbi não limpa o `useless`: um objeto reaproveitado nasceria congelado. O
  `OnZombieCreate` do `NOM_SirenFreeze` solta.
- Cancelar a sirene precisa limpar a cor que ela já tinha decidido, senão a próxima névoa herda.
- A calmaria ligada pelo `stop()` de debug ficava ligada durante a sirene e a névoa nova até o tick do
  clima do minuto seguinte. `force` e `begin` zeram a flag na hora.
- `Flow` (mod3) importa classes do jogo e do LWJGL e não compila no teste Java puro: a lógica que se
  testa fica em classe própria (`WindSource`, como `Wind`).

## Pendências que a próxima sprint herda

- O resultado do UNKNOWN do `faceLocationF` (passo 2).
- **0034 (sons):** o Johan escolhe as sirenes na escuta (branca melhorada, vermelha bizarra com gritos,
  e uma das três ideias da preta) antes da sprint começar.
- A névoa preta (`NOM.setBlackFog` só avisa) e a sirene dela ficam pra 0038.
- O foco de vento não trata troca de andar.

## Sessões

- 2026-10-06 — Cursor, execução das tarefas 1 a 8 e desta documentação (subagentes).
