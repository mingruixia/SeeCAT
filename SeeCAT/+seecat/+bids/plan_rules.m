function rules = plan_rules(T, file)
% PLAN_RULES  Naming rules from a checked plan, for the next subjects.
%   rules = seecat.bids.plan_rules(P)                 % P from from_nifti/from_dicom(..., 'dryrun', true)
%   seecat.bids.plan_rules(P, 'my_rules.json')        % and written to a file
%
% Each named image of the plan gives a rule that matches its series
% description with the run number at its end left open (Math_AI_trust3
% matches Math_AI_trust1, ...4) and names it with the plan's datatype,
% suffix and entities without run and echo, which are numbered again. An
% image the plan leaves out ("left out in the plan") gives a skip rule.
% Field maps and single-band references are left to the automatic naming
% (seecat.bids.organize), which also pairs them with the BOLD runs.
% Descriptions that were named in two different ways keep the first.

if ischar(T) || isstring(T)
    T = seecat.io.read_tsv(char(T));
end
desc = cellstr(string(T.description));
bids = cellstr(string(T.bids));
bids(ismissing(string(T.bids))) = {''};
note = cellstr(string(T.note));
note(ismissing(string(T.note))) = {''};
rules = struct('match', {}, 'skip', {}, 'datatype', {}, 'suffix', {}, 'entities', {});
seen = {};
for i = 1:height(T)
    if isempty(desc{i})
        continue
    end
    d = regexprep(desc{i}, '\d+$', '');
    pat = ['^' regexptranslate('escape', d) '\d*$'];
    if ismember(pat, seen)
        continue
    end
    if isempty(bids{i})
        if contains(note{i}, 'left out in the plan')
            rules(end+1) = struct('match', struct('SeriesDescription', pat), 'skip', true, ...
                'datatype', '', 'suffix', '', 'entities', struct()); %#ok<AGROW>
            seen{end+1} = pat; %#ok<AGROW>
        end
        continue
    end
    [dir_, name] = fileparts(regexprep(bids{i}, '\.nii(\.gz)?$', ''));
    [~, datatype] = fileparts(dir_);
    parts = strsplit(name, '_');
    suffix = parts{end};
    if strcmp(datatype, 'fmap') || strcmp(suffix, 'sbref')
        continue
    end
    ent = struct();
    for q = parts(2:end - 1)
        kv = strsplit(q{1}, '-');
        if ~ismember(kv{1}, {'sub', 'ses', 'run', 'echo'})
            ent.(kv{1}) = kv{2};
        end
    end
    rules(end+1) = struct('match', struct('SeriesDescription', pat), 'skip', false, ...
        'datatype', datatype, 'suffix', suffix, 'entities', ent); %#ok<AGROW>
    seen{end+1} = pat; %#ok<AGROW>
end
if nargin > 1
    seecat.util.write_json(file, rules);
end
end
