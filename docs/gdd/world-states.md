# Estados do mundo

| Campo | Valor |
|-------|-------|
| Status | `accepted` |
| Sprints | 0001 (noite), 0009 (névoa como evento) |

## O que é

O servidor mantém duas flags independentes:

| flag | condição |
|---|---|
| `night` | hora do jogo entre o pôr e o nascer do sol |
| `fog` | um evento de névoa do mod está aberto (sprint 0009) |

São flags, não um enum: as duas podem estar ativas ao mesmo tempo.

## Regras

- **A névoa é um evento do mod** (decisão do Johan, 05/10/2026, que reverte a do
  brainstorm de 04/10 "gatilho = névoa natural do clima"). Vale pro mapa inteiro.
  [ADR-009](../architecture/adr-009-nevoa-evento-do-mod.md).
  - **Quando:** numa hora qualquer, independente do dia e da noite. O intervalo até a
    próxima é sorteado, uniforme entre metade e uma vez e meia de `FogEventEveryDays`
    (padrão 3 dias de jogo), contado do fim da anterior: em média uma a cada 3 dias.
  - **Aviso:** uma **sirene** toca pra todo jogador, em qualquer lugar, **30 segundos
    reais** antes da névoa. Com o jogo pausado a contagem para. No sono e no
    fast-forward continua 30 s reais (muitas horas de jogo, se for o caso).
  - **Duração:** sorteada entre `FogMinHours` (2) e `FogMaxHours` (6) horas de jogo.
    A névoa entra e sai em ~20 minutos de jogo.
  - **Névoa natural não existe.** Fora do evento a névoa do jogo é zero, com qualquer
    clima, chuva ou opção de névoa do sandbox. O painel de clima do admin ainda passa
    por cima (escolha de quem administra), mas não abre evento.
  - Salvar e carregar no meio do evento volta com névoa e o mesmo número; no meio da
    sirene, ela toca de novo e os 30 s recomeçam.
- Mudança de flag dispara um evento interno (`NOM_World.onChange(fn)`,
  `fn("night"|"fog", valor)` só na borda), consumido pelos outros sistemas no
  servidor. O Eco usa a borda de fim da noite. Os clientes recebem as duas flags
  por comando do servidor (`night` desde a sprint 0003, `fog` desde a 0005), e
  quem entra no meio pergunta o estado. A sirene vai por comando (`siren`).
- Cada período (uma noite, uma névoa) tem um número próprio, contado pelo servidor
  e salvo com o mundo (o da névoa conta um por evento). O da **névoa** é a base do sorteio de todas as variantes
  (Estalador, Corredor, Sem-rosto, [monsters.md](monsters.md)); o da **noite** marca
  de que noite é cada Eco, e a hora em que ela abriu decide quais corpos já podem
  soltar Eco (sprint 0008).
