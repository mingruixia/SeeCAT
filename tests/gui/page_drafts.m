function problems = page_drafts()
% PAGE_DRAFTS  Settings on a pipeline page survive a visit to other pages
% (needs a desktop session). Review finding F11: they used to fall back to
% the defaults.
%   problems = page_drafts()
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, '..', '..', 'SeeCAT'));
d = tempname;
mkdir(d);
c1 = onCleanup(@() rmdir(d, 's'));
app = SeeCAT();
c2 = onCleanup(@() delete(app.fig));
problems = {};

cfg = seecat.config('prep');
cfg.bids_dir = d;
cfg.dummy_scans = 7;
f = fullfile(d, 'prep.json');
seecat.save_config(cfg, f);
app.load(f);
drawnow;
fc = seecat.config('fc');
fc.input_dir = d;
fc.seeds = struct('name', 'PCC', 'center', [0 -53 26], 'radius', 6, 'file', '');
f2 = fullfile(d, 'fc.json');
seecat.save_config(fc, f2);
app.load(f2);                                     % leaves Preprocessing for Seed FC
drawnow;
for p = {'Statistics', 'QC reports', 'Viewer', 'Preprocessing'}
    app.select(p{1});
    drawnow;
end
got = app.config();
if ~isequal(got.dummy_scans, 7), problems{end+1} = sprintf('dummy_scans came back as %s', mat2str(got.dummy_scans)); end
if ~strcmp(got.bids_dir, d), problems{end+1} = sprintf('bids_dir came back as "%s"', got.bids_dir); end
app.select('Seed FC');
drawnow;
got = app.config();
if numel(got.seeds) ~= 1 || ~strcmp(got.seeds(1).name, 'PCC'), problems{end+1} = 'the Seed FC seeds were lost'; end
fprintf('%d problem(s)\n', numel(problems));
for i = 1:numel(problems)
    fprintf('  %s\n', problems{i});
end
end
