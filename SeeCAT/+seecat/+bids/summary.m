function S = summary(src, kind)
% SUMMARY  Subjects, sessions and tasks of the BOLD runs in a dataset.
%   S = seecat.bids.summary('D:/study/bids')                 % raw BIDS
%   S = seecat.bids.summary('D:/study/derivatives/fmriprep', 'fmriprep')
%
% SRC is a folder or a layout (seecat.bids.layout). KIND 'raw' (default)
% counts *_bold images; 'fmriprep' counts *_desc-preproc_bold images, one per
% run whatever the number of spaces. S has:
%   subjects  labels of the subjects with BOLD runs (all subjects if none)
%   sessions  session labels
%   tasks     task labels, sorted
%   runs      number of runs of each task
%   nsub      number of subjects with runs of each task
%   text      one line for the form, e.g.
%             '20 subjects (01, 02, ..., 20); tasks: rest (20 runs), nback (18 runs)'

if nargin < 2
    kind = 'raw';
end
if isstruct(src)
    L = src;
else
    L = seecat.bids.layout(src);
end
img = {'.nii', '.nii.gz'};
if strcmp(kind, 'fmriprep')
    B = seecat.bids.query(L, 'suffix', 'bold', 'desc', 'preproc', 'ext', img);
else
    B = seecat.bids.query(L, 'suffix', 'bold', 'ext', img);
end
keys = arrayfun(@(b) regexprep(b.name, '_(space|res|den|desc)-[a-zA-Z0-9]+|_bold\.nii(\.gz)?$', ''), ...
    B, 'UniformOutput', false);
[~, first] = unique(keys, 'stable');
B = B(first);                                    % one per run

S.subjects = unique({B.sub});
if isempty(B)
    S.subjects = L.subjects;
end
S.subjects = S.subjects(:)';
ses = {B.ses};
S.sessions = reshape(unique(ses(~cellfun(@isempty, ses))), 1, []);
task = arrayfun(@(b) ent(b, 'task'), B, 'UniformOutput', false);
S.tasks = reshape(unique(task(~cellfun(@isempty, task))), 1, []);
S.runs = cellfun(@(t) sum(strcmp(task, t)), S.tasks);
S.nsub = cellfun(@(t) numel(unique({B(strcmp(task, t)).sub})), S.tasks);
S.text = describe(S, numel(B), kind);
end

function t = describe(S, n, kind)
if n == 0
    what = 'BOLD runs';
    if strcmp(kind, 'fmriprep')
        what = 'desc-preproc BOLD runs';
    end
    t = sprintf('%s; no %s found.', plural(numel(S.subjects), 'subject'), what);
    return
end
subs = S.subjects;
if numel(subs) > 6
    subs = [subs(1:3), {'...'}, subs(end-1:end)];
end
t = sprintf('%s (%s)', plural(numel(S.subjects), 'subject'), strjoin(subs, ', '));
if ~isempty(S.sessions)
    t = sprintf('%s; sessions: %s', t, strjoin(S.sessions, ', '));
end
parts = arrayfun(@(k) sprintf('%s (%s)', S.tasks{k}, plural(S.runs(k), 'run')), 1:numel(S.tasks), ...
    'UniformOutput', false);
if isempty(parts)
    parts = {'none (no task label)'};
end
t = sprintf('%s; tasks: %s', t, strjoin(parts, ', '));
end

function s = plural(n, word)
s = sprintf('%d %s', n, word);
if n ~= 1
    s = [s 's'];
end
end

function v = ent(f, key)
v = '';
if isfield(f.ent, key)
    v = f.ent.(key);
end
end
