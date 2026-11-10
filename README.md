# SeeCAT

SeeCAT is a MATLAB toolbox for brain functional connectivity analysis of
resting-state fMRI: preprocessing, denoising, seed-based functional
connectivity, voxel-wise degree centrality, connectivity gradients,
multi-site harmonisation, group statistics and viewing,
from a BIDS dataset to BIDS-derivatives outputs.

Version 2.0 is a rewrite. It needs only SPM, and no longer uses other toolboxes or
the `FunImgARW…` folder layout of 1.x.

## Development

| Version | When |
|---|---|
| 1.0 beta | working copy of March 2024 |
| 2.0 rewrite | started 30 October 2026 |
| 2.0.0 | released 6 November 2026 |
| 2.1 | in development since November 2026 |

## Requirements

- MATLAB. SeeCAT is developed and tested on R2025a; older releases are not
  tested (SeeCAT runs on them and notes it once). No other MathWorks toolbox
  is needed; the Parallel Computing Toolbox is optional, for running
  subjects in parallel.
- SPM25, or SPM12 r7771 or later.
- Optional: BrainNet Viewer 2.0, for surface and network figures.

dcm2niix (for importing DICOM) is included in the release zip.

## Install

1. Unzip `SeeCAT-<version>.zip`.
2. In MATLAB:

   ```matlab
   addpath('path/to/spm');
   addpath('path/to/SeeCAT-<version>/SeeCAT');
   savepath   % optional
   ```

On macOS, if dcm2niix is blocked the first time, allow it in System
Settings → Privacy & Security, or run
`xattr -dr com.apple.quarantine SeeCAT-<version>/external`.

The bundled Linux dcm2niix needs glibc 2.29 or later (Ubuntu 20.04+, Debian
11+, RHEL/Rocky 9+). On older systems install dcm2niix yourself (for example
`pip install dcm2niix`) and put it on the PATH or set `SEECAT_DCM2NIIX`;
SeeCAT uses it when the bundled copy does not run.

## Use

The main window:

```matlab
SeeCAT
```

Every pipeline also runs from a script. The window's Save button writes the
same JSON file.

```matlab
cfg = seecat.config('prep');                 % preprocessing defaults
cfg.bids_dir   = 'D:/data/ds000030';
cfg.subjects   = {'10159', '10171'};         % empty = all
cfg.n_workers  = 4;
seecat.run(cfg);                             % writes derivatives/seecat

cfg = seecat.config('fc');                   % seed-based FC
cfg.input_dir = 'D:/data/ds000030/derivatives/seecat';
cfg.seeds = struct('name', {'PCC'}, 'center', {[0 -53 26]}, 'radius', 6);
seecat.run(cfg);

seecat.run('my_study_stat.json');            % a saved config
seecat.viewer('group/.../..._stat-t_statmap.nii.gz')
```

| Pipeline | What it does |
|---|---|
| `prep` | slice timing, realign, coregistration, segmentation, normalisation, confounds, censoring, denoising, smoothing; MRIQC image quality metrics, QC exclusions, optional VBM maps |
| `fmriprep` | the same denoising, from fMRIPrep outputs |
| `fc` | seed-based connectivity maps (r and Fisher z) |
| `degree` | voxel-wise degree and strength |
| `gradient` | connectivity gradients (diffusion map embedding, as BrainSpace) on voxel or atlas nodes, aligned across runs |
| `harmonize` | multi-site harmonisation of per-subject maps: ComBat (parametric, non-parametric, no EB, location only), ComBat-GAM, CovBat, linear regression |
| `stat` | GLM group statistics (one-sample, two-sample, paired, ANOVA, regression) with RFT, FDR and TFCE (permutation) inference |

Import to BIDS: `seecat.bids.from_dicom(dicom_dir, bids_dir)` converts DICOM
folders, and `seecat.bids.from_nifti(nifti_dir, bids_dir)` organises NIfTI
images (scanner and platform exports with .json sidecars, or older .nii/.img
data). Both find the subjects from the folder tree and the headers (one folder
per subject, modality folders with subject folders inside, deeper trees),
make sessions from session folders or scan dates, and name T1w, BOLD (task from
the series name), field maps (with IntendedFor) and single-band references.
`'dryrun', true` returns the names for checking; an edited plan goes back in
with `'names'`, and `seecat.bids.plan_rules` saves it as rules for the next
subjects. Give `'sub'` and `'ses'` to set the labels yourself.

Each run writes an HTML QC report per subject and per dataset. The Data check
page lists every BOLD run's volumes, TR and head motion, and the viewer steps
through a 4D series volume by volume.

## Manual

The user manual, in English and Chinese, is in `Doc/manual`: open
`Doc/manual/index.html`, or the PDFs `SeeCAT_Manual_EN.pdf` and
`SeeCAT_Manual_ZH.pdf` in the release. The window's Manual button opens it.
It covers every module and option and works through a three-site example.

## Tests

```matlab
results = runtests('tests/unit');
```

See `tests/README.md` for the public test data. The tests and their data
are in the source repository only; the release zip does not include them.

## Licence

GPL-3.0-or-later; see `LICENSE`. Bundled third-party files and their terms
are listed in `THIRD_PARTY_NOTICES`.

Mingrui Xia, State Key Laboratory of Cognitive Neuroscience and Learning,
Beijing Normal University.
