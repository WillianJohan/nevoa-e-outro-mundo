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
| 1 | **Que Nunca Cresceu** | `K1` | só roupa vanilla + tinta (+ mechas existentes) | checklist §13 + print |
| 2 | **Embrulhada** | `K2` | provar **capuz/pano** estático (≤ cabeça+5%) com print **antes** do resto + rasgo no grito | spike visual → resto |
| 3 | **Rastejante** | `K3` | spike `setCrawler`→ficar de pé (`internal/screamer-rastejante-spike.md`) **antes** de implementar; botões `NOM.rasteja*` no painel | spike no jogo → resto |

## K1 — Que Nunca Cresceu (esta entrega)

- `Dress_Knees` tinta `#2E3442` (AllowRandomTint no ClothingItem)
- `Shirt_FormalTINT` `#D9D2C3` (blusa)
- `Socks_Long_White` + `Shoes_Black`
- `keepBody=false` (sem manto); mechas `NOM_CarpideiraCabelo` ficam
- Laço branco: **não há** acessório vanilla de cabelo; 1ª entrega sem peça nossa (assinatura = laço faltando; meias claras + vestido curto). Laço estático fica pra follow-up se o print pedir.

### Roteiro de print (Johan)

1. `git pull` na branch (ou staging depois do merge) + `scripts/dev-sync.sh` + **reiniciar**.
2. Névoa branca/vermelha → `NOM.lookVariant("carpideira", 1)` ou `NOM.lookGroup()`.
3. Close + médio + longe; colar `lookInspect` + print.
4. Conferir: sem manto preto; vestido curto marinho; meias brancas; mechas; proporção “roupa pequena em corpo adulto”.

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

## K2 — Embrulhada: prova do capuz (esta entrega)

- Peça estática `NOM_CarpideiraCapuz` (Bip01_Head, `nohairnobeard`), ≤ capacete vanilla +5%
- Relevo de boca aberta sob o pano (sem buraco de olhos); barbante no pescoço
- Wardrobe `K2` com `headItem` (substitui mechas); corpo Hazmat + rasgo no grito **depois** do print
- `keepBody=false`; `pieces={}` nesta prova (só o capuz); `weight=0` (só via `lookVariant`/force até o corpo)

### Roteiro de print (Johan)

1. `git pull` na branch + `scripts/dev-sync.sh` + **reiniciar**.
2. Névoa → `NOM.lookVariant("carpideira", 2)` (ou ciclar até `var=K2` no `lookInspect`).
3. Close + médio + longe; colar `lookInspect` + print.
4. Conferir: capuz de lençol sujo ≤ cabeça; relevo de boca; sem mechas; sem manto; escala ok.

## Fora de escopo agora

- Opção 1 (Sirene)
- Corpo Hazmat + rasgo no grito da Embrulhada (depois do aceite do capuz)
- Redesign de som (ninar / birra) — depois do visual aprovado
- Merge na staging só depois do aceite de cada variante (avisar o coordenador a cada uma pronta)
