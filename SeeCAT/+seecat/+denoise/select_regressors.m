function [R, cols] = select_regressors(T, names)
% SELECT_REGRESSORS  Confound columns for the denoising model.
%   [R, cols] = seecat.denoise.select_regressors(T, {'friston24', 'wm', 'csf'})
%
% T is a confounds table with fMRIPrep column names (from SeeCAT or from
% fMRIPrep). NAMES may contain these shortcuts, or any column name:
%   friston24  trans_*/rot_* with _derivative1, _power2, _derivative1_power2
%   wm         white_matter
%   csf        csf
%   gs         global_signal
%   acompcor   every c_comp_cor_* and w_comp_cor_* column
% R is T x k with NaN (the n/a first row of derivatives) set to 0; COLS
% are the column names used, without duplicates.

cols = {};
vars = T.Properties.VariableNames;
missing = {};
for i = 1:numel(names)
    n = names{i};
    switch n
        case 'friston24'
            base = {'trans_x', 'trans_y', 'trans_z', 'rot_x', 'rot_y', 'rot_z'};
            c = [base, strcat(base, '_derivative1'), strcat(base, '_power2'), strcat(base, '_derivative1_power2')];
        case 'wm'
            c = {'white_matter'};
        case 'csf'
            c = {'csf'};
        case 'gs'
            c = {'global_signal'};
        case 'acompcor'
            c = vars(~cellfun(@isempty, regexp(vars, '^[cw]_comp_cor_\d+$', 'once')));
            if isempty(c)
                missing{end+1} = 'c_comp_cor_*/w_comp_cor_*'; %#ok<AGROW>
            end
        otherwise
            c = {n};
    end
    absent = setdiff(c, vars, 'stable');
    missing = [missing, absent]; %#ok<AGROW>
    cols = [cols, setdiff(c, [cols, absent], 'stable')]; %#ok<AGROW>
end
if ~isempty(missing)
    error('SeeCAT:denoise', 'Confound columns not in the confounds table: %s.', strjoin(missing, ', '));
end
R = zeros(height(T), numel(cols));
for j = 1:numel(cols)
    R(:, j) = double(T.(cols{j}));
end
R(isnan(R)) = 0;
end
