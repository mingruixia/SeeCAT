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
  that API. Minimum MATLAB: R2020b.
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
- [ ] Release script: bundle dcm2niix v1.0.20260724 for win/mac/lnx; licence in
      THIRD_PARTY_NOTICES.
- [ ] Preprocessing:
  - [x] `seecat.prep.run_unit`: all steps, SPM batches built in code
        (first subject of ds000030 end to end, 5.4 min).
  - [ ] Remove `PrepfMRI/jobmats` (with the legacy GUI, weeks 7–8).
  - [x] Nuisance masks from the subject's own segmentation.
  - [x] aCompCor (CSF and WM separately).
  - [ ] Denoise from fMRIPrep outputs (confounds table already compatible).
  - [x] Censoring (interpolate → filter → regress → drop), with unit tests.
  - [x] Spectral gap fill (replaces Lomb–Scargle, which cannot fill gaps on a
        regular grid).
  - [x] One parallel pattern everywhere; no `cd`.
- [ ] Rebuild `templates/`: masks generated from SPM TPM by a script in the
      repo; remove DPABI-distributed masks and label files.
- [x] End-to-end on ds002785 (multiband, TR 0.75 s, 5 subjects): non-steady-state
      counts, motion and FD checked against its fMRIPrep confounds.
- [x] End-to-end test at 2 mm output (2 + 2 subjects).
- [x] WM/CSF masks built in native space, independent of the output grid
      (2 mm vs 3 mm seed maps r = 0.99 on both datasets).

## Weeks 5–6 (11/23 – 12/04): computation and statistics

- [ ] Vectorise seed FC and voxel-wise degree (degree: ~20 min → < 2 min on
      the 10-subject baseline).
- [ ] Rewrite Stat with no DPABI-derived code:
  - [ ] QR-based GLM with T and F contrasts.
  - [ ] Own FWHM (smoothness) estimation from residuals.
  - [ ] Own voxel- and cluster-level GRF, and FDR.
  - [ ] Drop AlphaSim.
  - [ ] Validate against SPM; DPABI V9 as an external cross-check.
- [ ] Basic QC report (head motion, FD, registration snapshots) as HTML.

## Weeks 7–8 (12/07 – 12/18): GUI and viewer

- [ ] Code-built GUI: launcher and module panels over the batch API.
- [ ] Own slice viewer: overlays, thresholding, cluster report, atlas labels,
      montage and export.
- [ ] BrainNet Viewer hook.
- [ ] Remove `Visual/` and `sc_check_dpabi.m`.

## Week 9 (12/21 – 12/31): release

- [ ] English manual.
- [ ] Full validation on both public datasets.
- [ ] `LICENSE` (GPL-3.0-or-later), `THIRD_PARTY_NOTICES`; atlases fetched
      from their original sources with licences checked.
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
