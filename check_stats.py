# -*- coding: utf-8 -*-
import pandas as pd

df = pd.read_stata('regression/product_price_stats.dta')
print(f'共 {len(df)} 个产品')
print(f'列名: {list(df.columns)}')
print()
print('Top 30 产品（按观测数排序）:')
print(f'{"product_id":12s} {"产品名称":22s} {"obs":>5s} {"firms":>5s} {"cities":>6s} {"mean_p":>12s} {"cv_p":>7s} {"mean_lnp":>9s} {"std_lnp":>8s}')
print('-'*100)
for _, r in df.head(30).iterrows():
    pname = str(r['货物和劳务名称'])[:20]
    print(f'{r["product_id"]:12s} {pname:22s} {int(r["n_obs"]):>5d} {int(r["n_firms"]):>5d} {int(r["n_cities"]):>6d} {r["mean_price"]:>12.2f} {r["cv_price"]:>7.3f} {r["mean_lnp"]:>9.3f} {r["std_lnp"]:>8.3f}')

print()
print('统计概览:')
print(f'  cv_price 中位数: {df["cv_price"].median():.3f}')
print(f'  cv_price 均值:   {df["cv_price"].mean():.3f}')
print(f'  std_lnp  中位数: {df["std_lnp"].median():.3f}')
print(f'  std_lnp  均值:   {df["std_lnp"].mean():.3f}')
print(f'  n_obs    均值:   {df["n_obs"].mean():.1f}')
print(f'  n_obs    中位数: {df["n_obs"].median():.1f}')
print(f'  n_firms  均值:   {df["n_firms"].mean():.1f}')
