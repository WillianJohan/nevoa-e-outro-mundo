# Modelo novo do mod: três névoas, folga e facelift

| Campo | Valor |
|-------|-------|
| Status | `aprovado no brainstorming`, falta a revisão do Johan |
| Data | 2026-10-06 |
| Origem | Brainstorming com o Johan ("mudei um pouco meu mindset"), 9 tópicos refinados um a um |
| Substitui | A agenda da sprint 0009/0019 (intervalo depois do fim da névoa) e a 0033 antiga (rosto censurado, que vira parte do facelift) |

## Mindset

A névoa deixa o jogador tenso: ele enxerga um pouco, mas nunca sabe o que vai surgir. Quando ela
acaba, o alívio é tanto que ele aproveita pra sair e explorar, como uma folga. A névoa fica
**frequente** (quase todo dia) e cada tipo tem **uma regra central** diferente, que muda como se joga.

## 1. Identidade das névoas

| | Branca | Vermelha | Preta |
|---|---|---|---|
| Tema | Cegueira (Silent Hill) | O Outro Mundo sangra | A escuridão (Alan Wake) |
| Regra central | Som é tudo: jogador e zumbi enxergam ~4 tiles | Caçada: todo zumbi é variante, gritos chamam horda | Luz é tudo: o Tição congela no facho |
| Ameaça | Zumbis perambulando, variantes raras (14%) | As quatro variantes, 1/4 cada | Só o Tição (todo zumbi vira Tição) |
| Outro Mundo | Erosão, ferrugem, sujeira, pouco sangue | Muito sangue, tentáculos pretos, cinza no ar | Chão queimado, cinzas, brasas apagando |
| Sirene | Normal, melhorada | Bizarra, com gritos | Fora de sintonia |
| Duração | 3–5 h de jogo | 4–6 h | 2–3 h |
| Frequência | o resto (~75%) | 20%, a partir do dia 7 | 5%, a partir do dia 14 |

A branca é o dia a dia, a vermelha é o pico, a preta é rara e temida (a pior, por isso curta).

## 2. Agenda

- **Sorteio do dia:** à meia-noite de jogo o servidor sorteia se o dia tem névoa.
  - A chance começa em **65%** e sobe em linha reta até **85% no dia 60**; depois fica fixa.
  - Se sair, a névoa começa numa hora aleatória do dia.
- **Segunda névoa no mesmo dia:** **15%** de chance. Só vale se começar antes da meia-noite (pode
  terminar depois) e vier depois de **6 h de jogo sem névoa**, pra não estragar a folga.
- **Garantia:** se passarem **2 dias seguidos sem névoa**, o terceiro tem névoa com certeza.
- **Determinismo:** o sorteio usa o número do dia e uma semente do mundo, como a vermelha já faz.
  Salvar e carregar não muda nada.
- **Tipo:** sorteado na hora da sirene.
  - preta: 5% (só a partir do dia 14);
  - vermelha: 20% (só a partir do dia 7);
  - branca: o resto.
  - A curva só mexe na chance do dia, não na proporção dos tipos.
- **Duração:** depende do tipo, com mínimo e máximo de cada um no sandbox.
- **Saves antigos:** a sirene que já estava agendada continua valendo se cair no dia de hoje;
  agendada pra depois, é descartada e o dia segue o sorteio (senão a garantia do 3º dia
  ficava travada; review final da 0033).

**Sandbox (novas ou revistas):**

| Opção | Padrão | O que faz |
|---|---|---|
| `FogDailyChance` | 65 | chance do dia, em % |
| `FogEscalation` | ligada | liga a curva de tensão |
| `FogMaxDailyChance` | 85 | chance no fim da curva |
| `FogEscalationDays` | 60 | dia em que a curva chega ao máximo |
| `FogSecondChance` | 15 | chance da segunda névoa no mesmo dia |
| `FogMinGapHours` | 6 | folga mínima antes da segunda |
| `FogMaxDaysWithout` | 2 | dias seguidos sem névoa antes da garantia |
| `RedFogChance` | 20 | (já existe; o padrão sobe de 10) |
| `RedFogGraceDays` | 7 | (já existe) |
| `BlackFogEnabled`, `BlackFogChance` | ligada, 5 | névoa preta |
| `BlackFogGraceDays` | 14 | carência da preta |
| mínimo e máximo de duração da branca, da vermelha e da preta | 3–5, 4–6, 2–3 | horas de jogo |
| `FogCalmHours` | 2 | duração da calmaria |

`FogEventEveryDays` deixa de ser usado. A subida da vermelha até o dobro no dia 90 (sprint 0019)
sai: a curva agora é só da chance do dia.

## 3. Sirene

- Passa de 30 para **45 s reais**.
- Um som por tipo, inconfundível desde o primeiro segundo: o jogador decide na hora se corre pro
  abrigo ou pega a lanterna.
- Os sons saem do `scripts/gen_sounds.py`. Antes da sprint 0034, o Johan ouve as amostras e escolhe:
  - **branca:** a atual melhorada;
  - **vermelha:** sirene bizarra com gritos;
  - **preta**, entre três conceitos:
    - (a) fita morrendo: desacelera, entorta o tom, falha, entra chiado de rádio e termina num grave arrastado;
    - (b) várias sirenes fora de fase num acorde dissonante que nunca resolve;
    - (c) quase silêncio: zumbido elétrico, rádio fora de sintonia e uma sirene distante tocada ao contrário.
- **Todos parados:** cada névoa sorteia uma direção de onde a sirene "vem".
  - Enquanto ela toca, todo zumbi para em pé, virado pra essa direção, e ignora o jogador, mesmo se apanhar.
  - Quando a névoa começa, todos voltam de uma vez.

## 4. Calmaria

Quando a névoa acaba, por `FogCalmHours` (2 h de jogo) os zumbis comuns ficam mais lentos e com os
sentidos reduzidos. É a janela pra explorar. Depois voltam ao normal, ou aos valores da noite se for
noite. Usa o mesmo caminho dos stats da noite (`NOM_NightRules`), com um degrau a menos.

## 5. Comportamento na branca e na vermelha

- **Visão de ~4 tiles:**
  - O jogo trava o raio de visão do zumbi entre 10 e 20 tiles (bytecode `IsoZombie.updateVisionRadius`).
    Por isso a visão menor usa a cegueira do Estalador (`NOM_VariantAI`): mira em jogador a mais de
    4 tiles sem som é desfeita.
  - A audição fica normal.
  - **Primeira tarefa da sprint:** medir o custo com ~300 zumbis carregados. Plano B: o piso de
    10 tiles com o pior degrau de visão, mostrado ao Johan antes de decidir.
- **Perambular:**
  - De tempos em tempos o servidor manda grupos de 1 a 3 zumbis parados perto de cada jogador
    andarem até pontos aleatórios da região.
  - Nunca vão direto ao jogador: encontro frequente, sem horda.
- **Gritos dos monstros:**
  - Cada variante grita de vez em quando, com intervalo aleatório de alguns minutos de jogo.
  - O som sai da posição dela, e no MP todos ouvem do lugar certo.
  - Não chama horda: isso continua sendo do Corredor e da Carpideira.
- **Gritos de gente:** só ambiente, no jogo de quem ouve, baixos e distantes, a cada 1 a 3 min reais.
- **Crepitar ("radiação, mas não igual"):**
  - Chiado crepitante por baixo do drone atual, na branca e na vermelha.
  - Fica mais forte quanto mais perto o monstro mais próximo, com a mesma conta do chiado do Sem-rosto.
  - Sem o tic-tic de contador Geiger.

## 6. Sonar do Estalador

- O estalo (em média a cada 2 min de jogo) solta um anel que avança **8 tiles**.
- **Visual:**
  - com o mod3, o anel empurra a névoa (fonte radial no `FlowGrid`, como tiro e explosão), abrindo-a
    por um instante e revelando o que estava escondido;
  - sem o mod3, um anel discreto desenhado na tela.
- **Regra (para todos, decidida no servidor):** o anel que passa por um jogador em pé ou andando faz
  o Estalador achá-lo. Agachado e parado, passa.

## 7. Outro Mundo

- **Cobertura:**
  - Todos os tiles carregados ganham o Outro Mundo, não mais o raio de 15 tiles (`NOM_DressingRules.RADIUS`).
  - Chunk novo nasce transformado.
  - O trabalho é dividido por quadro, do mais perto pro mais longe.
  - Continua anexado (ADR-017), tirado antes de todo save.
- **Medição primeiro:** a área fica umas 10× maior; a primeira tarefa mede FPS, memória e tempo de
  save. Plano B: tamanho da tela no zoom atual mais uma margem.
- **Transição escondida:**
  - O mundo vira nos primeiros minutos da subida da névoa, quando ela está densa demais pra ver.
  - Desvira no começo da descida, ainda densa. Nada surge na frente do jogador.
- **Tontura:** junto da transição, ~5 s por jogador.
  - Com o shader (mod2 ou mod3), a imagem turva e ondula.
  - Sem shader, a vinheta pulsa e a tela escurece um pouco.
  - Desligável em Opções > Mods, porque tontura incomoda algumas pessoas.
- **Visual por tipo:** conforme a tabela da seção 1.
  - Os tentáculos e a cinza da vermelha vêm da fila antiga (HANDOFF, "Névoa vermelha estilo Upside Down").

## 8. Névoa preta

- **Escuridão:**
  - O clima é forçado a ficar escuro como noite fechada, mesmo de dia.
  - Sem luz, o jogador enxerga 2–3 tiles.
- **Luzes que contam:**
  - lanterna e farol de carro (o facho, pela direção e distância);
  - luz fixa: poste, lâmpada de casa ligada, fogueira (quem está no raio dela).
  - Isqueiro e fósforo não contam.
- **Tição:**
  - **Quem vira:** todo zumbi vira Tição, e é a única ameaça. Os Ecos ficam fora enquanto durar a preta.
  - **Movimento:** cada um sorteia arrastado ou arrastado rápido.
  - **Sentidos e caça:** enxerga pouco, ouve muito bem e caça ativamente. De tempos em tempos os
    Tições de uma região são puxados na direção dos jogadores, mais forte que a caça da noite.
  - **Visual inicial:** corpo escuro com brasas vermelhas e fumaça, reaproveitando a casca de brasa
    (sprint 0022) e a fumaça do Eco. O facelift refina.
- **A luz congela:**
  - O servidor confere várias vezes por segundo se cada Tição está num facho ou no raio de luz fixa.
  - Iluminado, para no lugar e não ataca. O dano das armas é normal.
  - Uns 0,5 s depois de sair da luz, volta.
- **Lanterna pisca:**
  - De vez em quando, sem gastar bateria a mais.
  - Quem decide é o servidor, igual pra todos no MP.
  - Na piscada, o Tição iluminado solta por um instante.
- **A névoa:**
  - Com o mod3, ela é preta e a luz a empurra: o facho é um vento constante da lâmpada na direção
    que aponta, e o poste empurra pra todo lado.
  - Sem o mod3, névoa escura do clima e vinheta.

## 9. Facelift dos monstros

### Inventário

| Monstro | Quando | O que faz | Visual hoje | O que a peça 3D precisa contar |
|---|---|---|---|---|
| Estalador | névoa | cego, ouvido apurado, estalo vira sonar | atadura manchada e arame nos olhos, pele de porcelana rachada | os olhos fechados à força |
| Corredor | névoa | corre, grita e começa a horda | boca rasgada larga demais, pele cinza com veias | a boca que grita |
| Sem-rosto | névoa | some quando visto, reaparece atrás | cabeça de chiado de TV | o rosto que não existe (com o quadrado censurado) |
| Carpideira | névoa | parada soluçando, grita e caça quem a acordou | cabelo preto embolado no rosto, fuligem escorrendo | o luto, o rosto escondido |
| Eco | noite | alma de um corpo, fraco, some ao amanhecer | cinza e fumaça, véu de fumaça | algo que não é mais carne |
| Tição | névoa preta | congela na luz, caça no escuro | (novo) corpo escuro, brasas, fumaça | brasa viva que a luz apaga |

### Como as peças são feitas

- `scripts/gen_models.py` roda o **Blender 5.2** (Flatpak `org.blender.Blender`, já instalado) sem
  janela e monta cada peça presa aos ossos do esqueleto do jogo.
- O script **lê** o esqueleto da instalação local do jogo na hora de gerar. Nenhum arquivo do jogo
  entra no repositório.
- A peça entra como item de roupa do mod, igual às texturas de hoje.
- **Evidência pendente pro spike:** o formato de modelo que o B42 aceita e como o item de roupa
  aponta pro modelo, com arquivo e linha do vanilla.

### Ordem

1. Spike: uma peça (atadura com arame do Estalador), caminho completo até o jogo.
2. Os outros monstros.
3. Teste de IA 3D no Tição, com um modelo aberto que rode na RTX 4070 de 12 GB (Hunyuan3D-2 mini
   ou Stable Fast 3D; o TRELLIS oficial pede 16 GB), comparado com a versão por script.
4. O rosto censurado do Sem-rosto: quadrado na tela sobre a cabeça, que borra o que está atrás e
   chia como TV. É um passe do mod3, escondido pela parede (era a 0033 antiga).

**Regra do repo:** modelo gerado por IA é exceção ao "tudo gerado por script nosso". Só entra com uma
ADR nova e a licença do modelo conferida.

## 10. Fila de sprints

| Sprint | Entrega |
|---|---|
| 0033 | Ritmo novo: sorteio diário, tipos com duração, sirene de 45 s com todos parados, calmaria |
| 0034 | Sons: sirenes escolhidas na escuta, gritos dos monstros e de gente, crepitar |
| 0035 | Equilíbrio: visão de ~4 tiles e perambular, com medição de custo |
| 0036 | Outro Mundo por chunk, transição escondida, tontura, visual da branca |
| 0037 | Sonar do Estalador |
| 0038 | Névoa preta I: escuridão, Tição, luz que congela, lanterna piscando |
| 0039 | Névoa preta II: névoa preta que a luz empurra (mod3) e Outro Mundo queimado |
| 0040 | Vermelha nova: tentáculos e cinza no ar |
| 0041–0044 | Facelift: spike, outros monstros, teste de IA no Tição, rosto censurado |

Cada sprint segue o fluxo do AGENTS.md: branch, plano com TDD, testes verdes, merge, sync e teste no jogo.

## 11. Testes e erros

- **Regras puras em `lua/shared`, testadas com luajit:**
  - sorteio do dia, curva, segunda névoa, garantia, tipo e duração;
  - calmaria;
  - geometria do facho (ângulo e distância) e raio de luz fixa;
  - tempo e alcance do anel do sonar;
  - escolha dos grupos que perambulam.
- **Java (`FlowGrid`):** testes da fonte radial do sonar e do vento da luz.
- **Desempenho é critério de aceite:**
  - 0035: custo da cegueira com ~300 zumbis;
  - 0036: FPS, memória e tempo de save com o Outro Mundo cheio;
  - 0038: custo da checagem de luz.
- **Regras de sempre:**
  - o servidor decide e quem simula aplica;
  - toda chamada de API com evidência;
  - texto por chave PT-BR e EN;
  - nada do mod3 derruba o jogo (captura `Throwable`, loga e se desliga).

## Fora deste modelo

- Corpo inteiro novo (silhueta própria): continua fora do escopo.
- Rádio de bolso, sinalizador e afins: recusados antes, continuam recusados.
