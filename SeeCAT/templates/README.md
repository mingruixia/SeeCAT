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

They replace the DPABI-distributed `BrainMask_05`, `GreyMask_02`,
`WhiteMask_09`, `CsfMask_07` and `GMwithoutCER` (61x73x61), removed in
2.0. The thresholds are the same, but SPM12/25's TPM is sharper than the maps
those masks came from: the GM mask has 52,276 voxels at 3 mm (was 67,541;
Dice 0.87), the brain mask 69,937 (was 70,831; Dice 0.96).

## Atlases and underlays (legacy viewer)

`aal`, `brodmann`, `Brodmann_YCG` (+ `_Labels.mat`), `ch2*` and
`mni_icbm152_*` are used only by the legacy viewer (`Visual/`). They go with
it in the viewer rewrite (roadmap weeks 7–8), where atlases are fetched at
install time with their own licences.
