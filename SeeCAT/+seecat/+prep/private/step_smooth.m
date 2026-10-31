function ctx = step_smooth(ctx, opt, ~)
% SPM Gaussian smoothing, after denoising (decision D2). Without the
% denoise step the normalised series is smoothed instead.

src = ctx.files.wbold;
if isfield(ctx.files, 'denoised')
    src = ctx.files.denoised;
end
fwhm = opt.fwhm;
if isscalar(fwhm)
    fwhm = [fwhm fwhm fwhm];
end
job.spm.spatial.smooth = struct('data', {frame_list(src)}, 'fwhm', fwhm, 'dtype', 0, 'im', 0, 'prefix', 's');
seecat.util.spm_run(job);
[d, n, e] = fileparts(src);
ctx.files.smoothed = fullfile(d, ['s' n e]);
end
