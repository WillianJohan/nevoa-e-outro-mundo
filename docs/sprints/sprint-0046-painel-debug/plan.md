# Plano da sprint 0046: painel de debug novo

**Origem:** pedido do Johan em 2026-10-07: "tem muita coisa lá, e no fim das contas eu não consigo
entender o que tá acontecendo, porque o painel é muito pequeno. Queria poder dar um resize. Faz um
painel bacana, bem descritivo, intuitivo e bonito."

## O que muda

O painel da 0020 era uma grade fixa de 440 px com 12 linhas de botões curtos e uma linha de estado.
O novo:

1. **Janela grande e redimensionável:** 820×620 de partida, mínimo 600×440. O tamanho e a posição
   ficam salvos (`ISCollapsableWindow.RestoreLayout` guarda largura e altura quando `resizable`).
2. **Cabeçalho com o estado em cartões:** hora, dia ou noite, névoa (nenhuma, branca, vermelha ou
   preta, com a cor), monstros na tela e os cheats do jogador (deus, noclip, invisível) acesos.
3. **Seções na lateral:** Névoa, Tempo, Monstros, Tempestade e luz, Jogador, Diagnóstico, cada uma com
   cor própria e o número de ações.
4. **Lista de ações descritiva:** cada ação é um cartão com título, uma descrição do que faz (quebrada
   na largura) e botões à direita. As ações irmãs viram escolhas no mesmo cartão (hora: 00h, 06h,
   12h, 18h, 22h; criar zumbis: 1, 5, 10; transformar: os quatro e desfazer). Os toggles do jogador
   mostram LIGADO/DESLIGADO em verde/cinza. A lista rola com a roda do mouse.
5. **Respostas no próprio painel:** tudo que o debug escreve (`[NOM] debug ...`, local e do servidor)
   passa por `shared/NOM_DebugLog.lua`, que imprime como antes e guarda as últimas 60 linhas. O
   rodapé mostra as mais novas, com o clique ecoado ("› Relâmpago agora"), e um botão Limpar.

## Evidência (vanilla)

- Redimensionar: `ISCollapsableWindow:new` liga `resizable` (`ISCollapsableWindow.lua:395`) e o
  `createChildren` põe as alças (`:33-49`); `ISResizeWidget:resize` respeita `minimumWidth/Height` e
  chama `setWidth/setHeight` do alvo (`ISResizeWidget.lua:9-34`). O painel refaz o leiaute quando
  `width/height` mudam (no `update`), sem depender do `onResize` do Java.
- Leiaute salvo com tamanho: `ISCollapsableWindow:RestoreLayout` só apaga largura e altura sem
  `resizable` (`:336-340`).
- Painel desenhado: `ISPanel:derive/new` (`ISPanel.lua:96`), `drawRect`, `drawRectBorder`,
  `drawText`, `drawTextRight`, `setStencilRect`/`clearStencilRect` (`ISUIElement.lua:459-475,
  1191-1306`, como o `ISScrollingListBox.lua:505-541`); mouse local em `onMouseDown(x, y)`,
  `onMouseWheel(del)`, `getMouseX/Y` e `isMouseOver` (`ISUIElement.lua:339-414`;
  `ISScrollingListBox.lua:347, 577`).
- Medida do texto: `getTextManager():MeasureStringX(fonte, texto)` (`ISButton.lua:233`); fontes
  `UIFont.Small` e `UIFont.Medium` (`ISContextMenu.lua:1109`).
- Som do clique: `getSoundManager():playUISound("UIActivateButton")` (`ISButton.lua:46, 521`).

## Tarefas (TDD)

1. `NOM_DebugLog` (puro, `tests/test_debug_log.lua`) e as mensagens do debug passando por ele.
2. Painel: dados (seções, ações, descrições PTBR+EN), leiaute por tamanho, clique, roda, toggles,
   cabeçalho, rodapé, tecla e leiaute salvo (`tests/test_debug_panel.lua` reescrito, com a regra de
   todo comando do HELP ter botão).
3. README, índice, HANDOFF, `./run-tests.sh`, review.
