# Névoa e Outro Mundo — Design (MVP)

**Data:** 2026-10-04
**Jogo:** Project Zomboid Build 42 (testado contra 42.20.4)
**Distribuição:** Steam Workshop — funciona em solo e MP
**Nome:** provisório

## Visão

Mod de horror inspirado em The Last of Us + Silent Hill.
**A noite traz infectados de carne (TLOU). A névoa traz o Outro Mundo (Silent Hill).**
Quando os dois coincidem, valem juntos — é a pior noite possível, de propósito.

## Fora do MVP

Carrasco (Pyramid Head-like), modelos 3D próprios, criaturas não-humanas com
esqueleto/animação próprios, troca real de tiles, preset ReShade, evento com sirene,
Java mods.

## Estados do mundo

`NOM_World` (servidor) calcula um estado a partir do jogo:

| estado | condição |
|---|---|
| `night` | hora do jogo entre pôr e nascer do sol (`ClimateManager`/`GameTime`) |
| `fog` | intensidade de névoa do clima ≥ `FogThreshold` (sandbox) |

São flags independentes (`night`, `fog`), não um enum — os dois podem estar ativos.
Mudança de flag dispara um evento interno (`onNightStart/End`, `onFogStart/End`)
consumido por `NOM_Variants` e enviado aos clientes (`sendServerCommand`).

O gatilho do Outro Mundo é **só a névoa natural do clima**. A névoa do PZ é global,
então "tem névoa" vale pro mapa inteiro.

## Monstros

Três monstros são **zumbis existentes marcados** via `modData`. O Eco é a única
exceção: ele é **spawnado**.

Todo zumbi marcado guarda em `modData`:
- `NOM_variant` — `"estalador" | "corredor" | "semrosto" | "eco"`
- `NOM_orig` — stats originais relevantes, para restaurar ao desmarcar

Desmarcar sempre restaura `NOM_orig`. Zumbi nunca fica preso numa variante.

**Sorteio preguiçoso:** o sorteio não varre o mapa no início da noite/névoa. Cada
zumbi é sorteado uma vez por período (`NOM_rolledAt` = id do período) na primeira
vez que o loop de comportamento o processa. Assim zumbis de chunks carregados depois
também entram, e o custo se espalha.

### Estalador (noite, marcado)
- Sorteado à noite: `EstaladorChance`% dos zumbis carregados.
- Cego: ignora visão, reage só a som. Agachado e em silêncio, o jogador passa.
- Agarrão letal rápido.
- Estalo periódico audível (aviso ao jogador).
- Outfit/textura própria.
- Ao amanhecer: desmarcado.

### Corredor noturno (noite, marcado)
- De dia é zumbi comum. Sorteado à noite: `CorredorChance`%.
- À noite: sprinter.
- Ao ver o jogador: grita e atrai zumbis num raio (`CorredorScreamRadius`).
- Ao amanhecer: desmarcado.

### Sem-rosto (névoa, marcado)
- Sorteado durante a névoa: `SemRostoChance`% dos zumbis carregados.
- Quando entra no campo de visão do jogador ou é iluminado: some e reaparece mais
  perto, fora da visão.
- Rádio chia "na cabeça" do jogador, mais forte quanto mais perto (não exige rádio).
- Ao fim da névoa: volta a ser zumbi comum.

### Eco (noite, spawnado)
- Durante a noite, todo `IsoDeadBody` que estiver a até `EcoRadius` tiles de um
  jogador gera um Eco, respeitando `EcoMaxPerPlayer` (checagem periódica, não só
  no início da noite — cobre o jogador que anda até um cemitério às 2h).
- **Cada corpo gera Eco uma única vez na vida** (`modData.NOM_ecoReleased = true`
  no corpo). O cadáver continua no chão.
- Corpo queimado ou enterrado não existe mais como `IsoDeadBody` → não gera Eco.
  Nenhuma regra extra necessária.
- Fraco: vida baixa, lento, dano baixo. Textura fantasmagórica própria.
- Ao morrer: **sem cadáver e sem loot.**
- Ao amanhecer: **todos os Ecos somem**, independente de onde estejam.

Ponto técnico em aberto: "morrer sem cadáver" não é nativo. Abordagens a testar,
nessa ordem: (1) remover o zumbi do mundo antes da morte quando a vida chegar a 0;
(2) remover o corpo no tick seguinte ao `OnZombieDead`. Validar em MP.

## Noite agressiva (todos os zumbis)

Cada item tem toggle próprio no sandbox:

1. **Mais rápidos e fortes** — multiplicadores de velocidade e dano à noite.
2. **Sentidos aguçados** — maior alcance de audição/visão; lanterna ligada ao ar
   livre torna o jogador visível de longe.
3. **Caça ativa** — a cada `HuntIntervalMinutes` (tempo de jogo), zumbis num raio
   recebem um som na posição do jogador e vão até lá.
4. **Variantes só noturnas** — Estalador, Corredor e Eco (acima).

Tudo volta ao normal ao amanhecer.

## Atmosfera (cliente)

### Clima (`ClimateManager`, override por Lua)
- Noite: luz global menor, leve dessaturação, tint azulado.
- Névoa: dessaturação forte, tint sépia/cinza, névoa mais densa que vanilla.
- Transição suave de ~30s reais.
- Intensidade configurável no sandbox.

### Som
- Névoa: ambiente troca para drone grave + ruídos metálicos distantes.
- Rádio chiando por proximidade do Sem-rosto.
- Estalo do Estalador, grito do Corredor.

### Overlays (só na névoa)
- Manchas de sangue e ferrugem surgem gradualmente em tiles próximos ao jogador e
  somem ao fim da névoa.
- **Locais e só visuais** — não sincronizam. Cada jogador vê o próprio pesadelo.

## Spike: shader próprio

Separado do MVP; não bloqueia nada.

- **Pergunta:** o B42 carrega GLSL vindo da pasta do mod?
- **Probe:** shader de vinheta + grão de filme ativado só na névoa.
- **Se sim:** vira camada extra da atmosfera.
- **Se não:** segue só com o clima.
- **Pré-requisito:** jogo instalado na máquina de desenvolvimento.

## Estrutura

```
42/mod.info
common/media/
  lua/shared/NOM_Config.lua      sandbox + constantes
  lua/shared/NOM_Rules.lua       lógica pura (sem API do jogo) — testável
  lua/server/NOM_World.lua       estado night/fog, emite eventos
  lua/server/NOM_Variants.lua    marca/desmarca, spawn/despawn de Ecos
  lua/server/NOM_Behaviors.lua   comportamento por variante + noite agressiva
  lua/client/NOM_Atmosphere.lua  clima, som, rádio
  lua/client/NOM_Overlays.lua    sangue/ferrugem locais
  clothing/ textures/ sound/
  sandbox-options.txt
```

Toda lógica de jogo roda no servidor (no solo o jogo roda os dois lados), então
solo e MP usam o mesmo código. O cliente só renderiza e toca som.

## Sandbox options

Página própria. Valores default entre parênteses.

- Toggles: cada item da noite agressiva, cada monstro, clima dark, overlays.
- `FogThreshold` — intensidade de névoa que acorda o Outro Mundo.
- `EstaladorChance`, `CorredorChance`, `SemRostoChance` — % de zumbis marcados.
- `NightSpeedMult`, `NightDamageMult`, sentidos, `HuntIntervalMinutes`.
- `CorredorScreamRadius`.
- `EcoMaxPerPlayer` (30), `EcoRadius` (40).
- Intensidade do clima dark.

## Robustez

- Desmarcar restaura `NOM_orig`.
- Mod removido do save: zumbis viram vanilla, `modData` órfã é ignorada.
- Loop de comportamento processa zumbis em lotes por tick (não todos de uma vez).
- Teto de Ecos por jogador evita travar servidor em vala comum.

## Testes

- `NOM_Rules.lua` (máquina de estado, sorteio, elegibilidade do Eco) roda no `lua`
  puro do terminal, com um script de asserts.
- In-game: checklist no modo `-debug` (forçar hora, névoa, spawn).
- MP: servidor local + dois clientes.

## Ordem de construção

Cada fase é jogável sozinha.

1. Estado do mundo + clima dark — ~1 fim de semana
2. Eco — ~1 fim de semana
3. Noite agressiva (4 toggles) — ~1 fim de semana
4. Estalador + Corredor (texturas, sons) — ~1-2 fins de semana
5. Sem-rosto + overlays + rádio — ~2 fins de semana
6. Publicação no Workshop — ~1 tarde

Spike de shader em paralelo, quando o jogo estiver instalado.
