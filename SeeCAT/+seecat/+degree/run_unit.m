function result = run_unit(unit, cfg, log)
% RUN_UNIT  Voxel-wise degree maps of one run.
%   result = seecat.degree.run_unit(unit, cfg, log)
%
% Writes, per sign x weight x distance bin,
%   *_desc-deg<Pos|Abs|Neg><Bin|Wei>R<thr>[D<lo>to<hi>]_stat-raw_connectivity.nii.gz
%   ... stat-z (z-scored within the analysis mask, over the voxels with
%       signal; cfg.zscore)
%   ... desc-...Sm<fwhm> versions of both (cfg.smooth_fwhm > 0)
% in the run's space, with JSON sidecars of the settings.

maskOnly = isfield(cfg, 'mask_only') && cfg.mask_only;
S = seecat.conn.load_series(unit, cfg.mask, true, struct('mask_only', maskOnly));
if isfield(unit, 'group_mask') && ~isempty(unit.group_mask)
    log('group mask: %s', unit.group_mask);
end
live = S.live(:);
if maskOnly
    log('mask as given: %d voxels, %d outside this run''s brain mask, %d without signal (degree 0)', ...
        numel(S.index), nnz(~S.brain), nnz(~live));
end
t = tic;
[D, maps] = seecat.conn.degree(S.Y(:, S.in), S.xyz(:, S.in), struct('threshold', cfg.threshold, ...
    'sign', {cfg.sign}, 'weight', {cfg.weight}, 'exclude_local_mm', cfg.exclude_local_mm, ...
    'distance_edges', cfg.distance_edges));
log('degree: %d voxels, %d of %d frames, %d map(s) in %.1f s', nnz(S.in), S.n_kept, S.n_frames, numel(maps), toc(t));
src = ['bids:seecat:' strrep(unit.bold(numel(cfg.input_dir) + 2:end), '\', '/')];
opt = struct('output_dir', cfg.output_dir, 'work_dir', unit.work_dir, 'manifest', unit.manifest);
if ~exist(unit.work_dir, 'dir')
    mkdir(unit.work_dir);
end
idx = S.index(S.in);
signs = struct('positive', 'Pos', 'absolute', 'Abs', 'negative', 'Neg');
weights = struct('binary', 'Bin', 'weighted', 'Wei');
measure = struct('binary', 'degree', 'weighted', 'strength');
num = @seecat.util.number_label;
for k = 1:numel(maps)
    m = maps(k);
    desc = ['deg' signs.(m.sign) weights.(m.weight) 'R' num(cfg.threshold)];
    if ~isequal(cfg.distance_edges(:)', [0 Inf])
        desc = [desc 'D' num(m.lo) 'to' num(m.hi)]; %#ok<AGROW>
    end
    out = {'raw', D(:, k)};
    if cfg.zscore
        d = D(:, k);
        zd = zeros(size(d));                       % over the voxels with signal; 0 elsewhere
        zd(live) = (d(live) - mean(d(live))) / std(d(live));
        out(end+1, :) = {'z', zd}; %#ok<AGROW>
    end
    meta = struct('Measure', measure.(m.weight), 'Sign', m.sign, 'Threshold', cfg.threshold, ...
        'ExcludeLocalMM', cfg.exclude_local_mm, 'DistanceMM', [m.lo min(m.hi, realmax)], ...
        'Mask', cfg.mask, 'MaskOnly', maskOnly, 'GroupMask', seecat.conn.group_mask_uri(unit, cfg), 'Voxels', nnz(S.in), 'VoxelsWithSignal', nnz(live), 'Sources', {{src}}, 'FramesUsed', S.n_kept, 'FramesTotal', S.n_frames, ...
        'Software', ['SeeCAT ' seecat.version()]);
    for q = 1:size(out, 1)
        vol = zeros(S.hdr.dim, 'single');
        vol(idx) = out{q, 2};
        f = fullfile(unit.work_dir, sprintf('%s_%s.nii', desc, out{q, 1}));
        seecat.io.write_nii(vol, S.hdr, f);
        meta.Statistic = out{q, 1};
        name = @(dsc) seecat.bids.deriv_name(unit.bold, 'desc', dsc, 'stat', out{q, 1}, ...
            'suffix', 'connectivity', 'ext', '.nii.gz');
        seecat.util.publish_output(f, name(desc), meta, opt);
        if any(cfg.smooth_fwhm > 0)
            fs = smoothMap(vol, S.hdr, cfg.smooth_fwhm, idx, fullfile(unit.work_dir, sprintf('%s_%s_sm.nii', desc, out{q, 1})));
            sm = meta;
            sm.SmoothingFWHM = cfg.smooth_fwhm;
            seecat.util.publish_output(fs, name([desc 'Sm' num(cfg.smooth_fwhm)]), sm, opt);
        end
    end
end
result = struct('n_kept', S.n_kept, 'n_voxels', nnz(S.in));
end

function f = smoothMap(vol, hdr, fwhm, idx, f)
% SPM Gaussian kernel; the result is kept on the analysis mask
if isscalar(fwhm)
    fwhm = [fwhm fwhm fwhm];
end
seecat.util.spm_run([]);
vox = sqrt(sum(hdr.mat(1:3, 1:3) .^ 2));
out = zeros(hdr.dim);
spm_smooth(double(vol), out, fwhm ./ vox);
s = zeros(hdr.dim, 'single');
s(idx) = out(idx);
seecat.io.write_nii(s, hdr, f);
end
