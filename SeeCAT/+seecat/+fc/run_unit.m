function result = run_unit(unit, cfg, log)
% RUN_UNIT  Seed-based FC maps of one run.
%   result = seecat.fc.run_unit(unit, cfg, log)
%
% Writes, per seed, *_desc-<seed>_stat-r_connectivity.nii.gz and
% *_desc-<seed>_stat-z_connectivity.nii.gz (Fisher z) in the run's space,
% with a JSON sidecar giving the seed, the input series and the frames used.
%
% The seeds take their voxels from the brain mask (and the group mask); the
% maps cover cfg.mask within it. With cfg.mask_mode = 'given', the maps cover cfg.mask
% as given and the seeds their own voxels, without the brain mask; voxels
% without signal (outside the run's brain mask or field of view) are 0.

mask = 'brain';
if isfield(cfg, 'mask')
    mask = cfg.mask;
end
maskOnly = strcmp(seecat.conn.mask_mode(cfg), 'given');
opt = struct('mask_only', maskOnly);
if maskOnly
    opt.extra = @(hdr) seedVolume(cfg.seeds, hdr);
end
S = seecat.conn.load_series(unit, mask, false, opt);
if isfield(unit, 'group_mask') && ~isempty(unit.group_mask)
    log('group mask: %s (%d voxels)', unit.group_mask, numel(S.index));
end
if maskOnly
    log('mask as given: %d voxels, %d outside this run''s brain mask, %d without signal (r = 0)', ...
        nnz(S.in), nnz(S.in & ~S.brain), nnz(S.in & ~S.live(:)));
end
nS = numel(cfg.seeds);
[~, seeds] = seedVolume(cfg.seeds, S.hdr, S.index);
defs = cell(1, nS);
for s = 1:nS
    sd = cfg.seeds(s);
    if isfield(sd, 'file') && ~isempty(sd.file)
        defs{s} = struct('Name', sd.name, 'File', sd.file);
    else
        defs{s} = struct('Name', sd.name, 'CenterMM', sd.center(:)', 'RadiusMM', sd.radius);
    end
end
[r, z, empty] = seecat.conn.seed_fc(S.Y, seeds);
r = r(:, S.in);
z = z(:, S.in);
idx = S.index(S.in);
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
        vol(idx) = stats{q, 2}(s, :);
        f = fullfile(unit.work_dir, sprintf('%s_%s.nii', cfg.seeds(s).name, stats{q, 1}));
        seecat.io.write_nii(vol, S.hdr, f);
        meta = struct('Seed', defs{s}, 'Statistic', stats{q, 1}, 'Sources', {{src}}, ...
            'Mask', mask, 'MaskMode', seecat.conn.mask_mode(cfg), 'GroupMask', seecat.conn.group_mask_uri(unit, cfg), 'FramesUsed', S.n_kept, 'FramesTotal', S.n_frames, 'Software', ['SeeCAT ' seecat.version()]);
        rel = seecat.bids.deriv_name(unit.bold, 'desc', cfg.seeds(s).name, 'stat', stats{q, 1}, ...
            'suffix', 'connectivity', 'ext', '.nii.gz');
        seecat.util.publish_output(f, rel, meta, opt);
    end
end
log('fc: %d seed(s), %d of %d frames', nS, S.n_kept, S.n_frames);
result = struct('n_kept', S.n_kept, 'empty_seeds', nnz(empty));
end

function [vol, cols] = seedVolume(seeds, hdr, index)
% Logical volume of all seeds on the data grid; with INDEX, also the
% voxels x seeds matrix of those columns
vol = false(hdr.dim);
cols = false(0, numel(seeds));
if nargin > 2
    cols = false(numel(index), numel(seeds));
    [i, j, k] = ind2sub(hdr.dim, index);
    xyz = hdr.mat(1:3, :) * [i j k ones(numel(index), 1)]';
end
for s = 1:numel(seeds)
    sd = seeds(s);
    if isfield(sd, 'file') && ~isempty(sd.file)
        g = seecat.io.read_nii(sd.file, 'Ref', hdr, 'Interp', 0) > 0;
        g = g(:, :, :, 1);
        if nargin > 2
            cols(:, s) = g(index);
        end
    else
        [i, j, k] = ndgrid(1:hdr.dim(1), 1:hdr.dim(2), 1:hdr.dim(3));
        c = hdr.mat(1:3, :) * [i(:) j(:) k(:) ones(numel(i), 1)]';
        g = reshape(sqrt(sum((c - sd.center(:)) .^ 2, 1)) <= sd.radius, hdr.dim);
        if nargin > 2
            cols(:, s) = sqrt(sum((xyz - sd.center(:)) .^ 2, 1))' <= sd.radius;
        end
    end
    vol = vol | g;
end
end
