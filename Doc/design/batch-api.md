# SeeCAT 2 batch API — design draft

Status: **accepted** (2026-10-30). Decisions D1–D7 are recorded in section 11.

## 1. Goals

1. Every analysis runs from a script or a JSON file, with no GUI. The GUI
   only edits a config and calls the same entry point.
2. One run is reproducible from its saved config plus the versions recorded
   next to the outputs.
3. Input is BIDS; output is a BIDS-derivatives dataset.
4. One failing subject does not stop the others; the run ends with a
   per-subject report.
5. Re-running skips finished work unless the config changed or
   `overwrite` is set.

## 2. What a user writes

```matlab
cfg = seecat.config('prep');                 % defaults for the pipeline
cfg.bids_dir   = 'D:/data/ds000030';
cfg.output_dir = 'D:/data/ds000030/derivatives/seecat';
cfg.subjects   = {'10159', '10171'};         % empty = all
cfg.task       = 'rest';
cfg.denoise.regressors = {'friston24', 'wm', 'csf'};
cfg.n_workers  = 8;
seecat.run(cfg);

% or, from a saved file (the GUI's "Export" button writes one)
seecat.run('my_study_prep.json');
```

Post-processing reads the derivatives that `prep` wrote (or fMRIPrep's):

```matlab
cfg = seecat.config('fc');
cfg.input_dir = 'D:/data/ds000030/derivatives/seecat';   % or fMRIPrep output
cfg.seeds = seecat.seed.sphere('PCC', [0 -53 26], 6);
cfg.seeds(2) = seecat.seed.sphere('mPFC', [0 52 -6], 6);
seecat.run(cfg);

cfg = seecat.config('degree');
cfg.threshold = 0.2; cfg.sign = {'pos'}; cfg.weight = {'bin', 'wei'};
seecat.run(cfg);

cfg = seecat.config('stat');
cfg.design = seecat.design.ttest2(groupA_files, groupB_files);
cfg.covariates = table(age, sex);
seecat.run(cfg);
```

Pipelines in v2.0: `prep`, `fc`, `degree`, `stat`. (`vbm` and others come
later and plug in the same way.)

## 3. Code layout

Recommended: a MATLAB namespace package, so nothing collides with SPM,
DPABI or other toolboxes on the user's path.

```
SeeCAT/
  seecat.m                    launcher (GUI)
  +seecat/
    run.m  config.m  version.m
    +io/      read_nii.m  write_nii.m  resample.m  read_tsv.m  write_tsv.m  write_json.m
    +bids/    layout.m  query.m  sidecar.m  deriv_name.m  from_dicom.m
    +prep/    defaults.m  run_subject.m
              step_dummy.m  step_slicetime.m  step_realign.m  step_coreg.m
              step_segment.m  step_normalise.m  step_masks.m  step_confounds.m
              step_denoise.m  step_smooth.m
    +denoise/ friston24.m  acompcor.m  fd_power.m  spikes.m  bandpass.m  regress.m
    +fc/      defaults.m  run_subject.m  seed_maps.m
    +seed/    sphere.m  mask.m  atlas.m
    +degree/  defaults.m  run_subject.m  degree_map.m
    +stat/    defaults.m  run_group.m  glm.m  contrast.m  smoothness.m  grf.m  fdr.m
    +design/  ttest1.m  ttest2.m  paired.m  anova1.m  rmanova1.m  regression.m
    +util/    parallel.m  log.m  hash.m  check_spm.m
    +gui/     (weeks 7–8)
  templates/
```

Calls read as `seecat.io.read_nii(...)`. Inside the package, functions can
`import seecat.io.*` to keep lines short. The phase-0 `sc_*` helpers move
into the package (`sc_read_nii` → `seecat.io.read_nii`, etc.).

Alternative: keep flat `sc_*` names in plain folders. Simpler to read, but
every folder has to be on the path and name clashes are on us.

## 4. Config

- A plain struct, created by `seecat.config(pipeline)` with every field set
  to its default. No classes: easy to inspect, edit, save and diff.
- Saved and loaded as JSON (`jsonencode`/`jsondecode`); field names are
  `snake_case` so the JSON is readable by other tools.
- `seecat.check_config(cfg)` runs before any work starts: unknown fields
  are an error (catches typos), types and ranges are checked, files exist,
  SPM version is supported. All problems are reported together.
- Each pipeline's defaults live in one file (`+prep/defaults.m`, …), which is
  also what the manual's option table is generated from.

Common fields:

| field | default | meaning |
|---|---|---|
| `bids_dir` / `input_dir` | — | raw BIDS dataset (prep) or derivatives (post-processing) |
| `output_dir` | `<bids_dir>/derivatives/seecat` | derivatives root |
| `work_dir` | `<output_dir>/../seecat_work` | intermediate files |
| `subjects`, `sessions`, `task`, `run` | all | BIDS selection |
| `n_workers` | 0 | 0 = serial; >0 = subject-level `parfor` |
| `overwrite` | false | redo steps whose outputs exist |
| `keep_work` | false | keep intermediate files after a subject succeeds |

## 5. Preprocessing (`prep`)

### 5.1 Steps and defaults

| step | default | notes |
|---|---|---|
| DICOM → BIDS | off (separate tool) | `seecat.bids.from_dicom(dicom_dir, bids_dir, heuristic)` with dcm2niix; writes sidecars |
| dummy scans | `auto` | leading non-steady-state volumes: mean in-brain intensity a robust outlier (z > 3.5 vs median/MAD, first 20 frames). `NumberOfVolumesDiscardedBy*` describe volumes already removed, so they are not used. A number overrides |
| slice timing | on, `auto` | uses `SliceTiming` (seconds) from JSON, so multiband works; reference = middle of TR. Off if no SliceTiming and none given |
| realign | on | SPM estimate+reslice, register to mean; writes motion parameters |
| coregister | on | T1 → mean EPI (header only) |
| segment | on | unified segmentation of T1 with SPM TPM; native c1–c3 + forward deformation `y_` |
| normalise | on | `normalise.write` with `y_`; 3 mm, bounding box `[-90 -126 -72; 90 90 108]`. Without T1: `normalise.estwrite` of mean EPI to TPM |
| masks | on | brain mask; WM and CSF masks from the subject's own c2/c3 (p > 0.99, eroded 1 voxel), in output space |
| confounds | on | writes `desc-confounds_timeseries.tsv` (see 5.3) |
| denoise | on | detrend + regression + band-pass in one model (see 5.2) |
| smooth | on, 6 mm | applied **after** denoising |

### 5.2 Denoising

- One linear model per subject: polynomial trend (order 1 default) +
  selected confound columns. Data and regressors are band-passed with the
  same filter before the regression, so the filter does not reintroduce
  removed signal (Hallquist 2013; Lindquist 2019). High-motion frames are
  handled as below.
- `regressors`: any of `friston24`, `wm`, `csf`, `gs`, `acompcor` (5 WM + 5
  CSF components by default), or any column name in the confounds TSV.
  Default `{'friston24', 'wm', 'csf'}`; GSR off by default.
- Band-pass default 0.01–0.1 Hz; `[]` = no filter.
- High-motion frames, `censor.mode` (decided, D3):
  - `censor` (default). Order of operations:
    1. Flag bad frames: FD_Power > 0.5 mm, plus 1 before and 2 after.
    2. Interpolate the flagged frames from good frames only, in the BOLD data
       and in every regressor (cubic spline by default; `spectral` as an
       option: a joint ridge least-squares fit of sinusoids up to the
       low-pass edge. Power et al. 2014 used the Lomb–Scargle form, which
       fits each frequency separately; up to Nyquist on a regular grid its
       reconstruction is a sinc kernel that is 0 at every other sample, so
       gaps come back as the mean. Simulations on 2026-10-31, in-band signal
       plus broadband noise: spectral (ridge 0.03) beats spline and the mean
       in interior gaps; at the series edges no method beats the mean).
    3. Band-pass data and regressors with the same filter. No spike is left
       to spread, and filtering cannot reintroduce removed signal.
    4. Fit the regression on good frames only; residuals for all frames.
    5. Output keeps full length. Flagged frames are recorded in the
       confounds TSV (`motion_outlier_XX` columns and a summary `censor`
       column). FC and degree drop them automatically; interpolated frames
       never enter any statistic.
  - `none`: no frame handling.
  - `interp_keep`: steps 1–4, and the interpolated frames are kept in later
    analyses (closest to the legacy "interpolate" option).
  - Plain spike regressors are not offered: with band-pass filtering they
    either stop zeroing the frame (when filtered) or leave an artificial step
    that the filter spreads (when not). Dropping frames before filtering
    breaks even sampling, so legacy "cut" is not offered either.
  - Subjects with less than `censor.min_minutes` (default 5) of good data
    are flagged in the report.

### 5.3 Confounds file

Columns use fMRIPrep names (`trans_x`, `rot_x`, `*_derivative1`, `*_power2`,
`white_matter`, `csf`, `global_signal`, `a_comp_cor_00`,
`framewise_displacement`, `motion_outlier_00`, …). Consequence: the denoise
step reads the same table whether it came from SeeCAT or from fMRIPrep, so
"import fMRIPrep confounds" is not a separate code path.

### 5.4 Intermediate files

SPM needs uncompressed `.nii`. All SPM work happens in `work_dir` as `.nii`;
final derivatives are written as `.nii.gz`. Intermediates are deleted after
a subject succeeds unless `keep_work` is true.

## 6. Output layout (BIDS derivatives)

Space label for SPM's TPM: `IXI549Space` (BIDS template identifier for SPM12).

```
derivatives/seecat/
  dataset_description.json            GeneratedBy: SeeCAT version, SPM, MATLAB
  logs/  prep_20261102T101500.log  prep_20261102T101500_config.json
  reports/  prep_20261102T101500_summary.tsv   (subject, status, mean FD, % frames kept, …)
  sub-10159/
    anat/
      sub-10159_desc-preproc_T1w.nii.gz
      sub-10159_label-GM_probseg.nii.gz            (WM, CSF likewise)
      sub-10159_from-T1w_to-IXI549Space_mode-image_xfm.nii.gz
    func/
      sub-10159_task-rest_desc-confounds_timeseries.tsv (+ .json)
      sub-10159_task-rest_space-IXI549Space_res-3_desc-brain_mask.nii.gz
      sub-10159_task-rest_space-IXI549Space_res-3_desc-preproc_bold.nii.gz      normalised, not denoised
      sub-10159_task-rest_space-IXI549Space_res-3_desc-denoised_bold.nii.gz     denoised, unsmoothed
      sub-10159_task-rest_space-IXI549Space_res-3_desc-denoisedSm6_bold.nii.gz  denoised + smoothed
      sub-10159_task-rest_space-…_desc-PCC_stat-r_connectivity.nii.gz           (fc)
      sub-10159_task-rest_space-…_desc-PCC_stat-z_connectivity.nii.gz
      sub-10159_task-rest_space-…_desc-degPosBinR02_stat-z_connectivity.nii.gz  (degree)
  group/
    <analysis-name>/
      <analysis-name>_stat-t_statmap.nii.gz (+ .json: df, FWHM, dLh, contrast, design)
      <analysis-name>_desc-residuals_statmap.nii.gz
      <analysis-name>_design.tsv
```

Every image gets a JSON sidecar with the parameters that made it
(`Sources`, seed coordinates, threshold, filter band, …). Group statistics
keep df/FWHM in the JSON, not in the 80-character header description; the
viewer reads the JSON first and the old `descrip` format as a fallback.

FC and degree default to the `desc-denoised` input; FC can switch to the
smoothed series, and degree smooths the *map* afterwards (as the legacy
VoxDeg did).

## 7. Execution model

A pipeline is a package `seecat.<name>` with three functions:

| function | role |
|---|---|
| `[cfg, spec] = defaults()` | every option with its default, and the validation spec |
| `[units, cfg] = plan(cfg)` | resolve folder defaults, check prerequisites, list the units of work (struct array with an `id` field) |
| `result = run_unit(unit, cfg, log)` | process one unit; return a struct of scalars/text for the summary; throw on failure |

```
seecat.run(cfg)
  ├─ seecat.config (fill) → seecat.check_config → seecat.<p>.plan
  ├─ logs/<p>_<time>_config.json, logs/<p>_<time>.log (MATLAB, SPM, SeeCAT versions)
  ├─ parfor (unit, n_workers)                      the only parallel loop
  │     skip if logs/done/<p>_<unit>.json has the same config hash
  │     result = seecat.<p>.run_unit(unit, cfg, log)   try/catch per unit
  │        ctx = seecat.util.run_step(ctx, 'realign', @step, cfg.realign, log) …
  │     on success: write the done marker; delete work_dir/<p>/<unit> unless keep_work
  │     on failure: full error report in logs/<p>_<time>/<unit>.log; work folder kept
  └─ reports/<p>_<time>_summary.tsv: unit, status, seconds, message, result fields
```

- **Unit-level resume.** The config hash covers every option except
  `n_workers`, `overwrite` and `keep_work`. `overwrite` ignores markers and
  clears the unit's work folder.
- **Step-level resume** (`seecat.util.run_step`), used after a failure when the
  work folder still exists. A step is skipped when its key matches: step
  name, its options, the whole `ctx` before it, and size/date of every file
  in `ctx.files`. On skip, only the fields the step added or changed are
  applied to `ctx`. Conventions: a step's settings come in `opt`, never in
  `ctx`; `ctx` holds state only (paths, metadata) and is JSON-encodable.
- Steps never modify their input files; each writes new files (realign
  estimates on a copy, coregister changes a copy of the T1w). Otherwise a
  re-run step would start from its own earlier output.
- `ctx` carries `work_dir`, `files` (paths) and metadata (TR, slice times,
  confounds) from step to step. Steps never change directory.
- SPM runs through `spm_jobman('run', job)` with jobs built in code (no
  `jobmats`); `spm('defaults','fmri')` and `spm_jobman('initcfg')` are called
  once per worker.
- Group-level pipelines (`stat`) plan a single unit; their heavy parts are
  vectorised instead of parallelised.

## 8. BIDS handling

Recommended: a small in-house reader (`+bids/layout.m`): walks `sub-*/[ses-*]/
{anat,func}`, parses entities from file names, applies JSON inheritance,
validates that each BOLD has `RepetitionTime`. Covers what SeeCAT needs in a
few hundred lines and adds no dependency.

Alternative: bundle bids-matlab (GPL-3.0, compatible). More complete, but a
large dependency and its API changes between releases.

## 9. GUI contract (weeks 7–8)

The GUI holds one config struct per pipeline. Controls map one-to-one to
config fields; "Run" calls `seecat.run(cfg)`; "Export" saves the JSON and
a `.m` script; "Load" reads a JSON. No computation lives in GUI callbacks.

## 10. Testing

- Unit tests per step on synthetic data (`tests/unit`).
- Config tests: defaults validate; every invalid field is caught.
- End-to-end: `prep → fc → degree → stat` on ds000030 (3 mm and 2 mm) and
  ds002785 (multiband), compared with the phase-0 results where the
  method did not change.

## 11. Decisions (accepted 2026-10-30)

| # | question | decision |
|---|---|---|
| D1 | Namespace package `seecat.*` or flat `sc_*` | package `seecat.*`; phase-0 `sc_*` helpers move in |
| D2 | Order | denoise unsmoothed data, smooth last; degree computed on unsmoothed data, then the map is smoothed |
| D3 | High-motion frames | `censor`: interpolate → band-pass → regress on good frames → drop flagged frames in FC/degree (section 5.2) |
| D4 | GSR default | off |
| D5 | File format | final derivatives `.nii.gz`; work files `.nii`, deleted after success |
| D6 | BIDS reader | in-house minimal reader |
| D7 | Default output resolution | 3 mm |
