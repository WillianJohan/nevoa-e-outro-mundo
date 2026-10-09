# Sprint 0060 — Look real (roupa/pele uncanny)

| Campo | Valor |
|-------|-------|
| Status | `em teste` (0060c: look limpo — pós-fail 0060b) |
| Branch | `feature/0060-look-real-ca41` |
| PR | [#16](https://github.com/WillianJohan/nevoa-e-outro-mundo/pull/16) |
| Origem | playtest fail; prints 03/04 ainda glitch (ScreenFx + silhueta) |

## Root cause (0060)

Body PNGs da 0054 eram **P&B binário**. Strip ADR-012 + corpo nu = grade. Sync OK.

## Fail playtest

- Pós-0060: `03-ainda-listras.png` — manequim P&B + ScreenFx.
- Pós-0060b: `04-vermelho-glitch.png` — Scanlines/tear/aberração (shader) + silhuetas
  sem roupa legível. Damp `0.12` **não** tocava o canal do `screen.frag`.

## O que mudou (0060 → 0060c)

- **0060:** peles midtones + `NOM_*Roupa` + grain/lines baixos.
- **0060b:** sem Body/`NOM_*Roupa`; KEEP corpo; STRIP_HEAD; damp ScreenFx (insuficiente).
- **0060c (look limpo):** com `LookForce ≠ Auto`:
  - overlay grain/lines/vinheta/flash/fogStatic = 0;
  - canal shader blur/radius/desat/darkness/gradient = 0 (solta SearchMode);
  - prova ItemVisual `Tshirt_Sport` + `Trousers_WhiteTEXTURE`;
  - `NOM.lookClean()` + botão no painel.

Tição ainda usa pele carvão (próximo lote se falhar).

## Roteiro no jogo

1. `scripts/dev-sync.sh` nesta branch; reiniciar; **só** Staging.
2. `NOM.panel()` → **Look limpo** (ou LookForce Misaligned) → névoa vermelha.
3. `NOM.lookInspect()`: `skin=nil` + `Tshirt_Sport` + `Trousers_WhiteTEXTURE` + peça NOM.
4. Critério: **sem** scanline/tear/aberração; camisa esportiva + calça branca legíveis.
5. **Não declarar sucesso** até o Johan confirmar com print.
