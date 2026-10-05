# Névoa e Outro Mundo

Mod de horror para **Project Zomboid (Build 42)**, inspirado em The Last of Us e
Silent Hill. Para o Steam Workshop, funciona em solo e multiplayer.

**A noite traz infectados de carne. A névoa traz o Outro Mundo.**

- À noite, os zumbis caçam, enxergam e ouvem mais longe. Surgem Estaladores
  (cegos, guiados por som) e Corredores (gritam e chamam a horda).
- Corpos deixados no chão soltam **Ecos**: almas fracas que somem com o sol.
  Queime ou enterre os mortos.
- Com névoa forte, o mundo escurece, o rádio chia e o **Sem-rosto** aparece.
  Olhe pra ele e ele some. Pra reaparecer mais perto.

> Estado: **pronto pra publicar, esperando o teste in-game.** Sprints 0001–0007
> implementadas; falta a sessão no jogo ([roteiro](docs/teste-in-game.md)) e, depois
> dela, o envio pro Workshop ([publicar](docs/publicar.md)). Ver o [roadmap](docs/sprints/README.md).

### O que já está no mod

| Sistema | O que faz | Sprint |
|---|---|---|
| Noite e névoa | detecta a noite e a névoa natural forte; clima mais escuro, dessaturado e tingido | 0001 |
| Eco | corpo perto do jogador solta uma alma fraca à noite, uma vez; sem cadáver nem loot; some ao amanhecer | 0002 |
| Noite agressiva | todo zumbi mais rápido, com sentidos melhores, caça periódica e lanterna que chama | 0003 |
| Estalador e Corredor | cego guiado por som que estala; corredor que grita e chama a horda | 0004 |
| Sem-rosto e atmosfera | some quando visto e volta mais perto; rádio chiando, drone, sangue e ferrugem no chão, vinheta | 0005 |
| Balanceamento, MP e performance | orçamento por sistema travado por teste, comandos de debug, presets documentados | 0006 |
| Publicação | traduções EN/PT-BR auditadas, poster, ícone, página do Workshop, build da pasta de upload | 0007 |

Tudo configurável na página "Névoa e Outro Mundo" do sandbox ([opções e presets](docs/gdd/sandbox.md)).

## Instalar

**Jogador:** inscrever-se no item do Steam Workshop (link em breve, depois da
publicação) e ativar "Névoa e Outro Mundo" em Mods. Requer Build 42.20 ou mais novo.
Em servidor: `WorkshopItems=<ID>` e `Mods=NevoaEOutroMundo` no `.ini`.

**Dev:** symlink do repositório na pasta de mods:

```bash
ln -sfn "$PWD/mod" ~/Zomboid/mods/NevoaEOutroMundo
```

Se existir `~/Zomboid/Workshop/NevoaEOutroMundo/` (criada pelo
`scripts/build-workshop.sh`) ou a inscrição no Workshop, o jogo carrega essa cópia e
**ignora o symlink** ([por quê](docs/publicar.md#o-build-ganha-do-symlink)).

---

## Como este repositório é organizado

A documentação é a fonte da verdade. **Comece sempre pelo
[docs/gdd/Overview.md](docs/gdd/Overview.md).**

```
docs/
├─ gdd/            ← o QUÊ: design do mod, um arquivo por sistema. Hub: Overview.md
├─ architecture/   ← o COMO: ADRs e estrutura técnica
├─ sprints/        ← o QUANDO: roadmap + uma pasta por sprint
│  └─ sprint-NNNN-slug/README.md
├─ workshop/       ← textos e preview da página do Steam Workshop
├─ teste-in-game.md ← roteiro da sessão de teste no jogo
└─ publicar.md     ← passo a passo do Workshop e da release
mod/               ← o mod em si (nasce na sprint 0001)
scripts/           ← geradores de som e imagem, build do Workshop
tests/             ← testes (./run-tests.sh)
```

### Todo doc abre com uma tabela de `Status`

| Status | Significa |
|---|---|
| `accepted` | decidido, é o que vale |
| `draft` | rascunho, sujeito a mudança |
| `later` | norte de longo prazo, **não é escopo** |

Conflito entre GDD e ADR: o GDD manda no **quê**, o ADR manda no **como**.

### Gestão de tarefas por sprint

O trabalho é organizado em **sprints com um objetivo jogável cada**: ao fechar
uma sprint, o mod faz algo novo que dá pra ver no jogo.

O [README de cada sprint](docs/sprints/README.md#formato-do-readme-de-cada-sprint)
funciona como caderno de bordo:

- **Status** — `backlog` → `planejada` → `em andamento` → `em teste` → `concluída`
  (ou `bloqueada: <motivo>`).
- **Critérios de aceite** — marcados só **com a evidência** de como foram confirmados.
- **Checkpoints** — marcos datados, não um diário por commit.
- **Aprendizados** — armadilhas do PZ/Lua que custaram caro descobrir.
- **Pendências** — o que a próxima sprint herda.
- **Sessões** — UUID de cada conversa do Claude Code que trabalhou na sprint,
  pra retomar com `claude --resume <uuid>`.

### Fluxo de git

Uma branch por sprint, que nasce da `main` e morre no merge.

```bash
git checkout -b sprint/0001-estado-e-clima main
# ... trabalho da sprint ...
git checkout main && git merge sprint/0001-estado-e-clima
git push origin main
git branch -d sprint/0001-estado-e-clima
git push origin --delete sprint/0001-estado-e-clima
```

`main` sempre tem a última sprint fechada.

## Desenvolvimento

- Project Zomboid **Build 42** (desenvolvido contra 42.20.4).
- Lua do mod em `mod/42/media/` + `mod/common/` (estrutura de mod do B42.20).
- Testes: `brew install luajit`, depois `./run-tests.sh` (lógica pura, traduções,
  créditos e o build do Workshop, com `HOME` temporário).
- Teste in-game com o jogo em modo `-debug`: [roteiro consolidado](docs/teste-in-game.md).
- Sons e imagens são gerados por script (`scripts/gen_sounds.py`, `scripts/gen_images.py`);
  nada de terceiros ([CREDITS.md](CREDITS.md)).
- Publicar e atualizar no Workshop: [docs/publicar.md](docs/publicar.md)
  (`scripts/build-workshop.sh` monta a pasta de upload).

## Acordo de trabalho

O autor orienta, a IA implementa — e **contesta com explicação** se a orientação
parecer equivocada.

## Licença

[MIT](LICENSE). Project Zomboid é propriedade da The Indie Stone; este mod requer
uma cópia original do jogo.
