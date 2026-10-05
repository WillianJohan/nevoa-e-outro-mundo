# Contraste dos visuais — Plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** As nove texturas do visual dos monstros (sprint 0012) passam a ler de longe, na câmera isométrica e sob o tom escuro da névoa: contraste cheio, formas grandes, poucas cores, brilho puxado pra cima. Mesmos modelos, mesmos itens, mesmos GUIDs.

**Architecture:** Só dados. `scripts/gen_textures.py` troca as funções de desenho dos visuais (as do overlay de tela, sprint 0013, ficam com o gerador próprio e os mesmos bytes). Um teste Python (`tests/test_look_contrast.py`, chamado pelo `run-tests.sh`) mede o contraste de cada textura: desvio da luminância, fração de cinza médio e desvio "de longe" (depois de reduzir a textura 8×), com limite por textura. `scripts/preview_textures.py` monta uma folha de contato (64 px, normal e escurecida/avermelhada como a névoa) em `docs/sprints/sprint-0014-contraste-visual/preview.png`.

**Tech Stack:** Python 3 + numpy + Pillow (já usados pelo gerador), luajit pros testes Lua, bash.

**Spec:** o brief da sprint 0014 (decisão do Johan, 05/10/2026, opção 1: texturas bem mais agressivas nos mesmos modelos vanilla, pra todos os visuais), [README da sprint](README.md), [art-direction.md](../../gdd/art-direction.md), [ADR-012](../../architecture/adr-012-visual-das-variantes.md).

## Global Constraints

- Nada copiado: texturas procedurais e originais; da textura vanilla só tamanho e regiões visíveis do layout.
- Determinismo: rodar o gerador de novo dá os mesmos bytes (visuais e tela).
- Mesmos tamanhos (128 nas peças, 256 nas peles e no `NOM_EcoCinza`), mesmos caminhos, itens, XML e GUIDs; `NOM_VariantLook` intocado.
- Contraste: perto de preto e branco puros, formas ≥ 1/8 da largura, poucas cores, brilho puxado pra cima (a névoa corta 30–50%).
- Comentários e docs em português do Brasil.

## Review Focus

- Textura que o modelo estica (UV da balaclava desconhecido): o padrão tem que valer em qualquer ponto — blocos e faixas, nada posicionado no Sem-rosto. Teste: `far_std` alto no arquivo inteiro.
- Regressão futura pra "lã" (ruído fino que vira cinza de longe): `far_std` pega, mesmo com `std` alto. Teste: `contrast_catches_wool` passa o ruído fino por pixel e espera falha.
- Mudança no gerador que altere os bytes da tela (0013) sem querer: `screenfx_assets_deterministic` continua; os visuais ganham `look_assets_deterministic`.
- PNG com alfa (o `NOM_EcoCinza` é RGBA): a métrica ignora pixel transparente e o teste lê RGBA sem quebrar.
- Cor saturada (ferrugem da venda) cai no "cinza médio" da luminância: o limite de `mid` é por textura, apertado no Sem-rosto (o caso da lã) e folgado onde a cor é o desenho. Teste: a tabela `LIMITS` cobre as 9 e falha se aparecer textura sem limite.

---

### Task 1: Métrica de contraste (teste primeiro)

**Files:**
- Create: `tests/test_look_contrast.py`
- Modify: `run-tests.sh`

**Interfaces:**
- Produces: `metrics(path) -> (std, mid, far_std)`; tabela `LIMITS[nome] = (std_min, mid_max, far_min)`.

- [ ] **Step 1:** escrever o teste: luminância Rec. 601 0..1 dos pixels opacos; `mid` = fração em 0,3 < L < 0,7; `far_std` = desvio depois de média em blocos de largura/8 (do tamanho de uma "forma grande"). Um autoteste `contrast_catches_wool` gera ruído fino por pixel em memória e espera que ele reprove.
- [ ] **Step 2:** `python3 tests/test_look_contrast.py` → FAIL nas texturas da 0012 (Sem-rosto: `far_std` ~0).
- [ ] **Step 3:** ligar no `run-tests.sh` (depois do luajit, antes do build).

### Task 2: Texturas agressivas

**Files:**
- Modify: `scripts/gen_textures.py` (funções dos visuais)
- Regenerate: `mod/42/media/textures/Body/NOM_*.png`, `mod/42/media/textures/NOM/NOM_*.png`
- Modify: `tests/test_look_assets.lua` (`look_assets_deterministic`)

- [ ] **Step 1:** `look_assets_deterministic` (regerar não muda um byte das 9). Roda verde já (o gerador é determinístico): é guarda, não comportamento novo.
- [ ] **Step 2:** reescrever: Sem-rosto em blocos 16×8 preto/branco, faixas de varredura e rasgo horizontal; Estalador porcelana quase branca com rachaduras grossas pretas, venda branco-sujo e ferrugem com contorno preto; Corredor cinza-cinza clara com veias grossas quase pretas, boca vermelho saturado escuro com rasgos pretos e dentes brancos; Carpideira cabelo preto com poucas mechas brancas, pele muito pálida com escorridos e fuligem na região dos olhos (posição lida do layout da pele vanilla, igual no M e no F); Eco quase branco com salpico escuro.
- [ ] **Step 3:** `python3 scripts/gen_textures.py` duas vezes; `./run-tests.sh` → verde; `git diff --stat` mostra só os 9 PNG dos visuais (nenhum da `ScreenFx`).

### Task 3: Prévia

**Files:**
- Create: `scripts/preview_textures.py`, `docs/sprints/sprint-0014-contraste-visual/preview.png`

- [ ] **Step 1:** cada textura reduzida a 64 px, ao lado da cópia com brilho 50% e tom vermelho (multiplica por (0,62, 0,32, 0,32)); rótulo com o nome. Rodar, olhar, ajustar o gerador se algo some.

### Task 4: Docs

- [ ] README da sprint (em teste, critérios com evidência, roteiro), roadmap, art-direction, ADR-012 (consequência), CREDITS (descrições), README raiz (seção in-game, se citar texturas).
