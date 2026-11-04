# Quality control: IQMs, reports and exclusions

Decided 2026-11-05.

## Where the IQMs are computed

MRIQC-style image quality metrics are a step of the `prep` pipeline
(`qc.iqm`, default on), not a page of their own. They need exactly what
preprocessing already makes: the T1w segmentation (GM/WM/CSF in native
space), the bias-corrected T1w, the realignment and the EPI-T1w
coregistration. A separate step would repeat those, at about the cost of
preprocessing itself; inside `prep` the IQMs add about half a minute per run.

- BOLD: the run after dummy-scan removal, without slice timing, resliced with
  the realignment (MRIQC's head-motion-corrected series); brain mask =
  GM + WM + CSF > 0.5 of the segmentation on the mean EPI grid.
- T1w: the coregistered raw T1w, its bias-corrected image (`m`), the native
  tissue maps; INU = raw / corrected; head, air and "rot" (exact zeros) masks
  are SeeCAT's own (threshold, closing, hole filling, dilation).
- `fmriprep`: no IQMs (no raw data in its outputs); the motion and coverage
  rules still apply.

The formula-based metrics equal MRIQC 24.0.2 on identical inputs
(`tests/validation/make_iqm_reference.py`, `tests/unit/test_iqm.m`). AFNI-based
ones (aor, aqi, gcor, fwhm) are re-implemented from their definitions. Left
out: qi_1, qi_2, tpm_overlap. Absolute values differ from a real MRIQC run
because the masks differ; only comparisons within a dataset are meaningful.

## Exclusion

`seecat.qc.group_report` (the `finish` step of `prep` and `fmriprep`) writes
`reports/qc_exclusions.tsv`:

| column | meaning |
|---|---|
| id | run stem (`sub-01_task-rest`) or T1w stem (`sub-01_T1w`) |
| kind | `bold` or `T1w` |
| exclude | 1 = left out of later analyses |
| reasons | the rules a run breaks (auto exclusion) |
| warnings | not excluding: mean FD > 0.25 mm, bottom coverage < 80 %, IQM outliers |
| decision | `auto`, or `user` once changed on the QC reports page |
| note | free text |

Rules (`cfg.qc`): largest translation > 3 mm, largest rotation > 3 deg, mean
FD > 0.5 mm, too little data after censoring (`censor.min_minutes`), coverage
of the template brain < 0.9. IQM outliers: robust z (median, MAD) beyond
`qc.iqm_z` (3) in the bad direction, within the run's site (participants.tsv
`site`, >= 5 runs) or the whole dataset. T1w rows carry warnings only.

Rows with decision `user` keep their value when the report is made again.
Later pipelines (`fc`, `degree`, `gradient`, `harmonize`, `stat`) read the
list of their input folder when `qc_exclusions` is true (default) and match
files by run key (sub, ses, task, acq, ce, rec, dir, run, echo), so every
derivative of an excluded run, and the VBM maps of an excluded T1w, are left
out. The list of excluded runs is logged and kept out of the options hash, so
editing the list does not rerun finished units.

## VBM

`vbm.enable` asks SPM's segmentation for normalised tissue maps (TPM grid,
1.5 mm), modulated (`mwc`) by default, plus a smoothed copy (`vbm.fwhm`, 8
mm). No DARTEL/Shooting yet (ROADMAP: light VBM). Tissue volumes (GM, WM, CSF,
TIV in mL) are computed from the native maps for every T1w, stored in the
sidecar of the GM map and gathered in `reports/anat_volumes.tsv`; `stat` and
`harmonize` add these columns to participants.tsv when it lacks them.
