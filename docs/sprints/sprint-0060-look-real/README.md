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

## 0060d/e — produto

- **Look limpo** = só o botão/flag (`NOM.lookClean()`). Mudar LookForce **desliga** o limpo.
- **LookForce**: horror soft (roupa legível + FX suave) — **não** é clean.
- Texto do painel alinhado (0060e; antes dizia Force = clean).
- SemRosto sem `NOM_SemRostoEstatica`; KEEP camisa/calça; Sport+White só no limpo.

## I6 — Glitch de tela (modo + intensidade)

Trilha live (sem reload): painel → `NOM.param` → `NOM_PanelParams` → `NOM_ScreenFxRules.channel` → `NOM_FogVignette.write` (`SearchMode.y`) → `mod2/.../screen.frag` `hiss`.

- Teste: `tests/test_glitch_channel.lua` (0% radius=0; 200% radius=2 no mesmo tick; log `[NOM] glitch apply …`).
- **Prints bluefin ainda faltam:** mesmo lugar, intensidade 0% e 200%, + linha do `console.txt`.

## Roteiro

1. `scripts/dev-sync.sh`; reiniciar; só Staging (+ Shader pra I6).
2. Isolamento: botão **Look limpo** → Sport/White + FX off.
3. Produto: LookForce Misaligned **sem** Look limpo → roupa do outfit + vinheta leve.
4. `lookInspect`: `clean=false force=misaligned` (+ peça NOM se houver).
5. I6: névoa + Sem-rosto perto → Glitch original 0% e 200% no mesmo frame → 2 prints + log `glitch apply`.
6. **Não sucesso produto** até print do Johan.
