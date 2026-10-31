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

### Known issues
- At 3 mm the eroded CSF mask is small (35 voxels in the first ds000030
  subject).

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
