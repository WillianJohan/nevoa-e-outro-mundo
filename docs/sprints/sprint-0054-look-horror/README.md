# Sprint 0054 — Look horror psicológico (lote 1)

| Campo | Valor |
|-------|-------|
| Status | `em teste` |
| Branch | `feature/0054-look-horror-1775` (saiu da `staging`) |
| Plano | [plan.md](plan.md) |
| Origem | prompt store `docs/prompt-redesign-zombie-skins-horror.md`; anti-ref wrap `media/look-horror-refs/before-wrap-storefront.png` |

## Objetivo

Trocar o look “película / wrap” e o gore Jeff da tentativa 0053 por **wrongness psicológico**
(Silent Hill / uncanny), legível na câmera isométrica (contraste 0014).

## Lote 1 (entregue)

| Arquétipo | Asset | O quê mudou |
|-----------|-------|-------------|
| The Pale | `Body/NOM_Estalador` | Cera, rachadura esparsa, órbitas fracas; sem sangue |
| The Misaligned | `Body/NOM_Corredor` | Placa/veias assimétricas; bordas duras |
| The Forgotten Patient | `Body/NOM_Carpideira` + `NOM_CarpideiraManto` | Pele clínica; manto hospitalar **orgânico** (sem blocos 8×8 / faixas) |
| The Wrong Person | `NOM_SemRostoEstatica` | Vazios claros + manchas pretas; chiado residual |
| Distorted Silhouette | manto (capuz escuro) | Silhueta errada de longe |

Gerador: `scripts/gen_textures.py`. Teste anti-wrap: `test_manto_not_wrap_pelicula`.

## Debug (compacto)

- Forçar arquétipo: botões já existentes (`NOM.variant` / Estalador…Carpideira).
- **Novo:** `NOM.lookCycle()` + botão **Ciclar look** no cartão de variantes — Pale→Misaligned→Wrong→Patient→desfaz.
- Sem ciclo de textura em runtime (PNGs são bake do gerador).

## Roteiro no jogo

1. Nesta branch: `scripts/dev-sync.sh`; reiniciar; só Staging.
2. `NOM.panel()` → névoa branca → **Ciclar look** no zumbi mais perto; conferir os 4 looks.
3. Comparar com a screenshot wrap: manto **não** pode ler como listra/grade.
4. Zoom normal: cada monstro ainda tem silhueta/cor própria.

## Fora deste lote

- Boca 3D do Corredor (ainda monstro clássico).
- Roupa cotidiana em variante (ADR-012 strip) — “Wrong Person” de jeans fica pra depois.
- Merge com 0053: resolver texturas na hora (0054 é a direção de look).
