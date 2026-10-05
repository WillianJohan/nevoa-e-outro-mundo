# Sandbox options

| Campo | Valor |
|-------|-------|
| Status | `accepted` |

Página própria no sandbox ("Névoa e Outro Mundo"). Default entre parênteses
quando já decidido. Cada sprint adiciona as opções dos sistemas que entrega.

## Toggles

- Clima dark
- Noite: mais rápidos (`NightFaster`) · sentidos aguçados (`NightSharperSenses`) · caça ativa (`NightHunt`), todos padrão ligado
- Monstros: Estalador (`EstaladorEnabled`) · Corredor (`CorredorEnabled`) · Sem-rosto (`SemRostoEnabled`) · Carpideira (`CarpideiraEnabled`) · Eco (`EcoEnabled`), todos padrão ligado
- Névoa vermelha (`RedFogEnabled`, padrão ligado): parte das névoas vem vermelha, com sirene própria, e todo zumbi nela é monstro ([monsters.md](monsters.md#regra-geral))
- Curva de tensão (`FogEscalation`, padrão ligado, sprint 0019): a névoa começa mais rara e a vermelha mais fraca, e as duas apertam com os dias do save ([abaixo](#curva-de-tensão-sprint-0019))
- Névoa (evento com sirene, sem toggle: `FogEventEveryDays` alto deixa rara): som ambiente (`FogAmbience`) · sangue e erosão no chão e nas paredes (`FogOverlays`; a quantidade é opção de cada jogador, Opções > Mods, sprint 0015; anexado ao mapa e tirado antes do save desde a 0023) · vinheta (`FogVignette`), todos padrão ligado

## Números

| Opção | Sistema |
|---|---|
| `FogEventEveryDays` (2, faixa 0.5–30 dias de jogo): média entre névoas (com `FogEscalation`, multiplicada pela curva: 1,5× no começo, 0,75× do dia 45); cada intervalo sorteado entre 0,5× e 1,5×, contado do fim da anterior | [world-states.md](world-states.md) |
| `FogMinHours` (3), `FogMaxHours` (6), faixa 0.5–48 horas de jogo: duração sorteada entre as duas (invertidas, o jogo troca) | [world-states.md](world-states.md) |
| `RedFogChance` (10, faixa 0–100 %): das névoas, quantas vêm vermelhas; sorteado uma vez por névoa pelo número dela e pela semente do save (recarregar não muda; cada save tem a sua agenda); com `FogEscalation`, sobe do dia 30 até 2× no dia 90 | [monsters.md](monsters.md#regra-geral), [atmosphere.md](atmosphere.md#clima) |
| `RedFogGraceDays` (7, faixa 0–60 dias de jogo): nenhuma vermelha antes disso, com ou sem a escalada; 0 desliga | [abaixo](#curva-de-tensão-sprint-0019) |
| ~~`FogThreshold`~~ saiu na sprint 0009: a névoa não é mais lida do clima ([ADR-009](../architecture/adr-009-nevoa-evento-do-mod.md)); save antigo com ela não dá erro (opção desconhecida é pulada) | — |
| `DarkIntensity` (1.0, faixa 0–2) | [atmosphere.md](atmosphere.md) |
| `NightSpeedMult` (1.5, faixa 1–3, em degraus: 1.5 sobe um, 2.5 sobe dois) | [night.md](night.md) |
| `NightSenseMult` (1.5, faixa 1–3, mesmos degraus; lanterna = 20 × valor tiles, a cada 5 minutos) | [night.md](night.md) |
| `HuntIntervalMinutes` (90, faixa 10–720 minutos de jogo), `HuntRadius` (25 tiles, faixa 5–100) | [night.md](night.md) |
| Sem multiplicador de dano: decisão do autor ([night.md](night.md#sem-força-e-sem-dano-à-noite)) | — |
| `EstaladorChance` (5 %), `CorredorChance` (3 %), `SemRostoChance` (3 %), `CarpideiraChance` (3 %), faixa 0–100 cada, **por névoa** (14% somados): um sorteio só, faixas seguidas nessa ordem: somadas acima de 100, quem vem depois fica espremido (com o resto, ou zero) | [monsters.md](monsters.md#regra-geral) |
| `CorredorScreamRadius` (40 tiles, faixa 5–100) | [monsters.md](monsters.md#corredor) |
| `CarpideiraTriggerRadius` (4 tiles, faixa 1–20): jogador a essa distância acorda, mesmo agachado (lanterna e barulho alto: 10 tiles, fixo); `CarpideiraScreamRadius` (50 tiles, faixa 5–100): alcance do grito | [monsters.md](monsters.md#carpideira) |
| `FogVignetteIntensity` (1.0, faixa 0–2; 0 desliga) | [atmosphere.md](atmosphere.md#vinheta-só-na-névoa) |
| `EcoMaxPerPlayer` (20, faixa 0–200), `EcoRadius` (30 tiles, faixa 5–60) | [monsters.md](monsters.md#eco) |

## Presets

Dois jeitos prontos de ajustar o sofrimento, além do padrão (revistos pelo PO na sprint
0019, aprovados pelo Johan em 05/10/2026). Valores exatos de todas as opções da página
"Névoa e Outro Mundo":

| Opção | Padrão | Leve | Pesadelo |
|---|---|---|---|
| `DarkEnabled` | ligado | ligado | ligado |
| `DarkIntensity` | 1.0 | 0.7 | 1.5 |
| `FogEventEveryDays` | 2 | 3 | 1.5 |
| `FogMinHours` | 3 | 2 | 4 |
| `FogMaxHours` | 6 | 4 | 8 |
| `FogEscalation` | ligado | **desligado** | ligado |
| `RedFogEnabled` | ligado | ligado | ligado |
| `RedFogChance` | 10 | 5 | 20 |
| `RedFogGraceDays` | 7 | 14 | 3 |
| `EcoEnabled` | ligado | ligado | ligado |
| `EcoMaxPerPlayer` | 20 | 10 | 40 |
| `EcoRadius` | 30 | 25 | 45 |
| `NightFaster` | ligado | **desligado** | ligado |
| `NightSharperSenses` | ligado | ligado | ligado |
| `NightHunt` | ligado | ligado | ligado |
| `NightSpeedMult` | 1.5 | 1.5 | 2.5 |
| `NightSenseMult` | 1.5 | 1.5 | 2.5 |
| `HuntIntervalMinutes` | 90 | 120 | 45 |
| `HuntRadius` | 25 | 20 | 40 |
| `EstaladorEnabled` | ligado | ligado | ligado |
| `CorredorEnabled` | ligado | ligado | ligado |
| `EstaladorChance` | 5 | 4 | 6 |
| `CorredorChance` | 3 | 1 | 5 |
| `CorredorScreamRadius` | 40 | 30 | 50 |
| `SemRostoEnabled` | ligado | ligado | ligado |
| `SemRostoChance` | 3 | 2 | 5 |
| `CarpideiraEnabled` | ligado | ligado | ligado |
| `CarpideiraChance` | 3 | 2 | 5 |
| `CarpideiraTriggerRadius` | 4 | 3 | 6 |
| `CarpideiraScreamRadius` | 50 | 35 | 70 |
| `FogAmbience` | ligado | ligado | ligado |
| `FogOverlays` | ligado | ligado | ligado |
| `FogVignette` | ligado | ligado | ligado |
| `FogVignetteIntensity` | 1.0 | 0.7 | 1.5 |

- **Padrão — "o mundo tem horário":** a primeira semana ensina (névoa a cada ~3 dias, sem
  vermelha até o dia 7); do dia 30 em diante a névoa vem a cada ~2 dias e a vermelha começa
  a engrossar. 14% de monstros por névoa.
- **Leve — "primeira visita":** a noite muda o jeito de jogar sem virar corrida — os zumbis
  não ganham velocidade, a caça vem a cada 2 horas de perto, a névoa vem a cada ~3 dias sem
  curva, de 2 a 4 horas, com 9% de monstros; vermelha rara (5%) e só depois de duas semanas.
- **Pesadelo — "a cidade é proibida":** dois degraus de velocidade e sentidos (arrastado vira
  corredor), caça a cada 45 minutos de longe, névoa a cada ~2 dias no começo e ~1 dia no fim
  da curva, de 4 a 8 horas, com 21% de monstros (Carpideiras que acordam a 6 tiles e gritam
  pra 70); vermelha já no dia 3, uma em cada cinco, chegando a duas em cinco no dia 90.

**Como usar:** o jogo não aceita preset vindo de mod. A lista de presets do menu tem
os 5 vanilla fixos (`client/OptionScreens/SandboxOptions.lua:891-895`) e os `.cfg` da
pasta do usuário (`getSandboxPresets()`, bytecode: só lê `LuaManager.getSandboxCacheDir()`).
Pra ter "Leve" ou "Pesadelo" no menu: ajustar os valores acima uma vez e salvar como
preset do usuário. Os dois mudam só a página do mod; o resto do sandbox fica com o
preset vanilla escolhido.

## Curva de tensão (sprint 0019)

`FogEscalation` (padrão ligado) e `RedFogGraceDays` (7, faixa 0–60 dias). `d` = dias de
jogo desde o nascimento do save (`data.fog.bornAt`, gravado uma vez como a semente). Save
anterior à sprint 0019 que já tinha agenda de névoa nasce **no ponto neutro** (30 dias antes
do primeiro carregamento): intervalo 1×, vermelha 1×, carência já vencida, ou seja, nada muda
pra quem já jogava; a curva só aperta dali pra frente. Save antigo também **guarda o próprio
sandbox** (`SandboxOptions.load` lê o `map_sand.bin`; só opção nova ganha o default): os
defaults novos (2 dias, 3–6 h etc.) valem pra save novo ou pra quem mudar à mão.

- **Intervalo:** média `FogEventEveryDays × clamp(1,5 − d/60, 0,75, 1,5)`. Com a base 2: 3
  dias no começo, 2 no dia 30, 1,5 do dia 45 em diante. Cada intervalo continua sorteado entre
  0,5× e 1,5× da média, no fim da névoa anterior (com o dia do fim), e salvo.
- **Vermelha:** 0 antes de `RedFogGraceDays`; depois `RedFogChance × clamp(1 + (d − 30)/60,
  1, 2)`: 10% do dia 7 ao 30, subindo até 20% no dia 90. Decidida na sirene e salva: recarregar
  não muda a cor.
- **A carência vale com ou sem a escalada** (é opção própria; 0 desliga). Escalada desligada e
  carência 0 = a agenda de antes da sprint 0019 com os números do sandbox.
- Chances dos monstros e a noite **não** seguem a curva (sorteio da
  [ADR-006](../architecture/adr-006-variantes-deterministicas.md) intocado).
- O debug (`NOM_Debug.redFog(true)`) passa por cima da carência.

## Revisão dos defaults (2026-10-04, sem jogar)

Revisão de coerência feita na sprint 0006, contra o sandbox vanilla mais comum do B42
(Apocalypse: `ZombieLore.Speed = 4` aleatório, `Sight`/`Hearing = 5` aleatório,
`media/lua/shared/Sandbox/Apocalypse.lua:195-207`). **Nenhum default mudou:** sem
jogar, trocar número é chute; o que precisa ser sentido está no
[roteiro in-game](../teste-in-game.md#balanceamento).

- **Velocidade à noite é o ponto mais quente.** Com velocidade aleatória, de dia ~20%
  são corredores, ~40% rápidos e ~40% arrastados (`doZombieSpeed(-1)` com sandbox 4).
  `NightSpeedMult` 1.5 sobe um degrau: à noite **~60% correm**. Numa noite com névoa o
  Corredor quase só se distingue pelo grito. Se a noite ficar injusta, o ajuste é
  `NightFaster` desligado como padrão, não um multiplicador menor: 1.0–1.49 não sobe
  degrau nenhum.
- **Sentidos:** sandbox aleatório usa "normal" de base; um degrau dá águia/apurada a
  todos à noite. Audição apurada triplica o alcance de som, mas a caça e a lanterna já
  compensam (alcance efetivo = o configurado). Coerente.
- **Alcances:** caça 30, lanterna 30 (20 × 1.5), grito do Corredor 40, Eco 40. O
  Corredor é quem chama de mais longe entre os que gritam sempre (é ele que começa a
  horda); a caça e a lanterna empatam de propósito. A Carpideira (60) chama de mais longe
  ainda, mas uma vez por névoa e só se alguém a acordar. Coerente.
- **Chances (revistas em 05/10/2026, depois do primeiro teste):** todo monstro, menos o
  Eco, só existe na névoa (decisão do Johan), num sorteio só por névoa: Estalador 5,
  Corredor 2, Sem-rosto 5, Carpideira 3 (sprint 0011, decisão do Johan), 15% somados.
  Numa cidade com 200 zumbis carregados são ~10 Estaladores, ~4 Corredores, ~10 Sem-rosto
  e ~6 Carpideiras na névoa. A noite sem névoa fica só com a agressividade e os Ecos.
- **Eco:** 30 por jogador num raio de 40 é o teto contra vala comum (sprint 0002); Eco
  é fraco (vida 0.3) e lento. Coerente; ver o custo da varredura no
  [orçamento](../architecture/README.md#orçamento-por-sistema).
- **`DarkIntensity` 1.0:** depende de como a tela fica; só jogando.
- **Névoa a cada 3 dias, 2–6 h (sprint 0009, decisão do Johan):** ~5% do tempo de jogo
  com névoa (4 h a cada ~3,2 dias). Se ficar raro demais pra ver os monstros, o ajuste
  é `FogEventEveryDays`.

## Revisão do PO (2026-10-05, sprint 0019, aprovada pelo Johan)

A revisão de 04/10 (acima) não mudou número nenhum; esta muda, ainda sem jogar, pela
análise do PO aprovada integralmente pelo Johan. Cada número tem limiar de ajuste no
[playtest](../teste-in-game.md#balanceamento) (item entre parênteses). Os itens acima de
04/10 que citam número velho (caça 30, Eco 30/40, 15% somados, Carpideira 60) valem como
histórico.

| Opção | Antes | Agora | Item do playtest |
|---|---|---|---|
| `FogEventEveryDays` | 3 | 2 (com a curva, o começo fica ~3 dias efetivos) | — |
| `FogMinHours` | 2 | 3 | 8 |
| `EcoMaxPerPlayer` / `EcoRadius` | 30 / 40 | 20 / 30 | 3 |
| `HuntIntervalMinutes` / `HuntRadius` | 60 / 30 | 90 / 25 | 1, 2 |
| `CorredorChance` | 2 | 3 | 6 |
| `SemRostoChance` | 5 | 3 | 4 |
| `CarpideiraScreamRadius` | 60 | 50 | 5 |
| `FogEscalation` (nova) | — | ligado | 7 |
| `RedFogGraceDays` (nova) | — | 7 | 7 |

Monstros somados: 14% (5/3/3/3). O resto ficou como estava.

