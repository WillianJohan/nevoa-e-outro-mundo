# Estados do mundo

| Campo | Valor |
|-------|-------|
| Status | `accepted` |
| Sprints | 0001 (noite), 0009 (névoa como evento), 0033 (ritmo novo) |

## O que é

O servidor mantém três flags independentes:

| flag | condição |
|---|---|
| `night` | hora do jogo entre o pôr e o nascer do sol |
| `fog` | um evento de névoa do mod está aberto (sprint 0009) |
| `calm` | calmaria depois da névoa (sprint 0033) |

São flags, não um enum: podem estar ativas ao mesmo tempo (a calmaria só existe com a névoa fechada).

## Regras

- **A névoa é um evento do mod** (decisão do Johan, 05/10/2026, que reverte a do
  brainstorm de 04/10 "gatilho = névoa natural do clima"). Vale pro mapa inteiro.
  [ADR-009](../architecture/adr-009-nevoa-evento-do-mod.md).
  - **Quando (sprint 0033):** o servidor sorteia **por dia de jogo**, e não mais por intervalo
    depois do fim da anterior ([spec](../superpowers/specs/2026-10-06-modelo-novo-design.md)).
    - **Chance do dia:** `FogDailyChance` (padrão 65%). Com `FogEscalation` (padrão ligado) sobe em
      linha reta até `FogMaxDailyChance` (85%) no dia `FogEscalationDays` (60) desde o nascimento do
      save (`data.fog.bornAt`) e fica fixa. Desligado, a chance é sempre a do sandbox.
    - **Hora:** se o dia tem névoa, a sirene toca numa hora sorteada do dia.
    - **Segunda no mesmo dia:** `FogSecondChance` (15%). Só vale se começar antes da meia-noite (pode
      terminar depois) e depois de `FogMinGapHours` (6 h) sem névoa, pra não estragar a folga.
    - **Garantia:** `FogMaxDaysWithout` (2) dias seguidos sem névoa e o seguinte tem névoa com certeza.
    - **Determinismo:** o sorteio usa o número do dia e a semente do mundo (`NOM_VariantRules.hash`).
      Salvar e carregar não muda nada.
    - **Save antigo:** a sirene que já estava agendada (`data.fog.next`) vale como a névoa do dia se cair
      até o fim dele; marcada pra depois (o intervalo antigo ia a dias), sai, e o dia sorteia com a garantia.
  - **Aviso:** uma **sirene** toca pra todo jogador, em qualquer lugar, **45 segundos
    reais** antes da névoa. Com o jogo pausado a contagem para. No sono e no
    fast-forward continua 45 s reais (muitas horas de jogo, se for o caso). Cada névoa sorteia uma
    **direção** de onde a sirene "vem" (pura da semente e do número da névoa). Durante a sirene
    todo zumbi para virado pra essa direção e ignora o jogador; quando a névoa começa, todos voltam
    de uma vez (`NOM_SirenFreeze`, [pz-api-notes §21](../architecture/pz-api-notes.md#21-sirene-que-congela-sprint-0033)).
  - **Duração:** depende da cor, em horas de jogo: branca entre `FogMinHours` (3) e `FogMaxHours` (5);
    vermelha entre `RedFogMinHours` (4) e `RedFogMaxHours` (6). A névoa entra e sai em ~20 minutos de jogo.
  - **Calmaria:** quando a névoa acaba, por `FogCalmHours` (2 h de jogo) vale a flag `calm`. O zumbi
    comum fica um degrau mais lento e com visão e audição reduzidas (mesmo caminho dos stats da noite,
    [night.md](night.md); a calmaria vence a noite no zumbi comum). Eco e variantes não sentem. Uma névoa
    nova, aberta antes dela acabar, a encerra.
  - **Névoa natural não existe.** Fora do evento a névoa do jogo é zero, com qualquer
    clima, chuva ou opção de névoa do sandbox. O painel de clima do admin ainda passa
    por cima (escolha de quem administra), mas não abre evento.
  - Salvar e carregar no meio do evento volta com névoa e o mesmo número; no meio da
    sirene, ela toca de novo e os 45 s recomeçam.
- Mudança de flag dispara um evento interno (`NOM_World.onChange(fn)`,
  `fn("night"|"fog"|"calm", valor)` só na borda), consumido pelos outros sistemas no
  servidor. O Eco usa a borda de fim da noite. Os clientes recebem as flags
  por comando do servidor (`night` desde a sprint 0003, `fog` desde a 0005, `calm` desde a 0033), e
  quem entra no meio pergunta o estado. A sirene vai por comando (`siren`).
- Cada período (uma noite, uma névoa) tem um número próprio, contado pelo servidor
  e salvo com o mundo (o da névoa conta um por evento). O da **névoa** é a base do sorteio de todas as variantes
  (Estalador, Corredor, Sem-rosto, [monsters.md](monsters.md)); o da **noite** marca
  de que noite é cada Eco, e a hora em que ela abriu decide quais corpos já podem
  soltar Eco (sprint 0008).
