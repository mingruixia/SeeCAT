function ctx = smooth(ctx, opt, ~)
% SMOOTH  Pipeline step: Gaussian smoothing (SPM kernel, spm_smooth on arrays).
%   ctx = seecat.util.run_step(ctx, 'smooth', @seecat.steps.smooth, cfg.smooth, log)
%
% Smooths ctx.files.denoised, after denoising (decision D2), or
% ctx.files.wbold without a denoise step. Writes s<name>.nii in the same
% folder and sets ctx.files.smoothed. Shared by the prep and fmriprep
% pipelines.
%
% Volumes are smoothed in memory and the 4D file is written once; the SPM
% batch writes a 4D output volume by volume, which grows with the number of
% volumes.

src = ctx.files.wbold;
if isfield(ctx.files, 'denoised')
    src = ctx.files.denoised;
end
fwhm = opt.fwhm;
if isscalar(fwhm)
    fwhm = [fwhm fwhm fwhm];
end
seecat.util.spm_run([]);
[Y, V] = seecat.io.read_nii(src, 'Class', 'single');
vox = sqrt(sum(V(1).mat(1:3, 1:3) .^ 2));
for k = 1:size(Y, 4)
    out = zeros(V(1).dim);
    spm_smooth(double(Y(:, :, :, k)), out, fwhm ./ vox);
    Y(:, :, :, k) = out;
end
[d, n, e] = fileparts(src);
ctx.files.smoothed = fullfile(d, ['s' n e]);
seecat.io.write_nii(Y, V(1), ctx.files.smoothed);
end
