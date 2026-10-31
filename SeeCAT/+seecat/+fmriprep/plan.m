function [units, cfg] = plan(cfg)
% PLAN  Units of work for denoising fMRIPrep outputs: one per BOLD run.
%   [units, cfg] = seecat.fmriprep.plan(cfg)
%
% Finds, in cfg.fmriprep_dir, every *_space-<cfg.space>[_res-<cfg.res>]
% _desc-preproc_bold.nii[.gz] that matches the selection (subjects,
% sessions, task, runs), with its desc-brain_mask in the same space and
% the run's confounds table. output_dir defaults to a 'seecat' folder next
% to fmriprep_dir (derivatives/seecat), work_dir to 'seecat_work'.
% Every problem (missing mask or confounds, several resolutions, no
% RepetitionTime) is collected and raised as one SeeCAT:bids error.
%
% Units: id (the run's entities without space/res/desc), bold, mask,
% confounds, tr, meta.

L = seecat.bids.layout(cfg.fmriprep_dir);
cfg.fmriprep_dir = L.root;
if isempty(cfg.output_dir)
    cfg.output_dir = fullfile(fileparts(L.root), 'seecat');
end
if isempty(cfg.work_dir)
    cfg.work_dir = fullfile(fileparts(cfg.output_dir), 'seecat_work');
end

img = {'.nii', '.nii.gz'};
sel = {'sub', cfg.subjects, 'ses', cfg.sessions, 'run', cfg.runs};
B = seecat.bids.query(L, 'suffix', 'bold', 'desc', 'preproc', 'space', cfg.space, 'ext', img, sel{:});
msgs = {};
if isempty(B)
    raise({sprintf('No *_space-%s_desc-preproc_bold images in %s for this selection.', cfg.space, L.root)});
end
tasks = unique(arrayfun(@(f) ent(f, 'task'), B, 'UniformOutput', false));
task = cfg.task;
if isempty(task) && numel(tasks) > 1
    raise({sprintf('The outputs have several tasks (%s); set "task".', strjoin(tasks, ', '))});
elseif ~isempty(task)
    B = B(strcmp(arrayfun(@(f) ent(f, 'task'), B, 'UniformOutput', false), task));
    if isempty(B)
        raise({sprintf('Task "%s" not found. Tasks: %s.', task, strjoin(tasks, ', '))});
    end
end
res = arrayfun(@(f) ent(f, 'res'), B, 'UniformOutput', false);
if ~isempty(cfg.res)
    B = B(strcmp(res, cfg.res));
    if isempty(B)
        raise({sprintf('No res-%s outputs in space %s.', cfg.res, cfg.space)});
    end
end

units = struct('id', {}, 'sub', {}, 'bold', {}, 'mask', {}, 'confounds', {}, 'tr', {}, 'meta', {});
ids = {};
for i = 1:numel(B)
    b = B(i);
    id = regexprep(b.name, '_(space|res|den|desc)-[a-zA-Z0-9]+', '');
    id = regexprep(id, '_bold\.nii(\.gz)?$', '');
    if ismember(id, ids)
        msgs{end+1} = sprintf('%s: several resolutions in space %s; set "res".', id, cfg.space); %#ok<AGROW>
        continue
    end
    ids{end+1} = id; %#ok<AGROW>
    u.id = id;
    u.sub = b.ent.sub;
    u.bold = b.path;
    u.mask = sibling(L, b, {'desc', 'brain', 'suffix', 'mask'}, img);
    u.confounds = confoundsOf(L, b);
    u.meta = seecat.bids.metadata(L, b);
    u.tr = [];
    if isfield(u.meta, 'RepetitionTime')
        u.tr = u.meta.RepetitionTime;
    end
    if isempty(u.mask)
        msgs{end+1} = sprintf('%s: no desc-brain_mask in space %s.', id, cfg.space); %#ok<AGROW>
    end
    if isempty(u.confounds)
        msgs{end+1} = sprintf('%s: no desc-confounds_timeseries/_regressors.tsv.', id); %#ok<AGROW>
    end
    if isempty(u.tr)
        msgs{end+1} = sprintf('%s: RepetitionTime missing from the sidecar.', id); %#ok<AGROW>
    end
    units(end+1) = u; %#ok<AGROW>
end
if ~isempty(msgs)
    raise(msgs);
end
seecat.bids.write_description(cfg.output_dir, L.root);
end

function p = sibling(L, b, change, ext)
% The file with b's entities, some changed (e.g. desc, suffix)
e = b.ent;
for k = 1:2:numel(change)
    if strcmp(change{k}, 'suffix')
        suffix = change{k + 1};
    else
        e.(change{k}) = change{k + 1};
    end
end
args = {'suffix', suffix, 'ext', ext};
for f = fieldnames(e)'
    args = [args, f, {e.(f{1})}]; %#ok<AGROW>
end
F = seecat.bids.query(L, args{:});
F = F(arrayfun(@(x) isequal(sort(fieldnames(x.ent)), sort(fieldnames(e))), F));
p = '';
if ~isempty(F)
    p = F(1).path;
end
end

function p = confoundsOf(L, b)
% Confounds of the run: b's entities without space/res/den/desc
e = rmfield(b.ent, intersect(fieldnames(b.ent), {'space', 'res', 'den', 'desc'}));
p = '';
for suffix = {'timeseries', 'regressors'}
    args = {'suffix', suffix{1}, 'ext', '.tsv', 'desc', 'confounds'};
    for f = fieldnames(e)'
        args = [args, f, {e.(f{1})}]; %#ok<AGROW>
    end
    F = seecat.bids.query(L, args{:});
    keep = arrayfun(@(x) isequal(sort(fieldnames(x.ent)), sort([fieldnames(e); {'desc'}])), F);
    F = F(keep);
    if ~isempty(F)
        p = F(1).path;
        return
    end
end
end

function v = ent(f, key)
v = '';
if isfield(f.ent, key)
    v = f.ent.(key);
end
end

function raise(msgs)
error('SeeCAT:bids', 'fMRIPrep selection problems:\n  - %s', strjoin(msgs, '\n  - '));
end
