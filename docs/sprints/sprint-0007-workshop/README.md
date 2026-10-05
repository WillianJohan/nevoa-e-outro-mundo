# Sprint 0007 — Publicação no Workshop

| Campo | Valor |
|-------|-------|
| Status | em teste |
| Branch | `sprint/0007-workshop` |
| Plano | [plan.md](plan.md) |
| GDD | [Overview.md](../../gdd/Overview.md) (pilar 6: traduzível), [sandbox.md](../../gdd/sandbox.md) |

## Objetivo

O mod está no Steam Workshop, instala com um clique e qualquer pessoa entende o que ele faz.

Sem o Steam e sem o jogo aqui, a sprint deixou tudo pronto pra publicar em ~10 minutos
depois do teste in-game: [docs/publicar.md](../../publicar.md). O envio e a tag são do
Johan.

## Critérios de aceite

- [x] Textos do mod (sandbox, tooltips) em **EN e PT-BR** — `tests/test_translations.lua`:
      as 24 opções + página com rótulo e tooltip nos dois idiomas, nenhuma chave sobrando
      (`translations_sandbox_keys_exact`), toda chave de `getText` do Lua definida
      (`translations_lua_keys_defined`), EN só ASCII (o jogo lança exceção com caractere
      parecido: `Translator.cryAboutUnicodeConfusables`), vírgulas válidas pro JSON estrito.
      Nome/descrição do mod também traduzidos (`Translate/<LANG>/Mod.json`, lido por
      `Translator.readModTranslation`; `translations_mod_json`). Ver no jogo: roteiro passo 1.
- [x] `CREDITS.md` lista a origem e a licença de toda textura e som; **nenhum asset de
      terceiros** — sons por `scripts/gen_sounds.py`, imagens por `scripts/gen_images.py`
      (fonte embutida do Pillow, CC0), vanilla só por nome/GUID. `tests/test_credits.lua`
      falha com `.png/.ogg/.wav` fora do `CREDITS.md` (`credits_every_binary_asset_listed`)
      ou GUID vanilla não listado (`credits_vanilla_guids_listed`).
- [x] Thumbnail (256×256) e `poster.png` do mod — `docs/workshop/preview.png` 256×256
      (82 862 bytes; o build confere as regras de `SteamWorkshopItem.validatePreviewImage`,
      `build_refuses_bad_preview`), `mod/42/poster.png` 512×512 e `mod/42/icon.png` 64×64
      ligados no `mod.info` (`credits_modinfo_assets_exist`, `modinfo_lines_match_own_key`).
      Ver no jogo: roteiro passo 1.
- [ ] Página do Workshop em EN e PT-BR: o que faz, sandbox, compatibilidade, link do
      GitHub — **texto pronto** em `docs/workshop/description-{en,ptbr}.txt` (BBCode,
      5 980 bytes juntos), montado no `workshop.txt` pelo build (`build_creates_layout`);
      falta enviar e ver no Steam: [publicar.md §2–3](../../publicar.md#2-enviar-pelo-jogo-5-min)
- [ ] Mod baixado do Workshop numa instalação limpa funciona em solo e num servidor
      dedicado — falta o Steam: [publicar.md §4](../../publicar.md#4-testar-a-cópia-do-workshop-numa-instalação-limpa-20-min)
- [ ] Release `v1.0.0` taggeada no GitHub apontando pro mesmo commit publicado — espera o
      teste in-game e o envio: [publicar.md §5](../../publicar.md#5-abrir-pra-todo-mundo-e-taggear-2-min)

`./run-tests.sh`: `total=299 passou=299 falhou=0` (Lua) e `build total=10 passou=10
falhou=0` (`tests/test_build_workshop.sh`, `HOME` temporário).

## Roteiro in-game

Pré-requisito: o [teste in-game consolidado](../../teste-in-game.md) inteiro. Desta sprint:

1. **Lista de mods** ([teste-in-game 1.1](../../teste-in-game.md#11-menu-e-carga-5-min)):
   "Névoa e Outro Mundo" disponível (o `versionMin=42.20` não esconde no 42.20.4), ícone
   na linha, poster no painel de informações, descrição em PT-BR; trocando o idioma pra
   inglês, descrição em inglês. Nenhum `JSON Error in:` nem `Found look-a-like unicode
   char` no `console.txt`.
2. **Build:** `scripts/build-workshop.sh` imprime as 5 linhas do
   [publicar.md §1](../../publicar.md#1-montar-a-pasta-de-upload-1-min); na página 1 do
   envio o jogo aceita a pasta (nenhuma mensagem `UI_WorkshopError_*`).
3. **Envio, página do Steam, instalação limpa (solo e dedicado), release:**
   [publicar.md §2–5](../../publicar.md#2-enviar-pelo-jogo-5-min). No dedicado, esperado
   no console do servidor o download do item e, de noite com `-debug`, `[NOM] noite`.

## Checkpoints

- **04/10/2026** — Pesquisa no bytecode: formato do `mod.info` (casamento por
  `contains`), `Mod.json`, JSON estrito e exceção de caractere parecido no EN,
  `workshop.txt` reescrito pelo jogo com o `id=`, regras da preview, ordem de busca de
  mods (`workshop,steam,mods`). Tudo em [pz-api-notes §9](../../architecture/pz-api-notes.md#9-publicação-modinfo-traduções-e-workshop-sprint-0007).
- **04/10/2026** — Auditoria de traduções (nenhuma chave faltando; a checagem antiga do
  `test_config` ficou só com os defaults) e `Mod.json` EN/PT-BR.
- **04/10/2026** — Imagens geradas (`gen_images.py`), `mod.info` 1.0.0 com poster, ícone,
  `url=` e `versionMin=42.20`; `CREDITS.md` reescrito e auditado por teste.
- **04/10/2026** — Página do Workshop em EN e PT-BR e `scripts/build-workshop.sh` com
  teste; `docs/publicar.md`, README e roteiro in-game atualizados. 299 + 10 testes.

## Aprendizados

1. **A pasta de upload do Workshop ganha do symlink de dev.** O jogo procura mods em
   `~/Zomboid/Workshop/` (uploads), itens inscritos e `~/Zomboid/mods/`, nessa ordem, e
   fica com o primeiro `id` igual. Depois de um `build-workshop.sh`, o jogo roda a cópia
   do build, não o código do repo: testar mudança sem apagar a pasta é testar código velho.
2. **O jogo reescreve o `workshop.txt`** ao sair da página 2 e ao criar o item, e é ali
   que o `id=` do item fica. Gerar o arquivo de novo sem esse `id=` faz o próximo envio
   criar **outro item** no Steam. O build preserva `id=` e `visibility=`.
3. **`mod.info` casa linha por `contains`, numa cadeia em ordem fixa:** um valor que
   contenha `name=` ou `id=` (uma URL com `?id=`, por exemplo) vira essa chave.
4. **Tradução EN com aspas curvas derruba o carregamento:** todo JSON EN (menos o
   `Mod.json`) passa por uma checagem de caractere "parecido com ASCII" que lança
   `IllegalStateException`; e o JSON é lido em modo estrito (vírgula sobrando é erro).
5. **A fonte embutida do Pillow não tem `É`** (renderiza um `.notdef` igual pra qualquer
   acento): o acento do título é desenhado à mão.

## Pendências que a próxima sprint herda

- Rodar o [teste in-game consolidado](../../teste-in-game.md) e, depois, o
  [publicar.md](../../publicar.md) inteiro; marcar os 3 critérios abertos com o ID do
  item, o console e a URL da release.
- Depois do envio: link do Workshop no `README.md` (hoje "em breve") e o ID nas notas
  da release.
- Caixa de descrição da página 2 do envio corta texto longo? Não dá pra saber pelo
  bytecode (pz-api-notes, UNKNOWN 12): conferir no Steam ([publicar.md §3](../../publicar.md#3-conferir-a-página-2-min)).
- Visual próprio das variantes e do Eco segue `later` (ver sprint 0006): a página do
  Workshop diz isso em "Known limits".

## Sessões

- 2026-10-04 — abd764e2-7a9a-416b-b9b3-1630ab9e761f — plano e preparação da publicação (sem o jogo)
