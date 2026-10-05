# Arquitetura

| Doc | Assunto |
|-----|---------|
| [adr-001-variantes-por-moddata.md](adr-001-variantes-por-moddata.md) | Monstros = zumbis existentes marcados (mecanismo substituído pela ADR-006) |
| [adr-002-autoridade-servidor.md](adr-002-autoridade-servidor.md) | Lógica no servidor, cliente só renderiza |
| [adr-003-eco-spawnado.md](adr-003-eco-spawnado.md) | Eco é a exceção: spawnado |
| [adr-004-clima-antes-de-shader.md](adr-004-clima-antes-de-shader.md) | Visual dark via clima, shader é spike |
| [adr-005-quem-simula-aplica.md](adr-005-quem-simula-aplica.md) | O servidor decide, quem simula o zumbi aplica (emenda a ADR-002) |
| [adr-006-variantes-deterministicas.md](adr-006-variantes-deterministicas.md) | Variante = função do ID do outfit e da noite (substitui o mecanismo da ADR-001) |

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
    lua/shared/NOM_NightRules.lua   degraus de velocidade/sentidos, perfil, caça (puro)
    lua/shared/NOM_NightStats.lua   aplica stats noturnos em lotes (onde o zumbi é simulado)
    lua/server/NOM_Players.lua      jogadores do lado do servidor (solo e dedicado)
    lua/server/NOM_Night.lua        decide a noite, caça e lanterna; avisa os clientes
    lua/client/NOM_NightClient.lua  cliente de MP segue a flag e aplica os stats
    lua/shared/NOM_VariantRules.lua sorteio determinístico da variante, cooldown do grito (puro)
    lua/shared/NOM_VariantAI.lua    Estalador cego e estalando, Corredor visto (onde o zumbi é simulado)
    lua/server/NOM_NightCount.lua   número da noite (ModData global), do Eco e das variantes
    lua/server/NOM_Variants.lua     decide o grito do Corredor (som + chamado da horda)
    lua/client/NOM_VariantsClient.lua  cliente de MP roda o NOM_VariantAI e avisa o servidor
    lua/client/NOM_Atmosphere.lua   (sprint 0005) som de névoa, rádio
    lua/client/NOM_Overlays.lua     (sprint 0005) sangue/ferrugem locais
    clothing/clothing.xml           outfit NOM_Eco (itens vanilla por GUID)
    scripts/NOM_sounds.txt          sons do mod (estalo, grito)
    sound/*.ogg                     gerados por scripts/gen_sounds.py (CREDITS.md)
  common/                           exigida pelo B42
tests/                              asserts de lua puro (./run-tests.sh, luajit)
```

Fluxo: `World` deriva o estado do clima vanilla → `ClimateLook` escurece o
clima, que o jogo sincroniza → `NightCount` conta a noite, `Eco` spawna, `Night`
chama os zumbis e avisa os clientes (flag + número da noite) → quem simula o
zumbi (o próprio processo no solo, o cliente dono no MP) aplica os stats e o
perfil da variante em lotes por tick ([ADR-005](adr-005-quem-simula-aplica.md),
[ADR-006](adr-006-variantes-deterministicas.md)) e roda o `VariantAI`; o
servidor decide o grito do Corredor (`Variants`).

## Robustez

- Nada da variante é guardado: ela é recalculada do `persistentOutfitID` e da noite ([ADR-006](adr-006-variantes-deterministicas.md)); ao amanhecer o perfil volta a "dia".
- Mod removido do save: zumbis viram vanilla, `modData` órfã é ignorada.
- Loop de comportamento processa zumbis em lotes por tick, não todos de uma vez.
- Teto de Ecos por jogador evita travar servidor em vala comum.

## Testes

- `NOM_Rules.lua` (máquina de estado, sorteio, elegibilidade do Eco) roda no
  `lua` puro do terminal: `./run-tests.sh`.
- In-game: checklist da sprint no modo `-debug` (forçar hora, névoa, spawn).
- MP: servidor local + dois clientes.
