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
total = pad(2) + pad(4) + sum(heights) + g.RowSpacing * (numel(heights) - 1);
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
        h = 132;
    case 'contrasts'
        h = 110;
    otherwise
        h = seecat.gui.theme().row;
end
end

function c = makeRow(cg, f, v, r, T, help)
tipText = tip(f);
if any(strcmp(f.widget, {'seeds', 'contrasts'}))
    lg = uigridlayout(cg, [3 1], 'RowHeight', {T.row, 26, '1x'}, 'Padding', [0 0 0 0], ...
        'RowSpacing', 4, 'BackgroundColor', T.panel);
    uilabel(lg, 'Text', f.label, 'FontColor', T.text2, 'Tooltip', tipText);
    add = uibutton(lg, 'Text', 'Add row', 'Icon', seecat.gui.icon('plus'), 'BackgroundColor', T.panel, ...
        'FontColor', T.text2);
    lg.Layout.Row = r;
    lg.Layout.Column = 1;
else
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
    case {'folder', 'file'}
        holder = row(cg, {'1x', 30}, T);
        c = uieditfield(holder, 'text', 'Value', char(v), edit{:});
        uibutton(holder, 'Text', '', 'Icon', seecat.gui.icon('folder'), 'BackgroundColor', T.panel, ...
            'Tooltip', 'Browse', 'ButtonPushedFcn', @(~, ~) browse(c, f.widget));
    case 'seeds'
        c = uitable(cg, 'Data', seedTable(v), 'ColumnEditable', true, 'RowName', {}, ...
            'ColumnName', {'Name', 'x', 'y', 'z', 'Radius', 'File'}, 'Tooltip', tipText, ...
            'ColumnWidth', {110, 50, 50, 50, 56, 'auto'}, 'CellEditCallback', @(~, ~) help());
        add.ButtonPushedFcn = @(~, ~) set(c, 'Data', [c.Data; {'', 0, 0, 0, 6, ''}]);
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
else
    [f, p] = uigetfile('*.*');
    if ~isequal(f, 0), c.Value = fullfile(p, f); end
end
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
