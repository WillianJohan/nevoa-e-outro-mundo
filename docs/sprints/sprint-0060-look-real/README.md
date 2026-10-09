# Sprint 0060 — Look real (roupa/pele uncanny)

| Campo | Valor |
|-------|-------|
| Status | `em teste` (0060f: lote A wardrobe + I6 glitch) |
| Branch | `feature/0060-look-real-ca41` |
| PR | [#16](https://github.com/WillianJohan/nevoa-e-outro-mundo/pull/16) |
| Origem | playtest fail → isolamento OK → produto soft → guarda-roupa vanilla |

## Root cause

Body P&B + strip + ScreenFx/shader (scanline/tear/aberração) + SemRostoEstatica na cara.

## O que foi confirmado

- **Look Clean OK** (Johan): roupa vanilla legível, sem glitch.
- Staging tip = #16; `lookClean` no console com `screenFxClean=true`.

## 0060d/e — produto

- **Look limpo** = só o botão/flag (`NOM.lookClean()`). Mudar LookForce **desliga** o limpo.
- **LookForce**: horror soft (roupa legível + FX suave) — **não** é clean.
- Texto do painel alinhado (0060e; antes dizia Force = clean).
- SemRosto sem `NOM_SemRostoEstatica`; KEEP camisa/calça; Sport+White só no limpo.

## 0060f — lote A + I6

- **Guarda-roupa** E1–E5 / K1–K5 (`NOM_VariantWardrobe`): roupa vanilla + tint/dirt/blood; `NOM.lookVariant()`.
- **I2–I4:** Sem-rosto com sentinela `NOM_SemRostoEstatica` (casca lisa).
- **I5:** Tição pele carvão lisa; **C2:** manto com alfa 0 em rosto/mãos (K1); K2–K5 sem manto.
- **I7:** assets `*Roupa` / `MantoFx` / Body mortas removidos.
- **I6 glitch:** trilha panel → `SearchMode.y` → `hiss`; teste unitário OK; prints in-game com o Johan.

## Roteiro (Johan)

1. `git pull` na branch do PR + `scripts/dev-sync.sh` + **reiniciar** (Staging + Shader).
2. Névoa (`NOM.setFog(true)`); Sem-rosto perto.
3. **Glitch:** painel Look → modo original → intensidade **0%** (print) → **200%** mesmo lugar (print); `console.txt` com `[NOM] glitch apply … intensity=…%`.
4. **Estalador:** `NOM.variant("estalador")` + `NOM.lookVariant()` cicla E1–E5 (bata/pijama/avental…).
5. **Carpideira:** `NOM.variant("carpideira")` + `lookVariant` K1–K5; K1 manto+saia (rosto visível); K2+ vestido/capa sem manto.
6. **Sem-rosto / Tição / Corredor:** `lookInspect` → sentinela / pele carvão / boca; sem Body P&B.
7. Prints à distância normal, FX produto ligado, `lookClean` off.
