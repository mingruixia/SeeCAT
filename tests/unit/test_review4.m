function tests = test_review4
% Regression tests for the findings of the 2026-11-11 review: a config that
% a plan added its left-out runs to runs again (C06), Gradients leaves out
% short runs but fails on an empty analysis mask (C07, the behaviour the
% manual describes), and count options refuse Inf (C08).
%   results = runtests('tests/unit/test_review4.m')
tests = functiontests(localfunctions);
end

function setupOnce(~)
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, '..', '..', 'SeeCAT'));
spmDir = getenv('SEECAT_SPM');
if isempty(spmDir)
    spmDir = 'D:/verysync/dropbox/SciTools/MatlabToolbox/spm';
end
addpath(spmDir);
end

function setup(tc)
tc.TestData.root = tempname;
tc.TestData.in = fullfile(tc.TestData.root, 'derivatives', 'seecat');
for s = 1:3
    makeRun(tc.TestData.in, sprintf('%02d', s));
end
end

function teardown(tc)
if exist(tc.TestData.root, 'dir')
    rmdir(tc.TestData.root, 's');
end
end

function testSavedGradientConfigRunsAgain(tc)
% C06: a run left out for min_frames put few_frames into the saved config,
% which check_config then refused as an unknown option
in = tc.TestData.in;
censorFrom(in, '02', 41);                         % sub-02 keeps 40 of 120 frames
cfg = gradientConfig(in);
cfg.mask_mode = 'group';
S = quiet(@() seecat.run(cfg));
tc.verifyEqual(S.status, {'ok'}, S.message{1});
tc.verifyEqual(S.n_runs, 2);
saved = newest(fullfile(in, 'logs', 'gradient_*_config.json'));
j = jsondecode(fileread(saved));
tc.verifyFalse(isfield(j, 'few_frames'));          % options only
seecat.check_config(seecat.config(saved));
S = quiet(@() seecat.run(saved));                 % same options and inputs
tc.verifyEqual(S.status, {'skipped'}, S.message{1});
tc.verifyEqual(S.n_runs, 2);
tc.verifySubstring(fileread(newest(fullfile(in, 'logs', 'gradient_*.log'))), ...
    'fewer than min_frames (50) frames kept after censoring: sub-02_task-rest');

[~, planned] = seecat.gradient.plan(cfg);         % the planned config runs too
tc.verifyEqual(planned.few_frames, {'sub-02_task-rest'});
S = quiet(@() seecat.run(planned));
tc.verifyEqual(S.status, {'skipped'}, S.message{1});

% A config saved by an earlier build, with the field in the file
j.few_frames = {'sub-02_task-rest'};
old = fullfile(tc.TestData.root, 'old_config.json');
seecat.util.write_json(old, j);
tc.verifyFalse(isfield(seecat.config(old), 'few_frames'));

% The list follows the options: with min_frames 40 no run is left out
planned.min_frames = 40;
[units, again] = seecat.gradient.plan(planned);
tc.verifyNumElements(units.runs, 3);
tc.verifyFalse(isfield(again, 'few_frames'));
S = quiet(@() seecat.run(planned));
tc.verifyEqual(S.status, {'ok'}, S.message{1});
tc.verifyEqual(S.n_runs, 3);
tc.verifyEmpty(strfind(fileread(newest(fullfile(in, 'logs', 'gradient_*.log'))), 'Left out'));
src = jsondecode(fileread(fullfile(in, 'sub-02', 'func', ...
    'sub-02_task-rest_space-IXI549Space_res-3_desc-grad1Vox3_connectivity.json')));
tc.verifyTrue(isstruct(src));                     % sub-02 has maps again

% A misspelt option is still refused
planned.min_frame = 40;
tc.verifyError(@() seecat.run(planned), 'SeeCAT:config');
end

function testSavedConfigWithQcExclusionsRunsAgain(tc)
% C06, same pattern: qc_excluded (runs excluded by QC) in the saved config
in = tc.TestData.in;
mkdir(fullfile(in, 'reports'));
X = table({'sub-02_task-rest'}, {'bold'}, 1, {'mean FD > 0.5 mm'}, {''}, {'auto'}, {''}, ...
    'VariableNames', {'id', 'kind', 'exclude', 'reasons', 'warnings', 'decision', 'note'});
qc = fullfile(in, 'reports', 'qc_exclusions.tsv');
seecat.io.write_tsv(X, qc);
cfg = seecat.config('fc');
cfg.input_dir = in;
cfg.n_workers = 0;
cfg.seeds = struct('name', 'S', 'center', [0 0 0], 'radius', 4);
S = quiet(@() seecat.run(cfg));
tc.verifyEqual(S.unit', {'sub-01_task-rest', 'sub-03_task-rest'});
saved = newest(fullfile(in, 'logs', 'fc_*_config.json'));
tc.verifyFalse(isfield(jsondecode(fileread(saved)), 'qc_excluded'));
S = quiet(@() seecat.run(saved));
tc.verifyEqual(S.status', {'skipped', 'skipped'});
tc.verifySubstring(fileread(newest(fullfile(in, 'logs', 'fc_*.log'))), 'Left out by QC');

[~, planned] = seecat.fc.plan(cfg);
tc.verifyEqual(planned.qc_excluded, {'sub-02_task-rest'});
delete(qc);                                       % the exclusion is withdrawn
[units, again] = seecat.fc.plan(planned);
tc.verifyNumElements(units, 3);
tc.verifyFalse(isfield(again, 'qc_excluded'));
S = quiet(@() seecat.run(planned));
tc.verifyEqual(S.unit', {'sub-01_task-rest', 'sub-02_task-rest', 'sub-03_task-rest'});
end

function testGradientsShortRunLeftOutEmptyMaskFails(tc)
% C07: the two cases of the manual. A run below min_frames is left out and
% the others give gradients; an analysis mask that is empty on one run's
% grid stops the analysis, and no map is written
in = tc.TestData.in;
cfg = gradientConfig(in);
cfg.mask_mode = 'given';
d = fullfile(in, 'sub-02', 'func');
for suffix = {'desc-denoised_bold', 'desc-brain_mask'}
    f = fullfile(d, ['sub-02_task-rest_space-IXI549Space_res-3_' suffix{1} '.nii.gz']);
    [data, V] = seecat.io.read_nii(f);
    V = V(1);
    V.mat(1, 4) = V.mat(1, 4) + 1000;             % sub-02 lies 1 m from the mask
    seecat.io.write_nii(data, V, f);
end
S = quiet(@() seecat.run(cfg));
tc.verifyEqual(S.status, {'failed'});
tc.verifySubstring(S.message{1}, 'analysis mask');
tc.verifyEmpty(dir(fullfile(in, 'sub-*', 'func', '*_connectivity.nii.gz')));
censorFrom(in, '02', 41);                         % now also too short: left out before it is read
S = quiet(@() seecat.run(cfg));
tc.verifyEqual(S.status, {'ok'}, S.message{1});
tc.verifyEqual(S.n_runs, 2);
end

function testCountOptionsRefuseInf(tc)
% C08: Inf == round(Inf), so min_frames = Inf passed "an integer >= 2"
v = seecat.util.validators;
for x = {Inf, -Inf, NaN, 2.5, -1, 1 + 2i, [2 3], '2'}
    tc.verifyFalse(v.count(x{1}), mat2str(x{1}));
end
for x = {0, 1, 2, 50, int32(7)}
    tc.verifyTrue(v.count(x{1}), mat2str(x{1}));
end
for p = {'fc', 'degree', 'gradient'}
    cfg = seecat.config(p{1});
    cfg.input_dir = tc.TestData.in;
    cfg.seeds = struct('name', 'S', 'center', [0 0 0], 'radius', 4);
    if ~strcmp(p{1}, 'fc')
        cfg = rmfield(cfg, 'seeds');
    end
    for bad = {Inf, -Inf, NaN, 2.5, 1}
        cfg.min_frames = bad{1};
        msg = errorMessage(@() seecat.check_config(cfg));
        tc.verifySubstring(msg, 'min_frames must be an integer >= 2', sprintf('%s %g', p{1}, bad{1}));
    end
    for good = {2, 50}
        cfg.min_frames = good{1};
        seecat.check_config(cfg);
    end
end
end

function cfg = gradientConfig(in)
cfg = seecat.config('gradient');
cfg.input_dir = in;
cfg.n_workers = 0;
cfg.node_size = 3;
cfg.mask = fullfile(in, 'sub-01', 'func', 'sub-01_task-rest_space-IXI549Space_res-3_desc-brain_mask.nii.gz');
end

function censorFrom(in, sub, first)
% Censor the frames FIRST ... end of a run
tsv = fullfile(in, ['sub-' sub], 'func', ['sub-' sub '_task-rest_desc-confounds_timeseries.tsv']);
T = seecat.io.read_tsv(tsv);
T.censor(first:end) = 1;
seecat.io.write_tsv(T, tsv);
end

function f = newest(pattern)
% The last file matching PATTERN by name (run ids sort by time)
d = dir(pattern);
[~, o] = sort({d.name});
f = fullfile(d(o(end)).folder, d(o(end)).name);
end

function makeRun(in, sub)
% 6x6x6 voxels at 3 mm; the halves x <= 3 and x > 3 follow two signals
rng(str2double(sub));
d = fullfile(in, ['sub-' sub], 'func');
mkdir(d);
stem = fullfile(d, ['sub-' sub '_task-rest']);
M = [3 0 0 -9; 0 3 0 -9; 0 0 3 -9; 0 0 0 1];
V = struct('dim', [6 6 6], 'mat', M);
nT = 120;
a = randn(nT, 1);
b = randn(nT, 1);
w = reshape(linspace(1, 0, 6), 6, 1, 1);
Y = reshape(a, 1, 1, 1, nT) .* w + reshape(b, 1, 1, 1, nT) .* (1 - w) + 0.7 * randn(6, 6, 6, nT);
seecat.io.write_nii(Y, V, [stem '_space-IXI549Space_res-3_desc-denoised_bold.nii.gz']);
seecat.io.write_nii(uint8(true(6, 6, 6)), V, [stem '_space-IXI549Space_res-3_desc-brain_mask.nii.gz'], 'DataType', 'uint8');
T = table();
T.framewise_displacement = rand(nT, 1);
T.censor = zeros(nT, 1);
seecat.io.write_tsv(T, [stem '_desc-confounds_timeseries.tsv']);
end

function out = quiet(fn)
[~, out] = evalc('fn()');
end

function msg = errorMessage(fn)
msg = '';
try
    fn();
catch err
    msg = err.message;
end
end
