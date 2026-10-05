# Notas de API do PZ (Build 42.20.4) para as mecânicas do mod

| Campo | Valor |
|-------|-------|
| Status | `accepted` |
| Data | 2026-10-04 |
| Fonte | Lua vanilla em `media/lua`, scripts em `media/scripts`, bytecode de `projectzomboid.jar` |

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
- `z:setUseless(true)` (EXISTS) faz o zumbi ignorar tudo (checado em `ZombieIdleState`,
  `WalkTowardState`). Não serve para cego: mata a audição também.
- **Usado na sprint 0004:** Sight=3 e Hearing=1 via 2.1 + regra Lua no dono. A visão "ruim"
  não cega (piso de 10 tiles em `updateVisionRadius`). O spot é só `setTarget`:
  `IsoPlayer.TestZombieSpotPlayer` → `IsoZombie.spotted` → `spottedNew`, que zera o alvo ele
  mesmo quando o zumbi é `useless` (191–208) ou está na fumaça (209–235). `OnZombieUpdate`
  dispara em `IsoZombie.updateInternal` 696, **antes** de `IsoGameCharacter.update` (1029, a
  máquina de estados): `z:setTarget(nil)` ali, com o alvo `IsoPlayer` agachado
  (`isSneaking()`) e sem `isRunning()`/`isSprinting()`, faz o zumbi não agir no que viu.
  `setTarget`, `getTarget`, `isSneaking`, `isRunning`, `isSprinting`: EXISTS (públicos). Som
  não passa por alvo (vai pelo `WorldSoundManager`): o Estalador continua indo até o barulho.
  UNKNOWN: se o `pathToCharacter` do `spottedNew` (2434) deixa o zumbi andando até a posição
  do jogador mesmo sem alvo (roteiro da sprint 0004).
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
o servidor confere a variante e o cooldown e grita.

### 3.4 Sem-rosto (some quando visto ou iluminado)

Testes de "está sendo visto":

| API | Lado | Status | Evidência |
|---|---|---|---|
| `player:CanSee(obj)` | ambos | EXISTS | bytecode: só `LosUtil.lineClear`, sem luz e sem cone de visão |
| `square:isCouldSee(playerNum)` | cliente | CONFIRMED | `server/FireFighting/ISExtinguishCursor.lua:48` |
| `square:isSeen(playerNum)` | cliente | CONFIRMED | `server/ISObjectClickHandler.lua:10` |
| `square:isCanSee(playerNum)` | cliente | EXISTS | bytecode `IsoGridSquare.isCanSee(I)` |
| `z:getTargetAlpha(playerNum)` / `z:isOnScreen()` | cliente | EXISTS | bytecode `IsoObject.getTargetAlpha(I)`, `IsoMovingObject.isOnScreen()` |
| `player:getForwardDirection()` | ambos | EXISTS | para cone (produto escalar) no servidor |
| `square:getLightLevel(playerNum)` | cliente | EXISTS | usado por `IsoZombie.updateVisionRadius` |

As funções por `playerNum` dependem do cálculo de luz/LOS do cliente; no dedicado não valem.
Recomendado: cliente detecta (`getTargetAlpha(pn) > 0` ou `isCanSee`), manda
`sendClientCommand("Nevoa", "seen", { id = z:getOnlineID() })`; servidor valida com `CanSee` + cone
e decide o reposicionamento.

Mover o zumbi:

| API | Status | Evidência |
|---|---|---|
| `z:teleportTo(x, y, z)` | EXISTS | bytecode `IsoGameCharacter.teleportTo(FFI)` e variantes |
| `z:setX/setY/setZ` + `setCurrentSquareFromPosition()` / `setCurrent(sq)` | EXISTS | bytecode `IsoMovingObject` |
| `z:setInvisible(true)` | EXISTS | bytecode `IsoGameCharacter.setInvisible(Z)`; efeito em zumbi UNKNOWN |

UNKNOWN: no MP, teleporte feito no servidor pode ser desfeito pelo cliente dono ou interpolado
(deslizar). Fallback: remover (1.6) e spawnar outro Sem-rosto mais perto, fora da vista (1.3).

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

### 4.3 Som 2D/ambiente só para o jogador local

| API | Status | Evidência |
|---|---|---|
| `getSoundManager():playUISound(name)` → id | CONFIRMED | `server/BuildingObjects/ISMoveableCursor.lua:179` |
| `getSoundManager():stopUISound(id)`, `isPlayingUISound(id)` | EXISTS | bytecode `SoundManager` |
| `player:playSoundLocal(name)` | EXISTS | bytecode `IsoGameCharacter.playSoundLocal(String)` |

Loop: declarar `loop = true` no script e parar com `stopUISound(id)`.

---

## 5. Overlays de chão locais (sprint 0005)

| Opção | Local? | Salva? | Status | Evidência |
|---|---|---|---|---|
| `getIsoMarkers():addIsoMarker(spriteName, square, r, g, b, a)` → marker; `marker:remove()`, `setAlpha`, `setPos` | só cliente | não | CONFIRMED | `client/Foraging/ISBaseIcon.lua:577`, `:559`; bytecode `IsoMarkers` sem save/load |
| `getWorldMarkers():addGridSquareMarker(...)` | só cliente | não | CONFIRMED | `client/ISUI/Maps/ISWorldMap.lua:1457` (versão com coordenadas no mapa); bytecode tem `(String tex, String overlay, IsoGridSquare, r,g,b, doAlpha, size)` |
| `addBloodSplat(square, n[, dx, dy])` | sem envio de rede | **salva** no chunk (SP) | CONFIRMED | `shared/TimedActions/Animals/ISRemoveMeatFromAnimal.lua:121`; bytecode `IsoChunk.addBloodSplat` → `floorBloodSplats`, salvo por `IsoFloorBloodSplat.save` |
| `obj:addAttachedAnimSpriteByName`, `setOverlaySprite` em objeto do square | mexe no objeto do mapa | salva/sincroniza | EXISTS | bytecode `IsoObject`; **evitar** |

Recomendado: `IsoMarkers`. Nada vai para a rede nem para o save. Fallback: `addGridSquareMarker`.
Sangue de verdade só se a persistência no solo for aceitável.

Sprites vanilla de overlay de chão (nomes `<tileset>_<índice>`):
- `overlay_blood_floor_01_0` … (43 entradas em `media/tileDepthTextureAssignments.txt`)
- `overlay_grime_floor_01_0` … `_95` (mesmo arquivo)
- `floors_overlay_tiles_01_*`, `floors_overlay_tiles_02_0..15` (`server/Items/FloorTileOverlays.lua:4`)
- `d_floorleaves_1_*`, `floors_burnt_01_*` (tilesets em `media/tiledefinitions_overlays.tiles`)
Validar cada nome com `getSprite(name) ~= nil` (CONFIRMED `server/ClientCommands.lua:195`).

---

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
| Visto/iluminado | cliente detecta (`getTargetAlpha`, `isCanSee`) → comando → servidor valida com `CanSee` | só `CanSee` + cone no servidor |
| Teleporte | `teleportTo` no servidor | remover + spawnar perto |
| Som próprio | script `sound { clip { file = media/sound/x.ogg } }` | `.wav` |
| Som no mundo | `sendPlaySound` (servidor) / `z:playSound` (SP) | `playServerSound` |
| Ambiente local | `playUISound` + `stopUISound` | `playSoundLocal` |
| Decal local | `getIsoMarkers():addIsoMarker(sprite, sq, r,g,b,a)` | `addGridSquareMarker` |
| Pós-processo | `SearchMode` (vinheta/blur/desat/escuro) | override de `media/shaders/*.frag` |

## Testes in-game prioritários (UNKNOWNs)

1. ~~Ajuste de IA feito só no servidor sobrevive?~~ Não, por bytecode (§2.1): aplicado no
   dono (ADR-005). Falta confirmar no jogo que a aplicação no cliente vale (sprint 0003).
2. `addZombiesInOutfit` no Lua do servidor dedicado aparece para os clientes?
3. `removeFromWorld` no servidor sem `deleteZombie`: o cliente fica com fantasma?
4. `OnDeadBodySpawn` dispara no servidor dedicado na morte de zumbi? `removeCorpse` no tick
   seguinte some com o corpo para todos?
5. `teleportTo` em zumbi no MP: teleporta, desliza ou volta?
6. `VisionModifier` baixo em item vestido no zumbi deixa ele efetivamente cego?
7. Override de `media/shaders/screen.frag` por mod é aplicado (ordem boot × ativação de mod)?
9. Som de mod declarado com `file = media/sound/x.ogg` toca (sprint 0004: `NOM_sounds.txt`)?
10. `require` de arquivo do servidor por outro arquivo do servidor roda uma vez só: sim, por
    bytecode (`LuaManager.RunLuaInternal` 11–30 devolve `loadedReturn` se o caminho já está em `loaded`).
8. ~~`setValue` em opção de sandbox dispara sync?~~ Não, nem salva (§2.1).
