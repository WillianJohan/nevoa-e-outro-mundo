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
- Névoa (evento com sirene, sem toggle: `FogEventEveryDays` alto deixa rara): som ambiente (`FogAmbience`) · sangue e erosão no chão e nas paredes (`FogOverlays`; a quantidade é opção de cada jogador, Opções > Mods, sprint 0015) · vinheta (`FogVignette`), todos padrão ligado

## Números

| Opção | Sistema |
|---|---|
| `FogEventEveryDays` (3, faixa 0.5–30 dias de jogo): média entre névoas; cada intervalo sorteado entre 0,5× e 1,5×, contado do fim da anterior | [world-states.md](world-states.md) |
| `FogMinHours` (2), `FogMaxHours` (6), faixa 0.5–48 horas de jogo: duração sorteada entre as duas (invertidas, o jogo troca) | [world-states.md](world-states.md) |
| `RedFogChance` (10, faixa 0–100 %): das névoas, quantas vêm vermelhas; sorteado uma vez por névoa pelo número dela e pela semente do save (recarregar não muda; cada save tem a sua agenda) | [monsters.md](monsters.md#regra-geral), [atmosphere.md](atmosphere.md#clima) |
| ~~`FogThreshold`~~ saiu na sprint 0009: a névoa não é mais lida do clima ([ADR-009](../architecture/adr-009-nevoa-evento-do-mod.md)); save antigo com ela não dá erro (opção desconhecida é pulada) | — |
| `DarkIntensity` (1.0, faixa 0–2) | [atmosphere.md](atmosphere.md) |
| `NightSpeedMult` (1.5, faixa 1–3, em degraus: 1.5 sobe um, 2.5 sobe dois) | [night.md](night.md) |
| `NightSenseMult` (1.5, faixa 1–3, mesmos degraus; lanterna = 20 × valor tiles, a cada 5 minutos) | [night.md](night.md) |
| `HuntIntervalMinutes` (60, faixa 10–720 minutos de jogo), `HuntRadius` (30 tiles, faixa 5–100) | [night.md](night.md) |
| Sem multiplicador de dano: decisão do autor ([night.md](night.md#sem-força-e-sem-dano-à-noite)) | — |
| `EstaladorChance` (5 %), `CorredorChance` (2 %), `SemRostoChance` (5 %), `CarpideiraChance` (3 %), faixa 0–100 cada, **por névoa** (15% somados): um sorteio só, faixas seguidas nessa ordem: somadas acima de 100, quem vem depois fica espremido (com o resto, ou zero) | [monsters.md](monsters.md#regra-geral) |
| `CorredorScreamRadius` (40 tiles, faixa 5–100) | [monsters.md](monsters.md#corredor) |
| `CarpideiraTriggerRadius` (4 tiles, faixa 1–20): jogador a essa distância acorda, mesmo agachado (lanterna e barulho alto: 10 tiles, fixo); `CarpideiraScreamRadius` (60 tiles, faixa 5–100): alcance do grito | [monsters.md](monsters.md#carpideira) |
| `FogVignetteIntensity` (1.0, faixa 0–2; 0 desliga) | [atmosphere.md](atmosphere.md#vinheta-só-na-névoa) |
| `EcoMaxPerPlayer` (30, faixa 0–200), `EcoRadius` (40 tiles, faixa 5–60) | [monsters.md](monsters.md#eco) |

## Presets

Dois jeitos prontos de ajustar o sofrimento, além do padrão. Valores exatos de
todas as opções da página "Névoa e Outro Mundo":

| Opção | Padrão | Leve | Pesadelo |
|---|---|---|---|
| `DarkEnabled` | ligado | ligado | ligado |
| `DarkIntensity` | 1.0 | 0.6 | 1.5 |
| `FogEventEveryDays` | 3 | 5 | 1.5 |
| `FogMinHours` | 2 | 1 | 3 |
| `FogMaxHours` | 6 | 3 | 8 |
| `RedFogEnabled` | ligado | ligado | ligado |
| `RedFogChance` | 10 | 3 | 25 |
| `EcoEnabled` | ligado | ligado | ligado |
| `EcoMaxPerPlayer` | 30 | 10 | 60 |
| `EcoRadius` | 40 | 25 | 50 |
| `NightFaster` | ligado | **desligado** | ligado |
| `NightSharperSenses` | ligado | ligado | ligado |
| `NightHunt` | ligado | ligado | ligado |
| `NightSpeedMult` | 1.5 | 1.5 | 2.5 |
| `NightSenseMult` | 1.5 | 1.5 | 2.5 |
| `HuntIntervalMinutes` | 60 | 120 | 30 |
| `HuntRadius` | 30 | 20 | 50 |
| `EstaladorEnabled` | ligado | ligado | ligado |
| `CorredorEnabled` | ligado | ligado | ligado |
| `EstaladorChance` | 5 | 3 | 10 |
| `CorredorChance` | 2 | 1 | 5 |
| `CorredorScreamRadius` | 40 | 30 | 60 |
| `SemRostoEnabled` | ligado | ligado | ligado |
| `SemRostoChance` | 5 | 2 | 10 |
| `CarpideiraEnabled` | ligado | ligado | ligado |
| `CarpideiraChance` | 3 | 1 | 6 |
| `CarpideiraTriggerRadius` | 4 | 3 | 6 |
| `CarpideiraScreamRadius` | 60 | 40 | 80 |
| `FogAmbience` | ligado | ligado | ligado |
| `FogOverlays` | ligado | ligado | ligado |
| `FogVignette` | ligado | ligado | ligado |
| `FogVignetteIntensity` | 1.0 | 0.6 | 1.5 |

- **Leve:** a noite muda o jeito de jogar sem virar uma corrida — os zumbis não ganham
  velocidade, a caça vem a cada 2 horas de perto, e a névoa é rara (a cada ~5 dias), curta
  (1–3 h) e com poucos monstros (7% somados); névoa vermelha rara (3%).
- **Pesadelo:** a pior noite possível, de propósito — dois degraus de velocidade e
  sentidos (arrastado vira corredor), caça a cada meia hora de longe, névoa a cada
  ~1,5 dia, de 3 a 8 horas, com 31% de monstros (Carpideiras que acordam a 6 tiles e gritam pra 80), uma em cada quatro vermelha (todo
  zumbi monstro), e vala comum cheia de Ecos.

**Como usar:** o jogo não aceita preset vindo de mod. A lista de presets do menu tem
os 5 vanilla fixos (`client/OptionScreens/SandboxOptions.lua:891-895`) e os `.cfg` da
pasta do usuário (`getSandboxPresets()`, bytecode: só lê `LuaManager.getSandboxCacheDir()`).
Pra ter "Leve" ou "Pesadelo" no menu: ajustar os valores acima uma vez e salvar como
preset do usuário. Os dois mudam só a página do mod; o resto do sandbox fica com o
preset vanilla escolhido.

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
