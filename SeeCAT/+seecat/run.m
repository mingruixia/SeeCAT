function summary = run(cfg)
% RUN  Run a SeeCAT pipeline.
%   summary = seecat.run(cfg)            % config struct from seecat.config
%   summary = seecat.run('study.json')   % saved config
%
% Steps:
%   1. Fill and validate the config (seecat.config, seecat.check_config).
%   2. seecat.<pipeline>.plan(cfg) lists the units of work (BOLD runs for
%      per-subject pipelines, one unit for group pipelines) and resolves
%      folder defaults.
%   3. Each unit runs through seecat.<pipeline>.run_unit, in a parfor over
%      units when cfg.n_workers > 0. A failing unit is logged and the others
%      continue.
%   4. Writes, under <output_dir>/logs: the config, a run log and one log
%      per unit; and <output_dir>/reports/<run>_summary.tsv.
%   5. Calls seecat.<pipeline>.finish(cfg, summary, log) when the pipeline
%      has one (dataset-level outputs, e.g. the group QC page).
%
% A unit that finished before with the same options (all fields except
% n_workers, overwrite and keep_work) is skipped unless cfg.overwrite is
% true. Its working folder is deleted on success unless cfg.keep_work is
% true; after a failure it is kept, so finished steps are not redone.
%
% Each unit gets unit.manifest (logs/outputs/<pipeline>_<unit>.txt); the
% pipeline lists every derivative there with seecat.util.record_output
% before writing it. When a unit runs (is not skipped), the files of its
% previous manifest are deleted first, and if it fails, what it wrote is
% deleted too: a failed unit leaves no derivatives.
%
% SUMMARY is a table: unit, status ('ok', 'skipped' or 'failed'), seconds,
% message, then the fields each unit reports (e.g. mean FD).

seecat.util.check_matlab();
cfg = seecat.config(cfg);
seecat.check_config(cfg);
p = cfg.pipeline;
[units, cfg] = feval(['seecat.' p '.plan'], cfg);

runId = [p '_' char(datetime('now', 'Format', 'yyyyMMdd''T''HHmmss'))];
logDir = fullfile(cfg.output_dir, 'logs');
if ~exist(logDir, 'dir')
    mkdir(logDir);
end
seecat.save_config(cfg, fullfile(logDir, [runId '_config.json']));
mainLog = fullfile(logDir, [runId '.log']);
log = @(varargin) seecat.util.log_msg(mainLog, varargin{:});
log('SeeCAT %s, pipeline "%s", %d unit(s)', seecat.version(), p, numel(units));
log('MATLAB %s; %s', version, spmVersion());
log('Output: %s', cfg.output_dir);

if ischar(cfg.n_workers) || isstring(cfg.n_workers)  % 'auto': as many as memory allows
    [cfg.n_workers, note] = seecat.util.auto_workers(cfg, units);
    log('Parallel workers (auto): %s', note);
end
[nWorkers, poolNote] = seecat.util.start_pool(cfg.n_workers);
if ~isempty(poolNote)
    log('Parallel pool: %s', poolNote);
end
if isfield(cfg, 'qc_excluded') && ~isempty(cfg.qc_excluded)
    log('Left out by QC (reports/qc_exclusions.tsv): %s', strjoin(cfg.qc_excluded, ', '));
end
hashCfg = rmfield(cfg, intersect(fieldnames(cfg), {'n_workers', 'overwrite', 'keep_work', 'qc_excluded'}));
cfgHash = seecat.util.hash(hashCfg);
n = numel(units);
status = cell(n, 1);
message = cell(n, 1);
seconds = nan(n, 1);
results = cell(n, 1);
outer = nWorkers;
if n == 1
    outer = 0;          % one unit (group statistics): the pool is left to the unit, e.g. TFCE permutations
end
parfor (i = 1:n, outer)
    [status{i}, message{i}, seconds(i), results{i}] = runUnit(units(i), cfg, cfgHash, logDir, runId);
end

summary = table({units.id}', status, seconds, message, 'VariableNames', {'unit', 'status', 'seconds', 'message'});
summary = [summary, resultColumns(results)];
seecat.io.write_tsv(summary, fullfile(cfg.output_dir, 'reports', [runId '_summary.tsv']));
for i = 1:n
    if strcmp(status{i}, 'failed')
        log('%s: FAILED: %s', units(i).id, message{i});
    else
        log('%s: %s', units(i).id, status{i});
    end
end
% Optional dataset-level step of the pipeline (e.g. the group QC page)
if ~isempty(which(['seecat.' p '.finish']))
    try
        feval(['seecat.' p '.finish'], cfg, summary, log);
    catch err
        log('finish step failed: %s', err.message);
    end
end
log('Done: %d ok, %d skipped, %d failed. Logs in %s', nnz(strcmp(status, 'ok')), ...
    nnz(strcmp(status, 'skipped')), nnz(strcmp(status, 'failed')), logDir);
end

function [status, message, seconds, result] = runUnit(unit, cfg, cfgHash, logDir, runId)
p = cfg.pipeline;
marker = fullfile(logDir, 'done', [p '_' unit.id '.json']);
unitLog = fullfile(logDir, runId, [unit.id '.log']);
log = @(varargin) seecat.util.log_msg(unitLog, ['[' unit.id '] ' varargin{1}], varargin{2:end});
unit.work_dir = fullfile(cfg.work_dir, p, unit.id);
unit.manifest = fullfile(logDir, 'outputs', [p '_' unit.id '.txt']);
message = '';
seconds = 0;
result = struct();

if ~cfg.overwrite && exist(marker, 'file')
    m = jsondecode(fileread(marker));
    if strcmp(m.config_hash, cfgHash)
        status = 'skipped';
        result = m.result;
        log('finished on %s with the same options; skipped', m.finished);
        return
    end
end
if exist(marker, 'file')
    delete(marker);
end
n = clearOutputs(unit.manifest, cfg.output_dir);
if n > 0
    log('removed %d derivative(s) of the previous run', n);
end
if cfg.overwrite && exist(unit.work_dir, 'dir')
    rmdir(unit.work_dir, 's');
end

t = tic;
try
    result = feval(['seecat.' p '.run_unit'], unit, cfg, log);
    if isempty(result)
        result = struct();
    end
    status = 'ok';
    seconds = toc(t);
    m = struct('unit', unit.id, 'pipeline', p, 'config_hash', cfgHash, ...
        'seecat_version', seecat.version(), ...
        'finished', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')), ...
        'seconds', seconds, 'result', result);
    seecat.util.write_json(marker, m);
    if ~cfg.keep_work && exist(unit.work_dir, 'dir')
        rmdir(unit.work_dir, 's');
    end
    log('finished (%.1f s)', seconds);
catch err
    status = 'failed';
    seconds = toc(t);
    message = strtok(err.message, newline);
    log('FAILED: %s', getReport(err, 'extended', 'hyperlinks', 'off'));
    n = clearOutputs(unit.manifest, cfg.output_dir);
    if n > 0
        log('removed %d derivative(s) written before the failure', n);
    end
end
end

function n = clearOutputs(manifest, outDir)
% Delete the files listed in a unit's output manifest, then the manifest
n = 0;
if ~exist(manifest, 'file')
    return
end
files = strsplit(strtrim(fileread(manifest)), newline);
for i = 1:numel(files)
    f = fullfile(outDir, strtrim(files{i}));
    if ~isempty(strtrim(files{i})) && exist(f, 'file') == 2
        delete(f);
        n = n + 1;
    end
end
delete(manifest);
end

function T = resultColumns(results)
% One column per field reported by any unit; numeric scalars stay numeric
names = {};
for i = 1:numel(results)
    names = union(names, fieldnames(results{i}), 'stable');
end
T = table();
for j = 1:numel(names)
    k = names{j};
    vals = cell(numel(results), 1);
    for i = 1:numel(results)
        if isfield(results{i}, k)
            vals{i} = results{i}.(k);
        end
    end
    if all(cellfun(@(v) isempty(v) || (isnumeric(v) && isscalar(v)) || (islogical(v) && isscalar(v)), vals))
        col = nan(numel(vals), 1);
        has = ~cellfun(@isempty, vals);
        col(has) = cellfun(@double, vals(has));
        T.(k) = col;
    else
        T.(k) = vals;
    end
end
end

function v = spmVersion()
v = 'SPM not on the path';
if exist('spm', 'file')
    try
        [name, rel] = spm('Ver');
        v = [name ' ' rel];
    catch
    end
end
end
