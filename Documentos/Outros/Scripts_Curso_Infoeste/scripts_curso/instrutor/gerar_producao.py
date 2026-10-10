"""
Gerador das ordens de producao e perdas do banco operacional (agromaq_industrial).

As tabelas ordem_producao e perda chegam VAZIAS do 03_populacao_base.sql. O DW precisa delas
para a fato_producao (dashboard: total produzido, % de refugo, refugo por linha e por motivo).

Escreve:
    03b_populacao_producao.sql   -> rode no MySQL depois do 03_populacao_base.sql
    gabarito_producao.json       -> totais que o DW deve reproduzir

Historia plantada (para o aluno descobrir no dashboard):
    O refugo das linhas de SOLDAGEM sobe em marco, e o motivo dominante e "porosidade".

Uso:  python gerar_producao.py --senha SUA_SENHA [--socket ...]
Requer: pip install pymysql
"""
import argparse
import json
import random
from collections import defaultdict
from datetime import datetime, timedelta

import pymysql

ap = argparse.ArgumentParser()
ap.add_argument("--host", default="localhost")
ap.add_argument("--user", default="root")
ap.add_argument("--senha", default="")
ap.add_argument("--socket", default=None)
ap.add_argument("--banco", default="agromaq_industrial")
ap.add_argument("--semente", type=int, default=20261011)
ap.add_argument("--saida", default="03b_populacao_producao.sql")
ap.add_argument("--gabarito", default="gabarito_producao.json")
args = ap.parse_args()
random.seed(args.semente)

SEMANA_1 = datetime(2026, 1, 5)       # segunda-feira
N_SEMANAS = 12                         # ate 29/03/2026
ID_OP_INICIAL = 1001

db = pymysql.connect(host=args.host, user=args.user, password=args.senha, database=args.banco,
                     unix_socket=args.socket)
cur = db.cursor()
cur.execute("""SELECT l.id_linha, l.nome, s.nome, l.categoria_id, l.capacidade_produtiva
               FROM linha_producao l JOIN setor s ON s.id_setor = l.setor_id ORDER BY l.id_linha""")
LINHAS = cur.fetchall()
cur.execute("SELECT item_id, categoria_id FROM produto ORDER BY item_id")
PRODUTOS = defaultdict(list)
for item, cat in cur.fetchall():
    PRODUTOS[cat].append(item)
cur.execute("SELECT id_motivo, nome FROM motivo_nao_conformidade")
MOTIVOS = {nome: i for i, nome in cur.fetchall()}
cur.execute("SELECT id_tipo_perda FROM tipo_perda WHERE nome = 'Produto rejeitado'")
TIPO_PERDA = cur.fetchone()[0]
cur.execute("SELECT id_unidade_medida FROM unidade_medida WHERE sigla = 'un'")
UN = cur.fetchone()[0]
db.close()

MOTIVOS_SETOR = {   # motivos plausiveis por setor (nomes reais da tabela)
    "Corte": ["Falha dimensional", "Excesso de rebarba", "Dimensao fora de tolerancia"],
    "Usinagem": ["Falha dimensional", "Desalinhamento", "Dimensao fora de tolerancia", "Acabamento superficial inadequado"],
    "Soldagem": ["Problema de soldagem - porosidade", "Problema de soldagem - trinca",
                 "Problema de soldagem - penetracao insuficiente"],
    "Pintura": ["Falha de pintura - bolha", "Falha de pintura - escorrimento", "Falha de pintura - cor incorreta", "Cor fora de padrao"],
    "Montagem": ["Defeito de montagem - folga excessiva", "Defeito de montagem - aperto insuficiente",
                 "Defeito de montagem - peca invertida", "Componente incorreto", "Falta de componente"],
    "Controle de Qualidade": ["Ruido excessivo", "Vibracao excessiva", "Vazamento hidraulico - vedacao",
                              "Falha eletrica - mau contato"],
    "Expedicao": ["Etiquetagem incorreta", "Embalagem danificada"],
}
PESOS_SOLDA = [0.62, 0.25, 0.13]          # porosidade domina


def taxa_refugo(setor, mes):
    if setor == "Soldagem":
        return {1: 0.021, 2: 0.023, 3: 0.068}[mes]
    return {"Pintura": 0.030, "Montagem": 0.022}.get(setor, 0.018)


ops, perdas = [], []
id_op = ID_OP_INICIAL
seq = 1
for sem in range(N_SEMANAS):
    for (id_linha, nome_linha, setor, cat, cap) in LINHAS:
        for _ in range(2):                       # 2 ordens por linha por semana
            fim = SEMANA_1 + timedelta(weeks=sem, days=random.randint(0, 6),
                                       hours=random.randint(6, 21), minutes=random.randint(0, 59))
            ini = fim - timedelta(days=random.randint(1, 3), hours=random.randint(0, 5))
            plan = max(10, int(round(float(cap) * random.uniform(1.5, 4.0))))
            prod = min(plan, int(round(plan * random.uniform(0.92, 1.0))))
            taxa = max(0.0, random.gauss(taxa_refugo(setor, fim.month), 0.006))
            rej = min(prod, int(round(prod * taxa)))
            ret = min(prod - rej, int(round(prod * random.uniform(0.01, 0.05))))
            apr = prod - rej - ret
            item = random.choice(PRODUTOS[cat])
            ops.append(dict(id=id_op, num=f"OP2026-{seq:05d}", item=item, linha=id_linha, setor=setor,
                            plan=plan, prod=prod, apr=apr, ret=ret, rej=rej,
                            ini=ini, fim=fim, mes=fim.month, nome_linha=nome_linha))
            if rej > 0:
                lista = MOTIVOS_SETOR[setor]
                if setor == "Soldagem":
                    m1 = random.choices(lista, weights=PESOS_SOLDA)[0]
                else:
                    m1 = random.choice(lista)
                q1 = rej if rej == 1 else max(1, int(round(rej * random.uniform(0.6, 1.0))))
                perdas.append((id_op, item, q1, fim.date(), MOTIVOS[m1], m1))
                if rej - q1 > 0:
                    m2 = random.choice([m for m in lista if m != m1])
                    perdas.append((id_op, item, rej - q1, fim.date(), MOTIVOS[m2], m2))
            id_op += 1
            seq += 1

# ------------------------------------------------------------------- SQL
L = ["-- =====================================================================",
     "-- 03b_populacao_producao.sql  (GERADO por gerar_producao.py, semente %d)" % args.semente,
     "-- Ordens de producao CONCLUIDAS e perdas por produto rejeitado, de 05/01 a 29/03/2026.",
     "-- Rode DEPOIS do 03_populacao_base.sql. Idempotente: apaga so as OPs 'OP2026-%' e suas perdas.",
     "-- =====================================================================",
     "USE agromaq_industrial;", "START TRANSACTION;",
     "DELETE FROM perda WHERE op_id IN (SELECT id_op FROM ordem_producao WHERE numero_op LIKE 'OP2026-%');",
     "DELETE FROM ordem_producao WHERE numero_op LIKE 'OP2026-%';", ""]
L.append("INSERT INTO ordem_producao (id_op, numero_op, item_id, linha_id, quantidade_planejada, quantidade_produzida,"
         " quantidade_aprovada, quantidade_retrabalho, quantidade_rejeitada, data_inicio_planejada, data_fim_planejada,"
         " data_inicio_real, data_fim_real, status) VALUES")
vals = []
for o in ops:
    vals.append("(%d,'%s',%d,%d,%d,%d,%d,%d,%d,'%s','%s','%s','%s','CONCLUIDA')" % (
        o["id"], o["num"], o["item"], o["linha"], o["plan"], o["prod"], o["apr"], o["ret"], o["rej"],
        o["ini"].date(), o["fim"].date(), o["ini"].strftime("%Y-%m-%d %H:%M:%S"), o["fim"].strftime("%Y-%m-%d %H:%M:%S")))
L.append(",\n".join(vals) + ";")
L.append("")
L.append("INSERT INTO perda (tipo_perda_id, op_id, item_id, quantidade, unidade_medida_id, data_ocorrencia, motivo_id) VALUES")
L.append(",\n".join("(%d,%d,%d,%d,%d,'%s',%d)" % (TIPO_PERDA, p[0], p[1], p[2], UN, p[3], p[4]) for p in perdas) + ";")
L += ["COMMIT;", "",
      "SELECT COUNT(*) AS ordens_de_producao FROM ordem_producao;",
      "SELECT COUNT(*) AS perdas FROM perda;"]
open(args.saida, "w", encoding="utf-8").write("\n".join(L) + "\n")

# ------------------------------------------------------------- gabarito
def tot(filtro):
    sel = [o for o in ops if filtro(o)]
    p = sum(o["prod"] for o in sel)
    r = sum(o["rej"] for o in sel)
    return {"ordens": len(sel), "produzido": p, "rejeitado": r,
            "pct_refugo": round(100 * r / p, 2) if p else None}

gab = {"semente": args.semente, "ordens": len(ops), "perdas": len(perdas),
       "total": tot(lambda o: True),
       "por_mes": {m: tot(lambda o, m=m: o["mes"] == m) for m in (1, 2, 3)},
       "soldagem_por_mes": {m: tot(lambda o, m=m: o["setor"] == "Soldagem" and o["mes"] == m) for m in (1, 2, 3)},
       "outros_setores_por_mes": {m: tot(lambda o, m=m: o["setor"] != "Soldagem" and o["mes"] == m) for m in (1, 2, 3)},
       "motivo_dominante_soldagem_marco": max(
           ((m, sum(p[2] for p in perdas if p[5] == m and any(o["id"] == p[0] and o["setor"] == "Soldagem"
                                                               and o["mes"] == 3 for o in ops)))
            for m in MOTIVOS_SETOR["Soldagem"]), key=lambda x: x[1])}
json.dump(gab, open(args.gabarito, "w"), indent=2, ensure_ascii=False)
print(json.dumps(gab, indent=2, ensure_ascii=False))
