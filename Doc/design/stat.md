# SeeCAT 2.0 — group statistics (`stat` pipeline)

Status: **accepted** (2026-10-31; S1–S5 and S8 as recommended, S6 and S7 as chosen). Roadmap weeks 5–6. Replaces the
1.0 Stat module and the GRF/FDR/AlphaSim tools of the 1.0 viewer, with no
DPABI-derived code.

## 1. Goals

- Voxel-wise group statistics on per-subject maps from the SeeCAT
  derivatives (seed FC, degree, …) or any NIfTI list: the 1.0 designs, plus
  a custom design for everything else.
- Correct, reproducible inference: random field theory (voxel and cluster
  level) and FDR, with numbers that match SPM on the same data.
- Batch first (`seecat.run`), same config/log/summary machinery as the other
  pipelines; the GUI and viewer (weeks 7–8) read the outputs.
- Every result self-describing: design, contrasts, df, smoothness, resels and
  thresholds in JSON sidecars, not in the 80-character header.

Not in 2.0: non-parametric permutation inference (v2.x), mixed models,
surface data.

## 2. What a user writes

```matlab
cfg = seecat.config('stat');
cfg.name      = 'PCCzFC_SCHZvsCTL';                   % output folder group/<name>/
cfg.input_dir = 'D:/study/derivatives/seecat';
cfg.maps      = struct('desc', 'PCC', 'stat', 'z', 'suffix', 'connectivity');
cfg.design    = 'two_sample';
cfg.factor    = 'diagnosis';                          % participants.tsv column
cfg.levels    = {'CONTROL', 'SCHZ'};
cfg.covariates = {'age', 'gender'};                   % participants.tsv columns
seecat.run(cfg);
```

Other designs change three lines:

| `design` | needs | model (+ covariates) | default contrasts |
|---|---|---|---|
| `one_sample` | — | mean | `mean>0`, `mean<0` |
| `two_sample` | `factor`, 2 `levels` | 2 group means | `A>B`, `B>A` |
| `paired` | `factor` = `session` (or a column), 2 `levels` | condition + one dummy per subject | `A>B`, `B>A` |
| `anova1` | `factor`, ≥ 3 `levels` | one mean per level | F: all equal |
| `anova1_rm` | `factor` = `session`/condition, ≥ 3 levels | condition + subject dummies | F: all equal |
| `regression` | `regressors` (one or more columns) | all regressors + mean, one model (S8) | `<reg>pos`, `<reg>neg` per regressor |
| `custom` | `design_tsv` (one row per map) | the given columns | as given |

- `contrasts` can always be given instead of the defaults:
  `struct('name', {'AgtB'}, 'type', {'t'}, 'weights', {[1 -1 0 0]})`
  (weights over the design columns, listed in `design.tsv`; F contrasts are
  matrices).
- `image_covariates`: a map selector like `maps` (e.g. each subject's GM
  probability); fitted voxel by voxel, as in 1.0.
- Without BIDS derivatives: `cfg.files` (list of images) plus `cfg.design_tsv`.

## 3. Inputs

- Maps are found in `input_dir` by entity selector (`maps`) with
  `seecat.bids.query`; one map per subject (per subject and level for
  `paired`/`anova1_rm`, where the level is the `ses` entity or a column).
- Subject information comes from `participants.tsv` of the raw dataset
  (found from the derivatives' `dataset_description.json`, or
  `cfg.participants`). Subjects without a map, or with `n/a` in a used
  column, are dropped and listed in the log and the report.
- All maps must share one grid (checked; no silent resampling).
- Covariates: numeric columns are mean-centred; text columns are coded as
  centred dummy variables (k − 1 columns for k values). Centring makes the
  group-mean contrasts mean "at the average covariate value", as in SPM's
  default.

## 4. Mask

A voxel enters the analysis when (1) it is in `cfg.mask` — `gm` (default; the
TPM GM mask of the data's resolution, D11), `brain` (no anatomical
restriction), or a file — and (2) **every** map has a finite, non-zero value
there.

Change from 1.0, which used voxels non-zero in **any** subject: voxels
missing in some subjects were then fitted with zeros, biasing the edges of
the field of view. (2) is what SPM does with its implicit mask.

## 5. Estimation

- Ordinary least squares by QR decomposition of the design (`[Q, R] =
  qr(X, 0)`), all voxels at once: β = R \ (Qᵀ Y). Rank-deficient designs are
  allowed (pseudo-inverse); contrasts must be estimable, otherwise an error
  names the contrast.
- T: c β / sqrt(σ² c (XᵀX)⁻ cᵀ), df = n − rank(X). F: the extra sum of
  squares for the contrast's null space, df = [rank(c), n − rank(X)].
- With image covariates the design differs per voxel; voxels are solved in
  chunks with the same formulas (n is small; ~50k voxels take seconds).
- **Non-sphericity (S6).** `anova1_rm` (and, on request, `paired`,
  `two_sample`, `anova1` via `variance = 'unequal'`) estimates the error
  covariance as SPM does: covariance components for unequal variance per
  level and, for repeated measures, correlation between levels; the
  hyperparameters are estimated by ReML (`spm_reml`) on the covariance of
  voxels pooled over the mask that pass an omnibus F at p < 0.001 (SPM's
  `spm_spm` first pass), scaled to a correlation matrix; data and design are
  whitened with it; df use the Satterthwaite approximation (`trRV`,
  `trRVRV`), so they can be fractional. Default `variance`: `unequal` for
  `anova1_rm`, `equal` otherwise (classic t-tests and 1.0 numbers). When too
  few voxels pass the first pass, the model falls back to sphericity and the
  log and JSON say so.
- Collinearity: the variance inflation factor of every non-constant column is
  reported in the JSON; VIF > 5 is a warning in the log.
- Written: effect map (contrast estimate) per T contrast, T or F map, the
  equivalent **Z map** (same p), and −log10(p). Residuals are kept in the
  work folder for the smoothness estimate and deleted afterwards unless
  `keep_work`.

## 6. Smoothness and resels

- FWHM from the standardized residuals (Kiebel et al. 1999; Worsley 1996),
  the estimator of `spm_est_smoothness`, written in SeeCAT so that nothing is
  written to the current folder (SPM's function writes `RPV.nii` there).
  Must equal SPM's to numerical precision (test).
- Resels of the search volume with `spm_resels_vol` (mask + FWHM); FWHM,
  resels and resels-per-voxel go in the JSON.

## 7. Inference

`cfg.inference` (one or several):

| method | meaning | default parameters |
|---|---|---|
| `cluster_fwe` (default) | clusters of voxels above a cluster-forming threshold; cluster p by RFT (`spm_P_RF`, Friston 1994 / Hayasaka 2004 for T and F fields) | `cdt_p = 0.001`, `alpha = 0.05` |
| `voxel_fwe` | voxel p by RFT (EC densities of the T/F field, `spm_uc_RF`) | `alpha = 0.05` |
| `voxel_fdr` | Benjamini–Hochberg over the mask's voxels | `q = 0.05` |
| `none` | maps only | |

- T contrasts are one-sided, as in SPM; the default contrast pairs (`A>B`,
  `B>A`) cover both directions. `two_tailed = true` (default) splits `alpha`
  over the pair (each tested at alpha / 2), so the familywise rate for the
  two-sided question stays at `alpha`. F contrasts are not split.
- Clusters use 18-connectivity (SPM). See S3.
- Cluster-forming p 0.001 by default: lenient thresholds (p 0.01, 0.05) give
  inflated false-positive rates with RFT (Eklund et al. 2016). Values above
  0.001 are allowed with a warning in the log and the JSON.
- AlphaSim is not offered (same reason; it also had an implementation error
  in AFNI before 2015).
- Outputs per contrast and method: thresholded map (`desc-<contrast>
  <Method>_stat-t_statmap`), cluster mask (`_desc-…_dseg`, cluster index),
  and a cluster table TSV (size, cluster p, peak T/Z/p, peak MNI, up to 3
  local maxima 8 mm apart — SPM's results table).

## 8. Output layout

```
derivatives/seecat/group/<name>/
  <name>_design.tsv                       design matrix, one row per map (with the map path)
  <name>_desc-mask_mask.nii.gz             analysis mask
  <name>_contrast-<c>_stat-effect_statmap.nii.gz
  <name>_contrast-<c>_stat-t_statmap.nii.gz      (stat-F for F contrasts) + .json
  <name>_contrast-<c>_stat-z_statmap.nii.gz
  <name>_contrast-<c>_stat-p_statmap.nii.gz      −log10 p
  <name>_contrast-<c>_desc-clusterFWE_stat-t_statmap.nii.gz   thresholded
  <name>_contrast-<c>_desc-clusterFWE_dseg.nii.gz             cluster index
  <name>_contrast-<c>_desc-clusterFWE_clusters.tsv
  <name>_report.json                      n, dropped subjects, df, FWHM, resels, thresholds
```

JSON of a stat map: `Statistic`, `DegreesOfFreedom`, `Contrast` (name,
weights), `DesignColumns`, `FWHMmm`, `Resels`, `ReselsPerVoxel`,
`NonSphericity`, `VIF`, `Software`, `Sources`.

T and F maps also carry the 1.0 header string (S7), so 1.0 tools and DPABI
read them: `CAT{T_[df]}{dLh_<dLh>}{FWHMx_<x>FWHMy_<y>FWHMz_<z>mm}` (F:
`CAT{F_[df1,df2]}…`), with dLh = (4 ln 2)^(3/2) / (FWHMx FWHMy FWHMz in
voxels), as 1.0 wrote it; fractional df keep one decimal. The JSON stays the
primary source; the viewer reads it first.

## 9. Code layout

```
+seecat/+stat/   defaults.m  plan.m  run_unit.m        pipeline (one unit)
                 design.m        design matrix + default contrasts from cfg
                 glm.m           QR fit, T/F/Z/p, voxel-wise covariates
                 smoothness.m    FWHM from residuals (= spm_est_smoothness)
                 rft.m           resels, voxel/cluster p via spm_P_RF/spm_uc_RF
                 fdr.m           BH
                 clusters.m      labelling, peaks, table
```

Group pipelines plan one unit; heavy parts are vectorised (batch-api §7).

## 10. Validation

| check | reference | pass |
|---|---|---|
| β, T, F maps for each design (no image covariates) | SPM `spm_spm` + `spm_contrasts` on the same images, design and mask | max rel. difference < 1e-6 — **passed 2026-10-31** for every design (`tests/validation/compare_stat_spm.m`, `compare_designs_spm.m`, `compare_reml_spm.m`) |
| non-sphericity (`anova1_rm`, unequal variance) | SPM flexible/full factorial with the same independence and variance settings: hyperparameters, whitened df, F map | rel. difference < 1e-6 |
| 1.0 header string | parse back; dLh and FWHM equal to the JSON | exact |
| FWHM, resels | `spm_est_smoothness`, `spm_resels_vol` | equal to 1e-8 |
| voxel FWE threshold, cluster p, cluster table | SPM results (`spm_uc`, `spm_list`) at the same CDT | equal (same clusters, sizes, p to 1e-6) |
| FDR | own BH vs `spm_uc_FDR` (voxel FDR) | equal threshold |
| image covariates | per-voxel `regress` loop on a sample of voxels | 1e-10 |
| 1.0 maps | `T2_zFCSeed01_CONvsSCHZ` from the 1.0 baseline | T equal where both masks include the voxel |
| cross-check | DPABI V9 (if installed): same T map, smoothness | reported, not a gate |

Test data: ds000030 zFC (PCC), CONTROL 5 vs SCHZ 4 (sub-50052 has no
derivative), age and gender covariates; ds002785 one-sample on 5 subjects;
synthetic data with known effects for the unit tests.

## 11. Decisions (accepted 2026-10-31)

| # | question | recommendation | alternative |
|---|---|---|---|
| S1 | RFT engine | SPM's pure functions (`spm_resels_vol`, `spm_P_RF`, `spm_uc_RF`) for resels and p; own GLM, smoothness, FDR, clusters. SPM is already required; its RFT code is the reference everyone compares to | write RFT p-values ourselves too (more code to validate, same numbers) |
| S2 | default inference | `cluster_fwe`, CDT p 0.001, alpha 0.05, two-tailed split over the contrast pair | voxel FWE as default (more conservative); or no default thresholding |
| S3 | cluster connectivity | 18 (SPM; makes the SPM check exact) | 26 (1.0 and FSL) |
| S4 | mask rule | in `mask` and non-zero in **every** map (SPM) | 1.0 rule (any map) |
| S5 | covariate coding | numeric centred, text → centred dummies | uncentred (1.0) |
| S6 | repeated measures | **decided:** SPM-style ReML non-sphericity (section 5) | — |
| S7 | outputs | **decided:** t/F + Z + −log10 p + effect; JSON metadata **and** the 1.0 header string (section 8) | — |
| S8 | `regression` with several regressors | **decided:** one model with all regressors (partial effects, one family of tests; standard in SPM/FSL); VIF reported. A marginal test = an analysis with that regressor alone | one model per regressor (1.0): confounded effects when regressors correlate, and the extra models are not corrected for |

## 12. Differences users will see from 1.0

- Mask: all subjects, not any (S4); the default GM mask is smaller (D11).
- Covariates centred (S5): group-mean contrasts change meaning slightly
  (adjusted means); group differences are unchanged.
- `regression` with several regressors: one model (partial effects), not one
  model per regressor (S8).
- Repeated-measures ANOVA: non-sphericity corrected, fractional df (S6).
- GRF: RFT cluster p for T and F fields from SPM instead of the Gaussian
  approximation on a Z threshold; 18- not 26-connectivity; CDT 0.001 by
  default; AlphaSim removed.
- Outputs: BIDS names under `group/`, JSON metadata, Z and p maps, cluster
  tables.
