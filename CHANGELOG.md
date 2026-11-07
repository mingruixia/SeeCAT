# Changelog

## Unreleased: 2.1 development

### Added
- **Import to BIDS: NIfTI folders.** The DICOM to BIDS page is now Import
  to BIDS. It takes DICOM folders as before, or NIfTI images: scanner and
  platform exports with dcm2niix-style .json sidecars, or older data without
  sidecars (.nii, .nii.gz, Analyze .img/.hdr, one 4D file or numbered 3D
  volumes per run). The kind is found from the files. New functions:
  - `seecat.bids.from_nifti`;
  - `seecat.bids.scan_nifti`, which finds subjects in `sub-` folders, the
    shallowest folder level named like IDs, IDs at the start of file
    names, the PatientID, or a `subject_pattern`, and drops a name written
    after the ID (`sub173_zhangsan` -> `sub-173`); sessions come from
    session folders or the scanning visits;
  - `seecat.bids.source_kind`.
- **Built-in recognition for both kinds** (`seecat.bids.organize`, shared
  with from_dicom; `'auto'`, default on):
  - task BOLD named from the series (`Math_AI_trust3` -> `task-mathaitrust`
    `run-3`);
  - gradient-echo field maps as magnitude1/2 + phasediff with EchoTime1/2,
    spin-echo EPI field maps as epi with dir;
  - IntendedFor (`bids::` URIs) by acquisition order;
  - single-band references as the sbref of the next run;
  - localizers, phase and derived images, and the ND copy of a
    distortion-corrected T1w, left out with the reason.
- **Preview names, edit, Save as rules.** Preview names lists every image
  with its proposed BIDS name without writing (`'dryrun', true`); names
  edited or emptied in the Summary table are used by Convert (`'names'`).
  `seecat.bids.plan_rules` (Save as rules) turns a checked plan into rules
  for the next subjects. Rules may also match `Path` and `Volumes`, and
  `"skip": true` leaves images out.
- **Privacy in imported sidecars.** Sidecars are copied without the name,
  ID, birth date and other identifying fields; participants.tsv gets sex and
  age at the scan from them. The report in code/seecat shows the subject's
  folder as `sub-<label>`.
- `'link', true` (scripts): hard links instead of copies for .nii.gz images.
- **Preprocessing and fMRIPrep denoising show the dataset.** Once the BIDS
  (or fMRIPrep) folder is set, the line below it lists the subjects,
  sessions and tasks of its BOLD runs with the number of runs per task, and
  the empty Subjects and Task fields show what they will take
  (`seecat.bids.summary`).
- **Degree: same voxels in every run** (`group_mask`, default off). The
  brain masks of all selected runs are intersected into a group mask
  (`seecat.conn.group_mask`, written to group/masks/ with the list of runs),
  and each run's network uses only those voxels, combined with Mask. Without
  it, the voxel count differs a little between subjects with their field of
  view and segmentation.
- Tests: tests/unit/test_nifti.m on synthetic exports
  (tests/data/make_nifti_demo.m); test_dicom covers auto naming and dry runs.

### Changed
- from_dicom names BOLD-like series that no rule names (`'auto', false`
  restores the old behaviour) and its table has a `source` column.
- The BIDS folder of a NIfTI import must lie outside the source folder.
- Preprocessing and fMRIPrep denoising: an empty Task processes every task
  (it used to be an error when the data held several), and Task takes several
  labels (`rest, nback` in the window, `{'rest', 'nback'}` in a config). The
  analysis pages still take one task.

### Fixed (2026-11-07 review; tests in tests/unit/test_review3.m and test_nifti.m)
- *Numbered 3D volumes of different subjects or runs were merged.* Only the
  number at the end of a file name may change within a series
  (`S01_rest_0001` and `S02_rest_0001`, or `run1_vol0001` and
  `run2_vol0001`, are different runs), and frames are ordered by that number
  alone. A series with gaps in its numbers, or whose images differ in grid,
  orientation (the header's qform/sform) or TR, is not merged and a warning
  says why. High-resolution 3D images and names ending in a subject number
  are never series.
- *Files named by a relative path (`seed.nii`, `mask.nii`) were not
  followed* by resume and were not protected as inputs. Any text with a
  file extension that is a file in the current folder is now an input, by
  its canonical path; keywords and files found only on the MATLAB path are
  not.
- *Names in file names reached the dataset.* The words after the ID at the
  start of a file name that no other subject has, and the words of
  PatientName, are taken out of the import report, the descriptions and all
  kept text fields of the sidecars (`seecat.bids.scrub_names`), as the words
  after the ID in folder names already were. The manual says which names
  are recognised and asks to check before sharing.
- *A code edit in a running MATLAB session was not noticed.*
  seecat.util.code_fingerprint now checks the code files' names, sizes and
  dates on every run and reads them again when they changed.

## 2.0.0 (2026-11-06)

### Added
- **Fixes from the 2026-11-06 review** (regression tests in
  tests/unit/test_review2.m):
  - *An output folder that is the input folder deleted input files.* With
    output_dir = fmriprep_dir, publishing the brain mask copied a file onto
    itself, failed, and the failure clean-up deleted the input mask. The
    output folder may no longer be the BIDS or fMRIPrep folder (relative
    paths, trailing separators and links included); refused before anything
    is written. Every unit's input files are protected
    (seecat.util.protected_inputs): recording one of them as an output is an
    error before it is written, and clearing a unit's outputs never deletes
    one.
  - *Edited seed, mask or covariate images were not noticed.* Resume now
    fingerprints every file named in the config too (seeds, ROIs, masks,
    atlases, the participants table), and Statistics finds the image
    covariates' files when it plans, so they are part of the unit. Files up
    to 64 MB are compared by contents (MD5), larger ones by size and date.
    The SeeCAT code that computes results and the bundled templates are
    fingerprinted as well (seecat.util.code_fingerprint): after an update,
    finished units are computed again.
  - *Harmonize ids of long map selections collided*, so harmonising a second
    measure deleted the first one's maps. The unit id is now a readable part
    and 8 characters of a hash of the whole selection (field names and
    values, in any order), e.g. `harmonizeComBat_PCCz_3821b739`; the report
    folder is named after it. Long atlas names in Gradients get a hash too.
  - *An empty analysis mask* in Statistics stopped inside the GLM with an
    index error; it now stops with the voxel counts at each stage (mask,
    non-zero in every map, after the image covariates).
  - *Two runs on the same unit at once* could clear each other's outputs.
    A unit is locked while it runs (logs/locks/, created atomically, with
    the run, host and process); another session's unit fails with a message
    naming it, and a lock left by a MATLAB that is gone is taken over.
  - *The release could carry PDFs of another state of the manual.*
    build.py --pdf writes Doc/manual/pdf_build.json (the git trees of the
    manual's sources and images, uncommitted changes, each PDF's SHA-256);
    make_release takes the PDFs only when they match HEAD, and BUILD.txt
    records the full commit, the manual's tree and the PDFs' SHA-256.
  - Doc/design/gui.md no longer calls R2025a the minimum; test_run removes
    its temporary folder from the path before deleting it (no path
    warning); the manual's FAQ says what makes a unit run again and how
    inputs are protected.
- **Main window on MATLAB's screen.** With several screens, SeeCAT opens
  centred on the screen that shows the MATLAB desktop
  (seecat.gui.matlab_screen: the Java desktop before R2025a; on Windows the
  desktop window's process; else the screen under the pointer), and smaller
  than 1280×820 if that screen is small.
- **Release without tests.** The release zip no longer contains `tests/`
  (unit tests, fixtures, test-data scripts); they stay in the repository.
- **PDF manual layout.** A cover, a contents page with page numbers (a
  second pass reads each heading's page with pdftotext), running headers
  with the chapter and page numbers, chapter openers, booktabs tables and
  Noto Serif/Sans (SC for Chinese) type; the HTML manual is unchanged.
  Screenshots are retaken full-resolution and checked against the window's
  own content, so another window in front can no longer end up in them
  (the main-window picture showed a PDF reader); pages start at the top,
  help and log match each picture. The manual no longer mentions DPABI.
  The help column shows tick-box defaults as on/off.
- **Fixes from the 2026-11-05 review** (regression tests in
  tests/unit/test_audit.m, tests/gui/page_drafts.m):
  - *Resume checked only the options.* A finished unit is now skipped only
    if its inputs are unchanged too (seecat.util.input_fingerprint: the
    planned unit, e.g. the selected maps and participant values, and the
    size and date of every input file) and every output in its manifest
    still exists; otherwise it runs again and the log says why.
  - *fMRIPrep with smoothing but no denoising* wrote the smoothed series
    next to the fMRIPrep input and kept the non-steady-state frames. The
    smooth step now always writes into the work folder and drops the same
    leading frames as the denoise step.
  - *Image covariates* reused the first voxel's df everywhere. The residual
    traces and df are computed per voxel (p values use each voxel's df,
    RFT the smallest), and voxels where an image covariate is constant or
    collinear are left out with a warning.
  - *ComBat with one feature, CovBat with one component* gave NaN maps
    reported as "ok". Without spread across features the empirical Bayes
    prior is skipped (as neuroHarmonize does); the EB iteration is capped;
    non-finite results are an error, never written.
  - *CovBat with a reference site* changed the reference site's data; the
    component scores are now mapped onto the reference site too.
  - *Same unit for two inputs* (one run at two resolutions, .nii and
    .nii.gz): an error before anything is written. Seed FC, Degree and
    Gradients get `res` (Resolution label) to choose.
  - *Contrast names* that differ only in punctuation or case (A-B, AB) gave
    one set of files; now an error naming them. Seed names must differ
    ignoring case.
  - *SliceTiming* now follows SliceEncodingDirection (k as is, k- reversed;
    i/j an error) via seecat.bids.slice_times.
  - *Statistics and Harmonize* accepted sessions, task and runs but ignored
    them; they now narrow the maps (an error if they contradict Maps).
  - *Page settings* were lost when switching pages in the window; each
    pipeline page keeps them for the session.
  - *Number fields* read "10mm" as 10 and "1/2" as [1 2]; the whole text
    must now be numbers.
  - *4D NIfTI* outputs carry the TR in the header (pixdim(5), seconds).
  - *Run logs* of two runs started in the same second no longer share a
    name.
  - *Statistics and Machine Learning Toolbox* was needed for automatic
    dummy-scan detection (`mad`); replaced with base MATLAB, and a test
    checks that SeeCAT's code calls no other toolbox.
  - combat_gam is described as what it is: ComBat with fixed-df natural
    splines fitted by least squares, not the same as neuroHarmonize's
    penalised GAMs.
  - Manual: Overwrite does recompute; per-run maps are .nii.gz; Sources;
    slice timing support; PDF pages (tall figures fit a page, table headers
    repeat, PDF bookmarks).
- **No hard MATLAB minimum.** SeeCAT is developed and tested on R2025a;
  on older releases it now runs and notes once that they are untested,
  instead of stopping.
- **Parallel workers default to auto** on every page and in batch
  configurations (`n_workers = 'auto'`): as many workers as memory and
  cores allow. One-unit runs (Harmonize, Statistics without TFCE), too
  little memory, or no Parallel Computing Toolbox still run serially
  without a pool; 0 keeps the computer free.
- **User manual, English and Chinese** (Doc/manual: HTML with a language
  chooser, and SeeCAT_Manual_EN.pdf / SeeCAT_Manual_ZH.pdf in the release).
  Overview, concepts, every module with its algorithm, every option (tables
  generated from the software's own form descriptions), inputs and outputs,
  batch scripting, an output reference, and worked examples on a public
  three-site dataset (30 subjects) with screenshots of the real runs. The
  Manual button opens it. Sources and build script in Doc/manual/src
  (python build.py --pdf); the PDFs are not kept in git and the release
  script adds them.
- **Harmonize: small-site warning.** With fewer than 20 subjects in a site,
  the variance step of combat, combat_nonparam, combat_noeb, combat_gam and
  covbat makes later tests of the kept covariates too liberal (Nygaard et
  al. 2016): in the manual's example, a GM-age regression on ComBat VBM maps
  found 3 false clusters, none with combat_mean, lm, or unharmonised maps
  with site as a covariate. The log and report now say so, and the Method
  help recommends combat_mean or lm for small samples.
- **Fixed: Harmonize runs overwrote each other.** All runs used the unit
  `harmonizeComBat`, so harmonising a second measure deleted the first
  one's maps. The unit is now named by the maps too
  (`harmonizeComBat_PCCz`), with its report and map list in
  group/<unit>/.
- **Parallel pool retry.** When a pool of the chosen size does not start
  (e.g. 30 workers on Windows), SeeCAT retries with half and logs it.
- **Fixed:** blank lines between paragraphs of the option descriptions
  were lost; the titles of the QC report's strip plots overlapped.
- **Fixed: leaving the QC reports page broke the window.** The page's Save
  decisions button was stored in the same variable as the toolbar's Save
  button (nested functions share the launcher's variables); every page
  opened afterwards stopped with "Unrecognized property 'Visible'". A unit
  test now rejects page functions that assign a window variable, and
  tests/gui/page_switch.m visits every page from every other page (110
  switches) and uses each one.
- **Registration QC.** Each run report gives the Dice of the brain mask
  with the template brain (normalisation), the correlation and Dice of the
  normalised GM/WM/CSF with SPM's TPM, and the Dice of a brain mask from the
  mean EPI's own intensity with the T1w brain (EPI-T1w alignment). A brain
  Dice below `qc.min_brain_dice` (0.85) suggests exclusion; outliers within
  a site are warnings. fMRIPrep runs use fMRIPrep's tissue maps. On 6 DIDA
  runs (3 sites): brain Dice 0.956-0.983, GM r 0.64-0.74, EPI-T1w Dice
  0.85-0.92. A GM/WM contrast measure of the mean EPI was tried and dropped:
  at 3 mm it was near zero on 4 of 6 runs.
- **Image quality metrics (MRIQC) in Preprocessing (`qc.iqm`, on).** BOLD:
  tSNR, SNR, FBER, EFC, ghost-to-signal (x, y), standardised DVARS, FD,
  AFNI outlier ratio and quality index, global correlation, smoothness; T1w:
  CNR, CJV, SNR (tissue, Dietrich), EFC, FBER, bias-field median and range,
  WM-to-max, volume fractions, partial-volume residuals, smoothness, TIV.
  Computed from what preprocessing already makes (segmentation,
  realignment, coregistration), on the raw data without slice timing.
  The formula-based IQMs equal MRIQC 24.0.2's own functions on the same
  inputs (fixtures in tests/fixtures/iqm); AFNI-based ones (aor, aqi, gcor,
  fwhm) are re-implemented from their definitions.
- **QC exclusions.** The group QC report now shows largest translation and
  rotation, coverage of the template brain (total, top, bottom), the IQM
  distributions per site, and writes reports/qc_exclusions.tsv: runs that
  break a rule (`qc.max_translation` 3 mm, `qc.max_rotation` 3 deg,
  `qc.max_mean_fd` 0.5 mm, too little data, `qc.min_coverage` 0.9) are
  suggested for exclusion, IQM outliers within a site are warned about. The
  QC reports page lists every run with these numbers and an Exclude box;
  saved decisions survive a new run. Seed FC, Degree, Gradients, Harmonize
  and Statistics leave excluded runs out (`qc_exclusions`, on) and log them.
- **VBM maps (`vbm.enable`).** The T1w segmentation also writes GM/WM/CSF
  normalised to IXI549Space (1.5 mm), modulated or not, and smoothed
  (desc-modulatedSm8). Tissue volumes and TIV are written for every T1w
  (reports/anat_volumes.tsv); Statistics and Harmonize can use tiv_ml as a
  covariate directly.
- **Parallel workers 'auto' chooses by memory.** seecat.util.auto_workers
  estimates the memory of one task (from the largest run and brain mask,
  the node count for gradients, the maps for TFCE) plus 1 GB per worker and
  what the main MATLAB keeps, and starts as many workers as fit in 85 % of
  the free memory (at most one per core and per task; fewer than 2 means
  serial). The log shows the estimate. Pools now give each worker
  cores/workers threads: 5 gradient workers on 32 cores took 68 s instead of
  275 s with one thread each (134 s serial).
- **Gradients: group alignment iterates.** It starts from the gradients of
  the group-mean matrix (also written as desc-grad<k>_groupmatrix) and then
  updates the reference to the mean of the aligned runs, as procrustes
  does (up to 10 rounds, tolerance 1e-5).
- **Gradients page (`gradient` pipeline).** Connectivity gradients by
  diffusion map embedding with BrainSpace's steps (top-10% row sparsity,
  normalized-angle or cosine affinity, alpha 0.5). Nodes are voxels of a
  coarser MNI grid (node size 3-12 mm, in a grey-matter, brain or own mask)
  or atlas parcels. Runs are aligned to the gradients of the group-mean
  matrix (default) or to each other (generalized Procrustes). Writes
  desc-grad<k><nodes> maps per run, the group reference and a table of
  eigenvalues. Checks free memory first. The embedding equals the exact
  diffusion map to 1e-10; BrainSpace differs from it by up to 0.4% (it runs
  a symmetric eigensolver on the row-normalised matrix); Procrustes equals
  BrainSpace's.
- **Harmonize page (`harmonize` pipeline).** Multi-site harmonisation of
  per-subject maps between the measures and Statistics: ComBat with
  parametric or non-parametric empirical Bayes, without EB, location only,
  ComBat-GAM (spline covariates), CovBat, and linear regression; optional
  reference site. Results equal neuroCombat's (fixtures in
  tests/fixtures/combat). Writes desc-<name>ComBat maps and reports the
  share of voxels with a site effect before and after.
- **Statistics: TFCE correction (`tfce_fwe`).** Threshold-free cluster
  enhancement with voxel FWE p from permutations (Freedman-Lane; sign
  flips, row permutations or swaps within subjects by design), as FSL
  randomise. `tfce.n_perm` (5000), `tfce.E`, `tfce.H`. Writes the TFCE map,
  -log10 FWE p, the thresholded map and a cluster table. Parallel workers
  now share the permutations (a single-unit pipeline runs on the client).
- **Statistics: Maps as fixed fields.** Map (desc), Statistic, Suffix,
  Space, Task and Other replace the key=value text; each lists the values
  found in the derivatives folder, and a line counts the matching maps.
- **Help everywhere.** Every option of every page has a full description
  with examples; the help column scrolls, and each page has a longer
  overview there.
- **Parallel workers: auto.** Every pipeline takes `n_workers = 'auto'`
  (all workers of the default cluster profile) besides 0 (serial) and a
  number.
- **Mask and smoothing controls.** The Mask of Degree and Statistics is a
  menu (grey matter, whole brain, mask file) with a file button; Degree's
  map smoothing has an On box (off = `smooth_fwhm` 0). The Degree page and
  the shared Output/Selection/Run options have full descriptions with
  examples.
- **Fixed: viewer.** Going from Mosaic back to Orthogonal left the mosaic
  over the top-left view (a hidden axes still shows its image), which also
  hid later redraws such as a new colour map. hot and gray colour maps no
  longer start at black, so voxels just above the threshold stay visible.
- **Fixed: Degree run failed with "distance_edges must be increasing".**
  JSON has no Inf, so the window's config file (handed to the run) turned
  `[0 Inf]` into `[0 null]`. `save_config` now writes numbers with Inf or
  NaN as text (`"[0 75 Inf]"`) and `seecat.config` reads them back.
- **Seed table: spheres and masks side by side.** Each row has a Type
  (Sphere or Mask). A sphere takes its centre as one "x y z" cell and a
  radius; a mask takes a NIfTI file. Add sphere, Add mask files (several at
  once, named after the files), Choose file (for the selected row) and
  Remove replace the old Add row button and typed paths. A Check column
  says what a row still needs, and Run refuses a bad row with that message.
  The table spans the card's width.
- **DICOM to BIDS: resting-state names and reruns.** The default BOLD rule
  also knows RS as a word (`ge_func_..._RS`, `RS_bold`). A series that
  matches no rule but looks like BOLD (2D EPI, 20+ volumes, not diffusion)
  is reported as such, and the window's log lists every series that was not
  converted. Converting again into the same dataset keeps the images
  already there and adds the missing ones, instead of stopping; `overwrite`
  still replaces them.
- **DICOM to BIDS finds subjects in any common folder layout.**
  `seecat.bids.scan_dicom` reads the first and last file of each DICOM
  folder with a new fast header reader (`seecat.bids.dicom_header`) and
  groups folders by PatientID, or by the folder tree when IDs are missing or
  anonymised. One folder per subject, modality folders with subject folders
  inside (T1/S001, REST/S001) and deeper trees (S001/visit1/T1) all work;
  the label is the folder that holds all of a subject's files. A folder
  mixing two patients is an error, and folders without DICOM are skipped.
  The DICOM page has a Find subjects button that lists the subjects and
  their folders before converting.
- **DICOM to BIDS: help for each field.** Like the pipeline forms, every field
  has an info icon; clicking it, or editing the field, shows a description
  with examples, the default and the matching `from_dicom` argument in the
  help column. `tests/gui/smoke.m` checks the icons.
- **DICOM to BIDS: automatic subject and session labels.** With no subject,
  each folder in the DICOM folder becomes a subject named after the folder
  (letters and digits); a folder of one person's series (same PatientID) or a
  folder with DICOM files is one subject. With no session, a subject with
  several studies gets ses-1, ses-2, ... by study time and a single study no
  session folder; studies keep their session across conversions
  (`code/seecat/from_dicom_sessions.tsv`). A failing subject is reported and
  the others still convert. The report table gains `subject` and `session`
  columns; the DICOM page explains the empty fields.
- **Release.** `tools/make_release.m` builds `SeeCAT-<version>.zip` from the
  files committed at HEAD, with dcm2niix v1.0.20260724 for Windows, macOS and
  Linux (each zip's size and SHA-256 checked), a version stamp, `BUILD.txt`
  and `SHA256SUMS.txt`. `LICENSE` (GPL-3.0-or-later), `THIRD_PARTY_NOTICES`
  and `README.md` added. `find_dcm2niix` makes the bundled macOS/Linux binary
  executable.
- **4D data check.** Viewer: a "Time series" drawer tab for 4D images —
  Play, a volume slider, the cursor's signal (voxel, 6 mm sphere or global
  mean) above framewise displacement with flagged frames shaded, click to
  pick a volume, Export TSV; a BOLD series is drawn in grey instead of the
  underlay. Main window: a "Data check" page listing every run's volumes,
  TR, mean/max FD and flagged frames, highlighting high-motion runs, with
  Open in viewer and QC report. New `seecat.qc.motion`, `seecat.qc.runs`,
  `seecat.io.nii_info` (header only, also .nii.gz). Slices are now cut from
  the layer index per view, which made every viewer redraw faster.
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
- **Minimum MATLAB is R2025a** (was R2020b); development and testing use
  R2025a only. `SeeCAT` and `seecat.run` stop with a clear error on older
  releases (`seecat.util.check_matlab`). Workarounds for older releases were
  removed, including the extra hint line on the DICOM to BIDS page.
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

- `fmriprep` pipeline (`seecat.config('fmriprep')`): denoises fMRIPrep outputs
  with SeeCAT's censoring and the prep pipeline's denoise and smooth steps
  (now shared as `seecat.steps.*`, `seecat.util.denoise_defaults`,
  `seecat.denoise.censor_columns`, `seecat.util.publish_output`). Drops
  fMRIPrep's leading non-steady-state volumes and replaces its motion outlier
  flags by SeeCAT's own. Reads current and older fMRIPrep naming
  (`_timeseries`/`_regressors`, `motion_outlier00`/`_00`). `acompcor` now uses
  the first `acompcor_n` components per tissue.
  - ds002785, 5 subjects (fMRIPrep outputs from OpenNeuro): ~1 min per subject.
    PCC–mPFC r = 0.57–0.74 (SeeCAT's own preprocessing: 0.60–0.86); PCC seed
    maps of the two routes correlate spatially at 0.62–0.70.
  - Fed SeeCAT's own prep outputs (same file naming), it reproduces prep's
    denoised and smoothed series exactly (difference 0), and prep's outputs
    are unchanged by the refactor (difference 0, confounds byte-identical).
  - `tests/unit/test_fmriprep.m` (4 tests, synthetic fMRIPrep folder).

- `fc` and `degree` pipelines (`seecat.config('fc')`, `seecat.config('degree')`)
  on SeeCAT derivatives from prep or fmriprep, censored frames dropped.
  `seecat.conn.degree` computes the correlation network in blocks, all signs,
  metrics and distance bins in one pass; `seecat.conn.seed_fc`;
  `seecat.conn.load_series`; `seecat.bids.derivative_units`.
  - Same results as SeeCAT 1.0 on the legacy baseline input (sub-11061,
    67,541 voxels): degree and strength equal within float32 storage, z maps
    within 1.2e-7, seed FC within 6e-8. Degree takes 35 s instead of ~20 min.
  - ds000030, 9 subjects: FC 37 s, degree 2 min in total on 4 workers.
  - Config lists of records (e.g. `seeds`) merge correctly, from structs and
    from JSON with different fields per record.
  - `tests/unit/test_conn.m` (4 tests; degree against a brute-force loop over
    signs, metrics, local exclusion and distance bins).

- `stat` pipeline (`seecat.config('stat')`; Doc/design/stat.md): designs
  one_sample, two_sample, paired, anova1, anova1_rm, regression (all
  regressors in one model, S8) and custom (design TSV); covariates from
  participants.tsv (numeric centred, text as centred dummies); image
  covariates fitted voxel-wise; ReML non-sphericity (default for anova1_rm,
  `variance = 'unequal'` for the others); inference cluster FWE (CDT p 0.001),
  voxel FWE and voxel FDR, T contrasts at alpha/2 when two-tailed; outputs
  under `group/<name>/` (t/F, Z, −log10 p, effect, thresholded maps, cluster
  index, cluster tables, design.tsv, report.json) with JSON metadata and the
  1.0 header string. New code: `seecat.stat.{glm, design, reml, smoothness,
  inference}`; RFT p-values from SPM's functions (S1).
  - Against SPM (ds000030 PCC zFC, CONTROL 5 vs SCHZ 4 with age;
    `tests/validation/compare_stat_spm.m`): same 45,763 mask voxels, T within
    8e-7 (float32), betas 5e-8, df equal, FWHM and resels equal to 8 digits,
    height threshold equal, all 329 rows of SPM's results table equal (peak T,
    Z, p FWE, coordinates, cluster sizes, cluster p).
  - Within-subject ANOVA with dependence and unequal variance
    (`tests/validation/compare_reml_spm.m`): same 1,562 first-pass voxels,
    covariance V within 5e-12, df equal, F within 3e-7, FWHM equal.
  - one_sample, paired, anova1 and regression (age, with gender as covariate)
    through the whole pipeline against SPM's t1, pt, anova and mreg designs
    (`tests/validation/compare_designs_spm.m`): same mask voxels; statistic
    maps within 5e-7 (relative); df equal; FWHM and resels equal (to 1e-9);
    every row of SPM's results table at p < 0.001 equal (220, 49, 38, 48
    rows: peak statistic 3e-6, Z 5e-6, peak p FWE 8e-7, coordinates and
    cluster sizes exact).
  - 1.0's `T2_zFCSeed01_CONvsSCHZ` (10 subjects, same mask): T equal at all
    67,541 voxels (9.5e-7). Smoothness differs (FWHM ~12.0 vs 10.6 mm):
    1.0 used FSL smoothest's estimator, 2.0 SPM's, so RFT thresholds differ
    from 1.0.
  - Config: selector structs with free fields (e.g. `stat.maps`) are allowed.
  - `tests/unit/test_stat.m` (6 tests).

- QC report (`seecat.qc.run_report`, `seecat.qc.group_report`; design 5.7):
  per-run HTML pages and a dataset page for prep and fmriprep, drawn without
  MATLAB graphics. `seecat.run` calls an optional `seecat.<pipeline>.finish`
  after all units. On ds000030 sub-11061: r(FD, DVARS) 0.79 before and −0.05
  after denoising (kept frames), DVARS median 2.1 % → 0.51 %.
- Step-level resume now includes the step's source code in its key: after an
  update, a changed step runs again instead of reusing a result made by the
  old code (found when a confounds step from before the shared-step refactor
  was reused and the outputs step failed).

- New GUI (design gui.md, accepted): `SeeCAT` opens the main window
  (`seecat.gui.launcher`) with a form per pipeline generated from
  `seecat.<pipeline>.gui()` (a test checks every option is covered),
  Load/Save config, Run in a separate MATLAB process with a live log, the
  summary and the QC page; DICOM-to-BIDS and QC panels.
- Viewer (`seecat.viewer`, model `seecat.view.Model`): orthogonal views or
  montage, layers with threshold by statistic or p, voxel/cluster FWE and FDR
  through `seecat.stat.inference` (same clusters as the stat pipeline;
  checked), cluster table with atlas labels, 1.0 header fallback, underlay by
  data space (ch2 / MNI 2009c), neurological or radiological display,
  export PNG and thresholded map. Atlases: SPM Neuromorphometrics, BrainNet
  2.0 AAL/Brodmann, user atlases.
- BrainNet Viewer 2.0 hook (`seecat.view.surface`): writes a Scene JSON
  (ICBM152 smoothed surface, thresholded map, trilinear projection) and opens
  it in BrainNet or renders a PNG.
- GUI restyle (gui.md, "Visual style"): one theme and SeeCAT's own icons and
  logo for both windows. Main window: grouped side bar, section links that
  scroll the card form, help column for the option being edited, run status
  with progress, Log | Summary drawer. Viewer: Orthogonal / Single / Mosaic
  layouts, cursor read-out with p value and atlas label, colour bar on one
  scale for all views (the overlay was scaled per slice before), Threshold
  and Go to cards, cluster table docked and numbered by size.
- Removed: every 1.0 GUIDE window (`SeeCAT.fig`, PrepfMRI, FuncConnect,
  VoxDeg, Stat, Visual, Calculator — calculator returns in 2.1),
  `sc_check_dpabi.m`, `jobmats`, `dcm2nii`, the 1.0 atlas and label files, and
  unused underlays; ch2, ch2better and MNI 2009c are now `.nii.gz`. The 1.0
  phase-0 tests of removed code are dropped (band-pass tests kept in
  `test_bandpass.m`).
- Tests: `test_gui.m`, `test_view.m`; desktop smoke script `tests/gui/smoke.m`
  (all windows open, form round trip, screenshots).

### Known issues

## Phase 0 fixes on top of 1.0 beta (part of 2.0.0)

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

### Changed
- **Minimum MATLAB is R2025a** (was R2020b); development and testing use
  R2025a only. `SeeCAT` and `seecat.run` stop with a clear error on older
  releases (`seecat.util.check_matlab`). Workarounds for older releases were
  removed, including the extra hint line on the DICOM to BIDS page.

### Added
- **DICOM to BIDS finds subjects in any common folder layout.**
  `seecat.bids.scan_dicom` reads the first and last file of each DICOM
  folder with a new fast header reader (`seecat.bids.dicom_header`) and
  groups folders by PatientID, or by the folder tree when IDs are missing or
  anonymised. One folder per subject, modality folders with subject folders
  inside (T1/S001, REST/S001) and deeper trees (S001/visit1/T1) all work;
  the label is the folder that holds all of a subject's files. A folder
  mixing two patients is an error, and folders without DICOM are skipped.
  The DICOM page has a Find subjects button that lists the subjects and
  their folders before converting.
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
