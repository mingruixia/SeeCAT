function [units, cfg] = plan(cfg)
% PLAN  Units of work for preprocessing: one per selected BOLD run.
%   [units, cfg] = seecat.prep.plan(cfg)
%
% Resolves folder defaults (output_dir: <bids_dir>/derivatives/seecat;
% work_dir: next to it as seecat_work), checks SPM, lists the BOLD runs
% (seecat.bids.bold_units) and writes the derivatives'
% dataset_description.json.

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
seecat.bids.write_description(cfg.output_dir, L.root);
end
