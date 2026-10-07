# Sprint 0038: névoa preta I

| Campo | Valor |
|-------|-------|
| Status | `em teste` |
| Branch | `sprint/0038-nevoa-preta` (saiu da `staging`) |
| Origem | ideia do Johan de 2026-10-05; [spec do modelo novo §1, §2, §8](../../superpowers/specs/2026-10-06-modelo-novo-design.md) |
| Plano | [plan.md](plan.md) |

## O que entrou

- **Agenda:** a sirene sorteia o tipo **preta**: 5% das névoas (`BlackFogChance`), só a partir do dia 14
  (`BlackFogGraceDays`), 2 a 3 h de jogo. A preta ganha da vermelha. Sandbox com tradução PTBR e EN.
- **Escuridão:** o clima vira noite fechada mesmo de dia (luz do dia 0, noite 1, ambiente 0, luz quase
  preta), pelos dois canais do slider "Darkness" do admin, na camada modded. Não depende do `DarkEnabled`.
  A cor da névoa fica escura. Na tela, a vinheta fecha mais (sem vermelho), a estática é cinza-escura e as
  lascas e a cinza do Outro Mundo ficam cor de carvão.
- **Tição:** todo zumbi com ID vira Tição. Metade arrastado, metade arrastado rápido (sorteio por zumbi e
  período), visão ruim e audição apurada, visão curta de 3 tiles. A cada 20 min de jogo um chamado de 40
  tiles em volta de cada jogador (a caça da noite é 90 min e 25 tiles). Visual: pele de carvão com
  rachaduras de brasa (`Body/NOM_Ticao.png`, gerada pelo `scripts/gen_textures.py`) e o véu de fumaça do
  Eco; a casca de brasa da 0022 faz a transição. Sem Estalador, Corredor, Sem-rosto, Carpideira nem Eco: os
  Ecos somem quando a preta abre e não nascem nela.
- **A luz congela:** no facho da lanterna (cone pelo `TorchDot` do item), no raio do lampião (4 tiles) ou
  no farol do carro (8 tiles em volta), o Tição para e não ataca. Meio segundo fora da luz, volta. O
  servidor decide (`server/NOM_TicaoLight.lua`, todos os zumbis a cada 250 ms); o dono congela
  (`shared/NOM_TicaoFreeze.lua`, o mesmo `setUseless` + halt da sirene).
- **A lanterna pisca:** a cada 10 s, cada lanterna acesa na preta tem 25% de apagar por 0,7 a 1,6 s. Os
  Tições que ela segurava soltam na hora. Ela volta acesa sozinha, salvo se o jogador mexeu nela.
- **Debug:** `NOM.setBlackFog(skip)` (botão "Preta") e `NOM.ticao()` (botão "Tições no console").
- Evidência: [pz-api-notes §30](../../architecture/pz-api-notes.md).

## Decisões tomadas na ausência do Johan (fáceis de mudar)

- **Velocidade do Tição:** nunca corredor; metade arrastado, metade arrastado rápido. `NOM_TicaoRules`.
- **Caça:** 20 min e 40 tiles (`NOM_TicaoRules.HUNT_MINUTES`, `HUNT_REACH`).
- **Piscar mais longo que o plano** (0,7 a 1,6 s em vez de 0,2 a 0,4 s): com 0,2 s o Tição solto já
  congelava de novo antes de dar um passo. `NOM_LightRules.FLICKER_*`.
- **O piscar só aparece pro dono da lanterna:** sem pacote, os outros jogadores veem a lanterna acesa. O
  efeito no jogo (soltar o Tição) vale pra todos, porque quem decide é o servidor.
- **Farol de carro vira raio** em volta do carro (o Lua não tem a direção do carro sem `Vector3f`).
- **Luz fixa** (cômodo aceso, poste) **ainda não congela**: entra na 0039 com a luz que empurra a névoa.

## Testes

`test_fog_event_rules`, `test_fog_event`, `test_world`, `test_climate_look` (noite fechada e volta),
`test_rules` (`blacken`), `test_screen_fx_rules`, `test_flake_rules`, `test_variant_rules`,
`test_ticao_rules`, `test_night_rules`, `test_night_stats` (todo zumbi Tição e volta), `test_variant_ai`
(visão de 3 tiles), `test_night` (caça), `test_eco`, `test_variant_look`, `test_look_assets`,
`test_light_rules`, `test_ticao_light` (facho, lampião, fim da preta, dedicado manda IDs, cliente aplica,
silêncio solta, não pega zumbi de outra regra, unstick, piscar, custo: ~51 chamadas por tick com 300
zumbis e 4 lanternas), `test_debug`, `test_debug_panel`.

## Roteiro de teste no jogo

1. Com o mod de staging ativo, de dia: `NOM.setBlackFog(true)` (ou o botão "Preta" no `NOM.panel()`).
   Esperado: em ~20 min de jogo o céu escurece até noite fechada; a névoa fica escura; vinheta preta
   grossa; lascas cor de carvão.
2. Olhe os zumbis: pele de carvão com brasa e véu de fumaça. `NOM.ticao()` no console mostra
   `preta=true ticoes=N`.
3. Sem luz, agachado a 4 tiles: o Tição não te vê. Faça barulho: ele vem.
4. Pegue uma lanterna (`Base.HandTorch` com pilha), acenda e aponte pra um Tição: ele para na hora.
   Vire a lanterna: meio segundo depois ele volta a andar. `NOM.ticao()` mostra `congelados=1`.
5. Espere com a lanterna acesa: de vez em quando ela pisca (apaga por ~1 s) e o Tição iluminado anda.
6. Lampião aceso: congela quem chega a ~4 tiles. Carro com farol: ~8 tiles em volta.
7. Fim da preta (`NOM.setEndFog()`): o céu volta, os zumbis voltam ao normal, ninguém fica parado.
8. No MP: o facho de outro jogador também congela; girar com a lanterna solta um e congela outro (o
   UNKNOWN do §30).
