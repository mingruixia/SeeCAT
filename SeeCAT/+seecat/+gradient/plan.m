function [units, cfg] = plan(cfg)
% PLAN  One unit holding every run: the runs are aligned to each other.
%   [units, cfg] = seecat.gradient.plan(cfg)
% See seecat.bids.derivative_units for the runs and folder defaults. With
% cfg.group_mask, every run gets the intersection of the runs' brain masks
% (seecat.conn.group_mask) as group_mask: node series then come from the
% same voxels in every run. With cfg.mask_only, the voxels of cfg.mask (voxel
% nodes) or of the atlas are used as given, without the brain masks.
if strcmp(cfg.nodes, 'atlas') && isempty(cfg.atlas)
    error('SeeCAT:gradient', 'nodes = ''atlas'' needs "atlas" (an integer label image).');
end
if cfg.n_maps > cfg.n_components
    error('SeeCAT:gradient', 'n_maps (%d) cannot exceed n_components (%d).', cfg.n_maps, cfg.n_components);
end
seecat.conn.check_mask_only(cfg, false);      % mask 'brain' here is the template brain mask
[runs, cfg] = seecat.bids.derivative_units(cfg, cfg.input);
if numel(runs) < 2 && ~strcmp(cfg.align, 'none')
    error('SeeCAT:gradient', 'Alignment needs at least 2 runs; set align = ''none'' for one.');
end
if cfg.group_mask
    f = seecat.conn.group_mask(runs, cfg);
    [runs.group_mask] = deal(f);
end
N = seecat.gradient.nodes(cfg);
units = struct('id', ['gradients' N.tag], 'runs', {runs}, 'nodes', N);
end
