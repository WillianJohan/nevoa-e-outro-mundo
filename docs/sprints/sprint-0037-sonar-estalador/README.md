# Sprint 0037 — Sonar do Estalador

| Campo | Valor |
|-------|-------|
| Status | em teste (branch `sprint/0037-sonar-estalador`, sem merge) |
| Branch | `sprint/0037-sonar-estalador` |
| Plano | [plan.md](plan.md) |
| Spec | [modelo novo](../../superpowers/specs/2026-10-06-modelo-novo-design.md), §6 |
| API | [pz-api-notes §28](../../architecture/pz-api-notes.md#28-sonar-do-estalador-sprint-0037) |

## Objetivo

O estalo do Estalador vira sonar. Cada estalo (em média a cada 2 minutos de jogo) solta um anel
que corre 8 tiles. Quem o anel pega em pé ou andando é achado pelo Estalador, mesmo cego. Quem
está agachado e parado não é achado. O anel se vê: na névoa fluida do mod3 é uma onda que empurra
a névoa, e sem o mod3 é um anel discreto no chão.

## O que entrou

- **Regra pura** (`shared/NOM_SonarRules.lua`): raio no tempo, quem o anel cruzou neste tick,
  "em pé ou andando", "andando" pela posição, o sorteio do estalo, a validação das mensagens, a curva
  de alfa e o retângulo do anel na tela.
- **O servidor decide** (`server/NOM_SonarServer.lua`):
  - a cada minuto de jogo, com a névoa aberta, cada Estalador vivo (sorteio pelo ID persistente)
    estala com chance 1/2 se há jogador a até 40 tiles;
  - o anel anda no `OnTick` em tempo real (para com o jogo pausado);
  - quem ele cruza no mesmo andar é conferido.
- **Quem simula aplica** (`shared/NOM_Sonar.lua`, `NOM_VariantAI.sonarFound`):
  - o estalo toca no ponto, em cada cliente;
  - o dono do Estalador solta a cegueira, manda ele caçar o jogador (`spotted(p, true)`) e abre a
    janela anti-recegueira;
  - o estalo saiu do `NOM_VariantAI`, onde cada cliente sorteava o seu: agora estalo e anel são os
    mesmos pra todos no MP.
- **Visual sem mod3** (`client/NOM_SonarFx.lua`, textura `NOM_SonarAnel.png` gerada por
  `scripts/gen_textures.py`): uma elipse 2:1 no chão, na cor da névoa (vermelha na vermelha), alfa
  0,35. Cresce até 8 tiles em 1,5 s e some em 0,4 s. Um desenho por anel.
- **Visual com mod3** (`mod3/java/nom/render/Sonar.java`, `FlowGrid.sonar`, `NOMRender_sonar`):
  - a frente leva metade da névoa da faixa que acabou de varrer pra 1 tile à frente, sem criar nem
    sumir névoa;
  - fica um miolo ralo atrás e um monte que anda com a frente, até parar em 8 tiles e se desfazer
    com o vento;
  - interior e parede não dão nem recebem;
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
| Janela anti-recegueira | 10 s reais. Dá tempo de o Estalador andar os 8 tiles (~1 tile/s) mesmo que o jogador se agache logo depois do anel. Some com a morte, com o reuso do objeto e no fim da névoa | `FOUND_MS` |
| "Agachado" | `isSneaking()` do jogador no servidor (vem no pacote do jogador, bytecode no §28) | `check` no `NOM_SonarServer` |
| "Andando" | pela posição: o servidor guarda a posição a cada 250 ms e conta como andando quem moveu 0,1 tile ou mais desde a amostra anterior (≥ 0,2 tile/s). `isPlayerMoving` não foi usado: não achei sinal de que ele chegue ao servidor | `SAMPLE_MS`, `MOVE_EPS` |
| Quem é achado | em pé (parado ou andando) e agachado andando. Só agachado e parado passa | `NOM_SonarRules.exposed` |
| Frequência | chance 1/2 por minuto de jogo (média de 2 min), só com jogador a até 40 tiles | `CLICK_ODDS`, `SEND_RANGE` |
| Anéis ao mesmo tempo | 8 (servidor, tela e mod3); o mais velho sai | `MAX_RINGS` |
| Frente na névoa fluida | leva 50 % da faixa varrida pra 1 tile à frente | `Sonar.TAKE`, `Sonar.AHEAD` |

## Custo medido

- **Servidor** (`sonar_budget`, mundo falso):
  - sem névoa e sem anel: 0 chamadas por tick;
  - com névoa e sem anel: 2,4 por tick (a amostra de posição);
  - 8 anéis e 4 jogadores: pior tick de 58;
  - o minuto de jogo com 303 zumbis: 634.
- **Tela** (`sonar_fx_budget`): 0 idas ao Java por quadro sem anel; 6 de base + 4 por anel, ou seja,
  10 com 1 anel e 38 com 8.
- **mod3** (`FlowSonarTest.cost`): 8 anéis no fim (a maior faixa) num passo da grade de 128 tiles na
  escala 2: ~0,18 ms, na thread da simulação.

## Roteiro de teste no jogo

Save descartável, `-debug`, `scripts/dev-sync.sh` e o jogo reiniciado (o jar do mod3 foi
recompilado nesta sprint). Painel: Insert (ou `NOM.panel()`). Os nomes entre aspas são botões do
painel.

1. **Estalo de verdade:** "1 zumbi", "Vira Estalador", "Branca já". Fique a uns 10 tiles e espere
   uns minutos de jogo, parado em pé.
   - Esperado: o estalo de sempre, agora com um anel saindo do Estalador (na névoa fluida, uma onda
     que empurra a névoa; sem o mod3, um anel claro no chão).
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
7. **Sem Estalador ou sem névoa:** "Fim da névoa" e clique.
   - Esperado: um anel nos seus pés, só visual.
   - Console: `[NOM] debug sonar anel no jogador (sem Estalador a até 60 tiles)`.
8. **Sem o mod3** (desative "Névoa e Outro Mundo — Volumétrica" ou `NOMRender_setParam(4, 0)` no
   console): repita o passo 2. Esperado: o anel no chão aparece centrado no Estalador e chega nos
   8 tiles. Teste também com zoom perto e longe e num andar de cima.
9. **Névoa vermelha:** "Vermelha já" e o passo 2. Esperado: o anel na tela sai avermelhado.
10. **MP (se der):** dois clientes. O estalo e o anel aparecem no mesmo lugar e na mesma hora pros
    dois. O Estalador acha o jogador em pé do outro cliente.

**O que só o jogo responde:**
- se o anel se vê sem chamar atenção demais, e se 8 tiles em 1,5 s lê como onda;
- se a frente na névoa fluida é visível (50 % da faixa pra frente) ou precisa de mais força;
- se o anel na tela cai no chão certo com zoom e em andar de cima;
- se 10 s de janela bastam pro Estalador chegar, ou se ele chega e logo fica cego de novo;
- no dedicado: se o `isSneaking` visto no servidor acompanha o agachar do cliente, e se a posição
  chega fina o bastante pra separar parado de andando devagar (pz-api-notes, UNKNOWN 21).
