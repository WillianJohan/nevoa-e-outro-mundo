# Publicação no Workshop (preparação) — Plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deixar tudo pronto pra o Johan publicar o mod no Workshop em ~10 minutos depois que o teste in-game passar: traduções auditadas, créditos fechados, imagens, página do Workshop em EN e PT-BR, script que monta a pasta de upload, passo a passo e README atualizados.

**Architecture:** Nada muda no Lua do jogo. Entram: um teste que audita as chaves de tradução contra o `sandbox-options.txt` e o Lua; um `Mod.json` por idioma (o jogo traduz nome/descrição do mod por ele); imagens geradas por `scripts/gen_images.py` (PIL, desenho original); descrições do Workshop em BBCode em `docs/workshop/`; `scripts/build-workshop.sh`, que monta `~/Zomboid/Workshop/NevoaEOutroMundo/` a partir do repo e **gera** o `workshop.txt` (descrição EN + PT-BR), preservando o `id=` e o `visibility=` que o jogo grava de volta depois do primeiro upload.

**Tech Stack:** Lua 5.1 (luajit nos testes), bash, Python 3 + Pillow 12.

**Spec:** [README da sprint](README.md), brief da sprint 0007, [pz-api-notes](../../architecture/pz-api-notes.md) (§9 nova, desta sprint).

## Global Constraints

- Kahlua/Lua 5.1 nos testes também (sem `//`, sem `goto`).
- Todo texto que o jogador vê por chave de tradução, PTBR e EN, em `media/lua/shared/Translate/<LANG>/*.json`.
- Nada copiado de outro mod nem do jogo. Imagens geradas por script commitado; nada de screenshot do jogo.
- Toda afirmação sobre o jogo com evidência (Lua vanilla arquivo:linha ou bytecode).
- O build nunca escreve fora de `$HOME/Zomboid/Workshop/NevoaEOutroMundo`; os testes rodam com `HOME` temporário.
- Upload no Steam e tag `v1.0.0` são do Johan, depois do teste in-game: o plano só deixa os passos prontos ([publicar.md](../../publicar.md)).
- Comentários e docs em PT-BR com acento.

## Pesquisa (bytecode B42.20.4) que decide o desenho

- **`mod.info`** (`ChooseGameInfo.readModInfoAux`): chaves `name`, `poster` (várias), `description`, `require`, `id`, `author`, `modversion`, `icon`, `category`, `url`, `versionMin`, `versionMax`… Cada linha casa por `contains` numa cadeia `if/else` nessa ordem: um valor que contenha `name=` vira nome. `poster=`/`icon=` resolvem primeiro em `42/` e caem em `common/` (offsets 221–272, 652–700).
- **`versionMin=42.20`**: `GameVersion.parse` usa `([0-9]+)\.([0-9]+)(.*)`; `getInt = major*1000+minor`; `isAvailableSelf` só recusa se `versionMin.isGreaterThan(atual)` (compara `getInt`): 42.20.4 = 42020, aceita.
- **Tradução do mod.info:** `Translator.readModTranslation` lê `Translate/<LANG>/Mod.json` (de `common/` e de `42/`) e troca `name`/`description` do mod se a chave existir.
- **EN com caractere "parecido" derruba:** `Translator.tryFillMapFromFile` chama `cryAboutUnicodeConfusables` pra todo JSON EN que não seja `Mod`, e ele lança `IllegalStateException`. JSON é lido em modo estrito (`JSONParserConfiguration.withStrictMode(true)`): vírgula sobrando quebra.
- **`workshop.txt`** (`SteamWorkshopItem.readWorkshopTxt`): linhas `version=`, `id=`, `title=`, `description=` (uma por linha, juntadas com `\n`), `tags=` (separadas por `;`, permitidas em `media/WorkshopTags.txt`), `visibility=` (`public`/`friendsOnly`/`private`/`unlisted`); `#` e `//` são comentário. O jogo **reescreve** o arquivo (`writeWorkshopTxt`) ao avançar a página 2 e ao criar o item (`client/OptionScreens/WorkshopSubmitScreen.lua:351, 1157-1158`), gravando o `id=`.
- **Preview** (`validatePreviewImage`): PNG quadrado de 256 ou 512 px, menor que 1 024 000 bytes. **Conteúdo** (`validateContents`/`validateModFolder`/`validateFileTypes`): em `Contents/` só `mods/`; no mod, pastas `common` ou de versão (`42`); nada de `.sh .zip .exe .dll .bat .app .dylib .so`.
- **Ordem das pastas de mod:** `getAllModFolders` usa `workshop,steam,mods` e `getModDetails` para no primeiro `id` igual: a cópia em `~/Zomboid/Workshop/` **ganha** do symlink em `~/Zomboid/mods/`.
- Ícone: desenhado a 28 px na lista (`ModOrderListBox.lua:235`); poster pelo painel de info (`ModInfoPanelDesc.lua:37`).

## Review Focus

1. **Segundo build depois do primeiro upload** — o jogo gravou `id=` e a visibilidade escolhida no `workshop.txt`; o build seguinte tem de manter os dois, senão o próximo upload cria um item novo. Teste: `build_preserves_id_and_visibility` (Task 4).
2. **Arquivo apagado do mod continua no upload** — build idempotente remove o que saiu do repo. Teste: `build_removes_stale_files` (Task 4).
3. **Descrição longa demais pro Steam** (8000 caracteres, e o jogo ainda anexa "Workshop ID/Mod ID") — o build recusa acima de 7900 bytes. Teste: `build_refuses_long_description` (Task 4).
4. **Preview fora da regra do jogo** (tamanho/dimensão) — o build recusa antes do jogo recusar. Teste: `build_refuses_bad_preview` (Task 4).
5. **Tradução EN com acento/aspas curvas** (o jogo lança exceção) **ou JSON com vírgula sobrando** (modo estrito). Testes: `translations_en_is_ascii`, `translations_json_commas` (Task 1).

---

### Task 1: Auditoria de traduções + `Mod.json`

**Files:**
- Create: `tests/test_translations.lua`, `mod/42/media/lua/shared/Translate/EN/Mod.json`, `mod/42/media/lua/shared/Translate/PTBR/Mod.json`
- Modify: `tests/run.lua` (registrar)

**Interfaces:** Produces: nada pro código do mod; o teste é a auditoria.

- [ ] **Step 1: teste que falha.** `tests/test_translations.lua` lê `sandbox-options.txt` (`page = X` → `Sandbox_X`; `translation = X` → `Sandbox_X` e `Sandbox_X_tooltip`), o Lua do mod (`getText("K")`/`getTextOrNull("K")` literais) e os JSON de cada idioma, e afirma:
  - `translations_same_files_per_language`: EN e PTBR têm os mesmos arquivos, e `Mod.json` existe.
  - `translations_sandbox_keys_exact`: chaves do `Sandbox.json` de cada idioma = exatamente as usadas (falta → falha com o nome; sobra → falha com o nome).
  - `translations_lua_keys_defined`: toda chave literal de `getText` existe em todos os idiomas.
  - `translations_mod_json`: `Mod.json` com as mesmas chaves nos dois idiomas, só `name`/`description`, valores não vazios.
  - `translations_no_empty_values`, `translations_en_is_ascii` (exceto `Mod.json`), `translations_json_commas` (toda entrada termina com vírgula, menos a última; nenhuma linha fora de `"k": "v"`/chaves; nenhuma chave repetida).
- [ ] **Step 2:** `./run-tests.sh` → falha em `translations_same_files_per_language` e `translations_mod_json` (sem `Mod.json`).
- [ ] **Step 3:** criar os `Mod.json` (`description` em cada idioma; o nome fica o do `mod.info`, nome próprio).
- [ ] **Step 4:** `./run-tests.sh` → tudo passa. Conferir que `translations_sandbox_keys_exact` falha se eu apagar uma chave (teste do teste, revertido).
- [ ] **Step 5:** commit `test: auditoria de traduções EN/PTBR e Mod.json com a descrição do mod`.

### Task 2: Imagens + `mod.info` + créditos auditados

**Files:**
- Create: `scripts/gen_images.py`, `mod/42/poster.png` (512×512), `mod/42/icon.png` (64×64), `docs/workshop/preview.png` (256×256), `tests/test_credits.lua`
- Modify: `mod/42/mod.info`, `CREDITS.md`, `tests/run.lua`

- [ ] **Step 1: teste que falha.** `tests/test_credits.lua`:
  - `credits_every_binary_asset_listed`: todo `.png/.ogg/.wav` em `mod/` e `docs/workshop/` aparece pelo nome no `CREDITS.md`.
  - `credits_generators_exist`: `scripts/gen_sounds.py` e `scripts/gen_images.py` existem e são citados.
  - `credits_vanilla_guids_listed`: todo `itemGUID` do `clothing.xml` aparece no `CREDITS.md`.
  - `credits_modinfo_assets_exist`: cada `poster=`/`icon=` do `mod.info` aponta pra arquivo existente em `mod/42/`; `url=` é o GitHub; `versionMin=42.20`.
- [ ] **Step 2:** `./run-tests.sh` → falha (sem imagens, sem `poster=`).
- [ ] **Step 3:** `scripts/gen_images.py`: fundo quase preto com névoa em camadas (ruído suavizado por gaussiana, semente fixa), silhueta vaga de poste e figura ao longe, vinheta, título "NÉVOA E OUTRO MUNDO" na fonte embutida do Pillow (Aileron, sem `É`/`é`: o acento é desenhado à mão), subtítulo "Project Zomboid · Build 42". Ícone: só o "N" na névoa. Rodar e commitar os PNG.
- [ ] **Step 4:** `mod.info`: `poster=poster.png`, `icon=icon.png`, `url=https://github.com/WillianJohan/nevoa-e-outro-mundo`, `modversion=1.0.0`, `versionMin=42.20`. `CREDITS.md`: seção Imagens (gerador, fonte), seção Vanilla por nome (GUIDs, sprites de overlay, efeito SearchMode), "nada de terceiros".
- [ ] **Step 5:** `./run-tests.sh` passa; commit `feat: poster, ícone e preview gerados por script, mod.info 1.0.0 e créditos auditados`.

### Task 3: Página do Workshop (BBCode)

**Files:** Create: `docs/workshop/description-en.txt`, `docs/workshop/description-ptbr.txt`

- [ ] Texto: o que faz (noite, Eco, Estalador, Corredor, névoa, Sem-rosto, vinheta), opções de sandbox (todas, com padrão), MP (servidor decide; som/vinheta/manchas locais), compatibilidade (B42.20+, `versionMin`), limites conhecidos (sem visual próprio das variantes, presets só documentados, remover o mod é seguro), link do GitHub. EN natural, não tradução literal.
- [ ] Tamanho conferido pelo build da Task 4 (≤ 7900 bytes juntos).
- [ ] Commit `docs: página do Workshop em EN e PT-BR (BBCode)`.

### Task 4: `scripts/build-workshop.sh`

**Files:** Create: `scripts/build-workshop.sh`, `tests/test_build_workshop.sh`; Modify: `run-tests.sh`

- [ ] **Step 1: teste que falha** (`tests/test_build_workshop.sh`, bash, `HOME` temporário, cópia do repo em temp pros casos de erro):
  - `build_creates_layout`: `Contents/mods/NevoaEOutroMundo/{42/mod.info,common}`, `preview.png`, `workshop.txt` com `version=1`, `title=`, `tags=Build 42;Hardmode;Multiplayer`, `visibility=unlisted`, primeira e última linha da descrição EN e PT.
  - `build_excludes_repo_only`: nada de `docs/ tests/ scripts/ .git` no destino; nenhum tipo de arquivo que o jogo recusa.
  - `build_is_idempotent`: segundo build → mesma árvore (hash).
  - `build_preserves_id_and_visibility`: `id=123` e `visibility=public` gravados à mão sobrevivem.
  - `build_removes_stale_files`: arquivo a mais em `Contents/` some.
  - `build_dry_run_writes_nothing`.
  - `build_refuses_long_description`, `build_refuses_bad_preview`: saída ≠ 0 e nada escrito.
- [ ] **Step 2:** rodar → falha (script não existe).
- [ ] **Step 3:** script (bash, `set -euo pipefail`): valida preview (`file`: PNG, 256 ou 512 quadrado, < 1 024 000 bytes) e tamanho da descrição antes de escrever; lê `id=`/`visibility=` do `workshop.txt` existente; apaga e recopia `Contents/mods/NevoaEOutroMundo` a partir de `mod/`; copia `preview.png`; gera `workshop.txt`; imprime cada ação; `--dry-run` só imprime.
- [ ] **Step 4:** `run-tests.sh` roda o Lua e o teste do build; tudo passa.
- [ ] **Step 5:** commit `feat: build-workshop.sh monta a pasta de upload (idempotente, preserva id e visibilidade)`.

### Task 5: Docs

- [ ] `docs/publicar.md`: pré-requisito (teste in-game passou), build, abrir o jogo, Workshop → item → páginas 1–5, visibilidade `unlisted` no primeiro upload, conferir a instalação limpa (tirar o symlink e a pasta de staging), mudar pra `public`, tag `v1.0.0` + `gh release` no commit publicado, atualizar depois.
- [ ] `README.md`: estado (0001–0007), links pro roteiro e pro publicar, instalar (jogador: Workshop; dev: symlink, e o aviso de que o staging do Workshop ganha do symlink).
- [ ] `pz-api-notes.md` §9 (bytecode acima); `architecture/README.md` (estrutura com `Mod.json`, imagens, scripts).
- [ ] Sprint README: status `em teste`, critérios com evidência ou no Roteiro in-game, Checkpoints, Aprendizados, Pendências, Sessões; `docs/sprints/README.md` → `em teste`.
- [ ] Commit `docs: publicar.md, README, §9 do pz-api-notes e sprint 0007 em teste`.
