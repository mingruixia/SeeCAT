function [units, cfg] = plan(cfg)
% PLAN  One unit: every selected map, with its site and covariates.
%   [units, cfg] = seecat.harmonize.plan(cfg)
% output_dir defaults to input_dir, so the harmonised maps sit next to the
% originals; the report goes to <output_dir>/group/harmonize<label>_<maps>/,
% e.g. group/harmonizeComBat_PCCz/ for maps desc PCC, stat z.
if strcmp(cfg.method, 'combat_gam') && isempty(cfg.nonlinear)
    error('SeeCAT:harmonize', 'combat_gam needs "nonlinear" (e.g. age): the covariates fitted as splines.');
end
cols = unique([{cfg.site}, cfg.covariates(:)', cfg.nonlinear(:)'], 'stable');
[maps, dropped, root] = seecat.bids.select_maps(cfg.input_dir, cfg.maps, cfg.subjects, cfg.participants, cols, ...
    cfg.qc_exclusions);
if isempty(cfg.output_dir)
    cfg.output_dir = root;
end
if isempty(cfg.work_dir)
    cfg.work_dir = fullfile(fileparts(cfg.output_dir), 'seecat_work');
end
if height(maps) < 4
    error('SeeCAT:harmonize', 'Only %d map(s) left.', height(maps));
end
for c = cfg.nonlinear(:)'
    if ~isnumeric(maps.(c{1}))
        error('SeeCAT:harmonize', 'Nonlinear covariate %s is not numeric.', c{1});
    end
end
% One unit per label and map selection: harmonising several measures does
% not make one run replace another's outputs
tag = strjoin(cellfun(@(f) regexprep(char(string(cfg.maps.(f))), '[^a-zA-Z0-9]', ''), ...
    fieldnames(cfg.maps)', 'UniformOutput', false), '');
units = struct('id', ['harmonize' cfg.label '_' tag(1:min(end, 40))], 'maps', maps, 'dropped', {dropped});
end
