function U = bold_units(L, cfg)
% BOLD_UNITS  BOLD runs to process, each with its T1w and metadata.
%   U = seecat.bids.bold_units(L, cfg)
%
% CFG supplies the selection: subjects, sessions, task, runs (empty = all;
% an empty task is allowed only when the dataset has one task).
%
% U is a struct array, one element per BOLD run:
%   id    BIDS name stem without suffix, e.g. 'sub-01_task-rest_run-1'
%   sub, ses
%   bold  path of the BOLD image
%   t1w   path of the T1w image ('' if none). The same session is preferred;
%         otherwise the subject's first T1w in any session is used.
%   meta  merged sidecar metadata
%   tr    RepetitionTime in seconds
%
% Every problem (unknown subject, ambiguous task, missing RepetitionTime)
% is collected and raised as one SeeCAT:bids error.

isImage = {'.nii', '.nii.gz'};
msgs = {};

missingSubs = setdiff(cfg.subjects, L.subjects);
if ~isempty(missingSubs)
    msgs{end+1} = sprintf('Subjects not in the dataset: %s.', strjoin(missingSubs, ', '));
end

allBold = seecat.bids.query(L, 'suffix', 'bold', 'ext', isImage);
tasks = unique(arrayfun(@(f) taskOf(f), allBold, 'UniformOutput', false));
task = cfg.task;
if isempty(task)
    if numel(tasks) > 1
        msgs{end+1} = sprintf('The dataset has several tasks (%s); set "task".', strjoin(tasks, ', '));
    elseif isscalar(tasks)
        task = tasks{1};
    end
elseif ~ismember(task, tasks)
    msgs{end+1} = sprintf('Task "%s" not found. Tasks: %s.', task, strjoin(tasks, ', '));
end
if ~isempty(msgs)
    raise(msgs);
end

B = seecat.bids.query(L, 'suffix', 'bold', 'ext', isImage, 'task', task, ...
    'sub', cfg.subjects, 'ses', cfg.sessions, 'run', cfg.runs);
if isempty(B)
    raise({'No BOLD runs match the selection.'});
end

U = struct('id', {}, 'sub', {}, 'ses', {}, 'bold', {}, 't1w', {}, 'meta', {}, 'tr', {});
for i = 1:numel(B)
    b = B(i);
    u.id = regexprep(b.name, '_bold\.nii(\.gz)?$', '');
    u.sub = b.sub;
    u.ses = b.ses;
    u.bold = b.path;
    u.t1w = findT1w(L, b);
    u.meta = seecat.bids.metadata(L, b);
    u.tr = [];
    if isfield(u.meta, 'RepetitionTime') && isnumeric(u.meta.RepetitionTime) ...
            && isscalar(u.meta.RepetitionTime) && u.meta.RepetitionTime > 0
        u.tr = u.meta.RepetitionTime;
    else
        msgs{end+1} = sprintf('%s: RepetitionTime missing from the sidecar.', b.name); %#ok<AGROW>
    end
    U(end+1) = u; %#ok<AGROW>
end
if ~isempty(msgs)
    raise(msgs);
end
end

function t = taskOf(f)
t = '';
if isfield(f.ent, 'task')
    t = f.ent.task;
end
end

function p = findT1w(L, b)
p = '';
T = seecat.bids.query(L, 'suffix', 'T1w', 'ext', {'.nii', '.nii.gz'}, 'sub', b.sub, 'ses', b.ses);
if isempty(T)
    T = seecat.bids.query(L, 'suffix', 'T1w', 'ext', {'.nii', '.nii.gz'}, 'sub', b.sub);
end
if ~isempty(T)
    p = T(1).path;
end
end

function raise(msgs)
error('SeeCAT:bids', 'BIDS selection problems:\n  - %s', strjoin(msgs, '\n  - '));
end
