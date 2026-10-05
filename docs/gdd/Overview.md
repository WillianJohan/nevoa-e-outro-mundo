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
Corredores, Sem-rosto → amanhecer → repetir.

## Índice de sistemas

| Doc | Assunto | Status |
|-----|---------|--------|
| [world-states.md](world-states.md) | Noite e evento de névoa (sirene) | `accepted` |
| [night.md](night.md) | Noite agressiva (todos os zumbis) | `accepted` |
| [monsters.md](monsters.md) | Estalador, Corredor, Sem-rosto, Eco | `accepted` |
| [atmosphere.md](atmosphere.md) | Clima dark, som, overlays, shader | `accepted` |
| [sandbox.md](sandbox.md) | Opções de sandbox | `accepted` |

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
  (Estalador, Corredor, Carpideira da sprint 0010, Sem-rosto). A noite fica com a
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
