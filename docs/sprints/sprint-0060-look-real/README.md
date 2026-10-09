# Sprint 0060 — Look real (roupa/pele uncanny)

| Campo | Valor |
|-------|-------|
| Status | `em teste` (0060d: produto soft pós Look Clean OK) |
| Branch | `feature/0060-look-real-ca41` |
| PR | [#16](https://github.com/WillianJohan/nevoa-e-outro-mundo/pull/16) |
| Origem | playtest fail → isolamento OK (`06-look-clean-OK`) → produto |

## Root cause

Body P&B + strip + ScreenFx/shader (scanline/tear/aberração) + SemRostoEstatica na cara.

## O que foi confirmado

- **Look Clean OK** (Johan): roupa vanilla legível, sem glitch.
- Staging tip = #16; `lookClean` no console com `screenFxClean=true`.

## 0060d — produto

- **lookClean** = flag de debug (`NOM.lookClean()`), não = LookForce.
- **LookForce**: ScreenFx/shader **suaves** (vinheta/grain baixos; `lines=0`; hiss/`radius=0`).
- **Sempre**: sem scanlines; sem tear por chiado do Sem-rosto.
- **SemRosto**: não veste mais `NOM_SemRostoEstatica` (cobria cabeça/corpo).
- Corpo: KEEP camisa/calça vanilla; prova Sport+White só no look limpo.
- Sem Body custom (exceto Tição).

## Roteiro

1. `scripts/dev-sync.sh`; reiniciar; só Staging.
2. Isolamento: **Look limpo** → print sem glitch + Sport/White (já OK).
3. Produto: LookForce Misaligned/Pale/Wrong **sem** Look limpo → roupa legível + vinheta leve, sem TV quebrada / sem estática na cara.
4. `NOM.lookInspect()`: `clean=false force=misaligned` + camisa/calça (+ peça NOM se houver).
5. **Não sucesso** até Johan confirmar print do produto.
