# Sprint 0039: névoa preta II (plano)

Spec: [§1, §8 e §10](../../superpowers/specs/2026-10-06-modelo-novo-design.md). A 0038 fez a preta jogável
(escuridão, Tição, a luz que congela). Esta fecha o que ficou: a névoa preta que a luz empurra
(mod3), o Outro Mundo queimado e a luz fixa que também congela o Tição.

Decisões tomadas pelo agente (Johan descansando; "escolha o conservador, fácil de mudar"),
registradas aqui e no README.

## Tarefa 1: luz fixa congela o Tição

Hoje só lanterna, lampião e farol congelam. A spec pede também "lâmpada de casa ligada, poste,
fogueira".

**API (evidência no pz-api-notes §31):**

- `IsoCell.getLamppostPositions()` devolve um `Stack<IsoLightSource>`: poste, abajur, fogo.
  `Stack`, `Vector` e `IsoLightSource` são expostos (bytecode do `LuaManager$Exposer`).
  `IsoLightSource`: `getX/Y/Z()I`, `getRadius()I`, `isActive()Z` e `isHydroPowered()Z`. O vanilla
  usa `getCell():getLightSourceAt(...)` e `light:isActive()`/`isHydroPowered()` em
  `DebugChunkState_SquarePanel.lua:124-127`.
- `IsoLightSource.update()` (bytecode, offsets 22–49) apaga a luz ligada à rede quando o square
  não tem `hasGridPower()` nem `haveElectricity()`. Usamos a mesma regra, porque no dedicado o
  `update` pode não rodar.
- Lâmpada do cômodo: `IsoGridSquare.getRoom()` → `IsoRoom.getLightSwitches()` (vanilla:
  `DebugChunkState_SquarePanel.lua:104`) → `IsoLightSwitch.isActivated()` (vanilla:
  `ISWorldObjectContextMenu.lua:1230`), `hasLightBulb()`, `getUseBattery()`, `getHasBattery()`,
  `getPower()` e `getSquare()`.

**Regra (`shared/NOM_LightRules.lua`):**

- `R.fixed(radius, active, hydro, powered)`: nil se apagada, sem força (`hydro` sem `powered`) ou
  com raio < `FIXED_MIN` (3: vela não congela). Senão um raio de `min(radius, FIXED_MAX)` (8).
- `R.switchLit(on, bulb, battery, charge, mains)`: ligada, com lâmpada, e bateria com carga ou
  rede/gerador.

**Servidor (`server/NOM_TicaoLight.lua`):**

- A lista de postes é varrida em fatias de `FIXED_BATCH` (40) por tick, com uma volta a cada
  `FIXED_EVERY_MS` (2 s), guardando só quem está a até `FIXED_NEAR` (40) tiles de um jogador.
  As luzes fixas entram nas `lights` de cada leitura.
- Zumbi que não está em nenhuma luz: `getCurrentSquare():getRoom()`. A resposta "cômodo aceso"
  fica em cache por cômodo durante cada leitura (`SWEEP_MS`).

**Testes:** `test_light_rules` (fixed, switchLit); `test_ticao_light` (poste aceso congela, poste
sem força não congela, cômodo aceso congela quem está dentro, cômodo com o interruptor desligado
não congela, e o orçamento com postes e cômodos).

## Tarefa 2: Outro Mundo queimado

Spec §1: "Chão queimado, cinzas, brasas apagando".

- Texturas novas no `scripts/gen_tiles.py`, acrescentadas no FIM de `KINDS`. A semente é
  `(SEED, índice do tipo, n)`, então as antigas saem com os mesmos bytes:
  - `Cinza_F`: monte de cinza, cinza claro e escuro, com farelo;
  - `Brasa_F`: carvão rachado com brasa fraca nas trincas (laranja apagado);
  - `Fuligem_W` e `Fuligem_N`: fuligem subindo do rodapé, mais escura embaixo.
- `NOM_DressingRules`, com um parâmetro `black` no fim de `floor`, `wall` e `density`:
  - chão: queimado dentro e fora (fora no lugar do mato), sem metal; em cima, cinza em manchas e
    brasa rara;
  - parede: fuligem manda, com rachadura e sujeira;
  - densidade × `BLACK_MULT` (1,4).
- `client/NOM_FogOverlays.lua` passa `NOM_FogState.black` e põe a cor na chave do desenho.

**Testes:** `test_om_tiles.py` (tipos novos, cobertura e paleta), `test_dressing_rules` (preta
sem metal nem mato, com cinza e fuligem; branca e vermelha iguais a antes) e
`test_own_sprite_list`.

## Tarefa 3: a névoa preta que a luz empurra (mod3)

A cor já vem do clima (`COLOR_NEW_FOG`, que a preta deixa quase preta). Falta o empurrão.

- `RenderContext.PARAM_BLACK = 12`: o cliente manda `NOMRender_setParam(12, 1|0)` na borda da
  preta (`client/NOM_FogQualitySync.lua`, que já empurra os params).
- `LightWind.java` (puro, testado sem o jogo): de uma luz, os impulsos no fluido.
  - Facho: `BEAM_POINTS` pontos ao longo do cone, até `BEAM_REACH` tiles, soprando na direção
    da lâmpada a `SPEED`, com raio crescendo com a distância.
  - Raio (lampião, poste): `RING_POINTS` impulsos em volta, soprando pra fora.
- `Flow`: com o `PARAM_BLACK` ligado, a cada passo aplica os impulsos das lanternas e faróis (os
  mesmos do `collectTorches`) e dos postes acesos perto (`cell.getLamppostPositions()`, a mesma
  regra de força), até `MAX_LIGHTS`.
- Tudo em try/catch: erro no mod3 nunca derruba o jogo.

**Testes:** `tests/java/FlowLightWindTest.java` (facho sopra pra frente e não pra trás, raio sopra
pra fora, nada fora do alcance), e um teste no FlowGrid de que a névoa sai da frente do facho.

## Fora (fica pra depois)

- Farol com direção pro Tição (o Lua não tem o vetor do carro sem `Vector3f`; no mod3 o facho do
  farol já sopra com direção).
- Brasa animada (apagando de verdade): sprite parado nesta sprint.
