function [units, cfg] = plan(cfg)
% PLAN  One unit: every selected map, with its site and covariates.
%   [units, cfg] = seecat.harmonize.plan(cfg)
% output_dir defaults to input_dir, so the harmonised maps sit next to the
% originals; the report goes to <output_dir>/group/<unit>/, the unit being
% harmonize<label>_<maps>_<hash>, e.g. harmonizeComBat_PCCz_1a2b3c4d for maps
% desc PCC, stat z (see unitId below).
if strcmp(cfg.method, 'combat_gam') && isempty(cfg.nonlinear)
    error('SeeCAT:harmonize', 'combat_gam needs "nonlinear" (e.g. age): the covariates fitted as splines.');
end
cols = unique([{cfg.site}, cfg.covariates(:)', cfg.nonlinear(:)'], 'stable');
[maps, dropped, root] = seecat.bids.select_maps(cfg.input_dir, seecat.bids.map_selector(cfg), cfg.subjects, cfg.participants, cols, ...
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
units = struct('id', unitId(cfg), 'maps', maps, 'dropped', {dropped});
end

function id = unitId(cfg)
% One unit per label and map selection, so harmonising several measures
% never makes one run replace another's outputs: a readable part (the
% selector values, at most 24 characters) and 8 hex characters of a hash of
% the whole selection (field names and values; their order does not
% matter), which tells apart selections that read the same once shortened.
sel = seecat.bids.map_selector(cfg);
names = sort(fieldnames(sel))';
vals = cellfun(@(f) strjoin(sort(cellstr(string(sel.(f)))), ','), names, 'UniformOutput', false);
tag = regexprep(strjoin(vals, ''), '[^a-zA-Z0-9]', '');
key = strjoin(strcat(names, '=', vals), ';');
h = seecat.util.hash(key);
id = ['harmonize' cfg.label '_' tag(1:min(end, 24)) '_' h(1:8)];
end
