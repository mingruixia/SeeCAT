"""Reference values of MRIQC's IQM formulas for tests/unit/test_iqm.m.

Run with mriqc 24.0.2 (pip install mriqc) from this folder:
    python make_iqm_reference.py ../fixtures/iqm
Writes small synthetic volumes (.csv, column-major like MATLAB) and the
values MRIQC's own functions give for them (iqm_*.json). The masks and
inputs are given to both implementations, so this checks the formulas;
mask construction is SeeCAT's own.
"""
import json
import os
import sys

import numpy as np
from mriqc.qc import anatomical as A
from mriqc.qc.functional import gsr
from nipype.algorithms.confounds import compute_dvars
import nibabel as nb

out = sys.argv[1]
os.makedirs(out, exist_ok=True)
rng = np.random.default_rng(3)


def save(name, arr):
    np.savetxt(os.path.join(out, name + '.csv'), arr.reshape(-1, order='F'), fmt='%.9g')


# ---- anatomical: a 24^3 head with three tissues and noisy air
sh = (24, 24, 24)
x, y, z = np.meshgrid(*[np.arange(n) - 11.5 for n in sh], indexing='ij')
r = np.sqrt(x ** 2 + y ** 2 + (z * 1.1) ** 2)
wm = np.clip(1 - np.maximum(r - 4, 0) / 2, 0, 1) * (r < 6)       # solid core, 1 inside r < 4
gm = np.clip(1 - np.abs(r - 7) / 2.5, 0, 1) * (r >= 4)
csf = np.clip(1 - np.abs(r - 9.5) / 1.5, 0, 1) * (r >= 8)
tot = wm + gm + csf
s = np.maximum(tot, 1)
wm, gm, csf = wm / s, gm / s, csf / s
head = r < 10.5
inu = 1 + 0.15 * x / 12
t1 = (wm * 900 + gm * 600 + csf * 250) + rng.normal(0, 30, sh)
t1[~head] = np.abs(rng.normal(0, 12, (~head).sum()))
t1 = np.clip(t1, 0, None)
rot = np.zeros(sh, bool)
rot[:, :, :2] = True                       # e.g. zeroed slices
t1[rot] = 0
air = (~head) & (~rot) & (r > 11.5)
for k, v in dict(t1=t1, inu=inu, csf=csf, gm=gm, wm=wm, head=head, air=air, rot=rot).items():
    save(k, np.asarray(v, float))

# MRIQC's Harmonize: WM median (p >= 0.9, eroded) to 1000
import scipy.ndimage as nd
wmm = (wm >= 0.9).astype(np.uint8)
wmm = nd.binary_erosion(wmm, structure=nd.generate_binary_structure(3, 2)).astype(np.uint8)
data = t1 * 1000.0 / np.median(t1[wmm > 0])
pvms = {'csf': csf.copy(), 'gm': gm.copy(), 'wm': wm.copy(), 'bg': air.astype(np.uint8)}
st = A.summary_stats(data, pvms)
res = {}
snrs = []
for t in ('csf', 'wm', 'gm'):
    res['snr_' + t] = A.snr(st[t]['median'], st[t]['stdv'], st[t]['n'])
    snrs.append(res['snr_' + t])
res['snr_total'] = float(np.mean(snrs))
for t in ('csf', 'wm', 'gm'):
    res['snrd_' + t] = A.snr_dietrich(st[t]['median'], mad_air=st['bg']['mad'], sigma_air=st['bg']['stdv'])
res['cnr'] = A.cnr(st['wm']['median'], st['gm']['median'], st['bg']['stdv'], st['wm']['stdv'], st['gm']['stdv'])
res['cjv'] = A.cjv(st['wm']['median'], st['gm']['median'], st['wm']['mad'], st['gm']['mad'])
res['fber'] = A.fber(data, head.astype(np.uint8), rot.astype(np.uint8))
res['efc'] = A.efc(data, rot.astype(np.uint8))
res['wm2max'] = A.wm2max(data, st['wm']['median'])
seg = (csf + gm + wm) > 0.5
b = inu[seg]
res['inu_med'] = float(np.median(b))
res['inu_range'] = float(abs(np.percentile(b, 95) - np.percentile(b, 5)))
vf = A.volume_fraction([csf.copy(), gm.copy(), wm.copy()])
for t in ('csf', 'gm', 'wm'):
    res['icvs_' + t] = vf[t]
rp = A.rpve([csf.copy(), gm.copy(), wm.copy()], None)
for t in ('csf', 'gm', 'wm'):
    res['rpve_' + t] = rp[t]
for t in ('csf', 'gm', 'wm', 'bg'):
    for k2, v2 in st[t].items():
        res['summary_%s_%s' % (t, k2)] = v2
json.dump(res, open(os.path.join(out, 'iqm_anat.json'), 'w'), indent=1)

# ---- functional: 14x14x8 x 40, brain ellipsoid, ghost, drift and AR(1) noise
sh = (14, 14, 8)
x, y, z = np.meshgrid(*[np.arange(n) - (n - 1) / 2 for n in sh], indexing='ij')
mask = (x / 5) ** 2 + (y / 5) ** 2 + (z / 3) ** 2 < 1
nt = 40
base = 800 + 200 * mask
Y = np.zeros(sh + (nt,))
e = rng.normal(0, 1, sh + (nt,))
for t in range(1, nt):
    e[..., t] = 0.4 * e[..., t - 1] + e[..., t]
for t in range(nt):
    Y[..., t] = base * mask + 30 * e[..., t] + 5 * t / nt
Y[~mask] = np.abs(Y[~mask]) * 0.05
Y += 20 * np.roll(mask, 7, axis=1)[..., None]          # a ghost along y
Y = np.clip(Y, 0, None)
save('bold', Y)
save('bold_mask', mask.astype(float))
fd = np.abs(rng.normal(0.15, 0.1, nt - 1))
np.savetxt(os.path.join(out, 'fd.csv'), fd, fmt='%.9g')
epi = Y.mean(axis=3)
rois = {'fg': mask.astype(np.uint8), 'bg': (~mask).astype(np.uint8)}
st = A.summary_stats(epi, rois)
res = {'snr': A.snr(st['fg']['median'], st['fg']['stdv'], st['fg']['n']),
       'fber': A.fber(epi, mask.astype(np.uint8)), 'efc': A.efc(epi),
       'gsr_x': gsr(epi, mask.astype(np.uint8), 'x'), 'gsr_y': gsr(epi, mask.astype(np.uint8), 'y')}
aff = np.eye(4)
nb.Nifti1Image(Y.astype(np.float32), aff).to_filename(os.path.join(out, '_bold.nii'))
nb.Nifti1Image(mask.astype(np.uint8), aff).to_filename(os.path.join(out, '_mask.nii'))
dv = compute_dvars(os.path.join(out, '_bold.nii'), os.path.join(out, '_mask.nii'), remove_zerovariance=True)
os.remove(os.path.join(out, '_bold.nii'))
os.remove(os.path.join(out, '_mask.nii'))
res['dvars_std'], res['dvars_nstd'], res['dvars_vstd'] = [float(np.mean(d)) for d in dv]
sd = Y.std(axis=3)
tsnr = np.zeros_like(sd)
ok = sd > 1e-3
tsnr[ok] = Y.mean(axis=3)[ok] / sd[ok]
res['tsnr'] = float(np.median(tsnr[mask]))
num = int((fd > 0.2).sum())
res.update(fd_mean=float(fd.mean()), fd_num=num, fd_perc=float(num * 100 / (len(fd) + 1)))
for t in ('fg', 'bg'):
    for k2, v2 in st[t].items():
        res['summary_%s_%s' % (t, k2)] = v2
json.dump(res, open(os.path.join(out, 'iqm_bold.json'), 'w'), indent=1)
print('ok')
