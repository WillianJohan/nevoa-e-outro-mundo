# Sprint 0027 — Névoa orgânica, sem vai e vem (mod3)

Status: `em teste`.

## Por quê

No vídeo da 0026 o Johan viu a névoa "pegar altura e depois diminuir" sem parar, e detestou: parece
mecânica. A névoa já se comportava melhor como fluido; o problema era o ruído dos rolos.

## Causa

- **Flow map de duas fases** (`flowNoise` e `ruido2Fases` no `NOM_VolFog`): o ruído era empurrado pela
  velocidade durante 2 s e recomeçava, com duas cópias defasadas se revezando. No meio da troca as duas
  se misturam, o contraste cai e os rolos achatam; nas pontas voltam altos. A tela inteira fazia isso
  junto, a cada segundo. O vento mais forte da 0026 piorou, porque o ruído esticava mais antes de recomeçar.
- **Rajada por seno** (`Flow.wind`): um termo de 2,1 s, com ritmo fixo.
- De quebra: o ruído ficava em coordenadas relativas à origem do quadro e pulava quando ela mudava.

## O que mudou

- **O ruído anda junto com os bancos:** o Java publica a cada quadro quanto o vento já levou a névoa
  (o deslocamento dos `FogBanks` mais a fração de passo que falta simular, pra não andar aos trancos a
  20 Hz) em `uDrift`. O shader amostra o ruído no mundo menos esse deslocamento. Nada recomeça.
- **Forma viva sem pulsar:** a forma muda devagar pelo eixo do tempo do ruído, inclinado no espaço, pra
  cada lugar mudar num momento diferente. Um ruído largo torce o desenho (curvas), e onde o fluido desvia
  do vento (atrás de prédio, rastro) o desenho dobra.
- **Vento por ruído** (`Wind`, puro e testado): rajada e direção vagando sem ritmo que se repita.

## Roteiro in-game

1. Reiniciar o jogo depois do `dev-sync`; `NOM_Debug.fog(true, true)`.
2. Parado olhando a névoa por 30 s: os rolos têm que **passar** (levados pelo vento) e mudar de forma
   devagar, sem subir e descer juntos no lugar.
3. Andar e virar a câmera: o desenho não pode pular.
4. Atrás de prédio e no rastro: o desenho dobra e o vácuo continua.

## Ajustes fáceis

| Onde | Constante | Efeito |
|---|---|---|
| `NOM_VolFog` | `MORPH = 0.06` | rapidez com que a forma muda |
| `NOM_VolFog` | `curl * 3.0`, `q * 0.07` | quanto e com que tamanho as curvas torcem |
| `NOM_VolFog` | `WARP_S = 0.8` | quanto o desenho dobra onde o fluido desvia do vento |
| `Wind` | `0.7f`, `0.2f` (rajada), `1.2f`, `0.5f` (direção) | força das rajadas e quanto a direção vaga |

## Aprendizados

- **Flow map de duas fases pulsa** sempre que o período é visível. Pra névoa que viaja com um vento
  conhecido, basta andar o ruído pelo vento acumulado; o desvio local vira dobra fixa, não rampa no tempo.
- **Ruído de valor animado num eixo pulsa também** (perde contraste entre os nós). Inclinar o tempo no
  espaço espalha isso em faixas que andam, e o olho não lê como respiração.
