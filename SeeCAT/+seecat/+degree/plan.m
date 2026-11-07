function [units, cfg] = plan(cfg)
% PLAN  Units of work for voxel-wise degree: one per run in cfg.input_dir.
%   [units, cfg] = seecat.degree.plan(cfg)
% See seecat.bids.derivative_units. With cfg.group_mask, the brain masks of
% all planned runs are intersected (seecat.conn.group_mask) and each unit
% gets the file as unit.group_mask, so every run uses the same voxels.
[units, cfg] = seecat.bids.derivative_units(cfg, cfg.input);
if isfield(cfg, 'group_mask') && cfg.group_mask
    f = seecat.conn.group_mask(units, cfg);
    [units.group_mask] = deal(f);
end
end
