# Roteiro Power BI · Dia 2

Oct 24, 2026 · @Galindo

Este roteiro leva do DW carregado ao dashboard de três páginas, com as medidas DAX e os números que cada tela tem que mostrar. O script das medidas está em `Medidas_DAX_AgroMaq.dax`, e o desenho do modelo está no canvas "Modelo do DW no Power BI". Power BI e DAX não foram executados por nós ainda: os valores esperados vêm do SQL do DW.

## Antes da aula

O ensaio completo leva cerca de 1 hora e precisa acontecer na máquina da sala.

- [ ] Rodar `run_pipeline.sh` no MySQL 8 da sala e depois `09_valores_esperados_dax.sql`. Conferir: 209.804 leituras, 37 fora da faixa, 960 ordens, 79.702 produzidas.
- [ ] Instalar o Power BI Desktop e o MySQL Connector/NET, e reiniciar o Power BI depois do conector.
- [ ] Gerar a reserva com `08_reserva.sh` (dump do DW e CSVs das tabelas). É o plano B se o conector falhar.
- [ ] Montar um .pbix de referência seguindo este roteiro e tirar um print de cada página para os checkpoints.
- [ ] Ensaiar o X2 com a medida com defeito, para saber onde a IA costuma acertar e errar.
- [ ] Não mostrar as três histórias (Robô de Solda à noite, pico de 12/03, soldagem em março) antes da prática. Elas só funcionam se a dupla descobrir.

## Conectar e montar o modelo (B1)

O modelo pronto tem 6 tabelas e 5 relacionamentos, todos 1:\* da dimensão para a fato.

1. **Obter dados > Banco de dados MySQL**. Servidor `localhost`, banco `agromaq_dw`, modo **Importar**.
2. Marque só as 6 tabelas do modelo: `dim_tempo`, `dim_sensor`, `dim_linha`, `dim_produto`, `fato_leitura_sensor`, `fato_producao`. Deixe de fora `dim_maquina`, `cfg_faixa_sensor`, `stg_leitura`, `etl_rejeito` e `leitura_tratada`.
3. Na visão de **Modelo**, confira os relacionamentos da tabela abaixo. O Power BI costuma criá-los sozinho pelos nomes `sk_*`. Apague qualquer outro que ele tenha inventado.
4. **Marcar como tabela de datas**: `dim_tempo`, coluna `data`. Sem isso, o `DATEADD` não funciona direito.
5. Em `dim_tempo`, selecione `nome_mes` e use **Classificar por coluna > mes**. Sem isso, os meses saem em ordem alfabética.
6. Oculte na visão de relatório todas as colunas `sk_*` e `id_*_origem`. O aluno só vê nomes legíveis.
7. Crie a tabela de medidas: **Página Inicial > Inserir dados**, nome `_Medidas`, OK. Depois da primeira medida, oculte a `Coluna1` e a tabela vira tabela de medidas.
8. Crie duas pastas de exibição em `_Medidas`: **Sensores** e **Produção**.

| De (lado 1) | Para (lado \*) | Coluna | Direção do filtro |
| --- | --- | --- | --- |
| `dim_tempo` | `fato_leitura_sensor` | `sk_tempo` | Única |
| `dim_tempo` | `fato_producao` | `sk_tempo` | Única |
| `dim_sensor` | `fato_leitura_sensor` | `sk_sensor` | Única |
| `dim_linha` | `fato_producao` | `sk_linha` | Única |
| `dim_produto` | `fato_producao` | `sk_produto` | Única |

**Pronto quando:** a visão de Modelo fica igual ao canvas do modelo, com `dim_tempo` no meio, uma fato de cada lado e nenhuma linha solta.

**Nomes sem acento.** O DW grava `Marco` e `Expedicao` sem acento, porque o banco de origem veio assim. Para a aula dá para conviver; corrigir de verdade é no DW, não no Power Query.

## Medidas DAX (X1 e X2)

As cinco medidas do X1 cobrem as seis funções do slide (SUM, COUNTROWS, DIVIDE, CALCULATE, FILTER implícito no CALCULATE, DATEADD). O script completo, com comentários, está em `Medidas_DAX_AgroMaq.dax`.

**X1 · 12 min · as cinco medidas.** Crie nesta ordem, porque cada uma usa a anterior.

| Medida | Fórmula | Formato | Esperado (total) |
| --- | --- | --- | --- |
| Total produzido | `SUM ( fato_producao[quantidade_produzida] )` | Inteiro, milhar | 79.702 |
| % de refugo | `DIVIDE ( [Refugo], [Total produzido] )` | % com 2 casas | 2,32% |
| Leituras fora da faixa | `CALCULATE ( [Leituras], fato_leitura_sensor[fora_faixa] = 1 )` | Inteiro | 37 |
| % fora da faixa | `DIVIDE ( [Leituras fora da faixa], [Leituras] )` | % com 3 casas | 0,018% |
| Variação vs mês anterior | ver o script (VAR, DATEADD, HASONEVALUE) | Inteiro com sinal | março +5 |

As de apoio, que as cinco usam: `Leituras = COUNTROWS ( fato_leitura_sensor )` (209.804) e `Refugo = SUM ( fato_producao[quantidade_rejeitada] )` (1.852). O script ainda traz `Ordens`, `Ordens com refugo`, `Valor médio` e `Limite máximo da faixa` para as páginas.

**Três falas que valem a pena na demo:**

- `Leituras fora da faixa` fica **vazio**, não zero, quando não há leitura fora. Por isso a matriz por tipo de sensor só mostra Temperatura Motor.
- A `Variação vs mês anterior` só existe com **um mês** no contexto. No cartão sem filtro, ela fica vazia de propósito.
- Fevereiro não tem variação: as leituras começam em 16/02, então janeiro não tem com o que comparar.

**X2 · 6 min · depurar com IA.**

1. O instrutor cola no modelo a medida `% fora da faixa (com defeito)`, que está no fim do script.
2. Mostre o cartão sem filtro: 0,018%, **igual à certa**. Pergunte se está certa.
3. Coloque as duas medidas numa matriz por turno. Noite: 0,046% (certa) contra 0,015% (com defeito).
4. Cada dupla cola a medida com defeito numa IA do navegador e pede a explicação e a correção.
5. A dupla confere a correção contra o SQL: 32 fora em 69.901 leituras da Noite.

O defeito é o `ALL ( fato_leitura_sensor )` no denominador: ele divide sempre pelas 209.804 leituras. A lição é conferir num contexto **filtrado**, não só no total.

## As três páginas (D1 a D3)

Cada página começa pela pergunta de quem decide. Peça o palpite da turma **antes** de montar o visual que responde, e feche com o checkpoint projetado.

### D1 · Visão executiva · 15 min

**Pergunta:** quanto produzimos e onde perdemos?

1. Quatro cartões: `Total produzido`, `Refugo`, `% de refugo`, `Ordens`.
2. Barras horizontais: `% de refugo` por `dim_linha[setor]`, ordenadas do maior para o menor. Use setor e não linha: são 40 linhas de produção, e o detalhe por linha fica para a D3.
3. Duas segmentações: `dim_tempo[nome_mes]` e `dim_linha[unidade]`.

**Checkpoint:** 79.702 · 1.852 · 2,32% · 960. Soldagem lidera com 4,01%, seguida de Pintura com 2,96%.

**A descoberta:** peça o palpite "qual unidade perde mais?". Elas quase empatam (2,26% e 2,37%). Ao filtrar março, Soldagem salta para 7,03% e o total vai a 2,64%.

### D2 · Sensores · 15 min

**Pergunta:** alguma máquina está saindo do normal?

1. Três cartões: `Leituras`, `Leituras fora da faixa`, `% fora da faixa`.
2. Segmentação de seleção única em `dim_sensor[tipo_sensor]`, já em **Temperatura Motor**. Não se tira média de °C com rpm.
3. Gráfico de linhas: eixo `dim_tempo[data]`, valor `Valor médio`. No painel de Análise, uma **linha constante em 95** (o limite da faixa).
4. Segmentação de máquina em hierarquia: `dim_sensor[nome_linha]` e depois `dim_sensor[nome_maquina]`. O nome sozinho repete: existe Furadeira CNC em 4 linhas.
5. Matriz: linhas `nome_linha` e `nome_maquina`, colunas `fato_leitura_sensor[turno]`, valor `Leituras fora da faixa`. Formatação condicional com fundo dourado `#F4B942`.

**Checkpoint:** 209.804 · 37 · 0,018%. Na matriz só aparecem duas máquinas, as duas em Presidente Prudente:

| Linha | Máquina | Manhã | Tarde | Noite |
| --- | --- | --- | --- | --- |
| Linha de Soldagem - Colhedora | Robô de Solda TIG |  |  | 32 |
| Linha de Usinagem - Trator | Furadeira CNC | 2 | 3 |  |

**As descobertas:**

- **O Robô de Solda TIG esquenta à noite.** São 32 das 37 leituras fora, todas do sensor `SEN00104`, em 21 noites diferentes. Os valores ficam logo acima do limite (95,1 a 96,7 °C): é um padrão, não um susto.
- **A Furadeira CNC teve um pico em 12/03.** São 5 horas seguidas, das 12h às 16h, subindo até 121,3 °C (sensor `SEN00016`). Esse é um evento, não um padrão.
- Pergunta para a turma: qual dos dois chama a manutenção primeiro, e por quê?

### D3 · Produção e refugo · 10 min

**Pergunta:** onde está a causa do refugo?

1. Matriz: linhas `dim_linha[setor]`, expansível para `fato_producao[motivo_principal]`; colunas `dim_tempo[nome_mes]`; valores `% de refugo` e `Ordens`. Formatação condicional dourada no `% de refugo`.
2. Dispersão: detalhe `dim_linha[nome_linha]`, eixo X `Total produzido`, eixo Y `% de refugo`, legenda `dim_linha[setor]`. Use a segmentação de mês da página.

**Checkpoint:** Soldagem em 2,36% (jan), 2,36% (fev) e 7,03% (mar). Com março filtrado, as 4 linhas de soldagem ficam entre 6,7% e 7,2% na dispersão; nenhuma outra linha passa de 2,9%.

**A descoberta:** a porosidade é o motivo principal de 26 das 34 ordens de soldagem de março. Essas 26 ordens somam 201 das 238 peças rejeitadas no mês.

Vale a provocação final: a porosidade já dominava em janeiro (25 ordens) e fevereiro (21). O que mudou em março foi a **taxa**, que triplicou nas 4 linhas e nas duas unidades. Isso sugere uma causa comum (insumo, gás, procedimento), que o dashboard aponta mas não prova. E o Robô de Solda quente não explica: ele está numa linha só e esquenta desde fevereiro.

## Valores esperados por contexto e plano B

Se uma medida mostrar outro número, rode `09_valores_esperados_dax.sql` e compare no **mesmo contexto**: o defeito está na medida ou no modelo, não no dado. Os nomes aparecem como o DW grava: `Manha`, `Marco`, `Robo de Solda TIG`.

| Contexto | Leituras | Fora da faixa | % fora | Total produzido | Refugo | % de refugo |
| --- | --- | --- | --- | --- | --- | --- |
| Janeiro |  |  |  | 24.740 | 542 | 2,19% |
| Fevereiro | 97.396 | 16 | 0,016% | 26.903 | 570 | 2,12% |
| Março | 112.408 | 21 | 0,019% | 28.059 | 740 | 2,64% |
| Turno Manhã | 69.952 | 2 | 0,003% |  |  |  |
| Turno Tarde | 69.951 | 3 | 0,004% |  |  |  |
| Turno Noite | 69.901 | 32 | 0,046% |  |  |  |
| Presidente Prudente | 104.947 | 37 | 0,035% | 31.201 |  | 2,26% |
| Três Lagoas | 104.857 | 0 (vazio) |  | 48.501 |  | 2,37% |

Variação de produção contra o mês anterior (medida opcional): fevereiro +2.163, março +1.156. Janeiro fica vazio.

**Se algo der errado:**

| Sintoma | O que fazer |
| --- | --- |
| Power BI não lista MySQL ou a conexão falha | Plano B: importe os CSVs da reserva por **Texto/CSV** e crie os 5 relacionamentos à mão |
| CSV leu `71.5` como `715` | **Alterar tipo > Usando a localidade > Inglês (Estados Unidos)** na coluna decimal |
| `Variação vs mês anterior` vazia em março | Confira se `dim_tempo` está marcada como tabela de datas e se `data` é do tipo Data |
| Meses fora de ordem | `nome_mes` sem **Classificar por coluna > mes** |
| Segmentação de unidade não mexe nos sensores | Esperado: na D2 use `dim_sensor[unidade]`, não `dim_linha[unidade]` |
| Furadeira CNC soma leituras de 4 máquinas | Filtre pela hierarquia linha e máquina, ou por `codigo_maquina` |
| Máquina da sala lenta | Para ensaiar, gere o recorte com `--dias 7`; na aula, use o recorte completo de 28 dias |

Um cuidado do conector: se `fora_faixa` chegar como Verdadeiro/Falso, mude o tipo da coluna para **Número inteiro** no Power Query. Senão o `CALCULATE` com `= 1` e a soma não funcionam.
