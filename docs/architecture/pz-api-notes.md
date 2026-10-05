# Notas de API do PZ (Build 42.20.4) para as mecânicas do mod

| Campo | Valor |
|-------|-------|
| Status | `accepted` |
| Data | 2026-10-04 (§11, §12: 2026-10-05) |
| Fonte | Lua vanilla em `media/lua`, scripts em `media/scripts`, bytecode de `projectzomboid.jar` |

> **Kahlua ≠ luajit (visto no jogo, 2026-10-05):** `next()` é `nil` no Kahlua
> ("Object tried to call nil in prune"); o luajit dos testes tem, então o teste passou
> e o jogo quebrou. `tests/test_kahlua_compat.lua` varre `mod/` atrás do que o Kahlua
> não tem. Achou outra função faltando no jogo: acrescente lá.

## Como ler este documento

- **CONFIRMED**: visto em uso no Lua vanilla (arquivo:linha).
- **EXISTS**: método público no bytecode e classe exposta ao Lua (lista do
  `LuaManager$Exposer.exposeAll`), mas sem uso vanilla. Funciona em tese; teste antes de depender.
- **UNKNOWN**: o bytecode não responde; precisa de teste in-game.
- Caminhos Lua são relativos a `media/lua/`. Bytecode no formato `Classe.metodo(descritor)`.
- Nenhum código de mod do Workshop foi copiado ou usado como evidência.

### Três fatos transversais (leia antes de tudo)

1. **Detecção de "lado do servidor".** Em solo, `isServer()` e `isClient()` são **ambos
   `false`**; em dedicado, `isServer()` é `true` no servidor. Guarda correta para lógica
   autoritativa: `if isClient() then return end`. Evidência: `server/XpSystem/XpUpdate.lua:294-297`
   (`isServer() and players:size()-1 or getNumActivePlayers()-1`); bytecode
   `GlobalObject.sendClientCommand(...)` cai em `SinglePlayerClient.sendClientCommand` fora do MP.
2. **No MP do B42, a IA do zumbi é simulada pelo cliente "dono".** O servidor dá posse
   (ownership) de cada zumbi a uma conexão e só retransmite. Evidência: bytecode
   `NetworkZombieManager.updateAuth(IsoZombie)` (usa `ServerOptions.switchZombiesOwnershipEachUpdate`),
   `IsoZombie.setOwner(UdpConnection)`, `IsoZombie.isRemoteZombie()`, `NetworkZombieSimulator.getAuthorizedZombieCount()`.
   O `walkType` viaja nos dois sentidos: `NetworkZombiePacker` (servidor) **e** `NetworkZombieSimulator`
   (cliente) chamam `IsoZombie.setWalkType(String)`. Consequência: **a decisão** (variante, noite,
   spawn) pode ser autoritativa no servidor, mas **a aplicação** de ajustes de IA (velocidade,
   alvo, pathing, sentidos) tem que rodar também no cliente dono. Isso afeta a ADR-002. Sprint 0003:
   o bytecode mostra que velocidade feita só no servidor é sobrescrita pelo pacote do
   dono e que os sentidos são locais; a aplicação vai pra quem simula
   ([ADR-005](adr-005-quem-simula-aplica.md)). Falta o teste no jogo.
3. **`modData` de zumbi não persiste nem sincroniza.** `IsoZombie.save/load` só é chamado por
   `ReanimatedPlayers` (bytecode: único chamador de `IsoZombie.save(ByteBuffer)`). Quando o chunk
   descarrega, o zumbi vira virtual e o popman guarda só posição, direção, `persistentOutfitID`
   e flags (`ZombieStateFlag`: Initialized, Crawling, CanWalk, FakeDead, CanCrawlUnderVehicle,
   ReanimatedForGrappleOnly). Ao voltar, `ZombiePopulationManager` chama `IsoZombie.DoZombieStats()`,
   que re-sorteia os stats a partir do sandbox. Ver seção 3.

---

## 1. Eco (sprint 0002)

### 1.1 Enumerar corpos perto do jogador

| API | Status | Evidência |
|---|---|---|
| `getCell():getGridSquare(x, y, z)` | CONFIRMED | uso amplo; no dedicado, `IsoWorld.currentCell` existe (bytecode `RemoveZombiesCommand` usa `IsoCell.getGridSquare(III)`) |
| `square:getDeadBodys()` → `List<IsoDeadBody>` | CONFIRMED | `client/Vehicles/ISUI/ISVehicleMenu.lua:802`, `client/ISUI/ISVehicleAnimalUI.lua:167` |
| `square:getStaticMovingObjects()` + `instanceof(o, "IsoDeadBody")` | CONFIRMED | `shared/TimedActions/ISBuryCorpse.lua:56-58` |
| `square:getDeadBody()` (um só) | EXISTS | bytecode `IsoGridSquare.getDeadBody()` |

Recomendado: no servidor, a cada `EveryOneMinute` à noite, para cada jogador, varrer um quadrado
de raio N (N=10 → 441 squares) com `getGridSquare` e `getDeadBodys()`. Squares fora da área
carregada voltam `nil`; trate. Animais mortos também são `IsoDeadBody`: filtre com
`body:isAnimal()` (bytecode `IsoDeadBody.isAnimal()Z`). `body:isZombie()` diz se era zumbi.

### 1.2 Marcar o corpo ("uma vez por corpo, para sempre")

| API | Status | Evidência |
|---|---|---|
| `body:getModData()` | CONFIRMED | `ISBuryCorpse.lua:59` (`body:getModData()["lastPlayerGrabbed"]`) |
| persiste no save | EXISTS | bytecode `IsoDeadBody.save` → `IsoMovingObject.save` (offsets 104–133) grava `table` (campo de `IsoObject`) via `KahluaTable.save`; `IsoMovingObject.load` (89–118) relê. Chave numérica também salva (`KahluaTableImpl.save` grava `Double`) |

Basta `body:getModData().NOM_ecoReleased = true` no servidor (sprint 0002). Em MP o flag só precisa existir no
servidor (quem decide o spawn), e é o servidor que salva o chunk.

**Pegadinha:** o construtor de `IsoDeadBody(IsoGameCharacter, ...)` **copia o modData do
personagem** para o corpo (bytecode: `IsoGameCharacter.getModData()` + `LuaManager.copyTable`).
Ou seja, o corpo de um Eco nasce com o modData do Eco. Use chaves distintas para "sou Eco"
(no zumbi) e "já gerei Eco" (no corpo).

Corpos queimados/enterrados somem de verdade: enterrar chama `sq:removeCorpse(targetBody, false)`
(`ISBuryCorpse.lua:73`).

### 1.3 Spawnar o zumbi

| API | Status | Evidência |
|---|---|---|
| `addZombiesInOutfit(x, y, z, count, outfitName, femaleChance)` → `ArrayList<IsoZombie>` | CONFIRMED (cliente SP) | `client/Tutorial/Steps.lua:830` (`...:get(0)`), `client/DebugUIs/Scenarios/Trailer2_PoliceScenario.lua:112` |
| versão longa: `(x,y,z,count,outfit,femaleChance, crawler, isFallOnFront, isFakeDead, knockedDown, isInvulnerable, isSitting, health, isRecordingAnims, heightOffset, isRagdolling, onFire)` | CONFIRMED | `client/DebugUIs/ISSpawnHordeUI.lua:276`; health do slider 0..2, padrão 1.0 (`:110-111`) |
| `addZombiesInOutfitArea(x1,y1,x2,y2,z,count,outfit,femaleChance)` | CONFIRMED | `Steps.lua:2123-2124` |
| `createZombie(x, y, z, desc, palette, IsoDirections)` | CONFIRMED | `Steps.lua:1088` (`createZombie(x, y, 0, nil, 0, IsoDirections.S)`) |
| `spawnHorde(x1,y1,x2,y2,z,count)` / `createHordeFromTo(...)` | CONFIRMED | `Steps.lua:2111`, `client/LastStand/Challenge1.lua:138` |
| `zombie:dressInNamedOutfit(name)` / `dressInPersistentOutfit(name)` | EXISTS | bytecode `IsoZombie.dressInNamedOutfit(String)`; `addZombiesInOutfit` usa `dressInPersistentOutfit` |

Todos acabam em `VirtualZombieManager.createRealZombieAlways`, que dispara `OnZombieCreate`.

**Ordem no spawn (sprint 0002, bytecode `addZombiesInOutfit(...ZZ)`):** `createRealZombieAlways`
(offset 136, **dispara `OnZombieCreate`** com o outfit de zona) → `dressInPersistentOutfit(outfit)`
(314) → `DoZombieStats` (382) → `setHealth(health)` (410; a versão de 6 args passa 1.0). Quem
quer marcar o zumbi spawnado marca depois da chamada, não no evento. E `createRealZombieAlways`
só põe o zumbi em `getZombieList()` **depois** do evento (offsets 39–79): remover dentro do
`OnZombieCreate` deixa o zumbi meio removido.

**MP:** o debug do vanilla, em cliente MP, **não** chama `addZombiesInOutfit`; manda
`/createhorde2` para o servidor (`ISSpawnHordeUI.lua:254`). Ou seja, spawn é coisa de servidor.
Chamar `addZombiesInOutfit` no Lua do servidor dedicado: EXISTS (função estática no
`GlobalObject`, o servidor tem `IsoCell`), **UNKNOWN** na prática — nenhum Lua vanilla de
servidor spawna zumbi. O corpo do método checa `IsoWorld.getZombiesDisabled()` e loga
"Cannot spawn." se zumbis estiverem desligados.

Recomendado: no servidor,
`local z = addZombiesInOutfit(x, y, z, 1, "HospitalPatient", 50):get(0)` e configurar `z` em seguida.
Fallback: `createZombie(...)` + `z:dressInNamedOutfit(...)`.

### 1.4 Stats do Eco (fraco)

| Ajuste | API | Status | Evidência |
|---|---|---|---|
| vida | `z:setHealth(f)` / argumento `health` do spawn | EXISTS / CONFIRMED | bytecode `IsoGameCharacter.setHealth(F)`; `ISSpawnHordeUI.lua:276` |
| velocidade, força, sentidos | ver seção 2.1 (truque do sandbox + `DoZombieStats`) | EXISTS | bytecode `IsoZombie.DoZombieStats()` |
| dano | não há setter por zumbi | — | campo `IsoZombie.strength` é privado ao Lua (Kahlua só expõe métodos) |

### 1.5 Morte sem corpo e sem loot

Ordem real de eventos (bytecode `IsoZombie.onKilled`): `IsoGameCharacter.onKilled` →
`IsoZombie.DoZombieInventory()` (enche o inventário com roupas e itens) → **`OnZombieDead(zombie)`**
→ `IsoZombie.DoDeath(...)`. O corpo nasce **depois**, em `IsoGameCharacter.becomeCorpse()` →
`new IsoDeadBody(chr)`, cujo construtor adiciona o corpo ao square, tira o zumbi do mundo e
dispara **`OnDeadBodySpawn(body)`**.

| API | Status | Evidência |
|---|---|---|
| `Events.OnZombieDead.Add(function(zombie) ... end)` | CONFIRMED | `Steps.lua:840` |
| `Events.OnDeadBodySpawn.Add(function(body) ... end)` | CONFIRMED | `client/ISUI/ISWorldObjectContextMenu.lua:2778-2782` |
| `zombie:getInventory():removeAllItems()` | EXISTS | o próprio `DoZombieInventory` chama `ItemContainer.removeAllItems()` |
| `square:removeCorpse(body, false)` | CONFIRMED | `ISBuryCorpse.lua:73`, `shared/TimedActions/ISGrabCorpseAction.lua:78` |
| sync de `removeCorpse` | EXISTS | bytecode: no servidor manda `PacketType.RemoveCorpseFromMap` via `sendToRelative`; no cliente manda ao servidor |

Recomendado (servidor):
1. `OnZombieDead`: se `zombie:getModData().nevoaEco`, limpar inventário (cinto e suspensório).
2. `OnDeadBodySpawn`: se `body:getModData().nevoaEco` (veio copiado do zumbi), **enfileirar** o
   corpo; no próximo `OnTick`, `body:getSquare():removeCorpse(body, false)`. Enfileirar porque o
   evento roda dentro do construtor, antes de `becomeCorpse` terminar (`invokeOnDiedListeners`).

**Resolvido na sprint 0002: `OnDeadBodySpawn` não dispara no servidor dedicado** (bytecode
`IsoDeadBody.<init>` offsets 1298–1311: `if (... && !GameServer.server) triggerEvent`). O mod usa
o fallback: em `OnZombieDead` guardar `(x,y,z)` e procurar o corpo no 3×3 nos ticks seguintes
(o construtor copia o `modData` do zumbi pro corpo, offsets 1121–1128, e o `persistentOutfitID`,
906). `removeCorpse(body, false)` no servidor manda `RemoveCorpseFromMap` por `sendToRelative`
(bytecode `IsoGridSquare.removeCorpse` 45–74). Queimar corpo (`IsoDeadBody.Burn`) troca por
`burnedCorpse` e chama `removeCorpse`.

### 1.6 Sumir com o Eco vivo (amanhecer)

| API | Status | Evidência |
|---|---|---|
| `z:removeFromWorld()` + `z:removeFromSquare()` | EXISTS | é o que o comando admin `/removezombies` faz (bytecode `RemoveZombiesCommand`) |
| aviso de remoção aos clientes | **não exposto** | o admin chama `NetworkZombiePacker.deleteZombie(z)` antes; essa classe **não** está no Exposer |

`IsoZombie.removeFromWorld()` no servidor tira o zumbi de `ServerMap.zombieMap` e da lista da
célula, mas não envia `ZombieDeleteOnClient`. UNKNOWN se os clientes descartam o fantasma
sozinhos. Recomendado em camadas:
1. Solo: `removeFromWorld()` + `removeFromSquare()` resolve.
2. MP: servidor remove e manda `sendServerCommand("NevoaEOutroMundo", "ecoGone", { ids = {...} })`;
   cada cliente acha o zumbi por `getOnlineID()` em `getCell():getZombieList()` e remove localmente
   (no cliente, `removeFromWorld` chama `GameClient.removeZombieFromCache`, bytecode 146–167).
   Implementado na sprint 0002; UNKNOWN se o cliente dono recria o zumbi.
3. Fallback: `z:Kill(nil)` (morte sincronizada) + remoção do corpo da 1.5. Tem animação de queda,
   o que pode ser aceitável como "desfazer".

### 1.7 Iterar zumbis no servidor

`getCell():getZombieList()`: EXISTS (bytecode `IsoCell.getZombieList()`; o próprio
`removeFromWorld` usa essa lista no servidor). Sem uso vanilla em Lua. No dedicado a lista contém
os zumbis reais perto de qualquer jogador. Para localizar Ecos: guardar referência numa tabela Lua
do servidor (eles só existem à noite) e varrer a lista no amanhecer como rede de segurança.

---

## 2. Agressividade noturna (sprint 0003)

### 2.1 Velocidade, força e sentidos por zumbi

**Verificado na sprint 0003** (bytecode B42.20.4). Implementado em `shared/NOM_NightStats.lua`.

Não existe `setSight`, `setHearing`, `setStrength` nem `setSpeedType` públicos.

| API | Status | Evidência / comportamento |
|---|---|---|
| `getSandboxOptions():getOptionByName("ZombieLore.Speed")` (e `.Sight`, `.Hearing`, `.Cognition`) | getOptionByName CONFIRMED; nome EXISTS | `server/Farming/SFarmingSystem.lua:143`; mapa por `ConfigOption.getName()` (`SandboxOptions.addOption`), nomes em `SandboxOptions$ZombieLore.<init>`. Faixas: Speed 1–4, Sight/Hearing 1–5, Cognition 1–4 |
| `option:setValue(v)` | EXISTS, **seguro** | `IntegerConfigOption.setValue(I)`: ignora fora da faixa, grava o campo, `invokeOnChangeEvent()` só chama callback se houver — e só `Core` registra callback (opções do jogo). **Não sincroniza nem salva**: envio é `SandboxOptions.sendToServer()`, gravação é `saveGameFile`/`saveCurrentGameBinFile`. Fica seguro se a troca e a volta acontecem na mesma chamada Lua |
| `z:DoZombieStats()` | EXISTS | relê `sight`/`hearing` **sempre** (1..3 do sandbox; 4 = `Rand(3)+1`, 5 = `Rand(2)+2`); `cognition` só se o sandbox é 1 (vira 1) ou 4 (re-sorteia); **`strength` só se o campo ainda é -1**; `memory` com o campo em -1 **ou sempre** que o sandbox é 5/6 (aleatório: `Rand(4)` / `Rand(3)+1` escolhe 1250/800/500/25); termina em `doZombieSpeed()` e `initCanCrawlUnderVehicle()` (re-sorteio) |
| `z:doZombieSpeed(t)` | EXISTS | `determineZombieSpeed(t)` devolve `t` se `t ≠ -1` (senão relê o sandbox). `doZombieSpeedInternal`: `lore.speed==3 ou t==3` → arrastado; senão 2/3 de chance de `doFakeShambler(t)` (`speedType = t`); senão `lore==2 ou t==2` → rápido; senão `lore==1 ou t==1` → corredor. **O sandbox vence o argumento**: com sandbox "Arrastados" nenhum `t` promove sem trocar `ZombieLore.Speed` |
| `z:getSpeedType()` | EXISTS | 1 corredor, 2 rápido, 3 arrastado (`doSprinter/doFastShambler/doShambler`) |
| `z:isCanCrawlUnderVehicle()` / `setCanCrawlUnderVehicle(b)` | EXISTS | o mod devolve o valor que o `DoZombieStats` re-sorteia |
| `z:DoZombieSpeeds(f)` | EXISTS, **evitar** | concatena em `walkVariant` a cada chamada (cresce a string) |
| `z:makeInactive(b)` | EXISTS | é o `ActiveOnly` vanilla: `IsoZombie.updateActiveState` chama `makeInactive(GameTime.isZombieInactivityPhase())` a cada update; volta cedo se nada mudou; `true` → `speedType = 3` + `doZombieSpeed()`, sem reafirmar depois; `false` → `speedType = -1` + `DoZombieStats()`. `determineZombieSpeed(t)` só olha o `inactive` com `t = -1`: `doZombieSpeed(t)` acorda zumbi inativo. O mod não mexe na velocidade na fase inativa |
| `getGameTime():isZombieInactivityPhase()` | EXISTS | público em `GameTime` |
| `lunger` | sem getter/setter | `doFastShambler`/`doSprinter` (e `addZombiesInOutfit`) ligam; nada no dono desliga; o remoto copia do pacote (`NetworkZombieVariables.setBooleanVariables`). Zumbi promovido segue dando bote até ir pro virtual |

Força: **impossível por zumbi depois de nascer.** `createZombieOutsideWorld` chama
`DoZombieStats` (offset 421) antes do `OnZombieCreate`, e o `strength` só é sorteado
com o campo em -1. E o campo só é lido contra porta/janela/barricada/carro
(`IsoDoor`, `IsoWindow`, `IsoBarricade`, `AttackVehicleState`).

Visão: `getVisionRadiusAdjusted` = `20 − max(luz, chuva+névoa)`, ×1.75 se
`sight==1` **ou sandbox==1**, ×0.35 se `sight==3` **ou sandbox==3**, ÷ item vestido;
`updateVisionRadius` prende entre 10 e 20. Audição: `WorldSoundManager.getHearingMultiplier`
= 3.0 / 1.0 / 0.45 pelo campo `hearing` do zumbi, × item vestido × clima.

Receita usada (troca e volta na mesma chamada, volta garantida por `pcall`;
Kahlua `pcall` pega `Throwable` em `KahluaThread.pcall`):
`Speed = degrau, Sight/Hearing = degraus, Cognition = 2, Memory = 2 (neutros)` →
`z:DoZombieStats(); z:doZombieSpeed(degrau)` → restaura → devolve `canCrawlUnderVehicle`.

**MP (resolvido por bytecode, falta o jogo):** zumbi remoto copia `walkType` e
`speedMod` do pacote (`NetworkZombieAI.parse` com `isRemoteZombie()`), o servidor
aceita o do dono (`NetworkZombiePacker.applyZombie`). Mudança só no servidor é
sobrescrita. Sentidos são campos locais, lidos por quem simula. O cliente recebe
`OnZombieCreate` (`NetworkZombieSimulator.parseZombie` → `createRealZombieAlways`).
Por isso a [ADR-005](adr-005-quem-simula-aplica.md).

### 2.2 Dano

**Não há dano por zumbi.** `BodyDamage.AddRandomDamageFromZombie` lê o
`ZombieLore.Strength` **global** na hora do golpe (offsets 151–190), na máquina que
simula o zumbi (`AttackState.triggerPlayerReaction` 367–400, que antes faz
`setAttackedBy(zumbi)`); o valor do dano em si é sorteado sem olhar o zumbi.
`OnPlayerGetDamage` só dispara de `BodyDamage.Update`/`BodyPart.DamageUpdate`
(veneno, fome, doença, sangramento, sede), nunca com o zumbi. Trocar o sandbox
global a noite inteira vazaria pro save e pros Ecos. **Decisão do autor (2026-10-04):
não fazer** ([night.md](../gdd/night.md#sem-força-e-sem-dano-à-noite)).

### 2.3 Mandar o zumbi para um ponto

| API | Status | Evidência |
|---|---|---|
| `addSound(source, x, y, z, radius, volume)` (global) | CONFIRMED | `server/Camping/SCampfireSystem.lua:162`, `server/Traps/STrapGlobalObject.lua:130`; chama `WorldSoundManager.addSound(Object,IIIII)` |
| `addSound` no servidor dedicado | EXISTS | `WorldSoundManager.addSound(...S)` 264–330: põe na lista, no popman (`addWorldSound`) e manda `GameServer.sendWorldSound` aos clientes |
| `z:pathToLocationF(x, y, z)`, `z:pathToSound(x, y, z)`, `z:setTarget(obj)` | EXISTS | só valem no dono; não usados |

Usado: `addSound` no servidor (caça e lanterna). O alcance real é `raio ×
getHearingMultiplier(zumbi)` em quem simula (`WorldSoundManager.getSoundAttract`):
a audição apurada da noite triplica. O mod passa `alcance / multiplicador do degrau
noturno` (`NOM_NightRules.soundRadius`) pra o alcance efetivo ser o configurado;
roupa e clima (também no multiplicador) não são compensados.

### 2.4 Lanterna ligada

| API | Status | Evidência |
|---|---|---|
| `player:getActiveLightItem()` | EXISTS | mão direita, esquerda ou item preso com `isEmittingLight()` (= `canEmitLight` e, se ativável, `isActivated`) |
| liga/desliga chega ao servidor | CONFIRMED | `syncItemActivated` em `client/ISUI/ISInventoryPaneContextMenu.lua:2883`, `client/Hotbar/ISHotbar.lua:556` |
| `square:isOutside()` | CONFIRMED | `server/Farming/SFarmingSystem.lua:156` |

Não há alcance de visão por zumbi além dos degraus (e o teto é 20). Aproximação
usada: chamado sonoro (`addSound`) de `20 × NightSenseMult` na posição do jogador
com luz ativa ao ar livre, a cada 5 minutos de jogo à noite.

---

## 3. Variantes (sprints 0004/0005)

### 3.1 Persistir a variante

Fato transversal 3: `zombie:getModData()` existe e funciona em memória, mas morre quando o zumbi
vira virtual e não sincroniza no MP. O que sobrevive é `z:getPersistentOutfitID()` (EXISTS;
`ZombiePopulationManager` lê esse valor ao virtualizar).

**Formato do `persistentOutfitID` (sprint 0002, bytecode `PersistentOutfits.pickOutfitMale/getOutfit/applyOutfit`):**
bit 31 = feminino, bits 16–30 = índice do outfit na lista `all` (ordenada por nome, refeita a
cada boot, então muda se a lista de mods muda), bits 0–15 = semente (0 se o outfit não usa
semente, senão 1..500). Outfit inexistente → 0. No `OnZombieCreate` de um zumbi recarregado o
visual está limpo e `getOutfitName()` volta `nil`; `z:dressInPersistentOutfitID(id)` (público)
veste pelo ID e aí o nome responde. `IsoZombie.resetForReuse` faz `getModData():wipe()`, então
`modData` em memória de zumbi reaproveitado não vaza.

Recomendado: **variante derivada, não armazenada.**
`variant = f(persistentOutfitID, worldSeed)` determinístico, reaplicado em:
- `Events.OnZombieCreate.Add(function(z) ... end)`: dispara em todo zumbi que vira real,
  inclusive ao recarregar do virtual (bytecode `VirtualZombieManager.createRealZombieAlways`).
  EXISTS, sem uso vanilla.
- clientes: no `OnZombieUpdate` (CONFIRMED como evento; disparado em `IsoZombie.updateInternal`),
  checar um cache por `getOnlineID()`/objeto e aplicar uma vez.
Fallback: tabela global (`ModData.getOrCreate`, CONFIRMED `server/Foraging/forageServer.lua:26`)
chaveada por `persistentOutfitID`, com o risco de colisão (o ID mistura outfit e um aleatório).
Ecos não precisam disso: só existem durante a noite e são removidos no amanhecer.

**Resolvido na sprint 0004 (bytecode): o cliente recebe o mesmo `persistentOutfitID`.**
`ZombiePacket.set(IsoZombie)` grava `getPersistentOutfitID()` em `outfitId` (offsets 15–18),
`write/parse` levam o campo, e `NetworkZombieSimulator.parseZombie` (140–152) cria o zumbi com
`VirtualZombieManager.createRealZombieAlways(outfitId, dir, false, 0)` →
`PersistentOutfits.getOutfit(id)` (devolve o mesmo ID quando válido; só re-sorteia semente fora de
1..500) → `createZombieOutsideWorld`. O `OnZombieCreate` do cliente dispara antes do `onlineId`
ser setado (209). Usado como base da [ADR-006](adr-006-variantes-deterministicas.md):
variante = f(`persistentOutfitID`, número da noite), calculada igual no servidor e nos clientes.

### 3.2 Estalador (cego, só ouve)

- Não há "cegueira". `sight` só vai até Poor (3). `getVisionRadiusAdjusted` multiplica por
  `getWornItemsVisionModifier()` (bytecode), que vem do item vestido; vanilla usa
  `VisionModifier = 0.75` em óculos (`media/scripts/generated/items/clothing.txt:891`).
  Um item próprio do mod com `VisionModifier` baixo, vestido no zumbi, reduz visão. Existe um
  `PZMath.clamp` no fim de `updateVisionRadius` que pode impor piso: UNKNOWN.
- `z:setUseless(true)` (CONFIRMED) faz o zumbi ignorar tudo (checado em `ZombieIdleState`,
  `WalkTowardState.enter`, `RespondToSound`). Mata a audição também: só serve para cego em
  janela curta (abaixo).
- **Usado na sprint 0004 (corrigido no review):** Sight=3 e Hearing=1 via 2.1 + regra Lua no dono.
  A visão "ruim" não cega (piso de 10 tiles em `updateVisionRadius`). O spot:
  `IsoPlayer.TestZombieSpotPlayer` → `IsoZombie.spotted` → `spottedNew`, que faz `setTarget`, guarda
  `spottedLast` e, no spot não forçado, `bonusSpotTime = 720` (1909–1917); o spot forçado também chama
  `pathToCharacter` (2263–2447). `OnZombieUpdate` dispara em `updateInternal` 696, mas entre ele e a
  máquina de estados (`IsoGameCharacter.update`, 1029) o jogo refaz `spotted(spottedLast, true)`
  enquanto `bonusSpotTime > 0` (956–991): **`setTarget(nil)` no evento é desfeito no mesmo frame.**
  O que funciona: `z:setUseless(true)` (CONFIRMED `client/DebugUIs/DebugContextMenu.lua:566,673`,
  `client/Tutorial/Steps.lua:1107`). Com useless, `spottedNew` 191–208 faz `setTarget(null)` e
  `spottedLast = null` e volta: o laço do spot forçado morre. Custos: `RespondToSound` volta cedo
  com useless (8–15), então o zumbi fica surdo enquanto useless; `WalkTowardState.enter` (106) e
  `ZombieIdleState.execute` (191) checam useless, mas um `WalkTowardState` em andamento segue até
  `lastTargetSeenX/Y/Z` (`execute` 169–213), sem alvo e sem ataque. O mod liga useless numa
  janela curta, só enquanto o jogador agachado e silencioso é o alvo, e só desliga o que ligou.
  Outros efeitos do useless: `WalkTowardState.enter` manda pro idle, o idle não perambula, e o
  zumbi sai dos grupos (`ZombieGroupManager`). **O useless viaja na rede** (não é salvo): o dono
  manda `isUseless` em todo pacote (`NetworkZombieAI.set` → `NetworkZombieVariables.getBooleanVariables`
  86–89) e o remoto aplica (`NetworkZombieAI.parse` 204–252, `NetworkZombieSimulator.parseZombie`
  520). Quem assume a posse no meio da janela herda o useless sem saber: o mod desliga useless de
  Estalador local que ele não ligou, exceto o outfit de debug com "Useless" (`updateInternal` 47–58).
  `isSneaking`, `isRunning`, `isSprinting`: EXISTS (públicos). UNKNOWN: o efeito no jogo da
  caminhada até a última posição vista (roteiro da sprint 0004).
- Clique periódico: ver seção 4 (`sendPlaySound` no servidor / `z:playSound` no solo).
- Agarrão letal: **não existe caminho por golpe** (sprint 0004). `AttackState.triggerPlayerReaction`
  → `BodyDamage.AddRandomDamageFromZombie(zumbi, …)` lê do zumbi só `crawling`, `inactive`,
  `scratch`/`laceration` e `cantBite()`, e o `ZombieLore.Strength`/`ZombiesDragDown` globais;
  nenhum evento Lua no caminho. `OnPlayerGetDamage` sai de `BodyDamage.Update` (POISON, HUNGRY,
  SICK, BLEEDING, THIRST), `IsoGameCharacter.Hit` (arma), queda, fogo e carro;
  `OnWeaponHitCharacter`/`OnHitZombie` saem de `Hit` com arma. Sobra só observar a vida do
  jogador e `getAttackedBy()` (EXISTS) depois do golpe — não feito (pendência).

### 3.3 Corredor (sprinter que grita)

Velocidade via 2.1 (`Speed = 1`). Grito: `sendPlaySound("NOM_CorredorScream", false, z)` no
servidor (CONFIRMED `server/Fishing/BuildingObjects/FishingNet.lua:86`) ou
`z:getEmitter():playSound(...)` no solo (CONFIRMED `shared/TimedActions/ISDrinkFluidAction.lua:34`),
mais `addSound(z, x, y, z, raio, volume)` para puxar a horda (2.3).

**Sprint 0004:** o servidor não sabe o alvo do zumbi no MP (o `target` não viaja; `PFBData` só
restaura o caminho no cliente que assume a posse, `NetworkZombieMind.doRestorePFBTarget`). O dono
vê a borda "pegou um jogador de alvo" no `OnZombieUpdate` e manda `corredorSaw` com o `onlineID`;
o servidor confere a variante, a distância de quem avisou (`player:DistTo(x, y)` ≤ 25, CONFIRMED
`client/Vehicles/TimedActions/ISDetachTrailerFromVehicle.lua:34`), um aviso a cada 2 s reais por
jogador (`getTimestampMs()`, CONFIRMED `server/ISObjectClickHandler.lua:352`) e o cooldown, e grita.
O limite de 2 s roda antes da validação: um segundo aviso legítimo do mesmo jogador em menos de
2 s (outro Corredor) é descartado. Aceito: o grito do primeiro já chamou a horda.

### 3.4 Sem-rosto (some quando visto ou iluminado)

**Verificado na sprint 0005** (bytecode B42.20.4). Implementado em `shared/NOM_SemRosto.lua`
e `server/NOM_Fog.lua`; decisão na [ADR-007](adr-007-sem-rosto-e-atmosfera-local.md).

Testes de "está sendo visto":

| API | Lado | Status | Evidência |
|---|---|---|---|
| `square:isCanSee(pn)` | cliente | EXISTS, **usado** | bit 2 de `LightingJNI$JNILighting.vis` (linha de visão + cone + luz). É o teste do jogo pra "o jogador vê este zumbi": `IsoZombie.checkZombieEntersPlayerBuilding` 26–44 (`getCurrentSquare().isCanSee(playerIndex)`), `canSeeHeadSquare` |
| `square:isCouldSee(pn)` | cliente | CONFIRMED, **usado** | `server/FireFighting/ISExtinguishCursor.lua:48`; bit 4 do `vis` (linha de visão/cone, sem luz). "Fora da vista" do destino |
| `square:isSeen(playerNum)` | cliente | CONFIRMED | `server/ISObjectClickHandler.lua:10` (memória: já foi visto) |
| `IsoGameCharacter.TestIfSeen(pn, player)` | cliente | **protegido** (0x4) | distância ≤ `getViewDist`, `isCouldSee`/`isCanSee` (ou `ServerLOS` no servidor), luz ≥ 0.6, `getDotWithForwardDirection`; zera o `targetAlpha` quando falha (`updateSeenVisibility`). Não alcançável do Lua |
| `z:getTargetAlpha(pn)` | cliente | EXISTS | zerado por `updateSeenVisibility`; quem sobe é o render do square. Não usado (depende da ordem de render) |
| `player:CanSee(obj)` | ambos | EXISTS | só `LosUtil.lineClear`, sem luz e sem cone: no escuro todo zumbi à frente "seria visto" |
| `player:getForwardDirection():getDirection()` | ambos | CONFIRMED | `shared/Fishing/FishingRod.lua:286` (radianos) |
| `square:isFree(false)` | ambos | CONFIRMED | `client/ISUI/ISWorldObjectContextMenu.lua:2199` |

As funções por `playerNum` dependem do cálculo de luz/LOS do cliente; no dedicado não valem.

Mover o zumbi:

| API | Status | Evidência |
|---|---|---|
| `z:teleportTo(x, y, z)` | EXISTS, **usado no dono** | `IsoGameCharacter.teleportTo(III)`: `setX/Y/Z` com o int (canto do tile), `setLastX/Y`, `ensureOnTile`; sem rede. Sem uso vanilla em Lua. O mod centra depois com `setX/setY/setLastX/setLastY(x + 0.5)` (públicos em `IsoMovingObject`) |
| `square:getProperties():has(IsoFlagType.water)` | CONFIRMED | `server/Fishing/BuildingObjects/FishingNet.lua:31`, `server/BuildingObjects/ISNaturalFloor.lua:59` (água não é chão pro destino) |
| `z:setX/setY/setZ` | EXISTS | `server/ClientCommands.lua:845` usa `animal:setX` |
| `z:setInvisible(true)` | EXISTS | efeito em zumbi UNKNOWN; não usado |
| `z:dressInPersistentOutfitID(id)` | EXISTS, **fallback** | grava `persistentOutfitId` e veste (`PersistentOutfits.dressInOutfit`) |
| `z:isFemale()` | EXISTS | `IsoGameCharacter.isFemale` (final, público) |

**Resolvido na sprint 0005 (bytecode): teleporte no servidor volta; no dono, vale.**
`NetworkZombiePacker.parseZombie` (servidor) ignora o pacote de quem não é dono (64–88:
`getOwner() != conexão` → `recheck` e sai) e `applyZombie` aplica `realX/realY/realZ` do dono
direto (`setX/setNextX/setLastX`, 41–97), sem conferir distância. No cliente, a cópia remota
recebe a posição como alvo (`NetworkZombieAI.parse` 51–80: `targetX/targetY`, ou
`pathToLocationF` com `usePathFind`) e anda até ela; `IsoZombie.moveUnmodded` (181–283) acelera
até 2× (`smoothstep(0.5, 1.5, dist)`). Ou seja: **teleporte no dono é aceito pelo servidor, e as
outras cópias deslizam até lá**. UNKNOWN: como fica na tela de um terceiro jogador.

### 3.5 Outfits

- Mod pode trazer `media/clothing/clothing.xml` próprio: `OutfitManager` itera
  `ZomboidFileSystem.getModIDs()` e loga `mod "%s" overrides male outfit "%s"` (bytecode, strings).
  No B42 os arquivos do mod ficam nas pastas `42/` ou `common/` (bytecode
  `ChooseGameInfo$Mod.getVersionDir()/getCommonDir()`). Itens de roupa novos vão em
  `media/clothing/clothingItems/*.xml` + script de item.
- Para spawn por nome, não é preciso registrar em `ZombiesZoneDefinition` (só define spawn natural
  por zona, `shared/NPCs/ZombiesZoneDefinition.lua:596`, `:1815`).
- Outfits vanilla existentes (`media/clothing/clothing.xml`) úteis por referência:
  - paciente/fantasma: `HospitalPatient`, `HospitalPatientBathrobe`, `Bathrobe`, `NakedVeil`, `CostumeMonsterBride`
  - nu: `Naked`
  - padre: `Priest`
  - Não há outfit "queimado" nem "enfaixado". Queimado: `onFire` no spawn ou `z:setSkeleton(true)`
    (EXISTS); enfaixado: `z:addVisualBandage(BodyPartType, bool)` / `addRandomVisualBandages()` (EXISTS).

---

## 4. Sons

### 4.1 Declarar som próprio

Formato (CONFIRMED `media/scripts/generated/sounds/zombies/sounds_zombie_voice_tutorial.txt:1-12`):
```
module Base
{
    sound NevoaClick
    {
        category = Zombie,
        clip
        {
            file = media/sound/nevoa_click.ogg,
            distanceMax = 30,
        }
    }
}
```
Campos aceitos no parser (strings de `GameSoundScript`): `category, is3D, loop, master,
maxInstancesPerEmitter, clip, distanceMin, distanceMax, event, file, pitch, volume,
reverbFactor, reverbMaxRange, stopImmediate`. Formatos: `.ogg` e `.wav` (vanilla tem 211 `.ogg` e
401 `.wav` em `media/sound`; `GameSounds.getOrCreateSound` trata as duas extensões). Caminho
resolvido por `FMODManager.loadSound` → `ZomboidFileSystem.getAbsolutePath`, que enxerga a pasta
`media/` do mod (EXISTS). Quase todo som vanilla usa `event` (banco FMOD); `file` é o caminho de
mod.

### 4.2 Tocar no mundo para os jogadores

| API | Onde | Status | Evidência |
|---|---|---|---|
| `sendPlaySound(name, loop, movingObj)` | servidor → clientes próximos | CONFIRMED | `FishingNet.lua:86`; bytecode: só age se `GameServer.server`, via `sendToRelative` |
| `playServerSound(name, square)` | servidor | CONFIRMED | `STrapGlobalObject.lua:120`; bytecode chama `GameServer.PlayWorldSoundServer` |
| `getSoundManager():PlayWorldSound(name, square, 0, radius, volume, true)` | cliente/SP (em cliente MP também avisa o servidor) | CONFIRMED | `shared/Farming/TimedActions/ISShovelAction.lua:30`; bytecode chama `GameClient.PlayWorldSound` |
| `character:getEmitter():playSound(name)` / `z:playSound(name)` | local | CONFIRMED | `shared/TimedActions/ISLockDoor.lua:22` |

Som audível **não** atrai zumbi. Atração é `addSound` (2.3), separado.
Recomendado: helper `if isServer() then sendPlaySound(n, false, z) elseif not isClient() then z:playSound(n) end`.

**Sprint 0005 (bytecode): `emitter:playSound(nome)` não é local no cliente de MP.**
`FMODSoundEmitter.playSound(String)` (0–104), com `GameClient.client` e o dono do emitter
sendo `IsoMovingObject`, manda `PacketType.PlaySound` (ou `GameClient.PlayWorldSound`) antes
de tocar; `stopSound(id)` chama `sendStopSound`. Isso vale pro emitter de zumbi também: o
estalo do Estalador (`z:getEmitter():playSound`, tocado em toda cópia local, sprint 0004) sai
de cada cliente pra rede. **Corrigido na sprint 0005:** o estalo usa `z:playSoundLocal`
(= `getEmitter().playSoundImpl(nome, null)`, sem pacote).

### 4.3 Som 2D/ambiente só para o jogador local

| API | Status | Evidência |
|---|---|---|
| `player:playSoundLocal(name)` → id | CONFIRMED, **usado** | `client/ISUI/Maps/ISMap.lua:210`; bytecode `IsoGameCharacter.playSoundLocal` = `getEmitter().playSoundImpl(name, null)`, sem pacote |
| `player:getEmitter():setVolume(id, v)` | CONFIRMED (bytecode), **usado** | `CharacterSoundEmitter.setVolume(JF)` → `FMODSoundEmitter.setVolume` guarda o volume da instância; `FMODSoundEmitter$FileSound.tick` aplica todo tick com `FMOD_Channel_SetVolume(channel, getVolume())` (168–175) |
| `player:getEmitter():stopSoundLocal(id)` | EXISTS, **usado** | `FMODSoundEmitter.stopSoundLocal(J)`: para e solta, sem `sendStopSound` |
| `player:getEmitter():isPlaying(id)` | EXISTS, **usado** | `FMODSoundEmitter.isPlaying(J)` |
| `getSoundManager():playUISound(name)` → id | CONFIRMED | `server/BuildingObjects/ISMoveableCursor.lua:179`; local (`uiEmitter.playClip`), mas sem controle de volume pelo Lua |
| `getSoundManager():stopUISound(id)`, `isPlayingUISound(id)` | EXISTS | bytecode `SoundManager` |

Loop: `loop = true` no nível do `sound` (como `media/scripts/generated/sounds/sounds_ambience.txt:3-11`).
CONFIRMED (bytecode) pra clip de `file`: `FMODSoundEmitter$FileSound.tick` (5–24) chama
`FMOD_Channel_SetMode(channel, 2)` (FMOD_LOOP_NORMAL) quando `GameSound.isLooped()`. O mod
ainda toca de novo se `isPlaying(id)` cair (som cortado pelo jogo).

## 5. Overlays de chão locais (sprint 0005)

| Opção | Local? | Salva? | Status | Evidência |
|---|---|---|---|---|
| `getIsoMarkers():addIsoMarker(spriteName, square, r, g, b, a)` → marker; `marker:remove()`, `setAlpha`, `setPos` | só cliente | não | CONFIRMED, **usado** | `client/Foraging/ISBaseIcon.lua:577`, `:559`; bytecode abaixo |
| `getWorldMarkers():addGridSquareMarker(...)` | só cliente | não | CONFIRMED | `client/ISUI/Maps/ISWorldMap.lua:1457` (versão com coordenadas no mapa); bytecode tem `(String tex, String overlay, IsoGridSquare, r,g,b, doAlpha, size)` |
| `addBloodSplat(square, n[, dx, dy])` | sem envio de rede | **salva** no chunk (SP) | CONFIRMED | `shared/TimedActions/Animals/ISRemoveMeatFromAnimal.lua:121`; bytecode `IsoChunk.addBloodSplat` → `floorBloodSplats`, salvo por `IsoFloorBloodSplat.save` |
| `obj:addAttachedAnimSpriteByName`, `setOverlaySprite` em objeto do square | mexe no objeto do mapa | salva/sincroniza | EXISTS | bytecode `IsoObject`; **evitar** |

**Verificado na sprint 0005 (bytecode `IsoMarkers`):** `addIsoMarker(String, IsoGridSquare, FFFF)`
volta `null` no servidor (offset 0, `GameServer.server`), cria um `IsoMarker`, `setSquare`,
`init(nome, …)` (que acha a textura com `Texture.trygetTexture(nome)`) e põe na lista
`IsoMarkers.markers`, em memória. A classe só tem `reset/update/render/add/remove/get`: nenhum
`save`/`load`, nenhum pacote. `update()` só tira da lista o marcador com `isRemoved()`. O
marcador não é objeto do square. Usado em `client/NOM_FogOverlays.lua`.

Sprites vanilla de overlay de chão (nomes `<tileset>_<índice>`):
- `overlay_blood_floor_01_0` … `_27` e `_32` … `_46` (em `media/tileDepthTextureAssignments.txt`)
- `overlay_grime_floor_01_0` … `_95` (mesmo arquivo)
- `floors_overlay_tiles_01_*`, `floors_overlay_tiles_02_0..15` (`server/Items/FloorTileOverlays.lua:4`)
- `d_floorleaves_1_*`, `floors_burnt_01_*` (tilesets em `media/tiledefinitions_overlays.tiles`)
Validar cada nome com `getTexture(name) ~= nil` (`LuaManager.GlobalObject.getTexture` =
`Texture.getSharedTexture`). UNKNOWN: se a textura de tile é achada pelo nome antes de o mundo
carregar; o mod valida só na primeira mancha.

## 6. Spike de shader

- Carga: `ShaderProgram` monta `media/shaders/<nome>[_static][_instanced].vert|.frag`
  (strings do bytecode) e `ShaderUnit.preProcessShaderFile` lê via
  `IndieFileLoader.getStreamReader` → `ZomboidFileSystem.getString(path)`, que consulta
  `activeFileMap`, o mapa de overrides dos mods. **Um mod consegue sobrescrever um shader
  existente** colocando `media/shaders/screen.frag` (por exemplo) na sua pasta. EXISTS.
- UNKNOWN: se o shader já foi compilado antes de o mod ativar (os shaders de cena nascem no boot;
  os mods ativam ao carregar o save). Teste: override com cor absurda, ver se aparece.
- **Adicionar** shader novo: não dá por Lua. `Shader`/`ShaderProgram` não estão no Exposer;
  só Java cria programas por nome.
- Override é frágil: substitui o shader para todo mundo, quebra a cada patch e conflita com outros
  mods. Fica como último recurso (alinha com ADR-004).
- **Hook Lua de pós-processamento que já existe: `SearchMode`** (o modo de busca do forrageamento).
  `screen.frag` é o pós-processo de cena (`SceneShaderStore` usa `screen` e `blur`) e tem uniforms
  como `DesaturationVal`, `BlurFactor`, `DrunkFactor`, `NightVisionGoggles`, `SearchMode`.
  Lua controla vinheta/blur/dessaturação/escurecimento por jogador:
  - `getSearchMode():getSearchModeForPlayer(pn)` (CONFIRMED `client/Foraging/ISSearchManager.lua:1346`)
  - `psm:getBlur()/getDesat()/getRadius()/getGradientWidth()/getDarkness()` (CONFIRMED
    `client/DebugUIs/DebugMenu/General/ISSearchMode.lua:38-42`), cada um um `SearchModeFloat`
    com `set(...)`, `setTargets(ext, int)`, `setExterior/Interior` (EXISTS)
  - `getSearchMode():setOverride(pn, true)` / `setEnabled(pn, true)` (CONFIRMED `ISSearchMode.lua:268-270`)
  Conflita com o forrageamento real (o `ISSearchManager` checa `isOverrideSearchManager`, `:1102`).
  **Recomendação para efeito de tela: SearchMode antes de qualquer shader.**
- **Sprint 0005:** vinheta da névoa em `client/NOM_FogVignette.lua`, como o spike propôs:
  `getSearchMode():setEnabled(pn, true)` + alvos por `setTargets`, e
  `ISSearchManager.getManager(player).isOverride = true` (`ISSearchManager.lua:68`, `:1056`)
  só durante a névoa e enquanto `manager.isSearchMode` (forrageamento, `:1416-1428`) é falso.
  `SearchMode.isEnabled(I)` existe (bytecode) e guarda o estado de antes quando o override
  era de outro.
- Neblina: `ClimateManager` (exposto) e `zombie/iso/weather/fog/ImprovedFog` (exposto) são o
  caminho da ADR-004.

---

## 7. Eventos

| Evento | Params | Onde dispara | Status | Evidência |
|---|---|---|---|---|
| `OnTick` | (ticks) | SP e dedicado | CONFIRMED (evento, `server/Foraging/forageServer.lua:502`); dedicado EXISTS | `IngameState.onTick`; `GameServer` instancia `IngameState` e chama `update()` → `updateInternal` → `onTick` (bytecode) |
| `EveryOneMinute`, `EveryTenMinutes`, `EveryHours`, `EveryDays` | — | onde `GameTime` roda (ambos) | CONFIRMED | `server/XpSystem/XpUpdate.lua:375`, `server/Camping/SCampfireSystem.lua:183` |
| `OnDawn`, `OnDusk` | — | **nunca** | morto | só disparados em `server/Seasons/season.lua:314,318`, dentro de bloco comentado; nenhuma classe Java dispara |
| `OnZombieDead` | (zombie) | `IsoZombie.onKilled`, antes do corpo | CONFIRMED | `Steps.lua:840` |
| `OnDeadBodySpawn` | (body) | construtor de `IsoDeadBody`, **nunca no servidor dedicado** | CONFIRMED | `ISWorldObjectContextMenu.lua:2782`; bytecode `IsoDeadBody.<init>` 1298–1311 |
| `OnZombieCreate` | (zombie) | `VirtualZombieManager.createRealZombieAlways`, antes de entrar em `getZombieList()` e, no spawn por Lua, antes de vestir | EXISTS | bytecode |
| `OnZombieUpdate` | (zombie) | `IsoZombie.updateInternal` (696), antes da máquina de estados (1029) | EXISTS | bytecode; caro, filtre cedo |
| `OnHitZombie` | (zombie, wielder, bodyPart, weapon) | `IsoZombie.Hit` | CONFIRMED | `shared/Definitions/DamageModelDefinitions.lua:24,69` |
| `OnPlayerUpdate` | (player) | `IsoPlayer` | EXISTS | bytecode |
| `OnGameStart` | — | `IngameState` (cliente/SP) | CONFIRMED | `shared/TimedActions/ISGrabCorpseAction.lua:168` |
| `OnServerStarted` | — | `GameServer` (só dedicado) | EXISTS | bytecode |
| `OnInitGlobalModData` | (isNewGame) | `GlobalModData` (ambos) | CONFIRMED | `server/Vehicles/ProfessionVehicles.lua:343-350` |
| `OnCreatePlayer` | (playerNum, player) | cliente | CONFIRMED | `client/ISUI/PlayerData/ISPlayerData.lua` |
| `OnClientCommand` | (module, command, player, args) | servidor (e SP) | CONFIRMED | `server/ClientCommands.lua:1296,1307` |
| `OnServerCommand` | (module, command, args) | cliente | CONFIRMED | `client/ServerCommands.lua:218` |

Comandos:
- cliente → servidor: `sendClientCommand(module, command, args)` (ou com `player` como 1º arg).
  Em SP vira `OnClientCommand` local (bytecode `SinglePlayerClient`). No servidor lança
  `IllegalStateException("can't call this function on the server")`.
- servidor → cliente(s): `sendServerCommand(module, command, args)` para todos,
  `sendServerCommand(player, module, command, args)` para um (CONFIRMED `server/ClientCommands.lua:477`,
  `server/BuildingObjects/ISWoodenFloor.lua:21`).
- `args` é tabela Lua simples (números, strings, booleanos, subtabelas). Objetos Java não viajam:
  mande `getOnlineID()` / coordenadas.

Noite/amanhecer: `OnDawn/OnDusk` não servem. Use `EveryOneMinute` com
`getGameTime():getTimeOfDay()` comparado a `getClimateManager():getSeason():getDawn()/getDusk()`
(CONFIRMED `shared/Farming/TimedActions/ISPlowAction.lua:170`) e detecte a borda guardando o estado
anterior no `ModData` global.

Jogadores no servidor: `getOnlinePlayers()` no dedicado; `getNumActivePlayers()` +
`getSpecificPlayer(i)` em SP (CONFIRMED `XpUpdate.lua:294-297`).

---

## 8. Remover o mod de um save (sprint 0006)

**Verificado na sprint 0006** (bytecode B42.20.4). Conclusão: **nada quebra**; o que
fica no save é ignorado pelo jogo. Nenhuma correção foi necessária. Falta o teste no
jogo ([roteiro](../teste-in-game.md)).

O que o mod grava no save e o que acontece sem ele:

| O que fica | Onde | Sem o mod | Evidência |
|---|---|---|---|
| `ModData` global `NevoaEOutroMundo` (`eco.night/inNight/ids/start`, `fog.night/inNight/next/endAt`) | `global_mod_data.bin` | carregado como tabela qualquer e nunca lido: órfão, sem efeito | `GlobalModData.load` lê `nome → createModDataTable()` pra toda chave do arquivo, sem conferir quem é dono (offsets 125–183) |
| `modData` de corpo: `NOM_ecoReleased`, e `NOM_eco` num cadáver de Eco que escapou da remoção | chunk (`IsoMovingObject.save`, §1.2) | chave a mais numa `KahluaTable`; corpo comum | só o mod lê essas chaves |
| A lista de outfits (o mod registra `NOM_Eco`) | todo `persistentOutfitID` salvo (popman, chunk) | o ID guarda o **índice** do outfit (bits 16–30) na lista ordenada por nome, refeita a cada boot. Tirar o `NOM_Eco` desloca em −1 o índice de **todo outfit que vem depois dele** na lista: zumbis virtuais e corpos com esses outfits voltam com a roupa do vizinho, e (com o mod de volta, ou sem) o sorteio das variantes deles muda, porque é função do ID. Instalar o mod num save faz o mesmo no sentido contrário (+1). Índice que cai fora da lista: `PersistentOutfits.getOutfit(I)` devolve 0 (40–58) e `dressInOutfit` sai sem vestir (6–10), zumbi sem roupa. **Nada dá erro**: é o que acontece com qualquer mod que traz outfit (ADR-003) | bytecode `PersistentOutfits` |
| Opções `NevoaEOutroMundo.*` | `map_sand.bin` (save) e `<servidor>_SandboxVars.lua` (dedicado) | `.bin`: `SandboxOptions.load(ByteBuffer)` acha a opção pelo nome e, sem ela, só loga e pula (95–110). `.lua`: `readLuaFile` percorre as opções **conhecidas** e lê cada uma da tabela (`fromTable`, 235–272): chave desconhecida nunca é olhada | bytecode `SandboxOptions` |

O que **não** vai pro save (nada a limpar):

- Camada modded do clima: `ClimateManager.save` grava só os valores de admin
  (`ClimateFloat.saveAdmin`: `isAdminOverride` + `adminValue`; `ClimateColor.saveAdmin` idem).
- Troca do `ZombieLore` (§2.1): volta na mesma chamada.
- `modData` de zumbi, variante, useless, bote: não são salvos (fato transversal 3); o
  zumbi recarregado volta com os stats do sandbox.
- `IsoMarkers` (§5), `SearchMode`/`isOverride` (§6), sons locais: só em memória.
- Estados forçados do `NOM_Debug`: a tabela fica em memória, **mas a noite e a névoa
  forçadas avançam os contadores salvos** (`eco.night`, `fog.night` acima). Num save de
  verdade isso muda o número da noite pra sempre (sorteio das variantes, noite dos
  Ecos): debug só em save descartável.

Recolocar o mod num save que rodou sem ele: o `ModData` órfão volta a valer. Se o save
foi salvo de noite com o mod e reaberto de dia, a primeira leitura do clima fecha a
noite (Aprendizado 6 da sprint 0005). IDs de Eco velhos saem na poda (7 noites).

---

## 9. Publicação: mod.info, traduções e Workshop (sprint 0007)

**Verificado na sprint 0007** (bytecode B42.20.4 e Lua vanilla; conferido de novo contra o 42.21 no review).

**`mod.info`** — `ChooseGameInfo.readModInfoAux` (CONFIRMED pelo bytecode):

- Cada linha casa por `String.contains`, numa cadeia `if/else` nesta ordem (offsets
  152–1325): `name=`, `poster=`, `description=`, `require=`, `incompatible=`,
  `loadModAfter=`, `loadModBefore=`, `id=`, `author=`, `modversion=`, `icon=`,
  `category=`, `url=`, `pack=`, `type=`, `tiledef=`, `versionMax=`, `versionMin=`.
  **Armadilha:** uma linha cujo valor contenha uma chave anterior vira essa chave
  (`url=…?id=…` seria lido como `id=`). Travado por `modinfo_lines_match_own_key`.
- `poster=` (pode repetir) e `icon=` resolvem em `42/` e, se não existir, em `common/`
  (221–272, 652–700). Lista de mods desenha o ícone a 28 px
  (`client/OptionScreens/ModSelector/ModOrderListBox.lua:235`); o poster vai no painel
  de informações (`ModInfoPanelDesc.lua:37`).
- `versionMin=42.20`: `GameVersion.parse` usa `([0-9]+)\.([0-9]+)(.*)` e
  `getInt() = major*1000 + minor`; `Mod.isAvailableSelf` só recusa se
  `versionMin.isGreaterThan(atual)`, que compara `getInt`. 42.20.4 = 42020 e 42.21 = 42021: aceitos.

**Traduções** — `Translator`:

- Nome e descrição do mod traduzidos por `Translate/<LANG>/Mod.json`, chaves `name` e
  `description`, lidos de `common/` e de `42/` (`readModTranslation` e o lambda dele).
  Sem a chave, fica o texto do `mod.info`.
- JSON lido em **modo estrito** (`JSONParserConfiguration.withStrictMode(true)`, em
  `tryFillMapFromFile`): vírgula sobrando é erro ("JSON Error in: …").
- Todo JSON **EN** que não seja `Mod` passa por `cryAboutUnicodeConfusables`, que
  **lança `IllegalStateException`** se achar caractere parecido com ASCII (aspas
  curvas e afins). EN do mod fica só em ASCII (`translations_en_is_ascii`).

**Workshop** — `SteamWorkshopItem` e `client/OptionScreens/WorkshopSubmitScreen.lua`:

- Pasta de upload: `~/Zomboid/Workshop/<nome>/` com `Contents/mods/<mod>/`,
  `preview.png` e `workshop.txt` (é o formato do `Workshop/ModTemplate` que vem com o jogo).
- `readWorkshopTxt`: linhas `version=`, `id=`, `title=`, `description=` (uma por linha,
  juntadas com `\n`; linha vazia vira linha vazia), `tags=` (`;`), `visibility=`
  (`public`, `friendsOnly`, `private`, `unlisted`); `#` e `//` comentam. Tags
  permitidas: `media/WorkshopTags.txt`.
- O jogo **reescreve** o `workshop.txt` (`writeWorkshopTxt`) ao sair da página 2
  (`WorkshopSubmitScreen.lua:351`) e ao criar o item, gravando o `id=` (1157–1158).
  Sem o `id=`, o próximo envio cria outro item.
- **Visibilidade vai em todo envio:** `SteamWorkshop.SubmitWorkshopItem` chama
  `n_SetItemVisibility(item.getVisibilityInteger())`, e a página 2 já vem marcada com o
  `visibility=` do `workshop.txt` (`WorkshopSubmitScreen.lua:300-309`). Tornar público só
  na página do Steam e reenviar com `unlisted` no arquivo **esconde o item de novo**: a
  troca é pela página 2 ([publicar.md §5](../publicar.md#5-abrir-pra-todo-mundo-e-taggear-2-min)).
- `getSubmitDescription` anexa "Workshop ID" e "Mod ID" à descrição. O Steam corta em
  8000 caracteres: o build recusa acima de 7900 bytes.
- `validatePreviewImage`: existe, **até** 1 024 000 bytes (`Files.size`, `lcmp` com a constante `long` 1024000, `ifle` passa: offsets 34–41), PNG
  quadrado de **256 ou 512** px.
- `validateContents`: em `Contents/` só pastas (`mods`, `buildings`, `creative`);
  `validateModFolder`: no mod, pastas `common` ou de versão (`42`, entre a mínima e a
  atual), cada uma com `mod.info` válido (`id=` não vazio) se tiver; arquivo solto é
  ignorado. `validateFileTypes` recusa `.exe .dll .bat .app .dylib .sh .so .zip`
  (menos `pyramid.zip`).
- **Ordem de busca de mods:** `ZomboidFileSystem.getAllModFolders` usa
  `workshop,steam,mods` (pastas de upload, itens inscritos, `~/Zomboid/mods`) e
  `ChooseGameInfo.getModDetails` para no primeiro `id` igual: **a pasta de upload ganha
  do symlink de dev e da inscrição** ([publicar.md](../publicar.md#o-build-ganha-do-symlink)).
- `common/` não é obrigatória pra achar o mod (`getAllModFoldersAux` aceita `mod.info`
  em `common/` **ou** na pasta de versão); o mod manda a dele com `.gitkeep` mesmo assim.
- O `workshop.txt` é lido com `FileReader` (charset padrão); o jogo roda no Java 25
  (`jre64/release`), onde o padrão é UTF-8: título com acento passa.

---

## 10. Render da noite e hora da morte (sprint 0008)

**Verificado na sprint 0008** (bytecode do `projectzomboid.jar` instalado, 42.21;
`ClimateManager.class` e `IsoDeadBody.class` idênticos byte a byte ao jar extraído).
Motivo: no primeiro teste a noite do mod não mudava nada na tela
([ADR-008](adr-008-noite-pela-luz-global.md)).

### 10.1 Quem lê cada canal do clima

`RenderSettings$PlayerRenderSettings.updateRenderSettings(I, IsoPlayer)` copia do
`ClimateManager` os **finais** (offsets 19–88) e monta o que o render usa:

| Canal | Lido por | O que vira | Status |
|---|---|---|---|
| `FLOAT_GLOBAL_LIGHT_INTENSITY` (1) | só gravado em `cmGlobalLightIntensity` (34); lido só por `ThunderStorm.applyLightningForPlayer` | relâmpago | **não escurece nada** |
| `FLOAT_DESATURATION` (0) | `desaturation = cm × (1 − darkness)` (594–606, 805–817) → `WeatherShader` uniform `DesaturationVal` (`startMainThread` 120, `startRenderThread` 122–131) | dessaturação da tela | **zera de madrugada** |
| `FLOAT_DAYLIGHT_STRENGTH` (11) | `darkness = 1 − daylight` (202–209) → `NightValue` do shader (só óculos de visão noturna) e o fator acima | — | vanilla de madrugada: 0 |
| `FLOAT_NIGHT_STRENGTH` (2) | `night` (194–199) → `LightingJNI.stateEndFrame` e o termo do luar no piso | nativo | vanilla de madrugada: 1 |
| `FLOAT_AMBIENT` (9) | `ambient = n + (1 − n) × cm` (411–454), `n` = piso do sandbox + `0.075 × lua × night` (359–375; ×(0.925 − 0.075 × darkness) em interior, 378–398) → `stateEndFrame` e `getSkyLightLevel` | luz ambiente | vanilla de madrugada: 0 (`ClimateValues.updateValues` 1263–1268: `ambient = dayLightStrength`) |
| `COLOR_GLOBAL_LIGHT` (0) | exterior: `blendColor` e `blendIntensity = alfa` (224–246; `isExterior` forçado `true` em 212); `rmod/gmod/bmod = lerp(1, cor dessaturada, alfa)` (662–725) → `IsoGridSquare.rmod`/`IsoObject.rmod` (`applyRenderSettings`), `stateEndFrame` (`LightingJNI.update` 282–332) | **multiplicador da luz** | vanilla de madrugada: sem lua 0.25, lua cheia 0.33, **alfa 0.8** (`mod` 0.40–0.46). O construtor põe 0.33/0.4 (`<init>` 250–323), mas o `server/Climate/ClimateMain.lua:14-22` troca no `OnClimateManagerInit` (disparado no `<init>`, 590, a cada carga), e o `updateValues` mistura sem lua/lua cheia pela lua (1794–1841) |

- **Na névoa**, `updateValues` (1645–1770) puxa a luz global pela intensidade da
  névoa pra `colFog` (com `PerformanceSettings.fogQuality` 2), `colFogNew`, ou
  `colFogLegacy` (sem `SceneShaderStore.weatherShader`); o `ClimateMain.lua:24-34`
  põe 0.2 / 0.5,0.5,0.55 / 0.3, **alfa 0.8** nas três (`mod` 0.36–0.64). Tint de
  névoa mais claro que isso clareia a névoa.
- **Luz do céu**: `GameTime.getSkyLightLevel` (10–77) = `clamp(2 × mod × ambient)` por
  canal, empacotada em RGB e passada ao `stateEndFrame`; mudança invalida as luzes
  globais (`LightingJNI.doInvalidateGlobalLights`, chamado em `getSkyLightLevel` 139–157).
- **Piso do sandbox `NightDarkness`** (tableswitch em 306): 1 "Muito escuro" → 0,
  2 "Escuro" → 0.07, 3 "Normal" → 0.15, 4 "Claro" → 0.25 (padrão 0.15). Somado no
  render, depois do clima: a camada modded **não** muda o piso, mas o `mod` da cor
  multiplica o resultado. O save do teste usa 3 (`map_sand.bin`).
- `screen.frag` (shader de cena, `SceneShaderStore` "screen"): `blendOverlay(Light…)`
  comentado; da cor global só sobra a dessaturação.
- Luzes de prédio sem fonte (`IsoLightSource` com `localToBuilding`, `update`
  145–209) multiplicam por `ambient × mod`; lanterna e poste não.
- Visão do zumbi com alvo: `IsoZombie.updateVisionRadius` 37–116 usa
  `1 − square:getLightLevel` do alvo (até −5 tiles, preso em 10–20).
- A camada modded vale em todo canal: o loop de `ClimateManager.update` (416–478)
  chama `ClimateFloat.calculate`/`ClimateColor.calculate` pra todos;
  `Color.interp` mistura o alfa (34–109). Admin passa por cima (`calculate` 0–21).
  Na chuva, `WeatherPeriod.update` 684–696 faz `globalLight.setOverride(cloudColor, t)`
  sem ser de valor (mistura por cima do nosso interno).
- Admin vanilla: o slider "Darkness" mexe `DAYLIGHT_STRENGTH`, `NIGHT_STRENGTH` e
  `AMBIENT` juntos; a luz tem R/G/B/A (`client/ISUI/AdminPanel/ISAdmPanelClimate.lua:362-380`).
- `ClimateColor.getFinalValue()`, `ClimateColorInfo.getExterior()` e
  `Color.getRedFloat()…getAlphaFloat()`: EXISTS/CONFIRMED (`ISAdmPanelClimate.lua:295`).
- UNKNOWN: o que o nativo faz com `night` e quanto o `mod` escurece na tela. Roteiro
  da sprint 0008.

### 10.2 Hora da morte do corpo

| API | Status | Evidência |
|---|---|---|
| `body:getDeathTime()` → horas de mundo (float) | CONFIRMED | `shared/Definitions/animal/ButcheringUtil.lua:568` |
| gravada na morte | EXISTS | `IsoDeadBody.<init>(IsoGameCharacter,ZZ)` 1333–1341: `GameTime.getWorldAgeHours()`; também os corpos de cenário (`RandomizedWorldBase` usa esse construtor) |
| salva e carregada | EXISTS | `save` 444–449 (`putFloat`), `load` 593–598 (`getFloat`, sem checar versão) |
| `-1` ou futuro → agora | EXISTS | `addToWorld` 128–161: o Lua nunca vê `-1` |
| corpo de cenário | EXISTS | nasce na geração do chunk (`RandomizedWorldBase`) com a hora de então: área explorada pela primeira vez de noite só solta Eco na noite seguinte |
| pegar no colo e largar | EXISTS | `InventoryItem.tryLoadCorpseFromByteData` 101–114: `new IsoDeadBody(cell)` + `load(byteData)` relê `deathTime` e `modData` do corpo humano; só o `CorpseAnimal` (117+) e o fallback `createDefaultDeadBody` recomeçam |
| `getGameTime():getWorldAgeHours()` | CONFIRMED | `ButcheringUtil.lua:594` |

O mod guarda a hora em que a noite abriu (`data.eco.start`, `NOM_NightCount`) e só
solta Eco de corpo com `deathTime` menor. Fallback por `OnZombieDead` não foi
necessário.

### 10.3 Variantes por névoa

Decisão do Johan (05/10/2026): Estalador, Corredor e Sem-rosto só na névoa. A
[ADR-006](adr-006-variantes-deterministicas.md) passa a usar o número do período de
névoa e um sorteio só (faixas contíguas). Nenhuma API nova.

## 11. Névoa como evento (sprint 0009)

**Verificado na sprint 0009** (bytecode do `projectzomboid.jar` instalado, 42.21).
Decisão na [ADR-009](adr-009-nevoa-evento-do-mod.md).

### 11.1 Ordem por minuto de jogo e quem mexe na névoa

`ClimateManager.update` (servidor/solo; o cliente de MP só recebe): `updateSandboxOverrides()`
(377) → `updateValues()` (381) → `weatherPeriod.update()` (392) → `OnClimateTick` (402)
→ `ClimateColor.calculate` / `ClimateFloat.calculate` (411–458) → `updateFx` lê
`fogIntensity.finalValue` (77–83). O nosso `OnClimateTick` é o último a mexer antes do
`calculate`.

| Quem | O que faz no `fogIntensity` | Quando | Evidência |
|---|---|---|---|
| `updateValues` | recalcula o **interno** (névoa natural do dia, ou 0) e, com ele, puxa a luz global pra `colFog*`, a dessaturação, corta nuvem, sobe umidade | todo minuto | 1019–1037, 1144–1149, 1199–1341, 1644–1770 |
| `updateSandboxOverrides` | `fogOverride = (ClimateCycle == 6 && FogCycle != 2) ? 4 : FogCycle`; **na troca**: `setEnableOverride(>1)`, `setOverrideValue(>1)`; `== 2` → `setOverride(0, 1)`; `>= 3` → `overrideInternal = 0.5` e `setOverride(Rand(0.1, 1), t)` a cada hora | troca do sandbox; hora | 471–675 |
| `WeatherPeriod.updateCurrentStage` | `setOverride(0, linearT)`, `setOverride(0, 1)`, `setOverride(fogStrength, t)` (estágios de névoa) | todo minuto com período ativo (`update` 354) | 114–125, 334–339, 895–906, 963–1010, 1259–1300 |
| admin (painel de clima) | `isAdminOverride` → `final = adminValue` e sai | sempre que ligado | `ClimateFloat.calculate` 0–21 |

`ClimateFloat`: `setOverride(FF)` grava valor, `interpolate` e **liga** `isOverride` (0–15);
`setOverrideValue(Z)` grava `isOverrideValue` e `isOverride` (0–10); `setEnableOverride(Z)`
só grava `isOverride` (0–5); `isEnableOverride()` lê (EXISTS, já usado na sprint 0001).
`ClimateManager.save` grava só o admin (`saveAdmin`, 167–172): desligar o override não
vai pro save. `getFogIntensity()` = `finalValue` (0–7); `updateViewDistance` lê o final (9–12).

**Uso (sprint 0009):** no `OnClimateTick`, camada modded da névoa sempre ligada, valor
absoluto (0 ou a densidade do evento), `setModdedInterpolate(1)` e
`setEnableOverride(false)` se `isEnableOverride()`. O `calculate` do minuto inteiro dá o
valor do mod. O cinza que a névoa natural põe na luz (`updateValues`) **fica**: é o que o
`FogCycle` "Sem névoa" da vanilla também deixa.

### 11.2 Tempo real e pausa

| API | Status | Evidência |
|---|---|---|
| `getTimestampMs()` no servidor | CONFIRMED | `server/ISObjectClickHandler.lua:352` |
| `isGamePaused()` | CONFIRMED | `client/ISUI/ISJoystickButtonRadialMenu.lua:68`; `GlobalObject.isGamePaused` → `GameTime.isGamePaused` (0–63): dedicado = `Players` vazio e `PauseEmpty`; cliente de MP = `GameClient.IsClientPaused`; solo = velocidade 0 |
| `OnTick` | CONFIRMED | `IngameState.onTick` (0–11) só dispara o evento. No dedicado vazio com `PauseEmpty` o `OnTick` **para de todo** (`IngameState.updateInternal` 888–943); o primeiro tick depois traz um `dt` enorme, que o teto de 1 s por frame (`NOM_FogEventRules.MAX_STEP_MS`) absorve |
| `getGameTime():getWorldAgeHours()` | CONFIRMED | `shared/Definitions/animal/ButcheringUtil.lua:594` |
| `ZombRand(n)` | CONFIRMED | uso vanilla amplo; inteiro em `[0, n)` |

### 11.3 Sirene

Tocada por `player:playSoundLocal("NOM_Siren")` + `getEmitter():setVolume(id, 1)` no
jogador 0 (§4.3): sem pacote, sai da posição do próprio jogador, então se ouve em
qualquer lugar. Som declarado com `file = media/sound/NOM_Siren.ogg` (§4.1), sem `loop`
e sem `master` (volume de efeitos). No MP o servidor manda `sendServerCommand(MODULE,
"siren", {})` e cada cliente toca a dele. UNKNOWN: se o emitter do jogador pausa o som
com o jogo pausado (a contagem para de qualquer jeito).

## 12. Névoa vermelha (sprint 0010)

**Verificado na sprint 0010** (bytecode do `projectzomboid.jar` instalado, 42.21).
Decisão na [ADR-010](adr-010-nevoa-vermelha.md).

### 12.1 Cor da névoa (`COLOR_NEW_FOG`)

| Fato | Status | Evidência |
|---|---|---|
| A névoa é desenhada com a cor final exterior do `colorNewFog` | EXISTS | `ImprovedFog.update` 132–174 (`getColorNewFog().getExterior()` r/g/b → `colorR/G/B`); `renderFogSegment` passa ao `FogShader.setColorInfo(r, g, b, 1)` (459–469). O alfa da cor é ignorado |
| id 1 | CONFIRMED | `ClimateManager.setup()` 312–321, chamado pelo `<init>` no 525 (`initClimateColor(iconst_1, "COLOR_NEW_FOG")`); `client/ISUI/AdminPanel/ISAdmPanelClimate.lua:249` (`COLOR_NEW_FOG = 1`). **Não há** campo estático `ClimateManager.COLOR_NEW_FOG` (só `COLOR_GLOBAL_LIGHT` e `COLOR_MAX`): use o literal 1 |
| Vanilla 0.9/0.9/0.95/1 (exterior e interior), e o interno nunca volta | EXISTS | `setup()` 324–361 (chamado pelo `<init>` no 525); o único outro acesso ao campo no `ClimateManager` é o getter (`getColorNewFog`, 0–7); nenhum Lua vanilla mexe (`server/Climate/ClimateMain.lua` só troca as luzes `colFog*`) |
| `calculate` mistura a camada modded **no próprio interno** e o override por cima | EXISTS | `ClimateColor.calculate` 25–60 (`internal.interp(modded, t, internal)`), 61–97 (override → final), admin antes (0–24). Com interpolate 1 o interno vira o modded: desligar a camada sem escrever o vanilla antes deixa a cor presa até recarregar |
| Tempestade pinta a névoa | EXISTS | `WeatherPeriod.updateCurrentStage` 909–957: estágio com `fogStrength > 0` faz `colorNewFog.setOverride(fogTintStorm | fogTintTropical, t)` todo minuto (pula com `fogQuality == 2`, 872–876) |
| `isEnableOverride()` / `setEnableOverride(Z)` / `setEnableModded` / `setModdedValue(ClimateColorInfo)` / `setModdedInterpolate(F)` em `ClimateColor` | EXISTS | métodos públicos de `ClimateManager$ClimateColor` (mesmos do `COLOR_GLOBAL_LIGHT`, já usado desde a sprint 0001) |
| Vai pros clientes de MP | EXISTS | `ClimateManager.writePacketContents` 124–143: `finalValue` de toda `climateColors` |
| UNKNOWN | — | qual caminho de render usa o `ImprovedFog` em cada `fogQuality` (com o legado a névoa pode não ficar vermelha; a luz fica). Roteiro da sprint 0010 |

### 12.2 Vinheta

`SearchMode$PlayerSearchMode` só tem `getBlur`, `getDesat`, `getRadius`,
`getGradientWidth` e `getDarkness` (`SearchModeFloat`), sem cor (lista de métodos do
bytecode). A vinheta não tinge.

### 12.3 Semente do mundo

`ZombRand(n)` (CONFIRMED, uso vanilla amplo) é `LuaManager$GlobalObject.ZombRand(D)D`
(0–35): `n == 0` → 0; negativo → `-Next(-n)`; senão `RandLua.INSTANCE.Next((long) n)`,
que faz `Next((int) n, rand)` (`RandAbstract.Next(JLjava/util/Random;)J` 0–8): inteiro
em `[0, n)`. O `RandLua` é semeado por `PZSeedGenerator` (`RandLua.init`), diferente a
cada sessão. A semente da vermelha usa `ZombRand(67108859)` uma vez e salva no
`ModData` (`data.fog.seed`).

### 12.4 Sirene vermelha

Mesmo caminho da §11.3 com o som `NOM_SirenRed` (`media/sound/NOM_SirenRed.ogg`, ~28 s,
gerado por `scripts/gen_sounds.py`).

---

## Abordagem recomendada por mecânica (resumo)

| Mecânica | Caminho principal | Fallback |
|---|---|---|
| Achar corpos | `getGridSquare` + `getDeadBodys()` no servidor, `EveryOneMinute` | `getStaticMovingObjects()` + `instanceof` |
| Marcar corpo | `body:getModData()` (salvo com o chunk) | — |
| Spawn do Eco | `addZombiesInOutfit(...):get(0)` no servidor | `createZombie` + `dressInNamedOutfit` |
| Sem corpo/loot | `OnZombieDead` limpa inventário; `OnDeadBodySpawn` enfileira; `removeCorpse(body,false)` no tick seguinte | procurar corpo no square guardado |
| Sumir no amanhecer | servidor `removeFromWorld/removeFromSquare` + comando aos clientes | `Kill` + remoção de corpo |
| Velocidade/sentidos | swap de `ZombieLore.*` + `DoZombieStats()` + `doZombieSpeed(t)` onde o zumbi é simulado (ADR-005) | — (força e dano: não existem por zumbi) |
| Atrair | `addSound` global no servidor | `pathToSound` no cliente dono |
| Lanterna | `player:getActiveLightItem()` + `square:isOutside()` → `addSound` | — |
| Variante persistente | derivada do `persistentOutfitID`, reaplicada em `OnZombieCreate` | `ModData` global por ID |
| Visto/iluminado | cliente detecta (`square:isCanSee(pn)`) → comando → servidor confere distância e cooldown (ADR-007) | — |
| Teleporte | `teleportTo` no **dono** (servidor repassa `semRostoMove`) | remover + spawnar com `dressInPersistentOutfitID` |
| Som próprio | script `sound { clip { file = media/sound/x.ogg } }` | `.wav` |
| Som no mundo | `sendPlaySound` (servidor) / `z:playSound` (SP) | `playServerSound` |
| Ambiente local | `playSoundLocal` + `emitter:setVolume/stopSoundLocal` | `playUISound` (sem volume) |
| Decal local | `getIsoMarkers():addIsoMarker(sprite, sq, r,g,b,a)` | `addGridSquareMarker` |
| Pós-processo | `SearchMode` (vinheta/blur/desat/escuro) | override de `media/shaders/*.frag` |
| Névoa só do mod | camada modded da névoa + `setEnableOverride(false)` no `OnClimateTick` (§11) | — |
| Cor da névoa | camada modded do `getClimateColor(1)` (`COLOR_NEW_FOG`), vanilla escrito antes de desligar (§12) | — |
| Tempo real no servidor | `getTimestampMs()` no `OnTick`, parado com `isGamePaused()` | — |

## Testes in-game prioritários (UNKNOWNs)

1. ~~Ajuste de IA feito só no servidor sobrevive?~~ Não, por bytecode (§2.1): aplicado no
   dono (ADR-005). Falta confirmar no jogo que a aplicação no cliente vale (sprint 0003).
2. `addZombiesInOutfit` no Lua do servidor dedicado aparece para os clientes?
3. `removeFromWorld` no servidor sem `deleteZombie`: o cliente fica com fantasma?
4. `OnDeadBodySpawn` dispara no servidor dedicado na morte de zumbi? `removeCorpse` no tick
   seguinte some com o corpo para todos?
5. ~~`teleportTo` em zumbi no MP: teleporta, desliza ou volta?~~ Por bytecode (§3.4): no
   servidor volta; no dono vale e as outras cópias deslizam. Falta ver no jogo (sprint 0005).
6. `VisionModifier` baixo em item vestido no zumbi deixa ele efetivamente cego?
7. Override de `media/shaders/screen.frag` por mod é aplicado (ordem boot × ativação de mod)?
9. Som de mod declarado com `file = media/sound/x.ogg` toca (sprint 0004: `NOM_sounds.txt`)?
10. `require` de arquivo do servidor por outro arquivo do servidor roda uma vez só: sim, por
    bytecode (`LuaManager.RunLuaInternal` 11–30 devolve `loadedReturn` se o caminho já está em `loaded`).
8. ~~`setValue` em opção de sandbox dispara sync?~~ Não, nem salva (§2.1).
11. Sprite de tile por nome em `addIsoMarker` aparece (`Texture.trygetTexture`)? (sprint 0005;
    `loop = true` em `file` e `emitter:setVolume` resolvidos por bytecode, §4.3)
12. A caixa de descrição da página 2 do envio (`ISTextEntryBox` multilinha, sem
    `setMaxTextLength` no Lua) aceita os ~6000 bytes da descrição sem cortar? (sprint
    0007, conferir na página do Steam: [publicar.md §3](../publicar.md#3-conferir-a-página-2-min))
