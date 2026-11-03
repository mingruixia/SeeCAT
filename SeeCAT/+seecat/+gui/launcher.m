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
    'name', {'DICOM to BIDS', 'Preprocessing', 'fMRIPrep denoising', 'Seed FC', 'Degree', 'Statistics', 'Viewer', ...
    'Data check', 'QC reports'}, ...
    'pipe', {'', 'prep', 'fmriprep', 'fc', 'degree', 'stat', '', '', ''}, ...
    'icon', {'dicom', 'sliders', 'filter', 'target', 'network', 'stat', 'brain', 'activity', 'report'}, ...
    'group', {'PREPARE', 'PREPARE', 'PREPARE', 'ANALYSE', 'ANALYSE', 'ANALYSE', 'RESULTS', 'RESULTS', 'RESULTS'}, ...
    'about', {'Convert DICOM folders to a BIDS dataset with dcm2niix: one subject, or a folder of subjects.', ...
    'Slice timing, realignment, normalisation, denoising and smoothing of a raw BIDS dataset.', ...
    'Denoising and smoothing of fMRIPrep outputs, with the same steps as Preprocessing.', ...
    'Seed-based functional connectivity maps from denoised data.', ...
    'Voxel-wise degree centrality maps from denoised data.', ...
    'Group GLM with SPM inference: one- and two-sample tests, paired tests and regression.', ...
    'Slices, thresholds, clusters and surfaces of statistic maps.', ...
    'Volumes, TR and head motion of every BOLD run; open a run to step through its volumes.', ...
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
    'run', [], 'timer', [], 'help', '', 'started', [], 'units', 0, 'stale', 0, 'output', '');
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
            case 'Data check'
                dataPage();
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
            if isempty(p.pipe) && ~strcmp(p.name, 'DICOM to BIDS')
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
        state.output = strtrim(out{1});              % offered by the Data check page
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
        g = pageGrid(22 + 5 * T.row + 32 + 6 * 6 + 24);
        cg = pageCard(g, 'Conversion', [repmat({T.row}, 1, 5), {32}]);
        H = dicomHelp();
        kinds = {'folder', 'folder', '', '', 'file'};
        hint = {'', '', 'Empty: found automatically', 'Empty: one per scanning visit', 'Empty: T1w and resting BOLD'};
        ed = gobjects(1, 5);
        for i = 1:5
            uilabel(cg, 'Text', H(i).label, 'FontColor', T.text2, 'Tooltip', H(i).tip);
            parent = cg;
            if ~isempty(kinds{i})
                parent = uigridlayout(cg, [1 2], 'ColumnWidth', {'1x', 30}, 'Padding', [0 0 0 0], ...
                    'ColumnSpacing', 6, 'BackgroundColor', T.panel);
            end
            k = i;
            ed(i) = uieditfield(parent, 'text', 'BackgroundColor', T.panel, 'FontColor', T.text, ...
                'Tooltip', H(i).tip, 'ValueChangingFcn', @(~, ~) dicomInfo(H(k)), ...
                'ValueChangedFcn', @(~, ~) dicomInfo(H(k)));
            ed(i).Placeholder = hint{i};
            if ~isempty(kinds{i})
                kind = kinds{i};
                uibutton(parent, 'Text', '', 'Icon', seecat.gui.icon('folder'), 'BackgroundColor', T.panel, ...
                    'Tooltip', 'Browse', 'ButtonPushedFcn', @(~, ~) pick(ed(k), kind));
            end
            uiimage(cg, 'ImageSource', seecat.gui.icon('info', T.hex.muted), 'Tooltip', 'About this option', ...
                'ImageClickedFcn', @(~, ~) dicomInfo(H(k)));
        end
        b2 = uigridlayout(cg, [1 3], 'ColumnWidth', {140, 150, '1x'}, 'Padding', [0 0 0 0], ...
            'ColumnSpacing', 8, 'BackgroundColor', T.panel);
        b2.Layout.Row = 7;
        b2.Layout.Column = 2;
        uibutton(b2, 'Text', 'Convert', 'Icon', seecat.gui.icon('play', '#FFFFFF'), 'FontWeight', 'bold', ...
            'BackgroundColor', T.accent, 'FontColor', [1 1 1], 'ButtonPushedFcn', @(~, ~) convert(ed));
        sb = button(b2, 'Find subjects', 'refresh', @(~, ~) scanDicom(ed));
        sb.Tooltip = 'List the subjects SeeCAT finds in the DICOM folder, without converting';
        seecat.gui.style(fig);
    end

    function dicomInfo(h)
        if strcmp(state.help, ['dicom:' h.label]), return, end
        setHelp(h.label, h.text, sprintf('Default:  %s\nBatch:  %s', h.default, h.batch));
        state.help = ['dicom:' h.label];
    end

    function scanDicom(ed)
        if ~isempty(strtrim(ed(3).Value))
            logBox.Value = {sprintf('Subject is set: everything in the DICOM folder becomes sub-%s.', ...
                strtrim(ed(3).Value))};
            showPane('log');
            return
        end
        d = uiprogressdlg(fig, 'Title', 'DICOM to BIDS', 'Message', 'Reading DICOM headers ...', ...
            'Indeterminate', 'on');
        try
            [S, ~, info] = seecat.bids.scan_dicom(ed(1).Value);
        catch err
            close(d);
            uialert(fig, err.message, 'Find subjects');
            return
        end
        close(d);
        msg = {info.layout};
        for k = 1:height(S)
            msg{end+1} = sprintf('sub-%s  <-  %s   (PatientID %s; %d folder(s), %d file(s), %d study/studies)', ...
                S.subject{k}, S.source{k}, S.patient_id{k}, S.folders(k), S.files(k), S.studies(k)); %#ok<AGROW>
        end
        for k = 1:numel(info.ignored)
            msg{end+1} = sprintf('skipped, no DICOM files: %s', info.ignored{k}); %#ok<AGROW>
        end
        msg{end+1} = 'Convert uses these subjects. To change a label, convert that folder alone with Subject set.';
        logBox.Value = msg;
        summary.Data = S;
        showPane('log');
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
            subs = unique(R.subject);
            bad = unique(R.subject(isnan(R.series) & cellfun(@isempty, R.description)));
            msg = {sprintf('%d subject(s), %d image(s), %d copied into %s', numel(subs), height(R), ...
                nnz(~cellfun(@isempty, R.bids)), ed(2).Value)};
            for k = 1:numel(bad)
                msg{end+1} = sprintf('sub-%s failed: %s', bad{k}, R.note{strcmp(R.subject, bad{k})}); %#ok<AGROW>
            end
            logBox.Value = msg;
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

    function dataPage()
        g = uigridlayout(host, [1 1], 'Padding', [16 14 16 14], 'BackgroundColor', T.page);
        cg = pageCard(g, 'Runs', {T.row, T.row, '1x', 18, 32});
        uilabel(cg, 'Text', 'Folder', 'FontColor', T.text2);
        ed = uieditfield(cg, 'text', 'Value', state.output, 'BackgroundColor', T.panel, 'FontColor', T.text, ...
            'Tooltip', 'A BIDS dataset or a derivatives folder (SeeCAT or fMRIPrep)', 'ValueChangedFcn', @(~, ~) scan());
        uibutton(cg, 'Text', '', 'Icon', seecat.gui.icon('folder'), 'BackgroundColor', T.panel, 'Tooltip', 'Browse', ...
            'ButtonPushedFcn', @(~, ~) pickAndScan());
        uilabel(cg, 'Text', 'Series', 'FontColor', T.text2);
        sg2 = uigridlayout(cg, [1 3], 'ColumnWidth', {220, 90, '1x'}, 'Padding', [0 0 0 0], 'ColumnSpacing', 8, ...
            'BackgroundColor', T.panel);
        dd = uidropdown(sg2, 'Items', {'Preprocessed (desc-preproc)', 'Denoised (desc-denoised)', 'Raw (BIDS dataset)', ...
            'All BOLD images'}, 'ItemsData', {'preproc', 'denoised', 'raw', 'all'}, 'BackgroundColor', T.panel, ...
            'FontColor', T.text, 'ValueChangedFcn', @(~, ~) scan());
        button(sg2, 'Scan', 'refresh', @(~, ~) scan());
        found = uilabel(sg2, 'Text', '', 'FontColor', T.muted);
        tb = uitable(cg, 'RowName', {}, 'CellSelectionCallback', @(~, e) pickRow(e));
        tb.Layout.Row = 4;
        tb.Layout.Column = [1 3];
        note = uilabel(cg, 'Text', ['Highlighted: mean FD above 0.25 mm, or more than 20% of the volumes flagged ' ...
            'for motion. FD and flags come from each run''s confounds table.'], 'FontColor', T.icon, ...
            'FontSize', T.size.small);
        note.Layout.Row = 5;
        note.Layout.Column = [1 3];
        bg = uigridlayout(cg, [1 3], 'ColumnWidth', {160, 130, '1x'}, 'Padding', [0 0 0 0], 'ColumnSpacing', 8, ...
            'BackgroundColor', T.panel);
        bg.Layout.Row = 6;
        bg.Layout.Column = [1 3];
        uibutton(bg, 'Text', 'Open in viewer', 'Icon', seecat.gui.icon('activity', '#FFFFFF'), 'FontWeight', 'bold', ...
            'BackgroundColor', T.accent, 'FontColor', [1 1 1], 'Tooltip', 'Step through the volumes of the selected run', ...
            'ButtonPushedFcn', @(~, ~) openRun());
        button(bg, 'QC report', 'external', @(~, ~) openReport());
        seecat.gui.style(fig);
        R = table();
        row = [];
        if ~isempty(ed.Value)
            drawnow;
            scan();
        end

        function pickAndScan()
            pick(ed, 'folder');
            scan();
        end
        function scan()
            R = table();
            row = [];
            tb.Data = table();
            removeStyle(tb);
            found.Text = '';
            if isempty(ed.Value), return, end
            d = uiprogressdlg(fig, 'Title', 'Data check', 'Message', 'Reading headers and confounds tables ...', ...
                'Indeterminate', 'on');
            try
                R = seecat.qc.runs(ed.Value, dd.Value);
            catch err
                close(d);
                uialert(fig, err.message, 'Data check');
                return
            end
            close(d);
            if isempty(R)
                found.Text = 'No BOLD images of this kind in the folder';
                return
            end
            pct = compose('%d (%.0f%%)', R.flagged, R.flagged_pct);
            pct(isnan(R.flagged)) = {'–'};
            run = regexprep(R.run, '_(space|res|den|desc)-[a-zA-Z0-9]+', '');   % the same for every row
            tb.Data = table(run, R.volumes, num(R.tr, '%.3g'), num(R.mean_fd, '%.3f'), num(R.max_fd, '%.2f'), ...
                cellstr(pct), 'VariableNames', {'Run', 'Volumes', 'TR (s)', 'Mean FD (mm)', 'Max FD (mm)', 'Flagged'});
            tb.ColumnWidth = {'auto', 76, 70, 110, 110, 110};
            if any(R.flag)
                addStyle(tb, uistyle('BackgroundColor', [1 0.93 0.93], 'FontColor', T.failed), 'row', find(R.flag));
            end
            found.Text = sprintf('%d of %d highlighted', nnz(R.flag), height(R));
        end
        function pickRow(e)
            if ~isempty(e.Indices)
                row = e.Indices(1);
            end
        end
        function ok = chosen()
            if isempty(row) && height(R) == 1
                row = 1;
            end
            ok = ~isempty(row);
            if ~ok
                uialert(fig, 'Select a run in the table first.', 'Data check', 'Icon', 'info');
            end
        end
        function openRun()
            if ~chosen(), return, end
            d = uiprogressdlg(fig, 'Title', 'Data check', 'Message', ['Loading ' R.run{row} ' ...'], ...
                'Indeterminate', 'on');
            try
                seecat.viewer(R.file{row});
            catch err
                uialert(fig, err.message, 'Open in viewer');
            end
            close(d);
        end
        function openReport()
            if ~chosen(), return, end
            id = regexprep(R.run{row}, '_(space|res|den|desc)-[a-zA-Z0-9]+', '');
            sub = regexp(id, 'sub-([a-zA-Z0-9]+)', 'tokens', 'once');
            f = '';
            if ~isempty(sub)
                f = fullfile(ed.Value, ['sub-' sub{1}], [id '_desc-qc_report.html']);
            end
            if exist(f, 'file')
                web(f, '-browser');
            else
                uialert(fig, ['No QC report for this run. The Preprocessing and fMRIPrep denoising ' ...
                    'pipelines write one per run.'], 'QC report', 'Icon', 'info');
            end
        end
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

function H = dicomHelp()
% Help for the DICOM to BIDS fields: side column text, tooltip, default and
% the matching seecat.bids.from_dicom argument
H = struct('label', {}, 'tip', {}, 'text', {}, 'default', {}, 'batch', {});
H(1).label = 'DICOM folder';
H(1).tip = 'One subject''s DICOM files, or a folder with one folder per subject';
H(1).text = sprintf(['The folder with the DICOM files, arranged in any common way. Subjects ' ...
    'come from the PatientID in the headers, or from the folder tree when IDs are removed; ' ...
    'Find subjects lists them before converting. Files such as .txt, .csv and .nii are not read.\n\n' ...
    'Examples\n' ...
    '  S_001/, S_002/  ->  sub-S001, sub-S002\n' ...
    '  S_001/visit1/T1/  ->  sub-S001\n' ...
    '  T1/S_001/, REST/S_001/  ->  sub-S001']);
H(1).default = '(required)';
H(1).batch = 'from_dicom(dicom_dir, bids_dir)';

H(2).label = 'BIDS folder';
H(2).tip = 'The BIDS dataset to write into (created if missing)';
H(2).text = sprintf(['The BIDS dataset to write into; created if missing. Images go to ' ...
    'sub-<label>/[ses-<label>/]anat, func, ... as .nii.gz with a .json sidecar. ' ...
    'dataset_description.json is written if missing and participants.tsv gets new subjects. ' ...
    'Existing images are not replaced: converting them again stops with an error.\n\n' ...
    'Example\n' ...
    '  D:/data/mystudy  ->  D:/data/mystudy/sub-S001/anat/sub-S001_T1w.nii.gz\n\n' ...
    'A table of every series and where it went is written to code/seecat/.']);
H(2).default = '(required)';
H(2).batch = 'from_dicom(dicom_dir, bids_dir)';

H(3).label = 'Subject';
H(3).tip = 'Label without "sub-", letters and digits. Empty: each folder in the DICOM folder is a subject';
H(3).text = sprintf(['The participant label, without "sub-": letters and digits only.\n\n' ...
    'Given: everything in the DICOM folder is this subject.\n' ...
    'Empty: SeeCAT finds the subjects (Find subjects lists them). Files of one PatientID are ' ...
    'one subject, named after the folder that holds all of them and no one else''s, with other ' ...
    'characters removed; a single person is named after the DICOM folder. Without usable IDs ' ...
    'the folder tree decides. A subject that fails is reported and the others still convert.\n\n' ...
    'Examples\n' ...
    '  01  ->  sub-01\n' ...
    '  empty, folder S_001  ->  sub-S001\n' ...
    '  empty, T1/Pat-12a and REST/Pat-12a  ->  sub-Pat12a']);
H(3).default = '(empty: from folder names)';
H(3).batch = '''sub'', ''01''';

H(4).label = 'Session';
H(4).tip = 'Label without "ses-". Empty: no session folder for one visit, ses-1, ses-2, ... for several';
H(4).text = sprintf(['The session label, without "ses-": letters and digits only.\n\n' ...
    'Given: every image goes into this session; series with the same name get run-1, run-2.\n' ...
    'Empty: a subject scanned in one visit (one DICOM study) gets no session folder. Several ' ...
    'visits become ses-1, ses-2, ... by scan date. Converting a visit again keeps its session, ' ...
    'and a later visit gets the next number (recorded in code/seecat/from_dicom_sessions.tsv). ' ...
    'A subject already converted without a session needs a label for a new visit.\n\n' ...
    'Examples\n' ...
    '  pre  ->  sub-01/ses-pre/\n' ...
    '  empty, two visits  ->  ses-1/, ses-2/\n' ...
    '  empty, one visit  ->  sub-01/anat/']);
H(4).default = '(empty: from the scan dates)';
H(4).batch = '''ses'', ''pre''';

H(5).label = 'Rules (JSON)';
H(5).tip = 'Naming rules (seecat.bids.dicom_rules)';
H(5).text = sprintf(['A JSON file of rules that name the series. Each rule matches sidecar fields ' ...
    '(regular expressions, case-insensitive) and gives datatype, suffix and entities; the first ' ...
    'rule that matches wins. Series that match no rule are listed in the summary, not copied.\n\n' ...
    'Empty: a 3D T1w (MPRAGE, SPGR, BRAVO, ...) and resting BOLD (rest, rsfMRI).\n\n' ...
    'Example\n' ...
    '  [{"match": {"SeriesDescription": "rest"},\n' ...
    '    "datatype": "func", "suffix": "bold",\n' ...
    '    "entities": {"task": "rest"}}]']);
H(5).default = '(empty: T1w and resting BOLD)';
H(5).batch = '''rules'', ''my_rules.json''';
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

function c = num(x, f)
% Numbers as text for a table, '–' for NaN
c = cellstr(compose(f, x));
c(isnan(x)) = {'–'};
end
