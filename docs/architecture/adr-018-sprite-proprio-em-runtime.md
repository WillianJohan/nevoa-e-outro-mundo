# ADR-018 — Sprite próprio do Outro Mundo criado em runtime a partir de PNG nosso

| Campo | Valor |
|-------|-------|
| Status | `accepted` |
| Data | 2026-10-06 |
| Emenda | [ADR-017](adr-017-outro-mundo-anexado.md): o Outro Mundo passa a anexar também sprites **do mod**, além dos vanilla; o anexo, o registro, o `OnSave`, o corte e a conferência não mudam |
| Sprint | [0035](../sprints/sprint-0035-silent-hill/README.md), [spike](../sprints/sprint-0035-silent-hill/spike-sprite-proprio.md) |
| Evidência | [pz-api-notes §26](pz-api-notes.md#26-sprite-próprio-em-runtime-texturas-do-outro-mundo-sprint-0035) |

## Contexto

O Outro Mundo estilo Silent Hill pede tinta descascando, ferrugem escorrendo e grade metálica. Nada
disso existe entre os sprites vanilla, e o `AGENTS.md` proíbe copiar arte de outros mods: as
texturas têm de sair de script nosso. Até a 0034 a erosão só anexava sprites vanilla pelo nome
(ADR-017), então era preciso um jeito de o jogo conhecer um sprite **nosso** pelo nome.

O spike da 0035 olhou três caminhos no bytecode do B42.21:

- **1a, tile pack do mod:** `pack=` e `tiledef=` no `mod.info`, com `.pack` e `.tiles` gerados em
  Python. Funciona, mas o sprite ganha ID de verdade: o anexo que vazar pro save volta no load
  enquanto o mod estiver instalado, e o número do tiledef pode colidir com o de outro mod.
- **1b, sprite em runtime:** `getSprite(caminho)` cria o sprite a partir de um PNG em
  `media/textures/`, com ID 20000000, que nunca está no `intMap`.
- **Plano B, sprite vanilla tingido por instância:** não existe pelo Lua (`IsoSpriteInstance` não
  tem setter de tinta e o Kahlua não escreve campo Java).

## Decisão

1. **Caminho 1b.** Os PNG ficam em `mod/42/media/textures/NOM/OutroMundo/` e viram sprite no
   cliente por `client/NOM_OwnSprites.lua` (`ensure`, `total`, `missing`). O anexo continua sendo
   `obj:addAttachedAnimSpriteByName(nome)`, como na ADR-017.
2. **Formato:** PNG RGBA **128×256**, quadro inteiro, sem recorte, gerado por
   `scripts/gen_tiles.py` (semente fixa, mesmos bytes a cada rodada). Nome do arquivo
   `NOM_OM_<tipo>_<lado>_<nn>.png`, com `<lado>` `F` (chão, dentro do losango), `W` ou `N` (metade
   da face da parede). O **nome do sprite é o caminho completo**, o mesmo do `getTexture`:
   `media/textures/NOM/OutroMundo/NOM_OM_Tinta_W_03.png`. A lista pura (nome, lado, tipo) fica em
   `shared/NOM_OwnSpriteList.lua`, escrita pelo script.
3. **Registro, por sprite:**
   - `getTexture(nome)` antes; nil pula o sprite e loga uma vez (o `getSprite` de caminho que não
     existe criaria um sprite vazio, sem erro);
   - `getSprite(nome)` cria e põe no `namedMap`;
   - **`setName(nome)` é obrigatório**: sem ele `getParentSprite():getName()` volta nil, o registro
     da ADR-017 nunca acha a instância e o mod não tira o que pôs;
   - flags pelo lado: `FloorOverlay` no chão; `WallOverlay` mais `attachedW` ou `attachedN` na
     parede. São as flags dos decalques vanilla: a profundidade e o lado no recorte da parede de
     canto saem delas, sem PNG de depth.
4. **Quando registrar:** no `OnGameStart` e, preguiçoso, no primeiro `update` com névoa da sessão.
   O `OnMainMenuEnter` marca pra registrar de novo, porque o `namedMap` zera a cada mundo. Custa
   ~280 chamadas ao Java uma vez por sessão.
5. **Save:** o anexo de ID 20000000 que vazar pro save é **descartado no load**, com o mod ou sem
   ele. É mais seguro que os sprites vanilla do Outro Mundo, que ficam pra sempre se vazarem.
6. **Prefixo de limpeza:** `media/textures/NOM/OutroMundo/` entra no `OWN_PREFIXES` junto de
   `floors_burnt_01_`. O `D.own` e o `LoadGridsquare` passam a reconhecê-lo como do mod. Pelo item 5
   o `LoadGridsquare` nunca deveria achar um; a limpeza é defesa contra um ID reaproveitado e custa
   nada.
7. **MP:** nada no servidor. O checksum do jogo só cobre Lua, scripts e animação; cada cliente
   registra os próprios sprites.
8. **Plano B, 1a com os mesmos PNG:** se o teste no jogo mostrar textura ruim (nitidez, mipmap ou
   carga assíncrona), o `gen_tiles.py` empacota os mesmos PNG num `.pack` e num `.tiles`, o
   `mod.info` ganha `pack=` e `tiledef=`, e o `LoadGridsquare` passa a ser a única defesa contra o
   anexo vazado (ele voltaria do save com o mod instalado).

## Consequências

- O Outro Mundo ganha arte própria sem formato binário novo, sem mexer no `mod.info` e sem número
  de tiledef pra colidir.
- O fake de teste (`tests/attached_world.lua`) modela o jogo: o `getSprite` de nome novo cria
  sprite sem nome e sem flag, com ID 20000000; o `addAttachedAnimSpriteByName` só acha o que está
  no `namedMap`; o `getTexture` dá nil pra caminho que não existe; o load descarta o anexo de
  runtime.
- Esquecer o `setName` é o erro mais caro (o mod perderia o controle do que pôs): o registro fica
  num lugar só e o teste cobra.
- **UNKNOWN visual**, pro roteiro do Johan: profundidade e recorte certos, nitidez no zoom 0,5 a
  2,5 e a textura carregada assíncrona saindo vazia no primeiro quadro.
- A coleta vanilla (`forageSystem.getAffinitySpriteNames`) lê os nomes anexados, mas
  `media/textures/NOM/...` não bate com afinidade nenhuma.
- Todo sprite novo do Outro Mundo segue este formato: PNG gerado por script, nome = caminho, lado
  pelas flags, entrada na lista pura.
