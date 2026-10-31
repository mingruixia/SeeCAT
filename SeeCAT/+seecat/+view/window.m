function app = window(m)
% WINDOW  The viewer window for a seecat.view.Model (uifigure, G1).
%   app = seecat.view.window(model)
%
% Three orthogonal views (or a montage), a layer list and, for the selected
% layer, threshold, correction, colour and transparency. Clicking a view
% moves the cursor. All logic lives in the model; this file only draws and
% forwards user actions. Use seecat.viewer to open files.

app.model = m;
fig = uifigure('Name', 'SeeCAT Viewer', 'Position', [80 80 1320 760], 'Color', [0.08 0.08 0.1]);
app.fig = fig;
g = uigridlayout(fig, [2 2], 'ColumnWidth', {'1x', 330}, 'RowHeight', {'1x', 96}, ...
    'BackgroundColor', [0.08 0.08 0.1], 'Padding', [8 8 8 8]);

% ---- views ----
vg = uigridlayout(g, [1 3], 'Padding', [0 0 0 0], 'ColumnSpacing', 4, 'BackgroundColor', 'k');
vg.Layout.Row = 1;
vg.Layout.Column = 1;
names = {'sagittal', 'coronal', 'axial'};
for k = 1:3
    ax = uiaxes(vg, 'Color', 'k', 'XColor', 'none', 'YColor', 'none', 'Toolbar', []);
    disableDefaultInteractivity(ax);
    app.ax.(names{k}) = ax;
end

% ---- status bar ----
sb = uigridlayout(g, [2 8], 'ColumnWidth', {30, 70, 30, 70, 30, 70, 160, '1x'}, ...
    'RowHeight', {28, '1x'}, 'BackgroundColor', [0.08 0.08 0.1], 'Padding', [0 0 0 0]);
sb.Layout.Row = 2;
sb.Layout.Column = 1;
lbl = {'x', 'y', 'z'};
for k = 1:3
    uilabel(sb, 'Text', lbl{k}, 'FontColor', [0.8 0.8 0.85], 'HorizontalAlignment', 'right');
    app.coord(k) = uieditfield(sb, 'numeric', 'ValueDisplayFormat', '%.0f', ...
        'ValueChangedFcn', @(~, ~) onCoord());
end
app.mode = uidropdown(sb, 'Items', {'Orthogonal', 'Montage axial', 'Montage coronal', 'Montage sagittal'}, ...
    'ValueChangedFcn', @(~, ~) redraw());
app.values = uilabel(sb, 'Text', '', 'FontColor', [0.9 0.9 0.95]);
app.label = uilabel(sb, 'Text', '', 'FontColor', [0.75 0.8 0.9], 'WordWrap', 'on');
app.label.Layout.Row = 2;
app.label.Layout.Column = [1 8];

% ---- controls ----
cg = uigridlayout(g, [19 2], 'ColumnWidth', {110, '1x'}, 'RowHeight', repmat({26}, 1, 19), ...
    'BackgroundColor', [0.13 0.13 0.16], 'Scrollable', 'on');
cg.Layout.Row = [1 2];
cg.Layout.Column = 2;
lab = @(t) uilabel(cg, 'Text', t, 'FontColor', [0.85 0.85 0.9]);
app.layers = uilistbox(cg, 'Items', {}, 'ValueChangedFcn', @(~, ~) showLayer());
app.layers.Layout.Row = [1 3];
app.layers.Layout.Column = [1 2];
b = uibutton(cg, 'Text', 'Add layer…', 'ButtonPushedFcn', @(~, ~) onAdd());
b.Layout.Row = 4; b.Layout.Column = 1;
b = uibutton(cg, 'Text', 'Remove', 'ButtonPushedFcn', @(~, ~) onRemove());
b.Layout.Row = 4; b.Layout.Column = 2;
lab('Underlay');
app.underlay = uidropdown(cg, 'Items', {'ch2', 'ch2better', 'mni2009c', 'avg152T1', 'single_subj_T1', 'Other…'}, ...
    'Value', m.underlay.name, 'ValueChangedFcn', @(~, ~) onUnderlay());
lab('Display');
app.radio = uicheckbox(cg, 'Text', 'Radiological (left on right)', 'FontColor', [0.85 0.85 0.9], ...
    'ValueChangedFcn', @(s, ~) setRadio(s.Value));
lab('Threshold by');
app.tmode = uidropdown(cg, 'Items', {'stat', 'p'}, 'ValueChangedFcn', @(~, ~) onThreshold());
lab('Value');
app.tvalue = uieditfield(cg, 'numeric', 'ValueChangedFcn', @(~, ~) onThreshold());
lab('Sign');
app.tsign = uidropdown(cg, 'Items', {'both', 'pos', 'neg'}, 'ValueChangedFcn', @(~, ~) onThreshold());
lab('Min. cluster (vox)');
app.tk = uispinner(cg, 'Limits', [0 Inf], 'ValueChangedFcn', @(~, ~) onThreshold());
lab('Correction');
app.tcorr = uidropdown(cg, 'Items', {'none', 'cluster_fwe', 'voxel_fwe', 'voxel_fdr'}, 'ValueChangedFcn', @(~, ~) onThreshold());
lab('Alpha / CDT p');
ag = uigridlayout(cg, [1 2], 'Padding', [0 0 0 0], 'BackgroundColor', [0.13 0.13 0.16]);
app.talpha = uieditfield(ag, 'numeric', 'Value', 0.05, 'ValueChangedFcn', @(~, ~) onThreshold());
app.tcdt = uieditfield(ag, 'numeric', 'Value', 0.001, 'ValueChangedFcn', @(~, ~) onThreshold());
lab('Colormap');
app.cmap = uidropdown(cg, 'Items', {'auto', 'hot', 'winter', 'parula', 'jet', 'gray'}, ...
    'ValueChangedFcn', @(s, ~) setLayer('colormap', s.Value));
lab('Opacity');
app.alpha = uislider(cg, 'Limits', [0 1], 'Value', 1, 'ValueChangedFcn', @(s, ~) setLayer('alpha', s.Value));
lab('Volume');
app.frame = uispinner(cg, 'Limits', [1 1], 'ValueChangedFcn', @(s, ~) onFrame(s.Value));
app.info = uilabel(cg, 'Text', '', 'FontColor', [0.7 0.75 0.85], 'WordWrap', 'on');
app.info.Layout.Row = 16;
app.info.Layout.Column = [1 2];
b = uibutton(cg, 'Text', 'Clusters…', 'ButtonPushedFcn', @(~, ~) onClusters());
b.Layout.Row = 17; b.Layout.Column = 1;
app.surface = uibutton(cg, 'Text', 'Surface (BrainNet)…', 'ButtonPushedFcn', @(~, ~) onSurface());
app.surface.Layout.Row = 17; app.surface.Layout.Column = 2;
if isempty(which('BrainNetViewer'))
    app.surface.Enable = 'off';
    app.surface.Tooltip = 'Needs BrainNet Viewer 2.0 on the MATLAB path (nitrc.org/projects/bnv)';
end
b = uibutton(cg, 'Text', 'Export PNG…', 'ButtonPushedFcn', @(~, ~) onExport());
b.Layout.Row = 18; b.Layout.Column = 1;
b = uibutton(cg, 'Text', 'Save map…', 'ButtonPushedFcn', @(~, ~) onSave());
b.Layout.Row = 18; b.Layout.Column = 2;

refreshList();
redraw();

    % ---- callbacks ----------------------------------------------------------
    function i = current()
        i = find(strcmp(app.layers.Items, app.layers.Value), 1);
    end

    function refreshList()
        items = {m.layers.name};
        app.layers.Items = items;
        if ~isempty(items) && (isempty(app.layers.Value) || ~ismember(app.layers.Value, items))
            app.layers.Value = items{end};
        end
        showLayer();
    end

    function showLayer()
        i = current();
        if isempty(i), return, end
        L = m.layers(i);
        t = L.threshold;
        app.tmode.Value = t.mode;
        app.tvalue.Value = t.value;
        app.tsign.Value = t.sign;
        app.tk.Value = t.k;
        app.tcorr.Value = t.correction;
        app.talpha.Value = t.alpha;
        app.tcdt.Value = t.cdt_p;
        app.cmap.Value = L.colormap;
        app.alpha.Value = L.alpha;
        app.frame.Limits = [1 max(1.0001, size(L.data, 4))];
        app.frame.Value = L.frame;
        stat = 'no statistic (threshold on values)';
        if ~isempty(L.stat.type)
            stat = sprintf('%s map, df %s', L.stat.type, mat2str(round(L.stat.df, 1)));
        end
        app.info.Text = sprintf('%s. Height: %s', stat, mat2str(round(L.result.height, 3)));
        hasStat = ~isempty(L.stat.type);
        app.tcorr.Enable = onOff(hasStat && ~isempty(fieldnames(L.stat.S)));
        app.tmode.Enable = onOff(hasStat);
    end

    function onThreshold()
        i = current();
        if isempty(i), return, end
        try
            m.setThreshold(i, struct('mode', app.tmode.Value, 'value', app.tvalue.Value, ...
                'sign', app.tsign.Value, 'k', app.tk.Value, 'correction', app.tcorr.Value, ...
                'alpha', app.talpha.Value, 'cdt_p', app.tcdt.Value));
        catch err
            uialert(fig, err.message, 'Threshold');
        end
        showLayer();
        redraw();
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
        redraw();
    end

    function onAdd()
        [f, p] = uigetfile({'*.nii;*.nii.gz', 'NIfTI images'}, 'Add a layer');
        figure(fig);
        if isequal(f, 0), return, end
        try
            m.addLayer(fullfile(p, f));
        catch err
            uialert(fig, err.message, 'Add layer');
            return
        end
        refreshList();
        redraw();
    end

    function onRemove()
        i = current();
        if isempty(i), return, end
        m.removeLayer(i);
        app.layers.Value = {};
        refreshList();
        redraw();
    end

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
        redraw();
    end

    function onCoord()
        m.cursor = [app.coord.Value];
        redraw();
    end

    function onClick(view, ax)
        cp = ax.CurrentPoint(1, 1:2);
        if startsWith(app.mode.Value, 'Montage'), return, end
        m.cursor = m.mmAt(view, cp);
        redraw();
    end

    function onClusters()
        i = current();
        if isempty(i), return, end
        T = m.clusters(i);
        f2 = uifigure('Name', ['Clusters: ' m.layers(i).name], 'Position', [140 140 820 360]);
        gl = uigridlayout(f2, [2 1], 'RowHeight', {'1x', 28});
        tb = uitable(gl, 'Data', T, 'CellSelectionCallback', @(s, e) goRow(T, e));
        tb.ColumnWidth = {60, 60, 70, 50, 50, 50, 'auto'};
        uibutton(gl, 'Text', 'Save table…', 'ButtonPushedFcn', @(~, ~) saveTable(T));
    end

    function goRow(T, e)
        if isempty(e.Indices), return, end
        r = e.Indices(1);
        m.cursor = [T.x(r) T.y(r) T.z(r)];
        redraw();
    end

    function saveTable(T)
        [f, p] = uiputfile('*.tsv', 'Save cluster table', 'clusters.tsv');
        if isequal(f, 0), return, end
        seecat.io.write_tsv(T, fullfile(p, f));
    end

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
        [f, p] = uiputfile('*.png', 'Export view', 'seecat_view.png');
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
        if startsWith(app.mode.Value, 'Montage')
            img = m.montage(lower(strtrim(erase(app.mode.Value, 'Montage'))), 8);
        else
            parts = cellfun(@(v) m.slice(v), names, 'UniformOutput', false);
            h = max(cellfun(@(p) size(p, 1), parts));
            for k2 = 1:3
                parts{k2}(end+1:h, :, :) = 0;
            end
            img = cat(2, parts{:});
        end
    end

    function redraw()
        c = m.cursor;
        for k2 = 1:3
            app.coord(k2).Value = c(k2);
        end
        v = m.valuesAt();
        txt = {};
        for k2 = 1:numel(m.layers)
            txt{end+1} = sprintf('%s = %.3g', shortName(m.layers(k2).name), v(k2)); %#ok<AGROW>
        end
        app.values.Text = strjoin(txt, '   ');
        app.label.Text = m.labelAt(c);
        montage = startsWith(app.mode.Value, 'Montage');
        for k2 = 1:3
            ax = app.ax.(names{k2});
            cla(ax);
            if montage
                if k2 == 1
                    image(ax, m.montage(lower(strtrim(erase(app.mode.Value, 'Montage'))), 8));
                    axis(ax, 'image', 'off');
                end
                ax.Visible = onOff(k2 == 1);
                ax.Layout.Column = 1;
                continue
            end
            ax.Visible = 'on';
            [rgb, pos] = m.slice(names{k2});
            im = image(ax, rgb);
            axis(ax, 'image', 'off');
            hold(ax, 'on');
            xline(ax, pos(1), 'Color', [0.2 0.9 0.3], 'Alpha', 0.6, 'HitTest', 'off');
            yline(ax, pos(2), 'Color', [0.2 0.9 0.3], 'Alpha', 0.6, 'HitTest', 'off');
            hold(ax, 'off');
            view_ = names{k2};
            im.ButtonDownFcn = @(~, ~) onClick(view_, ax);
        end
        if montage
            app.ax.sagittal.Layout.Column = [1 3];
        else
            for k2 = 1:3
                app.ax.(names{k2}).Layout.Column = k2;
            end
        end
    end
end

function s = onOff(b)
if b, s = 'on'; else, s = 'off'; end
end

function n = shortName(n)
n = regexprep(n, '^(sub-[^_]+_)?', '');
if numel(n) > 28
    n = [n(1:25) '...'];
end
end
