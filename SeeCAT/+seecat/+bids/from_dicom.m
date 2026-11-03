function T = from_dicom(dicom_dir, bids_dir, varargin)
% FROM_DICOM  Convert DICOM folders into a BIDS dataset.
%   T = seecat.bids.from_dicom(dicom_dir, bids_dir)                 % labels found automatically
%   T = seecat.bids.from_dicom(dicom_dir, bids_dir, 'sub', '01')
%   T = seecat.bids.from_dicom(dicom_dir, bids_dir, 'sub', '01', 'ses', 'pre', ...
%                              'rules', 'my_rules.json')
%
% Subject. With 'sub', DICOM_DIR (and everything below it) is that subject.
% Without it, seecat.bids.scan_dicom finds the subjects: by PatientID in the
% DICOM headers, or by the folder tree when IDs are missing or anonymised,
% so that one folder per subject (S001/...), one folder per modality with
% subject folders inside (T1/S001, REST/S001, ...) and deeper trees all
% work. Labels come from the folder names, keeping letters and digits
% (S_001 -> sub-S001). Run scan_dicom first to see what will be converted.
% A subject that fails is reported in T and the others still run.
%
% Session. With 'ses', every image goes into ses-<ses>. Without it:
%   - a subject scanned in one study (one visit) gets no session folder;
%   - a subject with several studies gets ses-1, ses-2, ... by study time;
%   - a study converted again keeps its session, and a new study of a
%     subject who already has ses-N folders gets the next number.
% Studies and their sessions are kept in code/seecat/from_dicom_sessions.tsv.
%
% dcm2niix (seecat.util.find_dcm2niix) converts every series into a
% temporary folder with BIDS sidecars, anonymised. Each series is then named
% by the first rule that matches its sidecar (seecat.bids.dicom_rules) and
% copied to <bids_dir>/sub-<sub>/[ses-<ses>/]<datatype>/ as .nii.gz + .json.
%   - Several series with the same name in a session get run-1, run-2, ...
%     in series order; a series with several echoes gets echo-1, echo-2, ...
%   - BOLD sidecars get TaskName.
%   - Series that match no rule, or give several images that are not
%     echoes, are not copied; the report says why.
%   - dataset_description.json is written if missing; participants.tsv
%     gets the subject if missing.
%
% Options:
%   'sub'        subject label (letters and digits; default: from folder names)
%   'ses'        session label (default: from the studies, see above)
%   'rules'      rules struct array or JSON file (default: dicom_rules())
%   'dcm2niix'   path to dcm2niix (default: found automatically)
%   'overwrite'  replace existing images (default false: keep them, so
%                converting again only adds what is missing)
%
% T is a table with one row per converted image: subject, session, series,
% description, bids (path relative to bids_dir, or '' when not copied) and
% note. Each subject's rows are also written to
% <bids_dir>/code/seecat/from_dicom_sub-<sub>[_ses-<ses>].tsv.

p = inputParser;
p.addParameter('sub', '', @(x) ischar(x) || isstring(x));
p.addParameter('ses', '', @(x) ischar(x) || isstring(x));
p.addParameter('rules', [], @(x) isempty(x) || isstruct(x) || ischar(x) || isstring(x));
p.addParameter('dcm2niix', '', @(x) ischar(x) || isstring(x));
p.addParameter('overwrite', false, @(x) islogical(x) || isnumeric(x));
p.parse(varargin{:});
o = p.Results;
sub = strtrim(char(o.sub));
ses = strtrim(char(o.ses));
if ~isempty(sub) && isempty(regexp(sub, '^[a-zA-Z0-9]+$', 'once'))
    error('SeeCAT:bids', 'Subject label "%s" must be letters and digits only.', sub);
end
if ~isempty(ses) && isempty(regexp(ses, '^[a-zA-Z0-9]+$', 'once'))
    error('SeeCAT:bids', 'Session label "%s" must be letters and digits only.', ses);
end
if ~exist(dicom_dir, 'dir')
    error('SeeCAT:bids', 'DICOM folder not found: %s', dicom_dir);
end
rules = seecat.bids.dicom_rules(o.rules);
[exe, ver] = seecat.util.find_dcm2niix(o.dcm2niix);
if ~isempty(sub)
    T = convertSubject({dicom_dir}, bids_dir, sub, ses, rules, exe, ver, o.overwrite);
    return
end

[S, folders, info] = seecat.bids.scan_dicom(dicom_dir);
labels = S.subject;
fprintf('DICOM to BIDS: %s\n', info.layout);
for k = 1:numel(info.ignored)
    fprintf('DICOM to BIDS: no DICOM files in %s; skipped.\n', info.ignored{k});
end
parts = cell(numel(folders), 1);
failed = {};
for k = 1:numel(folders)
    fprintf('DICOM to BIDS: sub-%s (%d of %d)\n', labels{k}, k, numel(folders));
    try
        parts{k} = convertSubject(folders{k}, bids_dir, labels{k}, ses, rules, exe, ver, o.overwrite);
    catch err
        if numel(folders) == 1
            rethrow(err);
        end
        parts{k} = cell2table({labels{k}, '', NaN, '', '', err.message}, 'VariableNames', columns());
        failed{end+1} = sprintf('sub-%s: %s', labels{k}, err.message); %#ok<AGROW>
    end
end
T = vertcat(parts{:});
if numel(failed) == numel(folders)
    error('SeeCAT:bids', 'No subject was converted:\n%s', strjoin(failed, '\n'));
end
end

function T = convertSubject(folders, bids_dir, sub, ses, rules, exe, ver, overwrite)
% 1. Convert everything into a temporary folder; FOLDERS hold only this
% subject's files
tmp = tempname;
mkdir(tmp);
cleanup = onCleanup(@() rmdir(tmp, 's'));
out = '';
for k = 1:numel(folders)
    % %t (study date and time) keeps series apart when one folder holds two studies
    cmd = sprintf('"%s" -b y -ba y -z y -f "%%t_%%s_%%p" -o "%s" "%s"', exe, tmp, folders{k});
    [st, o] = system(cmd);
    out = [out o]; %#ok<AGROW>
end
J = dir(fullfile(tmp, '*.json'));
if st ~= 0 && isempty(J)
    error('SeeCAT:dcm2niix', 'dcm2niix failed (exit %d):\n%s', st, out);
end

% 2. One record per image: sidecar, study, series number, rule
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
        nv = boldVolumes(m, nf);
        if nv > 0
            r.note = sprintf(['no rule matched, but it looks like BOLD fMRI (2D EPI, %d volumes); ' ...
                'add a rule for it to convert it'], nv);
        end
    end
    img(end+1) = r; %#ok<AGROW>
end
if isempty(img)
    error('SeeCAT:dcm2niix', 'dcm2niix produced no images from %s:\n%s', strjoin(folders, ', '), out);
end
[~, order] = sortrows([[img.study]', [img.series]', (1:numel(img))']);
img = img(order);

% 3. Sessions, one per study unless given
studies = unique([img.study]);
sesOf = sessions(bids_dir, sub, ses, studies);
imgSes = arrayfun(@(r) sesOf{studies == r.study}, img, 'UniformOutput', false);

% 4. Names: echoes within a series; runs across series with the same name
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
    base{i} = bidsName(sub, imgSes{i}, ent, ru.suffix, ru.datatype);
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

% 5. Copy into the dataset
if ~exist(bids_dir, 'dir')
    mkdir(bids_dir);
end
rel = repmat({''}, numel(img), 1);
for i = find(~cellfun(@isempty, base))'
    rel{i} = base{i};
    dst = fullfile(bids_dir, [rel{i} '.nii.gz']);
    if exist(dst, 'file') && ~overwrite
        img(i).note = 'already in the dataset; kept (overwrite replaces it)';
        continue
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
recordSessions(bids_dir, sub, studies, sesOf);

n = numel(img);
T = table(repmat({sub}, n, 1), imgSes(:), [img.series]', {img.desc}', rel, {img.note}', ...
    'VariableNames', columns());
tag = ['sub-' sub];
if numel(unique(sesOf)) == 1 && ~isempty(sesOf{1})
    tag = [tag '_ses-' sesOf{1}];
end
seecat.io.write_tsv(T, fullfile(bids_dir, 'code', 'seecat', ['from_dicom_' tag '.tsv']));
end

function c = columns()
c = {'subject', 'session', 'series', 'description', 'bids', 'note'};
end

function out = sessions(bids_dir, sub, ses, studies)
% Session label of each study (see the help); '' = no session folder
out = repmat({ses}, size(studies));
if ~isempty(ses)
    return
end
M = readSessions(bids_dir);
id = ['sub-' sub];
M = M(strcmp(M.participant_id, id), :);
key = studyKey(studies);
[known, at] = ismember(key, M.study);
out(known) = M.session_id(at(known));
new = find(~known);
if isempty(new)
    return
end
subDir = fullfile(bids_dir, id);
S = dir(fullfile(subDir, 'ses-*'));
S = S([S.isdir]);
flat = any(cellfun(@(d) exist(fullfile(subDir, d), 'dir') == 7, {'anat', 'func', 'fmap', 'dwi', 'perf'})) ...
    || any(cellfun(@isempty, M.session_id));
if isempty(S) && ~flat && numel(studies) == 1
    out{1} = '';                                    % one visit: no session folder
    return
end
if flat
    error('SeeCAT:bids', ['sub-%s already has data without sessions, and this is another study ' ...
        '(scanned %s). Give the session label to add it.'], sub, key{new(1)});
end
taken = str2double([regexprep({S.name}, '^ses-', ''), M.session_id(:)']);
next = max([0, taken(isfinite(taken))]);
for k = new(:)'
    next = next + 1;
    out{k} = sprintf('%d', next);
end
end

function recordSessions(bids_dir, sub, studies, sesOf)
M = readSessions(bids_dir);
id = ['sub-' sub];
key = studyKey(studies);
M = M(~(strcmp(M.participant_id, id) & ismember(M.study, key)), :);
M = [M; table(repmat({id}, numel(key), 1), key(:), sesOf(:), ...
    'VariableNames', {'participant_id', 'study', 'session_id'})];
M = sortrows(M, {'participant_id', 'study'});
seecat.io.write_tsv(M, sessionsFile(bids_dir));
end

function M = readSessions(bids_dir)
f = sessionsFile(bids_dir);
M = table(cell(0, 1), cell(0, 1), cell(0, 1), 'VariableNames', {'participant_id', 'study', 'session_id'});
if exist(f, 'file')
    R = seecat.io.read_tsv(f);
    M = table(asText(R.participant_id), asText(R.study), asText(R.session_id), ...
        'VariableNames', M.Properties.VariableNames);
end
end

function c = asText(x)
% TSV columns may come back as numbers or with NaN for empty cells
if isnumeric(x)
    c = arrayfun(@(v) sprintf('%.0f', v), x, 'UniformOutput', false);
    c(isnan(x)) = {''};
else
    c = cellstr(string(x));
    c(ismissing(string(x))) = {''};
end
c = c(:);
end

function f = sessionsFile(bids_dir)
f = fullfile(bids_dir, 'code', 'seecat', 'from_dicom_sessions.tsv');
end

function k = studyKey(studies)
% Study date and time as dcm2niix writes it (yyyymmddHHMMSS; 0 when missing)
k = arrayfun(@(s) sprintf('%.0f', s), studies, 'UniformOutput', false);
end

function n = boldVolumes(m, nii)
% Volumes of a series that looks like BOLD fMRI (2D EPI, not diffusion,
% 20 or more volumes); 0 otherwise
n = 0;
seq = char(strjoin(string(field(m, 'ScanningSequence', '')), '\'));
type = char(strjoin(string(field(m, 'ImageType', '')), '\'));
if ~contains(seq, 'EP') || strcmpi(field(m, 'MRAcquisitionType', '2D'), '3D') || contains(type, 'DERIVED') ...
        || exist(regexprep(nii, '\.nii\.gz$', '.bval'), 'file')
    return
end
try
    h = seecat.io.nii_info(nii);
catch
    return
end
if h.dim(4) >= 20
    n = h.dim(4);
end
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
