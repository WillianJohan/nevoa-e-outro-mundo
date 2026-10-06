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

## Fluxo de sprint (decisão do Johan, 2026-10-05)

1. Branch `sprint/00NN-slug` saindo da `main`.
2. Plano, TDD e docs da sprint em `docs/sprints/sprint-00NN-slug/`.
3. **Code review só no final de cada entrega** (decisão do Johan, 2026-10-06).
4. Testes verdes, merge na `main`, push, `scripts/dev-sync.sh`.
5. O Johan testa no jogo e reinicia o jogo depois de cada sync.

Commits pequenos, mensagem em português.
