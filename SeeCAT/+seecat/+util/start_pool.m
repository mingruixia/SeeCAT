function nWorkers = start_pool(n)
% START_POOL  Make sure a parallel pool is running.
%   seecat.util.start_pool          % default pool size
%   w = seecat.util.start_pool(n)   % at most n workers; w = workers usable
%
% Returns 0, with a warning, when the Parallel Computing Toolbox is not
% available or the pool cannot start; parfor (i = 1:N, 0) then runs serially.
% An existing pool is reused as it is.

if nargin < 1
    n = Inf;
end
nWorkers = 0;
if n == 0
    return
end
if ~license('test', 'Distrib_Computing_Toolbox') || ~exist('gcp', 'file')
    warning('SeeCAT:noParallel', 'Parallel Computing Toolbox not available; running serially.');
    return
end
try
    pool = gcp('nocreate');
    if isempty(pool)
        if isfinite(n)
            pool = parpool(n);
        else
            pool = parpool;
        end
    end
    nWorkers = min(n, pool.NumWorkers);
catch err
    warning('SeeCAT:noParallel', 'Could not start a parallel pool (%s); running serially.', err.message);
end
end
