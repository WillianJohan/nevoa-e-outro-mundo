# Teste in-game — roteiro consolidado

| Campo | Valor |
|-------|-------|
| Status | `accepted` |
| Escrito em | sprint 0006 (2026-10-04) |
| Cobre | todo critério in-game das sprints [0001](sprints/sprint-0001-estado-e-clima/README.md) a [0006](sprints/sprint-0006-balanceamento-mp/README.md) |
| Duração | ~60–90 min: solo ~40, MP ~30, medições e remoção ~15 |

Uma sessão só. O save do solo anda na ordem natural (dia → anoitecer → noite →
névoa → amanhecer), então cada passo prepara o próximo. Os roteiros das sprints
continuam lá com o detalhe de cada sistema; aqui é a ordem pra rodar tudo de uma vez.
Cada item tem a caixinha, o que fazer, a linha esperada no console e o critério que
ele fecha.

**No fim, mandar de volta:** `~/Zomboid/console.txt` do solo, o do cliente de MP e o
console do servidor dedicado (`~/Zomboid/server-console.txt`), mais as respostas da
seção [Balanceamento](#balanceamento) e os números das [medições](#parte-3--medições-15-min).

## Antes de começar (~5 min)

- [ ] Mod linkado: `ln -sfn "$PWD/mod" ~/Zomboid/mods/NevoaEOutroMundo`.
- [ ] Jogo aberto com `-debug` (opção de inicialização da Steam).
- [ ] Toda linha do mod começa com `[NOM]`. No MP, o que é do servidor sai no console
      do **servidor** (noite, névoa, Eco, grito) e o que é de quem simula ou vê sai no
      do **cliente** (`stats aplicados`, `semrosto visto`).

### Atalhos de debug (console Lua do modo debug)

Só existem com `-debug` (sprint 0006). Valem no solo e no MP (no MP pedem a permissão
de debug do jogo; rodar como admin).

| Comando | Faz | Linha esperada |
|---|---|---|
| `NOM_Debug.status()` | estado do mod | `[NOM] debug local …` e `[NOM] debug servidor …` |
| `NOM_Debug.night(true)` / `(false)` / `()` | força noite / dia / devolve pro relógio | `[NOM] debug noite forcada=true`; vale no próximo minuto de jogo |
| `NOM_Debug.fog(0.8)` / `(0)` / `()` | força a intensidade de névoa lida pelo mod / devolve pro clima | `[NOM] debug nevoa forcada=0.8` |
| `NOM_Debug.variant("estalador")` | zumbi vivo mais perto vira Estalador (`"corredor"`, `"semrosto"`; `()` desfaz) | `[NOM] debug variante x=… y=… id=…` e `[NOM] debug variante id=… forcada=estalador` |
| `NOM_Debug.spawnEco()` | um Eco nos pés do jogador (só à noite) | `[NOM] debug eco spawn=true` |

A noite forçada liga tudo do mod, mas o céu continua o do relógio: pra **ver** a
noite, use Debug → Time. A névoa forçada liga a névoa do mod (flag, Sem-rosto, som,
chão, vinheta e a névoa que o mod soma no clima); a névoa vanilla continua a do clima.

- [ ] `NOM_Debug.status()` no menu principal → nada (não está em jogo). Já dentro do
      save: as duas linhas. **Se** `NOM_Debug` for `nil`: o jogo não está em `-debug`.

## Parte 1 — Solo (~40 min)

Save novo, sandbox Apocalypse, página "Névoa e Outro Mundo" com os **padrões**,
começando de dia, numa cidade (Muldraugh serve).

### 1.1 Menu e carga (5 min)

- [ ] **Sandbox:** a página "Névoa e Outro Mundo" mostra as 24 opções com rótulo e
      tooltip em PT-BR; trocar o idioma pra inglês e conferir "Clickers", "Runners",
      "Faceless". → [0001: tradução](sprints/sprint-0001-estado-e-clima/README.md#critérios-de-aceite),
      [0002 passo 1](sprints/sprint-0002-eco/README.md#roteiro-in-game),
      [0003 passo 1](sprints/sprint-0003-noite-agressiva/README.md#roteiro-in-game),
      [0004 passo 1](sprints/sprint-0004-estalador-corredor/README.md#roteiro-in-game),
      [0005 passo 1](sprints/sprint-0005-sem-rosto-e-nevoa/README.md#roteiro-in-game)
- [ ] **Carga:** nenhum `ERROR`/`WARN` com `NOM_`, `NOM_sounds` ou `clothing.xml` no
      `console.txt`. → [0001: mod ativa sem erro](sprints/sprint-0001-estado-e-clima/README.md#critérios-de-aceite)
- [ ] Primeira linha de clima: `[NOM] night=false fog=false fogI=0.00`.

### 1.2 Dia: preparar a noite (5 min)

- [ ] Debug → Spawn Horde: 20 zumbis a ~15 tiles. Anotar se correm ou arrastam (base
      do dia). Matar 5 deles e deixar os corpos (viram Ecos à noite).
- [ ] **FPS de dia com a horda:** contador de FPS do debug ligado, anotar. → medição da
      [0003 passo 10](sprints/sprint-0003-noite-agressiva/README.md#roteiro-in-game)

### 1.3 Anoitecer (5 min)

- [ ] Debug → Time: 20:30 e deixar correr. **Esperado:** `[NOM] night=true fog=false`
      no pôr do sol, depois `[NOM] noite night=true` e, em menos de um segundo,
      `[NOM] noite stats aplicados=N zumbis=M noite=true`.
      → [0001: flags na hora certa](sprints/sprint-0001-estado-e-clima/README.md#critérios-de-aceite)
- [ ] A tela escurece aos poucos, levemente dessaturada e azulada; cheia em ~20 minutos
      de jogo, sem corte. `[NOM] nightRamp=1.00 fogRamp=0.00` quando completa.
      → [0001: noite, transição](sprints/sprint-0001-estado-e-clima/README.md#critérios-de-aceite)
- [ ] Os zumbis ficam um degrau mais rápidos. → [0003 passo 2](sprints/sprint-0003-noite-agressiva/README.md#roteiro-in-game)

### 1.4 Noite: zumbis comuns e Ecos (10 min)

- [ ] **Ecos:** em até 10 minutos de jogo, `[NOM] eco spawn=5` (os corpos do 1.2).
      Ecos de camisola de hospital e véu, em cima dos corpos, arrastados; um golpe
      derruba. **Se** `[NOM] eco outfit NOM_Eco não carregou`: registrar.
      → [0002 passos 2 e 9 da 0003](sprints/sprint-0002-eco/README.md#roteiro-in-game)
- [ ] Matar um Eco: `[NOM] eco cadaveres=1` em segundos; sem corpo, sem loot.
      → [0002: Eco morto sem cadáver](sprints/sprint-0002-eco/README.md#critérios-de-aceite)
- [ ] `NOM_Debug.spawnEco()` → `[NOM] debug eco spawn=true` e um Eco aparece no jogador.
- [ ] **Sentidos:** gritar (Q) a ~20 tiles de um grupo de costas; reagem de mais longe
      que de dia. → [0003 passo 4](sprints/sprint-0003-noite-agressiva/README.md#roteiro-in-game)
- [ ] **Lanterna:** ao ar livre, ligar. Em até 5 minutos de jogo:
      `[NOM] noite lanterna jogadores=1 raio=30`; zumbis a 20–30 tiles vêm. Desligar:
      `jogadores=0`. → [0003 passo 5](sprints/sprint-0003-noite-agressiva/README.md#roteiro-in-game)
- [ ] **Caça:** parado e escondido; na virada da hora de jogo,
      `[NOM] noite caca jogadores=1 raio=30` e os zumbis a até ~30 tiles vêm.
      → [0003 passo 6](sprints/sprint-0003-noite-agressiva/README.md#roteiro-in-game)
- [ ] **FPS à noite** com a mesma horda, 5 segundos depois do anoitecer: anotar.
      → [0003: loop em lotes](sprints/sprint-0003-noite-agressiva/README.md#critérios-de-aceite)

### 1.5 Noite: Estalador e Corredor (8 min)

- [ ] Do lado de um zumbi: `NOM_Debug.variant("estalador")`. Em ~1 s (próxima passada)
      `NOM_Debug.status()` mostra `estaladores=1`.
- [ ] **Cego:** agachado (C), andar devagar até ele, dar a volta, ficar 10 s, sair. Não
      ataca (pode dar um passo até onde te viu). Em pé do lado: ataca em ~1 s. Agachado
      correndo: ataca. → [0004: Estalador ignora visão](sprints/sprint-0004-estalador-corredor/README.md#critérios-de-aceite) (passo 4)
- [ ] **Estalo:** perto dele, estalo seco a cada ~2 min de jogo, mais baixo de longe,
      mudo a ~25 tiles. → [0004: estalo](sprints/sprint-0004-estalador-corredor/README.md#critérios-de-aceite) (passo 5)
- [ ] **Golpe acorda:** agachado, bater nele: passa a atacar. → [0004 passo 9](sprints/sprint-0004-estalador-corredor/README.md#roteiro-in-game)
- [ ] Outro zumbi: `NOM_Debug.variant("corredor")`. Ao te ver: um grito e
      `[NOM] variantes grito x=… y=… raio=40`; zumbis de 30–40 tiles vêm até ele.
      Sair da vista e voltar várias vezes em 30 minutos de jogo: um grito só.
      → [0004: Corredor grita](sprints/sprint-0004-estalador-corredor/README.md#critérios-de-aceite) (passos 6 e 8)
- [ ] Num Eco: `NOM_Debug.variant("estalador")`. Continua arrastado, não estala.
      → [0004 passo 13](sprints/sprint-0004-estalador-corredor/README.md#roteiro-in-game)
- [ ] **Salvar e carregar de noite:** sair, carregar. Os mesmos zumbis seguem variantes
      (o forçado do debug some com o reinício; o sorteio natural, não), nenhum
      `eco spawn=` dos mesmos corpos. → [0002 passo 6](sprints/sprint-0002-eco/README.md#roteiro-in-game),
      [0004 passo 7](sprints/sprint-0004-estalador-corredor/README.md#roteiro-in-game)

### 1.6 Noite com névoa (8 min)

- [ ] `NOM_Debug.fog(0.8)`. **Esperado:** `[NOM] night=true fog=true fogI=0.80`,
      `[NOM] nevoa fog=true periodo=1`; tela mais dessaturada e sépia, névoa mais
      densa, em ~20 min de jogo. → [0001: névoa](sprints/sprint-0001-estado-e-clima/README.md#critérios-de-aceite)
- [ ] Drone grave entra em ~8 s; baque metálico a cada 20–60 s.
      → [0005: ambiente](sprints/sprint-0005-sem-rosto-e-nevoa/README.md#critérios-de-aceite) (passo 2)
- [ ] Vinheta (bordas escuras e desfocadas) com fade, sem UI de forrageamento; segue
      depois de entrar numa casa. Forragear funciona; soltar, a vinheta volta.
      → [0005: vinheta](sprints/sprint-0005-sem-rosto-e-nevoa/README.md#critérios-de-aceite) (passo 11)
- [ ] Parado ao ar livre 1 min: manchas de sangue e ferrugem surgem a 3–12 tiles, até
      ~40; andando 30 tiles, as de trás somem. **Se** `[NOM] overlays: nenhum sprite encontrado`: registrar.
      → [0005: overlays](sprints/sprint-0005-sem-rosto-e-nevoa/README.md#critérios-de-aceite) (passo 6)
- [ ] **Sem-rosto:** de costas pra um zumbi a ~15 tiles, `NOM_Debug.variant("semrosto")`.
      Rádio chiando sobe ao chegar perto (máximo a ≤ 3 tiles), some a ≥ 30.
      → [0005: rádio](sprints/sprint-0005-sem-rosto-e-nevoa/README.md#critérios-de-aceite) (passo 5)
- [ ] Virar pra ele: some e reaparece ~3 tiles mais perto, atrás ou do lado, fora da
      vista, nunca na água; `[NOM] semrosto visto x=… para x=…` e `[NOM] nevoa semrosto some x=…`.
      Não pisca (um sumiço a cada 4 s). Deixar chegar a 2 tiles olhando: ataca.
      → [0005: olhado some](sprints/sprint-0005-sem-rosto-e-nevoa/README.md#critérios-de-aceite) (passo 3)
- [ ] No escuro, sem lanterna, um Sem-rosto a ~8 tiles à frente não some; acender a
      lanterna nele: some. → [0005 passo 4](sprints/sprint-0005-sem-rosto-e-nevoa/README.md#roteiro-in-game)
- [ ] **Noite + névoa juntas:** o Estalador do 1.5 continua cego e estalando com a
      névoa ligada, ao lado do Sem-rosto; drone, rádio, manchas e vinheta ao mesmo
      tempo, sem erro. (O debug força um tipo por zumbi; o mesmo zumbi ser os dois só
      acontece pelo sorteio natural, coberto por `night_and_fog_together`.)
      → [0005: noite + névoa](sprints/sprint-0005-sem-rosto-e-nevoa/README.md#critérios-de-aceite) (passo 8)
- [ ] **Tiro na névoa:** atirar num zumbi a ~15 tiles com e sem `NOM_Debug.fog(0.8)`:
      anotar se a mira piora muito (o combate à distância lê a névoa).
      → pendência da [0001](sprints/sprint-0001-estado-e-clima/README.md#pendências-que-a-próxima-sprint-herda)

### 1.7 Salvar com névoa (2 min)

- [ ] Com manchas no chão: `NOM_Debug.fog(0)`, salvar, sair, carregar. Nenhuma mancha.
      `NOM_Debug.fog(0.8)` de novo: manchas recomeçam do zero.
      → [0005: overlays sem sobrar no save](sprints/sprint-0005-sem-rosto-e-nevoa/README.md#critérios-de-aceite) (passo 7)

### 1.8 Amanhecer (5 min)

- [ ] `NOM_Debug.fog()` e Debug → Time: 07:00. **Esperado:** `[NOM] nevoa fog=false periodo=…`,
      `[NOM] night=false`, `[NOM] noite night=false`, `[NOM] eco removidos=N`, depois
      `stats aplicados=` de novo. Ecos somem; zumbis voltam ao passo do dia; drone e
      vinheta saem com fade; a tela clareia em ~20 min de jogo.
      → [0002: Ecos somem](sprints/sprint-0002-eco/README.md#critérios-de-aceite),
      [0003 passo 3](sprints/sprint-0003-noite-agressiva/README.md#roteiro-in-game)
- [ ] O Sem-rosto da névoa: olhar pra ele não faz nada. O Estalador e o Corredor: comuns.
- [ ] `NOM_Debug.status()` alguns segundos depois: `noite=false`, `estaladores=0`.
- [ ] Debug → Sandbox (ou o painel de admin): `Speed`, `Sight`, `Hearing`,
      `Cognition`, `Memory` iguais aos do início (a troca do mod não vazou).
      → [0003: sem stat noturno preso](sprints/sprint-0003-noite-agressiva/README.md#critérios-de-aceite) (passo 8)

### 1.9 Toggles (5 min, opcional se o tempo apertar)

Num save à parte, cada um: `DarkEnabled` desligado (sem escurecer), `DarkIntensity`
2 (mais escuro que no 1.3), `NightFaster`/`NightSharperSenses`/`NightHunt` desligados
(sem ganho de velocidade / sem lanterna / sem caça). → [0001: toggle](sprints/sprint-0001-estado-e-clima/README.md#critérios-de-aceite),
[0003 passo 7](sprints/sprint-0003-noite-agressiva/README.md#roteiro-in-game)

## Parte 2 — Multiplayer (~30 min)

Servidor dedicado local com `-debug`, `Mods=NevoaEOutroMundo` no `.ini`, sandbox com os
padrões. Cliente(s) também com `-debug`, logados como admin.

### 2.1 Um cliente

- [ ] Conectar de dia. `NOM_Debug.status()` imprime a linha local no cliente e a do
      servidor no console do servidor e do cliente.
- [ ] Pular pra 21:00 pelo painel de admin (a hora é do servidor). Sem como mudar a
      hora: `NOM_Debug.night(true)` (o céu fica de dia, o mod fica de noite). Servidor:
      `[NOM] noite night=true`; cliente: `stats aplicados=`; zumbis correm **na tela do
      cliente**. **Se** não correrem: a aplicação no dono não vale (risco nº 1 da ADR-005).
      → [0003 passo 11](sprints/sprint-0003-noite-agressiva/README.md#roteiro-in-game)
- [ ] Tela do cliente escurece junto. → [0001: MP](sprints/sprint-0001-estado-e-clima/README.md#critérios-de-aceite)
- [ ] Matar zumbis perto, esperar Eco: servidor `[NOM] eco spawn=`; Eco aparece no
      cliente; morto, o cadáver some no cliente. → [0002: spike e passo 8](sprints/sprint-0002-eco/README.md#roteiro-in-game)
- [ ] `NOM_Debug.variant("estalador")` do cliente: o Estalador ignora o jogador agachado
      na tela do cliente; o estalo toca **uma vez** (sem eco duplicado).
      → [0004 passo 10](sprints/sprint-0004-estalador-corredor/README.md#roteiro-in-game),
      pendência da [0005](sprints/sprint-0005-sem-rosto-e-nevoa/README.md#pendências-que-a-próxima-sprint-herda)
- [ ] `NOM_Debug.variant("corredor")`: grito no console do **servidor**, toca no cliente,
      zumbis vêm. → [0004 passo 10](sprints/sprint-0004-estalador-corredor/README.md#roteiro-in-game)
- [ ] `NOM_Debug.fog(0.8)` + `NOM_Debug.variant("semrosto")`: servidor
      `[NOM] nevoa fog=true`; no cliente ele some ao ser visto e **não volta** pro lugar
      antigo. **Se** voltar: no servidor deve sair `[NOM] nevoa semrosto substituido`.
      → [0005 passo 9](sprints/sprint-0005-sem-rosto-e-nevoa/README.md#roteiro-in-game)
- [ ] Amanhecer: Ecos somem **no cliente** também (sem fantasma congelado).
      → [0002 passo 9](sprints/sprint-0002-eco/README.md#roteiro-in-game)

### 2.2 Segundo cliente

- [ ] B conecta **no meio da noite**: `stats aplicados=` no B logo depois de entrar, e as
      variantes valem. → [0003 passo 12](sprints/sprint-0003-noite-agressiva/README.md#roteiro-in-game),
      [0004 passo 12](sprints/sprint-0004-estalador-corredor/README.md#roteiro-in-game)
- [ ] Um zumbi perseguindo B corre também na tela de A.
      → [0003 passo 13](sprints/sprint-0003-noite-agressiva/README.md#roteiro-in-game)
- [ ] Estalador do A, B agachado do lado: B passa. B levanta e se afasta: o Estalador
      volta a caçar. → [0004 passo 11](sprints/sprint-0004-estalador-corredor/README.md#roteiro-in-game)
- [ ] Névoa: A olha um Sem-rosto mais perto de B: em A some sem deslizar. Cada cliente
      vê manchas diferentes. → [0005 passo 10](sprints/sprint-0005-sem-rosto-e-nevoa/README.md#roteiro-in-game)

### 2.3 Três noites

- [ ] Com os dois clientes, passar 3 noites (Debug → Time pulando de noite em noite,
      jogando uns minutos em cada, uma com névoa). **Esperado:** nenhum erro com `NOM_`
      nos 3 consoles. → [0006: 3 noites de MP](sprints/sprint-0006-balanceamento-mp/README.md#critérios-de-aceite)

## Parte 3 — Medições (~15 min)

Mesmo lugar e hora nas duas rodadas, centro de Louisville ou Muldraugh, à noite, horda
de 200 (Debug → Spawn Horde).

| Medida | Sem o mod | Com o mod |
|---|---|---|
| FPS (solo, contador do debug) | | |
| FPS 5 s depois do anoitecer (solo) | | |
| Tick do servidor (dedicado, `server-console.txt`) | | |
| Pico a cada 10 min de jogo (varredura do Eco) | — | |

- [ ] Preencher a tabela. → [0003: FPS](sprints/sprint-0003-noite-agressiva/README.md#critérios-de-aceite),
      [0006: FPS e tick](sprints/sprint-0006-balanceamento-mp/README.md#critérios-de-aceite)

## Parte 4 — Remover o mod (~5 min)

- [ ] Pegar o save do solo **de noite, com Ecos vivos e névoa** (antes do 1.8 serve, ou
      voltar a ele), salvar. Desligar o mod na lista do save e carregar.
      **Esperado:** carrega; nenhum erro além de linhas de opção desconhecida
      (`NevoaEOutroMundo.*`) no `console.txt`; Ecos que estavam perto podem aparecer como
      zumbis comuns (ou sem roupa); sem escuro do mod. Jogar 2 min, salvar, recarregar.
      Religar o mod e carregar: volta a funcionar. → [0006: remover o mod](sprints/sprint-0006-balanceamento-mp/README.md#critérios-de-aceite),
      análise em [pz-api-notes §8](architecture/pz-api-notes.md#8-remover-o-mod-de-um-save-sprint-0006)

## Balanceamento

Responder em uma linha cada, depois de jogar (vai pros Checkpoints da sprint 0006):

1. A noite com o padrão (~60% correndo) ficou divertida ou injusta? O Corredor se
   destacou dos outros? ([revisão dos defaults](gdd/sandbox.md#revisão-dos-defaults-2026-10-04-sem-jogar))
2. Quantos Sem-rosto apareceram na cidade com névoa? Rádio virou ruído?
3. 30 Ecos por jogador foi muito, pouco ou certo?
4. A escuridão (`DarkIntensity` 1.0) atrapalhou ver o jogo?
5. A caça a cada hora de jogo ficou presente demais ou passou despercebida?
