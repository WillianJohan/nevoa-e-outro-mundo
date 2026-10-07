# Mini-sprint 0037b — NOM: Noise of Mist

| Campo | Valor |
|-------|-------|
| Status | em teste (branch `sprint/0037b-noise-of-mist`, sem merge) |
| Branch | `sprint/0037b-noise-of-mist` |
| Plano | [plan.md](plan.md) |
| ADR | [ADR-019](../../architecture/adr-019-arte-de-lancamento.md) (arte de lançamento do Johan) |
| Regra | [AGENTS.md, "Desenvolvimento x lançado"](../../../AGENTS.md) (decisão do Johan, 2026-10-06) |

## Objetivo

O mod passa a se chamar **"NOM: Noise of Mist"**, com a arte de lançamento do Johan, e o mod de
desenvolvimento ganha identidade própria no jogo: o `scripts/dev-sync.sh` instala o **mod de staging**,
que convive com o do Workshop sem um esconder o outro.

## O que entrou

| | Oficial (repo, `build-workshop.sh`, Workshop 3814379207) | Staging (só a cópia do `dev-sync.sh`) |
|---|---|---|
| Mod principal | `NoiseOfMist`, "NOM: Noise of Mist" | `NoiseOfMist_Staging`, "[STAGING] NOM: Noise of Mist" |
| Shader | `NoiseOfMist_Shader`, "NOM: Noise of Mist — Shader (incompatível com ShadowZ)" | `NoiseOfMist_Shader_Staging` |
| Volumétrica | `NoiseOfMist_Volumetrica`, "NOM: Noise of Mist — Volumétrica (Java, ZombieBuddy)" | `NoiseOfMist_Volumetrica_Staging` |
| Pasta | `Workshop/NoiseOfMist/Contents/mods/<ID>` | `mods/<ID>_Staging` |
| Pôster / ícone | parede descascando / "NOM" enferrujado (mod2 e mod3 com as cores separadas) | preview vermelha / "NOM" avermelhado |
| `incompatible=` | — (mod2: `\ShadowZ`) | o oficial correspondente |

- **Não mudaram** (save e MP): o canal de rede, o `ModData`, o namespace das opções de sandbox e o ID das
  opções de mod continuam `NevoaEOutroMundo`; as chaves de tradução e o prefixo `NOM_` também.
- **Texto pro jogador:** página do sandbox e das opções "NOM: Noise of Mist"; painel de debug "NOM: debug".
- **Jar do mod3:** `NoiseOfMist_Volumetrica.jar`. No bytecode do ZombieBuddy 2.3.4, o `ZBSVerifier` acha a
  assinatura como o arquivo irmão `<jar>.zbs` e assina `ZBS:<SteamID64>:<sha256 do jar>`, sem o nome; o
  `JavaModInfo` só exige `javaJarFile=` terminando em `.jar` em `media/java/client/`. A aprovação do ZB é
  por ID do mod + hash do jar, então o ID novo pede aprovação de novo de qualquer jeito (o "Trust author"
  do Johan deve cobrir). Recompilado e assinado com `scripts/build-mod3.sh`.
- **Imagens:** fontes reduzidas em `docs/art/` (768 px; banner 1280 px), finais pelo `scripts/gen_images.py`:
  pôster 512 e ícone 64 nos três mods, preview 512 no Workshop, staging em `docs/art/staging/`.
- **Testes novos:** `tests/test_dev_sync.sh` (13, no `run-tests.sh`), `launch_art_images` e
  `modinfo_ids_and_names` em `tests/test_credits.lua`, `translations_new_mod_name` em
  `tests/test_translations.lua`.

## Saves antigos

Save criado até a 0037 lista os IDs antigos no `mods.txt` da pasta do save
(`Zomboid/Saves/<modo>/<save>/mods.txt`, linhas `mod = NevoaEOutroMundo,` etc.) e pede esses IDs pra abrir.
O `dev-sync.sh` **não apaga** as pastas `mods/NevoaEOutroMundo*`; só avisa que existem. Dois caminhos:

1. **Jogar o save antigo como estava:** deixar as pastas antigas onde estão. O save abre com a cópia
   antiga (a do último sync antes da 0037b), sem as novidades.
2. **Passar o save pro mod de staging:** com o jogo fechado, copiar a pasta do save (backup) e trocar no
   `mods.txt` `NevoaEOutroMundo` → `NoiseOfMist_Staging`, `NevoaEOutroMundo_Shader` →
   `NoiseOfMist_Shader_Staging`, `NevoaEOutroMundo_Volumetrica` → `NoiseOfMist_Volumetrica_Staging`.
   Opções de sandbox e `ModData` continuam valendo, porque os nomes de espaço no Lua não mudaram.

Nunca ativar o mod antigo junto com o novo no mesmo save: os arquivos Lua têm os mesmos nomes. Quando não
precisar mais dos saves antigos, apagar `mods/NevoaEOutroMundo*`.

## Roteiro de teste no jogo

1. `scripts/dev-sync.sh` com a `staging` no checkout (depois do merge) e reiniciar o jogo. O script avisa
   das pastas `NevoaEOutroMundo*`, que ficam.
2. Menu Mods: aparecem **"[STAGING] NOM: Noise of Mist"** (pôster vermelho, ícone avermelhado), o Shader e a
   Volumétrica de staging. Com o item do Workshop inscrito, "NOM: Noise of Mist" oficial aparece separado.
3. Ativar o de staging e tentar ativar o oficial junto: o jogo recusa (incompatível).
4. Volumétrica de staging: na janela do ZombieBuddy, aprovar o jar `NoiseOfMist_Volumetrica.jar` se ela
   perguntar; a névoa volumétrica aparece como antes.
5. Save novo: página do sandbox "NOM: Noise of Mist" com as opções de sempre; Opções > Mods com a seção
   "NOM: Noise of Mist"; no `-debug`, o painel (Insert) com o título "NOM: debug".
6. Save antigo passado pro staging (caminho 2 acima): abre, as opções de sandbox estão como antes.
