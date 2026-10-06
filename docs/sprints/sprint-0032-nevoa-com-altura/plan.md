# Sprint 0032 — Névoa com altura (mod3, etapa 2 da pesquisa)

## Por quê

Depois da 0031 a névoa contorna os prédios, mas todo obstáculo ainda é muro até o céu: a cerca baixa
segura a névoa como uma parede, e o carro só freia o ar. A [pesquisa](../../architecture/pesquisa-nevoa-volumetrica.md)
(etapa 2) propõe a camada rasa: a névoa tem profundidade e cada obstáculo tem altura. Passa por cima o
que é mais baixo que ela; para o que é mais alto.

## O que muda

1. **Densidade = profundidade.** `FOG_DEPTH = 0.8` andar por unidade de densidade (1,0 ≈ o rolo que o
   shader já desenha). Superfície `η = H + h`.
2. **Alturas.** Carro (`F_LOW`): célula com `H_LOW = 0.55` andar. Cerca baixa (`HoppableN/W`, evidência
   no [pz-api-notes §20](../../architecture/pz-api-notes.md)): face aberta com `H_FENCE = 0.4` andar e
   arrasto no vento. Parede, prédio, cerca alta, porta e janela fechadas: face fechada, como hoje.
3. **Regra de face seca** (Chentanez & Müller 2010, §2.1.4): na face com obstáculo, só passa a parte
   da coluna acima dele, `max(0, η_cima − H_face) / h_cima` do fluxo (advecção e difusão). Névoa rasa
   para na cerca; funda empilha na frente e transborda.
4. **Transbordo por gravidade** (névoa pesada, TWODEE-2): fluxo `G · h_efetivo · ∇η`, conservativo e
   limitado por face, **só nas faces com obstáculo baixo**. A pilha transborda e escorre do outro lado.
   *Mudou na execução:* em campo aberto a gravidade fechava os buracos que viajam com o vento (teste da
   0026), enchia o vácuo atrás do prédio (0,38 → 0,49 a 2 tiles) e subia o passo de 5,6 para 7,0 ms.
5. **Carro com menos arrasto** no vento (4 → 1/s): a névoa por cima dele anda com o ar de cima.
6. **Shader:** o topo do rolo sobe a altura do carro onde há carro (`nomFlowLow`, interpolado). Debug 5
   mostra a cerca baixa em amarelo (`T_FENCE_W/N` na textura).

## TDD

- [x] Cerca baixa: a névoa passa (2 tiles atrás > 0,7) e o vento também; um muro do mesmo tamanho deixa vácuo.
- [x] Névoa rasa (abaixo da cerca) não passa parada e, com vento, empilha na frente; funda passa.
- [x] Carro: a névoa passa por cima (dentro > 0,3) e o outro lado enche.
- [x] Sem vento: névoa funda transborda a cerca pela gravidade, rasa fica; nunca negativa.
- [x] Domínio fechado com cercas, carros e árvores conserva massa.
- [x] Estável com bancos e vácuos (h → 0) e vento forte; densidade em [0, D_MAX].
- [x] O vácuo da 0031 (escolha do Johan) continua: atrás do prédio < 0,6 com `stillDecay`.
- [x] Custo do passo na escala 2 ≤ 6,3 ms: medido 5,8–6,0 ms.
- [x] Contrato: `NOM_FLOW_LOW_H` = `H_LOW`, `NOM_FLOW_FENCE_W/N` = `T_FENCE_W/N`, `Flow` lê `HoppableW/N`.

## Fora

Camadas (névoa entrando por janela alta, caindo do telhado), velocidade própria da camada (ondas),
desenho que segue o fluxo local.
