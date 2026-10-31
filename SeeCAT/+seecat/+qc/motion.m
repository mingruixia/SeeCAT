function C = motion(bold, n)
% MOTION  Framewise displacement and flagged frames of a BOLD series.
%   C = seecat.qc.motion('.../sub-01_task-rest_space-X_desc-preproc_bold.nii.gz')
%   C = seecat.qc.motion(bold, nFrames)
%
% The run's confounds table is looked up next to the series: the same name
% without the space, res, den and desc entities, ending in
% _desc-confounds_timeseries.tsv (or _desc-confounds_regressors.tsv, from
% older fMRIPrep). C.file is '' when there is none.
% C.fd       framewise_displacement (mm; NaN for the first frame)
% C.flagged  frames flagged for motion: any motion_outlier* or censor column
% With NFRAMES, both are aligned to the end of the table, so a series whose
% non-steady-state volumes were dropped still lines up; frames the table
% does not cover get NaN and false.

C = struct('file', '', 'fd', [], 'flagged', false(0, 1));
[d, name] = fileparts(regexprep(char(bold), '\.gz$', ''));
stem = regexprep(regexprep(name, '_(space|res|den|desc)-[a-zA-Z0-9]+', ''), '_bold$', '');
for s = {'timeseries', 'regressors'}
    f = fullfile(d, [stem '_desc-confounds_' s{1} '.tsv']);
    if exist(f, 'file')
        C.file = f;
        break
    end
end
if isempty(C.file)
    if nargin > 1
        C.fd = nan(n, 1);
        C.flagged = false(n, 1);
    end
    return
end
T = seecat.io.read_tsv(C.file);
vars = T.Properties.VariableNames;
fd = nan(height(T), 1);
if ismember('framewise_displacement', vars)
    fd = double(T.framewise_displacement);
end
bad = false(height(T), 1);
for v = vars(~cellfun(@isempty, regexp(vars, '^motion_outlier_?\d+$|^censor$', 'once')))
    bad = bad | double(T.(v{1})) > 0;
end
if nargin > 1
    m = numel(fd);
    if m >= n
        fd = fd(m - n + 1:end);
        bad = bad(m - n + 1:end);
    else
        fd = [nan(n - m, 1); fd];
        bad = [false(n - m, 1); bad];
    end
end
C.fd = fd;
C.flagged = bad;
end
