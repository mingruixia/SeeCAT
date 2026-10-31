function [units, cfg] = plan(cfg)
% PLAN  Units of work for seed FC: one per run in cfg.input_dir.
%   [units, cfg] = seecat.fc.plan(cfg)
% See seecat.bids.derivative_units.
[units, cfg] = seecat.bids.derivative_units(cfg, cfg.input);
end
