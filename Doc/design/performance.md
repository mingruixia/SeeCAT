# Computation speed: review and options (plan, not yet done)

Status: plan only, written 2026-11-09 from a code review and a literature
search. Nothing here is implemented or measured; the speed-up figures are
estimates. Measure first (step 0) before changing code.

Reference machine: 64 cores, 256 GB RAM, NVIDIA RTX 3080 Ti (12 GB; strong
in single precision, double precision about 1/64 of it, so a GPU only pays
off in single precision).

## Where the time goes

| Module | Main cost | Parallel now | Room |
|---|---|---|---|
| Degree | thresholding and summing the voxel x voxel correlation matrix, block by block (`+conn/degree.m`) | over runs (parfor, threads shared per worker); BLAS multithreaded | large |
| Statistics, TFCE | ~100 connected-component labellings (`spm_bwlabel`) per permutation and contrast (`+stat/tfce.m`, `+stat/permutation.m`) | over permutations | large |
| Statistics with image covariates | voxel-by-voxel loop that recomputes n x n products at every voxel (`+stat/glm.m`, `traces`, F contrast) | none | large, exact |
| Gradients | `R*R'` (n^3), `acos` over n^2, `eigs` (`+gradient/embed.m`) | over runs; single precision above 8000 nodes | medium (GPU) |
| Preprocessing | inside SPM (realign, segment, normalise) | over units, memory-aware worker count | small |
| .nii.gz I/O | MATLAB `gzip`/`gunzip` are single-threaded | none | medium for large 4D files |

Not worth the effort: Seed FC (one seeds x voxels product), denoising
(blocked and vectorised), ComBat, QC.

## Tier 1: same results, no new dependency, low risk

1. Degree (estimate 3-5x)
   - Symmetry: compute only blocks on and above the diagonal and add both
     row and column sums; halves the GEMM and the element-wise work.
   - Absolute = positive + negative (exact for threshold >= 0): when all
     three signs are asked, skip the third pass.
   - Fewer full-size temporaries: no copy `S` per sign; compute the
     distance-bin index once per block instead of `dist > lo & dist <= hi`
     per map. The step is memory-bandwidth bound, not flop bound.
   - Optional: single-precision correlations, with the pairs within +-1e-5
     of the threshold recomputed in double, so binary counts stay identical.
2. Image covariates in statistics (estimate >10x on that path)
   - Move `Vw*Vw` and `trace(Vw)` out of the voxel loop in `traces`.
   - Rewrite the F-contrast `trace(M*Vw*M*Vw)` with k x k products.
   - Closed form when V = I: trRV = trRVRV = n - p.
   - The rank check runs twice (`stat/run_unit` and `glm`): once is enough.
   - Batch the remaining per-voxel `pinv` with `pagemtimes`/`pagesvd`
     (R2025a); vectorise the per-voxel `spm_Fcdf` `arrayfun`.
3. I/O
   - Keep intermediate files uncompressed; gzip only the published outputs.
   - Lower compression level, or `pigz` when found (optional, fallback as now).

## Tier 2: optional GPU (Parallel Computing Toolbox + NVIDIA)

Detect with `canUseGPU`, fall back to the CPU. One worker per GPU (workers
sharing one card compete). No GPU support in MATLAB on Apple Silicon.

- Degree: move the series (T x V single, ~160 MB at 2 mm) to the GPU once;
  per block correlate, threshold and sum there (fused `arrayfun`), return
  only V x K sums. Estimate >10x over 64 CPU cores at 2 mm (~200k voxels).
- Gradients: `R*R'` and `acos` on the GPU in single (already single above
  8000 nodes, so no new loss). `eigs` stays on the CPU.

## Tier 3: TFCE, optional (changes the method or adds maintenance)

- Tail approximation (Winkler et al. 2016, in PALM): a few hundred
  permutations, generalised Pareto fit to the tail of the max distribution;
  recommended there for FWE, up to ~100x faster. Approximate p values: offer
  as a "fast" option, default stays full permutation.
- Union-find TFCE in one sweep (eTFCE preprint 2026: ~50 % faster; pytfce's
  Python version slower). Real gains need a C MEX built per platform, which
  conflicts with "SPM only"; not recommended.
- Small exact gains: label each level only within the bounding box of its
  supra-threshold voxels; compute the GLM statistic of many permutations in
  one GEMM.

## Order

0. Time the current version on public test data at 3 mm and 2 mm: Degree,
   Gradients, TFCE statistics (the logs already print "degree: ... in X s",
   "gradients of ... in X s", "TFCE: ... s").
1. Tier 1, checked by the unit tests (results must not change).
2. Tier 2 and the TFCE fast option, as options; defaults unchanged.

## Sources

- Winkler et al. 2016, Faster permutation inference in brain imaging, NeuroImage 141: https://pmc.ncbi.nlm.nih.gov/articles/PMC5035139/
- PALM faster inference: https://fsl.fmrib.ox.ac.uk/fsl/docs/statistics/palm/faster_inference.html
- Craddock & Clark 2016, optimized voxel-wise degree centrality in AFNI: https://www.biorxiv.org/content/10.1101/067702.full.pdf
- Wang et al. 2013, CPU-GPU voxel-wise connectome, PLOS ONE: https://ideas.repec.org/a/plo/pone00/0062789.html
- Eklund et al. 2014, BROCCOLI: https://pmc.ncbi.nlm.nih.gov/articles/PMC3953750/
- eTFCE preprint: https://arxiv.org/html/2603.03004v1 ; hybrid eTFCE-GRF: https://arxiv.org/abs/2603.11344 ; pytfce: https://pypi.org/project/pytfce/
- MATLAB GPU functions: https://blogs.mathworks.com/matlab/?p=2750 ; eigs on GPU: https://au.mathworks.com/matlabcentral/answers/572377-accelerate-eigs-with-gpu
