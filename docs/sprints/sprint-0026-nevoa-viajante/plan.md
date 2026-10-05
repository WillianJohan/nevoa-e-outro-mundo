# Névoa viajante e luz que abre a névoa (mod3) — Plano

**Goal:** A névoa deixa de ser um mar parado. Viaja pelo mapa em bancos levados pelo vento, contorna
prédio, carro e árvore, deixa vácuo atrás deles e abre buracos que vêm e vão. Reage a quem anda, carro,
porta, tiro e explosão. A lanterna e o farol viram um facho visível dentro dela e abrem a névoa onde
batem, como a fumaça do CS2.

**Origem (Johan, 2026-10-05):**
- "Eu queria que ela se comportasse como uma névoa, que vai caminhando pelo mapa, desviando de objeto,
  fazendo vácuos."
- Quer todas as fontes: jogador, zumbis, carros, porta, tiros e explosões. Aceita o custo, desde que
  tenha opção de qualidade.
- "Fazer a luz abrir a fog", "volumétrica 3D parecida com o CS".
- Futuro (fora desta sprint): névoa preta.

**Decisões:**
- **Partículas (bolos de fumaça como imagem) ficaram de fora.** A luz precisa atravessar a névoa ponto a
  ponto, e só o volume do `NOM_VolFog` faz isso. Tudo fica no volume.
- **A simulação continua 2D por andar,** com a altura no shader. Volume por andares fica pra quando
  precisar subir escada.
- **As novidades do núcleo são opcionais e vêm desligadas no `FlowGrid`;** o `Flow` liga. Os 15 testes
  antigos continuam valendo como estão.

## Evidência (bytecode B42.21, `javap`)

- `WorldSoundManager.instance` (estático, final); `soundList` é `public final List<WorldSound>`.
  `WorldSound`: `x`, `y`, `z`, `radius`, `volume`, `life` (int), `sourceIsZombie`, `repeating` (públicos).
- `IsoCell.getVehicles()`: `Set<BaseVehicle>`; `BaseVehicle` é `IsoMovingObject` (`getX/getY/getZ`).
- Lanterna: `IsoGameCharacter$TorchInfo.set(IsoPlayer, InventoryItem)` monta a lanterna com
  `IsoPlayer.getLookVector(Vector2)` (direção), `InventoryItem.getLightDistance()` (alcance, int),
  `getLightStrength()`, `isTorchCone()` e `getTorchDot()` (abertura). O item vem de
  `IsoGameCharacter.getActiveLightItems(ArrayList)`.

## Tarefas

- [x] `FogBanks` (puro): ruído de mundo calibrado pra cobertura (~70%), levado pelo vento médio.
- [x] `FlowGrid`, tudo opcional:
  - `banks`: fora da grade e célula nova vêm dos bancos, não do ambiente;
  - `inertia`: a velocidade é levada por ela mesma (esteira, redemoinho);
  - `stillDecay`: onde o ar para, a névoa se desfaz (vácuo atrás de prédio);
  - `doorPuff`: porta que abre empurra névoa pra dentro;
  - `blast(x, y, r)`: tiro e explosão empurram a névoa pra fora (conserva massa).
- [x] Testes: banco atravessa com o vento; vácuo atrás de prédio; cobertura ~70%; rastro viaja; porta
      sopra pra dentro; explosão abre e conserva; custo.
- [x] `Flow`: liga tudo; vento mais forte com rajada; carros e sons altos; lanternas pro shader.
- [x] `NOM_VolFog`: facho de luz das lanternas (luz espalhada na névoa) e névoa aberta dentro do facho;
      passos do raio pela qualidade; borda da grade sem parede de névoa.
- [x] Qualidade (Opções > Mods, 0 baixa, 1 média, 2 alta) → `NOMRender_setParam(6, q)`; teste Lua.
- [x] Docs, testes verdes, build, merge, push, `dev-sync`.
