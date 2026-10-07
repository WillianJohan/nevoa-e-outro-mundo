# Sprint 0045: luz que pisca e tempestade

| Campo | Valor |
|-------|-------|
| Status | `em teste` (na `staging`) |
| Branch | `sprint/0045-luz-e-tempestade` (saiu da `staging`) |
| Origem | teste do Johan no jogo em 2026-10-07: "a lanterna não ficou piscando… os postes ficaram acesos… colocar tempestade, relâmpago, na preta e na vermelha. A branca está perfeita" |
| Plano | [plan.md](plan.md) |

## O que entrou

- **A lanterna gagueja de verdade** (névoa preta). Antes ela só apagava e voltava. Agora:
  - liga e desliga rápido de 3 a 6 vezes;
  - apaga pelo tempo sorteado (0,7 a 1,6 s, como antes);
  - liga e desliga mais 2 a 4 vezes;
  - termina acesa.
  - O Tição solta durante a janela inteira.
  - Quem mexe na lanterna no meio (desliga, guarda) fica com ela como deixou.
- **Postes piscam na névoa preta e na vermelha:**
  - a cada 2 s, com 30% de chance, um poste da rede aceso de fora a até 25 tiles de um jogador gagueja
    (4 a 9 piscadas, às vezes um escuro de 0,4 a 1,2 s) e volta na mesma cor;
  - no máximo 2 piscando juntos;
  - luz de dentro de casa, fogo e lampião não piscam (o jogo reescreve a cor deles);
  - no solo, salvar no meio do pisca devolve a cor antes (o save grava a cor da luz);
  - na preta, o poste piscando não congela o Tição e solta na hora quem ele segurava.
- **Tempestade na preta e na vermelha** (a branca fica como está):
  - um relâmpago a cada 8 a 30 s, longe de um jogador sorteado (40 a 900 tiles), com clarão e trovão;
  - o trovão chega até 3 s depois do clarão, conforme a distância;
  - nenhum raio cai: sem fogo nem dano;
  - **na preta, o clarão congela os Tições perto dos jogadores por 1 s**;
  - **chuva em 30% das névoas pretas e vermelhas**, fixa por névoa (a mesma névoa não liga e
    desliga) e pela semente do mundo (cada save chove em névoas diferentes), entrando em rampa de
    20 minutos de jogo;
  - a chuva só soma: chuva do jogo mais forte fica como está. No frio pode virar neve.
- **Debug, com botão no `NOM.panel()`:**
  - `NOM.thunder()`: relâmpago agora;
  - `NOM.flickerLamp()`: um poste perto pisca agora;
  - `NOM.rain()`: força a chuva nas pretas e vermelhas (liga e desliga, só em memória).

## Como funciona

- O servidor decide e quem desenha aplica (ADR-002/005):
  - **lanterna:** o servidor manda o padrão inteiro (`torchFlicker` com `segs`) só pro dono;
  - **poste:** manda posição e padrão pra todos (`lampFlicker`), e cada cliente acha a luz dele pela
    posição;
  - **relâmpago:** `ThunderStorm.triggerThunderEvent` no servidor, que o jogo transmite sozinho;
  - **chuva:** vai na camada modded do clima, como a névoa.
- **Poste pela cor:** o `setActive(false)` não serve no poste da rede, porque o jogo recalcula o
  aceso todo quadro. A cor passa pro motor de luz quando muda (pz-api-notes §34).
- **Arquivos novos:**
  - `shared/NOM_FlickerRules.lua` e `shared/NOM_StormRules.lua` (puros);
  - `server/NOM_LampFlicker.lua` e `server/NOM_Storm.lua`;
  - `client/NOM_LampFlickerFx.lua`.

## Testes

- `tests/test_flicker_rules.lua` (3): forma dos padrões, faixa da gagueira e `stateAt`.
- `tests/test_ticao_light.lua`:
  - a lanterna gagueja (6 ou mais trocas), o Tição solta e ela volta;
  - guardar ou desligar no meio para o padrão;
  - o dedicado manda o padrão só pro dono, com a janela do tamanho dele.
- `tests/test_lamp_flicker.lua` (7):
  - só na preta e na vermelha;
  - só poste de fora, aceso e perto;
  - teto de 2 juntos;
  - o dedicado manda pra todos sem mexer na cor de lá;
  - o cliente toca e devolve a cor;
  - o Tição solta.
- `tests/test_storm_rules.lua` (3) e `tests/test_storm.lua` (5):
  - intervalo e ponto longe;
  - 30% fixo por período;
  - só na preta e na vermelha abertas, sem raio caindo;
  - o clarão congela na preta e não na vermelha;
  - `force`.
- `tests/test_climate_look.lua`:
  - chuva só no período sorteado ou forçada, em rampa;
  - desliga no fim;
  - não mexe nem enfraquece a chuva do jogo.
- `tests/test_fog_client.lua`: os comandos `lampFlicker` e `torchFlicker` (padrão) no cliente de MP.
- `tests/test_debug*.lua`: as três ops e os três botões, com tradução PTBR e EN.

## Code review (fim da entrega)

Um revisor independente mais a minha leitura. Achado e corrigido:

- **Crítico, só no solo:** o save grava a cor da luz do poste, então salvar no meio do pisca deixaria
  o poste preto pra sempre. Agora a cor volta no `OnSave` (bytecode na §34). O resto (chunk
  descarregado no meio) ficou como UNKNOWN, improvável.
- **O poste piscando seguia congelando o Tição** por até ~0,75 s, porque a luz velha ficava na
  leitura até a próxima volta. Agora o `check()` pula o poste na hora. O teste exige soltar em até
  uma volta (antes passava por sorte).
- **O sorteio quase nunca achava poste perto:** olhava 12 entradas seguidas da lista da célula
  inteira. Agora:
  - uma volta em fatias (40 por tick) guarda os postes perto;
  - o `NOM.flickerLamp()` varre a lista toda;
  - um teste com 500 postes longe cobre isso.
- **Fogo e lampião entravam no sorteio:** piscavam sem se ver (o jogo reescreve a cor deles), mas
  paravam de congelar o Tição. Agora só poste da rede (`isHydroPowered`).
- **O clarão encurtava o congelamento do cômodo aceso:** o cômodo agora vem antes do clarão. Um teste
  em 16 fases do rodízio pegou o buraco.
- **Chuva sem a semente do mundo:** todo save chovia nas mesmas névoas. Agora sorteia como a preta.
- **Testes que vazavam estado global:** o teto de postes não devolvia o intervalo, e os de debug não
  devolviam `NOM_Storm` e `NOM_LampFlicker`.

## Roteiro de teste no jogo

1. `scripts/dev-sync.sh`, reiniciar o jogo, `-debug`, mod de staging.
2. **Lanterna:** `NOM.setBlackFog()` com a lanterna acesa na mão; esperar uns 10 s perto de um
   Tição. A lanterna deve gaguejar (pisca-pisca, escuro, pisca-pisca) e voltar; o Tição anda no
   escuro.
3. **Poste:** de noite, perto de um poste de rua aceso, `NOM.flickerLamp()` (ou o botão). Na preta
   e na vermelha eles também piscam sozinhos de vez em quando.
4. **Relâmpago:** `NOM.thunder()`. Conferir o clarão e o trovão depois. Na preta, os Tições perto
   param por ~1 s. Sem comando, na preta ou na vermelha, deve vir um a cada 8 a 30 s; na branca
   nenhum.
5. **Chuva:** `NOM.rain()` e uma névoa preta ou vermelha: chove em rampa e para quando a névoa
   acaba. `NOM.rain()` de novo volta pro sorteio de 30%.
6. Se algo não aparecer, procurar `[NOM] poste`, `[NOM] tempestade` e `chuva=` no `console.txt`
   (só com `-debug`).
