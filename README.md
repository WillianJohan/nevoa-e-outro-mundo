# Névoa e Outro Mundo

Mod de horror para **Project Zomboid (Build 42)**, inspirado em The Last of Us e
Silent Hill. Para o Steam Workshop, funciona em solo e multiplayer.

**A noite traz infectados de carne. A névoa traz o Outro Mundo.**

- À noite, bem mais escura que a vanilla, os zumbis caçam, enxergam e ouvem mais longe.
- Corpos de quem morreu antes do anoitecer soltam **Ecos**: almas fracas que somem
  com o sol. Queime ou enterre os mortos.
- A cada ~3 dias, numa hora qualquer, uma sirene toca; 30 segundos depois vem a névoa
  (de 2 a 6 horas, de dia ou de noite): o mundo escurece, o rádio chia e o Outro Mundo
  aparece: Estaladores (cegos, guiados por som), Corredores (gritam e chamam a horda),
  o **Sem-rosto** — olhe pra ele e ele some. Pra reaparecer mais perto — e a
  **Carpideira**, parada, chorando baixinho, até alguém acordá-la.
- Às vezes a sirene toca mais grave e rasgada: é a **névoa vermelha**, onde todo zumbi
  é monstro.

> Estado: **pronto pra publicar, esperando o teste in-game.** Sprints 0001–0015
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
| Ajustes do 1º teste | noite escura pela luz global, monstros só na névoa (5/2/5), Eco só de quem morreu antes do anoitecer | 0008 |
| Névoa como evento | sirene 30 s reais antes, hora aleatória a cada ~3 dias, 2–6 h; névoa natural do jogo some | 0009 |
| Névoa vermelha | 10% das névoas: sirene própria, névoa e luz vermelhas, todo zumbi é monstro (1/4 de cada) | 0010 |
| Carpideira | parada e soluçando na névoa; perto, lanterna ou tiro a acordam: grita (horda a 60 tiles) e caça quem a acordou | 0011 |
| Visual dos monstros | cada monstro com pele e peça próprias na névoa (venda, boca rasgada, rosto de chiado, cabelo caído); Eco de cinza e fumaça; contraste cheio e formas grandes pra ler sob a névoa | 0012, 0014 |
| Efeitos de tela | na névoa, grão de filme, vinheta que respira (vermelha na vermelha), chiado perto do Sem-rosto e pulso no grito da Carpideira; opção de cada jogador; shader opcional num segundo mod (sem ShadowZ) | 0013 |
| Outro Mundo sangrento | na névoa, poças e rastros de sangue, sujeira, rachaduras, musgo e trepadeiras no chão e nas paredes em volta (mais na vermelha); só na tela, nada no save; densidade de cada jogador | 0015 |

Tudo configurável na página "Névoa e Outro Mundo" do sandbox ([opções e presets](docs/gdd/sandbox.md)).

> **Steam Flatpak (o caso deste PC):** o jogo roda em sandbox e a pasta de dados é
> `~/.var/app/com.valvesoftware.Steam/Zomboid`, não `~/Zomboid` — vale pra `mods/`,
> `Workshop/` e `console.txt` em todo este documento. Mod de dev: **`scripts/dev-sync.sh`** copia `mod/`
> pra pasta de mods do jogo (rodar de novo a cada mudança e recarregar o save). **Não use
> symlink**: com link o jogo não lê `media/scripts/*.txt` (itens de visual somem).
> O `build-workshop.sh` detecta essa pasta sozinho (ou use `ZOMBOID_DIR=...`).

## Instalar

**Jogador:** inscrever-se no item do Steam Workshop (link em breve, depois da
publicação) e ativar "Névoa e Outro Mundo" em Mods. Requer Build 42.20 ou mais novo.
Em servidor: `WorkshopItems=<ID>` e `Mods=NevoaEOutroMundo` no `.ini` (se não carregar,
`Mods=\NevoaEOutroMundo`; a confirmar no teste do dedicado, [publicar.md §4](docs/publicar.md#servidor-dedicado)).

**Dev:** cópia do repositório na pasta de mods (`mod/` e o shader opcional `mod2/`):

```bash
scripts/dev-sync.sh
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
mod2/              ← mod opcional do shader (NevoaEOutroMundo_Shader, sprint 0013)
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

- Project Zomboid **Build 42**: desenvolvido contra 42.20.4; publicação verificada contra 42.21.
- Lua do mod em `mod/42/media/` + `mod/common/` (estrutura de mod do B42.20).
- Testes: `brew install luajit`, depois `./run-tests.sh` (lógica pura, traduções,
  créditos, contraste das texturas com Python + numpy + Pillow, e o build do Workshop, com `HOME` temporário).
- Teste in-game com o jogo em modo `-debug`: [roteiro consolidado](docs/teste-in-game.md).
- Sons, imagens e texturas são gerados por script (`scripts/gen_sounds.py`, `scripts/gen_images.py`,
  `scripts/gen_textures.py`; prévia das texturas no tamanho do jogo: `scripts/preview_textures.py`);
  nada de terceiros ([CREDITS.md](CREDITS.md)).
- Publicar e atualizar no Workshop: [docs/publicar.md](docs/publicar.md)
  (`scripts/build-workshop.sh` monta a pasta de upload).

## Acordo de trabalho

O autor orienta, a IA implementa — e **contesta com explicação** se a orientação
parecer equivocada.

## Licença

[MIT](LICENSE). Project Zomboid é propriedade da The Indie Stone; este mod requer
uma cópia original do jogo.
