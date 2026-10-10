"""
Exporta as tabelas do DW para CSV (UTF-8, ponto decimal, cabecalho) -> plano B do Power BI e do pandas.
Uso: python exportar_csv.py --senha SUA_SENHA [--socket ...] [--saida dw_csv]
"""
import argparse, csv, os
import pymysql
ap = argparse.ArgumentParser()
ap.add_argument("--host", default="localhost"); ap.add_argument("--user", default="root")
ap.add_argument("--senha", default=""); ap.add_argument("--socket", default=None)
ap.add_argument("--banco", default="agromaq_dw"); ap.add_argument("--saida", default="dw_csv")
a = ap.parse_args()
TABELAS = ["dim_tempo", "dim_sensor", "dim_maquina", "dim_linha", "dim_produto",
           "fato_leitura_sensor", "fato_producao"]
os.makedirs(a.saida, exist_ok=True)
db = pymysql.connect(host=a.host, user=a.user, password=a.senha, database=a.banco, unix_socket=a.socket)
cur = db.cursor()
for t in TABELAS:
    cur.execute(f"SELECT * FROM {t}")
    cols = [c[0] for c in cur.description]
    with open(os.path.join(a.saida, f"{t}.csv"), "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f, lineterminator="\n")
        w.writerow(cols)
        for row in cur:
            w.writerow(["" if v is None else v for v in row])
    print(t, "ok")
db.close()
