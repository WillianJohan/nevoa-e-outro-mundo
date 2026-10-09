# Sprint 0060 — Look real (roupa/pele uncanny)

| Campo | Valor |
|-------|-------|
| Status | `em teste` |
| Branch | `feature/0060-look-real-ca41` |
| Origem | playtest fail (`look-fail-playtest`); prompt store `prompt-look-refazer-urgente.md` |

## Root cause

As Body PNGs da 0054 eram **P&B binário** (`mid≈0`). Com o strip ADR-012, o corpo inteiro
virava grade geométrica no Staging. Sync/bytes OK — o material é que lia como UV.

## O que mudou

- Peles Body com midtones (Pale / Misaligned / Patient / Wrong Person).
- Camada de roupa no corpo (`NOM_*Roupa`) para Estalador, Corredor e Sem-rosto.
- Casca Sem-rosto e manto Carpideira menos binários.
- ScreenFx: grain/lines mais baixos pra não comer o look.
- Contraste: categoria `SKIN` exige mid (anti-regressão do grid).

## Roteiro no jogo

1. Nesta branch: `scripts/dev-sync.sh`; reiniciar; só Staging.
2. `NOM.panel()` → Look → forçar Misaligned / Pale / Wrong / Patient.
3. Zoom normal: deve ler **pessoa com roupa/pele errada**, não checker P&B.
