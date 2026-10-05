# Sprint 0031 — Névoa que contorna (mod3, etapa 1 da pesquisa)

## Por quê

O Johan viu a névoa como "uma fumaça que passa entre os objetos": sem volume, sem desviar, sem encher o
outro lado. A [pesquisa](../../architecture/pesquisa-nevoa-volumetrica.md) achou as causas no nosso
código (D1–D6). Esta sprint é a etapa 1 dela: consertar a simulação 2D antes da camada com altura (2,5D).

## O que muda

1. **Vácuo A/B** (`NOMRender_setParam(10, v)`): multiplica o `stillDecay`. 0 = a névoa contorna e
   enche o outro lado; 1 = o vácuo da 0026. No jogo o Johan preferiu 1, que virou o padrão.
2. **Acúmulo visível** (D4): a textura leva `densidade / D_MAX` e o shader multiplica de volta
   (`NOM_FLOW_DMAX = 1.5`); a névoa que empilha contra a parede chega no desenho.
3. **Obstáculo poroso e baixo** (D2): árvore deixa de ser sólida e vira arrasto (o ar passa freado);
   carro vira obstáculo baixo (`F_LOW`) com arrasto forte.
   *Mudou na execução:* a primeira versão deu ao carro face parcialmente aberta (pesos de Batty 2007).
   Em 2D isso vira um canal estreito, e a pressão **acelerava** o ar dentro do carro (1,55 contra 1,53
   fora). O arrasto faz o ar desviar pelos lados, com pouco passando por cima. Face fracionária volta
   na etapa 2, junto com a altura.
4. **Pressão com chute do passo anterior** (D6): não zera `p` a cada passo (zera ao rolar ou mudar a
   máscara). Diagnóstico `maxDivergence()`.
5. **Empilhamento só a barlavento** (D3): o rolo sobe onde o ar freia **e** há obstáculo logo à frente
   na direção do vento; na esteira não sobe mais.

## TDD

- [x] Sem `stillDecay`, a esteira do prédio enche (2, 4, 8 tiles atrás > 0,8); com ele, vácuo (< 0,6).
- [x] Textura: densidade 1,5 → 255, 1,0 → 170.
- [x] Árvore porosa: o ar passa freado (entre 10% e 70% do vento) e a névoa atrás fica > 0,8.
- [x] Carro (`F_LOW`): passa fluxo, velocidade menor que fora; domínio fechado com carros conserva massa.
- [x] Pressão com chute: divergência que sobra menor que começando do zero, mesmas iterações.
- [x] Custo do passo na escala 2 ≤ 6,3 ms (5,7 + 10%): medido 5,6 ms.
- [x] `test_mod3_depth.py`: `PARAM_VACUUM = 10` com padrão 1; `NOM_FLOW_DMAX` no shader; `pileUp` olha à frente.

## Fora (etapa 2)

Altura de obstáculo por tile (cerca baixa vs parede: precisa de evidência de API), camada rasa `h`,
desenho que segue o fluxo local (Neyret 2003 / curl noise).
