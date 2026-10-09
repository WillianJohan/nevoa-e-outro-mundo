# Monstros

| Campo | Valor |
|-------|-------|
| Status | `accepted` |
| Sprints | 0002 (Eco), 0004 (Estalador, Corredor), 0005 (Sem-rosto), 0008 (só na névoa, Eco do morto antigo), 0009 (névoa é evento), 0010 (névoa vermelha), 0011 (Carpideira), 0012 (visual), 0017 (Sem-rosto espalhado, chapéu caído não muda a variante), 0037 (sonar do Estalador) |

## Regra geral

Monstro = zumbi com outfit/textura própria e comportamento via Lua. Sem modelo
3D novo, sem animação nova.

**Todo monstro, menos o Eco, só existe na névoa** (decisão do Johan, 05/10/2026):
Estalador, Corredor, Sem-rosto e Carpideira aparecem com a névoa, de dia ou de
noite, e somem com ela. A névoa é um evento do mod, sorteada quase todo dia (65% subindo até 85% no dia 60, sprint 0033), anunciado pelo coro de sirenes ao longe
([world-states.md](world-states.md)). A noite fica com a agressividade dos zumbis comuns
([night.md](night.md)) e o Eco.

**Mutação queima (sprint 0018):** a peça do monstro se forma queimando quando o zumbi vira
variante e se desfaz queimando quando ele volta a ser comum
([art-direction.md](art-direction.md#queimar-ao-surgir-e-ao-sumir-sprint-0018)).

Estalador, Corredor, Sem-rosto e Carpideira são **zumbis existentes**
([ADR-001](../architecture/adr-001-variantes-por-moddata.md)). O Eco é a única
exceção: ele é **spawnado** ([ADR-003](../architecture/adr-003-eco-spawnado.md)).

Cada zumbi é sorteado **uma vez por névoa**, e o sorteio é uma conta, não uma
marca: a variante sai do ID do outfit do zumbi e do número do período de névoa
([ADR-006](../architecture/adr-006-variantes-deterministicas.md)). O mesmo zumbi
é a mesma coisa a névoa toda, inclusive depois de sair e voltar pro chunk ou de
salvar e recarregar; na névoa seguinte é outro sorteio. Zumbis de chunks
carregados depois também entram. Ecos nunca são variantes.

**Um sorteio só pra todas (sprint 0049 — transform 100%):** na névoa **branca**,
todo zumbi com outfit vira monstro. As chances do sandbox são **pesos relativos**
renormalizados pra 100% (padrão 5:3:3:3 → ~35,7% Estalador / ~21,4% Corredor /
~21,4% Sem-rosto / ~21,4% Carpideira). O chapéu que cai não muda o sorteio
(sprint 0017). Ninguém é duas coisas. Desligar um tipo deixa a faixa dele vazia
(vira comum), sem mexer nas outras. Variante nova entra no fim da lista (a
Carpideira entrou assim na sprint 0011).

**Identidade por cor (sprint 0049):** branca = cotidiano (perambular; Estalador
pode entrar na onda); vermelha = agitação (sem perambular; grito do Corredor mais
frequente; Estalador rápido); preta = só Tição (inalterado).

**Névoa vermelha** (sprint 0010, [ADR-010](../architecture/adr-010-nevoa-vermelha.md)):
`RedFogChance`% das névoas (10 por padrão) vêm vermelhas, com sirene própria; nenhuma nos primeiros `RedFogGraceDays` (7) dias do save, e com `FogEscalation` a chance sobe do dia 30 até o dobro no dia 90 (sprint 0019, [sandbox.md](sandbox.md#curva-de-tensão-sprint-0019)). Nelas
**todo zumbi é monstro**: o tipo sai de um segundo sorteio do mesmo ID e período,
dividido por igual entre os tipos (1/4 cada desde a sprint 0011). Cada um com o
comportamento de sempre. Um tipo desligado no sandbox deixa a fatia dele como
zumbi comum (não redistribui). O Eco continua Eco. Se a névoa é vermelha é sorteado
pelo número do período e por uma semente do mundo (cada save tem a sua agenda):
salvar e carregar no meio não muda nada.

Numa noite com névoa a variante vai por cima dos stats da noite (o Estalador corre
como os outros da noite e continua cego); de dia, por cima dos stats do jogo.

**Visual** (sprint 0012, [art-direction.md](art-direction.md)): enquanto a névoa dura, cada
variante ganha pele e uma peça no rosto, e a roupa que o zumbi tinha some (sprint 0016:
ficam só a pele, a peça e as feridas do corpo); quando a névoa baixa, volta a ser o zumbi de
antes, com a roupa, e morto deixa o loot de um zumbi comum. **O monstro larga tudo**
(Johan, 05/10/2026): enquanto é variante, a roupa não protege nada; ele morde através de
máscara e capacete, não tem armadura de roupa nem o que ela mudava na visão e na audição, e o
chapéu não cai. Tudo volta quando a variante acaba. O outfit não muda (trocar o outfit trocaria o ID e,
com ele, o sorteio). O visual é de cada tela: no MP, cada jogador vê o mesmo, porque cada um
calcula o mesmo sorteio. O som continua avisando (estalo, grito, rádio, soluço).

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
- Estalo audível que serve de aviso: cada Estalador estala num intervalo aleatório de 5 a
  30 segundos reais, sorteado a cada estalo (não estalam juntos; o tamanho do dia não muda o
  ritmo; a pausa não conta).
- **Sonar** (sprint 0037): cada estalo solta um anel que corre 8 tiles em 1,5 s. Se o anel
  passa por um jogador no mesmo andar **em pé ou andando**, o Estalador o acha, mesmo cego, e
  não volta a ser cegado por 10 s de jogo (a pausa não conta): dá tempo de ele chegar.
  **Agachado e parado**, o anel passa. Agachado andando não basta. **Casa protege**: com um
  dentro de casa e o outro na rua (ou em casas diferentes), o anel não acha; na mesma casa,
  acha. Quem decide é o servidor; o anel aparece na névoa fluida (mod Volumétrica) como uma
  onda que empurra a névoa pra fora e para nas paredes, ou, sem ela, como um anel discreto no
  chão, na cor da névoa. Estalo e anel são os mesmos pra todos no MP, e só chegam a quem está
  a até 40 tiles.
- Visual: olhos tapados por atadura manchada e arame enferrujado, pele de porcelana rachada.
- Quando a névoa baixa, volta a ser zumbi comum.

## Corredor

| Quando | Origem | Sandbox |
|---|---|---|
| névoa | sorteado | `CorredorEnabled`, `CorredorChance` % (3), `CorredorScreamRadius` (40 tiles) |

- Sem névoa é zumbi comum; na névoa é sprinter (mesmo com `NightFaster` desligado).
  Exceção aceita: com "Ativos só à noite" (`ZombieLore.ActiveOnly`), na névoa de dia
  (a fase inativa do jogo) ele fica arrastado como todos — a regra vanilla vence.
- Ao ver o jogador, grita e atrai os zumbis num raio. É ele que começa a horda.
  No máximo um grito por Corredor a cada meia hora de jogo, de dia ou de noite.
- Visual: boca rasgada larga demais, pele cinza esticada com veias escuras.
- Quando a névoa baixa, volta a ser zumbi comum.

## Sem-rosto

| Quando | Origem | Sandbox |
|---|---|---|
| névoa | sorteado | `SemRostoEnabled`, `SemRostoChance` % (3) |

- Só existe no evento de névoa. Sorteado uma vez por
  **névoa**, no mesmo sorteio do Estalador e do Corredor (faixa própria): um
  Sem-rosto nunca é Estalador nem Corredor.
- Quando entra no campo de visão do jogador ou é iluminado (o jogo só "vê" no
  escuro o que está iluminado), some e reaparece 3 tiles mais perto (nunca a menos
  de 3), atrás do jogador, em chão (não na água) e fora da linha de visão de todos
  os jogadores daquela tela. Depois de sumir, só some de novo 4 segundos depois
  (não pisca). Sem lugar livre e escondido atrás do jogador, fica onde está até haver.
  Um grupo visto junto se **espalha**: cada um reaparece num tile diferente (o tile de
  um sumiço fica reservado por 5 s, sprint 0017).
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
- Visual: a cabeça inteira é chiado de TV cinza, o mesmo chiado do rádio.
- Ecos nunca são Sem-rosto.

## Carpideira

| Quando | Origem | Sandbox |
|---|---|---|
| névoa | sorteado | `CarpideiraEnabled`, `CarpideiraChance` % (3), `CarpideiraTriggerRadius` (4 tiles), `CarpideiraScreamRadius` (50 tiles) |

Pedido do Johan (05/10/2026): um monstro que grita muito alto, na linha da Witch do
L4D ou do grito que chama a horda no Back 4 Blood. **Inspirado, não copiado:** o nome é
o das mulheres pagas pra chorar em velório.

- **Calma (piloto Witch, sprint 0052):** soluça baixinho (ouvido a ~12 tiles; volume sobe
  perto) e, de tempos em tempos, **anda chorando** 2–6 tiles sem ir na direção do jogador;
  entre caminhadas fica parada (`useless`). Não persegue nem vai atrás de som até o grito.
- **Acorda** com qualquer um destes, do jogador:
  - chegar a `CarpideiraTriggerRadius` tiles (4), **mesmo agachado** (é aí que ela
    difere do Estalador: não adianta passar de fininho do lado);
  - lanterna acesa apontada pra ela a até 10 tiles (ela na frente do jogador e
    iluminada; aproximação: luz de outra fonte com a lanterna acesa na mão também conta);
  - barulho alto perto: um som do jogador com alcance de 30 tiles ou mais (tiro), nascido
    a até 10 tiles dela. Tarefas barulhentas comuns (raio até 20) não acordam.
- **Grito:** ensurdecedor, ouvido de longe, e chama todo zumbi a `CarpideiraScreamRadius`
  tiles (50) até ela. Depois ela vira corredora e caça **quem a acordou**.
- **Um grito por névoa por Carpideira**, valendo no MP: o servidor decide e guarda (salvar
  e carregar no meio da névoa não deixa gritar de novo). Na névoa seguinte, se o sorteio
  a fizer Carpideira de novo, ela recomeça calma.
- Zumbis com o mesmo ID de outfit são a mesma variante (ADR-006): quando uma grita, as
  outras com o mesmo ID (raras) ficam furiosas também, sem gritar.
- Quando a névoa baixa, volta a ser zumbi comum (e anda de novo).
- Visual: cabelo preto embolado em mechas 3D, **manto penitente** escuro no corpo (0052),
  pele pálida com escorridos de fuligem ([art-direction.md](art-direction.md)); o soluço
  continua sendo o aviso de longe. Técnica: [ADR-011](../architecture/adr-011-carpideira.md),
  [ADR-012](../architecture/adr-012-visual-das-variantes.md).

## Almas esqueléticas (névoa)

| Quando | Origem | Sandbox |
|---|---|---|
| névoa branca, vermelha ou preta (ciclo) | spawn na rua perto do jogador | `AlmaEnabled` (ligado) |

Presença constante na névoa (sprint 0055): **4–20** vivos, **~68% crawler**, seek lento, TTL curto, só rua. Não substituem as variantes. Debug: `NOM.alma()` / painel (pop, crawler, cores).

## Eco

| Quando | Origem | Sandbox |
|---|---|---|
| noite | spawnado de corpo | `EcoMaxPerPlayer` (20), `EcoRadius` (30) |

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

Visual (sprint 0012): cinza e fumaça no corpo todo e um véu de fumaça, itens do mod no
outfit `NOM_Eco` ([art-direction.md](art-direction.md)). **Morte (sprint 0018):** o Eco queima
até a cinza durante a queda, com brasas subindo, e o corpo não aparece
([art-direction.md](art-direction.md#queimar-ao-surgir-e-ao-sumir-sprint-0018)); no MP o cliente
não tem a queda (o corpo chega pronto), então só as brasas. Vida baixa e lento (arrastado, sem o bônus da noite) desde a sprint
0003. Dano baixo não existe por zumbi no jogo e não será feito ([night.md](night.md#sem-força-e-sem-dano-à-noite)).

## Sobreposição

Noite + névoa ao mesmo tempo: valem todas as regras juntas.
