function ctx = step_outputs(ctx, opt, log)
% Write the final derivatives (.nii.gz with JSON sidecars) into output_dir,
% named by seecat.bids.deriv_name (Doc/design/batch-api.md, section 6).
% Anatomical derivatives are written by one unit per T1w (unit.write_anat),
% so parallel units never write the same file.

space = {'space', 'IXI549Space', 'res', num2label(opt.voxel_size)};
bold = ctx.files.bold_src;
src = bidsUri(bold, opt.bids_dir);
boldMeta = struct('RepetitionTime', ctx.tr, 'SkullStripped', false, 'Sources', {{src}});
if isfield(opt.meta, 'TaskName')
    boldMeta.TaskName = opt.meta.TaskName;
end
put = @(file, rel, meta) publish(file, rel, meta, opt.output_dir, ctx.work_dir);

put(ctx.files.wbold, name(bold, space{:}, 'desc', 'preproc'), boldMeta);
put(ctx.files.mask_brain, name(bold, space{:}, 'desc', 'brain', 'suffix', 'mask'), ...
    struct('Type', 'Brain', 'Sources', {{src}}));

conf = name(bold, 'desc', 'confounds', 'suffix', 'timeseries', 'ext', '.tsv');
copyTo(ctx.files.confounds, fullfile(opt.output_dir, conf));
seecat.util.write_json(fullfile(opt.output_dir, regexprep(conf, '\.tsv$', '.json')), confoundsMeta(opt.censor));

if isfield(ctx.files, 'denoised')
    dm = boldMeta;
    dm.Denoising = struct('Regressors', {opt.denoise.regressors}, 'Columns', {ctx.denoise_columns}, ...
        'DetrendOrder', opt.denoise.detrend_order, 'BandPass', opt.denoise.band, ...
        'CensorMode', opt.censor.mode, 'Interpolation', opt.censor.interp, ...
        'MeanAdded', true, 'Software', ['SeeCAT ' seecat.version()]);
    put(ctx.files.denoised, name(bold, space{:}, 'desc', 'denoised'), dm);
end
if isfield(ctx.files, 'smoothed')
    sm = boldMeta;
    sm.SmoothingFWHM = opt.smooth.fwhm;
    base = 'preproc';
    if isfield(ctx.files, 'denoised')
        base = 'denoised';
        sm.Denoising = dm.Denoising;
    end
    put(ctx.files.smoothed, name(bold, space{:}, 'desc', [base 'Sm' num2label(opt.smooth.fwhm)]), sm);
end

xfmMeta = struct('Sources', {{src}}, 'Software', spm('Ver'));
if ~isempty(ctx.files.t1w)
    if opt.write_anat
        t1 = ctx.files.t1w_src;
        anat = struct('Sources', {{bidsUri(t1, opt.bids_dir)}});
        put(ctx.files.biascorr, name(t1, 'datatype', 'anat', 'desc', 'preproc', 'suffix', 'T1w'), anat);
        labels = {'GM', 'WM', 'CSF'};
        for k = 1:3
            put(ctx.files.(sprintf('c%d', k)), ...
                name(t1, 'datatype', 'anat', 'label', labels{k}, 'suffix', 'probseg'), anat);
        end
        anat.Software = spm('Ver');
        put(ctx.files.deform, name(t1, 'datatype', 'anat', 'from', 'T1w', 'to', 'IXI549Space', ...
            'mode', 'image', 'suffix', 'xfm'), anat);
    end
else
    put(ctx.files.deform, name(bold, 'from', 'boldref', 'to', 'IXI549Space', 'mode', 'image', 'suffix', 'xfm'), xfmMeta);
end
log('outputs: written to %s', opt.output_dir);
end

function rel = name(src, varargin)
rel = seecat.bids.deriv_name(src, varargin{:});
end

function publish(file, rel, meta, outDir, workDir)
% Compress in the unit's own work folder, then move into place
dst = fullfile(outDir, rel);
tmp = fullfile(workDir, 'gz');
if ~exist(tmp, 'dir')
    mkdir(tmp);
end
g = gzip(file, tmp);
copyTo(g{1}, dst);
delete(g{1});
seecat.util.write_json(regexprep(dst, '\.nii\.gz$', '.json'), meta);
end

function copyTo(src, dst)
d = fileparts(dst);
if ~exist(d, 'dir')
    mkdir(d);
end
copyfile(src, dst, 'f');
end

function u = bidsUri(f, root)
rel = strrep(f(numel(root) + 2:end), '\', '/');
u = ['bids:raw:' rel];
end

function s = num2label(v)
% 3 -> '3', [2 2 2] -> '2', 2.5 -> '2p5', [2 2 3] -> '2x2x3'
if ~isscalar(v) && all(v == v(1))
    v = v(1);
end
if isscalar(v)
    s = strrep(sprintf('%g', v), '.', 'p');
else
    s = strjoin(arrayfun(@num2label, v, 'UniformOutput', false), 'x');
end
end

function m = confoundsMeta(c)
m.framewise_displacement = struct('Description', 'Framewise displacement (Power et al. 2012), rotations on a 50 mm sphere', 'Units', 'mm');
m.motion_outlier = struct('Description', sprintf(['One column per flagged frame: FD > %g mm, ' ...
    'plus %d frame(s) before and %d after'], c.fd_threshold, c.before, c.after));
m.censor = struct('Description', ['1 = frame excluded from later analyses (censor.mode ''censor''). ' ...
    'In the denoised series these frames hold interpolated values.'], 'CensorMode', c.mode);
m.c_comp_cor = struct('Description', 'aCompCor components from the eroded CSF mask, good frames only');
m.w_comp_cor = struct('Description', 'aCompCor components from the eroded WM mask, good frames only');
end
