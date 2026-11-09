function T = organize(img, bids_dir, sub, varargin)
% ORGANIZE  Name one subject's images and copy them into a BIDS dataset.
%   T = seecat.bids.organize(img, bids_dir, sub, 'rules', rules, ...)
%
% The step that seecat.bids.from_dicom (after dcm2niix) and
% seecat.bids.from_nifti share. IMG is a struct array, one element per
% image:
%   files   cell of image files: one .nii/.nii.gz/.img, or the 3D volumes
%           of one run in order (merged into one 4D image when copied)
%   json    its sidecar ('' if none)
%   meta    sidecar fields (struct; filled from the header when there is
%           no sidecar)
%   study   text key of the scanning visit, sortable by time
%           (yyyymmddHHMMSS, or '0' when unknown)
%   ses     session label given by the folders ('' = from the visits)
%   series  series number (or the order of the images)
%   desc    series description, shown in the report
%   source  where the image comes from, as shown in the report and used by
%           the 'names' option
%   aux     other files of the image (.bval, .bvec), copied alongside
%   dim     [x y z volumes]
%   tr      repetition time from the image header (NaN if none)
%   names   (optional) words that are the subject's name, taken out of
%           the sidecar and the report (seecat.bids.scan_nifti)
%
% Naming, in this order:
%   1. The first rule that matches (seecat.bids.dicom_rules) names the
%      image, or leaves it out ("skip": true).
%   2. Without a matching rule and with 'auto' (default true): localizers
%      are left out; field maps become magnitude1/magnitude2/phasediff
%      (Siemens/GE gradient echo) or epi with dir-<label> (spin-echo EPI);
%      a single-band reference becomes the sbref of the BOLD run that
%      follows it; a series that looks like BOLD (2D EPI, 20 or more
%      volumes) gets task-<series description without trailing digits>,
%      e.g. Math_AI_trust3 -> task-mathaitrust, run-3 of 4.
%   3. Several series with the same name get run-1, run-2, ... in series
%      order; several images of one series that are echoes get echo-<n>.
%   4. A T1w that is the copy without distortion correction (ImageType ND)
%      of another T1w of the same acquisition is left out.
%   5. 'names' (a table with source and bids columns, as T) replaces the
%      names: an edited bids path is used as given, an empty one leaves
%      the image out.
% Field maps get IntendedFor (bids:: URIs): the BOLD and sbref images
% acquired after them and before the next field map of the session;
% phasediff gets EchoTime1 and EchoTime2 from its magnitude images.
%
% Sidecars are copied without identifying fields (PatientName, PatientID,
% PatientBirthDate, ...), and the subject's name (the words of PatientName
% and the field names) is taken out of every text field that is kept
% (SeriesDescription, ProtocolName, ... also nested ones). Other free text
% is kept as it is: check it before sharing the dataset. participants.tsv gets the subject, with sex and
% age at the scan when the sidecars give them.
%
% Options: 'ses' (one label for all images), 'rules' (from dicom_rules),
% 'auto' (true), 'overwrite' (false), 'dryrun' (false: return T, write
% nothing), 'names' (table), 'link' (false: copy; true: hard links for
% .nii.gz images on the same drive, falling back to copies), 'tr' (seconds,
% for BOLD without a sidecar or a TR in the header), 'report' (file name
% prefix of the table in code/seecat), 'generator' (struct array of
% Name/Version for dataset_description.json).
%
% T: one row per image: subject, session, series, description, source,
% bids (path relative to bids_dir; '' when not copied) and note.

p = inputParser;
p.addParameter('ses', '');
p.addParameter('rules', []);
p.addParameter('auto', true);
p.addParameter('overwrite', false);
p.addParameter('dryrun', false);
p.addParameter('names', []);
p.addParameter('link', false);
p.addParameter('tr', []);
p.addParameter('report', 'import');
p.addParameter('generator', struct('Name', {}, 'Version', {}));
p.parse(varargin{:});
o = p.Results;
ses = strtrim(char(o.ses));
rules = seecat.bids.dicom_rules(o.rules);
n = numel(img);
if n == 0
    error('SeeCAT:bids', 'sub-%s: no images to organise.', sub);
end
[~, order] = sortrows([cellfun(@str2double, {img.study})', [img.series]', (1:n)']);
img = img(order);
for i = 1:n
    if isempty(img(i).dim)
        h = seecat.io.nii_info(img(i).files{1});
        img(i).dim = h.dim;
        if numel(img(i).files) > 1
            img(i).dim(4) = numel(img(i).files);
        end
        img(i).tr = h.tr;
    end
end

% 1-2. What each image is
A = repmat(struct('datatype', '', 'suffix', '', 'ent', struct(), 'how', '', 'note', '', 'target', 0), n, 1);
for i = 1:n
    A(i) = classify(img(i), rules, o.auto);
end
A = echoes(img, A);
A = notDistortionCorrected(img, A);

% Sessions, one per visit unless given
[sesOf, studies] = sessions(bids_dir, sub, ses, img);

% 3. Names, with runs across series
base = repmat({''}, n, 1);
for i = 1:n
    if ~isempty(A(i).suffix) && ~strcmp(A(i).suffix, 'sbref')
        base{i} = bidsName(sub, sesOf{i}, A(i).ent, A(i).suffix, A(i).datatype);
    end
end
base = addRuns(base, img, A);
[base, A] = attachSbref(base, img, A, sesOf);

% 5. Names given in a plan
if ~isempty(o.names)
    [base, A] = applyNames(base, A, img, o.names, sub);
end
[base, A] = unique_(base, A);
% an sbref follows the final name of its BOLD run, and goes when the run does
for i = find(strcmp({A.suffix}, 'sbref') & [A.target] > 0 & ~strcmp({A.how}, 'plan'))
    t = A(i).target;
    if isempty(base{i})
        continue
    elseif isempty(base{t}) || ~strcmp(A(t).suffix, 'bold')
        base{i} = '';
        A(i).note = joinNote(A(i).note, 'its BOLD run is left out; not copied');
    else
        base{i} = regexprep(base{t}, '_bold$', '_sbref');
        A(i).ent = A(t).ent;
    end
end

% Field map metadata
extra = fieldmapMeta(base, img, A, sesOf);

T = report(sub, sesOf, img, base, A);
if o.dryrun
    return
end

% Copy into the dataset
if ~exist(bids_dir, 'dir')
    mkdir(bids_dir);
end
for i = find(~cellfun(@isempty, base))'
    dst = fullfile(bids_dir, [base{i} '.nii.gz']);
    if exist(dst, 'file') && ~o.overwrite
        A(i).note = joinNote(A(i).note, 'already in the dataset; kept (overwrite replaces it)');
        continue
    end
    if ~exist(fileparts(dst), 'dir')
        mkdir(fileparts(dst));
    end
    m = sidecar(img(i), A(i), extra{i}, o.tr);
    if strcmp(A(i).suffix, 'bold') && ~isfield(m, 'RepetitionTime')
        A(i).note = joinNote(A(i).note, 'no RepetitionTime: give it (''tr'') before preprocessing');
    elseif strcmp(A(i).suffix, 'bold') && ~isfield(m, 'SliceTiming')
        A(i).note = joinNote(A(i).note, 'no SliceTiming in the source; slice timing will be skipped unless set');
    end
    copyImage(img(i), dst, o.link, field(m, 'RepetitionTime', []));
    for a = img(i).aux(:)'
        [~, ~, ext] = fileparts(a{1});
        copyfile(a{1}, fullfile(bids_dir, [base{i} ext]), 'f');
    end
    seecat.util.write_json(fullfile(bids_dir, [base{i} '.json']), m);
end
describe(bids_dir, o.generator);
addParticipant(bids_dir, sub, demographics(img));
recordSessions(bids_dir, sub, studies, sesOf, img);
T = report(sub, sesOf, img, base, A);
tag = ['sub-' sub];
if numel(unique(sesOf)) == 1 && ~isempty(sesOf{1})
    tag = [tag '_ses-' sesOf{1}];
end
W = T;
if isfield(img, 'public')                % no names of people from folder names in the dataset
    W.source = {img.public}';
end
for i = 1:numel(img)
    W.description{i} = seecat.bids.scrub_names(W.description{i}, nameWords(img(i)));
end
seecat.io.write_tsv(W, fullfile(bids_dir, 'code', 'seecat', [o.report '_' tag '.tsv']));
end

%% ---- what an image is ----------------------------------------------------

function a = classify(r, rules, auto)
a = struct('datatype', '', 'suffix', '', 'ent', struct(), 'how', '', 'note', '', 'target', 0);
m = r.meta;
mm = m;                                     % rules can also match the path and volume count
mm.Path = r.source;
mm.Volumes = r.dim(4);
k = firstRule(rules, mm);
if k > 0
    ru = rules(k);
    if ru.skip
        a.note = sprintf('left out by rule %d', k);
        return
    end
    a.datatype = ru.datatype;
    a.suffix = ru.suffix;
    a.ent = ru.entities;
    a.how = sprintf('rule %d', k);
    if strcmp(a.suffix, 'bold') && isSbref(m, r.dim)
        a.suffix = 'sbref';                   % e.g. rest_SBRef matched by a rest rule
        a.ent = rmfield(a.ent, intersect(fieldnames(a.ent), {'task'}));
    end
    return
end
if ~auto
    a.note = noRule(r);
    return
end
desc = r.desc;
type = imageType(m);
if ~isempty(regexpi(desc, 'localizer|localiser|scout|survey|aahead|plane_loc|3-?plane', 'once'))
    a.note = 'localizer; not copied';
    return
end
if ~isempty(regexp(type, '(^|\\)(DERIVED|MOCO)(\\|$)', 'once'))
    a.note = 'derived image; not copied';
    return
end
isEP = contains(char(strjoin(string(field(m, 'ScanningSequence', '')), '\')), 'EP');
fmapLike = ~isempty(regexpi(desc, 'field.?map|fmap|b0.?map|gre_field|topup|se.?epi|spin.?echo.?(fm|epi)|_?pepolar', 'once'));
phase = ~isempty(regexp(type, '(^|\\)(P|PHASE)(\\|$)', 'once')) || ~isempty(regexpi(r.source, '_ph(\.nii|\.img|$)', 'once'));
if fmapLike && ~(isEP && r.dim(4) <= 10 && ~isfield(m, 'EchoNumber')) && ~(isEP && r.dim(4) >= 20)
    a.datatype = 'fmap';
    a.how = 'field map';
    if phase
        a.suffix = 'phasediff';
    else
        e = field(m, 'EchoNumber', NaN);
        if e == 1 || e == 2
            a.suffix = sprintf('magnitude%d', e);
        else
            a.suffix = 'magnitude';
        end
    end
    return
end
if phase
    a.note = 'phase image; not copied';
    return
end
if fmapLike && isEP
    a.datatype = 'fmap';
    a.suffix = 'epi';
    a.ent = struct('dir', dirLabel(desc, m));
    a.how = 'field map';
    return
end
if isSbref(m, r.dim) || (~isempty(regexpi(desc, '(^|[^a-z])sb\d*$|sbref|single.?band', 'once')) && r.dim(4) == 1)
    a.datatype = 'func';
    a.suffix = 'sbref';
    a.how = 'single-band reference';
    return
end
if ~isempty(r.aux) && any(endsWith(r.aux, '.bval'))
    a.datatype = 'dwi';
    a.suffix = 'dwi';
    a.how = 'diffusion (bval/bvec)';
    return
end
if looksBold(r)
    [task, guessed] = taskFrom(desc);
    a.datatype = 'func';
    a.suffix = 'bold';
    a.how = 'task from the series name';
    if guessed && isfield(r, 'name_cut') && r.name_cut
        task = 'unknown';                  % the only word left out as a possible name
        a.note = ['task not known: a word of the file name that differs between subjects was ' ...
            'taken out as a possible name; set the task in the bids column (Preview names) or ' ...
            'add a rule'];
    elseif guessed
        a.note = 'task name guessed; check it';
    end
    a.ent = struct('task', task);
    return
end
a.note = noRule(r);
end

function s = noRule(r)
s = 'no rule matched';
if looksBold(r)
    s = sprintf(['no rule matched, but it looks like BOLD fMRI (2D EPI, %d volumes); ' ...
        'add a rule for it to convert it'], r.dim(4));
end
end

function tf = looksBold(r)
% 2D EPI (or no sidecar), 4D with 20 or more volumes, not diffusion
m = r.meta;
seq = char(strjoin(string(field(m, 'ScanningSequence', 'EP')), '\'));
tf = r.dim(4) >= 20 && contains(seq, 'EP') && ~strcmpi(field(m, 'MRAcquisitionType', '2D'), '3D') ...
    && isempty(regexp(imageType(m), 'DERIVED', 'once')) && ~any(endsWith(r.aux, '.bval'));
end

function tf = isSbref(m, dim)
tf = dim(4) == 1 && ~isempty(regexpi(char(string(field(m, 'SeriesDescription', ''))), 'sbref', 'once'));
end

function [task, guessed] = taskFrom(desc)
% Series description -> task label: trailing run numbers, scanner words and
% other characters removed; "rest" for resting state
s = lower(desc);
guessed = false;
if ~isempty(regexp(s, 'rest|rs-?fmri|(^|[^a-z])rs([^a-z]|$)', 'once'))
    task = 'rest';
    return
end
s = regexprep(s, '([_\- ]+(run|r))?[_\- ]*\d+$', '');
words = regexp(s, '[a-z0-9]+', 'match');
skip = {'ccbd', 'bold', 'fmri', 'func', 'fun', 'epi', 'ep2d', 'mb', 'cmrr', 'ap', 'pa', 'lr', 'rl', ...
    'task', 'raw', 'img', 'nii', 'nifti', 'data', 'scan', 'series'};
words = words(~ismember(words, skip) & cellfun(@(w) isempty(regexp(w, '^(mb|r)?\d+$', 'once')), words));
task = strjoin(words, '');
if isempty(task)
    task = 'rest';
    guessed = true;
end
end

function d = dirLabel(desc, m)
tok = regexp(upper(desc), '(^|[^A-Z])(AP|PA|LR|RL|SI|IS)([^A-Z]|$)', 'tokens', 'once');
if ~isempty(tok)
    d = tok{2};
    return
end
ped = char(string(field(m, 'PhaseEncodingDirection', '')));
d = strrep(strrep(ped, '-', 'minus'), ' ', '');
if isempty(d)
    d = 'unknown';
end
end

function A = echoes(img, A)
% Several images of one series with the same name: echoes or an error
key = arrayfun(@(i) sprintf('%s|%g|%s|%s|%s', img(i).study, img(i).series, A(i).datatype, A(i).suffix, ...
    jsonencode(A(i).ent)), 1:numel(img), 'UniformOutput', false);
named = ~cellfun(@isempty, {A.suffix});
for k = reshape(unique(key(named)), 1, [])
    idx = find(strcmp(key, k{1}) & named);
    if numel(idx) < 2
        continue
    end
    e = arrayfun(@(i) field(img(i).meta, 'EchoNumber', NaN), idx);
    if all(isfinite(e)) && numel(unique(e)) == numel(idx)
        for j = 1:numel(idx)
            A(idx(j)).ent.echo = sprintf('%d', e(j));
        end
    else
        for i = idx
            A(i).suffix = '';
            A(i).note = sprintf('series gave %d images that are not echoes; not copied', numel(idx));
        end
    end
end
end

function A = notDistortionCorrected(img, A)
% Siemens writes a T1w twice when distortion correction is on: ND (none)
% and DIS2D/DIS3D. Keep the corrected one.
for i = 1:numel(img)
    if ~strcmp(A(i).datatype, 'anat') || isempty(regexp(imageType(img(i).meta), '(^|\\)ND(\\|$)', 'once'))
        continue
    end
    for j = 1:numel(img)
        if j ~= i && strcmp(A(j).datatype, 'anat') && strcmp(A(j).suffix, A(i).suffix) ...
                && strcmp(img(j).study, img(i).study) && ~isempty(regexp(imageType(img(j).meta), 'DIS[23]D', 'once')) ...
                && isequal(field(img(j).meta, 'AcquisitionTime', 1), field(img(i).meta, 'AcquisitionTime', 2))
            A(i).suffix = '';
            A(i).note = sprintf('copy of series %g without distortion correction (ND); not copied', img(j).series);
        end
    end
end
end

%% ---- names ---------------------------------------------------------------

function base = addRuns(base, img, A)
% run-<n> when several series give the same name (echoes and magnitude
% 1/2 of one series count once)
sid = findgroups({img.study}', [img.series]');
key = regexprep(base, '_echo-\d+', '');
key = regexprep(key, '_magnitude[12]?$|_phasediff$|_phase[12]$', '_FMAP');
used = ~cellfun(@isempty, base);
fm = strcmp({A.datatype}', 'fmap');
for k = reshape(unique(key(used)), 1, [])
    idx = find(strcmp(key, k{1}));
    s = unique(sid(idx), 'stable');
    if all(fm(idx))
        % a magnitude series and the phase series that follows it are one set
        s = setsOf(img(idx), A(idx));
        nset = numel(unique(s));
        if nset > 1
            for j = 1:numel(idx)
                base{idx(j)} = addRun(base{idx(j)}, s(j));
            end
        end
        continue
    end
    if numel(s) > 1
        for i = idx(:)'
            base{i} = addRun(base{i}, find(s == sid(i)));
        end
    end
end
end

function s = setsOf(img, A)
% Set number of each field map image: a new set starts at every magnitude
% series (or every series, for sets without magnitudes)
[~, ord] = sort([img.series]);
s = zeros(numel(img), 1);
cur = 0;
last = NaN;
hasMag = false;
hasPhase = false;
for j = ord(:)'
    isMag = startsWith(A(j).suffix, 'magnitude') || strcmp(A(j).suffix, 'epi');
    if cur == 0 || (img(j).series ~= last && ((isMag && hasMag) || (~isMag && hasPhase)))
        cur = cur + 1;
        hasMag = false;
        hasPhase = false;
    end
    hasMag = hasMag || isMag;
    hasPhase = hasPhase || ~isMag;
    last = img(j).series;
    s(j) = cur;
end
end

function [base, A] = attachSbref(base, img, A, sesOf)
% An sbref takes the name of the next BOLD run of the visit with the same
% slice grid; of several sbrefs before one run, the nearest is kept
for i = find(strcmp({A.suffix}, 'sbref'))
    if ~isempty(base{i})
        continue
    end
    best = [];
    for j = 1:numel(img)
        if strcmp(A(j).suffix, 'bold') && ~isempty(base{j}) && strcmp(img(j).study, img(i).study) ...
                && img(j).series > img(i).series && isequal(img(j).dim(1:3), img(i).dim(1:3)) ...
                && strcmp(sesOf{j}, sesOf{i})
            if isempty(best) || img(j).series < img(best).series
                best = j;
            end
        end
    end
    if isempty(best)
        A(i).suffix = '';
        A(i).note = 'single-band reference without a following BOLD run of the same size; not copied';
        continue
    end
    base{i} = regexprep(base{best}, '_bold$', '_sbref');
    A(i).ent = A(best).ent;
    A(i).how = sprintf('sbref of series %g', img(best).series);
    A(i).target = best;
end
% several for one run: keep the nearest
[u, ~, g] = unique(base);
for k = 1:numel(u)
    idx = find(g == k & strcmp({A.suffix}', 'sbref'));
    if numel(idx) > 1 && ~isempty(u{k})
        [~, keep] = max([img(idx).series]);
        for i = idx(setdiff(1:numel(idx), keep))'
            base{i} = '';
            A(i).note = 'another single-band reference is nearer to the same run; not copied';
        end
    end
end
end

function [base, A] = applyNames(base, A, img, names, sub)
if ischar(names) || isstring(names)
    names = seecat.io.read_tsv(char(names));
end
src = cellstr(string(names.source));
bids = cellstr(string(names.bids));
bids(ismissing(string(names.bids))) = {''};
for i = 1:numel(img)
    k = find(strcmp(src, img(i).source), 1);
    if isempty(k)
        continue
    end
    b = regexprep(strtrim(strrep(bids{k}, '\', '/')), '\.nii(\.gz)?$', '');
    if strcmp(b, base{i})
        continue
    end
    if isempty(b)
        base{i} = '';
        A(i).suffix = '';
        A(i).note = 'left out in the plan';
        continue
    end
    tok = regexp(b, ['^sub-' sub '(/ses-[a-zA-Z0-9]+)?/([a-z]+)/sub-' sub '(_[a-z]+-[a-zA-Z0-9]+)*_([a-zA-Z0-9]+)$'], 'tokens', 'once');
    if isempty(tok)
        error('SeeCAT:bids', ['Plan name "%s" (%s) is not a BIDS path of sub-%s, e.g. ' ...
            'sub-%s/func/sub-%s_task-rest_bold.nii.gz.'], bids{k}, img(i).source, sub, sub, sub);
    end
    base{i} = b;
    A(i).datatype = tok{2};
    A(i).suffix = tok{4};
    A(i).ent = entitiesOf(b);
    A(i).how = 'plan';
end
end

function [base, A] = unique_(base, A)
[u, ~, g] = unique(base, 'stable');
for k = 1:numel(u)
    idx = find(g == k);
    if isempty(u{k}) || numel(idx) < 2
        continue
    end
    for i = idx(2:end)'
        base{i} = '';
        A(i).note = joinNote(A(i).note, sprintf('same name as an earlier image (%s); not copied', u{k}));
    end
end
end

function e = entitiesOf(b)
[~, name] = fileparts(b);
parts = strsplit(name, '_');
e = struct();
for p = parts(2:end - 1)
    kv = strsplit(p{1}, '-');
    if ~ismember(kv{1}, {'sub', 'ses'})
        e.(kv{1}) = kv{2};
    end
end
end

function extra = fieldmapMeta(base, img, A, sesOf)
% IntendedFor of every field map; EchoTime1/2 of phasediff
n = numel(img);
extra = repmat({struct()}, n, 1);
isF = ~cellfun(@isempty, base) & strcmp({A.datatype}', 'fmap');
if ~any(isF)
    return
end
setKey = regexprep(base, '_(magnitude[12]?|phasediff|phase[12]|epi|fieldmap)$', '');
setKey(~isF) = {''};
targets = find(~cellfun(@isempty, base) & ismember({A.suffix}', {'bold', 'sbref'}));
for s = reshape(unique(sesOf(isF)), 1, [])
    inSes = isF & strcmp(sesOf(:), s{1});
    keys = unique(setKey(inSes), 'stable');
    first = cellfun(@(k) min([img(strcmp(setKey, k)).series]), keys);
    [first, o] = sort(first);
    keys = keys(o);
    uses = cell(size(keys));
    for t = targets(:)'
        if ~strcmp(sesOf{t}, s{1})
            continue
        end
        k = find(first < img(t).series, 1, 'last');
        if isempty(k)
            k = 1;
        end
        uses{k}{end+1} = ['bids::' base{t} '.nii.gz'];
    end
    for k = 1:numel(keys)
        idx = find(strcmp(setKey, keys{k}));
        mags = idx(startsWith({A(idx).suffix}, 'magnitude'));
        for i = idx(:)'
            if ~isempty(uses{k})
                extra{i}.IntendedFor = uses{k}(:);
            end
            if strcmp(A(i).suffix, 'phasediff')
                te = sort(arrayfun(@(j) field(img(j).meta, 'EchoTime', NaN), mags));
                if numel(te) == 2 && all(isfinite(te))
                    extra{i}.EchoTime1 = te(1);
                    extra{i}.EchoTime2 = te(2);
                end
            end
        end
    end
end
end

%% ---- sessions ------------------------------------------------------------

function [out, studies] = sessions(bids_dir, sub, ses, img)
% Session label of each image: given, from the folders, or one per visit
n = numel(img);
studies = unique({img.study});
if ~isempty(ses)
    out = repmat({ses}, n, 1);
    return
end
given = {img.ses};
if any(~cellfun(@isempty, given))
    if ~all(~cellfun(@isempty, given))
        error('SeeCAT:bids', 'sub-%s: some images are in session folders and some are not.', sub);
    end
    out = given(:);
    return
end
lab = studySessions(bids_dir, sub, studies);
[~, at] = ismember({img.study}, studies);
out = lab(at);
out = out(:);
end

function out = studySessions(bids_dir, sub, studies)
out = repmat({''}, size(studies));
M = readSessions(bids_dir);
id = ['sub-' sub];
M = M(strcmp(M.participant_id, id), :);
[known, at] = ismember(studies, M.study);
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
    error('SeeCAT:bids', ['sub-%s already has data without sessions, and this is another visit ' ...
        '(scanned %s). Give the session label to add it.'], sub, studies{new(1)});
end
taken = str2double([regexprep({S.name}, '^ses-', ''), M.session_id(:)']);
next = max([0, taken(isfinite(taken))]);
for k = new(:)'
    next = next + 1;
    out{k} = sprintf('%d', next);
end
end

function recordSessions(bids_dir, sub, studies, sesOf, img)
M = readSessions(bids_dir);
id = ['sub-' sub];
lab = cellfun(@(s) sesOf{find(strcmp({img.study}, s), 1)}, studies, 'UniformOutput', false);
M = M(~(strcmp(M.participant_id, id) & ismember(M.study, studies)), :);
M = [M; table(repmat({id}, numel(studies), 1), studies(:), lab(:), ...
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

%% ---- writing -------------------------------------------------------------

function m = sidecar(r, a, extra, tr)
m = r.meta;
words = nameWords(r);
private = {'PatientName', 'PatientID', 'PatientBirthDate', 'PatientSex', 'PatientAge', 'PatientWeight', ...
    'PatientSize', 'AccessionNumber', 'ReferringPhysicianName', 'InstitutionAddress', 'PatientComments', ...
    'SeriesDescriptionOriginal', 'ImageComments'};
m = rmfield(m, intersect(fieldnames(m), private));
m = seecat.bids.scrub_names(m, words);
if ismember(a.suffix, {'bold', 'sbref'})
    m.TaskName = char(string(a.ent.task));
end
if strcmp(a.suffix, 'bold') && ~isfield(m, 'RepetitionTime')
    if isfinite(r.tr) && r.tr > 0
        m.RepetitionTime = r.tr;
    elseif ~isempty(tr)
        m.RepetitionTime = tr;
    end
end
for f = fieldnames(extra)'
    m.(f{1}) = extra.(f{1});
end
end

function w = nameWords(r)
% The subject's name: the image's names, and the words of PatientName
w = {};
if isfield(r, 'names')
    w = cellstr(r.names);
end
pn = char(string(field(r.meta, 'PatientName', '')));
if ~isempty(pn) && isempty(regexpi(strtrim(pn), '^(anon\w*|unknown|none|n/?a|x+|0+|\*+|-+)$', 'once'))
    p = regexp(pn, '[^\^\s,_\-.]+', 'match');
    p = p(cellfun(@(t) isempty(regexp(t, '\d', 'once')), p));
    w = [w(:)', p, {strjoin(p, '')}];
end
end

function copyImage(r, dst, link, tr)
src = r.files;
if isscalar(src) && endsWith(src{1}, '.nii.gz', 'IgnoreCase', true)
    if ~(link && hardLink(src{1}, dst))
        copyfile(src{1}, dst, 'f');
    end
    return
end
if isscalar(src) && endsWith(src{1}, '.nii', 'IgnoreCase', true)
    tmp = tempname;
    mkdir(tmp);
    c = onCleanup(@() rmdir(tmp, 's'));
    gz = gzip(src{1}, tmp);
    copyfile(gz{1}, dst, 'f');
    return
end
% Analyze .img/.hdr, or the 3D volumes of one run: one 4D NIfTI
tmp = tempname;
mkdir(tmp);
c = onCleanup(@() rmdir(tmp, 's'));
V = spm_vol(char(src));
out = fullfile(tmp, 'merged.nii');
if isempty(tr) || ~isnumeric(tr)
    tr = NaN;
end
if isscalar(V)
    Y = spm_read_vols(V);
    W = V;
    W.fname = out;
    W.private = [];
    W = spm_create_vol(W);
    spm_write_vol(W, Y);
else
    spm_file_merge(V, out, 0, tr);
end
gz = gzip(out, tmp);
copyfile(gz{1}, dst, 'f');
end

function ok = hardLink(src, dst)
ok = false;
try
    if exist(dst, 'file')
        delete(dst);
    end
    java.nio.file.Files.createLink(java.io.File(dst).toPath(), java.io.File(src).toPath());
    ok = true;
catch
end
end

function d = demographics(img)
% Sex and age at the scan from the first sidecar that has them
d = struct('sex', '', 'age', NaN);
for i = 1:numel(img)
    m = img(i).meta;
    s = upper(char(string(field(m, 'PatientSex', ''))));
    if isempty(d.sex) && ismember(s, {'M', 'F', 'O'})
        d.sex = s;
    end
    if isnan(d.age)
        a = char(string(field(m, 'PatientAge', '')));
        tok = regexp(a, '^(\d+)Y$', 'tokens', 'once');
        if ~isempty(tok)
            d.age = str2double(tok{1});
        else
            b = char(string(field(m, 'PatientBirthDate', '')));
            t = char(string(field(m, 'AcquisitionDateTime', field(m, 'AcquisitionDate', ''))));
            b = regexprep(b, '\D', '');
            t = regexprep(t(1:min(end, 10)), '\D', '');
            if numel(b) == 8 && numel(t) == 8          % whole years at the scan
                y = str2double({b(1:4), t(1:4)});
                md = str2double({b(5:8), t(5:8)});
                d.age = y(2) - y(1) - (md(2) < md(1));
            end
        end
    end
end
end

function T = report(sub, sesOf, img, base, A)
n = numel(img);
rel = base;
used = ~cellfun(@isempty, base);
rel(used) = strcat(base(used), '.nii.gz');
note = {A.note}';
how = {A.how}';
for i = find(used)'
    if ~isempty(how{i}) && ~startsWith(how{i}, 'rule') && ~strcmp(how{i}, 'plan')
        note{i} = joinNote(['named: ' how{i}], note{i});
    end
end
T = table(repmat({sub}, n, 1), sesOf(:), [img.series]', {img.desc}', {img.source}', rel(:), note, ...
    'VariableNames', {'subject', 'session', 'series', 'description', 'source', 'bids', 'note'});
end

function describe(bids_dir, gen)
f = fullfile(bids_dir, 'dataset_description.json');
if exist(f, 'file')
    return
end
[~, name] = fileparts(char(java.io.File(bids_dir).getCanonicalPath()));
g = [gen(:); struct('Name', 'SeeCAT', 'Version', seecat.version())];
d = struct('Name', name, 'BIDSVersion', '1.10.0', 'DatasetType', 'raw', 'GeneratedBy', g);
seecat.util.write_json(f, d);
end

function addParticipant(bids_dir, sub, d)
f = fullfile(bids_dir, 'participants.tsv');
id = ['sub-' sub];
if exist(f, 'file')
    P = seecat.io.read_tsv(f);
else
    P = table(cell(0, 1), 'VariableNames', {'participant_id'});
end
k = find(strcmp(P.participant_id, id), 1);
if isempty(k)
    row = cell2table(repmat({''}, 1, width(P)), 'VariableNames', P.Properties.VariableNames);
    for c = P.Properties.VariableNames
        if isnumeric(P.(c{1}))
            row.(c{1}) = NaN;
        end
    end
    row.participant_id = {id};
    P = [P; row];
    k = height(P);
end
if ~isempty(d.sex)
    if ~ismember('sex', P.Properties.VariableNames)
        P.sex = repmat({''}, height(P), 1);
    elseif ~iscell(P.sex)                          % read back as numbers when all empty
        P.sex = asText(P.sex);
    end
    if iscell(P.sex) && isempty(P.sex{k})
        P.sex{k} = d.sex;
    end
end
if ~isnan(d.age)
    if ~ismember('age', P.Properties.VariableNames)
        P.age = nan(height(P), 1);
    end
    if isnumeric(P.age) && isnan(P.age(k))
        P.age(k) = d.age;
    end
end
seecat.io.write_tsv(P, f);
end

%% ---- small helpers -------------------------------------------------------

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

function t = imageType(m)
t = char(strjoin(string(field(m, 'ImageType', '')), '\'));
end

function v = field(s, name, dflt)
if isfield(s, name)
    v = s.(name);
else
    v = dflt;
end
end

function s = joinNote(a, b)
if isempty(a)
    s = b;
elseif isempty(b)
    s = a;
else
    s = [a '; ' b];
end
end

function rel = bidsName(sub, ses, ent, suffix, datatype)
order = {'task', 'acq', 'ce', 'rec', 'dir', 'run', 'echo', 'part'};
f = fieldnames(ent)';
unknown = setdiff(f, order);
if ~isempty(unknown)
    error('SeeCAT:bids', 'Unsupported entity in a naming rule: %s.', strjoin(unknown, ', '));
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
