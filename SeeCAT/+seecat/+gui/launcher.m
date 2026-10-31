function app = launcher()
% LAUNCHER  The SeeCAT main window (design gui.md, section 2).
%   seecat.gui.launcher        % or simply: SeeCAT
%
% Side bar with the pipelines; for the selected one a header with section
% links, its form (from seecat.<p>.gui) as cards in one scrolling column, a
% right-hand column with help on the option being edited and the run
% status, and a log drawer at the bottom. Run starts the pipeline in a
% separate MATLAB process (seecat.gui.runner) and follows its log.

T = seecat.gui.theme();
pages = struct( ...
    'name', {'DICOM to BIDS', 'Preprocessing', 'fMRIPrep denoising', 'Seed FC', 'Degree', 'Statistics', 'Viewer', 'QC reports'}, ...
    'pipe', {'', 'prep', 'fmriprep', 'fc', 'degree', 'stat', '', ''}, ...
    'icon', {'dicom', 'sliders', 'filter', 'target', 'network', 'stat', 'brain', 'report'}, ...
    'group', {'PREPARE', 'PREPARE', 'PREPARE', 'ANALYSE', 'ANALYSE', 'ANALYSE', 'RESULTS', 'RESULTS'}, ...
    'about', {'Convert a DICOM folder to a BIDS dataset with dcm2niix.', ...
    'Slice timing, realignment, normalisation, denoising and smoothing of a raw BIDS dataset.', ...
    'Denoising and smoothing of fMRIPrep outputs, with the same steps as Preprocessing.', ...
    'Seed-based functional connectivity maps from denoised data.', ...
    'Voxel-wise degree centrality maps from denoised data.', ...
    'Group GLM with SPM inference: one- and two-sample tests, paired tests and regression.', ...
    'Slices, thresholds, clusters and surfaces of statistic maps.', ...
    'The HTML quality-control reports of a derivatives folder.'});
here = fileparts(fileparts(fileparts(mfilename('fullpath'))));   % SeeCAT/

fig = uifigure('Name', 'SeeCAT', 'Position', [60 60 1280 820], 'Color', T.border, ...
    'Icon', fullfile(here, 'resources', 'logo_64.png'));
root = uigridlayout(fig, [1 2], 'ColumnWidth', {212, '1x'}, 'Padding', [0 0 0 0], ...
    'ColumnSpacing', 1, 'BackgroundColor', T.border);
nav = uihtml(root, 'HTMLSource', fullfile(here, 'resources', 'ui', 'nav.html'), ...
    'Data', navData('Preprocessing'), 'DataChangedFcn', @(s, ~) onNav(s.Data));
main = uigridlayout(root, [3 1], 'RowHeight', {98, '1x', 31}, 'Padding', [0 0 0 0], ...
    'RowSpacing', 1, 'BackgroundColor', T.border);

% ---- header ----
head = uigridlayout(main, [3 4], 'ColumnWidth', {'1x', 170, 86, 86}, 'RowHeight', {26, 18, '1x'}, ...
    'Padding', [22 0 16 14], 'RowSpacing', 2, 'ColumnSpacing', 8, 'BackgroundColor', T.panel);
title_ = uilabel(head, 'Text', '', 'FontSize', T.size.title, 'FontWeight', 'bold', 'FontColor', T.text);
title_.Layout.Column = [1 2];
loadB = button(head, 'Load', 'folder', @(~, ~) onLoad());
saveB = button(head, 'Save', 'save', @(~, ~) onSave());
desc = uilabel(head, 'Text', '', 'FontColor', T.text2);
desc.Layout.Row = 2;
desc.Layout.Column = [1 4];
tabs = uihtml(head, 'HTMLSource', fullfile(here, 'resources', 'ui', 'tabs.html'), ...
    'DataChangedFcn', @(s, ~) onTab(s.Data));
tabs.Layout.Row = 3;
tabs.Layout.Column = 1;
adv = uicheckbox(head, 'Text', 'Show advanced options', 'FontColor', T.text2, ...
    'ValueChangedFcn', @(~, ~) rebuild());
adv.Layout.Row = 3;
adv.Layout.Column = [2 4];

% ---- body: form | help and run ----
body = uigridlayout(main, [1 2], 'ColumnWidth', {'1x', 292}, 'Padding', [0 0 0 0], ...
    'ColumnSpacing', 1, 'BackgroundColor', T.border);
host = uipanel(body, 'BorderType', 'none', 'BackgroundColor', T.page);
side = uigridlayout(body, [12 1], 'RowHeight', {16, 36, '1x', 40, 1, 16, 22, 8, 18, 34, 30, 4}, ...
    'Padding', [18 14 18 16], 'RowSpacing', 6, 'BackgroundColor', T.side);
caption(side, 'OPTION');
helpTitle = uilabel(side, 'Text', '', 'FontWeight', 'bold', 'FontColor', T.text, 'WordWrap', 'on', ...
    'VerticalAlignment', 'top');
helpText = uilabel(side, 'Text', '', 'FontColor', T.text2, 'WordWrap', 'on', 'VerticalAlignment', 'top');
helpMeta = uilabel(side, 'Text', '', 'FontColor', T.icon, 'WordWrap', 'on', 'VerticalAlignment', 'top', ...
    'FontSize', T.size.small);
uipanel(side, 'BorderType', 'none', 'BackgroundColor', T.border);
runCap = caption(side, 'RUN');
sg = uigridlayout(side, [1 3], 'ColumnWidth', {12, '1x', 60}, 'Padding', [0 0 0 0], 'ColumnSpacing', 6, ...
    'BackgroundColor', T.side);
lamp = uilamp(sg, 'Color', T.control);
statusL = uilabel(sg, 'Text', 'Ready', 'FontColor', T.text);
clockL = uilabel(sg, 'Text', '', 'FontColor', T.muted, 'HorizontalAlignment', 'right');
bar = uigridlayout(side, [1 2], 'ColumnWidth', {0, '1x'}, 'Padding', [0 0 0 0], 'ColumnSpacing', 0, ...
    'BackgroundColor', T.border);
uipanel(bar, 'BorderType', 'none', 'BackgroundColor', T.accent);
uipanel(bar, 'BorderType', 'none', 'BackgroundColor', T.border);
countL = uilabel(side, 'Text', '', 'FontColor', T.muted, 'FontSize', T.size.small);
rg = uigridlayout(side, [1 2], 'ColumnWidth', {'1x', 84}, 'Padding', [0 0 0 0], 'ColumnSpacing', 8, ...
    'BackgroundColor', T.side);
runB = uibutton(rg, 'Text', 'Run', 'Icon', seecat.gui.icon('play', '#FFFFFF'), 'FontWeight', 'bold', ...
    'BackgroundColor', T.accent, 'FontColor', [1 1 1], 'ButtonPushedFcn', @(~, ~) onRun());
stopB = button(rg, 'Stop', 'stop', @(~, ~) onStop());
stopB.Enable = 'off';
qcB = button(side, 'Open QC report', 'external', []);
qcB.Visible = 'off';
runParts = {runCap, sg, bar, countL, rg, qcB};

% ---- drawer: log | summary ----
drawer = uigridlayout(main, [2 1], 'RowHeight', {30, '1x'}, 'Padding', [0 0 0 0], 'RowSpacing', 0, ...
    'BackgroundColor', T.panel);
dh = uigridlayout(drawer, [1 6], 'ColumnWidth', {30, 64, 84, '1x', 30, 6}, 'Padding', [8 3 4 3], ...
    'ColumnSpacing', 4, 'BackgroundColor', T.panel);
fold = uibutton(dh, 'Text', '', 'Icon', seecat.gui.icon('chevron-up'), 'BackgroundColor', T.panel, ...
    'Tooltip', 'Show or hide the log', 'ButtonPushedFcn', @(~, ~) toggleDrawer());
logTab = uibutton(dh, 'Text', 'Log', 'ButtonPushedFcn', @(~, ~) showPane('log'));
sumTab = uibutton(dh, 'Text', 'Summary', 'ButtonPushedFcn', @(~, ~) showPane('summary'));
uilabel(dh, 'Text', '');
uibutton(dh, 'Text', '', 'Icon', seecat.gui.icon('copy'), 'BackgroundColor', T.panel, ...
    'Tooltip', 'Copy the log', 'ButtonPushedFcn', @(~, ~) copyLog());
pane = uigridlayout(drawer, [1 1], 'Padding', [0 0 0 0], 'BackgroundColor', T.logBg);
logBox = uitextarea(pane, 'FontName', T.mono, 'FontSize', T.size.small, ...   % editable: R2020b greys out read-only text areas
    'BackgroundColor', T.logBg, 'FontColor', T.logText, 'Value', {''});
summary = uitable(pane, 'Visible', 'off', 'RowName', {});
summary.Layout.Row = 1;
summary.Layout.Column = 1;

seecat.gui.segment([logTab, sumTab], [true false]);
state = struct('page', 'Preprocessing', 'pipe', '', 'cfg', [], 'defaults', [], 'form', [], ...
    'run', [], 'timer', [], 'help', '', 'started', [], 'units', 0, 'stale', 0);
seecat.gui.style(fig);
app.fig = fig;
app.select = @(name) select(name);
app.config = @() currentConfig();
app.scrollTo = @(name) onTab(struct('clicked', name));
app.load = @loadFile;                             % for scripts and tests
app.run = @onRun;
show();

    % ---- navigation ------------------------------------------------------
    function d = navData(selected)
        groups = unique({pages.group}, 'stable');
        g = cell(1, numel(groups));
        for i = 1:numel(groups)
            k = find(strcmp({pages.group}, groups{i}));
            its = arrayfun(@(p) struct('id', p.name, 'label', p.name, ...
                'icon', seecat.gui.icon(p.icon, T.hex.icon, 'markup'), ...
                'iconOn', seecat.gui.icon(p.icon, T.hex.accent, 'markup')), pages(k), 'UniformOutput', false);
            g{i} = struct('title', groups{i}, 'items', {its});
        end
        foot = {struct('id', 'manual', 'label', 'Manual', 'icon', seecat.gui.icon('book', T.hex.icon, 'markup')), ...
            struct('id', 'about', 'label', 'About', 'icon', seecat.gui.icon('info', T.hex.icon, 'markup'))};
        d = struct('logo', seecat.gui.icon('logo', '', 'markup'), 'version', ['version ' seecat.version()], ...
            'font', T.font, 'selected', selected, 'groups', {g}, 'footer', {foot});
    end

    function onNav(d)
        if ~isfield(d, 'clicked'), return, end
        switch d.clicked
            case 'manual'
                openManual();
            case 'about'
                uialert(fig, sprintf(['SeeCAT %s\nSeed-based Connectivity Analysis Toolbox\n\n' ...
                    'Mingrui Xia, Beijing Normal University\nLicence: GPL-3.0-or-later'], seecat.version()), ...
                    'About SeeCAT', 'Icon', fullfile(here, 'resources', 'logo_64.png'));
            otherwise
                if ~strcmp(d.clicked, state.page)
                    state.page = d.clicked;
                    show();
                end
        end
    end

    function select(name)
        state.page = name;
        nav.Data = navData(name);
        show();
    end

    function show()
        p = pages(strcmp({pages.name}, state.page));
        title_.Text = p.name;
        desc.Text = p.about;
        state.form = [];                          % its controls are deleted below
        delete(host.Children);
        host.SizeChangedFcn = '';                 % set again by seecat.gui.form
        host.Scrollable = 'off';
        state.pipe = p.pipe;
        setHelp('', '', '');
        isPipe = ~isempty(p.pipe);
        for h = [loadB, saveB, adv]
            h.Visible = onOff(isPipe);
        end
        for k = 1:numel(runParts)
            if k < numel(runParts) || ~isPipe
                runParts{k}.Visible = onOff(isPipe);
            end
        end
        if isPipe
            state.cfg = seecat.config(p.pipe);
            state.defaults = state.cfg;
            rebuild();
            return
        end
        tabs.Data = struct('font', T.font, 'sections', {{}}, 'active', '');
        switch p.name
            case 'DICOM to BIDS'
                dicomPage();
            case 'Viewer'
                viewerPage();
            case 'QC reports'
                qcPage();
        end
    end

    function rebuild()
        if isempty(state.pipe), return, end
        if ~isempty(state.form)
            try
                state.cfg = state.form.get(state.cfg);
            catch
            end
        end
        delete(host.Children);
        state.form = seecat.gui.form(host, feval(['seecat.' state.pipe '.gui']), state.cfg, adv.Value, @onHelp);
        secs = state.form.sections;
        tabs.Data = struct('font', T.font, 'sections', {secs}, 'active', secs{1});
        seecat.gui.style(host);
        drawnow;                                  % let the window settle, then fit the cards
        state.form.fit();
    end

    function onTab(d)
        if isfield(d, 'clicked') && ~isempty(state.form)
            state.form.scrollTo(d.clicked);
        end
    end

    % ---- help column -------------------------------------------------------
    function onHelp(f)
        if strcmp(state.help, f.path), return, end
        state.help = f.path;
        txt = f.help;
        if isempty(txt)
            txt = 'No further description; see the manual.';
        end
        def = seecat.gui.format(getPath(state.defaults, f.path), f.widget);
        if isempty(def)
            def = '(empty)';
        end
        setHelp(f.label, txt, sprintf('Default:  %s\nBatch:  %s', def, f.path));
    end

    function setHelp(t, txt, meta)
        if isempty(t)
            state.help = '';
            p = pages(strcmp({pages.name}, state.page));
            t = p.name;
            txt = [p.about ' Click the info icon of an option, or edit it, to see its description here.'];
            if isempty(p.pipe)
                txt = p.about;
            end
            meta = '';
        end
        helpTitle.Text = t;
        helpText.Text = txt;
        helpMeta.Text = meta;
    end

    % ---- config files ------------------------------------------------------
    function cfg = currentConfig()
        if isempty(state.form)
            error('SeeCAT:gui', 'Select a pipeline first.');
        end
        cfg = state.form.get(state.cfg);
    end

    function onLoad()
        [f, p] = uigetfile('*.json', 'Load a SeeCAT config');
        figure(fig);
        if isequal(f, 0), return, end
        loadFile(fullfile(p, f));
    end

    function loadFile(file)
        cfg = seecat.config(file);
        k = find(strcmp({pages.pipe}, cfg.pipeline), 1);
        select(pages(k).name);
        state.cfg = cfg;
        state.form = [];
        rebuild();
    end

    function onSave()
        [f, p] = uiputfile('*.json', 'Save the config', [state.pipe '_config.json']);
        figure(fig);
        if isequal(f, 0), return, end
        try
            seecat.save_config(currentConfig(), fullfile(p, f));
        catch err
            uialert(fig, err.message, 'Save config');
        end
    end

    % ---- running -----------------------------------------------------------
    function onRun()
        try
            cfg = currentConfig();
            seecat.check_config(seecat.config(cfg));
        catch err
            uialert(fig, err.message, 'Check the options');
            return
        end
        logBox.Value = {sprintf('Starting %s in a new MATLAB process ...', state.pipe)};
        summary.Data = table();
        openDrawer(true);
        showPane('log');
        qcB.Visible = 'off';
        state.run = seecat.gui.runner(cfg);
        state.started = tic;
        state.units = 0;
        state.stale = 0;
        setStatus('Running', T.running, 0, 0, 0);
        runB.Enable = 'off';
        stopB.Enable = 'on';
        state.timer = timer('ExecutionMode', 'fixedSpacing', 'Period', 1, 'TimerFcn', @(~, ~) poll());
        start(state.timer);
    end

    function poll()
        if ~isvalid(fig)
            stop(state.timer);
            delete(state.timer);
            return
        end
        t = state.run.read();
        if ~isempty(t)
            lines = splitlines(strtrim(t));
            stale = staleFolder(lines);           % MATLAB's start-up warnings about the saved path
            state.stale = state.stale + nnz(stale);
            lines = lines(~stale & ~cellfun(@isempty, lines));
            logBox.Value = [logBox.Value; lines];
            scroll(logBox, 'bottom');
        end
        [n, done, failed] = progress(logBox.Value);
        alive = state.run.running();
        if alive
            setStatus('Running', T.running, n, done, failed);
            return
        end
        stop(state.timer);
        delete(state.timer);
        runB.Enable = 'on';
        stopB.Enable = 'off';
        code = state.run.exitCode();
        if code == 0 && failed == 0
            setStatus('Finished', T.ok, n, n, failed);
        elseif code == 0
            setStatus(sprintf('Finished, %d failed', failed), T.failed, n, n, failed);
        else
            setStatus(sprintf('Stopped (exit %d)', code), T.failed, n, done, failed);
        end
        if state.stale > 0
            logBox.Value{end+1} = sprintf(['Note: MATLAB''s saved path lists %d folder(s) that no longer exist; ' ...
                'MATLAB warns about them at every start. Remove them in pathtool and save the path.'], state.stale);
            scroll(logBox, 'bottom');
        end
        showSummary(strjoin(logBox.Value, newline));
    end

    function setStatus(txt, colour, n, done, failed)
        statusL.Text = txt;
        lamp.Color = colour;
        if ~isempty(state.started)
            s = round(toc(state.started));
            clockL.Text = sprintf('%02d:%02d', floor(s / 60), mod(s, 60));
        end
        if n > 0
            bar.ColumnWidth = {sprintf('%gx', done), sprintf('%gx', n - done)};
            countL.Text = sprintf('%d of %d units  ·  %d failed', done, n, failed);
        else
            bar.ColumnWidth = {0, '1x'};
            countL.Text = '';
        end
    end

    function onStop()
        state.run.stop();
        statusL.Text = 'Stopping';
    end

    function showSummary(txt)
        out = regexp(txt, 'Output: ([^\r\n]+)', 'tokens', 'once');
        if isempty(out), return, end
        d = dir(fullfile(strtrim(out{1}), 'reports', '*_summary.tsv'));
        if isempty(d), return, end
        [~, k] = max([d.datenum]);
        summary.Data = seecat.io.read_tsv(fullfile(d(k).folder, d(k).name));
        q = dir(fullfile(strtrim(out{1}), 'reports', '*_qc.html'));
        if ~isempty(q)
            qcB.ButtonPushedFcn = @(~, ~) web(fullfile(q(1).folder, q(1).name), '-browser');
            qcB.Visible = 'on';
        end
    end

    % ---- drawer ------------------------------------------------------------
    function toggleDrawer()
        openDrawer(main.RowHeight{3} < 40);
    end

    function openDrawer(on)
        if on
            main.RowHeight{3} = 210;
            fold.Icon = seecat.gui.icon('chevron-down');
        else
            main.RowHeight{3} = 31;
            fold.Icon = seecat.gui.icon('chevron-up');
        end
    end

    function copyLog()
        clipboard('copy', strjoin(logBox.Value, newline));
    end

    function showPane(which_)
        isLog = strcmp(which_, 'log');
        seecat.gui.segment([logTab, sumTab], [isLog, ~isLog]);
        logBox.Visible = onOff(isLog);
        summary.Visible = onOff(~isLog);
        openDrawer(true);
    end

    % ---- pages without a pipeline -----------------------------------------
    function [cg, card] = pageCard(parent, titleText, rows)
        card = uigridlayout(parent, [1 1], 'Padding', [1 1 1 1], 'BackgroundColor', T.border);   % 1 px outline
        cg = uigridlayout(card, [numel(rows) + 1, 3], 'ColumnWidth', {T.label, '1x', 30}, ...
            'RowHeight', [{22}, rows], 'RowSpacing', 6, 'ColumnSpacing', 10, ...
            'Padding', [14 12 12 10], 'BackgroundColor', T.panel);
        h = uilabel(cg, 'Text', titleText, 'FontSize', T.size.card, 'FontWeight', 'bold', 'FontColor', T.text);
        h.Layout.Column = [1 3];
    end

    function g = pageGrid(heights)
        g = uigridlayout(host, [numel(heights) + 1, 1], 'RowHeight', [num2cell(heights), {'1x'}], ...
            'Padding', [16 14 16 14], 'RowSpacing', 12, 'BackgroundColor', T.page);
    end

    function dicomPage()
        g = pageGrid(22 + 5 * T.row + 6 * 6 + 34 + 24);
        cg = pageCard(g, 'Conversion', [repmat({T.row}, 1, 5), {32}]);
        lab = {'DICOM folder', 'BIDS folder', 'Subject', 'Session', 'Rules (JSON)'};
        kinds = {'folder', 'folder', '', '', 'file'};
        ed = gobjects(1, 5);
        for i = 1:5
            uilabel(cg, 'Text', lab{i}, 'FontColor', T.text2);
            ed(i) = uieditfield(cg, 'text', 'BackgroundColor', T.panel, 'FontColor', T.text);
            if isempty(kinds{i})
                uilabel(cg, 'Text', '');
            else
                kind = kinds{i};
                uibutton(cg, 'Text', '', 'Icon', seecat.gui.icon('folder'), 'BackgroundColor', T.panel, ...
                    'ButtonPushedFcn', @(~, ~) pick(ed(i), kind));
            end
        end
        b2 = uigridlayout(cg, [1 2], 'ColumnWidth', {140, '1x'}, 'Padding', [0 0 0 0], 'BackgroundColor', T.panel);
        b2.Layout.Row = 7;
        b2.Layout.Column = 2;
        uibutton(b2, 'Text', 'Convert', 'Icon', seecat.gui.icon('play', '#FFFFFF'), 'FontWeight', 'bold', ...
            'BackgroundColor', T.accent, 'FontColor', [1 1 1], 'ButtonPushedFcn', @(~, ~) convert(ed));
        seecat.gui.style(fig);
    end

    function convert(ed)
        args = {'sub', ed(3).Value, 'ses', ed(4).Value};
        if ~isempty(ed(5).Value)
            args = [args, {'rules', ed(5).Value}];
        end
        d = uiprogressdlg(fig, 'Title', 'DICOM to BIDS', 'Indeterminate', 'on');
        try
            R = seecat.bids.from_dicom(ed(1).Value, ed(2).Value, args{:});
            close(d);
            summary.Data = R;
            logBox.Value = {sprintf('%d image(s), %d copied into %s', height(R), nnz(~cellfun(@isempty, R.bids)), ed(2).Value)};
            showPane('summary');
        catch err
            close(d);
            uialert(fig, err.message, 'DICOM to BIDS');
        end
    end

    function viewerPage()
        g = pageGrid(22 + 40 + 32 + 6 * 2 + 24);
        cg = pageCard(g, 'Viewer', {40, 32});
        t = uilabel(cg, 'Text', ['Orthogonal, single and mosaic views; thresholds by value or p with voxel ' ...
            'or cluster FWE and FDR; cluster tables with atlas labels; BrainNet Viewer surfaces.'], ...
            'FontColor', T.text2, 'WordWrap', 'on');
        t.Layout.Column = [1 3];
        bg = uigridlayout(cg, [1 3], 'ColumnWidth', {150, 150, '1x'}, 'Padding', [0 0 0 0], ...
            'ColumnSpacing', 8, 'BackgroundColor', T.panel);
        bg.Layout.Row = 3;
        bg.Layout.Column = [1 3];
        uibutton(bg, 'Text', 'Open a map', 'Icon', seecat.gui.icon('folder', '#FFFFFF'), 'FontWeight', 'bold', ...
            'BackgroundColor', T.accent, 'FontColor', [1 1 1], 'ButtonPushedFcn', @(~, ~) openMap());
        button(bg, 'Empty viewer', 'brain', @(~, ~) seecat.viewer());
        seecat.gui.style(fig);
    end

    function openMap()
        [f, p] = uigetfile({'*.nii;*.nii.gz', 'NIfTI images'}, 'Open a map');
        figure(fig);
        if isequal(f, 0), return, end
        seecat.viewer(fullfile(p, f));
    end

    function qcPage()
        g = pageGrid(22 + T.row + 180 + 32 + 6 * 3 + 24);
        cg = pageCard(g, 'Reports', {T.row, 180, 32});
        uilabel(cg, 'Text', 'Derivatives folder', 'FontColor', T.text2);
        ed = uieditfield(cg, 'text', 'BackgroundColor', T.panel, 'FontColor', T.text, ...
            'ValueChangedFcn', @(~, ~) listQc());
        uibutton(cg, 'Text', '', 'Icon', seecat.gui.icon('folder'), 'BackgroundColor', T.panel, ...
            'ButtonPushedFcn', @(~, ~) pickAndList());
        lb = uilistbox(cg, 'Items', {}, 'FontColor', T.text);
        lb.Layout.Row = 3;
        lb.Layout.Column = 2;
        holder = uigridlayout(cg, [1 2], 'ColumnWidth', {150, '1x'}, 'Padding', [0 0 0 0], 'BackgroundColor', T.panel);
        holder.Layout.Row = 4;
        holder.Layout.Column = 2;
        button(holder, 'Open report', 'external', @(~, ~) openQc());
        seecat.gui.style(fig);

        function pickAndList()
            pick(ed, 'folder');
            listQc();
        end
        function listQc()
            q = dir(fullfile(ed.Value, 'reports', '*_qc.html'));
            lb.Items = {q.name};
            lb.ItemsData = fullfile({q.folder}, {q.name});
            if isempty(q)
                lb.Items = {'No reports/*_qc.html in this folder'};
                lb.ItemsData = {''};
            end
        end
        function openQc()
            if ~isempty(lb.Value)
                web(lb.Value, '-browser');
            end
        end
    end

    function pick(c, kind)
        if strcmp(kind, 'folder')
            p = uigetdir();
            if ~isequal(p, 0), c.Value = p; end
        else
            [f, p] = uigetfile('*.json');
            if ~isequal(f, 0), c.Value = fullfile(p, f); end
        end
        figure(fig);
    end

    function openManual()
        f = fullfile(fileparts(here), 'Doc', 'manual', 'index.html');
        if exist(f, 'file')
            web(f, '-browser');
        else
            web('https://www.nitrc.org/projects/seecat', '-browser');
        end
    end

    % ---- small helpers -----------------------------------------------------
    function b = button(parent, text, iconName, fn)
        b = uibutton(parent, 'Text', text, 'Icon', seecat.gui.icon(iconName), 'BackgroundColor', T.panel, ...
            'FontColor', T.text2);
        if ~isempty(fn)
            b.ButtonPushedFcn = fn;
        end
    end

    function h = caption(parent, text)
        h = uilabel(parent, 'Text', text, 'FontColor', T.muted, 'FontSize', T.size.small - 1, 'FontWeight', 'bold');
    end
end

function [n, done, failed] = progress(lines)
% Units in the run and how many have finished, from seecat.run's log
txt = strjoin(lines, newline);
tok = regexp(txt, '(\d+) unit\(s\)', 'tokens', 'once');
n = 0;
if ~isempty(tok)
    n = str2double(tok{1});
end
stamp = '\d{4}-\d\d-\d\d \d\d:\d\d:\d\d  ';
ok = numel(regexp(txt, ['^' stamp '\[[^\]]+\] finished (\(|on )'], 'start', 'lineanchors'));   % '[unit] finished ...'
failed = numel(regexp(txt, ['^' stamp '\[[^\]]+\] FAILED: '], 'start', 'lineanchors'));
done = min(n, ok + failed);
end

function tf = staleFolder(lines)
% Lines of MATLAB's warning that a folder on the saved path does not exist
% (English and Chinese MATLAB), including the indented "In ..." trace lines
tf = contains(lines, {'nonexistent or not a directory', '名称不存在或不是目录'});
end

function v = getPath(s, p)
for k = strsplit(p, '.')
    s = s.(k{1});
end
v = s;
end

function s = onOff(b)
if b, s = 'on'; else, s = 'off'; end
end
