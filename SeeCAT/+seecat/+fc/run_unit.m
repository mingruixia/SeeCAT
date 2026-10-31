function result = run_unit(unit, cfg, log)
% RUN_UNIT  Seed-based FC maps of one run.
%   result = seecat.fc.run_unit(unit, cfg, log)
%
% Writes, per seed, *_desc-<seed>_stat-r_connectivity.nii.gz and
% *_desc-<seed>_stat-z_connectivity.nii.gz (Fisher z) in the run's space,
% with a JSON sidecar giving the seed, the input series and the frames used.

S = seecat.conn.load_series(unit, 'brain');
nS = numel(cfg.seeds);
seeds = false(numel(S.index), nS);
defs = cell(1, nS);
for s = 1:nS
    sd = cfg.seeds(s);
    if isfield(sd, 'file') && ~isempty(sd.file)
        g = seecat.io.read_nii(sd.file, 'Ref', S.hdr, 'Interp', 0) > 0;
        seeds(:, s) = g(S.index);
        defs{s} = struct('Name', sd.name, 'File', sd.file);
    else
        seeds(:, s) = sqrt(sum((S.xyz - sd.center(:)) .^ 2, 1))' <= sd.radius;
        defs{s} = struct('Name', sd.name, 'CenterMM', sd.center(:)', 'RadiusMM', sd.radius);
    end
end
[r, z, empty] = seecat.conn.seed_fc(S.Y, seeds);
for s = find(empty)
    log('seed %s has no voxel with signal in this run; its maps are 0', cfg.seeds(s).name);
end
src = ['bids:seecat:' strrep(unit.bold(numel(cfg.input_dir) + 2:end), '\', '/')];
opt = struct('output_dir', cfg.output_dir, 'work_dir', unit.work_dir, 'manifest', unit.manifest);
if ~exist(unit.work_dir, 'dir')
    mkdir(unit.work_dir);
end
stats = {'r', r; 'z', z};
for s = 1:nS
    for q = 1:2
        vol = zeros(S.hdr.dim, 'single');
        vol(S.index) = stats{q, 2}(s, :);
        f = fullfile(unit.work_dir, sprintf('%s_%s.nii', cfg.seeds(s).name, stats{q, 1}));
        seecat.io.write_nii(vol, S.hdr, f);
        meta = struct('Seed', defs{s}, 'Statistic', stats{q, 1}, 'Sources', {{src}}, ...
            'FramesUsed', S.n_kept, 'FramesTotal', S.n_frames, 'Software', ['SeeCAT ' seecat.version()]);
        rel = seecat.bids.deriv_name(unit.bold, 'desc', cfg.seeds(s).name, 'stat', stats{q, 1}, ...
            'suffix', 'connectivity', 'ext', '.nii.gz');
        seecat.util.publish_output(f, rel, meta, opt);
    end
end
log('fc: %d seed(s), %d of %d frames', nS, S.n_kept, S.n_frames);
result = struct('n_kept', S.n_kept, 'empty_seeds', nnz(empty));
end
