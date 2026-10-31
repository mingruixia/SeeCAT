function [units, cfg] = plan(cfg)
% PLAN  Units of work for voxel-wise degree: one per run in cfg.input_dir.
%   [units, cfg] = seecat.degree.plan(cfg)
% See seecat.bids.derivative_units.
[units, cfg] = seecat.bids.derivative_units(cfg, cfg.input);
end
