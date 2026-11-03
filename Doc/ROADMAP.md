# SeeCAT 2.0 roadmap

Target: release v2.0 on GitHub and NITRC by 2026-12-31.
Maintainer: Mingrui Xia. Licence: GPL-3.0-or-later.

## Ground rules

- **No DPABI code.** Every DPABI-derived file and function is removed and
  reimplemented. DPABI may be used only as an external cross-check in tests;
  it is never shipped or called.
- **SPM is the only required toolbox** (SPM25; SPM12 r7771+ should work).
  BrainNet Viewer is optional, for surface and network figures.
- **Batch API first, GUI second.** Every step runs from a config struct
  without a GUI. The GUI is built in code (`uicontrol`, no `.fig`) on top of
  that API. Minimum MATLAB: R2025a (raised from R2020b on 2026-11-03).
- **BIDS in, BIDS-derivatives out.** No compatibility with the old
  `FunImgARW…` folder layout.
- **New SPM routines only.** Unified segmentation + `normalise.write` with the
  `y_` field. Without a T1, `normalise.estwrite` of the mean EPI to `TPM.nii`.
  OldNorm and OldSeg are not used.
- English UI and manual.
- Test data: OpenNeuro ds000030 (single band) and ds002785 (multiband),
  neurolabusc dcm_qa for DICOM, plus synthetic data for unit tests
  (see `tests/README.md`).

## Phase 0 — done (2026-10-30)

Git repository, legacy baseline on ds000030, P0 bug fixes, unit tests.
See `CHANGELOG.md`.

## Weeks 2–4 (11/02 – 11/20): core library and preprocessing

- [x] Unified NIfTI I/O: `seecat.io.read_nii` / `write_nii`. Stored
      orientation, correct world space, `.nii.gz`, 3D/4D, file lists.
      (Remaining `y_*` callers are Calculator and `Visual/`, rewritten later.)
- [x] Batch API design accepted: `Doc/design/batch-api.md`.
- [x] `seecat.*` package with config defaults, JSON load/save and validation.
- [x] `seecat.run` entry point: units, logging, per-unit errors, resume.
- [x] BIDS input (layout query, sidecar JSON).
- [x] BIDS-derivatives naming and `dataset_description.json`.
- [x] DICOM conversion with dcm2niix (`seecat.bids.from_dicom`); checked against the
      dcm2niix QA references (Siemens incl. multiband, Philips).
- [x] Release script `tools/make_release.m`: committed files plus dcm2niix
      v1.0.20260724 for win/mac/lnx (size and SHA-256 checked); licence in
      THIRD_PARTY_NOTICES.
- [ ] Preprocessing:
  - [x] `seecat.prep.run_unit`: all steps, SPM batches built in code
        (first subject of ds000030 end to end, 5.4 min).
  - [ ] Remove `PrepfMRI/jobmats` (with the legacy GUI, weeks 7–8).
  - [x] Nuisance masks from the subject's own segmentation.
  - [x] aCompCor (CSF and WM separately).
  - [x] Denoise from fMRIPrep outputs (`seecat.config('fmriprep')`; ds002785, 5
        subjects, ~1 min each).
  - [x] Censoring (interpolate → filter → regress → drop), with unit tests.
  - [x] Spectral gap fill (replaces Lomb–Scargle, which cannot fill gaps on a
        regular grid).
  - [x] One parallel pattern everywhere; no `cd`.
- [x] Rebuild `templates/` masks from SPM TPM (`seecat.util.make_templates`, 2 and
      3 mm); DPABI-distributed masks removed.
- [x] Atlases from installed sources (SPM Neuromorphometrics, BrainNet AAL/Brodmann);
      underlays ch2 / ch2better / MNI 2009c kept (gzip), chosen by data space.
- [x] End-to-end on ds002785 (multiband, TR 0.75 s, 5 subjects): non-steady-state
      counts, motion and FD checked against its fMRIPrep confounds.
- [x] End-to-end test at 2 mm output (2 + 2 subjects).
- [x] WM/CSF masks built in native space, independent of the output grid
      (2 mm vs 3 mm seed maps r = 0.99 on both datasets).

## Weeks 5–6 (11/23 – 12/04): computation and statistics

- [x] Vectorise seed FC and voxel-wise degree: `fc` and `degree` pipelines on
      SeeCAT derivatives. Degree equals SeeCAT 1.0 on the legacy baseline input
      (float32 precision) and takes 35 s instead of ~20 min per subject; all 9
      ds000030 subjects in 2 min on 4 workers.
- [x] Rewrite Stat with no DPABI-derived code (`seecat.config('stat')`,
      Doc/design/stat.md, accepted 2026-10-31):
  - [x] QR-based GLM with T and F contrasts, image covariates, ReML
        non-sphericity.
  - [x] Own FWHM (smoothness) estimation from residuals (= spm_est_smoothness).
  - [x] Voxel- and cluster-level RFT (SPM's spm_P / spm_uc, S1), and FDR.
  - [x] AlphaSim not offered by the new pipeline (the legacy viewer's AlphaSim
        goes with Visual/ in weeks 7–8).
  - [x] Validated against SPM for all built-in designs (one-sample, two-sample
        with covariate, paired, ANOVA, regression with covariate, within-subject
        ANOVA with non-sphericity) and against 1.0's T map.
  - [ ] DPABI V9 cross-check (needs a DPABI installation; not a gate).
- [x] QC report as HTML: per run (motion, FD with censored frames, DVARS and
      FD–DVARS before/after denoising, carpet plots, registration and nuisance
      mask snapshots) and per dataset (`reports/<pipeline>_qc.html`), for prep
      and fmriprep.

## Weeks 7–8 (12/07 – 12/18): GUI and viewer

- [x] Code-built GUI (`SeeCAT`): launcher with forms generated from
      `seecat.<p>.gui()`, config load/save, runs in a background MATLAB process.
- [x] Own slice viewer (`seecat.viewer`): overlays, thresholding, cluster report, atlas labels,
      montage and export.
- [x] BrainNet Viewer 2.0 hook (Scene JSON; app or `BrainNetRender`).
- [x] Remove all 1.0 GUIs, `Visual/`, `sc_check_dpabi.m`, `jobmats`, `dcm2nii`, atlas files.

## Week 9 (12/21 – 12/31): release

- [ ] English manual.
- [ ] Full validation on both public datasets.
- [x] `LICENSE` (GPL-3.0-or-later), `THIRD_PARTY_NOTICES` (dcm2niix, Colin27,
      ICBM152 2009c, TPM-derived masks; atlases are read from SPM and
      BrainNet installations, not shipped), `README.md`.
- [ ] Release on GitHub and NITRC.

## Cut order if late

1. QC report shrinks to a text summary.
2. Montage export moves to v2.1.

Thresholding and the cluster report in the viewer are not cut.

## v2.x (2027 onward)

- Image calculator (moved from v2.0).
- Light VBM (DARTEL/Shooting, modulated GM, TIV) and structural covariance.
- TFCE and permutation tests, ComBat, linear mixed models.
- lFCD, fECM, dynamic FC.
