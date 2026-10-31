function smoke(outDir, statMap)
% SMOKE  Open every SeeCAT window and save screenshots (needs a desktop
% session; -batch cannot draw windows). exportapp leaves out the uihtml
% parts (side bar, section links); check those on screen.
%   smoke('C:/tmp/shots', 'group/x/x_contrast-pos_stat-t_statmap.nii.gz')
if ~exist(outDir, 'dir'), mkdir(outDir); end
app = SeeCAT();
for name = {'Preprocessing', 'fMRIPrep denoising', 'Seed FC', 'Degree', 'Statistics', 'DICOM to BIDS'}
    app.select(name{1});
    drawnow; pause(1);
    exportapp(app.fig, fullfile(outDir, ['launcher_' strrep(name{1}, ' ', '_') '.png']));
end
app.select('Preprocessing');
cfg = app.config();                                  % an untouched form reads back the defaults
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
