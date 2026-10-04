# Noite agressiva

| Campo | Valor |
|-------|-------|
| Status | `draft` |
| Sprint | 0003 |

## O que é

À noite, **todos os zumbis** ficam mais perigosos. Cada item tem toggle
próprio no sandbox e tudo volta ao normal ao amanhecer.

1. **Mais rápidos e fortes** — multiplicadores de velocidade e dano.
2. **Sentidos aguçados** — maior alcance de audição e visão. Lanterna ligada ao
   ar livre torna o jogador visível de longe.
3. **Caça ativa** — a cada `HuntIntervalMinutes` (tempo de jogo), zumbis num raio
   recebem um som na posição do jogador e vão até lá, mesmo sem vê-lo.
4. **Variantes só noturnas** — Estalador, Corredor e Eco ([monsters.md](monsters.md)).

O sandbox vanilla já tem "zumbis mais ativos à noite" (só velocidade). Este
sistema vai além dele, não o substitui.
