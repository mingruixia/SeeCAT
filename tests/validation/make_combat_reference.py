"""Reference outputs of neuroCombat for tests/unit/test_harmonize.m.

Run with neuroCombat 0.2.12 (pip install neuroCombat pandas; on numpy >= 1.24
replace np.int( by int( in neuroCombat.py):
    python make_combat_reference.py ../fixtures/combat
Writes Y.csv (60 maps x 30 features), covars.csv and H_<variant>.csv.
"""
import os
import sys
import numpy as np
import pandas as pd
from neuroCombat import neuroCombat

out = sys.argv[1]
rng = np.random.default_rng(1)
n, V = 60, 30
site = np.array(['A'] * 18 + ['B'] * 22 + ['C'] * 20)
group = rng.integers(0, 2, n)
age = rng.uniform(20, 70, n)
Y = rng.standard_normal((n, V)) + group[:, None] * 0.8 + age[:, None] * 0.02
shift = {'A': 0, 'B': 1.0, 'C': -0.7}
scale = {'A': 1, 'B': 1.6, 'C': 0.7}
for i in range(n):
    Y[i] = Y[i] * scale[site[i]] + shift[site[i]] + rng.standard_normal(V) * 0.1
np.savetxt(os.path.join(out, 'Y.csv'), Y, delimiter=',', fmt='%.10g')
pd.DataFrame({'site': site, 'group': group, 'age': age}).to_csv(os.path.join(out, 'covars.csv'), index=False)
cov = pd.DataFrame({'site': site, 'group': group.astype(str), 'age': age})
variants = {'param': {}, 'nonparam': {'parametric': False}, 'noeb': {'eb': False},
            'meanonly': {'mean_only': True}, 'ref': {'ref_batch': 'B'}}
for name, kw in variants.items():
    r = neuroCombat(dat=Y.T.copy(), covars=cov.copy(), batch_col='site',
                    categorical_cols=['group'], continuous_cols=['age'], **kw)
    np.savetxt(os.path.join(out, 'H_%s.csv' % name), r['data'].T, delimiter=',', fmt='%.10g')
