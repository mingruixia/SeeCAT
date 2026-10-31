# Changelog

## Unreleased: 2.0 development

### Added
- **Preprocessing pipeline** `seecat.prep` (`seecat.run(cfg)` with
  `cfg = seecat.config('prep')`): input copy with non-steady-state detection,
  slice timing from `SliceTiming` (multiband-ready), realign (estimate only; data
  resampled once, at normalisation), T1w → mean EPI coregistration, unified
  segmentation (T1w, or the mean EPI without one), normalisation to IXI549Space,
  brain/WM/CSF masks from the subject's segmentation, confounds table with
  fMRIPrep column names (Friston 24, FD, tissue signals, aCompCor, motion
  outliers, `censor`), censor-aware denoising, smoothing after denoising, and
  BIDS-derivative outputs with JSON sidecars. Anatomical outputs are written by
  one unit per T1w.
- `seecat.denoise`: `fd_power`, `flag_frames`, `interpolate` (spline,
  spectral), `clean` (interpolate → band-pass data and regressors → fit on
  good frames), `compcor`, `motion_regressors`, `select_regressors`,
  `poly_trend`. `seecat.io.read_tsv`; `seecat.util.spm_run`.
- Tests: `tests/unit/test_denoise.m` (10), including that values on censored
  frames cannot change the residuals of good frames.

### Changed
- `censor.interp = 'lombscargle'` is replaced by `'spectral'`. On a regular TR
  grid, Lomb–Scargle reconstruction (fitting each frequency separately, up to
  Nyquist, as in Power et al. 2014 and in xcpEngine) is a sinc kernel that is 0
  at every other sample, so gaps came back as the series mean (checked for
  both the τ-shifted and the xcpEngine variant). `spectral` fits all sinusoids
  jointly up to the low-pass edge, with a ridge penalty. In simulations
  (in-band signal plus broadband noise) it beats spline and the mean in
  interior gaps; at the series edges no method beats the mean.
- Default `censor.interp` is now `'spectral'` (was `'spline'`). On ds000030
  (10 subjects; held-out real frames censored with other subjects' censor
  patterns, `tests/validation/compare_interp.m`) it changed the remaining good
  frames less in 9/9 subjects (median 6 % less) and the PCC seed map less in
  9/9 (10 % less); fill accuracy on the held-out frames did not differ.

- ds002785 (TR 0.75 s): at short TR the spectral fill is much better than spline
  (5/5 subjects; kept frames 35 % less changed, held-out frames 47 % more
  accurate).

### Fixed (found on ds002785, 480-volume runs)
- Realign took over 20 minutes per run: through the batch, SPM rewrites the 4D
  file's header once per volume. `spm_realign` is now called directly and the
  affines are written once (identical parameters; 152 volumes in 26 s, 477 in
  ~100 s).
- Normalisation took ~13 minutes per run: SPM writes a 4D output volume by
  volume, each write slower as the file grows. Volumes are now split, normalised
  by SPM and written back in one go (477 volumes: 775 s → 100 s). Output is
  float32 (was the input type, e.g. int16).
- Smoothing: SPM kernel applied in memory, 4D written once (identical output;
  152 volumes 63–124 s → 10 s).
- Full ds002785 rerun with these changes (`overwrite`): 405–501 s per subject
  (was 1040–1159 s), 15 min for 5 subjects on 4 workers (was 35). Motion, FD and
  censor flags bit-identical to the earlier run; tissue signals and aCompCor
  r = 1.0000; PCC seed correlations unchanged.
- A `.mat` affine file left by an interrupted realign could give a re-made work
  copy stale affines; `work_copy` now removes it.

### Validation
- ds002785 against its fMRIPrep confounds: non-steady-state volumes 3/2/1/1/3 vs
  3/2/0/3/2; FD r = 0.71–0.91 (mean FD ~20 % higher than fMRIPrep's); motion
  parameters r ≥ 0.92 for trans_z, rot_x, rot_y, and consistently negative r for
  trans_x and rot_z (axis sign convention, SPM vs FSL). PCC–mPFC r = 0.55–0.86.

- 2 mm output (`normalise.voxel_size = 2`; ds000030 sub-11061, sub-50048;
  ds002785 sub-0001, sub-0002; `tests/validation/compare_resolution.m`): names
  `res-2`, grid 91×109×91; brain-mask Dice with mask_ICV equal to 3 mm
  (0.92–0.98); FD identical. Seed-map spatial r between 2 mm and 3 mm: 0.99 on
  ds002785, 0.80 and 0.93 on ds000030. ds002785 2 mm: ~13 min per subject,
  ~2.5 min of it gzip of the 4D outputs.

### Changed: WM/CSF masks built in native space
- WM and CSF masks were thresholded and eroded on the output grid, so they
  depended on the output voxel size (ds000030 sub-11061: CSF 35 voxels at 3 mm,
  389 at 2 mm; CSF signal r = 0.80–0.84 between grids; PCC seed maps r = 0.80
  and 0.93). They are now built in the native space of the segmentation
  (`step_tissue_masks`: WM p > 0.99, CSF p > 0.95, eroded `masks.erode_mm` = 2 mm
  with a ball) and resampled to the output grid. Option `masks.erode` (voxels)
  is replaced by `masks.erode_mm`. Thresholds from a sweep over 15 subjects:
  CSF p > 0.99 eroded 2 mm can be empty; p > 0.95 keeps 2.7–8.4 cm^3
  (min–median); WM keeps 46–104 cm^3.
- Result on the same 4 subjects: CSF mask sizes now scale with voxel volume
  (sub-11061: 246 vs 813 voxels, ratio 3.3), CSF signal r = 0.95–0.99 between
  grids, PCC seed maps r = 0.991–0.995 on both datasets.
- Denoised data change with the new regressors. Example: ds000030 sub-11061
  PCC–V1 r went from 0.20 to 0.50 at 3 mm. The old 35-voxel CSF mask carried
  grey-matter partial volume and removed some shared signal, close to a partial
  global-signal regression.

- Re-checked with the new masks on all 15 subjects (3 mm): the interpolation
  comparison is unchanged (spectral better in 9/9 and 5/5 subjects; kept-frame
  change ratio 0.94 at TR 2 s and 0.65 at TR 0.75 s). PCC–mPFC median r = 0.63.

### Fixed
- Denoising now refuses runs with fewer than 10 residual degrees of freedom.
  ds000030 sub-50052 (123 of 152 frames flagged) kept 29 frames for 28
  regressors; every voxel's residual had the same shape and all seed
  correlations were 1.00. The unit now fails with the reason in the summary.

- Output manifest per unit (`logs/outputs/<pipeline>_<unit>.txt`,
  `seecat.util.record_output`). A unit that runs again first deletes the
  derivatives of its previous run, and a failed unit deletes what it wrote, so
  a failure never leaves earlier or partial derivatives behind (before: a
  failed rerun of ds000030 sub-50052 kept its earlier, meaningless denoised
  files). Changing an option that renames outputs (e.g. `smooth.fwhm`) no
  longer leaves the old files. The prep outputs step now always runs.
  Derivatives written before this change have no manifest and stay until
  removed by hand.

- `seecat.bids.from_dicom`: DICOM → BIDS with dcm2niix (anonymised sidecars) and
  naming rules (`seecat.bids.dicom_rules`; JSON file or struct; default rules
  for 3D T1w and resting BOLD only). Handles runs (several series, one name;
  ordered by study time and series number, so two studies in one folder do
  not collide), multi-echo, TaskName, dataset_description.json,
  participants.tsv and a per-subject report. `seecat.util.find_dcm2niix`
  (argument, SEECAT_DCM2NIIX, bundled copy, PATH; v1.0.20220720 or later).
  Tested on the dcm2niix QA data: 47 Siemens images (incl. multiband with
  SliceTiming) and Philips EPI (reported as having no SliceTiming) equal the
  reference outputs in data, affine and every sidecar field except
  WipMemBlock, which dcm2niix v1.0.20260724 itself writes differently.
  `tests/unit/test_dicom.m` (6 tests; skipped without dcm2niix or the data).

- Group masks rebuilt from SPM's TPM (`seecat.util.make_templates`): brain, GM,
  WM and CSF at 2 and 3 mm, `tpl-IXI549Space_res-*_mask.nii` with JSON
  sidecars, thresholds as in 1.0 (brain 0.5, GM 0.2, WM 0.9, CSF 0.7). The
  DPABI-distributed masks (`BrainMask_05`, `GreyMask_02`, `WhiteMask_09`,
  `CsfMask_07`, `GMwithoutCER`) are removed; Stat, VoxDeg, FuncConnect and the
  legacy PrepfMRI use the new files. The default GM analysis mask is smaller
  than 1.0's (52,276 vs 67,541 voxels at 3 mm, Dice 0.87; brain mask Dice
  0.96, and 0.99 with SPM's mask_ICV), because SPM12/25's TPM is sharper, so
  voxel-wise degree and group statistics within the default mask differ from
  1.0. `tests/unit/test_templates.m` checks that regenerating gives the
  committed files.

### Known issues

## Unreleased: phase 0 fixes on top of 1.0 beta

### Fixed
- **Stat, repeated-measures ANOVA**: the per-subject regressors were filled from a
  leftover loop variable. The F map came out constant (invalid) for any data.
  Subject `n` now gets its own dummy across all conditions, and unequal group sizes
  are rejected with a message.
- **Stat, orientation**: inputs were read with `y_ReadRPI`, which mirrors the affine
  of RAS-oriented images (`mat(1,1) > 0`). When the field of view is not centred on
  x = 0, results were written back left-right flipped. Images are now read in their
  stored orientation on the grid of the first input. The mask and image covariates
  are resampled to that grid.
- **Stat**: output maps are always float32. Before, they inherited the input data
  type, so int16 inputs truncated T/F values.
- **Stat**: with three or more groups, image covariates were assigned to the wrong
  subjects (wrong start index).
- **Preprocessing, filter**: a stray character made high-pass-only filtering
  (high cutoff 0 or above Nyquist) fail with "Undefined 's'". A low cutoff of 0
  indexed past the end of the frequency mask. The filter moved to
  `seecat.denoise.bandpass`; results for ordinary bands are unchanged
  (checked against the old code to 1e-10).
- **Preprocessing, scrubbing**: extending bad frames before or after the scan edge
  wrongly marked the first or last frame as bad. Out-of-range indices are now
  dropped. `ScrubbingPercentage.txt` now reports the fraction of frames actually
  removed, including the neighbours.
- **Preprocessing, nuisance regression**: the WM/CSF/global masks (3 mm, 61×73×61)
  are resampled to the data grid. Before, any voxel size other than 3 mm gave wrong
  signals or an error.
- **Preprocessing, normalisation (T1 segment, SPM12+)**: the voxel size and bounding
  box set in the GUI were ignored; output was always 3 mm.
- **Seed FC**:
  - The calculation mask and mask seeds are resampled to the data grid.
  - Only voxels with signal are averaged into a seed.
  - Zero-variance voxels give 0 instead of NaN; r is clipped so Fisher z stays finite.
  - Each subject folder must hold exactly one 4D `.nii`.
  - No more `cd` inside `parfor`.
  - Seed numbering is `%02d`, so more than 99 seeds work.
  - Per-subject computation lives in `FuncConnect/sc_seed_fc_subject.m`.
- **Voxel-wise degree**: the mask is resampled to the data grid.
- **All modules**:
  - Subject folders are listed with `sc_list_subjects`: directories only, hidden
    entries skipped, no longer relying on `.`, `..` and `.DS_Store` sorting first.
  - The invalid `parpool('size')` fallback was replaced by `seecat.util.start_pool`.
- **Viewer**: opening it now lists the DPABI functions it needs but cannot find,
  instead of failing later with "Undefined function".
- The log message at the end of realignment said "Started".

### Added
- `+seecat` namespace package (design: `Doc/design/batch-api.md`).
  - `seecat.io.read_nii` / `seecat.io.write_nii`: one NIfTI I/O layer for
    v2. Images are read in stored orientation (nothing is flipped), `.nii.gz`
    and file lists are supported, and an optional reference grid resamples in
    world space. These replace the DPABI `y_Read*`/`y_Write` calls; Stat
    already writes through them.
  - Phase-0 helpers moved in: `sc_resample_to_ref` → `seecat.io.resample`,
    `sc_bandpass` → `seecat.denoise.bandpass`, `sc_start_pool` →
    `seecat.util.start_pool`.
  - `seecat.config`, `seecat.check_config`, `seecat.save_config`: pipeline
    configuration as a struct with defaults, JSON load/save, and validation
    that reports every problem at once. Preprocessing defaults in
    `seecat.prep.defaults`.
  - `seecat.bids.layout`, `query`, `metadata`, `bold_units`: a minimal BIDS
    reader. Indexes `sub-*/[ses-*]/<datatype>/` (derivatives and other
    non-raw folders are skipped), merges sidecars by the inheritance
    principle, and lists the BOLD runs to process with their T1w, TR and
    metadata. Selection problems are reported together.
  - `seecat.bids.deriv_name`, `parse_name`, `write_description`:
    BIDS-derivatives file names in entity order, and the derivatives'
    `dataset_description.json`.
  - `seecat.run`: runs any pipeline (`defaults`/`plan`/`run_unit`) over its
    units, serially or in a parfor; per-unit logs and error isolation; a
    summary TSV; skips units finished with the same options. Steps go
    through `seecat.util.run_step`, which resumes a failed unit after its
    last finished step.
  - `seecat.prep.plan`: resolves folders and BOLD runs; checks SPM
    (`seecat.util.check_spm`). The preprocessing steps are next.
- `Doc/ROADMAP.md`: the v2.0 plan.
- `tests/unit/test_io.m`, `test_config.m`, `test_bids.m`, `test_run.m`: tests
  for the I/O layer, the configuration, the BIDS reader and the run framework
  (with a test-only `demo` pipeline in `tests/fixtures`).
- `tests/unit/test_p0_fixes.m`: synthetic-data tests for the fixes above.
- `tests/legacy_baseline/`: scripts that run the legacy GUIs headlessly on public
  data (OpenNeuro ds000030 subset) and compare outputs between code versions.
