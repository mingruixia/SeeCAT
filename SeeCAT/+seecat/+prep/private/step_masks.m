function ctx = step_masks(ctx, opt, log)
% Masks in output space, from the subject's own segmentation:
%   brain  GM + WM + CSF > 0.5, inside the BOLD field of view (every frame
%          non-zero)
%   wm     WM > wm_threshold inside the brain, eroded opt.erode voxels
%   csf    CSF > csf_threshold inside the brain, eroded likewise
% When erosion would leave fewer than 10 voxels, the uneroded mask is used
% and the log says so.

[P, V] = seecat.io.read_nii({ctx.files.wc1, ctx.files.wc2, ctx.files.wc3}, 'Class', 'single');
Vb = spm_vol(ctx.files.wbold);
covered = true(Vb(1).dim);
for k = 1:numel(Vb)
    y = spm_read_vols(Vb(k));
    covered = covered & isfinite(y) & y ~= 0;
end
brain = sum(P, 4) > 0.5 & covered;
wm = tissueMask(P(:, :, :, 2) > opt.wm_threshold & brain, opt.erode, 'WM', log);
csf = tissueMask(P(:, :, :, 3) > opt.csf_threshold & brain, opt.erode, 'CSF', log);

names = {'brain', 'wm', 'csf'};
masks = {brain, wm, csf};
for i = 1:3
    f = fullfile(ctx.work_dir, ['mask_' names{i} '.nii']);
    seecat.io.write_nii(uint8(masks{i}), V(1), f, 'DataType', 'uint8');
    ctx.files.(['mask_' names{i}]) = f;
end
log('masks: brain %d, WM %d, CSF %d voxels', nnz(brain), nnz(wm), nnz(csf));
end

function m = tissueMask(m0, n, name, log)
m = erodeN(m0, n);
if nnz(m) < 10
    log('masks: %s mask after %d-voxel erosion has %d voxels; using it uneroded (%d voxels)', ...
        name, n, nnz(m), nnz(m0));
    m = m0;
end
end

function m = erodeN(m, n)
for k = 1:n
    m = erode6(m);
end
end

function e = erode6(m)
% A voxel stays when it and its six face neighbours are all in the mask
e = m;
e(2:end, :, :) = e(2:end, :, :) & m(1:end-1, :, :);
e(1:end-1, :, :) = e(1:end-1, :, :) & m(2:end, :, :);
e(:, 2:end, :) = e(:, 2:end, :) & m(:, 1:end-1, :);
e(:, 1:end-1, :) = e(:, 1:end-1, :) & m(:, 2:end, :);
e(:, :, 2:end) = e(:, :, 2:end) & m(:, :, 1:end-1);
e(:, :, 1:end-1) = e(:, :, 1:end-1) & m(:, :, 2:end);
e([1 end], :, :) = false;
e(:, [1 end], :) = false;
e(:, :, [1 end]) = false;
end
