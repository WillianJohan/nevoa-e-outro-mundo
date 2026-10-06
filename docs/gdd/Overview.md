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
sirene → névoa (de dia ou de noite, quase todo dia): fugir ou se esconder do Outro Mundo — Estaladores,
Corredores, Sem-rosto, Carpideiras → fim da névoa e calmaria (a folga pra explorar) → amanhecer → repetir.

## Índice de sistemas

| Doc | Assunto | Status |
|-----|---------|--------|
| [world-states.md](world-states.md) | Noite e evento de névoa (sirene) | `accepted` |
| [night.md](night.md) | Noite agressiva (todos os zumbis) | `accepted` |
| [monsters.md](monsters.md) | Estalador, Corredor, Sem-rosto, Carpideira, Eco | `accepted` |
| [atmosphere.md](atmosphere.md) | Clima dark, som, overlays, vinheta, efeitos de tela, shader opcional | `accepted` |
| [sandbox.md](sandbox.md) | Opções de sandbox | `accepted` |
| [art-direction.md](art-direction.md) | Visual dos monstros e da tela na névoa | `accepted` |

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
- **2026-10-05** — **Efeitos de tela** (sprint 0013), depois do teste da névoa no jogo ("LINDA",
  mas falta efeito de tela): opção 3 do Johan. (A) **overlay Lua no mod principal**, só na
  névoa: grão de filme, vinheta que respira (vermelha e mais forte na vermelha), linhas de
  chiado pela distância do Sem-rosto e pulso vermelho no grito da Carpideira; opção de cada
  jogador (Opções > Mods), não do servidor. (B) **shader opcional num segundo mod** do mesmo item
  ("Névoa e Outro Mundo — Shader"): aberração cromática, grão e distorção; incompatível com
  ShadowZ, vale a partir do primeiro mundo da sessão. Sem grão à noite
  ([atmosphere.md](atmosphere.md#efeitos-de-tela-só-na-névoa),
  [art-direction.md](art-direction.md#a-tela-na-névoa-sprint-0013),
  [ADR-013](../architecture/adr-013-efeitos-de-tela.md)).
- **2026-10-05** — **Outro Mundo sangrento** (sprint 0015), pedido do Johan: "o Outro Mundo eu
  imaginei com bastante sangue e com a erosão no máximo". Na névoa, num raio de 25 tiles: poças e
  rastros de sangue, sujeira, rachadura e musgo no chão; sangue, sujeira, rachadura e trepadeira
  nas paredes; mais na vermelha (sprint 0021: só o chão, sem musgo, sujeira em manchas, só onde o
  jogador vê; paredes desligadas). Só na tela de quem vê, nada no save; densidade de cada jogador
  (Opções > Mods), `FogOverlays` continua o liga/desliga do servidor
  ([atmosphere.md](atmosphere.md#outro-mundo-sangrento-só-na-névoa),
  [art-direction.md](art-direction.md#o-outro-mundo-sangrento-sprint-0015),
  [ADR-015](../architecture/adr-015-outro-mundo-sangrento.md)). **Sprint 0023** (05/10, o Johan
  recusou no jogo o buraco limpo debaixo do jogador e confirmou o anexo): o desenho vai **anexado** ao
  chão e às paredes de verdade, como a erosão do jogo — embaixo dos personagens, com a luz e o
  recorte; as paredes voltam (trepadeira, rachadura, sujeira, sangue); chão queimado dentro, mato fora;
  raio de 15 tiles; o mod tira tudo antes de todo save
  ([ADR-017](../architecture/adr-017-outro-mundo-anexado.md)).
- **2026-10-05** — **Monstro sem roupa comum** (sprint 0016), visto no jogo pelo Johan: "os
  zombies quando se transformam devem ficar sem roupa ... tudo que contribui pro monstro
  fica, mas de resto não ... tem monstro que tem coisa na cabeça e fica estranho". Enquanto é
  variante, a roupa vanilla some; ficam a pele, a peça do mod e as feridas do corpo. Volta
  quando a variante acaba, e o corpo e o loot são os do zumbi comum. Exceções de roupa (a
  "saia estranha") numa lista curta, vazia por enquanto. Reverte "a roupa do zumbi fica" da
  sprint 0012. Na mesma data, **"o monstro larga tudo"**: enquanto é variante, a roupa
  escondida não protege (morde através de máscara e capacete, sem armadura nem modificador de
  visão/audição da roupa, o chapéu não cai); tudo volta no fim
  ([art-direction.md](art-direction.md#regra), [monsters.md](monsters.md),
  [ADR-012](../architecture/adr-012-visual-das-variantes.md#emenda-de-2026-10-05--sprint-0016-a-roupa-comum-some-na-variante)).
- **2026-10-05** — **Dissolve e bloom** (sprint 0018), pedido do Johan: o efeito de *dissolve* (ruído
  com borda acesa) quando o Eco morre (antes sumia na hora) e quando o zumbi vira monstro e volta;
  e **bloom**. A peça do monstro se forma e se desfaz queimando em ~1 s; o Eco queima até a cinza
  com brasas e não deixa corpo (casca de cinza: decisão de arte do Johan pendente); bloom no shader
  opcional, mais forte na névoa. Os dois com opção de cada jogador (Opções > Mods). Sem Java: shader
  próprio nas peças pelo `<m_Shader>` do item, sem tocar no vanilla
  ([art-direction.md](art-direction.md#queimar-ao-surgir-e-ao-sumir-sprint-0018),
  [atmosphere.md](atmosphere.md#shader-opcional-mod-névoa-e-outro-mundo--shader),
  [ADR-016](../architecture/adr-016-dissolve-e-bloom.md)).
- **2026-10-05** — **Balanceamento do PO e curva de tensão** (sprint 0019): a análise do PO foi
  aprovada integralmente pelo Johan. Ela muda cinco decisões anteriores dele, cada uma com o
  limiar de volta no [playtest](../teste-in-game.md#balanceamento):
  1. `FogEventEveryDays` 3 → **2** (decisão da sprint 0009). Motivo do PO: com a curva de
     tensão o começo do save continua ~3 dias efetivos; o 2 é o ritmo do save maduro (dia 30).
  2. `FogMinHours` 2 → **3** (sprint 0009). Duração 3–6 h; volta a subir pra 4 se duas névoas
     seguidas terminarem com "já acabou?" (item 8).
  3. `CorredorChance` 2 → **3** (05/10, "chances 5/2/3/5"). Sobe pra 4 se três névoas passarem
     sem perseguição (item 6).
  4. `SemRostoChance` 5 → **3** (mesma decisão). Volta a 2 se o rádio chiar mais de 70% do
     tempo na cidade, a 4 se três névoas passarem sem ver nenhum (item 4).
  5. `CarpideiraScreamRadius` 60 → **50** (sprint 0011). 60 se ninguém conseguir fugir do
     grito, 40 se ele matar em 2 de 3 névoas (item 5).

  Junto: Eco 20 num raio de 30, caça a cada 90 min num raio de 25, 14% de monstros somados, e
  duas opções novas: **`FogEscalation`** (ligada: a névoa começa a cada ~3 dias e chega a ~1,5
  do dia 45; a vermelha sobe do dia 30 até o dobro no dia 90) e **`RedFogGraceDays`** (7:
  nenhuma vermelha na primeira semana). As chances dos monstros e a noite não seguem a curva.
  Presets Leve ("primeira visita"), Padrão ("o mundo tem horário") e Pesadelo ("a cidade é
  proibida") revistos ([sandbox.md](sandbox.md#curva-de-tensão-sprint-0019),
  [ADR-009](../architecture/adr-009-nevoa-evento-do-mod.md), [ADR-010](../architecture/adr-010-nevoa-vermelha.md)).
- **2026-10-06** — **Ritmo novo** (sprint 0033), "mudei um pouco meu mindset": a névoa deixa o jogador
  tenso (enxerga um pouco, nunca sabe o que vem) e o fim dela é um alívio, uma folga pra explorar.
  Por isso ela fica **frequente** e ganha ritmo, no
  [modelo novo](../superpowers/specs/2026-10-06-modelo-novo-design.md):
  1. **Sorteio por dia**, no lugar do intervalo (`FogEventEveryDays` saiu): 65% subindo até 85%
     no dia 60; segunda névoa de 15% depois de 6 h de folga; garantia no terceiro dia sem névoa.
  2. **Duração por tipo:** branca 3–5 h, vermelha 4–6 h. A vermelha é 20% (a partir do dia 7) e
     não sobe mais até o dobro no dia 90 (reverte parte da 0019).
  3. **Sirene de 45 s** (era 30) com **todos os zumbis parados**, virados pra uma direção, e
     voltando juntos quando a névoa começa.
  4. **Calmaria:** 2 h de jogo depois da névoa, com o zumbi comum um degrau mais lento e de
     sentidos reduzidos.

  O resto do modelo (sons, visão de ~4 tiles, Outro Mundo por chunk, sonar, névoa preta e
  facelift) está na spec e entra nas sprints 0034 a 0044. O rosto censurado do Sem-rosto, que era
  a 0033 antiga, virou parte do facelift ([world-states.md](world-states.md),
  [sandbox.md](sandbox.md), [ADR-009](../architecture/adr-009-nevoa-evento-do-mod.md#emenda-de-2026-10-06--sprint-0033-ritmo-novo)).
