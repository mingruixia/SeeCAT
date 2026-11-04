function [ex, file] = exclusions(root, name)
% EXCLUSIONS  Run keys excluded by QC in a derivatives folder.
%   [ex, file] = seecat.qc.exclusions(derivatives_dir)
%   tf = ismember(seecat.qc.exclusions('key', name), ex)
%
% Reads <root>/reports/qc_exclusions.tsv (seecat.qc.group_report; changed
% on the QC reports page) and returns the keys of the rows with exclude = 1
% ({} when there is no list). A key names a run by the entities that
% identify an acquisition (sub, ses, task, acq, ce, rec, dir, run, echo),
% so every file derived from it matches: the BOLD run's denoised series,
% its seed maps and degree maps, or, for a T1w row, the VBM maps.
%   key = seecat.qc.exclusions('key', 'sub-01_task-rest_space-X_desc-PCC_stat-z_connectivity.nii.gz')
%   % -> 'sub-01_task-rest'
if strcmp(root, 'key')
    ex = key(name);
    file = '';
    return
end
ex = {};
file = fullfile(root, 'reports', 'qc_exclusions.tsv');
if ~exist(file, 'file')
    file = '';
    return
end
T = seecat.io.read_tsv(file);
if ~all(ismember({'id', 'exclude'}, T.Properties.VariableNames))
    return
end
x = T.exclude;
if ~isnumeric(x)
    x = str2double(cellstr(string(x)));
end
ids = cellstr(string(T.id));
ex = unique(cellfun(@key, ids(x == 1), 'UniformOutput', false));
end

function k = key(name)
[~, n] = fileparts(char(name));
n = regexprep(n, '\.nii$', '');
parts = strsplit(n, '_');
keep = {'sub', 'ses', 'task', 'acq', 'ce', 'rec', 'dir', 'run', 'echo'};
out = {};
for e = keep
    hit = parts(startsWith(parts, [e{1} '-']));
    if ~isempty(hit)
        out{end+1} = hit{1}; %#ok<AGROW>
    end
end
k = strjoin(out, '_');
end
