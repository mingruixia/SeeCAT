function rules = dicom_rules(src)
% DICOM_RULES  Rules that give imported images (DICOM or NIfTI) their BIDS names.
%   rules = seecat.bids.dicom_rules()             % defaults
%   rules = seecat.bids.dicom_rules('rules.json') % from a file
%   rules = seecat.bids.dicom_rules(structArray)  % checked and completed
%
% A rule is a struct with:
%   match     struct: sidecar field -> regular expression (case-insensitive);
%             every listed field must match. ImageType is matched as its
%             values joined with '\', e.g. 'ORIGINAL\PRIMARY\M\ND'. Two more
%             fields can be matched: Path (where the image is, relative to
%             the folder being imported, e.g. 'FunRaw/sub01/rest.nii') and
%             Volumes (the number of volumes, as text, e.g. '^1$').
%   exclude   struct: field -> regex; the rule does not apply when any
%             matches. Missing: ImageType DERIVED, MOCO or phase (P/PHASE).
%   skip      true: images that match are left out (e.g. localizers);
%             datatype and suffix are then not needed.
%   datatype  'anat', 'func', 'fmap', 'dwi', ...
%   suffix    'T1w', 'bold', 'epi', ...
%   entities  struct of BIDS entities, e.g. struct('task', 'rest', 'acq', 'mb3')
% The first rule that matches a series wins. A 'func' rule must give a task.
%
% The defaults recognise a 3D T1w (MPRAGE, SPGR, BRAVO, TFL, T1w in the
% series description) and resting-state BOLD (rest, resting, rsfMRI, or RS
% as a word: func_RS, RS_bold). Images that no rule names are named by
% seecat.bids.organize when it may guess ('auto'): field maps, single-band
% references and task BOLD; anything else is reported, not converted.
% seecat.bids.plan_rules turns an edited plan into rules.

if nargin < 1 || isempty(src)
    rules = defaults();
elseif ischar(src) || isstring(src)
    rules = jsondecode(fileread(char(src)));
    if iscell(rules)                              % rules with different fields
        rules = cellfun(@(r) completeOne(r, 0), rules);
    end
else
    rules = src;
end
rules = complete(rules);
end

function r = defaults()
r(1).match = struct('SeriesDescription', 'mprage|spgr|bravo|tfl|t1w|t1_|_t1|^t1', 'MRAcquisitionType', '^3D$');
r(1).datatype = 'anat';
r(1).suffix = 'T1w';
r(1).entities = struct();
r(2).match = struct('SeriesDescription', 'rest|rs-?fmri|rs_fmri|(^|[^a-z])rs([^a-z]|$)');   % ..._RS, RS_bold
r(2).datatype = 'func';
r(2).suffix = 'bold';
r(2).entities = struct('task', 'rest');
end

function rules = complete(rules)
for i = 1:numel(rules)
    out(i) = completeOne(rules(i), i); %#ok<AGROW>
end
if numel(rules) == 0
    out = struct('match', {}, 'exclude', {}, 'skip', {}, 'datatype', {}, 'suffix', {}, 'entities', {});
end
rules = out;
end

function r = completeOne(r, i)
dflt = struct('ImageType', '(^|\\)(DERIVED|MOCO|P|PHASE)(\\|$)');
if ~isfield(r, 'skip') || isempty(r.skip)
    r.skip = false;
end
r.skip = logical(r.skip);
if ~isfield(r, 'match') || isempty(r.match)
    error('SeeCAT:bids', 'Naming rule %d has no "match".', i);
end
for f = {'datatype', 'suffix'}
    if ~isfield(r, f{1}) || isempty(r.(f{1}))
        if ~r.skip
            error('SeeCAT:bids', 'Naming rule %d has no "%s".', i, f{1});
        end
        r.(f{1}) = '';
    end
end
if ~isstruct(r.match)
    error('SeeCAT:bids', 'Naming rule %d: "match" must map field names to patterns.', i);
end
if ~isfield(r, 'exclude') || isempty(r.exclude)
    r.exclude = dflt;
end
if ~isfield(r, 'entities') || isempty(r.entities)
    r.entities = struct();
end
if strcmp(r.datatype, 'func') && ~isfield(r.entities, 'task') && ~r.skip
    error('SeeCAT:bids', 'Naming rule %d (func) needs entities.task.', i);
end
r = orderfields(r, {'match', 'exclude', 'skip', 'datatype', 'suffix', 'entities'});
end
