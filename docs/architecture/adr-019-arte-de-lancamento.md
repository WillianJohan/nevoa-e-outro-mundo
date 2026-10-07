# ADR-019 — Arte de lançamento do Johan, redimensionada e tingida por script

| Campo | Valor |
|-------|-------|
| Status | `accepted` |
| Data | 2026-10-06 |
| Sprint | [0037b](../sprints/sprint-0037b-noise-of-mist/README.md) |
| Decisão | do Johan (AGENTS.md, "Desenvolvimento x lançado", 2026-10-06) |

## Contexto

O `AGENTS.md` pede que texturas e sons sejam gerados por scripts nossos (`scripts/gen_*.py`), e até a
0037 o pôster, o ícone e a preview do Workshop também eram desenhados por código. Com a renomeação
pra "NOM: Noise of Mist" o Johan trouxe a arte de lançamento pronta: pôster (parede descascando com
"NOISE OF MIST"), preview cinza, preview vermelha, ícone ("NOM" enferrujado) e banner.

## Decisão

1. **A arte de lançamento é do Johan**, por decisão dele: exceção à regra de tudo gerado por script, que
   continua valendo pra texturas, sprites e sons do mod.
2. As fontes ficam no repo **reduzidas** em `docs/art/` (768 px nas quadradas, 1280 px no banner, PNG
   sem perda), importadas dos originais por `python3 scripts/gen_images.py --importar <pasta>`.
3. Os arquivos finais saem do `scripts/gen_images.py`, que só **redimensiona, separa as cores e tinge**:
   pôster 512 e ícone 64 dos três mods (mod2 e mod3 com as cores separadas, como antes), preview 512 do
   Workshop, e o pôster e o ícone avermelhado do mod de staging em `docs/art/staging/`.
4. As imagens de staging **não** ficam em `mod*/42/`: o repo e o `build-workshop.sh` só usam as oficiais;
   o `scripts/dev-sync.sh` as aplica na cópia de staging.
5. O `CREDITS.md` registra "arte de lançamento: Johan" e lista cada arquivo; `tests/test_credits.lua`
   confere tamanhos, a separação de staging e o crédito.

## Consequências

- Trocar a arte é rodar `--importar` com os originais novos e depois o script; nada é editado à mão.
- O repo ganha ~5,5 MB de fontes; reduzir mais custaria qualidade nas saídas de 512.
- A descrição do Workshop e o README deixam de dizer que todas as imagens são geradas por script.
