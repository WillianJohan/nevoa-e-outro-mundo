# Design — fog viva integrada (implementação 0047e+)

| Campo | Valor |
|-------|-------|
| Status | **Decisão PO fechada** — implementar sem nova aprovação do Johan; playtest depois |
| Data | 2026-10-08 |
| Autor | PO (agente) |
| Âncoras | agent-store `internal/fog-viva-pesquisa.md` + `fog-viva-auditoria.md`; [proximos-passos-refinamento.md](../../proximos-passos-refinamento.md) §3.4 |
| Playtest | store `playtest-vermelha-rasa-centro.png`; [ref-nevoa-pratica-baixa.png](ref-nevoa-pratica-baixa.png) |
| Branch alvo | `sprint/0047-fog-climax` (continua 0047; não abre sprint nova) |
| Implementador | bluefin (0047e nesta branch) |

> Só design. Código noutro worker. Johan autorizou agentes a decidirem e implementarem; ele só playtesta.

---

## 1. Problema (5 linhas)

1. Com Volumétrica+ScreenFx, a leitura é **rosquinha**: miolo transparente, bordas densas — prioridade **tela > volume**.
2. No miolo só conta o raymarch: HAZE×scale ≈ **0,09** no chão (metade do pré-0047) + rolos × `fd` + fluido que **escava** perto do jogador → mar some.
3. Nas bordas ganha a **vinheta** (`vigBase` × **1,45** na vermelha / ×**1,8** na preta) + estática/scanlines — flat de overlay, não extinção world-space.
4. Subir `layer`/altura (0047d) engorda envelope; **não** enche optical depth se o piso ainda depende de `fd` oco.
5. Flicker/bolhas (0047b) = detalhe reancorado em vento por frame; qualquer “vida” nova **não** pode tocar `uDrift.zw` no domínio do chão.

---

## 2. Approaches (trade-offs)

### Approach α — Inverter tela→volume + piso world-space (recomendada)

**O quê:** (1) Gate/cortar vinheta (e atenuar estática) com mod3 ativo; (2) densificar HAZE/`baseHaze` até HAZE×scale chão ~0,16–0,22; (3) camada de chão em `densityLook` com piso mínimo **sem** apagar quando `fd` cava; (4) só depois: curl/advecção estável pela grade + rampa de obstáculo.

| Prós | Contras |
|------|---------|
| Ataca a hipótese raiz A/B da auditoria em 1 toggle + dials já existentes | Calibração A/B no jogo ainda necessária (números-alvo são faixas) |
| Alinha 1º+2º da pesquisa; cabe na 0047 agora | Sem física 2,5D ainda — cascata “transborda muro” fica parcial |
| Risco baixo de flicker se não mexer em aniso/`uDrift.zw` | Sem mod3 o fallback continua overlay (já aceito §3.4) |

### Approach β — Só engordar shader (HAZE/C-lite/sigma/amp) sem tocar ScreenFx

**O quê:** Subir HAZE, baixar `fall`, subir `sigma`/piso de `rollTop`, eventualmente encolher `uChars`.

| Prós | Contras |
|------|---------|
| Mudança só no mod3 | **Não mata o donut vermelho** — vinheta ×1,45 continua ganhando as bordas |
| | Olho ainda lê “filtro” na vermelha mesmo com miolo melhor |
| | Descarta lição TLOU2 / pesquisa §2.7 |

### Approach γ — B' RT / 2,5D / froxel agora

**O quê:** FBO intermediário, shallow layer `h`/`H`, ou volume 3D.

| Prós | Contras |
|------|---------|
| Cascata/luz rich no longo prazo | Fora do critério “0047 agora”; atrasa playtest |
| | B só se A+C-lite+detalhe estável falharem (decisão §3.4.4 + pesquisa §6.3º) |

**Descartadas β e γ para esta entrega.** β não inverte prioridade; γ é later.

---

## 3. Decisão PO (recomendada) — passos ordenados

**Adotar Approach α.** Prioridade explícita: **volume world no centro > ScreenFx nas bordas.** Vida = detalhe estável (pesquisa 2º), não overlay nem bolsão como remendo da base.

### Passo 0 — Prova rápida no jogo (opcional, 1 sync)

Se o bluefin quiser validar a cadeia antes de calibrar números: com Volumétrica ativa, forçar `vignette → 0` (ou ×0,2) e tirar print da mesma rua vermelha. Esperado: donut some; miolo ainda ralo → confirma A/B e segue Passo 1–2.

### Passo 1 — Matar a vitória do screen-space (obrigatório primeiro)

Arquivo: `mod/42/media/lua/shared/NOM_ScreenFxRules.lua` (+ consumo em `NOM_ScreenFx.lua` se o gate não estiver nas rules).

- Se `NOMRender_isActive` (ou equivalente já usado no mod):  
  - **vinheta:** `vigBase → 0` **ou** multiplicador ×**0,2–0,3** (preferência PO: ×0,25; zero se ainda ler rosquinha).  
  - **Não** aplicar o boost vermelha/preta (`×1,45` / `×1,8`) em cima desse fallback — o boost só faz sentido sem volume.  
  - **Estática / scanlines (`fogStatic`):** cortar pra ~**≤0,05** com mod3 (ou off); chiado não pode ser a “textura da névoa”.
- Sem mod3: manter ScreenFx atual (fallback §3.4.1).
- **Não** densificar vinheta pra “tapar” miolo.

### Passo 2 — Mar no chão world-space (pesquisa 1º / auditoria 1+2)

Arquivos: `mod3/42/media/shaders/NOM_VolFog.frag`, sync Lua `NOM_FogClimaxRules` / params (`PARAM_HAZE` = 7, altura = 2).

1. **HAZE efetivo no chão:** alvo **HAZE × hazeScale ≈ 0,18–0,20** fora do bolsão (faixa auditoria 0,16–0,22; preferência centro **0,19**).  
   - Ex.: manter `HAZE` const 0,28 e subir `baseHaze`/param 7 pra ~**0,50–0,55**, **ou** `HAZE` 0,40 × scale ~0,48 — escolher um eixo e documentar no commit.  
   - Termo **liso** + `exp(-k·hz)` — risco baixo de bolha.
2. **Floor layer no `densityLook`:** parcela de densidade no hz baixo **com piso mínimo independente de `fd`** (ex. `floorMin * exp(-10*hz)` + `fd` só nos tufos/rolos). Escavação do fluido = clareira local, **não** buraco no miolo da tela.
3. **C-lite `fall`:** de 2,6 → **2,0–2,2** (preferência **2,1**) — um pouco mais peito sem sopa; **não** subir altura base primeiro (0047d já mostrou que altura sozinha falha).
4. **Altura base:** manter ~**0,68** (0047d) até o miolo opaco fechar; só então A/B fino vs ref.
5. **`sigma`:** +0,1 se optical depth ainda fraca depois de HAZE+floor (teto ~1,2); vigiar engolir câmera.
6. **Piso do amp em `rollTop`:** constante 0,72 → ~**0,85** (opcional, depois de floor); **proibido** ridge / aniso em `uDrift.zw`.
7. **`uChars`:** só se o miolo oco for o tile do player; reduzir raio ou suavizar com cuidado (névoa no corpo = regressão).

### Passo 3 — Vida estável (pesquisa 2º) — depois do mar opaco

Só quando Passo 1+2 já dão miolo opaco sem donut:

- Curl / warp / fiapos dirigidos por **`nomFlowVel`** (vel da grade), potencial em mundo + tempo lento (`MORPH`).
- Rampa por distância a sólido (`wu` / flags 0032 / `gLow`/`gTree`): densidade na **base** do obstáculo (cascata visual), não só elevar `rollTop`.
- **Proibido:** reancorar eixo/amplitude em `uDrift.zw` por frame; subir `SWIRL_ADV` amarrado ao vento; flow-map dual-buffer global (pulse 0027).
- Opcional: exportar pressão/`p` pro pile-up (pesquisa D5/D6) se já houver canal — senão heurística de vel atual basta nesta fatia.

### Passo 4 — Bolsão intacto como exceção

- Coverage/boost de pocket **não** remendam a base.
- Bolsão continua absurdo local (~10% cov); contraste base↔bolsão ≤ 5 s (§3.4.3).
- Cor vermelha/preta continua via clima (`uFog.yzw`); **sem** path raymarch separado por cor.

### Ordem de merge / sync

1. Passo 1 (ScreenFx gate) + Passo 2 mínimo (HAZE + floorMin) → sync → print branca **e** vermelha.  
2. Ajuste C-lite/`sigma`/amp se preciso.  
3. Passo 3 (curl estável) em commit seguinte se 1+2 já passaram critérios de miolo.  
4. **Não** abrir B' / 2,5D / B 3D nesta fatia.

---

## 4. Critérios de sucesso jogáveis

### Branca (e base em geral)

- [ ] **Mar no piso:** miolo da tela opaco rente ao chão (vs `ref-nevoa-pratica-baixa.png`); não “vidro no centro”.
- [ ] **Sem rosquinha:** bordas não são o lugar mais denso por vinheta; fiapos vêm do volume, não de `NOM_Vignette.png`.
- [ ] **Câmera livre:** fachada/rosto legíveis; objetos altos furam o mar (C-lite).
- [ ] **Contorno:** névoa abraça o pé de cerca/árvore/ Degrau; sem fumaça fantasma atravessando casa.
- [ ] **Sem flicker/bolhas:** 10–20 s de câmera/movimento — padrão não “teleporta”; sem bolhas da 0047b.
- [ ] **Bolsão:** ao entrar, visão some; ao sair, volta o mar baixo — contraste imediato.

### Vermelha (e preta no eixo vinheta)

- [ ] **Não lê filtro flat:** cor vem do clima no volume; **não** de vinheta vermelha saturada + scanlines dominando.
- [ ] Mesmo miolo opaco da branca (raymarch idêntico); diferença = cor/clima + tempero ScreenFx **fraco**, não donut ×1,45.
- [ ] Estática ≤ limiar do Passo 1 — chiado de presença, não textura da fog.

### Regressões que matam o PR

- Flicker/bolhas de volta; sopa no peito/câmera; vinheta forte com mod3; bolsão usado como base; névoa vanilla religada.

---

## 5. Fora de escopo (esta fatia)

| Item | Por quê |
|------|---------|
| **B 3D** / froxel / fluido 3D GPU | Later — só se A+C-lite+Passo 3 falharem “gelo seco” |
| **B'** RT intermediário | Só se Passo 2 pedir e FPS permitir; não bloquear 1+2 |
| **2,5D shallow `h`/`H`** | Later (pesquisa 3º) |
| **Sons II**, Estalador rítmico, Carpideira Witch/look | §3.1–3.2 — depois do P0 fog |
| **Almas / transform universal / preta terror** | §3.9 / aperto preta — depois |
| **Soft particles em massa** | Complemento later; núcleo = raymarch |
| **Path raymarch separado vermelha** | Cor já é clima; gap = overlay |
| **Sandbox redesign completo** | Números finos ok; eixos novos só se já previstos na 0047 |

---

## 6. Checklist de implementação (bluefin)

### Arquivos

| # | Arquivo | Ação |
|---|---------|------|
| 1 | `mod/.../NOM_ScreenFxRules.lua` | Gate: se Volumétrica/`NOMRender_isActive` → vinheta ×0–0,3; **sem** ×1,45/1,8; estática ≤0,05 |
| 2 | `mod/.../client/NOM_ScreenFx.lua` | Garantir que o gate chega no draw (não só comentário “fallback”) |
| 3 | `mod3/.../shaders/NOM_VolFog.frag` | HAZE efetivo chão ~0,18–0,20; `floorMin` independente de `fd`; `fall` 2,0–2,2; opcional sigma/amp; Passo 3 curl/`nomFlowVel` |
| 4 | `mod/.../NOM_FogClimaxRules.lua` (ou sync de look) | `baseHaze`/param 7 alinhado ao alvo HAZE×scale; altura base ~0,68 |
| 5 | Testes Lua/shader existentes + asserts de rules ScreenFx | Cobrir gate mod3 e que vermelha não multiplica vinheta com volume |
| 6 | `docs/sprints/sprint-0047-*/` + HANDOFF se a sprint exigir | Nota 0047e: prioridade volume > tela; link este design |

### Params / consts (alvos)

| Dial | 0047d | Alvo 0047e |
|------|-------|------------|
| ScreenFx vignette @ mod3 | ~0,28 × (1+0,45r) | **~0–0,08** efetivo (gate) |
| ScreenFx static @ mod3 | ~0,14 | **≤0,05** |
| HAZE×hazeScale no chão | ~0,09 | **0,18–0,20** |
| C-lite `fall` | 2,6 | **2,0–2,2** |
| `FogBaseHeight` / param 2 | 0,68 | **manter** até miolo fechar |
| `sigma` | 1,05 | **1,05–1,20** se preciso |
| `rollTop` const | 0,72 | **~0,85** opcional pós-floor |
| Pocket cov/boost | 0,10 / 1,2 | **não usar** pra tapar base |
| Aniso / `uDrift.zw` | vetado 0047d | **continua vetado** |

### Não mexer

- Reancorar detalhe em `uDrift.zw`; ridge/pow agressivo; `SWIRL_ADV`×vento frame; densificar só vinheta; `PARAM_VANILLA_FOG`; `MAX_A`/passos como 1º dial; bolsão como remendo do miolo.

### Verificação

```bash
./run-tests.sh
# depois: scripts/dev-sync.sh na branch 0047; restart jogo; prints branca+vermelha mesma rua
```

Critério de pronto pra handoff ao Johan: checklist §4 branca+vermelha; vídeo curto sem flicker; comparação lado a lado com `ref-nevoa-pratica-baixa.png`.

---

## Veredito em uma frase

**Na 0047e: primeiro desarmar ScreenFx com mod3, depois encher o mar world-space no miolo (HAZE + floorMin), depois vida por curl/grade — volume no centro manda; tela só tempera; B 3D fica pra depois.**
