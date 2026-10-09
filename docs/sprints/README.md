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
| [0035](sprint-0035-silent-hill/README.md) | Outro Mundo estilo Silent Hill: a erosão descasca em manchas ao abrir (6 s) e recua ao fechar (4 s), lascas de tinta e cinza sobem do chão e das paredes, tontura na transição (opção ligada por padrão), 50 texturas nossas (grade, ferrugem, chapa, tinta descascando) como sprite de runtime ([ADR-018](../architecture/adr-018-sprite-proprio-em-runtime.md)), borda da tela coberta andando, teto de custo do carro; cobertura além da tela medida e não feita (margem do save); todo comando de debug com botão no painel | `em teste` (branch `sprint/0035-silent-hill`) — [roteiro](sprint-0035-silent-hill/README.md#roteiro-de-teste-no-jogo) |
| [0036](sprint-0036-equilibrio/README.md) | Equilíbrio: na névoa branca e na vermelha o zumbi comum (e o Sem-rosto) enxerga ~4 tiles e acha o jogador pelo barulho (cegueira em rodízio, medida antes: ~1/7 do custo da ingênua com 300 zumbis); grupos de 1 a 3 zumbis parados perambulam pela região a cada 4–8 min de jogo, nunca na direção do jogador; opções `FogZombieVision` e `FogWander`; `NOM.wander()` e `NOM.blind()` com botão no painel | `em teste` (branch `sprint/0036-equilibrio`) — [roteiro](sprint-0036-equilibrio/README.md#roteiro-de-teste-no-jogo) |
| [0037](sprint-0037-sonar-estalador/README.md) | Sonar do Estalador: cada estalo (a cada 5–30 s reais, sorteado) solta um anel de 8 tiles (1,5 s); em pé ou andando o Estalador te acha mesmo cego (e não volta a cegar por 10 s), agachado e parado o anel passa, e casa protege (um dentro e o outro fora, não acha). O servidor decide e o estalo é o mesmo pra todos no MP; o anel empurra a névoa fluida do mod3 ou, sem ela, aparece discreto no chão; `NOM.sonar()` com botão no painel | `em teste` (branch `sprint/0037-sonar-estalador`) — [roteiro](sprint-0037-sonar-estalador/README.md#roteiro-de-teste-no-jogo) |
| [0037b](sprint-0037b-noise-of-mist/README.md) | Renomeação pra "NOM: Noise of Mist": IDs `NoiseOfMist`, `NoiseOfMist_Shader` e `NoiseOfMist_Volumetrica` (nomes de espaço no Lua mantidos), arte de lançamento do Johan ([ADR-019](../architecture/adr-019-arte-de-lancamento.md)), jar `NoiseOfMist_Volumetrica.jar`; o `dev-sync.sh` instala o mod de staging (`*_Staging`, `[STAGING]`, pôster vermelho, incompatível com o oficial) | `em teste` (branch `sprint/0037b-noise-of-mist`) — [roteiro](sprint-0037b-noise-of-mist/README.md#roteiro-de-teste-no-jogo) |
| [0037c](sprint-0037c-tiro-abre-nevoa/README.md) | Tiro abre a névoa do mod3: cada tiro ou explosão abre uma clareira na névoa inteira (véu de fundo incluso) de 5 a 12 tiles (pistola: 10), que abre em 0,15 s e fecha em 4 s; o sopro no fluido também ficou maior; log `[NOM-Render] tiro na névoa` (até 10 por minuto) | `em teste` (branch `fix/tiro-abre-nevoa`) — [roteiro](sprint-0037c-tiro-abre-nevoa/README.md#roteiro-de-teste-no-jogo) |
| [0038](sprint-0038-nevoa-preta/README.md) | Névoa preta I: 5% das névoas a partir do dia 14 (2–3 h), noite fechada mesmo de dia, todo zumbi vira Tição (arrastado, visão de 3 tiles, ouve muito, caça a cada 20 min), Eco some; a luz da lanterna, do lampião e do farol congela o Tição e a lanterna pisca; `NOM.setBlackFog()` e `NOM.ticao()` com botões | `em teste` (branch `sprint/0038-nevoa-preta`) — [roteiro](sprint-0038-nevoa-preta/README.md#roteiro-de-teste-no-jogo) |
| [0039](sprint-0039-nevoa-preta-ii/README.md) | Névoa preta II: luz fixa congela o Tição (poste, abajur, fogo, cômodo aceso, com a regra de força do jogo); Outro Mundo queimado (cinza, brasa e fuligem, texturas novas do `gen_tiles.py`); no mod3 a luz empurra a névoa preta (o facho sopra na direção da lâmpada, poste e lampião pra todo lado; `NOMRender_setParam(12, 1)`) | `em teste` (na `staging`) — [roteiro](sprint-0039-nevoa-preta-ii/README.md#roteiro-de-teste-no-jogo) |
| [0040](sprint-0040-vermelha-nova/README.md) | Vermelha nova: tentáculos pretos na parede (subindo do rodapé) e no chão (peça solta, fora da grama), texturas novas do `gen_tiles.py`; cinza solta flutuando no ar em volta do jogador | `em teste` (na `staging`) — [roteiro](sprint-0040-vermelha-nova/README.md#roteiro-de-teste-no-jogo) |
| [0041](sprint-0041-facelift-spike/README.md) | Facelift, spike: a venda do Estalador vira peça 3D nossa (faixa com volume, dois arames farpados com farpas, nó atrás), `.x` gerado em Python puro por `scripts/gen_models.py`, um modelo por sexo | `em teste` (na `staging`) — [roteiro](sprint-0041-facelift-spike/README.md#roteiro-de-teste-no-jogo) |
| [0042](sprint-0042-facelift-monstros/README.md) | Facelift, os outros monstros: boca 3D do Corredor (buraco escuro, lábio rasgado, dentes, rasgos até a orelha), casca lisa de chiado do Sem-rosto, cabelo de mechas da Carpideira (três brancas); mesmo gerador da 0041 | `em teste` (na `staging`) — [roteiro](sprint-0042-facelift-monstros/README.md#roteiro-de-teste-no-jogo) |
| [0043](sprint-0043-ticao-ia/README.md) | Tição: crosta de carvão 3D por script (placas com rachaduras de brasa, olhos de brasa, lascas, fumaça) no lugar do véu do Eco; licenças de IA conferidas e [ADR-020](../architecture/adr-020-modelos-3d-por-ia.md) proposta (Hunyuan fora, Stable Fast 3D possível); teste de IA espera o Johan | `em teste` (na `staging`) — [roteiro](sprint-0043-ticao-ia/README.md#roteiro-de-teste-no-jogo) |
| [0044](sprint-0044-rosto-censurado/README.md) | Rosto censurado do Sem-rosto: passe do mod3 com quadrado de TV na cabeça (mosaico da cena, chiado, varredura), escondido pela parede e coberto pela névoa; `NOMRender_setParam(13, s)` | `em teste` (na `staging`) — [roteiro](sprint-0044-rosto-censurado/README.md#roteiro-de-teste-no-jogo) |
| [0045](sprint-0045-luz-e-tempestade/README.md) | Luz que pisca e tempestade: a lanterna gagueja de verdade, postes de fora piscam na preta e na vermelha, relâmpago e trovão a cada 8–30 s na preta e na vermelha (na preta o clarão congela o Tição por 1 s), chuva em 30% delas; `NOM.thunder()`, `NOM.flickerLamp()` e `NOM.rain()` com botões | `em teste` (na `staging`) — [roteiro](sprint-0045-luz-e-tempestade/README.md#roteiro-de-teste-no-jogo) |
| [0046](sprint-0046-painel-debug/README.md) | Painel de debug novo: janela grande e redimensionável, cabeçalho com o estado (hora, noite, névoa, monstros, cheats), seções na lateral, cada ação num cartão com descrição e botões, respostas do debug no rodapé (`shared/NOM_DebugLog.lua`) | `em teste` (na `staging`) — [roteiro](sprint-0046-painel-debug/README.md#roteiro-de-teste-no-jogo) |
| [0047](sprint-0047-fog-climax/README.md) | **FOG clímax (P0):** base baixa tipo gelo seco + bolsões viajantes raros/brutais; pipeline A→C-lite→B'→B; sandbox 2 eixos; fallback sem mod3 | `em teste` (na `staging`) — [roteiro](sprint-0047-fog-climax/README.md#roteiro-de-teste-no-jogo) |
| [0048](https://github.com/WillianJohan/nevoa-e-outro-mundo/pull/4) | Sons II — gritos + Estalador clicker (PR draft; sem merge até escuta) | `em andamento` (branch `sprint/0048-sons-ii`) |
| [0051](sprint-0051-aperto-preta/README.md) | Aperto da névoa preta: sandbox `BlackFogPressure` (Leve/Padrão/Pesadelo), piscar + caça no piscar + hold curto + postes instáveis; só Tição (não vira vermelha escura) | `em andamento` (branch `sprint/0051-aperto-preta`) — [roteiro](sprint-0051-aperto-preta/README.md#roteiro-de-teste-no-jogo) |
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
