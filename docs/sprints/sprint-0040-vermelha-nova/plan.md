# Sprint 0040: vermelha nova (plano)

Spec: [§1, §7 e §10](../../superpowers/specs/2026-10-06-modelo-novo-design.md). Na tabela do §1, o
Outro Mundo da vermelha é "muito sangue, tentáculos pretos, cinza no ar". O sangue de parede já
existe. A fila antiga (HANDOFF, "Névoa vermelha estilo Upside Down") detalha:
- tentáculos pretos orgânicos em parede e chão, pelos anexos da 0023, com textura procedural nossa;
- esporos e cinza flutuando;
- NÃO deixar tudo vermelho.

Decisões tomadas pelo agente (Johan descansando; "escolha o conservador, fácil de mudar"),
registradas aqui e no README.

## Tarefa 1: texturas de tentáculo

No `scripts/gen_tiles.py`, no FIM de `KINDS` (as antigas saem com os mesmos bytes):
- `Tentaculo_F`: uma massa escura com um buraco no chão, de onde saem 3 a 5 tentáculos que se
  arrastam e enrolam na ponta;
- `Tentaculo_W` e `Tentaculo_N`: 2 a 4 tentáculos subindo do rodapé pela parede, com ramos finos
  (veias) e uma mancha úmida em volta.

Visual: tubo que afina até a ponta, com gomos (anéis), quase preto com reflexo vermelho-escuro e
brilho molhado pequeno, sombra no chão ou na parede. A paleta continua dessaturada (o teste de
saturação vale).

**Testes:** `test_om_tiles.py` (tipos novos, cobertura, escuro: luminância média baixa, e o
gerador determinístico); `test_own_sprite_list`.

## Tarefa 2: tentáculos no Outro Mundo da vermelha

`NOM_DressingRules`:
- parede: o tipo `tentacle` entra nas faixas da vermelha, fora (0,15) e dentro (0,15). O sangue
  continua o mais comum fora;
- chão: manchas de tentáculo (ruído numa rede de `TENTACLE_CELL` tiles, `TENTACLE_SPOT` dos tiles
  da mancha), por cima do chão de baixo, antes da ferrugem e da rachadura. Vale também na grama
  (bicho saindo da terra, como a cinza da preta);
- branca e preta não mudam.

**Testes:** `test_dressing_rules` (vermelha tem tentáculo no chão e na parede, em manchas, também
em piso natural; branca e preta sem tentáculo).

## Tarefa 3: cinza no ar

Hoje as lascas e a cinza sobem do que o Outro Mundo vestiu (`NOM_FlakeRules`). Na vermelha entra
uma segunda fonte, o ar: pontos de cinza e esporo nascem soltos em volta do jogador, a meia altura,
e flutuam devagar pra qualquer lado, com vida longa e fade lento.
- `NOM_FlakeRules.air(state, rate, x, y, z, dt, rand)`: nasce até `AIR_MAX` vivas no ar, dentro de
  `AIR_RADIUS`, no andar do jogador; não anda o relógio (o `step` anda).
- `NOM_Flakes`: só na vermelha, com o mesmo ritmo das lascas (densidade e efeitos de tela). A
  posição é a da última leitura das fontes, sem ida a mais ao Java.

**Testes:** `test_flake_rules` (nasce no ar, perto, no andar, flutua sem subir rápido, teto
próprio); `test_flakes` (só na vermelha, respeita os efeitos de tela, orçamento igual).

## Fora

- Tentáculo animado (mexendo): sprite parado, como a brasa da 0039.
- Luz fria pelo clima: a vermelha já tem o visual de clima dela; mexer nisso fica pro Johan.
