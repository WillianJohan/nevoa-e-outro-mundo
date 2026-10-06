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
| [0020](sprint-0020-debug-amigavel/README.md) | Debug amigável: atalhos `NOM.*` com `NOM.help()` no console e painel de botões no Insert, só com `-debug` | `em teste` — [roteiro](sprint-0020-debug-amigavel/README.md#roteiro-in-game) |
| [0021](sprint-0021-outro-mundo-ajustes/README.md) | Outro Mundo: correções vistas no jogo — chão só de decalque chato e só onde o jogador vê, nunca por cima dele; sujeira sem xadrez; paredes desligadas com o porquê | `em teste` — [roteiro](sprint-0021-outro-mundo-ajustes/README.md#roteiro-in-game) |
| [0022](sprint-0022-brasa-corpo-inteiro/README.md) | Brasa no corpo inteiro: na mutação e na volta da variante, uma casca de brasa cobre o zumbi todo e se desfaz revelando o monstro (ou o zumbi comum), com brasas subindo | `em teste` — [roteiro](sprint-0022-brasa-corpo-inteiro/README.md#roteiro-in-game) |
| [0023](sprint-0023-outro-mundo-anexado/README.md) | Outro Mundo anexado: sangue, sujeira, rachadura, chão queimado e mato presos ao chão e às paredes de verdade (embaixo dos personagens, com luz e recorte), paredes de volta, nada no save | `concluída` |
| [0024](sprint-0024-nevoa-fluida/README.md) | Névoa fluida no mod3: contorna parede, árvore e carro, escorre por porta aberta, abre rastro atrás de quem anda; mais densa no chão e cinza em cima | `em teste` — [roteiro](sprint-0024-nevoa-fluida/README.md#roteiro-in-game) |
| [0025](sprint-0025-luz-da-nevoa/README.md) | Luz e volume na névoa: rolos com silhueta, sombra própria e fiapos (só shader); `NOMRender_setParam(5, 0/1)` compara com o antigo | `em teste` — [roteiro](sprint-0025-luz-da-nevoa/README.md#roteiro-in-game) |
| [0026](sprint-0026-nevoa-viajante/README.md) | Névoa viajante: bancos levados pelo vento, vácuo atrás de prédio, rastro que viaja; carro, porta, tiro e explosão empurram; lanterna e farol acendem e abrem a névoa; qualidade nas opções | `em teste` — [roteiro](sprint-0026-nevoa-viajante/README.md#roteiro-in-game) |
| [0027](sprint-0027-nevoa-organica/README.md) | Névoa orgânica: sem o vai e vem dos rolos (ruído anda com os bancos, nada recomeça), vento por ruído | `em teste` — [roteiro](sprint-0027-nevoa-organica/README.md#roteiro-in-game) |
| [0028](sprint-0028-nevoa-sem-vanilla/README.md) | Névoa só nossa: a vanilla sai (deixava uma faixa sem névoa embaixo com zoom afastado) e o shader ganha véu de fundo | `em teste` — [roteiro](sprint-0028-nevoa-sem-vanilla/README.md#roteiro-in-game) |
| [0029](sprint-0029-ondas-nos-obstaculos/README.md) | Ondas nos obstáculos: reforço de redemoinho na esteira e rolo que sobe onde o ar freia contra a parede | `em teste` — [roteiro](sprint-0029-ondas-nos-obstaculos/README.md#roteiro-in-game) |
| [0030](sprint-0030-nevoa-em-alta-resolucao/README.md) | Névoa em alta resolução: 1 a 3 células por tile (parâmetro e Opções > Mods), simulação numa linha própria, redemoinho sem xadrez | `em teste` — [roteiro](sprint-0030-nevoa-em-alta-resolucao/README.md#roteiro-in-game) |
| [0031](sprint-0031-nevoa-que-contorna/README.md) | Névoa que contorna: vácuo atrás do prédio vira opção (param 10), árvore porosa, carro baixo, pressão com chute, rolo só a barlavento (etapa 1 da [pesquisa](../architecture/pesquisa-nevoa-volumetrica.md)) | `em teste` — [roteiro](sprint-0031-nevoa-que-contorna/README.md#roteiro-in-game) |
| [0032](sprint-0032-nevoa-com-altura/README.md) | Névoa com altura: passa por cima da cerca baixa e do carro, para na parede; empilha e transborda (etapa 2 da [pesquisa](../architecture/pesquisa-nevoa-volumetrica.md)) | `em teste` — [roteiro](sprint-0032-nevoa-com-altura/README.md#roteiro-in-game) |
| [0033](sprint-0033-ritmo-novo/README.md) | Ritmo novo: névoa sorteada por dia (65% subindo até 85%, segunda névoa com folga, garantia no 3º dia), duração por tipo, sirene de 45 s que congela todos os zumbis virados pra mesma direção (trocada na 0034), 2 h de calmaria depois; comandos de debug novos e foco de vento no mod3 ([modelo novo](../superpowers/specs/2026-10-06-modelo-novo-design.md)) | `em teste` — [roteiro](sprint-0033-ritmo-novo/README.md#roteiro-in-game) |
| [0034](sprint-0034-sons/README.md) | Sons I, sirene e fuga: estática na tela 3 s antes da sirene, coro de 5 sirenes ao longe (150–500 tiles, 31 sons nossos de 11,8 s), 30 s de fuga com a névoa subindo e os zumbis parados virados pro jogador; TV, rádio e carro chiam na névoa; Outro Mundo pela tela, casa destruída e sem sangue no chão; correção do dono do zumbi no solo (`isLocal`) | `em teste` (branch `sprint/0034-sons`) — [roteiro](sprint-0034-sons/README.md#roteiro-de-teste-no-jogo) |
| próxima (0035) | Outro Mundo estilo Silent Hill: tinta descascando, ferrugem e grade na erosão, partículas saindo do chão e das paredes, transição descascando no shader depois da sirene, transição escondida e tontura (decisão do Johan, 2026-10-06) | backlog |
| futuro | Sprints 0036 a 0044 do [modelo novo](../superpowers/specs/2026-10-06-modelo-novo-design.md#10-fila-de-sprints): equilíbrio (visão de ~4 tiles e perambular), sonar do Estalador, névoa preta (0038–0039, ideia do Johan de 2026-10-05), vermelha nova e facelift dos monstros (inclui o rosto censurado do Sem Rosto, que era a 0033 antiga) | ideia |
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
