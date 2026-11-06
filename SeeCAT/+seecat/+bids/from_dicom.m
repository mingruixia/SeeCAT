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
% temporary folder with BIDS sidecars, anonymised. seecat.bids.organize then
% names every image and copies it to <bids_dir>/sub-<sub>/[ses-<ses>/]<datatype>/
% as .nii.gz + .json, as for NIfTI imports (seecat.bids.from_nifti):
%   - the first rule that matches its sidecar (seecat.bids.dicom_rules);
%     without one, field maps, single-band references and task BOLD are
%     named from the series ('auto'), and anything else is reported;
%   - several series with the same name get run-1, run-2, ... in series
%     order; a series with several echoes gets echo-1, echo-2, ...;
%   - BOLD sidecars get TaskName, field maps IntendedFor;
%   - dataset_description.json is written if missing; participants.tsv
%     gets the subject if missing.
%
% Options:
%   'sub'        subject label (letters and digits; default: from folder names)
%   'ses'        session label (default: from the studies, see above)
%   'rules'      rules struct array or JSON file (default: dicom_rules())
%   'auto'       name images that no rule names (default true)
%   'dcm2niix'   path to dcm2niix (default: found automatically)
%   'overwrite'  replace existing images (default false: keep them, so
%                converting again only adds what is missing)
%   'dryrun'     true: only return the table of names; nothing is written
%   'names'      a table as returned (source and bids columns) with names
%                edited or emptied: used instead of the rules
%
% T is a table with one row per image: subject, session, series,
% description, source, bids (path relative to bids_dir, or '' when not
% copied) and note. Each subject's rows are also written to
% <bids_dir>/code/seecat/from_dicom_sub-<sub>[_ses-<ses>].tsv.

p = inputParser;
p.addParameter('sub', '', @(x) ischar(x) || isstring(x));
p.addParameter('ses', '', @(x) ischar(x) || isstring(x));
p.addParameter('rules', [], @(x) isempty(x) || isstruct(x) || ischar(x) || isstring(x));
p.addParameter('dcm2niix', '', @(x) ischar(x) || isstring(x));
p.addParameter('overwrite', false, @(x) islogical(x) || isnumeric(x));
p.addParameter('auto', true, @(x) islogical(x) || isnumeric(x));
p.addParameter('dryrun', false, @(x) islogical(x) || isnumeric(x));
p.addParameter('names', [], @(x) isempty(x) || istable(x) || ischar(x) || isstring(x));
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
    T = convertSubject({dicom_dir}, bids_dir, sub, ses, rules, exe, ver, o);
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
        parts{k} = convertSubject(folders{k}, bids_dir, labels{k}, ses, rules, exe, ver, o);
    catch err
        if numel(folders) == 1
            rethrow(err);
        end
        parts{k} = cell2table({labels{k}, '', NaN, '', '', '', err.message}, 'VariableNames', columns());
        failed{end+1} = sprintf('sub-%s: %s', labels{k}, err.message); %#ok<AGROW>
    end
end
T = vertcat(parts{:});
if numel(failed) == numel(folders)
    error('SeeCAT:bids', 'No subject was converted:\n%s', strjoin(failed, '\n'));
end
end

function T = convertSubject(folders, bids_dir, sub, ses, rules, exe, ver, o)
% 1. Convert everything into a temporary folder; FOLDERS hold only this
% subject's files
tmp = tempname;
mkdir(tmp);
cleanup = onCleanup(@() rmdir(tmp, 's'));
out = '';
for k = 1:numel(folders)
    % %t (study date and time) keeps series apart when one folder holds two studies
    cmd = sprintf('"%s" -b y -ba y -z y -f "%%t_%%s_%%p" -o "%s" "%s"', exe, tmp, folders{k});
    [st, o_] = system(cmd);
    out = [out o_]; %#ok<AGROW>
end
J = dir(fullfile(tmp, '*.json'));
if st ~= 0 && isempty(J)
    error('SeeCAT:dcm2niix', 'dcm2niix failed (exit %d):\n%s', st, out);
end

% 2. One record per image, then naming and copying as for NIfTI imports
img = struct('files', {}, 'json', {}, 'meta', {}, 'study', {}, 'ses', {}, 'series', {}, ...
    'desc', {}, 'source', {}, 'aux', {}, 'dim', {}, 'tr', {});
for i = 1:numel(J)
    jf = fullfile(tmp, J(i).name);
    nf = regexprep(jf, '\.json$', '.nii.gz');
    if ~exist(nf, 'file')
        continue                                   % e.g. a sidecar without an image
    end
    m = jsondecode(fileread(jf));
    r.files = {nf};
    r.json = jf;
    r.meta = m;
    r.study = regexp(J(i).name, '^\d+', 'match', 'once');
    if isempty(r.study)
        r.study = '0';                             % no study time in the DICOM
    end
    r.ses = '';
    r.series = field(m, 'SeriesNumber', NaN);
    r.desc = char(string(field(m, 'SeriesDescription', field(m, 'ProtocolName', ''))));
    r.source = regexprep(J(i).name, '\.json$', '');
    stem = regexprep(nf, '\.nii\.gz$', '');
    r.aux = {};
    for e = {'.bval', '.bvec'}
        if exist([stem e{1}], 'file')
            r.aux{end+1} = [stem e{1}];
        end
    end
    r.dim = [];
    r.tr = NaN;
    img(end+1) = r; %#ok<AGROW>
end
if isempty(img)
    error('SeeCAT:dcm2niix', 'dcm2niix produced no images from %s:\n%s', strjoin(folders, ', '), out);
end
T = seecat.bids.organize(img, bids_dir, sub, 'ses', ses, 'rules', rules, 'auto', o.auto, ...
    'overwrite', o.overwrite, 'dryrun', o.dryrun, 'names', o.names, 'report', 'from_dicom', ...
    'generator', struct('Name', 'dcm2niix', 'Version', ver));
end

function c = columns()
c = {'subject', 'session', 'series', 'description', 'source', 'bids', 'note'};
end

function v = field(s, name, dflt)
if isfield(s, name)
    v = s.(name);
else
    v = dflt;
end
end
