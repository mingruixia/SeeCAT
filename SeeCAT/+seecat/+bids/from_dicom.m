function T = from_dicom(dicom_dir, bids_dir, varargin)
% FROM_DICOM  Convert one subject's (or session's) DICOM folder into BIDS.
%   T = seecat.bids.from_dicom(dicom_dir, bids_dir, 'sub', '01')
%   T = seecat.bids.from_dicom(dicom_dir, bids_dir, 'sub', '01', 'ses', 'pre', ...
%                              'rules', 'my_rules.json')
%
% dcm2niix (seecat.util.find_dcm2niix) converts every series into a
% temporary folder with BIDS sidecars, anonymised. Each series is then named
% by the first rule that matches its sidecar (seecat.bids.dicom_rules) and
% copied to <bids_dir>/sub-<sub>/[ses-<ses>/]<datatype>/ as .nii.gz + .json.
%   - Several series with the same name get run-1, run-2, ... in series
%     order; a series with several echoes gets echo-1, echo-2, ...
%   - BOLD sidecars get TaskName.
%   - Series that match no rule, or give several images that are not
%     echoes, are not copied; the report says why.
%   - dataset_description.json is written if missing; participants.tsv
%     gets the subject if missing.
%
% Options:
%   'sub'        subject label (required; letters and digits)
%   'ses'        session label (default: none)
%   'rules'      rules struct array or JSON file (default: dicom_rules())
%   'dcm2niix'   path to dcm2niix (default: found automatically)
%   'overwrite'  replace existing files (default false: error)
%
% T is a table with one row per converted image: series, description,
% bids (path relative to bids_dir, or '' when not copied) and note. It is
% also written to <bids_dir>/code/seecat/from_dicom_sub-<sub>[_ses-<ses>].tsv.

p = inputParser;
p.addParameter('sub', '', @(x) ischar(x) || isstring(x));
p.addParameter('ses', '', @(x) ischar(x) || isstring(x));
p.addParameter('rules', [], @(x) isempty(x) || isstruct(x) || ischar(x) || isstring(x));
p.addParameter('dcm2niix', '', @(x) ischar(x) || isstring(x));
p.addParameter('overwrite', false, @(x) islogical(x) || isnumeric(x));
p.parse(varargin{:});
o = p.Results;
sub = char(o.sub);
ses = char(o.ses);
if isempty(regexp(sub, '^[a-zA-Z0-9]+$', 'once'))
    error('SeeCAT:bids', 'Give the subject label with ''sub'' (letters and digits only).');
end
if ~isempty(ses) && isempty(regexp(ses, '^[a-zA-Z0-9]+$', 'once'))
    error('SeeCAT:bids', 'Session label "%s" must be letters and digits only.', ses);
end
if ~exist(dicom_dir, 'dir')
    error('SeeCAT:bids', 'DICOM folder not found: %s', dicom_dir);
end
rules = seecat.bids.dicom_rules(o.rules);
[exe, ver] = seecat.util.find_dcm2niix(o.dcm2niix);

% 1. Convert everything into a temporary folder
tmp = tempname;
mkdir(tmp);
cleanup = onCleanup(@() rmdir(tmp, 's'));
% %t (study date and time) keeps series apart when one folder holds two studies
cmd = sprintf('"%s" -b y -ba y -z y -f "%%t_%%s_%%p" -o "%s" "%s"', exe, tmp, dicom_dir);
[st, out] = system(cmd);
J = dir(fullfile(tmp, '*.json'));
if st ~= 0 && isempty(J)
    error('SeeCAT:dcm2niix', 'dcm2niix failed (exit %d):\n%s', st, out);
end

% 2. One record per image: sidecar, series number, rule
img = struct('json', {}, 'nii', {}, 'meta', {}, 'study', {}, 'series', {}, 'desc', {}, 'rule', {}, 'note', {});
for i = 1:numel(J)
    jf = fullfile(tmp, J(i).name);
    nf = regexprep(jf, '\.json$', '.nii.gz');
    if ~exist(nf, 'file')
        continue                                   % e.g. a sidecar without an image
    end
    m = jsondecode(fileread(jf));
    r.json = jf;
    r.nii = nf;
    r.meta = m;
    r.study = str2double(regexp(J(i).name, '^\d+', 'match', 'once'));
    if isnan(r.study)
        r.study = 0;                               % no study time in the DICOM
    end
    r.series = field(m, 'SeriesNumber', NaN);
    r.desc = char(string(field(m, 'SeriesDescription', field(m, 'ProtocolName', ''))));
    r.rule = firstRule(rules, m);
    r.note = '';
    if r.rule == 0
        r.note = 'no rule matched';
    end
    img(end+1) = r; %#ok<AGROW>
end
if isempty(img)
    error('SeeCAT:dcm2niix', 'dcm2niix produced no images from %s:\n%s', dicom_dir, out);
end
[~, order] = sortrows([[img.study]', [img.series]', (1:numel(img))']);
img = img(order);

% 3. Names: echoes within a series; runs across series with the same name
base = cell(numel(img), 1);
series = [img.series];
sid = findgroups([img.study]', series');            % one id per study + series
for i = 1:numel(img)
    if img(i).rule == 0
        continue
    end
    ru = rules(img(i).rule);
    same = find(sid' == sid(i) & [img.rule] == img(i).rule);
    ent = ru.entities;
    if numel(same) > 1
        echoes = arrayfun(@(k) field(img(k).meta, 'EchoNumber', NaN), same);
        if all(isfinite(echoes)) && numel(unique(echoes)) == numel(same)
            ent.echo = sprintf('%d', field(img(i).meta, 'EchoNumber', NaN));
        else
            img(i).note = sprintf('series gave %d images that are not echoes; not copied', numel(same));
            img(i).rule = 0;
            continue
        end
    end
    base{i} = bidsName(sub, ses, ent, ru.suffix, ru.datatype);
end
keyNoEcho = regexprep(base, '_echo-\d+', '');
used = ~cellfun(@isempty, base);
for k = unique(keyNoEcho(used))'
    idx = find(strcmp(keyNoEcho, k{1}));
    s = unique(sid(idx), 'stable');
    if numel(s) > 1
        for i = idx(:)'
            base{i} = addRun(base{i}, find(s == sid(i)));
        end
    end
end

% 4. Copy into the dataset
if ~exist(bids_dir, 'dir')
    mkdir(bids_dir);
end
rel = repmat({''}, numel(img), 1);
for i = find(~cellfun(@isempty, base))'
    rel{i} = base{i};
    dst = fullfile(bids_dir, [rel{i} '.nii.gz']);
    if exist(dst, 'file') && ~o.overwrite
        error('SeeCAT:bids', '%s exists; use ''overwrite'', true to replace it.', dst);
    end
    if ~exist(fileparts(dst), 'dir')
        mkdir(fileparts(dst));
    end
    copyfile(img(i).nii, dst, 'f');
    m = img(i).meta;
    ru = rules(img(i).rule);
    if strcmp(ru.suffix, 'bold')
        m.TaskName = ru.entities.task;
        if ~isfield(m, 'SliceTiming')
            img(i).note = 'no SliceTiming in the DICOM; slice timing will be skipped unless set';
        end
    end
    seecat.util.write_json(fullfile(bids_dir, [rel{i} '.json']), m);
end
rel = cellfun(@(x) strrep([x '.nii.gz'], '\', '/'), rel, 'UniformOutput', false);
rel(cellfun(@isempty, base)) = {''};

describe(bids_dir, ver);
addParticipant(bids_dir, sub);

T = table([img.series]', {img.desc}', rel, {img.note}', 'VariableNames', {'series', 'description', 'bids', 'note'});
tag = ['sub-' sub];
if ~isempty(ses)
    tag = [tag '_ses-' ses];
end
seecat.io.write_tsv(T, fullfile(bids_dir, 'code', 'seecat', ['from_dicom_' tag '.tsv']));
end

function k = firstRule(rules, m)
k = 0;
for i = 1:numel(rules)
    if matches(rules(i).match, m, true) && ~matches(rules(i).exclude, m, false)
        k = i;
        return
    end
end
end

function tf = matches(pat, m, all_)
% all_ true: every field must match; false: true when any field matches
f = fieldnames(pat);
hits = false(numel(f), 1);
for i = 1:numel(f)
    v = field(m, f{i}, []);
    if iscell(v)
        v = strjoin(cellfun(@(x) char(string(x)), v, 'UniformOutput', false), '\');
    elseif isnumeric(v) || islogical(v)
        v = strjoin(arrayfun(@(x) sprintf('%g', x), v(:)', 'UniformOutput', false), '\');
    end
    hits(i) = ~isempty(regexpi(char(v), pat.(f{i}), 'once'));
end
if all_
    tf = all(hits);
else
    tf = any(hits);
end
end

function v = field(s, name, dflt)
if isfield(s, name)
    v = s.(name);
else
    v = dflt;
end
end

function rel = bidsName(sub, ses, ent, suffix, datatype)
order = {'task', 'acq', 'ce', 'rec', 'dir', 'run', 'echo', 'part'};
f = fieldnames(ent)';
unknown = setdiff(f, order);
if ~isempty(unknown)
    error('SeeCAT:bids', 'Unsupported entity in a DICOM rule: %s.', strjoin(unknown, ', '));
end
parts = {['sub-' sub]};
if ~isempty(ses)
    parts{end+1} = ['ses-' ses];
end
for k = order(ismember(order, f))
    v = char(string(ent.(k{1})));
    if isempty(regexp(v, '^[a-zA-Z0-9]+$', 'once'))
        error('SeeCAT:bids', 'Entity %s = "%s" must be letters and digits only.', k{1}, v);
    end
    parts{end+1} = [k{1} '-' v]; %#ok<AGROW>
end
name = [strjoin(parts, '_') '_' suffix];
d = ['sub-' sub];
if ~isempty(ses)
    d = [d '/ses-' ses];
end
rel = [d '/' datatype '/' name];
end

function s = addRun(s, n)
% Insert run-<n> after acq/ce/rec/dir and before echo/part (BIDS order)
[d, name] = fileparts(s);
parts = strsplit(name, '_');
keys = cellfun(@(x) strtok(x, '-'), parts(1:end - 1), 'UniformOutput', false);
pos = find(ismember(keys, {'echo', 'part'}), 1);
if isempty(pos)
    pos = numel(parts);
end
parts = [parts(1:pos - 1), {sprintf('run-%d', n)}, parts(pos:end)];
s = [d '/' strjoin(parts, '_')];
end

function describe(bids_dir, ver)
f = fullfile(bids_dir, 'dataset_description.json');
if exist(f, 'file')
    return
end
[~, name] = fileparts(char(java.io.File(bids_dir).getCanonicalPath()));
d = struct('Name', name, 'BIDSVersion', '1.10.0', 'DatasetType', 'raw', ...
    'GeneratedBy', struct('Name', {'dcm2niix', 'SeeCAT'}, 'Version', {ver, seecat.version()}));
seecat.util.write_json(f, d);
end

function addParticipant(bids_dir, sub)
f = fullfile(bids_dir, 'participants.tsv');
id = ['sub-' sub];
if exist(f, 'file')
    P = seecat.io.read_tsv(f);
    if ismember(id, P.participant_id)
        return
    end
    row = cell2table(repmat({''}, 1, width(P)), 'VariableNames', P.Properties.VariableNames);
    for c = P.Properties.VariableNames
        if isnumeric(P.(c{1}))
            row.(c{1}) = NaN;
        end
    end
    row.participant_id = {id};
    P = [P; row];
else
    P = table({id}, 'VariableNames', {'participant_id'});
end
seecat.io.write_tsv(P, f);
end
