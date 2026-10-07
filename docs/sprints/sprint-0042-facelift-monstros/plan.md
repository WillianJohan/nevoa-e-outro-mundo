# Sprint 0042 — Facelift: os outros monstros em 3D

## Objetivo

Levar o caminho da 0041 (peça estática nossa presa à cabeça, `.x` gerado em Python puro) pros
monstros que têm peça no rosto ou na cabeça. Cada peça conta o que a spec pede (§9):

| Monstro | Hoje (modelo vanilla + textura) | Peça 3D nova | Conta |
|---|---|---|---|
| Corredor | máscara cirúrgica pintada com boca rasgada | boca escancarada larga demais: buraco escuro, lábios rasgados, dentes em volta, rasgos até perto da orelha | a boca que grita |
| Sem-rosto | balaclava inteira pintada de chiado | casca lisa em volta da cabeça inteira, sem nariz, olho nem boca, com o chiado de TV | o rosto que não existe |
| Carpideira | véu de noiva pintado de cabelo | cortina de mechas pretas caindo da cabeça, mais densa na frente (tapa o rosto), três mechas brancas | o luto, o rosto escondido |

Fora: **Eco** (a cinza é camada no corpo todo; peça estática na cabeça não acompanha o corpo, e o
véu já conta "não é mais carne"). **Tição** é da 0043 (teste de IA comparado com a versão por script).

## Evidência (pz-api-notes §32, complemento)

- Peça estática que cobre a cabeça inteira e esconde cabelo e barba: `Hat_CrashHelmetFULL.xml`
  vanilla (`m_Static true`, `Bip01_Head`, `nohairnobeard`, `Hat/Masks`); `Hat_Spiffo.xml` (estática,
  `nohair`).
- Medidas da cabeça (números dos `.x` vanilla, nada copiado):

| Medida | Origem | Masculino | Feminino |
|---|---|---|---|
| alto do crânio | touca de banho | x 0,181 | x 0,176 |
| nuca | touca de banho | z −0,092 | z −0,082 |
| lado do crânio | touca de banho | y ±0,071 | y ±0,066 |
| frente na altura do nariz | máscara de hóquei | z 0,084 em x 0,05 | z 0,086 em x 0,05 |
| testa | máscara de hóquei | z ~0,072 em x 0,12 | z ~0,074 em x 0,11 |
| queixo (embaixo) | máscara cirúrgica | x −0,017, z 0,062 | x −0,007, z 0,064 |
| narina | brinco de nariz | x 0,054–0,062 | x 0,041–0,053 |
| casca da cabeça inteira | capacete fechado | x −0,017–0,179, y ±0,071, z −0,091..0,093 | x −0,014–0,171, y ±0,067, z −0,085..0,088 |

## Decisões (Johan fora; conservadoras e fáceis de voltar)

- **Mesmo item, outro modelo**, como na 0041: GUID, lugar no corpo e Lua iguais; voltar é trocar
  modelo e textura nos dois XML de cada peça (a peça e o gêmeo `Fx`). As texturas antigas ficam
  geradas.
- **Sem-rosto reaproveita a textura de chiado** (`NOM_SemRostoEstatica`): o desenho em blocos vale
  em qualquer UV; o que muda é a forma (ovo liso no lugar da balaclava com feições).
- **Sem-rosto e capacete:** a casca vira estática presa à cabeça e mantém `nohairnobeard`
  (cabelo comprido não fura a casca).
- **Carpideira passa a `nohair`** (como o Spiffo): o cabelo do zumbi sumiria por baixo das mechas de
  qualquer jeito e cabelo comprido furaria a cortina.
- **Corredor mantém `nobeard`** (a barba atravessaria a boca).
- **Texturas novas espelhadas em v** (Boca3D, Cabelo3D), como a da venda: o v virado não muda nada.

## TDD (tests/test_models.py, generalizado por peça)

1. Todas as peças, nos dois sexos:
   - formato;
   - winding do vanilla;
   - malha fechada;
   - cascas viradas pra fora;
   - o gerador é determinístico;
   - até 2500 vértices.
2. Texturas novas espelhadas em v; cada parte cai na cor certa:
   - arame na ferrugem;
   - dente claro;
   - boca e rasgo escuros;
   - lábio vermelho;
   - mecha preta escura;
   - mecha branca clara.
3. Corredor:
   - tudo perto da boca (caixa entre o queixo e a narina, na frente do rosto);
   - a frente em +Z;
   - o buraco é bem mais largo que alto (≥ 2×).
4. Sem-rosto:
   - os pontos medidos da cabeça (alto, nuca, lados, olhos, testa, nariz, queixo, mandíbula) ficam
     todos dentro da casca, com folga;
   - a casca não é enorme (caixa perto do capacete fechado).
5. Carpideira:
   - nada entra no crânio;
   - na frente do rosto as mechas passam na frente do nariz;
   - pelo menos três mechas cruzam o rosto (rosto escondido);
   - três mechas brancas.
6. `test_look_assets.lua`: os modelos próprios novos existem no caminho que o jogo monta;
   tamanho das texturas.
7. `test_look_contrast.py`: limites das texturas novas.
