# ADR-001 — Monstros são zumbis existentes marcados

| Campo | Valor |
|-------|-------|
| Status | `accepted` |
| Data | 2026-10-04 |

## Contexto

O PZ não permite criar um tipo novo de criatura por Lua: a IA, o render e a
câmera ficam em Java. O que o Lua alcança é o zumbi existente — stats, sentidos,
outfit, `modData` e reações a eventos.

## Decisão

Estalador, Corredor e Sem-rosto são **zumbis vanilla marcados** com
`modData.NOM_variant`. Ao marcar, os stats originais vão para
`modData.NOM_orig`; ao desmarcar (amanhecer ou fim da névoa), são restaurados.

O sorteio é **preguiçoso**: cada zumbi é sorteado uma vez por período
(`NOM_rolledAt` = id do período) na primeira vez que o loop o processa.

## Alternativas recusadas

| Alternativa | Por que não |
|---|---|
| Spawnar e despawnar cada variante | População artificial, cadáveres somem, mais código de spawn. |
| Java mod | Não suportado no Workshop, quebra a cada patch. |
| Sorteio em varredura no início do período | Zumbi de chunk carregado depois ficaria de fora, e o custo concentra num tick. |

## Consequências

- Zumbi nunca fica preso numa variante: todo caminho de saída restaura `NOM_orig`.
- A densidade de variantes acompanha a densidade de zumbis da região.
- O Sem-rosto pode "ser" um zumbi que o jogador já viu; isso é tratado como
  feature de tom.
