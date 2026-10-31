function H = form(parent, F, cfg, advanced)
% FORM  Controls for a pipeline's form description, filled from CFG.
%   H = seecat.gui.form(parent, seecat.prep.gui(), cfg, showAdvanced)
%   cfg = H.get(cfg)          % read the controls back into a config
%
% PARENT is a container (uipanel/uigridlayout). Entries are grouped by
% section; advanced entries are left out unless ADVANCED. Values are turned
% back into the type of the option's current value (numbers, vectors,
% matrices, keywords such as 'auto', lists), see seecat.gui.parse.

if nargin < 4
    advanced = false;
end
F = F(advanced | ~[F.advanced]);
secs = unique({F.section}, 'stable');
nRows = numel(F) + numel(secs);
g = uigridlayout(parent, [nRows 3], 'ColumnWidth', {170, '1x', 70}, ...
    'RowHeight', repmat({26}, 1, nRows), 'Scrollable', 'on', 'RowSpacing', 4);
ctl = cell(numel(F), 1);
r = 0;
for s = secs
    r = r + 1;
    h = uilabel(g, 'Text', s{1}, 'FontWeight', 'bold');
    h.Layout.Row = r;
    h.Layout.Column = [1 3];
    for k = find(strcmp({F.section}, s{1}))
        r = r + 1;
        f = F(k);
        lab = uilabel(g, 'Text', f.label, 'Tooltip', tip(f));
        lab.Layout.Row = r;
        lab.Layout.Column = 1;
        v = getPath(cfg, f.path);
        [ctl{k}, tall] = makeControl(g, f, v, r);
        if tall > 0
            g.RowHeight{r} = tall;
        end
    end
end
H.get = @readBack;
H.fields = F;

    function cfg = readBack(cfg)
        for k2 = 1:numel(F)
            old = getPath(cfg, F(k2).path);
            cfg = setPath(cfg, F(k2).path, readControl(F(k2), ctl{k2}, old));
        end
    end
end

function t = tip(f)
t = sprintf('%s (batch: %s)', f.help, f.path);
if isempty(f.help)
    t = sprintf('batch: %s', f.path);
end
end

function [c, tall] = makeControl(g, f, v, r)
tall = 0;
switch f.widget
    case 'flag'
        c = uicheckbox(g, 'Text', '', 'Value', logical(v));
    case 'choice'
        c = uidropdown(g, 'Items', f.choices, 'Value', char(v));
    case 'multi'
        c = uigridlayout(g, [1 numel(f.choices)], 'Padding', [0 0 0 0]);
        for i = 1:numel(f.choices)
            uicheckbox(c, 'Text', f.choices{i}, 'Value', any(strcmp(cellstr(v), f.choices{i})));
        end
    case {'folder', 'file'}
        c = uieditfield(g, 'text', 'Value', char(v));
        b = uibutton(g, 'Text', '…', 'ButtonPushedFcn', @(~, ~) browse(c, f.widget));
        b.Layout.Row = r;
        b.Layout.Column = 3;
    case 'seeds'
        c = uitable(g, 'Data', seedTable(v), 'ColumnEditable', true, ...
            'ColumnName', {'name', 'x', 'y', 'z', 'radius', 'file'});
        tall = 120;
        addRows(g, c, r, {'', 0, 0, 0, 6, ''});
    case 'contrasts'
        c = uitable(g, 'Data', contrastTable(v), 'ColumnEditable', true, ...
            'ColumnName', {'name', 'type', 'weights'});
        tall = 100;
        addRows(g, c, r, {'', 't', ''});
    otherwise                                     % text, labels, number, range, maps
        c = uieditfield(g, 'text', 'Value', seecat.gui.format(v, f.widget));
end
c.Layout.Row = r;
if ~any(strcmp(f.widget, {'folder', 'file', 'seeds', 'contrasts'}))
    c.Layout.Column = [2 3];
else
    c.Layout.Column = 2;
end
c.Tooltip = tip(f);
end

function addRows(g, t, r, blank)
b = uibutton(g, 'Text', '+ row', 'ButtonPushedFcn', @(~, ~) set(t, 'Data', [t.Data; blank]));
b.Layout.Row = r;
b.Layout.Column = 3;
end

function browse(c, kind)
if strcmp(kind, 'folder')
    p = uigetdir(c.Value);
    if ~isequal(p, 0), c.Value = p; end
else
    [f, p] = uigetfile('*.*');
    if ~isequal(f, 0), c.Value = fullfile(p, f); end
end
end

function v = readControl(f, c, old)
switch f.widget
    case 'flag'
        v = c.Value;
    case 'choice'
        v = c.Value;
    case 'multi'
        boxes = c.Children;
        on = {boxes([boxes.Value]).Text};
        v = f.choices(ismember(f.choices, on));    % in the listed order, whatever the child order
    case {'folder', 'file'}
        v = strtrim(c.Value);
    case 'seeds'
        v = seedsFrom(c.Data);
    case 'contrasts'
        v = contrastsFrom(c.Data);
    otherwise
        v = seecat.gui.parse(c.Value, f.widget, old);
end
end

function T = seedTable(s)
T = cell(0, 6);
for i = 1:numel(s)
    c = [NaN NaN NaN];
    rad = NaN;
    file = '';
    if isfield(s, 'center') && ~isempty(s(i).center), c = s(i).center(:)'; end
    if isfield(s, 'radius') && ~isempty(s(i).radius), rad = s(i).radius; end
    if isfield(s, 'file') && ~isempty(s(i).file), file = s(i).file; end
    T(end+1, :) = {s(i).name, c(1), c(2), c(3), rad, file}; %#ok<AGROW>
end
end

function s = seedsFrom(T)
s = struct('name', {}, 'center', {}, 'radius', {}, 'file', {});
for i = 1:size(T, 1)
    if isempty(T{i, 1}), continue, end
    if ~isempty(T{i, 6})
        s(end+1) = struct('name', T{i, 1}, 'center', [], 'radius', [], 'file', T{i, 6}); %#ok<AGROW>
    else
        s(end+1) = struct('name', T{i, 1}, 'center', [T{i, 2:4}], 'radius', T{i, 5}, 'file', ''); %#ok<AGROW>
    end
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
