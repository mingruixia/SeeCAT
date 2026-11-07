function [units, cfg] = plan(cfg)
% PLAN  Units of work for seed FC: one per run in cfg.input_dir.
%   [units, cfg] = seecat.fc.plan(cfg)
% See seecat.bids.derivative_units. With cfg.group_mask, every unit gets
% the intersection of the planned runs' brain masks (seecat.conn.group_mask)
% as unit.group_mask: seeds and maps then cover the same voxels in every run.
[units, cfg] = seecat.bids.derivative_units(cfg, cfg.input);
if isfield(cfg, 'group_mask') && cfg.group_mask
    f = seecat.conn.group_mask(units, cfg);
    [units.group_mask] = deal(f);
end
end
