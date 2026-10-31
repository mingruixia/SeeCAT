function ctx = step_tissue_masks(ctx, opt, log)
% WM and CSF masks in the native space of the segmentation (the T1w, or
% the mean EPI without one): probability > threshold, then eroded by
% opt.erode_mm with a ball. The normalise step resamples them to the output
% grid. Built here rather than on the output grid so that they do not
% depend on the output voxel size (on ds000030 a 3 mm-grid CSF mask had 35
% voxels, a 2 mm-grid one 389, and the CSF signals correlated 0.80-0.84).
% When erosion leaves fewer than 100 mm^3, the uneroded mask is used and
% the log says so.

names = {'wm', 'csf'};
src = {ctx.files.c2, ctx.files.c3};
thr = [opt.wm_threshold, opt.csf_threshold];
for i = 1:2
    [p, V] = seecat.io.read_nii(src{i}, 'Class', 'single');
    vox = sqrt(sum(V(1).mat(1:3, 1:3) .^ 2));
    m0 = p > thr(i);
    m = erodeBall(m0, opt.erode_mm, vox);
    if nnz(m) * prod(vox) < 100
        log('tissue masks: %s mask after %g mm erosion is %.0f mm^3; using it uneroded (%.0f mm^3)', ...
            upper(names{i}), opt.erode_mm, nnz(m) * prod(vox), nnz(m0) * prod(vox));
        m = m0;
    end
    f = fullfile(ctx.work_dir, ['native_' names{i} '.nii']);
    seecat.io.write_nii(single(m), V(1), f);
    ctx.files.(['native_' names{i}]) = f;
    log('tissue masks: native %s %.1f cm^3', upper(names{i}), nnz(m) * prod(vox) / 1000);
end
end

function e = erodeBall(m, r, vox)
% A voxel stays when every voxel within R mm of it is in the mask
if r <= 0
    e = m;
    return
end
n = floor(r ./ vox);
[x, y, z] = ndgrid(-n(1):n(1), -n(2):n(2), -n(3):n(3));
ball = single((x * vox(1)) .^ 2 + (y * vox(2)) .^ 2 + (z * vox(3)) .^ 2 <= r ^ 2);
outside = convn(single(~m), ball, 'same');
e = m & outside < 0.5;
% Voxels near the image edge see "outside" only through the padding zeros,
% which convn treats as inside; the edge is never tissue in practice.
end
