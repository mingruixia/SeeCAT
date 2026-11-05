function [nWorkers, note] = start_pool(n)
% START_POOL  Make sure a parallel pool is running.
%   seecat.util.start_pool          % default pool size
%   w = seecat.util.start_pool(n)   % at most n workers; w = workers usable
%   w = seecat.util.start_pool('auto')   % as many workers as the cluster allows
%   [w, note] = seecat.util.start_pool(n)   % NOTE says what went wrong, for the log
%
% Returns 0, with a warning, when the Parallel Computing Toolbox is not
% available or no pool can start; parfor (i = 1:N, 0) then runs serially.
% A pool that fails to start is tried once more with half the workers
% (a large pool can fail when another MATLAB uses the local cluster).
% An existing pool is reused as it is.

if nargin < 1
    n = Inf;
end
auto = ischar(n) || isstring(n);
if auto
    n = Inf;
end
nWorkers = 0;
note = '';
if n == 0
    return
end
if ~license('test', 'Distrib_Computing_Toolbox') || ~exist('gcp', 'file')
    note = 'Parallel Computing Toolbox not available; running serially.';
    warning('SeeCAT:noParallel', '%s', note);
    return
end
pool = gcp('nocreate');
if isempty(pool)
    c = parcluster;
    if ~isfinite(n)
        n = c.NumWorkers;                     % all workers of the default profile
    end
    tries = unique([n, ceil(n / 2)], 'stable');
    tries = tries(tries >= 2 | tries == n);
    for k = tries
        try
            % Workers compute with one thread by default; share the cores
            % among them so that matrix work (degree, gradients) keeps its
            % speed: e.g. 5 workers on 32 cores get 6 threads each.
            try
                c.NumThreads = max(1, floor(c.NumWorkers / k));
            catch
            end
            pool = parpool(c, k);
            break
        catch err
            msg = regexprep(err.message, '\s+', ' ');
            note = [note sprintf('A pool of %d workers did not start (%s). ', k, msg)]; %#ok<AGROW>
        end
    end
    if isempty(pool)
        note = [note 'Running serially.'];
        warning('SeeCAT:noParallel', '%s', note);
        return
    end
    if ~isempty(note)
        note = [note sprintf('Started %d workers instead.', pool.NumWorkers)];
    end
end
nWorkers = min(n, pool.NumWorkers);
end
