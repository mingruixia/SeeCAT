function [n, note] = auto_workers(cfg, units)
% AUTO_WORKERS  How many parallel workers fit, for n_workers = 'auto'.
%   [n, note] = seecat.util.auto_workers(cfg, units)
%
% n = min(cores, parallel tasks, floor(usable memory / memory per worker)),
% where usable memory is 85 % of the free physical memory less what the
% main MATLAB keeps for itself during the run, and each worker needs the
% estimated memory of one task plus about 1 GB for the worker process.
% Fewer than 2 workers gives 0 (one after another, no pool). NOTE explains
% the choice for the log. The estimates per pipeline (GB):
%   prep, fmriprep  1.5 + 4 copies of the run's output series in double
%                   (prep with IQMs: at least 10 copies of the largest T1w)
%   fc              0.5 + 3 copies of the run's series in the brain mask
%   degree          fc + 4 blocks of 1000 x brain-mask voxels
%   gradient        3 node x node matrices per run (4 with group alignment);
%                   the main MATLAB keeps 4 for the group step
%   stat            TFCE permutations: the contrasts' residuals (maps x voxels)
% Tasks are the units, or for one-unit pipelines the runs (gradient) or
% permutations (stat).

cores = 0;
if license('test', 'Distrib_Computing_Toolbox') && exist('parcluster', 'file')
    try
        cores = parcluster().NumWorkers;
    catch
    end
end
if cores == 0
    n = 0;
    note = 'no Parallel Computing Toolbox: running one after another';
    return
end
[perTask, client, tasks] = estimate(cfg, units);
free = freeGB();
if isnan(free)
    n = min(cores, tasks);
    note = sprintf('free memory unknown on this system: %d worker(s) (one per core, at most one per task)', n);
else
    worker = perTask + 1;                          % + the worker's own MATLAB
    fit = floor((0.85 * free - client) / worker);
    n = max(0, min([cores, tasks, fit]));
    note = sprintf(['about %.1f GB per worker (%.1f GB task + 1 GB worker), %.1f GB kept by the main ' ...
        'MATLAB, %.1f GB free: %d worker(s) (%d cores, %d task(s))'], worker, perTask, client, free, ...
        n, cores, tasks);
end
if n < 2
    n = 0;
    note = [note '; running one after another'];
end
end

function [perTask, client, tasks] = estimate(cfg, units)
GB = 2 ^ 30;
client = 0.5;
tasks = numel(units);
perTask = 2;
switch cfg.pipeline
    case {'prep', 'fmriprep', 'fc', 'degree'}
        v = 0;
        t = 0;
        for i = 1:numel(units)                    % the largest run decides
            h = seecat.io.nii_info(units(i).bold);
            if prod(h.dim(1:3)) * h.dim(4) > v * t
                v = prod(h.dim(1:3));
                t = h.dim(4);
            end
        end
        switch cfg.pipeline
            case 'prep'
                vs = cfg.normalise.voxel_size;
                bb = cfg.normalise.bounding_box;
                v = max(v, prod(floor(diff(bb, 1, 1) ./ vs) + 1));
                perTask = 1.5 + 4 * 8 * v * t / GB;
                if isfield(cfg, 'qc') && isfield(cfg.qc, 'iqm') && cfg.qc.iqm   % T1w IQMs: ~10 copies
                    t1 = 0;
                    for i = 1:numel(units)
                        if ~isempty(units(i).t1w)
                            h = seecat.io.nii_info(units(i).t1w);
                            t1 = max(t1, prod(h.dim(1:3)));
                        end
                    end
                    perTask = max(perTask, 1.5 + 10 * 8 * t1 / GB);
                end
            case 'fmriprep'
                perTask = 1.5 + 4 * 8 * v * t / GB;
            case 'fc'
                perTask = 0.5 + 3 * 8 * brainVoxels(units, v) * t / GB;
            case 'degree'
                b = brainVoxels(units, v);
                perTask = 0.5 + 3 * 8 * b * t / GB + 4 * 8 * 1000 * b / GB;
        end
    case 'gradient'
        u = units(1);
        b = 8;
        if u.nodes.n > 8000, b = 4; end
        m = u.nodes.n ^ 2 * b / GB;
        group = strcmp(cfg.align, 'group');
        perTask = (3 + group) * m;
        client = 0.5 + group * 4 * m;
        tasks = numel(u.runs);
    case 'stat'
        u = units(1);
        h = seecat.io.nii_info(u.maps.path{1});
        perTask = 0.3 + 4 * 8 * height(u.maps) * prod(h.dim(1:3)) / GB;
        client = 0.5 + 3 * 8 * height(u.maps) * prod(h.dim(1:3)) / GB;
        tasks = Inf;
        if ~ismember('tfce_fwe', cfg.inference)
            tasks = 1;                            % nothing runs in parallel
        end
    otherwise
        tasks = 1;
end
end

function b = brainVoxels(units, whole)
% Voxels of the first run's brain mask (the series is read inside it)
b = whole;
try
    b = nnz(seecat.io.read_nii(units(1).mask) > 0);
catch
end
end

function g = freeGB()
g = NaN;
try
    [~, s] = memory;                              % Windows
    g = s.PhysicalMemory.Available / 2 ^ 30;
    return
catch
end
try
    txt = fileread('/proc/meminfo');              % Linux
    k = regexp(txt, 'MemAvailable:\s+(\d+)', 'tokens', 'once');
    g = str2double(k{1}) / 2 ^ 20;
    return
catch
end
try
    [st, out] = system('vm_stat');                % macOS: free + inactive pages
    if st == 0
        ps = str2double(regexp(out, 'page size of (\d+)', 'tokens', 'once'));
        f = str2double(regexp(out, 'Pages free:\s+(\d+)', 'tokens', 'once'));
        in = str2double(regexp(out, 'Pages inactive:\s+(\d+)', 'tokens', 'once'));
        g = (f + in) * ps / 2 ^ 30;
    end
catch
end
end
