# Noite agressiva

| Campo | Valor |
|-------|-------|
| Status | `accepted` |
| Sprint | 0003 |

## O que é

À noite, **todos os zumbis** ficam mais perigosos. Cada item tem toggle
próprio no sandbox e tudo volta ao normal ao amanhecer.

1. **Mais rápidos** (`NightFaster`, `NightSpeedMult`) — a velocidade do
   jogo é em degraus: arrastado → rápido → corredor. `NightSpeedMult` 1.5 (padrão)
   sobe um degrau, 2.5 sobe dois.
2. **Sentidos aguçados** (`NightSharperSenses`, `NightSenseMult`) — visão e audição
   também em degraus (ruim → normal → águia/apurada), mesma regra. Sandbox com
   sentido aleatório usa "normal" como base. Lanterna ligada ao ar livre vira
   farol: a cada minuto de jogo chama os zumbis num raio de `20 × NightSenseMult`
   tiles (20 é o teto da visão do zumbi no jogo).
3. **Caça ativa** (`NightHunt`) — a cada `HuntIntervalMinutes` (tempo de jogo),
   zumbis a até `HuntRadius` tiles recebem um som na posição de cada jogador e vão
   até lá, mesmo sem vê-lo.
4. **Variantes só noturnas** — Estalador, Corredor e Eco ([monsters.md](monsters.md)).
   O Eco **não** recebe o bônus: fica lento.

O sandbox vanilla já tem "zumbis mais ativos à noite" (só velocidade). Este
sistema vai além dele, não o substitui.

## Limites conhecidos

- **Força e dano não sobem.** O jogo não tem força nem dano por zumbi: o dano no
  jogador vem do `ZombieLore.Strength` global, lido na hora do golpe, e a força do
  zumbi (só usada contra portas, janelas e carros) é sorteada uma vez quando ele
  nasce. Fica como pendência; não há opção de sandbox pra dano.
- A visão de qualquer zumbi é presa entre 10 e 20 tiles pelo jogo; o degrau de
  águia rende pouco à noite (de ~15 pra 20). A audição rende mais (×3).
- Com a opção vanilla "Ativos só de dia/noite", o jogo também mexe na velocidade
  na troca de fase; o mod reaplica na passada seguinte.

Como é feito: [ADR-005](../architecture/adr-005-quem-simula-aplica.md).
