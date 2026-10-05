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
| [0015](sprint-0015-outro-mundo-sangrento/README.md) | Outro Mundo sangrento: muito sangue e erosão no máximo no chão e nas paredes, só na névoa e só local | `em teste` — [roteiro](sprint-0015-outro-mundo-sangrento/README.md#roteiro-in-game) |
| [0016](sprint-0016-monstro-sem-roupa/README.md) | Monstro sem roupa comum: na variante, a roupa vanilla some (só pele, peça do mod e feridas); volta no fim, e o loot da morte é o do zumbi comum | `em teste` — [roteiro](sprint-0016-monstro-sem-roupa/README.md#roteiro-in-game) |
| [0017](sprint-0017-semrosto-espalhado/README.md) | Sem-rosto espalhado (a horda vista junta reaparece em tiles diferentes) e chapéu caído não muda a variante | `em teste` — [roteiro](sprint-0017-semrosto-espalhado/README.md#roteiro-in-game) |
| [0018](sprint-0018-dissolve-bloom/README.md) | Dissolve e bloom: a peça do monstro se forma e se desfaz queimando, o Eco queima na morte com brasas, bloom no shader opcional | `em teste` — [roteiro](sprint-0018-dissolve-bloom/README.md#roteiro-in-game) |
| [0019](sprint-0019-balanceamento/README.md) | Balanceamento do PO (defaults novos, presets) e curva de tensão: a névoa começa rara e sem vermelha e aperta com os dias do save | `em teste` — [roteiro](sprint-0019-balanceamento/README.md#roteiro-in-game) |
| [0020](sprint-0020-debug-amigavel/README.md) | Debug amigável: atalhos `NOM.*` com `NOM.help()` no console e painel de botões no F7, só com `-debug` | `em teste` — [roteiro](sprint-0020-debug-amigavel/README.md#roteiro-in-game) |
| [spike](spike-shader/README.md) | Shader próprio na névoa | `concluída` (estática) — vinheta via SearchMode feita na 0005; grão e override do `screen.frag` feitos na 0013 (mod opcional) |
| [spike](spike-dissolve/README.md) | Dissolve na morte do Eco e na mutação das variantes | `concluída` (estática) — `m_Shader` na peça + `Alpha` como limiar; virou a [0018](sprint-0018-dissolve-bloom/README.md), probes no roteiro dela |
| [spike](spike-motor-visual/README.md) | Motor visual: estender o render (bloom, dissolver, fogo, luz, sombra) via ZombieBuddy | `concluída` (estática) — Java só cliente e opcional; bloom e dissolver são os únicos alvos que valem; sombra e luz do sol ficam com o ShadowZ. Corrigida na [0018](sprint-0018-dissolve-bloom/README.md): shader novo por peça sai sem Java |

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
