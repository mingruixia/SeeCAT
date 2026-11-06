function [lock, holder] = unit_lock(d, runId)
% UNIT_LOCK  Claim a unit for this MATLAB while it runs.
%   [lock, holder] = seecat.util.unit_lock(lockDir, runId)
%
% Creates the folder LOCKDIR (atomically: only one process can) with an
% owner.json (run, host, process id, time). LOCK is an onCleanup object
% that removes the folder when it is cleared, i.e. when the unit ends,
% failed or not. When another process holds the unit, LOCK is empty and
% HOLDER describes it. A lock left by a process that no longer runs on
% this computer (MATLAB was closed or crashed) is taken over.

holder = '';
parent = fileparts(d);
if ~exist(parent, 'dir')
    mkdir(parent);
end
me = struct('run', runId, 'host', host(), 'pid', feature('getpid'), ...
    'started', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));
for attempt = 1:2
    if java.io.File(d).mkdir()
        seecat.util.write_json(fullfile(d, 'owner.json'), me);
        lock = onCleanup(@() release(d, me.pid));
        return
    end
    o = owner(d);
    if isempty(o)                    % being created by another process right now
        pause(1);
        o = owner(d);
    end
    if ~isempty(o) && strcmp(o.host, me.host) && ~alive(o.pid)
        rmdir(d, 's');               % stale: its MATLAB is gone
        continue
    end
    break
end
lock = [];
if isempty(o)
    holder = 'unknown';
else
    holder = sprintf('run %s, %s, process %d, since %s', o.run, o.host, o.pid, o.started);
end
end

function release(d, pid)
o = owner(d);
if isempty(o) || o.pid == pid
    try
        rmdir(d, 's');
    catch
    end
end
end

function o = owner(d)
o = [];
f = fullfile(d, 'owner.json');
if exist(f, 'file')
    try
        o = jsondecode(fileread(f));
    catch
    end
end
end

function h = host()
h = char(java.net.InetAddress.getLocalHost().getHostName());
end

function tf = alive(pid)
% Whether process PID runs on this computer (true when it cannot be told)
tf = true;
try
    tf = logical(java.lang.ProcessHandle.of(pid).isPresent());
    return
catch
end
try
    if ispc
        System.Diagnostics.Process.GetProcessById(pid);
    else
        [s, ~] = system(sprintf('kill -0 %d', pid));
        tf = s == 0;
    end
catch
    tf = false;
end
end
