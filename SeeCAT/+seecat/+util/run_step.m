function ctx = run_step(ctx, name, fn, opt, log)
% RUN_STEP  Run one processing step, or skip it if it already ran.
%   ctx = seecat.util.run_step(ctx, 'realign', @step_realign, cfg.realign, log)
%
% FN is called as ctx = fn(ctx, opt, log). CTX must have work_dir (the
% unit's working folder) and files (a struct of file paths, possibly
% nested or cell arrays of paths).
%
% After a successful step, the fields the step added or changed are saved
% to <work_dir>/<name>.done.mat with a key made from NAME, OPT, the whole
% ctx before the step, the sizes and dates of the files in ctx.files, and
% the source code of FN (so a changed step runs again after an update).
% The step is skipped when the key matches and every file it produced
% exists; its saved changes are then applied to ctx. A changed option, a
% different ctx or a re-made input file therefore re-runs the step and,
% through the new file dates, every later step.
%
% Conventions: settings a step needs come in OPT, not in ctx; ctx holds
% only state (paths, metadata) and must be JSON-encodable.

if nargin < 5 || isempty(log)
    log = @(varargin) [];
end
done = fullfile(ctx.work_dir, [name '.done.mat']);
key = seecat.util.hash({name, opt, ctx, fileSignature(ctx.files), codeSignature(fn)});

if exist(done, 'file')
    s = load(done);
    if isfield(s, 'key') && strcmp(s.key, key) && all(cellfun(@(f) exist(f, 'file') == 2, filePaths(s.delta)))
        log('%s: already done, skipped', name);
        ctx = applyDelta(ctx, s.delta);
        return
    end
    delete(done);
end

log('%s: started', name);
t = tic;
before = ctx;
ctx = fn(ctx, opt, log);
log('%s: finished (%.1f s)', name, toc(t));
delta = changes(before, ctx);
if ~exist(ctx.work_dir, 'dir')
    mkdir(ctx.work_dir);
end
save(done, 'key', 'delta');
end

function d = changes(a, b)
% Fields of struct B that are new or differ from A (one level into ctx.files)
d = struct();
for f = fieldnames(b)'
    k = f{1};
    if strcmp(k, 'files') && isfield(a, k) && isstruct(a.files) && isstruct(b.files)
        df = changes(a.files, b.files);
        if ~isempty(fieldnames(df))
            d.files = df;
        end
    elseif ~isfield(a, k) || ~isequal(a.(k), b.(k))
        d.(k) = b.(k);
    end
end
end

function ctx = applyDelta(ctx, d)
for f = fieldnames(d)'
    k = f{1};
    if strcmp(k, 'files')
        for g = fieldnames(d.files)'
            ctx.files.(g{1}) = d.files.(g{1});
        end
    else
        ctx.(k) = d.(k);
    end
end
end

function sig = fileSignature(files)
paths = filePaths(files);
sig = cell(numel(paths), 1);
for i = 1:numel(paths)
    d = dir(paths{i});
    if isscalar(d)
        sig{i} = sprintf('%s|%d|%.10f', paths{i}, d.bytes, d.datenum);
    else
        sig{i} = [paths{i} '|missing'];
    end
end
end

function p = filePaths(x)
% Every non-empty char found in a struct / cell tree
p = {};
if ischar(x)
    if ~isempty(x)
        p = {x};
    end
elseif iscell(x)
    for i = 1:numel(x)
        p = [p; filePaths(x{i})]; %#ok<AGROW>
    end
elseif isstruct(x)
    for i = 1:numel(x)
        for f = fieldnames(x)'
            p = [p; filePaths(x(i).(f{1}))]; %#ok<AGROW>
        end
    end
end
p = p(:);
end

function sig = codeSignature(fn)
% Hash of the step function's source file ('' for anonymous functions)
sig = '';
info = functions(fn);
if isfield(info, 'file') && ~isempty(info.file) && exist(info.file, 'file')
    sig = seecat.util.hash(fileread(info.file));
end
end
