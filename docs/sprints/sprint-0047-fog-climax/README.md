# Sprint 0047 — FOG clímax (P0)

| Campo | Valor |
|-------|-------|
| Status | `em teste` — 0047g na staging; looks por cor aprovados (Johan) |
| Branch | `sprint/0047g-fog-primeira` (merge na `staging`) |
| Go | Johan, 2026-10-08 |
| Design | [proximos-passos-refinamento.md](../../proximos-passos-refinamento.md) §3.4 |
| Plano | [plan.md](plan.md) |
| Ref visual | [ref-nevoa-pratica-baixa.png](ref-nevoa-pratica-baixa.png) · [vídeo t=478](https://youtu.be/a-wtJulfhlo?t=478) |

## Por quê

A fog volumétrica de hoje (rolos altos, véu, densidade que abraça tudo) funciona como
espetáculo, mas como *default* atrapalha andar e ver. O clímax de Noise of Mist é a névoa:
**base navegável** (mar baixo no chão) + **bolsões** que matam a visão — exceção, não o estado
base.

## O que entrega (produto A, depois C-lite)

1. **Base baixa e densa no chão** — perfil de altura baixo (~tornozelo/joelho visual); densidade
   alta no piso; véu de fundo fraco. Alvo: §3.4.3a (gelo seco / vapor pesado).
2. **Bolsões viajantes raros/brutais** — poucos, pesados, derivam com vento/`FogBanks`; dentro =
   fog absurda atual; ao sair, volta a base.
3. **Sandbox 2 eixos** — `FogBaseHeight` (altura da base) + `FogPocketAggression` (chance/tamanho/
   intensidade/velocidade dos bolsões, um dial). Presets Leve / Pesadelo.
4. **Cliente** — qualidade e resolução da grade continuam em Opções > Mods.
5. **Sem mod3** — fallback: vinheta/clima mais fraca na base, mais forte no “bolsão” (sem fingir
   volume).
6. **Pipeline** — A → C-lite (dois perfis chão/alto no `fogLook`) → B' só se precisar → **B 3D
   completo fora** até A+C-lite falharem.

## Fora de escopo

Sons II, Estalador clicker, Carpideira Witch/look, transform 100%, almas esqueléticas, aperto da
preta, partículas “descamando”, rastejante. Documentados no refinamento como after-P0.

## O que já entrou (código)

- `NOM_FogClimaxRules` + sandbox `FogBaseHeight` / `FogPocketAggression` (2 eixos).
- `FogPockets.java` + uniforms `uPocket`/`uPocketShape` (produto mantido).
- Shader: `layerAt` + C-lite; sync Lua → params 2/3/7/14/15; fallback vinheta; `NOM.fogLook()`.
- **Look shader** = 1ª 0047 (`b012989`: HAZE 0,18 / fall 8 / sigma 0,9; sem FLOOR_MIN; ScreenFx sem gate).
- **Defaults playtest Johan (0047g), por cor** — sync / `NOM.fogLook()` / `onColorChange`:

  | Param | Branca | Vermelha | Preta |
  |-------|--------|----------|-------|
  | 2 altura | **1,0** (sandbox) | **1,0** | **1,2** |
  | 3 bolsão H | **1,2** | **1,1** | **1,1** |
  | 7 véu | **0,8** | **1,0** | **1,0** |
  | 9 res | **3** | **3** | **3** |
  | 14 cov | **0,1** | **1,0** | **1,0** |
  | 15 boost | **1,1** | **1,0** | **1,2** |

  Branca: sandbox. Vermelha/preta: `lookRed()` / `lookBlack()` fixos.
- Histórico rejeitado: tempero 0047b → 0047c–f. Docs de design α ficam; código do look visual não.
- `./run-tests.sh` verde.

## Ainda falta

- Nada do P0 fog — looks branca/vermelha/preta gravados. Próximo: Sons II (refinamento §3.1).

## Critérios (§3.4.3 / §3.4.3a)

- [ ] Base não engole a câmera; lê-se mar baixo; print bate a ref.
- [ ] Bolsão: visão some ao entrar; contraste &lt; 5 s ao sair; move em 1–2 min.
- [ ] Poucos bolsões vivos; MP: *onde* está denso igual; qualidade por cliente.
- [ ] Sem ZB: ainda dá pra sentir base vs zona pior.
- [ ] FPS jogável no `scale` padrão.

## Roteiro de teste no jogo

1. `scripts/dev-sync.sh` com esta branch no checkout; **reiniciar o jogo**.
2. Ativar **`[STAGING] NOM: Noise of Mist`** + **`[STAGING] … Volumétrica`** (e Shader se quiser).
3. `NOM.fog(true, true)` numa rua aberta.
4. **Base:** câmera livre? fachada/rosto legíveis? mar no chão tipo a foto?
5. **Bolsão:** em 1–2 min parado, um bolsão passa? ao entrar a visão some? ao sair volta?
6. **Sem Volumétrica:** desligar o mod3; ainda há base mais “fina” vs zona pior (vinheta)?
7. Sandbox: baixar `FogBaseHeight` / `FogPocketAggression` e repetir; presets Leve/Pesadelo.
8. Debug: `NOM.fogLook()` (se existir) / `NOMRender_setParam(2, h)` e `(7, v)` pra A/B rápido.
9. Comparar print com [ref-nevoa-pratica-baixa.png](ref-nevoa-pratica-baixa.png).

## Como voltar

- Defaults antigos: altura 1,2 / véu 1 via `NOMRender_setParam(2, 1.2)` e `(7, 1)` (ou sandbox
  FogBaseHeight alto + FogPocketAggression 0).
- Desligar bolsões: `FogPocketAggression = 0`.
