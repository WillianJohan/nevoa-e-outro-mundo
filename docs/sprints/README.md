# Sprints

Cada sprint tem **um objetivo jogável**: ao fechar, o mod faz algo novo que dá
pra ver no jogo. Uma pasta por sprint, `sprint-NNNN-slug/README.md`.

## Roadmap

| Sprint | Objetivo | Status |
|--------|----------|--------|
| [0001](sprint-0001-estado-e-clima/README.md) | Noite e névoa detectadas e com clima dark | `em teste` |
| [0002](sprint-0002-eco/README.md) | Eco: corpos soltam almas à noite | `em teste` |
| [0003](sprint-0003-noite-agressiva/README.md) | Noite agressiva (todo zumbi) | `backlog` |
| [0004](sprint-0004-estalador-corredor/README.md) | Estalador + Corredor noturno | `backlog` |
| [0005](sprint-0005-sem-rosto-e-nevoa/README.md) | Sem-rosto + atmosfera da névoa | `backlog` |
| [0006](sprint-0006-balanceamento-mp/README.md) | Balanceamento, MP e performance | `backlog` |
| [0007](sprint-0007-workshop/README.md) | Publicação no Workshop | `backlog` |
| [spike](spike-shader/README.md) | Shader próprio na névoa | `backlog` — precisa do jogo instalado |

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
