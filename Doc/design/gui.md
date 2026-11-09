# SeeCAT 2.0 — GUI, viewer and BrainNet hook

Status: **accepted** (2026-10-31; G5 by data space, the others as recommended). Roadmap weeks 7–8. Replaces the
1.0 GUIDE windows (`SeeCAT.m`, `PrepfMRI/`, `FuncConnect/`, `VoxDeg/`,
`Stat/`, `Visual/`, `Utilities/SeeCAT_Calculator`) and the 1.0 dependency check.

## 1. Goals

- Every GUI action is a batch-API action: the GUI builds a config, runs
  `seecat.run`, and can save the config as JSON. Nothing is computed only in
  the GUI.
- Forms stay in step with the pipelines as they change: the form for a
  pipeline is generated from a small description next to its defaults.
- A slice viewer for SeeCAT's outputs (and any NIfTI): orthogonal views,
  overlays, thresholding with the **same** inference code as the stat
  pipeline, cluster table, atlas labels, export.
- Surface display through BrainNet Viewer 2.0 when it is installed.
- Logic separate from widgets, so it can be tested headless (`-batch`
  cannot open windows).

## 2. Launcher

```
┌ SeeCAT 2.0 ─────────────────────────────────────────────────────────────┐
│ Pipelines          │ Preprocessing (prep)                    [?] [Load] │
│ ▸ DICOM → BIDS     │ ┌ Input ───────────────────────────────────────────┐│
│ ▸ Preprocessing    │ │ BIDS folder   [D:/study/bids            ] [ … ]  ││
│ ▸ fMRIPrep denoise │ │ Subjects      [01, 02 (empty = all)     ]        ││
│ ▸ Seed FC          │ └──────────────────────────────────────────────────┘│
│ ▸ Degree           │ ┌ Denoising ───────────────────────────────────────┐│
│ ▸ Statistics       │ │ Regressors    [x] Friston 24 [x] WM [x] CSF [ ] GS││
│ ─────────────────  │ │ Band (Hz)     [0.01] – [0.1]                     ││
│ ▸ Viewer           │ │ Censoring     (•) censor ( ) keep ( ) none       ││
│ ▸ QC reports       │ └──────────────────────────────────────────────────┘│
│                    │ [ Show advanced options ]                            │
│                    │ Workers [4]   [Save config…]   [ Run ]               │
│                    │ ┌ Log ─────────────────────────────────────────────┐│
│                    │ │ 10:31  sub-01 realign: finished (78 s)           ││
│                    │ └──────────────────────────────────────────────────┘│
│                    │ Summary table (after the run): unit, status, QC link │
└─────────────────────────────────────────────────────────────────────────┘
```

- Left: pipelines in workflow order, plus Viewer, Data check and QC reports.
- Right: the pipeline's form, grouped in sections; advanced options hidden by
  default; every field shows the batch name and the validator's message as a
  tooltip; invalid fields are marked before Run (`seecat.check_config`).
- `Load` / `Save config…`: JSON, the same files `seecat.run` accepts.
- Run: log lines stream into the log box; at the end the summary table,
  with links to each run's QC page and buttons to open outputs in the viewer.

### Form descriptions

Each pipeline gets `seecat.<p>.gui()` returning sections of fields:

```matlab
f = struct('path', 'denoise.band', 'label', 'Band (Hz)', 'widget', 'range', ...
           'section', 'Denoising', 'advanced', false, 'help', 'Band-pass filter ...');
```

Widgets: `folder`, `file`, `text`, `labels` (comma list), `number`,
`range`, `flag`, `choice` (with `choices`), `multi` (check boxes), `seeds`
(table), `contrasts` (table). A unit test checks that every option of
`defaults()` appears in `gui()` (or is listed as batch-only), so a new
option cannot silently miss the GUI.

### Visual style (revised 2026-10-31, after the first trial)

The first version worked but looked plain. The user chose option "A + V1"
from several mock-ups, with these additions: the main window takes the help
column, run status and log drawer of the other options; the viewer takes
the single-view layout, docked cluster table and colour bar; both windows
share one style; all text is English; the main window carries a logo.

- One theme (`seecat.gui.theme`): white cards with a 1 px outline on a
  light grey page, slate text, one accent (#3B5BDB), Segoe UI (Helvetica on
  macOS/Linux). `seecat.gui.icon` holds SeeCAT's own line icons (SVG) and the
  mark; `resources/logo_*.png` (from `tools/make_logo.py`) is the window icon.
- Main window: side bar with logo and grouped pages (Prepare, Analyse,
  Results), drawn by `resources/ui/nav.html` in a `uihtml`; header with the
  pipeline's name, one-line description, section links
  (`resources/ui/tabs.html`) and Load/Save; the form as one scrolling
  column of cards (the links only scroll to a card, nothing is hidden);
  right column with help on the option being edited (description, default,
  batch name; shown on editing or on its info icon) and the run status
  (lamp, elapsed time, units done/failed, Run/Stop, QC report); a Log |
  Summary drawer at the bottom.
- Viewer: tool bar (Open, Orthogonal | Single | Mosaic, underlay,
  Neuro | Radio, Surface, Save image, Save map); views on black with
  orientation and coordinate tags and L/R marks; cursor read-out (MNI,
  voxel, value, p, atlas label, cluster); colour bar with the shown range
  and the threshold; side cards Layers, Threshold, Go to (with Peak); the
  cluster table docked at the bottom.
- R2020b limits met on the way (history: the code was later developed and
  tested on R2025a only, and older releases are untested, not refused; the
  layout built around these limits stays): panel border colours cannot be set (cards
  are a 1 px padded grid instead); numeric `scroll` works on panels, not on
  grid layouts (the form is a fixed-height panel inside a scrollable panel);
  the uihtml browser has no flex `gap`; read-only text areas are greyed;
  the child process writes its log in the system encoding.

### 4D data check (added 2026-10-31)

Requested after the restyle: scroll through a 4D fMRI series with a slider
to check the data. Placed in two parts, so there is one viewer to maintain:

- Viewer, drawer tab "Time series" next to "Clusters". A 4D image without
  a statistic (a BOLD series) is a *series* layer: drawn in grey instead of
  the underlay, at its current volume, with no threshold. The tab has Play,
  a volume slider, the volume / time / FD read-out, and two plots sharing
  the volume axis: the cursor's signal (voxel, 6 mm sphere or global mean)
  and framewise displacement, with flagged frames shaded; a click on a plot
  picks a volume; Export TSV saves the plotted series. FD and flags come
  from the run's confounds table next to the image (`seecat.qc.motion`,
  aligned at the end when non-steady-state volumes were dropped). A volume
  step only replaces the pixels of the views (about 0.1 s in R2020b,
  0.05 s in R2025a, on a 3 mm series over the 1 mm underlay).
- Main window, Results › "Data check": a folder (BIDS dataset, SeeCAT or
  fMRIPrep derivatives) and the series kind (preprocessed, denoised, raw,
  all) give a table of runs with volumes, TR, mean and max FD and flagged
  frames (`seecat.qc.runs`, headers only via `seecat.io.nii_info`); runs
  with mean FD > 0.25 mm or > 20% flagged volumes are highlighted. "Open in
  viewer" opens the run on the Time series tab; "QC report" opens its page.

## 3. Viewer (`seecat.view`)

```
┌ SeeCAT Viewer ──────────────────────────────────────────────────────────┐
│ ┌─ sagittal ─┐┌─ coronal ──┐┌─ axial ────┐ │ Layers                      │
│ │            ││            ││            │ │ ☑ PCC zFC  t  hot  thr 3.2 │
│ │     +      ││     +      ││     +      │ │ ☐ degree   z  winter       │
│ └────────────┘└────────────┘└────────────┘ │ underlay: avg152T1 (SPM)   │
│ x [-2] y [-52] z [26] mm   t=7.12 p=2e-6   │ Threshold: (•) stat ( ) p  │
│ Label: Precuneus (Neuromorphometrics)      │ [3.20]  ± [both]  k [12]   │
│ [Orthogonal | Montage]  [Neuro | Radio]    │ Correction: [cluster FWE ▾]│
│                                            │ [Clusters…] [Surface…]     │
│                                            │ [Export PNG] [Save map]    │
└─────────────────────────────────────────────────────────────────────────┘
```

- Layers: any number of overlays, each with colormap, threshold (statistic
  or p, positive/negative/both), minimum cluster size, transparency; 4D files
  get a volume slider and the Time series tab (see 4D data check above).
- Statistic maps: df, FWHM and resels come from the JSON sidecar written by
  the stat pipeline, else from the 1.0 header string (`CAT{T_[df]}{dLh_…}`).
  p ↔ statistic conversion and corrections (voxel FWE, voxel FDR, cluster
  FWE) call `seecat.stat.inference`, so the viewer and the stat pipeline give
  the same thresholds and clusters.
- Cluster table: SPM-style (as the stat pipeline's TSV) with atlas labels per
  peak; clicking a row moves the cursor; export as TSV.
- Coordinates: mm and voxel; neurological or radiological display; crosshair
  on/off; link several viewer windows to one cursor.
- Export: current views or a montage as PNG (`exportapp`/`getframe`), the
  thresholded map or cluster mask as NIfTI.
- Model/view split: `seecat.view.Model` (layers, cursor, thresholds,
  clusters, labels; no graphics) and the window that renders it. Tests drive
  the model.

### Atlases and underlays

Atlas labels at the cursor and for cluster peaks, from sources the user
already has (nothing bundled or downloaded):

| atlas | source | condition |
|---|---|---|
| Neuromorphometrics | `spm/tpm/labels_Neuromorphometrics.nii` + `.xml` | always (SPM is required) |
| AAL, Brodmann | BrainNet Viewer 2.0 lookup files, with its provenance notice | BrainNet 2.0 on the path |
| user atlas | NIfTI + TSV (`index`, `name`) | given by the user |

Underlays (G5, decided): chosen by the space of the first overlay, so
anatomy and data line up —

| data space | default underlay |
|---|---|
| `IXI549Space` (SeeCAT prep), or unknown | `ch2` (Colin27, 1 mm) |
| `MNI152NLin2009cAsym` (fMRIPrep) | MNI ICBM152 2009c asym (1 mm) |

Also selectable: `ch2better` (Colin27, 0.5 mm, skull-stripped), SPM's
canonical images, or any image (e.g. a subject's T1w). The three underlays
stay in `templates/` as `.nii.gz`, with their licences in
`THIRD_PARTY_NOTICES` (checked against the original terms at release);
`ch2bet` and the 2009c face mask are removed. The 1.0 atlas files
(`aal`, `brodmann`, `Brodmann_YCG` with label MAT files) are removed (G4).
Comparison of the candidates: 2026-10-31, six underlays at x = −4, y = −18,
z = 10 mm; the SPM canonical images (2 mm) were too coarse.

## 4. BrainNet hook

`Surface…` in the viewer (and `seecat.view.surface(map, threshold, …)`):
writes a BrainNet Viewer 2.0 Scene JSON — the ICBM152 smoothed surface from
BrainNet's library, the current overlay mapped onto it with the viewer's
threshold and colormap — and opens it in the BrainNet desktop app, or renders
a PNG with `BrainNetRender`. Without BrainNet 2.0 on the path the button is
disabled with a tooltip on where to get it. The Scene is saved next to the
map so the figure can be reproduced.

## 5. Removed

`SeeCAT.m`/`.fig`, `SeeCAT_vbm.fig`, `PrepfMRI/` (GUI, `jobmats`,
`dcm2nii`), `FuncConnect/`, `VoxDeg/`, `Stat/`, `Visual/`,
`Utilities/SeeCAT_Calculator.*` (calculator: v2.1, roadmap),
the 1.0 dependency check, `Utilities/sc_list_subjects.m`, and the atlas
files and the unused underlays (`ch2bet`, 2009c face mask) in `templates/`. `tests/legacy_baseline` keeps running the
1.0 export outside the repository. The 1.0 tests that drive the old Stat code
(`test_p0_fixes`) move to that export too.

## 6. Testing

- Unit tests (headless): form descriptions cover every option; config ↔ form
  round trip; viewer model — reslicing, cursor ↔ coordinates, thresholds and
  clusters equal to `seecat.stat.inference`, atlas lookups at known
  coordinates, 1.0 header parsing; Scene JSON for BrainNet validated against
  its schema (when BrainNet is installed).
- Desktop smoke script (`tests/gui/smoke.m`): opens each form and the viewer,
  runs a small pipeline from the GUI, takes screenshots; run by hand on a
  desktop session, not in `-batch`.

## 7. Decisions (accepted 2026-10-31)

| # | question | recommendation | alternative |
|---|---|---|---|
| G1 | UI toolkit | `uifigure` + `uigridlayout` (resizes cleanly, the current MATLAB UI; available since R2018b; SeeCAT is developed and tested on R2025a, older releases are untested) | classic `figure` + `uicontrol` (the earlier plan; manual layout, older look) |
| G2 | forms | generated from `seecat.<p>.gui()` descriptions | one hand-written panel per pipeline |
| G3 | running from the GUI (implemented as a separate `matlab -batch` process rather than `parfeval`: inside a pool worker, seecat.run's own parfor would run serially; the separate process opens its own pool, works without the Parallel Computing Toolbox, and Stop ends it) | in a background process (`parfeval` on a process pool) when the Parallel Computing Toolbox is present, so the window stays responsive and Stop works; otherwise in the foreground with the log updating | always in the foreground |
| G4 | atlases | installed sources only (SPM Neuromorphometrics, BrainNet 2.0 AAL/Brodmann, user atlases); remove the bundled ones | download Schaefer/AAL3 etc. at first use |
| G5 | underlays | **decided:** by data space — `ch2` for IXI549Space, MNI 2009c asym for MNI152NLin2009cAsym; `ch2better`, SPM canonical images and any image selectable (section 3) | — |
| G6 | display convention | neurological (left on the left) by default, radiological as a toggle | radiological by default |
| G7 | legacy windows | remove all 1.0 GUIs now (section 5) | keep them as a "classic" menu until 2.1 |
