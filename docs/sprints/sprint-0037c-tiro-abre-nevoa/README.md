# Sprint 0037c: tiro abre a névoa (mod3)

| Campo | Valor |
|-------|-------|
| Status | `em teste` |
| Branch | `fix/tiro-abre-nevoa` (saiu da `staging`) |
| Origem | Johan no jogo, 2026-10-06: "o tiro não interage com a névoa", "nada mesmo" |

## Diagnóstico

O tiro era pego e o sopro era aplicado no fluido (sprint 0026), mas nada aparecia na tela:

- um tiro de pistola gera dois sons no tile do jogador, raio 40 e raio 20; o sopro era som/10, então
  4 e 2,5 tiles;
- perto do jogador o fluido já está quase vazio (log: "sob o jogador=0.02"), porque o personagem cava
  o rastro ao andar; o sopro tirava 85% de quase nada;
- o véu de fundo (`HAZE` no `NOM_VolFog.frag`) é somado sem depender do fluido e cobre ~40% mesmo
  num buraco perfeito.

## O que mudou

- **Clareira** (`mod3/java/nom/render/Blasts.java`, `nomClearing` no `NOM_RenderContext.glsl`): cada
  tiro ou explosão abre a névoa inteira (véu, rolos, fluido) num círculo em volta da origem do som.
  Abre em 0,15 s, fecha em 4 s com curva suave, miolo limpo até meio raio e borda macia até o raio.
  Até 8 ao mesmo tempo (a mais velha sai). O tempo é o da simulação: para na pausa.
- **Raio maior:** som × 0,25, entre 5 e 12 tiles. Pistola (40) abre 10 tiles. Os dois sons do mesmo
  tiro viram uma clareira só. O sopro no fluido usa o mesmo raio. Constantes em `Blasts`, fáceis de
  mudar.
- **Log:** `[NOM-Render] tiro na névoa: som em (x, y) raio R -> sopro e clareira de N tiles`, no
  máximo 10 por minuto.
- Evidência e decisões: [pz-api-notes §29](../../architecture/pz-api-notes.md).

## Testes

`tests/java/FlowBlastTest.java` (no `tests/test_mod3_flow.sh`): raio pelo som, curva da clareira,
junção dos dois sons do mesmo tiro, teto de clareiras e expiração, coordenadas relativas, teto do log
e o sopro de raio 10 na grade (centro 0,16, meio raio 0,37, anel 1,50, massa conservada).

## Roteiro de teste no jogo

1. Com o mod de staging e a Volumétrica ativos, abra a névoa: `NOM.setFog(true)` (ou o botão no
   `NOM.panel()`).
2. Pegue uma pistola e munição pelo menu de debug do jogo (Items List: `Base.Pistol`, `Base.Bullets9mm`,
   carregue o pente) ou no console Lua:
   `local inv = getPlayer():getInventory(); inv:AddItem("Base.Pistol"); inv:AddItems("Base.Bullets9mm", 30)`.
3. Em campo aberto, atire. Esperado: um círculo de ~10 tiles em volta de você abre a névoa na hora e
   ela volta devagar em ~4 s; nas bordas, a névoa do fluido fica mais grossa (o anel do sopro).
4. No `console.txt`: `[NOM-Render] tiro na névoa: som em (...) raio 40 -> sopro e clareira de 10.0 tiles`.
5. Pausar no meio: a clareira congela e continua fechando ao despausar.
