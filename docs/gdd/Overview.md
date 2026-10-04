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
névoa: fugir ou se esconder do Outro Mundo → amanhecer → repetir.

## Índice de sistemas

| Doc | Assunto | Status |
|-----|---------|--------|
| [world-states.md](world-states.md) | Detecção de noite e névoa | `accepted` |
| [night.md](night.md) | Noite agressiva (todos os zumbis) | `accepted` |
| [monsters.md](monsters.md) | Estalador, Corredor, Sem-rosto, Eco | `accepted` |
| [atmosphere.md](atmosphere.md) | Clima dark, som, overlays, shader | `accepted` |
| [sandbox.md](sandbox.md) | Opções de sandbox | `accepted` |

## Fora do MVP (`later`)

Carrasco (Pyramid Head-like), modelos 3D próprios, criaturas com esqueleto e
animação próprios, troca real de tiles, preset ReShade, evento com sirene.
Só viram escopo por promoção explícita.

## Decisões do autor

- **2026-10-04** — Público: Workshop (solo + MP, com sandbox).
- **2026-10-04** — Gatilho do Outro Mundo: névoa natural do clima, sem evento próprio.
- **2026-10-04** — Monstros por comportamento + visual simples, sem animação nova.
- **2026-10-04** — Eco: corpo solta Eco uma vez na vida; corpo queimado/enterrado não solta.
- **2026-10-04** — Visual: clima via Lua como base + spike de shader.
- **2026-10-04** — Noite sem força e sem dano a mais: o jogo não tem isso por zumbi, e trocar o `ZombieLore.Strength` global a noite inteira vazaria pro save. A noite é velocidade, sentidos e caça ([night.md](night.md#sem-força-e-sem-dano-à-noite)).
