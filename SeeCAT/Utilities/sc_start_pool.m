function sc_start_pool()
% SC_START_POOL  Start the default parallel pool if none is running.
% Falls back silently to serial execution when the Parallel Computing
% Toolbox is unavailable.

if ~license('test', 'Distrib_Computing_Toolbox') || ~exist('gcp', 'file')
    warning('SeeCAT:noParallel', 'Parallel Computing Toolbox not available; running serially.');
    return
end
try
    gcp;
catch err
    warning('SeeCAT:noParallel', 'Could not start a parallel pool (%s); running serially.', err.message);
end
end
