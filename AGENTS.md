# AGENTS.md — regras pra qualquer agente (Cursor, Claude, etc.)

Antes de tudo, leia **[docs/HANDOFF.md](docs/HANDOFF.md)**: estado atual, o que está em andamento e o próximo passo.

## Regras que não se negociam

- **Nada copiado de outros mods.** Mods instalados (inclusive ShadowZ) servem só pra saber qual API existe. Sprites e outfits vanilla são referenciados por nome; nenhum arquivo do jogo ou de terceiros entra no repo. Texturas e sons são gerados por scripts nossos (`scripts/gen_*.py`).
- **Lua roda em Kahlua (subset de Lua 5.1):**
  - não tem `next()`, `//`, `goto` nem operadores de bit;
  - use `unpack`, nunca `table.unpack`;
  - `%` trunca, então use `NOM_Math.mod`;
  - `%` sozinho em tradução quebra o Formatter do Java: escreva `%%`;
  - `/*` dentro de comentário de script (`media/scripts/*.txt`) aninha e apaga o resto do arquivo.
  Os lints em `tests/` pegam esses casos.
- **O servidor decide e quem simula aplica** (ADR-002/005). Arquivo em `lua/server/` começa com `if isClient() then return end`. Lógica pura vai em `lua/shared/`, sem API do jogo, testada com luajit.
- **Toda chamada de API precisa de evidência**: arquivo e linha do Lua vanilla, ou bytecode. Veja `docs/architecture/pz-api-notes.md` antes. Fake de teste modela o jogo de verdade, nunca é stub bonzinho.
- **Texto pro jogador** sempre por chave de tradução PTBR + EN (`media/lua/shared/Translate/`).
- Comentários e docs em português BR com acento.
- **Todo comando de debug (`NOM.*` em `client/NOM_Console.lua`) também ganha botão no `NOM.panel()`** (`client/NOM_DebugPanel.lua`). Decisão do Johan, 2026-10-06.

## Comandos

```bash
./run-tests.sh            # todos os testes (luajit, contraste em python, build)
scripts/dev-sync.sh       # COPIA mod/ e mod2/ pra pasta de mods do jogo (symlink quebra o ScriptManager)
```

- **Jogo:** Steam via Flatpak, instalado em `/mnt/stuff/steam/steamapps/common/ProjectZomboid/projectzomboid`.
- **Dados e log:** `~/.var/app/com.valvesoftware.Steam/Zomboid/console.txt`.
- **Opções de inicialização:** `-javaagent:ZombieBuddy.jar -- -debug`.

## Desenvolvimento x lançado (decisão do Johan, 2026-10-06)

O mod em desenvolvimento e o mod lançado ficam separados **no git e no jogo**.

**No git:**

- **`main` = o mod lançado.** É o que está (ou vai estar) no Steam Workshop. Só recebe merge da `staging` na hora de lançar uma versão, ou um `hotfix/*`. Cada lançamento é um commit da `main` com tag `vX.Y.Z` ([docs/publicar.md](docs/publicar.md)).
- **`staging` = o mod em desenvolvimento.** Toda sprint e toda funcionalidade é mergeada aqui. É o que o Johan testa no jogo.
- **Nunca mergear sprint direto na `main`.** O merge `staging` → `main` é decisão do Johan, junto com o número da versão.
- **Hotfix do lançado:** `hotfix/slug` saindo da `main`, merge `--no-ff` na `main` e depois na `staging`, pra a correção não se perder no próximo lançamento.

**No jogo:**

- **O mod lançado** é o do Workshop (inscrição na Steam), com o ID e o nome oficiais.
- **O mod de desenvolvimento** é o que o `scripts/dev-sync.sh` copia pra `Zomboid/mods/`, com **ID e nome próprios**: ID com sufixo `_Dev` (também no `require=` dos mods opcionais) e nome com `[DEV]` na lista de mods. Assim os dois ficam instalados ao mesmo tempo e o Johan escolhe qual ativar em cada save.
- **Nunca os dois ativos no mesmo save**: os arquivos Lua têm os mesmos nomes e um sobrescreve o outro. O `mod.info` de desenvolvimento marca o lançado como `incompatible=`.
- O ID `_Dev` e o `[DEV]` existem **só na cópia do `dev-sync.sh`**; o repo e o `build-workshop.sh` usam sempre o ID e o nome oficiais. Os nomes de espaço no Lua (canal de rede, `ModData`, ID das opções) não mudam.
- Save criado com o mod de desenvolvimento pede o mod de desenvolvimento pra abrir (e vice-versa).
- **Pendente:** o `dev-sync.sh` ainda copia com o ID oficial. A troca entra na mini-sprint da renomeação pra "NOM: Noise of Mist" (logo depois da 0037), junto com os IDs novos (`NoiseOfMist` e `NoiseOfMist_Dev`).

## Fluxo de sprint (decisão do Johan, 2026-10-05; branches de 2026-10-06)

1. Branch `sprint/00NN-slug` saindo da `staging`.
2. Plano, TDD e docs da sprint em `docs/sprints/sprint-00NN-slug/`.
3. **Code review só no final de cada entrega** (decisão do Johan, 2026-10-06).
4. Testes verdes, merge `--no-ff` na `staging`, push, `scripts/dev-sync.sh` com a `staging` no checkout (o sync copia a branch que estiver no checkout).
5. O Johan testa no jogo, com o mod de desenvolvimento, e reinicia o jogo depois de cada sync.

## Lançar uma versão

1. O Johan decide o que da `staging` vira versão e o número (`modversion=` nos `mod.info`).
2. Testes verdes na `staging`, merge `--no-ff` da `staging` na `main` ("Lançamento vX.Y.Z: ..."), push.
3. Na `main`: `scripts/build-workshop.sh`, envio pelo jogo e tag `vX.Y.Z` ([docs/publicar.md](docs/publicar.md)).

Commits pequenos, mensagem em português.
