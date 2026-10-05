# Sprint 0022 — Brasa no corpo inteiro

| Campo | Valor |
|-------|-------|
| Status | em teste |
| Branch | `sprint/0022-brasa-corpo-inteiro` |
| Plano | [plan.md](plan.md) |
| GDD | [art-direction.md](../../gdd/art-direction.md#o-corpo-inteiro-em-brasa-sprint-0022) |
| ADR | [emenda da ADR-016](../../architecture/adr-016-dissolve-e-bloom.md#emenda-de-2026-10-05--sprint-0022-o-corpo-inteiro-em-brasa); [pz-api-notes §17.5](../../architecture/pz-api-notes.md#175-casca-no-zumbi-vivo-sprint-0022) |
| Base | [sprint 0018](../sprint-0018-dissolve-bloom/README.md) (dissolve, casca do Eco, brasas) |

## Objetivo

Quando o zumbi vira monstro, o corpo inteiro queima: uma casca de carvão e brasa cobre o zumbi
todo e se desfaz em ~1 s revelando o monstro embaixo, com brasas subindo; quando volta, a casca
se forma por cima do monstro, a troca acontece embaixo dela e ela se desfaz revelando o zumbi
comum.

Pedido do Johan (05/10/2026), depois de confirmar no jogo que a peça queima com a borda laranja
na mutação e na volta e que o Eco queima na morte: "o personagem inteiro em brasa".

## Critérios de aceite

- [x] Casca `Base.NOM_Brasa`: malha Hazmat vanilla pelo nome, sem máscara, textura de carvão e
      brasa original (gerada, determinística), shader `NOM_Dissolve`, `base:zeddmg`, sem
      `BloodLocation` nem defesa; GUID, nomes EN/PTBR e CREDITS — `look_assets_ember_shell`,
      `look_assets_items_resolve` (13 itens), `look_assets_deterministic`, `look_assets_guids_unique`,
      `credits_*`, `translations_*`; contraste em `tests/test_look_contrast.py`.
- [x] Mutação: o monstro já está embaixo (pele, peça **sem** shader, roupa escondida) e a casca
      entra inteira (alfa > 0,97) e se desfaz; sai no fim, monstro fica, corpo nunca abaixo da
      faixa de 0,85 — `ember_mutation_shell_burns_off`.
- [x] Volta: a casca se forma (alfa começa < 0,9) com a peça ainda lá; a troca só no fim do
      "in", com a casca ainda na lista; a casca se desfaz e sai; roupa igual à de antes, mesmos
      objetos e ordem — `ember_revert_cover_swap_reveal`.
- [x] A mesma variante no meio da volta: a casca se desfaz de novo e o monstro fica; depois sai
      normalmente — `ember_leave_cancelled_by_same_look`.
- [x] Morte no meio (mutação ou depois da troca da volta): loot e vestidos exatos de um gêmeo
      que nunca foi variante, lista sem item do mod, efeito parado; fogo e cliente de MP sem
      loot inventado — `ember_dead_mid_mutation_loot_exact`, `ember_dead_after_swap_no_loot`,
      `ember_dead_fire_and_mp_client` (o jogo falso imita `DoZombieInventory`,
      `WornItems.setItem` multi-item, `FireCheck` e `DeadZombiePacket`, sprint 0016).
- [x] Reaproveitamento no meio: casca e efeito saem na hora — `ember_reuse_mid_effect_clean`.
- [x] Névoa vermelha: exatamente 6 cascas (`SHELL_CAP`), os seguintes pelo gêmeo da 0018 até o
      teto de 12, o resto na hora; o fim em lotes (≤ 20 por tick) e nada sobra —
      `ember_red_fog_cap`.
- [x] A casca de uma volta que ainda queima não entra na lista guardada da 0016 se a variante
      voltar — `ember_shell_not_kept_as_hidden_clothes`.
- [x] Nunca em jogador reanimado — `ember_skips_reanimated_player`.
- [x] Zumbi fora da vista (`getTargetAlpha(0) = 0`, bytecode `IsoObject.getTargetAlpha(I)` 0–14):
      sem brasa (o overlay desenha na tela sem visão nem parede e o revelaria) e sem casca (não
      prende vaga); vai pelo caminho da 0018, na mutação e na volta —
      `ember_unseen_zombie_no_shell_no_burst`.
- [x] Erro da API no driver do alfa no meio: o fim roda mesmo assim e a casca sai —
      `dissolve_api_error_still_calls_done`, `ember_shell_removed_on_dissolve_error`.
- [x] Brasas no pé do zumbi, uma no começo da mutação e uma no começo da volta, pelo
      `NOM_Embers` (teto dele) — `ember_bursts_at_each_transition`.
- [x] Opção "Brasa no corpo inteiro" (ligada, EN/PTBR, falsa com o "Dissolve" desligado);
      desligada no meio, a casca acaba e nenhuma nova; desligada = sprint 0018 exata (os 43
      testes antigos do visual rodam sem ela) — `body_embers_option`, `ember_option_off_mid_effect`,
      `ember_off_is_sprint_0018`.
- [x] Nada pela rede nem pro save; nenhum efeito de combate — bytecode em
      [pz-api-notes §17.5](../../architecture/pz-api-notes.md#175-casca-no-zumbi-vivo-sprint-0022)
      (leitores de `IsoZombie.itemVisuals`, `getBodyPartClothingDefense` 40–80 pula item sem
      `BloodLocation`); `sendClientCommand`/`sendServerCommand` explodem no jogo falso.
- [x] Orçamento — `ember_budget`; tabela no
      [architecture/README.md](../../architecture/README.md#orçamento-por-sistema). Status do
      debug com `cascas=N` — `debug_status_counts_shells`.
- [ ] A casca aparece e queima no jogo, sem piscar, revelando o monstro — **falta o jogo:**
      roteiro, passos 1–2.
- [ ] A volta: a casca cobre e a troca não aparece — **falta o jogo:** passo 3.
- [ ] Pele, cabelo ou roupa atravessando a malha sem máscara; silhueta aceitável — **falta o
      jogo:** passos 1–3 (decisão de arte do Johan).
- [ ] Horda na vermelha sem engasgo — **falta o jogo:** passo 4.
- [ ] Opção em Opções > Mods — **falta o jogo:** passo 5.

`./run-tests.sh` (com a `main` da 0020): `total=700 passou=700 falhou=0`, `contraste total=4 passou=4`,
`build total=25 passou=25`.

## Roteiro in-game

Jogo em `-debug`, **save descartável**. Console em
`~/.var/app/com.valvesoftware.Steam/Zomboid/console.txt` (Flatpak). Antes: `scripts/dev-sync.sh`
e **fechar e abrir o jogo** (textura e item novos). Opções > Mods: "Monstros queimam ao surgir
e sumir" e "Brasa no corpo inteiro" ligados.

1. **Mutação.** De dia, Spawn Horde com 3 zumbis a ~6 tiles, `NOM_Debug.fog(true, true)`,
   `NOM_Debug.variant("estalador")` num. **Esperado:** em ~1 s o zumbi inteiro aparece coberto
   de carvão com rachaduras laranja (a silhueta da roupa de proteção), que se desfaz em manchas
   com borda laranja, revelando o Estalador (pele de porcelana, venda) já pronto; brasas sobem do
   pé. `NOM_Debug.status()` logo depois: `cascas=1 dissolve=1`; depois de 1 s: `cascas=0
   dissolve=0`. Nenhuma linha com `ERROR` e `NOM_Brasa` ou `Couldn't find item Base.NOM_Brasa`.
   **Se** a casca não aparecer e o zumbi trocar na hora: copiar o console. **Se** ficar
   rosa/branca: a textura não carregou (`media/textures/NOM/NOM_Brasa.png`).
2. **Malha.** No meio da queima, parar o jogo (Esc) e olhar de perto: pele, cabelo ou roupa
   furando a casca? A silhueta mais larga no segundo da queima incomoda? **Decisão de arte do
   Johan.**
3. **Volta.** Com o Estalador à vista: `NOM_Debug.variant(nil)` (ou `NOM_Debug.fog(false)`).
   **Esperado:** a casca se forma por cima do monstro em ~1 s (brasas sobem), e em seguida se
   desfaz revelando o zumbi comum com a roupa dele; a troca nunca aparece. No meio da volta,
   `NOM_Debug.variant("estalador")` de novo: a casca se desfaz e o Estalador fica. Matar um zumbi
   no meio da queima: o corpo e o loot são os de um zumbi comum, sem "Casca de brasa".
4. **Horda.** `NOM_Debug.redFog(true)` com ~30 zumbis à vista. **Esperado:** no máximo 6 queimam
   inteiros (só os que estão à vista; atrás de parede, sem casca nem brasa), ~6 queimam só a peça, o resto troca na hora (`cascas≤6 dissolve≤12` no status);
   anotar engasgo no começo e no fim (`NOM_Debug.fog(false)`).
5. **Opções.** Esc > Opções > Mods: "Brasa no corpo inteiro" (ligada). Desligada: a próxima
   mutação é a da sprint 0018 (só a peça queima). "Monstros queimam…" desligado: troca na hora,
   sem casca.

## Checkpoints

- **05/10/2026** — Sprint aberta pelo pedido do Johan (05/10). Bytecode: leitores de
  `IsoZombie.itemVisuals`, `getBodyPartClothingDefense` e o som de armadura (item sem
  `BloodLocation` é pulado). Decisão: casca no zumbi vivo pela lista de `ItemVisual`, peça sem
  shader embaixo (o Alpha é um só). Plano escrito.
- **05/10/2026** — Item, textura, opção e traduções; `client/NOM_EmberShell.lua` e o
  `NOM_VariantLook` (mutação, volta, cancelamento, morte, reaproveitamento, teto, brasas).
  Testes verdes.
- **05/10/2026** — Docs: emenda da ADR-016, pz-api-notes §17.5, arte, orçamento, roteiro. Em teste.
- **05/10/2026** — Review: brasa e casca só em zumbi à vista (o overlay revelaria quem está
  atrás da parede); o fim do dissolve roda também no erro da API (a casca sai); merge da `main`
  (sprint 0020).

## Aprendizados

- **O Alpha é um só por zumbi:** todo item com o shader do dissolve no mesmo zumbi queima com o
  mesmo limiar. Dois efeitos em sentidos opostos (casca sumindo enquanto a peça se forma) não
  existem sem um segundo shader; aqui a peça vai sem shader quando há casca.
- **Item na lista do zumbi vivo vira loot no solo:** o `DoZombieInventory` roda antes do
  `OnZombieDead` e faz item de toda a lista. Qualquer coisa só visual na lista tem de sair do
  `WornItems` e do inventário na morte, inclusive quando o módulo que a pôs já esqueceu o zumbi
  (fase da casca depois da troca).
- **A lista guardada da 0016 guarda tudo que está na lista:** um visual nosso que esteja lá
  quando a variante começa volta como "roupa" no fim. Tirar antes do `hide`.

## Pendências que a próxima sprint herda

- Tudo do roteiro acima; em especial a malha sem máscara (atravessa?) e a decisão de arte da
  silhueta.
- Brasas: o teto de 4 do overlay é dividido com a morte do Eco; numa horda as brasas da mutação
  podem ocupar as vagas e um Eco morto no mesmo segundo sai sem brasa.
- Só o jogador 0 conta como "à vista" (como o overlay da 0013): na tela dividida, o zumbi que
  só o jogador 1 vê muda pelo caminho da 0018.
- Se a casca Hazmat ficar ruim, a próxima opção é um modelo próprio (fora do escopo: sem modelo 3D
  novo até agora, art-direction).

## Sessões

- 2026-10-05 — abd764e2-7a9a-416b-b9b3-1630ab9e761f — plano, casca de brasa (item, textura, opção, módulo, VariantLook), docs
