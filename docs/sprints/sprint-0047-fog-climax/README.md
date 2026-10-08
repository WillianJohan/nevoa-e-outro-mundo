# Sprint 0047 — FOG clímax (P0)

| Campo | Valor |
|-------|-------|
| Status | `em andamento` — produto A + C-lite no shader; falta playtest do Johan |
| Branch | `sprint/0047-fog-climax` (saiu da `staging`) |
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
- `FogPockets.java` + uniforms `uPocket`/`uPocketShape`; defaults altura **0,68** / véu **0,32**
  (0047d; 0,45/0,2 viraram overlay no piso).
- Shader: `layerAt` + C-lite (corta peito na base; sobe no bolsão).
- Sync Lua → params 2/3/7/14/15; fallback vinheta sem mod3; `NOM.fogLook()` + botão no painel.
- **Tempero 0047b:** aniso no vento do quadro + ridge → flicker e “bolinhas” no piso (rejeitado).
- **0047c (hotfix):** eixo mundo fixo, warp espacial sem tempo, fbm suave (sem ridge), amp baixa,
  `ROLL_SOFT` 0,20 — estável, mas rasa demais (playtest).
- **0047d (playtest rasa):** altura 0,68… ainda overlay no miolo + rosquinha vermelha (vinheta).
- **0047e (design α):** [fog-viva-integrada-design.md](fog-viva-integrada-design.md) —
  gate ScreenFx ×0,25 sem boost; `FLOOR_MIN` 0,62 flat + HAZE~0,19 + fall 2,1 +
  `FLOW_ADV` 0,45. Playtest Johan: **péssimo** (overcorrection — ver 0047f).
- **0047f (após “péssimo”):** corrige a overcorrection da 0047e:
  - **Diagnóstico:** vinheta ×0,25 + zero cor → vermelha flat; `FLOOR_MIN` 0,62 liso +
    fall 2,1 → sopa chapada no peito; curl/`normalize(vel)` por quadro → smear.
  - ScreenFx tempera de novo (×**0,48** + boost leve 0,12r/0,22b; estática ≤0,08) —
    sem voltar ao donut ×1,45/1,8.
  - Mar gelo seco: `FLOOR_MIN` **0,42** **ondulado** (ruído espacial estável); HAZE 0,32 ×
    haze **0,52** ≈ **0,17**; fall **3,2**; sigma 1,08; amp 0,78; `FLOW_ADV` **0,12**;
    fiapos no eixo mundo (sem `normalize(vel)`).
  - Prioridade mantida: **volume no centro > tela nas bordas**; tela só tempera.
- `./run-tests.sh` verde.

## Ainda falta

- Playtest **0047f** no jogo (branca **e** vermelha; critérios §4 do design); calibrar vs foto/vídeo.
- B' / B só se A+C-lite+Passo 3 falharem no playtest.

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
