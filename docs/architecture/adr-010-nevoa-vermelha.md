# ADR-010 — Névoa vermelha: propriedade do evento, sorteada pelo período

| Campo | Valor |
|-------|-------|
| Status | `accepted` |
| Data | 2026-10-05 |
| Emenda | [ADR-006](adr-006-variantes-deterministicas.md) (4º argumento `red` no sorteio) e [ADR-009](adr-009-nevoa-evento-do-mod.md) (`data.fog.red`, comando `fog` com `red`, cor da névoa) |

## Contexto

Decisão do Johan (05/10/2026): a cada evento de névoa, `RedFogChance`% (10) de chance
de vir **vermelha**: sirene própria no lugar da normal, névoa e luz vermelhas, e todo
zumbi (menos o Eco) vira variante, dividido por igual entre os tipos. O sorteio tem
que ser determinístico por período (recarregar no meio não re-sorteia; servidor e
clientes concordam), e o servidor decide e espalha com o comando `fog` que já existe.

O que o bytecode do B42.21 diz ([pz-api-notes §12](pz-api-notes.md#12-névoa-vermelha-sprint-0010)):

- A cor com que a névoa é desenhada é o `COLOR_NEW_FOG` do clima (id 1), lido pelo
  `ImprovedFog` todo frame. O interno dela **nunca** volta sozinho e o `calculate`
  mistura a camada modded no próprio interno.
- A tempestade com névoa liga um override de cor nela todo minuto.
- A cor final de todo `ClimateColor` vai pros clientes no pacote de clima.
- O efeito de tela do modo de busca (a vinheta) não tem cor.

## Decisão

1. **Sorteio puro** em `NOM_VariantRules` (o mesmo `mix` sem operador de bit da
   ADR-006, com sais próprios): `redFog(period, cfg)` = hash do período com
   `RED_SALT` < `RedFogChance` (e `RedFogEnabled`). Função só do número do período.
2. **Decidido na sirene.** A sirene anuncia o período `night + 1`; o servidor
   sorteia (ou usa o forçado do debug), toca a sirene certa (`NOM_SirenRed` ou
   `NOM_Siren`; dedicado: `siren {red}`) e, quando a contagem acaba, abre o evento com
   esse valor (`NOM_FogEventRules.start(..., red)`). Fica em `data.fog.red` no
   `ModData`: recarregar no meio continua vermelha, mesmo que o sandbox tenha mudado.
   Recarregar durante a sirene re-sorteia o mesmo período: dá o mesmo resultado.
3. **Flag.** `NOM_World.setFog(on, red)` guarda `NOM_World.red` (sempre false sem
   névoa) e avisa a borda `"red"` só quando a névoa não mudou junto (debug). O
   `NOM_Fog` manda `fog {on, period, red}` nas duas bordas e pra quem entra; o cliente
   guarda em `NOM_FogState.red`.
4. **Variantes.** `NOM_VariantRules.variant(id, period, cfg, red)`: com `red`, o tipo é
   `KINDS[floor(hash(id, period, SPLIT_SALT)/Q × #KINDS) + 1]` (100% dos zumbis,
   dividido por igual, outro hash pra não correlacionar com a faixa normal); tipo
   desligado devolve `nil` (a fatia não redistribui, como a faixa da ADR-006). O
   forçado do debug e o ID 0 valem como antes; o Eco é excluído por quem chama, como
   antes. Quem chama passa `NOM_World.red` (servidor: grito, Sem-rosto) ou
   `NOM_FogState.red` (quem simula e vê).
5. **Clima** (`NOM_ClimateLook`, servidor, `OnClimateTick`, valor absoluto,
   interpolate 1): rampa `redRamp` de 20 minutos de jogo seguindo `fog and red`.
   - Luz: `NOM_Rules.mix(..., redRamp)` puxa o look da névoa pro `LOOKS.redFog` (tint
     vermelho escuro, dessaturação pra 0). Só com o clima sombrio, como o resto do look.
   - Cor da névoa (`COLOR_NEW_FOG`): `lerp(FOG_COLOR, RED_FOG_COLOR, redRamp)`, com ou
     sem clima sombrio (é o evento), override da tempestade desligado enquanto
     vermelha. No fim, **um minuto escrevendo o vanilla (0.9/0.9/0.95/1) antes de
     desligar a camada**: senão o interno fica vermelho até recarregar.
6. **Vinheta sem cor**: o `SearchMode` não tem canal de cor; fica a mesma da névoa.
7. **Debug:** `NOM_Debug.redFog(true|false)`, mesma porta dos outros comandos.

## Alternativas recusadas

| Alternativa | Por que não |
|---|---|
| Cada processo calcular o vermelho sozinho (sem `red` no comando) | O debug forçado precisaria de outro comando e de reenvio pra quem entra; o brief pede o servidor decidindo e espalhando. O sorteio continua puro, então os dois concordam de qualquer jeito. |
| `red` dentro do `cfg` do sorteio | O `cfg` é o sandbox, montado em vários lugares; o vermelho é estado do evento. Argumento explícito deixa visível quem depende dele. |
| Redistribuir a fatia de um tipo desligado | Mudaria quem é o quê ao ligar/desligar outro tipo; a ADR-006 já escolheu faixa vazia. |
| Sortear o vermelho no `start` em vez da sirene | A sirene tem que saber qual tocar, 30 s antes. |
| Desligar a camada da cor direto no fim | O interno do `COLOR_NEW_FOG` não volta sozinho: a névoa seguinte viria vermelha. |

## Consequências

- Um tipo novo em `KINDS` (Carpideira, sprint 0011) re-divide a vermelha (1/4 cada).
  A faixa normal não muda.
- Com `fogQuality` legado o jogo pode desenhar a névoa sem o `ImprovedFog`; aí só a
  luz fica vermelha (roteiro in-game).
- Save da sprint 0009 com evento aberto: `red` ausente = normal.
