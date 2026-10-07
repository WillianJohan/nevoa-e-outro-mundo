# Sprint 0037 — Sonar do Estalador

| Campo | Valor |
|-------|-------|
| Status | em teste (branch `sprint/0037-sonar-estalador`, sem merge) |
| Branch | `sprint/0037-sonar-estalador` |
| Plano | [plan.md](plan.md) |
| Spec | [modelo novo](../../superpowers/specs/2026-10-06-modelo-novo-design.md), §6 |
| API | [pz-api-notes §28](../../architecture/pz-api-notes.md#28-sonar-do-estalador-sprint-0037) |

## Objetivo

O estalo do Estalador vira sonar. Cada estalo (a cada 5 a 30 segundos reais, sorteado) solta um
anel que corre 8 tiles. Quem o anel pega em pé ou andando é achado pelo Estalador, mesmo cego. Quem
está agachado e parado não é achado, e casa protege: um dentro e o outro fora, o anel não acha. O
anel se vê: na névoa fluida do mod3 é uma onda que empurra a névoa, e sem o mod3 é um anel discreto
no chão.

## O que entrou

- **Regra pura** (`shared/NOM_SonarRules.lua`): raio no tempo, quem o anel cruzou neste tick,
  "em pé ou andando", "andando" pela posição, o sorteio do estalo, a validação das mensagens, a curva
  de alfa e o retângulo do anel na tela.
- **O servidor decide** (`server/NOM_SonarServer.lua`):
  - com a névoa aberta, cada Estalador vivo (sorteio pelo ID persistente) estala num intervalo
    aleatório de 5 a 30 s reais, sorteado de novo a cada estalo, se há jogador a até 40 tiles. O
    relógio é o tempo real do `OnTick` e para com o jogo pausado; a lista de zumbis é lida a cada
    1 s;
  - o anel anda no `OnTick` em tempo real (para com o jogo pausado);
  - quem ele cruza no mesmo andar é conferido (também quem anda na direção dele e pularia a frente
    entre dois ticks), uma vez por anel; casa protege;
  - o anel guarda o ID persistente do Estalador e confere antes de aplicar (objeto reaproveitado);
  - no dedicado, o anel vai só a quem está a até 40 tiles;
  - com 8 anéis vivos, sai o que já não alcança jogador nenhum; se nenhum, o estalo novo não nasce
    (nem som, nem anel): anel anunciado é sempre simulado até o fim.
- **Quem simula aplica** (`shared/NOM_Sonar.lua`, `NOM_VariantAI.sonarFound`):
  - o estalo toca no ponto, em cada cliente;
  - o cliente descarta anel longe de todo jogador local (mais de 40 tiles);
  - o dono do Estalador solta a cegueira (e o useless herdado na troca de posse), manda ele caçar
    o jogador (`spotted(p, true)`) e abre a janela anti-recegueira, que não corre com o jogo
    pausado;
  - o estalo saiu do `NOM_VariantAI`, onde cada cliente sorteava o seu: agora estalo e anel são os
    mesmos pra todos no MP.
- **Visual sem mod3** (`client/NOM_SonarFx.lua`, textura `NOM_SonarAnel.png` gerada por
  `scripts/gen_textures.py`): uma elipse 2:1 no chão, na cor da névoa (vermelha na vermelha), alfa
  0,35. Cresce até 8 tiles em 1,5 s e some em 0,4 s. Um desenho por anel.
- **Visual com mod3** (`mod3/java/nom/render/Sonar.java`, `FlowGrid.sonar`, `NOMRender_sonar`):
  - cada célula da faixa que a frente acabou de varrer leva metade da névoa dela pra frente, na
    própria direção, até meio tile depois da frente, sem criar nem sumir névoa;
  - fica um miolo ralo atrás e um monte que anda com a frente, até parar em 8 tiles e se desfazer
    com o vento;
  - a névoa levada para em parede, janela fechada, sólido e interior: nada passa pro outro lado;
  - se o mod3 pega o anel, a tela não desenha. Ele recusa (e a tela desenha) se a névoa fluida está
    desligada ou morta, se não tem névoa visível, se o anel é de outro andar ou perto da borda da
    grade, ou se já tem 8 anéis.
- **Debug:** `NOM.sonar()` e o botão "Sonar do Estalador agora" no `NOM.panel()`.
  - Na névoa, o Estalador mais perto (mesmo andar, até 60 tiles) estala na hora.
  - Sem Estalador, ou sem névoa, o anel sai dos seus pés. Esse anel é só visual: não acha ninguém.

## Decisões (pra revisar no teste)

| Decisão | Valor | Onde mudar |
|---|---|---|
| Velocidade e alcance do anel | 8 tiles em 1,5 s reais (~5,3 tiles/s, mais rápido que qualquer corrida) | `NOM_SonarRules.RANGE`, `DURATION_MS` (e `Sonar.java`, o contrato confere) |
| Duração do desenho | a expansão + 0,4 s de fade; alfa 0,35 | `FADE_MS`, `ALPHA` |
| Janela anti-recegueira | 10 s reais, que param com o jogo pausado. Dá tempo de o Estalador andar os 8 tiles (~1 tile/s) mesmo que o jogador se agache logo depois do anel. Some com a morte, com o reuso do objeto e no fim da névoa | `FOUND_MS` |
| Casa protege (Johan, 2026-10-06) | um dentro de casa e o outro fora, ou em casas diferentes: o anel não acha. Os dois na rua ou na mesma casa: acha. "Dentro" é o square sem a flag de exterior (`sq:isOutside()` falso); a casa é `sq:getBuilding()`. Conferido no square do Estalador quando ele estala e no do jogador quando o anel o cruza. Sem square: não protege | `NOM_SonarRules.sheltered` |
| "Agachado" | `isSneaking()` do jogador no servidor (vem no pacote do jogador, bytecode no §28) | `check` no `NOM_SonarServer` |
| "Andando" | pela posição: o servidor guarda a posição a cada 250 ms e conta como andando quem moveu 0,1 tile ou mais desde a amostra anterior (≥ 0,2 tile/s). `isPlayerMoving` não foi usado: não achei sinal de que ele chegue ao servidor | `SAMPLE_MS`, `MOVE_EPS` |
| Quem é achado | em pé (parado ou andando) e agachado andando. Só agachado e parado passa | `NOM_SonarRules.exposed` |
| Ritmo (Johan, 2026-10-06) | cada Estalador estala num intervalo aleatório de 5 a 30 s reais, sorteado de novo a cada estalo e por Estalador (não estalam juntos), só com jogador a até 40 tiles. Tempo real que para na pausa (precisão de ~0,25 s): não depende do tamanho do dia. Substitui a chance de 1/2 por minuto de jogo | `GAP_MIN_MS`, `GAP_MAX_MS`, `SEND_RANGE` |
| Quem recebe o anel | no dedicado, só quem está a até 40 tiles (em qualquer andar: o estalo se ouve); o cliente também descarta anel além disso | `SEND_RANGE`, `NOM_SonarRules.hears` |
| Anéis ao mesmo tempo | 8 (servidor, tela e mod3). Lotado no servidor: sai o anel mais longe de todo jogador, se ele já não alcança ninguém (sem jogador a até 17 tiles no andar); senão o estalo novo não nasce, sem som nem anel | `MAX_RINGS`, `REACH` |
| Frente na névoa fluida | cada célula da faixa varrida leva 50 % da névoa dela na própria direção radial, até meio tile depois da frente; para em parede, sólido e interior | `Sonar.TAKE`, `Sonar.AHEAD` |

## Custo medido

- **Servidor** (`sonar_budget`, mundo falso):
  - sem névoa e sem anel: 0 chamadas por tick;
  - com névoa e sem anel: 2,4 por tick (a amostra de posição);
  - 8 anéis e 4 jogadores: pior tick de 79 (a casa custa 3 por cruzamento, o ID persistente 1 por
    achado);
  - a passada na lista de zumbis (a cada 1 s) com 303 zumbis: 624 num tick, 11,3 por tick em média.
- **Tela** (`sonar_fx_budget`): 0 idas ao Java por quadro sem anel; 6 de base + 4 por anel, ou seja,
  10 com 1 anel e 38 com 8.
- **mod3** (`FlowSonarTest.cost`): 8 anéis no fim (a maior faixa) num passo da grade de 128 tiles na
  escala 2: ~0,15 ms, na thread da simulação (~3 % do passo da grade nessa escala, ~5,6 ms).
- **Limite do mod3 abaixo de 10 FPS:** o `Flow` roda no máximo 2 passos de 0,05 s por quadro; abaixo
  de 10 FPS a onda na névoa fluida fica atrás do tempo real. Quem acha é o servidor: só o desenho
  atrasa.

## Roteiro de teste no jogo

Save descartável, `-debug`, `scripts/dev-sync.sh` e o jogo reiniciado (o jar do mod3 foi
recompilado nesta sprint). Painel: Insert (ou `NOM.panel()`). Os nomes entre aspas são botões do
painel.

1. **Estalo de verdade, intervalo aleatório 5–30 s:** "1 zumbi", "Vira Estalador", "Branca já".
   Fique a uns 10 tiles, parado em pé, e marque o tempo entre os estalos por uns 2 minutos.
   - Esperado: o estalo de sempre, agora com um anel saindo do Estalador (na névoa fluida, uma onda
     que empurra a névoa; sem o mod3, um anel claro no chão). Entre um estalo e outro, de 5 a 30 s
     reais, cada vez diferente. Com dois Estaladores, eles não estalam juntos. Pause (Esc) por uns
     40 s: nenhum estalo enquanto pausado.
   - Console: `[NOM] sonar estalo por=tempo x=... y=... z=0 estalador=true`.
2. **Em pé, o anel acha:** a 5 tiles dele, em pé, clique "Sonar do Estalador agora".
   - Esperado: o anel passa por você e o Estalador vem.
   - Console: `[NOM] debug sonar estalador x=... y=... dist=...`,
     `[NOM] sonar achou jogador dist=... agachado=false andando=false` e
     `[NOM] sonar estalador achou o jogador (alvo=true)`.
3. **Agachado e parado, passa:** afaste-se, agache (C), fique parado e clique de novo.
   - Esperado: o anel passa e ele não vem (continua cego).
   - Console: `[NOM] sonar passou agachado e parado dist=...`.
4. **Agachado andando, acha:** agachado, ande devagar e clique.
   - Esperado: ele vem. `[NOM] sonar achou jogador dist=... agachado=true andando=true`.
5. **Janela de 10 s:** repita o passo 2 e agache logo depois de o anel passar.
   - Esperado: ele continua vindo até você, não para no meio do caminho.
6. **Fora do alcance:** a 12 tiles, em pé, clique. Esperado: o anel não chega a você e ele não vem
   (nenhuma linha `achou`).
6a. **Casa protege:** fique em pé dentro de casa com o Estalador fora, a uns 5 tiles (pela janela),
   e clique "Sonar do Estalador agora".
   - Esperado: o anel passa e não te acha (ele não vem).
   - Console: `[NOM] sonar passou pela casa dist=... jogador_dentro=true estalador_dentro=false`.
   - Depois, com o Estalador dentro da mesma casa (porta aberta, "1 zumbi" lá dentro e "Vira
     Estalador"), em pé, clique: aí ele te acha (`sonar achou jogador`).
6b. **Janela de 10 s com pausa:** repita o passo 5 e pause (Esc) logo depois de o anel passar, por
   uns 20 s. Volte e agache. Esperado: ele continua vindo (a janela não correu na pausa).
7. **Sem Estalador ou sem névoa:** "Fim da névoa" e clique.
   - Esperado: um anel nos seus pés, só visual.
   - Console: `[NOM] debug sonar anel no jogador (sem Estalador a até 60 tiles)`.
7a. **Onda e parede (mod3):** com a névoa fluida, clique "Sonar do Estalador agora" com o
   Estalador perto de uma parede comprida. Esperado: a onda amontoa névoa do lado de cá da parede e
   não joga névoa pro outro lado.
8. **Sem o mod3** (desative "Névoa e Outro Mundo — Volumétrica" ou `NOMRender_setParam(4, 0)` no
   console): repita o passo 2. Esperado: o anel no chão aparece centrado no Estalador e chega nos
   8 tiles. Teste também com zoom perto e longe e num andar de cima.
9. **Névoa vermelha:** "Vermelha já" e o passo 2. Esperado: o anel na tela sai avermelhado.
10. **MP (se der):** dois clientes. O estalo e o anel aparecem no mesmo lugar e na mesma hora pros
    dois. O Estalador acha o jogador em pé do outro cliente. Com um cliente a mais de 40 tiles, ele
    não ouve nem vê o estalo.

**O que só o jogo responde:**
- se o anel se vê sem chamar atenção demais, e se 8 tiles em 1,5 s lê como onda;
- se a frente na névoa fluida é visível (50 % da faixa pra frente) ou precisa de mais força;
- se o anel na tela cai no chão certo com zoom e em andar de cima;
- se 10 s de janela bastam pro Estalador chegar, ou se ele chega e logo fica cego de novo;
- no dedicado: se o `isSneaking` visto no servidor acompanha o agachar do cliente, e se a posição
  chega fina o bastante pra separar parado de andando devagar (pz-api-notes, UNKNOWN 21);
- se 5–30 s de intervalo dá o ritmo certo (estala demais com vários Estaladores?);
- se varanda e garagem sem sala (cobertas, sem prédio) protegem como deveriam (UNKNOWN 21).
