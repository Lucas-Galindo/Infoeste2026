import pandas as pd, numpy as np
print(pd.__version__)
df = pd.read_csv("leituras_lab.csv", dtype=str)           # tudo texto, como na staging
print(df.shape)
df.info()
print(df.isna().sum())
print("duplicadas exatas (texto):", df.duplicated(subset=["sensor_id","data_hora","valor"]).sum())
print("sentinela:", (df["valor"] == "-999").sum())
print("virgula:", df["valor"].str.contains(",", na=False).sum())
print("datas fora do padrao:", (~df["data_hora"].str.match(r"^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$")).sum())
print(df["tipo_maquina"].value_counts().sort_index())
sensores_validos = {1,16,83,104,168,244}
print("orfaos (contra os 6 sensores do lab):", (~df["sensor_id"].astype(int).isin(sensores_validos)).sum())

# tratamento
df["valor"] = df["valor"].str.replace(",", ".")
df["valor"] = pd.to_numeric(df["valor"])
df.loc[df["valor"] == -999, "valor"] = np.nan
iso = pd.to_datetime(df["data_hora"], format="%Y-%m-%d %H:%M:%S", errors="coerce")
br  = pd.to_datetime(df["data_hora"], format="%d/%m/%Y %H:%M", errors="coerce")
df["data_hora"] = iso.fillna(br)
df["tipo_maquina"] = df["tipo_maquina"].str.strip().str.capitalize()
df["sensor_id"] = df["sensor_id"].astype(int)
ok = df.dropna(subset=["valor"])
ok = ok[ok["sensor_id"].isin(sensores_validos)]
ok = ok.drop_duplicates(subset=["sensor_id","data_hora"], keep="first")
print("tratadas:", len(ok))
# estatistica
v16 = ok.loc[ok["sensor_id"]==16, "valor"]
print(v16.describe().round(2))
q1,q3 = v16.quantile([.25,.75]); iqr=q3-q1
print("IQR limites:", q1-1.5*iqr, q3+1.5*iqr, "outliers IQR:", ((v16<q1-1.5*iqr)|(v16>q3+1.5*iqr)).sum())
z=(v16-v16.mean())/v16.std()
print("|z|>3:", (z.abs()>3).sum(), "max valor", v16.max())
print(ok.groupby("sensor_id")["valor"].agg(["count","mean","std","median"]).round(2))
