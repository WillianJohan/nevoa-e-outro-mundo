# Sprint 0062 — Look lote 2 (Corredor / Tição / Almas / Sem-rosto)

| Campo | Valor |
|-------|-------|
| Status | `em curso` |
| Branch | `feature/0062-look-lote2-ca41` |
| Origem | bíblia look §5/§7/§8/§9 + pedido Johan pós-#16 |
| Base | `staging` (0060f + proporção §7.3) |

## Escopo

- **Corredor C1–C5** (guarda-roupa) + boca 3D revisada (rasgo escuro, sem dentes de longe).
- **Tição T1–T5** (tratamento N2 na roupa própria / bombeiro / pijama).
- **Almas A1–A5** (A1 nua; A2 farrapo; A3 véu; A4 um sapato; A5 rastro — se API deixar).
- **Sem-rosto:** S1–S5 + rostos **F1–F4** no remendo A′; todos os 24 tons de bochecha (já em `NOM_SemRostoFace.CHEEK`).

## Aceite

Checklist da bíblia §13 (diretor de arte) nas três névoas, com `lookInspect` colado. Print no store `media/look-fail-playtest/` (ou `media/look-lote2/`).

## Roteiro (Johan) — após ajustes playtest 1–7 + adendo preta

1. `git pull` na branch + `scripts/dev-sync.sh` + **reiniciar o jogo**.
2. Névoa branca ou vermelha na rua → `NOM.lookGroup()` (ou painel **Grupo forçado**).
3. Colar no chat o `lookInspect` de cada linha que o console imprimir + print do grupo.
4. Close Corredor (zoom padrão): boca colada, sem aro claro, rasgo pra uma orelha.
5. Close Sem-rosto F1 e F3 (tom claro e escuro): remendo sem oval branco.
6. Névoa **preta** → `NOM.lookGroup()` de novo (força T1/T2/T3) + `NOM.alma()` se precisar.
7. Conferir: crosta ≤ cabeça, irregular; **nenhuma** roupa clara intacta; sem peça branca/rosa no tronco; almas rastejando/escuras.
8. Colar prints + lookInspect pro diretor de arte (§13) antes de merge.
