# Notas de API do PZ (Build 42.20.4) para as mecânicas do mod

| Campo | Valor |
|-------|-------|
| Status | `accepted` |
| Data | 2026-10-04 (§11, §12, §13, §14, §15, §16, §17, §18: 2026-10-05; §16.5: sprint 0021; §17.5: sprint 0022; §16.6: sprint 0023, raio pela tela na 0034; §25 e §26: sprint 0035) |
| Fonte | Lua vanilla em `media/lua`, scripts em `media/scripts`, bytecode de `projectzomboid.jar` |

> **Kahlua ≠ luajit (visto no jogo, 2026-10-05):** `next()` é `nil` no Kahlua
> ("Object tried to call nil in prune"); o luajit dos testes tem, então o teste passou
> e o jogo quebrou. `tests/test_kahlua_compat.lua` varre `mod/` atrás do que o Kahlua
> não tem. Achou outra função faltando no jogo: acrescente lá.

> **Symlink quebra os scripts (visto no jogo, 2026-10-05):** com o mod linkado por
> symlink, Lua, texturas, `clothing.xml` e `fileGuidTable.xml` carregam, mas o
> `ScriptManager` monta `.../Zomboid/mods/var/home/.../nom_clothing.txt` e não acha
> `media/scripts/*.txt` → `Couldn't find item Base.NOM_*`. Use `scripts/dev-sync.sh` (cópia).

## Como ler este documento

- **CONFIRMED**: visto em uso no Lua vanilla (arquivo:linha).
- **EXISTS**: método público no bytecode e classe exposta ao Lua (lista do
  `LuaManager$Exposer.exposeAll`), mas sem uso vanilla. Funciona em tese; teste antes de depender.
- **UNKNOWN**: o bytecode não responde; precisa de teste in-game.
- Caminhos Lua são relativos a `media/lua/`. Bytecode no formato `Classe.metodo(descritor)`.
- Nenhum código de mod do Workshop foi copiado ou usado como evidência.

### Fatos transversais (leia antes de tudo)

1. **Detecção de "lado do servidor".** Em solo, `isServer()` e `isClient()` são **ambos
   `false`**; em dedicado, `isServer()` é `true` no servidor. Guarda correta para lógica
   autoritativa: `if isClient() then return end`. Evidência: `server/XpSystem/XpUpdate.lua:294-297`
   (`isServer() and players:size()-1 or getNumActivePlayers()-1`); bytecode
   `GlobalObject.sendClientCommand(...)` cai em `SinglePlayerClient.sendClientCommand` fora do MP.
2. **No MP do B42, a IA do zumbi é simulada pelo cliente "dono".** O servidor dá posse
   (ownership) de cada zumbi a uma conexão e só retransmite. Evidência: bytecode
   `NetworkZombieManager.updateAuth(IsoZombie)` (usa `ServerOptions.switchZombiesOwnershipEachUpdate`),
   `IsoZombie.setOwner(UdpConnection)`, `IsoZombie.isRemoteZombie()`, `NetworkZombieSimulator.getAuthorizedZombieCount()`.
   **Pra saber se este processo é o dono, use `z:isLocal()`, nunca `z:isRemoteZombie()`:** no solo
   ninguém chama `setOwner` e o `isRemoteZombie()` dá `true` pra todo zumbi (§24, sprint 0034).
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
4. **O `%` do Kahlua trunca e satura** (review da sprint 0017). `KahluaThread.primitiveMath`
   faz `a - (double)(int)(a/b)*b`: com operando negativo o resto sai negativo (`-1 % 2 = -1`;
   o luajit dos testes dá `1`), e o `(int)` do Java satura em `2^31-1` quando `a/b` passa disso
   (`getTimestampMs()` é ~1.76e12). `math.floor` é `Math.floor` em double (`MathLib.floor`
   23–32), sem `(int)`. Use `NOM_Math.mod`; o lint `kahlua_percent_safe` pega paridade e `%`
   em ID de outfit ou tempo real.

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
| `obj:addAttachedAnimSpriteByName`, `setOverlaySprite` em objeto do square | mexe no objeto do mapa | salva/sincroniza | anexo: CONFIRMED, **usado desde a 0023** com a retirada antes do save (§16.6); overlay: evitar | bytecode `IsoObject` |

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
- ~~**Adicionar** shader novo: não dá por Lua.~~ **Correção (sprint 0018):** vale só pro Lua
  (`Shader`/`ShaderProgram` não estão no Exposer). Um item de roupa com `<m_Shader>X</m_Shader>`
  no XML cria um shader **novo** com o nome `X`, lido de `media/shaders/X[_static].vert` e
  `X.frag` do mod: `ClothingItemXML` → `ClothingItemAssetManager.onFileTaskFinished` 170–173 →
  `PopTemplateManager.addClothingItem` 100–157 → `ShaderManager.getOrCreateShader` 86–110
  (arquivo de mod pelo `activeFileMap`, `ZomboidFileSystem.loadMod` 216). EXISTS; usado pelo
  dissolve ([§17](#17-dissolve-e-bloom-sprint-0018), [ADR-016](adr-016-dissolve-e-bloom.md)).
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
| `OnWorldSound` | (x, y, z, radius, volume, source) | `WorldSoundManager$WorldSound.init` (todo `addSound`), no processo que chama o `addSound`; no servidor também pro som de cliente (`WorldSoundPacket.processServer`) | EXISTS, **usado** (sprint 0011) | bytecode §13 |
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

Sprint 0033: a sirene dura 15 s e o comando passa a levar `{ red, dir }` (`dir` = graus
de onde ela "vem", `NOM_FogEventRules.sirenDir`, igual em toda máquina). Sirene cancelada
no dedicado manda `sendServerCommand(MODULE, "sirenStop", {})` (mesma forma do `siren`,
sem API nova); no solo o servidor chama `NOM_SirenFreeze.start/stop` direto. Cliente que
não conhece um comando o ignora (`client/NOM_FogClient.lua`: cadeia de `if` sem `else`).

Sprint 0034: a sirene deixa de ser chapada no jogador. São 3 por jogador, em emitters do
mundo (§23); o `dir` e o `NOM_FogEventRules.sirenDir` saíram, e o comando leva só `{ red }`.
Review final da 0034: o debug que troca a cor no meio do presságio ou da fuga (`NOM_FogEvent.setRed`)
manda `sendServerCommand(MODULE, "sirenColor", { red })` (mesma forma, sem API nova); o cliente só
troca a cor do presságio e da subida que já correm (`NOM_FogState.recolor`), sem tocar a sirene de
novo.

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

## 13. Carpideira (sprint 0011)

Verificado no bytecode do B42.21 (o instalado). Decisão na [ADR-011](adr-011-carpideira.md).

### 13.1 Barulho: `Events.OnWorldSound`

- `WorldSoundManager$WorldSound.init(Object,IIIIIFFS)` 129–155:
  `LuaEventManager.triggerEvent("OnWorldSound", x, y, z, radius, volume, source)`. Os
  outros `init` caem nele (`(Object,IIIII)` 13 → `(Object,IIIIIZFF)` 31 → este).
- `WorldSoundManager.addSound(Object,IIIIIFFZZZZS)` 16–34 (`getNew` + `init`), e todas as
  sobrecargas de `addSound` caem nela: **todo `addSound` dispara o evento**, na hora,
  no processo que chama. Depois, no cliente de MP manda `GameClient.sendWorldSound`
  (304–315); no servidor, `GameServer.sendWorldSound` (321–330).
- `WorldSoundPacket.processServer` 90–139: o servidor recebe o som do cliente e chama
  `WorldSoundManager.addSound` com `CharacterID.getCharacter()` (o jogador) de fonte →
  o `OnWorldSound` dispara **no servidor** com o jogador. `processClient` 38–87 faz o
  mesmo nos outros clientes.
- Raio: tarefas vanilla de 6 a 20 (`shared/TimedActions/ISRemoveBush.lua:41`,
  `ISRemoveGrass.lua:30`, `ISPickupBrokenGlass.lua:22`, `ISRemoveBrokenGlass.lua:23`,
  `ISDestroyStuffAction.lua:69`); `SoundRadius` de arma de fogo nos scripts de item, de 50 a
  200. O mod chama "alto" a partir de 30.
- O `addSound` do próprio mod (caça, lanterna, gritos: `NOM_Night.call`) também
  dispara: marcado com `NOM_Night.calling` durante a chamada.

### 13.2 Parar e soltar

- Parada: `setUseless(true)` (§3.2; CONFIRMED `client/DebugUIs/DebugContextMenu.lua:566`),
  mais `setTarget(nil)` uma vez (uma caçada em andamento continuaria: o useless só zera o
  alvo no próximo spot). `WalkTowardState` em andamento segue até a última posição vista.
- Caçar quem a acordou: `IsoZombie.spotted(IsoMovingObject,Z)` público (→ `spottedNew`
  com `ZombieLore.spottedLogic`, senão `spottedOld`). No `spottedNew`, `forced` faz a
  chance de spot 1 000 000 (1114–1120); o spot grava `target` e `lastTargetSeenX/Y/Z`
  (1909–1950). Antes disso, zumbi `useless` volta com alvo nulo (191–208), e um alvo
  atual mais perto que o novo faz voltar (1042–1113). Mesmo spot forçado que o jogo usa
  pra manter a caçada (`updateInternal` 956–991). UNKNOWN: o efeito no jogo (roteiro).
- `getPlayerByOnlineID(id)` no cliente: CONFIRMED `client/ServerCommands.lua:10`.

### 13.3 Soluço no zumbi

- `IsoGameCharacter.playSoundLocal(String)J` = `getEmitter().playSoundImpl(nome, null)`
  (§4.3); `getEmitter()` devolve `BaseCharacterSoundEmitter`, com `isPlaying(J)Z`,
  `stopSoundLocal(J)V`, `setVolume(JF)V` e `stopAll()V` abstratos, implementados no
  `CharacterSoundEmitter`.
- `IsoZombie.removeFromWorld` 0–191 só chama `getEmitter().stopOrTriggerSoundByName`
  (um nome) e não para os outros sons: um loop do mod continuaria. O mod para o soluço de
  quem saiu da lista de zumbis.
- `volume` dentro do `clip`: CONFIRMED `media/scripts/generated/sounds/zombies/sounds_zombie_foley.txt:243`.

### 13.4 Lanterna

- `player:getActiveLightItem()` (§2.4) e `square:isCanSee(pn)` (§3.4) no cliente.
- Direção do jogador no servidor: `PlayerPacket` → `NetworkPlayerAI.set` grava
  `Prediction.direction` (158); quem aplica no servidor não foi seguido. UNKNOWN, não usado:
  o servidor confere só lanterna acesa e distância.

---

## 14. Visual das variantes (sprint 0012)

Verificado no bytecode do B42.21 (o instalado). Decisão na [ADR-012](adr-012-visual-das-variantes.md).

### 14.1 Pele

- `HumanVisual.getSkinTexture()` 0–11: com `skinTextureName != null`, devolve ele; senão
  calcula a pele (zumbi: `PopTemplateManager.*SkinsZombie1..3` pelo `zombieRotStage`).
  `setSkinTextureName(String)` só grava o campo (0–5). EXISTS (`HumanVisual` no Exposer).
- Quem grava o campo: `clear`, `copyFrom`, `load`, `setSkinTextureName`; o único chamador
  do setter é o `IsoMannequin`. Zumbi normal tem nulo: tirar = `setSkinTextureName(nil)`.
- `ModelInstanceTextureCreator.init` 489–497 põe a pele em `baseTexture`, montada como
  `media/textures/Body/<nome>.png` (string do pool). **UNKNOWN:** a textura do mod nesse
  caminho é achada (roteiro).

### 14.2 Peça (`ItemVisual`)

- `IsoZombie.getItemVisuals()` → `ItemVisuals extends ArrayList<ItemVisual>`. `ItemVisual` e
  `ItemVisuals` no `LuaManager$Exposer` (2998, 3005): `ItemVisual.new()` EXISTS, sem uso vanilla.
- `ItemVisual.<init>()` deixa `textureChoice = -1`; `getTextureChoice(ClothingItem)` 17–49
  sorteia na hora. `getClothingItem()` sai do item de script (`getScriptItem` →
  `ScriptManager.getItem(fullType)` → `getClothingItemAsset`): basta `setItemType("Base.X")`.
- `HumanVisual.addClothingItem(ItemVisuals, Item)` tira da lista quem ocupa o mesmo lugar
  (251, 300): não usado.
- `resetModelNextFrame()` no zumbi depois de mexer no visual: CONFIRMED
  `client/Tutorial/Steps.lua:832-838`, `:1152`.
- Item de roupa do mod: script com `ClothingItem = X` → `OutfitManager.getClothingItem` pelo
  GUID → caminho pela `fileGuidTable`; o mod traz a dele (`ZomboidFileSystem.loadFileGuidTable`
  113–312: lê `<pasta do mod>/media/fileGuidTable.xml` e `mergeFrom`). Textura em
  `media/textures/<textureChoices>.png`.
- `IsoZombie.helmetFallFromVisuals` 62–70: só cai item com `getChanceToFall() > 0`.
- **Lugar da peça (review da 0012):** `WornItems.setItem` 5–19: lugar que não é multi-item e
  já está ocupado → tira quem está (106); 35–96: tira quem é exclusivo do lugar novo. O
  `DoZombieInventory` veste na ordem da lista, então uma peça do mod num lugar comum
  (`base:eyes`, `base:mask`, `base:hat`) expulsa a do zumbi, que some do corpo e do loot. As
  peças das variantes vão em `base:zeddmg`: `setMultiItem(ItemBodyLocation.ZED_DMG, true)` em
  `shared/NPCs/BodyLocations.lua:859`, sem `setExclusive` nem `setHideModel` (77 itens
  vanilla `ZedDmg_*`, todos camadas sem modelo). **UNKNOWN:** a peça com modelo nesse lugar
  aparece na cabeça (roteiro).

### 14.3 Rede, save, reaproveitamento, morte

- `ZombiePacket.set(IsoZombie)`: `outfitId` (15–18) e `skinTextureIndex` (259–265, o
  índice, não o nome). Nada mais do visual. `SharedDescriptors` (que manda `ItemVisuals`) é
  dos zumbis de jogador reanimado.
- `IsoZombie.dressInPersistentOutfitID(I)` 1–43: `HumanVisual.clear()`, `itemVisuals.clear()`,
  grava o mesmo ID, veste (`PersistentOutfits.dressInOutfit`). Quem chama: o
  `ModelManager.dressInRandomOutfit` quando `!isPersistentOutfitInit()` (116–128 e, no
  cliente de MP, 29–58) — o jogo veste tarde — e o `DoZombieInventory` no servidor (15–33).
- `VirtualZombieManager.createZombieOutsideWorld` 177–230 (objeto reaproveitado):
  `HumanVisual.clear()` e `setPersistentOutfitID(I)` (init = false). A lista de
  `ItemVisual` só é limpa quando o jogo veste.
- `IsoZombie.onKilled` 45–52: `DoZombieInventory()` antes do `OnZombieDead`.
  `DoZombieInventory(Z)` 54–73: `WornItems.setFromItemVisuals` (cria item de todo
  `ItemVisual` cujo tipo existe, `InventoryItemFactory.CreateItem`) e
  `addItemsToItemContainer`. O corpo (`IsoDeadBody.<init>` 661–710) copia a `HumanVisual`, o
  inventário e o `WornItems`.
- `WornItems.remove(InventoryItem)` e `ItemContainer.Remove(InventoryItem)` são locais.
  `IsoGameCharacter.removeWornItem` → `setWornItem` manda `SyncClothing` no cliente de MP
  (352–378): não usado.
- ~~**UNKNOWN:** no cliente de MP, o `OnZombieDead` dispara na cópia local antes de um corpo
  local (se houver)?~~ CONFIRMED pelo bytecode na sprint 0016 (§14.4). O corpo do servidor
  sai limpo (ele nunca pinta).
- **Jogador reanimado:** `IsoZombie.save` só é chamado pelo `ReanimatedPlayers` (fato
  transversal 3) e grava a `HumanVisual` (`HumanVisual.save` escreve o `skinTextureName`, que
  o `load` lê). O mod não pinta quem tem `isReanimatedPlayer()` (EXISTS, `IsoZombie`).
- Peles vanilla de zumbi (`Body/M_ZedBody01_level1.png`) são RGBA 256×256; as do mod, RGB
  (só o formato foi lido). **UNKNOWN:** o compositor trata igual.

### 14.4 Esconder a roupa (sprint 0016)

Bytecode do B42.21. Decisão na [emenda da ADR-012](adr-012-visual-das-variantes.md#emenda-de-2026-10-05--sprint-0016-a-roupa-comum-some-na-variante).

- **Sem flag de esconder:** `ItemVisual` só tem tipo, nome de modelo alternativo, tinta, matiz,
  textura base, escolha de textura, decal, sangue, sujeira, buracos e remendos. `HumanVisual`
  não tem nada por item. Esconder = tirar da `ItemVisuals` e devolver.
- **Nenhum evento antes do inventário da morte:** `IsoGameCharacter.die` 15–27 → `Kill` 0–53 →
  `onKilled` (vazio no `IsoGameCharacter`); `IsoZombie.onKilled` 38–52: `DoZombieInventory()`
  só fora do cliente de MP, depois `OnZombieDead`. No solo, o corpo (`becomeCorpse`, `die`
  79–80) vem depois e copia `HumanVisual`, inventário e `WornItems` (`IsoDeadBody.<init>`
  661–710); o corpo desenha o `WornItems`.
- `DoZombieInventory(Z)`: 0–14 sai cedo pra jogador reanimado e `wasFakeDead`; 36–73
  `removeAllItems`, `WornItems.setFromItemVisuals(itemVisuals)`,
  `addItemsToItemContainer(inventory)`; 76–198 itens presos; 201–325 `itemsToSpawnAtDeath` e
  `clear()` da lista. `DoZombieInventory()` no Lua: CONFIRMED `client/Tutorial/Steps.lua:1095`,
  `:1698` (não usado: a segunda chamada perderia os `itemsToSpawnAtDeath`).
- `WornItems.setFromItemVisuals` 0–105: `clear()`; por `ItemVisual`, `CreateItem(tipo)`,
  `getVisual().copyFrom(iv)`, `synchWithVisual`, `setItem(lugar, item)`.
  `addItemsToItemContainer` 0–66: condição pelos buracos e `AddItem`. EXISTS (`WornItems` no
  `LuaManager$Exposer`, sem uso vanilla desses dois). `getWornItems():size()` e
  `:get(i):getItem()`: CONFIRMED `client/ISUI/ISFitnessUI.lua:295-296`.
- **Fogo:** `IsoGameCharacter.FireCheck` 268–290 e `ReduceHealthWhenBurning` 229–251 disparam
  `OnZombieDead` sem `DoZombieInventory`; `BurntToDeath.execute` 47–58 cria o corpo direto
  (fora do cliente de MP).
- **Cliente de MP:** `DeadZombiePacket.parse` → `DeadCharacterPacket.parseCharacterInventory`
  limpa e lê inventário, `WornItems` e presos do servidor e chama `resetModelNextFrame`;
  `processClient` 514 → `dieNetwork` 0–10: `Kill` (`OnZombieDead`) e depois `becomeCorpse`.
  CONFIRMED (bytecode): o `OnZombieDead` do cliente vem antes do corpo local (fecha o UNKNOWN
  do §14.3), e o corpo do cliente veste o que o servidor mandou.
- `IsoZombie.getItemVisuals()` com `isUsingWornItems()` (morto, reanimado, `wasFakeDead`)
  reconstrói a lista a partir do `WornItems` (0–38): mexer na lista de um zumbi desses não
  dura. O mod só pinta zumbi vivo e não reanimado.
- **Chapéu caído:** `PersistentOutfits.setFallenHat` 0–36 liga o bit `0x8000` do
  `persistentOutfitID` (`setPersistentOutfitID(id | 32768, init)`); `isHatFallen(I)` testa o bit;
  `removeFallenHat` 0–93 tira da lista quem tem `getScriptItem():getChanceToFall() > 0`.
  `PersistentOutfits` não está no `Exposer` (o mod lê o bit no ID); `ItemVisual.getScriptItem`
  e `Item.getChanceToFall` EXISTS (`Item` no `Exposer`). No cliente de MP,
  `ZombieHelmetFallingPacket.processClient` 0–241: procura o chapéu na lista pelo nome, tira se
  achar, `clear` + `addAll`, `resetModelNextFrame` e `setFallenHat(true)` mesmo sem achar.
- **Quem liga o bit do chapéu** (sprint 0017, bytecode): `setFallenHat` mantém o
  `isPersistentOutfitInit` (0–36) e com `false` desliga o bit. No zumbi: servidor dedicado
  em `hit/Zombie.react` 20–57 (só `GameServer.server`, flag 64 do golpe; `removeFallenHat` só
  com `ServerGUI`) e cliente em `ZombieHelmetFallingPacket.processClient` 238.
  `IsoGameCharacter.helmetFall` 81–97 só liga pra quem não é zumbi: no solo o jogo não muda
  o ID do zumbi. Ninguém re-veste um zumbi vivo porque o bit mudou: o `outfitId` do
  `ZombiePacket` só é usado na criação (`NetworkZombieSimulator.parseZombie` 144–152). O mod
  tira o bit antes do sorteio (`NOM_VariantRules.baseId`, ADR-006).
- **Sair pro menu reinicia o Lua:** `IngameState.exit` 986 `LuaManager.init`, 1314
  `LoadDirBase`. Estado em tabela Lua não sobrevive.
- **UNKNOWN:** `ArrayList.remove(Object)` devolve o booleano pro Lua (o Kahlua converte
  `boolean`); se vier sempre nil, a roupa não volta no fim (roteiro da sprint 0016).

## 15. Efeitos de tela (sprint 0013)

Verificado no bytecode do B42.21 (o instalado) e no Lua vanilla. Decisão na
[ADR-013](adr-013-efeitos-de-tela.md).

### 15.1 Desenhar por cima do mundo e por baixo da UI

| Fato | Status | Evidência |
|---|---|---|
| Ordem: mundo, `OnPreUIDraw`, lista de UI na ordem, `OnPostUIDraw` | EXISTS | `UIManager.render` 170 (`OnPreUIDraw`), 240–426 (laço da lista `UI`, índice 0 primeiro; pula invisível e `isFollowGameWorld`), 668 (`OnPostUIDraw`) |
| `backMost()` põe o elemento no fundo da UI | CONFIRMED / EXISTS | `client/Fishing/FishingManager.lua:41`; `UIElement.backMost` só liga `alwaysBack`; `UIManager.update` 389–454 tira todo `isBackMost()` do lugar e põe no índice 0, todo update |
| Elemento de 1×1 px que desenha a tela inteira | CONFIRMED | `client/ISUI/ISSleepingUI.lua:70-82` (1×1, `setConsumeMouseEvents(false)`, desenha o relógio no meio da tela) |
| Desenho com cor e alfa | CONFIRMED | `ISUIElement.lua:1032-1041` (`drawTextureScaled(tex, x, y, w, h, a, r, g, b)` → `DrawTextureScaledColor`) |
| Ladrilhos numa chamada | CONFIRMED / EXISTS | `ISUIElement.lua:1109-1117` (`drawTextureTiled`); `UIElement.DrawTextureTiled` laça `DrawSubTextureRGBA` no Java, cortando o último ladrilho |
| `UIElement.render` sem pai não corta por posição | EXISTS | `UIElement.render` 0–124: só sai por `enabled`/`isVisible` e por corte do pai |
| Retângulo de tela por jogador (tela dividida) | CONFIRMED | `getPlayerScreenLeft/Top/Width/Height(i)`, `ISSleepingUI.lua:16-17, 60-61` |
| Menu aberto | CONFIRMED | `MainScreen.instance:isReallyVisible()`, `ISSleepingUI.lua:49` |
| Criar / tirar | CONFIRMED | `Events.OnGameStart` (`MainScreen.lua:2180`), `Events.OnMainMenuEnter` (`MainScreen.lua:2178`) |
| `getRenderer():render(...)` num `OnPreUIDraw` | **não usado** | os dois usos vanilla estão desligados (`server/NewSelectionSystem/GridSquareSelector.lua:56-59`, registro comentado); `SpriteRenderer.render(Texture, 8×F, Consumer)` tem 10 argumentos e o vanilla passa 9 |
| `UIManager.DrawTexture(tex, x, y, w, h, a)` | EXISTS, não usado | estático, sem cor (`renderi` com branco), sem uso vanilla |

### 15.2 Não pegar clique

- `UIManager.updateMouseButtons` 54–206: percorre a lista do topo pro fundo; só quem passa no
  `isOverElement` (o retângulo do elemento, 0–204) recebe `onConsumeMouseButtonDown`, que chama
  `UIElement.onMouseDown`: com `onMouseDown` no Lua, vale o retorno (nil → `consumeMouseEvents`,
  644–667); sem, `false`. `true` para o clique ali.
- Roda: `UIManager.update` 867–979, `isPointOver` + `onConsumeMouseWheel`; `true` corta o zoom.
- `UIManager.isForceCursorVisible`: `true` se algum elemento visível está com o mouse em cima:
  um elemento do tamanho da tela manteria o cursor sempre visível. 1×1 px evita.

### 15.3 Opção de cliente

- `PZAPI.ModOptions` existe no B42 (`client/PZAPI/ModOptions.lua`): `create(id, nome)`,
  `addTickBox(id, nome, valor, dica)`, `addSlider(id, nome, min, max, passo, valor, dica)`,
  `getOptions(id):getOption(id):getValue()`; grava em `ModOptions.ini` (`save`, linhas
  `tipo|mod|opção|valor`). Sem uso vanilla da criação: CONFIRMED pela leitura do consumidor,
  `MainOptions:addModOptionsPanel` (`MainOptions.lua:2795+`), que faz `load()` e monta a página
  "Mods" se `#PZAPI.ModOptions.Data ~= 0` (`:409`). Nomes e dicas passam por `getText`.
- O `MainScreen` do jogo nasce no `OnGameStart` (`LoadMainScreenPanelIngame`,
  `MainScreen.lua:1784-1790, 2180`) e cria o `MainOptions` (`:177, :694`): as opções têm de ser
  criadas na carga do arquivo.
- Categoria de tradução `UI` existe (`Translator$1`, `BY_NAME`): `Translate/<LANG>/UI.json` do
  mod é lido como o `Sandbox.json` (`tryFillMapFromMods`).

### 15.4 Shader de tela e canal

- `WeatherShader.onCompileSuccess` busca (`glGetUniformLocation`): `TimeOfDay`, `BloomVal`,
  `PixelOffset`, `PixelSize`, `BlurStrength`, `bgl_RenderedTextureWidth/Height`, `timer`,
  `TextureSize`, `Zoom`, `Light`, `LightIntensity`, `NightValue`, `Exterior`,
  `NightVisionGoggles`, `DesaturationVal`, `FogMod`, `SearchMode`, `ScreenInfo`, `ParamInfo`,
  `VarInfo`, `DrunkFactor`, `BlurFactor`, `timerWrap`. Tipos pelo `glUniform*` do
  `startRenderThread`. `FogMod` é buscado e **nunca enviado**.
- `startMainThread` monta `vars`: 0–2 cor da luz, 3 força, 4 dessaturação, 5 visão noturna,
  6 `getShaderBlur`, 7 `getShaderRadius`, 8–9 canto do offscreen, 10–11 tamanho, 12–13 clique
  direito, 14 zoom, 15 tile (64/32), 16 `gradient·tile/2`, 17 `getShaderDesat`,
  18 `isShaderEnabled ? 1 : 0`, 19 `getShaderDarkness`, 22 bêbado, 23 desfoque. Uniforms:
  `SearchMode = (6, 7, 8, 9)`, `ScreenInfo = (10..13)`, `ParamInfo = (14..17)`,
  `VarInfo = (18, 19, 20, 21)` (20–21 nunca escritos).
- `PlayerSearchMode.getShader*` = exterior ou interior do `SearchModeFloat` (pelo
  `isPlayerExterior`). `SearchModeFloat.setAll(v)` grava atual e alvo dos dois.
- `SearchMode.setOverride(pn, b)` só grava o flag; `PlayerSearchMode.update` sai na 1ª linha com
  override (nem fade, nem `reset`); sem override e sem `enabled`, `reset()` nos quatro e o
  gradiente só `equalise`. `setEnabled` igual ao atual não faz nada; `true→false` começa o
  `FadeOut`, e `isShaderEnabled = enabled || doFadeIn || doFadeOut`: override no meio de um fade
  o congela.
- `ShaderUnit.preProcessShaderFile`: `#include`, troca de `#version`/sintaxe com
  `getUseOpenGL21` (`#version 120`, `texture2D`, `out vec4 colour`). O `screen.frag` do mod2
  passa no `glslangValidator` em 330 e em 120.
- Multi-mod no Workshop: `SteamWorkshopItem.validateModsFolder` valida cada pasta de
  `Contents/mods/` (arquivo solto: `FileNotAllowedInMods`). `readModInfoAux`: `require=` tira
  `\` e separa por vírgula.
- **UNKNOWN:** o vencedor quando dois mods trazem `screen.frag` (ordem do `activeFileMap`); o
  shader compilando no driver do Johan (roteiro).
- **Tontura no `darkness` (sprint 0035, ADR-013 emenda).** Bytecode do B42.21 instalado:
  - `SearchModeFloat.setAll(F)` só chama `setExterior`/`setTargetExterior`/`setInterior`/
    `setTargetInterior`, sem prender em `min`/`max` (os campos existem e não são lidos ali);
    `PlayerSearchMode.getShaderDarkness` 0–24 devolve `getExterior`/`getInterior` pelo
    `isPlayerExterior`; `WeatherShader.startMainThread` 343–354 grava em `vars[19]`, e o
    `startRenderThread` 385–417 manda `VarInfo = (vars[18], vars[19], vars[20], vars[21])` por
    `glUniform4f`. Um valor como `4·256 + 2` chega inteiro ao shader.
  - Quem mais lê o `darkness`: no jar, só `SearchMode`, `PlayerSearchMode`, `WeatherShader` e
    `RenderSettings$PlayerRenderSettings` citam `getDarkness`/`getShaderDarkness`, e o último só
    pega o `SearchMode` e zera `smAlpha`/`smRadius` (`updateRenderSettings` 0–11). No Lua
    vanilla: `ISSearchManager.lua:1081` (escreve o alvo, fora do nosso override) e o painel de
    debug `DebugUIs/DebugMenu/General/ISSearchMode.lua:42` (mostra).
  - `timer` é inteiro: `startRenderThread` 163–176 manda `timerVal / 2` (`idiv`, depois `i2f`);
    `timerVal` anda +1 a cada 2 quadros com `PerformanceSettings.getLockFPS() >= 60` (188–229) ou
    +2 por quadro abaixo disso (232–239). Animação pelo `timer` anda em degraus (~15 por segundo a
    60 FPS). `timerWrap` = `1 − 2·timerVal/2³¹` (242–255): quase parado.

## 16. Outro Mundo sangrento (sprint 0015)

Verificado no bytecode do B42.21 (o instalado), no Lua vanilla e nos packs de textura. Decisão na
[ADR-015](adr-015-outro-mundo-sangrento.md).

### 16.1 O que vai pro save ou pra rede (proibido)

| Mecanismo | Salva? | Rede? | Evidência |
|---|---|---|---|
| `IsoObject.attachedAnimSprite` (`addAttachedAnimSprite*`) | **sim** | com o objeto | `IsoObject.save` 64–187 (lista inteira, por ID do sprite). Usado desde a 0023, tirado antes de todo save: §16.6 |
| `IsoObject` overlay (`setOverlaySprite`) | **sim** (flag 256, nome e cor) | `setOverlaySprite(..., true)` → `UpdateOverlaySprite` / `GameServer.updateOverlayForClients` | `IsoObject.save` 1041–1182; `setOverlaySprite` 203–305 |
| Sangue de parede (`wallBloodSplats`) | **sim** (até 32) | — | `IsoObject.save` 741–825 |
| Sangue de chão (`addBloodSplat`) | **sim** | — | §5 |
| Objeto novo no square (`AddSpecialObject`, `AddTileObject`, `addTileObject`) | **sim**: `IsoGridSquare.save` grava todo objeto da lista `objects`, sem filtro; `IsoObject.Serialize()` é `true` na base | — | `IsoGridSquare.save` 116–342 |
| Erosão de verdade (`ErosionMain`, categorias `WallCracks`, `WallVines`...) | **sim**: vira objeto/overlay do square | — | `zombie/erosion/categories/*.init` montam `ErosionObjOverlay` com os mesmos sprites |

### 16.2 O que desenha sem tocar em nada

| Mecanismo | Onde desenha | Prof.? | Luz? | Status | Evidência |
|---|---|---|---|---|---|
| `getIsoMarkers():addIsoMarker(tabelaDeNomes, sq, r, g, b, a)` | quad de cada textura **centrado no meio do tile, base no meio** (`renderTextureWithDepth`: `x − w/2`, `y − h`, tamanho recortado da textura) | sim (`enableDepthTest`, profundidade do ponto `x+0.5, y+0.5, z+0.01`) | não (só a cor do marcador) | CONFIRMED, **usado** | `ISBaseIcon.lua:579` (tabela de nomes); `IsoMarker.init(KahluaTable,...)` (uma `Texture.trygetTexture` por item); `IsoMarkers.renderIsoMarkers` 32–330 (FBO), só no andar do jogador; `IngameState.exit` 602 → `reset()` |
| `Events.RenderOpaqueObjectsInWorld(pn, x, y, z, sq)` + `sprite:RenderGhostTileColor(x, y, z, r, g, b, a)` | posição de tile de verdade (`IsoSprite.render(inst, nil, x, y, z, N, 32·escala, 96·escala, branco, true)`) | **não** (com `setRenderingGhostTile(true)` o `renderCurrentAnim` faz `disableDepthTest`) | não (cor branca cheia × tinta) | evento CONFIRMED (`ISBuildingObject.lua:721-741`), desenho CONFIRMED (`ISFarmingCursorMouse.lua:21`, 7 argumentos); os dois juntos fora do cursor: EXISTS, **usado** | `FBORenderCell.performRenderTiles` 372–374 chama `renderOpaqueObjectsEvent(pn)` todo quadro, depois de itens e poças, antes dos personagens; o evento sai sempre (`UIManager.PickedTile` nasce no `<clinit>`, nunca nil; com controle, a posição da câmera). `IsoSprite.RenderGhostTileColor(IIIFFFFFF)` 0–313; o `IsoSpriteInstance` volta pro pool (`IsoSpriteInstance.add`) |
| `getWorldMarkers():addGridSquareMarker` | círculo/ícone de chão | — | — | CONFIRMED | §5 |

- **Escolha:** chão por `IsoMarker` (tem profundidade; o deslocamento de meio tile é igual pra
  todos), parede por `RenderGhostTileColor` (só ele põe o sprite de parede no lugar; o `IsoMarker`
  centraria o recorte da textura e a parede cairia fora). Sem profundidade, a parede passaria por
  cima do que está na frente: só parede limpa (`getObjects():size()` = piso + paredes, sem
  batente), de frente e com `isCouldSee`.
- `getSprite(nome)` → `IsoSpriteManager.getSprite(String)`: nome desconhecido **cria** um sprite
  vazio (`AddSprite`). Conferir com `getTexture(nome)` antes. Uso vanilla de `getSprite` por nome:
  `server/ClientCommands.lua:195` (`o:setSprite(getSprite("blends_natural_01_64"))`, nome que existe).
- `square:getWall(north)`: o objeto cujo sprite tem `cutN` (norte) ou `cutW` (oeste), pulando
  `WallSE` (`IsoGridSquare.getWall(Z)` 0–85; `ISDestroyStuffAction.lua:141-142`). Batente de porta
  e janela também têm `cut*`: o mod pula o square com `DoorWallN/W`, `WindowN/W`, `doorN/W` ou
  `windowN/W` nas propriedades (`square:getProperties():has(IsoFlagType.X)`,
  `ISBuildIsoEntity.lua:195-198`; os oito nomes estão no enum `IsoFlagType` do bytecode).
- `square:getLightLevel(pn)`: `max(r, g, b)` da luz do square pro jogador (`IsoGridSquare.getLightLevel(I)`
  10–37; `forageSystem.lua:1889`).
- `IsoMarker.setColor(FFFF)` existe (EXISTS): cor e alfa numa chamada.

### 16.3 Sprites vanilla (pack `Tiles2x`, contagem)

Lado da parede por dois caminhos que batem: o recorte da textura no quadro de 128×256 (metade
esquerda = parede W, direita = N; tabela `x, y, w, h, ox, oy` de cada entrada do pack) e a
profundidade em `media/tileDepthTextureAssignments.txt` (`preset_depthmaps_01_4` = W, `_5` = N,
`_6` = canto, conferido com `walls_exterior_house_01_0/1`). Sangue de parede: o `splatBlood`
vanilla usa `0..3`, `8..11`, `16..19` pra parede W (`IsoGridSquare.splatBlood` 506–639).
`WallCracks.init`: 9 colunas por linha, `{2,2,2,1,1,1,0,0,0}` (W, N, canto). `WallVines.init`:
`idx = 24·k + 6·estágio + tipo`, tipos 0–1 W, 2–3 N, 4–5 canto.

| Set | No pack | Usados (lado) |
|---|---|---|
| `overlay_blood_floor_01_` | 43 (0–27, 32–46 com falhas) | nenhum desde a sprint 0034 (eram 37 de chão; o Johan achou feio no jogo) |
| `overlay_grime_floor_01_` | 84 | 82 de chão |
| `d_streetcracks_1_` | 118 | 118 (rachadura de chão) |
| `d_plants_1_` | 64 | 33 de chão (musgo, mato rasteiro) |
| `overlay_blood_wall_01_` | 64 | 11 W, 9 N (6 largos, de dois tiles, fora) |
| `overlay_grime_wall_01_` | 46 | 9 W, 9 N (cantos e pilares fora) |
| `d_wallcracks_1_` | 72 | 24 W, 24 N |
| `f_wallvines_1_` | 72 | 24 W, 24 N (4 estágios) |
| `overlay_graffiti_wall_01_` | 112 (0–98, 100–108, 112–115) | 22 desenhos W (47 peças), 25 N (64 peças); fora o 92 (sprint 0034) |
| `overlay_messages_wall_01_` | 36 (0–21, 24–31, 34–39) | 6 desenhos W (20 peças), 3 N (10 peças); fora 34–39 (sprint 0034) |

Outros que existem e ficaram de fora: `overlay_blood_fence_01_` (24), `blood_floor_small/med/large`
(1x), `overlay_graffiti_wall_02_` (64, não auditado). `d_floorleaves_1_` (12) e
`floors_burnt_01_` (29) entraram no chão na 0023. Lixo, objeto avariado e parede queimada: §16.6
(casa destruída).

### 16.4 Custo

- Marcador: zero Lua por quadro; o Java percorre a lista e manda um quad por textura (≤ 600
  marcadores × ≤ 4). Parede: **uma chamada Lua→Java por parede desenhada por quadro** (≤ 120),
  cada uma um sprite no mesmo caminho do fantasma de construção.
- Atualização (a cada 10 ticks): a regra pura custa ~3,5 µs por square no luajit sem JIT
  (`-joff`); no Kahlua, estimado 10–30× isso: o lote de 80 squares fica em poucos ms. Chamadas
  Java: ≤ ~1040 enquanto enche (getGridSquare, isFree, getWall×2, getObjects, luz, marcador),
  ~180 parado (luz em rodízio, paredes conferidas, visão das paredes); a 1ª vez, +404 `getTexture`. Contado em
  `overlays_budget`.
- **Teto que serve o perto:** com a reserva cheia, o raio efetivo encolhe pra antes do anel que
  não coube, e tudo fora dele (ou de outro andar) sai na hora; numa volta inteira com folga de 20%
  ele cresce um tile se o anel novo cabe (`n·(r+1)²/r² < 95%` do teto). Cada reserva marca o
  square como decidido uma vez (o chão e cada lado da parede à parte): o anel fora do raio do chão
  não é reolhado a cada volta. Parede de costas não entra na reserva (nem fica marcada): entra
  quando o jogador passa pro outro lado. Com 600 marcadores e ~85% do chão coberto, fica em ~13–15 tiles.
- `RenderOpaqueObjectsInWorld` só sai com o tile do mouse dentro do mundo
  (`IsoWorld.isValidSquare`, `renderOpaqueObjectsEvent` 82–92): mouse fora do mapa, sem parede
  naquele quadro.
- **UNKNOWN (roteiro):** o tempo de quadro de verdade com 600 marcadores e 120 paredes; se pesar,
  baixar `MAX_FLOOR`/`MAX_WALL` ou o `SCAN_BUDGET`.

### 16.5 O que o jogo mostrou (sprint 0021)

Prints do Johan de 05/10 (parede preta por cima do jogador, chão de dentro em cima do telhado,
sujeira em xadrez, arbusto por cima do jogador). Bytecode do B42.21 e packs, só leitura.

| Fato | Status | Evidência |
|---|---|---|
| Posição do `IsoMarker`: `setPos(III)` → `x = i + 0,5`, `y = j + 0,5`, `z = k + 0,01`, `zLayer = k`. É o único setter de posição (os três `init` chamam ele); `x/y/z` não têm setter float | CONFIRMED (bytecode) | `IsoMarkers$IsoMarker.setPos(III)` 0–32, `init(KahluaTable,IIILIsoGridSquare)` 64–69 |
| Desenho: quad do tamanho **recortado** da textura (`getWidth/getHeight` = região do pack, sem o quadro), `XToScreen − w/2`, `YToScreen − h`: base do recorte no centro do tile. `GenericSpriteRenderState.render` sem cutaway não soma `offsetX/Y` | CONFIRMED (bytecode) | `IsoSprite.renderTextureWithDepth` 151–211; `GenericSpriteRenderState.render(Texture,FFFFFFFF,Consumer)` 50–124 |
| Erro por sprite (quadro 2×: 128×256, diamante do chão centrado em (64, 224)): `(64 − (ox + w/2), 224 − (oy + h))`. Losango cheio: 32 px pra cima = meio tile. Compensar exato é impossível (tile inteiro anda 64/32 px na tela; `z` anda um andar) | medido | `scripts/audit_floor_sprites.py` |
| Ordem do quadro: `renderPlayers` (241) → itens, poças → `renderOpaqueObjectsEvent` (374) → `renderMovingObjects` (387) → por andar: piso translúcido, sombras, `WorldMarkers.renderGridSquareMarkers` (769), **`IsoMarkers.renderIsoMarkers` (784)**, objetos translúcidos (818) | CONFIRMED (bytecode) | `FBORenderCell.performRenderTiles` |
| O marcador **testa profundidade**, mas com **um valor só pro quad inteiro**, o do centro do tile: `IndieGL.enableDepthTest` (`renderIsoMarkers` 38) e `TextureDraw.nextZ = calculateDepth(x+0,5, y+0,5, z+0,01)·2 − 1` (`renderTextureWithDepth` 131–144). Tudo que fica atrás desse ponto em profundidade e sob o quad na tela leva o decalque por cima: personagem em tile de trás, base de parede; nos prints, também o telhado | CONFIRMED (bytecode) + visto no jogo | `IsoMarkers.renderIsoMarkers` 38; `IsoSprite.renderTextureWithDepth`; prints 6, 7, 9, 10 de 05/10 |
| `renderIsoMarkers` pula marcador com `active = false` (`setActive(Z)`); `setAlpha(F)` = `setA` | EXISTS | `renderIsoMarkers` 166–174; `IsoMarker.setActive`, `setAlpha` |
| `WorldMarkers.addGridSquareMarker`: textura esticada num quadrado do chão (`x ± size·0,69`), pra círculo; deforma decalque isométrico | CONFIRMED (bytecode) | `FBORenderWorldMarkers.render` 150–235 |
| `d_plants_1_*`: todos com `MoveWithWind` e `BlocksPlacement` (planta em pé); `d_streetcracks_1_*`: `FloorOverlay` | CONFIRMED | `media/tiledefinitions_erosion.tiles.txt` |
| Recorte de parede por jogador: `square:getPlayerCutawayFlag(pn, ms)` → bits 1 = N cortada, 2 = W (no FBO devolve `targetPlayerCutawayFlags[pn]`, o `ms` não pesa) | EXISTS | `IsoGridSquare.getPlayerCutawayFlag(IJ)` 0–12; `FBORenderCutaways.doCutawayVisitSquares` 354, 612–616 (bit 1, visitados ao norte), 710–716 (bit 2, a oeste); lido por `FBORenderCell.renderMinusFloor_DoorOrWall` 59–150 |
| Prédio: `square:isOutside()`, `square:getBuilding()`, `player:getBuilding()`, comparados com `~=` | CONFIRMED | `server/Farming/SFarmingSystem.lua:295`; `server/ClientCommands.lua:676`; `client/ISUI/ISWorldObjectContextMenu.lua:1679` |
| Profundidade de tela de um andar: `YToScreen` sobe a altura de 3 tiles na diagonal por andar (um prédio de 1 andar cobre na tela os squares até 3 atrás dele) | CONFIRMED (bytecode): `YToScreen = 16·escala·(x + y) − 96·escala·z`, um andar = 6 passos de `x+y` = 3 tiles na diagonal | `IsoUtils.YToScreen(FFFI)` 0–50 |

- **Escolha:** o deslocamento não se compensa. O pool do chão só tem decalque chato que não
  invade o centro dos tiles N, W e NW (heurística de vazamento: com o pé fora do centro, todo
  sprite alcança, porque o losango deslocado fica centrado no canto N do tile — review 0021).
  Quem garante o corpo limpo é o cliente: o decalque do tile do personagem e dos S, E e SE dele
  fica apagado — do jogador todo tick, de zumbis e jogadores do MP a até 10 tiles em rodízio.
  Visibilidade por prédio e sombra de prédio (inclusive o prédio do próprio jogador, cujas
  paredes N/W não são cortadas), não por `isCouldSee` (o cone de visão apagaria o chão às
  costas e faria o chão acender e apagar ao virar).
- **UNKNOWN (roteiro da 0021):** a latência do rodízio de zumbis (até ~2 voltas de 8 por tick)
  se vê? Prédio de 2+ andares deixa chão de fora em cima do telhado (a sombra conta 3 tiles)?

### 16.6 Anexado ao objeto (sprint 0023)

O `IsoMarker` sai depois dos personagens (§16.5) e o "apagar 4 tiles debaixo de cada
personagem" deixava um buraco que o Johan recusou no jogo. O caminho da erosão vanilla —
anexar o sprite ao `IsoObject` do piso ou da parede — sai no FBO do chunk, antes dos
personagens. Mas vai pro save com o objeto: a sprint inteira é sobre tirar antes de gravar.
Bytecode do B42.21 (`projectzomboid.jar`, só leitura). Decisão na
[ADR-017](adr-017-outro-mundo-anexado.md).

**Visto no jogo pelo Johan (05/10):** `floor:addAttachedAnimSpriteByName("overlay_grime_floor_01_5")`
sai embaixo do jogador; `wall:addAttachedAnimSpriteByName("f_wallvines_1_2")` funciona.

| Fato | Status | Evidência |
|---|---|---|
| Ordem do quadro: `renderOneChunk` (157; FBO do chunk: `renderFloor` → `renderAttachedAndOverlaySpritesInternal`) **antes** de `renderPlayers` (241); `IsoMarkers.renderIsoMarkers` em 784 | CONFIRMED (bytecode) | `FBORenderCell.performRenderTiles` |
| `addAttachedAnimSpriteByName(String)`: nome vazio sai; `IsoSprite.getSprite(manager, nome, 0)` lê o `namedMap` e volta **`null` pra nome desconhecido** (não cria sprite vazio, ao contrário de `getSprite` do Lua); `addAttachedAnimSprite(null)` sai; com sprite, `IsoSpriteInstance.get` (pool) → `addAttachedAnimSpriteInstance` (cria a lista se nula, `add` no fim, `invalidateRenderChunkLevel`). **Não** chama `flagForHotSave` | CONFIRMED (bytecode) + visto no jogo | `IsoObject.addAttachedAnimSpriteByName` 0–22, `addAttachedAnimSprite(IsoSprite)` 0–15, `addAttachedAnimSpriteInstance` 0–54; `IsoSprite.getSprite(IsoSpriteManager,String,I)` 0–17 |
| `RemoveAttachedAnim(I)`: índice fora sai; `Dispose`, `remove(i)` (os de trás andam um), `IsoSpriteInstance.add` (**volta pro pool**: o próximo anexo de qualquer objeto pode receber a mesma instância), invalida o nível | CONFIRMED (bytecode); usado no vanilla (`ISRemoveBush.lua:129`) | `IsoObject.RemoveAttachedAnim` 0–76; `IsoSpriteInstance.get` 0–47 |
| `RemoveAttachedAnims()` limpa a lista toda (blend de grama, decalque do mapa): **proibido pro mod** | CONFIRMED | `IsoObject.RemoveAttachedAnims` 0–86; `ISShovelGround.lua:63` ("remove blend tiles") |
| `getAttachedAnimSprite()` devolve a `ArrayList` viva (nil até o 1º anexo); `inst:getParentSprite():getName()` | CONFIRMED | `IsoObject.getAttachedAnimSprite` 0–4; `ISRemoveBush.lua:100-103` |
| Alfa por anexo: `renderAttachedSprites` põe `ColorInfo.a = inst.alpha` (146–149); `IsoSpriteInstance.SetAlpha(F)` e `SetTargetAlpha(F)` existem; `update()` é vazio (o alfa não volta sozinho) | EXISTS | `IsoObject.renderAttachedSprites`; `IsoSpriteInstance` (lista de métodos) |
| Recorte e prédio: o anexo da parede é cortado com ela (`CutawayAttachedModifier`, `renderAttachedSprites` 158–178); prédio apagado vale pro anexo (`isBlackedOutBuildingSquare`, `getBlackedOutRoomFadeRatio`, `renderAttachedAndOverlaySpritesInternal` 23–40); posição = a do objeto (`IsoSprite.render(inst, obj, x, y, z, …)` com `offsetX/offsetY/renderYOffset`, 404–438): não flutua | CONFIRMED (bytecode); **UNKNOWN** visual (roteiro) | `IsoObject.renderAttachedSprites`, `renderAttachedAndOverlaySpritesInternal` |
| `IsoObject.save` grava a lista de anexos inteira (ID do sprite pai), sem filtro | CONFIRMED (bytecode) | `IsoObject.save` 64–187 |
| `transmitUpdatedSpriteToServer` manda a lista de anexos (IDs) | CONFIRMED (bytecode) | `IsoObject.transmitUpdatedSpriteToServer` 88–138; chamado pelo cliente de MP em `ISDismantleAction.lua:86`, `ISMoveableSpriteProps.lua:1458,1474,2114,2127` |
| `GameWindow.save(Z)`: `OnSave` (302) antes de `IsoCell.save` (364); no cliente de MP, `OnSave` (68) e sai. `IsoCell.save` espera o `ChunkSaveWorker` (0–26) e chama `IsoChunkMap.Save` → `IsoChunk.Save(Z)` em todo chunk carregado, na mesma thread | CONFIRMED (bytecode) | `GameWindow.save`, `IsoCell.save(DataOutputStream,Z)`, `IsoChunkMap.Save` |
| Quem chama `GameWindow.save`: `GameWindow.exit`, `IngameState.updateInternal` (sair), **`SleepingEvent.wakeUp`** (acordar no solo), `ModalDialog.Clicked`, `GameLoadingState$1.runInner`, `LuaManager$GlobalObject.save` | CONFIRMED (bytecode) | varredura de referências a `GameWindow.save` |
| `OnPostSave` só sai na **saída** do jogo (`GameWindow.exit` 127/156, `IngameState.updateInternal` 207 e 1557); **não** depois do save de acordar | CONFIRMED (bytecode) | idem; vanilla: `ISPlayerData.lua:205` (`destroyAllPlayerData` no `OnPostSave`) |
| `IsoChunk.Save(Z)`: `Core.isNoSave()` ou `GameClient.client` → não grava (o cliente de MP nunca grava chunk) | CONFIRMED (bytecode) | `IsoChunk.Save(Z)` 5–47 |
| Chunk que sai do mapa: `IsoChunkMap.Up/Down/Left/Right` → `removeFromWorld` → `ChunkSaveWorker.Add` (fila; serializa depois, na thread do `WorldStreamer`); `chunkGridWidth` = 13 → o chunk que sai está a ≥ 48 tiles | CONFIRMED (bytecode) | `IsoChunkMap.Up` 201–208, `<clinit>` 74; `ChunkSaveWorker.Add`, `Update` 141, `WriteQueuedSave` 196 |
| Hot save (só solo): `IsoChunkMap.updateInternal` 323–429 serializa **na hora** o chunk com `requiresHotSave` (`ChunkSaveWorker.AddHotSave` 42 → `IsoChunk.Save(ByteBuffer,CRC32,Z)`); a bandeira vem de `IsoObject.flagForHotSave` (`addToWorld`, `removeFromWorld`, `transmitModData`, `syncIsoObject`, contêineres). Sem evento Lua | CONFIRMED (bytecode) | `IsoChunk.flagForHotSave` 0–12; `IsoChunkMap.updateInternal` |
| `LoadGridsquare(square)`: `IsoChunk.doLoadGridsquare` | CONFIRMED | bytecode; `client/DebugUIs/DebugScenarios.lua:101` |
| Quem anexa no vanilla: `CellLoader.DoTileObjectCreation` (`FloorOverlay` no piso 2018–2061; `WallOverlay`/`attachedN/W/SE` na parede 1673–1970; tampo 1602–1630); piso sólido novo **troca** o sprite (134–265, `setSprite`). Erosão: `ErosionObjOverlay.setOverlay`/`removeOverlay` (por ID); `WallVines.update` 296 | CONFIRMED (bytecode) | `CellLoader`, `ErosionObjOverlay`, `WallVines` |
| `floors_burnt_01_*`: `solidfloor`, `diamondFloor`, sem `FloorOverlay`; o vanilla usa como sprite de piso (`IsoGridSquare.BurnWalls` 1488), objeto de cinza (`client/Tests/TimedActionsTests.lua:593`) e chão do worldgen (`server/WorldGen/features/ground/burnt.lua`). **Ninguém anexa** | CONFIRMED (bytecode, Lua, `newtiledefinitions.tiles.txt:71445`) | idem |
| Ações do jogador que mexem nos anexos: `ISDestroyStuffAction.lua:313-321` (solo: a parede de canto nova **copia** os anexos), `ISShovelGround.lua:63/81` (limpa tudo), `ISRemoveBush.lua:100-137` (trepadeira por prefixo), `ISMoveableSpriteProps.lua:1456`, `ISDismantleAction.lua:86`. Fila: `ISTimedActionQueue.queues[personagem].queue[1]` (`ISTimedActionQueue.lua:138-155`); alvos em `square`, `object`, `item`, `thumpable` (`ISMoveablesAction.lua:274-280`, `ISDismantleAction.lua:107`, `ISDestroyStuffAction.lua:362`, `ISRemoveBush.lua:187`) | CONFIRMED (Lua vanilla) | idem |
| Tabela Lua do Kahlua (`KahluaTableImpl`) é um `Map` do Java percorrido por iterador: o mod não apaga chave no meio do `pairs` (junta e tira depois) | EXISTS (bytecode: `KahluaTableImpl(Map)`, `iterator()`) | `se.krka.kahlua.j2se.KahluaTableImpl` |
| `instanceof(obj, "IsoThumpable")`, `"IsoDoor"`, `"IsoWindow"`, `"IsoGridSquare"` | CONFIRMED | `server/ClientCommands.lua:705`, `server/BuildRecipeCode/buildRecipeCode.lua:27`, `shared/TimedActions/ISDeviceBatteryAction.lua:48` |

- **Escolha:** anexar ao piso (`getFloor`) e às paredes N/W (`getWall`) que não são
  `IsoThumpable`, `IsoDoor` nem `IsoWindow`; registro de cada instância posta; tirar só elas (mesma
  instância **e** mesmo nome, de trás pra frente); `OnSave` tira tudo e a atualização seguinte põe
  de volta; raio pela tela, 15 a 30 (sprint 0034, abaixo; além de 30 + 8 sai na hora, a cada 2 tiles andados); `LoadGridsquare` limpa
  `floors_burnt_01_*` vazado; a ação atual do jogador segura o square do alvo. Saem: `IsoMarker`,
  `RenderGhostTileColor`, luz relida, fade, visibilidade por prédio.
- **Custo** (mundo falso, `overlays_budget`): enchendo, ≤ ~2000 chamadas Java e ≤ ~410
  invalidações de nível por atualização (10 ticks), umas 9 atualizações; parado, ~165 (rodízio de
  20 alvos conferidos + a volta da varredura). `LoadGridsquare`: ~3–7 chamadas por square carregado.
- **UNKNOWN (roteiro da 0023):** o mato anexado ao piso fica bem (ele sai antes do que está atrás
  dele); o recorte de parede e o telhado com anexo; o custo de invalidar ~400 níveis de chunk por
  lote; o `LoadGridsquare` no cliente de MP.

**Raio pela tela (sprint 0034).** O Johan via o limite dos 15 tiles com o zoom longe. O raio
agora é o canto da tela do jogador 0 mais longe dele, no chão do andar dele, + 2, entre 15 e 30
(`NOM_DressingRules.radius`), relido a cada atualização (10 ticks). Bytecode do B42.21.

| Fato | Status | Evidência |
|---|---|---|
| `getPlayerScreenWidth/Height(i)` = `IsoCamera.getScreenWidth/Height(i)` (a tela do jogador, metade na tela dividida) | CONFIRMED | `ISSleepingUI.lua:16-17`; `LuaManager$GlobalObject.getPlayerScreenWidth(I)` 0–4 |
| `getCore():getZoom(i)` = `displayZoom · tileScale / 2` (1 sem FBO) | CONFIRMED | `ISMenuContextWorld.lua:77`, `ISSearchManager.lua:103`; `Core.getZoom(I)` 0–24 |
| A câmera trabalha no tamanho do FBO: `offscreenWidth(i) = int(getScreenWidth(i) · getZoom(i))` (idem altura). Por isso o pixel da tela entra × zoom (`ISMenuContextWorld.lua:77` faz igual) | CONFIRMED (bytecode) | `MultiTextureFBO2.getWidth(I)` 0–19, `Core.getOffscreenWidth(I)` 0–34 |
| `IsoUtils.XToIso(i, sx, sy, z) = (sx + offX + 2(sy + offY)) / (64T) + 3z`; `YToIso(i, sx, sy, z) = (sx + offX − 2(sy + offY)) / (−64T) + 3z`, com `offX/offY = IsoCamera.getOffX/getOffY(i)` = `int(PlayerCamera.offX + rightClickX)` e `T = Core.tileScale`. É o inverso exato de `XToScreen = 32T(x − y)`, `YToScreen = 16T(x + y) − 96T z` | CONFIRMED (bytecode) | `server/ISCoordConversion.lua:19-24`; `IsoUtils.XToIso(IFFF)` 0–36, `YToIso(IFFF)` 0–36; `IsoCamera.getOffX(I)` 0–8; `PlayerCamera.getOffX()` 0–11 |
| A câmera centra no personagem: `offX = XToScreen(x + deferedX, y + deferedY, zCam, 0) − offscreenW/2 + playerOffsetX`, `offY = YToScreen(…) − offscreenH/2 − offsetY · 1,5 + playerOffsetY`, `playerOffsetY = −56 / (2 / T)` (o centro da tela fica 0,875 tile atrás do jogador no Tiles2x); `zCam = getZ()` a pé | CONFIRMED (bytecode) | `PlayerCamera.center` 0–147; `IsoCamera.<clinit>` 46–54; `IsoCamera$FrameState.calculateCameraZ` |
| `math.huge` no Kahlua | EXISTS (bytecode) | `se.krka.kahlua.j2se.MathLib` registra `huge` = `Infinity` |

- **Números** (fake fiel acima, 1920×1080, Tiles2x): zoom 1 → canto a ~16,4 tiles → raio 19;
  zoom 0,5 e 0,75 → 15; 1,25 → 23; 1,5 → 27; 2 em diante → 30. `OFFSETS` vai até 30: 2821 deslocamentos (709 até
  15). A volta da varredura no raio 30 leva 36 atualizações (~6 s) com `SCAN_BUDGET` 80; o custo
  por atualização não muda (enchendo ~2060 chamadas Java e ≤ 411 invalidações; parado ~175).
- **Save:** saída em lote acima do raio da hora; na hora acima de 30 + 8 = 38 (constante: o zoom
  chegando perto tira o anel de fora em lote, 80 por atualização). **Sem supor FPS (review final da
  0034):** o `OnTick` é por quadro e a atualização a cada 10 ticks; a conta antiga (38 + ~5 de carro
  numa atualização < 48) só valia a 60 FPS. A 30 FPS e ~30 tiles/s o carro anda ~10 tiles entre
  atualizações e o anexo visto a 38 chegava aos 48 com o chunk saindo do mapa. Agora o corte de 38
  roda **no tick** em que o jogador passa de `MOVE_TILES` (2) desde o último corte, sem lote e sem
  esperar a atualização. Entre cortes nada passa de 38 + 2; no tick do corte o chunk pode sair antes
  do `OnTick` (o `IsoChunkMap` anda no update do mundo), com o passo daquele tick a mais. Carro a
  2 tiles por tick (~30 tiles/s a 15 FPS): 38 + 2 + 2 + 1 (o anexo é do square inteiro, o jogador
  anda em float) = **43 < 48**. Aguenta até ~6 tiles num tick (38 + 2 + 6 + 1 = 47). O chunk
  gravado está a ≥ 48 em Chebyshev, e Chebyshev ≤ euclidiana.
  **Salto:** não tem mais caso próprio (era ≥ 8 tiles num tick → tira tudo, o que um engasgo de
  FPS no carro disparava, com tudo revestido de novo). O teleporte cai no mesmo corte: o lugar novo
  está longe e tudo passa de 38. Um teleporte maior que ~6 tiles num tick tem o mesmo risco de antes
  (o chunk velho sair do mapa antes do `OnTick` daquele quadro).
  Custo (`overlays_fast_car_low_fps_never_past_hard`): o corte é só Lua até achar o que sai (o
  registro inteiro, a cada 2 tiles andados); o pior tick de carro a 1–2,24 tiles por tick fica em
  ~1960 chamadas Java, a ordem do enchimento (~1940 por atualização). O anexo mais longe medido:
  38,6–39,5 tiles.
- **Além da tela (sprint 0035, Tarefa 5): não feito.** A medição e as tabelas estão no
  [plano da sprint](../sprints/sprint-0035-silent-hill/plan.md) (Tarefa 5).
  - O zoom máximo do jogo é 2,5 (`MultiTextureFBO2.<init>` 4–61: `zoomLevelsDefault` =
    2,5, 2,25, 2, 1,75, 1,5, 1,25, 1, 0,75, 0,5, 0,25).
  - **A conta:** R + `SLACK` + `MOVE_TILES` + 2 (carro por tick) + 1 (square) < 48, então
    R + `SLACK` ≤ 42. Com `SLACK` 8, o maior R seguro é 34; com `SLACK` 2, 40. O 45 não cabe nem
    com `SLACK` 0.
  - **A folga:** hoje (38) o corte aguenta ~6 tiles num tick; em 42, só 2. Um engasgo pra 10 FPS
    no carro dá 3.
  - **O `SLACK`:** diminuir não causa pisca-pisca. O mod só põe anexo a até r ≤ `MAX_RADIUS` e só
    tira na hora acima de `MAX_RADIUS` + `SLACK`, então as faixas nunca se cruzam. Mas cada tile
    que sai do `SLACK` e vai pro raio sai da folga.
  - **O custo:** as chamadas por atualização quase não mudam com o raio (orçamentos), mas os
    anexos vivos e a volta crescem com R²: 4694 anexos e 36 atualizações no 30, 8481 e 63 no 40.
  - **O ganho:** em 1080p no zoom 2,5, a tela coberta vai de 84,6% (30) a 95% (34). Em 1440p e 4K
    o canto passa dos 48 tiles com qualquer raio. Andando, a cobertura além de 15 tiles é a mesma
    em qualquer raio: quem manda é a vazão da varredura (o `reseen()` a cada `RESEEN_TILES`
    zera o `seen`), não o raio.
  - **A trava:** `overlays_save_margin_invariant` falha se `MAX_RADIUS` + `SLACK` +
    `MOVE_TILES` + 3 ≥ 48.
- **A borda ao andar (sprint 0035, Tarefa 5c): feito.** O raio continua 30, e a margem do save não
  muda. O que mudou foi a varredura:
  - o `seen` não é mais zerado a cada 8 tiles: a âncora e o `RESEEN_TILES` saíram;
  - o square já visto custa só a chave, contada nas olhadas (`SCAN_BUDGET` × `LOOK_MULT`) e fora
    do lote de 80 que vai ao Java;
  - a atualização, se o jogador andou `MOVE_TILES` desde a última vez, esquece do `seen` o que
    passou de `radius` + `SLACK` (antes da varredura). Assim o `seen` fica do tamanho da área do
    raio, não do caminho. O valor é x e y num número só (`pack`). Se o esquecimento tira mais do
    que guarda (teleporte), a volta recomeça do mais perto. Até o review final da 0035 isso rodava
    no corte do tick: de carro (corte todo tick), uma volta no `seen` por tick, só Lua, que o
    teste de chamadas Java não via. A margem do save não depende dele (é o `stripWhere` do corte).
  - A 3 tiles/s, as faixas de 15–20, 20–25 e 25–30 tiles vão de 78%, 39% e 28% pra 100%, 99% e
    87%. A 6 tiles/s, de 32%, 22% e 18% pra 95%, 88% e 67%.
  - Custo a pé: ~900 → ~1400 chamadas Java por atualização (estresse: ~1360 → ~2400, teto
    2500). Carro em campo aberto: até ~2090 por tick. No estresse, ~3270 → ~3900 por tick: o lote
    de 80 agora vai inteiro pra square novo.
  - Testes: `overlays_walking_covers_screen_edge`, `overlays_seen_memory_bounded` (sem o
    esquecimento, 33212 squares em 520 tiles sem piso; com ele, até 3234),
    `overlays_leave_and_return_redressed`, `overlays_walking_cost_stress` e
    `overlays_reveal_walking_far`.
- **Teto de custo do carro na área densa (sprint 0035, Tarefa 5c): feito.** Estresse (parede N
  e W em todo square, densidade 3,2, zoom 2,5, raio 30), saindo do disco cheio, 220 ticks. O
  maior de cada parte num tick (uma rodada; a ordem do `pairs` varia: o pior tick, em 12
  rodadas, fica em 2005–2050 a 0,5 tile/tick, 1992–2059 a 1 e 2216–2284 a 2):

  | Carro | Corte duro | Retirada em lote | Conferência | Vestir | Pior tick |
  |---|---|---|---|---|---|
  | Antes, 0,5 tile/tick | 1581 | 1086 | 100 | 1872 | 3751 |
  | Antes, 1 tile/tick | 1598 | 455 | 86 | 1878 | 3898 |
  | Antes, 2 tiles/tick | 1628 | 431 | 80 | 1864 | 3851 |
  | Depois, 0,5 tile/tick | 1657 | 140 | 112 | 1865 | 2081 |
  | Depois, 1 tile/tick | 1646 | 137 | 106 | 1860 | 2088 |
  | Depois, 2 tiles/tick | 1650 | 116 | 64 | 1892 (446 no tick do corte) | 2248 |

  - O pior tick de antes era o corte de um anel cheio (~1600, os primeiros ~30 ticks) somado à
    atualização inteira no mesmo tick. A 0,5 tile por tick, a retirada em lote também tirava sem
    lote o que passava de 38 entre dois cortes.
  - **O corte sozinho fica em ~1650**, abaixo de 2500: ele continua inteiro, sem lote.
  - No tick em que o corte tirou alguma coisa, a atualização vai pro tick seguinte. A 0,5 e a
    1 tile por tick ela nunca cai em cima do corte. A 2 tiles por tick (corte em todo tick) ela
    roda com o lote de vestir ÷ `LIGHT_DIV` (4): 20 squares, ~450 chamadas.
  - Quem andou `MOVE_TILES` desde a atualização anterior (≥ 0,2 tile por tick) tira em lote
    `STRIP_BUDGET` ÷ 4 = 20 alvos. O que passou de 38 entra nesse lote como qualquer alvo fora do
    raio: o corte no tick já garante que nada passa de 38 + `MOVE_TILES`.
  - A margem do save não muda: anexo mais longe 40,0 (0,5), 39,5 (1) e 38,6 (2), dentro de
    38 + 2 + 1,5. A pé, nada muda: cobertura 100/99/87% a 3 tiles/s e 95/88/67% a 6 tiles/s;
    estresse a pé 2331–2436 por atualização (antes, 2335–2434).
  - Custo aceito: trocar de desenho (período ou densidade) dirigindo tira o desenho velho a
    20 alvos por atualização; o que fica pra trás o corte leva.
  - Teste: `overlays_car_cost_stress` (0,5, 1 e 2 tiles por tick, teto 2500, margem em todo
    tick, enche ao parar).
  - **Trabalho Lua do esquecimento (review final da 0035).** O mesmo teste conta as chaves do
    `seen` percorridas (`NOM_FogOverlays.seenVisits`). Voltas no `seen` em 220 ticks: antes 55,
    110 e 220 (0,5, 1 e 2 tiles por tick, média de 345, 350 e 261 chaves por tick); depois 21, 21
    e 20 (média de 130, 60 e 15). Trava: no máximo uma volta por atualização
    (⌈ticks ÷ `UPDATE_TICKS`⌉ + 1) e até 5417 chaves numa volta. Cobertura, margem e chamadas
    Java não mudaram.
- **UNKNOWN (roteiro da 0034):** o custo no jogo de ~2800 squares com anexo (invalidação de nível
  de chunk, FBO) no zoom longe; a câmera do jogo anda atrás do `tOffX` (`PlayerCamera.update`) e o
  carro adianta (`deferedX/Y`): o raio é dos cantos de verdade, mas no zoom longe em carro rápido
  a borda da tela pode ver o anel ainda enchendo; a tela dividida (só o jogador 0).

**Casa destruída (sprint 0034).** O Johan quer a erosão nas casas: "apagadas, acabadas, sujas,
pichadas". A parede de dentro ganha até 3 camadas e entram pichação e mensagem. Só leitura do
jogo instalado (B42.21): packs, arquivos de texto, Lua e bytecode. A regra está na
[ADR-017](adr-017-outro-mundo-anexado.md), decisão 7. A medida sai de
`scripts/audit_wall_sprites.py` → `tests/wall_sprites.lua`.

| Fato | Status | Evidência |
|---|---|---|
| Pichação e mensagem estão no `Tiles2x.pack` (não no `Overlays2x`), em quadro de 128×256 como as outras paredes | CONFIRMED (pack) | `scripts/audit_wall_sprites.py` |
| Lado por três caminhos, que batem: recorte (metade esquerda = W), `tileDepthTextureAssignments.txt` (`preset_depthmaps_01_4` = W, `_5` = N) e `attachedW`/`attachedN` na definição do tile | CONFIRMED | `media/newtiledefinitions.tiles.txt:162363` (`overlay_graffiti_wall_01_0`: `WallOverlay`, `attachedW`), `:162475` (`_16`: `attachedN`), `:164043` (`overlay_messages_wall_01_6`: `attachedW`); `tests/wall_sprites.lua` |
| Divergentes, fora do pool: `overlay_graffiti_wall_01_92` (recorte e profundidade W, definição `attachedN`); `overlay_messages_wall_01_34..39` ("WE SHOOT ON SIGHT": só `WallOverlay`, sem `attachedW/N`, conteúdo até x = 127, além da face) | CONFIRMED | `media/newtiledefinitions.tiles.txt:164211-164246` (34 a 39); `tests/wall_sprites.lua` |
| São desenhos de **1 a 5 paredes** cortados em peças de um tile. A peça que continua no vizinho encosta na borda da face (`hi` de uma, `lo` da seguinte). A ordem no sheet é a da tela, da esquerda pra direita: parede N em x crescente (`XToScreen = 32T(x − y)`), parede W em y decrescente. Montados assim, os desenhos leem certo ("KEEP OUT", "ALIVE INSIDE", "TEA BOYS") | CONFIRMED (medida + montagem conferida a olho, fora do repo) | `tests/wall_sprites.lua` (`lo`/`hi`); `IsoUtils.XToScreen` |
| Quem anexa no vanilla: o `CellLoader` põe `WallOverlay`/`attachedN/W` na parede ao carregar o mapa → nome vanilla, **não** entra no `R.own` | CONFIRMED (bytecode) | `CellLoader.DoTileObjectCreation` 1673 (`WallOverlay`), 1711 (`attachedW`), 1790 (`attachedN`) |
| Propriedade de sprite anexado não vai pro square: `RecalcProperties` soma só `IsoObject.getProperties()` (o sprite do objeto) | CONFIRMED (bytecode) | `IsoGridSquare.RecalcProperties` 150 (`IsoObject.getProperties`) → 232 (`PropertyContainer.AddProperties`) |
| **A coleta lê os anexos**: `forageSystem.getAffinitySpriteNames(obj)` junta o nome do sprite e o de cada `IsoSpriteInstance` anexado (`getName` = `parentSprite.getName`). Usado pelo ícone de coleta do cliente e pelo sorteio do servidor | CONFIRMED (Lua + bytecode) | `shared/Foraging/forageSystem.lua:1569-1584`; `client/Foraging/ISSearchManager.lua:321-335`; `server/Foraging/forageServer.lua:141-150`; `IsoSpriteInstance.getName` 0–7 |
| `trash_01_*` é afinidade "trash" da coleta, objeto móvel (`IsMoveAble`, `CanScrap`, `CustomName = Trash`). 31 peças passam no critério de decalque do chão (≥ 95% no losango, nada acima dele). **Não usado**: anexado, mudaria a coleta | CONFIRMED | `forageSystem.lua:245-261`; `newtiledefinitions.tiles.txt:232063`; `scripts/audit_floor_sprites.py` (`measure`) |
| `d_plants_1_*` (o mato que o mod anexa fora desde a 0023) é afinidade `genericPlants` da coleta: na névoa, o mato do mod pode dar ícone de coleta de planta | CONFIRMED (efeito colateral que já existia) | `forageSystem.lua:189-200` |
| `damaged_objects_01_*`: objeto em pé (sobe 25 a 125 px acima do losango, `StopCar`). **Não usado** | CONFIRMED | `newtiledefinitions.tiles.txt:30935`; medida |
| `walls_burnt_01_*`: sprite de parede inteira (`WallW`/`wall`, profundidade de parede e de canto, opaco na face toda), não decalque. **Não usado** | CONFIRMED | `newtiledefinitions.tiles.txt:253314`; `tileDepthTextureAssignments.txt` |

- **Escolha:** a parede de dentro empilha até 3 tipos diferentes (rachadura, sujeira, sangue,
  escrita em cima). Pichação e mensagem entram como desenho inteiro, num trecho de 6 paredes da
  fileira. O desenho do trecho é o mesmo dentro e fora; só a chance de aparecer muda. Só pichação
  e mensagem entram de novo; o lixo fica pra quando houver um decalque sem afinidade.
- **Custo** (`overlays_budget`): fora, quase igual (enchendo ~2060 chamadas e 417 invalidações,
  contra ~2000 e 411). Casa de estresse (parede N e W em todo square, densidade 3,2): enchendo
  ~1980 → ~2360 chamadas, 387 → 656 invalidações por atualização. Teto: 80 × (5 + 2 × 3).
- **UNKNOWN (roteiro da 0034, casa destruída):** a escrita anexada fica em cima do recorte
  certo (a peça é do mesmo quadro da parede); mensagem branca e apagada some em parede clara; a
  peça cortada quando a parede vizinha da fileira é porta, janela ou falta; o tempo de quadro
  numa casa grande com 3 camadas por parede; o ícone de coleta de planta no mato do mod.

### 16.7 Piso natural (hotfix do chão da 0035)

O Johan viu no jogo (06/10) o metal da branca em qualquer chão: painéis escuros na calçada e uma
grade de manchas de ferrugem na grama. Grama, terra e areia não ganham mais textura nossa
([plano da 0035](../sprints/sprint-0035-silent-hill/plan.md), "Hotfix do chão"). Só leitura do
B42.21 instalado: bytecode, Lua vanilla e tiledef.

| Fato | Status | Evidência |
|---|---|---|
| `IsoGridSquare.hasNaturalFloor()`: o nome do sprite do piso (`getFloor().getSprite().getName()`) começa com `blends_natural_01` ou `floors_exterior_natural`; sem piso, sprite ou nome, `false` | CONFIRMED (bytecode); sem uso no Lua vanilla | `IsoGridSquare.hasNaturalFloor` 0–68 |
| `hasSand()`/`hasDirt()`: o mesmo prefixo (com `contains`) e nomes exatos. Areia: `blends_natural_01_0/5/6/7`, `floors_exterior_natural_24`. Terra: `blends_natural_01_64/69/70/71` e `_80/85/86/87`, `floors_exterior_natural_16..19` | CONFIRMED (bytecode) | `IsoGridSquare.hasSand` 0–120, `hasDirt` 0–192 |
| `IsoObject.getTextureName()` = `sprite == null ? null : sprite.name`: um getter | CONFIRMED (bytecode) | `IsoObject.getTextureName` 0–16 |
| O vanilla testa o piso natural pelo prefixo de `square:getFloor():getTextureName()` (ou do nome do sprite) | CONFIRMED (Lua) | `shared/Foraging/forageSystem.lua:1679-1685` com `forageCategories.lua:82` (`floors_exterior_natural`, `blends_natural`); `server/BuildingObjects/ISEmptyGraves.lua:93`; `client/Mining/DiggingUtil.lua:136`; `shared/Moveables/ISMoveableSpriteProps.lua:1893-1894` |
| `blends_natural_01`: 28 pisos sólidos, 4 de cada `FloorMaterial` (Grass_Light, Grass_Medium, Grass_Dark, Dirt_Grass, Dirt, Clay, Sand). Só 20 têm a propriedade `natureFloor`, e nenhum dos 22 de `floors_exterior_natural_01` tem. Não naturais: `blends_street_01` (asfalto, `Road_01`..`Road_07`), `floors_exterior_street_01`, `floors_interior_*`. `blends_natural_02` é água | CONFIRMED (tiledef) | `media/newtiledefinitions.tiles.txt:8321` (`blends_natural_01`), `:9807` (`_02`), `:10013` (`blends_street_01`), `:71728`, `:72031`, `:73472` |

- **Escolha:** o prefixo do `hasNaturalFloor` (`NOM_DressingRules.NATURAL_PREFIXES`, `R.natural`)
  sobre `obj:getTextureName()` do piso que o overlay já pegou (`sq:getFloor()`). O resultado é o do
  `hasNaturalFloor`, mas por uma chamada com uso no vanilla. A propriedade `natureFloor` não serve:
  falta em 8 pisos de `blends_natural_01` e em todo `floors_exterior_natural_01`. A água
  (`blends_natural_02`) já sai antes, pelo `IsoFlagType.water`.
- **Custo:** uma ida ao Java (`getTextureName`) só no square em que a regra pôs textura nossa
  (`R.hasOwn`). Aí a regra roda de novo com `natural`, só Lua. Com `natural`, `R.floor` só tira as
  camadas nossas: sem elas, a resposta é igual (`dressing_rules_natural_only_drops_own`), então não
  ler o nome nos outros squares não erra nada. No mundo falso (`overlays_budget`), são 3 a 19
  leituras por atualização. Enchendo: 2097 → 2100 chamadas por atualização no campo e 2375 → 2378
  na casa. Estresse a pé: até 2433 (antes, 2331–2436). Carro: 2039, 2040 e 2231 por tick
  (0,5, 1 e 2 tiles por tick; antes, 2005–2050, 1992–2059 e 2216–2284).
- **UNKNOWN (roteiro do hotfix):** piso de mapa com nome natural que não é grama nem terra (nenhum
  conhecido). O piso trocado pelo jogador no meio da névoa (pá, saco de terra) só conta quando o
  square é vestido de novo; o nome não é relido a cada volta.

## 17. Dissolve e bloom (sprint 0018)

Bytecode do B42.21. Decisão na [ADR-016](adr-016-dissolve-e-bloom.md); a cadeia do `<m_Shader>`
e o `Alpha` por personagem estão na [spike-dissolve](../sprints/spike-dissolve/README.md).

### 17.1 Shader de peça

| Fato | Status | Evidência |
|---|---|---|
| `<m_Shader>` cria shader novo pelo nome; caixa diferente de um existente lança `IllegalArgumentException` | EXISTS | `ShaderManager.getOrCreateShader` 0–110 |
| Arquivos: `<nome>.vert` (peça com esqueleto), `<nome>_static.vert` (`m_Static`), `<nome>.frag` (os dois) | EXISTS | `ShaderProgram.getRootVertFileName` 0–43, `getRootFragFileName` 0–23 |
| Uniforms: `MatrixPalette`, `transform`, `HueChange`, `LightingAmount`, `Light0..4Colour/Direction`, `TintColour`, `Alpha`, `Texture` (+ veículo); `FinalScale`, `targetDepth`, `DepthBias` pelos setters; `ModelViewProjection` pelo `VertexBufferObject.setModelViewProjection` | EXISTS | `skinnedmodel.Shader.onProgramCompiled`, `setScale`, `setTargetDepth`, `setDepthBias` |
| Atributos pelo índice do elemento do vértice (`layout (location = N)`) | EXISTS | `VertexBufferObject.BeginDraw` 39–295 (`glVertexAttribPointer(i, …)`) |
| GL 2.1: reescrita linha a linha (`trim`): `#version` → 120; `layout … in T N;` → `attribute` (regex só com `[A-Za-z0-9]` no tipo e no nome); no `.vert` `out` → `varying`; no `.frag` `in` → `varying` (a regex `^in\s*(\S+)\s*(\S+)\s*;` pega também `int k;`!), `out vec4 colour` some, `colour = X;` → `gl_FragColor`; só `texture2DLod` vira `texture2D` | EXISTS | `ShaderUnit.processShaderSyntax` 32–458, padrões no `<clinit>`; `preProcessShaderFile` 47 (`trim`) |
| **Falha de compilação:** `compileFailed`, `destroy()` (programa 0) e erro do `DebugType.Shader` com o log do driver; ninguém confere: `Model.DrawSolid` 141–160 faz `effect.Start()` → `glUseProgramObjectARB(0)` (pipeline fixa: peça sem esqueleto nem textura, ou nada). Sem fallback no motor; o do mod é a opção "Dissolve" desligada (peça sem shader) | EXISTS | `ShaderProgram.compile` 147–308, `ShaderProgram.Start` 0–7 |
| **UNKNOWN:** compila no driver do Johan (passa no `glslangValidator` em 330 e na reescrita 120: `tests/test_dissolve_shader.lua`) | UNKNOWN | roteiro, passo 1 |

### 17.2 Alpha por personagem

| Fato | Status | Evidência |
|---|---|---|
| `setAlpha(IF)` (clamp 0..1, sai no servidor), `getAlpha(I)`, públicos | EXISTS | `IsoObject.setAlpha(IF)` 0–39, `getAlpha(I)` 0–14 |
| Personagem não anda o alfa no render | EXISTS | `IsoGameCharacter.isUpdateAlphaDuringRender` = false |
| Passo do jogo: `0.28 × GameTime.multiplier × taxa` em direção ao alvo | EXISTS | `IsoObject.updateAlpha(IFF)` 79–188 |
| O mod escreve `min(efeito, alfa do jogo)`: quem não está à vista (alvo 0) não aparece | — | `client/NOM_Dissolve.lua`, `dissolve_never_reveals_unseen_zombie` |

### 17.3 Morte

| Fato | Status | Evidência |
|---|---|---|
| `onKillDone` liga **depois** do `onKilled` (que dispara o `OnZombieDead`) | EXISTS | `IsoGameCharacter.Kill` 35–50 |
| Com `onKillDone`, `getItemVisuals` sai do `WornItems`: o modelo da animação de morte é feito dele | EXISTS | `IsoZombie.isUsingWornItems` 0–33, `getItemVisuals(ItemVisuals)` 0–38, `WornItems.getItemVisuals` 0–69 (visual de cada item vestido) |
| `WornItems.setItem(ItemBodyLocation, InventoryItem)` local; `InventoryItem.getBodyLocation()`, `getVisual()` públicos; `instanceItem` CONFIRMED (Lua vanilla) | EXISTS | métodos públicos de `WornItems`, `InventoryItem` |
| `IsoDeadBody.getOutfitName()` (`HumanVisual.getOutfit().name`), `setDoRender(Z)` (+ `setInvalidateNextRender`) | EXISTS | `IsoDeadBody.getOutfitName` 0–22, `setDoRender` 0–18 |
| Cliente de MP: `dieNetwork` faz `Kill` e logo `becomeCorpse`: sem janela de animação | EXISTS | `IsoGameCharacter.dieNetwork` 0–10 (§14.4) |
| No solo, o `OnZombieDead` do `client/` roda antes do do `server/` (ordem de carga); o `server/NOM_Eco.lua` limpa o `WornItems` do Eco: o cliente veste no tick seguinte | CONFIRMED (mod) | `server/NOM_Eco.lua` `onZombieDead`; `ecofx_sp_with_server_handler` |
| `IsoDeadBody.getWornItems()` público (o corpo copia o do zumbi no construtor, antes do `OnDeadBodySpawn`) | EXISTS | `IsoDeadBody.getWornItems`, `<init>` 661–710 |
| **UNKNOWN:** `resetModelNextFrame` durante a animação de morte refaz o modelo sem piscar nem travar a pose; o corpo some com `setDoRender(false)`; a casca Hazmat cobre o corpo e a cabeça fica de fora (máscaras 1 e 2 não estão na lista) | UNKNOWN | roteiro, passos 4–6 |

### 17.4 Bloom

- O `screen.frag` vanilla tem um bloom desligado (`BloomVal`, mipmap que o FBO da tela não gera).
  O do mod é uma passada própria no `screen.frag` do mod2 (spike-motor-visual §3).
- A intensidade do jogador vai na fração do gradiente do `SearchMode` (`ParamInfo.z·2/ParamInfo.y
  = 13 + bloom·0,25`, §15.4): não há outro float livre (`VarInfo.zw` nunca são escritos, mas o
  Lua não os alcança).

### 17.5 Casca no zumbi vivo (sprint 0022)

Bytecode do B42.21, varredura de todos os métodos de `IsoZombie` e dos leitores de
`getItemVisuals` em `IsoGameCharacter`.

| Fato | Status | Evidência |
|---|---|---|
| O campo `IsoZombie.itemVisuals` só é lido por `<init>`, `getItemVisuals`, `dressInClothingItem`, `dressInNamedOutfit`, `dressInPersistentOutfitID`, `useDescriptor`, `helmetFallFromVisuals` e `DoZombieInventory`; o `save` não está na lista (e só o `ReanimatedPlayers` o chama, fato 3) | EXISTS | varredura do `IsoZombie` |
| Rede: nada da lista (`ZombiePacket.set`, §14.3) | EXISTS | §14.3 |
| Na morte no solo, `DoZombieInventory` faz item vestido e loot de toda a lista antes do `OnZombieDead` (a casca viraria loot: o mod tira da lista, do `WornItems` e do inventário) | EXISTS | §14.4; `ember_dead_mid_mutation_loot_exact`, `ember_dead_after_swap_no_loot` |
| `getBodyPartClothingDefense` (40–80) e `playWeaponHitArmourSound` (34–91) pulam item cujo script não tem `BloodLocation` (`getBloodClothingType` nulo → `goto`); `cantBite` olha só lugares de máscara/capacete; `helmetFallFromVisuals` só `ChanceToFall > 0`. A casca (`base:zeddmg`, sem `BloodLocation`, defesa ou `ChanceToFall`) não muda combate | EXISTS | `IsoGameCharacter.getBodyPartClothingDefense`, `playWeaponHitArmourSound`, `IsoZombie.cantBite` |
| `base:zeddmg` multi-item: a casca não expulsa a peça nem a roupa no `WornItems.setItem` | EXISTS | §14.2 |
| `IsoObject.getTargetAlpha(I)`: o alvo do alfa por jogador que a visão dá (1 no servidor); o mod só usa casca e brasa com alvo > 0 no jogador 0 | EXISTS | `IsoObject.getTargetAlpha(I)` 0–14 (campo `targetAlpha[]`) |
| **UNKNOWN:** a malha Hazmat sem máscara sobre o corpo vivo: pele, cabelo ou roupa atravessando; a casca aparece em todo zumbi que vira variante à vista | UNKNOWN | roteiro da sprint 0022 |

## 18. Debug amigável (sprint 0020)

Verificado no B42.21 instalado (bytecode e Lua vanilla).

| Fato | Status | Evidência |
|---|---|---|
| Autocomplete do console do debug só sugere Java | EXISTS | `UIDebugConsole.InitSuggestionEngine` 0–15: `LuaManager$GlobalObject.getDeclaredMethods()` vai pra `globalLuaMethods` (reflexão, `java.lang.reflect.Method`); função Lua nunca entra e mod não estende. Saída do mod: `NOM.help()` |
| Tecla de mod nas opções | CONFIRMED (consumidor) | `client/PZAPI/ModOptions.lua:182-204` (`addKeyBind(id, nome, tecla, dica)`, `getValue()` devolve o código), save `:276-280`, load `:326-327`; tela `MainOptions.lua:2987-3010` (botão de tecla, `getText(option.name)`) |
| F7 é do vanilla em `-debug` | CONFIRMED (review) | `IngameState.updateInternal`, bloco só de debug, `bipush 65` → `GameKeyboard.isKeyPressed`, 547–606 → `EditVehicleState` (editor de veículos). F2, F8, F9 também são do debug (chunk debugger, `WorldMapEditor`, `SeamEditor`); F1–F6, F10, F11 têm bind em `shared/keyBinding.lua` |
| `Keyboard.KEY_INSERT` (210) livre | EXISTS | constante em `org/lwjglx/input/Keyboard.class`; a review varreu as 46 classes que leem o teclado e nenhuma usa. Padrão da tecla do painel |
| Janela com botões | CONFIRMED | `ISCollapsableWindow:derive` + `ISButton:new(x, y, w, h, título, alvo, onclick)` (`client/DebugUIs/ISFilmingToolsUI.lua`); `onclick(alvo, botão)` (`ISButton.lua:47`); `close()` só esconde (`ISCollapsableWindow.lua:134-136`); `createChildren` põe as alças de redimensionar pela altura do momento (`:26-50`) |
| Fora do UIManager não pega nada | CONFIRMED | `ISUIElement.lua:1365-1380` (`addToUIManager` instancia na primeira vez; `removeFromUIManager` → `UIManager.RemoveElement`); `UIManager.AddUI` tira antes de pôr (bytecode 0–28), repetir não duplica |
| Posição lembrada | CONFIRMED | `ISLayoutManager.RegisterWindow(nome, ISCollapsableWindow, janela)` (`client/TimedActions/ISBBQInfoAction.lua:29`; `ISLayoutManager.lua:6-60`: x, y e `visible` salvos e restaurados) |
| God / noclip / invisível | CONFIRMED | `client/ISUI/AdminPanel/ISAdminPowerUI.lua:31-53` (`is/setInvisible`, `is/setGodMod`, `is/setNoClip` no jogador local) e `:403` (`sendPlayerExtraInfo(player)` depois); no MP o servidor aplica as regras dele (UNKNOWN pra quem tem só `-debug` sem ser admin) |
| Modo deus completo (sprint 0033) | CONFIRMED | `NOM.godMode` liga junto `setGodMod` (`ISAdminPowerUI.lua:44`, lê `isGodMod` `:41`), `setInvisible` (`:36`) e `setZombiesDontAttack` (`:178`, lê `isZombiesDontAttack` `:175`), depois `sendPlayerExtraInfo` (`:403`) |
| Puxar zumbi (sprint 0033) | CONFIRMED (mesmo caminho do Sem-rosto) | dedicado: servidor manda `debugMove {id,x,y,z}` e o dono (`z:isLocal()`, §24) chama `NOM_SemRosto.move` (`teleportTo`, §ADR-007); solo: o processo é o dono. Não usa `semRostoMove`: o cliente dele exige destino fora da vista do jogador. Zumbi sem ID de rede (`getOnlineID() == -1`, solo): o servidor usa o mais perto de quem pede |
| Hora | CONFIRMED (solo) / EXISTS (MP) | `getGameTime():setTimeOfDay(h)` (`client/LastStand/LastStandSetup.lua:63`) só grava o campo (bytecode 0–5). **Nunca pra trás:** no dedicado a data dos clientes dessincroniza (`SyncClockPacket.processClient` → `serverNewDays++` → `advanceOneDay`) e o `getWorldAgeHours` volta (timers da névoa). Hora menor que a de agora vai como `h + 24`: o `GameTime.update` (938–972) tira 24, chama `advanceOneDay` e, no servidor, marca o sync |
| Spawn espalhado | CONFIRMED | `addZombiesInOutfitArea(x1, y1, x2, y2, z, n, outfit, femaleChance)` → `ArrayList` (`Steps.lua:2123`): n vezes `addZombiesInOutfit` em `Rand.Next(x1, x2)` (fim exclusivo, bytecode 0–54); outfit `nil` sorteia (`ISSpawnHordeUI.lua:73, 276`); nomes válidos por `getAllOutfits(false/true)` (`ISSpawnHordeUI.lua:71-72`). No servidor dedicado: UNKNOWN, o mesmo do Eco (item 2 abaixo) |
| Frente do jogador | CONFIRMED | `player:getForwardDirection():getDirection()` em radianos (`shared/Fishing/FishingRod.lua:286`) |

## 19. Névoa viajante e luz na névoa (mod3, sprint 0026)

Bytecode do B42.21 (`javap -c` no `projectzomboid.jar`). Tudo lido na thread principal, no `Core.EndFrame`.

| Fato | Status | Evidência |
|---|---|---|
| Lista de sons do mundo | EXISTS | `WorldSoundManager.instance` (estático final); `soundList` é `public final List<WorldSound>`. `WorldSound`: `x`, `y`, `z`, `radius`, `volume`, `life` (int), `sourceIsZombie`, `repeating` públicos; `sourceIsVehicle()` |
| Carros da célula | EXISTS | `IsoCell.getVehicles()` → `Set<BaseVehicle>`; `BaseVehicle extends IsoMovingObject` (`getX/getY/getZ`) |
| Luz ativa do personagem | EXISTS | `IsoGameCharacter.getActiveLightItems(ArrayList)`: mão secundária, primária e itens presos, cada um por `addActiveLightItem`, que só põe se `InventoryItem.isEmittingLight()` |
| Lanterna como o jogo monta | EXISTS | `IsoGameCharacter$TorchInfo.set(IsoPlayer, InventoryItem)`: posição do jogador, direção `IsoPlayer.getLookVector(Vector2)`, `getLightDistance()` (int), `getLightStrength()`, `isTorchCone()`, `getTorchDot()` |
| Farol como o jogo monta | EXISTS | `TorchInfo.set(VehiclePart)`: local = (`offset.x * extents.x / 2`, 0, `offset.y * extents.z / 2`) → `BaseVehicle.getWorldPos(local, out)` dá x, y, z do mundo; direção `getForwardVector` (x, z), invertida se `getId()` contém `"Rear"`; `VehiclePart.getLightDistance()`, `getLightIntensity()`, `VehicleLight.dot`, `r/g/b`. Faróis: `BaseVehicle.getHeadlightsOn()`, `getLightCount()`, `getLightByIndex(i)` |
| Névoa vanilla zerável por quadro (sprint 0028) | EXISTS | `ImprovedFog.update()` é chamado no `IsoWorld.updateInternal` (48), antes do desenho (`FBORenderCell.renderFog` → `startRender`/`renderRowsBehind`/`endRender`); o `update` recalcula `baseAlpha` pela `ClimateManager.getFogIntensity()` (43–73) a não ser com `enableEditing`; `setBaseAlpha(float)` é público e estático. Patch `@OnExit` no `update` zera pro quadro. Também exposto ao Lua (`NewFogDebug.lua:159-244`) |
| Por que a vanilla deixa faixa embaixo | EXISTS | linhas de `minY` a `maxY` pela tela (`IsoCamera.getOffscreenHeight`), com `maxYOffset = -5` no `<clinit>`; no jogo, `setMaxYOffset(12/25)` não tirou a faixa com zoom afastado; desligar a vanilla tirou (prints da 0028) |
| UNKNOWN | — | o raio real dos sons de tiro e explosão (o mod usa raio ≥ 20 como "alto"); se o facho da lanterna na névoa bate com a luz do jogo (roteiro da 0026) |

## 20. Cerca baixa vs parede (mod3, sprint 0032)

Bytecode do B42.21 e Lua vanilla. A névoa passa por cima da cerca baixa e para na parede e na cerca alta.

| Fato | Status | Evidência |
|---|---|---|
| Flag do quadrado | EXISTS | `IsoGridSquare.has(IsoFlagType)` (público, bytecode) |
| Cerca baixa na borda N/W do quadrado | EXISTS | `ISClimbOverFence.lua:48`: `square:has(IsoFlagType.HoppableN)` = cerca na borda norte (o personagem com `y < square.y` está ao norte); sem ela, a borda oeste (`HoppableW`) |
| "Pulável" é só a baixa | EXISTS | `IsoObject.getHoppableDirection()` testa só `HoppableN`/`HoppableW`; a alta é `isTallHoppable()` (`TallHoppableN`/`TallHoppableW`) |
| `isHoppableTo` não serve | EXISTS | `IsoGridSquare.isHoppableTo` → `isHoppable(edge)` → `getHoppableOrWindowFrame` → `IsoObject.isHoppableOrWindowFrame`: conta moldura de janela, que é buraco na parede |
| Cerca baixa bloqueia o `isBlockedTo` | UNKNOWN | provável (o personagem tem que pular); o `Flow` não depende disso: cerca baixa vira face aberta com altura de qualquer jeito |

## 21. Sirene que congela (sprint 0033)

`shared/NOM_SirenFreeze.lua`: durante os 30 s de fuga depois da sirene, todo zumbi que este processo
simula fica parado, virado pra direção dela (sprint 0034: pro jogador vivo mais perto, §23). No solo é o próprio processo
(`server/NOM_FogEvent.lua`); no MP, o cliente dono (`client/NOM_FogClient.lua`, comandos
`siren`, `fog` e `sirenStop`). Não há API nova além do `faceLocationF`.

| Fato | Status | Evidência |
|---|---|---|
| `z:setUseless(true)` / `z:setTarget(nil)` | CONFIRMED | §3.2 e §13 (uso vanilla em `client/DebugUIs/DebugContextMenu.lua:566,673`) |
| `z:faceLocationF(x, y)` | EXISTS | `IsoGameCharacter.faceLocationF(FF)Z` (bytecode, `javap`); uso vanilla `client/BuildingObjects/TimedActions/ISBuildAction.lua:248` (`self.character:faceLocationF(self.x + 0.5, self.y)`) |
| `z:isMoving()` (só no log do `-debug`, contagem `andando=`) | EXISTS | `IsoGameCharacter.isMoving()Z` (bytecode, `javap`, 0–23): devolve o campo `isMoving`; no `IsoPlayer` com `isAttackAnimThrowTimeOut()` dá `false`. Nenhum uso no Lua vanilla. Não decide nada: o congelamento para todo zumbi local pelo `halt` |
| O useless viaja na rede no pacote do dono | EXISTS | §3.2 (`NetworkZombieAI.set` → `getBooleanVariables`): a cópia remota não precisa ser tocada |
| Dono = `z:isLocal()`; cópia remota = `not z:isLocal()` | CONFIRMED (bytecode) | §24. Até a sprint 0034 o teste era `isRemoteZombie()`, que no solo dá `true` pra todo zumbi: no jogo (2026-10-06) a sirene não congelou ninguém (`congelados=0 ... pulados morto/remoto/jogo=0/20/0`) |
| `resetForReuse` não limpa o useless | EXISTS | §3.2; por isso o `OnZombieCreate` do módulo solta o objeto reaproveitado que estava congelado |
| `Events.OnTick`, `OnZombieDead`, `OnZombieCreate` | CONFIRMED | já usados pelo mod (§3, §10, §11.2) |
| Dedicado: sem `sirenStop` quando a névoa abre | decisão | o cliente solta ao receber `fog {on=true}` ou, sem comando, 15 s (`SAFETY_MS`) depois do fim da sirene |
| Posse que chega **depois** do stop (review final da 0034): o useless do dono antigo vem no pacote (§3.2) num zumbi que a passada do stop não pegou | decisão | por `SWEEP_MS` (10 s reais) depois do stop, o `F.tick` segue em rodízio (`BATCH` por tick) soltando zumbi local useless, menos a Carpideira parada (`NOM_Carpideira.still`), o Estalador que este processo cegou (`NOM_VariantAI.blinded`, exposta pra isso) e o useless do jogo. Sem API nova. Posse que chega depois dos 10 s fica presa (UNKNOWN de MP, README da 0034) |
| O useless **não para quem já anda** | EXISTS | `PathFindState.execute` não lê `isUseless` (bytecode, `javap`); só `WalkTowardState.enter` (106) e `ZombieIdleState` leem. No jogo (2026-10-06) os zumbis não pararam na sirene |
| Parar o zumbi andando: `getPathFindBehavior2():cancel()`, `setPath2(nil)`, `setVariable("bPathfind", false)`, `setVariable("bMoving", false)` | EXISTS | é o que o `PathFindState.execute` faz ao chegar (128–149); `setVariable` em zumbi: `client/DebugUIs/DebugContextMenu.lua:642-643`; `cancel` + `setPath2(nil)`: `client/TimedActions/WalkToTimedAction.lua:49-50` (métodos de `IsoGameCharacter`). Refeito a cada passada do lote |
| UNKNOWN | — | se a troca de estado sai do `PathFindState`/`WalkTowardState` no mesmo frame (o `WalkTowardState.execute` mexe em `bPathfind`/`bMoving`); se o zumbi useless parado mantém o `faceLocationF` ou volta a girar sozinho. Conferir no jogo pelo log `[NOM] sirene congelados=N andando=M` (`-debug`) |

## 22. Aparelhos do Outro Mundo (sprint 0034)

`client/NOM_Devices.lua` (regras em `shared/NOM_DeviceRules.lua`): TV, rádio, caixa de som e
rádio de carro perto do jogador 0 chiam e "falam" no presságio e na névoa aberta, ligados ou
não. Atmosfera local (ADR-007): nada vai pra rede nem pro save, não chama zumbi e o aparelho
não muda de estado. Bytecode do B42 instalado (`javap -c -p`).

| Fato | Status | Evidência |
|---|---|---|
| `getZomboidRadio()` global | CONFIRMED | `server/radio/ISDynamicRadio.lua:32`, `client/RadioCom/RadioWindowModules/RWMGeneral.lua:69` |
| `ZomboidRadio:getDevices()` → `ArrayList<WaveSignalDevice>` com todo `IsoWaveSignal` (TV, rádio) e toda `VehiclePart` com `DeviceData` em chunk carregado | EXISTS | bytecode `ZomboidRadio.getDevices` (devolve o campo `devices`); `IsoWaveSignal.addToWorld`/`removeFromWorld` → `RegisterDevice`/`UnRegisterDevice`; `VehicleParts.addToWorld` registra parte com `getDeviceData() ~= nil`; chunk que descarrega chama `removeFromWorld` (`IsoChunk.removeFromWorld` 464) |
| `WaveSignalDevice`: `getX/getY/getZ` (float; a da `VehiclePart` é a posição do carro), `getDeviceData()` | EXISTS | `javap zombie.radio.devices.WaveSignalDevice`; `VehiclePart.getX` 0–9 |
| `dd:getIsTelevision()` | CONFIRMED | `RWMGeneral.lua:67` |
| `dd:isVehicleDevice()`, `dd:getIsTurnedOn()` | CONFIRMED | `shared/RadioCom/ISRadioAction.lua:63-64` |
| "Pode ligar": `getIsBatteryPowered() and getPower() > 0 or canBePoweredHere()` (no carro, `canBePoweredHere` = bateria do carro) | CONFIRMED | `ISRadioAction.lua:57`; bytecode `DeviceData.canBePoweredHere` 0–121 |
| Rádio de carro instalado: `part:getInventoryItem()` | CONFIRMED | `client/Vehicles/ISUI/ISVehicleDashboard.lua:541` |
| `part:getVehicle()` | CONFIRMED | `shared/Vehicles/TimedActions/ISRepairLightbar.lua:91` |
| `getWorld():getFreeEmitter(x, y, z)` → emitter do pool já posicionado; o pool devolve o emitter quando ele fica vazio | EXISTS | bytecode `IsoWorld.getFreeEmitter(FFF)` 0–16; `IsoWorld` 8947–8990 (`currentEmitters` → `freeEmitters`); `getWorld()` CONFIRMED `client/Traps/CTrapGlobalObject.lua:32` |
| `emitter:playSoundImpl(nome, false, nil)` → id, **local** (sem pacote), no emitter do pool | CONFIRMED | bytecode `FMODSoundEmitter.playSoundImpl(String,boolean,IsoObject)` 0–6 → `(String,IsoObject)` 0–24. **NÃO use `(nome, nil)` no `FMODSoundEmitter`:** ele também tem `(String,IsoGridSquare)` (1208–1235, lê `square.x`), o Kahlua escolhe esse com nil e dá NPE (console.txt, 2026-10-06). O `(nome, nil)` de `shared/TimedActions/ISAddItemInRecipe.lua:44` é no emitter de personagem, que não tem o overload do square |
| `vehicle:playSoundImpl(nome, nil)` = `getEmitter():playSoundImpl`; o emitter segue o carro | EXISTS | bytecode `BaseVehicle.playSoundImpl` 0–9, `BaseVehicle.updateSounds` 96–113 |
| `emitter:setVolume(id, v)`, `isPlaying(id)`, `stopSoundLocal(id)` | CONFIRMED | §4.3 |
| Volume que sai = volume da instância (`setVolume`) × `volume` do clip no script | CONFIRMED (bytecode) | `FMODSoundEmitter$Sound.getVolume` 0–23 (`volume * clip.getEffectiveVolume()`) |
| `emitter:playSound`, `getSoundManager():PlayWorldSound`, `deviceData:playSoundSend` mandam pacote no cliente de MP | CONFIRMED (bytecode) | `FMODSoundEmitter.playSound(String)` 0–107; `SoundManager.PlayWorldSound` 12–35; `ISRadioAction.lua:63` |
| O emitter do próprio aparelho (`dd:getEmitter()`) só existe ligado e com ouvinte a até 16 tiles | CONFIRMED (bytecode) | `DeviceData.updateEmitter` 0–143 (`cleanSoundsAndEmitter` fora disso) |
| Som com `distanceMax` não zera depois dele (rolloff inverso do FMOD) | LIKELY | nenhum modo de rolloff no jar; `FMOD_System_Set3DSettings(1, 1, 1)`: o cliente para o som a 20 tiles |
| Som tocado não chama zumbi; o que chama é `addSound` | CONFIRMED | §4.2 |

Decisões: o emitter do pool é parado só pelo id (`stopSoundLocal`), nunca por `stopAll`, porque
outro sistema pode estar usando o mesmo emitter. O rádio instalado num carro durante a sessão
pode só entrar na lista quando o carro voltar ao mundo (`VehiclePart.createSignalDevice` não
registra): sem fallback pelos veículos até o jogo mostrar que faz falta. O grito do Corredor não
chega ao cliente pelo Lua (`sendPlaySound` do servidor), então só o da Carpideira
(`NOM_Carpideira.onScream`) faz o aparelho respirar na vermelha.

| UNKNOWN | — |
|---|---|
| tamanho da lista numa cidade, e se os aparelhos das casas a ~15 tiles estão nela no cliente de MP | `getZomboidRadio():getDevices():size()` no console |
| atenuação real com `distanceMin` 2 e `distanceMax` 18; oclusão atrás de parede | ouvir no jogo |
| `stopSoundLocal(id)` para mesmo o som de um emitter do pool que já se afastou | ouvir no jogo |

## 23. Sirenes posicionais (sprint 0034)

`shared/NOM_Siren.lua` (posições, sons e atrasos em `shared/NOM_SirenSpotsRules.lua`): 5
sirenes por jogador local, todas de 150 a 500 tiles (tarefa 3, pedido do Johan em 2026-10-06:
"não quero que fique gritando no ouvido do jogador"), pelo menos 40° entre vizinhas, a
primeira na hora e as outras 4 cada uma na sua janela (0,3–1, 1,3–2, 2,3–3 e 3,3–4 s, então
pelo menos 0,3 s entre duas), em ordem de direção embaralhada; o som de cada uma sai da lista
da névoa sem repetir no coro, com afinação sorteada por sirene (`pitch`, 0,95 a 1,05).
Cada uma num emitter do mundo, parado onde foi posto, com a mesma técnica da §22
(`getFreeEmitter` + `playSoundImpl`, afinada por `setPitch(id, fator)` e parada por
`stopSoundLocal(id)` no `sirenStop` e no cancelamento do solo). O congelamento (§21) vira cada zumbi pro jogador vivo mais perto.
Bytecode do B42 instalado.

| Fato | Status | Evidência |
|---|---|---|
| As 4 atrasadas contam o atraso como a fuga (`NOM_FogEventRules.countdown`, review final da 0034): param com `isGamePaused()` e cada tick desconta no máximo `MAX_STEP_MS`; antes seguiam `getTimestampMs` e entravam com o jogo pausado | CONFIRMED | §11.2 (`isGamePaused`, uso vanilla `client/ISUI/ISJoystickButtonRadialMenu.lua:68`, `client/Foraging/ISSearchManager.lua:1462`); se o som que já toca pausa junto segue UNKNOWN (§11.3) |
| O jogo não corta som de arquivo 3D por distância: nada em `FMODSoundEmitter.addSound` (chamado pelo `playClip`) nem no `FileSound.tick` compara a distância do ouvinte com o `distanceMax`; o `tick` só posiciona (`Set3DAttributes`, z × 3), passa `Set3DMinMaxDistance(distanceMin, distanceMax)` e a oclusão | CONFIRMED (bytecode) | `FMODSoundEmitter.addSound` 259–487 (ramo `file`); `FMODSoundEmitter$FileSound.tick` 52–264 (`Set3DAttributes`), 353–386 (`Set3DLevel` só abaixo de 2 tiles do ouvinte), 893–908 (`Set3DMinMaxDistance`) |
| O pool do `IsoWorld` faz `tick` em todo emitter em uso, sem filtro de distância, e só devolve o vazio | CONFIRMED (bytecode) | `IsoWorld` 8930–8990 (`currentEmitters` → `freeEmitters` quando `isEmpty`) |
| Square do emitter fora da célula carregada (a 150–500 tiles, quase sempre) só pula a oclusão: o som toca | CONFIRMED (bytecode) | `FileSound.tick` 909–936 (`getGridSquare` nulo → salta pro fim, 1533) |
| Sem modo de rolloff explícito: inverso do FMOD, ganho `distanceMin / d` entre `distanceMin` e `distanceMax`, e constante depois (não zera) | LIKELY | §22 / `api-aparelhos.md` §5; `FMOD_System_Set3DSettings(1, 1, 1)` |
| `getOnlinePlayers()`: servidor = `GameServer.getPlayers`, cliente = `GameClient.getPlayers` (o `IDToPlayerMap`: os jogadores que o cliente conhece), solo = `ArrayList` vazia | CONFIRMED | uso vanilla no cliente `client/Chat/ISChat.lua:560`; bytecode `LuaManager$GlobalObject.getOnlinePlayers` 0–30, `GameClient.getPlayers` 0–42 |
| `emitter:setPitch(id, fator)` existe no `FMODSoundEmitter` (classe exposta ao Lua), com um overload só: `setPitch(long, float)`, a mesma conversão do id que o `setVolume(long, float)` já usa | EXISTS | `javap fmod.fmod.FMODSoundEmitter` (o pacote é `fmod.fmod`, não `zombie.audio`); abstrato em `zombie.audio.BaseSoundEmitter`; `LuaManager$Exposer` 163–165 (`setExposed(FMODSoundEmitter)`). Nenhum uso no Lua vanilla |
| `setPitch` é **local**: só grava `Sound.pitch` e, se o id bate, escreve no `DebugLog` ("Set pitch for ToStart/Instance", uma linha no console por sirene). Nenhum pacote | CONFIRMED (bytecode) | `FMODSoundEmitter.setPitch` 0–112: dois laços (`toStart` 3–53, `instances` 59–109), `putfield Sound.pitch` 47 e 103 |
| Pegadinha: o id **não filtra**: o `lcmp` (35 e 91) só decide o log; o `putfield` vale pra todo som do emitter. Com o emitter do pool vazio e só a sirene nele, afina só ela | CONFIRMED (bytecode) | `FMODSoundEmitter.setPitch` 36 `ifne 44` e 92 `ifne 100` pulam só o `DebugLog.log` |
| Funciona em som de arquivo (`clip { file = ... }`): o `addSound` copia o `pitch` do clip (padrão 1,0) pro `FileSound`, e o `FileSound.tick` passa o campo pro canal no início e em todo tick, mesmo com o square fora da célula carregada | CONFIRMED (bytecode) | `FMODSoundEmitter.addSound` 410–416 (`GameSoundClip.pitch` → `FileSound.pitch`); `GameSoundClip.<init>` 9–11 (1,0); `FileSound.tick` 179–187 e 1747–1755 (`FMOD_Channel_SetPitch`), 936 `ifnull 1533` segue até 1755 sem `return`. O `EventSound` (FMOD Studio) não lê o campo |
| O FMOD muda tom e velocidade juntos (fator 1,05 = +84 cents e 5% mais curto) | LIKELY | semântica de `FMOD_Channel_SetPitch` (multiplicador da frequência de reprodução) |

Alternativa descartada: o campo `pitch` do clip no script de som (`GameSoundScript` 176–192 →
`GameSoundClip.pitch`) é fixo por som; afinação por sirene exigiria variantes declaradas
(5 tons × 31 sons), e o `setPitch` em tempo de execução faz o mesmo sem nenhuma.

Decisão (audibilidade, tarefa 3): as 31 sirenes oficiais (`NOM_SirenWhite1`–`9`,
`NOM_SirenRed1`–`9`, `NOM_SirenBlack1`–`13`) são declaradas com `distanceMin` 50 e
`distanceMax` 500. Com o rolloff inverso, uma sirene sai a −9,5 dB em 150 tiles e −20 dB em
500 (queda de 10,5 dB na faixa, que é o que separa "perto" de "longe" no coro), e o
`distanceMax` em 500 faz a queda valer até o fim da faixa. Os arquivos têm RMS ~ −12 dBFS
(~ −12 LUFS); com 5 distâncias uniformes em [150, 500], a soma das potências esperada é
`5 × 50² / (150 × 500)` = −7,8 dB, ou seja ~ −20 LUFS no ouvido, contra −13,4 a −19,4 LUFS da
sirene perto antiga (−7,4 LUFS no arquivo, a 40–80 tiles com `distanceMin` 20). Como o jogo
não corta, **o emitter fica na posição sorteada**, sem aproximar. A distância que o FMOD não
faz vem embutida no arquivo (`scripts/gen_sounds.py`, `eco_cidade`): passa-baixa de ar
(4 kHz, 2ª ordem), cinco reflexões de cidade de 0,31 a 1,47 s (ganho 0,45 → 0,12, cada vez
mais escuras, atrasos ±8% por sirene) e cauda de reverb distante (rt60 2,6 s).

Jogadores do congelamento: os locais (`getNumActivePlayers` + `getSpecificPlayer`) e, no
cliente de MP, os do `getOnlinePlayers()`; o mais perto até `NOM_SirenFreeze.RANGE` (100 tiles).
Sem jogador nesse raio, o zumbi congela e fica virado como estava.

| UNKNOWN | — |
|---|---|
| a 500 tiles (−20 dB, ~ −32 LUFS no ouvido) a sirene ainda se ouve sobre o drone e a chuva? o coro de 5 incomoda? | ouvir no jogo |
| o FMOD não virtualiza (corta) canal baixo com muitos sons tocando (5 sirenes + drone + aparelhos) | ouvir na cidade, com a névoa subindo |
| o pan do FMOD a 150–500 tiles dá direção clara (o emitter está fora da célula carregada) | ouvir girando a câmera |
| o `IDToPlayerMap` do cliente traz a posição atual dos jogadores longe dele | MP com dois jogadores |
| a afinação de 0,95 a 1,05 se ouve como aparelhos diferentes, sem soar desafinado nem "fita acelerada" | ouvir o coro; com `-debug`, o `tom=` de cada sirene sai no console |

## 24. Dono do zumbi: `isLocal`, não `isRemoteZombie` (sprint 0034)

Visto no jogo (solo, `-debug`, 2026-10-06): a sirene não congelou nenhum zumbi, com o log
`[NOM] sirene congelados=0 ... lista=104 pulados morto/remoto/jogo=0/20/0`. O lote inteiro foi
pulado como cópia remota, no solo. Causa: `isRemoteZombie()` pergunta "este zumbi tem dono de
rede?", e no solo nenhum tem. Bytecode do B42 instalado (`javap -c -p`).

| Fato | Status | Evidência |
|---|---|---|
| Todo zumbi tem um `NetworkZombieComponent` | EXISTS | `IsoZombie.registerECSComponents` 0–14 (`new NetworkZombieComponent(this)`) |
| `IsoZombie.isRemoteZombie()` = `isRemote()` | EXISTS | `IsoZombie.isRemoteZombie` 0–4 |
| `IsoGameCharacter.isRemote()` (`public final`) = `NetworkComponent.isRemote()`; sem componente, `false` | EXISTS | `IsoGameCharacter.isRemote` 0–28 (`tryGetECSComponent(NetworkComponent)`, `PZOptional.ifPresent` com padrão `false`) |
| `NetworkZombieComponent.isRemote()` = `authOwner == null` | EXISTS | `NetworkZombieComponent.isRemote` 0–12 |
| Só o cliente de MP chama `setOwner`: `NetworkZombieSimulator.becomeLocal` põe `GameClient.connection`, `becomeRemote` limpa, `parseZombie` também mexe. No solo ninguém chama, então **`isRemoteZombie()` dá `true` pra todo zumbi no solo** | EXISTS | `zombie.popman.NetworkZombieSimulator.becomeLocal` 6–9, `becomeRemote` 32–37, `parseZombie` 823–844 |
| `IsoGameCharacter.isLocal()` (`public final`) = `NetworkComponent.isLocal()`; sem componente, `true` | EXISTS | `IsoGameCharacter.isLocal` 0–28 (padrão `true`) |
| `NetworkComponent.isLocal()` = `(not isClient() and not isServer()) or not isRemote()`, com `isClient` = `GameClient.client` e `isServer` = `GameServer.server` | EXISTS | `NetworkComponent.isLocal` 0–26, `isClient` 0–3, `isServer` 0–3 |
| Solo: `isLocal()` = `true` pra todo zumbi. Cliente de MP: `true` só no zumbi de que ele é dono (`authOwner ~= nil`), igual ao `not isRemoteZombie()` de antes | EXISTS | as duas linhas acima |
| Uso vanilla de `isLocal()` em personagem (método de `IsoGameCharacter`, vale pro `IsoZombie`) | CONFIRMED | `client/Fishing/FishingHandler.lua:16` (`player:isLocal()`), `client/ISUI/ISTradingUI.lua:7` |
| Nenhum Lua vanilla chama `isRemoteZombie` | CONFIRMED | `rg isRemoteZombie media/lua` vazio; só o Java (`NetworkZombieAI.parse` 204 e 388, que roda no cliente, onde o sentido bate) |

No servidor dedicado `isLocal()` = `authOwner ~= nil` (zumbi com dono cliente é "local" pro
servidor); o mod não pergunta isso no servidor. Decisão: todo código do mod testa dono com
`z:isLocal()` e cópia de outro cliente com `not z:isLocal()` (`NOM_SirenFreeze`, `NOM_VariantAI`,
`NOM_NightStats`, `NOM_Carpideira`, `client/NOM_FogClient.lua`, `client/NOM_Debug.lua`). Antes da
troca, no solo, além da sirene: a IA das variantes não rodava (Estalador não cegava, Corredor não
avisava que caçava, Carpideira calma não parava), o laço da noite não reaplicava a velocidade
re-rolada e a Carpideira não soltava depois do grito. O lint `tests/test_kahlua_compat.lua` (`api_no_is_remote_zombie`) falha se
`isRemoteZombie` voltar em `mod/` ou `mod2/`, e os fakes de zumbi não têm o método.

## 25. Lascas do Outro Mundo (sprint 0035)

Lascas de tinta e cinza que sobem do chão e das paredes vestidos (`client/NOM_Flakes.lua`,
regra em `shared/NOM_FlakeRules.lua`), desenhadas pelo overlay de tela da 0013 (§15.1), como as
brasas do Eco. Bytecode do B42.21 instalado (`javap -c -p`).

| Fato | Status | Evidência |
|---|---|---|
| `isoToScreenX/Y(i, x, y, z)`: ponto do mundo → pixel da tela do jogador `i` | CONFIRMED | `client/ISUI/ISButtonPrompt.lua:176-177` |
| É afim em x, y, z dentro do quadro: `(XToScreen(x + fjx, y + fjy, z, 0) − PlayerCamera.getOffX()) / zoom + IsoCamera.getScreenLeft(i)`, idem Y com `getOffY`/`getScreenTop`; `XToScreen = 32T(x − y)` (não lê z), `YToScreen = 16T(x + y) + 96T(0 − z)`. Projetar 4 pontos por quadro dá a base; cada lasca sai em Lua | EXISTS | `LuaManager$GlobalObject.isoToScreenX/Y(IFFF)` 0–60; `IsoUtils.XToScreen(FFFI)` 0–33, `YToScreen(FFFI)` 0–50. `fjx/fjy` = `PlayerCamera.fixJigglyModelsSquareX/Y` (campo, fixo no quadro) |
| Devolve `float`: com x, y ~10⁴ tiles (~6·10⁵ px antes de tirar o offset) o erro é ~0,06 px. A base usa pontos a 16 tiles e divide | EXISTS | o mesmo bytecode (`freturn`, contas em `F`) |
| `drawSubTexture(tex, subX, subY, subW, subH, x, y, w, h, a, r, g, b)` recorta a textura em **pixels dela** | CONFIRMED | `client/ISUI/ISUIElement.lua:1043-1052`; `client/ISUI/ISUISprite.lua:106-118`; `client/ISUI/ISLcdBar.lua:69-72` (recorte `índice × charW`, em pixels) |
| `UIElement.DrawSubTextureRGBA`: o recorte é preso a `[0, getWidth/Height]`, dividido pelo tamanho e levado a `xStart..xEnd` / `yStart..yEnd` (a folga de potência de 2 da textura não atrapalha); sai cedo invisível, com `w`/`h` ≤ 0 ou `y` fora de `[−h, 4096]` | EXISTS | `UIElement.DrawSubTextureRGBA(Texture, 12×D)` 0–122 (saídas), 123–306 (recorte → UV) |
| **Pegadinha:** sem `r`, o `drawSubTexture` vanilla chama `DrawSubTextureRGBA(tex, x, y, w, h, 1, 1, 1, a)`, sem o recorte: desenha o sheet inteiro na caixa. O mod passa a cor sempre | CONFIRMED | `client/ISUI/ISUIElement.lua:1046-1047` |
| Não existe `math.random` no Kahlua: o `MathLib` registra `abs` … `tanh`, sem `random`; o `RandomLib` dá `newrandom()`, sem uso vanilla. O mod usa um Park–Miller próprio (`NOM_FlakeRules.rng`, semente `getTimestampMs()`) | EXISTS | `se.krka.kahlua.j2se.MathLib.<clinit>` (nomes), `se.krka.kahlua.stdlib.RandomLib`; `rg 'math.random\|newrandom' media/lua` vazio |
| `drawTextureScaled` com cor, `getCore():getZoom(0)`, retângulo da tela, menu aberto | CONFIRMED | §15.1 e §16.6 |

Custo medido no mundo falso (`tests/test_flakes.lua`, `flakes_budget`): até 160 lascas vivas, pior
quadro ~175 idas ao Java (até 20 de base + 1 por lasca na tela). Sem névoa e sem lasca, 0.

## 26. Sprite próprio em runtime: texturas do Outro Mundo (sprint 0035)

Os PNG de `scripts/gen_tiles.py` (`media/textures/NOM/OutroMundo/`, lista em
`shared/NOM_OwnSpriteList.lua`) viram sprites de runtime em `client/NOM_OwnSprites.lua` e o
`client/NOM_FogOverlays.lua` anexa pelo nome, como os vanilla (ADR-017). Tabelas copiadas do
spike (`docs/sprints/sprint-0035-silent-hill/spike-sprite-proprio.md` §1b, §2, §5, §6), bytecode
do B42.21 instalado (`javap -c -p`).

### 26.1 Registro (spike §1b)

| Fato | Status | Evidência |
|---|---|---|
| `IsoSprite`, `IsoSpriteInstance`, `IsoSpriteManager` e `PropertyContainer` são expostos ao Lua (métodos públicos chamáveis) | CONFIRMED | `LuaManager$Exposer.exposeAll` 989, 3012–3033; uso vanilla: `IsoSpriteManager.instance:getSprite(nome)` em `shared/Util/CustomTileProps.lua:320` |
| `getSprite(nome)` (global do Lua) = `IsoSpriteManager.instance.getSprite(nome)`: se o nome está no `namedMap`, devolve; senão **`AddSprite(nome)`** | CONFIRMED | `LuaManager$GlobalObject.getSprite(String)` 0–7; `IsoSpriteManager.getSprite(String)` 0–28; uso vanilla do global: `server/ClientCommands.lua:195` |
| `AddSprite(String)`: `new IsoSprite`, `LoadSingleTexture(nome)` e `namedMap.put(nome, sprite)`. **Não** põe no `intMap` e **não** chama `setName` | CONFIRMED | `IsoSpriteManager.AddSprite(String)` 0–26 |
| `LoadSingleTexture(nome)` = `texture = Texture.getSharedTexture(nome)`, a mesma função do `getTexture(caminho)` do Lua (nil se o caminho não existe), que o mod já usa com `media/textures/NOM/...` (`NOM_Embers.lua:17`, `NOM_Flakes.lua:77`) | CONFIRMED | `IsoSprite.LoadSingleTexture` 0–16; `LuaManager$GlobalObject.getTexture(String)` 1 |
| Sem animação, o desenho usa o campo `texture` | CONFIRMED | `IsoSprite.getTextureForFrame(I,IsoDirections,Z)` 22–46 |
| ID do sprite novo: **20000000** (valor do construtor, igual pra todo sprite criado assim) | CONFIRMED | `IsoSprite.<init>(IsoSpriteManager)` 50–53 |
| `addAttachedAnimSpriteByName(nome)` lê o `namedMap` (`IsoSprite.getSprite(manager, nome, 0)`): **acha o sprite de runtime** | CONFIRMED | `IsoSprite.getSprite(IsoSpriteManager,String,I)` 0–23; `IsoObject.addAttachedAnimSpriteByName` (§16.6) |
| `setName(String)` é público e só grava o campo `name` (o que `getParentSprite():getName()` lê) | CONFIRMED | `IsoSprite.setName` 0–5; `javap -p IsoSprite` (`getName()`, `setName(String)`, `getProperties()`) |
| Flags no sprite pelo Lua: `sprite:getProperties():set(IsoFlagType.X)`; `IsoFlagType` tem `FloorOverlay`, `WallOverlay`, `attachedN` e `attachedW` | CONFIRMED | `shared/Util/CustomTileProps.lua:333-338`; `PropertyContainer.set(IsoFlagType)` público; `javap -p IsoFlagType`; uso vanilla de `IsoFlagType.attachedW/N` em `ISDestroyStuffAction.lua:166,171` e de `WallOverlay` em `ISMoveableSpriteProps.lua:157` |
| O `namedMap` é esvaziado a cada carga de mundo (`IsoSpriteManager.Dispose` antes dos tiledefs): o sprite de runtime tem de ser recriado por jogo | CONFIRMED | `IsoWorld.init` 2182–2185 |
| Mexer em sprite no `OnGameStart` é o que o vanilla faz | CONFIRMED | `shared/Util/CustomTileProps.lua:318-341` |

**Como o mod usa** (`NOM_OwnSprites.ensure`): pra cada nome da lista, `getTexture(nome)` (nil:
pula e loga uma vez, nunca cria sprite vazio), `getSprite(nome)`, `setName(nome)` (**obrigatório**)
e as flags do lado (`F`: `FloorOverlay`; `W`/`N`: `WallOverlay` + `attachedW`/`attachedN`).
Roda no `OnGameStart` e, preguiçoso, no primeiro `update` com névoa da sessão; depois disso volta
sem ir ao Java. Custo: ~280 chamadas uma vez por sessão (50 sprites), medido no mundo falso.

### 26.2 Profundidade (spike §2)

O anexo é desenhado com a profundidade **do sprite anexado**, não do objeto:
`IsoObject.renderAttachedSprites` 438 → `IsoSprite.render(inst, obj, …)` → `renderCurrentAnim` 96 →
`renderCurrentAnim_FBORender` 375 → **`IsoSprite.setupTileDepth(obj, …)`** com `this` = sprite anexado.
Sem `depthTexture` próprio: `solidfloor`/`FloorOverlay` → `setupFloorDepth`; `WallOverlay` +
`attachedN`/`attachedW` → depth da parede pai ou `setupWallDepth` do lado; sem flag →
`getDefaultDepthTexture()` (genérica, errada pra decalque) (`IsoSprite.setupTileDepth` 0–781).

| Pergunta | Resposta | Status |
|---|---|---|
| Anexo sem depth e sem flag renderiza certo? | **Não**: cai na profundidade genérica. | CONFIRMED (bytecode); efeito visual UNKNOWN |
| Chão: como ter depth certo? | Flag `FloorOverlay` no sprite. É o que os decalques vanilla de chão têm (`d_streetcracks_1_*`, §16.5) | CONFIRMED |
| Parede: como ter depth certo? | Flags `WallOverlay` + `attachedW` (ou `attachedN`): depth da parede pai ou `setupWallDepth`. É o que pichação vanilla tem (`newtiledefinitions.tiles.txt:162363`) | CONFIRMED |
| Precisa de PNG de depth nosso? | Não. Reaproveita a do pai ou a do `setupWallDepth`/`setupFloorDepth`. | CONFIRMED |
| Runtime | `sprite:getProperties():set(IsoFlagType.FloorOverlay)` ou `set(IsoFlagType.WallOverlay)` + `set(IsoFlagType.attachedW/N)` | CONFIRMED (API); UNKNOWN (visual no jogo) |

A regra (`NOM_DressingRules.wall`) só põe sprite `W` em parede oeste e `N` em parede norte
(`tests/test_dressing_rules.lua`, `dressing_rules_own_wall_side`; o fake acusa anexo de parede
sem a flag do lado).

### 26.3 Save: o nome que vaza (spike §5)

`IsoObject.save` grava, por anexo, o **ID** do sprite (`IsoSpriteInstance.getID`), um byte de flags,
`offX/offY/offZ`, `tintr/g/b` e às vezes o alfa (`IsoObject.save(ByteBuffer,Z)` 168–400: `getID` 184,
tinta 229–249). Não grava o nome. No load (`IsoObject.load(ByteBuffer,I,Z)` 184–601), por anexo: lê
o ID e chama `IsoSprite.getSprite(manager, id)`, que só olha o `intMap` e dá **`null` se o ID não
está lá** (`IsoSprite.getSprite(IsoSpriteManager,I)` 0–81); com `null`, em debug loga
`"discarding attached sprite because it has no tile properties"`, consome os bytes do registro e
**não** adiciona nada (221–251, 508–510).

| Caminho | Vazou e carregou **com** o mod | Vazou e carregou **sem** o mod |
|---|---|---|
| Tile pack (ID 1048576+…) | O anexo **volta** (ID no `intMap`): precisa da limpeza por prefixo no `LoadGridsquare` | Descartado no load. Mas se **outro** mod usar o mesmo número de tiledef, o ID vira o sprite dele |
| Runtime (ID 20000000, o do mod) | **Descartado no load** (20000000 nunca entra no `intMap`): o vazamento se limpa sozinho | Descartado no load |

CONFIRMED (bytecode). O "sem o mod" foi lido no código, não testado no jogo. Mesmo assim o
`NOM_DressingRules.own` reconhece `media/textures/NOM/OutroMundo/` e o `LoadGridsquare` tira o que
sobrar fora do registro (defesa, igual ao `floors_burnt_01_*`).

### 26.4 Tinta por instância não existe (spike §6)

| Fato | Status | Evidência |
|---|---|---|
| `IsoSpriteInstance` tem `tintr/tintg/tintb` (campos públicos), gravados no save por anexo | CONFIRMED | `IsoObject.save` 229–249; `IsoObject.load` 382–426 |
| Pelo Lua: só `getTintR/G/B`, `SetAlpha`, `SetTargetAlpha`, `setScale`. **Não há setter de tinta** | CONFIRMED | `javap -p IsoSpriteInstance` |
| O Kahlua não escreve campo Java: o exposer só **lê** campo estático anotado (`Field.get` em `LuaJavaClassExposer.exposeStatics` 143–222); `getClassFieldVal` é só leitura. Nenhum Lua vanilla escreve `tintr` | CONFIRMED | `se.krka.kahlua.integration.expose.LuaJavaClassExposer`; `rg tintr media/lua` vazio |
| `IsoSprite.setTintMod(ColorInfo)` existe, mas é do **sprite** (compartilhado): tingiria toda instância daquele sprite no mapa | CONFIRMED | `IsoSprite.setTintMod`; proibido pela ADR-017 |

Por isso o visual novo vem de PNG nosso, não de sprite vanilla tingido.

## 27. Visão curta e perambular na névoa (sprint 0036)

Visão de ~4 tiles (`shared/NOM_VariantAI.lua`) e perambular (`shared/NOM_WanderRules.lua`,
`shared/NOM_Wander.lua`, `server/NOM_WanderServer.lua`). Bytecode do B42 instalado (`javap -c -p`).

| Fato | Status | Evidência |
|---|---|---|
| O raio de visão do zumbi fica preso em 10–20 tiles: a visão menor não sai do sandbox nem do degrau | EXISTS | `IsoZombie.updateVisionRadius` (§3.2); por isso a cegueira do Estalador em rodízio |
| `setUseless(true)` + `setTarget(nil)` desfaz a mira e mata o spot forçado; o zumbi fica surdo enquanto useless | CONFIRMED | §3.2 (`spottedNew` 191–208, `RespondToSound` 8–15) |
| O useless não para quem já anda: o mesmo `halt` da sirene (`getPathFindBehavior2():cancel()`, `setPath2(nil)`, `setVariable("bPathfind"/"bMoving", false)`) | EXISTS | §21 |
| `Events.OnWorldSound(x, y, z, raio, volume, fonte)` sai de todo `addSound`, no `WorldSound.init`, antes de os zumbis ouvirem | EXISTS | `WorldSoundManager$WorldSound.init(Object, IIIII, FF, S)` 129 (`"OnWorldSound"`); já usado no servidor (§13) |
| O som vive 16 atualizações; o zumbi ouve no próprio update | EXISTS | `WorldSound.init` 6–8 (`life = 16`); `IsoZombie.updateInternal` 1765–1788 chama `RespondToSound` quando `timeSinceSeenFlesh > 240` e `timeSinceRespondToSound > 5` |
| Quem viu carne há menos de 240 (unidades de 30 FPS, ~8 s) não responde a som | EXISTS | o mesmo trecho do `updateInternal`. Consequência: o cego que acabou de ver o jogador ignora uma garrafa jogada longe, como no vanilla |
| `z:pathToLocationF(x, y, z)` manda o zumbi andar até o ponto | EXISTS | `IsoZombie.pathToLocationF(FFF)` 0–47 (recusa só com `allowRepathDelay > 0` em quem já está em `PathFindState`/`WalkTowardState`/`WalkTowardNetworkState`); `IsoGameCharacter.pathToLocationF` 0–17 (`PathFindBehavior2.pathToLocationF` + `pathToAux`); `pathToAux` 0–274 (linha livre no mesmo andar a ≤ 30 tiles Manhattan: `bPathfind` falso e `setMoving(true)`; senão `bPathfind` verdadeiro) |
| Uso vanilla do mesmo caminho em zumbi | CONFIRMED | `client/DebugUIs/DebugContextMenu.lua:640` (`selectedZombie:pathToLocation(x, y, z)`; `IsoGameCharacter.pathToLocation(III)` 0–28 é a versão de tile inteiro, que soma 0,5) |
| `z:isMoving()` como "parado" | EXISTS | §21 (`IsoGameCharacter.isMoving()Z`); o `pathToAux` liga o `setMoving` |
| Destino: `getCell():getGridSquare(x, y, z)` + `NOM_SemRosto.floorOk` (carregado, `isFree(false)`, sem água) | CONFIRMED | §3.4 |
| No MP só o dono anda o zumbi: a posição vai no pacote dele | EXISTS | §3.4 (`NetworkZombiePacker.applyZombie`) |
| `ZombRand(n)`, `EveryOneMinute`, `sendServerCommand` sem jogador (todos) | CONFIRMED | `server/ClientCommands.lua:120`; §7 |
| O 6º argumento do `OnWorldSound` é a fonte do `addSound`: o próprio jogador no passo e no tiro dele | EXISTS | `WorldSoundManager.addSound(Object, …)` passa a fonte ao `WorldSound.init` (§13); `IsoPlayer.DoFootstepSound(F)` 257–292 chama `addSound(this, x, y, z, raio, raio, …)`; uso no mod: `server/NOM_Variants.lua:123` (`instanceof(source, "IsoPlayer")`) |
| O passo do jogador é som de mundo: raio `ceil(volume × 1,4 × 10)` (×0,6 Graceful, ×1,2 Clumsy, ×0,5 descalço, × Lightfoot, × (2 − Nimble), × furtividade agachado; metade dentro de casa), com chance 1/2 andando | EXISTS | `IsoPlayer.DoFootstepSound(F)` 0–296; volume por passo em `DoFootstepSound(String)` 0–248: `sneak_walk` 0,2, `walk` e `sneak_run` 0,5, `strafe` 0,3 (0,2 agachado), `run` 1,3, `sprint` 1,8. Andando de sapato na rua: raio ~7. Por isso a visão curta só deixa o som denunciar com raio ≥ 10 (`NOISE_MIN_RADIUS`) |
| `z:isFakeDead()` e `z:isSitOnGround()` (o perambular deixa quem finge de morto e quem está sentado) | EXISTS | `IsoZombie.isFakeDead()Z` (`javap`; uso vanilla no zumbi `client/DebugUIs/DebugContextMenu.lua:560`); `IsoGameCharacter.isSitOnGround()Z` 0–4 (campo `sitOnGround`; uso vanilla no jogador `client/ISUI/ISWorldObjectContextMenu.lua:1490`) |
| Jogadores de outros clientes no destino do perambular: `getOnlinePlayers()` no cliente de MP (vazio no solo) | CONFIRMED | §23 (`client/Chat/ISChat.lua:560`; `LuaManager$GlobalObject.getOnlinePlayers` 0–30) |
| Sem-rosto fora do perambular: `NOM_SemRosto.isSemRosto(z, período, cfg, vermelha)` (sorteio pelo `getPersistentOutfitID`; o `NOM_NightStats` não o põe em `variants`) | CONFIRMED | §3 (ID persistente, ADR-006); `shared/NOM_SemRosto.lua` |
| Janela depois da névoa no MP (`AFTER_FOG_MS`) em tempo real: `getTimestampMs()` | CONFIRMED | `server/ISObjectClickHandler.lua:352`; o mesmo do `SWEEP_MS` da sirene (§21) |

Custo medido no mundo falso (Tarefa 0 e testes da sprint): a cegueira em todo zumbi, todo frame,
custaria 600 chamadas por frame com 300 zumbis parados e 2700 com a multidão. Em rodízio de 30 por tick
(`vision_budget_300_zombies`): 61 parados; multidão com média de 129 e pior tick de 452. O som com
~216 cegos (`vision_budget_sound_per_tick_200_blind`, um som por tick): 4 chamadas por som (eram 437:
duas por cego; o cego guarda onde parou). A onda de perambular (`wander_wave_cost_300`), fatiada em
ticks de ~600 chamadas: 566 num tick com todos perto, 1203 em 2 ticks (pior tick 602) com todos longe,
1046 em 2 ticks (pior 604) misturado; uma vez a cada 4–8 minutos de jogo.

## 28. Sonar do Estalador (sprint 0037)

Regra pura em `shared/NOM_SonarRules.lua`; o servidor decide (`server/NOM_SonarServer.lua`), quem
simula aplica (`shared/NOM_Sonar.lua`, `NOM_VariantAI.sonarFound`), quem renderiza desenha
(`client/NOM_SonarFx.lua` e `NOMRender_sonar` no mod3). Bytecode do B42 instalado (`javap -c -p`).

| Fato | Status | Evidência |
|---|---|---|
| "Agachado" lido no servidor: `p:isSneaking()` | CONFIRMED | `IsoGameCharacter.isSneaking()Z` 0–4 (campo `sneaking`); uso vanilla `shared/TimedActions/ISFitnessAction.lua:17`. Chega ao servidor no pacote do jogador: `NetworkPlayerVariables.getBooleanVariables(IsoPlayer)` 5–12 põe `Flags.isSneaking` de `IsoPlayer.isSneaking`; `setBooleanVariables(IsoPlayer, ShortFlags)` 2–8 chama `setSneaking`; `NetworkPlayerAI.parse(PlayerPacket)` 221–224 chama o `setBooleanVariables` |
| "Andando" lido no servidor pela posição, não por `isPlayerMoving` | decisão | `IsoPlayer.isPlayerMoving()Z` só lê o campo `isPlayerMoving`, e não achei quem o escreva a partir do pacote no servidor; a posição chega (`Prediction.position`, §3.4). O servidor guarda a posição a cada `SAMPLE_MS` (250 ms) e conta como andando quem moveu ≥ `MOVE_EPS` (0,1 tile) desde a amostra anterior |
| Caçar mesmo com a cegueira: soltar (`release`) e `z:spotted(p, true)` | CONFIRMED | §13.2 (`spotted` forçado só vale com o zumbi não useless; por isso o `release` antes) |
| O estalo num ponto, sem pacote: `getWorld():getFreeEmitter(x, y, z):playSoundImpl(nome, false, nil)` | CONFIRMED | §22; cada cliente toca o seu quando chega o comando `sonar` |
| `sendServerCommand(MODULE, "sonar" / "sonarFound", args)` a todos; `getPlayerByOnlineID(id)` no cliente | CONFIRMED | §7; `client/ServerCommands.lua:10` |
| Tempo real do anel no servidor: `getTimestampMs()` no `OnTick`, parado com `isGamePaused()` | CONFIRMED | `server/ISObjectClickHandler.lua:352`; §11.2 |
| Anel na tela: `isoToScreenX/Y(0, x, y, z)` e `el:drawTextureScaled(tex, x, y, w, h, a, r, g, b)` | CONFIRMED | §25; `client/ISUI/ISUIElement.lua:1032-1041` (com cor → `DrawTextureScaledColor`); `getTexture` nil sem arquivo (`ISSleepingUI.lua:14-15`) |
| Círculo de raio r no chão isométrico vira elipse 2:1 na tela; a ponta da direita é (x + r/√2, y − r/√2) | CONFIRMED | `IsoUtils.XToScreen = 32T(x − y)`, `YToScreen = 16T(x + y) − 96Tz` (§25): o máximo de x − y no círculo é r√2 e o de x + y também, com metade do peso em y |
| `NOMRender_sonar(x, y, z)` (mod3): `@LuaMethod(global = true)` como os outros, devolve boolean, `catch (Throwable)` devolve false | CONFIRMED | o mesmo caminho do `NOMRender_setParam` (registro no `Main.java`); contrato em `tests/test_mod3_sonar.lua` |
| O mod3 recusa o anel sem névoa visível: `ClimateManager.getInstance().getFogIntensity() < 0.05` | CONFIRMED | já lido no `RenderContext.onWorldEnd` (`f.fogIntensity`); uso vanilla `shared/Fishing/Bobber.lua:94` |
| Na névoa fluida o anel move densidade (como o `blast`), não velocidade | decisão | a projeção de pressão do `FlowGrid.step` apaga velocidade radial pra fora (divergência); cada célula da faixa varrida leva `Sonar.TAKE` (50 %) da névoa dela pra frente na própria direção radial, até meio tile depois da frente, sem criar massa (`FlowSonarTest`) |
| A frente da névoa fluida para em parede: face fechada (`openU`/`openV`, a máscara de parede, porta e janela que o `Flow` monta), sólido e interior | decisão (review final) | `FlowGrid.sonarPass`/`sonarTarget`; `FlowSonarTest.noneBehindWall` (o lado de trás de uma parede comprida começa vazio e continua vazio) |
| Casa protege: interior pelo square, `o:getCurrentSquare()`, `sq:isOutside()`, `sq:getBuilding()` | CONFIRMED (bytecode + vanilla) | `IsoGridSquare.isOutside()Z` 0–10 lê a flag `IsoFlagType.exterior` das propriedades do square; `IsoGridSquare.getBuilding()` 0–15 = `getRoom()` e `IsoRoom.getBuilding()`, ou `null` sem sala; `getCurrentSquare()` em `IsoMovingObject` (`javap -p`). Vanilla: `shared/RadioCom/ISRadioInteractions.lua:185` (`source:isOutside() ~= plrsquare:isOutside()`: o rádio não chega de dentro pra fora), `client/ISUI/ISWorldObjectContextMenu.lua:1679` (`getBuilding() ~=` entre square e jogador); no servidor, `getCurrentSquare():isOutside()` já roda no `server/NOM_Night.lua:89`. Regra: um dentro e o outro fora, ou prédios diferentes, o anel não acha (`NOM_SonarRules.sheltered`); sem square, não protege |
| O anel vai só a quem está perto: `sendServerCommand(jogador, MODULE, "sonar", args)` | CONFIRMED | §7 (`server/ClientCommands.lua:477`); já usado no `server/NOM_Fog.lua:43`. O `sonarFound` continua indo a todos (o dono do Estalador pode ser qualquer cliente) e leva o `persistentOutfitID` (`pid`), que o dono confere (o `onlineID` se reaproveita) |
| Ritmo do estalo e janela do achado em tempo real que para na pausa | CONFIRMED | `getTimestampMs()` + `isGamePaused()` (§11.2). Servidor: `S.clock` soma o tempo do `OnTick` (no máximo 250 ms por tick) e joga fora o acumulado com o jogo pausado (conferido a cada amostra, 250 ms). Dono: `NOM_VariantAI.found[z].left` desconta pelo `NOM_FogEventRules.countdown` (parado na pausa, no máximo 1 s por tick), como as sirenes atrasadas |
| Abaixo de 10 FPS a frente do mod3 anda mais devagar que o anel do servidor | limitação | `Flow` roda no máximo 2 passos de 0,05 s por quadro (`while (acc >= STEP && steps < 2)`) e joga fora o resto: abaixo de 10 FPS a simulação (e a onda na névoa) fica atrás do tempo real. Quem acha é o servidor, então só o desenho atrasa |

Custo medido (mundo falso e teste Java):

- servidor, `sonar_budget`: com névoa e sem anel, 2,37 chamadas por tick (a amostra de posição a cada
  250 ms); 8 anéis e 4 jogadores, pior tick 79 (+3 por cruzamento pela casa, +1 por achado pelo
  `persistentOutfitID`); a passada na lista (a cada 1 s) com 303 zumbis, 624 num tick, média de
  11,3 por tick (sorteio pelo ID persistente, sem tocar no zumbi que não é Estalador além disso).
  Sem névoa e sem anel: 0;
- tela, `sonar_fx_budget`: 0 por quadro sem anel; 6 de base + 4 por anel (3 projeções e 1 desenho):
  10 com 1 anel, 38 com 8;
- mod3, `FlowSonarTest.cost`: 8 anéis no fim (maior faixa) num passo da grade de 128 tiles na escala 2:
  ~0,15 ms na thread da simulação, ~3 % do passo inteiro da grade nessa escala (~5,6 ms,
  `FlowScaleTest`).

## 29. Tiro abre a névoa (mod3, sprint 0037c)

O §19 já tinha a lista de sons (`WorldSoundManager.instance.soundList`). Aqui fica o que o teste no
jogo mostrou e por que o tiro não aparecia.

| Fato | Status | Evidência |
|---|---|---|
| Um tiro de pistola gera dois sons no tile do jogador, raio 40 e raio 20, z do jogador | CONFIRMED (no jogo) | `Events.OnWorldSound` de teste no console.txt do Johan, 2026-10-06 (não 100 como o `SoundRadius` do script sugere) |
| O som vive 16 atualizações; a coleta do `Flow` (~20 Hz) o vê | EXISTS | `WorldSound.init` 6–8 (`life = 16`, §27); `Flow.collectSounds` roda a cada `STEP` (0,05 s) |
| O sopro no fluido não aparecia: perto do jogador o fluido já está ~0 (o personagem cava o rastro, `outdoorRefill = 0`) e o véu de fundo (`HAZE`) é somado sem depender do fluido | decisão | log do mod3 "densidade ... sob o jogador=0.02"; `NOM_VolFog.frag` `densityLook` soma `HAZE * uParams[1].w` fora do `fd` |
| Clareira: até 8 (`uClears`), abre em 0,15 s, fecha em 4 s (tempo da simulação, para na pausa), miolo limpo até meio raio e borda até o raio; multiplica a densidade inteira (véu, rolos, fluido) | decisão | `Blasts.java`, `nomClearing` no `NOM_RenderContext.glsl`; `FlowBlastTest` |
| Raio do sopro e da clareira: som × 0,25, entre 5 e 12 tiles (pistola 10, som 20 → 5); os dois sons do mesmo tiro viram uma clareira só | decisão | `Blasts.radius`, `Blasts.add`; antes era som/10 entre 2,5 e 9 |

## 30. Névoa preta: escuridão, Tição e luz (sprint 0038)

| Fato | Status | Evidência |
|---|---|---|
| `ClimateManager.FLOAT_DESATURATION = 0`, `FLOAT_NIGHT_STRENGTH = 2`, `FLOAT_AMBIENT = 9`, `FLOAT_DAYLIGHT_STRENGTH = 11` | EXISTS | `javap -constants zombie.iso.weather.ClimateManager` |
| O slider "Darkness" do admin escreve luz do dia = 1 − v e noite = v na camada modded | CONFIRMED (Lua vanilla) | `client/ISUI/AdminPanel/ISAdmPanelClimate.lua:235-244, 362-364`; a preta usa os mesmos dois canais pela camada modded (`server/NOM_ClimateLook.lua`, `NOM_Rules.blacken`) |
| `IsoPlayer.getActiveLightItem()` devolve o item aceso na mão ou preso; o liga/desliga é sincronizado pelo vanilla, então o servidor vê | EXISTS | javap `IsoPlayer`; `client/ISUI/ISInventoryPaneContextMenu.lua:2880-2884` (`setActivated` + `syncItemActivated`); já usado no `server/NOM_Night.lua` |
| `InventoryItem.isTorchCone()Z`, `getLightDistance()I`, `getTorchDot()F`, `isActivated()Z`, `setActivated(Z)V`, `getContainer()` | EXISTS | javap `zombie.inventory.InventoryItem`; `getContainer() == getInventory()`: `shared/TimedActions/ISEquipHeavyItem.lua:56` |
| `setActivated` é local: o vanilla manda o `syncItemActivated` à parte | CONFIRMED (Lua vanilla) | `ISInventoryPaneContextMenu.lua:2882-2883`; o piscar da lanterna apaga só no dono, sem pacote |
| Lanternas vanilla: HandTorch 15 / cone / 0,5; Torch 25 / 0,66; PenLight 11 / 0,75; lampiões 15 (elétrico 10) sem cone; isqueiro 5 sem cone | EXISTS | `media/scripts/generated/items/drainable.txt` (HandTorch 979–992, Torch 1058–1071, PenLight 1084–1094, Lantern_* 1123–1376, Lighter 712–725) |
| `TorchDot` tratado como o cosseno do meio ângulo do cone | decisão | 0,5 = 60° pra cada lado, coerente com a lanterna larga do jogo; `NOM_LightRules.lit` |
| `IsoGameCharacter.getForwardDirectionX()F` / `getForwardDirectionY()F` | EXISTS | javap `zombie.characters.IsoGameCharacter` |
| `IsoGameCharacter.getVehicle()`, `BaseVehicle.getHeadlightsOn()Z` | EXISTS | javap; `server/Vehicles/Vehicles.lua:565` |
| Direção do carro sem `Vector3f` no Lua: o farol vira um raio de 8 tiles em volta do carro | decisão (conservadora) | `BaseVehicle.getForwardVector(Vector3f)` pede um `org.joml.Vector3f`; a 0039 decide se vale |
| Luz fixa (cômodo aceso, poste) não congela o Tição na 0038 | decisão | a varredura de squares acesos fica pra 0039, junto com a luz que empurra a névoa do mod3 |
| Congelar = `setUseless(true)` + `setTarget(nil)` + halt, no dono (`z:isLocal()`); a lista vai por `onlineID` | EXISTS | o mesmo da sirene (§3.2, §21, §24); `IsoZombie.getOnlineID()` (javap, já usado no Eco) |
| Com a direção do jogador remoto no servidor dedicado, o facho segue quem gira | UNKNOWN | testar no MP: girar com a lanterna e ver o Tição soltar e outro congelar |

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
| Som local num ponto do mundo | `getWorld():getFreeEmitter(x, y, z):playSoundImpl(nome, false, nil)`, parado pelo id; no carro, `vehicle:playSoundImpl` (§22) | — (`PlayWorldSound` manda pacote) |
| Achar aparelho perto | `getZomboidRadio():getDevices()` filtrado por distância² (§22) | varrer quadrados (caro, sem o carro) |
| Decal local de chão e de parede | `obj:addAttachedAnimSpriteByName` no piso/parede, registro do que o mod pôs, tirado no `OnSave`, fora do raio (pela tela, 15 a 30), na morte e no salto (§16.6) | — (`IsoMarker` e `RenderGhostTileColor` saíram: §16.5) |
| Pós-processo | `SearchMode` (vinheta/blur/desat/escuro) | override de `media/shaders/*.frag` |
| Névoa só do mod | camada modded da névoa + `setEnableOverride(false)` no `OnClimateTick` (§11) | — |
| Cor da névoa | camada modded do `getClimateColor(1)` (`COLOR_NEW_FOG`), vanilla escrito antes de desligar (§12) | — |
| Barulho do jogador no servidor | `Events.OnWorldSound` (todo `addSound`, inclusive o de cliente refeito no servidor) (§13) | — |
| Zumbi parado | `setUseless(true)` + `setTarget(nil)` no dono (§3.2, §13) | — |
| Visão menor que 10 tiles | cegueira em rodízio no dono (`useless` + `halt`), solta por som (`OnWorldSound`); som com raio ≥ 10 denuncia o jogador pra quem está no raio (§27) | piso de 10 tiles com o pior degrau |
| Zumbi andar até um ponto | `z:pathToLocationF(x, y, z)` no dono (§27) | `addSound` no ponto (puxa todos em volta) |
| Zumbi achar o jogador apesar da cegueira | servidor decide (`isSneaking` + posição), dono solta e `spotted(p, true)` com janela anti-recegueira (§28) | — |
| Tempo real no servidor | `getTimestampMs()` no `OnTick`, parado com `isGamePaused()` | — |
| Efeito de tela | `ISUIElement` de 1×1 px, `backMost`, sem consumir mouse, desenhando no retângulo do jogador 0 (§15) | — |
| Canal Lua → shader | floats do `SearchMode` com override e sem `enabled`, marcador no gradiente (§15.4) | `DesaturationVal` (ambíguo) |
| Visual da variante | pele `setSkinTextureName` + `ItemVisual` na lista + `resetModelNextFrame`, na cópia local de quem renderiza (§14) | — (outfit troca o ID) |

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
13. Visual das variantes (sprint 0012): textura do mod em `media/textures/Body/` e
    `media/textures/NOM/` é achada? `ItemVisual.new()` responde no Lua? O Kahlua escolhe
    `ItemVisuals.remove(Object)` com o `ItemVisual` (e não `remove(int)`)? (§14)
14. Efeitos de tela (sprint 0013): texturas do mod por `getTexture("media/textures/NOM/ScreenFx/...")`,
    o elemento de 1 px por baixo do HUD de verdade, `PZAPI.ModOptions` em Opções > Mods, e o
    `screen.frag` do mod2 compilando e vencendo o vanilla (§15)
15. Outro Mundo anexado (sprint 0023, §16.6): o mato anexado ao piso fica bem? Recorte de parede
    e telhado com anexo; o custo de ~400 invalidações de nível de chunk por lote; save + sair +
    voltar na névoa e depois dela sem nada sobrando (roteiro da sprint 0023)
16. Debug amigável (sprint 0020): Insert livre em `-debug` (as 46 classes dizem que sim)? `NOM.time` no dedicado chega nos
    clientes, com a data certa? `NOM.god` de quem tem `-debug` mas não é admin vale no MP? (§18)
17. Aparelhos do Outro Mundo (sprint 0034): a TV e o rádio das casas perto estão na
    `getZomboidRadio():getDevices()`? O som some com a distância e para a 20 tiles? O rádio de
    carro toca no carro? Volume e frequência agradam? (§22)
18. Sirenes posicionais (sprint 0034): as 5 vêm de lados diferentes, desencontradas, sem
    gritar no ouvido? A de 500 tiles ainda se ouve? A afinação por sirene soa natural? Os
    zumbis congelados olham pro jogador e acompanham quando ele anda? (§23)
19. Outro Mundo na tela toda (sprint 0034, §16.6): no zoom mais longe o desenho chega nas
    bordas da tela? O FPS aguenta ~2800 squares com anexo? De carro, a borda que entra enche a
    tempo? Dormir e sair do jogo com o zoom longe, voltar: nada sobrando
    (`[NOM] outro mundo: N alvos limpos pro save` no console com `-debug`)
20. Visão curta e perambular (sprint 0036, §27): o `halt` para o zumbi cego que já vinha andando
    atrás do jogador? O `OnWorldSound` dispara no cliente de MP dono do zumbi (no solo, sim)? O
    `pathToLocationF` anda o zumbi parado até o ponto, e no MP a cópia dos outros acompanha?
    No MP, `isRunning()`/`isSprinting()` do jogador de outro cliente (a cópia remota que o dono
    do zumbi vê) acompanham o que ele faz? Se vierem sempre falsos, quem corre perto do zumbi de
    outro cliente conta como quieto pra ele.
21. Sonar do Estalador (sprint 0037, §28): no dedicado, o `isSneaking()` do jogador visto no
    servidor acompanha o agachar do cliente (o bytecode diz que sim)? A posição chega fina o bastante
    pra 0,1 tile em 250 ms contar como andando, sem contar o jogador parado como andando? O anel na
    tela cai no chão certo com zoom e em andar de cima? A frente na névoa fluida do mod3 se vê, e
    lê como onda? O Estalador achado anda mesmo até o jogador agachado antes de a janela de 10 s
    acabar? No dedicado, o square do jogador remoto (`getCurrentSquare()`) acompanha ele entrar e
    sair de casa, e varanda ou garagem sem sala (`isOutside` falso, `getBuilding` nil) protege como
    o esperado?
