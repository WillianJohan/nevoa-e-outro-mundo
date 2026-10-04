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
  common/media/
    lua/shared/NOM_Config.lua      sandbox + constantes
    lua/shared/NOM_Rules.lua       lógica pura (sem API do jogo), testável
    lua/server/NOM_World.lua       flags night/fog, emite eventos
    lua/server/NOM_Variants.lua    marca/desmarca, spawn/despawn de Ecos
    lua/server/NOM_Behaviors.lua   comportamento por variante + noite agressiva
    lua/client/NOM_Atmosphere.lua  clima, som, rádio
    lua/client/NOM_Overlays.lua    sangue/ferrugem locais
    clothing/ textures/ sound/
    sandbox-options.txt
tests/                             asserts de NOM_Rules.lua em lua puro
```

Fluxo: `World` decide o estado → `Variants` marca/desmarca/spawna →
`Behaviors` aplica o comportamento em lotes por tick → cliente só renderiza e
toca som.

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
