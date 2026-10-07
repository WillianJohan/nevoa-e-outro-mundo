# Sprint 0036 — Equilíbrio: visão de ~4 tiles e perambular

| Campo | Valor |
|-------|-------|
| Status | em teste (branch `sprint/0036-equilibrio`, sem merge) |
| Branch | `sprint/0036-equilibrio` |
| Plano | [plan.md](plan.md) (com a medição da Tarefa 0) |
| Spec | [modelo novo](../../superpowers/specs/2026-10-06-modelo-novo-design.md), §5 e §11 |
| API | [pz-api-notes §27](../../architecture/pz-api-notes.md#27-visão-curta-e-perambular-na-névoa-sprint-0036) |

## Objetivo

Na névoa branca e na vermelha, o zumbi enxerga só ~4 tiles e acha o jogador pelo barulho. De tempos em
tempos, grupos pequenos de zumbis parados saem andando pela região, nunca na direção do jogador: o
encontro vem a qualquer hora, sem virar horda. O custo com ~300 zumbis carregados era critério de aceite
e foi medido antes de qualquer código.

## O que entrou

- **Medição primeiro** ([plan.md](plan.md#tarefa-0-medição), [medicao.lua](medicao.lua)): estender a
  cegueira do Estalador a todo zumbi, todo frame, custaria 600 chamadas ao Java por frame com 300 zumbis
  parados e 2700 com a multidão (o teto do repo é 2500 por atualização). Em rodízio de 30 por tick o custo
  cai pra ~1/7, então o plano B (piso de 10 tiles) não foi preciso.
- **Visão de ~4 tiles** (`shared/NOM_VariantAI.lua`):
  - **Quem:** todo zumbi sem mira própria, o comum e o Sem-rosto. Estalador, Corredor, Carpideira e Eco
    ficam como estão.
  - **Quando fica cego:** se ele mira num jogador quieto (sem correr nem sprint) a mais de 4 tiles, e
    não está no raio de um barulho recente desse jogador, a mira é desfeita e ele para (o mesmo
    `useless` + `halt` da sirene).
  - **Como confere:** a cada 10 frames vê se o jogador chegou perto ou fez barulho. Em ~1 s solta e
    vigia 30 frames, e se o jogador ainda está longe e quieto, fecha de novo.
  - **Som acorda:** todo som do mundo (`OnWorldSound`) solta os cegos no raio dele.
  - **Som atrai:** um som com raio de 10 tiles ou mais, feito pelo jogador (tiro) ou no pé dele (carro),
    o denuncia pra todo zumbi no raio do som. Quem ouviu vem até ele e não fica cego no caminho. A
    janela cresce com o raio (2 s por tile, de 3 s a 2 min a 60 FPS), pra dar tempo de o zumbi lento
    chegar. O passo andando (raio ~7) não denuncia.
  - **Opção:** `FogZombieVision`, de 0 a 10, padrão 4; 0 desliga.
  - **Custo** com 300 zumbis no mundo falso: 61 chamadas por tick com todos parados; na multidão, média
    de 129 e pior tick de 452. Cada som custa 4 chamadas, com qualquer número de cegos.
- **Perambular** (`shared/NOM_WanderRules.lua`, `shared/NOM_Wander.lua`, `server/NOM_WanderServer.lua`):
  - **Quem decide:** o servidor, a cada 4 a 8 minutos de jogo de névoa aberta (10 a 20 s reais com o dia
    de 1 h). Ele solta a onda e a semente.
  - **Quem aplica:** quem simula os zumbis. Pra cada jogador local, pega no máximo um grupo de 1 a 3
    zumbis parados (sem alvo, sem andar, sem regra própria) a 6–30 tiles dele.
  - **Pra onde:** o grupo anda 8–20 tiles em formação até um ponto a 8–35 tiles de todo jogador. O
    caminho reto não passa a menos de 5 tiles de nenhum jogador, inclusive os de outros clientes no MP.
  - **Andar:** `pathToLocationF`, com evidência no bytecode e no menu de debug vanilla.
  - **Ficam de fora:** a sirene, variantes, Sem-rostos, Ecos, cegos, Carpideira parada, congelados, quem
    finge de morto e quem está sentado no chão.
  - **Opção:** `FogWander`, ligada.
  - **Custo da onda** com 300 zumbis: até ~1200 chamadas, fatiadas em 1 ou 2 ticks de até ~600, uma vez
    a cada 4–8 minutos de jogo.
- **Debug:**
  - `NOM.wander()`: uma onda agora, decidida pelo servidor.
  - `NOM.blind()`: cegos, vigiados e a última onda neste processo.
  - Os dois têm botão no `NOM.panel()`: "Onda de perambular" e "Cegos da visão curta no console".

## Decisões (pra revisar no teste)

| Decisão | Valor | Onde mudar |
|---|---|---|
| Raio da visão | 4 tiles | opção `FogZombieVision` (padrão em `NOM_Config` e `sandbox-options.txt`) |
| "Quieto" | andar e agachar contam como quieto; correr e sprint, não | `about` no `NOM_VariantAI` |
| Barulho que atrai | som com raio ≥ 10 do jogador (fonte) ou no pé dele (≤ 3 tiles); vale pra quem está no raio, por raio × 2 s (de 3 s a 2 min a 60 FPS) | `NOM_VariantAI.NOISE_*` |
| Sem-rosto | ganha a visão curta (não tem IA de mira própria) e não perambula | `sweep` no `NOM_VariantAI`, `idle` no `NOM_Wander` |
| Intervalo das ondas | 4 a 8 minutos de jogo | `NOM_WanderRules.MIN_GAP`/`MAX_GAP` |
| Grupo | 1 a 3, juntos a até 5 tiles, um grupo por jogador por onda | `GROUP_MAX`, `GROUP_RADIUS` |
| Distâncias | saem de 6–30 tiles, andam 8–20, destino a 8–35, caminho a ≥ 5 do jogador | `NEAR_*`, `LEG_*`, `DEST_MIN`, `REGION_MAX`, `PASS_MIN` |
| Useless herdado | só no cliente de MP: na névoa, com a visão curta ligada, qualquer useless local que não é do jogo cai (inclusive o de outro mod). No solo não há troca de posse, então o useless de outro mod e o do menu de debug ficam (troca do code review final) | `heldByMod` no `NOM_VariantAI` |

## Roteiro de teste no jogo

Save descartável, `-debug`, `scripts/dev-sync.sh` e o jogo reiniciado. Painel: Insert (ou `NOM.panel()`).

1. **Visão curta, parado:** "10 zumbis" duas ou três vezes, afaste-se uns 8 tiles e clique "Branca já".
   Ande devagar, sem correr, a uns 6–8 tiles deles.
   - Esperado: eles não vêm. Alguns dão um passo e param.
   - Console, a cada ~5 s: `[NOM] visao curta cegos=N vigiados=M estaladores=0 lista=L raio=4`.
   - "Cegos da visão curta no console" imprime `[NOM] debug visão curta ligada=true raio=4 cegos=...`.
2. **Chegando perto:** ande até 3 tiles de um deles. Esperado: ele te vê e vem.
3. **Barulho:** a 8 tiles, corra (Shift) ou dê um tiro. Esperado: eles vêm.
4. **Atire na névoa e veja os zumbis chegarem:** "10 zumbis" uns 25–30 tiles longe de você (fora da
   vista), "Branca já", fique parado e dê um tiro.
   - Esperado: eles vêm até você e mordem. Não param no caminho a 10–20 tiles nem ficam dando um passo
     e parando.
   - Depois, ande devagar uns 20 tiles pra longe (sem correr). Esperado: zumbi que não estava no raio
     do tiro e te vê de longe não vem.
5. **Garrafa longe:** jogue algo longe deles. Pelo bytecode, quem viu você há menos de ~8 s não liga pro
   som (como no vanilla): só os que não te viram vão até lá.
6. **Variantes iguais:** "Vira Corredor" num deles, a 8 tiles. Esperado: ele te vê, grita e corre.
7. **Perambular:** névoa aberta, fique parado num lugar com zumbis espalhados a 6–30 tiles e clique
   "Onda de perambular".
   - Esperado: 1 a 3 zumbis parados saem andando juntos, pra longe de você, nunca na sua direção.
   - Console: `[NOM] debug perambular onda semente=N` e `[NOM] perambular zumbis=K candidatos=C jogadores=1 lista=L`.
   - Sem clicar, uma onda a cada 4–8 minutos de jogo: `[NOM] perambular onda por=tempo semente=N`.
8. **Sem névoa:** "Fim da névoa". Esperado: os cegos soltam na hora e `visao curta` some do console.
   "Onda de perambular" responde `[NOM] debug perambular precisa de névoa aberta`. Com a névoa aberta
   e a opção "Zumbis perambulando na névoa" (`FogWander`) desligada, responde `[NOM] debug perambular desligado na opção FogWander`.
9. **FPS:** numa cidade cheia (300+ zumbis carregados), névoa aberta. Compare o FPS com a névoa e sem ela.

**O que só o jogo responde:**
- se 4 tiles fica bom (pouco demais, muito?) e se andar em pé deve contar como barulho;
- se o piso de raio 10 separa bem o passo do tiro, e se a janela do barulho (2 s por tile do raio) dá
  tempo de os zumbis chegarem sem durar demais;
- se o perambular dá encontro frequente sem horda, e se o intervalo de 4–8 minutos é muito ou pouco;
- se o `halt` para o zumbi que já vinha andando, ou se ele continua até a última posição vista;
- o FPS com muitos zumbis;
- no MP: se o `OnWorldSound` chega no cliente dono (senão o tiro não acorda os cegos dele), e se a cópia
  dos outros acompanha o grupo que perambula, e se correr perto do zumbi de outro cliente conta como
  barulho (`isRunning` do jogador remoto; pz-api-notes §27, UNKNOWN 20).
