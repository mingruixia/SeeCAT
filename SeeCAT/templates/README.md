# templates

## Group masks (IXI549Space, generated)

`tpl-IXI549Space_res-{2,3}_*_mask.nii` are made from SPM's tissue probability
maps (`spm/tpm/TPM.nii`) by `seecat.util.make_templates`, on the grid SPM
normalisation writes with SeeCAT's default bounding box. Each has a JSON
sidecar with its source and threshold. Regenerate with:

```matlab
seecat.util.make_templates('SeeCAT/templates', [2 3])
```

| mask | rule |
|---|---|
| `desc-brain` | GM + WM + CSF > 0.5 |
| `label-GM` | GM > 0.2 (default analysis mask of Stat, VoxDeg, FuncConnect) |
| `label-WM` | WM > 0.9 |
| `label-CSF` | CSF > 0.7 |

They replace the 1.0 masks `BrainMask_05`, `GreyMask_02`,
`WhiteMask_09`, `CsfMask_07` and `GMwithoutCER` (61x73x61), removed in
2.0. The thresholds are the same, but SPM12/25's TPM is sharper than the maps
those masks came from: the GM mask has 52,276 voxels at 3 mm (was 67,541;
Dice 0.87), the brain mask 69,937 (was 70,831; Dice 0.96).

## Underlays (viewer)

| file | what | default for |
|---|---|---|
| `ch2.nii.gz` | Colin27 single-subject T1, 1 mm (MRIcron distribution) | IXI549Space (SeeCAT prep) |
| `ch2better.nii.gz` | Colin27, 0.5 mm, skull-stripped (MRIcroGL distribution) | (selectable) |
| `mni_icbm152_t1_tal_nlin_asym_09c.nii.gz` | MNI ICBM152 2009c asymmetric average, 1 mm | MNI152NLin2009cAsym (fMRIPrep) |

Licences and credits are in `THIRD_PARTY_NOTICES` (MNI notice for Colin27
and ICBM152 2009c, MRIcron's BSD licence). SPM's canonical images and any other image can
also be used. Atlas labels come from installed sources only (SPM's
Neuromorphometrics; AAL and Brodmann from BrainNet Viewer 2.0); the 1.0
atlas files were removed (design gui.md, G4/G5).
