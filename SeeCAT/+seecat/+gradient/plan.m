function [units, cfg] = plan(cfg)
% PLAN  One unit holding every run: the runs are aligned to each other.
%   [units, cfg] = seecat.gradient.plan(cfg)
% See seecat.bids.derivative_units for the runs and folder defaults. With
% cfg.mask_mode = 'group', every run gets the intersection of the runs' brain masks
% (seecat.conn.group_mask) as group_mask: node series then come from the
% same voxels in every run. With mask_mode 'given', the voxels of cfg.mask (voxel
% nodes) or of the atlas are used as given, without the brain masks. Runs that
% keep fewer than cfg.min_frames frames after censoring are left out.
if strcmp(cfg.nodes, 'atlas') && isempty(cfg.atlas)
    error('SeeCAT:gradient', 'nodes = ''atlas'' needs "atlas" (an integer label image).');
end
if cfg.n_maps > cfg.n_components
    error('SeeCAT:gradient', 'n_maps (%d) cannot exceed n_components (%d).', cfg.n_maps, cfg.n_components);
end
mode = seecat.conn.mask_mode(cfg);           % mask 'brain' here is the template brain mask
[runs, cfg] = seecat.bids.derivative_units(cfg, cfg.input);
% Runs with fewer kept frames than min_frames are left out (listed in
% cfg.few_frames and in the log), before the group mask is built
few = false(size(runs));
for r = 1:numel(runs)
    few(r) = seecat.conn.kept_frames(runs(r)) < cfg.min_frames;
end
if any(few)
    cfg.few_frames = arrayfun(@(u) u.id, runs(few), 'UniformOutput', false);
    cfg.few_frames = cfg.few_frames(:)';
    runs = runs(~few);
end
if isempty(runs)
    error('SeeCAT:gradient', 'No run keeps at least min_frames (%d) frames after censoring.', cfg.min_frames);
end
if numel(runs) < 2 && ~strcmp(cfg.align, 'none')
    error('SeeCAT:gradient', 'Alignment needs at least 2 runs; set align = ''none'' for one.');
end
if strcmp(mode, 'group')
    f = seecat.conn.group_mask(runs, cfg);
    [runs.group_mask] = deal(f);
end
N = seecat.gradient.nodes(cfg);
units = struct('id', ['gradients' N.tag], 'runs', {runs}, 'nodes', N);
end
