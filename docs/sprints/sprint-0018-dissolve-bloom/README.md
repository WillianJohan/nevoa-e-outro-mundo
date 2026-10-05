# Sprint 0018 — Dissolve e bloom

| Campo | Valor |
|-------|-------|
| Status | em teste |
| Branch | `sprint/0018-dissolve-bloom` |
| Plano | [plan.md](plan.md) |
| GDD | [art-direction.md](../../gdd/art-direction.md#queimar-ao-surgir-e-ao-sumir-sprint-0018), [monsters.md](../../gdd/monsters.md#eco), [atmosphere.md](../../gdd/atmosphere.md#shader-opcional-mod-névoa-e-outro-mundo--shader), [Overview.md](../../gdd/Overview.md#decisões-do-autor) |
| ADR | [ADR-016](../../architecture/adr-016-dissolve-e-bloom.md) (nova; emenda ADR-012, ADR-013, ADR-004); [pz-api-notes §6 (correção) e §17](../../architecture/pz-api-notes.md#17-dissolve-e-bloom-sprint-0018) |
| Base | [spike-dissolve](../spike-dissolve/README.md), [spike-motor-visual](../spike-motor-visual/README.md) (corrigida nesta sprint) |

## Objetivo

A peça do monstro se forma queimando (ruído, borda em brasa) quando o zumbi vira variante e se
desfaz queimando quando ele volta; o Eco queima até a cinza ao morrer, com brasas subindo, e não
deixa corpo; com o mod do shader, luzes fortes ganham bloom, mais forte na névoa. Tudo com opção
do jogador.

Pedido do Johan (05/10/2026): "dissolve" quando o Eco morre (hoje some na hora) e quando o zumbi
vira variante e volta; e bloom.

## Critérios de aceite

- [x] Tempo e limiar do dissolve: faixa `(Alpha − 0,85)/0,15`, entrada, saída, troca no meio a
      partir do limiar atual, morte (queima, fade, segura em 0 até o corpo nascer, teto de 5 s) —
      `tests/test_dissolve_rules.lua` (`dissolve_rules_*`).
- [x] Alpha por quadro na faixa, nunca acima do alfa do jogo (zumbi fora da vista não aparece),
      cada jogador local, teto de 12, fim com callback, limpeza ao sair do mundo, no
      reaproveitamento e no menu, erro da API isolado — `tests/test_dissolve.lua` (zumbi falso com o
      alfa do jogo: `IsoObject.setAlpha(IF)` 0–39, `updateAlpha(IFF)` 79–188,
      `isUpdateAlphaDuringRender` = false, ordem `IngameState.updateInternal` 1067 → 1331).
- [x] Variante: gêmeo com shader na mutação e se forma; no fim desfaz e só então a roupa volta,
      igual; a mesma variante de volta cancela a saída; troca de tipo, morte (loot exato) e
      reaproveitamento na hora; teto na vermelha com o fim ainda em lotes (≤ 20 por tick);
      desligado = sprint 0017 — `dissolve_look_*`, `look_fx_items_exist_in_script` em
      `tests/test_variant_look.lua` (os 34 testes antigos rodam com a opção desligada e passam).
- [x] Peças gêmeas `*Fx` com o mesmo modelo, textura e lugar e `<m_Shader>NOM_Dissolve</m_Shader>`;
      as originais sem shader; casca do Eco com a malha Hazmat e as mesmas máscaras do
      `HazmatSuit.xml` instalado; GUIDs, nomes EN/PTBR e CREDITS — `look_assets_fx_twins`,
      `look_assets_eco_shell`, `look_assets_items_resolve` (12 itens), `credits_*`.
- [x] Shader original com a interface do jogo, sem texto do vanilla, compilando em 330 e na
      reescrita GL 2.1 que o jogo faz — `tests/test_dissolve_shader.lua` (uniforms ⊆ os de
      `skinnedmodel.Shader.onProgramCompiled`, atributos com o `layout` do
      `VertexBufferObject.BeginDraw`, varyings casando, `NOM_BAND` = Lua, sem linha dos
      `basicEffect*.vert/.frag` instalados, `glslangValidator` 330 e 120 com a regex do
      `ShaderUnit.processShaderSyntax`; pula sem o validador).
- [x] O que o motor faz se o shader falhar: documentado pelo bytecode (`ShaderProgram.compile`
      147–308 destrói o programa, `Model.DrawSolid` usa o programa 0) em
      [pz-api-notes §17.1](../../architecture/pz-api-notes.md#171-shader-de-peça); o fallback é a
      opção desligada (peça sem shader), coberto por `dissolve_look_off_plain`.
- [x] Morte do Eco: véu gêmeo e casca pelo `WornItems` (o modelo da animação de morte sai dele
      com `onKillDone`), efeito até o corpo nascer, corpo escondido, brasas; MP sem janela: corpo
      escondido e brasas, com a linha `janela ms=0`; constante da casca; desligado e zumbi comum
      intocados; teto — `tests/test_eco_fx.lua` (`ecofx_*`).
- [x] Brasas pelo overlay da 0013 com ou sem névoa, perto do Eco, encolhendo com o zoom, sem menu,
      somem no fim, teto, quadro sem brasa ainda 1 chamada — `embers_*` em
      `tests/test_screen_fx.lua`; regras em `tests/test_ember_rules.lua`.
- [x] Bloom no `screen.frag` do mod2 pelo canal: escala = Lua, intensidade no marcador
      (`13 + bloom·0,25`), canal tomado fora da névoa só com bloom, solta pro forrageamento, o
      sandbox da vinheta não desliga o bloom, sem o mod2 nada — `shader_marker_matches_lua`,
      `shader_bloom`, `screenfx_rules_channel_bloom`, `vignette_channel_bloom_*`,
      `vignette_bloom_needs_shader_mod`; `shader_compiles` (330) e 120 à mão.
- [x] Opções do jogador: "Dissolve" (ligado) e "Bloom" (1,0, 0–2), EN/PTBR —
      `dissolve_and_bloom_options`, `translations_*`.
- [x] Orçamento — `dissolve_budget`, `embers_cap_and_budget`, `embers_idle_cheap`; tabela no
      [architecture/README.md](../../architecture/README.md#orçamento-por-sistema).
- [ ] O shader compila no jogo e a peça aparece normal com o dissolve ligado — **falta o jogo:**
      roteiro, passo 1.
- [ ] A peça se forma e se desfaz na mutação, a faixa de 0,85 é aceitável — **falta o jogo:** passos 2–3.
- [ ] O Eco queima na morte no solo, sem piscar; a casca cobre o corpo — **falta o jogo:** passo 4.
- [ ] Corpo escondido e janela do MP — **falta o jogo:** passos 5–6.
- [ ] Bloom no jogo, FPS — **falta o jogo:** passo 7.
- [ ] Opções > Mods mostra e aplica "Dissolve" e "Bloom" — **falta o jogo:** passo 8.

`./run-tests.sh`: `total=620 passou=620 falhou=0` (Lua), `contraste total=4 passou=4`,
`build total=25 passou=25`.

**Decisão de arte do Johan pendente:** a casca de cinza do Eco (`NOM_EcoFx.SHELL`, ligada) usa a
malha da roupa de proteção vanilla e muda a silhueta do Eco no segundo da morte. Sem ela
(`false`), só o véu queima e o corpo some em fade. Ver no passo 4 e decidir.

## Roteiro in-game

Jogo em `-debug`, **save descartável**. Console em
`~/.var/app/com.valvesoftware.Steam/Zomboid/console.txt` (Flatpak). Antes:
`scripts/dev-sync.sh` (copia `mod/` e `mod2/`), **fechar e abrir o jogo** (shader novo e mod2
compilam na primeira carga da sessão) e carregar o save. Os passos são os probes 1–5 da
[spike-dissolve](../spike-dissolve/README.md#probes-in-game-johan) adaptados ao código.

1. **O shader carrega (probe 1).** De dia, Spawn Horde com 3 zumbis a ~6 tiles,
   `NOM_Debug.fog(true, true)`, `NOM_Debug.variant("estalador")` num, `("semrosto")` noutro.
   **Esperado:** em ~1 s a venda (peça presa a osso, `_static.vert`) e o rosto de chiado (peça com
   esqueleto, `.vert`) aparecem normais, sem linha com `NOM_Dissolve` e `ERROR`/`Shader` no
   console. **Se** a peça sumir, ficar branca, preta, rosa ou no lugar errado: o shader não
   compilou ou não linkou no driver (copiar as linhas de `Shader` do console). Se só a venda
   falhar, é o `_static.vert`. Contorno imediato: Opções > Mods > "Monstros queimam ao surgir e
   sumir" desligado (as peças voltam sem shader na próxima mutação).
2. **Forma e desfaz (probe 2).** Com o Estalador à vista: `NOM_Debug.variant(nil)` (ou
   `NOM_Debug.fog(false)`). **Esperado:** a venda se desfaz em manchas com borda laranja em ~1 s, o
   corpo fica quase opaco; só então a roupa e a pele de antes voltam. `NOM_Debug.status()` no meio:
   `dissolve=1`. De novo `NOM_Debug.fog(true, true)` e `variant("estalador")`: a venda se forma.
   Sem piscar de volta pro inteiro no meio (confirma que o `OnTick` vem depois do alfa do jogo).
3. **A faixa de 0,85.** Olhar o corpo durante a queima: **decidir se o corpo a 85% é aceitável**
   (o probe 2 da spike, item 4). Andar até o monstro sair da vista: a peça queima no começo do
   fade vanilla (efeito colateral aceito). Névoa vermelha (`NOM_Debug.redFog(true)`) com ~30 zumbis:
   no máximo 12 queimam juntos, o resto troca na hora; anotar engasgo no começo e no fim.
4. **Morte do Eco no solo (probe 3).** À noite, `NOM_Debug.spawnEco()`, matar o Eco.
   **Esperado:** durante a queda, o corpo vira a casca de cinza (roupa de proteção) e queima com o
   véu, borda laranja, brasas e cinza subindo; o que sobra some; nenhum corpo no chão. Console:
   `[NOM] eco: morte com dissolve` e depois `[NOM] eco: corpo escondido, janela ms=N` — **anotar
   N** (a duração da queda; o dissolve leva 1000 + 500 ms: se N for menor, a queima é cortada no
   meio). **Se** o Eco piscar, travar a pose ou ficar sem roupa ao trocar o modelo: o
   `resetModelNextFrame` na queda não serve (registrar; contorno `NOM_EcoFx.SHELL = false` não
   resolve, o véu também troca). **Decisão de arte:** casca sim ou não.
5. **Corpo (probe 4).** Matar um zumbi comum e, com o corpo perto, no console:
   `local b = getPlayer():getCurrentSquare():getDeadBodys():get(0); b:setDoRender(false)`
   (some?) e `b:setDoRender(true)` (volta?). Confirma o esconderijo do corpo do Eco.
6. **MP (probe 3 no dedicado).** Servidor local + cliente. Matar um Eco pelo cliente.
   **Esperado:** brasas no lugar e nenhum corpo; no console do cliente `janela ms=0` (sem queda:
   `dieNetwork`). Se a janela for maior que 0, o cliente tem a queda e a queima também aparece.
   O outro cliente vê as brasas dele (cada um roda o próprio efeito).
7. **Bloom (motor-visual, probe 2).** Só sem ShadowZ, com o mod do Shader ativo. À noite perto de
   poste aceso, farol de carro e fogo. **Esperado:** brilho curto em volta das luzes; na névoa,
   mais forte; na vermelha, avermelhado; a borda da peça queimando também brilha. Anotar o FPS em
   1080p e em 4K com bloom 0 e 2. Forragear: o círculo de busca normal; parar: o bloom volta.
8. **Opções.** Esc > Opções > Mods > "Névoa e Outro Mundo": "Monstros queimam ao surgir e sumir"
   (ligado) e "Bloom (mod do Shader)" (1.0). Bloom 0: some no tick seguinte. Dissolve desligado:
   a próxima mutação é instantânea, com a peça sem shader; matar um Eco: corpo some como antes,
   sem brasa.
9. **Luz da morte (probe 5, opcional).** `local L = getCell():addLamppost(x, y, z, 1, 0.5, 0.1, 4)`
   e `getCell():removeLamppost(L)` meio segundo depois. Aparece? No MP, o outro vê? Decide se a
   morte do Eco ganha um clarão (fora desta sprint).

## Checkpoints

- **04/10/2026** — Sprint aberta pelo pedido do Johan (05/10). Bytecode: falha de compilação do
  shader (`ShaderProgram.compile`, programa 0, sem fallback), reescrita GL 2.1
  (`ShaderUnit.processShaderSyntax`), uniforms e atributos do item-model, `onKillDone` e o
  `WornItems` na animação de morte, `IsoDeadBody.getOutfitName`/`setDoRender`. Plano escrito.
- **04/10/2026** — Regras puras, driver do alfa, opções, gêmeos com shader e o visual que se forma
  e se desfaz, shader `NOM_Dissolve`, morte do Eco com casca e brasas, bloom no mod2. Testes verdes.
- **04/10/2026** — Docs: ADR-016, pz-api-notes §6 (correção) e §17, GDD, orçamento, correção da
  spike-motor-visual, roteiro com os probes. Em teste.

## Aprendizados

- **O modelo da animação de morte não sai da lista de `ItemVisual`.** O `Kill` liga o
  `onKillDone` logo depois do `OnZombieDead`, e daí o `getItemVisuals` do zumbi é refeito do
  `WornItems` a cada chamada. Mexer na lista no `OnZombieDead` não aparece na queda: tem de mexer
  no visual dos itens vestidos.
- **Soltar o alfa no fim da morte traz o zumbi de volta.** O jogo anda o alfa pro alvo da visão a
  cada update: um Eco ainda caindo com o efeito acabado reaparece inteiro. O efeito de morte segura
  o alfa em 0 até o corpo nascer.
- **A reescrita GL 2.1 do jogo é por regex, linha a linha.** No `.frag`, toda linha que começa com
  `in` e termina em `;` vira `varying` (`int k;` vira `varying t k;`), e linha que começa com
  `colour` vira `gl_FragColor`. O teste compila o shader depois da mesma reescrita.
- **`dofile` não registra em `package.loaded`:** um `require` do mesmo módulo depois carrega de
  novo (no teste, dois overlays). Registrar antes de carregar quem dá `require` nele.

## Pendências que a próxima sprint herda

- Tudo do roteiro acima; em especial o shader no driver, o `resetModelNextFrame` na queda, a
  janela de morte (`janela ms=`), e as decisões do Johan: a casca do Eco e a faixa de 0,85.
- Se a janela da queda for menor que 1,5 s, encurtar `NOM_DissolveRules.MS`/`FADE_MS` ou atrasar a
  remoção do corpo no servidor.
- MP sem janela: só brasas. A pele com buracos no corpo parado (spike, abordagem 2) só entra se as
  brasas sozinhas ficarem fracas.
- O corpo do zumbi não dissolve na mutação (o `basicEffect` é fixo; só com Java).
- Bloom de uma passada é curto; se ficar fraco, o bloom por Java (spike-motor-visual) é o próximo
  passo.
- Brasas passam por cima de parede (sem profundidade) e só no jogador 0 da tela dividida.

## Sessões

- 2026-10-05 — abd764e2-7a9a-416b-b9b3-1630ab9e761f — plano, dissolve (regras, driver, gêmeos, shader), morte do Eco, brasas, bloom, docs
