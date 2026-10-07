# Sprint 0039: névoa preta II

| Campo | Valor |
|-------|-------|
| Status | `em teste` |
| Branch | `sprint/0039-nevoa-preta-ii` (saiu da `staging`) |
| Origem | [spec do modelo novo §1, §8 e §10](../../superpowers/specs/2026-10-06-modelo-novo-design.md) |
| Plano | [plan.md](plan.md) |

## O que entrou

- **A luz fixa congela o Tição.** Valem o poste, o abajur e o fogo (a lista de postes do jogo) e o
  cômodo com o interruptor aceso:
  - poste aceso vira um raio de até 8 tiles;
  - vela (raio menor que 3) não congela;
  - luz da rede só conta com força (rede ou gerador), a mesma regra do jogo; abajur a pilha precisa de
    carga.
  O servidor varre a lista em fatias (40 por tick, uma volta a cada 2 s, só o que está a até 40 tiles
  de um jogador). O zumbi fora de toda luz confere o cômodo dele, com a resposta guardada por cômodo a
  cada 250 ms. `NOM.ticao()` agora mostra `luzes_fixas=N` (no solo; no cliente de MP, `-`).
- **Outro Mundo queimado** na preta:
  - chão: queimado dentro e fora (fora no lugar do mato), sem metal; por cima, cinza em manchas e brasa
    no miolo do queimado (12% desses tiles);
  - parede: a fuligem manda, com sujeira e rachadura (sem tinta, ferrugem, sangue nem trepadeira);
  - densidade ×1,4.
  As texturas novas (`NOM_OM_Cinza_F`, `NOM_OM_Brasa_F`, `NOM_OM_Fuligem_W/N`, 5 de cada) saem do
  `scripts/gen_tiles.py`, e as antigas saem com os mesmos bytes.
- **mod3: a luz empurra a névoa preta.** O facho da lanterna e do farol é um vento constante da lâmpada
  na direção que aponta: 4 impulsos ao longo do cone, até 12 tiles, a 2,5 tiles/s, e a névoa abre um
  túnel na frente. Lampião e poste empurram pra todo lado num anel de 6 impulsos. São até 8 luzes. O
  Lua liga isso com `NOMRender_setParam(12, 1)` na borda da preta (`client/NOM_FogQualitySync.lua`). A
  cor escura já vinha do clima. O `NOMRender_flowInfo()` mostra `preta=1 luz=N postes=M`.
- Evidência: [pz-api-notes §31](../../architecture/pz-api-notes.md).

## Decisões tomadas na ausência do Johan (fáceis de mudar)

- **Cômodo aceso congela quem está dentro dele**, mesmo longe da lanterna do jogador. É a leitura direta
  de "lâmpada de casa ligada". Vale até 40 tiles de um jogador (`FIXED_NEAR`, o mesmo dos postes, a tela
  inteira): o code review final achou que, sem esse limite, toda casa acesa do mundo carregado entrava
  na lista mandada aos clientes. Tirar: apagar o bloco do cômodo em `NOM_TicaoLight.check`.
- **Raio do poste preso em 8 tiles** e vela fora (`NOM_LightRules.FIXED_MAX`, `FIXED_MIN`).
- **Brasa parada** (sprite, sem animação): "apagando" é o laranja fraco, só em metade das trincas.
- **A preta vence a vermelha** também no Outro Mundo.
- **Cinza e brasa servem na grama:** chão queimado é chão queimado. Na branca, a textura nossa continua
  fora da grama.
- **Força do empurrão** igual à do foco de vento (2,5 tiles/s). O facho abre bem a névoa (no teste, a
  densidade na frente cai pra ~0,12). Mudar em `LightWind.SPEED` e `BEAM_REACH`.
- **Farol com direção pro Tição** ficou de fora: no Lua continua raio. No mod3 o facho do farol já sopra
  com direção.

## Testes

- `test_light_rules`: `fixed` e `switchLit`.
- `test_ticao_light`: poste aceso, poste sem força, gerador, poste longe, cômodo aceso e desligado, e o
  custo com 200 postes (~5 chamadas no poste por tick; o cômodo lido uma vez por leitura). A luz da
  0038 continua em ~69 chamadas no zumbi por tick com 300 zumbis e 4 lanternas.
- `test_debug`: `luzes_fixas`.
- `test_dressing_rules`: preta queimada, sem metal nem mato, cinza, brasa, fuligem manda;
  determinística e diferente das outras.
- `test_fog_overlays`: preta anexa o que a regra pede e volta pra branca.
- `test_own_sprite_list` e `test_om_tiles.py`: tipos novos, cobertura, a brasa tem laranja (só ela pode),
  e o gerador determinístico.
- `test_fog_quality_sync`: o param 12 na borda.
- `test_mod3_light`: o contrato Lua/Java.
- `tests/java/FlowLightWindTest.java`: o facho sopra pra frente e no alcance, o anel sopra pra fora, e a
  névoa sai da frente do facho na grade.

## Code review

- As lascas que sobem do chão usavam a densidade da branca na preta (×1 contra o ×1,4 do Outro
  Mundo). Agora acompanham (`NOM_Flakes`, teste `flakes_black_denser`).
- Conferido sem achado:
  - o cômodo congela sem dono, então o piscar da lanterna não solta quem está nele;
  - poste com square não carregado conta como sem força;
  - o buffer de impulsos do Java cabe o pior caso (8 luzes × 6);
  - o layout `torchPos`/`torchDir` bate com o `collectTorches`.

## Roteiro de teste no jogo

1. Staging com o mod3. `NOM.setBlackFog(true)` e espere escurecer.
2. Acenda a lanterna e aponte: a névoa escura abre um túnel na frente do facho e fecha quando você vira.
   No console, `NOMRender_flowInfo()` mostra `preta=1 luz=4`.
3. Ache um poste aceso na rua (com força no mapa): a névoa se afasta em volta dele, e o Tição que
   chega perto para. `NOM.ticao()` mostra `luzes_fixas=N`.
4. Entre numa casa com a luz ligada: os Tições dentro dela ficam parados. Desligue o interruptor e meio
   segundo depois eles andam.
5. Olhe o chão e as paredes: queimado com cinza e brasa fraca no chão, fuligem subindo pelas paredes.
   Nada de grade de metal.
6. Fim da preta (`NOM.setEndFog()`): o Outro Mundo some como sempre. Numa branca depois, as grades de
   metal voltam.
7. No MP: poste aceso congela pro servidor dedicado também (o UNKNOWN do §31).
