"""
Gerador do CSV sujo OFICIAL da aula (Alem do Codigo - Infoeste 2026).

Le os 316 sensores reais do banco agromaq_industrial e gera uma grade de leituras
horarias (um valor por sensor por hora), planta defeitos em quantidades conhecidas
e escreve:
    leituras_sujas.csv   -> o arquivo que os alunos carregam na staging
    gabarito_leituras.json -> as contagens que o ETL e o DW devem reproduzir

Uso:
    python gerar_leituras.py --senha SUA_SENHA                 # recorte da aula (28 dias)
    python gerar_leituras.py --senha SUA_SENHA --completo      # volume completo (~2,15 mi linhas)
    python gerar_leituras.py --senha SUA_SENHA --dias 7        # recorte menor, para ensaio rapido

Mesma semente = mesmo arquivo. Requer: pip install pymysql
"""
import argparse
import csv
import json
import math
import random
from datetime import datetime, timedelta

import pymysql

# ---------------------------------------------------------------- parametros
ap = argparse.ArgumentParser()
ap.add_argument("--host", default="localhost")
ap.add_argument("--user", default="root")
ap.add_argument("--senha", default="")
ap.add_argument("--socket", default=None, help="opcional: caminho do socket (Linux/macOS)")
ap.add_argument("--banco", default="agromaq_industrial")
ap.add_argument("--inicio", default="2026-02-16", help="primeira data (AAAA-MM-DD)")
ap.add_argument("--dias", type=int, default=28, help="quantos dias de leituras")
ap.add_argument("--completo", action="store_true", help="283 dias (~2,15 mi de leituras)")
ap.add_argument("--semente", type=int, default=20261010)
ap.add_argument("--saida", default="leituras_sujas.csv")
ap.add_argument("--gabarito", default="gabarito_leituras.json")
args = ap.parse_args()
if args.completo:
    args.dias = 283

random.seed(args.semente)
INICIO = datetime.strptime(args.inicio, "%Y-%m-%d")
HORAS = args.dias * 24

# --------------------------------------------- tipos de sensor: (base, amplitude diaria,
# ruido, faixa_min, faixa_max, casas). A faixa e a MESMA de cfg_faixa_sensor no DW.
TIPOS = {
    "Temperatura Motor":         (78.0, 4.0, 1.2, 50, 95, 1),
    "Temperatura Forno Pintura": (180.0, 3.0, 2.0, 160, 200, 1),
    "Vibracao Geral":            (2.5, 0.3, 0.3, 0, 7.1, 1),
    "Pressao Hidraulica":        (180.0, 6.0, 5.0, 150, 220, 1),
    "Velocidade Angular":        (1500.0, 40.0, 20.0, 1200, 1800, 1),
    "Velocidade de Corte":       (120.0, 5.0, 4.0, 90, 150, 1),
    "Consumo Energetico":        (35.0, 8.0, 2.0, 10, 60, 1),
    "Corrente Eletrica":         (45.0, 4.0, 2.0, 20, 70, 1),
    "Umidade Tinta":             (55.0, 3.0, 2.0, 40, 70, 1),
    "Posicao Linear":            (250.0, 60.0, 30.0, 0, 500, 1),
    "Torque":                    (320.0, 15.0, 10.0, 250, 400, 1),
    "Tempo de Ciclo":            (42.0, 2.0, 1.5, 30, 60, 1),
    "Quantidade Produzida":      (5.0, 2.0, 1.2, 0, 12, 0),
    "Status Operacional":        (None, None, None, 0, 1, 0),
    "Espessura de Tinta":        (80.0, 2.0, 3.0, 60, 110, 1),
}
SENSOR_NOITE_QUENTE = 104   # Robo de Solda TIG (Colhedora): +10 C entre 22h e 6h
SENSOR_PICO = 16            # Furadeira CNC (Trator): pico legitimo antes de uma parada
PICO = [(datetime(2026, 3, 12, 12), 98.4), (datetime(2026, 3, 12, 13), 105.2),
        (datetime(2026, 3, 12, 14), 112.7), (datetime(2026, 3, 12, 15), 121.3),
        (datetime(2026, 3, 12, 16), 118.9)]

# taxas de defeito sobre a grade limpa
TAXAS = {"nulo": 0.0070, "sentinela": 0.0050, "data_br": 0.0080, "virgula": 0.0060,
         "dup_exata": 0.0090, "dup_data_br": 0.0025, "orfao": 0.0035, "suspeita": 0.0045}

# ------------------------------------------------------------------ sensores
db = pymysql.connect(host=args.host, user=args.user, password=args.senha, database=args.banco,
                     unix_socket=args.socket)
cur = db.cursor()
cur.execute("""
    SELECT s.id_sensor, ts.nome, cp.nome
    FROM sensor s
    JOIN tipo_sensor ts       ON ts.id_tipo_sensor = s.tipo_sensor_id
    JOIN maquina m            ON m.id_maquina = s.maquina_id
    JOIN linha_producao l     ON l.id_linha = m.linha_id
    JOIN categoria_produto cp ON cp.id_categoria = l.categoria_id
    ORDER BY s.id_sensor""")
SENSORES = cur.fetchall()
db.close()
assert len(SENSORES) == 316, "esperava 316 sensores; confira o banco"
faltam = {t for _, t, _ in SENSORES} - set(TIPOS)
assert not faltam, f"tipos de sensor sem parametros: {faltam}"

# ---------------------------------------------------------------- grade limpa
grade = []   # [sensor_id, datetime, valor, status, categoria, tipo]
t = INICIO
for h in range(HORAS):
    ciclo_h = math.sin((t.hour - 8) / 24 * 2 * math.pi)
    for sid, tipo, cat in SENSORES:
        base, amp, ruido, fmin, fmax, casas = TIPOS[tipo]
        if tipo == "Status Operacional":
            v = 1.0 if random.random() < 0.92 else 0.0
        else:
            b = 87.0 if sid == SENSOR_NOITE_QUENTE else base
            noite = 10.0 if (sid == SENSOR_NOITE_QUENTE and (t.hour >= 22 or t.hour < 6)) else 0.0
            v = b + amp * ciclo_h + noite + random.gauss(0, ruido)
            v = max(v, 0.0)
            v = round(v, casas)
        grade.append([sid, t, v, "VALIDA", cat, tipo])
    t += timedelta(hours=1)
N = len(grade)

protegidos = set()
pico_gravado = []
for dt, v in PICO:
    for i, r in enumerate(grade):
        if r[0] == SENSOR_PICO and r[1] == dt:
            r[2] = v
            protegidos.add(i)
            pico_gravado.append([dt.strftime("%Y-%m-%d %H:%M:%S"), v])

indices = [i for i in range(N) if i not in protegidos]
random.shuffle(indices)
n = {k: int(round(N * p)) for k, p in TAXAS.items()}
cursor = 0


def pegar(k):
    global cursor
    out = indices[cursor:cursor + k]
    cursor += k
    return out


i_susp = pegar(n["suspeita"])
i_nulo = pegar(n["nulo"])
i_sent = pegar(n["sentinela"])
i_fmt = pegar(n["data_br"])
i_virg = pegar(n["virgula"])
i_dup = pegar(n["dup_exata"])
i_dupbr = pegar(n["dup_data_br"])
for i in i_susp:
    grade[i][3] = "SUSPEITA"

VARIANTES = {c: [c.lower(), c.upper(), c + " ", c] for c in ("Trator", "Colhedora", "Plantadora", "Pulverizador")}


def fmt_valor(r):
    casas = TIPOS[r[5]][5]
    return f"{r[2]:.{max(casas, 1)}f}" if casas else f"{r[2]:.1f}"


def linha(r, dt_txt=None, valor_txt=None, sensor_txt=None):
    return {
        "sensor_id": sensor_txt or str(r[0]),
        "data_hora": dt_txt or r[1].strftime("%Y-%m-%d %H:%M:%S"),
        "valor": valor_txt if valor_txt is not None else fmt_valor(r),
        "status_leitura": r[3],
        "tipo_maquina": random.choice(VARIANTES[r[4]]),
    }


br = lambda d: d.strftime("%d/%m/%Y %H:%M")
S_nulo, S_sent, S_fmt, S_virg = set(i_nulo), set(i_sent), set(i_fmt), set(i_virg)
linhas = []
for i, r in enumerate(grade):
    if i in S_nulo:
        linhas.append(linha(r, valor_txt=""))
    elif i in S_sent:
        linhas.append(linha(r, valor_txt="-999"))
    elif i in S_fmt:
        linhas.append(linha(r, dt_txt=br(r[1])))
    elif i in S_virg:
        linhas.append(linha(r, valor_txt=fmt_valor(r).replace(".", ",")))
    else:
        linhas.append(linha(r))

extras = [(i, linha(grade[i])) for i in i_dup] + \
         [(i, linha(grade[i], dt_txt=br(grade[i][1]))) for i in i_dupbr]
orfaos = []
for _ in range(n["orfao"]):
    r = random.choice(grade)
    orfaos.append(linha(r, sensor_txt=random.choice(["9999", "9876"])))

posicoes = [(min(len(linhas), i + random.randint(1, 400)), ex) for i, ex in extras]
posicoes += [(random.randint(0, len(linhas)), o) for o in orfaos]
saida = list(linhas)
for pos, ex in sorted(posicoes, key=lambda p: -p[0]):
    saida.insert(pos, ex)

with open(args.saida, "w", newline="", encoding="utf-8") as f:
    w = csv.DictWriter(f, fieldnames=["sensor_id", "data_hora", "valor", "status_leitura", "tipo_maquina"],
                       lineterminator="\n")
    w.writeheader()
    w.writerows(saida)

# --------------------------------------------------------------- gabarito
com_defeito = S_nulo | S_sent
fora = 0
por_cat = {}
for i, r in enumerate(grade):
    if i in com_defeito:
        continue
    fmin, fmax = TIPOS[r[5]][3], TIPOS[r[5]][4]
    if r[5] == "Status Operacional":
        continue
    if r[2] < fmin or r[2] > fmax:
        fora += 1
        por_cat[r[4]] = por_cat.get(r[4], 0) + 1
gab = {
    "semente": args.semente,
    "inicio": args.inicio, "dias": args.dias, "sensores": len(SENSORES),
    "linhas_no_arquivo": len(saida),
    "grade_limpa": N,
    "defeitos_plantados": {
        "valor_nulo": n["nulo"], "sentinela_-999": n["sentinela"], "sensor_orfao": n["orfao"],
        "duplicada_exata": n["dup_exata"], "duplicada_data_br": n["dup_data_br"],
        "data_formato_br": n["data_br"], "valor_virgula": n["virgula"],
        "suspeita_legitima": n["suspeita"]},
    "datas_fora_do_padrao_ISO": n["data_br"] + n["dup_data_br"],
    "rejeitos_esperados": {"SENSOR_INEXISTENTE": n["orfao"], "VALOR_NULO": n["nulo"],
                           "VALOR_SENTINELA": n["sentinela"],
                           "DUPLICADA": n["dup_exata"] + n["dup_data_br"]},
    "linhas_tratadas_esperadas": N - n["nulo"] - n["sentinela"],
    "fora_da_faixa_esperado_na_fato": fora,
    "fora_da_faixa_por_categoria": por_cat,
    "pico_legitimo": {"sensor_id": SENSOR_PICO, "leituras": pico_gravado},
    "sensor_noite_quente": SENSOR_NOITE_QUENTE,
}
json.dump(gab, open(args.gabarito, "w"), indent=2, ensure_ascii=False)
print(json.dumps(gab, indent=2, ensure_ascii=False))
