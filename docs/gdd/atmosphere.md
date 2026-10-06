# Atmosfera

| Campo | Valor |
|-------|-------|
| Status | `accepted` |
| Sprints | 0001 (clima), 0005 (som de névoa, overlays, vinheta), 0008 (noite pela luz global), 0009 (névoa como evento, sirene), 0010 (névoa vermelha), 0013 (efeitos de tela, shader opcional), 0015 (Outro Mundo sangrento), 0023 (anexado ao chão e às paredes), 0034 (coro de sirenes, estática na tela, aparelhos, casa destruída, sem sangue no chão) |

Som, overlays e vinheta rodam no **cliente**: é o que se ouve e o que cada
jogador vê sozinho. Nada disso vai pra rede nem pro save
([ADR-007](../architecture/adr-007-sem-rosto-e-atmosfera-local.md)). O clima é a exceção: roda no **servidor** e chega aos clientes pela
sincronização de clima do próprio jogo.

## Clima

Camada modded do `ClimateManager` via Lua
([ADR-004](../architecture/adr-004-clima-antes-de-shader.md)), escrita no
servidor a cada minuto de jogo (`OnClimateTick`). No solo o servidor roda no
mesmo processo; em MP o cliente não escreve no clima, só recebe.

- **Noite: claramente mais escura e mais fria que a vanilla.** A cor da luz global
  vai pra quase preto, puxado pro azul, com força alta: contra a noite vanilla (com
  ou sem lua) a luz do céu cai ~46% no vermelho e ~40% no azul com `DarkIntensity` 1,
  e 73–89% com 2. Lanterna, poste e luz de casa não
  mudam: de noite, luz vira o que separa ver de não ver.
- **Névoa: do mod, não do clima** ([ADR-009](../architecture/adr-009-nevoa-evento-do-mod.md)).
  O canal de névoa do clima é 0 fora do evento e denso (0.85) durante, com entrada e
  saída de ~20 minutos de jogo. Desde a sprint 0034 a entrada começa já na sirene: nos 30 s reais
  da fuga (~12 minutos de jogo) a névoa chega a uns 60% e completa logo depois que o evento abre.
  Sirene cancelada, a rampa desce. Vale com o clima sombrio desligado: a névoa é o evento.
  Por cima, o look: dessaturação forte (de dia), tint sépia bem escuro, luz ambiente menor. Contra a luz de névoa vanilla (que também escurece)
  a luz do céu cai mais 29–46% com `DarkIntensity` 1, o azul mais (sépia).
- **Névoa vermelha** ([ADR-010](../architecture/adr-010-nevoa-vermelha.md)): a névoa
  em si fica vermelha escura (a cor que o jogo usa pra desenhar a névoa), com a mesma
  rampa de ~20 minutos, e isso vale com o clima sombrio desligado (é o evento): **com
  `DarkEnabled` desligado, só a cor da névoa fica vermelha**, a luz não. Por
  cima, com o clima sombrio ligado, a luz vai pra um vermelho escuro: contra as três
  luzes de névoa vanilla a luz do céu cai 17–32% no vermelho e ~50% no verde e no
  azul com `DarkIntensity` 1; com a noite junto, ≥ 30% em todo canal. A dessaturação
  vai pra baixo (a da névoa normal lavaria o vermelho). Com `DarkIntensity` 0.5 a luz
  ainda escurece, por menos (≥ 5%). Na tempestade com névoa o jogo pinta a névoa de
  marrom: na vermelha, o mod passa por cima, saindo do marrom em rampa. Quando acaba, a
  cor volta à branca vanilla. A vinheta **não** fica vermelha: o efeito de tela do
  jogo não tem cor (só desfoque, dessaturação, raio e escurecimento).
- Por que esses canais ([ADR-008](../architecture/adr-008-noite-pela-luz-global.md)):
  o jogo só escurece o céu pela cor e pela força da luz global; a "intensidade" da luz
  não é lida, a dessaturação some de noite (o render multiplica pelo dia), e de
  madrugada a luz ambiente já é zero.
- **O sandbox vanilla "Escuridão à noite" continua valendo** e soma depois do clima:
  "Muito escuro" deixa o céu apagado, "Claro" põe um piso de 25%. A noite do mod
  escurece por cima de qualquer um deles (multiplica), mas não tira o piso.
- Transição de ~20 minutos de jogo (um passo por minuto). No MP chega aos
  clientes a cada 10 minutos de jogo com fade de ~5 s, mesma cadência do
  anoitecer vanilla.
- Intensidade configurável no sandbox.
- A névoa do mod também encurta a visão dos zumbis (o jogo calcula a distância
  de visão pelo valor final da névoa). É intencional: ninguém enxerga na névoa,
  nem eles.
- Névoa do painel de clima do admin passa por cima da nossa camada e não abre evento.
- Resíduo aceito: num dia em que a vanilla teria névoa natural, o jogo ainda puxa a luz
  pro cinza e dessatura um pouco (calcula isso antes da camada do mod), sem névoa
  nenhuma. É o mesmo da opção vanilla "Sem névoa".

## Som

- **Sirenes** (evento de névoa, sprint 0034): um **coro de 5 sirenes ao longe**, no jogo de cada
  jogador, sorteadas em volta dele a 150–500 tiles, de lados diferentes e desencontradas em até 4 s.
  Cada uma fica parada no mundo enquanto o jogador anda, toca um som diferente da lista da névoa e
  tem afinação própria (0,95 a 1,05), pra duas do coro nunca soarem como o mesmo aparelho. Cada som
  dura 11,8 s, com o eco de uma cidade vazia embutido no arquivo. A sirene abre a **fuga**: 30 s
  reais até os bichos ([world-states.md](world-states.md)). Sem toggle: é o aviso do evento.
  - **Brancas** (9): sirenes de defesa civil, de rotor no poste, de rádio de emergência e de fita
    velha, abafadas pela névoa.
  - **Vermelhas** (9): sinal de ataque com o rotor rosnando, uivos quase orgânicos pelo megafone,
    estática agressiva. Tocam no lugar das brancas: quem ouve sabe o que vem. Nos primeiros
    `RedFogGraceDays` (7) dias do save não há vermelha (sprint 0019): o jogador aprende a branca antes.
  - **Pretas** (13): apagões, disjuntores e sirenes graves morrendo. Já geradas; só tocam na névoa
    preta (sprint 0038).
- **Aparelhos do Outro Mundo** (sprint 0034, com `FogAmbience`): TV, rádio, caixa de som e rádio de
  carro, ligados ou não, "tentam falar". O ligado tem prioridade e fala mais alto.
  - No presságio (3 s antes da sirene), todo aparelho a até 25 tiles dá um estouro curto de estática,
    cortado pela sirene. Na fuga, silêncio.
  - Na névoa aberta, a cada 90 a 180 s reais o aparelho mais perto entre 6 e 18 tiles toca um evento
    (TV fora do ar, rádio varrendo estações mortas, caixa de som de poste, rádio de carro ligando
    sozinho; versões vermelhas da TV e do rádio). Nunca dois juntos pro mesmo jogador; para se ele
    passa de 20 tiles.
  - O Sem-rosto a até 10 tiles de um aparelho o faz chiar; na vermelha, o grito da Carpideira faz o
    aparelho perto respirar.
  - Só no jogo de quem ouve: não chama zumbi e não mexe no aparelho.
- Névoa (`FogAmbience`): um drone grave em loop entra em ~8 s e sai em ~8 s com
  a névoa; ruídos metálicos distantes de vez em quando (a cada 20–60 s). Desde a sprint 0034 ele
  já entra na sirene, com a névoa subindo.
- Rádio chiando por proximidade do Sem-rosto (`SemRostoEnabled`): loop de estática
  com volume pela distância do Sem-rosto mais perto; para quando a névoa baixa.
- Estalo do Estalador, grito do Corredor.
- Sons originais, gerados por `scripts/gen_sounds.py` ([CREDITS.md](../../CREDITS.md)).

## Outro Mundo sangrento (só na névoa)

Sprint 0015, pedido do Johan: "o Outro Mundo eu imaginei com bastante sangue e com a erosão no
máximo". Substitui as manchas esparsas da sprint 0005
([ADR-015](../architecture/adr-015-outro-mundo-sangrento.md); como, desde a sprint 0023:
[ADR-017](../architecture/adr-017-outro-mundo-anexado.md)).

- **Chão, num raio de 15 a 30 tiles (segue a tela):** rachaduras e sujeira em manchas, mais leve.
  Dentro de casa, **chão queimado** em manchas (casa destruída: o miolo todo queimado, a borda só
  marcada); fora, **mato e folha** rasteiros. **Sem sangue no chão** (sprint 0034: as poças e
  rastros pareciam "jogo dos anos 2000 com textura ruim", decisão do Johan); o sangue fica nas
  paredes. Na densidade 1, ~66% dos squares mudam (~83% na névoa vermelha).
- **Paredes** (de volta na sprint 0023): sangue escorrido, sujeira e rachadura; trepadeira nas
  paredes de fora.
- **Casa destruída** (sprint 0034, pedido do Johan: "apagadas, acabadas, sujas, pichadas"): a parede
  de dentro ganha quase sempre uma camada e pode empilhar até 3 de tipos diferentes (rachadura,
  sujeira, sangue e, por cima, escrita). Pichações e mensagens vanilla ("KEEP OUT", "ALIVE INSIDE"
  e outras) aparecem **inteiras**, espalhadas pelas paredes seguidas que o desenho ocupa: mensagem
  mais comum dentro de casa, pichação mais comum fora. A parede de fora continua com uma camada.
- **Colado no mundo** (sprint 0023): o desenho vai preso ao chão e à parede de verdade, como a
  erosão do jogo. Fica embaixo dos personagens, pega a luz do lugar (a lanterna clareia, o breu
  esconde), some com a parede quando o jogo a corta e com o telhado quando o jogador está fora. Sem
  buraco debaixo do jogador.
- **Névoa vermelha = o máximo:** 1,6× a densidade.
- **Fixo por lugar:** o mesmo square tem o mesmo desenho a névoa inteira (e se o jogador voltar);
  outra névoa, outro desenho. Nada pisca enquanto se anda.
- Enche em ~1,5 s quando a névoa chega, do mais perto pro mais longe, acompanha o jogador andando e
  some do mesmo jeito quando ela baixa. Na morte, no salto e no save some na hora (e volta logo
  depois do save).
- **Densidade do jogador:** Opções > Mods > "Névoa e Outro Mundo" > "Sangue e erosão na névoa"
  (1.0, 0–2; 0 desliga). `FogOverlays` no sandbox é o liga/desliga do servidor.
- **Locais e só visuais**, sem sincronizar: cada jogador vê o próprio pesadelo (em MP, cada um
  num lugar diferente). **Nada fica no save:** o mod tira tudo antes de o jogo gravar
  ([ADR-017](../architecture/adr-017-outro-mundo-anexado.md); o único furo é o jogo cair logo
  depois de gravar um pedaço do mapa em segundo plano).
- Enquanto o jogador faz uma ação num lugar (cavar, marretar, pegar um móvel), aquele square fica
  limpo; volta quando a ação acaba.
- Sprites vanilla por nome: `overlay_grime_floor_01_*`, `d_streetcracks_1_*`, `floors_burnt_01_*`, `d_plants_1_*`, `d_floorleaves_1_*`; nas paredes
  `overlay_blood_wall_01_*`, `overlay_grime_wall_01_*`, `d_wallcracks_1_*`, `f_wallvines_1_*`,
  `overlay_graffiti_wall_01_*`, `overlay_messages_wall_01_*`
  ([pz-api-notes §16](../architecture/pz-api-notes.md#16-outro-mundo-sangrento-sprint-0015)).
- **Próximo visual** (decisão do Johan, 06/10/2026): o Outro Mundo fica mais **Silent Hill** (tinta
  descascando, ferrugem, grade metálica, lascas subindo) na sprint 0035
  ([spec](../superpowers/specs/2026-10-06-modelo-novo-design.md#7-outro-mundo)).
- Limites: só o andar do jogador; montado pro jogador 0 na tela dividida.

## Vinheta (só na névoa)

> Vinheta, sangue e erosão, drone e rádio **só aparecem no evento de névoa**,
> nunca só de noite. Pra ver sem esperar: `NOM.setFog(true)` no console
> (névoa na hora) ou `NOM.setFog()` (presságio, sirene e névoa 30 s depois).
> Vermelha: `NOM.setRedFog(true)`. A vinheta e o drone já sobem durante a fuga.

- `FogVignette`, `FogVignetteIntensity` (1.0, 0–2): as bordas da tela escurecem,
  desfocam e perdem cor, com fade. É o efeito de tela do modo de busca do jogo,
  ligado sem ligar o forrageamento.
- Se o jogador forragear na névoa, a vinheta sai da frente e o forrageamento usa a
  dele; volta quando ele para.

## Efeitos de tela (só na névoa)

Sprint 0013, pedido do Johan depois de ver a névoa no jogo: um efeito de tela de verdade.
Desenhado por cima do mundo e por baixo do HUD, sem pegar clique
([ADR-013](../architecture/adr-013-efeitos-de-tela.md)). Entra e sai com a névoa em ~4 s.

- **Grão de filme** animado (quadros de ruído trocando ~16 vezes por segundo).
- **Vinheta que respira:** as bordas escurecem e clareiam devagar (~7 s por respiração).
- **Névoa vermelha:** a vinheta fica vermelha escura e mais forte (~45%), e o grão um pouco mais.
- **Linhas de chiado** horizontais, pulando de lugar, mais fortes quanto mais perto o Sem-rosto
  mais próximo: a mesma distância do rádio (a partir de 30 tiles, cheio a 3).
- **Pulso vermelho** quando uma Carpideira grita perto: cheio a até 6 tiles, nada a partir de 30,
  some em menos de 1 s.
- **Estática da névoa** (sprint 0034): chiado em mosaico, na cor da névoa (branca ou vermelha). É a
  única camada que aparece **antes** da névoa: começa 3 s antes da sirene (o presságio), fraca no
  começo e forte no fim; depois da sirene desce em ~4 s até um nível sutil, que fica a fuga e a névoa
  inteiras; no fim some em ~3 s. Segue a mesma opção e intensidade dos outros efeitos de tela.
- **Opção do jogador, não do servidor:** Opções > Mods > "Névoa e Outro Mundo": liga/desliga e
  intensidade (1.0, 0–2). Cada um ajusta a própria tela.
- **Fora da névoa, nada**, nem à noite, a não ser a estática do presságio e da fuga: a noite é
  escuridão; o filme granulado é a assinatura do Outro Mundo (decisão da sprint 0013, ADR-013).
- Só o primeiro jogador na tela dividida; some com o menu aberto e morto.
- É desenhado pela UI: esconder a UI (tecla do HUD) esconde o efeito, e ele anda no ritmo de
  quadros da UI do jogo.

## Shader opcional (mod "Névoa e Outro Mundo — Shader")

| Status | `accepted` — sprint 0013 (o ShadowZ instalado aqui prova que o override do `screen.frag` pega; [spike](../sprints/spike-shader/README.md)) |
|---|---|

- Segundo mod no mesmo item do Workshop, **desligado por padrão**: troca o shader de tela do jogo
  por um próprio, que soma aberração cromática, grão de verdade (o do overlay sai), distorção
  (onda lenta na névoa, faixas que escorregam com o Sem-rosto perto) e bordas desfocadas e sem
  cor; na vermelha, bordas puxando pro vermelho; no grito, a aberração dá um salto.
- **Incompatível com ShadowZ** e com qualquer mod que troque o `screen.frag`: só um vale.
- O jogo compila o shader **uma vez por sessão**, no primeiro mundo carregado: ligou ou
  desligou o mod, reinicie o jogo.
- **MP:** é a lista de mods do servidor que decide (vale pra todo mundo); cada jogador só escolhe a
  intensidade e o liga/desliga nas Opções > Mods. A vinheta do sandbox (`FogVignette`,
  `FogVignetteIntensity`) também liga e escala os efeitos do shader.
- Fora da névoa a tela fica como a vanilla nas cores e no tom; os desfoques do jogo (óculos de grau,
  bêbado, círculo de busca) são refeitos com outro padrão de amostras e podem sair um pouco
  diferentes.
- Com ele, a vinheta do modo de busca na névoa (acima) sai: as bordas desfocadas são do shader.
  Forragear continua igual.
- **Bloom (sprint 0018):** luz forte (poste, farol, fogo, a borda em brasa dos monstros) ganha um
  brilho que vaza em volta, também fora da névoa; na névoa o brilho é mais forte e começa em luz
  mais fraca (a névoa espalha a luz), e na vermelha puxa pro vermelho. É curto (uma passada só) e
  custa no 4K. Intensidade do jogador nas Opções > Mods ("Bloom", 1.0, 0–2; 0 desliga)
  ([ADR-016](../architecture/adr-016-dissolve-e-bloom.md)).

O jogo trata a névoa do mod como névoa de verdade em todo lugar que lê `getFogIntensity()`: visão dos zumbis, do jogador, combate e o parâmetro de áudio de névoa. É intencional.
