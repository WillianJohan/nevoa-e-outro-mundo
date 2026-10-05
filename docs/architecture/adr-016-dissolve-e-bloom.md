# ADR-016 — Dissolve pelas peças com shader próprio e o Alpha como limiar; bloom no shader de tela

| Campo | Valor |
|-------|-------|
| Status | `accepted` |
| Data | 2026-10-05 |
| Emenda | [ADR-012](adr-012-visual-das-variantes.md) (a peça da variante ganha um gêmeo com shader e entra/sai queimando), [ADR-013](adr-013-efeitos-de-tela.md) (o canal do `SearchMode` leva a intensidade do bloom e pode ficar tomado fora da névoa), [ADR-004](adr-004-clima-antes-de-shader.md) (shader novo por peça, sem sobrescrever nada do vanilla) |

## Contexto

Pedido do Johan (05/10/2026): um *dissolve* (limiar sobre ruído, borda brilhando, o do tutorial
clássico de Unity) quando o Eco morre (hoje some na hora), quando o zumbi vira variante e
quando volta. E **bloom**. Duas spikes estáticas mostraram o caminho sem Java
([spike-dissolve](../sprints/spike-dissolve/README.md),
[spike-motor-visual](../sprints/spike-motor-visual/README.md)):

- O `clothingItem` aceita `<m_Shader>`: o jogo cria um shader **novo** pelo nome, lendo
  `media/shaders/<nome>[_static].vert` e `<nome>.frag` do mod
  (`ClothingItemAssetManager.onFileTaskFinished` 170–173 → `PopTemplateManager.addClothingItem`
  100–157 → `ShaderManager.getOrCreateShader` 86–110). Não sobrescreve nada.
- Não há uniform de tempo nem float por peça. O único canal Lua → shader de peça a cada
  quadro é o **`Alpha` do personagem**, por jogador (`setAlpha(pn, a)` no `OnTick`).
- O corpo usa sempre o `basicEffect`. O cadáver é sprite de atlas: o shader de peça não roda
  nele.
- Falha de compilação: o `ShaderProgram` destrói o programa e a peça desenha com o programa 0
  (`Model.DrawSolid` não confere). O motor não tem fallback.
- O `screen.frag` do mod2 (ADR-013) já é nosso: bloom de uma passada cabe nele.

## Decisão

1. **Shader `NOM_Dissolve`** (`.vert`, `_static.vert`, `.frag`), código original com a
   interface do item-model (atributos pelo índice, paleta de 60 ossos, os uniforms que o Java
   manda). Ruído procedural do `texCoords`, borda laranja somada depois da luz. O limiar é
   `(Alpha − 0,85) / 0,15`: o corpo (`basicEffect`) fica a no mínimo 85% enquanto a peça se forma.
2. **Gêmeos `*Fx`.** As peças das variantes e o véu do Eco ganham um gêmeo com `<m_Shader>`, e
   as originais ficam sem. A opção do jogador "Dissolve" (Opções > Mods, ligada) escolhe qual
   vestir. Desligada = sprint 0017 exata. É também o fallback se o shader não compilar no
   driver de alguém.
3. **`client/NOM_Dissolve.lua` dirige o Alpha** no `OnTick`: `min(efeito, alfa do jogo)` pra
   cada jogador local (quem não está à vista continua sumindo), teto de 12 efeitos (o resto é
   instantâneo), limpa no reaproveitamento, no menu e quando o zumbi sai do mundo. Regras
   puras em `shared/NOM_DissolveRules.lua`.
4. **Variante:** o `put` veste o gêmeo e dissolve pra dentro; o fim da variante dissolve pra
   fora e só então faz o `strip` (a roupa volta). A mesma variante pedida de novo no meio
   cancela a saída. Troca de tipo, morte e reaproveitamento continuam instantâneos. Os efeitos
   nascem nos lotes do `NightStats` e duram o mesmo tempo: os `strip` continuam espalhados.
5. **Morte do Eco** (`client/NOM_EcoFx.lua`): o `OnZombieDead` começa o efeito "death" (queima,
   fade, e segura o Alpha em 0 enquanto o Eco morto tiver square) e as brasas
   (`client/NOM_Embers.lua`), e enfileira o zumbi. No **tick seguinte**, cópias novas
   (`instanceItem`) da cinza, do véu gêmeo e de uma **casca** (malha Hazmat vanilla com as
   máscaras do `HazmatSuit.xml`, cinza do mod, shader) entram no **`WornItems`** (com
   `onKillDone` o modelo da queda sai dele) e `resetModelNextFrame`. No tick seguinte porque, no
   solo, o `OnZombieDead` do servidor roda depois do nosso e limpa inventário e `WornItems` (sem
   loot, ADR-003); a outra saída, o servidor pular a limpeza quando o dissolve do cliente está
   ligado, amarraria a regra do servidor a uma opção de cliente. Nada vai pro inventário. O
   corpo que nasce fica com `setDoRender(false)` e o `WornItems` limpo até o servidor tirá-lo. A casca está atrás de
   `NOM_EcoFx.SHELL` (decisão de arte do Johan pendente). Cliente de MP: sem janela de
   animação (`dieNetwork`), só brasas e o corpo escondido.
6. **Bloom** no `screen.frag` do mod2: claro da cena num anel de 16 amostras, mais forte e com
   limiar mais baixo na névoa, avermelhado na vermelha. A intensidade do jogador (Opções >
   Mods, 0–2) vai na fração do marcador do gradiente (`13 + bloom·0,25`); com bloom > 0 o
   canal fica tomado também fora da névoa, sem nada da névoa nele, e solta pro forrageamento.

## Alternativas recusadas

| Alternativa | Por que não |
|---|---|
| `<m_Shader>` direto nas peças originais | Sem fallback: shader que não compila no driver deixaria a peça quebrada pra sempre. |
| Pele com buracos trocada em quadros (spike, abordagem 2) | Um reset do modelo por passo; não escala pra névoa vermelha e não serve pra mutação (a pele de antes é qualquer uma das vanilla). |
| Fade puro por alfa | Lê como "sumiu", não como queimar. Fica só como o fim da morte. |
| Mod Java (ZombieBuddy) pra dissolver o corpo inteiro | Instalação manual por jogador e quebra a cada patch; o dissolve das peças já sai sem Java. |
| Luz laranja (`addLamppost`) na morte | Não se sabe se fica local no MP (spike, probe 5). Fora. |
| Bloom em FBOs por Java | Mesmo custo do Java; o de uma passada é o protótipo que decide se precisa. |

## Consequências

- Custo: por efeito, por tick, 1 + 2·P chamadas (P = jogadores locais); zero sem efeito. Brasas:
  ≤ 4 + 2·mortes + partículas desenhadas por quadro, zero sem brasa. Canal do shader: +11 por
  tick também fora da névoa quando o bloom está ligado. Bloom: 16 amostras por pixel na tela.
- Com o shader, a peça também queima quando o zumbi sai da vista (o fade vanilla passa pela
  faixa de 0,85). Fica como comportamento.
- O corpo do zumbi não dissolve na mutação (o `basicEffect` é fixo); a pele e a roupa trocam de
  uma vez, no começo da mutação e no fim do desfazer.
- A casca muda a silhueta do Eco no segundo da morte; um corpo de Eco que escapasse da remoção
  levaria a casca e o véu gêmeo pro save (como já levaria a cinza e o véu).
- UNKNOWNs (roteiro da sprint): o shader compilando no driver, o `resetModelNextFrame` durante
  a animação de morte, a janela de morte no cliente de MP, o corpo escondido pelo
  `setDoRender`, a casca cobrindo o corpo, o bloom no FPS em 4K.

## Emenda de 2026-10-05 — sprint 0022: o corpo inteiro em brasa

Johan viu a peça queimar no jogo (mutação e volta) e o Eco queimar na morte, e pediu "o
personagem inteiro em brasa". O corpo continua no `basicEffect` (sem Java, spike-motor-visual):
a técnica é a **casca da morte do Eco aplicada ao zumbi vivo** ([sprint 0022](../sprints/sprint-0022-brasa-corpo-inteiro/README.md)).

1. **Casca de brasa** `Base.NOM_Brasa`: malha Hazmat vanilla pelo nome, **sem máscara** (o buraco
   da queima mostra o monstro embaixo; a do Eco esconde o corpo de propósito), textura de carvão
   e brasa do `gen_textures.py`, `<m_Shader>NOM_Dissolve</m_Shader>`, em `base:zeddmg` e sem
   `BloodLocation` (nenhum efeito de jogo: pz-api-notes §17.5).
2. **No zumbi vivo, pela lista de `ItemVisual`** (como as peças desde a 0012), não pelo
   `WornItems` (que é o caminho do morto). `client/NOM_EmberShell.lua` veste, desfaz e tira; o
   `NOM_VariantLook` decide quando.
3. **Um Alpha por zumbi.** Todo item com shader no zumbi lê o mesmo limiar: a casca e o gêmeo da
   peça não andam juntos em sentidos opostos. Com casca, a peça é a **original sem shader**.
   Mutação: troca na hora embaixo da casca, casca em `"out"` (1 → 0). Volta: casca em `"in"`
   (0 → 1), troca (`strip`) no fim, casca em `"out"`. A mesma variante de volta no meio da
   volta: `"out"` de novo, do limiar atual. Recusado um segundo shader com o limiar invertido
   (casca some enquanto a peça se forma): mais um programa pro driver compilar sem fallback,
   por um efeito que a casca já cobre.
4. **Teto:** `SHELL_CAP = 6` cascas dentro do teto de 12 efeitos. Na horda, os 6 primeiros da
   passada queimam inteiros, os 6 seguintes só a peça (0018), o resto na hora; os lotes do
   `NightStats` continuam espaçando o começo e o fim.
5. **Brasas** (`NOM_Embers.burst`, teto de 4 do overlay) no pé do zumbi no começo de cada
   transição com casca.
6. **Morte e reaproveitamento:** a casca sai da lista, do `WornItems` e do inventário (o
   `DoZombieInventory` do solo já a teria feito item); o loot fica o do zumbi vanilla. Inclusive
   depois da troca da volta, quando o `VariantLook` já não guarda o zumbi.
7. **Opção:** "Brasa no corpo inteiro", sub-opção do "Dissolve", ligada. Desligada = sprint 0018.

Consequências: a casca muda a silhueta por ~1 s (a Hazmat é mais larga); sem máscara, pele ou
roupa podem atravessar a malha (roteiro); a primeira mutação de uma sessão compila o mesmo
`NOM_Dissolve` de antes (nenhum shader novo). Custo: pôr com casca ≤ 22 + 3·N chamadas uma vez,
cobrir ≤ 12, trocar embaixo e revelar ≤ 14 + 2·N, mais o driver do alfa de sempre.

