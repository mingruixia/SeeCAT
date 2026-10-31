function app = window(m)
% WINDOW  The viewer window for a seecat.view.Model (uifigure, G1).
%   app = seecat.view.window(model)
%
% Tool bar (layout, underlay, orientation, surface and export), the views
% with a colour bar, a side column with Layers, Threshold and Go to cards,
% and a cluster table at the bottom whose rows move the cursor. Layouts:
% Orthogonal (three views and the cursor read-out), Single (one large view
% and three thumbnails) and Mosaic (slices of the chosen orientation).
% All logic lives in the model; this file only draws and forwards user
% actions. Use seecat.viewer to open files.

T = seecat.gui.theme();
here = fileparts(fileparts(fileparts(mfilename('fullpath'))));       % SeeCAT/
app.model = m;
fig = uifigure('Name', 'SeeCAT Viewer', 'Position', [70 60 1380 880], 'Color', T.border, ...
    'Icon', fullfile(here, 'resources', 'logo_64.png'));
app.fig = fig;
root = uigridlayout(fig, [3 1], 'RowHeight', {46, '1x', 31}, 'Padding', [0 0 0 0], ...
    'RowSpacing', 1, 'BackgroundColor', T.border);
st = struct('layout', 'orthogonal', 'view', 'axial', 'clusters', table());
names = {'sagittal', 'coronal', 'axial'};

% ---- tool bar ----
tb = uigridlayout(root, [1 15], 'ColumnWidth', {24, 84, 14, 108, 78, 82, 14, 140, 14, 70, 70, '1x', 96, 112, 104}, ...
    'Padding', [12 9 12 9], 'ColumnSpacing', 0, 'BackgroundColor', T.panel);
uiimage(tb, 'ImageSource', fullfile(here, 'resources', 'logo_64.png'));
openB = tool(tb, 'Open', 'folder', @(~, ~) onAdd());
openB.Layout.Column = 2;
lay(1) = tool(tb, 'Orthogonal', 'grid', @(~, ~) setLayout('orthogonal'));
lay(2) = tool(tb, 'Single', 'single', @(~, ~) setLayout('single'));
lay(3) = tool(tb, 'Mosaic', 'mosaic', @(~, ~) setLayout('mosaic'));
for k = 1:3, lay(k).Layout.Column = 3 + k; end
underlays = {'ch2', 'ch2better', 'mni2009c', 'avg152T1', 'single_subj_T1', 'Other…'};
app.underlay = uidropdown(tb, 'Items', underlays, 'Value', m.underlay.name, 'Tooltip', 'Underlay image', ...
    'BackgroundColor', T.panel, 'FontColor', T.text, 'ValueChangedFcn', @(~, ~) onUnderlay());
app.underlay.Layout.Column = 8;
ori(1) = tool(tb, 'Neuro', '', @(~, ~) setRadio(false));
ori(2) = tool(tb, 'Radio', '', @(~, ~) setRadio(true));
ori(1).Tooltip = 'Neurological: left on the left';
ori(2).Tooltip = 'Radiological: left on the right';
ori(1).Layout.Column = 10;
ori(2).Layout.Column = 11;
app.surface = tool(tb, 'Surface', 'surface', @(~, ~) onSurface());
app.surface.Layout.Column = 13;
if isempty(which('BrainNetViewer'))
    app.surface.Enable = 'off';
    app.surface.Tooltip = 'Needs BrainNet Viewer 2.0 on the MATLAB path (nitrc.org/projects/bnv)';
else
    app.surface.Tooltip = 'Show the selected layer on the cortex in BrainNet Viewer';
end
b = tool(tb, 'Save image', 'image', @(~, ~) onExport());
b.Layout.Column = 14;
b = tool(tb, 'Save map', 'download', @(~, ~) onSave());
b.Layout.Column = 15;
b.Tooltip = 'Save the thresholded map of the selected layer (NIfTI)';

% ---- views | side column ----
mid = uigridlayout(root, [1 2], 'ColumnWidth', {'1x', 316}, 'Padding', [0 0 0 0], ...
    'ColumnSpacing', 1, 'BackgroundColor', T.border);
canvas = uigridlayout(mid, [2 1], 'RowHeight', {'1x', 26}, 'Padding', [3 3 3 3], 'RowSpacing', 3, ...
    'BackgroundColor', T.canvas);
area = uigridlayout(canvas, [2 2], 'Padding', [0 0 0 0], 'RowSpacing', 3, 'ColumnSpacing', 3, ...
    'BackgroundColor', T.canvas);
for k = 1:3
    app.ax.(names{k}) = viewAxes(area);
end
app.ax.main = viewAxes(area);
info = uigridlayout(area, [9 1], 'RowHeight', [{18}, repmat({17}, 1, 7), {'1x'}], 'Padding', [14 10 10 12], ...
    'RowSpacing', 2, 'BackgroundColor', T.canvas2);
caption(info, 'CURSOR', T.muted);
app.read = gobjects(1, 7);
for k = 1:7
    app.read(k) = uilabel(info, 'Text', '', 'FontName', T.mono, 'FontSize', T.size.small, 'FontColor', T.canvasText);
end
app.read(5).FontColor = [1 0.83 0.23];      % the atlas label
cb = uigridlayout(canvas, [1 5], 'ColumnWidth', {54, '1x', 54, 16, 230}, 'Padding', [6 4 6 4], ...
    'ColumnSpacing', 6, 'BackgroundColor', T.canvas);
app.cbLo = uilabel(cb, 'Text', '', 'FontColor', T.muted, 'FontSize', T.size.small, 'HorizontalAlignment', 'right');
app.cbImg = uiimage(cb, 'ScaleMethod', 'stretch');
app.cbHi = uilabel(cb, 'Text', '', 'FontColor', T.muted, 'FontSize', T.size.small);
uilabel(cb, 'Text', '');
app.cbText = uilabel(cb, 'Text', '', 'FontColor', T.muted, 'FontSize', T.size.small);

side = uigridlayout(mid, [4 1], 'RowHeight', {236, 284, 82, '1x'}, 'Padding', [12 12 12 12], ...
    'RowSpacing', 12, 'Scrollable', 'on', 'BackgroundColor', T.side);
% Layers card
cg = card(side, 'Layers', 'layers', {84, T.row, T.row, T.row});
hb = uigridlayout(cg, [1 2], 'ColumnWidth', {26, 26}, 'Padding', [0 0 0 0], 'ColumnSpacing', 4, ...
    'BackgroundColor', T.panel);
hb.Layout.Row = 1;
hb.Layout.Column = 2;
iconButton(hb, 'plus', 'Add a layer', @(~, ~) onAdd());
iconButton(hb, 'minus', 'Remove the selected layer', @(~, ~) onRemove());
app.layers = uilistbox(cg, 'Items', {}, 'FontColor', T.text, 'ValueChangedFcn', @(~, ~) showLayer());
app.layers.Layout.Row = 2;
app.layers.Layout.Column = [1 2];
label(cg, 'Colour map', 3);
app.cmap = uidropdown(cg, 'Items', {'auto', 'hot', 'winter', 'parula', 'jet', 'gray'}, 'BackgroundColor', T.panel, ...
    'FontColor', T.text, 'ValueChangedFcn', @(s, ~) setLayer('colormap', s.Value));
label(cg, 'Opacity', 4);
app.alpha = uislider(cg, 'Limits', [0 1], 'MajorTicks', [], 'MinorTicks', [], 'Value', 1, ...
    'ValueChangedFcn', @(s, ~) setLayer('alpha', s.Value));
label(cg, 'Volume', 5);
app.frame = uispinner(cg, 'Limits', [1 1.0001], 'BackgroundColor', T.panel, 'FontColor', T.text, ...
    'ValueChangedFcn', @(s, ~) onFrame(s.Value));
% Threshold card
cg = card(side, 'Threshold', 'sliders', {T.row, T.row, T.row, T.row, T.row, T.row, 36});
label(cg, 'Threshold by', 2);
g2 = pair(cg, 2);
app.tmode(1) = tool(g2, 'Value', '', @(~, ~) setMode('stat'));
app.tmode(2) = tool(g2, 'p', '', @(~, ~) setMode('p'));
label(cg, 'Threshold', 3);
app.tvalue = uieditfield(cg, 'numeric', 'BackgroundColor', T.panel, 'FontColor', T.text, ...
    'ValueChangedFcn', @(~, ~) onThreshold());
label(cg, 'Correction', 4);
app.tcorr = uidropdown(cg, 'Items', {'none', 'cluster FWE', 'voxel FWE', 'voxel FDR'}, ...
    'ItemsData', {'none', 'cluster_fwe', 'voxel_fwe', 'voxel_fdr'}, 'BackgroundColor', T.panel, ...
    'FontColor', T.text, 'ValueChangedFcn', @(~, ~) onThreshold());
label(cg, 'Alpha / CDT p', 5);
g2 = pair(cg, 5);
app.talpha = uieditfield(g2, 'numeric', 'Value', 0.05, 'BackgroundColor', T.panel, 'FontColor', T.text, ...
    'Tooltip', 'Corrected significance level', 'ValueChangedFcn', @(~, ~) onThreshold());
app.tcdt = uieditfield(g2, 'numeric', 'Value', 0.001, 'BackgroundColor', T.panel, 'FontColor', T.text, ...
    'Tooltip', 'Cluster-defining threshold (cluster FWE)', 'ValueChangedFcn', @(~, ~) onThreshold());
label(cg, 'Sign', 6);
g3 = uigridlayout(cg, [1 3], 'Padding', [0 0 0 0], 'ColumnSpacing', 0, 'BackgroundColor', T.panel);
g3.Layout.Row = 6;
g3.Layout.Column = 2;
signs = {'pos', 'neg', 'both'};
glyph = {'+', '−', '±'};
for k = 1:3
    s_ = signs{k};
    app.tsign(k) = tool(g3, glyph{k}, '', @(~, ~) setSign(s_));
end
label(cg, 'Min. cluster (voxels)', 7);
app.tk = uispinner(cg, 'Limits', [0 Inf], 'BackgroundColor', T.panel, 'FontColor', T.text, ...
    'ValueChangedFcn', @(~, ~) onThreshold());
app.info = uilabel(cg, 'Text', '', 'FontColor', T.icon, 'FontSize', T.size.small, 'WordWrap', 'on', ...
    'VerticalAlignment', 'top');
app.info.Layout.Row = 8;
app.info.Layout.Column = [1 2];
% Go to card
cg = card(side, 'Go to', 'crosshair', {T.row});
g4 = uigridlayout(cg, [1 4], 'ColumnWidth', {'1x', '1x', '1x', 70}, 'Padding', [0 0 0 0], ...
    'ColumnSpacing', 4, 'BackgroundColor', T.panel);
g4.Layout.Row = 2;
g4.Layout.Column = [1 2];
for k = 1:3
    app.coord(k) = uieditfield(g4, 'numeric', 'ValueDisplayFormat', '%.0f', 'BackgroundColor', T.panel, ...
        'FontColor', T.text, 'Tooltip', sprintf('%s (mm)', axisName(k)), 'ValueChangedFcn', @(~, ~) onCoord());
end
tool(g4, 'Peak', 'peak', @(~, ~) onPeak());

% ---- cluster drawer ----
drawer = uigridlayout(root, [2 1], 'RowHeight', {30, '1x'}, 'Padding', [0 0 0 0], 'RowSpacing', 0, ...
    'BackgroundColor', T.panel);
dh = uigridlayout(drawer, [1 5], 'ColumnWidth', {30, 70, '1x', 110, 6}, 'Padding', [8 3 4 3], ...
    'ColumnSpacing', 6, 'BackgroundColor', T.panel);
app.fold = iconButton(dh, 'chevron-up', 'Show or hide the cluster table', @(~, ~) toggleDrawer());
uilabel(dh, 'Text', 'Clusters', 'FontWeight', 'bold', 'FontColor', T.text);
app.clText = uilabel(dh, 'Text', '', 'FontColor', T.muted);
tool(dh, 'Export TSV', 'download', @(~, ~) saveTable());
app.table = uitable(drawer, 'RowName', {}, 'CellSelectionCallback', @(~, e) goRow(e));

seecat.gui.style(fig);
for k = 1:7
    app.read(k).FontName = T.mono;
end
app.setLayout = @setLayout;                   % for scripts and tests
app.refresh = @showLayer;
refreshList(1);
setLayout('orthogonal');
seecat.gui.segment(ori, [~m.radiological, m.radiological]);
if ~isempty(m.layers)
    openDrawer(true);
end

    % ---- building blocks ----------------------------------------------------
    function b = tool(parent, text, iconName, fn)
        b = uibutton(parent, 'Text', text, 'BackgroundColor', T.panel, 'FontColor', T.text2, 'ButtonPushedFcn', fn);
        if ~isempty(iconName)
            b.Icon = seecat.gui.icon(iconName);
        end
    end

    function b = iconButton(parent, iconName, tipText, fn)
        b = uibutton(parent, 'Text', '', 'Icon', seecat.gui.icon(iconName), 'BackgroundColor', T.panel, ...
            'Tooltip', tipText, 'ButtonPushedFcn', fn);
    end

    function cg = card(parent, titleText, iconName, rows)
        outer = uigridlayout(parent, [1 1], 'Padding', [1 1 1 1], 'BackgroundColor', T.border);
        cg = uigridlayout(outer, [numel(rows) + 1, 2], 'ColumnWidth', {112, '1x'}, ...
            'RowHeight', [{24}, rows], 'RowSpacing', 6, 'ColumnSpacing', 8, ...
            'Padding', [12 12 12 10], 'BackgroundColor', T.panel);
        hg = uigridlayout(cg, [1 2], 'ColumnWidth', {18, '1x'}, 'Padding', [0 0 0 0], 'ColumnSpacing', 6, ...
            'BackgroundColor', T.panel);
        uiimage(hg, 'ImageSource', seecat.gui.icon(iconName, T.hex.accent));
        uilabel(hg, 'Text', titleText, 'FontSize', T.size.card, 'FontWeight', 'bold', 'FontColor', T.text);
    end

    function label(cg, text, r)
        h = uilabel(cg, 'Text', text, 'FontColor', T.text2);
        h.Layout.Row = r;
        h.Layout.Column = 1;
    end

    function g = pair(cg, r)
        g = uigridlayout(cg, [1 2], 'Padding', [0 0 0 0], 'ColumnSpacing', 4, 'BackgroundColor', T.panel);
        g.Layout.Row = r;
        g.Layout.Column = 2;
    end

    % ---- layers and thresholds ------------------------------------------
    function i = current()
        i = app.layers.Value;
        if ~isnumeric(i) || isempty(i) || i > numel(m.layers)
            i = [];
        end
    end

    function refreshList(select)
        n = numel(m.layers);
        app.layers.Items = cellfun(@shortName, {m.layers.name}, 'UniformOutput', false);
        app.layers.ItemsData = 1:n;
        if nargin && n > 0
            app.layers.Value = min(select, n);
        end
        showLayer();
    end

    function showLayer()
        i = current();
        if isempty(i)
            redraw();
            return
        end
        L = m.layers(i);
        t = L.threshold;
        seecat.gui.segment(app.tmode, strcmp(t.mode, {'stat', 'p'}));
        app.tvalue.Value = t.value;
        seecat.gui.segment(app.tsign, strcmp(t.sign, signs));
        app.tk.Value = t.k;
        app.tcorr.Value = t.correction;
        app.talpha.Value = t.alpha;
        app.tcdt.Value = t.cdt_p;
        app.cmap.Value = L.colormap;
        app.alpha.Value = L.alpha;
        app.frame.Limits = [1 max(1.0001, size(L.data, 4))];
        app.frame.Value = L.frame;
        hasStat = ~isempty(L.stat.type);
        canCorrect = hasStat && ~isempty(fieldnames(L.stat.S));
        app.tcorr.Enable = onOff(canCorrect);
        app.talpha.Enable = onOff(canCorrect);
        app.tcdt.Enable = onOff(canCorrect);
        for h = app.tmode, h.Enable = onOff(hasStat); end
        stat = 'No statistic: thresholded on values.';
        if hasStat
            stat = sprintf('%s map, df %s.', L.stat.type, strjoin(arrayfun(@(x) sprintf('%.4g', x), L.stat.df, 'UniformOutput', false), ', '));
        end
        h = L.result.height;
        app.info.Text = sprintf('%s Height %s, extent k ≥ %d.', stat, ...
            strjoin(arrayfun(@(x) sprintf('%s %.3f', compare(x), abs(x)), h, 'UniformOutput', false), ' and '), t.k);
        refreshClusters();
        redraw();
    end

    function onThreshold()
        i = current();
        if isempty(i), return, end
        L = m.layers(i);
        try
            m.setThreshold(i, struct('mode', L.threshold.mode, 'value', app.tvalue.Value, ...
                'sign', L.threshold.sign, 'k', app.tk.Value, 'correction', app.tcorr.Value, ...
                'alpha', app.talpha.Value, 'cdt_p', app.tcdt.Value));
        catch err
            uialert(fig, err.message, 'Threshold');
        end
        showLayer();
    end

    function setMode(mode)
        i = current();
        if isempty(i), return, end
        if ~strcmp(m.layers(i).threshold.mode, mode)
            m.layers(i).threshold.mode = mode;
            if strcmp(mode, 'p')
                app.tvalue.Value = 0.001;
            else
                s = m.layers(i).stat;
                app.tvalue.Value = round(spm_u(0.001, s.df, s.type), 2);
            end
        end
        onThreshold();
    end

    function setSign(s)
        i = current();
        if isempty(i), return, end
        m.layers(i).threshold.sign = s;
        onThreshold();
    end

    function setLayer(f, v)
        i = current();
        if isempty(i), return, end
        m.layers(i).(f) = v;
        redraw();
    end

    function onFrame(k)
        i = current();
        if isempty(i), return, end
        m.setFrame(i, round(k));
        showLayer();
    end

    function onAdd()
        [f, p] = uigetfile({'*.nii;*.nii.gz', 'NIfTI images'}, 'Add a layer', 'MultiSelect', 'on');
        figure(fig);
        if isequal(f, 0), return, end
        for f1 = cellstr(f)
            try
                m.addLayer(fullfile(p, f1{1}));
            catch err
                uialert(fig, err.message, 'Add layer');
                return
            end
        end
        app.underlay.Value = m.underlay.name;
        refreshList(numel(m.layers));
        openDrawer(true);
    end

    function onRemove()
        i = current();
        if isempty(i), return, end
        m.removeLayer(i);
        refreshList(max(1, i - 1));
    end

    % ---- display ----------------------------------------------------------
    function onUnderlay()
        v = app.underlay.Value;
        if strcmp(v, 'Other…')
            [f, p] = uigetfile({'*.nii;*.nii.gz', 'NIfTI images'}, 'Underlay image');
            figure(fig);
            if isequal(f, 0), app.underlay.Value = m.underlay.name; return, end
            v = fullfile(p, f);
        end
        m.setUnderlay(v);
        redraw();
    end

    function setRadio(v)
        m.radiological = v;
        seecat.gui.segment(ori, [~v, v]);
        redraw();
    end

    function setLayout(name)
        st.layout = name;
        seecat.gui.segment(lay, strcmp(name, {'orthogonal', 'single', 'mosaic'}));
        if strcmp(name, 'orthogonal')
            area.ColumnWidth = {'1x', '1x'};
            area.RowHeight = {'1x', '1x'};
            place(app.ax.sagittal, 1, 1);
            place(app.ax.coronal, 1, 2);
            place(app.ax.axial, 2, 1);
            place(info, 2, 2);
            app.ax.main.Visible = 'off';
            app.ax.main.Layout.Row = 1;
            app.ax.main.Layout.Column = 1;
        else
            area.ColumnWidth = {220, '1x'};
            area.RowHeight = {'1x', '1x', '1x', 190};
            for k2 = 1:3
                place(app.ax.(names{k2}), k2, 1);
            end
            place(info, 4, 1);
            app.ax.main.Visible = 'on';
            app.ax.main.Layout.Row = [1 4];
            app.ax.main.Layout.Column = 2;
        end
        redraw();
    end

    function place(h, r, c)
        h.Layout.Row = r;
        h.Layout.Column = c;
    end

    % ---- cursor -----------------------------------------------------------
    function onCoord()
        m.cursor = [app.coord.Value];
        redraw();
    end

    function onPeak()
        i = current();
        if isempty(i), return, end
        L = m.layers(i);
        [~, k] = max(abs(L.shown(:)));
        if isempty(k) || L.shown(k) == 0, return, end
        [a, b2, c] = ind2sub(size(L.shown), k);
        m.cursor = (L.hdr.mat(1:3, :) * [a; b2; c; 1])';
        redraw();
    end

    function onClick(view, ax)
        cp = ax.CurrentPoint(1, 1:2);
        if ax == app.ax.main
            if strcmp(st.layout, 'mosaic'), return, end
            view = st.view;
        elseif ~strcmp(st.layout, 'orthogonal')
            st.view = view;                       % a thumbnail picks the large view
        end
        m.cursor = m.mmAt(view, cp);
        redraw();
    end

    % ---- clusters ---------------------------------------------------------
    function refreshClusters()
        i = current();
        C = table();
        if ~isempty(i)
            C = m.clusters(i);
        end
        st.clusters = C;
        if isempty(C)
            app.table.Data = table();
            app.clText.Text = 'No suprathreshold clusters';
            return
        end
        D = C;
        D.cluster = (1:height(C))';               % numbered by size, as in the read-out
        D.peak = cellstr(compose('%.2f', D.peak));
        D.label = regexprep(D.label, '^Neuromorphometrics: ', '');
        D.Properties.VariableNames = {'#', 'Voxels', 'Peak', 'x (mm)', 'y (mm)', 'z (mm)', 'Label'};
        app.table.Data = D;
        app.table.ColumnWidth = {44, 70, 70, 70, 70, 70, max(200, fig.Position(3) - 420)};
        L = m.layers(i);
        app.clText.Text = sprintf('%d cluster(s), %d voxels  ·  %s', height(C), sum(C.voxels), correctionText(L));
    end

    function goRow(e)
        if isempty(e.Indices) || isempty(st.clusters), return, end
        r = e.Indices(1);
        C = st.clusters;
        m.cursor = [C.x(r) C.y(r) C.z(r)];
        redraw();
    end

    function saveTable()
        if isempty(st.clusters), return, end
        [f, p] = uiputfile('*.tsv', 'Save cluster table', 'clusters.tsv');
        figure(fig);
        if isequal(f, 0), return, end
        seecat.io.write_tsv(st.clusters, fullfile(p, f));
    end

    function toggleDrawer()
        openDrawer(root.RowHeight{3} < 40);
    end

    function openDrawer(on)
        if on
            root.RowHeight{3} = 190;
            app.fold.Icon = seecat.gui.icon('chevron-down');
        else
            root.RowHeight{3} = 31;
            app.fold.Icon = seecat.gui.icon('chevron-up');
        end
    end

    % ---- surface and export -----------------------------------------------
    function onSurface()
        i = current();
        if isempty(i), return, end
        try
            seecat.view.surface(m, i);
        catch err
            uialert(fig, err.message, 'BrainNet Viewer');
        end
    end

    function onExport()
        [f, p] = uiputfile('*.png', 'Save image', 'seecat_view.png');
        figure(fig);
        if isequal(f, 0), return, end
        imwrite(currentImage(), fullfile(p, f));
    end

    function onSave()
        i = current();
        if isempty(i), return, end
        [f, p] = uiputfile('*.nii.gz', 'Save thresholded map', [m.layers(i).name '_thresholded.nii.gz']);
        figure(fig);
        if isequal(f, 0), return, end
        m.saveShown(i, fullfile(p, f));
    end

    function img = currentImage()
        switch st.layout
            case 'mosaic'
                img = m.montage(st.view, 12, 4);
            case 'single'
                img = m.slice(st.view);
            otherwise
                parts = cellfun(@(v) m.slice(v), names, 'UniformOutput', false);
                h = max(cellfun(@(p) size(p, 1), parts));
                for k2 = 1:3
                    parts{k2}(end+1:h, :, :) = 0;
                end
                img = cat(2, parts{:});
        end
    end

    % ---- drawing ----------------------------------------------------------
    function redraw()
        c = m.cursor;
        for k2 = 1:3
            app.coord(k2).Value = c(k2);
        end
        for k2 = 1:3
            v = names{k2};
            drawView(app.ax.(v), v, ~strcmp(st.layout, 'orthogonal'));
        end
        if strcmp(st.layout, 'single')
            drawView(app.ax.main, st.view, false);
        elseif strcmp(st.layout, 'mosaic')
            ax = app.ax.main;
            cla(ax);
            image(ax, m.montage(st.view, 12, 4));
            axis(ax, 'image', 'off');
        end
        readOut();
        colourBar();
    end

    function drawView(ax, v, thumb)
        cla(ax);
        [rgb, pos] = m.slice(v);
        im = image(ax, rgb);
        axis(ax, 'image', 'off');
        hold(ax, 'on');
        col = T.cursor;
        line(ax, [0.5 size(rgb, 2) + 0.5], pos([2 2]), 'Color', col, 'LineWidth', 0.5, 'HitTest', 'off');
        line(ax, pos([1 1]), [0.5 size(rgb, 1) + 0.5], 'Color', col, 'LineWidth', 0.5, 'HitTest', 'off');
        idx = struct('sagittal', 1, 'coronal', 2, 'axial', 3).(v);
        tag = sprintf('%s  %s = %.0f', [upper(v(1)) v(2:end)], axisName(idx), m.cursor(idx));
        tagColour = T.muted;
        if thumb
            tag = [upper(v(1)) v(2:end)];
            if strcmp(v, st.view)
                tagColour = [0.45 0.6 1];        % the view shown large
            end
        end
        text(ax, 4, 4, tag, 'Color', tagColour, 'FontSize', 10, 'FontName', T.font, ...
            'VerticalAlignment', 'top', 'HitTest', 'off');
        if ~strcmp(v, 'sagittal') && ~thumb
            lr = {'L', 'R'};
            if m.radiological, lr = fliplr(lr); end
            text(ax, 4, size(rgb, 1) / 2, lr{1}, 'Color', T.muted, 'FontSize', 10, 'HitTest', 'off');
            text(ax, size(rgb, 2) - 4, size(rgb, 1) / 2, lr{2}, 'Color', T.muted, 'FontSize', 10, ...
                'HorizontalAlignment', 'right', 'HitTest', 'off');
        end
        hold(ax, 'off');
        im.ButtonDownFcn = @(~, ~) onClick(v, ax);
    end

    function readOut()
        c = m.cursor;
        vox = round(m.grid.mat \ [c(:); 1]);
        lines = repmat({''}, 1, 7);
        lines{1} = sprintf('MNI    %4.0f %4.0f %4.0f', c);
        lines{2} = sprintf('voxel  %4d %4d %4d', vox(1:3));
        vals = m.valuesAt();
        i = current();
        if ~isempty(i)
            L = m.layers(i);
            s = L.stat;
            lines{3} = sprintf('value  %.3f', vals(i));
            if ~isempty(s.type) && isfinite(vals(i))
                lines{4} = sprintf('p      %s (1-sided)', pText(vals(i), s));
            end
        end
        lab = m.labelAt(c);
        parts = strsplit(lab, '; ');
        if ~isempty(lab)
            first = regexp(parts{1}, '^(.*?): (.*)$', 'tokens', 'once');
            if ~isempty(first)
                lines{5} = first{2};
                lines{6} = first{1};
            else
                lines{5} = parts{1};
            end
        end
        lines{7} = clusterAt(c);
        for k2 = 1:7
            app.read(k2).Text = lines{k2};
        end
        app.read(5).Tooltip = lab;
    end

    function s = clusterAt(c)
        s = '';
        C = st.clusters;
        i = current();
        if isempty(C) || isempty(i), return, end
        L = m.layers(i);
        vox = round(L.hdr.mat \ [c(:); 1]);
        if any(vox(1:3)' < 1 | vox(1:3)' > size(L.shown, 1:3)) || L.shown(vox(1), vox(2), vox(3)) == 0
            return
        end
        lab = spm_bwlabel(double(L.shown ~= 0), 18);
        id = lab(vox(1), vox(2), vox(3));
        for r = 1:height(C)                       % the row whose peak lies in this cluster
            pk = round(L.hdr.mat \ [C.x(r); C.y(r); C.z(r); 1]);
            if lab(pk(1), pk(2), pk(3)) == id
                s = sprintf('cluster %d  ·  %d voxels', r, C.voxels(r));
                return
            end
        end
    end

    function colourBar()
        i = current();
        if isempty(i) || isempty(m.layers(i).range)
            app.cbImg.Visible = 'off';
            app.cbLo.Text = '';
            app.cbHi.Text = '';
            app.cbText.Text = '';
            return
        end
        L = m.layers(i);
        app.cbImg.Visible = 'on';
        hasNeg = any(L.shown(:) < 0);
        hasPos = any(L.shown(:) > 0);
        app.cbImg.ImageSource = colourBarImage(L, hasPos, hasNeg);
        r = L.range;
        app.cbLo.Text = sprintf('%.2f', r(1));
        if hasNeg && hasPos
            app.cbLo.Text = sprintf('-%.2f', r(2));
        elseif hasNeg
            app.cbLo.Text = sprintf('-%.2f', r(2));
            r = -fliplr(r);
        end
        app.cbHi.Text = sprintf('%.2f', r(2));
        if hasNeg && ~hasPos
            app.cbHi.Text = sprintf('%.2f', r(2));
        end
        app.cbText.Text = sprintf('%s  ·  %s', shortName(L.name), correctionText(L));
    end
end

%% ---- local functions --------------------------------------------------------
function ax = viewAxes(parent)
T = seecat.gui.theme();
ax = uiaxes(parent, 'Color', T.canvas, 'XColor', 'none', 'YColor', 'none', 'Toolbar', [], ...
    'BackgroundColor', T.canvas);
disableDefaultInteractivity(ax);
end

function h = caption(parent, text, colour)
h = uilabel(parent, 'Text', text, 'FontColor', colour, 'FontSize', 10, 'FontWeight', 'bold');
end

function img = colourBarImage(L, hasPos, hasNeg)
t = linspace(0, 1, 128);
if strcmp(L.colormap, 'auto')
    pos = [ones(128, 1), t', zeros(128, 1)];
    neg = [zeros(128, 1), t', ones(128, 1)];
else
    pos = feval(L.colormap, 128);
    neg = pos;
end
if hasPos && hasNeg
    row = [flipud(neg); zeros(16, 3); pos];
elseif hasNeg
    row = flipud(neg);
else
    row = pos;
end
img = repmat(reshape(row, 1, [], 3), 8, 1, 1);
end

function s = pText(v, s0)
switch s0.type
    case 'T'
        p = spm_Tcdf(-v, s0.df(end));
    case 'F'
        p = 1 - spm_Fcdf(v, s0.df);
    otherwise
        p = spm_Ncdf(-v);
end
s = sprintf('%.2g', p);
end

function s = correctionText(L)
t = L.threshold;
switch t.correction
    case 'none'
        if strcmp(t.mode, 'p') && ~isempty(L.stat.type)
            s = sprintf('p < %g uncorrected', t.value);
        else
            s = sprintf('|value| ≥ %.3g', t.value);
        end
    case 'cluster_fwe'
        s = sprintf('cluster FWE p < %g (CDT p < %g)', t.alpha, t.cdt_p);
    case 'voxel_fwe'
        s = sprintf('voxel FWE p < %g', t.alpha);
    case 'voxel_fdr'
        s = sprintf('voxel FDR q < %g', t.alpha);
end
end

function s = compare(x)
if x < 0
    s = '≤ −';
else
    s = '≥';
end
end

function c = axisName(k)
c = 'xyz';
c = c(k);
end

function s = onOff(b)
if b, s = 'on'; else, s = 'off'; end
end

function n = shortName(n)
n = regexprep(n, '^(sub-[^_]+_)?', '');
if numel(n) > 34
    n = [n(1:31) '...'];
end
end
