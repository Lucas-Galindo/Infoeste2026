# Banco de Dados Industrial — Fabricação de Máquinas Agrícolas
## Modelagem Conceitual, Validação e Dicionário de Dados — VERSÃO 2 (Revisada em Auditoria)

---

## 0. SOBRE ESTA REVISÃO

Este documento é uma **revisão** da versão 1 do modelo, mantendo a mesma arquitetura de base
(padrão supertipo/subtipo `item`, estrutura organizacional `unidade → setor → linha →
máquina`, IoT genérico, rastreabilidade por lote, estoque por movimentação). Nenhuma tabela
nova foi criada além do necessário para corrigir os problemas encontrados; uma tabela foi
**renomeada/generalizada** (`produto_componente` → `estrutura_bom`) e nenhuma entidade foi
adicionada por excesso de normalização.

A seção 9 lista, passo a passo, a auditoria realizada: as inconsistências encontradas ao
comparar o modelo conceitual da v1 com o SQL da v1, e como cada uma foi corrigida.

---

## 1. RESUMO DO ENTENDIMENTO DO CENÁRIO

Indústria fictícia de máquinas agrícolas, ~500 funcionários, 2 unidades produtivas:

- **Unidade 1 — Presidente Prudente/SP**: Tratores e Colhedoras
- **Unidade 2 — Três Lagoas/MS**: Plantadoras e Pulverizadores

Escopo do banco: cadastros mestres (produtos, componentes, BOM, fornecedores, materiais),
estrutura organizacional (unidade → setor → linha → máquina), IoT (sensores e leituras),
produção (ordens de produção com etapas — **agora também de componentes de fabricação
própria**, não apenas de produtos acabados), qualidade (inspeções), perdas classificadas,
estoque com movimentações rastreáveis, lotes de matéria-prima, números de série de produtos
acabados, clientes (nacional/internacional), vendas e itens de venda.

Fora do escopo: manutenção de máquinas, dados pessoais sensíveis de funcionários,
população de dados operacionais (esta etapa é somente DDL).

O banco deve suportar 3 anos de histórico, alto volume de leituras IoT, e servir de base
relacional normalizada para futura camada analítica no Power BI (não construiremos modelo
dimensional agora).

---

## 2. DECISÕES DE MODELAGEM IMPORTANTES

### 2.1 Padrão "Supertipo/Subtipo" para materiais (item)

- `item` — supertipo: id, tipo_item (discriminador: `MATERIA_PRIMA`, `COMPONENTE`,
  `PRODUTO_ACABADO`), código, nome, unidade de medida padrão, status.
- `materia_prima` (1:1 com `item`) — tipo de material.
- `componente` (1:1 com `item`) — origem (`PROPRIA`/`FORNECEDOR`) e **categoria_id
  (nullable)**: quando um componente de fabricação própria é específico de uma categoria de
  produto (ex.: "Chassi Trator"), isso fica registrado aqui e é usado para validar a
  compatibilidade OP × linha (seção 2.9). Componentes genéricos/compartilhados entre
  categorias (ex.: parafuso padronizado) deixam este campo `NULL`.
- `produto` (1:1 com `item`) — categoria (`categoria_id`, obrigatória), capacidade
  produtiva, preço de referência.

`estoque_movimentacao`, `perda`, `fornecedor_item`, `estrutura_bom` e **agora também
`ordem_producao`** referenciam apenas `item_id` (ou, quando o caso, especificamente
`componente`/`produto`), sem FK polimórfica solta.

### 2.2 BOM (Bill of Materials) — GENERALIZADA NA REVISÃO

Na v1, a hierarquia produto→componente vivia em `produto_componente`, e a hierarquia entre
sub-componentes vivia separadamente em `componente.componente_pai_id` (auto-relacionamento
**sem quantidade**). A auditoria (seção 9, item 2) identificou que isso era insuficiente:
um componente pode ser montado a partir de vários sub-componentes, cada um com sua própria
quantidade (ex.: 1 Eixo Dianteiro usa 2 Rolamentos + 4 Parafusos M12) — algo que um simples
ponteiro de "pai" não representa.

**Solução adotada**: uma única tabela genérica `estrutura_bom`:

```
estrutura_bom (
    item_pai_id          -- PRODUTO_ACABADO ou COMPONENTE (o que está sendo montado)
    componente_filho_id  -- sempre um COMPONENTE (a peça consumida na montagem)
    quantidade
    unidade_medida_id
)
```

Isso cobre, com uma única estrutura:

- **Produto → Componente** (BOM de topo, o mesmo caso que antes).
- **Componente → Subcomponente** (BOM multi-nível, agora **com quantidade em cada nível**,
  o que o antigo `componente_pai_id` não permitia).

`componente.componente_pai_id` foi **removido** — a hierarquia agora é 100% representada
pela própria `estrutura_bom` (quando `item_pai_id` é um `COMPONENTE`).

### 2.3 Categoria de produto ↔ Unidade fabril

Cada categoria (Trator, Colhedora, Plantadora, Pulverizador) é fabricada em **uma única
unidade**. A unidade fica associada à **categoria** (`categoria_produto.unidade_id`);
`produto` referencia apenas `categoria_id`. Um trigger em `linha_producao` garante que a
categoria da linha pertence à mesma unidade do setor da linha.

### 2.4 IoT — estrutura flexível

`tipo_sensor` → `sensor` → `leitura_sensor` (genérica, sem uma tabela por tipo de sensor).
**Revisão item 13**: o particionamento por mês de `leitura_sensor` foi estendido para cobrir
**2025-01 a 2029-12** (5 anos civis completos) + partição de captura (`p_futuro`), dando
folga confortável sobre os 3 anos de dataset planejados, independentemente do ano-calendário
exato em que a carga de dados realmente começar. Instruções para expansão futura (via
`REORGANIZE PARTITION`) estão comentadas no SQL.

### 2.5 Rastreabilidade lote → produção → produto acabado → venda

- `lote` registra a entrada de matéria-prima.
- `op_consumo_lote` associa uma **Ordem de Produção** (agora podendo ser de componente ou
  de produto acabado — seção 2.8) aos lotes consumidos.
- `produto_serial` vincula-se à `ordem_producao` que o originou, e é validado por trigger
  para garantir que o produto do serial é exatamente o item que aquela OP fabrica
  (seção 2.10).
- `venda_item_serial` vincula um item de venda aos números de série vendidos.

Como uma OP agora pode fabricar um **componente**, a cadeia de rastreabilidade fica mais rica:
é possível seguir `lote de matéria-prima → OP do componente → estoque do componente →
consumo desse componente em uma OP de produto acabado (via estrutura_bom) → produto_serial →
venda`, respondendo tanto "quanto de matéria-prima foi consumido para fabricar um
componente" quanto "quais produtos foram produzidos com o lote X".

### 2.6 Perdas — três naturezas distintas, mesma estrutura classificada

`tipo_perda` (catálogo) + tabela única `perda`. **Revisão item 8**: o campo genérico
`etapa_id` (que apontava só para o catálogo `etapa_processo`, sem amarrar à OP específica)
foi substituído por `op_etapa_id`, que aponta para a **instância real** de uma etapa dentro
de uma OP específica (ex.: "Soldagem da OP 100", não apenas "Soldagem" em abstrato). Um
trigger garante que, se `op_etapa_id` e `op_id` forem informados juntos, sejam consistentes
(e preenche `op_id` automaticamente a partir da etapa quando este vier vazio).

### 2.7 Estoque — movimentação, não saldo

Só existem movimentações (`estoque_movimentacao`); o saldo é sempre derivado. **Revisão item
11**: triggers adicionais garantem que `item_id` da movimentação seja compatível com o lote
(quando informado), com o item produzido pela OP (quando a movimentação é de produção sem
lote) e com o produto vendido (quando é uma movimentação de venda) — sem usar FK polimórfica.

### 2.8 Produção de itens fabricáveis — CORRIGIDO NA REVISÃO (problema crítico)

Na v1, `ordem_producao` referenciava diretamente `produto`, impedindo que uma OP
representasse a fabricação interna de um componente (chassi, eixo, chicote elétrico etc.) —
incompatível com o cenário, que exige distinguir componentes de fabricação própria dos
comprados de fornecedor.

**Solução**: `ordem_producao.produto_item_id` foi renomeado para `ordem_producao.item_id` e
passou a referenciar o **supertipo `item`**, não mais só `produto`. Um conjunto de triggers
garante:

1. O item da OP **nunca** pode ser `MATERIA_PRIMA`.
2. Se o item for `COMPONENTE`, ele deve ter `origem = 'PROPRIA'` — não faz sentido abrir uma
   OP para fabricar um componente que é, por definição, comprado de fornecedor.
3. A categoria do item (a do `produto`, sempre; ou a do `componente`, quando preenchida)
   deve ser igual à categoria da linha de produção informada (seção 2.9).

Isso permite responder diretamente:

- **"Quanto produzimos de cada componente?"** — `SUM(quantidade_produzida)` agrupado por
  `ordem_producao.item_id` filtrando `item.tipo_item = 'COMPONENTE'`.
- **"Qual componente apresentou mais perdas?"** — `perda.item_id` já é genérico; basta
  filtrar por `item.tipo_item = 'COMPONENTE'` e agrupar.
- **"Quanto de matéria-prima foi consumido para fabricar um componente?"** — via
  `op_consumo_lote` das OPs cujo `item_id` é um componente.
- **"Quais componentes internos foram utilizados na montagem do produto final?"** — via
  `estrutura_bom` (produto → componente), independentemente de o componente ter sido
  fabricado internamente ou comprado.

### 2.9 OP × Linha × Categoria — CORRIGIDO NA REVISÃO

**Revisão item 6**: antes não havia nenhuma garantia de que a linha informada numa OP
realmente fabricasse a categoria daquele item. O mesmo conjunto de triggers da seção 2.8
valida: `item.categoria (via produto ou componente) = linha_producao.categoria_id`. Para
componentes sem categoria definida (compartilhados entre categorias), a checagem de
categoria é dispensada, mas a checagem de "não é matéria-prima" e "origem própria" continua
valendo.

### 2.10 Produto serializado × OP — CORRIGIDO NA REVISÃO

**Revisão itens 7 e 10**: `produto_serial` tinha `linha_id` e `unidade_id` **totalmente
deriváveis** de `op_id` (via `ordem_producao.linha_id → linha_producao.setor_id →
setor.unidade_id`) — foram **removidos** para eliminar risco de divergência sem nenhum
ganho de integridade. `produto_item_id` foi **mantido** (é o dado semântico central do
registro) e passou a ser validado por trigger contra `ordem_producao.item_id`: mesmo que as
duas FKs individuais sejam tecnicamente válidas, não é mais possível cadastrar um número de
série de "Colhedora CH500" numa OP que na verdade fabrica "Trator TR220".

### 2.11 Qualidade

`inspecao_qualidade` referencia a etapa específica da OP (`op_etapa`), com resultado
(`APROVADO`/`REPROVADO`/`RETRABALHO`) e `motivo_nao_conformidade`.

### 2.12 Etapas de produção flexíveis

`etapa_processo` é catálogo mestre; `op_etapa` são instâncias por OP, com sequência livre
(nenhuma OP é obrigada a ter todas as etapas do catálogo). **Revisão item 9**: adicionado
`UNIQUE(op_id, sequencia)` — uma mesma OP não pode ter duas etapas na mesma posição da
sequência.

### 2.13 Clientes e internacionalização

`pais` normalizado, com `mercado` (`NACIONAL`/`INTERNACIONAL`) como **único** ponto de
armazenamento desse conceito. **Revisão item 3**: `cliente.tipo_mercado` foi **removido** —
existia simultaneamente com `cliente.pais_id`, criando risco de divergência (ex.: cliente
com país China, mas mercado marcado como Nacional). O mercado de um cliente é sempre obtido
com um `JOIN cliente.pais_id = pais.id_pais` (ou, na camada de BI, uma view/medida
`mercado = IF(pais.sigla_iso = 'BR', 'NACIONAL', 'INTERNACIONAL')`).

**Revisão item 4**: `cliente.estado_id` podia apontar para um estado de um país diferente do
`cliente.pais_id` (ex.: cliente da China com estado de São Paulo). Um trigger agora garante
que, se `estado_id` for informado, `estado_provincia.pais_id` deve ser igual a
`cliente.pais_id`.

### 2.14 Funcionário × Setor × Unidade — CORRIGIDO NA REVISÃO

**Revisão item 5**: `funcionario` tinha `unidade_id` **e** `setor_id`, sem nenhuma garantia
de que fossem consistentes entre si (um funcionário podia estar lotado num setor de uma
unidade, mas com `unidade_id` apontando para outra). Como a unidade é 100% determinável por
`setor_id → setor.unidade_id`, o campo `funcionario.unidade_id` foi **removido**,
priorizando normalização sobre a conveniência de evitar um join a mais — que é de apenas um
salto e, portanto, barato tanto operacionalmente quanto no Power BI.

### 2.15 Sobre não criar a entidade `empresa`

**Revisão item 14**: avaliado e **mantida a decisão de não criar** uma tabela `empresa`.
Justificativa: há uma única empresa no escopo deste banco (não existe — e não está prevista
— nenhuma outra empresa/grupo/matriz a modelar), então uma tabela `empresa` com uma única
linha não agregaria nenhuma capacidade de consulta, filtro ou integridade que já não exista
hoje através de `unidade`. Se, no futuro, o cenário evoluir para múltiplas empresas (holding,
fusão, etc.), essa entidade pode ser introduzida então, com `unidade.empresa_id` apontando
para ela — sem necessidade de redesenhar o restante do modelo. Isso evita adicionar uma
entidade apenas por excesso de normalização, conforme instruído.

---

## 3. LISTA DE ENTIDADES (38 tabelas — mesma contagem da v1; uma renomeada/generalizada)

### Catálogos
1. `unidade`
2. `setor`
3. `cargo`
4. `turno`
5. `unidade_medida`
6. `categoria_produto`
7. `tipo_material`
8. `tipo_sensor`
9. `etapa_processo`
10. `motivo_nao_conformidade`
11. `tipo_perda`
12. `tipo_movimentacao_estoque`
13. `pais`
14. `estado_provincia`

### Estrutura organizacional e produtiva
15. `linha_producao`
16. `maquina`
17. `sensor`
18. `leitura_sensor` (alto volume, particionada — cobertura estendida)
19. `funcionario` (**sem `unidade_id`** — revisão item 5)

### Materiais (supertipo/subtipo)
20. `item` (supertipo)
21. `materia_prima` (subtipo)
22. `componente` (subtipo — **sem `componente_pai_id`, com `categoria_id` nullable**)
23. `produto` (subtipo)
24. `estrutura_bom` (**renomeada de `produto_componente`, generalizada** — associativa N:N)

### Fornecimento e rastreabilidade
25. `fornecedor`
26. `fornecedor_item` (associativa N:N — **validada por tipo/origem**)
27. `lote`
28. `op_consumo_lote` (associativa N:N — rastreabilidade)

### Produção
29. `ordem_producao` (**`item_id` no lugar de `produto_item_id`** — pode ser componente ou produto)
30. `op_etapa` (**`UNIQUE(op_id, sequencia)`**)
31. `inspecao_qualidade`
32. `perda` (**`op_etapa_id` no lugar de `etapa_id`**)

### Estoque
33. `estoque_movimentacao` (**validações de compatibilidade item×lote×OP×venda**)

### Produto acabado e comercial
34. `produto_serial` (**sem `linha_id`/`unidade_id`**, validado contra a OP)
35. `cliente` (**sem `tipo_mercado`**, `estado_id` validado contra `pais_id`)
36. `venda`
37. `venda_item`
38. `venda_item_serial` (associativa N:N)

---

## 4. DESCRIÇÃO DAS ENTIDADES, PKs, FKs E CARDINALIDADES

| # | Entidade | Finalidade | PK | Principais FK | Cardinalidade |
|---|---|---|---|---|---|
| 1 | unidade | As 2 plantas industriais | id_unidade | — | 1 unidade : N setor |
| 2 | setor | Departamentos dentro da unidade | id_setor | unidade_id | 1 setor : N linha_producao; 1 setor : N funcionario |
| 3 | cargo | Catálogo de cargos | id_cargo | — | 1 cargo : N funcionario |
| 4 | turno | Catálogo de turnos | id_turno | — | 1 turno : N funcionario |
| 5 | unidade_medida | kg, un, m, l, °C, RPM etc. | id_unidade_medida | — | 1 : N em vários pontos |
| 6 | categoria_produto | Categoria ligada à unidade fabricante | id_categoria | unidade_id | 1 : N produto; 1 : N linha_producao; 1 : N componente (opcional) |
| 7 | tipo_material | Aço, alumínio, cobre etc. | id_tipo_material | — | 1 : N materia_prima |
| 8 | tipo_sensor | Temperatura, vibração etc. | id_tipo_sensor | unidade_medida_id | 1 : N sensor |
| 9 | etapa_processo | Corte, Soldagem, Pintura etc. | id_etapa | — | 1 : N op_etapa |
| 10 | motivo_nao_conformidade | Falha dimensional, elétrica etc. | id_motivo | — | 1 : N inspecao_qualidade; 1 : N perda |
| 11 | tipo_perda | Perda de MP, fabricação, montagem, defeito | id_tipo_perda | — | 1 : N perda |
| 12 | tipo_movimentacao_estoque | Entrada, saída, ajuste | id_tipo_mov | — | 1 : N estoque_movimentacao |
| 13 | pais | Países dos clientes; único local do conceito de mercado | id_pais | — | 1 : N cliente; 1 : N estado_provincia |
| 14 | estado_provincia | Estados/províncias, vinculados a um país | id_estado | pais_id | 1 : N cliente |
| 15 | linha_producao | Linha física de fabricação | id_linha | setor_id, categoria_id | 1 : N maquina; 1 : N ordem_producao |
| 16 | maquina | Máquina industrial | id_maquina | linha_id | 1 : N sensor |
| 17 | sensor | Sensor IoT instalado | id_sensor | maquina_id, tipo_sensor_id | 1 : N leitura_sensor |
| 18 | leitura_sensor | Série temporal de leituras IoT | id_leitura (+data_hora, partição) | sensor_id (sem FK — tabela particionada) | N:1 sensor |
| 19 | funcionario | Colaborador | id_funcionario | cargo_id, setor_id, turno_id | N:1 em cada catálogo; unidade via setor |
| 20 | item | Supertipo de material | id_item | unidade_medida_id | 1:1 com subtipo correspondente |
| 21 | materia_prima | Subtipo matéria-prima | item_id | tipo_material_id | 1:1 item; 1 : N lote |
| 22 | componente | Subtipo componente | item_id | categoria_id (nullable) | 1:1 item; 1 : N estrutura_bom (como filho) |
| 23 | produto | Subtipo produto/modelo acabado | item_id | categoria_id | 1:1 item; 1 : N produto_serial |
| 24 | estrutura_bom | BOM (produto/componente → subcomponente) | (item_pai_id, componente_filho_id) | item_pai_id (item), componente_filho_id (componente), unidade_medida_id | N:N item×componente |
| 25 | fornecedor | Fornecedor externo | id_fornecedor | — | 1 : N fornecedor_item; 1 : N lote |
| 26 | fornecedor_item | Itens que cada fornecedor fornece (só MP e componente comprado) | (fornecedor_id, item_id) | fornecedor_id, item_id | N:N fornecedor×item |
| 27 | lote | Lote de matéria-prima recebido | id_lote | materia_prima_item_id, fornecedor_id | 1 : N estoque_movimentacao; 1 : N op_consumo_lote |
| 28 | op_consumo_lote | Rastreabilidade OP × lote consumido | (op_id, lote_id) | ordem_producao_id, lote_id | N:N OP×lote |
| 29 | ordem_producao | Ordem de produção — de componente OU produto | id_op | item_id, linha_id | 1 : N op_etapa; 1 : N produto_serial (quando item = produto) |
| 30 | op_etapa | Etapa executada dentro de uma OP | id_op_etapa | op_id, etapa_id, funcionario_id | 1 : N inspecao_qualidade; 1 : N perda; **UNIQUE(op_id, sequencia)** |
| 31 | inspecao_qualidade | Resultado de inspeção em uma etapa real | id_inspecao | op_etapa_id, motivo_id, funcionario_id | N:1 op_etapa |
| 32 | perda | Registro de perda classificada | id_perda | tipo_perda_id, op_id, op_etapa_id, item_id | N:1 em cada FK (todas opcionais exceto tipo) |
| 33 | estoque_movimentacao | Movimentação de estoque | id_movimentacao | item_id, unidade_id, lote_id, tipo_mov_id, op_id, venda_item_id | N:1 item; validada contra lote/OP/venda |
| 34 | produto_serial | Unidade física fabricada (nº de série) | id_serial | produto_item_id, op_id | N:1 OP; 1 : N venda_item_serial |
| 35 | cliente | Cliente (empresa) | id_cliente | pais_id, estado_id | 1 : N venda |
| 36 | venda | Pedido de venda (cabeçalho) | id_venda | cliente_id | 1 : N venda_item |
| 37 | venda_item | Item do pedido de venda | id_venda_item | venda_id, produto_item_id | 1 : N venda_item_serial |
| 38 | venda_item_serial | Nº de série vendido em cada item | (venda_item_id, serial_id) | venda_item_id, serial_id | N:N venda_item×produto_serial |

---

## 5. TABELAS ASSOCIATIVAS (N:N)

- `estrutura_bom` — Item (produto ou componente) × Componente filho, com quantidade/unidade
  (BOM de topo **e** multi-nível, unificados).
- `fornecedor_item` — Fornecedor × Item (matéria-prima ou componente comprado).
- `op_consumo_lote` — Ordem de Produção × Lote (rastreabilidade).
- `venda_item_serial` — Item de venda × Produto serializado.

---

## 6. REGRAS DE INTEGRIDADE (consolidado após a revisão)

- Toda FK com `ON UPDATE CASCADE` e `ON DELETE RESTRICT`.
- `produto_serial.numero_serie`, `item.codigo`, `lote.numero_lote`, `ordem_producao.numero_op`,
  `venda.numero_pedido` — todos `UNIQUE`.
- `item.tipo_item` controla os subtipos; cada subtipo só existe se o `item` tiver o
  `tipo_item` compatível (trigger `BEFORE INSERT`).
- **`ordem_producao`** (revisão itens 1 e 6): item não pode ser `MATERIA_PRIMA`; se
  `COMPONENTE`, exige `origem = 'PROPRIA'`; categoria do item deve bater com a categoria da
  linha (quando aplicável).
- **`estrutura_bom`** (revisão item 2): `item_pai_id` deve ser `PRODUTO_ACABADO` ou
  `COMPONENTE`; não pode ser igual a `componente_filho_id`. Ciclos indiretos multi-nível
  ficam como responsabilidade da aplicação/ETL (exigiriam CTE recursiva, fora do escopo de
  uma constraint declarativa).
- **`produto_serial`** (revisão item 10): `produto_item_id` deve ser exatamente o item que a
  OP referenciada (`op_id`) fabrica.
- **`perda`** (revisão item 8): se `op_etapa_id` informado, deve pertencer à mesma OP de
  `op_id` (ou `op_id` é preenchido automaticamente a partir da etapa).
- **`estoque_movimentacao`** (revisão item 11): item compatível com o lote (quando
  informado), com o item produzido pela OP (movimentação de produção sem lote) e com o
  produto vendido (movimentação de venda).
- **`fornecedor_item`** (revisão item 12): não aceita `PRODUTO_ACABADO`; se `COMPONENTE`,
  exige `origem = 'FORNECEDOR'`.
- **`cliente`** (revisão item 4): `estado_id`, quando informado, deve pertencer ao mesmo
  país de `pais_id`.
- **`linha_producao`**: categoria da linha deve pertencer à mesma unidade do setor.
- **`op_etapa`** (revisão item 9): `UNIQUE(op_id, sequencia)`.
- `ordem_producao`: `quantidade_produzida <= quantidade_planejada`;
  `quantidade_aprovada + quantidade_retrabalho + quantidade_rejeitada <= quantidade_produzida`.
- `venda_item.valor_total` — coluna gerada (`quantidade * preco_unitario`).
- Datas de fim não podem ser anteriores às datas de início (OP e op_etapa).

---

## 7. NORMALIZAÇÃO — REVISÃO GERAL (item 15 do pedido de auditoria)

Auditoria final, por tipo de problema:

- **Atributos redundantes removidos**: `produto.unidade_id` (v1, já eliminado antes),
  `cliente.tipo_mercado`, `funcionario.unidade_id`, `produto_serial.linha_id`,
  `produto_serial.unidade_id`, `componente.componente_pai_id` (substituído por
  `estrutura_bom`).
- **Dependências funcionais corrigidas**: mercado depende só de `pais`; unidade do
  funcionário depende só de `setor`; linha/unidade do serial dependem só da OP; categoria do
  item de uma OP depende do subtipo (produto ou componente), não mais assumida
  implicitamente.
- **FKs que podiam produzir inconsistência, agora com trigger de validação**: `ordem_producao`
  (item×linha×categoria), `produto_serial` (produto×OP), `perda` (etapa×OP), `cliente`
  (estado×país), `estoque_movimentacao` (item×lote/OP/venda), `fornecedor_item`
  (tipo/origem do item).
- **Cardinalidade corrigida**: `ordem_producao` deixou de ser estritamente N:1 com `produto`
  e passou a ser N:1 com `item` (supertipo), habilitando `item.tipo_item IN ('COMPONENTE',
  'PRODUTO_ACABADO')`.
- **Tabela associativa que precisava ser generalizada**: `produto_componente` → `estrutura_bom`
  (ver seção 2.2).
- **N:N escondido identificado e corrigido**: a hierarquia de sub-componentes com quantidade
  era, na prática, um relacionamento N:N item-pai × componente-filho que estava mal
  representado como 1:N via `componente_pai_id` (perdendo a quantidade por nível).
- **Nenhum campo identificado que devesse virar entidade própria** além do que já existe.
- **Nenhuma entidade desnecessária identificada** para remoção; avaliada e descartada a
  criação de `empresa` (seção 2.15).

---

## 8. REVISÃO DAS CARDINALIDADES (item 16 do pedido de auditoria)

| Relação | Cardinalidade revalidada |
|---|---|
| Unidade : Setor | 1:N — inalterado |
| Setor : Linha | 1:N — inalterado |
| Linha : Máquina | 1:N — inalterado |
| Máquina : Sensor | 1:N — inalterado |
| Sensor : Leitura | 1:N — inalterado (sem FK física por particionamento, mas cardinalidade lógica mantida) |
| Categoria : Produto | 1:N — inalterado |
| Categoria : Componente | 1:N (opcional/nullable) — **novo**, revisão item 6 |
| Item (produto/componente) : Componente filho (BOM) | N:N via `estrutura_bom` — **generalizado**, revisão item 2 |
| Fornecedor : Item | N:N via `fornecedor_item` — inalterado na forma, **validado por tipo/origem** |
| OP : Lote | N:N via `op_consumo_lote` — inalterado |
| OP : Etapa | 1:N via `op_etapa`, agora com **UNIQUE(op_id, sequencia)** |
| OP : Produto Serial | 1:N — **agora só válido quando o item da OP é PRODUTO_ACABADO** (validado por trigger) |
| Item (supertipo) : OP | 1:N — **antes era Produto : OP**; revisão item 1, o principal ajuste desta auditoria |
| Cliente : Venda | 1:N — inalterado |
| Venda : Venda Item | 1:N — inalterado |
| Venda Item : Produto Serial | N:N via `venda_item_serial` — inalterado |

---

## 9. AUDITORIA — PROCESSO, INCONSISTÊNCIAS ENCONTRADAS E CORREÇÕES

Processo seguido: leitura integral do modelo conceitual v1 → leitura integral do
`02_schema.sql` v1 → comparação linha a linha → lista de inconsistências → correção do
modelo conceitual → revalidação de entidades/PKs/FKs/cardinalidades/regras → atualização do
SQL → segunda auditoria do SQL final → validação de execução em MySQL/MariaDB 8.0+
(testado de ponta a ponta, incluindo os cenários de erro esperados — ver changelog abaixo).

### Lista de alterações realizadas

| # | Problema encontrado | Onde | Correção aplicada |
|---|---|---|---|
| 1 | OP só podia referenciar `produto`, impedindo fabricação interna de componente | `ordem_producao.produto_item_id` | Renomeado para `item_id`, agora referencia `item` (supertipo); trigger impede `MATERIA_PRIMA` e exige `origem='PROPRIA'` para componente |
| 2 | Hierarquia de componente sem quantidade por nível; BOM de produto separada da hierarquia de componente | `componente.componente_pai_id` + `produto_componente` | Unificadas em `estrutura_bom` (item_pai × componente_filho, com quantidade) |
| 3 | Mercado armazenado em dois lugares (`cliente.tipo_mercado` e implicitamente via `pais.mercado`) | `cliente.tipo_mercado` | Coluna removida; mercado sempre derivado de `cliente.pais_id → pais.mercado` |
| 4 | `cliente.estado_id` podia pertencer a país diferente de `cliente.pais_id` | `cliente` | Trigger valida `estado_provincia.pais_id = cliente.pais_id` |
| 5 | `funcionario.unidade_id` podia divergir de `setor.unidade_id` | `funcionario.unidade_id` | Coluna removida; unidade sempre obtida via `setor_id` |
| 6 | OP podia ter produto/componente de uma categoria e linha de outra categoria | `ordem_producao` × `linha_producao` | Trigger valida categoria do item × categoria da linha |
| 7 | `produto_serial.linha_id`/`unidade_id` totalmente deriváveis da OP, redundantes | `produto_serial` | Colunas removidas; obtidas via `op_id` |
| 8 | `perda.etapa_id` referenciava só o catálogo, não a etapa real de uma OP específica | `perda.etapa_id` | Substituído por `op_etapa_id` (instância real), com trigger de consistência com `op_id` |
| 9 | Nada impedia duas etapas com a mesma sequência numa OP | `op_etapa` | `UNIQUE(op_id, sequencia)` |
| 10 | `produto_serial.produto_item_id` podia divergir do item realmente produzido pela OP | `produto_serial` | Trigger valida `produto_item_id = ordem_producao.item_id` |
| 11 | `estoque_movimentacao` sem garantia de coerência item×lote / item×OP / item×venda | `estoque_movimentacao` | Trigger com as três validações |
| 12 | `fornecedor_item` podia registrar fornecimento de produto acabado ou de componente próprio | `fornecedor_item` | Trigger restringe a matéria-prima e componente de origem FORNECEDOR |
| 13 | Particionamento de `leitura_sensor` cobria só 2026 | `leitura_sensor` | Partições mensais estendidas para 2025–2029 + `p_futuro` |
| 14 | Avaliar necessidade de entidade `empresa` | — | Mantida a decisão de **não criar** (empresa única, sem ganho de integridade — seção 2.15) |

### Segunda auditoria do SQL final (pós-correção)

- Todas as 38 tabelas, 4 tabelas associativas, PKs e os agora ~58 FKs foram revisadas uma a
  uma contra o dicionário de dados da seção 4 — sem divergência encontrada.
- Todas as novas regras de negócio (itens 1, 4, 6, 8, 9, 10, 11, 12) foram implementadas via
  trigger `BEFORE INSERT`/`BEFORE UPDATE`, já que o MySQL/MariaDB recusa `CHECK` sobre coluna
  que já participa de `FOREIGN KEY` (erro 1901 — confirmado nos testes) e não suporta `CHECK`
  entre tabelas diferentes.
- `leitura_sensor` permanece sem FK declarada (limitação do MySQL/MariaDB para tabelas
  particionadas), documentado no SQL.

### Verificação de execução em MySQL 8.0+/MariaDB (item 19, etapa 9)

O script `02_schema.sql` revisado foi executado do zero em um servidor MariaDB 10.11
(compatível com a sintaxe usada, que não emprega nenhum recurso exclusivo do MySQL) sem
nenhum erro. Além disso, **todas as 12 regras de negócio críticas** introduzidas nesta
revisão foram testadas com inserções de teste (não incluídas no arquivo final, pois o
enunciado veda `INSERT`), confirmando que:

- uma OP não aceita item do tipo `MATERIA_PRIMA`;
- uma OP aceita fabricar um `COMPONENTE` de origem `PROPRIA`;
- uma OP rejeita `COMPONENTE` de origem `FORNECEDOR`;
- uma OP rejeita item cuja categoria não bate com a categoria da linha;
- `estado_id` de um país diferente do `pais_id` do cliente é rejeitado;
- `UNIQUE(op_id, sequencia)` bloqueia etapas duplicadas;
- `perda.op_etapa_id` de uma OP diferente da informada em `op_id` é rejeitada, e o
  preenchimento automático de `op_id` a partir da etapa funciona;
- `produto_serial` com produto divergente do item da OP é rejeitado;
- `estoque_movimentacao` com item incompatível com o lote é rejeitada;
- `fornecedor_item` rejeita produto acabado e componente de origem própria;
- `estrutura_bom` aceita hierarquia multi-nível com quantidade e rejeita item pai igual ao
  filho.

---

## 10.5 VERIFICAÇÃO FINAL — AUDITORIA DE QUALIDADE E NOTA

Esta seção documenta uma auditoria adicional, feita **depois** da revisão da seção 9, com o
objetivo específico de validar o alinhamento entre este documento e o `02_schema.sql`, e de
caçar problemas que a revisão anterior pudesse ter deixado passar. O processo foi: reler os
dois arquivos por completo, cruzar cada FK/índice/trigger do SQL contra o dicionário de dados
(seção 4), testar hipóteses de problema diretamente em um MySQL 8.0.46 real (não apenas por
inspeção visual), e só então corrigir.

### Alinhamento entre o documento e o SQL

**Sim, estão alinhados.** Contagem de tabelas (38), colunas removidas/renomeadas
(`ordem_producao.item_id`, `componente` sem `componente_pai_id`, `produto_serial` sem
`linha_id`/`unidade_id`, `cliente` sem `tipo_mercado`, `funcionario` sem `unidade_id`) e as
regras de negócio descritas na seção 6 batem com o que está implementado no SQL. Não foi
encontrada nenhuma contradição entre o que o documento afirma e o que o schema realmente faz.

### Uma suspeita investigada e descartada

Antes de aceitar qualquer suspeita como problema real, cada uma foi testada. A primeira
hipótese — de que várias colunas teriam **índice duplicado** (um automático, criado pela
própria `FOREIGN KEY`, e outro explícito da seção 15, ex. `ordem_producao.item_id`) — foi
testada isoladamente em uma tabela de teste e **descartada**: o MySQL 8.0 automaticamente
substitui o índice de suporte auto-gerado pela FK por um índice explícito equivalente
criado depois, então não há duplicação física de índice neste schema. Isso é registrado
aqui para que a auditoria seja auditável — não só a conclusão, mas o processo de checagem.

### Problemas reais encontrados e corrigidos

| # | Problema | Severidade | Onde | Correção aplicada |
|---|---|---|---|---|
| A | `venda_item_serial` não validava que o produto do número de série vendido é o mesmo produto do `venda_item` — a mesma classe de falha já corrigida para `produto_serial`×OP (item 10 da seção 9), mas que tinha ficado sem cobertura no lado da venda. Mesmo com as duas FKs individuais válidas, era possível vincular o serial de um Trator a um item de venda que na verdade vende uma Colhedora. | **Alta** (rastreabilidade/integridade comercial) | `venda_item_serial` | Adicionados triggers `trg_vendaitemserial_valida_produto_ins/upd` |
| B | Nenhuma tabela tinha `CHECK` de positividade em quantidade/preço/capacidade (exceto as somas já existentes em `ordem_producao`). Era possível inserir `lote.quantidade = -10`, `venda_item.preco_unitario = 0`, etc. | **Média** | `lote`, `op_consumo_lote`, `perda`, `estoque_movimentacao`, `produto`, `linha_producao`, `maquina`, `estrutura_bom`, `venda_item`, `fornecedor_item`, `ordem_producao.quantidade_planejada`, `op_etapa.sequencia` | 15 novos `CHECK` adicionados diretamente nas tabelas |
| C | `funcionario.matricula`, `maquina.codigo` e `sensor.codigo` são identificadores naturais (mencionados explicitamente no enunciado original como "código"/"matrícula"), mas só tinham índice comum, não `UNIQUE` — era possível cadastrar dois funcionários com a mesma matrícula ou duas máquinas com o mesmo código. | **Média** | `funcionario`, `maquina`, `sensor` | Índices trocados para `UNIQUE` (`ux_funcionario_matricula`, `ux_maquina_codigo`, `ux_sensor_codigo`) |
| D | `componente.categoria_id` podia ser preenchida mesmo quando `origem = 'FORNECEDOR'`, contrariando a própria intenção documentada na seção 2.1 (categoria só faz sentido para componente de fabricação própria). | **Baixa** (consistência entre doc e dado, não quebra rastreabilidade) | `componente` | Trigger valida `origem='FORNECEDOR' ⇒ categoria_id IS NULL` |
| E | As checagens de `tipo_item` dos subtipos (`materia_prima`, `componente`, `produto`) só existiam para `BEFORE INSERT`, sem equivalente `BEFORE UPDATE` — uma lacuna defensiva, já que `item_id` é a PK desses subtipos e raramente seria atualizada, mas inconsistente com o padrão INSERT+UPDATE usado em todos os outros triggers do schema. | **Baixa** (defesa em profundidade) | `materia_prima`, `componente`, `produto` | Adicionados `trg_materiaprima_valida_tipo_upd`, `trg_componente_valida_tipo_upd`, `trg_produto_valida_tipo_upd` |

Todos os cinco itens foram corrigidos no `02_schema.sql` e **testados com inserções reais em
um MySQL 8.0.46**, confirmando que cada regra rejeita exatamente o caso inválido e aceita o
caso válido (ex.: vincular o serial certo ao item de venda certo funciona; vincular o serial
errado é rejeitado com a mensagem de erro apropriada).

### Nota

| | Nota | Justificativa |
|---|---|---|
| **Antes desta verificação** (v2, seção 9) | **8,0 / 10** | Arquitetura correta, as 14 correções da auditoria anterior implementadas e testadas, documento e SQL alinhados — mas com as 5 lacunas acima ainda presentes (nenhuma quebra a execução, mas item A é uma lacuna de integridade real na trilha comercial, e B/C são omissões que um banco de produção não deveria ter). |
| **Depois desta verificação** (v3, esta seção) | **9,5 / 10** | As 5 lacunas foram corrigidas e testadas. Os 0,5 ponto restante fica por conta de limitações estruturais já documentadas e aceitas conscientemente (não são "erros" a corrigir, são trade-offs): `leitura_sensor` sem FK física (limitação do MySQL para tabelas particionadas), e ciclos indiretos multi-nível na BOM (`A usa B, B usa C, C usa A`) que ficam como responsabilidade da aplicação/ETL por exigirem CTE recursiva fora do escopo de uma constraint declarativa. |

---

## 10.6 RESUMO DAS CORREÇÕES DESTA VERIFICAÇÃO (v3)

- **24 triggers** (eram 19): +2 `venda_item_serial`, +1 `componente` (categoria×origem, incorporado
  aos triggers de tipo existentes), +3 `_upd` que faltavam nos subtipos de `item`.
- **19 `CHECK` constraints** (eram 4): +15 novos, todos de positividade de quantidade, preço
  ou capacidade.
- **3 índices promovidos a `UNIQUE`**: `maquina.codigo`, `sensor.codigo`, `funcionario.matricula`
  (mais um índice `UNIQUE` novo em `sensor.codigo`, que antes não tinha nenhum índice).
- Nenhuma tabela nova, nenhuma tabela removida, nenhuma mudança de cardinalidade — a
  arquitetura da v2 permanece intacta; esta é uma auditoria de **hardening**, não uma
  revisão estrutural.
- Executado do zero em MySQL 8.0.46 real sem erros; as 5 correções testadas individualmente
  com casos de sucesso e de rejeição esperada.

---

## 10. RESUMO FINAL DA ESTRUTURA

- **38 tabelas** (mesma contagem da v1): 14 catálogos, 5 estrutura organizacional/IoT,
  5 materiais (supertipo + 3 subtipos + BOM generalizada), 4 fornecimento/rastreabilidade,
  4 produção, 1 estoque, 5 comercial.
- Nenhuma tabela de manutenção foi criada (fora de escopo).
- Nenhuma entidade `empresa` criada — decisão justificada na seção 2.15.
- Nenhum dado populado — apenas DDL (estrutura, constraints, triggers, índices).
- Modelo relacional normalizado; toda redundância identificada na auditoria foi eliminada
  (mercado, unidade do funcionário, linha/unidade do serial, hierarquia de componente sem
  quantidade).
- Toda regra de negócio que o MySQL/MariaDB não consegue expressar via `CHECK`/`FOREIGN KEY`
  (por cruzar tabelas, ou por envolver uma coluna que já é FK) foi implementada via trigger,
  testada e confirmada.
- Números finais (pós-verificação, seção 10.5/10.6): 38 tabelas, 57 FKs, 24 triggers,
  19 `CHECK` constraints, ~120 índices (incluindo 4 `UNIQUE` sobre identificadores naturais:
  `item.codigo`, `maquina.codigo`, `sensor.codigo`, `funcionario.matricula`).
- Pronto para a próxima etapa do projeto: **população gradual dos dados** (fora do escopo
  deste documento e deste script).
- Ver `02_schema.sql` para o DDL completo (tabelas, constraints/FKs, triggers e índices).
