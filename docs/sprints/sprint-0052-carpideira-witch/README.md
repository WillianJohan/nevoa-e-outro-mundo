# Sprint 0052 — Look + Carpideira Witch (piloto)

| Campo | Valor |
|-------|-------|
| Status | `em teste` (PR draft) |
| Branch | `sprint/0052-carpideira-witch` (saiu da `staging`) |
| Plano | [plan.md](plan.md) |
| GDD | [monsters.md](../../gdd/monsters.md#carpideira), [art-direction.md](../../gdd/art-direction.md) |
| ADR | emenda [ADR-011](../../architecture/adr-011-carpideira.md), [ADR-012](../../architecture/adr-012-visual-das-variantes.md), [ADR-013](../../architecture/adr-013-efeitos-de-tela.md) |
| Origem | fila overnight item 5; [proximos-passos §3.2](/cursor/stores/self/docs/proximos-passos-refinamento.md) |

## Objetivo

A Carpideira calma deixa de ser estátua: **anda chorando** em trechos curtos (sem
caçar), ganha **manto penitente** (silhueta de criatura de luto, não “zumbi nu com
cabelo”) e a tela **respira a vinheta** perto do soluço — tudo no mod principal,
**sem Zombie Buddy**.

## Critérios de aceite

- [ ] Calma: soluço local; a cada 20–60 s reais faz caminhada de 2–6 tiles **sem**
      aproximar o jogador; entre caminhadas fica `useless` — testes `carpideira_walk_*`
- [ ] Gatilhos de acordar (raio 4 / lanterna / tiro) e um grito por névoa intactos —
      testes da 0011 verdes
- [ ] Look: peça de corpo `NOM_CarpideiraManto` (+ gêmeo Fx) + mechas 3D + pele; sem
      trocar `persistentOutfitID` — `look_*`, `look_assets_*`, contraste
- [ ] Vinheta ZB-free sobe com a proximidade do soluço (overlay / regras puras) —
      `screenfx_rules_sob_*`
- [ ] Nada de asset de terceiro no repo; malha/camada citada por nome; textura gerada
- [ ] `NOM.carpWalk()` + botão no painel (Johan, 2026-10-06)
- [ ] Roteiro no jogo (Johan): silhueta + andar chorando + vinheta perto

## Checkpoints

- **09/10/2026** — branch, plano, TDD do piloto (look + walk + vinheta).

## Code review (fim da entrega)

- **OK:** sem asset de terceiro; manto = camada + textura gerada; API = useless / pathToLocationF / ItemVisual / setVolume já usadas.
- **OK:** `hide` exclui `bodyIv` do snapshot vanilla; unhide remove os dois ItemVisual do mod.
- **OK:** calma parada ainda sai cedo no `hold` (orçamento); agenda só no 1º frame / ao vencer o gap.
- **Risco aceito:** silhueta ainda é camada (sem malha 3D) — A/B do Johan decide se precisa `gen_models`.
- **Ambiente:** build Workshop / `dev-sync` não rodaram aqui (sem Flatpak Zomboid / JDK 25).

## Aprendizados

- `hold` que chama `furious` (e `getPersistentOutfitID`) **antes** do early-return da calma
  estoura o orçamento da vermelha; a ordem da 0011 (still primeiro) tem de ser preservada.

## Pendências que a próxima sprint herda

- Volume 3D do manto (se a camada ainda ler “toalha” no A/B do Johan).
- Sons II: lamento com fraseado (0048 / escuta); esta sprint não regenera oggs.
- Traje “criatura” nas outras monstras (§3.3) — só Carpideira neste piloto.

## Sessões

- 09/10/2026 — bc-65fbe311-5d75-5a4b-84d7-0556e6462865 — piloto Witch

## Roteiro de teste no jogo

1. `scripts/dev-sync.sh`, reiniciar, `-debug`.
2. `NOM.setFog(true)`, `NOM.turnZombie` Carpideira (ou painel).
3. De longe: ouvir soluço; em 1–2 min vê-la **andar** sem virar pra você.
4. `NOM.carpWalk()`: força a próxima caminhada logo.
5. Aproximar a ~4 tiles / lanterna / tiro: grito + caça; um grito por névoa.
6. Zoom normal: silhueta de manto escuro + mechas; não “nu com pano na cabeça”.
7. Perto do soluço (efeitos de tela ligados): vinheta mais fechada; sem mod3/ZB.
8. Fim da névoa: roupa vanilla de volta; loot normal.
