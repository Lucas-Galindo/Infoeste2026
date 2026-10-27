# Pacote de scripts · Além do Código (Infoeste 2026)

Três pastas, cada uma com um propósito. As medidas DAX e o roteiro do Power BI ficam em `Documentos/PowerBI/`.

| Pasta | Para quem | O que é |
|:--|:--|:--|
| `instrutor/` | Você | Os scripts completos da aula, o gerador do CSV sujo, o gerador das ordens de produção, o gabarito e a reserva (plano B) |
| `aluno/` | Alunos | O que distribuir: o CSV, a staging e o DW (sem o ETL do Dia 1 e sem o gabarito) |
| `laboratorio_estudo/` | Você (estudo) | O laboratório pequeno dos guias de estudo (6 sensores, 8.626 linhas); **não é** o material da aula |

Tudo foi executado de ponta a ponta em **MariaDB 10.11** contra o `agromaq_industrial`. **Não foi executado em MySQL 8:** rode `instrutor/run_pipeline.sh` uma vez no MySQL 8 da sala antes da aula e compare com os números abaixo.

## Ordem de execução (instrutor)

| # | Arquivo | O que faz |
|:--|:--|:--|
| 0 | `03b_populacao_producao.sql` | Popula `ordem_producao` e `perda` no OLTP (chegam vazias do `03_populacao_base.sql`) |
| 1 | `01_criar_staging.sql` | Cria `agromaq_dw`: staging, quarentena e tabela tratada |
| 2 | `02_carregar_csv.sql` | Carrega `leituras_sujas.csv` na staging |
| 3 | `03_perfilamento.sql` | Mede os defeitos (demo da P2) |
| 4 | `04_etl_transformacao.sql` | ETL completo, uma regra por defeito (**plano de segurança da P3**) |
| 5 | `05_dw_agromaq.sql` | DDL do DW: 5 dimensões, 2 fatos e `cfg_faixa_sensor` |
| 6 | `06a_carga_dimensoes.sql` | Upsert das dimensões (E1) |
| 7 | `06b_carga_fatos.sql` | Carga das fatos por partição (E2); rode de novo (E3) |
| 8 | `07_consultas_dw.sql` | Reconciliação, integridade e as perguntas de negócio |
| 9 | `08_reserva.sh` | Gera o dump do DW e os CSVs das 7 tabelas (plano B) |
| 10 | `09_valores_esperados_dax.sql` | Valores para conferir as medidas do X1 |

`run_pipeline.sh` roda tudo e repete a carga para provar a idempotência.

Geradores (Python, `pip install pymysql`): `gerar_leituras.py` (padrão: 28 dias, de 16/02 a 15/03/2026; `--completo` gera 283 dias, cerca de 2,15 milhões de leituras) e `gerar_producao.py`. Mesma semente, mesmo arquivo.

## Números esperados (recorte da aula, semente padrão)

**CSV sujo (`leituras_sujas.csv`): 215.537 linhas.**

| Perfilamento | Valor |
|:--|:--|
| Nulos em `valor` | 1.486 |
| Sentinela `-999` | 1.062 |
| Órfãos (sensores 9999 e 9876) | 743 |
| Datas fora do padrão ISO | 2.230 |
| Valores com vírgula decimal | 1.274 |
| Duplicadas pelo **texto** | 1.920 |
| Variantes de `tipo_maquina` (com `BINARY`) | 16, que viram 4 |

As 1.920 duplicadas pelo texto são 1.911 plantadas mais 9 coincidências entre linhas órfãs (duas órfãs copiaram a mesma leitura). Isso não afeta o ETL, porque o órfão é rejeitado antes.

**ETL:** 215.537 na staging, **209.804 tratadas**, **5.733 rejeitadas**: `SENSOR_INEXISTENTE` 743, `VALOR_NULO` 1.486, `VALOR_SENTINELA` 1.062, `DUPLICADA` 2.442 (1.911 exatas e 531 com a data em formato brasileiro).

**DW:** `dim_linha` 40, `dim_maquina` 120, `dim_sensor` 316, `dim_produto` 20, `dim_tempo` 84 dias (05/01 a 29/03/2026), `fato_leitura_sensor` 209.804, `fato_producao` 960. A conta fecha: 215.537 − 5.733 = 209.804.

**Leituras fora da faixa: 37** (Colhedora na Noite 32, do sensor `SEN00104`; Trator 5, o pico de 12/03 do `SEN00016`, 2 na Manhã e 3 na Tarde). Por turno: Manhã 2, Tarde 3, Noite 32.

**Produção:** 960 ordens; produzido 79.702; refugo 1.852 (2,32%). Por mês: janeiro 24.740 / 2,19%; fevereiro 26.903 / 2,12%; março 28.059 / 2,64%. **A história plantada:** as linhas de **Soldagem** vão de 2,36% (jan e fev) a **7,03% em março**, e o motivo dominante é a **porosidade** (motivo principal de 26 das 34 ordens de soldagem de março).

**Medidas do X1** (conferência): `Leituras` 209.804; `Leituras fora da faixa` 37; `% fora da faixa` 0,018%; fevereiro 97.396 leituras e 16 fora; março 112.408 e 21 fora; `Variação vs mês anterior` em março: +5. Total produzido por mês e % de refugo: tabela acima; por unidade: Presidente Prudente 31.201 (2,26%) e Três Lagoas 48.501 (2,37%).

## Decisões que você precisa confirmar

1. **`fato_producao`: uma linha por ordem de produção concluída.** O slide D3 fala em "matriz máquina × motivo", mas o banco operacional **não liga ordem de produção nem perda a uma máquina** (só à linha). Por isso a fato traz `sk_linha` e `motivo_principal` (o motivo com mais peças rejeitadas na ordem), e a matriz fica **setor (ou linha) × motivo**. **Ajustado:** o slide D3 agora diz "matriz setor × motivo".
2. **Ordens de produção e perdas foram geradas** (960 ordens, 05/01 a 29/03/2026): as tabelas chegam vazias do `03_populacao_base.sql`. Sem elas, não há `fato_producao`, nem páginas 1 e 3 do dashboard, nem `Total produzido` no X1.
3. **Banco `agromaq_dw`** guarda staging, quarentena, tratada, dimensões e fatos (os mesmos nomes do laboratório dos guias). Se preferir dois bancos, é só separar os `USE`.
4. **`faixa` normal por tipo de sensor** não existe no banco operacional: está em `cfg_faixa_sensor` (valores fictícios, editáveis). `Status Operacional` (0 ou 1) nunca sai da faixa.
5. **O desafio de vendas** (`dim_cliente`, fato de vendas) **não foi scriptado**: `venda` e `venda_item` também chegam vazias.
6. **Recorte de 28 dias** (cerca de 215 mil linhas, 10 MB): carrega em segundos, mas confirme o desempenho nas máquinas da sala. Para ensaio rápido: `--dias 7`.
7. **CSV no Power BI em português:** os CSVs de `reserva/dw_csv` usam ponto decimal; se `71.5` virar `715`, use **Alterar tipo > Usando a localidade > Inglês (Estados Unidos)**.
8. **O dump de reserva foi gerado em MariaDB.** Gere de novo no MySQL 8 da sala com `08_reserva.sh`.
9. **Power BI e DAX não foram executados.** Os valores esperados vêm de SQL equivalente (`09_valores_esperados_dax.sql`).
