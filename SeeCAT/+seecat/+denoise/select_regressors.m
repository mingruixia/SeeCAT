function [R, cols] = select_regressors(T, names, ncomp)
% SELECT_REGRESSORS  Confound columns for the denoising model.
%   [R, cols] = seecat.denoise.select_regressors(T, {'friston24', 'wm', 'csf'})
%   [R, cols] = seecat.denoise.select_regressors(T, {'acompcor'}, 5)
%
% T is a confounds table with fMRIPrep column names (from SeeCAT or from
% fMRIPrep). NAMES may contain these shortcuts, or any column name:
%   friston24  trans_*/rot_* with _derivative1, _power2, _derivative1_power2
%   wm         white_matter
%   csf        csf
%   gs         global_signal
%   acompcor   the first NCOMP (default 5) c_comp_cor_* and w_comp_cor_*
%              columns. Older fMRIPrep writes only a_comp_cor_*, whose
%              tissue is given in its JSON sidecar; then name the columns.
% R is T x k with NaN (the n/a first row of derivatives) set to 0; COLS
% are the column names used, without duplicates.

if nargin < 3
    ncomp = 5;
end
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
            c = [firstN(vars, 'c_comp_cor', ncomp), firstN(vars, 'w_comp_cor', ncomp)];
            if isempty(c) && any(startsWith(vars, 'a_comp_cor_'))
                error('SeeCAT:denoise', ['The confounds table has a_comp_cor_* but no c_comp_cor_*/w_comp_cor_* ' ...
                    '(older fMRIPrep). Which tissue each a_comp_cor component belongs to is in the ' ...
                    'confounds JSON; list the columns you want in denoise.regressors instead of ''acompcor''.']);
            elseif isempty(c)
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

function c = firstN(vars, prefix, n)
% Columns prefix_00, prefix_01, ... in number order, at most n
c = vars(~cellfun(@isempty, regexp(vars, ['^' prefix '_\d+$'], 'once')));
[~, k] = sort(cellfun(@(x) str2double(x(numel(prefix) + 2:end)), c));
c = c(k(1:min(n, numel(k))));
end
