function make_shots(which)
% MAKE_SHOTS  Screenshots of the manual, from the worked examples.
%   make_shots            % all
%   make_shots('viewer')  % one group: window, pages, run, qc, viewer
%
% Needs a desktop session (windows are captured from the screen and checked
% against exportapp),
% the example outputs in D:/data/test_seecat/DIDA/manual_run (run_examples.m) and SPM on the path. Images go to Doc/manual/images.
if nargin < 1, which = 'all'; end
here = fileparts(mfilename('fullpath'));
repo = fileparts(fileparts(fileparts(here)));
addpath(fullfile(repo, 'SeeCAT'));
img = fullfile(fileparts(here), 'images');
if ~exist(img, 'dir'), mkdir(img); end
run = 'D:/data/test_seecat/DIDA/manual_run';
D = fullfile(run, 'derivatives', 'seecat');
cfgs = fullfile(run, 'configs');
pos = [40 40 1480 940];

if any(strcmp(which, {'all', 'pages'}))
    app = SeeCAT();
    app.fig.Position = pos;
    settle(app.fig);
    app.load(fullfile(cfgs, 'prep.json'));
    settle(app.fig);
    shot(app.fig, fullfile(img, 'main_window.png'));
    clickInfo(app.fig, 'Parallel workers');
    settle(app.fig);
    shot(app.fig, fullfile(img, 'help_panel.png'));
    app.scrollTo('Preprocessing');
    settle(app.fig);
    clickInfo(app.fig, 'Slice timing');           % the help column matches the page
    settle(app.fig);
    shot(app.fig, fullfile(img, 'prep_page.png'));
    app.select('fMRIPrep denoising');
    settle(app.fig);
    app.scrollTo('Input');                        % from the top of the page
    settle(app.fig);
    shot(app.fig, fullfile(img, 'fmriprep_page.png'));
    pages = {'fc.json', 'fc_page.png'; 'degree.json', 'degree_page.png'; 'gradient.json', 'gradient_page.png'; ...
        'harmonize_1.json', 'harmonize_page.png'; 'stat_onesample.json', 'stat_page.png'};
    for k = 1:size(pages, 1)
        app.load(fullfile(cfgs, pages{k, 1}));
        settle(app.fig);
        if strcmp(pages{k, 1}, 'gradient.json'), clickInfo(app.fig, 'Node size (mm)'); end
        if strcmp(pages{k, 1}, 'harmonize_1.json'), clickInfo(app.fig, 'Method'); end
        if strcmp(pages{k, 1}, 'stat_onesample.json'), clickInfo(app.fig, 'Correction'); end
        settle(app.fig);
        app.scrollTo('Input');
        settle(app.fig);
        shot(app.fig, fullfile(img, pages{k, 2}));
    end
    % DICOM to BIDS: Find subjects on the DICOM test folder
    app.select('DICOM to BIDS');
    settle(app.fig);
    e1 = byTip(app.fig, 'One subject');
    e1.Value = 'D:/data/test_seecat/dicom';
    e2 = byTip(app.fig, 'The BIDS dataset to write');
    e2.Value = 'D:/data/test_seecat/bids_example';
    b = findall(app.fig, 'Type', 'uibutton', 'Text', 'Find subjects');
    b.ButtonPushedFcn(b, []);
    settle(app.fig);
    shot(app.fig, fullfile(img, 'dicom_page.png'));
    % Data check on the raw dataset (the DICOM page's log hidden)
    app.select('Data check');
    settle(app.fig);
    closeDrawer(app.fig);
    dd = findall(app.fig, 'Type', 'uidropdown');
    dd = dd(arrayfun(@(d) any(strcmp(d.ItemsData, 'raw')), dd));
    dd.Value = 'raw';
    ed = byTip(app.fig, 'A BIDS dataset or a derivatives folder');
    ed.Value = 'D:/data/test_seecat/DIDA/bids2';
    ed.ValueChangedFcn(ed, []);
    settle(app.fig);
    closeDrawer(app.fig);
    settle(app.fig);
    shot(app.fig, fullfile(img, 'data_check.png'));
    % QC reports page
    app.select('QC reports');
    settle(app.fig);
    ed = byTip(app.fig, 'The output folder of Preprocessing');
    ed.Value = D;
    ed.ValueChangedFcn(ed, []);
    settle(app.fig);
    closeDrawer(app.fig);
    settle(app.fig);
    shot(app.fig, fullfile(img, 'qc_page.png'));
    delete(app.fig);
end

if any(strcmp(which, {'all', 'run'}))
    % A finished run: Seed FC with Overwrite, so every unit runs
    app = SeeCAT();
    app.fig.Position = pos;
    settle(app.fig);
    c = seecat.config(fullfile(cfgs, 'fc.json'));
    c.overwrite = true;
    c.n_workers = 'auto';
    f = fullfile(tempdir, 'fc_shot.json');
    seecat.save_config(c, f);
    app.load(f);
    settle(app.fig);
    app.run();
    t = tic;
    while toc(t) < 900
        pause(3);
        L = findall(app.fig, 'Type', 'uilabel');
        if any(ismember({L.Text}, {'Finished', 'Failed'}))
            break
        end
    end
    pause(4);
    settle(app.fig);
    b = findall(app.fig, 'Type', 'uibutton', 'Text', 'Summary');   % the summary table, as the caption says
    b(1).ButtonPushedFcn(b(1), []);
    settle(app.fig);
    shot(app.fig, fullfile(img, 'run_finished.png'));
    delete(app.fig);
end

if any(strcmp(which, {'all', 'viewer'}))
    g = fullfile(D, 'group', 'PCConeSampleHC');
    v = seecat.viewer(fullfile(g, 'PCConeSampleHC_contrast-pos_stat-t_statmap.nii.gz'));
    v.fig.Position = pos;
    settle(v.fig);
    m = v.model;
    m.setThreshold(1, struct('mode', 'p', 'value', 0.001, 'correction', 'cluster_fwe', 'alpha', 0.05, 'cdt_p', 0.001));
    m.cursor = [0 -53 26];
    v.refresh();
    settle(v.fig);
    shot(v.fig, fullfile(img, 'viewer_ortho.png'));
    b = findall(v.fig, 'Type', 'uibutton', 'Text', 'Mosaic');
    b.ButtonPushedFcn(b, []);
    settle(v.fig);
    shot(v.fig, fullfile(img, 'viewer_mosaic.png'));
    delete(v.fig);
    gr = dir(fullfile(D, 'group', 'gradients*', '*_desc-grad1_reference.nii*'));
    v = seecat.viewer(fullfile(gr(1).folder, gr(1).name));
    v.fig.Position = pos;
    settle(v.fig);
    b = findall(v.fig, 'Type', 'uibutton', 'Text', 'Mosaic');
    b.ButtonPushedFcn(b, []);
    settle(v.fig);
    shot(v.fig, fullfile(img, 'viewer_gradient.png'));
    delete(v.fig);
end
end

function settle(f)
drawnow;
pause(2.5);
figure(f);
drawnow;
pause(1.5);
end

function shot(f, file)
% Screen capture of the window at the screen's full resolution (2x on a
% scaled display), with the window kept on top while it is taken. The
% capture is checked against the window's own content (exportapp): if
% another window got in the way, the exportapp image (1x) is saved instead
% and a warning says so.
figure(f);
old = f.WindowStyle;
f.WindowStyle = 'alwaysontop';
c = onCleanup(@() set(f, 'WindowStyle', old));
drawnow;
pause(1.5);
ref = [tempname '.png'];
exportapp(f, ref);
R = imread(ref);
delete(ref);
r = java.awt.Robot;
sz = java.awt.Toolkit.getDefaultToolkit.getScreenSize;
im = r.createScreenCapture(java.awt.Rectangle(0, 0, sz.width, sz.height));
w = im.getWidth; h = im.getHeight;
px = typecast(int32(im.getRGB(0, 0, w, h, [], 0, w)), 'uint8');
px = reshape(px, 4, w, h);
rgb = permute(px([3 2 1], :, :), [3 2 1]);
s = get(0, 'ScreenSize');
k = w / s(3);
p = f.Position;                                   % inner area (no title bar), as exportapp
above = s(4) - (p(2) + p(4) - 1);               % screen rows above the window
rows = max(1, round(k * above) + 1):min(h, round(k * (above + p(4))));
cols = max(1, round(k * (p(1) - 1)) + 1):min(w, round(k * (p(1) - 1 + p(3))));
C = rgb(rows, cols, :);
% compare with the exportapp image in 16-pixel blocks (a shift of a pixel
% or two does not matter, another window in front does)
a = blocks(double(mean(C, 3)), 16 * k);
b = blocks(double(mean(R, 3)), 16);
n = min(numel(a), numel(b));
cc = corrcoef(a(1:n), b(1:n));
if size(C, 1) > 10 && cc(2) > 0.9
    imwrite(C, file);
else
    warning('make_shots:capture', '%s: the screen did not show the window (r = %.2f); saved the 1x exportapp image.', file, cc(2));
    imwrite(R, file);
end
fprintf('%s\n', file);
end

function clickInfo(fig, labelText)
% Click the info icon on the row of the option labelled LABELTEXT
L = findall(fig, 'Type', 'uilabel', 'Text', labelText);
if isempty(L), return, end
L = L(1);
im = findall(L.Parent, 'Type', 'uiimage', 'Tooltip', 'About this option');
for i = 1:numel(im)
    if isequal(im(i).Layout.Row, L.Layout.Row)
        im(i).ImageClickedFcn(im(i), []);
        return
    end
end
end

function e = byTip(fig, prefix)
% The edit field whose tooltip starts with PREFIX
e = findall(fig, 'Type', 'uieditfield');
e = e(arrayfun(@(x) startsWith(x.Tooltip, prefix), e));
e = e(1);
end

function v = blocks(x, b)
% Means of b x b blocks, as a column
b = round(b);
m = floor(size(x, 1) / b);
n = floor(size(x, 2) / b);
x = x(1:m * b, 1:n * b);
v = reshape(mean(mean(reshape(x, b, m, b, n), 1), 3), [], 1);
end

function closeDrawer(fig)
% Hide the log drawer if it is open
b = findall(fig, 'Type', 'uibutton', 'Tooltip', 'Show or hide the log');
if isempty(b), return, end
g = b(1).Parent;
while ~isempty(g) && ~(isa(g, 'matlab.ui.container.GridLayout') && numel(g.RowHeight) >= 3 && isnumeric(g.RowHeight{3}))
    g = g.Parent;
end
if ~isempty(g) && g.RowHeight{3} >= 40
    b(1).ButtonPushedFcn(b(1), []);
    drawnow;
end
end
