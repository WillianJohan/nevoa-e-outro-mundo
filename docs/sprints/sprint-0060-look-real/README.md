# Sprint 0060 — Look real (roupa/pele uncanny)

| Campo | Valor |
|-------|-------|
| Status | `em teste` (0060b: pivot pós-fail) |
| Branch | `feature/0060-look-real-ca41` |
| PR | [#16](https://github.com/WillianJohan/nevoa-e-outro-mundo/pull/16) |
| Origem | playtest fail (`look-fail-playtest`); print pós-0060 ainda listrado |

## Root cause (0060)

Body PNGs da 0054 eram **P&B binário**. Strip ADR-012 + corpo nu = grade. Sync OK.

## Fail playtest pós-0060

Johan: `03-ainda-listras.png` — manequim P&B listrado + ScreenFx. Midtones + `NOM_*Roupa`
**não** fecharam o critério. Hipótese ativa: `setSkinTextureName` Body do mod (UNKNOWN/RGB)
+ strip ainda leem como manequim; Lines do ScreenFx pintam listra horizontal.

## O que mudou (0060 → 0060b)

- **0060:** peles midtones + `NOM_*Roupa` + grain/lines baixos + contraste `SKIN` mid.
- **0060b (pivot):** sem `skin` Body em estalador/corredor/semrosto/carpideira; sem
  `NOM_*Roupa` no look; **KEEP** camisa/calça vanilla; só `STRIP_HEAD`; ScreenFx damp
  `0.12` se `LookForce ≠ ""`; `NOM.lookInspect()` + botão no painel.

Tição ainda usa pele carvão (próximo lote se falhar).

## Roteiro no jogo

1. `scripts/dev-sync.sh` nesta branch; reiniciar; **só** Staging.
2. `NOM.panel()` → Look → Misaligned (ou Pale/Wrong/Patient).
3. `NOM.lookInspect()` (ou botão): deve mostrar `skin=nil` (ou vanilla) e camisa/calça + peça NOM.
4. Critério: **pessoa com roupa vanilla + peça do monstro**, não checker/listras P&B.
5. **Não declarar sucesso** até o Johan confirmar com print.
