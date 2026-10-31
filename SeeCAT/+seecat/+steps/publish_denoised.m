function publish_denoised(ctx, bold, nameArgs, boldMeta, opt)
% PUBLISH_DENOISED  Write the denoised and smoothed series of one run.
%   seecat.steps.publish_denoised(ctx, boldSrc, {'space', ..., 'res', ...}, boldMeta, opt)
%
% Names come from seecat.bids.deriv_name(boldSrc, nameArgs{:}, 'desc', ...):
% desc-denoised, and desc-denoisedSm<fwhm> (desc-preprocSm<fwhm> without
% denoising). Each sidecar is BOLDMETA plus the denoising settings. OPT has
% denoise, censor, smooth, output_dir and manifest; CTX has work_dir,
% files.denoised / files.smoothed (when made) and denoise_columns. Shared by
% the prep and fmriprep pipelines.

put = @(file, rel, meta) seecat.util.publish_output(file, rel, meta, ...
    struct('output_dir', opt.output_dir, 'work_dir', ctx.work_dir, 'manifest', opt.manifest));
name = @(varargin) seecat.bids.deriv_name(bold, nameArgs{:}, varargin{:});
dm = [];
if isfield(ctx.files, 'denoised')
    dm = boldMeta;
    dm.Denoising = struct('Regressors', {opt.denoise.regressors}, 'Columns', {ctx.denoise_columns}, ...
        'DetrendOrder', opt.denoise.detrend_order, 'BandPass', opt.denoise.band, ...
        'CensorMode', opt.censor.mode, 'Interpolation', opt.censor.interp, ...
        'MeanAdded', true, 'Software', ['SeeCAT ' seecat.version()]);
    put(ctx.files.denoised, name('desc', 'denoised'), dm);
end
if isfield(ctx.files, 'smoothed')
    sm = boldMeta;
    sm.SmoothingFWHM = opt.smooth.fwhm;
    base = 'preproc';
    if ~isempty(dm)
        base = 'denoised';
        sm.Denoising = dm.Denoising;
    end
    put(ctx.files.smoothed, name('desc', [base 'Sm' seecat.util.number_label(opt.smooth.fwhm)]), sm);
end
end
