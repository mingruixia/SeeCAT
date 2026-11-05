function ctx = smooth(ctx, opt, ~)
% SMOOTH  Pipeline step: Gaussian smoothing (SPM kernel, spm_smooth on arrays).
%   ctx = seecat.util.run_step(ctx, 'smooth', @seecat.steps.smooth, cfg.smooth, log)
%
% Smooths ctx.files.denoised, after denoising (decision D2), or
% ctx.files.wbold without a denoise step; from wbold the frames before
% ctx.first_frame (fMRIPrep non-steady-state volumes) are left out, as in
% the denoise step, so the series matches the confounds table. Writes
% s<name>.nii into ctx.work_dir (never next to the input, which may be a
% read-only fMRIPrep folder) and sets ctx.files.smoothed. Shared by the
% prep and fmriprep pipelines.
%
% Volumes are smoothed in memory and the 4D file is written once; the SPM
% batch writes a 4D output volume by volume, which grows with the number of
% volumes.

src = ctx.files.wbold;
first = 1;
if isfield(ctx.files, 'denoised')
    src = ctx.files.denoised;                     % already without the leading frames
elseif isfield(ctx, 'first_frame') && ~isempty(ctx.first_frame)
    first = ctx.first_frame;
end
fwhm = opt.fwhm;
if isscalar(fwhm)
    fwhm = [fwhm fwhm fwhm];
end
seecat.util.spm_run([]);
[Y, V] = seecat.io.read_nii(src, 'Class', 'single');
Y = Y(:, :, :, first:end);
vox = sqrt(sum(V(1).mat(1:3, 1:3) .^ 2));
for k = 1:size(Y, 4)
    out = zeros(V(1).dim);
    spm_smooth(double(Y(:, :, :, k)), out, fwhm ./ vox);
    Y(:, :, :, k) = out;
end
[~, n] = fileparts(src);
n = regexprep(n, '\.nii$', '', 'ignorecase');     % x.nii.gz -> x
if ~exist(ctx.work_dir, 'dir')
    mkdir(ctx.work_dir);
end
ctx.files.smoothed = fullfile(ctx.work_dir, ['s' n '.nii']);
tr = [];
if isfield(ctx, 'tr')
    tr = ctx.tr;
end
seecat.io.write_nii(Y, V(1), ctx.files.smoothed, 'TR', tr);
end
