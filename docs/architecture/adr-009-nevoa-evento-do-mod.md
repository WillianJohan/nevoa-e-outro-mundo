# ADR-009 — A névoa é um evento do mod, e o mod é dono do canal de névoa

| Campo | Valor |
|-------|-------|
| Status | `accepted` |
| Data | 2026-10-05 |
| Substitui | o gatilho "névoa natural do clima" ([world-states.md](../gdd/world-states.md), sprint 0001) |
| Emendada por | [ADR-010](adr-010-nevoa-vermelha.md) (névoa vermelha: `data.fog.red`, `red` no comando `fog` e na sirene, cor da névoa); [emenda da sprint 0019](#emenda-de-2026-10-05--sprint-0019-curva-de-tensão) (curva de tensão, `data.fog.bornAt`) |
| Emenda | [ADR-004](adr-004-clima-antes-de-shader.md) e [ADR-008](adr-008-noite-pela-luz-global.md) (o canal `FLOAT_FOG_INTENSITY` sai do look) |

## Contexto

Até a sprint 0008 o Outro Mundo acordava com a névoa natural do clima acima de
`FogThreshold`. Decisão do Johan (05/10/2026): a névoa é um **evento**, em hora
aleatória, ~1 a cada 3 dias de jogo, anunciado por uma **sirene 30 segundos reais
antes**, durando 2 a 6 horas de jogo; e névoa natural vanilla **não existe**.

O que o bytecode do B42.21 diz sobre o canal de névoa ([pz-api-notes §11](pz-api-notes.md#11-névoa-como-evento-sprint-0009)):

- Por minuto de jogo, no servidor/solo: `updateSandboxOverrides` → `updateValues` →
  `WeatherPeriod.update` → `OnClimateTick` → `calculate` (`ClimateManager.update`
  363–461). O `calculate` faz admin, depois a camada modded no interno, depois o
  override por cima.
- Dois donos de override religam a névoa todo minuto, **antes** do nosso evento: o
  sandbox (`FogCycle` "sem névoa"/"névoa eterna", `ClimateCycle` "nevasca eterna"; de
  valor, o final ignora o interno) e o `WeatherPeriod` (chuva e tempestade:
  `setOverride(0, t)` ou a névoa do estágio).
- `setEnableOverride(false)` só zera o `isOverride`; não vai pro save.

## Decisão

1. **Agenda no servidor** (`server/NOM_FogEvent.lua`, regra pura em
   `shared/NOM_FogEventRules.lua`). Estado no `ModData` global, `data.fog`:
   `night` (número do período, a chave da sprint 0005), `inNight`, `next` (hora de
   mundo da próxima sirene) e `endAt` (fim do evento aberto).
   - Intervalo: uniforme entre 0,5× e 1,5× de `FogEventEveryDays`, contado **do fim**
     do evento anterior (média = o valor; um ciclo completo dá o valor mais a duração
     média, ~3,2 dias com o padrão).
   - Duração: uniforme entre `FogMinHours` e `FogMaxHours` (min > max troca os dois).
   - Verificado uma vez por minuto de jogo (`OnClimateTick`). Fast-forward, sono ou
     admin que pula dias: um evento só, nada se acumula.
2. **Sirene em tempo real.** Na hora marcada, o servidor toca a sirene (solo: local;
   dedicado: comando `siren` pra todos) e conta 30 000 ms com `getTimestampMs()` no
   `OnTick`. A contagem para com `isGamePaused()` (velocidade 0 no solo; servidor
   vazio com `PauseEmpty`) e um frame desconta no máximo 1 s (travada, volta da
   pausa). Quando zera, o evento abre: período novo, `endAt` sorteado,
   `NOM_World.setFog(true)`. No sono e no fast-forward a sirene continua 30 s reais
   antes: em horas de jogo isso é mais tempo, e tudo bem (a promessa é pro jogador).
3. **Recarga.** O estado salvo sobrevive; a contagem da sirene, não: carregar durante
   ela **toca a sirene de novo e recomeça os 30 s** (o `next` segue no passado).
   Carregar no meio do evento volta com névoa e o mesmo período. Save da sprint 0008
   com a névoa natural aberta (`inNight` sem `endAt`) fecha sem contar.
4. **O mod é dono do canal de névoa** (`server/NOM_ClimateLook.lua`, todo
   `OnClimateTick`): camada modded ligada sempre, valor absoluto
   `DENSITY × rampa` (0 fora do evento; `DENSITY` 0.85, rampa de 20 minutos de jogo
   na entrada e na saída), `setModdedInterpolate(1)`, e `setEnableOverride(false)` se
   o jogo religou o override. Independente de `DarkEnabled`: a névoa é o evento; o
   look (tint, dessaturação, ambient) continua por cima, como na ADR-008.
5. **Admin passa por cima.** O painel de clima do admin (`isAdminOverride`) vence o
   `calculate` antes de tudo; o mod não briga. É escolha explícita de quem administra.
6. **`FogThreshold` sai.** Sem leitura do clima não há limite a comparar. O sandbox
   desconhecido de saves antigos é pulado pelo jogo (pz-api-notes §8).

## Alternativas recusadas

| Alternativa | Por que não |
|---|---|
| Trocar `FogCycle` pra "sem névoa" via `getSandboxOptions():getOptionByName(...):setValue(2)` | É opção do jogador e vai pro save no próximo `saveGameFile`; e o override de valor 0 também apagaria a névoa do evento. |
| Admin override pra escrever a névoa | `ClimateManager.save` grava o admin: remover o mod deixaria a névoa travada no save; e briga com o painel de clima do admin. |
| Sirene em minutos de jogo | 30 s reais viram de 30 s a minutos de jogo conforme o dia, a velocidade e o sono; a promessa é pro ouvido do jogador. |
| Contagem salva no `ModData` | Recarregar é raro e tocar a sirene de novo é o aviso certo pra quem acabou de entrar. |

## Consequências

- **Resíduo da névoa vanilla:** o `updateValues` calcula a névoa natural e, com ela,
  puxa a luz global pra cor de névoa, aumenta a dessaturação, corta nuvem e sobe a
  umidade (1019–1341, 1644–1770) **antes** da camada modded. Zerar o canal não desfaz
  isso: numa manhã em que a vanilla teria névoa, o céu fica mais cinza sem névoa
  nenhuma. É o mesmo que o `FogCycle` "Sem névoa" da vanilla faz. Roteiro in-game da
  sprint 0009 confere.
- Névoa, visão e áudio do jogo leem o final (`getFogIntensity`, `updateFx`,
  `updateViewDistance`): seguem o mod.
- Toda chuva/tempestade e todo `FogCycle` deixam de mexer na névoa; o resto do clima
  (chuva, vento, nuvem) fica intacto.
- O período de névoa muda de ritmo (agora ~1 a cada 3 dias); o número continua a
  mesma chave e a [ADR-006](adr-006-variantes-deterministicas.md) não muda.

## Emenda de 2026-10-05 — sprint 0019: curva de tensão

Balanceamento do PO aprovado pelo Johan: a agenda deixa de ter média fixa.

1. **Nascimento do save.** `data.fog.bornAt` (hora de mundo) é gravado uma vez, no
   `state()` do `server/NOM_FogEvent.lua` (`NOM_FogEventRules.born`), como a `seed`. Save
   novo nasce agora. Save veterano (já tem `night` ou `next`, sem `bornAt`) nasce **no ponto
   neutro da curva**, 30 dias antes do primeiro carregamento: intervalo 1×, vermelha 1×,
   carência vencida; quem já jogava não sente mudança (ruling da review). `bornAt` no futuro
   vira agora. `d` = dias desde o bornAt (`NOM_FogEventRules.days`, nunca negativo); o
   `worldAge` cru não entra. O save antigo também guarda o próprio sandbox
   (`SandboxOptions.load(ByteBuffer)` 81–122 só lê as opções gravadas): os defaults novos
   valem pra save novo.
2. **Intervalo.** Com `FogEscalation` (padrão ligado), a média é
   `FogEventEveryDays × clamp(1,5 − d/60, 0,75, 1,5)` (`NOM_FogEventRules.everyDays`). O
   intervalo continua uniforme entre 0,5× e 1,5× da média, sorteado no `R.stop` (fim do
   evento, com o `d` daquele momento) e salvo no `next`; a primeira agenda de um save novo
   usa o `d` de agora. Mudar o sandbox no meio não mexe no `next` já salvo. Desligado, a média
   é o `FogEventEveryDays`, como antes.
3. **Por que no stop e não em todo minuto:** o `next` salvo é a promessa; recalcular a cada
   minuto com o `d` andando faria a sirene "adiantar" sozinha e quebraria o
   `fog_event_no_compounding_after_long_skip` (sono longo = um evento só).

Sono ou fast-forward de meses satura a curva (0,75×), sem acumular evento. Default da base
passou de 3 pra 2 dias e da duração mínima de 2 pra 3 horas: com a curva, o começo do save
fica ~3 dias efetivos, como era.
