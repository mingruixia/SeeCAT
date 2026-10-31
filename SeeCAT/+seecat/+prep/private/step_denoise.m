function ctx = step_denoise(ctx, opt, log)
% Denoise the normalised BOLD inside the brain mask with
% seecat.denoise.clean: flagged frames (motion_outlier_* columns) are
% interpolated, data and regressors band-passed together, and the model
% fitted on good frames. The voxel's mean is added back so the image stays
% readable; voxels outside the mask are 0.

d = opt.denoise;
T = seecat.io.read_tsv(ctx.files.confounds);
[R, cols] = seecat.denoise.select_regressors(T, d.regressors);
bad = [];
if ~strcmp(opt.censor.mode, 'none')
    outl = T.Properties.VariableNames(startsWith(T.Properties.VariableNames, 'motion_outlier_'));
    bad = false(height(T), 1);
    for k = 1:numel(outl)
        bad = bad | T.(outl{k}) > 0;
    end
end

[Y, V] = seecat.io.read_nii(ctx.files.wbold, 'Class', 'single');
dim = size(Y);
nT = dim(4);
mask = logical(seecat.io.read_nii(ctx.files.mask_brain));
Y = reshape(Y, [], nT)';
y = Y(:, mask(:));
clear Y
[e, info] = seecat.denoise.clean(y, R, struct('tr', ctx.tr, 'detrend_order', d.detrend_order, ...
    'band', d.band, 'bad', bad, 'interp', opt.censor.interp));
e = e + mean(y, 1);
out = zeros(prod(dim(1:3)), nT, 'single');
out(mask(:), :) = e';
f = fullfile(ctx.work_dir, 'denoised.nii');
seecat.io.write_nii(reshape(out, dim), V(1), f);
ctx.files.denoised = f;
ctx.denoise_columns = cols;
log('denoise: %d confounds + trend order %d, %d good frames, %d dof left', ...
    numel(cols), d.detrend_order, info.n_good, info.dof);
end
