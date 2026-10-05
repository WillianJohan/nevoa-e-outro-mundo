# Sprint 0024 — Névoa fluida (mod3)

| Campo | Valor |
|-------|-------|
| Status | em teste |
| Branch | `sprint/0024-nevoa-fluida` |
| Plano | [plan.md](plan.md) |
| Base | [spike da volumétrica](../spike-volumetrica/README.md) (mod3: ponte GPU + `NOM_VolFog`) |
| Mod | `mod3/` → `NevoaEOutroMundo_Volumetrica` (opcional, só cliente, ZombieBuddy) |

## Objetivo

A névoa do mod3 se comporta como um líquido. Ela contorna prédios, paredes, árvores e carros em vez de
atravessar, acumula nos abertos, escorre por porta e janela abertas e é empurrada por quem anda,
deixando rastro. O visual também muda: fica mais densa no chão, mais cinza e suave em cima, e envolve
a base das árvores.

Pedido do Johan (05/10/2026), com dois ajustes do print do spike: a névoa estava branca e chapada
demais, e as árvores ficavam por cima dela.

## Como funciona

- **Núcleo puro** (`FlowGrid.java`, sem API do jogo):
  - grade de 128×128 tiles em volta do personagem da câmera, presa em tile inteiro do mundo e rolada quando ele anda;
  - grade escalonada: a densidade fica no centro do tile e a velocidade nas faces. A parede do jogo é uma borda N/W do square, então vira **uma face fechada**;
  - a densidade anda por fluxo nas faces (upwind conservativo), então face fechada não deixa passar nada, por construção;
  - a projeção (SOR red-black, 16 iterações) tira a divergência, e é ela que faz o vento contornar o obstáculo em vez de bater e parar.
- **Forças:**
  - vento do clima (`ClimateManager`), lento e com a direção oscilando;
  - quem anda arrasta a névoa e abre um vazio onde passa (o rastro);
  - a névoa entra pelas bordas da grade;
  - fora de prédio, volta pro ambiente em uns 8 s;
  - dentro, se desfaz em uns 12 s, a não ser que continue entrando por uma abertura.
- **Máscara** (`Flow.java`, thread principal):
  - 8 linhas por quadro, então a grade inteira é revista a cada 16 quadros;
  - a faixa que entra na rolagem é montada na hora;
  - no começo e quando muda de andar, a grade inteira é montada de uma vez.
- **Render:**
  - textura RGBA8 128×128 na unidade 6, publicada a 20 Hz;
  - o `NOM_VolFog` multiplica a densidade da névoa pela do fluido;
  - o ruído é levado pela velocidade do fluido (flow map de duas fases).

## Critérios de aceite

- [x] **Obstáculos com evidência** ([plan.md](plan.md#evidência-bytecode-b4221-projectzomboidjar-javap--c)):
  - `isBlockedTo` cobre parede (`collideN`/`collideW`, sem janela), janela fechada ou barricada, porta fechada ou barricada, e escada;
  - porta e janela abertas ou quebradas passam;
  - sólido, árvore e carro bloqueiam o tile inteiro;
  - square não carregado é ar aberto.
- [x] **Caixa fechada não deixa entrar névoa**, nem com vento forte e gente andando em volta. A velocidade nas faces fechadas é zero. Teste: `caixa fechada não deixa entrar névoa`.
- [x] **Passa por fresta de 1 tile:** uma parede com uma fresta deixa passar, e a mesma parede sem fresta não. Teste: `parede com fresta de 1 tile deixa passar`.
- [x] **Escorre por porta e janela abertas:** uma casa com duas aberturas enche. Teste: `casa com porta e janela abertas enche`.
- [x] **A rolagem preserva a densidade e as paredes no mundo**, e uma rolagem maior que a grade reseta. Teste: `rolagem preserva a densidade no mundo`.
- [x] **O impulso desloca a densidade, e quem anda deixa rastro.** Testes: `impulso desloca a densidade` e `quem anda deixa rastro`.
- [x] **Transporte conserva massa**, é estável com velocidade absurda e contorna obstáculo sólido (acelera ao lado). Interior novo começa vazio e esvazia.
- [x] **Custo:** passo de ~0,9 ms em 128×128 (Ryzen 7600X). O teste imprime o valor e falha acima de 3 ms. A 20 Hz, isso dá ~0,3 ms por quadro a 60 FPS, mais a máscara (o log do jogo mostra as duas).
- [x] **Contrato Java ↔ GLSL:** todo uniform que o Java procura existe no cabeçalho, e as flags e a escala da velocidade batem (`test_mod3_depth.py`). Os shaders compilam com `glslangValidator` (`test_mod3_flow.sh`).
- [x] **Nada derruba o jogo:** erro no fluido (thread principal ou upload) loga `[NOM-Render] ERRO no fluido` e desliga só a simulação. A névoa segue com densidade 1.
- [ ] **No jogo (Johan):** roteiro abaixo.

## Controles (console Lua, com `-debug`)

| Comando | O que faz |
|---|---|
| `NOMRender_setParam(4, 0)` | desliga a simulação (névoa como antes, densidade 1) |
| `NOMRender_setParam(4, 1)` | liga (padrão) |
| `NOMRender_setParam(1, 5)` | obstáculos: sólido vermelho, árvore verde, interior azul, parede/porta fechada em linha branca na borda |
| `NOMRender_setParam(1, 6)` | densidade do fluido (branco = cheio, preto = vazio) |
| `NOMRender_setParam(1, 7)` | velocidade (vermelho = +x, verde = +y, cinza = parado) |
| `NOMRender_setParam(2, 1.5)` | altura da camada em andares (padrão 1,2) |

## Roteiro in-game

1. `scripts/build-mod3.sh && scripts/dev-sync.sh`, depois reiniciar o jogo (`-javaagent:ZombieBuddy.jar -- -debug`).
2. No `console.txt` têm que aparecer `[NOM-Render] pass NOM_VolFog ok`, `[NOM-Render] fluido: textura 128x128` e, a cada ~30 s, `fluido: passo X ms, máscara Y ms/quadro`. **Anotar os dois números.** Não pode aparecer nenhum `ERRO`.
3. `NOMRender_setParam(0, 1)` (névoa forçada) e `NOMRender_setParam(1, 5)`:
   - prédio azul por dentro;
   - linha branca nas paredes externas;
   - a linha some na porta aberta e volta ao fechar (em até ~0,3 s);
   - árvores verdes e carros vermelhos.
4. `NOMRender_setParam(1, 6)`:
   - dentro de casa fechada fica preto, fora fica branco;
   - abrir a porta deixa entrar uma língua clara, que some devagar ao fechar;
   - andando, fica um rastro escuro atrás do personagem que se fecha em alguns segundos.
5. `NOMRender_setParam(1, 7)`: o vento contorna prédios e árvores (as cores mudam em volta deles), e quem anda deixa uma mancha colorida.
6. `NOMRender_setParam(1, 0)`, com a névoa normal:
   - a névoa não atravessa parede;
   - entra pela porta aberta;
   - abre e deixa rastro atrás de quem anda;
   - tufos se mexem com o vento e redemoinham em volta de quem passa;
   - mais densa rente ao chão, mais cinza e fina em cima;
   - a base das árvores some na névoa.
7. Subir e descer escada: a grade reseta no andar novo, sem erro. No máximo um soluço curto na troca.
8. `NOMRender_setParam(4, 0)`: volta a névoa uniforme. `(4, 1)`: volta a fluida.
9. Névoa vermelha: a cor continua vindo do clima (vermelha), agora com a mesma forma fluida.
10. FPS com e sem a simulação (`setParam(4, 0/1)`): anotar a diferença.

## Decisões

- **Grade escalonada e advecção por fluxo** em vez de semi-Lagrangiana:
  - a semi-Lagrangiana interpola através de parede fina e vaza;
  - o fluxo nas faces garante zero através de face fechada e conserva massa;
  - o custo é mais difusão numérica, que pra névoa é até bom.
- **Sem auto-advecção da velocidade:**
  - a velocidade relaxa pro vento e a projeção a torna sem divergência;
  - o impulso vira um par de vórtices, que é o redemoinho em volta de quem anda;
  - o handoff permitia simplificar se justificasse, e os testes cobrem o que o Johan pediu.
- **CPU, não GPU:** 0,9 ms por passo a 20 Hz cabe na meta. FBO ping-pong ficaria pra se a CPU não der conta.
- **O vazio do impulso não conserva massa** (de propósito): o rastro é névoa que some e volta. O teste de massa cobre só o transporte.
- **Árvores:** o sprite da árvore escreve profundidade constante (achado do spike), então a reconstrução sobe e a névoa passava por cima. Com a flag de árvore da máscara, a névoa ganha densidade extra perto do chão em volta da árvore e envolve a base. A copa acima da camada continua limpa, que é o certo.
- **Vento:** vem do `ClimateManager` (ângulo e intensidade). A convenção do ângulo no mundo não foi conferida; pra névoa, a direção exata não importa.

## Aprendizados

- **Gauss-Seidel em ordem de linha é preso por latência na JVM:** cada célula espera a anterior, e deu 2,6 ms. O red-black com os pesos pré-multiplicados e sem desvio no laço deu 0,95 ms com 24 iterações e 0,86 ms com 16. A rolagem e a velocidade que persistem entre passos compensam as iterações a menos (os testes de contorno e de fresta passam com 12).
- **Teste com vento precisa de tempo pra convergir:** a velocidade relaxa a 0,6/s, então em 5 s está só a 95%.
- **`glslangValidator` (brew) compila o shader do mod3 igual ao Java monta** (cabeçalho + `#line 1` + passe), e pega erro de GLSL antes de ir pro jogo.

## Riscos

- O custo da máscara depende de quantos objetos tem no square (`isBlockedTo` varre objetos de borda). O log mostra; se pesar, baixar `ROWS_PER_FRAME`.
- Cerca baixa com `collideN`/`collideW` bloqueia a névoa como parede alta.
- Splitscreen: a grade segue só o jogador 0.
