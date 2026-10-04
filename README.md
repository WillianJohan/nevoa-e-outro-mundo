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

> Estado: **em design**. Ainda não há código jogável. Ver o [roadmap](docs/sprints/README.md).

---

## Como este repositório é organizado

A documentação é a fonte da verdade. **Comece sempre pelo
[docs/gdd/Overview.md](docs/gdd/Overview.md).**

```
docs/
├─ gdd/            ← o QUÊ: design do mod, um arquivo por sistema. Hub: Overview.md
├─ architecture/   ← o COMO: ADRs e estrutura técnica
└─ sprints/        ← o QUANDO: roadmap + uma pasta por sprint
   └─ sprint-NNNN-slug/README.md
mod/               ← o mod em si (nasce na sprint 0001)
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
- Lua do mod em `mod/42/` + `mod/common/` (estrutura de mod do B42).
- Lógica pura testável com `lua` no terminal (`./run-tests.sh`, a partir da sprint 0001).
- Teste in-game com o jogo em modo `-debug`.

## Acordo de trabalho

O autor orienta, a IA implementa — e **contesta com explicação** se a orientação
parecer equivocada.

## Licença

[MIT](LICENSE). Project Zomboid é propriedade da The Indie Stone; este mod requer
uma cópia original do jogo.
