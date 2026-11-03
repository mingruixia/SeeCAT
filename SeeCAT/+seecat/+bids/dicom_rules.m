function rules = dicom_rules(src)
% DICOM_RULES  Rules that give DICOM series their BIDS names.
%   rules = seecat.bids.dicom_rules()             % defaults
%   rules = seecat.bids.dicom_rules('rules.json') % from a file
%   rules = seecat.bids.dicom_rules(structArray)  % checked and completed
%
% A rule is a struct with:
%   match     struct: sidecar field -> regular expression (case-insensitive);
%             every listed field must match. ImageType is matched as its
%             values joined with '\', e.g. 'ORIGINAL\PRIMARY\M\ND'.
%   exclude   struct: field -> regex; the rule does not apply when any
%             matches. Missing: ImageType DERIVED, MOCO or phase (P/PHASE).
%   datatype  'anat', 'func', 'fmap', 'dwi', ...
%   suffix    'T1w', 'bold', 'epi', ...
%   entities  struct of BIDS entities, e.g. struct('task', 'rest', 'acq', 'mb3')
% The first rule that matches a series wins. A 'func' rule must give a task.
%
% The defaults recognise only a 3D T1w (MPRAGE, SPGR, BRAVO, TFL, T1w in the
% series description) and resting-state BOLD (rest, resting, rsfMRI, or RS
% as a word: func_RS, RS_bold). Anything else needs your own rules;
% unmatched series are reported, not converted (a series that looks like
% BOLD is reported as such).

if nargin < 1 || isempty(src)
    rules = defaults();
elseif ischar(src) || isstring(src)
    rules = jsondecode(fileread(char(src)));
    if iscell(rules)
        rules = [rules{:}];
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
dflt = struct('ImageType', '(^|\\)(DERIVED|MOCO|P|PHASE)(\\|$)');
for i = 1:numel(rules)
    r = rules(i);
    for f = {'match', 'datatype', 'suffix'}
        if ~isfield(r, f{1}) || isempty(r.(f{1}))
            error('SeeCAT:bids', 'DICOM rule %d has no "%s".', i, f{1});
        end
    end
    if ~isstruct(r.match)
        error('SeeCAT:bids', 'DICOM rule %d: "match" must map field names to patterns.', i);
    end
    if ~isfield(r, 'exclude') || isempty(r.exclude)
        r.exclude = dflt;
    end
    if ~isfield(r, 'entities') || isempty(r.entities)
        r.entities = struct();
    end
    if strcmp(r.datatype, 'func') && ~isfield(r.entities, 'task')
        error('SeeCAT:bids', 'DICOM rule %d (func) needs entities.task.', i);
    end
    out(i) = orderfields(r, {'match', 'exclude', 'datatype', 'suffix', 'entities'}); %#ok<AGROW>
end
rules = out;
end
