function [units, cfg] = plan(cfg)
% PLAN  Units of work for preprocessing: one per selected BOLD run.
%   [units, cfg] = seecat.prep.plan(cfg)
%
% Resolves folder defaults (output_dir: <bids_dir>/derivatives/seecat;
% work_dir: next to it as seecat_work), checks SPM, lists the BOLD runs
% (seecat.bids.bold_units) and writes the derivatives'
% dataset_description.json. Units get write_anat: true for the first unit
% of each T1w, which then writes the anatomical derivatives.

seecat.util.check_spm();
L = seecat.bids.layout(cfg.bids_dir);
cfg.bids_dir = L.root;
if isempty(cfg.output_dir)
    cfg.output_dir = fullfile(L.root, 'derivatives', 'seecat');
end
if isempty(cfg.work_dir)
    cfg.work_dir = fullfile(fileparts(cfg.output_dir), 'seecat_work');
end
units = seecat.bids.bold_units(L, cfg);
% The first unit using a T1w writes its anatomical derivatives
[~, first] = unique({units.t1w}, 'stable');
[units.write_anat] = deal(false);
for i = first'
    units(i).write_anat = ~isempty(units(i).t1w);
end
seecat.bids.write_description(cfg.output_dir, L.root);
end
