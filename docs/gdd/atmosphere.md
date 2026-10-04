# Atmosfera

| Campo | Valor |
|-------|-------|
| Status | `draft` |
| Sprints | 0001 (clima), 0005 (som de névoa, overlays) |

Tudo aqui roda no **cliente**: é o que se vê e se ouve.

## Clima

Override do `ClimateManager` via Lua
([ADR-004](../architecture/adr-004-clima-antes-de-shader.md)).

- Noite: luz global menor, leve dessaturação, tint azulado.
- Névoa: dessaturação forte, tint sépia/cinza, névoa mais densa que a vanilla.
- Transição suave de ~30 segundos reais.
- Intensidade configurável no sandbox.

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
