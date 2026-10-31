function result = run_unit(unit, cfg, log)
% RUN_UNIT  Denoise one fMRIPrep BOLD run.
%   result = seecat.fmriprep.run_unit(unit, cfg, log)
%
% Called by seecat.run. Steps:
%   confounds  the fMRIPrep table without the leading non-steady-state
%              rows; SeeCAT's own frame flags (seecat.denoise.censor_columns)
%   denoise    seecat.steps.denoise, as in the prep pipeline
%   smooth     seecat.steps.smooth
%   outputs    confounds TSV, brain mask, denoised and smoothed series, in
%              the fMRIPrep space (always runs; see seecat.run)
% The fMRIPrep files are read in place; nothing is copied to the work
% folder except the confounds table and the SeeCAT outputs.

ctx.work_dir = unit.work_dir;
ctx.id = unit.id;
ctx.tr = unit.tr;
ctx.files = struct('wbold', unit.bold, 'mask_brain', unit.mask, 'confounds_src', unit.confounds);

step = @(ctx, name, fn, opt) seecat.util.run_step(ctx, name, fn, opt, log);
ctx = step(ctx, 'confounds', @step_confounds, struct('censor', cfg.censor, 'dummy_scans', cfg.dummy_scans));
if cfg.denoise.enable
    ctx = step(ctx, 'denoise', @seecat.steps.denoise, struct('denoise', cfg.denoise, 'censor', cfg.censor));
end
if cfg.smooth.enable && any(cfg.smooth.fwhm > 0)
    ctx = step(ctx, 'smooth', @seecat.steps.smooth, cfg.smooth);
end
ctx = step_outputs(ctx, struct('output_dir', cfg.output_dir, 'fmriprep_dir', cfg.fmriprep_dir, ...
    'denoise', cfg.denoise, 'censor', cfg.censor, 'smooth', cfg.smooth, 'manifest', unit.manifest, ...
    'meta', unit.meta), log);
result = ctx.qc;
end

function ctx = step_confounds(ctx, opt, log)
T = seecat.io.read_tsv(ctx.files.confounds_src);
vars = T.Properties.VariableNames;
nss = vars(~cellfun(@isempty, regexp(vars, '^non_steady_state_outlier_?\d+$', 'once')));
n = opt.dummy_scans;
if ischar(n)                                   % 'auto': leading flagged rows
    flagged = false(height(T), 1);
    for k = 1:numel(nss)
        flagged = flagged | T.(nss{k}) > 0;
    end
    n = find(~flagged, 1) - 1;
    if isempty(n)
        error('SeeCAT:fmriprep', 'Every frame is marked non-steady-state in %s.', ctx.files.confounds_src);
    end
end
if n >= height(T) - 10
    error('SeeCAT:fmriprep', 'dummy_scans = %d leaves too few of the %d volumes.', n, height(T));
end
T = T(n + 1:end, :);
if ~ismember('framewise_displacement', T.Properties.VariableNames)
    error('SeeCAT:fmriprep', 'No framewise_displacement column in %s.', ctx.files.confounds_src);
end
fd = T.framewise_displacement;
[T, qc, meta] = seecat.denoise.censor_columns(T, fd, opt.censor, ctx.tr);
f = fullfile(ctx.work_dir, 'confounds.tsv');
if ~exist(ctx.work_dir, 'dir')
    mkdir(ctx.work_dir);
end
seecat.io.write_tsv(T, f);
ctx.files.confounds = f;
ctx.first_frame = n + 1;
ctx.confounds_meta = meta;
ctx.qc = qc;
ctx.qc.dummy_scans = n;
log('confounds: %d non-steady-state volume(s) dropped; mean FD %.3f mm, %d of %d frames flagged, %.1f min kept', ...
    n, qc.mean_fd, qc.n_flagged, qc.n_frames, qc.minutes_kept);
if qc.low_data
    log('confounds: WARNING less than %g min of good data', opt.censor.min_minutes);
end
end

function ctx = step_outputs(ctx, opt, log)
bold = ctx.files.wbold;
src = ['bids:fmriprep:' strrep(bold(numel(opt.fmriprep_dir) + 2:end), '\', '/')];
boldMeta = struct('RepetitionTime', ctx.tr, 'SkullStripped', false, 'Sources', {{src}}, ...
    'NonSteadyStateVolumesDropped', ctx.first_frame - 1);
if isfield(opt.meta, 'TaskName')
    boldMeta.TaskName = opt.meta.TaskName;
end
put = @(file, rel, meta) seecat.util.publish_output(file, rel, meta, ...
    struct('output_dir', opt.output_dir, 'work_dir', ctx.work_dir, 'manifest', opt.manifest));
name = @(varargin) seecat.bids.deriv_name(bold, varargin{:});
put(ctx.files.mask_brain, name('desc', 'brain', 'suffix', 'mask', 'ext', ext(ctx.files.mask_brain)), ...
    struct('Type', 'Brain', 'Sources', {{['bids:fmriprep:' strrep(ctx.files.mask_brain(numel(opt.fmriprep_dir) + 2:end), '\', '/')]}}));
put(ctx.files.confounds, name('space', '', 'res', '', 'den', '', 'desc', 'confounds', 'suffix', 'timeseries', 'ext', '.tsv'), ...
    ctx.confounds_meta);
seecat.steps.publish_denoised(ctx, bold, {}, boldMeta, opt);
log('outputs: written to %s', opt.output_dir);
end

function e = ext(f)
e = '.nii';
if endsWith(f, '.gz')
    e = '.nii.gz';
end
end
