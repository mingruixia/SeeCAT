function [maps, dropped, root] = select_maps(input_dir, selector, subjects, participants, columns)
% SELECT_MAPS  Per-subject maps chosen by entities, with participants.tsv columns.
%   [maps, dropped, root] = seecat.bids.select_maps(input_dir, struct('desc', 'PCC', 'stat', 'z'), ...
%       {}, '', {'site', 'age'})
%
% MAPS is a table: path, sub, then the requested COLUMNS of
% participants.tsv (PARTICIPANTS, or found next to the derivatives as
% seecat.stat does). Maps of subjects missing from participants.tsv, or
% with an empty or n/a value in a requested column, are left out and
% described in DROPPED. SUBJECTS ({} = all) limits the subjects.

L = seecat.bids.layout(input_dir);
root = L.root;
args = {'ext', {'.nii', '.nii.gz'}, 'sub', subjects};
for f = fieldnames(selector)'
    args = [args, f, {selector.(f{1})}]; %#ok<AGROW>
end
F = seecat.bids.query(L, args{:});
if isempty(F)
    error('SeeCAT:bids', 'No maps in %s match the selector.', root);
end
maps = table({F.path}', arrayfun(@(f) f.ent.sub, F, 'UniformOutput', false), 'VariableNames', {'path', 'sub'});
dropped = {};
columns = columns(~cellfun(@isempty, columns));
if isempty(columns)
    return
end
f = participants;
if isempty(f)
    f = findParticipants(root);
end
if isempty(f) || ~exist(f, 'file')
    error('SeeCAT:bids', 'participants.tsv not found; set "participants".');
end
P = seecat.io.read_tsv(f);
[in, row] = ismember(strcat('sub-', maps.sub), P.participant_id);
for s = unique(maps.sub(~in))'
    dropped{end+1} = sprintf('sub-%s: not in participants.tsv', s{1}); %#ok<AGROW>
end
maps = maps(in, :);
row = row(in);
ok = true(height(maps), 1);
for c = columns(:)'
    if ~ismember(c{1}, P.Properties.VariableNames)
        error('SeeCAT:bids', 'Column "%s" is not in %s.', c{1}, f);
    end
    v = P.(c{1})(row);
    maps.(c{1}) = v;
    if isnumeric(v)
        bad = isnan(v);
    else
        bad = cellfun(@(x) isempty(x) || strcmp(x, 'n/a'), cellstr(string(v)));
    end
    for s = unique(maps.sub(bad))'
        dropped{end+1} = sprintf('sub-%s: no value for %s', s{1}, c{1}); %#ok<AGROW>
    end
    ok = ok & ~bad;
end
maps = maps(ok, :);
end

function f = findParticipants(root)
% participants.tsv of the derivatives, of the dataset above them, or of the
% dataset named in dataset_description.json (SourceDatasets)
cand = {fullfile(root, 'participants.tsv'), fullfile(fileparts(fileparts(root)), 'participants.tsv')};
d = fullfile(root, 'dataset_description.json');
if exist(d, 'file')
    j = jsondecode(fileread(d));
    if isfield(j, 'SourceDatasets')
        s = j.SourceDatasets;
        if iscell(s), s = s{1}; end
        if isfield(s, 'URL') && startsWith(s.URL, 'file://')
            src = s.URL(8:end);
            cand = [cand, {fullfile(src, 'participants.tsv'), fullfile(fileparts(fileparts(src)), 'participants.tsv')}];
        end
    end
end
f = '';
for c = cand
    if exist(c{1}, 'file')
        f = c{1};
        return
    end
end
end
