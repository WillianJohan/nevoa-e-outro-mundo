# Overview — Névoa e Outro Mundo

| Campo | Valor |
|-------|-------|
| Status | `accepted` |
| Tipo | Hub do GDD (único ponto de entrada) |

## O que é o mod

Mod de horror para **Project Zomboid Build 42**, inspirado em The Last of Us e
Silent Hill. Publicado no Steam Workshop, funciona em solo e multiplayer.

**A noite traz infectados de carne (TLOU). A névoa traz o Outro Mundo (Silent Hill).**
Quando os dois coincidem, valem juntos: é a pior noite possível, de propósito.

## Pilares

1. **O mundo tem horário de perigo** — dia é respiro, noite e névoa são ameaça.
2. **Ameaça por comportamento, não por número** — cada monstro muda como tu joga
   (agachar, apagar a lanterna, não olhar).
3. **Limpar tem valor** — corpo deixado no chão vira problema à noite.
4. **Configurável** — tudo tem toggle e número no sandbox; o servidor escolhe o
   nível de sofrimento.
5. **Solo = MP** — a lógica roda no servidor; o mesmo código serve os dois.
6. **Traduzível desde o nascimento** — todo texto por chave; PT-BR desde a
   sprint 0001, EN na publicação.

## Loop

Dia: saquear, limpar corpos (queimar/enterrar), preparar abrigo →
noite: sobreviver aos infectados agressivos e aos Ecos →
sirene → névoa (de dia ou de noite, a cada ~3 dias): fugir ou se esconder do Outro Mundo — Estaladores,
Corredores, Sem-rosto, Carpideiras → amanhecer → repetir.

## Índice de sistemas

| Doc | Assunto | Status |
|-----|---------|--------|
| [world-states.md](world-states.md) | Noite e evento de névoa (sirene) | `accepted` |
| [night.md](night.md) | Noite agressiva (todos os zumbis) | `accepted` |
| [monsters.md](monsters.md) | Estalador, Corredor, Sem-rosto, Carpideira, Eco | `accepted` |
| [atmosphere.md](atmosphere.md) | Clima dark, som, overlays, shader | `accepted` |
| [sandbox.md](sandbox.md) | Opções de sandbox | `accepted` |
| [art-direction.md](art-direction.md) | Visual dos monstros: o que cada um veste e por quê | `accepted` |

## Fora do MVP (`later`)

Carrasco (Pyramid Head-like), modelos 3D próprios, criaturas com esqueleto e
animação próprios, troca real de tiles, preset ReShade. (O evento com sirene foi
promovido na sprint 0009.)
Só viram escopo por promoção explícita.

## Decisões do autor

- **2026-10-04** — Público: Workshop (solo + MP, com sandbox).
- **2026-10-04** — ~~Gatilho do Outro Mundo: névoa natural do clima, sem evento próprio.~~
  Revertida em 05/10 (abaixo).
- **2026-10-04** — Monstros por comportamento + visual simples, sem animação nova.
- **2026-10-04** — Eco: corpo solta Eco uma vez na vida; corpo queimado/enterrado não solta.
- **2026-10-04** — Visual: clima via Lua como base + spike de shader.
- **2026-10-04** — Noite sem força e sem dano a mais: o jogo não tem isso por zumbi, e trocar o `ZombieLore.Strength` global a noite inteira vazaria pro save. A noite é velocidade, sentidos e caça ([night.md](night.md#sem-força-e-sem-dano-à-noite)).
- **2026-10-05** — Todos os monstros, exceto os Ecos, só na névoa; chances 5/2/3/5
  (Estalador, Corredor, Carpideira da sprint 0011, Sem-rosto). A noite fica com a
  agressividade dos zumbis comuns e os Ecos ([monsters.md](monsters.md#regra-geral)).
- **2026-10-05** — O Eco só nasce de quem morreu antes do anoitecer: quem morre de
  noite espera o próximo entardecer ([monsters.md](monsters.md#eco)).
- **2026-10-05** — A noite tem que ser claramente mais escura que a vanilla
  ([atmosphere.md](atmosphere.md#clima)).
- **2026-10-05** — **A névoa é um evento do mod, não clima** (reverte a decisão de
  04/10 "gatilho = névoa natural do clima"): numa hora aleatória, em média a cada ~3
  dias de jogo (`FogEventEveryDays`), uma sirene toca 30 segundos reais antes; dura de
  2 a 6 horas de jogo (`FogMinHours`, `FogMaxHours`). Névoa natural vanilla não existe:
  o mod é dono do canal de névoa ([world-states.md](world-states.md),
  [ADR-009](../architecture/adr-009-nevoa-evento-do-mod.md)).
- **2026-10-05** — **Névoa vermelha** (sprint 0010): a cada evento de névoa,
  `RedFogChance`% (10) de chance de vir vermelha, sorteada pelo número da névoa (salvar
  e carregar não muda). Sirene própria (mais grave, distorcida e longa) no lugar da
  normal, névoa e luz vermelhas, e **todo** zumbi nela é monstro, dividido por igual
  entre os tipos (o Eco continua Eco) ([monsters.md](monsters.md#regra-geral),
  [atmosphere.md](atmosphere.md#clima),
  [ADR-010](../architecture/adr-010-nevoa-vermelha.md)).
- **2026-10-05** — **Carpideira** (sprint 0011), pedido do Johan: um 4º monstro da névoa
  que grita muito alto (inspirado na Witch do L4D e no grito de horda do Back 4 Blood,
  sem copiar). Parada e soluçando; acorda com jogador a 4 tiles, lanterna apontada ou
  barulho alto a até 10; grita (horda a 60 tiles) e caça quem a acordou. Chance 3%
  (decisão do Johan), na faixa depois das outras (15% somados); na névoa vermelha, 1/4
  de cada tipo. Um grito por névoa ([monsters.md](monsters.md#carpideira),
  [ADR-011](../architecture/adr-011-carpideira.md)).
- **2026-10-05** — **Visual dos monstros** (sprint 0012), decisão do Johan: cada monstro com
  cara própria, de **textura procedural original em modelo 3D vanilla** (máscara, véu, camada
  no corpo), sem modelo 3D novo por enquanto. "Não quero ser igual TLOU... quero me inspirar,
  então pode ser criativo": nada de cabeça de fungo nem de cópia de Silent Hill; o visual conta
  o que o monstro faz. A roupa do zumbi fica e o outfit não muda (o sorteio depende dele)
  ([art-direction.md](art-direction.md),
  [ADR-012](../architecture/adr-012-visual-das-variantes.md)).
