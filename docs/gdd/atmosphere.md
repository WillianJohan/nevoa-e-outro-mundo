# Atmosfera

| Campo | Valor |
|-------|-------|
| Status | `accepted` |
| Sprints | 0001 (clima), 0005 (som de névoa, overlays) |

Som e overlays rodam no **cliente**: é o que se ouve e o que cada jogador vê
sozinho. O clima é a exceção: roda no **servidor** e chega aos clientes pela
sincronização de clima do próprio jogo.

## Clima

Camada modded do `ClimateManager` via Lua
([ADR-004](../architecture/adr-004-clima-antes-de-shader.md)), escrita no
servidor a cada minuto de jogo (`OnClimateTick`). No solo o servidor roda no
mesmo processo; em MP o cliente não escreve no clima, só recebe.

- Noite: luz global menor, leve dessaturação, tint azulado.
- Névoa: dessaturação forte, tint sépia/cinza, névoa mais densa que a vanilla.
- Transição de ~20 minutos de jogo (um passo por minuto). No MP chega aos
  clientes a cada 10 minutos de jogo com fade de ~5 s, mesma cadência do
  anoitecer vanilla.
- Intensidade configurável no sandbox.
- A névoa do mod também encurta a visão dos zumbis (o jogo calcula a distância
  de visão pelo valor final da névoa). É intencional: ninguém enxerga na névoa,
  nem eles.
- Névoa forçada pelo admin (painel de clima) passa por cima da nossa camada e
  não liga o estado de névoa: o gatilho é só a névoa natural.

## Som

- Névoa: o ambiente troca para drone grave + ruídos metálicos distantes.
- Rádio chiando por proximidade do Sem-rosto.
- Estalo do Estalador, grito do Corredor.

## Overlays (só na névoa)

- Manchas de sangue e ferrugem surgem aos poucos em tiles perto do jogador e
  somem quando a névoa baixa.
- **Locais e só visuais**, sem sincronizar. Cada jogador vê o próprio pesadelo.

## Shader (spike)

| Status | `draft` — depende do spike |
|---|---|

- Pergunta: o B42 carrega GLSL vindo da pasta do mod?
- Probe: vinheta + grão de filme ativados só na névoa.
- Se sim, vira camada extra. Se não, fica só o clima.

O jogo trata a névoa do mod como névoa de verdade em todo lugar que lê `getFogIntensity()`: visão dos zumbis, do jogador, combate e o parâmetro de áudio de névoa. É intencional.
