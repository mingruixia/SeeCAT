function [T, roots, info] = scan_dicom(dicom_dir)
% SCAN_DICOM  Find the subjects in a folder of DICOM files, before converting.
%   [T, roots, info] = seecat.bids.scan_dicom('D:/dicom')
%
% Reads the header of the first and last DICOM file in every folder that
% holds DICOM files (seecat.bids.dicom_header), then groups the folders
% into subjects:
%   - By PatientID, when every folder has a real one (not empty and not a
%     placeholder such as "anonymous", "xxxx" or "0000"). The label is the
%     folder name that all of a subject's folders share and no other
%     subject's folder has, taken nearest the top; this finds S001 in
%     S001/T1/..., T1/S001/... (one folder per modality, then per subject)
%     or S001/visit1/T1/... alike. With one subject, the folder above its
%     series, or DICOM_DIR itself, names it; without such a folder the
%     PatientID does.
%   - By folder, when IDs are missing or anonymised. With one folder per
%     subject (S001/..., S002/...) the top folders are the subjects. When
%     the top folders hold the same set of subfolders (T1/S001, REST/S001,
%     T1/S002, ...) and there are more of those than top folders, the
%     subfolders are the subjects and the top folders their modalities.
% Labels keep letters and digits (S_001 -> S001).
%
% T has one row per subject: subject, patient_id, studies (StudyInstanceUID
% count), folders, files and source (the folders converted for it, relative
% to DICOM_DIR). ROOTS{k} lists the folders of subject k: they hold only
% that subject's files, and dcm2niix converts each (with its subfolders).
% INFO has mode ('PatientID' or 'folders'), layout (a sentence for the
% log) and ignored (folders with files but no DICOM).
%
% A folder whose first and last DICOM files belong to different patients
% is an error: sort it, or convert it with seecat.bids.from_dicom(...,
% 'sub', ...).

dicom_dir = char(java.io.File(dicom_dir).getCanonicalPath());
[leaves, nfiles, H, ignored] = readLeaves(dicom_dir);
if isempty(leaves)
    error('SeeCAT:bids', 'No DICOM files found in %s.', dicom_dir);
end
rel = cellfun(@(f) relPath(f, dicom_dir), leaves, 'UniformOutput', false);
parts = cellfun(@(r) strsplit(r, '/'), rel, 'UniformOutput', false);
parts(strcmp(rel, '')) = {{}};

ids = cellfun(@(h) h.PatientID, H, 'UniformOutput', false);
if all(cellfun(@realID, ids))
    info.mode = 'PatientID';
    [keys, ~, g] = unique(ids, 'stable');
    labels = cell(size(keys));
    how = cell(size(keys));
    for k = 1:numel(keys)
        [labels{k}, how{k}] = labelFromFolders(parts, g == k, dicom_dir, keys{k});
    end
    labels = unduplicate(labels, keys, how);
else
    info.mode = 'folders';
    [g, labels, how] = groupByFolders(parts, dicom_dir);
    keys = arrayfun(@(k) strjoin(unique(ids(g == k), 'stable'), ', '), (1:numel(labels))', 'UniformOutput', false);
    [u, ~, j] = unique(labels);
    dup = u(accumarray(j(:), 1) > 1);
    if ~isempty(dup)
        error('SeeCAT:bids', 'Folders of %s give the same subject label sub-%s; rename them or convert them one by one.', ...
            dicom_dir, dup{1});
    end
end

n = numel(labels);
roots = cell(n, 1);
studies = zeros(n, 1);
folders = zeros(n, 1);
files = zeros(n, 1);
source = cell(n, 1);
for k = 1:n
    roots{k} = subtreeRoots(leaves, g == k, dicom_dir, n == 1);
    studies(k) = numel(unique(cellfun(@(h) h.StudyInstanceUID, H(g == k), 'UniformOutput', false)));
    folders(k) = nnz(g == k);
    files(k) = sum(nfiles(g == k));
    r = cellfun(@(f) relPath(f, dicom_dir), roots{k}, 'UniformOutput', false);
    r(strcmp(r, '')) = {'.'};
    source{k} = strjoin(r, '; ');
end
T = table(labels(:), keys(:), studies, folders, files, source, ...
    'VariableNames', {'subject', 'patient_id', 'studies', 'folders', 'files', 'source'});
info.layout = layoutText(info.mode, how, n);
if n == 1 && strcmp(info.mode, 'PatientID')
    info.layout = sprintf('One subject (PatientID %s), sub-%s.', keys{1}, labels{1});
end
info.ignored = cellfun(@(f) relPath(f, dicom_dir), ignored, 'UniformOutput', false);
end

function [leaves, nfiles, H, ignored] = readLeaves(dicom_dir)
% Folders with DICOM files: their file count and a header per folder
F = dir(fullfile(dicom_dir, '**', '*'));
F = F(~[F.isdir] & ~startsWith({F.name}, '.'));
F = F(cellfun(@isempty, regexpi({F.name}, otherFiles(), 'once')));
[folders, ~, j] = unique({F.folder});
leaves = {};
nfiles = [];
H = {};
ignored = {};
for k = 1:numel(folders)
    idx = find(j == k);
    first = [];
    for i = idx(1:min(3, end))'                    % the first DICOM among the first files
        first = seecat.bids.dicom_header(fullfile(F(i).folder, F(i).name));
        if ~isempty(first), break, end
    end
    if isempty(first)
        ignored{end+1} = folders{k}; %#ok<AGROW>
        continue
    end
    last = seecat.bids.dicom_header(fullfile(F(idx(end)).folder, F(idx(end)).name));
    if ~isempty(last) && ~strcmp(person(last), person(first))
        error('SeeCAT:bids', ['%s holds DICOM files of more than one patient (%s and %s). Put each ' ...
            'patient in a folder of their own, or convert the folder with ''sub''.'], folders{k}, ...
            person(first), person(last));
    end
    leaves{end+1} = char(java.io.File(folders{k}).getCanonicalPath()); %#ok<AGROW>
    nfiles(end+1) = numel(idx); %#ok<AGROW>
    H{end+1} = first; %#ok<AGROW>
end
leaves = leaves(:);
nfiles = nfiles(:);
H = H(:);
end

function p = person(h)
p = strjoin({h.PatientID, h.PatientName, h.PatientBirthDate}, '/');
end

function tf = realID(id)
tf = ~isempty(id) && isempty(regexpi(strtrim(id), ...
    '^(anon\w*|anonymi[sz]ed|unknown|none|null|n/?a|test|phantom|x+|0+|-+|\*+|\?+)$', 'once'));
end

function [lab, how] = labelFromFolders(parts, mine, dicom_dir, id)
% The folder name shared by all of this subject's folders and no others',
% nearest the top
own = parts(mine);
other = [{}, parts{~mine}];
common = own{1};
for i = 2:numel(own)
    common = common(ismember(common, own{i}));
end
cand = common(~ismember(common, other));
if ~any(~mine)
    lab = onlySubject(parts, dicom_dir);
    how = 'top';
elseif ~isempty(cand) && ~isempty(clean(cand{1}))
    lab = clean(cand{1});
    how = 'folder';
else
    lab = clean(id);
    how = 'id';
end
if isempty(lab)
    lab = clean(id);
    how = 'id';
end
end

function labels = unduplicate(labels, keys, how)
% Subjects that end up with one label are named by their PatientID instead
[~, ~, j] = unique(labels);
for d = find(accumarray(j(:), 1) > 1)'
    for k = find(j == d)'
        if ~strcmp(how{k}, 'id')
            labels{k} = clean(keys{k});
        end
    end
end
[u, ~, j] = unique(labels);
dup = u(accumarray(j(:), 1) > 1);
if ~isempty(dup)
    error('SeeCAT:bids', 'Two patients give the subject label sub-%s; convert them one by one with ''sub''.', dup{1});
end
end

function [g, labels, how] = groupByFolders(parts, dicom_dir)
% Subjects from the folder tree when the headers cannot tell people apart
depth = cellfun(@numel, parts);
top = cellfun(@(p) firstOr(p, 1), parts, 'UniformOutput', false);
tops = unique(top(depth >= 1));
level = 1;
if numel(tops) >= 2 && all(depth >= 2)
    second = cellfun(@(p) p{2}, parts, 'UniformOutput', false);
    perTop = cellfun(@(t) unique(second(strcmp(top, t))), tops, 'UniformOutput', false);
    names = [perTop{:}];
    [u, ~, j] = unique(names);
    shared = u(accumarray(j(:), 1) >= 2);
    more = numel(shared) > numel(tops);
    tie = numel(shared) == numel(tops) && modalityLike(tops) > modalityLike(shared);
    if (more || tie) && numel(shared) >= 0.5 * numel(u)
        level = 2;                                % modality folders, then subject folders
    end
end
if numel(tops) < 2 || any(depth < level)
    g = ones(numel(parts), 1);                    % files in DICOM_DIR itself: one subject
    labels = {onlySubject(parts, dicom_dir)};
    how = {'top'};
    return
end
key = cellfun(@(p) p{level}, parts, 'UniformOutput', false);
[names, ~, g] = unique(key, 'stable');
labels = cellfun(@clean, names, 'UniformOutput', false);
how = repmat({sprintf('level%d', level)}, size(labels));
bad = find(cellfun(@isempty, labels), 1);
if ~isempty(bad)
    error('SeeCAT:bids', 'Folder "%s" gives no subject label (letters and digits); give the label with ''sub''.', names{bad});
end
end

function f = modalityLike(names)
% Share of NAMES that read like a scan type rather than a subject
pat = ['^(t1|t2|pd|flair|mprage|spgr|bravo|anat\w*|func\w*|rest\w*|bold|fmri|rs\w*|task\w*|' ...
    'dti|dwi|diff\w*|fmap|field\w*|epi|asl|perf\w*|swi|tof|localizer|survey|scout)'];
f = mean(~cellfun(@isempty, regexpi(names, pat, 'once')));
end

function lab = onlySubject(parts, dicom_dir)
% Label of the only subject: DICOM_DIR's name, or the name of its single
% subfolder when that looks like an ID (has a digit: S001, not DICOM)
lab = clean(baseName(dicom_dir));
top = cellfun(@(p) firstOr(p, 1), parts, 'UniformOutput', false);
if all(cellfun(@numel, parts) >= 2) && isscalar(unique(top)) && any(isstrprop(top{1}, 'digit')) ...
        && ~isempty(clean(top{1}))
    lab = clean(top{1});
end
end

function roots = subtreeRoots(leaves, mine, dicom_dir, only)
% The highest folders that hold this subject's DICOM folders and no others'
roots = {};
for i = find(mine)'
    r = leaves{i};
    while true
        up = fileparts(r);
        if strcmp(r, dicom_dir) || (strcmp(up, dicom_dir) && ~only) || numel(up) < numel(dicom_dir)
            break
        end
        inside = strcmp(leaves, up) | startsWith(leaves, [up filesep]);
        if any(inside & ~mine)
            break
        end
        r = up;
    end
    roots{end+1} = r; %#ok<AGROW>
end
roots = unique(roots);
keep = true(size(roots));
for i = 1:numel(roots)
    keep(i) = ~any(startsWith(roots{i}, strcat(roots([1:i-1, i+1:end]), filesep)));
end
roots = roots(keep);
roots = roots(:);
end

function t = layoutText(mode, how, n)
if strcmp(mode, 'PatientID')
    src = 'their PatientID';
    if all(strcmp(how, 'folder'))
        src = 'the folder that holds each person''s files';
    elseif all(strcmp(how, 'top'))
        src = 'the DICOM folder';
    end
    t = sprintf('%d subject(s) told apart by PatientID; labels from %s.', n, src);
elseif strcmp(how{1}, 'level2')
    t = sprintf(['%d subject(s): the top folders look like modalities, each with one folder per subject ' ...
        '(no usable PatientID).'], n);
elseif strcmp(how{1}, 'top')
    t = 'One subject: the DICOM folder (no usable PatientID).';
else
    t = sprintf('%d subject(s): one top folder per subject (no usable PatientID).', n);
end
end

function r = relPath(f, root)
r = strrep(f(numel(root) + 2:end), '\', '/');
end

function s = baseName(f)
[~, s, e] = fileparts(f);
s = [s e];
end

function s = clean(name)
s = regexprep(char(name), '[^a-zA-Z0-9]', '');
end

function v = firstOr(p, k)
v = '';
if numel(p) >= k
    v = p{k};
end
end

function r = otherFiles()
% Names of files that are not DICOM images
r = '\.(txt|md|csv|tsv|json|xlsx?|docx?|pdf|zip|gz|nii|log|png|jpe?g|html?|xml|mat|m|py)$|^DICOMDIR$';
end
