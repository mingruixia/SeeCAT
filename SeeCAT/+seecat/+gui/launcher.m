function app = launcher()
% LAUNCHER  The SeeCAT main window (design gui.md, section 2).
%   seecat.gui.launcher        % or simply: SeeCAT
%
% Pipelines on the left; the selected pipeline's form on the right (from
% seecat.<p>.gui), with Load/Save config (the JSON files seecat.run reads)
% and Run, which starts the pipeline in a separate MATLAB process and shows
% its log, then the summary with links to the QC pages.

items = {'DICOM to BIDS', 'Preprocessing', 'fMRIPrep denoising', 'Seed FC', 'Degree', 'Statistics', 'Viewer', 'QC reports'};
pipes = {'', 'prep', 'fmriprep', 'fc', 'degree', 'stat', '', ''};
fig = uifigure('Name', sprintf('SeeCAT %s', seecat.version()), 'Position', [60 60 1180 800]);
g = uigridlayout(fig, [1 2], 'ColumnWidth', {190, '1x'});
nav = uilistbox(g, 'Items', items, 'ValueChangedFcn', @(~, ~) show());
right = uigridlayout(g, [5 1], 'RowHeight', {30, '1x', 32, 150, 0});
title_ = uilabel(right, 'Text', '', 'FontSize', 16, 'FontWeight', 'bold');
body = uipanel(right, 'BorderType', 'none');
bar = uigridlayout(right, [1 7], 'ColumnWidth', {150, '1x', 90, 110, 110, 80, 70}, 'Padding', [0 0 0 0]);
adv = uicheckbox(bar, 'Text', 'Advanced options', 'ValueChangedFcn', @(~, ~) rebuild());
status = uilabel(bar, 'Text', '');
help_ = uibutton(bar, 'Text', 'Help', 'ButtonPushedFcn', @(~, ~) showHelp());
loadB = uibutton(bar, 'Text', 'Load config…', 'ButtonPushedFcn', @(~, ~) onLoad());
saveB = uibutton(bar, 'Text', 'Save config…', 'ButtonPushedFcn', @(~, ~) onSave());
runB = uibutton(bar, 'Text', 'Run', 'FontWeight', 'bold', 'ButtonPushedFcn', @(~, ~) onRun());
stopB = uibutton(bar, 'Text', 'Stop', 'Enable', 'off', 'ButtonPushedFcn', @(~, ~) onStop());
logBox = uitextarea(right, 'Editable', 'off', 'FontName', 'Consolas', 'Value', {''});
summary = uitable(right);

state = struct('pipe', '', 'cfg', [], 'form', [], 'run', [], 'timer', []);
app.fig = fig;
app.select = @(name) select(name);
app.config = @() currentConfig();
nav.Value = 'Preprocessing';
show();

    function select(name)
        nav.Value = name;
        show();
    end

    function show()
        k = find(strcmp(items, nav.Value));
        title_.Text = nav.Value;
        state.form = [];                          % its controls are deleted below
        delete(body.Children);
        right.RowHeight{5} = 0;
        state.pipe = pipes{k};
        if ~isempty(state.pipe)
            state.cfg = seecat.config(state.pipe);
            rebuild();
            setRun(true);
            return
        end
        setRun(false);
        switch nav.Value
            case 'DICOM to BIDS'
                dicomPanel();
            case 'Viewer'
                b = uibutton(body, 'Text', 'Open the viewer', 'Position', [20 20 200 34], ...
                    'ButtonPushedFcn', @(~, ~) seecat.viewer());
                b.Position(2) = body.Position(4) - 60;
            case 'QC reports'
                qcPanel();
        end
    end

    function setRun(on)
        for h = [runB, saveB, loadB, adv]
            h.Enable = onOff(on);
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
        delete(body.Children);
        state.form = seecat.gui.form(body, feval(['seecat.' state.pipe '.gui']), state.cfg, adv.Value);
    end

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
        cfg = seecat.config(fullfile(p, f));
        k = find(strcmp(pipes, cfg.pipeline), 1);
        nav.Value = items{k};
        show();
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

    function onRun()
        try
            cfg = currentConfig();
            seecat.check_config(seecat.config(cfg));
        catch err
            uialert(fig, err.message, 'Check the options');
            return
        end
        logBox.Value = {sprintf('Starting %s ...', state.pipe)};
        summary.Data = table();
        state.run = seecat.gui.runner(cfg);
        runB.Enable = 'off';
        stopB.Enable = 'on';
        status.Text = 'running';
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
            logBox.Value = [logBox.Value; lines(~cellfun(@isempty, lines))];
            scroll(logBox, 'bottom');
        end
        if ~state.run.running()
            stop(state.timer);
            delete(state.timer);
            runB.Enable = 'on';
            stopB.Enable = 'off';
            status.Text = sprintf('finished (exit %d)', state.run.exitCode());
            showSummary(strjoin(logBox.Value, newline));
        end
    end

    function onStop()
        state.run.stop();
        status.Text = 'stopping';
    end

    function showSummary(txt)
        out = regexp(txt, 'Output: ([^\r\n]+)', 'tokens', 'once');
        if isempty(out), return, end
        d = dir(fullfile(strtrim(out{1}), 'reports', '*_summary.tsv'));
        if isempty(d), return, end
        [~, k] = max([d.datenum]);
        T = seecat.io.read_tsv(fullfile(d(k).folder, d(k).name));
        summary.Data = T;
        q = dir(fullfile(strtrim(out{1}), 'reports', '*_qc.html'));
        if ~isempty(q)
            right.RowHeight{5} = 30;
            b = uibutton(right, 'Text', 'Open QC report', 'ButtonPushedFcn', ...
                @(~, ~) web(fullfile(q(1).folder, q(1).name), '-browser'));
            b.Layout.Row = 5;
        end
    end

    function showHelp()
        if isempty(state.pipe), return, end
        doc_ = help(['seecat.' state.pipe '.defaults']);
        uialert(fig, doc_, ['Help: ' nav.Value], 'Icon', 'info');
    end

    function dicomPanel()
        gl = uigridlayout(body, [7 3], 'ColumnWidth', {170, '1x', 70}, 'RowHeight', repmat({26}, 1, 7));
        lab = {'DICOM folder', 'BIDS folder', 'Subject', 'Session', 'Rules (JSON)'};
        ed = gobjects(1, 5);
        for i = 1:5
            uilabel(gl, 'Text', lab{i});
            ed(i) = uieditfield(gl, 'text');
            if any(i == [1 2 5])
                kind = 'folder';
                if i == 5, kind = 'file'; end
                uibutton(gl, 'Text', '…', 'ButtonPushedFcn', @(~, ~) pick(ed(i), kind));
            else
                uilabel(gl, 'Text', '');
            end
        end
        b = uibutton(gl, 'Text', 'Convert', 'FontWeight', 'bold', 'ButtonPushedFcn', @(~, ~) convert(ed));
        b.Layout.Row = 6;
        b.Layout.Column = 2;
    end

    function convert(ed)
        args = {'sub', ed(3).Value, 'ses', ed(4).Value};
        if ~isempty(ed(5).Value)
            args = [args, {'rules', ed(5).Value}];
        end
        d = uiprogressdlg(fig, 'Title', 'DICOM to BIDS', 'Indeterminate', 'on');
        try
            T = seecat.bids.from_dicom(ed(1).Value, ed(2).Value, args{:});
            close(d);
            summary.Data = T;
            logBox.Value = {sprintf('%d image(s), %d copied into %s', height(T), nnz(~cellfun(@isempty, T.bids)), ed(2).Value)};
        catch err
            close(d);
            uialert(fig, err.message, 'DICOM to BIDS');
        end
    end

    function qcPanel()
        gl = uigridlayout(body, [3 3], 'ColumnWidth', {170, '1x', 70}, 'RowHeight', {26, 26, '1x'});
        uilabel(gl, 'Text', 'Derivatives folder');
        ed = uieditfield(gl, 'text');
        uibutton(gl, 'Text', '…', 'ButtonPushedFcn', @(~, ~) pick(ed, 'folder'));
        b = uibutton(gl, 'Text', 'Open', 'ButtonPushedFcn', @(~, ~) openQc(ed.Value));
        b.Layout.Row = 2;
        b.Layout.Column = 2;
    end

    function openQc(d)
        q = dir(fullfile(d, 'reports', '*_qc.html'));
        if isempty(q)
            uialert(fig, 'No QC report in this folder (reports/*_qc.html).', 'QC reports');
            return
        end
        for k = 1:numel(q)
            web(fullfile(q(k).folder, q(k).name), '-browser');
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
end

function s = onOff(b)
if b, s = 'on'; else, s = 'off'; end
end
