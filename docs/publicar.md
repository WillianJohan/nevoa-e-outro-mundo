# Publicar no Steam Workshop

| Campo | Valor |
|-------|-------|
| Status | `accepted` |
| Escrito em | sprint 0007 (2026-10-04) |
| Duração | ~10 min de publicação + ~20 min de teste da cópia do Workshop |

Passo a passo pra publicar (e atualizar) o mod. Tudo que dava pra preparar sem o
Steam já está no repositório: textos em `docs/workshop/`, imagens geradas por
`scripts/gen_images.py`, e `scripts/build-workshop.sh`, que monta a pasta que o jogo
envia.

> **Steam Flatpak (o caso deste PC):** o jogo roda em sandbox e a pasta de dados é
> `~/.var/app/com.valvesoftware.Steam/Zomboid`, não `~/Zomboid` — vale pra `mods/`,
> `Workshop/` e `console.txt` em todo este documento. Mod de dev: **`scripts/dev-sync.sh`** copia `mod/`
> pra pasta de mods do jogo (rodar de novo a cada mudança e recarregar o save). **Não use
> symlink**: com link o jogo não lê `media/scripts/*.txt` (itens de visual somem).
> O `build-workshop.sh` detecta essa pasta sozinho (ou use `ZOMBOID_DIR=...`).

## Antes de publicar

- [ ] O [teste in-game consolidado](teste-in-game.md) passou (solo e MP), com o mod
      pelo symlink.
- [ ] A sprint em teste foi mergeada na `main` e a `main` está limpa:

Comandos na raiz do repositório (`cd ~/Documents/projects/nevoa-e-outro-mundo`).

```bash
git checkout main && git pull
git status            # nada pendente: o commit publicado é o que vai ganhar a tag
./run-tests.sh        # total=… falhou=0 e build … falhou=0
```

## 1. Montar a pasta de upload (1 min)

```bash
scripts/build-workshop.sh --dry-run   # mostra o que vai fazer, não escreve nada
scripts/build-workshop.sh
```

Esperado (o número de arquivos muda com o mod):

```
destino: /home/<você>/Zomboid/Workshop/NevoaEOutroMundo
Contents/mods/NevoaEOutroMundo/ <- mod/ do commit <hash> (45 arquivos, cópia limpa)
Contents/mods/NevoaEOutroMundo_Shader/ <- mod2/ do mesmo commit (6 arquivos; mod opcional do shader, ADR-013)
preview.png <- docs/workshop/preview.png (82862 bytes)
workshop.txt <- docs/workshop/description-en.txt + description-ptbr.txt (5980 bytes); sem id (primeiro upload), visibility=unlisted
pronto. Abra o jogo: menu principal > Workshop > Névoa e Outro Mundo.
```

O script recusa (e não escreve nada) se a preview não for PNG de 256 ou 512 px
quadrado com até 1 024 000 bytes, se as duas descrições juntas passarem de 7900
bytes (regras do jogo e do Steam), se houver mudança não commitada em `mod/` ou em
`docs/workshop/` (texto, preview, ID), ou se o commit não tiver `mod/42/mod.info` e
`mod/common/.gitkeep`:
**vai pro upload só o que está no último commit** (`git archive HEAD mod`), que é o
commit que leva a tag. Arquivo fora do git em `mod/` fica de fora, com `AVISO:`.
Rodar de novo é seguro: o mod é recopiado do zero e o `id=`/`visibility=` que o jogo
gravou são mantidos. Depois do primeiro envio o ID também fica no repo
(`docs/workshop/workshop-id.txt`, passo 2.7): se o `workshop.txt` local perder o
`id=`, o build usa o do repo, e se os dois forem diferentes avisa (`AVISO: …`) antes de
você criar um item duplicado.

## 2. Enviar pelo jogo (5 min)

Abrir o Project Zomboid **sem** `-debug`, logado na Steam.

1. Menu principal → **Workshop** (Oficina) → **Criar e atualizar itens**.
2. Página 1, "Escolher diretório do item": escolher `NevoaEOutroMundo` → Próximo.
   O jogo valida a pasta aqui; erro nessa hora = mensagem `UI_WorkshopError_*`
   (pasta `Contents/` errada, `mod.info` sem `id=`, tipo de arquivo proibido).
3. Página 2, "Editar detalhes do item": título, descrição, marcadores
   (`Build 42`, `Hardmode`, `Multiplayer`) e a preview já vêm preenchidos do
   `workshop.txt`. **Não editar aqui**: o que mudar nessa tela o jogo grava no
   `workshop.txt`, e o próximo build sobrescreve com o que está no repo. Mudança de
   texto se faz em `docs/workshop/` e no build.
   **Visibilidade:** no primeiro envio, deixar **Não listado** (só quem tem o link
   vê), pra testar a cópia do Workshop antes de abrir pra todo mundo.
4. Página 3: primeiro envio → **"Este é um novo item da Oficina"**. Atualização →
   não aparece (o `workshop.txt` já tem o `id=`).
5. Página 5, "Preparar item para publicação": **Editar Notas de Alteração** (ex.:
   `v1.0.0 — primeira versão pública`), aceitar os termos da Oficina e
   **Enviar para a Oficina Steam agora!**
6. Ao criar o item, o jogo grava o `id=` no `~/Zomboid/Workshop/NevoaEOutroMundo/workshop.txt`.
   **Copiar esse número** (o ID da Oficina) pra usar abaixo.
7. **Registrar o ID no repo, na hora** (é a única cópia fora desta máquina):

```bash
grep '^id=' ~/Zomboid/Workshop/NevoaEOutroMundo/workshop.txt | cut -d= -f2 > docs/workshop/workshop-id.txt
```

   No `README.md`, trocar o "em breve" do Workshop pelo link
   `https://steamcommunity.com/sharedfiles/filedetails/?id=<ID>`. Commit
   (`docs: ID do item no Workshop`) na `main` e push. Não mexe em `mod/`: o commit
   enviado continua sendo o que leva a tag no passo 5.

Se o Steam pedir pra aceitar o acordo legal da Oficina, o item fica oculto até
aceitar na página do item no navegador.

## 3. Conferir a página (2 min)

Abrir `https://steamcommunity.com/sharedfiles/filedetails/?id=<ID>`:

- [ ] A descrição aparece inteira: a última linha é "Todos os sons e imagens são
      originais…" (fim da parte em português). Se cortou, a caixa de texto do jogo
      tem limite (não confirmado no bytecode): enxugar `docs/workshop/` e reenviar.
- [ ] BBCode renderizado (títulos, listas, link do GitHub).
- [ ] Preview e marcadores certos. O jogo anexa "Workshop ID" e "Mod ID" no fim da
      descrição; é normal.

## 4. Testar a cópia do Workshop numa instalação limpa (~20 min)

Fecha o critério "mod baixado do Workshop numa instalação limpa funciona em solo e
num servidor dedicado".

### O build ganha do symlink

O jogo procura mods nesta ordem: `~/Zomboid/Workshop/` (pastas de upload), depois os
itens inscritos da Steam, depois `~/Zomboid/mods/`, e usa o **primeiro** com o `id`
igual (bytecode `ZomboidFileSystem.getAllModFolders`, ordem `workshop,steam,mods`;
`ChooseGameInfo.getModDetails` para no primeiro). Enquanto a pasta do build existir,
**o jogo carrega ela, não o symlink nem a inscrição**. Por isso, pra testar a cópia
baixada:

```bash
mkdir -p ~/Zomboid/Workshop-parked
mv ~/Zomboid/Workshop/NevoaEOutroMundo ~/Zomboid/Workshop-parked/   # tira o build da frente (guarda o id=)
rm ~/Zomboid/mods/NevoaEOutroMundo                                  # tira o symlink
```

`~/Zomboid/Workshop-parked/` fica fora da busca de mods do jogo e sobrevive a reboot
(não use `/tmp`): é ali que está o `workshop.txt` com o `id=`. O passo "Devolver a
pasta", no fim desta seção, desfaz isso.

### Solo

1. Na página do item, **Inscrever-se**. Esperar a Steam baixar.
2. Abrir o jogo (pode ser com `-debug`). Mods: "Névoa e Outro Mundo" aparece com o
   ícone e o poster.
3. Save novo com o mod: página do sandbox com as 24 opções; anoitecer
   (Debug → Time) e ver `[NOM] night=true` no `console.txt`.
4. Nenhum `ERROR` com `NOM_` no `console.txt`.

### Servidor dedicado

1. No `.ini` do servidor (`~/Zomboid/Server/servertest.ini` no teste local):
   `WorkshopItems=<ID>` e `Mods=NevoaEOutroMundo` (o `id=` do `mod.info`; com outros
   mods, separar por `;`). Ou pelo menu Host → configurações do servidor → Mods.
   **A confirmar nesta sessão:** no B42 a linha `Mods=` aparece com o ID puro e também
   com barra invertida (`Mods=\NevoaEOutroMundo`). Começar pelo ID puro; se o console
   do servidor não carregar o mod, tentar com `\`, e anotar qual valeu no README da
   sprint 0007 (e no `README.md`, seção Instalar).
2. Subir o servidor: o console mostra o download do item e o mod carregando, sem
   `ERROR` com `NOM_`.
3. Entrar com um cliente: o cliente baixa o item sozinho, entra, e de noite o console
   do servidor mostra `[NOM] noite` (com `-debug`).

Se tudo passou: marcar o critério no README da sprint 0007 com o ID e o console.

### Devolver a pasta (obrigatório)

```bash
mv ~/Zomboid/Workshop-parked/NevoaEOutroMundo ~/Zomboid/Workshop/
~/Documents/projects/nevoa-e-outro-mundo/scripts/dev-sync.sh
```

Sem a pasta de volta, o próximo build cai no ID do repo (e avisa); com ela, nada muda.
Pra voltar a desenvolver pelo symlink: cancelar a inscrição e, antes de abrir o jogo,
`mv ~/Zomboid/Workshop/NevoaEOutroMundo ~/Zomboid/Workshop-parked/` de novo (a pasta de
upload e a inscrição ganham do symlink). Na hora de atualizar, devolver de novo.

## 5. Abrir pra todo mundo e taggear (2 min)

1. **Pelo jogo** (o caminho principal): `scripts/build-workshop.sh`, jogo → Workshop →
   Criar e atualizar itens → `NevoaEOutroMundo` → página 2: **Visibilidade = Público**
   → página 5, nota "visibilidade pública" → enviar. A página 2 grava `visibility=public`
   no `workshop.txt` (`WorkshopSubmitScreen.lua:350-351`) e o build mantém daí em diante.

   **Por que não pela página do Steam:** todo envio manda a visibilidade do
   `workshop.txt` (`SteamWorkshop.SubmitWorkshopItem` chama `n_SetItemVisibility` com
   `getVisibilityInteger()`) e a página 2 já vem marcada com ela. Mudar só no Steam deixa
   `visibility=unlisted` no arquivo local, e a próxima atualização **esconde o item de
   novo** sem avisar. Se mudar no Steam mesmo assim, trocar também à mão:
   `sed -i 's/^visibility=.*/visibility=public/' ~/Zomboid/Workshop/NevoaEOutroMundo/workshop.txt`.
2. Taggear **o commit que foi enviado** (o `HEAD` da `main` no passo "Antes de
   publicar"):

```bash
git tag -a v1.0.0 -m "v1.0.0 — primeira versão no Steam Workshop (ID <ID>)"
git push origin v1.0.0
gh release create v1.0.0 --title "v1.0.0" \
  --notes "Primeira versão pública. Steam Workshop: https://steamcommunity.com/sharedfiles/filedetails/?id=<ID>"
```

3. Marcar o critério da release no README da sprint 0007 e fechar a sprint.

## Atualizar depois

1. Subir o `modversion=` em `mod/42/mod.info` e mergear na `main` (commitado: o build
   recusa `mod/` sujo).
2. A pasta `~/Zomboid/Workshop/NevoaEOutroMundo` no lugar (não em `Workshop-parked`) e
   `scripts/build-workshop.sh` (mantém o `id=` e a visibilidade; `AVISO:` de ID = parar e
   conferir).
3. Jogo → Workshop → Criar e atualizar itens → `NevoaEOutroMundo` → página 2:
   **confirmar Visibilidade = Público** → página 5 (notas de alteração) → enviar. A
   página 3 não aparece: o `id=` já está lá.
4. `git tag -a vX.Y.Z` + `gh release create` no commit enviado.

Se a pasta `~/Zomboid/Workshop/NevoaEOutroMundo` sumiu (outro PC, HD novo), o build
recria o `workshop.txt` com o ID de `docs/workshop/workshop-id.txt` (com `AVISO:`), mas
com `visibility=unlisted`: na página 2, **Público**. Se nem o arquivo do repo existir,
na página 3 escolher **"Este é um item existente…"** e digitar o ID da Oficina. Nunca
criar um item novo pra uma atualização.
