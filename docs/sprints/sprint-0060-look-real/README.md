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

## 0060f — lote A + I6 + censor/glitch/A′

- **Guarda-roupa** E1–E5 / K1–K5 (`NOM_VariantWardrobe`): roupa vanilla + tint/dirt/blood; `NOM.lookVariant()`.
- **Sem-rosto:** casca-ovo aposentada; remendo 2D A′ (`NOM_SemRostoRosto` + tint por bochecha); censor no osso `Bip01_Head` (fallback prone).
- **I5:** Tição pele carvão lisa; **C2:** manto com alfa 0 em rosto/mãos (K1); K2–K5 sem manto.
- **I7:** assets `*Roupa` / `MantoFx` / Body mortas removidos.
- **I6 glitch:** Opções > Mods > Qualidade (Original/110%); painel debug sobrescreve ao vivo; slider sem sobrepor texto.

## Roteiro (Johan)

1. `git pull` na branch do PR + `scripts/dev-sync.sh` + **reiniciar** (Staging + Shader + Volumétrica).
2. Névoa; `NOM.variant("semrosto")` no mais perto (ou LookForce Wrong).
3. **Censor:** quadrado colado na cabeça em pé, andando, caído/rastejando; zoom in/out e câmera.
4. **A′ rosto:** `lookInspect` → `items=…NOM_SemRostoRosto`, `base=M_ZedBody0N_levelN`, sem casca-ovo; zoom normal + máximo.
5. **Glitch opções:** Opções > Mods > Qualidade → Original / 110%; Aplicar; conferir no jogo. Painel Look sobrescreve ao vivo; valor do slider não cobre a descrição.
6. **Estalador / Carpideira:** `lookVariant` como antes.
7. Proporção Sem-rosto: **ainda espera decisão do Johan** (bíblia §7.3).
