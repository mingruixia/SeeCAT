function ctx = step_masks(ctx, ~, log)
% Masks in output space, from the subject's own segmentation:
%   brain  GM + WM + CSF > 0.5, inside the BOLD field of view (every frame
%          non-zero)
%   wm     the native-space WM mask (step_tissue_masks) resampled, > 0.5,
%          inside the brain
%   csf    the same for CSF

[P, V] = seecat.io.read_nii({ctx.files.wc1, ctx.files.wc2, ctx.files.wc3}, 'Class', 'single');
Vb = spm_vol(ctx.files.wbold);
covered = true(Vb(1).dim);
for k = 1:numel(Vb)
    y = spm_read_vols(Vb(k));
    covered = covered & isfinite(y) & y ~= 0;
end
brain = sum(P, 4) > 0.5 & covered;
wm = seecat.io.read_nii(ctx.files.wnative_wm) > 0.5 & brain;
csf = seecat.io.read_nii(ctx.files.wnative_csf) > 0.5 & brain;
if nnz(wm) < 10 || nnz(csf) < 10
    error('SeeCAT:prep', ['WM (%d) or CSF (%d) mask has fewer than 10 voxels on the output grid; ' ...
        'check the segmentation, or lower masks.erode_mm.'], nnz(wm), nnz(csf));
end

names = {'brain', 'wm', 'csf'};
masks = {brain, wm, csf};
for i = 1:3
    f = fullfile(ctx.work_dir, ['mask_' names{i} '.nii']);
    seecat.io.write_nii(uint8(masks{i}), V(1), f, 'DataType', 'uint8');
    ctx.files.(['mask_' names{i}]) = f;
end
log('masks: brain %d, WM %d, CSF %d voxels', nnz(brain), nnz(wm), nnz(csf));
end
