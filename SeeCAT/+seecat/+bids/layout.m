function L = layout(root)
% LAYOUT  Index the raw data files of a BIDS dataset.
%   L = seecat.bids.layout(bids_dir)
%
% Walks sub-*/[ses-*]/<datatype>/ only; derivatives, sourcedata, code and
% hidden folders are not entered.
%
% L.root         dataset folder (absolute)
% L.description  dataset_description.json as a struct ([] if absent)
% L.subjects     sorted subject labels (without "sub-")
% L.files        struct array, one element per data file:
%                  path, dir, name, sub, ses, datatype, suffix, ext, ent
%                (ent holds every key-value entity, e.g. ent.task)
% L.sidecars     the same fields for every .json file at any level; used by
%                seecat.bids.metadata for the inheritance principle.

root = char(root);
if ~exist(root, 'dir')
    error('SeeCAT:bids', 'BIDS folder not found: %s', root);
end
root = absolutePath(root);
L.root = root;
L.description = [];
f = fullfile(root, 'dataset_description.json');
if exist(f, 'file')
    L.description = jsondecode(fileread(f));
end

files = {};
sidecars = topLevelJson(root);
subDirs = listDirs(root, 'sub-');
L.subjects = sort(erase(subDirs, 'sub-'));
for s = 1:numel(subDirs)
    subDir = fullfile(root, subDirs{s});
    sidecars = [sidecars; jsonIn(subDir)]; %#ok<AGROW>
    sesDirs = listDirs(subDir, 'ses-');
    if isempty(sesDirs)
        dataDirs = {subDir};
    else
        dataDirs = fullfile(subDir, sesDirs);
        for k = 1:numel(dataDirs)
            sidecars = [sidecars; jsonIn(dataDirs{k})]; %#ok<AGROW>
        end
    end
    for k = 1:numel(dataDirs)
        for dt = listDirs(dataDirs{k}, '')
            d = fullfile(dataDirs{k}, dt{1});
            [data, json] = filesIn(d, dt{1});
            files = [files; data]; %#ok<AGROW>
            sidecars = [sidecars; json]; %#ok<AGROW>
        end
    end
end
L.files = toStruct(files);
L.sidecars = toStruct(sidecars);
end

function p = absolutePath(p)
d = dir(p);
p = d(1).folder;          % dir() on a folder lists "." first, with an absolute folder
end

function names = listDirs(d, prefix)
l = dir(d);
l = l([l.isdir]);
names = {l.name};
names = names(~startsWith(names, '.'));
if ~isempty(prefix)
    names = names(startsWith(names, prefix));
end
end

function out = topLevelJson(root)
l = dir(fullfile(root, '*.json'));
names = {l.name};
names = names(~ismember(names, {'dataset_description.json', 'participants.json', 'genetic_info.json'}));
out = cellfun(@(n) parse(root, n, ''), names(:), 'UniformOutput', false);
out = out(~cellfun(@isempty, out));
end

function out = jsonIn(d)
l = dir(fullfile(d, '*.json'));
out = cellfun(@(n) parse(d, n, ''), {l.name}', 'UniformOutput', false);
out = out(~cellfun(@isempty, out));
end

function [data, json] = filesIn(d, datatype)
l = dir(d);
l = l(~[l.isdir] & ~startsWith({l.name}, '.'));
recs = cellfun(@(n) parse(d, n, datatype), {l.name}', 'UniformOutput', false);
recs = recs(~cellfun(@isempty, recs));
isJson = cellfun(@(r) strcmp(r.ext, '.json'), recs);
data = recs(~isJson);
json = recs(isJson);
end

function r = parse(d, name, datatype)
% sub-01_ses-1_task-rest_run-1_bold.nii.gz -> entities + suffix + extension
r = [];
dot = find(name == '.', 1);
if isempty(dot)
    return
end
stem = name(1:dot-1);
parts = strsplit(stem, '_');
ent = struct();
for i = 1:numel(parts) - 1
    kv = regexp(parts{i}, '^([a-zA-Z0-9]+)-([a-zA-Z0-9]+)$', 'tokens', 'once');
    if isempty(kv)
        return                     % not a BIDS name
    end
    ent.(kv{1}) = kv{2};
end
if isempty(regexp(parts{end}, '^[a-zA-Z0-9]+$', 'once'))
    return
end
if ~isempty(datatype) && ~isfield(ent, 'sub')
    return                         % files in a datatype folder must start with sub-
end
r.path = fullfile(d, name);
r.dir = d;
r.name = name;
r.sub = field(ent, 'sub');
r.ses = field(ent, 'ses');
r.datatype = datatype;
r.suffix = parts{end};
r.ext = name(dot:end);
r.ent = ent;
end

function v = field(s, k)
v = '';
if isfield(s, k)
    v = s.(k);
end
end

function s = toStruct(c)
template = struct('path', {}, 'dir', {}, 'name', {}, 'sub', {}, 'ses', {}, ...
    'datatype', {}, 'suffix', {}, 'ext', {}, 'ent', {});
if isempty(c)
    s = template;
else
    s = vertcat(c{:});
end
end
