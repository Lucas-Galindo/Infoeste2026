"""
Gerador do CSV sujo do laboratorio de estudo (Alem do Codigo - Infoeste 2026).

NAO e o CSV oficial da aula. E um conjunto pequeno, reprodutivel (semente fixa),
feito para o instrutor treinar antes de aplicar.

Uso:
    python gerar_leituras_lab.py            # escreve leituras_lab.csv e gabarito_lab.json

Os sensores sao reais (tabela sensor do agromaq_industrial, tipo 'Temperatura Motor').
"""
import csv
import json
import random
from datetime import datetime, timedelta

SEED = 20261010
random.seed(SEED)

SENSORES = {  # id_sensor: (categoria da maquina, temperatura-base em graus C)
    1:   ("Trator", 76.0),
    16:  ("Trator", 72.0),
    83:  ("Colhedora", 78.0),
    104: ("Colhedora", 87.0),   # esquenta mais a noite: gera leituras fora da faixa
    168: ("Plantadora", 70.0),
    244: ("Pulverizador", 74.0),
}
INICIO = datetime(2026, 2, 1, 0, 0)
FIM = datetime(2026, 3, 31, 23, 0)

# ------------------------------------------------------------------ grade limpa
grade = []
t = INICIO
while t <= FIM:
    for sid, (cat, base) in SENSORES.items():
        ciclo = 4.0 * __import__("math").sin((t.hour - 8) / 24 * 2 * 3.14159265)
        noite = 10.0 if (sid == 104 and (t.hour >= 22 or t.hour < 6)) else 0.0
        valor = base + ciclo + noite + random.gauss(0, 1.2)
        grade.append({"sensor_id": sid, "dt": t, "valor": round(valor, 1),
                      "status": "VALIDA", "tipo": cat})
    t += timedelta(hours=1)

# pico legitimo: sensor 16 aquece antes de uma parada (nao e erro!)
PICO = [(datetime(2026, 3, 12, 12), 98.4), (datetime(2026, 3, 12, 13), 105.2),
        (datetime(2026, 3, 12, 14), 112.7), (datetime(2026, 3, 12, 15), 121.3),
        (datetime(2026, 3, 12, 16), 118.9)]
protegidos = set()
for dt, v in PICO:
    for i, r in enumerate(grade):
        if r["sensor_id"] == 16 and r["dt"] == dt:
            r["valor"] = v
            protegidos.add(i)

# algumas leituras SUSPEITA legitimas (nao sao defeito de carga)
livres = [i for i in range(len(grade)) if i not in protegidos]
random.shuffle(livres)
suspeitas = livres[-40:]          # leituras SUSPEITA legitimas: nao recebem defeito de carga
livres = livres[:-40]
for i in suspeitas:
    grade[i]["status"] = "SUSPEITA"
usados = set()


def pegar(n):
    """Pega n indices ainda nao usados por outro defeito."""
    global livres
    out, resto = [], []
    for i in livres:
        if len(out) < n and i not in usados:
            out.append(i)
        else:
            resto.append(i)
    livres = resto
    usados.update(out)
    return out


N_NULO, N_SENT, N_FMT, N_VIRG, N_ORFAO, N_DUP, N_DUPBR = 60, 45, 70, 50, 30, 80, 20
i_nulo = pegar(N_NULO)
i_sent = pegar(N_SENT)
i_fmt = pegar(N_FMT)
i_virg = pegar(N_VIRG)
i_dup = pegar(N_DUP)      # copias exatas de linhas boas
i_dupbr = pegar(N_DUPBR)  # copias de linhas boas, mas com a data no formato BR

TIPOS_SUJOS = {"Trator": ["trator", "TRATOR", "Trator ", "Trator"],
               "Colhedora": ["colhedora", "COLHEDORA", "Colhedora ", "Colhedora"],
               "Plantadora": ["plantadora", "PLANTADORA", "Plantadora ", "Plantadora"],
               "Pulverizador": ["pulverizador", "PULVERIZADOR", "Pulverizador ", "Pulverizador"]}


def linha(r, dt_txt=None, valor_txt=None):
    return {
        "sensor_id": str(r["sensor_id"]),
        "data_hora": dt_txt or r["dt"].strftime("%Y-%m-%d %H:%M:%S"),
        "valor": valor_txt if valor_txt is not None else f'{r["valor"]:.1f}',
        "status_leitura": r["status"],
        "tipo_maquina": random.choice(TIPOS_SUJOS[r["tipo"]]),
    }


br = lambda d: d.strftime("%d/%m/%Y %H:%M")
nulos, sents, fmts, virgs = set(i_nulo), set(i_sent), set(i_fmt), set(i_virg)
linhas = []
for i, r in enumerate(grade):
    if i in nulos:
        linhas.append(linha(r, valor_txt=""))
    elif i in sents:
        linhas.append(linha(r, valor_txt="-999"))
    elif i in fmts:
        linhas.append(linha(r, dt_txt=br(r["dt"])))
    elif i in virgs:
        linhas.append(linha(r, valor_txt=f'{r["valor"]:.1f}'.replace(".", ",")))
    else:
        linhas.append(linha(r))

# extras inseridos DEPOIS da linha original (a original e a que deve sobreviver)
extras = []
for i in i_dup:
    extras.append((i, linha(grade[i])))
    # copia exata: mesma linha ja gerada (mesmo texto de tipo_maquina nao importa)
for i in i_dupbr:
    extras.append((i, linha(grade[i], dt_txt=br(grade[i]["dt"]))))
orfaos = []
for k in range(N_ORFAO):
    r = random.choice(grade)
    o = linha(r)
    o["sensor_id"] = random.choice(["9999", "9876"])
    orfaos.append(o)

# posicao: a copia cai em algum ponto depois da original
saida = list(linhas)
posicoes = []
for i, ex in extras:
    posicoes.append((min(len(saida), i + random.randint(1, 400)), ex))
for o in orfaos:
    posicoes.append((random.randint(0, len(saida)), o))
for pos, ex in sorted(posicoes, key=lambda p: -p[0]):
    saida.insert(pos, ex)

with open("leituras_lab.csv", "w", newline="", encoding="utf-8") as f:
    w = csv.DictWriter(f, fieldnames=["sensor_id", "data_hora", "valor", "status_leitura", "tipo_maquina"], lineterminator="\n")
    w.writeheader()
    w.writerows(saida)

total_grade = len(grade)
gab = {
    "semente": SEED,
    "linhas_no_arquivo": len(saida),
    "grade_limpa": total_grade,
    "defeitos": {"nulo": N_NULO, "sentinela": N_SENT, "orfao": N_ORFAO,
                 "duplicada_exata": N_DUP, "duplicada_data_br": N_DUPBR,
                 "data_formato_br": N_FMT, "valor_virgula": N_VIRG},
    "rejeitos_esperados": {"SENSOR_INEXISTENTE": N_ORFAO, "VALOR_NULO": N_NULO,
                           "VALOR_SENTINELA": N_SENT, "DUPLICADA": N_DUP + N_DUPBR},
    "linhas_tratadas_esperadas": total_grade - N_NULO - N_SENT,
    "pico_legitimo": {"sensor_id": 16, "leituras": [[d.strftime("%Y-%m-%d %H:%M:%S"), v] for d, v in PICO]},
}
json.dump(gab, open("gabarito_lab.json", "w"), indent=2, ensure_ascii=False)
print(json.dumps(gab, indent=2, ensure_ascii=False))
