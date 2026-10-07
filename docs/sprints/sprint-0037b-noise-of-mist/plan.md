# Mini-sprint 0037b: NOM: Noise of Mist (plano de implementação)

> Para agentes: executar tarefa por tarefa, com TDD. Code review só no fim da entrega (decisão do Johan, 2026-10-06).

**Objetivo:** o mod passa a se chamar **"NOM: Noise of Mist"**, com IDs, imagens de lançamento e um mod de
staging que convive com o oficial no jogo (AGENTS.md, "Desenvolvimento x lançado", decisão do Johan, 2026-10-06).

Fora: qualquer mudança de comportamento do mod; merge, push e `dev-sync.sh` de verdade (o Johan faz).

## Mapa de IDs

| Mod | ID antigo | ID oficial (repo e Workshop) | ID de staging (só a cópia do `dev-sync.sh`) |
|-----|-----------|------------------------------|---------------------------------------------|
| principal (`mod/`) | `NevoaEOutroMundo` | `NoiseOfMist` | `NoiseOfMist_Staging` |
| shader (`mod2/`) | `NevoaEOutroMundo_Shader` | `NoiseOfMist_Shader` | `NoiseOfMist_Shader_Staging` |
| volumétrica (`mod3/`) | `NevoaEOutroMundo_Volumetrica` | `NoiseOfMist_Volumetrica` | `NoiseOfMist_Volumetrica_Staging` |

**Não mudam** (save e MP): canal de rede `"NevoaEOutroMundo"`, `ModData.getOrCreate("NevoaEOutroMundo")`, o
namespace das opções de sandbox (`NevoaEOutroMundo.*`), o ID das opções de mod (`PZAPI.ModOptions`),
as chaves de tradução (`Sandbox_NevoaEOutroMundo` etc.) e o prefixo `NOM_`.

## Restrições globais

- Nada da pasta `~/.signing/` entra no repo; o jar do mod3 continua fora do git.
- As imagens de staging não ficam em `mod*/42/`: o repo e o `build-workshop.sh` usam só as oficiais.
- Pastas antigas `NevoaEOutroMundo*` em `Zomboid/mods/` não são apagadas pelo script (saves antigos pedem o ID antigo).

## Tarefas

### 1. IDs e nomes oficiais
- [ ] **Teste primeiro:** `tests/test_build_workshop.sh` confere as pastas `NoiseOfMist*` no upload, `id=` e
  `require=` novos, o jar `NoiseOfMist_Volumetrica.jar`, o título `NOM: Noise of Mist`; `tests/test_shader.lua`
  confere `id=NoiseOfMist_Shader` e `require=NoiseOfMist`; novo teste em `tests/test_credits.lua` confere `id=`,
  `name=` e `require=` dos três `mod.info` (mod3 com `\ZombieBuddy`).
- [ ] `mod*/42/mod.info`: `id=`, `name=`, `require=`, `javaJarFile=`, descrições com o nome novo.
- [ ] `mod2` `Translate/*/Mod.json`: nome e descrição com o nome novo.
- [ ] `scripts/build-workshop.sh`, `scripts/build-mod3.sh`, `scripts/dev-sync.sh` (só os IDs, a cópia de staging é a tarefa 4).
- [ ] **Jar:** `NoiseOfMist_Volumetrica.jar`. Evidência no bytecode do ZombieBuddy 2.3.4: `ZBSVerifier.check`
  procura o `.zbs` como irmão (`resolveSibling(nome + ".zbs")`) e assina `ZBS:<SteamID64>:<sha256>`, sem o
  nome do arquivo; `JavaModInfo` só exige `javaJarFile=` terminando em `.jar` e em `media/java/client/`. A
  aprovação (`ModApprovalsStore$ModEntry`) é por `id` + `jarHash`: o ID novo pede aprovação de novo de qualquer
  jeito (o "Trust author" do Johan cobre). Recompilar com `scripts/build-mod3.sh`.

### 2. Texto pro jogador
- [ ] **Teste primeiro:** `tests/test_translations.lua` recusa "Névoa e Outro Mundo" e "Fog and Otherworld" nos
  valores das traduções do mod e do mod2.
- [ ] `Sandbox_NevoaEOutroMundo`, `UI_NOM_Options`, `UI_NOM_Debug_Title`, `UI_NOM_DebugPanelKey_tooltip` em PTBR e EN:
  "NOM: Noise of Mist" (ou "NOM" no título do painel). Chaves não mudam.

### 3. Imagens do lançamento (arte do Johan)
- [ ] **Teste primeiro:** os testes de imagem (`tests/test_shader.lua`, `tests/test_credits.lua`) passam a cobrir
  os três mods: pôster 512, ícone 64, mod3 igual ao mod2; preview 512; fontes em `docs/art/` (≤ 1024 px, banner
  ≤ 1600); imagens de staging em `docs/art/staging/` e não em `mod*/42/`; tudo citado no `CREDITS.md`.
- [ ] Fontes reduzidas em `docs/art/` (pôster, preview cinza, preview vermelha, ícone em 768 px; banner em 1280 px).
- [ ] `scripts/gen_images.py` reescrito: redimensiona e tinge a arte. Oficial: `mod/42/poster.png` (pôster),
  `mod/42/icon.png`, `docs/workshop/preview.png` (preview cinza); `mod2`/`mod3` com o pôster e o ícone de cores
  separadas (como hoje). Staging: `docs/art/staging/poster.png` (preview vermelha) e `icon.png` (ícone avermelhado).
- [ ] `CREDITS.md` ("arte de lançamento: Johan") e ADR-019 (exceção à regra de tudo gerado por script).

### 4. `dev-sync.sh` copia como staging
- [ ] **Teste primeiro:** `tests/test_dev_sync.sh` (entra no `run-tests.sh`) roda o script numa cópia do repo
  com `ZOMBOID_DIR` temporário e confere: pastas `*_Staging`, `id=`, `require=`, `name=[STAGING] …`,
  `incompatible=` do oficial, nome do `Mod.json` do mod2, pôster e ícone de staging, ordem das chaves do
  `mod.info`, aviso das pastas `NevoaEOutroMundo*` (sem apagar) e o repo intacto.
- [ ] Script: `rsync` pra `mods/<ID>_Staging`, depois reescreve o `mod.info` e o `Mod.json` e troca as imagens na cópia.

### 5. Docs
- [ ] README (título, banner), `docs/workshop/description-*.txt`, `docs/publicar.md`, AGENTS.md (tira o "Pendente"),
  HANDOFF (aviso dos saves antigos), README da mini-sprint com roteiro, `docs/sprints/README.md`.

### 6. Fechamento
- [ ] `./run-tests.sh` verde.
