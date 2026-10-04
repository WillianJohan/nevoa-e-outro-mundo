# Arquitetura

| Doc | Assunto |
|-----|---------|
| [adr-001-variantes-por-moddata.md](adr-001-variantes-por-moddata.md) | Monstros = zumbis existentes marcados |
| [adr-002-autoridade-servidor.md](adr-002-autoridade-servidor.md) | Lógica no servidor, cliente só renderiza |
| [adr-003-eco-spawnado.md](adr-003-eco-spawnado.md) | Eco é a exceção: spawnado |
| [adr-004-clima-antes-de-shader.md](adr-004-clima-antes-de-shader.md) | Visual dark via clima, shader é spike |

Design de jogo fica em [../gdd/Overview.md](../gdd/Overview.md). Conflito
entre ADR e GDD: o GDD manda no **quê**, o ADR manda no **como**.

## Estrutura do mod

```
mod/
  42/mod.info
  42/media/
    sandbox-options.txt
    lua/shared/NOM_Rules.lua        lógica pura (sem API do jogo), testável
    lua/shared/NOM_Config.lua       sandbox + defaults
    lua/shared/NOM_World.lua        flags night/fog derivadas do clima vanilla
    lua/shared/Translate/<LANG>/    traduções em JSON (B42.20)
    lua/shared/NOM_EcoRules.lua     elegibilidade do corpo e chave de outfit (puro)
    lua/server/NOM_ClimateLook.lua  clima sombrio (OnClimateTick), só no servidor
    lua/server/NOM_Eco.lua          spawn, morte sem cadáver e amanhecer dos Ecos
    lua/client/NOM_EcoClient.lua    apaga o fantasma do Eco removido (só MP)
    lua/server/NOM_Variants.lua     (sprint 0004+) marca/desmarca variantes
    lua/server/NOM_Behaviors.lua    (sprint 0003+) comportamento
    lua/client/NOM_Atmosphere.lua   (sprint 0005) som de névoa, rádio
    lua/client/NOM_Overlays.lua     (sprint 0005) sangue/ferrugem locais
    clothing/clothing.xml           outfit NOM_Eco (itens vanilla por GUID)
  common/                           exigida pelo B42
tests/                              asserts de lua puro (./run-tests.sh, luajit)
```

Fluxo (tudo no servidor): `World` deriva o estado do clima vanilla →
`ClimateLook` escurece o clima, que o jogo sincroniza → `Variants`
marca/desmarca, `Eco` spawna → `Behaviors` aplica o comportamento em lotes por tick.
O cliente só renderiza e toca som.

## Robustez

- Desmarcar restaura o estado original salvo em `modData` (`NOM_orig`).
- Mod removido do save: zumbis viram vanilla, `modData` órfã é ignorada.
- Loop de comportamento processa zumbis em lotes por tick, não todos de uma vez.
- Teto de Ecos por jogador evita travar servidor em vala comum.

## Testes

- `NOM_Rules.lua` (máquina de estado, sorteio, elegibilidade do Eco) roda no
  `lua` puro do terminal: `./run-tests.sh`.
- In-game: checklist da sprint no modo `-debug` (forçar hora, névoa, spawn).
- MP: servidor local + dois clientes.
