function result = run_unit(unit, cfg, log)
% RUN_UNIT  Preprocess one BOLD run.
%   result = seecat.prep.run_unit(unit, cfg, log)
%
% Called by seecat.run. Steps (Doc/design/batch-api.md, section 5), each
% through seecat.util.run_step so a failed run resumes where it stopped:
%
%   input       copy BOLD/T1w into the work folder as .nii; drop dummy scans
%   slicetime   SPM slice timing from SliceTiming (seconds)
%   realign     SPM realign (estimate; mean image only); motion parameters
%   coreg       T1w -> mean EPI (header only)
%   segment     unified segmentation of the T1w (or of the mean EPI)
%   tissue_masks  eroded WM/CSF masks in native space
%   normalise   BOLD and tissue maps to IXI549Space with the deformation
%   masks       brain, WM and CSF masks in output space
%   confounds   motion, FD, censor flags, tissue signals, aCompCor
%   denoise     interpolation of flagged frames + detrend + regression + band-pass
%   smooth      Gaussian smoothing of the denoised series
%   outputs     .nii.gz derivatives with JSON sidecars, confounds TSV
%
% The outputs step always runs (it is not resumable): seecat.run removes a
% unit's previous derivatives before running it.
%
% Steps never change their input files; each writes new files, which keeps
% step-level resume correct (a re-run realign would otherwise re-estimate
% on headers it had already corrected).
%
% RESULT feeds the run summary: dummy_scans, n_frames, mean_fd, max_fd,
% n_flagged, minutes_kept, low_data, normalise_method.

ctx.work_dir = unit.work_dir;
ctx.id = unit.id;
ctx.tr = unit.tr;
ctx.slice_timing = [];
if isfield(unit.meta, 'SliceTiming')
    ctx.slice_timing = unit.meta.SliceTiming(:)';
end
ctx.files = struct('bold_src', unit.bold, 't1w_src', unit.t1w);

method = cfg.normalise.method;
if strcmp(method, 'auto')
    method = 'epi';
    if ~isempty(unit.t1w)
        method = 'segment';
    end
elseif strcmp(method, 'segment') && isempty(unit.t1w)
    error('SeeCAT:prep', 'normalise.method is ''segment'' but %s has no T1w image.', unit.id);
end
if ~cfg.normalise.enable
    error('SeeCAT:prep', 'normalise.enable = false (native-space output) is not supported yet.');
end

step = @(ctx, name, fn, opt) seecat.util.run_step(ctx, name, fn, opt, log);
ctx = step(ctx, 'input', @step_input, struct('dummy_scans', cfg.dummy_scans, 'use_t1w', strcmp(method, 'segment')));
if cfg.slice_timing.enable
    ctx = step(ctx, 'slicetime', @step_slicetime, cfg.slice_timing);
end
ctx = step(ctx, 'realign', @step_realign, cfg.realign);
if strcmp(method, 'segment')
    ctx = step(ctx, 'coreg', @step_coreg, struct());
end
ctx = step(ctx, 'segment', @step_segment, struct('source', method));
ctx = step(ctx, 'tissue_masks', @step_tissue_masks, cfg.masks);
ctx = step(ctx, 'normalise', @step_normalise, cfg.normalise);
ctx = step(ctx, 'masks', @step_masks, struct());
ctx = step(ctx, 'confounds', @step_confounds, struct('censor', cfg.censor, ...
    'acompcor_n', cfg.denoise.acompcor_n, 'detrend_order', cfg.denoise.detrend_order));
if cfg.denoise.enable
    ctx = step(ctx, 'denoise', @seecat.steps.denoise, struct('denoise', cfg.denoise, 'censor', cfg.censor));
end
if cfg.smooth.enable && any(cfg.smooth.fwhm > 0)
    ctx = step(ctx, 'smooth', @seecat.steps.smooth, cfg.smooth);
end
out = struct('output_dir', cfg.output_dir, 'bids_dir', cfg.bids_dir, 'write_anat', unit.write_anat, ...
    'voxel_size', cfg.normalise.voxel_size, 'smooth', cfg.smooth, 'denoise', cfg.denoise, ...
    'censor', cfg.censor, 'meta', unit.meta, 'manifest', unit.manifest);
% Not through run_step: seecat.run deletes the previous outputs before a
% unit runs, so this step must always write them.
ctx = step_outputs(ctx, out, log);

result = ctx.qc;
result.normalise_method = method;
% QC page; a failure here is logged, the derivatives are already written
f = ctx.files;
R = struct('id', unit.id, 'sub', unit.sub, 'output_dir', cfg.output_dir, 'work_dir', ctx.work_dir, ...
    'manifest', unit.manifest, 'pipeline', 'prep', 'tr', ctx.tr, 'bold', f.wbold, 'mask', f.mask_brain, ...
    'wm', f.mask_wm, 'csf', f.mask_csf, 'tissue', {{f.wc1, f.wc2, f.wc3}}, 'confounds', f.confounds, ...
    'fd_threshold', cfg.censor.fd_threshold, 'summary', result);
if isfield(f, 'denoised')
    R.denoised = f.denoised;
end
try
    M = seecat.qc.run_report(R);
    result.tsnr_median = M.tsnr_median;
catch err
    log('QC report failed: %s', err.message);
end
end
