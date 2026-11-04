function [units, cfg] = plan(cfg)
% PLAN  One unit holding every run: the runs are aligned to each other.
%   [units, cfg] = seecat.gradient.plan(cfg)
% See seecat.bids.derivative_units for the runs and folder defaults.
if strcmp(cfg.nodes, 'atlas') && isempty(cfg.atlas)
    error('SeeCAT:gradient', 'nodes = ''atlas'' needs "atlas" (an integer label image).');
end
if cfg.n_maps > cfg.n_components
    error('SeeCAT:gradient', 'n_maps (%d) cannot exceed n_components (%d).', cfg.n_maps, cfg.n_components);
end
[runs, cfg] = seecat.bids.derivative_units(cfg, cfg.input);
if numel(runs) < 2 && ~strcmp(cfg.align, 'none')
    error('SeeCAT:gradient', 'Alignment needs at least 2 runs; set align = ''none'' for one.');
end
N = seecat.gradient.nodes(cfg);
units = struct('id', ['gradients' N.tag], 'runs', {runs}, 'nodes', N);
end
