# Painel AgroMaq · Dia 2: fórmulas e passo a passo

Infoeste 2026 · Além do Código. Instrutores: Lucas Galindo e Lucas Araujo.

## Antes de começar: dados e modelo

Se as 6 tabelas estão carregadas e ligadas por 5 relacionamentos, o resto do roteiro funciona. Sem isso, os números não batem.

1. **Carregar os dados.** Página Inicial > Obter dados > Pasta de Trabalho do Excel > `agromaq_dw.xlsx` (pasta `Documentos\PowerBI\Dados_AgroMaq_DW`). Marque as 6 abas: `dim_tempo`, `dim_sensor`, `dim_linha`, `dim_produto`, `fato_leitura_sensor`, `fato_producao`. Clique em **Carregar**.
2. **Abrir a Visão de Modelo** (ícone do diagrama, na lateral esquerda) e conferir que existem estes 5 relacionamentos, todos **um para muitos**, com o lado "um" na tabela dimensão:

| De (dimensão, lado 1) | Para (fato, lado muitos) |
| --- | --- |
| `dim_tempo[sk_tempo]` | `fato_leitura_sensor[sk_tempo]` |
| `dim_sensor[sk_sensor]` | `fato_leitura_sensor[sk_sensor]` |
| `dim_tempo[sk_tempo]` | `fato_producao[sk_tempo]` |
| `dim_linha[sk_linha]` | `fato_producao[sk_linha]` |
| `dim_produto[sk_produto]` | `fato_producao[sk_produto]` |

3. **Se faltar algum**, arraste o campo `sk_...` da dimensão até o mesmo campo da fato. Se aparecer um relacionamento que não está na tabela, apague.
4. **Marcar a tabela de datas.** Clique em `dim_tempo`, depois Ferramentas de Tabela > Marcar como tabela de datas, e escolha a coluna `data`. Ela precisa estar com tipo **Data**.
5. **Ordenar os meses.** Clique na coluna `nome_mes` > Classificar por coluna > `mes`. Sem isso, os meses aparecem em ordem alfabética.
6. **Esconder as chaves.** Nas colunas que começam com `sk_` e `id_`, clique com o botão direito e escolha Ocultar na exibição de relatório. O aluno só deve ver campos que fazem sentido.

## As medidas DAX

Seis medidas bastam para as três páginas. Cinco delas só somam ou contam; a que não dá para trocar por um campo arrastado é `% de refugo`.

### Criar a tabela das medidas

1. Página Inicial > **Inserir dados**.
2. Nomeie a tabela como `_Medidas` e clique em **Carregar**. O sublinhado faz ela ficar no topo da lista.
3. Com `_Medidas` selecionada, vá em Modelagem > **Nova medida** e cole uma fórmula por vez (do nome até o fim). Confirme com Enter.
4. Depois de criar cada medida, ajuste o formato na faixa Ferramentas de Medida, como indicado abaixo. Com as medidas criadas, clique com o botão direito na coluna vazia (`Coluna1`) e escolha **Ocultar na exibição de relatório**: a tabela passa a mostrar o ícone de calculadora e só aparecem as medidas.

### Páginas D1 e D3: produção

```
Total produzido =
SUM ( fato_producao[quantidade_produzida] )
```

Soma as peças produzidas no contexto atual (mês, setor, unidade). Formato: número inteiro com separador de milhar.

```
Refugo =
SUM ( fato_producao[quantidade_rejeitada] )
```

Soma as peças rejeitadas. Formato: número inteiro.

```
% de refugo =
DIVIDE ( [Refugo], [Total produzido] )
```

Porcentagem de refugo. O `DIVIDE` é a divisão segura: não dá erro quando o denominador é zero. Formato: porcentagem com 2 casas. **Esta é a medida que não dá para trocar por soma ou média.** A média das taxas de cada linha dá um número errado, porque cada linha produz uma quantidade diferente.

```
Ordens =
COUNTROWS ( fato_producao )
```

Quantas ordens de produção concluídas. Formato: número inteiro.

### Página D2: sensores

```
Leituras =
COUNTROWS ( fato_leitura_sensor )
```

Base de tudo no D2. Formato: número inteiro com separador de milhar.

```
Leituras fora da faixa =
CALCULATE (
    [Leituras],
    fato_leitura_sensor[fora_faixa] = 1
)
```

O `CALCULATE` muda o contexto: conta só as leituras com `fora_faixa = 1`. Quando não há nenhuma, o resultado fica **vazio**, não zero. Formato: número inteiro.

Se a turma ainda não chegou em `CALCULATE`, o D2 também funciona sem medidas: use `Valor` com agregação Média e `fora_faixa` com agregação Soma, porque esse campo vale 0 ou 1. Mas assim você perde a explicação do contexto, que é a parte mais valiosa da aula.

## Página D1: Visão executiva (15 min)

Pergunta da página: **Quanto produzimos e onde perdemos?**

1. **Quatro cartões.** Insira 4 visuais do tipo Cartão e arraste para cada um uma medida: `Total produzido`, `Refugo`, `% de refugo`, `Ordens`.
2. **Barras por setor.** Insira um gráfico de barras agrupadas. Eixo Y: `dim_linha[setor]`. Eixo X: a medida `% de refugo`. Ordene por `% de refugo`, do maior para o menor.
3. **Duas segmentações.** Insira dois visuais Segmentação: um com `dim_tempo[nome_mes]` e outro com `dim_linha[unidade]`.
4. **Teste.** Clique em um mês e em uma unidade e veja os cartões e as barras mudarem juntos. Isso é o relacionamento do modelo funcionando.

**Conferência (sem filtro):**

| Cartão | Valor esperado |
| --- | --- |
| Total produzido | 79.702 |
| Refugo | 1.852 |
| % de refugo | 2,32% |
| Ordens | 960 |

**Conferência (com filtro):**

| Filtro | % de refugo |
| --- | --- |
| Março | 2,64% |
| Unidade Presidente Prudente | 2,26% |
| Unidade Três Lagoas | 2,37% |

**Barras por setor:** Soldagem 4,01%, Pintura 2,96%, Montagem 2,18%. Soldagem é a que mais perde, e isso leva à D3.

## Página D2: Sensores (15 min)

Pergunta da página: **Alguma máquina está saindo do normal?** Crie uma nova página (botão + no rodapé) antes de começar.

1. **Escolher um tipo de sensor.** Insira uma Segmentação com `dim_sensor[tipo_sensor]` e selecione **Temperatura Motor**. Misturar graus com rotação (rpm) numa média não faz sentido, por isso um tipo por vez.
2. **Linha do tempo.** Insira um gráfico de linhas. Eixo X: `dim_tempo[data]` (clique na seta ao lado do campo e escolha **data**, não a hierarquia de datas). Eixo Y: arraste `fato_leitura_sensor[valor]` e mude a agregação para **Média**.
3. **Linha de referência em 95.** Selecione o gráfico, abra o painel Analisar (a lupa) > Linha constante do eixo Y > Adicionar linha, valor `95`. É o limite máximo normal da temperatura do motor.
4. **Filtro de linha e máquina.** O nome da máquina sozinho se repete em várias linhas. Por isso, no painel Dados, clique com o botão direito em `dim_sensor[nome_linha]` > Criar hierarquia, e arraste `nome_maquina` para dentro dela. Depois insira uma Segmentação com essa hierarquia.
5. **Matriz por turno.** Insira uma Matriz. Linhas: `fato_leitura_sensor[turno]`. Valores: a medida `Leituras fora da faixa` (ou `fora_faixa` com agregação Soma).
6. **Destaque em dourado.** Na matriz, abra as opções do campo de valores > Formatação condicional > Cor do plano de fundo > Regras. Regra: se o valor for maior ou igual a `1`, cor `#F4B942`.

**Conferência:**

| Turno | Leituras fora da faixa |
| --- | --- |
| Noite | 32 |
| Tarde | 3 |
| Manha | 2 |
| Total | 37 |

- O turno aparece como `Manha`, sem acento, porque o banco foi carregado assim. A ordem da matriz é alfabética: Manha, Noite, Tarde.
- As 37 leituras são todas de **Temperatura Motor**. Em outro tipo de sensor, a medida fica vazia (não zero), e a matriz não mostra nada.
- A linha do tempo começa em 16/02, porque não há leituras de sensor antes disso.
- Na linha do tempo de Temperatura Motor, 12/03 tem um pico entre 12h e 16h, com máximo de 121,3 °C às 15h. As leituras acima de 95 nesse intervalo são do setor de Usinagem.

## Página D3: Produção e refugo (10 min)

Pergunta da página: **Onde está a causa do refugo?** Crie outra página nova. A produção é registrada por **linha**, não por máquina, por isso a matriz cruza setor com motivo.

1. **Matriz setor × motivo.** Insira uma Matriz. Linhas: `dim_linha[setor]` e, abaixo dele, `fato_producao[motivo_principal]` (o setor passa a expandir para os motivos). Colunas: `dim_tempo[nome_mes]`. Valores: `Refugo`.
2. **Expandir.** Ative "Expandir para baixo" no topo da matriz (ou o sinal de + ao lado do setor) e abra a linha **Soldagem**.
3. **Dispersão por linha.** Insira um gráfico de dispersão. Detalhes: `dim_linha[nome_linha]`. Eixo X: `Total produzido`. Eixo Y: `% de refugo`. Cada ponto é uma linha de produção.
4. **Interagir.** Clique em um ponto da dispersão e veja a matriz filtrar. Clique em um mês e veja os dois visuais mudarem.

**Conferência:**

| Soldagem | Total produzido | Refugo | % de refugo |
| --- | --- | --- | --- |
| Janeiro | 3.176 | 75 | 2,36% |
| Fevereiro | 3.050 | 72 | 2,36% |
| Março | 3.386 | 238 | 7,03% |

- Troque os valores da matriz para `% de refugo` e você vê o salto de Soldagem em março: de 2,36% para 7,03%, quase três vezes mais.
- Em março, o motivo principal de 26 das 34 ordens de Soldagem é **Problema de soldagem - porosidade**. Trinca aparece em 5 e penetração insuficiente em 3.
- Porosidade já era o motivo principal em janeiro e fevereiro. O que mudou em março foi o **tamanho** do problema (a taxa quase triplicou), não o motivo.
- Resposta da pergunta: o refugo está concentrado em Soldagem, por porosidade, e disparou em março.

## Se o número não bater

| Sintoma | Causa mais provável | O que fazer |
| --- | --- | --- |
| Segmentação não filtra o gráfico | Relacionamento ausente ou apontando para o campo errado | Visão de Modelo: refaça a ligação `sk_...` entre dimensão e fato |
| Meses em ordem alfabética | `nome_mes` sem classificação | Classificar por coluna > `mes` |
| `Leituras fora da faixa` dá outro número | `fora_faixa` não está como número inteiro | Transformar dados > tipo Número inteiro, e a medida volta a contar |
| Valores como 715 em vez de 71,5 | Importação com localidade errada (acontece com CSV) | Use o `agromaq_dw.xlsx`, que já traz os números prontos |
| `% de refugo` dá um valor estranho | Relação ausente com `dim_linha` ou `dim_tempo` | Confira os 5 relacionamentos e reabra o cartão sem filtro: deve dar 2,32% |
| `Leituras fora da faixa` aparece vazio | Normal: não há leitura fora da faixa nesse contexto | Nada a corrigir. A medida devolve vazio, não zero |
| Linha do tempo cheia de níveis (ano, trimestre, mês) | Foi usada a hierarquia de datas | No eixo X, troque a hierarquia pelo campo `data` |

Regra de ouro: se o cartão sem filtro não der o número da tabela de conferência, o problema está no modelo ou na medida, não no visual. Resolva isso antes de montar o resto.

Os números desta página foram calculados direto no banco `agromaq_dw`. Os passos de clique seguem o Power BI Desktop em português e ainda não foram testados na tela desta máquina; se algum menu tiver outro nome na sua versão, me diga e eu corrijo.
