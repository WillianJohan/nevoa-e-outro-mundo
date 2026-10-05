# Noite agressiva

| Campo | Valor |
|-------|-------|
| Status | `accepted` |
| Sprint | 0003 |

## O que é

À noite, **todos os zumbis** ficam mais perigosos. Cada item tem toggle
próprio no sandbox e tudo volta ao normal ao amanhecer.

1. **Mais rápidos** (`NightFaster`, `NightSpeedMult`) — a velocidade do jogo é em
   degraus: arrastado → rápido → corredor. `NightSpeedMult` 1.5 (padrão) sobe um
   degrau, 2.5 sobe dois.
2. **Sentidos aguçados** (`NightSharperSenses`, `NightSenseMult`) — visão e audição
   também em degraus (ruim → normal → águia/apurada), mesma regra. Sandbox com
   sentido aleatório usa "normal" como base. Lanterna ligada ao ar livre vira
   farol: a cada 5 minutos de jogo chama os zumbis a até `20 × NightSenseMult`
   tiles (20 é o teto da visão do zumbi no jogo).
3. **Caça ativa** (`NightHunt`) — a cada `HuntIntervalMinutes` (90, tempo de jogo),
   zumbis a até `HuntRadius` (25) tiles recebem um som na posição de cada jogador e vão
   até lá, mesmo sem vê-lo.
4. **Eco** — o único monstro da noite ([monsters.md](monsters.md#eco)). Ele **não**
   recebe o bônus: fica lento e com a audição do dia, então ouve a caça e a
   lanterna a 1/3 do alcance (de propósito: alma fraca, não caçadora).

Estalador, Corredor e Sem-rosto **não são da noite**: só existem na névoa, de dia ou
de noite (decisão do Johan, 05/10/2026, [monsters.md](monsters.md#regra-geral)). Numa
noite com névoa, a variante vai por cima dos stats da noite: o Estalador fica cego e
de ouvido apurado mas corre como os outros da noite; o Corredor corre sempre. O
Estalador tem sempre o ouvido apurado: ouve a caça, a lanterna e o grito do Corredor
a 3× o alcance mesmo com `NightSharperSenses` desligado (de propósito: ele vive de som).

O alcance da caça e da lanterna é o configurado: o jogo multiplica o raio de todo
som pela audição do zumbi (×3 na apurada da noite), e o mod compensa.

O sandbox vanilla já tem "zumbis mais ativos à noite" (só velocidade). Este
sistema vai além dele, não o substitui. Com "Ativos só de dia/noite"
(`ZombieLore.ActiveOnly`), na fase em que o jogo deixa os zumbis inativos a
velocidade fica com o jogo (arrastados); os sentidos da noite valem mesmo assim.

## Sem força e sem dano à noite

**Decisão do autor (2026-10-04):** a noite não deixa os zumbis mais fortes nem
aumenta o dano. O jogo não tem força nem dano por zumbi: o dano no jogador vem do
`ZombieLore.Strength` global, lido na hora do golpe, e a força do zumbi (só usada
contra portas, janelas e carros) é sorteada uma vez quando ele nasce. A
alternativa — trocar o `ZombieLore.Strength` global a noite inteira — foi recusada
pelo risco de vazar pro save.

## Efeitos colaterais conhecidos

- **Bote (lunge).** Ao virar rápido ou corredor, o jogo liga o bote do zumbi
  (`lunger`), e nada no jogo desliga nem deixa ler. Zumbi arrastado promovido à
  noite continua dando bote depois do amanhecer, até ir pro virtual (sair de
  perto dos jogadores).
- **Sentido aleatório re-sorteia no anoitecer e no amanhecer.** Com visão ou
  audição "Aleatória" no sandbox, o jogo sorteia de novo cada vez que o mod
  aplica ou devolve os stats: o zumbi pode amanhecer com outro sentido (dentro do
  sorteio vanilla).
- A visão de qualquer zumbi é presa entre 10 e 20 tiles pelo jogo; o degrau de
  águia rende pouco à noite (de ~15 pra 20). A audição rende mais.
- O alcance compensado da caça e da lanterna ignora roupa e clima (o jogo também
  multiplica por eles).

Como é feito: [ADR-005](../architecture/adr-005-quem-simula-aplica.md).
