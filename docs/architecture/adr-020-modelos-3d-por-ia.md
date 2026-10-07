# ADR-020 — Modelo 3D gerado por IA: só com licença mundial e o Johan aceitando

| Campo | Valor |
|-------|-------|
| Status | `proposed` (espera o Johan) |
| Data | 2026-10-07 |
| Sprint | [0043](../sprints/sprint-0043-ticao-ia/README.md) |
| Decisão | proposta pelo agente na ausência do Johan; nada de IA entrou no mod |

## Contexto

O `AGENTS.md` pede tudo gerado por script nosso. A [spec do modelo novo §9](../superpowers/specs/2026-10-06-modelo-novo-design.md#9-facelift-dos-monstros)
abre uma exceção a testar: uma peça 3D do Tição gerada por um modelo aberto que rode na RTX 4070
de 12 GB (Hunyuan3D-2 mini ou Stable Fast 3D), comparada com a versão por script. A regra da spec:
"só entra com uma ADR nova e a licença do modelo conferida".

O mod é distribuído de graça no Steam Workshop, que alcança o mundo todo, e o código é MIT.

## Licenças conferidas (2026-10-07, texto lido no Hugging Face)

| Modelo | Licença | Pode distribuir o que ele gera no Workshop? | Baixar |
|---|---|---|---|
| Hunyuan3D-2 mini (`tencent/Hunyuan3D-2mini`) | Tencent Hunyuan 3D 2.0 Community License | **Não.** A licença "não vale na União Europeia, no Reino Unido e na Coreia do Sul" (território, §1.l), e §5.c proíbe "usar, reproduzir, modificar, distribuir ou exibir [...] o Output [...] fora do Território". O Workshop entrega pra jogador na UE | livre (não é gated) |
| Stable Fast 3D (`stabilityai/stable-fast-3d`) | Stability AI Community License (5 jul. 2024) | **Sim, com cuidado.** Licença mundial; uso não comercial (hobby) é livre; "você é dono dos outputs" (§IV.c.iii); output não é "Derivative Work" (§V). A obrigação de atribuição (§IV.a: arquivo "Notice" e "Powered by Stability AI") vale pra quem distribui os Materiais ou uma obra derivada; por cautela, faríamos as duas se um output entrar | **gated**: precisa de conta no Hugging Face e aceitar os termos (com nome e contato) |

## Decisão (proposta)

1. **Nenhum modelo gerado por IA entra no mod sem esta ADR aceita pelo Johan.** Hoje não entrou nenhum:
   a peça do Tição da 0043 é a versão por script (`TicaoCrosta` em `scripts/gen_models.py`).
2. **Hunyuan3D-2 fica fora** de qualquer coisa que vá pro Workshop ou pro repositório público (nem
   prévia de output no repo: "exibir fora do Território" também é vedado). Teste local dele, só se o
   Johan quiser, e o resultado fica fora do repo.
3. **Se for usar IA, é o Stable Fast 3D** (ou outro com licença mundial que deixe distribuir o output),
   e o Johan aceita os termos no Hugging Face com a conta dele.
4. Um output de IA, se entrar, passa pelo mesmo caminho das peças por script:
   - imagem de entrada nossa (prévia do `preview_models.py` ou desenho do Johan), nunca de terceiros;
   - convertido pra `.x` pelo nosso gerador, encaixado no quadro do osso da cabeça e reduzido pra
     ≤ 2500 vértices;
   - os mesmos testes de `tests/test_models.py` (fechado, virado pra fora, winding, encaixe);
   - textura nossa (a IA dá só a forma);
   - no `CREDITS.md`, marcado "gerado por IA" com modelo, versão e imagem de entrada, mais o
     "Notice" e o "Powered by Stability AI".

## Por que o teste não rodou na 0043

- Stable Fast 3D é gated: baixar exige aceitar termos com a identidade do Johan.
- Hunyuan3D-2 mini baixa livre, mas o output não pode ir pro Workshop; e o review automático
  bloqueou instalar o pipeline (torch, pesos, dependências) com o Johan fora.

## Como rodar quando o Johan aprovar

1. Aceitar os termos em `huggingface.co/stabilityai/stable-fast-3d` e gerar um token de leitura.
2. Ambiente fora do repo (ex.: `~/.cache/nom-ia/venv`), com torch CUDA e o repositório público do
   Stable Fast 3D; a imagem de entrada é a vista "iso" de `docs/sprints/sprint-0043-ticao-ia/preview-script.png`
   (ou um desenho do Johan).
3. O `.glb` gerado fica fora do repo. Comparar com a versão por script nos critérios abaixo; só se
   ganhar, convertê-lo pelo item 4 da decisão.

**Critérios da comparação:** lê a 20 px de tela (o tamanho da cabeça no zoom normal)? Encaixa na
cabeça sem atravessar? Quantos vértices sobram depois de reduzir? Quanto custa mudar um detalhe
(na versão por script é uma constante)?

## Consequências

- A regra "tudo por script" continua inteira até o Johan aceitar.
- Aceitando, o mod passa a carregar a atribuição da Stability AI e uma dependência de pipeline fora
  do repo (pesos não versionados), que ninguém mais consegue reproduzir byte a byte.
