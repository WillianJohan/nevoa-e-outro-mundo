# Sprint 0064 — Screamer: 3 variantes (opções 2/3/4)

| Campo | Valor |
|-------|-------|
| Status | `em curso` |
| Branch | `feature/0064-screamer-variantes-ca41` |
| Origem | Johan escolheu opções 2, 3 e 4 de `screamer-opcoes.md` (store) |
| Base | `staging` (lote 2 + gritos) |
| Código | nomenclatura **Carpideira** permanece (`kind=carpideira`, `NOM_Carpideira*`) |

Substitui o visual de manto/viúva (K1–K5) por três identidades sorteadas. Concepts: store
`media/look-concepts/screamer-opcao-2..4.jpg` (não entram no repo).

## Ordem de entrega

| # | Variante | id | Escopo técnico | Aceite |
|---|----------|-----|----------------|--------|
| 1 | **Que Nunca Cresceu** | `K1` | laço nosso + vestido médio + manga longa + meias joelho (sem mechas) | checklist §13 + print |
| 2 | **Embrulhada** | `K2` | capuz ≤ SKULL+5% + casca Hazmat (lençol); rasgo no grito depois | spike visual → resto |
| 3 | **Rastejante** | `K3` | spike `setCrawler`→ficar de pé (`internal/screamer-rastejante-spike.md`) **antes** de implementar; botões `NOM.rasteja*` no painel | spike no jogo → resto |

## K1 — Que Nunca Cresceu (esta entrega)

- Laço estático `NOM_CarpideiraLaco` no alto (sem mechas; cabelo vanilla aparece)
- `Dress_Normal` tinta `#2E3442` (até o joelho, não saia curta)
- `Shirt_FormalTINT` `#D9D2C3` (manga longa + gola)
- `Socks_Long_White` + `Shoes_Black`
- `keepBody=false` (sem manto)

### Roteiro de print (Johan)

1. `git pull` na branch + `scripts/dev-sync.sh` + **reiniciar**.
2. Névoa → **Screamer** / `NOM.lookVariant("carpideira", 1)`; preferir **rua no zoom padrão**.
3. Close + médio + longe; colar `lookInspect` (`var=K1`, `NOM_CarpideiraLaco`) + print.
4. Conferir: laço branco no alto, vestido marinho até o joelho, meias claras, sem mechas/Samara.

## Spike Rastejante (antes de K3)

Recomendação do revisor: **caminho 2c** (cair de bruços → motor levanta), plano B gritar deitada.

Botões no painel (seção Monstros → Spike Rastejante), no zumbi mais perto:

| Botão | Comando | O quê |
|-------|---------|-------|
| setCrawler off | `NOM.rastejaToggle()` | `setCrawler(false)` puro |
| toggleCrawl | `NOM.rastejaToggle2()` | `toggleCrawling()` |
| 2c levanta | `NOM.rastejaLevanta()` | fallOnFront+onFloor+knockedDown+setCrawler(false) |

Cada um loga `state/crawl/floor/canWalk` ~3 s. Johan prova no bluefin (SP; MP se der) e escolhe o que anima.

Evidência javap (bluefin): `internal/screamer-rastejante-evidencia-bluefin.md`.

## K2 — Embrulhada (esta entrega)

- Capuz `NOM_CarpideiraCapuz`: ≤ **SKULL+5%** (não capacete-ovo), topo caído, boca úmida, barbante com pontas
- Corpo `NOM_EmbrulhadaCasca` (Hazmat vanilla + máscaras + textura lençol/plástico/amarras)
- `weight=0` (só botão / `lookVariant(..., 2)` até aceite); Turn the nearest limpa alma/esqueleto
- Rasgo no grito (`setTextureChoice`) depois do aceite visual

### Roteiro de print (Johan)

1. `git pull` na branch + `scripts/dev-sync.sh` + **reiniciar**.
2. Névoa → **Screamer K2 (capuz)** ou `NOM.lookVariant("carpideira", 2)`; `lookInspect` → `var=K2`, `NOM_CarpideiraCapuz` + `NOM_EmbrulhadaCasca`, **sem** `SkeletonMuscle`.
3. Close de frente (boca no pano) + zoom padrão na rua + grupo na vermelha.
4. Conferir: sem cúpula branca 2×; coluna clara encaroçada; sem membros vermelhos de palito.

## Fora de escopo agora

- Opção 1 (Sirene)
- Rasgo no grito da Embrulhada (depois do aceite visual)
- Redesign de som (ninar / birra) — depois do visual aprovado
- Merge na staging só depois do aceite de cada variante (avisar o coordenador a cada uma pronta)
