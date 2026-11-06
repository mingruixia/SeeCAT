function T = from_nifti(src, bids_dir, varargin)
% FROM_NIFTI  Put a folder of NIfTI images into a BIDS dataset.
%   T = seecat.bids.from_nifti(src, bids_dir)                     % subjects found automatically
%   P = seecat.bids.from_nifti(src, bids_dir, 'dryrun', true)     % the plan only
%   T = seecat.bids.from_nifti(src, bids_dir, 'names', P)         % with names edited in P
%   T = seecat.bids.from_nifti(src, bids_dir, 'sub', '01', 'ses', 'pre', 'rules', 'my_rules.json')
%
% For NIfTI exports of scanners and imaging platforms (with dcm2niix-style
% .json sidecars) and for older data without sidecars (.nii, .nii.gz,
% Analyze .img/.hdr, one 4D file or one 3D file per volume), in any common
% layout: one folder per subject, modality folders with subject folders
% inside (FunRaw/S001, T1Raw/S001), subject IDs in the file names, folders
% per visit or per series. seecat.bids.scan_nifti finds the subjects,
% sessions and images; seecat.bids.organize names and copies them as
% seecat.bids.from_dicom does after dcm2niix:
%   - rules first (seecat.bids.dicom_rules: the defaults name 3D T1w and
%     resting BOLD); then, with 'auto', field maps (magnitude1/2 and
%     phasediff, or epi), single-band references (sbref of the BOLD run
%     after them) and task BOLD named from the series (Math_AI_trust1 ->
%     task-mathaitrust run-1); localizers, phase and derived images are
%     left out; anything else is reported, not copied;
%   - runs, echoes and sessions as for DICOM; field maps get IntendedFor;
%     a T1w copy without distortion correction (ND) is left out when the
%     corrected one is there;
%   - identifying sidecar fields are not copied; participants.tsv gets sex
%     and age at the scan when the sidecars have them.
% The source folder is only read. Run with 'dryrun' first, check the
% plan, and change names in it (or empty them) before running with
% 'names'; seecat.bids.plan_rules turns the edited plan into rules for the
% next subjects.
%
% Options:
%   'sub'              one subject label for everything (default: found)
%   'subject_pattern'  regular expression with one token: the label in the
%                      path, e.g. 'Subj_(\d+)' (see scan_nifti)
%   'ses'              one session label for everything (default: from
%                      session folders or the scanning visits)
%   'rules'            rules struct array or JSON file
%   'auto'             name images that no rule names (default true)
%   'tr'               repetition time in seconds for BOLD without one in a
%                      sidecar or the header (default: none; reported)
%   'link'             true: hard links instead of copies for .nii.gz
%                      images on the same drive (saves space)
%   'overwrite'        replace images already in the dataset (default false)
%   'dryrun'           true: return the plan; nothing is written
%   'names'            a plan (table or TSV file) with bids names edited
%
% T has one row per image: subject, session, series, description, source
% (relative to SRC), bids (relative to bids_dir; '' when not copied) and
% note. Each subject's rows are written to
% <bids_dir>/code/seecat/from_nifti_sub-<sub>[_ses-<ses>].tsv.

p = inputParser;
p.addParameter('sub', '', @(x) ischar(x) || isstring(x));
p.addParameter('subject_pattern', '', @(x) ischar(x) || isstring(x));
p.addParameter('ses', '', @(x) ischar(x) || isstring(x));
p.addParameter('rules', [], @(x) isempty(x) || isstruct(x) || ischar(x) || isstring(x));
p.addParameter('auto', true, @(x) islogical(x) || isnumeric(x));
p.addParameter('tr', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x) && x > 0));
p.addParameter('link', false, @(x) islogical(x) || isnumeric(x));
p.addParameter('overwrite', false, @(x) islogical(x) || isnumeric(x));
p.addParameter('dryrun', false, @(x) islogical(x) || isnumeric(x));
p.addParameter('names', [], @(x) isempty(x) || istable(x) || ischar(x) || isstring(x));
p.parse(varargin{:});
o = p.Results;
ses = strtrim(char(o.ses));
if ~isempty(ses) && isempty(regexp(ses, '^[a-zA-Z0-9]+$', 'once'))
    error('SeeCAT:bids', 'Session label "%s" must be letters and digits only.', ses);
end
checkOutput(src, bids_dir);
rules = seecat.bids.dicom_rules(o.rules);
names = o.names;
if ischar(names) || isstring(names)
    names = seecat.io.read_tsv(char(names));
end
[S, groups, info] = seecat.bids.scan_nifti(src, 'sub', o.sub, 'subject_pattern', o.subject_pattern);
fprintf('NIfTI to BIDS: %s\n', info.layout);
for k = 1:numel(info.ignored)
    fprintf('NIfTI to BIDS: no subject for %s; skipped.\n', info.ignored{k});
end
parts = cell(height(S), 1);
failed = {};
for k = 1:height(S)
    if ~o.dryrun
        fprintf('NIfTI to BIDS: sub-%s (%d of %d)\n', S.subject{k}, k, height(S));
    end
    try
        parts{k} = seecat.bids.organize(groups{k}, bids_dir, S.subject{k}, 'ses', ses, 'rules', rules, ...
            'auto', o.auto, 'tr', o.tr, 'link', o.link, 'overwrite', o.overwrite, 'dryrun', o.dryrun, ...
            'names', names, 'report', 'from_nifti');
    catch err
        if height(S) == 1
            rethrow(err);
        end
        parts{k} = cell2table({S.subject{k}, '', NaN, '', S.source{k}, '', err.message}, 'VariableNames', ...
            {'subject', 'session', 'series', 'description', 'source', 'bids', 'note'});
        failed{end+1} = sprintf('sub-%s: %s', S.subject{k}, err.message); %#ok<AGROW>
    end
end
T = vertcat(parts{:});
if numel(failed) == height(S)
    error('SeeCAT:bids', 'No subject was organised:\n%s', strjoin(failed, '\n'));
end
end

function checkOutput(src, bids_dir)
% The BIDS folder must not be the source folder or inside it
[~, a] = seecat.util.canonical_path(src);
[~, b] = seecat.util.canonical_path(bids_dir);
if strcmp(a, b) || startsWith(b, [a '/']) || startsWith(b, [a filesep])
    error('SeeCAT:bids', 'The BIDS folder (%s) must be outside the NIfTI folder (%s).', bids_dir, src);
end
end
