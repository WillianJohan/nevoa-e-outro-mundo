# Sprint 0064 — Screamer: 3 variantes (opções 2/3/4)

| Campo | Valor |
|-------|-------|
| Status | `pronta pro playtest` |
| Branch | `feature/0064-screamer-variantes-ca41` |
| Origem | Johan escolheu opções 2, 3 e 4 de `screamer-opcoes.md` (store) |
| Base | `staging` (lote 2 + gritos) |
| Código | nomenclatura **Carpideira** permanece (`kind=carpideira`, `NOM_Carpideira*`) |

Substitui o visual de manto/viúva (K1–K5) por três identidades sorteadas. Concepts: store
`media/look-concepts/screamer-opcao-2..4.jpg` (não entram no repo).

## Ordem de entrega

| # | Variante | id | Escopo técnico | Aceite |
|---|----------|-----|----------------|--------|
| 1 | **Que Nunca Cresceu** | `K1` | laço + pinafore (alças) + gola + meias + cabelo escuro longo | print Johan |
| 2 | **Embrulhada** | `K2` | balaclava vanilla + textura lençol (caminho A; sem capuz 3D); casca BoilerSuit + máscaras Hazmat; Scarf nó | print Johan |
| 3 | **Rastejante** | `K3` | `setCrawler` + canWalk; grito = getup 2c + fallback B (timeout); botões `NOM.rasteja*` | playtest Johan |

## K1 — Que Nunca Cresceu (esta entrega)

- Laço estático `NOM_CarpideiraLaco` (dois loops ≈ largura da cabeça)
- Cabelo vanilla `Long` + `setHairColor` escuro `#1A1512`
- `Dress_Straps` tinta `#2E3442` (pinafore com alças) + `Shirt_FormalTINT` gola clara
- `Socks_Long` tinta `#C8C2B4` (≠ pele) + `Shoes_Black`
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

## K2 — Embrulhada (caminho A, diretor v3)

- Cabeça: malha vanilla `Hat_BalaclavaFull` + textura nossa `NOM_EmbrulhadaBalaclava` (boca úmida)
- Nó: `Scarf_White` tint `#5A4A38`
- Corpo: `NOM_EmbrulhadaCasca` = BoilerSuit + máscaras Hazmat (sem hood, sem gola/estampa)
- Pés descalços acinzentados; Turn the nearest limpa alma

## K3 — Rastejante

- Bata `HospitalGown` tint `#BDB5A6` + `setCrawler(true)` com `canWalk=true`
- Grito: caminho **2c** (fallOnFront+onFloor+knockedDown+setCrawler false) → espera Getup/timeout 2 s → grito (fallback B = grita deitada)
- Spike no painel: `NOM.rastejaToggle` / `rastejaToggle2` / `rastejaLevanta`

## Pesos (painel Look)

`ScreamerK1Weight` / `K2` / `K3` (padrão 1/1/1; 0 = fora do sorteio). Botões K1/K2/K3 forçam a variante.

### Roteiro de print (Johan)

1. `git pull` + `scripts/dev-sync.sh` + **reiniciar**.
2. Névoa → botões **Screamer K1/K2/K3**; `lookInspect` com `var=K*`.
3. K2: close de frente (boca no pano) + rua; sem ovo/urso; sem gola vanilla.
4. K3: rasteja calma; ao acordar, levanta (ou grita deitada no timeout) e caça.

## Fora de escopo agora

- Opção 1 (Sirene)
- Rasgo no grito da Embrulhada (depois do aceite visual)
- Redesign de som (ninar / birra) — depois do visual aprovado
