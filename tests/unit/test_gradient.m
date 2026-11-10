function tests = test_gradient
% Tests for seecat.gradient: the embedding against an exact
% eigendecomposition (the BrainSpace steps), Procrustes alignment, and the
% pipeline on synthetic derivatives.
%   results = runtests('tests/unit/test_gradient.m')
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

function testEmbedEqualsDefinition(tc)
rng(1);
X = randn(150, 6) * (randn(6, 120) .* linspace(0.2, 2, 120)) + randn(150, 120);
R = corrcoef(X);
for kern = {'normalized_angle', 'cosine'}
    [G, l] = seecat.gradient.embed(R, struct('kernel', kern{1}));
    tc.verifyEqual(G, reference(R, kern{1}), 'AbsTol', 1e-8, kern{1});
    tc.verifySize(l, [1 10]);
    tc.verifyTrue(issorted(l, 'descend'));
end
end

function testAlignRecoversRotations(tc)
rng(2);
base = randn(300, 5);
G = cell(1, 4);
for i = 1:4
    [Q, ~] = qr(randn(5));
    G{i} = (base + 0.01 * randn(300, 5)) * Q;
end
G{2}(7, :) = NaN;                                  % a node missing in one run
A = seecat.gradient.align(G);
for i = 2:4
    ok = all(isfinite(A{i}), 2);
    tc.verifyEqual(A{i}(ok, :), A{1}(ok, :), 'AbsTol', 0.1);     % noise 0.01 per run
end
tc.verifyTrue(all(isnan(A{2}(7, :))));
end

function testPipeline(tc)
root = tempname;
c = onCleanup(@() rmdir(root, 's'));
in = fullfile(root, 'derivatives', 'seecat');
for s = 1:3
    makeRun(in, sprintf('%02d', s));
end
mask = fullfile(in, 'sub-01', 'func', 'sub-01_task-rest_space-IXI549Space_res-3_desc-brain_mask.nii.gz');
cfg = seecat.config('gradient');
cfg.input_dir = in;
cfg.node_size = 3;
cfg.mask = mask;
S = quiet(@() seecat.run(cfg));
tc.verifyEqual(S.status, {'ok'});
tc.verifyEqual(S.n_nodes, 216);
f = @(s, k) fullfile(in, ['sub-' s], 'func', sprintf('sub-%s_task-rest_space-IXI549Space_res-3_desc-grad%dVox3_connectivity.nii.gz', s, k));
tc.verifyTrue(exist(f('02', 3), 'file') == 2);
% gradient 1 separates the two halves that follow different signals, in every run
[x, y, z] = ndgrid(-6:3:9);                       % the data voxels, mm
for s = {'01', '02', '03'}
    g = valuesAt(f(s{1}, 1), [x(:) y(:) z(:)]);
    a = g(x(:) < 1.5);
    b = g(x(:) > 1.5);
    tc.verifyGreaterThan(abs(mean(a) - mean(b)) / std(g), 1.5, s{1});
    signs(str2double(s{1})) = sign(mean(a(:)) - mean(b(:))); %#ok<AGROW>
end
tc.verifyEqual(numel(unique(signs)), 1);          % aligned: same orientation in every run
j = jsondecode(fileread(strrep(f('01', 1), '.nii.gz', '.json')));
tc.verifyEqual(numel(j.Lambdas), 10);
tc.verifyTrue(exist(fullfile(in, 'group', 'gradientsVox3', 'gradientsVox3_desc-grad1_reference.nii.gz'), 'file') == 2);
tc.verifyTrue(exist(fullfile(in, 'group', 'gradientsVox3', 'gradientsVox3_desc-grad1_groupmatrix.nii.gz'), 'file') == 2);

% n_workers = 'auto': a choice from the memory estimate, with a note for the log
[units, c2] = seecat.gradient.plan(seecat.config(cfg));
c2.n_workers = 'auto';
[n, note] = seecat.util.auto_workers(c2, units);
tc.verifyGreaterThanOrEqual(n, 0);
tc.verifyLessThanOrEqual(n, 3);                    % never more than the runs
tc.verifyNotEqual(n, 1);                          % 1 worker is never chosen
tc.verifySubstring(note, 'worker');

% an atlas with one label per voxel gives the voxel result
[m, V] = seecat.io.read_nii(mask);
atlas = reshape(1:216, 6, 6, 6) .* (m > 0);
af = fullfile(root, 'atlas.nii');
seecat.io.write_nii(atlas, V, af);
cfg.nodes = 'atlas';
cfg.atlas = af;
cfg.output_dir = fullfile(root, 'atlas_out');
S = quiet(@() seecat.run(cfg));
tc.verifyEqual(S.status, {'ok'});
ga = valuesAt(fullfile(root, 'atlas_out', 'sub-02', 'func', ...
    'sub-02_task-rest_space-IXI549Space_res-3_desc-grad1Atlasatlas_connectivity.nii.gz'), [x(:) y(:) z(:)]);
gv = valuesAt(f('02', 1), [x(:) y(:) z(:)]);
tc.verifyEqual(ga, gv, 'AbsTol', 1e-5);
end

function testGroupMask(tc)
% sub-03's brain mask lacks the slab x = 9 mm: with the group mask, every
% run's node series come from the same 180 voxels; parcels of two voxels
% along x then average one voxel at that edge in every run
root = tempname;
c = onCleanup(@() rmdir(root, 's'));
in = fullfile(root, 'derivatives', 'seecat');
for s = 1:3
    makeRun(in, sprintf('%02d', s));
end
f = fullfile(in, 'sub-03', 'func', 'sub-03_task-rest_space-IXI549Space_res-3_desc-brain_mask.nii.gz');
[m, V] = seecat.io.read_nii(f);
m(6, :, :) = 0;
seecat.io.write_nii(uint8(m), V(1), f, 'DataType', 'uint8');
[i, ~, ~] = ndgrid(1:6, 1:6, 1:6);
atlas = ceil(i / 2) + 3 * (reshape(0:35, 1, 6, 6));   % 108 parcels of 2 voxels along x
af = fullfile(root, 'atlas.nii');
seecat.io.write_nii(atlas, V(1), af);
cfg = seecat.config('gradient');
cfg.input_dir = in;
cfg.nodes = 'atlas';
cfg.atlas = af;
cfg.mask_mode = 'group';
units = seecat.gradient.plan(seecat.config(cfg));
g = units.runs(1).group_mask;
tc.verifyEqual(nnz(seecat.io.read_nii(g) > 0), 180);
tc.verifyTrue(all(strcmp({units.runs.group_mask}, g)));
S1 = seecat.conn.load_series(units.runs(1), 'brain', true);
tc.verifyNumElements(S1.index, 180);
S0 = seecat.conn.load_series(rmfield(units.runs(1), 'group_mask'), 'brain', true);
tc.verifyNumElements(S0.index, 216);
S = quiet(@() seecat.run(cfg));
tc.verifyEqual(S.status, {'ok'}, S.message{1});
tc.verifyEqual(S.n_common_nodes, 108);
j = jsondecode(fileread(fullfile(in, 'sub-01', 'func', ...
    'sub-01_task-rest_space-IXI549Space_res-3_desc-grad1Atlasatlas_connectivity.json')));
[~, gn, ge] = fileparts(g);
tc.verifyEqual(j.GroupMask, ['bids:seecat:group/masks/' gn ge]);
end

function testMaskAsGiven(tc)
% sub-03's brain mask lacks the slab x = 9 mm but its data do not (as
% fMRIPrep data can): with the atlas used as given, every run averages the
% 180 atlas voxels (the atlas has no voxels at x = -6 mm)
root = tempname;
c = onCleanup(@() rmdir(root, 's'));
in = fullfile(root, 'derivatives', 'seecat');
for s = 1:3
    makeRun(in, sprintf('%02d', s));
end
f = fullfile(in, 'sub-03', 'func', 'sub-03_task-rest_space-IXI549Space_res-3_desc-brain_mask.nii.gz');
[m, V] = seecat.io.read_nii(f);
m(6, :, :) = 0;
seecat.io.write_nii(uint8(m), V(1), f, 'DataType', 'uint8');
[i, ~, ~] = ndgrid(1:6, 1:6, 1:6);
atlas = ceil(i / 2) + 3 * (reshape(0:35, 1, 6, 6));
atlas(1, :, :) = 0;
af = fullfile(root, 'atlas.nii');
seecat.io.write_nii(atlas, V(1), af);
cfg = seecat.config('gradient');
cfg.input_dir = in;
cfg.nodes = 'atlas';
cfg.atlas = af;
cfg.mask_mode = 'given';
units = seecat.gradient.plan(seecat.config(cfg));
N = units.nodes;
S3 = seecat.conn.load_series(units.runs(3), N.mask_file, true, struct('mask_only', true));
tc.verifyNumElements(S3.index, 180);
tc.verifyEqual(nnz(S3.brain), 144);
tc.verifyTrue(all(S3.live));
S0 = seecat.conn.load_series(units.runs(3), 'brain', true);
tc.verifyNumElements(S0.index, 180);              % the brain mask: x = 9 mm left out
tc.verifyEqual(nnz(S0.xyz(1, :) > 7.5), 0);
S = quiet(@() seecat.run(cfg));
tc.verifyEqual(S.status, {'ok'}, S.message{1});
tc.verifyEqual(S.n_common_nodes, 108);
j = jsondecode(fileread(fullfile(in, 'sub-03', 'func', ...
    'sub-03_task-rest_space-IXI549Space_res-3_desc-grad1Atlasatlas_connectivity.json')));
tc.verifyEqual(j.MaskMode, 'given');
end

function testRunsWithFewFramesLeftOut(tc)
% A run keeping fewer than min_frames (default 50) frames after censoring
% is left out of the gradients and named in cfg.few_frames; with every run
% too short the analysis stops
root = tempname;
c = onCleanup(@() rmdir(root, 's'));
in = fullfile(root, 'derivatives', 'seecat');
for s = 1:3
    makeRun(in, sprintf('%02d', s));
end
tsv = fullfile(in, 'sub-02', 'func', 'sub-02_task-rest_desc-confounds_timeseries.tsv');
T = seecat.io.read_tsv(tsv);
T.censor(41:end) = 1;                             % keeps 40 of 120 frames
seecat.io.write_tsv(T, tsv);
cfg = seecat.config('gradient');
cfg.input_dir = in;
cfg.node_size = 3;
cfg.mask = fullfile(in, 'sub-01', 'func', 'sub-01_task-rest_space-IXI549Space_res-3_desc-brain_mask.nii.gz');
[units, cfg2] = seecat.gradient.plan(cfg);
tc.verifyEqual(cfg2.few_frames, {'sub-02_task-rest'});
tc.verifyEqual({units.runs.id}, {'sub-01_task-rest', 'sub-03_task-rest'});
S = quiet(@() seecat.run(cfg));
tc.verifyEqual(S.status, {'ok'});
tc.verifyEqual(S.n_runs, 2);
tc.verifyEmpty(dir(fullfile(in, 'sub-02', 'func', '*grad1Vox3_connectivity.nii.gz')));
log = dir(fullfile(in, 'logs', 'gradient_*.log'));
tc.verifySubstring(fileread(fullfile(log(1).folder, log(1).name)), ...
    'fewer than min_frames (50) frames kept after censoring: sub-02_task-rest');
cfg.min_frames = 40;                              % 40 kept frames are enough
[units, cfg3] = seecat.gradient.plan(cfg);
tc.verifyNumElements(units.runs, 3);
tc.verifyFalse(isfield(cfg3, 'few_frames'));
cfg.min_frames = 200;                             % no run keeps 200 frames
tc.verifyError(@() seecat.gradient.plan(cfg), 'SeeCAT:gradient');
end

function v = valuesAt(file, mm)
[g, V] = seecat.io.read_nii(file);
p = round(V.mat \ [mm'; ones(1, size(mm, 1))]);
v = g(sub2ind(size(g), p(1, :), p(2, :), p(3, :)))';
end

function G = reference(R, kernel)
% BrainSpace's steps, with an exact symmetric eigendecomposition
n = size(R, 1);
k = floor((1 - 0.9) * n);                         % as BrainSpace: 0.0999... x n, rounded down
S = zeros(n);
for i = 1:n
    [~, o] = sort(R(i, :), 'descend');
    S(i, o(1:k)) = R(i, o(1:k));
end
Sn = S ./ sqrt(sum(S .^ 2, 2));
A = Sn * Sn';
A = min(max(A, -1), 1);
if strcmp(kernel, 'normalized_angle')
    A = 1 - acos(A) / pi;
end
A(A < 0) = 0;
A = (A + A') / 2;
d = sum(A, 2) .^ -0.5;
A = A .* d .* d';
d = sum(A, 2) .^ -0.5;
A = A .* d .* d';
A = (A + A') / 2;
[U, L] = eig(A);
[l, o] = sort(diag(L), 'descend');
U = U(:, o);
psi = U ./ U(:, 1);
lam = l(2:11) ./ (1 - l(2:11));
G = psi(:, 2:11) .* lam';
[~, im] = max(abs(G), [], 1);
G = G .* sign(G(sub2ind(size(G), im, 1:10)));
end

function makeRun(in, sub)
% 6x6x6 voxels at 3 mm; the halves x <= 3 and x > 3 follow two signals
rng(str2double(sub));
d = fullfile(in, ['sub-' sub], 'func');
mkdir(d);
stem = fullfile(d, ['sub-' sub '_task-rest']);
M = [3 0 0 -9; 0 3 0 -9; 0 0 3 -9; 0 0 0 1];       % centres -6 ... 9, on the node grid
V = struct('dim', [6 6 6], 'mat', M);
nT = 120;
a = randn(nT, 1);
b = randn(nT, 1);
w = reshape(linspace(1, 0, 6), 6, 1, 1);          % a smooth change from signal a to signal b
Y = reshape(a, 1, 1, 1, nT) .* w + reshape(b, 1, 1, 1, nT) .* (1 - w) + 0.7 * randn(6, 6, 6, nT);
mask = true(6, 6, 6);
seecat.io.write_nii(Y, V, [stem '_space-IXI549Space_res-3_desc-denoised_bold.nii.gz']);
seecat.io.write_nii(uint8(mask), V, [stem '_space-IXI549Space_res-3_desc-brain_mask.nii.gz'], 'DataType', 'uint8');
T = table();
T.framewise_displacement = rand(nT, 1);
T.censor = zeros(nT, 1);
seecat.io.write_tsv(T, [stem '_desc-confounds_timeseries.tsv']);
end

function out = quiet(fn)
[~, out] = evalc('fn()');
end
