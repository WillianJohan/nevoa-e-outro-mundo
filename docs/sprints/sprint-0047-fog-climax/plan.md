# Sprint 0047 — plano (FOG clímax)

Âncora de produto: [proximos-passos-refinamento.md](../../proximos-passos-refinamento.md) §3.4.
Go Johan 2026-10-08.

## Pipeline (fechado)

| Ordem | O quê | Quando |
|-------|--------|--------|
| **A** | Base baixa+densa + bolsões viajantes; sandbox 2 eixos; sync params; fallback sem mod3 | Primeiro — entrega o produto |
| **C-lite** | Dois perfis no `fogLook` (chão denso / alto quase zero na base) | Se A ainda enche peito/câmera |
| **B'** | RT/composite intermediário | Só se C-lite pedir |
| **B** | Fluido 3D de verdade | Só se A+C-lite+B' falharem |

## Produto A — desenho técnico

### Regras puras (`shared/NOM_FogClimaxRules.lua`)

Sandbox → números:

| Opção | Faixa | Default | Papel |
|-------|-------|---------|--------|
| `FogBaseHeight` | 0,2–1,2 andares | **0,45** | Altura da camada base (param 2) |
| `FogPocketAggression` | 0–2 | **1** | 0 = sem bolsões; 1 = raros/brutais; 2 = Pesadelo |

Derivados (regras, não opções separadas):

- `baseHaze` — véu fraco (~0,15–0,25 no default)
- `pocketCoverage` — ~5–12% (raro)
- `pocketScale` — ~40–70 tiles
- `pocketHeight` — ~1,2 (absurdo atual)
- `pocketSpeedMul` — deriva com o vento (1× no default)
- fallback: multiplicadores de vinheta base vs “zona pior”

### mod3

1. **`FogPockets.java`** — ruído de mundo como `FogBanks`, cobertura baixa, escala grande;
   `advance(wind)` + `sample(x,y)` ∈ [0,1]. Puro, testado em Java.
2. **`Flow`** — cria os bolsões junto dos bancos; manda uniforms `uPocket` /
   `uPocketShape` no `bindUniforms` (offset, morph, scale, threshold, soft, boost).
3. **Shader `NOM_VolFog`** — `layerEff = mix(baseLayer, pocketLayer, pocketSample)`;
   véu × `baseHaze` fora do bolsão; no bolsão sobe. Densidade no chão não baixa
   (mar opaco).
4. **Defaults Java** — `PARAM_HAZE` baixo; altura vem do Lua (param 2).

### Lua cliente

- `NOM_FogQualitySync` também empurra param 2 (altura) e 7 (véu) a partir das regras +
  sandbox; pocket height em param 3 (`uParams[0].w`).
- Sem `NOMRender_setParam`: `NOM_ScreenFxRules.layers` usa fallback de vinheta
  (base mais fraca; “pocket” mais forte se amostra local — ou dial único se amostragem
  espacial sem mod3 for cara demais: então base baixa + chance de pulso forte raro
  no cliente, documentado).

### Debug

- `NOM.fogLook()` — imprime altura/véu/agressão atuais; botão no painel.
- Params manuais: `(2,h)`, `(7,v)`, `(3,pocketH)`.

## TDD (ordem)

1. `tests/test_fog_climax_rules.lua` — defaults, Leve/Pesadelo, aggression 0 zera coverage.
2. `tests/java/FogPocketsTest.java` — cobertura rara, anda com o vento, sample ∈ [0,1].
3. `tests/test_fog_quality_sync.lua` — manda params 2 e 7 (e 3) do sandbox.
4. `tests/test_screen_fx_rules.lua` (ou foco) — fallback vinheta base vs agressão.
5. Contrato shader/Java (`test_mod3_depth.py` / flow.sh) — uniforms novos; glslang ok.
6. Traduções PTBR + EN das duas opções + tooltips.

## Fora

Sons II, almas, transform, Carpideira, look, preta aperta, B 3D sem falha de A+C-lite.

## Evidência de API

- Params / EndFrame / Flow / FogBanks: HANDOFF + sprints 0024–0032 / 0026.
- Sandbox options: pz-api-notes (opção desconhecida é pulada).
- Overlay/vinheta sem ZB: ADR-013, `NOM_ScreenFxRules`.
- Noise espacial no shader: extensão do que `FogBanks` / `uDrift` já fazem — spike A
  com constantes espelhadas Java↔GLSL; se divergir no playtest, matar e ficar só no
  boost de densidade na grade (`[HIPÓTESE]` do refinamento §3.4.1).
