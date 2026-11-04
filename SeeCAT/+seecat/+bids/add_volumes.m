function P = add_volumes(P, root)
% ADD_VOLUMES  Tissue volumes (reports/anat_volumes.tsv) as participants columns.
%   P = seecat.bids.add_volumes(P, derivatives_dir)
% Adds gm_ml, wm_ml, csf_ml and tiv_ml, written by the prep pipeline, to the
% participants table P for the columns P does not have already (the first
% T1w of a subject when there are several), so Statistics and Harmonize
% can use TIV as a covariate.
f = fullfile(root, 'reports', 'anat_volumes.tsv');
if ~exist(f, 'file') || ~ismember('participant_id', P.Properties.VariableNames)
    return
end
A = seecat.io.read_tsv(f);
[~, first] = unique(A.participant_id, 'stable');
A = A(first, :);
[in, row] = ismember(P.participant_id, A.participant_id);
for c = {'gm_ml', 'wm_ml', 'csf_ml', 'tiv_ml'}
    if ismember(c{1}, A.Properties.VariableNames) && ~ismember(c{1}, P.Properties.VariableNames)
        v = nan(height(P), 1);
        v(in) = A.(c{1})(row(in));
        P.(c{1}) = v;
    end
end
end
