# Sprint 0017 — Sem-rosto espalhado e sorteio estável com chapéu caído

| Campo | Valor |
|-------|-------|
| Status | em teste |
| Branch | `sprint/0017-semrosto-espalhado` |
| Plano | [plan.md](plan.md) |
| GDD | [monsters.md](../../gdd/monsters.md#sem-rosto) |
| ADR | [ADR-006](../../architecture/adr-006-variantes-deterministicas.md#emenda-de-2026-10-05--sprint-0017-o-chapéu-caído-não-é-identidade) (emenda), [ADR-007](../../architecture/adr-007-sem-rosto-e-atmosfera-local.md#emenda-de-2026-10-05--sprint-0017-a-horda-se-espalha) (emenda); [pz-api-notes §14.4](../../architecture/pz-api-notes.md#144-esconder-a-roupa-sprint-0016) |

## Objetivo

Uma horda de Sem-rostos vista junta reaparece espalhada em volta do jogador, cada um num
tile diferente, e um zumbi que perde o chapéu na névoa continua sendo o que era (a mesma
variante, ou comum).

Duas correções do Claude (rulings de 05/10/2026). A primeira vem do console do Johan na
névoa vermelha: `semrosto visto x=10688 y=10238 para x=10720 y=10192` repetido, um a cada
~0,5 s, todos pro mesmo tile. A segunda era pendência da 0016: o bit `0x8000` que o jogo
liga no ID quando o chapéu cai é a entrada do sorteio (ADR-006).

## Critérios de aceite

- [x] 5 Sem-rostos vistos juntos no mesmo lugar reaparecem em 5 tiles diferentes, todos
      fora da vista e aceitos pela conferência do servidor — `fog_sp_horde_spreads` (solo,
      `server/NOM_Fog.lua` de verdade: 5 teleportes, tiles distintos, `isCouldSee` falso,
      `validMove` verdadeiro). Sem a correção o teste falhava com os dois primeiros em `91,100`.
- [x] O tile reservado volta a valer depois de `RESERVE_MS` (5 s) e a névoa nova começa sem
      reserva — `semrosto_reservation_expires`.
- [x] MP: o destino que o servidor espalha (`semRostoMove`, sumiço visto por qualquer
      cliente) fica reservado em todo cliente — `fog_client_move_reserves_tile`.
- [x] Um ID com e sem o bit `0x8000` sorteia o mesmo tipo (normal e vermelha, 20 000 IDs × 5
      períodos), inclusive o forçado do debug — `variant_rules_fallen_hat_same_kind`;
      máscara exata no ID negativo (bit 31 = feminino) e nos limites —
      `variant_rules_base_id_exact`.
- [x] Zumbi que perde o chapéu continua a variante e o visual não é refeito —
      `look_fallen_hat_keeps_variant` (fake do `ZombieHelmetFallingPacket.processClient`: bit
      ligado e lista refeita com os mesmos objetos). Bytecode: `setFallenHat` 0–36 mantém o
      init; o `outfitId` do pacote só cria (`NetworkZombieSimulator.parseZombie` 144–152).
- [x] Eco recarregado com o bit ainda é Eco, vestido pelo ID que tem —
      `eco_reloaded_with_fallen_hat_still_eco`.
- [x] Carpideira que gritou e perdeu o chapéu não grita de novo nem volta a soluçar —
      `carpideira_fallen_hat_does_not_scream_again` (servidor), `carpideira_furious_with_fallen_hat`
      (quem vê), `variants_client_scream_with_fallen_hat` (o grito acha a cópia com o bit).
- [x] O debug força pelo ID sem o bit — `debug_variant_sends_base_id`.
- [ ] No jogo, uma horda de Sem-rostos vista junta reaparece espalhada — **falta o jogo:**
      roteiro, passos 2–3.
- [ ] MP: uma variante que perde o chapéu num golpe continua a variante nos dois clientes e no
      servidor — **falta o jogo:** passo 4.

`./run-tests.sh`: `total=559 passou=559 falhou=0` (Lua), `contraste total=4 passou=4`,
`build total=25 passou=25`.

## Roteiro in-game

Jogo em `-debug`, **save descartável**. Console em
`~/.var/app/com.valvesoftware.Steam/Zomboid/console.txt` (Flatpak).

1. **Copiar e carregar.** `scripts/dev-sync.sh`, abrir e carregar o save. **Esperado:**
   nenhuma linha com `NOM_` e `ERROR`.
2. **Horda na vermelha.** De dia, `NOM_Debug.redFog(true)` e Spawn Horde com ~20 zumbis a
   ~15 tiles, à frente. Olhar pra horda. **Esperado:** as linhas
   `[NOM] semrosto visto x=… y=… para x=… y=…` saem uma a cada ~0,3–0,5 s com o **`para`
   diferente** em cada uma (nunca o mesmo `x=… y=…` duas vezes seguidas em menos de 5 s);
   na tela, os Sem-rostos aparecem atrás e dos lados, separados. **Se** repetir o mesmo
   destino: anotar as linhas.
3. **Corredor apertado.** Mesma coisa num corredor de prédio. **Esperado:** alguns somem pra
   tiles diferentes; o que não acha tile fica parado à vista até ~5 s depois (aceito).
4. **Chapéu caído no MP** (dedicado + 2 clientes). Névoa normal, `NOM_Debug.variant("corredor")`
   num zumbi de capacete ou chapéu (no cliente ele aparece sem o chapéu; o servidor, que não
   pinta, ainda tem). Bater nele com taco até o chapéu cair no chão. **Esperado:** ele continua
   Corredor (corre, grita) e `NOM_Debug.status()` dá o mesmo `corredores=` nos dois clientes.
   **Se** virar comum ou outra variante logo depois do chapéu cair: anotar o `id=` das linhas
   do debug.

## Checkpoints

- **04/10/2026** — Sprint aberta (rulings do Claude de 05/10). Bytecode: quem liga o bit do
  chapéu no zumbi (servidor no golpe, cliente no pacote; no solo ninguém), ninguém re-veste
  por causa do bit. Plano escrito.
- **04/10/2026** — `NOM_VariantRules.baseId` no sorteio e em toda tabela chaveada pelo ID;
  reserva do destino do Sem-rosto (solo, cliente e `semRostoMove`). Testes verdes.
- **04/10/2026** — Docs: monsters.md, emendas da ADR-006 e da ADR-007, pz-api-notes §14.4,
  roteiro. Em teste.

## Aprendizados

- **No solo o jogo nunca liga o bit do chapéu caído no zumbi.** `IsoGameCharacter.helmetFall`
  só chama `setFallenHat` pra quem não é zumbi; no zumbi quem liga é o servidor dedicado no
  golpe (`hit/Zombie.react`) e o cliente no `ZombieHelmetFallingPacket`. Um teste em solo não
  reproduz a troca de variante; só o MP (ou um ID salvo com o bit).
- **Máscara de bit sem operador de bit, em ID com sinal:** `math.floor(id / 2^k) % 2` é o
  deslocamento aritmético exato em double também pra negativo, e subtrair `2^k` desliga o bit
  sem tocar no bit de sinal.

## Pendências que a próxima sprint herda

- Tudo do roteiro acima.
- Dois clientes que veem a mesma horda no mesmo instante ainda podem mandar o mesmo tile antes
  do `semRostoMove` do outro chegar (janela de ida e volta; ADR-007).
- Marcas de Carpideira salvas com o bit antes desta sprint (névoa em curso na atualização)
  deixam de casar: um grito a mais, uma vez.
- Herdadas da 0016: `remove(Object)` devolvendo booleano no Kahlua, a "saia estranha", zumbi
  pulado no fim da névoa até a passada de hora em hora.

## Sessões

- 2026-10-05 — abd764e2-7a9a-416b-b9b3-1630ab9e761f — plano, `baseId`, reserva do destino, docs
