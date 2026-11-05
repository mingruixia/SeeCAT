function ctx = denoise(ctx, opt, log)
% DENOISE  Pipeline step: denoise a BOLD series with its confounds table.
%   ctx = seecat.util.run_step(ctx, 'denoise', @seecat.steps.denoise, opt, log)
%
% Uses ctx.files.wbold (4D), ctx.files.mask_brain, ctx.files.confounds
% (fMRIPrep column names), ctx.tr and, if present, ctx.first_frame (frames
% before it are skipped, e.g. non-steady-state volumes kept in an fMRIPrep
% series). OPT has the denoise and censor options.
%
% seecat.denoise.clean does the work: flagged frames (motion_outlier_*
% columns) are interpolated, data and regressors band-passed together, and
% the model fitted on good frames. The voxel's mean is added back so the
% image stays readable; voxels outside the mask are 0. Writes
% <work_dir>/denoised.nii and sets ctx.files.denoised and
% ctx.denoise_columns. Shared by the prep and fmriprep pipelines.

d = opt.denoise;
T = seecat.io.read_tsv(ctx.files.confounds);
[R, cols] = seecat.denoise.select_regressors(T, d.regressors, d.acompcor_n);
bad = [];
if ~strcmp(opt.censor.mode, 'none')
    vars = T.Properties.VariableNames;
    outl = vars(~cellfun(@isempty, regexp(vars, '^motion_outlier_\d+$', 'once')));
    bad = false(height(T), 1);
    for k = 1:numel(outl)
        bad = bad | T.(outl{k}) > 0;
    end
end

first = 1;
if isfield(ctx, 'first_frame')
    first = ctx.first_frame;
end
[Y, V] = seecat.io.read_nii(ctx.files.wbold, 'Class', 'single');
Y = Y(:, :, :, first:end);
if size(Y, 4) ~= height(T)
    error('SeeCAT:denoise', 'The BOLD series has %d frames but the confounds table %d.', size(Y, 4), height(T));
end
dim = size(Y);
nT = dim(4);
mask = logical(seecat.io.read_nii(ctx.files.mask_brain)) & all(Y ~= 0 & isfinite(Y), 4);
Y = reshape(Y, [], nT)';
y = Y(:, mask(:));
clear Y
[e, info] = seecat.denoise.clean(y, R, struct('tr', ctx.tr, 'detrend_order', d.detrend_order, ...
    'band', d.band, 'bad', bad, 'interp', opt.censor.interp));
e = e + mean(y, 1);
out = zeros(prod(dim(1:3)), nT, 'single');
out(mask(:), :) = e';
f = fullfile(ctx.work_dir, 'denoised.nii');
seecat.io.write_nii(reshape(out, dim), V(1), f, 'TR', ctx.tr);
ctx.files.denoised = f;
ctx.denoise_columns = cols;
log('denoise: %d confounds + trend order %d, %d good frames, %d dof left', ...
    numel(cols), d.detrend_order, info.n_good, info.dof);
end
