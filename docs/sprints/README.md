# Sprints

Cada sprint tem **um objetivo jogável**: ao fechar, o mod faz algo novo que dá
pra ver no jogo. Uma pasta por sprint, `sprint-NNNN-slug/README.md`.

## Roadmap

| Sprint | Objetivo | Status |
|--------|----------|--------|
| [0001](sprint-0001-estado-e-clima/README.md) | Noite e névoa detectadas e com clima dark | `em teste` |
| [0002](sprint-0002-eco/README.md) | Eco: corpos soltam almas à noite | `em teste` |
| [0003](sprint-0003-noite-agressiva/README.md) | Noite agressiva (todo zumbi) | `em teste` |
| [0004](sprint-0004-estalador-corredor/README.md) | Estalador + Corredor noturno | `em teste` |
| [0005](sprint-0005-sem-rosto-e-nevoa/README.md) | Sem-rosto + atmosfera da névoa | `em teste` |
| [0006](sprint-0006-balanceamento-mp/README.md) | Balanceamento, MP e performance | `em teste` — [roteiro in-game consolidado](../teste-in-game.md) |
| [0007](sprint-0007-workshop/README.md) | Publicação no Workshop | `em teste` — envio e release pelo [publicar.md](../publicar.md), depois do roteiro in-game |
| [0008](sprint-0008-ajustes-teste/README.md) | Ajustes do primeiro teste in-game (noite escura, monstros só na névoa, Eco) | `em teste` — [roteiro](sprint-0008-ajustes-teste/README.md#roteiro-in-game) |
| [0009](sprint-0009-nevoa-evento/README.md) | Névoa como evento: sirene 30 s antes, hora aleatória, 2–6 h; sem névoa natural | `em teste` — [roteiro](sprint-0009-nevoa-evento/README.md#roteiro-in-game) |
| [0010](sprint-0010-nevoa-vermelha/README.md) | Névoa vermelha: sirene própria, névoa e luz vermelhas, todo zumbi é variante | `em teste` — [roteiro](sprint-0010-nevoa-vermelha/README.md#roteiro-in-game) |
| [0011](sprint-0011-carpideira/README.md) | Carpideira: parada e soluçando na névoa, grita (horda) e caça quem a acorda | `em teste` — [roteiro](sprint-0011-carpideira/README.md#roteiro-in-game) |
| [0012](sprint-0012-visual-variantes/README.md) | Visual das variantes e do Eco: pele e peça por textura procedural em modelo vanilla | `em teste` — [roteiro](sprint-0012-visual-variantes/README.md#roteiro-in-game) |
| [0013](sprint-0013-efeitos-tela/README.md) | Efeitos de tela na névoa: overlay Lua (grão, vinheta, chiado, pulso) + shader opcional num segundo mod | `em teste` — [roteiro](sprint-0013-efeitos-tela/README.md#roteiro-in-game) |
| [0014](sprint-0014-contraste-visual/README.md) | Contraste dos visuais: texturas agressivas (preto e branco cheios, formas grandes) nos mesmos modelos, pra ler sob a névoa | `em teste` — [roteiro](sprint-0014-contraste-visual/README.md#roteiro-in-game) |
| [0016](sprint-0016-monstro-sem-roupa/README.md) | Monstro sem roupa comum: na variante, a roupa vanilla some (só pele, peça do mod e feridas); volta no fim, e o loot da morte é o do zumbi comum | `em teste` — [roteiro](sprint-0016-monstro-sem-roupa/README.md#roteiro-in-game) |
| [spike](spike-shader/README.md) | Shader próprio na névoa | `concluída` (estática) — vinheta via SearchMode feita na 0005; grão e override do `screen.frag` feitos na 0013 (mod opcional) |

A ordem é deliberada: 0001 é a fundação (estado do mundo) que todo o resto
consome; 0002 vem antes da noite agressiva porque o Eco é o sistema mais
isolado e o que mais testa a técnica de spawn/despawn; 0006 existe porque
"funciona na minha máquina" não é "aguenta 3 noites de MP".

O spike não tem lugar fixo: roda quando o jogo estiver instalado e o resultado
dele decide se vira sprint.

Sprint em `backlog` tem objetivo e critérios, mas **não tem `plan.md`**. O plano
é escrito quando ela vira `planejada`, com o que as anteriores ensinaram.

## Estados

`backlog` → `planejada` → `em andamento` → `em teste` → `bloqueada: <motivo>` → `concluída`

Atualizado a cada marco relevante, não a cada commit.

## Formato do README de cada sprint

```markdown
# Sprint NNNN — <Título>

| Campo | Valor |
|-------|-------|
| Status | planejada |
| Branch | `sprint/NNNN-slug` |
| Plano | [plan.md](plan.md) |
| GDD | links dos docs de sistema que a sprint entrega |

## Objetivo

<uma frase: o que dá pra ver no jogo quando a sprint fechar>

## Critérios de aceite

- [ ] <condição verificável> — ao marcar, dizer **como** foi confirmado

## Checkpoints

- **DD/MM** — <o que aconteceu>

## Aprendizados

<armadilhas do PZ/Lua descobertas na sprint — o que custou caro descobrir>

## Pendências que a próxima sprint herda

## Sessões

- <data> — <uuid> — <o que foi feito>
```

### Regras

- **Critério marcado sem evidência não conta.** Escreva como foi confirmado
  (teste, log, print, checklist em `-debug`).
- **`## Sessões`** guarda o UUID de cada conversa do Claude Code que trabalhou na
  sprint (`claude --resume <uuid>`). A linha entra quando o trabalho começa.
- **Aprendizado** é o que alguém precisaria saber pra não perder a mesma tarde
  de novo. Não é diário.
