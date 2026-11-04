function finish(cfg, summary, log)
% FINISH  Group QC page and tables after every unit ran (called by seecat.run).
%   seecat.prep.finish(cfg, summary, log)
% Writes reports/prep_qc.html, prep_qc.tsv, qc_exclusions.tsv
% (seecat.qc.group_report) and reports/anat_volumes.tsv: GM, WM, CSF and
% TIV (mL) of every T1w, from the sidecars of the native tissue maps; add
% its columns to participants.tsv to use TIV as a covariate.
seecat.qc.group_report(cfg.output_dir, 'prep', summary, cfg.qc);
log('QC: %s', fullfile(cfg.output_dir, 'reports', 'prep_qc.html'));
F = dir(fullfile(cfg.output_dir, 'sub-*', '**', 'anat', '*_label-GM_probseg.json'));
F = F(~contains({F.name}, '_space-'));
if isempty(F)
    return
end
rows = {};
for i = 1:numel(F)
    j = jsondecode(fileread(fullfile(F(i).folder, F(i).name)));
    if ~isfield(j, 'TissueVolumesML'), continue, end
    v = j.TissueVolumesML;
    t1 = regexprep(F(i).name, '_label-GM_probseg\.json$', '');
    rows(end+1, :) = {['sub-' regexp(t1, '(?<=^sub-)[a-zA-Z0-9]+', 'match', 'once')], t1, ...
        v.GM, v.WM, v.CSF, v.TIV}; %#ok<AGROW>
end
if isempty(rows), return, end
T = cell2table(rows, 'VariableNames', {'participant_id', 't1w', 'gm_ml', 'wm_ml', 'csf_ml', 'tiv_ml'});
f = fullfile(cfg.output_dir, 'reports', 'anat_volumes.tsv');
seecat.io.write_tsv(T, f);
log('Tissue volumes: %s', f);
end
