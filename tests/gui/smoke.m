function smoke(outDir, statMap, series)
% SMOKE  Open every SeeCAT window and save screenshots (needs a desktop
% session; -batch cannot draw windows). exportapp leaves out the uihtml
% parts (side bar, section links); check those on screen.
%   smoke('C:/tmp/shots', 'group/x/x_contrast-pos_stat-t_statmap.nii.gz')
%   smoke(..., 'sub-01/func/..._desc-preproc_bold.nii.gz')   % also the 4D data check
if ~exist(outDir, 'dir'), mkdir(outDir); end
app = SeeCAT();
for name = {'Preprocessing', 'fMRIPrep denoising', 'Seed FC', 'Degree', 'Statistics', 'Import to BIDS'}
    app.select(name{1});
    drawnow; pause(1);
    exportapp(app.fig, fullfile(outDir, ['launcher_' strrep(name{1}, ' ', '_') '.png']));
end
info = findall(app.fig, 'Type', 'uiimage', 'Tooltip', 'About this option');   % Import to BIDS is showing
if numel(info) ~= 5
    error('smoke:dicom', 'Import to BIDS has %d info icons, not 5.', numel(info));
end
for h = info'
    h.ImageClickedFcn(h, []);
    txt = cellfun(@(t) char(join(string(t), newline)), get(findall(app.fig, 'Type', 'uilabel'), 'Text'), ...
        'UniformOutput', false);
    if ~any(startsWith(txt, 'Default:  ('))
        error('smoke:dicom', 'An info icon on Import to BIDS shows no help.');
    end
end
app.select('Preprocessing');
cfg = app.config();                                 % an untouched form reads back the defaults
d = differences(cfg, seecat.config('prep'), '');
if ~isempty(d)
    error('smoke:roundtrip', 'The preprocessing form changes: %s', strjoin(d, '; '));
end
fprintf('launcher ok (%s)\n', cfg.pipeline);
v = seecat.viewer(statMap);
v.model.setThreshold(1, struct('mode', 'p', 'value', 0.001, 'sign', 'pos', 'correction', 'cluster_fwe', 'alpha', 0.025));
v.refresh();
drawnow; pause(1);
exportapp(v.fig, fullfile(outDir, 'viewer.png'));
for layout = {'single', 'mosaic'}
    v.setLayout(layout{1});
    drawnow; pause(1);
    exportapp(v.fig, fullfile(outDir, ['viewer_' layout{1} '.png']));
end
fprintf('viewer ok\n');
delete(v.fig);
if nargin > 2
    v = seecat.viewer(series);                       % opens on the Time series tab
    v.setFrame(10);
    v.play(); pause(2); v.play();
    exportapp(v.fig, fullfile(outDir, 'viewer_timeseries.png'));
    v.fig.CloseRequestFcn(v.fig, []);
    app.select('Data check');
    drawnow; pause(1);
    exportapp(app.fig, fullfile(outDir, 'launcher_Data_check.png'));
    fprintf('4D check ok\n');
end
delete(app.fig);
end

function d = differences(a, b, prefix)
d = {};
for f = fieldnames(b)'
    x = a.(f{1});
    y = b.(f{1});
    if isstruct(y) && isscalar(y)
        d = [d, differences(x, y, [prefix f{1} '.'])]; %#ok<AGROW>
    elseif ~isequaln(x, y)
        d{end+1} = sprintf('%s%s: %s (%s) vs %s (%s)', prefix, f{1}, mat2str(size(x)), class(x), mat2str(size(y)), class(y)); %#ok<AGROW>
    end
end
end
