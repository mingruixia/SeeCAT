function [units, cfg] = plan(cfg)
% PLAN  The single unit of a group analysis: its maps and subject data.
%   [units, cfg] = seecat.stat.plan(cfg)
%
% Finds the maps (cfg.maps selector in cfg.input_dir, or the 'path' column
% of cfg.design_tsv for the custom design), joins them with participants.tsv
% and drops subjects that lack a map, a level (within designs) or a value
% in a used column; they are listed in unit.dropped. output_dir defaults to
% input_dir; outputs go to <output_dir>/group/<name>/.

if isempty(cfg.name)
    error('SeeCAT:stat', 'Set "name" (letters and digits): the analysis folder group/<name>/.');
end
within = any(strcmp(cfg.design, {'paired', 'anova1_rm'}));
if strcmp(cfg.design, 'custom')
    [maps, dropped] = customMaps(cfg);
    root = fileparts(cfg.design_tsv);
else
    L = seecat.bids.layout(cfg.input_dir);
    root = L.root;
    [maps, dropped] = bidsMaps(cfg, L, within);
end
if isempty(cfg.output_dir)
    cfg.output_dir = root;
end
if isempty(cfg.work_dir)
    cfg.work_dir = fullfile(fileparts(cfg.output_dir), 'seecat_work');
end
if height(maps) < 3
    error('SeeCAT:stat', 'Only %d map(s) left for the analysis.', height(maps));
end
units = struct('id', cfg.name, 'maps', maps, 'dropped', {dropped});
end

function [maps, dropped] = bidsMaps(cfg, L, within)
args = {'ext', {'.nii', '.nii.gz'}, 'sub', cfg.subjects};
for f = fieldnames(cfg.maps)'
    args = [args, f, {cfg.maps.(f{1})}]; %#ok<AGROW>
end
if within
    if isempty(cfg.factor)
        error('SeeCAT:stat', 'The %s design needs "factor": the entity that holds the level (e.g. ses, desc).', cfg.design);
    end
    args = [args, {cfg.factor, cfg.levels}];
end
F = seecat.bids.query(L, args{:});
if isempty(F)
    error('SeeCAT:stat', 'No maps in %s match the selector.', L.root);
end
sub = arrayfun(@(f) f.ent.sub, F, 'UniformOutput', false);
level = repmat({''}, numel(F), 1);
if within
    level = arrayfun(@(f) ent(f, cfg.factor), F, 'UniformOutput', false);
end
key = strcat(sub, '|', level);
[u, ~, k] = unique(key);
dup = u(accumarray(k, 1) > 1);
if ~isempty(dup)
    error('SeeCAT:stat', 'Several maps match for %s; narrow the selector (e.g. space, task, run).', ...
        strjoin(strrep(dup, '|', ' '), ', '));
end
maps = table({F.path}', sub, level, 'VariableNames', {'path', 'sub', 'level'});
[maps, dropped] = joinParticipants(maps, cfg, L.root);
if within
    lv = cfg.levels;
    if isempty(lv)
        lv = unique(maps.level, 'stable');
    end
    complete = splitapply(@(x) all(ismember(lv, x)), maps.level, findgroups(maps.sub));
    subs = unique(maps.sub, 'stable');
    [~, order] = sort(subs);
    subs = subs(order);
    lack = subs(~complete(:));
    for s = lack'
        dropped{end+1} = sprintf('sub-%s: not every level of %s', s{1}, cfg.factor); %#ok<AGROW>
    end
    maps = maps(~ismember(maps.sub, lack), :);
    [~, o] = sortrows([findgroups(maps.sub), cellfun(@(x) find(strcmp(lv, x)), maps.level)]);
    maps = maps(o, :);
end
end

function [maps, dropped] = joinParticipants(maps, cfg, root)
used = [{cfg.factor}, cfg.regressors(:)', cfg.covariates(:)'];
if any(strcmp(cfg.design, {'paired', 'anova1_rm'}))
    used = setdiff(used, {cfg.factor});
end
used = used(~cellfun(@isempty, used));
dropped = {};
f = participantsFile(cfg, root);
if isempty(f)
    if ~isempty(used)
        error('SeeCAT:stat', 'participants.tsv not found; set "participants".');
    end
    return
end
P = seecat.io.read_tsv(f);
id = strcat('sub-', maps.sub);
[in, row] = ismember(id, P.participant_id);
for s = unique(id(~in))'
    dropped{end+1} = sprintf('%s: not in participants.tsv', s{1}); %#ok<AGROW>
end
maps = maps(in, :);
row = row(in);
for c = used
    if ~ismember(c{1}, P.Properties.VariableNames)
        error('SeeCAT:stat', 'Column "%s" is not in %s.', c{1}, f);
    end
    maps.(c{1}) = P.(c{1})(row);
end
ok = true(height(maps), 1);
for c = used
    v = maps.(c{1});
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
if any(strcmp(cfg.design, {'two_sample', 'anova1'})) && ~isempty(cfg.levels)
    inLevels = ismember(cellstr(string(maps.(cfg.factor))), cfg.levels);
    ok = ok & inLevels;
end
maps = maps(ok, :);
end

function f = participantsFile(cfg, root)
f = cfg.participants;
if ~isempty(f)
    return
end
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

function [maps, dropped] = customMaps(cfg)
if isempty(cfg.design_tsv)
    error('SeeCAT:stat', 'The custom design needs "design_tsv" with a path column.');
end
T = seecat.io.read_tsv(cfg.design_tsv);
if ~ismember('path', T.Properties.VariableNames)
    error('SeeCAT:stat', '%s has no "path" column.', cfg.design_tsv);
end
d = fileparts(cfg.design_tsv);
p = cellstr(T.path);
rel = ~cellfun(@(x) ~isempty(regexp(x, '^([a-zA-Z]:|/|\\)', 'once')), p);
p(rel) = fullfile(d, p(rel));
T.path = p;
T.sub = cellfun(@(x) regexprep(char(regexp(x, 'sub-[a-zA-Z0-9]+', 'match', 'once')), '^sub-', ''), p, 'UniformOutput', false);
T.level = repmat({''}, height(T), 1);
maps = T;
dropped = {};
end

function v = ent(f, key)
v = '';
if isfield(f.ent, key)
    v = f.ent.(key);
end
end
