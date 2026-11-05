function tests = test_audit
% Regression tests for the findings of the 2026-11-05 review (F01-F15):
% each reproduces a case that used to give a wrong result silently.
%   results = runtests('tests/unit/test_audit.m')
tests = functiontests(localfunctions);
end

function setupOnce(~)
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, '..', '..', 'SeeCAT'));
addpath(fullfile(here, '..', 'fixtures'));
spmDir = getenv('SEECAT_SPM');
if isempty(spmDir)
    spmDir = 'D:/verysync/dropbox/SciTools/MatlabToolbox/spm';
end
addpath(spmDir);
end

function setup(tc)
tc.TestData.root = tempname;
mkdir(tc.TestData.root);
end

function teardown(tc)
if exist(tc.TestData.root, 'dir')
    rmdir(tc.TestData.root, 's');
end
end

%% F01: resume checks inputs and outputs, not just options
function testResumeRedoesUnitsWithChangedInputsOrMissingOutputs(tc)
root = tc.TestData.root;
in = fullfile(root, 'input.txt');
writeText(in, 'a');
cfg = seecat.config('demo');
cfg.output_dir = fullfile(root, 'derivatives', 'seecat');
cfg.work_dir = fullfile(root, 'work');
cfg.input_file = in;
S = quiet(@() seecat.run(cfg));
tc.verifyEqual(S.status, {'ok'; 'ok'; 'ok'});
S = quiet(@() seecat.run(cfg));
tc.verifyEqual(S.status, {'skipped'; 'skipped'; 'skipped'});
% an output deleted: only that unit runs again
delete(fullfile(cfg.output_dir, 'deriv', 'u2_value-1.txt'));
S = quiet(@() seecat.run(cfg));
tc.verifyEqual(S.status, {'skipped'; 'ok'; 'skipped'});
tc.verifyTrue(exist(fullfile(cfg.output_dir, 'deriv', 'u2_value-1.txt'), 'file') == 2);
% the input edited (same path, same options): every unit runs again
writeText(in, 'changed content');
S = quiet(@() seecat.run(cfg));
tc.verifyEqual(S.status, {'ok'; 'ok'; 'ok'});
tc.verifySubstring(unitLogs(cfg, 'u1'), 'the inputs changed');
tc.verifySubstring(unitLogs(cfg, 'u2'), 'missing');
end

%% F14: two runs in the same second keep separate logs and configs
function testRunIdsAreUnique(tc)
root = tc.TestData.root;
cfg = seecat.config('demo');
cfg.output_dir = fullfile(root, 'derivatives', 'seecat');
cfg.work_dir = fullfile(root, 'work');
cfg.overwrite = true;
quiet(@() seecat.run(cfg));
quiet(@() seecat.run(cfg));
tc.verifyNumElements(dir(fullfile(cfg.output_dir, 'logs', 'demo_*_config.json')), 2);
tc.verifyNumElements(dir(fullfile(cfg.output_dir, 'reports', 'demo_*_summary.tsv')), 2);
end

%% F02, F13: smoothing never writes next to its input, drops the leading frames, keeps TR
function testSmoothWritesToWorkFolderWithoutLeadingFrames(tc)
root = tc.TestData.root;
src = fullfile(root, 'fmriprep', 'sub-01_task-rest_space-MNI_desc-preproc_bold.nii');
M = [-3 0 0 6; 0 3 0 -6; 0 0 3 -6; 0 0 0 1];
seecat.io.write_nii(rand(4, 4, 4, 30) + 1, struct('dim', [4 4 4], 'mat', M), src);
before = dir(fullfile(root, 'fmriprep'));
ctx = struct('work_dir', fullfile(root, 'work'), 'tr', 2, 'first_frame', 3, ...
    'files', struct('wbold', src));
ctx = seecat.steps.smooth(ctx, struct('fwhm', 6));
tc.verifyEqual(fileparts(ctx.files.smoothed), ctx.work_dir);
after = dir(fullfile(root, 'fmriprep'));
tc.verifyEqual({after.name}, {before.name});            % nothing new next to the input
h = seecat.io.nii_info(ctx.files.smoothed);
tc.verifyEqual(h.dim(4), 28);
tc.verifyEqual(h.tr, 2, 'AbsTol', 1e-6);
end

%% F05: the same run at two resolutions must be chosen between
function testSeveralResolutionsNeedRes(tc)
d = fullfile(tc.TestData.root, 'seecat');
f = fullfile(d, 'sub-01', 'func');
mkdir(f);
for r = {'2', '3'}
    for n = {['_res-' r{1} '_desc-denoised_bold.nii'], ['_res-' r{1} '_desc-brain_mask.nii']}
        writeText(fullfile(f, ['sub-01_task-rest_space-MNI' n{1}]), '');
    end
end
writeText(fullfile(f, 'sub-01_task-rest_desc-confounds_timeseries.tsv'), 'a');
cfg = seecat.config('fc');
cfg.input_dir = d;
tc.verifyError(@() seecat.bids.derivative_units(cfg, 'denoised'), 'SeeCAT:bids');
cfg.res = '2';
U = seecat.bids.derivative_units(cfg, 'denoised');
tc.verifyNumElements(U, 1);
tc.verifySubstring(U.bold, 'res-2');
end

%% F06: contrast names that clean to the same file name are refused
function testContrastNamesMustGiveDistinctFiles(tc)
root = tc.TestData.root;
M = [-3 0 0 9; 0 3 0 -9; 0 0 3 -9; 0 0 0 1];
n = 8;
paths = cell(n, 1);
for i = 1:n
    paths{i} = fullfile(root, sprintf('sub-%02d_map.nii', i));
    seecat.io.write_nii(randn(6, 6, 6) + 10, struct('dim', [6 6 6], 'mat', M), paths{i});
end
g = double((1:n)' > n / 2);
seecat.io.write_tsv(table(paths, 1 - g, g, 'VariableNames', {'path', 'A', 'B'}), fullfile(root, 'design.tsv'));
cfg = seecat.config('stat');
cfg.name = 'names';
cfg.design = 'custom';
cfg.design_tsv = fullfile(root, 'design.tsv');
cfg.output_dir = fullfile(root, 'out');
cfg.mask = 'brain';
cfg.contrasts = struct('name', {'A-B', 'AB'}, 'type', 't', 'weights', {[1 -1], [-1 1]});
S = quiet(@() seecat.run(cfg));
tc.verifyEqual(S.status, {'failed'});
tc.verifySubstring(S.message{1}, 'same file names');
end

%% F03: image covariates with non-sphericity: every voxel gets its own df
function testImageCovariateDfPerVoxel(tc)
rng(3);
n = 12;
X = [ones(n, 1), double((1:n)' > 6)];
C = randn(n, 3);
Y = X * [1; 0.5] + 0.7 * C + randn(n, 3);
A = randn(n);
V = A * A' / n + eye(n);
con = struct('name', 'g', 'type', 't', 'weights', [0 1 0]);
G = seecat.stat.glm(Y, X, con, struct('V', V, 'Ximg', reshape(C, n, 3, 1)));
for v = 1:3
    Gv = seecat.stat.glm(Y(:, v), [X C(:, v)], con, struct('V', V));
    tc.verifyEqual(G.con(1).stat(v), Gv.con(1).stat, 'RelTol', 1e-9);
    tc.verifyEqual(G.erdf_voxel(v), Gv.erdf, 'RelTol', 1e-9);
    tc.verifyEqual(G.con(1).p(v), Gv.con(1).p, 'RelTol', 1e-6);
end
tc.verifyEqual(G.erdf, min(G.erdf_voxel));
% a voxel whose covariate is constant (rank changes) is refused, not fitted with another df
C(:, 2) = 0;
tc.verifyError(@() seecat.stat.glm(Y, X, con, struct('Ximg', reshape(C, n, 3, 1))), 'SeeCAT:stat');
end

%% F04, F10: ComBat with one feature, CovBat with one component and a reference site
function testCombatDegenerateCasesAndCovbatReference(tc)
rng(6);
site = repelem({'A'; 'B'; 'C'}, 10);
y = randn(30, 1) + repelem([0; 1; -1], 10);
[h, est] = seecat.harmonize.combat(y, site);
tc.verifyTrue(all(isfinite(h)));
tc.verifyEqual(numel(est.eb_skipped), 3);                 % one feature: no prior, no EB
Y = randn(30, 40) + repelem([0; 1; -1], 10) + randn(30, 1) * ones(1, 40) * 3;
[H, info] = seecat.harmonize.covbat(Y, site, [], struct('pct_var', 0.01));
tc.verifyEqual(info.components, 1);
tc.verifyTrue(all(isfinite(H(:))));
H = seecat.harmonize.covbat(Y, site, [], struct('ref', 'A'));
tc.verifyEqual(H(1:10, :), Y(1:10, :));
tc.verifyGreaterThan(max(abs(H(11:end, :) - Y(11:end, :)), [], 'all'), 0.1);
end

%% F07: SliceTiming follows SliceEncodingDirection
function testSliceTimesFollowEncodingDirection(tc)
st = [0 0.5 1 1.5];
tc.verifyEqual(seecat.bids.slice_times(st, 'k'), st);
tc.verifyEqual(seecat.bids.slice_times(st, ''), st);
tc.verifyEqual(seecat.bids.slice_times(st, 'k-'), fliplr(st));
tc.verifyError(@() seecat.bids.slice_times(st, 'j'), 'SeeCAT:prep');
tc.verifyError(@() seecat.bids.slice_times(st, 'i-'), 'SeeCAT:prep');
end

%% F09: sessions, task and runs narrow the maps of Statistics and Harmonize
function testCommonSelectionNarrowsMaps(tc)
cfg = seecat.config('stat');
cfg.maps = struct('desc', 'PCC', 'stat', 'z');
cfg.task = 'rest';
cfg.sessions = {'A'};
sel = seecat.bids.map_selector(cfg);
tc.verifyEqual(sel.task, 'rest');
tc.verifyEqual(sel.ses, {'A'});
cfg.maps.task = 'memory';
tc.verifyError(@() seecat.bids.map_selector(cfg), 'SeeCAT:config');
% in a plan
d = fullfile(tc.TestData.root, 'seecat');
M = [-3 0 0 9; 0 3 0 -9; 0 0 3 -9; 0 0 0 1];
for i = 1:4
    for t = {'rest', 'memory'}
        f = fullfile(d, sprintf('sub-%02d', i), 'func', sprintf('sub-%02d_task-%s_desc-PCC_stat-z_connectivity.nii', i, t{1}));
        seecat.io.write_nii(randn(6, 6, 6), struct('dim', [6 6 6], 'mat', M), f);
    end
end
c = seecat.config('stat');
c.name = 'sel';
c.input_dir = d;
c.maps = struct('desc', 'PCC', 'stat', 'z');
c.task = 'rest';
[U, ~] = seecat.stat.plan(seecat.config(c));
tc.verifyEqual(height(U.maps), 4);
tc.verifyTrue(all(contains(U.maps.path, 'task-rest')));
end

%% F12: number fields take numbers only
function testNumberParsingIsStrict(tc)
for s = {'1/2', '1e-3xyz', '10mm', '[[1 2]]', '1 2 abc'}
    tc.verifyError(@() seecat.gui.parse(s{1}, 'number', 6), 'SeeCAT:gui', s{1});
end
tc.verifyEqual(seecat.gui.parse('1E-3', 'number', 6), 1e-3);
tc.verifyEqual(seecat.gui.parse('[1, 2; 3 4]', 'text', zeros(2)), [1 2; 3 4]);
tc.verifyEqual(seecat.gui.parse('0 75 -Inf', 'text', [0 1 2]), [0 75 -Inf]);
tc.verifyEqual(seecat.gui.parse('10mm', 'text', 'auto'), '10mm');   % a text option keeps the text
end

%% F08: SeeCAT's own code calls no toolbox beyond MATLAB (Parallel Computing
% is optional). 'toponly': SPM's functions mention toolboxes they use only
% when present.
function testNoOtherToolboxIsNeeded(tc)
here = fileparts(mfilename('fullpath'));
f = dir(fullfile(here, '..', '..', 'SeeCAT', '**', '*.m'));
bad = {};
for k = 1:numel(f)
    fn = fullfile(f(k).folder, f(k).name);
    [~, p] = matlab.codetools.requiredFilesAndProducts(fn, 'toponly');
    n = setdiff({p.Name}, {'MATLAB', 'Parallel Computing Toolbox'});
    if ~isempty(n)
        bad{end+1} = sprintf('%s (%s)', f(k).name, strjoin(n, ', ')); %#ok<AGROW>
    end
end
tc.verifyEmpty(bad, strjoin(bad, '; '));
end

%% Helpers
function txt = unitLogs(cfg, unit)
L = dir(fullfile(cfg.output_dir, 'logs', 'demo_*', [unit '.log']));
txt = strjoin(arrayfun(@(f) fileread(fullfile(f.folder, f.name)), L, 'UniformOutput', false));
end

function writeText(f, s)
d = fileparts(f);
if ~exist(d, 'dir')
    mkdir(d);
end
fid = fopen(f, 'w');
fprintf(fid, '%s', s);
fclose(fid);
end

function out = quiet(fn)
[~, out] = evalc('fn()');
end
