# Changelog

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
- `Doc/ROADMAP.md`: the v2.0 plan.
- `tests/unit/test_io.m`, `tests/unit/test_config.m`: tests for the I/O layer
  and the configuration.
- `tests/unit/test_p0_fixes.m`: synthetic-data tests for the fixes above.
- `tests/legacy_baseline/`: scripts that run the legacy GUIs headlessly on public
  data (OpenNeuro ds000030 subset) and compare outputs between code versions.
