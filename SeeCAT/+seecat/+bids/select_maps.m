function [maps, dropped, root] = select_maps(input_dir, selector, subjects, participants, columns, qcExclusions)
% SELECT_MAPS  Per-subject maps chosen by entities, with participants.tsv columns.
%   [maps, dropped, root] = seecat.bids.select_maps(input_dir, struct('desc', 'PCC', 'stat', 'z'), ...
%       {}, '', {'site', 'age'})
%
% MAPS is a table: path, sub, then the requested COLUMNS of
% participants.tsv (PARTICIPANTS, or found next to the derivatives as
% seecat.stat does). Maps of subjects missing from participants.tsv, or
% with an empty or n/a value in a requested column, are left out and
% described in DROPPED. SUBJECTS ({} = all) limits the subjects. With
% QCEXCLUSIONS (default true), maps of runs or T1w images excluded in
% <input_dir>/reports/qc_exclusions.tsv are left out too.

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
dropped = {};
if nargin < 6 || qcExclusions
    ex = seecat.qc.exclusions(root);
    if ~isempty(ex)
        k = arrayfun(@(f) seecat.qc.exclusions('key', f.name), F, 'UniformOutput', false);
        out = ismember(k, ex);
        dropped = strcat(unique(k(out))', {': excluded by QC'});
        F = F(~out);
        if isempty(F)
            error('SeeCAT:bids', 'Every matching map is excluded by QC (reports/qc_exclusions.tsv).');
        end
    end
end
maps = table({F.path}', arrayfun(@(f) f.ent.sub, F, 'UniformOutput', false), 'VariableNames', {'path', 'sub'});
columns = columns(~cellfun(@isempty, columns));
if isempty(columns)
    return
end
f = participants;
if isempty(f)
    f = seecat.bids.participants_file(root);
end
if isempty(f) || ~exist(f, 'file')
    error('SeeCAT:bids', 'participants.tsv not found; set "participants".');
end
P = seecat.bids.add_volumes(seecat.io.read_tsv(f), root);
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
