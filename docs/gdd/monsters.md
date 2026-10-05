# Monstros

| Campo | Valor |
|-------|-------|
| Status | `accepted` |
| Sprints | 0002 (Eco), 0004 (Estalador, Corredor), 0005 (Sem-rosto), 0008 (só na névoa, Eco do morto antigo) |

## Regra geral

Monstro = zumbi com outfit/textura própria e comportamento via Lua. Sem modelo
3D novo, sem animação nova.

**Todo monstro, menos o Eco, só existe na névoa** (decisão do Johan, 05/10/2026):
Estalador, Corredor e Sem-rosto aparecem com a névoa forte, de dia ou de noite, e
somem com ela. A noite fica com a agressividade dos zumbis comuns
([night.md](night.md)) e o Eco.

Estalador, Corredor e Sem-rosto são **zumbis existentes**
([ADR-001](../architecture/adr-001-variantes-por-moddata.md)). O Eco é a única
exceção: ele é **spawnado** ([ADR-003](../architecture/adr-003-eco-spawnado.md)).

Cada zumbi é sorteado **uma vez por névoa**, e o sorteio é uma conta, não uma
marca: a variante sai do ID do outfit do zumbi e do número do período de névoa
([ADR-006](../architecture/adr-006-variantes-deterministicas.md)). O mesmo zumbi
é a mesma coisa a névoa toda, inclusive depois de sair e voltar pro chunk ou de
salvar e recarregar; na névoa seguinte é outro sorteio. Zumbis de chunks
carregados depois também entram. Ecos nunca são variantes.

**Um sorteio só pra todas:** cada zumbi tira um número de 0 a 99, e as chances
viram faixas seguidas — Estalador `[0, 5)`, Corredor `[5, 7)`, Sem-rosto `[7, 12)`
com o padrão. Ninguém é duas coisas, e o total é a soma (12% com o padrão).
Desligar um tipo deixa a faixa dele vazia, sem mexer nas outras. Variante nova entra
no fim da lista (a Carpideira, sprint 0010).

Numa noite com névoa a variante vai por cima dos stats da noite (o Estalador corre
como os outros da noite e continua cego); de dia, por cima dos stats do jogo.

As variantes não têm roupa própria (trocar o outfit trocaria o ID e, com ele, o
sorteio): quem avisa é o som.

## Estalador

| Quando | Origem | Sandbox |
|---|---|---|
| névoa | sorteado | `EstaladorEnabled`, `EstaladorChance` % (5) |

- Cego: ignora visão, reage só a som. Agachado e em silêncio, o jogador passa.
  Em pé, correndo ou batendo nele, ele acha o jogador. Enquanto "não vê" um
  jogador agachado do lado, fica surdo por instantes (limite do jogo, ver a
  [sprint 0004](../sprints/sprint-0004-estalador-corredor/README.md#pendências-que-a-próxima-sprint-herda)). Ouvido apurado (o melhor
  do jogo), visão a pior; a velocidade é a do jogo de dia e a da noite à noite.
- Agarrão letal rápido: **pendente** — o jogo não tem dano por zumbi nem evento
  no golpe do zumbi (ver Pendências da [sprint 0004](../sprints/sprint-0004-estalador-corredor/README.md)).
- Estalo audível, em média a cada 2 minutos de jogo, que serve de aviso.
- Quando a névoa baixa, volta a ser zumbi comum.

## Corredor

| Quando | Origem | Sandbox |
|---|---|---|
| névoa | sorteado | `CorredorEnabled`, `CorredorChance` % (2), `CorredorScreamRadius` (40 tiles) |

- Sem névoa é zumbi comum; na névoa é sprinter (mesmo com `NightFaster` desligado).
  Exceção aceita: com "Ativos só à noite" (`ZombieLore.ActiveOnly`), na névoa de dia
  (a fase inativa do jogo) ele fica arrastado como todos — a regra vanilla vence.
- Ao ver o jogador, grita e atrai os zumbis num raio. É ele que começa a horda.
  No máximo um grito por Corredor a cada meia hora de jogo, de dia ou de noite.
- Quando a névoa baixa, volta a ser zumbi comum.

## Sem-rosto

| Quando | Origem | Sandbox |
|---|---|---|
| névoa | sorteado | `SemRostoEnabled`, `SemRostoChance` % (5) |

- Só existe com névoa forte (névoa ≥ `FogThreshold`). Sorteado uma vez por
  **névoa**, no mesmo sorteio do Estalador e do Corredor (faixa própria): um
  Sem-rosto nunca é Estalador nem Corredor.
- Quando entra no campo de visão do jogador ou é iluminado (o jogo só "vê" no
  escuro o que está iluminado), some e reaparece 3 tiles mais perto (nunca a menos
  de 3), atrás do jogador, em chão (não na água) e fora da linha de visão de todos
  os jogadores daquela tela. Depois de sumir, só some de novo 4 segundos depois
  (não pisca). Sem lugar livre e escondido atrás do jogador, fica onde está até haver.
- **Colado, ataca:** a 2 tiles ou menos de quem o vê, ele para de sumir e ataca
  como zumbi comum (`ATTACK_DIST`, decisão de 04/10/2026). Senão ficaria piscando
  atrás de quem o encara e nunca seria ameaça. Quem foge de costas é alcançado.
- No MP, quem o viu também não o vê deslizar: a cópia dele vai direto pro ponto
  novo. Um terceiro jogador olhando pode vê-lo deslizar até lá
  ([ADR-007](../architecture/adr-007-sem-rosto-e-atmosfera-local.md)).
- O rádio chia "na cabeça" do jogador, mais forte quanto mais perto (no máximo a 3
  tiles, mudo a partir de 30). Não exige rádio no inventário.
- Quando a névoa baixa, volta a ser zumbi comum: aquele zumbi qualquer *era* a coisa.
  Ele não tem stats próprios, então não há nada a desfazer.
- Ecos nunca são Sem-rosto.

## Eco

| Quando | Origem | Sandbox |
|---|---|---|
| noite | spawnado de corpo | `EcoMaxPerPlayer` (30), `EcoRadius` (40) |

A alma de um morto. Fraco sozinho; perigoso onde há muitos corpos.

- Durante a noite, todo `IsoDeadBody` a até `EcoRadius` tiles de um jogador gera
  um Eco, respeitando o teto por jogador. A checagem é periódica, não só no
  início da noite: quem anda até um cemitério às 2h também é pego.
- **Só de quem morreu antes do anoitecer atual** (decisão do Johan, 05/10/2026: "se
  eu matar o zombie e logo em seguida ele nascer, é ruim"). Quem morre durante a
  noite espera o próximo entardecer. A hora da morte é a do próprio corpo no jogo
  (salva com ele, e mantida quando o corpo é pego no colo e largado). Corpo de cenário
  (casas, acidentes) nasce quando o chunk é gerado: uma área explorada pela primeira
  vez de noite só solta Ecos na noite seguinte.
- **Cada corpo gera Eco uma única vez na vida.** O cadáver continua no chão.
- **Corpo queimado ou enterrado não gera Eco**, porque deixa de existir como
  `IsoDeadBody`. Nenhuma regra extra.
- Vida baixa, lento, dano baixo. Textura fantasmagórica própria.
- Ao morrer: **sem cadáver e sem loot**.
- Ao amanhecer: **todos os Ecos somem**, onde quer que estejam.

Sem cadáver: o corpo do Eco é removido pelo servidor logo depois que nasce
(técnica na [ADR-003](../architecture/adr-003-eco-spawnado.md)). Validação em MP
no roteiro da [sprint 0002](../sprints/sprint-0002-eco/README.md#roteiro-in-game).

Visual atual (placeholder): camisola de hospital e véu de noiva vanilla, outfit
`NOM_Eco`. Vida baixa e lento (arrastado, sem o bônus da noite) desde a sprint
0003. Dano baixo não existe por zumbi no jogo e não será feito ([night.md](night.md#sem-força-e-sem-dano-à-noite)).

## Sobreposição

Noite + névoa ao mesmo tempo: valem todas as regras juntas.
