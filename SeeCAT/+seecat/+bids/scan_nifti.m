function [T, groups, info] = scan_nifti(src, varargin)
% SCAN_NIFTI  Find the subjects and images in a folder of NIfTI files.
%   [T, groups, info] = seecat.bids.scan_nifti('D:/export')
%   [...] = seecat.bids.scan_nifti(src, 'sub', '01')                    % all one subject
%   [...] = seecat.bids.scan_nifti(src, 'subject_pattern', 'Subj(\d+)') % label from the path
%
% Images are .nii, .nii.gz and Analyze .img/.hdr pairs, in any folder below
% SRC (folders named derivatives, and hidden ones, are left out). A .json
% with the same name is the image's sidecar (as written by dcm2niix and
% most scanner export tools); without one, the description, volume count
% and TR come from the path and the header. A folder of numbered 3D images
% without sidecars (vol0001.nii, vol0002.nii, ...: 10 or more of the same
% size) is one run.
%
% Subjects, in this order:
%   1. 'sub' given: everything is that subject.
%   2. 'subject_pattern' given: a regular expression with one token,
%      matched against each image's path relative to SRC; its token is the
%      label. Images it does not match are listed in info.ignored.
%   3. Folders named sub-<label> (a BIDS-like tree).
%   4. The shallowest folder level whose names all look like subject IDs
%      (they contain a digit and are not dates, sessions or series folders
%      such as 07_rest): one folder per subject (S001/...), or modality
%      folders with subject folders inside (FunRaw/S001, T1Raw/S001).
%   5. File names that start with a subject ID (S001_rest.nii, ...).
%   6. The PatientID of the sidecars.
%   7. One subject, named after SRC.
% Labels keep the ID and drop a name after it: sub173_zhangsan -> 173,
% S_001 -> S001, sub-01 -> 01.
%
% Sessions: folders named ses-<label>, or pre/post/baseline/followup/
% visit1/v1/time1/t1 ..., give the session label. Otherwise images are
% grouped into scanning visits (sidecar StudyInstanceUID and acquisition
% time, or date folders such as 2026-10-13T11_09_18), and
% seecat.bids.organize numbers several visits ses-1, ses-2, ...
%
% T has one row per subject: subject, source (folders, relative to SRC),
% images and visits. GROUPS{k} is the image list of subject k for
% seecat.bids.organize. INFO has layout (a sentence for the log) and
% ignored (images not assigned to a subject).

p = inputParser;
p.addParameter('sub', '', @(x) ischar(x) || isstring(x));
p.addParameter('subject_pattern', '', @(x) ischar(x) || isstring(x));
p.parse(varargin{:});
o = p.Results;
if ~exist(src, 'dir')
    error('SeeCAT:bids', 'Folder not found: %s', src);
end
src = char(java.io.File(src).getCanonicalPath());
R = findImages(src);
if isempty(R)
    error('SeeCAT:bids', 'No NIfTI images (.nii, .nii.gz, .img) found in %s.', src);
end
info.ignored = {};

% subjects
parts = cellfun(@(r) folderParts(r), {R.source}, 'UniformOutput', false);
level = zeros(numel(R), 1);                % folder level of the subject (0: none)
sub = strtrim(char(o.sub));
pat = strtrim(char(o.subject_pattern));
if ~isempty(sub)
    if isempty(regexp(sub, '^[a-zA-Z0-9]+$', 'once'))
        error('SeeCAT:bids', 'Subject label "%s" must be letters and digits only.', sub);
    end
    lab = repmat({sub}, numel(R), 1);
    info.layout = sprintf('everything in %s is sub-%s', src, sub);
elseif ~isempty(pat)
    lab = cell(numel(R), 1);
    for i = 1:numel(R)
        tok = regexp(R(i).source, pat, 'tokens', 'once');
        if isempty(tok)
            lab{i} = '';
        else
            lab{i} = regexprep(tok{1}, '[^a-zA-Z0-9]', '');
        end
    end
    info.layout = sprintf('subjects from the pattern %s', pat);
else
    [lab, level, info.layout] = subjects(R, parts, src);
end
none = cellfun(@isempty, lab);
info.ignored = {R(none).source}';
R = R(~none);
lab = lab(~none);
parts = parts(~none);
level = level(~none);
if isempty(R)
    error('SeeCAT:bids', 'No image in %s could be given a subject (%s).', src, info.layout);
end

% descriptions of images without a sidecar; the path as it may be shown in
% the dataset, with the subject's folder (often an ID and a name) as sub-<label>
[R.public] = deal('');
for i = 1:numel(R)
    if isempty(R(i).json)
        R(i).desc = description(R(i), parts{i}, level(i), lab{i});
        R(i).meta.SeriesDescription = R(i).desc;
    end
    q = strsplit(R(i).source, '/');
    if level(i) > 0
        q{level(i)} = ['sub-' lab{i}];
    elseif numel(q) == 1
        q{1} = regexprep(q{1}, '^[^_\-.]+', ['sub-' lab{i}]);   % ID at the start of the file name
    end
    R(i).public = strjoin(q, '/');
end
[subs, ~, g] = unique(lab, 'stable');
groups = cell(numel(subs), 1);
src_ = cell(numel(subs), 1);
nimg = zeros(numel(subs), 1);
visits = zeros(numel(subs), 1);
for k = 1:numel(subs)
    idx = find(g == k);
    G = visitsOf(R(idx), parts(idx), level(idx));
    [~, ord] = sortrows([cellfun(@str2double, {G.study})', [G.series]']);
    groups{k} = G(ord);
    top = unique(cellfun(@(q) strjoin(q(1:max(level(idx(1)), 0)), '/'), parts(idx), 'UniformOutput', false));
    top(cellfun(@isempty, top)) = {'.'};
    src_{k} = strjoin(top, ', ');
    nimg(k) = numel(idx);
    visits(k) = numel(unique(strcat({G.study}, '|', {G.ses})));
end
T = table(subs(:), src_, nimg, visits, 'VariableNames', {'subject', 'source', 'images', 'visits'});
end

%% ---- images --------------------------------------------------------------

function R = findImages(src)
D = dir(fullfile(src, '**', '*'));
D = D(~[D.isdir]);
rel = strrep(cellfun(@(f, n) relPath(fullfile(f, n), src), {D.folder}, {D.name}, 'UniformOutput', false), '\', '/');
low = lower(rel);
skip = ~cellfun(@isempty, regexp(low, '(^|/)(derivatives|\.[^/]*)(/|$)', 'once'));
isImg = (endsWith(low, '.nii') | endsWith(low, '.nii.gz') | endsWith(low, '.img')) & ~skip;
R = struct('files', {}, 'json', {}, 'meta', {}, 'study', {}, 'ses', {}, 'series', {}, ...
    'desc', {}, 'source', {}, 'aux', {}, 'dim', {}, 'tr', {});
for i = find(isImg)
    f = fullfile(D(i).folder, D(i).name);
    stem = regexprep(f, '(\.nii\.gz|\.nii|\.img)$', '', 'ignorecase');
    hdr = f;
    if endsWith(low{i}, '.img')
        hdr = [stem '.hdr'];
        if ~exist(hdr, 'file')
            continue
        end
    end
    try
        h = seecat.io.nii_info(hdr);
    catch
        continue                                 % not an image we can read
    end
    r.files = {f};
    r.json = '';
    r.meta = struct();
    if exist([stem '.json'], 'file')
        r.json = [stem '.json'];
        try
            r.meta = jsondecode(fileread(r.json));
        catch
            r.json = '';
        end
    end
    r.study = '0';
    r.ses = '';
    r.series = field(r.meta, 'SeriesNumber', NaN);
    r.desc = char(string(field(r.meta, 'SeriesDescription', field(r.meta, 'ProtocolName', ''))));
    r.source = rel{i};
    r.aux = {};
    for e = {'.bval', '.bvec'}
        if exist([stem e{1}], 'file')
            r.aux{end+1} = [stem e{1}];
        end
    end
    r.dim = h.dim;
    r.tr = h.tr;
    if isempty(r.json)
        r.meta = synthesize(h);
    end
    R(end+1) = r; %#ok<AGROW>
end
R = mergeVolumes(R);
% series order for images without a series number: their path order
n = isnan([R.series]);
if any(n)
    [~, ord] = sort({R(n).source});
    k = find(n);
    base = max([0, R(~n).series]);
    for j = 1:numel(ord)
        R(k(ord(j))).series = base + j;
    end
end
end

function m = synthesize(h)
% Sidecar fields guessed from the header (no sidecar)
m = struct('ImageType', {{'ORIGINAL'; 'PRIMARY'}});
if h.dim(4) == 1 && min(h.dim(1:3)) >= 100 && max(h.pixdim(1:3)) <= 1.5
    m.MRAcquisitionType = '3D';                % a structural volume
else
    m.MRAcquisitionType = '2D';
end
if h.dim(4) >= 20
    m.ScanningSequence = 'EP';
end
if isfinite(h.tr) && h.tr > 0
    m.RepetitionTime = h.tr;
end
end

function R = mergeVolumes(R)
% Numbered 3D images in one folder, without sidecars: one run
if isempty(R)
    return
end
folder = cellfun(@(s) fileparts(s), {R.source}, 'UniformOutput', false);
[~, name] = cellfun(@(s) fileparts(regexprep(s, '\.gz$', '')), {R.source}, 'UniformOutput', false);
key = strcat(folder, '|', regexprep(name, '\d+', '#'), '|', ...
    arrayfun(@(r) sprintf('%d_', r.dim(1:3)), R, 'UniformOutput', false));
cand = arrayfun(@(r) isempty(r.json) && r.dim(4) == 1, R) & contains(name, digitsPattern);
keep = true(size(R));
for k = reshape(unique(key(cand)), 1, [])
    idx = find(strcmp(key, k{1}) & cand);
    if numel(idx) < 10
        continue
    end
    [~, ord] = sortrows(cell2mat(cellfun(@numbers, name(idx)', 'UniformOutput', false)));
    idx = idx(ord);
    r = R(idx(1));
    r.files = [R(idx).files];
    r.dim(4) = numel(idx);
    r.source = [folder{idx(1)} '/' regexprep(name{idx(1)}, '\d+', '#') ' (' num2str(numel(idx)) ' volumes)'];
    r.source = regexprep(r.source, '^/', '');
    r.meta = synthesize(struct('dim', r.dim, 'pixdim', [2 2 2 r.tr], 'tr', r.tr));
    R(idx(1)) = r;
    keep(idx(2:end)) = false;
end
R = R(keep);
end

function v = numbers(s)
% The numbers in a file name, last first (the volume number), padded to 4
v = fliplr(str2double(regexp(s, '\d+', 'match')));
v = [v, zeros(1, 4 - numel(v))];
v = v(1:4);
end

%% ---- subjects ------------------------------------------------------------

function [lab, level, how] = subjects(R, parts, src)
n = numel(R);
level = zeros(n, 1);
% BIDS-like sub-<label> folders
lab = cell(n, 1);
for i = 1:n
    k = find(startsWith(parts{i}, 'sub-'), 1);
    if ~isempty(k)
        lab{i} = regexprep(parts{i}{k}(5:end), '[^a-zA-Z0-9]', '');
        level(i) = k;
    end
end
if all(~cellfun(@isempty, lab))
    how = 'subjects from sub-<label> folders';
    return
end
% the shallowest folder level of subject IDs
depth = cellfun(@numel, parts);
for L = 1:max([depth, 0])
    if any(depth < L)
        break
    end
    names = cellfun(@(q) q{L}, parts, 'UniformOutput', false);
    if ~all(cellfun(@subjectLike, names))
        continue
    end
    if seriesLevel(R, names)
        continue
    end
    lab = cellfun(@cleanLabel, names, 'UniformOutput', false);
    level(:) = L;
    u = unique(names, 'stable');
    how = sprintf('subjects from folder names at level %d (e.g. %s -> sub-%s)', L, ...
        u{1}, cleanLabel(u{1}));
    if L > 1
        how = sprintf('%s, below %s', how, strjoin(unique(cellfun(@(q) q{1}, parts, 'UniformOutput', false)), ', '));
    end
    return
end
% file names that start with an ID
[~, stems] = cellfun(@(s) fileparts(regexprep(s, '\.gz$', '')), {R.source}, 'UniformOutput', false);
first = regexp(stems, '^[^_\-.]+(?=[_\-.])', 'match', 'once');
if all(cellfun(@(s) ~isempty(s) && subjectLike(s), first)) && numel(unique(first)) > 1
    lab = cellfun(@cleanLabel, first(:), 'UniformOutput', false);
    how = sprintf('subjects from the start of the file names (e.g. %s -> sub-%s)', stems{1}, lab{1});
    return
end
% PatientID
ids = arrayfun(@(r) char(string(field(r.meta, 'PatientID', ''))), R, 'UniformOutput', false);
if all(cellfun(@realID, ids)) && numel(unique(ids)) > 1
    lab = cellfun(@cleanLabel, ids(:), 'UniformOutput', false);
    how = 'subjects from the PatientID of the sidecars';
    return
end
% one subject: the folder's name, else its PatientID
[~, name] = fileparts(src);
l = cleanLabel(name);
if ~subjectLike(name) && all(cellfun(@realID, ids)) && isscalar(unique(ids))
    l = cleanLabel(ids{1});
end
if isempty(l)
    error('SeeCAT:bids', ['Cannot tell the subject of the images in %s: give the subject label ' ...
        '(''sub'') or a subject pattern.'], src);
end
lab = repmat({l}, n, 1);
how = sprintf('one subject, sub-%s (from %s)', l, name);
end

function tf = subjectLike(s)
low = lower(s);
tf = ~isempty(regexp(s, '\d', 'once')) ...
    && isempty(regexp(low, '^\d{4}[-_.]?\d{2}[-_.]?\d{2}', 'once')) ...          % a date
    && ~sessionLike(s) ...
    && isempty(regexp(low, '^(t1|t2|t1w|t2w|pd|dti|dwi|fmri|bold)[-_]?(raw|img|w)?$', 'once'));
end

function tf = sessionLike(s)
tf = ~isempty(regexpi(s, ['^(ses-[a-z0-9]+|(visit|session|time|wave|timepoint|tp|v|t)[-_]?\d+|' ...
    'pre|post|baseline|base|follow[-_]?up|fu\d*)$'], 'once'));
end

function tf = seriesLevel(R, names)
% Folders of single series, e.g. 07_Math_AI_trust1: each holds one series
% and the names start with the series number
if mean(~cellfun(@isempty, regexp(names, '^\d+[_\-]', 'once'))) < 0.5
    tf = false;
    return
end
[~, ~, g] = unique(names);
tf = true;
for k = 1:max(g)
    if numel(unique([R(g == k).series])) > 1
        tf = false;
        return
    end
end
end

function l = cleanLabel(s)
s = char(s);
s = regexprep(s, '^sub-', '');
s = regexprep(s, '^(subject|subj|sub)[-_ ]?(?=[a-zA-Z0-9])', '', 'ignorecase');
tok = regexp(s, '[^_\-\s.]+', 'match');
keep = {};
seenDigit = false;
for t = tok
    hasDigit = ~isempty(regexp(t{1}, '\d', 'once'));
    if seenDigit && ~hasDigit
        break                                     % a name after the ID
    end
    keep{end+1} = t{1}; %#ok<AGROW>
    seenDigit = seenDigit || hasDigit;
end
l = regexprep(strjoin(keep, ''), '[^a-zA-Z0-9]', '');
end

function tf = realID(id)
s = lower(strtrim(id));
tf = ~isempty(s) && isempty(regexp(s, '^(anon\w*|unknown|none|n/?a|x+|0+|\*+|-+)$', 'once'));
end

%% ---- visits and descriptions ---------------------------------------------

function G = visitsOf(G, parts, level)
% Session label from folders, else the visit key (yyyymmddHHMMSS)
for i = 1:numel(G)
    q = parts{i}(level(i) + 1:end);
    s = q(cellfun(@sessionLike, q));
    if ~isempty(s)
        G(i).ses = regexprep(regexprep(s{1}, '^ses-', '', 'ignorecase'), '[^a-zA-Z0-9]', '');
    end
    d = q(~cellfun(@isempty, regexp(q, '^\d{4}[-_.]?\d{2}[-_.]?\d{2}', 'once')));
    if ~isempty(d)
        k = regexprep(d{1}, '\D', '');
        G(i).study = [k repmat('0', 1, max(0, 14 - numel(k)))];
        G(i).study = G(i).study(1:14);
    end
end
% sidecars: one visit per StudyInstanceUID (or day), at its first acquisition
uid = arrayfun(@(r) char(string(field(r.meta, 'StudyInstanceUID', ''))), G(:), 'UniformOutput', false);
t = arrayfun(@(r) acqTime(r.meta), G(:), 'UniformOutput', false);
has = ~cellfun(@isempty, t);
for i = find(has)'
    if isempty(uid{i})
        uid{i} = t{i}(1:8);
    end
end
for u = reshape(unique(uid(has)), 1, [])
    idx = find(has & strcmp(uid, u{1}));
    k = min(cellfun(@str2double, t(idx)));
    for i = idx(:)'
        if strcmp(G(i).study, '0')
            G(i).study = sprintf('%.0f', k);
        end
    end
end
% images without a visit join the only visit there is
known = unique({G(~strcmp({G.study}, '0')).study});
if isscalar(known)
    [G(strcmp({G.study}, '0')).study] = deal(known{1});
end
end

function s = acqTime(m)
% yyyymmddHHMMSS of the acquisition, '' when unknown
s = '';
v = char(string(field(m, 'AcquisitionDateTime', '')));
if isempty(v) && isfield(m, 'AcquisitionDate')
    v = [char(string(m.AcquisitionDate)) 'T' char(string(field(m, 'AcquisitionTime', '000000')))];
end
d = regexprep(regexprep(v, '\..*$', ''), '\D', '');
if numel(d) >= 8
    s = [d repmat('0', 1, max(0, 14 - numel(d)))];
    s = s(1:14);
end
end

function d = description(r, q, level, lab)
% For an image without a sidecar: the folders that are not the subject,
% session or a date, and the file name without the subject label
keep = q;
if level > 0
    keep(level) = [];
end
keep = keep(~cellfun(@sessionLike, keep) & cellfun(@isempty, regexp(keep, '^\d{4}[-_.]?\d{2}[-_.]?\d{2}', 'once')));
[~, stem] = fileparts(regexprep(r.source, '(\.nii)?\.gz$|\.nii$|\.img$', ''));
stem = regexprep(stem, ['(^|[_\-])(sub-?|subj-?)?' regexptranslate('escape', lab) '(?=[_\-]|$)'], '', 'ignorecase');
stem = regexprep(stem, '^[_\-]+|[_\-]+$', '');
d = strjoin([keep, {stem}], '/');
d = regexprep(d, '/+$', '');
end

function q = folderParts(rel)
d = fileparts(rel);
if isempty(d)
    q = {};
else
    q = strsplit(d, '/');
end
end

function r = relPath(f, root)
r = f(numel(root) + 2:end);
end

function v = field(s, name, dflt)
if isfield(s, name)
    v = s.(name);
else
    v = dflt;
end
end
