# Teste in-game — roteiro consolidado

| Campo | Valor |
|-------|-------|
| Status | `accepted` |
| Escrito em | sprint 0006 (2026-10-04) |
| Cobre | o evento de névoa da [0009](sprints/sprint-0009-nevoa-evento/README.md#roteiro-in-game) a névoa vermelha da [0010](sprints/sprint-0010-nevoa-vermelha/README.md#roteiro-in-game) a Carpideira da [0011](sprints/sprint-0011-carpideira/README.md#roteiro-in-game) e o visual dos monstros da [0012](sprints/sprint-0012-visual-variantes/README.md#roteiro-in-game) (roteiros próprios) e os critérios in-game das sprints [0001](sprints/sprint-0001-estado-e-clima/README.md) a [0006](sprints/sprint-0006-balanceamento-mp/README.md) e a lista de mods da [0007](sprints/sprint-0007-workshop/README.md) (o teste da cópia do Workshop fica no [publicar.md](publicar.md)), menos o que está em [Fora desta sessão](#fora-desta-sessão) |
| Duração | ~60–90 min: solo ~40, MP ~30, medições e remoção ~15 |

> **⚠️ Use um save descartável.** `NOM_Debug.night` e `NOM_Debug.fog` avançam os
> contadores de noites e de névoas que o mod **salva** no save (ModData global). O
> número da noite decide o sorteio das variantes e a noite dos Ecos: num save de
> verdade a mudança é permanente. Nada aqui é pra rodar num save que se quer manter.

Uma sessão só. O save do solo anda na ordem natural (dia → anoitecer → noite →
névoa → amanhecer), então cada passo prepara o próximo. Os roteiros das sprints
continuam lá com o detalhe de cada sistema; aqui é a ordem pra rodar tudo de uma vez.
Cada item tem a caixinha, o que fazer, a linha esperada no console e o critério que
ele fecha.

**No fim, mandar de volta:** `~/Zomboid/console.txt` do solo, o do cliente de MP e o
console do servidor dedicado (`~/Zomboid/server-console.txt`), mais as respostas da
seção [Balanceamento](#balanceamento) e os números das [medições](#parte-3--medições-15-min).

> **Steam Flatpak (o caso deste PC):** o jogo roda em sandbox e a pasta de dados é
> `~/.var/app/com.valvesoftware.Steam/Zomboid`, não `~/Zomboid` — vale pra `mods/`,
> `Workshop/` e `console.txt` em todo este documento. Mod de dev: **`scripts/dev-sync.sh`** copia `mod/`
> pra pasta de mods do jogo (rodar de novo a cada mudança e recarregar o save). **Não use
> symlink**: com link o jogo não lê `media/scripts/*.txt` (itens de visual somem).
> O `build-workshop.sh` detecta essa pasta sozinho (ou use `ZOMBOID_DIR=...`).

## Antes de começar (~5 min)

- [ ] Mod de staging copiado: `scripts/dev-sync.sh`; no menu Mods, ativar **"[STAGING] NOM: Noise of Mist"**
      (pôster vermelho), nunca junto do oficial "NOM: Noise of Mist" do Workshop
      ([AGENTS.md](../AGENTS.md#desenvolvimento-x-lançado-decisão-do-johan-2026-10-06)).
- [ ] Jogo aberto com `-debug` (opção de inicialização da Steam).
- [ ] Toda linha do mod começa com `[NOM]`. No MP, o que é do servidor sai no console
      do **servidor** (noite, névoa, Eco, grito) e o que é de quem simula ou vê sai no
      do **cliente** (`stats aplicados`, `semrosto visto`).

### Atalhos de debug (console Lua do modo debug)

Só existem com `-debug` (sprint 0006). Valem no solo e no MP (no MP pedem a permissão
de debug do jogo; rodar como admin).

**Atalhos curtos (sprint 0020).** `NOM.help()` lista todos com uma linha em PT-BR (o
autocomplete do console é do Java e não vê função Lua). Toggle sem argumento inverte.
Os `NOM_Debug.*` da tabela abaixo continuam iguais.

| Comando | Faz | Linha esperada |
|---|---|---|
| `NOM.help()` | lista os comandos | `[NOM] NOM.fog(on, skip) - névoa: …` (uma por comando) |
| `NOM.fog()` / `(true)` / `(true, true)` / `(false)` | inverte (cancela a sirene que está contando) / sirene / névoa já / termina | `[NOM] debug nevoa sirene=true` ou `[NOM] debug nevoa fim=true` |
| `NOM.redFog()` / `(true)` / `(false)` | névoa vermelha: inverte (o servidor vê a vermelha aberta ou na sirene) / força / desfaz | `[NOM] debug nevoa vermelha=…` |
| `NOM.night()` / `(true)` / `(false)` | noite forçada: inverte / noite / dia (relógio: `NOM_Debug.night()`) | `[NOM] debug noite forcada=…` |
| `NOM.time(22)` | hora do relógio, sempre pra frente (hora que já passou vira a de amanhã; 25 vira 1) | `[NOM] debug hora=22.00` |
| `NOM.spawn(5)` / `NOM.spawn(5, "Police")` | zumbis espalhados em 3×3, 3 tiles na sua frente (1 a 50; outfit opcional, nome errado é recusado) | `[NOM] debug spawn n=5 criados=5 outfit=-` (ou `spawn outfit desconhecido=…`) |
| `NOM.variant("corredor")` / `NOM.eco()` / `NOM.status()` | os mesmos do `NOM_Debug` | idem |
| `NOM.god()` / `NOM.noclip()` / `NOM.invisible()` | truques do jogador local (inverte; `true`/`false` fixa) | `[NOM] debug god=true` |
| `NOM.panel()` ou **Insert** | abre e fecha o painel de botões (tecla em Opções > Mods > NOM: Noise of Mist) | janela "NOM: debug" |
| `NOM.setFog()` / `(true)` | névoa **sempre branca**: 3 s de estática, coro de sirenes, 30 s de fuga com a névoa subindo (zumbis param) e névoa / névoa na hora; fecha o que estiver aberto ou contando (sprints 0033 e 0034) | `[NOM] debug nevoa forcada branca=true` |
| `NOM.setRedFog()` / `(true)` | o mesmo, **sempre vermelha** | `[NOM] debug nevoa forcada vermelha=true` |
| `NOM.setBlackFog()` / `NOM.setEndFog()` | a preta só avisa (0038) / termina a névoa ou cancela a sirene | `[NOM] debug nevoa fim=…` |
| `NOM.getZombie()` | puxa o zumbi vivo mais perto pra cima de você (no MP, o cliente dono move; zumbi sem ID de rede é recusado) | `[NOM] debug zumbi puxado x=… y=…` |
| `NOM.turnZombie(i)` | o mais perto vira 1 estalador, 2 corredor, 3 semrosto, 4 carpideira; 0 desfaz (só na névoa) | `[NOM] debug variante id=… forcada=…` |
| `NOM.godMode()` / `NOM.wind()` | deus + invisível + zumbis não atacam / foco de vento do mod3 (inverte; `true`/`false` fixa) | `[NOM] debug godMode=true` |

Roteiro completo dos comandos da 0033: [sprint 0033](sprints/sprint-0033-ritmo-novo/README.md#roteiro-in-game). Sirenes, fuga, estática e aparelhos: [sprint 0034](sprints/sprint-0034-sons/README.md#roteiro-de-teste-no-jogo).

| Comando | Faz | Linha esperada |
|---|---|---|
| `NOM_Debug.status()` | estado do mod | `[NOM] debug local …` e `[NOM] debug servidor …` |
| `NOM_Debug.night(true)` / `(false)` / `()` | força noite / dia / devolve pro relógio | `[NOM] debug noite forcada=true`; vale no próximo minuto de jogo |
| `NOM_Debug.fog(true)` / `(true, true)` / `(false)` | evento de névoa: sirene (sem o presságio) e névoa 30 s reais depois / névoa na hora / termina (sprint 0009; 30 s de fuga desde a 0034) | `[NOM] debug nevoa sirene=true`, depois `[NOM] nevoa evento inicio periodo=N fim=…`; `[NOM] debug nevoa fim=true` |
| `NOM_Debug.redFog(true)` / `(false)` | névoa vermelha: com névoa aberta vira na hora; sem, sirene vermelha e névoa vermelha 30 s depois / desfaz (sprint 0010) | `[NOM] debug nevoa vermelha=true`, `[NOM] nevoa sirene contagem=30000 vermelha=true …` |
| `NOM_Debug.variant("estalador")` | zumbi vivo mais perto vira Estalador (`"corredor"`, `"semrosto"`, `"carpideira"`; `()` desfaz). Vale pelo `persistentOutfitID`: outro zumbi com o mesmo ID (gêmeo, raro) vira junto. Some quando o jogo reinicia (carregar o save de novo) | `[NOM] debug variante x=… y=… id=…` e `[NOM] debug variante id=… forcada=estalador` |
| `NOM_Debug.spawnEco()` | um Eco nos pés do jogador (só à noite) | `[NOM] debug eco spawn=true` |

A noite forçada liga tudo do mod, mas o céu continua o do relógio: pra **ver** a
noite, use Debug → Time. O `NOM_Debug.fog` abre um evento de névoa de verdade (flag,
Sem-rosto, som, chão, vinheta e a névoa do clima, que é toda do mod desde a sprint 0009).

- [ ] Dentro do save, `NOM_Debug.status()` imprime as duas linhas. **Se** `NOM_Debug`
      for `nil`: o jogo não está em `-debug` (ou o mod não está ativo no save).
- [ ] Painel e atalhos (sprint 0020): [roteiro da 0020](sprints/sprint-0020-debug-amigavel/README.md#roteiro-in-game).
- [ ] Outro Mundo anexado e o save limpo (sprint 0023, **save descartável**): [roteiro da 0023](sprints/sprint-0023-outro-mundo-anexado/README.md#roteiro-in-game).

## Parte 1 — Solo (~40 min)

Save novo, sandbox Apocalypse, página "NOM: Noise of Mist" com os **padrões**,
começando de dia, numa cidade (Muldraugh serve).

### 1.1 Menu e carga (5 min)

- [ ] **Lista de mods (Mods no menu principal):** "[STAGING] NOM: Noise of Mist" aparece
      disponível, com o ícone ("NOM" avermelhado) na linha e o pôster vermelho no painel de
      informações; descrição em PT-BR, e em inglês depois de trocar o idioma (vem do
      `Mod.json`). → [0007: textos, poster e ícone](sprints/sprint-0007-workshop/README.md#roteiro-in-game)
- [ ] **Sandbox:** a página "NOM: Noise of Mist" mostra as 24 opções com rótulo e
      tooltip em PT-BR; trocar o idioma pra inglês e conferir "Clickers", "Runners",
      "Faceless". → [0001: tradução](sprints/sprint-0001-estado-e-clima/README.md#critérios-de-aceite),
      [0002 passo 1](sprints/sprint-0002-eco/README.md#roteiro-in-game),
      [0003 passo 1](sprints/sprint-0003-noite-agressiva/README.md#roteiro-in-game),
      [0004 passo 1](sprints/sprint-0004-estalador-corredor/README.md#roteiro-in-game),
      [0005 passo 1](sprints/sprint-0005-sem-rosto-e-nevoa/README.md#roteiro-in-game)
- [ ] **Carga:** nenhum `ERROR`/`WARN` com `NOM_`, `NOM_sounds` ou `clothing.xml` no
      `console.txt`. → [0001: mod ativa sem erro](sprints/sprint-0001-estado-e-clima/README.md#critérios-de-aceite)
- [ ] Primeira linha de clima: `[NOM] night=false fog=false fogI=…` (a névoa vanilla do momento).

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
- [ ] A tela escurece aos poucos, **bem mais escura e azulada que a noite vanilla**;
      cheia em ~20 minutos de jogo, sem corte. `[NOM] nightRamp=1.00 fogRamp=0.00` e o
      bloco `[NOM] clima …` quando completa (o que conferir nas linhas:
      [roteiro da 0008](sprints/sprint-0008-ajustes-teste/README.md#roteiro-in-game), passo 1).
      → [0001: noite, transição](sprints/sprint-0001-estado-e-clima/README.md#critérios-de-aceite),
      [0008: noite escura](sprints/sprint-0008-ajustes-teste/README.md#critérios-de-aceite)
- [ ] Os zumbis ficam um degrau mais rápidos. → [0003 passo 2](sprints/sprint-0003-noite-agressiva/README.md#roteiro-in-game)

### 1.4 Noite: zumbis comuns e Ecos (10 min)

- [ ] **Ecos:** em até 10 minutos de jogo, `[NOM] eco spawn=5` (os corpos do 1.2).
      Ecos de camisola de hospital e véu, em cima dos corpos, arrastados; um golpe
      derruba. **Se** `[NOM] eco outfit NOM_Eco não carregou`: registrar.
      → [0002 passos 2 e 9 da 0003](sprints/sprint-0002-eco/README.md#roteiro-in-game)
- [ ] **Corpo carregado:** pegar no colo um dos corpos que já soltou Eco, largar uns
      tiles adiante e esperar 10 minutos de jogo. **Esperado:** nenhum segundo Eco desse
      corpo (sem `eco spawn=` novo ali). **Se** sair: o `modData` do corpo não sobrevive
      ao carregar. → pendência da [0002](sprints/sprint-0002-eco/README.md#pendências-que-a-próxima-sprint-herda)
- [ ] **Recém-morto não vira Eco:** matar um zumbi comum perto de você agora, à noite.
      Na varredura seguinte, `[NOM] eco esperando a proxima noite=1` e nenhum Eco dele;
      na noite seguinte, ele solta. → [0008: Eco só de quem morreu antes](sprints/sprint-0008-ajustes-teste/README.md#roteiro-in-game) (passo 3)
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

### 1.5 Noite com névoa: Estalador e Corredor (8 min)

Desde a sprint 0008 **todo monstro, menos o Eco, só existe na névoa**: sem névoa o
`variant` do debug não tem efeito. Ligar a névoa antes: `NOM_Debug.fog(true, true)`
(`[NOM] nevoa fog=true periodo=N`); ela fica ligada até o 1.7.

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
### 1.6 Noite com névoa: atmosfera e Sem-rosto (8 min)

O Estalador do 1.5 segue forçado (o jogo não reiniciou). Se ele morreu:
`NOM_Debug.variant("estalador")` num zumbi perto.

- [ ] (névoa ligada no 1.5) **Esperado:** `[NOM] night=true fog=true fogI=0.80`,
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
- [ ] **Tiro na névoa:** atirar num zumbi a ~15 tiles com e sem `NOM_Debug.fog(true, true)`:
      anotar se a mira piora muito (o combate à distância lê a névoa).
      → pendência da [0001](sprints/sprint-0001-estado-e-clima/README.md#pendências-que-a-próxima-sprint-herda)

### 1.7 Salvar e carregar de noite (4 min)

- [ ] Com manchas no chão (evento de névoa aberto), salvar, sair, carregar (ainda de
      noite). As manchas antigas não voltam; a névoa volta sozinha (evento salvo, sprint
      0009) e as manchas recomeçam do zero. → [0005: overlays sem sobrar no save](sprints/sprint-0005-sem-rosto-e-nevoa/README.md#critérios-de-aceite) (passo 7)
- [ ] Mesma noite depois de carregar: nenhum `eco spawn=` dos corpos que já soltaram
      Eco; `NOM_Debug.status()` com o mesmo `noiteN`; os zumbis que eram variante **pelo
      sorteio natural** continuam (o forçado do debug some no reinício, é esperado).
      → [0002 passo 6](sprints/sprint-0002-eco/README.md#roteiro-in-game),
      [0004 passo 7](sprints/sprint-0004-estalador-corredor/README.md#roteiro-in-game)
- [ ] Pro amanhecer ter o que conferir: `NOM_Debug.variant("estalador")` num zumbi
      perto (a névoa continua: o evento é salvo).

### 1.8 Amanhecer (5 min)

- [ ] `NOM_Debug.fog(false)` e Debug → Time: 07:00. **Esperado:** `[NOM] nevoa fog=false periodo=…`,
      `[NOM] night=false`, `[NOM] noite night=false`, `[NOM] eco removidos=N`, depois
      `stats aplicados=` de novo. Ecos somem; zumbis voltam ao passo do dia; drone e
      vinheta saem com fade; a tela clareia em ~20 min de jogo.
      → [0002: Ecos somem](sprints/sprint-0002-eco/README.md#critérios-de-aceite),
      [0003 passo 3](sprints/sprint-0003-noite-agressiva/README.md#roteiro-in-game)
- [ ] O Sem-rosto da névoa: olhar pra ele não faz nada. O Estalador e o Corredor: comuns
      (é a névoa que baixou que leva os dois, não o amanhecer: com névoa de dia eles
      continuam, [roteiro da 0008](sprints/sprint-0008-ajustes-teste/README.md#roteiro-in-game) passo 4).
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

Servidor dedicado local com `-debug`, `Mods=NoiseOfMist_Staging` no `.ini` (o mod de staging copiado pelo `dev-sync.sh`), sandbox com os
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
- [ ] `NOM_Debug.fog(true, true)` + `NOM_Debug.variant("semrosto")`: servidor
      `[NOM] nevoa fog=true`; no cliente ele some ao ser visto e **não volta** pro lugar
      antigo. **Se** voltar: no servidor deve sair `[NOM] nevoa semrosto substituido`.
      → [0005 passo 9](sprints/sprint-0005-sem-rosto-e-nevoa/README.md#roteiro-in-game)
- [ ] Amanhecer: Ecos somem **no cliente** também (sem fantasma congelado).
      → [0002 passo 9](sprints/sprint-0002-eco/README.md#roteiro-in-game)

### 2.2 Segundo cliente

Os dois clientes com `-debug`: é o `client/NOM_Debug.lua` (só existe com `-debug`) que
recebe as variantes forçadas, inclusive as de antes de B entrar (o servidor manda a
tabela inteira na resposta ao pedido de estado da entrada).

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
| FPS com névoa normal (`NOM_Debug.fog(true, true)`, 1 min depois) | — | |
| FPS com névoa vermelha (`NOM_Debug.redFog(true)` com a névoa aberta, 1 min depois: todo zumbi é variante) | — | |

- [ ] **Névoa vermelha com horda** (sprint 0010): com a horda de 200 carregada, anotar o
      FPS sem névoa, depois `NOM_Debug.fog(true, true)` e o FPS 1 minuto depois (todos
      os stats aplicados), depois `NOM_Debug.redFog(true)` e o FPS 1 minuto depois. No
      dedicado, o tick do servidor nas mesmas três. **Esperado:** a vermelha a menos de
      ~10% do FPS da normal; se cair mais, mandar os números (o orçamento contado está
      no [README da arquitetura](architecture/README.md#orçamento-por-sistema)).
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

Playtest dos defaults do PO (sprint 0019, [revisão](gdd/sandbox.md#revisão-do-po-2026-10-05-sprint-0019-aprovada-pelo-johan)),
com o sandbox padrão e um **save novo** (a curva conta do nascimento do save; save antigo guarda o próprio sandbox, então continua com 3 dias, 2–6 h e os números velhos). Cada item tem um
alvo e o ajuste se passar do limiar; anotar o resultado em uma linha nos Checkpoints da
[sprint 0019](sprints/sprint-0019-balanceamento/README.md). Substitui as 5 perguntas da 0006
(noite injusta, Sem-rosto, Ecos, escuro e caça estão nos itens 1–4 e 9).

1. **Noites 1–3 na cidade**, dentro de casa sem barricada, luz apagada. Morrer dentro de casa →
   `HuntIntervalMinutes` 120. Morrer na rua com lanterna acesa = ok (é o jogo).
2. **Zumbis na porta ao amanhecer** (cidade): alvo 5–15. Mais de 25 → `HuntRadius` 20; menos
   de 3 → `HuntIntervalMinutes` 60.
3. **Ecos** (`[NOM] eco spawn=N` no console): alvo 5–15 numa noite sem limpar. Teto de 20
   batido mesmo queimando os corpos do dia → `EcoRadius` 25; três noites sem um Eco fazer o
   jogador recuar → `EcoMaxPerPlayer` 30.
4. **Rádio do Sem-rosto** na névoa da cidade: chiando mais de 70% do tempo →
   `SemRostoChance` 2; três névoas sem ver nenhum → 4.
5. **Carpideira**, três névoas na cidade: alvo 1–2 gritos, e o soluço ouvido **antes** de
   cada um. Acordou sem soluço = bug de justiça (volume/alcance do soluço, abrir issue). Zero
   fugas do grito → `CarpideiraScreamRadius` 60; morreu em 2 de 3 → 40.
6. **Corredor:** três névoas sem uma perseguição → `CorredorChance` 4.
7. **Vermelha** forçada por volta do dia 7 (`NOM_Debug.redFog(true)`) numa casa não limpa.
   Morrer escondido numa casa **limpa** → a vermelha precisa de teto de variantes (sprint
   nova). FPS abaixo de 90% do da névoa normal com 200 zumbis → **bloqueador de release**.
8. **Duração:** duas névoas seguidas terminando com "já acabou?" → `FogMinHours` 4.
9. **Escuro:** ao ar livre, lua cheia, sem luz. Não vê zumbi a 5 tiles → `DarkIntensity` 0.8;
   vê a 15 → 1.2.
10. **Overlays:** perdeu item caído no chão ou não achou a poça de uma luta real → densidade
    do Outro Mundo 0.7 (Opções > Mods).

## Fora desta sessão

- **Sem-rosto deslizando na tela de um terceiro jogador** ([0005 passo 10](sprints/sprint-0005-sem-rosto-e-nevoa/README.md#roteiro-in-game),
  parte "com B longe olhando A"): precisa de um terceiro cliente. Se der pra abrir um,
  repetir o último item do 2.2 com C olhando de longe e anotar se ele desliza.
- **`ActiveOnly`** ([0003 passo 14](sprints/sprint-0003-noite-agressiva/README.md#roteiro-in-game)):
  precisa de um save com "Ativos só de dia". Se sobrar tempo: save descartável com essa
  opção, à noite os zumbis continuam arrastados e sem `stats aplicados=` repetido a cada
  passada.
- **Tela dividida:** fora do escopo (pendência `later` da 0005).
