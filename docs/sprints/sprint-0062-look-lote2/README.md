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

## Roteiro (Johan)

1. `git pull` na branch + `scripts/dev-sync.sh` + **reiniciar**.
2. `NOM.lookVariant("corredor", n)` / painel — C1…C5; boca sem dentes brancos à distância.
3. Sem-rosto: `lookInspect` → `face=F*`, `ward=S*`, tons variados; capped → F1+S5.
4. Névoa preta: Tições T1–T5; almas A* se spawnar.
5. Colar prints + lookInspect pro diretor de arte (§13) antes de merge.
