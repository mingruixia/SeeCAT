function H = form(parent, F, cfg, advanced, onHelp)
% FORM  Controls for a pipeline's form description, filled from CFG.
%   H = seecat.gui.form(parent, seecat.prep.gui(), cfg, showAdvanced, @(f) ...)
%   cfg = H.get(cfg)          % read the controls back into a config
%   H.sections                % section names, in order
%   H.scrollTo('Censoring')   % scroll the form to that section's card
%   H.fit()                   % refit the cards to the panel's width
%
% PARENT is a uipanel, which becomes the scrolling area (numeric scroll
% works on panels in R2020b, not on grid layouts). Each section is a card in
% one column; advanced entries are left out unless ADVANCED.
% ONHELP(f) is called with the form entry the user is working on (editing,
% or clicking its info icon). Values are turned back into the type of the
% option's current value (numbers, vectors, matrices, keywords such as
% 'auto', lists), see seecat.gui.parse.

if nargin < 4
    advanced = false;
end
if nargin < 5
    onHelp = @(f) [];
end
T = seecat.gui.theme();
F = F(advanced | ~[F.advanced]);
secs = unique({F.section}, 'stable');
pad = [16 14 16 14];                              % left bottom right top
parent.Scrollable = 'on';
content = uipanel(parent, 'BorderType', 'none', 'BackgroundColor', T.page);
g = uigridlayout(content, [numel(secs) 1], 'Padding', pad, 'RowSpacing', 12, 'BackgroundColor', T.page);
ctl = cell(numel(F), 1);
heights = zeros(1, numel(secs));
for s = 1:numel(secs)
    k = find(strcmp({F.section}, secs{s}));
    rows = [22, arrayfun(@(i) rowHeight(F(i)), k)];
    card = uigridlayout(g, [1 1], 'Padding', [1 1 1 1], 'BackgroundColor', T.border);   % 1 px outline
    cg = uigridlayout(card, [numel(rows) 3], 'ColumnWidth', {T.label, '1x', 18}, ...
        'RowHeight', num2cell(rows), 'RowSpacing', 6, 'ColumnSpacing', 10, ...
        'Padding', [14 12 12 10], 'BackgroundColor', T.panel);
    h = uilabel(cg, 'Text', secs{s}, 'FontSize', T.size.card, 'FontWeight', 'bold', 'FontColor', T.text);
    h.Layout.Row = 1;
    h.Layout.Column = [1 3];
    for r = 1:numel(k)
        f = F(k(r));
        ctl{k(r)} = makeRow(cg, f, getPath(cfg, f.path), r + 1, T, @() onHelp(f));
    end
    heights(s) = sum(rows) + 6 * (numel(rows) - 1) + 22 + 2;
end
g.RowHeight = num2cell(heights);
iMaps = find(strcmp({F.widget}, 'maps'), 1);
iIn = find(strcmp({F.path}, 'input_dir'), 1);
if ~isempty(iMaps) && ~isempty(iIn)
    m = ctl{iMaps};
    in = ctl{iIn};
    % the maps fields list what the derivatives folder holds and count the matches
    recount = @() countMaps(m, in, false);
    for h = [num2cell(m.dd), {m.other}]
        old = h{1}.ValueChangedFcn;               % the help call
        h{1}.ValueChangedFcn = @(s, e) both(old, recount, s, e);
    end
    for h = m.dd
        h.DropDownOpeningFcn = @(~, ~) fillMaps(m, in);
    end
    old = in.ValueChangedFcn;
    in.ValueChangedFcn = @(s, e) both(old, @() countMaps(m, in, true), s, e);
    countMaps(m, in, false);
end
total = pad(2) + pad(4) + sum(heights) + g.RowSpacing * (numel(heights) - 1);
parent.AutoResizeChildren = 'off';               % otherwise SizeChangedFcn never runs
parent.SizeChangedFcn = @(~, ~) fit();
drawnow;                                          % the panel gets its size from the layout
fit();
H.get = @readBack;
H.fields = F;
H.sections = secs;
H.scrollTo = @scrollTo;
H.fit = @fit;                                     % after the window has its final size
H.grid = g;

    function cfg = readBack(cfg)
        for k2 = 1:numel(F)
            old = getPath(cfg, F(k2).path);
            cfg = setPath(cfg, F(k2).path, readControl(F(k2), ctl{k2}, old));
        end
    end

    function fit()
        % Content as wide as the visible area (less the scroll bar), top aligned
        if ~isvalid(content), return, end
        v = parent.InnerPosition;
        w = v(3);
        if total > v(4)
            w = w - 18;
        end
        content.Position = [1, max(0, v(4) - total) + 1, max(w, 100), total];
    end

    function scrollTo(name)
        s2 = find(strcmp(secs, name), 1);
        if isempty(s2), return, end
        top = sum(heights(1:s2 - 1)) + g.RowSpacing * (s2 - 1);   % the card's top, below the padding
        fit();
        view = parent.InnerPosition(4);
        top = min(top, max(0, total - view));     % the last cards cannot reach the top
        scroll(parent, 0, total - view - top);    % y counts from the bottom of the contents
    end
end

function h = rowHeight(f)
switch f.widget
    case 'seeds'
        h = 176;
    case 'contrasts'
        h = 110;
    case 'maps'
        h = 4 * 26 + 3 * 4;
    otherwise
        h = seecat.gui.theme().row;
end
end

function c = makeRow(cg, f, v, r, T, help)
tipText = tip(f);
if strcmp(f.widget, 'contrasts')
    lg = uigridlayout(cg, [3 1], 'RowHeight', {T.row, 26, '1x'}, 'Padding', [0 0 0 0], ...
        'RowSpacing', 4, 'BackgroundColor', T.panel);
    uilabel(lg, 'Text', f.label, 'FontColor', T.text2, 'Tooltip', tipText);
    add = uibutton(lg, 'Text', 'Add row', 'Icon', seecat.gui.icon('plus'), 'BackgroundColor', T.panel, ...
        'FontColor', T.text2);
    lg.Layout.Row = r;
    lg.Layout.Column = 1;
elseif ~strcmp(f.widget, 'seeds')                 % the seed table is as wide as its card
    lab = uilabel(cg, 'Text', f.label, 'FontColor', T.text2, 'Tooltip', tipText);
    lab.Layout.Row = r;
    lab.Layout.Column = 1;
end
info = uiimage(cg, 'ImageSource', seecat.gui.icon('info', T.hex.muted), 'Tooltip', 'About this option', ...
    'ImageClickedFcn', @(~, ~) help());
info.Layout.Row = r;
info.Layout.Column = 3;
edit = {'BackgroundColor', T.panel, 'FontColor', T.text, 'Tooltip', tipText, ...
    'ValueChangingFcn', @(~, ~) help(), 'ValueChangedFcn', @(~, ~) help()};
holder = [];
switch f.widget
    case 'flag'
        c = uicheckbox(cg, 'Text', '', 'Value', logical(v), 'Tooltip', tipText, 'ValueChangedFcn', @(~, ~) help());
    case 'choice'
        holder = row(cg, {220, '1x'}, T);
        c = uidropdown(holder, 'Items', f.choices, 'Value', char(v), 'BackgroundColor', T.panel, ...
            'FontColor', T.text, 'Tooltip', tipText, 'ValueChangedFcn', @(~, ~) help());
    case 'number'
        holder = row(cg, {90, '1x'}, T);
        c = uieditfield(holder, 'text', 'Value', seecat.gui.format(v, 'number'), edit{:});
    case 'range'
        holder = row(cg, {80, 22, 80, '1x'}, T);
        parts = strsplit(seecat.gui.format(v, 'range'));
        parts(end+1:2) = {''};
        a = uieditfield(holder, 'text', 'Value', parts{1}, edit{:});
        uilabel(holder, 'Text', 'to', 'FontColor', T.muted, 'HorizontalAlignment', 'center');
        b = uieditfield(holder, 'text', 'Value', parts{2}, edit{:});
        c = [a b];
    case 'multi'
        holder = row(cg, [num2cell(30 + 7.5 * cellfun(@numel, f.choices)), {'1x'}], T);
        c = gobjects(1, numel(f.choices));
        for i = 1:numel(f.choices)
            c(i) = uicheckbox(holder, 'Text', f.choices{i}, 'Value', any(strcmp(cellstr(v), f.choices{i})), ...
                'FontColor', T.text, 'Tooltip', tipText, 'ValueChangedFcn', @(~, ~) help());
        end
    case 'mask'                                   % 'gm', 'brain' or a mask file
        holder = row(cg, {170, '1x', 30}, T);
        isFile = ~any(strcmp(char(v), {'gm', 'brain'}));
        dd = uidropdown(holder, 'Items', {'Grey matter (gm)', 'Whole brain (brain)', 'Mask file'}, ...
            'ItemsData', {'gm', 'brain', 'file'}, 'BackgroundColor', T.panel, 'FontColor', T.text, 'Tooltip', tipText);
        ed = uieditfield(holder, 'text', 'Value', '', 'Placeholder', 'NIfTI mask in MNI space (voxels > 0)', edit{:});
        if isFile
            dd.Value = 'file';
            ed.Value = char(v);
        else
            dd.Value = char(v);
        end
        ed.Enable = isFile;
        uibutton(holder, 'Text', '', 'Icon', seecat.gui.icon('folder'), 'BackgroundColor', T.panel, ...
            'Tooltip', 'Choose a mask file', 'ButtonPushedFcn', @(~, ~) browseMask(dd, ed, help));
        dd.ValueChangedFcn = @(~, ~) maskChoice(dd, ed, help);
        c = {dd, ed};
    case 'optnumber'                              % a number that can be switched off (0)
        holder = row(cg, {56, 90, '1x'}, T);
        on = any(v(:) > 0);
        cb = uicheckbox(holder, 'Text', 'On', 'Value', on, 'FontColor', T.text, 'Tooltip', tipText);
        shown = v;
        if ~on
            shown = f.choices;                        % the value offered when switched on
        end
        ed = uieditfield(holder, 'text', 'Value', seecat.gui.format(shown, 'number'), 'Enable', on, edit{:});
        cb.ValueChangedFcn = @(~, ~) switchNumber(cb, ed, help);
        c = {cb, ed};
    case {'folder', 'file'}
        holder = row(cg, {'1x', 30}, T);
        c = uieditfield(holder, 'text', 'Value', char(v), edit{:});
        uibutton(holder, 'Text', '', 'Icon', seecat.gui.icon('folder'), 'BackgroundColor', T.panel, ...
            'Tooltip', 'Browse', 'ButtonPushedFcn', @(~, ~) browse(c, f.widget));
    case 'seeds'
        holder = uigridlayout(cg, [2 1], 'RowHeight', {26, '1x'}, 'Padding', [0 0 0 0], ...
            'RowSpacing', 4, 'BackgroundColor', T.panel);
        bar = uigridlayout(holder, [1 5], 'ColumnWidth', {104, 124, 116, 84, '1x'}, 'Padding', [0 0 0 0], ...
            'ColumnSpacing', 6, 'BackgroundColor', T.panel);
        c = uitable(holder, 'Data', seedTable(v), 'RowName', {}, ...
            'ColumnName', {'Name', 'Type', 'Centre x y z (mm)', 'Radius (mm)', 'Check', 'Mask file'}, ...
            'ColumnEditable', [true true true true false true], ...
            'ColumnFormat', {'char', {'Sphere', 'Mask'}, 'char', 'char', 'char', 'char'}, ...
            'ColumnWidth', {100, 80, 130, 86, 120, 400}, 'Tooltip', tipText);
        c.CellEditCallback = @(~, e) seedEdited(c, e, help);
        c.CellSelectionCallback = @(~, e) set(c, 'UserData', unique(e.Indices(:, 1))');
        seedButton(bar, 'Add sphere', 'target', 'Add a sphere seed (centre and radius in MNI mm)', @() addSphere(c, help));
        seedButton(bar, 'Add mask files', 'image', 'Add one seed per mask image (NIfTI in MNI space; voxels > 0)', ...
            @() addMasks(c, help));
        seedButton(bar, 'Choose file', 'folder', 'Choose the mask file of the selected row', @() chooseMask(c, help));
        seedButton(bar, 'Remove', 'minus', 'Remove the selected rows', @() removeSeeds(c, help));
        uilabel(bar, 'Text', 'Spheres and masks can be mixed', ...
            'FontColor', T.muted, 'FontSize', T.size.small);
        recheck(c);
    case 'maps'                                   % entity selector: fixed fields
        holder = uigridlayout(cg, [4 4], 'ColumnWidth', {64, '1x', 64, '1x'}, 'RowHeight', {26, 26, 26, 26}, ...
            'Padding', [0 0 0 0], 'RowSpacing', 4, 'ColumnSpacing', 8, 'BackgroundColor', T.panel);
        keys = {'desc', 'stat', 'suffix', 'space', 'task'};
        names = {'Map (desc)', 'Statistic', 'Suffix', 'Space', 'Task'};
        tips = {'desc label of the maps, e.g. PCC or degPosBinR0p2Sm6', 'stat label, e.g. z or raw', ...
            'file type, e.g. connectivity', 'e.g. MNI152NLin2009cAsym; empty: any', 'e.g. rest; empty: any'};
        if ~isstruct(v), v = struct(); end
        c = struct('keys', {keys}, 'dd', gobjects(1, numel(keys)), 'other', [], 'count', [], 'cache', []);
        for q = 1:numel(keys)
            uilabel(holder, 'Text', names{q}, 'FontColor', T.text2, 'Tooltip', tips{q});
            val = '';
            if isfield(v, keys{q}), val = char(string(v.(keys{q}))); end
            c.dd(q) = uidropdown(holder, 'Editable', 'on', 'Items', unique({'', val}, 'stable'), 'Value', val, ...
                'BackgroundColor', T.panel, 'FontColor', T.text, 'Tooltip', [tips{q} '. Type, or open the list for the values found.'], ...
                'ValueChangedFcn', @(~, ~) help());
        end
        rest = rmfield(v, intersect(fieldnames(v), keys));
        uilabel(holder, 'Text', 'Other', 'FontColor', T.text2, 'Tooltip', 'Any other entity, e.g. ses=1, run=1');
        c.other = uieditfield(holder, 'text', 'Value', seecat.gui.format(rest, 'maps'), ...
            'Placeholder', 'e.g. ses=1, run=1', edit{:});
        c.count = uilabel(holder, 'Text', '', 'FontColor', T.muted, 'FontSize', T.size.small);
        c.count.Layout.Row = 4;
        c.count.Layout.Column = [1 4];
    case 'contrasts'
        c = uitable(cg, 'Data', contrastTable(v), 'ColumnEditable', true, 'RowName', {}, ...
            'ColumnName', {'Name', 'Type', 'Weights'}, 'Tooltip', tipText, ...
            'ColumnWidth', {140, 60, 'auto'}, 'CellEditCallback', @(~, ~) help());
        add.ButtonPushedFcn = @(~, ~) set(c, 'Data', [c.Data; {'', 't', ''}]);
    otherwise                                     % text, labels, maps
        c = uieditfield(cg, 'text', 'Value', seecat.gui.format(v, f.widget), edit{:});
end
if isempty(holder)
    c(1).Layout.Row = r;
    c(1).Layout.Column = 2;
else
    holder.Layout.Row = r;
    holder.Layout.Column = 2;
    if strcmp(f.widget, 'seeds')
        holder.Layout.Column = [1 2];
    end
end
end

function h = row(cg, widths, T)
h = uigridlayout(cg, [1 numel(widths)], 'ColumnWidth', widths, 'Padding', [0 0 0 0], ...
    'ColumnSpacing', 6, 'BackgroundColor', T.panel);
end

function t = tip(f)
t = sprintf('%s (batch: %s)', f.help, f.path);
if isempty(f.help)
    t = sprintf('batch: %s', f.path);
end
end

function browse(c, kind)
if strcmp(kind, 'folder')
    p = uigetdir(c.Value);
    if ~isequal(p, 0), c.Value = p; end
    if ~isequal(p, 0) && ~isempty(c.ValueChangedFcn)
        c.ValueChangedFcn(c, []);                 % as if typed (e.g. the maps fields list the folder)
    end
else
    [f, p] = uigetfile('*.*');
    if ~isequal(f, 0), c.Value = fullfile(p, f); end
end
end

function switchNumber(cb, ed, help)
ed.Enable = cb.Value;
help();
end

function maskChoice(dd, ed, help)
ed.Enable = strcmp(dd.Value, 'file');
if strcmp(dd.Value, 'file') && isempty(strtrim(ed.Value))
    browseMask(dd, ed, help);
end
help();
end

function browseMask(dd, ed, help)
[f, p] = uigetfile({'*.nii;*.nii.gz', 'NIfTI images (*.nii, *.nii.gz)'; '*.*', 'All files'}, 'Choose a mask', ed.Value);
if ~isequal(f, 0)
    dd.Value = 'file';
    ed.Enable = true;
    ed.Value = fullfile(p, f);
elseif isempty(strtrim(ed.Value)) && strcmp(dd.Value, 'file')
    dd.Value = 'gm';                              % cancelled: back to a mask that needs no file
    ed.Enable = false;
end
help();
end

function v = readControl(f, c, old)
switch f.widget
    case {'flag', 'choice'}
        v = c.Value;
    case 'multi'
        on = {c([c.Value]).Text};
        v = f.choices(ismember(f.choices, on));    % in the listed order
    case 'range'
        v = seecat.gui.parse(strtrim([c(1).Value ' ' c(2).Value]), 'range', old);
    case {'folder', 'file'}
        v = strtrim(c.Value);
    case 'mask'
        v = c{1}.Value;
        if strcmp(v, 'file')
            v = strtrim(c{2}.Value);
        end
    case 'optnumber'
        v = 0;
        if c{1}.Value
            v = seecat.gui.parse(c{2}.Value, 'number', old);
        end
    case 'seeds'
        v = seedsFrom(c.Data);
    case 'maps'
        v = mapsFrom(c);
    case 'contrasts'
        v = contrastsFrom(c.Data);
    otherwise
        v = seecat.gui.parse(c.Value, f.widget, old);
end
end

% ---- maps: entity selector of the per-subject maps ---------------------

function v = mapsFrom(c)
v = seecat.gui.parse(c.other.Value, 'maps', struct());
for q = 1:numel(c.keys)
    s = strtrim(char(c.dd(q).Value));
    if ~isempty(s)
        v.(c.keys{q}) = s;
    end
end
end

function both(f1, f2, s, e)
f1(s, e);
f2();
end

function F = mapFiles(dirField, fresh)
% Image files of the derivatives folder that can be maps (cached per folder)
persistent cacheDir cacheFiles
F = [];
d = strtrim(dirField.Value);
if isempty(d) || ~exist(d, 'dir')
    return
end
if isequal(cacheDir, d) && ~fresh
    F = cacheFiles;
    return
end
try
    L = seecat.bids.layout(d);
catch
    return
end
F = seecat.bids.query(L, 'ext', {'.nii', '.nii.gz'});
F = F(~ismember({F.suffix}, {'bold', 'boldref', 'mask', 'dseg', 'probseg', 'T1w', 'T2w'}));
cacheDir = d;
cacheFiles = F;
end

function fillMaps(c, dirField)
F = mapFiles(dirField, false);
if isempty(F)
    return
end
for q = 1:numel(c.keys)
    k = c.keys{q};
    if strcmp(k, 'suffix')
        vals = {F.suffix};
    else
        vals = arrayfun(@(f) ent(f, k), F, 'UniformOutput', false);
    end
    vals = unique(vals(~cellfun(@isempty, vals)));
    cur = char(c.dd(q).Value);
    c.dd(q).Items = unique([{''}, vals(:)', {cur}], 'stable');
    c.dd(q).Value = cur;
end
end

function countMaps(c, dirField, fresh)
F = mapFiles(dirField, fresh);
if isempty(F)
    c.count.Text = 'Set the derivatives folder above, then open a list to pick from the maps found there.';
    return
end
v = mapsFrom(c);
keep = true(size(F));
for k = fieldnames(v)'
    if strcmp(k{1}, 'suffix')
        have = {F.suffix};
    else
        have = arrayfun(@(f) ent(f, k{1}), F, 'UniformOutput', false);
    end
    keep = keep & strcmp(have, v.(k{1}));
end
subs = unique(arrayfun(@(f) ent(f, 'sub'), F(keep), 'UniformOutput', false));
c.count.Text = sprintf('%d map(s) of %d subject(s) match.', nnz(keep), numel(subs));
end

function x = ent(f, k)
x = '';
if isfield(f.ent, k)
    x = f.ent.(k);
end
end

% ---- seeds: one row per seed, a sphere or a mask image ----------------
% Columns: name, type ('Sphere' or 'Mask'), centre ('x y z'), radius, check
% (what is wrong with the row, or 'OK'), mask file

function T = seedTable(s)
T = cell(0, 6);
for i = 1:numel(s)
    if isfield(s, 'file') && ~isempty(s(i).file)
        T(end+1, :) = {s(i).name, 'Mask', '', '', '', s(i).file}; %#ok<AGROW>
    else
        T(end+1, :) = {s(i).name, 'Sphere', sprintf('%g %g %g', s(i).center), sprintf('%g', s(i).radius), '', ''}; %#ok<AGROW>
    end
end
end

function s = seedsFrom(T)
s = struct('name', {}, 'center', {}, 'radius', {}, 'file', {});
for i = 1:size(T, 1)
    if all(cellfun(@(x) isempty(strtrim(char(x))), T(i, [1 3 6]))), continue, end   % a blank row
    [msg, c, r] = seedCheck(T(i, :), T(:, 1));
    if ~strcmp(msg, 'OK')
        error('SeeCAT:gui', 'Seed %d (%s): %s.', i, strtrim(char(T{i, 1})), msg);
    end
    if strcmp(T{i, 2}, 'Mask')
        s(end+1) = struct('name', strtrim(T{i, 1}), 'center', [], 'radius', [], 'file', strtrim(T{i, 6})); %#ok<AGROW>
    else
        s(end+1) = struct('name', strtrim(T{i, 1}), 'center', c, 'radius', r, 'file', ''); %#ok<AGROW>
    end
end
end

function [msg, c, r] = seedCheck(row, names)
% 'OK', or what is wrong with one row; C and R are the sphere's centre and
% radius
c = [];
r = [];
name = strtrim(char(row{1}));
if isempty(regexp(name, '^[a-zA-Z0-9]+$', 'once'))
    msg = 'name: letters and digits';
    return
end
if nnz(strcmp(strtrim(cellstr(names)), name)) > 1
    msg = 'name used twice';
    return
end
if strcmp(row{2}, 'Mask')
    f = strtrim(char(row{6}));
    if isempty(f)
        msg = 'choose a mask file';
    elseif ~exist(f, 'file')
        msg = 'file not found';
    elseif isempty(regexpi(f, '\.nii(\.gz)?$', 'once'))
        msg = 'not a .nii or .nii.gz';
    else
        msg = 'OK';
    end
    return
end
c = sscanf(regexprep(char(row{3}), '[,;\[\]]', ' '), '%f')';
r = str2double(row{4});
if numel(c) ~= 3 || any(~isfinite(c))
    msg = 'centre: three numbers, x y z';
elseif ~isfinite(r) || r <= 0
    msg = 'radius: a number above 0';
else
    msg = 'OK';
end
end

function recheck(c)
% Fill the Check column and colour the rows that need fixing
D = c.Data;
for i = 1:size(D, 1)
    D{i, 5} = seedCheck(D(i, :), D(:, 1));
end
c.Data = D;
removeStyle(c);
bad = find(~strcmp(D(:, 5), 'OK'));
if ~isempty(bad)
    addStyle(c, uistyle('FontColor', [0.75 0.1 0.1]), 'cell', [bad(:), repmat(5, numel(bad), 1)]);
end
end

function seedButton(parent, text, iconName, tipText, fn)
T = seecat.gui.theme();
uibutton(parent, 'Text', text, 'Icon', seecat.gui.icon(iconName), 'Tooltip', tipText, ...
    'BackgroundColor', T.panel, 'FontColor', T.text2, 'ButtonPushedFcn', @(~, ~) fn());
end

function seedEdited(c, e, help)
r = e.Indices(1);
D = c.Data;
if e.Indices(2) == 2 && strcmp(D{r, 2}, 'Sphere') && isempty(strtrim(D{r, 3}))
    D(r, [3 4 6]) = {'0 0 0', '6', ''};               % switched to a sphere: a centre to edit
    c.Data = D;
elseif e.Indices(2) == 2 && strcmp(D{r, 2}, 'Mask') && isempty(strtrim(D{r, 6}))
    c.UserData = r;                               % switched to a mask: pick the file now
    chooseMask(c, help);
    return
elseif e.Indices(2) == 6 && ~isempty(strtrim(D{r, 6}))
    D{r, 2} = 'Mask';                             % a path typed in: it is a mask
    c.Data = D;
end
recheck(c);
help();
end

function addSphere(c, help)
c.Data = [c.Data; {newName(c.Data(:, 1), 'Seed'), 'Sphere', '0 0 0', '6', '', ''}];
recheck(c);
help();
end

function addMasks(c, help)
[f, p] = uigetfile({'*.nii;*.nii.gz', 'NIfTI images (*.nii, *.nii.gz)'}, 'Seed masks', 'MultiSelect', 'on');
figure(ancestor(c, 'figure'));
if isequal(f, 0), return, end
D = c.Data;
for k = cellstr(f)
    D(end+1, :) = {newName(D(:, 1), maskName(k{1})), 'Mask', '', '', '', fullfile(p, k{1})}; %#ok<AGROW>
end
c.Data = D;
recheck(c);
help();
end

function chooseMask(c, help)
rows = c.UserData;
if ~isscalar(rows) || rows > size(c.Data, 1)
    uialert(ancestor(c, 'figure'), 'Select one row of the seed table first.', 'Seeds', 'Icon', 'info');
    return
end
[f, p] = uigetfile({'*.nii;*.nii.gz', 'NIfTI images (*.nii, *.nii.gz)'}, 'Seed mask');
figure(ancestor(c, 'figure'));
D = c.Data;
if isequal(f, 0)
    if strcmp(D{rows, 2}, 'Mask') && isempty(strtrim(D{rows, 6}))
        D(rows, 2:4) = {'Sphere', '0 0 0', '6'};  % nothing chosen: back to a sphere
        c.Data = D;
        recheck(c);
    end
    return
end
D(rows, [2 3 4 6]) = {'Mask', '', '', fullfile(p, f)};
if isempty(strtrim(D{rows, 1})) || ~isempty(regexp(D{rows, 1}, '^Seed\d*$', 'once'))
    D{rows, 1} = newName(D([1:rows-1, rows+1:end], 1), maskName(f));
end
c.Data = D;
recheck(c);
help();
end

function removeSeeds(c, help)
rows = c.UserData;
if isempty(rows) || any(rows > size(c.Data, 1))
    uialert(ancestor(c, 'figure'), 'Select the rows to remove first.', 'Seeds', 'Icon', 'info');
    return
end
c.Data(rows, :) = [];
c.UserData = [];
recheck(c);
help();
end

function n = maskName(file)
% A seed name from a mask file name: PCC_sphere6mm_mask.nii.gz -> PCCsphere6mm
n = regexprep(file, '(?i)\.nii(\.gz)?$', '');
n = regexprep(n, '(?i)([_\-. ]?(mask|roi|seed|bin|binary))+$', '');
n = regexprep(n, '[^a-zA-Z0-9]', '');
if isempty(n)
    n = 'Seed';
end
end

function n = newName(names, base)
% BASE, or BASE2, BASE3, ... when taken ('Seed' always gets a number)
taken = strtrim(cellstr(names));
n = base;
k = 1;
while any(strcmp(taken, n)) || (strcmp(base, 'Seed') && k == 1)
    n = sprintf('%s%d', base, k);
    k = k + 1;
end
end

function T = contrastTable(c)
T = cell(0, 3);
for i = 1:numel(c)
    T(end+1, :) = {c(i).name, c(i).type, mat2str(c(i).weights)}; %#ok<AGROW>
end
end

function c = contrastsFrom(T)
c = struct('name', {}, 'type', {}, 'weights', {});
for i = 1:size(T, 1)
    if isempty(T{i, 1}), continue, end
    c(end+1) = struct('name', T{i, 1}, 'type', T{i, 2}, 'weights', seecat.gui.parse(T{i, 3}, 'text', zeros(1, 0))); %#ok<AGROW>
end
end

function v = getPath(s, p)
for k = strsplit(p, '.')
    s = s.(k{1});
end
v = s;
end

function s = setPath(s, p, v)
k = strsplit(p, '.');
if isscalar(k)
    s.(k{1}) = v;
else
    s.(k{1}) = setPath(s.(k{1}), strjoin(k(2:end), '.'), v);
end
end
