# ADR-013 — Efeitos de tela: overlay Lua por padrão, shader original num segundo mod

| Campo | Valor |
|-------|-------|
| Status | `accepted` |
| Data | 2026-10-05 |
| Emenda | [ADR-004](adr-004-clima-antes-de-shader.md) (o override de shader sai do arquivo, como mod opcional) e [ADR-007](adr-007-sem-rosto-e-atmosfera-local.md) (a tela da névoa ganha camadas desenhadas pelo Lua) |

## Contexto

Johan testou a névoa no jogo e gostou ("LINDA"), mas quer um efeito de tela de verdade.
Escolheu a opção 3: (A) overlay Lua como padrão e (B) shader opcional pra quem não usa
ShadowZ. O ShadowZ (Workshop 3800671550), instalado aqui, já substitui
`media/shaders/screen.frag`: prova que o override pega, e que um `screen.frag` no mod
principal brigaria com ele. O que o B42 dá ([pz-api-notes §15](pz-api-notes.md#15-efeitos-de-tela-sprint-0013)):

- `UIManager.render` desenha o mundo antes e depois a lista de elementos de UI em ordem;
  `backMost()` põe o elemento no índice 0 (por baixo de toda a UI).
- Clique, roda e "cursor forçado" só chegam a elemento cujo retângulo contém o mouse.
  O `ISSleepingUI` vanilla é um elemento de 1×1 px que desenha a tela inteira.
- `PZAPI.ModOptions` (B42): opções por máquina, na tela Opções > Mods.
- O shader de tela (`WeatherShader` "screen") compila uma vez por sessão, no primeiro
  mundo; não há uniform de névoa, mas os floats do `SearchMode` chegam ao shader todo
  quadro e, com override e sem `enabled`, ninguém mexe neles (spike do shader).

## Decisão

1. **(A) Overlay no mod principal** (`client/NOM_ScreenFx.lua`, só no cliente): um
   `ISUIElement` de 1×1 px, `backMost`, `setConsumeMouseEvents(false)` e `onMouse*` →
   `false`, criado no `OnGameStart` e tirado no `OnMainMenuEnter`. No `render()`
   desenha no retângulo de tela do jogador 0, lido a cada quadro: grão (4 quadros,
   `drawTextureTiled` com deslocamento aleatório), vinheta que respira (preta; vermelha
   e mais forte na névoa vermelha), linhas de chiado pela distância do Sem-rosto (o
   volume do rádio da sprint 0005) e pulso vermelho no grito da Carpideira
   (`NOM_Carpideira.onScream`). Não desenha com o menu aberto nem morto. As alfas vêm de
   `shared/NOM_ScreenFxRules.lua` (puro); texturas brancas com alfa de
   `scripts/gen_textures.py`, tingidas no desenho.
2. **Só na névoa.** Sem grão à noite: a noite já é a escuridão, e o filme granulado fica
   como a assinatura do Outro Mundo. Custo zero fora da névoa (uma leitura da hora por
   quadro).
3. **Opção do jogador, não do servidor:** `PZAPI.ModOptions` com liga/desliga e
   intensidade 0–2 (`client/NOM_ScreenFxOptions.lua`); sem a API, padrão ligado e 1.
4. **(B) Shader num segundo mod** do mesmo item do Workshop (`mod2/` →
   `Contents/mods/NevoaEOutroMundo_Shader/`, `require=NevoaEOutroMundo`,
   `incompatible=\ShadowZ`):
   `screen.frag` **original**, com a interface do vanilla (uniforms do
   `WeatherShader.onCompileSuccess`, `in vec2 vUV`, `gl_FragColor`) e o comportamento que
   importa refeito (dessaturação do clima, círculo do modo de busca, visão noturna,
   bêbado, óculos, tom de base); na névoa, aberração cromática, grão, distorção e bordas
   desfocadas. Nenhum texto do vanilla no repositório (teste contra o arquivo instalado).
5. **Canal Lua → shader pelo `SearchMode`, com um dono só.** O mod2 traz
   `NOM_ShaderFlag.lua` (`NOM_ShaderMod = true`, no `shared`, que carrega antes do
   `client`). Com a flag, o `NOM_FogVignette` deixa a vinheta de busca e passa a escrever
   o canal: override do `SearchMode` ligado, `enabled` nunca, e todo tick
   `blur` = névoa, `radius` = chiado, `desat` = vermelha, `darkness` = pulso,
   `gradientWidth` = 13 (marcador que o shader confere em `ParamInfo.z·2/ParamInfo.y`).
   Espera o fade do forrageamento acabar antes de tomar, solta zerado quando o jogador
   forrageia ou a névoa baixa. O overlay continua desenhando vinheta, linhas e pulso, e
   deixa o grão pro shader.

## Alternativas recusadas

| Alternativa | Por que não |
|---|---|
| `screen.frag` no mod principal | Briga com o ShadowZ e com qualquer mod de shader; vale só no primeiro mundo da sessão. |
| Gerar o shader no build a partir do `screen.frag` instalado | Não precisou: a reimplementação original cabe e fica sob MIT. |
| Desenhar no `OnPreUIDraw` com `getRenderer():render(...)` | Os dois usos vanilla estão em código desligado (registro comentado); o `SpriteRenderer` não tem sobrecarga de 9 argumentos (a com cor pede um `Consumer` de 10º), e como o Kahlua resolve isso não foi visto. O elemento de UI é o caminho que o jogo usa. |
| Elemento do tamanho da tela | Fica "por cima" do mouse em toda a tela: força o cursor (`isForceCursorVisible`) e depende só do `onMouse*` pra não engolir clique. |
| Sandbox pra intensidade | É efeito de tela de cada jogador; o servidor não tem por que decidir. |
| Canal pelo `DesaturationVal` | Ambíguo (o vanilla dessatura em outros climas) e um número só. |
| Vinheta do `SearchMode` junto com o canal | Os dois querem os mesmos floats; com `enabled` o ramo de busca do shader os consome. |

## Consequências

- Custo ([orçamento](README.md#orçamento-por-sistema)): fora da névoa 1 chamada por quadro;
  na névoa ≤ 4 desenhos (o grão em ladrilhos é uma chamada, ~40 quads no Java a 1080p) e
  ~12 chamadas; com o shader, +11 por tick do canal.
- Só o jogador 0 na tela dividida (como o som e a vinheta).
- Desenhado pela UI: esconder a UI esconde o efeito, e ele anda no ritmo de quadros da UI.
- MP: o mod2 vale pelo que o servidor carrega (lista de mods); por jogador só a intensidade e o
  liga/desliga. No modo do shader o canal também obedece ao sandbox `FogVignette` e é escalado por
  `FogVignetteIntensity` (decisão do admin continua valendo).
- O shader refaz o vanilla nas cores e no tom; os desfoques (óculos, bêbado, busca) usam outro
  padrão de amostras e podem diferir um pouco.
- O shader vale do primeiro mundo carregado até fechar o jogo; ligar ou desligar o mod2
  pede reiniciar. Com ShadowZ junto, ganha quem o jogo carregar por último no mapa de
  arquivos: o outro some. A descrição do mod2 avisa.
- Com o mod2 ativo mas o shader de outro mod vencendo, o canal escreve floats que ninguém
  lê (sem efeito ruim) e o forrageamento continua normal; o grão do overlay some.
- UNKNOWNs do jogo (roteiro da sprint): texturas do mod por `getTexture`, o 1×1 px por baixo
  do HUD de verdade, `PZAPI.ModOptions` aparecendo em Opções > Mods, o shader compilando
  no driver do Johan (passa no `glslangValidator`, 330 e 120).

## Emenda de 2026-10-05 — sprint 0018: bloom e o canal fora da névoa

O `screen.frag` do mod2 ganha bloom de uma passada. A intensidade do jogador (Opções > Mods,
"Bloom") vai na fração do marcador do gradiente (`13 + bloom·0,25`); com bloom > 0 o canal fica
tomado também fora da névoa, sem nada da névoa nele, e solta pro forrageamento como antes. O
overlay ganha uma lista `NOM_ScreenFx.extra` de desenhos por quadro com ou sem névoa (as brasas do
Eco). Detalhe em [ADR-016](adr-016-dissolve-e-bloom.md).

## Emenda de 2026-10-06 — sprint 0035: canal da tontura

Quando o Outro Mundo começa a se espalhar ao vivo (`NOM_FogOverlays.revealStartedAt()`), ~5 s de
tontura por jogador local, desligável em Opções > Mods ("Tontura na transição"; sem os efeitos
de tela não há).

- **Canal:** não sobra float livre. Os cinco que o Lua escreve (`blur`, `radius`, `desat`,
  `darkness`, `gradient`) estão em uso, e `VarInfo.z/w` o jogo nunca escreve
  ([pz-api-notes §15.4](pz-api-notes.md#154-shader-de-tela-e-canal)). A tontura vai na **parte
  inteira do `darkness`** (`VarInfo.y`): `pulso + 4·round(tontura·256)`, com o pulso do grito
  preso em 0..2 no resto. O shader decodifica com `floor(v/4)`; o pulso continua igual.
  Constantes `DIZZY_BASE`/`DIZZY_STEPS` no Lua e `NOM_DIZZY_*` no `screen.frag`, conferidas em teste.
- **Por que o `darkness`:** o jogo grava o valor sem prender (`SearchModeFloat.setAll`) e só o
  `WeatherShader` o lê; o pulso é curto e cabe folgado abaixo de 4. Codificar no marcador do
  gradiente mexeria na conferência de "o canal é nosso".
- **Com o shader:** a cena ondula, desdobra numa imagem dupla leve e turva. Não usa o `DrunkFactor`
  (a bebedeira é estado de jogo). O canal é tomado só pela tontura quando nada mais o pede
  (sandbox `FogVignette` desligado, sem bloom), como o bloom, e solta zerado.
- **Sem o shader:** o overlay soma um pulso na vinheta e uma camada preta leve (+1 desenho).
- **Custo:** zero Java a mais pra decidir (o sinal e a opção são Lua); +1 desenho por quadro sem
  o shader, durante a tontura.
