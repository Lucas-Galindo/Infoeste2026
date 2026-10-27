# Conectar o Power BI ao agromaq_dw (MySQL local, sem senha)

Infoeste 2026 · Além do Código · Dia 2. Instrutores: Lucas Galindo e Lucas Araujo.

> Status: o passo 1 foi confirmado na máquina do instrutor (o Power BI exige o conector do MySQL).
> Os passos 2 a 7 seguem o fluxo padrão do Power BI e ainda precisam ser conferidos na tela depois que o conector for instalado.

## Antes de começar

- MySQL 8 rodando na própria máquina, com o banco `agromaq_dw` já carregado (209.804 leituras, 960 ordens).
- Nenhuma conta, login da Microsoft ou senha de nuvem é necessária. A conexão é local: `localhost`, usuário `root`, senha em branco.
- Nunca grave senha em arquivo do projeto nem no relatório.

## Passos

1. **Instalar o conector (uma vez por máquina).** Instale o MySQL Connector/NET 8.0 (instalador Windows do site oficial do MySQL) e **feche e abra o Power BI** depois. Sem isso, ao escolher "Banco de dados MySQL" o Power BI mostra o aviso "este conector exige que um ou mais componentes adicionais sejam instalados".
2. **Relatório em branco.** Abra o Power BI Desktop e escolha "Relatório em branco". Não é preciso entrar com conta.
3. **Obter dados.** Página Inicial > Obter dados > Mais... > Banco de Dados > "Banco de dados MySQL" > Conectar.
4. **Servidor e banco.**
   - Servidor: `localhost` (ou `127.0.0.1:3306`)
   - Banco de dados: `agromaq_dw`
   - Modo de Conectividade de Dados: **Importar**
   - Opções avançadas: deixe em branco. Confirme com OK.
5. **Credenciais.** Na aba "Banco de Dados": usuário `root`, senha em branco, e Conectar. Se o Power BI avisar sobre conexão sem criptografia, aceite: a conexão é na própria máquina.
6. **Escolher as tabelas.** No Navegador, marque só as 6 tabelas do modelo:
   `dim_tempo`, `dim_sensor`, `dim_linha`, `dim_produto`, `fato_leitura_sensor`, `fato_producao`.
   Deixe de fora `dim_maquina`, `cfg_faixa_sensor`, `stg_leitura`, `etl_rejeito` e `leitura_tratada`. Clique em **Carregar**.
7. **Conferir.** Na visão de Dados, `fato_leitura_sensor` deve ter 209.804 linhas e `fato_producao` 960. Depois siga o `Roteiro_PowerBI_Dia2.md` (relacionamentos, tabela de datas e medidas DAX).

## Se algo der errado

- **"Este conector exige componentes adicionais"**: falta o passo 1, ou o Power BI não foi reaberto depois de instalar.
- **Acesso negado para root**: no Workbench, confira se a conexão local entra como `root` sem senha. Se o seu MySQL tem senha, informe-a na hora, na tela do Power BI, sem salvá-la em arquivo.
- **Banco não aparece**: confira no Workbench se `agromaq_dw` existe e se as tabelas têm dados.
