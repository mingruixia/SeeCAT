function [units, cfg] = derivative_units(cfg, desc)
% DERIVATIVE_UNITS  BOLD runs in a SeeCAT derivatives folder, for analyses.
%   [units, cfg] = seecat.bids.derivative_units(cfg, 'denoised')
%
% Used by the plan of the fc and degree pipelines. cfg.input_dir is the
% derivatives folder written by the prep or fmriprep pipeline; output_dir
% defaults to it, work_dir to 'seecat_work' next to it. DESC selects the
% series (*_desc-<desc>_bold, e.g. 'denoised' or 'denoisedSm6'); one space
% must be present, or cfg.space chooses (and cfg.res among resolutions). Each unit has id, bold, mask
% (desc-brain_mask), confounds (desc-confounds_timeseries) and space. All
% problems are collected into one SeeCAT:bids error. With
% cfg.qc_exclusions, runs excluded in reports/qc_exclusions.tsv are left out
% and listed in cfg.qc_excluded.

L = seecat.bids.layout(cfg.input_dir);
cfg.input_dir = L.root;
if isempty(cfg.output_dir)
    cfg.output_dir = L.root;
end
if isempty(cfg.work_dir)
    cfg.work_dir = fullfile(fileparts(cfg.output_dir), 'seecat_work');
end
img = {'.nii', '.nii.gz'};
res = '';
if isfield(cfg, 'res')
    res = cfg.res;
end
B = seecat.bids.query(L, 'suffix', 'bold', 'desc', desc, 'ext', img, ...
    'sub', cfg.subjects, 'ses', cfg.sessions, 'run', cfg.runs, 'task', cfg.task, 'space', cfg.space, 'res', res);
if isempty(B)
    raise({sprintf('No *_desc-%s_bold images in %s for this selection.', desc, L.root)});
end
cfg = rmfield(cfg, intersect(fieldnames(cfg), {'qc_excluded'}));   % this plan's list, not an earlier one's
if isfield(cfg, 'qc_exclusions') && cfg.qc_exclusions          % runs excluded by QC
    ex = seecat.qc.exclusions(L.root);
    if ~isempty(ex)
        k = arrayfun(@(b) seecat.qc.exclusions('key', b.name), B, 'UniformOutput', false);
        out = ismember(k, ex);
        cfg.qc_excluded = unique(k(out))';
        B = B(~out);
        if isempty(B)
            raise({'Every run is excluded by QC (reports/qc_exclusions.tsv).'});
        end
    end
end
spaces = unique(arrayfun(@(f) ent(f, 'space'), B, 'UniformOutput', false));
if numel(spaces) > 1
    raise({sprintf('Several spaces (%s); set "space".', strjoin(spaces, ', '))});
end
tasks = unique(arrayfun(@(f) ent(f, 'task'), B, 'UniformOutput', false));
if numel(tasks) > 1
    raise({sprintf('Several tasks (%s); set "task".', strjoin(tasks, ', '))});
end
ress = unique(arrayfun(@(f) ent(f, 'res'), B, 'UniformOutput', false));
if numel(ress) > 1
    raise({sprintf('Several resolutions (res %s); set "res".', strjoin(ress, ', '))});
end

msgs = {};
units = struct('id', {}, 'sub', {}, 'bold', {}, 'mask', {}, 'confounds', {}, 'space', {});
for i = 1:numel(B)
    b = B(i);
    u.id = regexprep(regexprep(b.name, '_(space|res|den|desc)-[a-zA-Z0-9]+', ''), '_bold\.nii(\.gz)?$', '');
    u.sub = b.ent.sub;
    u.bold = b.path;
    u.space = ent(b, 'space');
    u.mask = find1(L, b.ent, {'desc', 'brain'}, 'mask', img);
    e = rmfield(b.ent, intersect(fieldnames(b.ent), {'space', 'res', 'den', 'desc'}));
    u.confounds = find1(L, e, {'desc', 'confounds'}, 'timeseries', {'.tsv'});
    if isempty(u.mask)
        msgs{end+1} = sprintf('%s: no desc-brain_mask in its space.', u.id); %#ok<AGROW>
    end
    if isempty(u.confounds)
        msgs{end+1} = sprintf('%s: no desc-confounds_timeseries.tsv.', u.id); %#ok<AGROW>
    end
    units(end+1) = u; %#ok<AGROW>
end
if ~isempty(msgs)
    raise(msgs);
end
end

function p = find1(L, e, change, suffix, ext)
for k = 1:2:numel(change)
    e.(change{k}) = change{k + 1};
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

function v = ent(f, key)
v = '';
if isfield(f.ent, key)
    v = f.ent.(key);
end
end

function raise(msgs)
error('SeeCAT:bids', 'Input selection problems:\n  - %s', strjoin(msgs, '\n  - '));
end
